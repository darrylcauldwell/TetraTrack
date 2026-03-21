//
//  SwimControlView.swift
//  TetraTrack Watch App
//
//  Autonomous swimming session control for Apple Watch
//  Start, monitor, and stop swims directly from Watch
//

import SwiftUI
import HealthKit
import TetraTrackShared

struct SwimControlView: View {
    @Environment(WatchConnectivityService.self) private var connectivityService
    @Environment(WorkoutManager.self) private var workoutManager

    var body: some View {
        Group {
            if workoutManager.isWorkoutActive && workoutManager.activityType == .swimming {
                activeSwimView
            } else {
                startSwimView
            }
        }
    }

    // MARK: - Start Swim View

    private var startSwimView: some View {
        VStack(spacing: 12) {
            // Icon at top
            Image(systemName: "figure.pool.swim")
                .font(.system(size: 44))
                .foregroundStyle(WatchAppColors.swimming)
                .padding(.top, 8)

            // Pending sync indicator (only if needed)
            if WatchSessionStore.shared.pendingCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "icloud.and.arrow.up")
                    Text("\(WatchSessionStore.shared.pendingCount) pending")
                }
                .font(.caption2)
                .foregroundStyle(.orange)
            }

            Spacer()

            // Start button
            Button {
                Task {
                    await workoutManager.startWorkout(type: .swimming)
                }
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Swim")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(WatchAppColors.swimming)
            .padding(.bottom, 8)
        }
        .padding(.horizontal)
    }

    // MARK: - Active Swim View

    private var activeSwimView: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 6) {
                    // Distance and Laps — hero metrics
                    HStack(spacing: 16) {
                        VStack(spacing: 2) {
                            Text(workoutManager.formattedSwimmingDistance)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                            Text("distance")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 2) {
                            Text("\(workoutManager.lapCount)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                            Text("laps")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(WatchAppColors.swimming)

                    Divider()
                        .padding(.vertical, 2)

                    // Stroke info and pace
                    HStack(spacing: 12) {
                        WatchMetricCell(value: "\(workoutManager.strokeCount)", unit: "strokes")

                        WatchMetricCell(value: workoutManager.swimPacePer100m, unit: "/100m")

                        WatchHeartRateZoneBadge(heartRate: workoutManager.currentHeartRate)
                    }

                    // SWOLF and stroke type
                    HStack(spacing: 16) {
                        if workoutManager.swolfScore > 0 {
                            VStack(spacing: 2) {
                                Text("\(workoutManager.swolfScore)")
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(WatchAppColors.swimming)
                                Text("SWOLF")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if workoutManager.currentStrokeType != .unknown {
                            VStack(spacing: 2) {
                                Text(workoutManager.strokeTypeName)
                                    .font(.callout)
                                    .fontWeight(.medium)
                                Text("stroke")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .padding(.bottom, 62)
            }

            WatchFloatingControlPanel(
                disciplineIcon: "figure.pool.swim",
                disciplineColor: WatchAppColors.swimming,
                disciplineName: "Swim"
            )
        }
    }
}

#Preview {
    SwimControlView()
        .environment(WatchConnectivityService.shared)
}
