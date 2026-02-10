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
            // Show active session view when workout is running
            if workoutManager.isWorkoutActive {
                activeWorkoutView
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
    }

    // MARK: - Active Workout View

    private var activeWorkoutView: some View {
        VStack(spacing: 6) {
            // Header with discipline
            HStack {
                Image(systemName: activityIcon)
                    .font(.title3)
                    .foregroundStyle(activityColor)

                Text(activityName)
                    .font(.caption)
                    .fontWeight(.semibold)

                Spacer()

                // Live indicator
                Circle()
                    .fill(WatchAppColors.active)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 4)

            // Duration - BIG
            Text(workoutManager.formattedElapsedTime)
                .font(.system(size: 44, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)

            // Distance/Laps based on activity
            if workoutManager.activityType == .swimming {
                // Swimming: show distance and laps
                HStack(spacing: 16) {
                    Text(workoutManager.formattedSwimmingDistance)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(activityColor)
                    Text("\(workoutManager.lapCount) laps")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(workoutManager.formattedDistance)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(activityColor)
            }

            Divider()
                .padding(.vertical, 2)

            // Metrics
            HStack(spacing: 16) {
                // Speed/Pace (not for swimming)
                if workoutManager.activityType == .riding {
                    VStack(spacing: 2) {
                        Text("Speed")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formattedSpeed)
                            .font(.body)
                            .fontWeight(.medium)
                    }
                } else if workoutManager.activityType == .running {
                    VStack(spacing: 2) {
                        Text("Pace")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(workoutManager.formattedPace)
                            .font(.body)
                            .fontWeight(.medium)
                    }
                } else if workoutManager.activityType == .swimming {
                    // Swimming metrics: strokes and pace
                    VStack(spacing: 2) {
                        Text("\(workoutManager.strokeCount)")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("strokes")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 2) {
                        Text(workoutManager.swimPacePer100m)
                            .font(.body)
                            .fontWeight(.medium)
                        Text("/100m")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Heart Rate
                if workoutManager.currentHeartRate > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                        Text("\(workoutManager.currentHeartRate)")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
            }

            Spacer()

            // Control buttons
            HStack(spacing: 20) {
                // Pause/Resume button
                Button {
                    if workoutManager.isPaused {
                        workoutManager.resumeWorkout()
                    } else {
                        workoutManager.pauseWorkout()
                    }
                } label: {
                    Image(systemName: workoutManager.isPaused ? "play.fill" : "pause.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(WatchAppColors.primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // Stop button
                Button {
                    Task {
                        await workoutManager.stopWorkout()
                    }
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(WatchAppColors.error)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    // MARK: - Activity Helpers

    private var activityIcon: String {
        switch workoutManager.activityType {
        case .riding: return "figure.equestrian.sports"
        case .running: return "figure.run"
        case .swimming: return "figure.pool.swim"
        case .none: return "figure.stand"
        }
    }

    private var activityName: String {
        switch workoutManager.activityType {
        case .riding: return "Riding"
        case .running: return "Running"
        case .swimming: return "Swimming"
        case .none: return "Workout"
        }
    }

    private var activityColor: Color {
        switch workoutManager.activityType {
        case .riding: return WatchAppColors.riding
        case .running: return WatchAppColors.running
        case .swimming: return WatchAppColors.swimming
        case .none: return WatchAppColors.primary
        }
    }

    private var formattedSpeed: String {
        let speed = workoutManager.currentSpeed
        let kmh = speed * 3.6
        return String(format: "%.1f km/h", kmh)
    }
}

#Preview {
    ContentView()
        .environment(WatchConnectivityService.shared)
}
