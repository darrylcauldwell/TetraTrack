//
//  RideControlView.swift
//  TrackRide Watch App
//
//  Autonomous riding session control for Apple Watch
//  Start, monitor, and stop rides directly from Watch
//

import SwiftUI

struct RideControlView: View {
    @Environment(WatchConnectivityService.self) private var connectivityService
    @Environment(WorkoutManager.self) private var workoutManager
    @State private var showingStopConfirmation = false

    var body: some View {
        Group {
            if workoutManager.isWorkoutActive && workoutManager.activityType == .riding {
                activeRideView
            } else {
                startRideView
            }
        }
    }

    // MARK: - Start Ride View

    private var startRideView: some View {
        VStack(spacing: 12) {
            // Icon at top
            Image(systemName: "figure.equestrian.sports")
                .font(.system(size: 44))
                .foregroundStyle(WatchAppColors.riding)
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
                    await workoutManager.startWorkout(type: .riding)
                }
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Ride")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(WatchAppColors.riding)
            .padding(.bottom, 8)
        }
        .padding(.horizontal)
    }

    // MARK: - Active Ride View

    private var activeRideView: some View {
        VStack(spacing: 8) {
            // Duration - big and prominent
            Text(workoutManager.formattedElapsedTime)
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundStyle(WatchAppColors.riding)

            // Distance
            Text(workoutManager.formattedDistance)
                .font(.title3)
                .fontWeight(.semibold)

            Divider()
                .padding(.vertical, 4)

            // Metrics grid
            HStack(spacing: 16) {
                // Speed
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", workoutManager.currentSpeed * 3.6))
                        .font(.headline)
                    Text("km/h")
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
        .confirmationDialog("End Ride?", isPresented: $showingStopConfirmation) {
            Button("Save Ride") {
                Task {
                    await workoutManager.stopWorkout()
                }
            }
            Button("Discard", role: .destructive) {
                workoutManager.discardWorkout()
            }
            Button("Continue Riding", role: .cancel) {}
        }
    }
}

#Preview {
    RideControlView()
        .environment(WatchConnectivityService.shared)
}
