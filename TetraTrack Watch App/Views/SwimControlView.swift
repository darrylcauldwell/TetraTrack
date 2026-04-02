//
//  SwimControlView.swift
//  TetraTrack Watch App
//
//  Autonomous swimming session with lap count as hero metric
//

import SwiftUI

struct SwimControlView: View {
    @Environment(WorkoutManager.self) private var workoutManager

    var body: some View {
        Group {
            if workoutManager.isWorkoutActive && workoutManager.activityType == .swimming {
                activeSwimView
            } else {
                startSwimView
            }
        }
        .navigationBarBackButtonHidden(workoutManager.isWorkoutActive)
    }

    // MARK: - Start Swim View

    private var startSwimView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.pool.swim")
                .font(.system(size: 44))
                .foregroundStyle(WatchAppColors.swimming)
                .padding(.top, 8)

            // Pool length display
            Text("\(Int(workoutManager.poolLength))m pool")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                Task {
                    await workoutManager.startAutonomousSwim()
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
        SessionPager(disciplineIcon: "figure.pool.swim", disciplineColor: WatchAppColors.swimming, disciplineName: "Swim") {
            VStack(spacing: 8) {
                Text("\(workoutManager.lapCount)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchAppColors.swimming)
                Text("laps")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(workoutManager.formattedElapsedTime)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)

                Divider().padding(.vertical, 4)

                HStack(spacing: 12) {
                    WatchHeartRateZoneBadge(heartRate: workoutManager.currentHeartRate)
                    WatchMetricCell(value: "\(workoutManager.strokeCount)", unit: "strokes")
                    WatchMetricCell(value: workoutManager.formattedSwimmingDistance, unit: "dist")
                }
            }
            .padding()
        }
    }
}

#Preview {
    SwimControlView()
}
