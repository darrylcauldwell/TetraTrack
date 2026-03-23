//
//  WorkoutLifecycleService.swift
//  TetraTrack
//
//  Unified workout lifecycle: prepare → start → collect live data → add route → end → save.
//  Replaces the split LiveWorkoutManager (discard) + HealthKitManager (re-create) approach.
//  Live HR auto-collected by HKLiveWorkoutDataSource is preserved in the final workout.
//

import HealthKit
import CoreLocation
import Observation
import os
import TetraTrackShared

// MARK: - Workout State

enum WorkoutLifecycleState: Sendable {
    case idle
    case preparing
    case active
    case paused
    case ending
}

// MARK: - Mirroring Pipeline State

enum MirroringPipelineState: String, Sendable {
    case idle
    case commandSent
    case mirroringInProgress
    case mirroredSessionReceived

    /// Ordinal for forward-only state validation. Higher = further along.
    var order: Int {
        switch self {
        case .idle: 0
        case .commandSent: 1
        case .mirroringInProgress: 2
        case .mirroredSessionReceived: 3
        }
    }
}

// MARK: - WorkoutLifecycleService

@Observable
@MainActor
final class WorkoutLifecycleService: NSObject {
    static let shared = WorkoutLifecycleService()

    // State
    var state: WorkoutLifecycleState = .idle
    var error: String?

    // Live statistics from HKLiveWorkoutBuilder
    var liveActiveCalories: Double = 0
    var liveDistance: Double = 0
    var liveHeartRate: Int = 0
    var liveStepCount: Int = 0
    var liveSwimmingStrokeCount: Int = 0
    var liveRunningSpeed: Double = 0
    var liveRunningPower: Double = 0
    var liveRunningStrideLength: Double = 0
    var liveGroundContactTime: Double = 0
    var liveVerticalOscillation: Double = 0

    // Internal HealthKit objects
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var routeBuilder: HKWorkoutRouteBuilder?
    private let watchConnectivity = WatchConnectivityManager.shared

    // Track whether we're building a route (outdoor sessions)
    private var isOutdoorSession: Bool = false
    // Track whether any route data was inserted (avoid finalizing empty routes)
    private var hasInsertedRouteData: Bool = false

    // Track activity type for watch motion mode mapping
    private var currentActivityType: HKWorkoutActivityType?

    // Mirroring handshake state machine
    private(set) var mirroringState: MirroringPipelineState = .idle

    // Whether the Watch owns the primary session (Watch-primary mode)
    private(set) var isWatchPrimary: Bool = false

    // The mirrored session's startDate (Watch's actual workout start time)
    private(set) var mirroredSessionStartDate: Date?

    // Watch's authoritative elapsed time (received at 1Hz via mirrored session)
    private(set) var watchElapsedTime: TimeInterval = 0
    private(set) var watchIsPaused: Bool = false

    // Tracked workout save task for ordered post-session pipeline
    private var workoutSaveTask: Task<HKWorkout?, Never>?

    /// Callback fired when a mirrored session arrives autonomously (Watch-initiated).
    /// SessionTracker wires this to create a DisciplinePlugin and start tracking.
    /// The Date parameter is the Watch's workout start time for elapsed time sync.
    var onAutonomousMirroredSession: ((HKWorkoutActivityType, Date) -> Void)?

    private override init() {
        super.init()
    }

    // MARK: - Watch-Primary Workout

    /// Request the Watch to start a primary workout session.
    /// Uses `HKHealthStore.startWatchApp(toHandle:)` to wake the Watch app and deliver
    /// the workout configuration via `handle(_ workoutConfiguration:)`.
    /// Watch creates its own HKWorkoutSession and mirrors it back to iPhone
    /// via `startMirroringToCompanionDevice()`.
    func requestWatchWorkout(configuration: HKWorkoutConfiguration) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            Log.health.warning("HealthKit not available")
            return
        }

        // End any existing session first
        if workoutSession != nil {
            await discard()
        }

        state = .preparing
        workoutSaveTask = nil
        isOutdoorSession = configuration.locationType == .outdoor
        self.currentActivityType = configuration.activityType
        isWatchPrimary = true

        // Mirroring handler is already registered at app launch via registerMirroringHandler().
        // No need to call setupMirroringHandler() here.

        // Create route builder for outdoor sessions (iPhone captures GPS)
        if isOutdoorSession {
            routeBuilder = createRouteBuilderIfAuthorized()
        }

        // Use startWatchApp to wake/launch the Watch app and deliver the configuration.
        // Watch receives it via handle(_ workoutConfiguration:) → startWorkoutFromiPhone().
        do {
            try await healthStore.startWatchApp(toHandle: configuration)
            updateMirroringState(.commandSent)
            Log.health.error("TT: startWatchApp succeeded — mirroring pipeline → commandSent")
        } catch {
            let errMsg = error.localizedDescription
            Log.health.error("TT: startWatchApp failed: \(errMsg, privacy: .public)")
            cleanup()
            throw error
        }

        // Persist context for crash recovery (only after startWatchApp succeeds)
        persistSessionContext(
            discipline: "\(configuration.activityType.rawValue)",
            startDate: Date()
        )
    }

    /// Register the mirroring handler at app launch so iPhone is always ready
    /// to receive mirrored sessions from Watch-autonomous workouts.
    func registerMirroringHandler() {
        setupMirroringHandler()
        Log.health.error("TT: mirroring handler registered at launch — ready to receive Watch sessions")
    }

    /// Set up handler to receive mirrored workout session from Watch.
    private func setupMirroringHandler() {
        healthStore.workoutSessionMirroringStartHandler = { [weak self] mirroredSession in
            guard let self else { return }
            Task { @MainActor in
                // Discard stale mirrored sessions from previous Watch workouts
                if let startDate = mirroredSession.startDate,
                   Date().timeIntervalSince(startDate) > 60 {
                    let age = Int(Date().timeIntervalSince(startDate))
                    Log.health.error("TT: ignoring stale mirrored session (started \(age)s ago)")
                    return
                }

                self.mirroringState = .mirroredSessionReceived
                Log.health.error("TT: mirroring pipeline → mirroredSessionReceived")

                self.workoutSession = mirroredSession
                mirroredSession.delegate = self
                // No builder or data source — builder runs on Watch only
                self.state = .active
                self.error = nil

                // Capture Watch's workout start time for elapsed time sync
                let watchStartDate = mirroredSession.startDate ?? Date()
                self.mirroredSessionStartDate = watchStartDate

                // If this session arrived without requestWatchWorkout() (autonomous Watch start),
                // configure state so pause/resume/endAndSave use the correct Watch-primary path.
                if !self.isWatchPrimary {
                    self.isWatchPrimary = true
                    let config = mirroredSession.workoutConfiguration
                    self.currentActivityType = config.activityType
                    self.isOutdoorSession = config.locationType == .outdoor

                    // Create route builder for outdoor activities (iPhone captures GPS)
                    if self.isOutdoorSession {
                        self.routeBuilder = self.createRouteBuilderIfAuthorized()
                    }

                    self.persistSessionContext(
                        discipline: "\(config.activityType.rawValue)",
                        startDate: watchStartDate
                    )

                    // Notify SessionTracker to create a plugin and start tracking
                    self.onAutonomousMirroredSession?(config.activityType, watchStartDate)

                    Log.health.info("WorkoutLifecycleService: configured Watch-primary state for autonomous workout")
                }

                Log.health.error("TT: received mirrored session from Watch — Watch-primary mode active")
            }
        }
    }

    // MARK: - Mirroring Pipeline State Updates

    /// Called by WatchConnectivityManager when ack/mirroring messages arrive from Watch.
    /// Forward-only: rejects transitions that would move backward in the pipeline
    /// (e.g., a late ACK arriving after mirroredSessionReceived).
    func updateMirroringState(_ newState: MirroringPipelineState) {
        let previous = mirroringState
        // Allow reset to idle (cleanup), but otherwise only advance forward
        guard newState == .idle || newState.order > previous.order else {
            Log.health.error("TT: mirroring pipeline REJECTED \(newState.rawValue, privacy: .public) — already at \(previous.rawValue, privacy: .public)")
            return
        }
        mirroringState = newState
        Log.health.error("TT: mirroring pipeline → \(newState.rawValue, privacy: .public) (was \(previous.rawValue, privacy: .public))")
    }

    // MARK: - Start Workout (iPhone-Primary)

    /// iPhone-only workout lifecycle for when Watch is unavailable.
    /// Creates HKWorkoutSession with prepare() + startActivity(), HKLiveWorkoutBuilder
    /// with HKLiveWorkoutDataSource for auto HR/calorie collection, and optionally
    /// an HKWorkoutRouteBuilder for outdoor sessions.
    func startWorkoutFallback(configuration: HKWorkoutConfiguration) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            Log.health.warning("HealthKit not available")
            return
        }

        // End any existing session first
        if workoutSession != nil {
            await discard()
        }

        state = .preparing
        workoutSaveTask = nil
        isOutdoorSession = configuration.locationType == .outdoor
        self.currentActivityType = configuration.activityType
        isWatchPrimary = false

        // Send session control commands to Watch (WCSession fallback path)
        watchConnectivity.sendReliableCommand(.startRide)
        watchConnectivity.startMotionTracking(mode: watchMotionMode)

        do {
            // Create workout session FIRST so it's available for Watch mirroring
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            session.delegate = self

            // Prepare session — makes it available for Watch mirroring
            session.prepare()

            // Create live workout builder with auto data collection
            let builder = session.associatedWorkoutBuilder()
            builder.delegate = self
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            // Start the activity
            let startDate = Date()
            session.startActivity(with: startDate)

            do {
                try await builder.beginCollection(at: startDate)
            } catch {
                session.end()
                state = .idle
                Log.health.error("Failed to begin workout collection: \(error)")
                throw error
            }

            // Create route builder for outdoor sessions
            var route: HKWorkoutRouteBuilder?
            if isOutdoorSession {
                route = createRouteBuilderIfAuthorized()
            }

            // Store references after successful setup
            self.workoutSession = session
            self.workoutBuilder = builder
            self.routeBuilder = route
            self.state = .active
            self.error = nil

            // Persist context for crash recovery (iOS 26+)
            persistSessionContext(
                discipline: "\(configuration.activityType.rawValue)",
                startDate: startDate
            )

            Log.health.info("WorkoutLifecycleService: started \(configuration.activityType.rawValue) workout (iPhone-only fallback)")

        } catch {
            state = .idle
            self.error = error.localizedDescription
            Log.health.error("WorkoutLifecycleService: failed to start workout: \(error)")
            throw error
        }
    }

    // MARK: - Route Data

    /// Create a route builder only if HealthKit write authorization for workoutRoute is granted.
    private func createRouteBuilderIfAuthorized() -> HKWorkoutRouteBuilder? {
        let routeType = HKSeriesType.workoutRoute()
        let status = healthStore.authorizationStatus(for: routeType)
        guard status == .sharingAuthorized else {
            Log.health.warning("WorkoutLifecycleService: skipping route builder — workoutRoute write not authorized (status: \(status.rawValue))")
            return nil
        }
        return HKWorkoutRouteBuilder(healthStore: healthStore, device: .local())
    }

    /// Add GPS locations incrementally during the session (outdoor sessions only).
    func addRouteData(_ locations: [CLLocation]) async {
        guard let routeBuilder = routeBuilder, isOutdoorSession, !locations.isEmpty else { return }

        do {
            try await routeBuilder.insertRouteData(locations)
            hasInsertedRouteData = true
        } catch {
            let hasSession = workoutSession != nil
            Log.health.error("WorkoutLifecycleService: failed to insert route data: \(error) — isWatchPrimary=\(self.isWatchPrimary), hasWorkoutSession=\(hasSession)")
        }
    }

    // MARK: - Add Samples

    /// Add custom HKQuantitySamples (e.g., gait-adjusted calories, stroke counts).
    func addSamples(_ samples: [HKSample]) async {
        guard let builder = workoutBuilder else { return }

        do {
            try await builder.addSamples(samples)
        } catch {
            Log.health.error("WorkoutLifecycleService: failed to add samples: \(error)")
        }
    }

    // MARK: - Add Workout Events

    /// Add workout events (e.g., lap markers, gait segments, interval markers).
    func addWorkoutEvents(_ events: [HKWorkoutEvent]) async {
        guard let builder = workoutBuilder, !events.isEmpty else { return }

        do {
            try await builder.addWorkoutEvents(events)
        } catch {
            Log.health.error("WorkoutLifecycleService: failed to add workout events: \(error)")
        }
    }

    // MARK: - Add Metadata

    /// Add metadata to the workout builder before ending the workout.
    func addMetadata(_ metadata: [String: Any]) async {
        guard let builder = workoutBuilder, !metadata.isEmpty else { return }

        do {
            try await builder.addMetadata(metadata)
        } catch {
            Log.health.error("WorkoutLifecycleService: failed to add metadata: \(error)")
        }
    }

    // MARK: - Disable Auto Calories

    /// Disable automatic calorie collection from the data source.
    /// Use when providing custom calorie samples (e.g., gait-adjusted calories for riding).
    func disableAutoCalories() {
        guard let builder = workoutBuilder,
              let dataSource = builder.dataSource else { return }

        dataSource.disableCollection(for: HKQuantityType(.activeEnergyBurned))
        Log.health.info("WorkoutLifecycleService: disabled auto calorie collection")
    }

    // MARK: - Pause / Resume

    func pause() {
        if isWatchPrimary {
            // In Watch-primary mode, send control command via mirrored session.
            // Watch pauses the session → delegate callback updates our state.
            sendControlCommand("pause")
            // Set state immediately for responsive UI; delegate will confirm.
            state = .paused
        } else {
            workoutSession?.pause()
            watchConnectivity.sendReliableCommand(.pauseRide)
            state = .paused
        }
    }

    func resume() {
        if isWatchPrimary {
            sendControlCommand("resume")
            state = .active
        } else {
            workoutSession?.resume()
            watchConnectivity.sendReliableCommand(.resumeRide)
            state = .active
        }
    }

    // MARK: - Mirrored Session Control Commands

    /// Send a control command to Watch via the mirrored workout session.
    func sendControlCommand(_ action: String) {
        guard let session = workoutSession else { return }
        guard session.state == .running || session.state == .paused else {
            let state = session.state.rawValue
            Log.health.warning("sendControlCommand: skipping '\(action)' — session state \(state)")
            return
        }

        let payload: [String: Any] = [
            "type": "control",
            "action": action
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        Task {
            do {
                try await session.sendToRemoteWorkoutSession(data: data)
            } catch {
                Log.health.error("WorkoutLifecycleService: failed to send control '\(action)': \(error)")
            }
        }
    }

    // MARK: - End and Save

    /// End the workout, finalize the route, and save. Returns the saved HKWorkout if successful.
    @discardableResult
    func endAndSave(metadata: [String: Any]? = nil) async -> HKWorkout? {
        if isWatchPrimary {
            return await endWatchPrimaryWorkout()
        } else {
            return await endIPhonePrimaryWorkout(metadata: metadata)
        }
    }

    /// End workout when Watch owns the primary session.
    /// iPhone only needs to send a stop command and attach the route.
    private func endWatchPrimaryWorkout() async -> HKWorkout? {
        state = .ending

        // Tell Watch to stop via mirrored session
        sendControlCommand("stop")

        // Attach route to the workout synced from Watch.
        // Watch saves the workout to HealthKit. After sync, iPhone can query it
        // and attach the GPS route captured on iPhone.
        if let routeBuilder, hasInsertedRouteData {
            let workout = await queryRecentWorkoutWithRetry()
            if let workout {
                do {
                    try await routeBuilder.finishRoute(with: workout, metadata: nil)
                    Log.health.info("WorkoutLifecycleService: route attached to Watch workout")
                } catch {
                    Log.health.error("WorkoutLifecycleService: failed to attach route to Watch workout: \(error)")
                }
            }
        }

        let workout = await queryRecentWorkoutWithRetry()
        cleanup()
        Log.health.info("WorkoutLifecycleService: Watch-primary workout ended")
        return workout
    }

    /// End workout when iPhone owns the primary session (fallback mode).
    private func endIPhonePrimaryWorkout(metadata: [String: Any]?) async -> HKWorkout? {
        // Stop watch session via WCSession (fallback path)
        watchConnectivity.stopMotionTracking()
        watchConnectivity.sendReliableCommand(.stopRide)

        guard let session = workoutSession,
              let builder = workoutBuilder else {
            cleanup()
            return nil
        }

        state = .ending
        var sessionEnded = false

        do {
            // Apply metadata before ending collection
            if let metadata, !metadata.isEmpty {
                try await builder.addMetadata(metadata)
            }

            // End data collection
            try await builder.endCollection(at: Date())

            // Finalize and save the workout
            let workout = try await builder.finishWorkout()

            // End session AFTER builder operations complete (Apple docs requirement)
            session.end()
            sessionEnded = true

            // Attach route if we have one
            if let routeBuilder = routeBuilder, hasInsertedRouteData, let workout = workout {
                do {
                    try await routeBuilder.finishRoute(with: workout, metadata: nil)
                    Log.health.info("WorkoutLifecycleService: route attached to workout")
                } catch {
                    Log.health.error("WorkoutLifecycleService: failed to attach route: \(error)")
                }
            }

            cleanup()
            Log.health.info("WorkoutLifecycleService: saved workout \(workout?.uuid.uuidString ?? "unknown")")
            return workout

        } catch {
            // End session even on failure to avoid orphaned sessions
            if !sessionEnded { session.end() }
            Log.health.error("WorkoutLifecycleService: failed to end workout: \(error)")
            cleanup()
            return nil
        }
    }

    /// Query HealthKit for the most recent workout (synced from Watch) with retry.
    private func queryRecentWorkoutWithRetry(maxRetries: Int = 3) async -> HKWorkout? {
        for attempt in 0..<maxRetries {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s delay between retries
            }

            let workout = await queryMostRecentWorkout()
            if workout != nil { return workout }
        }
        Log.health.warning("WorkoutLifecycleService: could not find Watch workout after \(maxRetries) retries")
        return nil
    }

    private func queryMostRecentWorkout() async -> HKWorkout? {
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-300), // Last 5 minutes
            end: nil,
            options: .strictStartDate
        )

        let descriptor = HKSampleQueryDescriptor<HKWorkout>(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )

        do {
            let results = try await descriptor.result(for: healthStore)
            return results.first
        } catch {
            Log.health.error("WorkoutLifecycleService: workout query failed: \(error)")
            return nil
        }
    }

    // MARK: - Begin End and Save (Non-Blocking)

    /// Start ending and saving the workout in a tracked Task.
    /// Non-blocking — call `awaitWorkoutSave()` later to get the result.
    func beginEndAndSave(metadata: [String: Any]? = nil, events: [HKWorkoutEvent]? = nil, samples: [HKSample]? = nil) {
        workoutSaveTask = Task {
            if let events, !events.isEmpty {
                await addWorkoutEvents(events)
            }
            if let samples, !samples.isEmpty {
                await addSamples(samples)
            }
            let workout = await endAndSave(metadata: metadata)
            sendIdleStateToWatch()
            return workout
        }
    }

    /// Await the tracked workout save Task. Returns the saved HKWorkout if successful.
    func awaitWorkoutSave() async -> HKWorkout? {
        guard let task = workoutSaveTask else { return nil }
        return await task.value
    }

    // MARK: - Discard

    /// Discard the workout without saving.
    func discard() async {
        if isWatchPrimary {
            // Tell Watch to stop — it will discard on its end
            sendControlCommand("stop")
        } else {
            watchConnectivity.stopMotionTracking()
            watchConnectivity.sendReliableCommand(.stopRide)

            guard let session = workoutSession else {
                cleanup()
                return
            }

            if let builder = workoutBuilder {
                try? await builder.endCollection(at: Date())
                builder.discardWorkout()
            }

            session.end()
        }

        cleanup()
        Log.health.info("WorkoutLifecycleService: discarded workout")
    }

    // MARK: - Mirrored Session Data Exchange

    /// Send a status update to the Watch via the mirrored workout session.
    func sendMirroredStatusUpdate(duration: TimeInterval, distance: Double, speed: Double, gait: String?) {
        guard let session = workoutSession else { return }

        let payload: [String: Any] = [
            "type": "statusUpdate",
            "duration": duration,
            "distance": distance,
            "speed": speed,
            "gait": gait ?? "Stationary"
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        Task {
            try? await session.sendToRemoteWorkoutSession(data: data)
        }
    }

    /// Send a haptic feedback request to the Watch via the mirrored session.
    func sendHapticToWatch(type: String) {
        guard let session = workoutSession else { return }

        let payload: [String: Any] = [
            "type": "haptic",
            "hapticType": type
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        Task {
            try? await session.sendToRemoteWorkoutSession(data: data)
        }
    }

    // MARK: - Send Idle State to Watch

    /// Send idle state to Watch to return UI to summary view.
    func sendIdleStateToWatch() {
        watchConnectivity.sendStatusUpdate(
            rideState: .idle,
            duration: 0,
            distance: 0,
            speed: 0,
            gait: "Stationary",
            heartRate: nil,
            heartRateZone: nil,
            averageHeartRate: nil,
            maxHeartRate: nil,
            horseName: nil,
            rideType: nil
        )
    }

    // MARK: - Crash Recovery (iOS 26+)

    /// Persist minimal session context so UI can be restored after crash recovery.
    func persistSessionContext(discipline: String, startDate: Date) {
        UserDefaults.standard.set(discipline, forKey: "activeWorkoutDiscipline")
        UserDefaults.standard.set(startDate.timeIntervalSince1970, forKey: "activeWorkoutStartDate")
    }

    /// Clear persisted session context after normal workout completion.
    func clearSessionContext() {
        UserDefaults.standard.removeObject(forKey: "activeWorkoutDiscipline")
        UserDefaults.standard.removeObject(forKey: "activeWorkoutStartDate")
    }

    /// Check for and recover an interrupted workout session on app launch.
    /// Returns the recovered session's discipline and start date, or nil if none found.
    @available(iOS 26.0, *)
    func recoverInterruptedWorkout() async -> (discipline: String, startDate: Date)? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }

        do {
            guard let session = try await healthStore.recoverActiveWorkoutSession() else {
                clearSessionContext()
                return nil
            }
            session.delegate = self

            let builder = session.associatedWorkoutBuilder()
            builder.delegate = self
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: session.workoutConfiguration
            )

            let config = session.workoutConfiguration
            isOutdoorSession = config.locationType == .outdoor
            if isOutdoorSession {
                routeBuilder = createRouteBuilderIfAuthorized()
            }

            self.workoutSession = session
            self.workoutBuilder = builder
            self.state = .active
            self.error = nil

            // Retrieve persisted context
            let discipline = UserDefaults.standard.string(forKey: "activeWorkoutDiscipline") ?? "unknown"
            let startTimestamp = UserDefaults.standard.double(forKey: "activeWorkoutStartDate")
            let startDate = startTimestamp > 0 ? Date(timeIntervalSince1970: startTimestamp) : Date()

            Log.health.info("WorkoutLifecycleService: recovered interrupted \(discipline) workout")
            return (discipline: discipline, startDate: startDate)

        } catch {
            // No recoverable session found — this is normal
            clearSessionContext()
            return nil
        }
    }

    // MARK: - Private

    private var watchMotionMode: WatchMotionModeShared {
        switch currentActivityType {
        case .equestrianSports: return .riding
        case .running: return .running
        case .walking: return .walking
        case .swimming: return .swimming
        default: return .shooting
        }
    }

    /// Update WatchConnectivityManager motion properties from mirrored session data.
    private func updateMotionFromMirroredData(_ dict: [String: Any]) {
        WatchConnectivityManager.shared.updateFromMirroredMotionDict(dict)
    }

    private func cleanup() {
        clearSessionContext()
        workoutSession = nil
        workoutBuilder = nil
        routeBuilder = nil
        // Note: workoutSaveTask is intentionally NOT nilled here —
        // awaitWorkoutSave() needs it after cleanup runs inside endAndSave().
        // It is nilled on the next requestWatchWorkout() or discard() call.
        isOutdoorSession = false
        hasInsertedRouteData = false
        isWatchPrimary = false
        mirroredSessionStartDate = nil
        watchElapsedTime = 0
        watchIsPaused = false
        currentActivityType = nil
        mirroringState = .idle
        state = .idle
        liveActiveCalories = 0
        liveDistance = 0
        liveHeartRate = 0
        liveStepCount = 0
        liveSwimmingStrokeCount = 0
        liveRunningSpeed = 0
        liveRunningPower = 0
        liveRunningStrideLength = 0
        liveGroundContactTime = 0
        liveVerticalOscillation = 0
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutLifecycleService: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            let isWP = self.isWatchPrimary
            switch toState {
            case .running:
                Log.health.error("TT: WorkoutLifecycleService session → running (isWatchPrimary=\(isWP, privacy: .public))")
                if self.isWatchPrimary {
                    self.state = .active
                }
            case .paused:
                Log.health.error("TT: WorkoutLifecycleService session → paused (isWatchPrimary=\(isWP, privacy: .public))")
                if self.isWatchPrimary {
                    self.state = .paused
                }
            case .ended:
                Log.health.error("TT: WorkoutLifecycleService session → ended (isWatchPrimary=\(isWP, privacy: .public))")
            default:
                break
            }
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            Log.health.error("WorkoutLifecycleService: session failed: \(error)")
            self.error = error.localizedDescription
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didDisconnectFromRemoteDeviceWithError error: (any Error)?
    ) {
        Task { @MainActor in
            if let error {
                Log.health.error("TT: mirrored session disconnected with error: \(error.localizedDescription, privacy: .public)")
            } else {
                Log.health.error("TT: mirrored session disconnected (no error)")
            }
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didReceiveDataFromRemoteWorkoutSession data: [Data]
    ) {
        // Handle data sent from Watch via sendToRemoteWorkoutSession
        for item in data {
            guard let payload = try? JSONSerialization.jsonObject(with: item) as? [String: Any],
                  let type = payload["type"] as? String else { continue }

            switch type {
            case "elapsedTime":
                // Watch's authoritative elapsed time (1Hz)
                guard let elapsed = payload["elapsed"] as? TimeInterval else { continue }
                let paused = payload["isPaused"] as? Bool ?? false
                Task { @MainActor in
                    self.watchElapsedTime = elapsed
                    self.watchIsPaused = paused
                }
            case "autoPauseEvent":
                // HealthKit auto-pause/resume event from Watch (informational)
                let paused = payload["paused"] as? Bool ?? false
                Log.health.info("WorkoutLifecycleService: Watch auto-pause event — paused=\(paused)")
            case "heartRate":
                // HR sent from Watch via mirrored session
                guard let bpm = payload["bpm"] as? Int, bpm > 0 else { continue }
                Log.health.info("WorkoutLifecycleService: received mirrored HR \(bpm) bpm from Watch")
                Task { @MainActor in
                    self.liveHeartRate = bpm
                    WatchConnectivityManager.shared.updateFromMirroredHeartRate(bpm)
                }
            case "motionData":
                // Decode motion metrics sent from Watch via mirrored session.
                // The JSON is a WatchMotionMetrics struct encoded on Watch.
                // We decode it as a dictionary and update WatchConnectivityManager
                // properties directly since the type isn't shared.
                guard let metricsString = payload["metricsJSON"] as? String,
                      let metricsData = metricsString.data(using: .utf8),
                      let metricsDict = try? JSONSerialization.jsonObject(with: metricsData) as? [String: Any] else {
                    Log.health.info("WorkoutLifecycleService: failed to decode mirrored motion data")
                    continue
                }
                Log.health.info("WorkoutLifecycleService: received mirrored motion data from Watch")
                Task { @MainActor in
                    self.updateMotionFromMirroredData(metricsDict)
                }
            case "builderStats":
                // HKLiveWorkoutBuilder stats forwarded from Watch
                Task { @MainActor in
                    if let v = payload["activeCalories"] as? Double { self.liveActiveCalories = v }
                    if let v = payload["distance"] as? Double { self.liveDistance = v }
                    if let v = payload["stepCount"] as? Int { self.liveStepCount = v }
                    if let v = payload["swimmingStrokeCount"] as? Int { self.liveSwimmingStrokeCount = v }
                    if let v = payload["runningSpeed"] as? Double { self.liveRunningSpeed = v }
                    if let v = payload["runningPower"] as? Double { self.liveRunningPower = v }
                    if let v = payload["runningStrideLength"] as? Double { self.liveRunningStrideLength = v }
                    if let v = payload["groundContactTime"] as? Double { self.liveGroundContactTime = v }
                    if let v = payload["verticalOscillation"] as? Double { self.liveVerticalOscillation = v }
                }
            case "gaitResult":
                // Decode Watch gait classification result
                guard let resultString = payload["resultJSON"] as? String,
                      let resultData = resultString.data(using: .utf8),
                      let result = try? JSONDecoder().decode(WatchGaitResult.self, from: resultData) else {
                    Log.health.info("WorkoutLifecycleService: failed to decode mirrored gait result")
                    continue
                }
                Log.health.info("WorkoutLifecycleService: received Watch gait result: \(result.gaitState)")
                Task { @MainActor in
                    WatchConnectivityManager.shared.updateFromWatchGaitResult(result)
                }
            default:
                break
            }
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutLifecycleService: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor in
            // Heart rate
            if let hrType = collectedTypes.first(where: { $0 == HKQuantityType(.heartRate) }) as? HKQuantityType,
               let stats = workoutBuilder.statistics(for: hrType),
               let mostRecent = stats.mostRecentQuantity() {
                self.liveHeartRate = Int(mostRecent.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
            }

            // Active calories
            if let calType = collectedTypes.first(where: { $0 == HKQuantityType(.activeEnergyBurned) }) as? HKQuantityType,
               let stats = workoutBuilder.statistics(for: calType) {
                self.liveActiveCalories = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
            }

            // Distance (walking/running)
            if let distType = collectedTypes.first(where: { $0 == HKQuantityType(.distanceWalkingRunning) }) as? HKQuantityType,
               let stats = workoutBuilder.statistics(for: distType) {
                self.liveDistance = stats.sumQuantity()?.doubleValue(for: .meter()) ?? 0
            }

            // Distance (swimming)
            if let swimDistType = collectedTypes.first(where: { $0 == HKQuantityType(.distanceSwimming) }) as? HKQuantityType,
               let stats = workoutBuilder.statistics(for: swimDistType) {
                self.liveDistance = stats.sumQuantity()?.doubleValue(for: .meter()) ?? 0
            }

            // Step count
            if let stepType = collectedTypes.first(where: { $0 == HKQuantityType(.stepCount) }) as? HKQuantityType,
               let stats = workoutBuilder.statistics(for: stepType) {
                self.liveStepCount = Int(stats.sumQuantity()?.doubleValue(for: .count()) ?? 0)
            }

            // Swimming stroke count
            if let strokeType = collectedTypes.first(where: { $0 == HKQuantityType(.swimmingStrokeCount) }) as? HKQuantityType,
               let stats = workoutBuilder.statistics(for: strokeType) {
                self.liveSwimmingStrokeCount = Int(stats.sumQuantity()?.doubleValue(for: .count()) ?? 0)
            }

            // Running speed
            if let speedType = collectedTypes.first(where: { $0 == HKQuantityType(.runningSpeed) }) as? HKQuantityType,
               let stats = workoutBuilder.statistics(for: speedType),
               let avg = stats.averageQuantity() {
                self.liveRunningSpeed = avg.doubleValue(for: HKUnit.meter().unitDivided(by: .second()))
            }

            // Running power
            if let powerType = collectedTypes.first(where: { $0 == HKQuantityType(.runningPower) }) as? HKQuantityType,
               let stats = workoutBuilder.statistics(for: powerType),
               let avg = stats.averageQuantity() {
                self.liveRunningPower = avg.doubleValue(for: .watt())
            }

            // Running stride length
            if let strideType = collectedTypes.first(where: { $0 == HKQuantityType(.runningStrideLength) }) as? HKQuantityType,
               let stats = workoutBuilder.statistics(for: strideType),
               let avg = stats.averageQuantity() {
                self.liveRunningStrideLength = avg.doubleValue(for: .meter())
            }

            // Ground contact time
            if let gctType = collectedTypes.first(where: { $0 == HKQuantityType(.runningGroundContactTime) }) as? HKQuantityType,
               let stats = workoutBuilder.statistics(for: gctType),
               let avg = stats.averageQuantity() {
                self.liveGroundContactTime = avg.doubleValue(for: .secondUnit(with: .milli))
            }

            // Vertical oscillation
            if let oscType = collectedTypes.first(where: { $0 == HKQuantityType(.runningVerticalOscillation) }) as? HKQuantityType,
               let stats = workoutBuilder.statistics(for: oscType),
               let avg = stats.averageQuantity() {
                self.liveVerticalOscillation = avg.doubleValue(for: HKUnit.meterUnit(with: .centi))
            }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Workout events (e.g., lap markers) - can be extended per discipline
    }
}
