//
//  ContentView.swift
//  TetraTrack Watch App
//
//  Main watch app view - Glanceable insights dashboard with autonomous session support
//

import SwiftUI

struct ContentView: View {
    @Environment(WatchConnectivityService.self) private var connectivityService
    @State private var workoutManager = WorkoutManager.shared
    @State private var fallDetectionManager = WatchFallDetectionManager.shared
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack {
            // Show discipline-specific view when workout is running
            if workoutManager.isWorkoutActive && !workoutManager.isCompanionMode {
                switch workoutManager.activityType {
                case .riding:
                    RideControlView()
                case .running, .walking:
                    RunningControlView()
                case .swimming:
                    SwimControlView()
                case .shooting:
                    ShootingControlView()
                case .none:
                    EmptyView()
                }
            } else if connectivityService.hasActiveSession {
                // iPhone is driving the session — show companion summary
                WatchHomeView()
            } else {
                // Main dashboard with tabbed pages
                TabView(selection: $selectedTab) {
                    // Page 0: Start Session (autonomous)
                    WatchStartSessionView()
                        .tag(0)

                    // Page 1: Home/Summary
                    WatchHomeView()
                        .tag(1)

                    // Page 2: Recent sessions
                    WatchInsightsView()
                        .tag(2)

                    // Page 3: Trends
                    WatchTrendsView()
                        .tag(3)

                    // Page 4: Workload
                    WatchWorkloadView()
                        .tag(4)
                }
                .tabViewStyle(.verticalPage)
            }

            // Fall detection alert overlay (kept for safety)
            if fallDetectionManager.fallDetected {
                WatchFallAlertView(fallManager: fallDetectionManager)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: fallDetectionManager.fallDetected)
        .animation(.easeInOut(duration: 0.3), value: workoutManager.isWorkoutActive)
        .animation(.easeInOut(duration: 0.3), value: connectivityService.hasActiveSession)
    }

}

#Preview {
    ContentView()
        .environment(WatchConnectivityService.shared)
}
