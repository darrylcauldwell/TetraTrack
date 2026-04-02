//
//  RunControlView.swift
//  TetraTrack Watch App
//
//  Autonomous running session with min/400m pace as hero metric
//

import SwiftUI

struct RunControlView: View {
    @Environment(WorkoutManager.self) private var workoutManager

    var body: some View {
        Group {
            if workoutManager.isWorkoutActive && workoutManager.activityType == .running {
                activeRunView
            } else {
                startRunView
            }
        }
        .navigationBarBackButtonHidden(workoutManager.isWorkoutActive)
    }

    // MARK: - Start Run View

    private var startRunView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.system(size: 44))
                .foregroundStyle(WatchAppColors.running)
                .padding(.top, 8)

            Spacer()

            Button {
                Task {
                    await workoutManager.startAutonomousRun()
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
        }
        .padding(.horizontal)
    }

    // MARK: - Active Run View

    private var activeRunView: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 8) {
                // Pace per 400m — hero metric
                Text(workoutManager.formattedPace400m)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchAppColors.running)
                Text("min/400m")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // Timer
                Text(workoutManager.formattedElapsedTime)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)

                Divider().padding(.vertical, 4)

                // Metrics grid
                HStack(spacing: 12) {
                    WatchHeartRateZoneBadge(heartRate: workoutManager.currentHeartRate)

                    WatchMetricCell(
                        value: workoutManager.formattedDistance,
                        unit: "dist"
                    )

                    WatchMetricCell(
                        value: "\(workoutManager.runningCadence)",
                        unit: "spm"
                    )
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
    RunControlView()
}
