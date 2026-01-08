//
//  WorkloadCardView.swift
//  TrackRide
//
//  Displays horse workload indicator with recommendations

import SwiftUI

struct WorkloadCardView: View {
    let workload: WorkloadData

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Workload")
                    .font(.headline)
                Spacer()
                WorkloadBadge(level: workload.level)
            }

            // Stats row
            HStack(spacing: 16) {
                // Last 7 Days stats
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last 7 Days")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        Label("\(workload.last7DaysRides) rides", systemImage: "figure.equestrian.sports")
                        Label(workload.formattedLast7DaysDistance, systemImage: "arrow.left.and.right")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                }

                Spacer()

                // Last Ride
                if let days = workload.daysSinceLastRide {
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("Last Ride")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(days == 0 ? "Today" : "\(days) days ago")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }

            // Recommendation
            if !workload.recommendation.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(workloadColor)
                    Text(workload.recommendation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var workloadColor: Color {
        switch workload.level {
        case .rest: return .secondary
        case .light: return AppColors.success
        case .moderate: return AppColors.primary
        case .heavy: return AppColors.warning
        case .overworked: return AppColors.error
        }
    }
}

// MARK: - Workload Badge

struct WorkloadBadge: View {
    let level: WorkloadLevel

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: level.icon)
            Text(level.rawValue)
                .fontWeight(.medium)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(badgeColor.opacity(0.15))
        .foregroundStyle(badgeColor)
        .clipShape(Capsule())
    }

    private var badgeColor: Color {
        switch level {
        case .rest: return .secondary
        case .light: return AppColors.success
        case .moderate: return AppColors.primary
        case .heavy: return AppColors.warning
        case .overworked: return AppColors.error
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        WorkloadCardView(workload: WorkloadData(
            level: .moderate,
            last7DaysRides: 3,
            last7DaysDuration: 10800,
            last7DaysDistance: 15000,
            daysSinceLastRide: 1,
            recommendation: "Moderate workload - well balanced"
        ))

        WorkloadCardView(workload: WorkloadData(
            level: .rest,
            last7DaysRides: 0,
            last7DaysDuration: 0,
            last7DaysDistance: 0,
            daysSinceLastRide: 5,
            recommendation: "Consider a light session to maintain fitness"
        ))
    }
    .padding()
}
