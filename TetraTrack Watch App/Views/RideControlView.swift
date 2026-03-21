//
//  RideControlView.swift
//  TetraTrack Watch App
//
//  Autonomous riding session control for Apple Watch
//  Start, monitor, and stop rides directly from Watch
//

import SwiftUI
import TetraTrackShared

struct RideControlView: View {
    @Environment(WatchConnectivityService.self) private var connectivityService
    @Environment(WorkoutManager.self) private var workoutManager

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
        ZStack(alignment: .bottom) {
            VStack(spacing: 8) {
                // Distance — hero metric
                Text(workoutManager.formattedDistance)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchAppColors.riding)

                // Current gait indicator
                if let gaitResult = WatchGaitAnalyzer.shared.currentGaitResult, gaitResult.gaitState != "stationary" {
                    Text(gaitResult.gaitState.capitalized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(watchGaitColor(gaitResult.gaitState))
                        .clipShape(Capsule())
                }

                Divider()
                    .padding(.vertical, 4)

                // Metrics grid
                HStack(spacing: 12) {
                    // Speed
                    WatchMetricCell(
                        value: String(format: "%.1f", workoutManager.currentSpeed * 3.6),
                        unit: "km/h"
                    )

                    // Heart Rate
                    WatchHeartRateZoneBadge(heartRate: workoutManager.currentHeartRate)

                    // Elevation
                    WatchMetricCell(
                        value: String(format: "%.0f", workoutManager.elevationGain),
                        unit: "m gain"
                    )
                }

                Spacer()
            }
            .padding()
            .padding(.bottom, 62)

            WatchFloatingControlPanel(
                disciplineIcon: "figure.equestrian.sports",
                disciplineColor: WatchAppColors.riding,
                disciplineName: "Ride"
            )
        }
    }

    private func watchGaitColor(_ gait: String) -> Color {
        switch gait {
        case "walk": return .green
        case "trot": return .blue
        case "canter": return .orange
        case "gallop": return .red
        default: return .gray
        }
    }
}

#Preview {
    RideControlView()
        .environment(WatchConnectivityService.shared)
}
