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
        WatchConnectivityService.sendDiagnostic("handle() called — activity=\(workoutConfiguration.activityType.rawValue)")
        Task { @MainActor in
            Log.tracking.info("WKApplicationDelegate: dispatching to WorkoutManager.startWorkoutFromiPhone()")
            await WorkoutManager.shared.startWorkoutFromiPhone(configuration: workoutConfiguration)
            let isActive = WorkoutManager.shared.isWorkoutActive
            Log.tracking.info("WKApplicationDelegate: startWorkoutFromiPhone() completed, isActive=\(isActive)")
            WatchConnectivityService.sendDiagnostic("startWorkoutFromiPhone() done — isActive=\(isActive)")
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
                    // Send diagnostic breadcrumb confirming Watch app launched
                    WatchConnectivityService.sendDiagnostic("Watch app launched, build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?")")
                    // Legacy mirroring handler for backward compatibility
                    workoutManager.setupLegacyMirroringHandler()
                }
        }
    }
}
