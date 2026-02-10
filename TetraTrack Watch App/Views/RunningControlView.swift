//
//  RunningControlView.swift
//  TetraTrack Watch App
//
//  Autonomous running session control for Apple Watch
//  Start, monitor, and stop runs directly from Watch
//

import SwiftUI

struct RunningControlView: View {
    @Environment(WatchConnectivityService.self) private var connectivityService
    @Environment(WorkoutManager.self) private var workoutManager
    @State private var showingStopConfirmation = false
    @State private var showingAuthError = false

    var body: some View {
        Group {
            if workoutManager.isWorkoutActive && workoutManager.activityType == .running {
                activeRunView
            } else {
                startRunView
            }
        }
    }

    // MARK: - Start Run View

    private var startRunView: some View {
        VStack(spacing: 12) {
            // Icon at top
            Image(systemName: "figure.run")
                .font(.system(size: 44))
                .foregroundStyle(WatchAppColors.running)
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
                    await workoutManager.startWorkout(type: .running)
                    // Check if workout actually started
                    if !workoutManager.isWorkoutActive {
                        showingAuthError = true
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Run")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(WatchAppColors.running)
            .padding(.bottom, 8)
            .alert("Unable to Start", isPresented: $showingAuthError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please ensure Health permissions are granted in the Watch Settings app.")
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Active Run View

    private var activeRunView: some View {
        VStack(spacing: 8) {
            // Duration - big and prominent
            Text(workoutManager.formattedElapsedTime)
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundStyle(WatchAppColors.running)

            // Distance
            Text(workoutManager.formattedDistance)
                .font(.title3)
                .fontWeight(.semibold)

            Divider()
                .padding(.vertical, 4)

            // Metrics grid
            HStack(spacing: 16) {
                // Pace
                VStack(spacing: 2) {
                    Text(workoutManager.formattedPace)
                        .font(.headline)
                    Text("pace")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Heart Rate
                if workoutManager.currentHeartRate > 0 {
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                            Text("\(workoutManager.currentHeartRate)")
                                .font(.headline)
                        }
                        Text("bpm")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Elevation
                VStack(spacing: 2) {
                    Text(String(format: "%.0f", workoutManager.elevationGain))
                        .font(.headline)
                    Text("m gain")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Calories if available
            if workoutManager.activeCalories > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(Int(workoutManager.activeCalories)) kcal")
                }
                .font(.caption)
            }

            Spacer()

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
        .padding()
        .confirmationDialog("End Run?", isPresented: $showingStopConfirmation) {
            Button("Save Run") {
                Task {
                    await workoutManager.stopWorkout()
                }
            }
            Button("Discard", role: .destructive) {
                workoutManager.discardWorkout()
            }
            Button("Continue Running", role: .cancel) {}
        }
    }
}

#Preview {
    RunningControlView()
        .environment(WatchConnectivityService.shared)
}
