//
//  TetraTrackWatchApp.swift
//  TetraTrack Watch App
//
//  Watch app entry point
//

import SwiftUI
import HealthKit
import WatchKit
import os

// MARK: - WKApplicationDelegate

/// Handles iPhone-triggered workout sessions via healthStore.startWatchApp().
/// When iPhone calls startWatchApp(toHandle:), watchOS delivers the configuration here.
class TetraTrackWatchDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Log.tracking.info("WKApplicationDelegate: received workout config — activity=\(workoutConfiguration.activityType.rawValue), location=\(workoutConfiguration.locationType.rawValue)")
        Task { @MainActor in
            Log.tracking.info("WKApplicationDelegate: dispatching to WorkoutManager.startWorkoutFromiPhone()")
            await WorkoutManager.shared.startWorkoutFromiPhone(configuration: workoutConfiguration)
            Log.tracking.info("WKApplicationDelegate: startWorkoutFromiPhone() completed, isActive=\(WorkoutManager.shared.isWorkoutActive)")
        }
    }

    func handleActiveWorkoutRecovery() {
        Log.tracking.info("WKApplicationDelegate: recovering active workout after crash")
        Task { @MainActor in
            await WorkoutManager.shared.recoverActiveWorkout()
        }
    }
}

// MARK: - App

@main
struct TetraTrackWatchApp: App {
    @WKApplicationDelegateAdaptor(TetraTrackWatchDelegate.self) var delegate

    @State private var workoutManager = WorkoutManager.shared
    @State private var connectivityService = WatchConnectivityService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(workoutManager)
                .environment(connectivityService)
                .onAppear {
                    connectivityService.activate()
                    // Legacy mirroring handler for backward compatibility
                    workoutManager.setupLegacyMirroringHandler()
                }
        }
    }
}
