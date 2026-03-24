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

    // Tracked workout save task for ordered post-session pipeline
    private var workoutSaveTask: Task<HKWorkout?, Never>?

    // Continuation for waiting on session .stopped state (WWDC 2025 lifecycle requirement)
    private var stoppedContinuation: CheckedContinuation<Void, Never>?

    private override init() {
        super.init()
    }

    // MARK: - Wake Watch

    /// Wake the Watch app to start HR sensor collection.
    /// Fire-and-forget — no mirroring, no timeout. Watch starts its own
    /// HKWorkoutSession for HR and sends data via WCSession.
    func wakeWatch(configuration: HKWorkoutConfiguration) async throws {
        try await healthStore.startWatchApp(toHandle: configuration)
        Log.health.info("TT: startWatchApp succeeded — Watch will provide HR/motion via WCSession")
    }

    // MARK: - Start Workout (iPhone-Primary)

    /// iPhone-only workout lifecycle for when Watch is unavailable.
    /// Creates HKWorkoutSession with prepare() + startActivity(), HKLiveWorkoutBuilder
    /// with HKLiveWorkoutDataSource for auto HR/calorie collection, and optionally
    /// an HKWorkoutRouteBuilder for outdoor sessions.
    /// Start an iPhone-primary workout session (no Watch mirroring).
    /// - Parameter skipWatchCommands: When true, don't send .startRide/motionTracking to Watch
    ///   (Watch already has a session from handle() when mirroring failed).
    func startWorkoutFallback(configuration: HKWorkoutConfiguration, skipWatchCommands: Bool = false) async throws {
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

        // Send session control commands to Watch (only when Watch doesn't already have a session)
        if !skipWatchCommands {
            watchConnectivity.sendReliableCommand(.startRide)
            watchConnectivity.startMotionTracking(mode: watchMotionMode)
        }

        do {
            // Create workout session
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            session.delegate = self

            // Prepare session — allows sensors and external HR monitors to connect
            session.prepare()

            // Create live workout builder with auto data collection
            let builder = session.associatedWorkoutBuilder()
            builder.delegate = self
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            // 3-second countdown for sensor connection (WWDC 2025 recommendation)
            try await Task.sleep(nanoseconds: 3_000_000_000)

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
            Log.health.error("WorkoutLifecycleService: failed to insert route data: \(error) — hasWorkoutSession=\(hasSession)")
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
        workoutSession?.pause()
        watchConnectivity.sendReliableCommand(.pauseRide)
        state = .paused
    }

    func resume() {
        workoutSession?.resume()
        watchConnectivity.sendReliableCommand(.resumeRide)
        state = .active
    }

    // MARK: - End and Save

    /// End the workout, finalize the route, and save. Returns the saved HKWorkout if successful.
    @discardableResult
    func endAndSave(metadata: [String: Any]? = nil) async -> HKWorkout? {
        return await endIPhonePrimaryWorkout(metadata: metadata)
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

            // Stop activity — initiates async transition to .stopped (WWDC 2025 requirement)
            session.stopActivity(with: Date())

            // Wait for session delegate to report .stopped before ending collection
            if state != .ending {
                await withCheckedContinuation { continuation in
                    self.stoppedContinuation = continuation
                }
            }

            // End data collection after session has fully stopped
            let endDate = Date()
            try await builder.endCollection(at: endDate)

            // Finalize and save the workout
            let workout = try await builder.finishWorkout()

            // Attach route BEFORE ending session (route needs active session context)
            if let routeBuilder = routeBuilder, hasInsertedRouteData, let workout = workout {
                do {
                    try await routeBuilder.finishRoute(with: workout, metadata: nil)
                    Log.health.info("WorkoutLifecycleService: route attached to workout")
                } catch {
                    Log.health.error("WorkoutLifecycleService: failed to attach route: \(error)")
                }
            }

            // End session AFTER all builder and route operations complete
            session.end()
            sessionEnded = true

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
        watchConnectivity.stopMotionTracking()
        watchConnectivity.sendReliableCommand(.stopRide)

        guard let session = workoutSession else {
            cleanup()
            return
        }

        session.stopActivity(with: Date())

        // Wait for .stopped state before ending collection
        if state != .ending {
            await withCheckedContinuation { continuation in
                self.stoppedContinuation = continuation
            }
        }

        if let builder = workoutBuilder {
            try? await builder.endCollection(at: Date())
            builder.discardWorkout()
        }

        session.end()

        cleanup()
        Log.health.info("WorkoutLifecycleService: discarded workout")
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

    /// Update WatchConnectivityManager motion properties from data dict.
    private func updateMotionData(_ dict: [String: Any]) {
        WatchConnectivityManager.shared.updateFromMirroredMotionDict(dict)
    }

    private func cleanup() {
        clearSessionContext()
        // Resume any pending stopped continuation to prevent leaks
        stoppedContinuation?.resume()
        stoppedContinuation = nil
        workoutSession = nil
        workoutBuilder = nil
        routeBuilder = nil
        // Note: workoutSaveTask is intentionally NOT nilled here —
        // awaitWorkoutSave() needs it after cleanup runs inside endAndSave().
        // It is nilled on the next startWorkoutFallback() or discard() call.
        isOutdoorSession = false
        hasInsertedRouteData = false
        currentActivityType = nil
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
            switch toState {
            case .prepared:
                Log.health.error("TT: WorkoutLifecycleService session → prepared")
            case .running:
                Log.health.error("TT: WorkoutLifecycleService session → running")
                self.state = .active
            case .paused:
                Log.health.error("TT: WorkoutLifecycleService session → paused")
                self.state = .paused
            case .stopped:
                Log.health.error("TT: WorkoutLifecycleService session → stopped")
                self.state = .ending
                // Resume any code waiting for .stopped transition (WWDC 2025 end sequence)
                self.stoppedContinuation?.resume()
                self.stoppedContinuation = nil
            case .ended:
                Log.health.error("TT: WorkoutLifecycleService session → ended")
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
                let bpm = Int(mostRecent.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
                self.liveHeartRate = bpm
                WatchConnectivityManager.shared.updateHeartRate(bpm)
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
