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
            if workoutManager.isWorkoutActive && !workoutManager.isCompanionMode {
                activeWorkoutView
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

    // MARK: - Active Workout View

    private var activeWorkoutView: some View {
        ZStack(alignment: .bottom) {
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

                // Distance/Laps/Shots — hero metric
                if workoutManager.activityType == .swimming {
                    HStack(spacing: 16) {
                        Text(workoutManager.formattedSwimmingDistance)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(activityColor)
                        Text("\(workoutManager.lapCount) laps")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } else if workoutManager.activityType == .shooting {
                    Text("Shooting Session")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text(workoutManager.formattedDistance)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(activityColor)
                }

                Divider()
                    .padding(.vertical, 2)

                // Metrics
                HStack(spacing: 16) {
                    if workoutManager.activityType == .riding {
                        WatchMetricCell(value: formattedSpeed, unit: "speed")
                    } else if workoutManager.activityType == .running || workoutManager.activityType == .walking {
                        WatchMetricCell(value: workoutManager.formattedPace, unit: "pace")
                    } else if workoutManager.activityType == .swimming {
                        WatchMetricCell(value: "\(workoutManager.strokeCount)", unit: "strokes")
                        WatchMetricCell(value: workoutManager.swimPacePer100m, unit: "/100m")
                    }

                    WatchHeartRateZoneBadge(heartRate: workoutManager.currentHeartRate)
                }

                // Diagnostic overlay
                HStack(spacing: 8) {
                    Text("T:\(workoutManager.motionSendTickCount)")
                    Text("HR:\(workoutManager.currentHeartRate)")
                    Text(workoutManager.isMirroringToiPhone ? "MIR" : "WC")
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.gray)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 62)

            WatchFloatingControlPanel(
                disciplineIcon: activityIcon,
                disciplineColor: activityColor,
                disciplineName: activityName
            )
        }
    }

    // MARK: - Activity Helpers

    private var activityIcon: String {
        switch workoutManager.activityType {
        case .riding: return "figure.equestrian.sports"
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .swimming: return "figure.pool.swim"
        case .shooting: return "target"
        case .none: return "figure.stand"
        }
    }

    private var activityName: String {
        switch workoutManager.activityType {
        case .riding: return "Riding"
        case .running: return "Running"
        case .walking: return "Walking"
        case .swimming: return "Swimming"
        case .shooting: return "Shooting"
        case .none: return "Workout"
        }
    }

    private var activityColor: Color {
        switch workoutManager.activityType {
        case .riding: return WatchAppColors.riding
        case .running: return WatchAppColors.running
        case .walking: return WatchAppColors.running
        case .swimming: return WatchAppColors.swimming
        case .shooting: return WatchAppColors.shooting
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
