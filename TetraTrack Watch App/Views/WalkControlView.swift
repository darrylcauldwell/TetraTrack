//
//  WalkControlView.swift
//  TetraTrack Watch App
//
//  Autonomous walking session with SPM (steps per minute) as hero metric
//

import SwiftUI

struct WalkControlView: View {
    @Environment(WorkoutManager.self) private var workoutManager

    var body: some View {
        Group {
            if workoutManager.isWorkoutActive && workoutManager.activityType == .walking {
                activeWalkView
            } else {
                startWalkView
            }
        }
        .navigationBarBackButtonHidden(workoutManager.isWorkoutActive)
    }

    // MARK: - Start Walk View

    private var startWalkView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.walk")
                .font(.system(size: 44))
                .foregroundStyle(WatchAppColors.walking)
                .padding(.top, 8)

            Spacer()

            Button {
                Task {
                    await workoutManager.startAutonomousWalk()
                }
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Walk")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(WatchAppColors.walking)
            .padding(.bottom, 8)
        }
        .padding(.horizontal)
    }

    // MARK: - Active Walk View

    private var activeWalkView: some View {
        SessionPager(disciplineIcon: "figure.walk", disciplineColor: WatchAppColors.walking, disciplineName: "Walk") {
            VStack(spacing: 8) {
                Text("\(workoutManager.walkingCadence)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchAppColors.walking)
                Text("steps/min")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(workoutManager.formattedElapsedTime)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)

                Divider().padding(.vertical, 4)

                HStack(spacing: 12) {
                    WatchHeartRateZoneBadge(heartRate: workoutManager.currentHeartRate)
                    WatchMetricCell(value: workoutManager.formattedDistance, unit: "dist")
                    WatchMetricCell(value: String(format: "%.0f", workoutManager.elevationGain), unit: "m gain")
                }
            }
            .padding()
        }
    }
}

#Preview {
    WalkControlView()
}
