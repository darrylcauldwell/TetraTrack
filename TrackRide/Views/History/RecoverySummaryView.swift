//
//  RecoverySummaryView.swift
//  TrackRide
//
//  Post-ride recovery metrics summary
//

import SwiftUI

struct RecoverySummaryView: View {
    let recoveryMetrics: RecoveryMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with quality badge
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(.teal)
                Text("Recovery")
                    .font(.headline)

                Spacer()

                RecoveryQualityBadge(quality: recoveryMetrics.recoveryQuality)
            }

            // Recovery stats
            HStack(spacing: 24) {
                RecoveryStatItem(
                    title: "1-Min Drop",
                    value: recoveryMetrics.formattedOneMinuteRecovery,
                    subtitle: "HR decrease"
                )

                RecoveryStatItem(
                    title: "2-Min Drop",
                    value: recoveryMetrics.formattedTwoMinuteRecovery,
                    subtitle: "HR decrease"
                )

                if recoveryMetrics.timeToRestingHR != nil {
                    RecoveryStatItem(
                        title: "To Resting",
                        value: recoveryMetrics.formattedTimeToResting,
                        subtitle: "Time"
                    )
                }
            }

            // Interpretation
            VStack(alignment: .leading, spacing: 4) {
                Text("What This Means")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Text(recoveryMetrics.recoveryQuality.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Recovery Quality Badge

struct RecoveryQualityBadge: View {
    let quality: RecoveryQuality

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: quality.iconName)
                .font(.caption)

            Text(quality.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(qualityColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(qualityColor.opacity(0.15))
        .clipShape(Capsule())
    }

    private var qualityColor: Color {
        switch quality {
        case .excellent: return .green
        case .good: return .teal
        case .average: return .blue
        case .belowAverage: return .orange
        case .poor: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Recovery Stat Item

struct RecoveryStatItem: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        RecoverySummaryView(
            recoveryMetrics: RecoveryMetrics(
                peakHeartRate: 175,
                heartRateAtEnd: 160,
                oneMinuteRecovery: 35,
                twoMinuteRecovery: 55,
                timeToRestingHR: 180
            )
        )

        RecoverySummaryView(
            recoveryMetrics: RecoveryMetrics(
                peakHeartRate: 165,
                heartRateAtEnd: 155,
                oneMinuteRecovery: 15,
                twoMinuteRecovery: 25,
                timeToRestingHR: nil
            )
        )
    }
    .padding()
}
