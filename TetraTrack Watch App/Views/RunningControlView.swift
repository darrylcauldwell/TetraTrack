//
//  RunningControlView.swift
//  TetraTrack Watch App
//
//  Autonomous running session control for Apple Watch
//  Start, monitor, and stop runs directly from Watch
//

import SwiftUI
import TetraTrackShared

struct RunningControlView: View {
    @Environment(WatchConnectivityService.self) private var connectivityService
    @Environment(WorkoutManager.self) private var workoutManager
    @State private var showingAuthError = false

    var body: some View {
        Group {
            if workoutManager.isWorkoutActive && (workoutManager.activityType == .running || workoutManager.activityType == .walking) {
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
        ZStack(alignment: .bottom) {
            VStack(spacing: 8) {
                // Distance — hero metric
                Text(workoutManager.formattedDistance)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchAppColors.running)

                Divider()
                    .padding(.vertical, 4)

                // Metrics grid
                HStack(spacing: 12) {
                    // Pace
                    WatchMetricCell(value: workoutManager.formattedPace, unit: "pace")

                    // Heart Rate
                    WatchHeartRateZoneBadge(heartRate: workoutManager.currentHeartRate)

                    // Cadence
                    WatchMetricCell(
                        value: WatchMotionManager.shared.cadence > 0 ? "\(WatchMotionManager.shared.cadence)" : "\u{2013}",
                        unit: "spm"
                    )
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
            }
            .padding()
            .padding(.bottom, 62)

            WatchFloatingControlPanel(
                disciplineIcon: "figure.run",
                disciplineColor: WatchAppColors.running,
                disciplineName: "Run"
            )
        }
    }
}

#Preview {
    RunningControlView()
        .environment(WatchConnectivityService.shared)
}
