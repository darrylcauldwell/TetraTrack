//
//  RideControlView.swift
//  TetraTrack Watch App
//
//  Type-specific active ride display for autonomous Watch rides.
//  Shows metrics relevant to each ride type (Ride, Dressage, Showjumping).
//

import SwiftUI

struct RideControlView: View {
    @Environment(WorkoutManager.self) private var workoutManager

    var body: some View {
        Group {
            if workoutManager.isWorkoutActive && workoutManager.activityType == .riding {
                activeRideView
            } else {
                // Fallback — should navigate via RideTypePickerView instead
                Text("Select a ride type to start")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Active Ride View

    @ViewBuilder
    private var activeRideView: some View {
        let collector = workoutManager.rideMetricsCollector
        let rideType = workoutManager.currentRideType ?? .ride

        ZStack(alignment: .bottom) {
            VStack(spacing: 8) {
                switch rideType {
                case .ride:
                    rideLayout(collector: collector)
                case .dressage:
                    dressageLayout(collector: collector)
                case .showjumping:
                    showjumpingLayout(collector: collector)
                }

                Spacer()
            }
            .padding()
            .padding(.bottom, 62)

            WatchFloatingControlPanel(
                disciplineIcon: rideType.icon,
                disciplineColor: WatchAppColors.riding,
                disciplineName: rideType.rawValue
            )
        }
    }

    // MARK: - Ride (General) Layout

    private func rideLayout(collector: WatchRideMetricsCollector?) -> some View {
        VStack(spacing: 8) {
            // Distance — hero metric
            Text(workoutManager.formattedDistance)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(WatchAppColors.riding)

            // Timer
            Text(workoutManager.formattedElapsedTime)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)

            Divider().padding(.vertical, 4)

            HStack(spacing: 12) {
                WatchHeartRateZoneBadge(heartRate: workoutManager.currentHeartRate)

                WatchMetricCell(
                    value: String(format: "%.0f", collector?.armSteadiness ?? 0),
                    unit: "steady"
                )

                WatchMetricCell(
                    value: String(format: "%.0f", workoutManager.elevationGain),
                    unit: "m gain"
                )
            }
        }
    }

    // MARK: - Dressage Layout

    private func dressageLayout(collector: WatchRideMetricsCollector?) -> some View {
        VStack(spacing: 8) {
            // Timer — hero metric for dressage
            Text(workoutManager.formattedElapsedTime)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(WatchAppColors.riding)

            Divider().padding(.vertical, 4)

            HStack(spacing: 12) {
                WatchHeartRateZoneBadge(heartRate: workoutManager.currentHeartRate)

                WatchMetricCell(
                    value: String(format: "%.0f", collector?.postingRhythm ?? 0),
                    unit: "rhythm"
                )
            }

            Divider().padding(.vertical, 2)

            // Turn balance + halts
            HStack(spacing: 12) {
                WatchMetricCell(
                    value: "L:\(collector?.leftTurnCount ?? 0) R:\(collector?.rightTurnCount ?? 0)",
                    unit: "turns"
                )

                WatchMetricCell(
                    value: "\(collector?.haltCount ?? 0)",
                    unit: "halts"
                )
            }
        }
    }

    // MARK: - Showjumping Layout

    private func showjumpingLayout(collector: WatchRideMetricsCollector?) -> some View {
        VStack(spacing: 8) {
            // Jump count — hero metric (fully autonomous detection)
            Text("\(collector?.jumpCount ?? 0)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(WatchAppColors.riding)
            Text("jumps")
                .font(.caption2)
                .foregroundStyle(.secondary)

            // Timer
            Text(workoutManager.formattedElapsedTime)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)

            Divider().padding(.vertical, 2)

            HStack(spacing: 12) {
                WatchHeartRateZoneBadge(heartRate: workoutManager.currentHeartRate)

                WatchMetricCell(
                    value: String(format: "%.0f", collector?.armSteadiness ?? 0),
                    unit: "steady"
                )

                WatchMetricCell(
                    value: workoutManager.formattedElapsedTime,
                    unit: "time"
                )
            }
        }
    }
}

#Preview {
    RideControlView()
}
