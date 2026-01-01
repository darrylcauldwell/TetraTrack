//
//  TetraTrackWatchApp.swift
//  TetraTrack Watch App
//
//  Watch app entry point
//

import SwiftUI
import HealthKit

@main
struct TetraTrackWatchApp: App {
    @State private var workoutManager = WorkoutManager.shared
    @State private var connectivityService = WatchConnectivityService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(workoutManager)
                .environment(connectivityService)
                .onAppear {
                    connectivityService.activate()
                    workoutManager.setupMirroringHandler()
                }
        }
    }
}
