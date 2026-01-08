//
//  LiveWorkoutManager.swift
//  TrackRide
//
//  Manages live workout signaling to Watch for auto-launching Watch app
//

import HealthKit
import Combine
import os

@MainActor
final class LiveWorkoutManager: NSObject, ObservableObject {
    static let shared = LiveWorkoutManager()

    private let healthStore = HKHealthStore()
    private let watchConnectivity = WatchConnectivityManager.shared

    @Published var isWorkoutActive: Bool = false

    private override init() {
        super.init()
    }

    // MARK: - Start Workout (signals Watch to start and bring app to foreground)

    func startWorkout(activityType: HKWorkoutActivityType = .equestrianSports) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            Log.health.warning("HealthKit not available")
            return
        }

        // Send command to Watch to start workout - this will bring the Watch app to foreground
        // if it's running, or wake it up if the user has relevant settings enabled
        watchConnectivity.sendCommand(.startRide)

        isWorkoutActive = true
        Log.health.info("Signaled Watch to start workout")
    }

    // MARK: - Pause/Resume

    func pauseWorkout() {
        watchConnectivity.sendCommand(.pauseRide)
    }

    func resumeWorkout() {
        watchConnectivity.sendCommand(.resumeRide)
    }

    // MARK: - End Workout

    func endWorkout() async {
        watchConnectivity.sendCommand(.stopRide)
        isWorkoutActive = false
        Log.health.info("Signaled Watch to end workout")
    }

    // MARK: - Discard Workout

    func discardWorkout() async {
        watchConnectivity.sendCommand(.stopRide)
        isWorkoutActive = false
        Log.health.info("Signaled Watch to discard workout")
    }
}
