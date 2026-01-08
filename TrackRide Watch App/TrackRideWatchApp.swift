//
//  TrackRideWatchApp.swift
//  TrackRide Watch App
//
//  Watch app entry point
//

import SwiftUI

@main
struct TrackRideWatchApp: App {
    @State private var workoutManager = WorkoutManager()
    @State private var connectivityService = WatchConnectivityService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(workoutManager)
                .environment(connectivityService)
                .onAppear {
                    connectivityService.activate()
                }
        }
    }
}
