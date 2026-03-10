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

    // Internal HealthKit objects
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var routeBuilder: HKWorkoutRouteBuilder?
    private let watchConnectivity = WatchConnectivityManager.shared

    // Track whether we're building a route (outdoor sessions)
    private var isOutdoorSession: Bool = false

    // Track activity type for watch motion mode mapping
    private var currentActivityType: HKWorkoutActivityType?

    // Tracked workout save task for ordered post-session pipeline
    private var workoutSaveTask: Task<HKWorkout?, Never>?

    private override init() {
        super.init()
    }

    // MARK: - Start Workout

    /// Start a full workout lifecycle with the given configuration.
    /// Creates HKWorkoutSession with prepare() + startActivity(), HKLiveWorkoutBuilder
    /// with HKLiveWorkoutDataSource for auto HR/calorie collection, and optionally
    /// an HKWorkoutRouteBuilder for outdoor sessions.
    ///
    /// On iOS 26+, HKWorkoutSession runs as a full standalone session on iPhone,
    /// providing live HR collection from connected BLE heart rate monitors even
    /// without Apple Watch. On iOS 17-25, live HR requires Watch mirroring or
    /// companion mode via WatchConnectivity.
    func startWorkout(configuration: HKWorkoutConfiguration) async throws {
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

        // Send session control commands to Watch before HealthKit setup
        // so the Watch transitions even if HealthKit fails
        self.currentActivityType = configuration.activityType
        watchConnectivity.sendCommand(.startRide)
        watchConnectivity.startMotionTracking(mode: watchMotionMode)

        do {
            // Create workout session
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            session.delegate = self

            // Prepare session — makes it available for Watch mirroring via
            // HKHealthStore.workoutSessionMirroredFromCompanionDevice() on watchOS
            session.prepare()

            // Create live workout builder with auto data collection
            let builder = session.associatedWorkoutBuilder()
            builder.delegate = self
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            // Start the activity
            session.startActivity(with: Date())

            do {
                try await builder.beginCollection(at: Date())
            } catch {
                session.end()
                state = .idle
                Log.health.error("Failed to begin workout collection: \(error)")
                throw error
            }

            // Create route builder for outdoor sessions
            var route: HKWorkoutRouteBuilder?
            if isOutdoorSession {
                route = HKWorkoutRouteBuilder(healthStore: healthStore, device: .local())
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
                startDate: Date()
            )

            Log.health.info("WorkoutLifecycleService: started \(configuration.activityType.rawValue) workout")

        } catch {
            state = .idle
            self.error = error.localizedDescription
            Log.health.error("WorkoutLifecycleService: failed to start workout: \(error)")
            throw error
        }
    }

    // MARK: - Route Data

    /// Add GPS locations incrementally during the session (outdoor sessions only).
    func addRouteData(_ locations: [CLLocation]) async {
        guard let routeBuilder = routeBuilder, isOutdoorSession, !locations.isEmpty else { return }

        do {
            try await routeBuilder.insertRouteData(locations)
        } catch {
            Log.health.error("WorkoutLifecycleService: failed to insert route data: \(error)")
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
        state = .paused
        watchConnectivity.sendCommand(.pauseRide)
    }

    func resume() {
        workoutSession?.resume()
        state = .active
        watchConnectivity.sendCommand(.resumeRide)
    }

    // MARK: - End and Save

    /// End the workout, finalize the route, and save. Returns the saved HKWorkout if successful.
    @discardableResult
    func endAndSave(metadata: [String: Any]? = nil) async -> HKWorkout? {
        // Stop watch session (always, even if HealthKit session is nil)
        watchConnectivity.stopMotionTracking()
        watchConnectivity.sendCommand(.stopRide)

        guard let session = workoutSession,
              let builder = workoutBuilder else {
            cleanup()
            return nil
        }

        state = .ending

        // End the session
        session.end()

        do {
            // Apply metadata before ending collection
            if let metadata, !metadata.isEmpty {
                try await builder.addMetadata(metadata)
            }

            // End data collection
            try await builder.endCollection(at: Date())

            // Finalize and save the workout
            let workout = try await builder.finishWorkout()

            // Attach route if we have one
            if let routeBuilder = routeBuilder, let workout = workout {
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
        // Stop watch session (always, even if HealthKit session is nil)
        watchConnectivity.stopMotionTracking()
        watchConnectivity.sendCommand(.stopRide)

        guard let session = workoutSession else {
            cleanup()
            return
        }

        session.end()

        if let builder = workoutBuilder {
            builder.discardWorkout()
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
                routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: .local())
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
        case .running, .walking: return .running
        case .swimming: return .swimming
        default: return .shooting
        }
    }

    private func cleanup() {
        clearSessionContext()
        workoutSession = nil
        workoutBuilder = nil
        routeBuilder = nil
        // Note: workoutSaveTask is intentionally NOT nilled here —
        // awaitWorkoutSave() needs it after cleanup runs inside endAndSave().
        // It is nilled on the next startWorkout() or discard() call.
        isOutdoorSession = false
        currentActivityType = nil
        state = .idle
        liveActiveCalories = 0
        liveDistance = 0
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
            case .running:
                Log.health.debug("WorkoutLifecycleService: session running")
            case .paused:
                Log.health.debug("WorkoutLifecycleService: session paused")
            case .ended:
                Log.health.debug("WorkoutLifecycleService: session ended")
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
        didReceiveDataFromRemoteWorkoutSession data: [Data]
    ) {
        // Handle data sent from Watch via sendToRemoteWorkoutSession
        for item in data {
            guard let payload = try? JSONSerialization.jsonObject(with: item) as? [String: Any],
                  let type = payload["type"] as? String else { continue }

            switch type {
            case "sensorData":
                // Watch sensor data (motion, altitude, etc.) — can be extended per discipline
                break
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
            // Extract live statistics from the builder
            if let calType = collectedTypes.first(where: { $0 == HKQuantityType(.activeEnergyBurned) }) as? HKQuantityType {
                if let stats = workoutBuilder.statistics(for: calType) {
                    self.liveActiveCalories = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                }
            }

            // Distance (walking/running)
            if let distType = collectedTypes.first(where: { $0 == HKQuantityType(.distanceWalkingRunning) }) as? HKQuantityType {
                if let stats = workoutBuilder.statistics(for: distType) {
                    self.liveDistance = stats.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                }
            }

            // Distance (swimming)
            if let swimDistType = collectedTypes.first(where: { $0 == HKQuantityType(.distanceSwimming) }) as? HKQuantityType {
                if let stats = workoutBuilder.statistics(for: swimDistType) {
                    self.liveDistance = stats.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                }
            }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Workout events (e.g., lap markers) - can be extended per discipline
    }
}
