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
/// Matches Apple's MirroringWorkoutsSample reference: NO applicationDidFinishLaunching(),
/// handle() resets then starts, WCSession activation happens in onAppear.
class TetraTrackWatchDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        let activityRaw = workoutConfiguration.activityType.rawValue
        let locationRaw = workoutConfiguration.locationType.rawValue
        Log.tracking.error("TT: handle() called — activity=\(activityRaw, privacy: .public), location=\(locationRaw, privacy: .public)")
        WatchConnectivityService.sendDiagnostic("handle() called — activity=\(activityRaw)")
        Task {
            do {
                WorkoutManager.shared.resetWorkout()
                try await WorkoutManager.shared.startWorkoutFromiPhone(configuration: workoutConfiguration)
                Log.tracking.error("TT: handle() — workout started successfully")
                WatchConnectivityService.sendDiagnostic("handle() — workout started successfully")
            } catch {
                let errMsg = error.localizedDescription
                Log.tracking.error("TT: handle() — failed: \(errMsg, privacy: .public)")
                WatchConnectivityService.sendDiagnostic("handle() — FAILED: \(errMsg)")
            }
        }
    }

    func handleActiveWorkoutRecovery() {
        Log.tracking.error("TT: recovering active workout after crash")
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
                    // Activate WCSession here — Apple's reference has no applicationDidFinishLaunching()
                    WatchConnectivityService.shared.activate()
                    // Request HealthKit auth at launch, not during workout startup
                    Task { _ = await WorkoutManager.shared.requestAuthorization() }
                    WatchConnectivityService.sendDiagnostic("Watch app launched, build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?")")
                }
        }
    }
}
