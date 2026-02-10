//
//  LiveWorkoutManager.swift
//  TetraTrack
//
//  Manages live workout sessions with Watch mirroring for auto-launching Watch app
//
//  When a workout is started on iPhone, this uses HKWorkoutSession mirroring
//  to signal the Watch. The Watch receives a "Workout in Progress" notification
//  that users can tap to open the app directly to the active session view.
//

import HealthKit
import Combine
import os

@MainActor
final class LiveWorkoutManager: NSObject, ObservableObject {
    static let shared = LiveWorkoutManager()

    private let healthStore = HKHealthStore()
    private let watchConnectivity = WatchConnectivityManager.shared

    // Workout session for mirroring to Watch
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    @Published var isWorkoutActive: Bool = false
    @Published var workoutError: String?

    private override init() {
        super.init()
    }

    // MARK: - Authorization

    /// Request HealthKit authorization for workout sessions
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            return false
        }

        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned)
        ]

        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            return true
        } catch {
            Log.health.error("HealthKit authorization failed: \(error)")
            return false
        }
    }

    // MARK: - Start Workout (with Watch Mirroring)

    /// Start a workout session that mirrors to Apple Watch
    /// This will show a "Workout in Progress" notification on the Watch
    /// that users can tap to open the app directly to the active session view
    func startWorkout(activityType: HKWorkoutActivityType = .equestrianSports) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            Log.health.warning("HealthKit not available")
            return
        }

        // End any existing session first
        if workoutSession != nil {
            await endWorkout()
        }

        // Create workout configuration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .outdoor

        do {
            // Create workout session
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            session.delegate = self

            // Create live workout builder for data collection
            let builder = session.associatedWorkoutBuilder()
            builder.delegate = self
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            // Start the workout session - this triggers Watch mirroring
            // The Watch will receive a notification that can launch the app
            session.startActivity(with: Date())

            do {
                try await builder.beginCollection(at: Date())
            } catch {
                // Clean up session if collection fails to start
                session.end()
                Log.health.error("Failed to begin workout collection: \(error)")
                throw error
            }

            // Only store session/builder after successful setup
            self.workoutSession = session
            self.workoutBuilder = builder

            // Also send WatchConnectivity message as backup
            // This updates the Watch app state even if the user doesn't tap the notification
            watchConnectivity.sendCommand(.startRide)

            isWorkoutActive = true
            workoutError = nil
            Log.health.info("Started workout session with Watch mirroring")

        } catch {
            Log.health.error("Failed to start workout session: \(error)")
            workoutError = error.localizedDescription

            // Clean up any partial state
            workoutSession = nil
            workoutBuilder = nil

            // Fall back to just sending command via WatchConnectivity
            watchConnectivity.sendCommand(.startRide)
            isWorkoutActive = true
        }
    }

    // MARK: - Pause/Resume

    func pauseWorkout() {
        workoutSession?.pause()
        watchConnectivity.sendCommand(.pauseRide)
    }

    func resumeWorkout() {
        workoutSession?.resume()
        watchConnectivity.sendCommand(.resumeRide)
    }

    // MARK: - End Workout

    func endWorkout() async {
        guard let session = workoutSession,
              let builder = workoutBuilder else {
            // Just send idle state if no active session
            sendIdleStateToWatch()
            isWorkoutActive = false
            return
        }

        // End the workout session
        session.end()

        // End data collection and save
        do {
            try await builder.endCollection(at: Date())
            // Note: We don't call finishWorkout() here because the main
            // HealthKitManager.saveRideAsWorkout() handles saving the complete
            // workout with all ride data
        } catch {
            Log.health.error("Failed to end workout collection: \(error)")
        }

        // Send idle state to Watch - this updates rideState and triggers UI to return to summary
        sendIdleStateToWatch()

        // Clean up
        workoutSession = nil
        workoutBuilder = nil
        isWorkoutActive = false

        Log.health.info("Ended workout session")
    }

    /// Send idle state to Watch to return UI to summary view
    private func sendIdleStateToWatch() {
        // Send status update with idle state - Watch will update rideState and UI
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

    // MARK: - Discard Workout

    func discardWorkout() async {
        workoutSession?.end()

        // Discard builder data (don't save)
        if let builder = workoutBuilder {
            builder.discardWorkout()
        }

        // Send idle state to Watch to return UI to summary view
        sendIdleStateToWatch()

        workoutSession = nil
        workoutBuilder = nil
        isWorkoutActive = false

        Log.health.info("Discarded workout session")
    }
}

// MARK: - HKWorkoutSessionDelegate

extension LiveWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            switch toState {
            case .running:
                Log.health.debug("Workout session running")
            case .paused:
                Log.health.debug("Workout session paused")
            case .ended:
                Log.health.debug("Workout session ended")
                self.isWorkoutActive = false
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
            Log.health.error("Workout session failed: \(error)")
            self.workoutError = error.localizedDescription
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension LiveWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        // Data collected - we could forward heart rate, etc. here if needed
        // But the Watch has its own heart rate monitoring
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Workout events (e.g., lap markers) - not used for riding
    }
}
