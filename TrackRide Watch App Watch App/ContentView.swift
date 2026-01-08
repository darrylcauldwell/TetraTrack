//
//  ContentView.swift
//  TrackRide Watch App
//
//  Main watch app view - routes to discipline-specific views
//

import SwiftUI

struct ContentView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(WatchConnectivityService.self) private var connectivityService
    @State private var fallDetectionManager = WatchFallDetectionManager.shared

    var body: some View {
        ZStack {
            Group {
                switch connectivityService.activeDiscipline {
                case .swimming:
                    SwimmingControlView()
                case .running:
                    RunningControlView()
                case .riding:
                    RideControlView()
                case .idle:
                    // Show idle/ready state with ride controls
                    RideControlView()
                }
            }
            .id(connectivityService.activeDiscipline)  // Force view refresh on discipline change

            // Fall detection alert overlay
            if fallDetectionManager.fallDetected {
                WatchFallAlertView(fallManager: fallDetectionManager)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: fallDetectionManager.fallDetected)
    }
}

#Preview {
    ContentView()
        .environment(WorkoutManager())
        .environment(WatchConnectivityService.shared)
}
