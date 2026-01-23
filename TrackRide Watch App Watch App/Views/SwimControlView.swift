//
//  SwimControlView.swift
//  TrackRide Watch App
//
//  Autonomous swimming session control for Apple Watch
//  Start, monitor, and stop swims directly from Watch
//

import SwiftUI
import HealthKit

struct SwimControlView: View {
    @Environment(WatchConnectivityService.self) private var connectivityService
    @State private var workoutManager = WorkoutManager.shared
    @State private var showingStopConfirmation = false

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
        ScrollView {
            VStack(spacing: 6) {
                // Duration - big and prominent
                Text(workoutManager.formattedElapsedTime)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundStyle(WatchAppColors.swimming)

                // Distance and Laps
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text(workoutManager.formattedSwimmingDistance)
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("distance")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 2) {
                        Text("\(workoutManager.lapCount)")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("laps")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()
                    .padding(.vertical, 2)

                // Stroke info and pace
                HStack(spacing: 12) {
                    // Strokes
                    VStack(spacing: 2) {
                        Text("\(workoutManager.strokeCount)")
                            .font(.callout)
                            .fontWeight(.semibold)
                        Text("strokes")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    // Pace /100m
                    VStack(spacing: 2) {
                        Text(workoutManager.swimPacePer100m)
                            .font(.callout)
                            .fontWeight(.semibold)
                        Text("/100m")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    // Heart Rate
                    if workoutManager.currentHeartRate > 0 {
                        VStack(spacing: 2) {
                            HStack(spacing: 2) {
                                Image(systemName: "heart.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                                Text("\(workoutManager.currentHeartRate)")
                                    .font(.callout)
                                    .fontWeight(.semibold)
                            }
                            Text("bpm")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
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

                Spacer(minLength: 8)

                // Control buttons
                HStack(spacing: 12) {
                    // Pause/Resume
                    Button {
                        if workoutManager.isPaused {
                            workoutManager.resumeWorkout()
                        } else {
                            workoutManager.pauseWorkout()
                        }
                    } label: {
                        Image(systemName: workoutManager.isPaused ? "play.fill" : "pause.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)

                    // Stop
                    Button {
                        showingStopConfirmation = true
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .confirmationDialog("End Swim?", isPresented: $showingStopConfirmation) {
            Button("Save Swim") {
                Task {
                    await workoutManager.stopWorkout()
                }
            }
            Button("Discard", role: .destructive) {
                workoutManager.discardWorkout()
            }
            Button("Continue Swimming", role: .cancel) {}
        }
    }
}

#Preview {
    SwimControlView()
        .environment(WatchConnectivityService.shared)
}
