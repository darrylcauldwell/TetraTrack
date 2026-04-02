//
//  ContentView.swift
//  TetraTrack Watch App
//
//  Five discipline pages — swipe vertically to choose, tap to start.
//  When a workout is active, shows the discipline-specific control view.
//

import SwiftUI

struct ContentView: View {
    @Environment(WatchConnectivityService.self) private var connectivityService
    @State private var workoutManager = WorkoutManager.shared
    @State private var fallDetectionManager = WatchFallDetectionManager.shared
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack {
            if workoutManager.isWorkoutActive {
                // Active workout — show discipline control view
                activeWorkoutView
            } else {
                // Idle — five discipline pages
                TabView(selection: $selectedTab) {
                    ridingPage.tag(0)
                    runningPage.tag(1)
                    swimmingPage.tag(2)
                    walkingPage.tag(3)
                    shootingPage.tag(4)
                }
                .tabViewStyle(.verticalPage)
            }

            // Fall detection alert overlay
            if fallDetectionManager.fallDetected {
                WatchFallAlertView(fallManager: fallDetectionManager)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: fallDetectionManager.fallDetected)
        .animation(.easeInOut(duration: 0.3), value: workoutManager.isWorkoutActive)
    }

    // MARK: - Active Workout View

    @ViewBuilder
    private var activeWorkoutView: some View {
        switch workoutManager.activityType {
        case .riding:
            RideControlView()
        case .running:
            RunControlView()
        case .walking:
            WalkControlView()
        case .swimming:
            SwimControlView()
        case .shooting:
            ShootingControlView()
        case .none:
            ProgressView("Starting...")
        }
    }

    // MARK: - Discipline Pages

    private var ridingPage: some View {
        NavigationStack {
            RideTypePickerView()
        }
    }

    private var runningPage: some View {
        NavigationStack {
            RunControlView()
        }
    }

    private var swimmingPage: some View {
        NavigationStack {
            SwimControlView()
        }
    }

    private var walkingPage: some View {
        NavigationStack {
            WalkControlView()
        }
    }

    private var shootingPage: some View {
        NavigationStack {
            ShootingControlView()
        }
    }
}

#Preview {
    ContentView()
        .environment(WatchConnectivityService.shared)
}
