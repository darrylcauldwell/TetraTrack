//
//  ReinBalanceView.swift
//  TrackRide
//
//  Displays left/right rein balance and quality metrics for flatwork

import SwiftUI

struct ReinBalanceView: View {
    let ride: Ride

    private var leftPercent: Int {
        ride.reinBalancePercent
    }

    private var rightPercent: Int {
        100 - leftPercent
    }

    private var totalReinDuration: TimeInterval {
        ride.totalReinDuration
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Rein Balance")
                    .font(.headline)

                Spacer()

                Text("Flatwork")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if totalReinDuration == 0 {
                Text("No rein data recorded")
                    .foregroundStyle(.secondary)
            } else {
                // Balance bar
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        // Left side
                        Rectangle()
                            .fill(AppColors.turnLeft)
                            .frame(width: geometry.size.width * CGFloat(leftPercent) / 100)

                        // Right side
                        Rectangle()
                            .fill(AppColors.turnRight)
                            .frame(width: geometry.size.width * CGFloat(rightPercent) / 100)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(height: 24)

                // Duration labels
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .foregroundStyle(AppColors.turnLeft)
                            Text("Left Rein")
                                .font(.subheadline)
                        }
                        Text(ride.formattedLeftReinDuration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(leftPercent)%")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.turnLeft)
                    }

                    Spacer()

                    // Balance indicator
                    VStack {
                        Image(systemName: isBalanced ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundStyle(isBalanced ? AppColors.success : AppColors.warning)
                        Text(isBalanced ? "Balanced" : "Uneven")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        HStack {
                            Text("Right Rein")
                                .font(.subheadline)
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .foregroundStyle(AppColors.turnRight)
                        }
                        Text(ride.formattedRightReinDuration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(rightPercent)%")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.turnRight)
                    }
                }

                Divider()

                // Quality metrics per rein
                HStack(spacing: 20) {
                    // Left rein quality
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Left Rein Quality")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 16) {
                            QualityMetricBadge(
                                label: "Symmetry",
                                value: ride.leftReinSymmetry,
                                color: AppColors.turnLeft
                            )
                            QualityMetricBadge(
                                label: "Rhythm",
                                value: ride.leftReinRhythm,
                                color: AppColors.turnLeft
                            )
                        }
                    }

                    Spacer()

                    // Right rein quality
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("Right Rein Quality")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 16) {
                            QualityMetricBadge(
                                label: "Symmetry",
                                value: ride.rightReinSymmetry,
                                color: AppColors.turnRight
                            )
                            QualityMetricBadge(
                                label: "Rhythm",
                                value: ride.rightReinRhythm,
                                color: AppColors.turnRight
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var isBalanced: Bool {
        leftPercent >= 40 && leftPercent <= 60
    }
}

struct QualityMetricBadge: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(String(format: "%.0f%%", value))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ReinBalanceView(ride: {
        let ride = Ride()
        ride.leftReinDuration = 300
        ride.rightReinDuration = 280
        ride.leftReinSymmetry = 85
        ride.rightReinSymmetry = 82
        ride.leftReinRhythm = 78
        ride.rightReinRhythm = 81
        return ride
    }())
    .padding()
}
