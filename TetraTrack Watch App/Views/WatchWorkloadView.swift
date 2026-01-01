//
//  WatchWorkloadView.swift
//  TetraTrack Watch App
//
//  Glanceable workload indicators showing training load and rest recommendations
//  Part of Phase 2: Watch app as companion-only dashboard
//

import SwiftUI

/// Represents workload data received from iPhone
struct WorkloadData: Codable {
    let sessionsThisWeek: Int
    let targetSessionsPerWeek: Int
    let totalDurationThisWeek: TimeInterval
    let restDays: Int
    let consecutiveTrainingDays: Int
    let recommendation: WorkloadRecommendation

    enum WorkloadRecommendation: String, Codable {
        case rest = "rest"
        case light = "light"
        case moderate = "moderate"
        case ready = "ready"
        case active = "active"  // Currently in a session
    }
}

struct WatchWorkloadView: View {
    @Environment(WatchConnectivityService.self) private var connectivityService

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("Workload")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 4)

                // Main workload indicator ring
                workloadRing

                // Weekly progress bar
                weeklyProgressSection

                // Rest recommendation
                recommendationCard
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Workload Ring

    private var workloadRing: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(WatchAppColors.inactive.opacity(0.3), lineWidth: 10)
                .frame(width: 100, height: 100)

            // Progress ring
            Circle()
                .trim(from: 0, to: progressFraction)
                .stroke(
                    progressColor,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(-90))

            // Center content
            VStack(spacing: 2) {
                Text("\(connectivityService.workload.sessionsThisWeek)")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(progressColor)

                Text("of \(connectivityService.workload.targetSessionsPerWeek)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private var progressFraction: Double {
        guard connectivityService.workload.targetSessionsPerWeek > 0 else { return 0 }
        let fraction = Double(connectivityService.workload.sessionsThisWeek) /
                       Double(connectivityService.workload.targetSessionsPerWeek)
        return min(fraction, 1.0)
    }

    private var progressColor: Color {
        let fraction = progressFraction
        if fraction >= 1.0 { return WatchAppColors.active }
        if fraction >= 0.7 { return WatchAppColors.primary }
        if fraction >= 0.4 { return WatchAppColors.warning }
        return WatchAppColors.inactive
    }

    // MARK: - Weekly Progress Section

    private var weeklyProgressSection: some View {
        VStack(spacing: 6) {
            HStack {
                Text("This Week")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formattedWeeklyDuration)
                    .font(.caption)
                    .fontWeight(.medium)
            }

            // Stats row
            HStack(spacing: 12) {
                MiniStatView(
                    value: "\(connectivityService.workload.consecutiveTrainingDays)",
                    label: "Streak",
                    icon: "flame.fill",
                    color: streakColor
                )

                MiniStatView(
                    value: "\(connectivityService.workload.restDays)",
                    label: "Rest Days",
                    icon: "moon.fill",
                    color: WatchAppColors.swimming
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(WatchAppColors.cardBackground.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var formattedWeeklyDuration: String {
        let hours = Int(connectivityService.workload.totalDurationThisWeek) / 3600
        let minutes = (Int(connectivityService.workload.totalDurationThisWeek) % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        }
        return String(format: "%d min", minutes)
    }

    private var streakColor: Color {
        let streak = connectivityService.workload.consecutiveTrainingDays
        if streak >= 5 { return WatchAppColors.running }  // Hot streak
        if streak >= 3 { return WatchAppColors.warning }
        return WatchAppColors.inactive
    }

    // MARK: - Recommendation Card

    private var recommendationCard: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(recommendationColor.opacity(0.2))
                    .frame(width: 36, height: 36)

                Image(systemName: recommendationIcon)
                    .font(.body)
                    .foregroundStyle(recommendationColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(recommendationTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text(recommendationDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(recommendationColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var recommendationIcon: String {
        switch connectivityService.workload.recommendation {
        case .rest: return "bed.double.fill"
        case .light: return "leaf.fill"
        case .moderate: return "figure.walk"
        case .ready: return "bolt.fill"
        case .active: return "figure.run"
        }
    }

    private var recommendationColor: Color {
        switch connectivityService.workload.recommendation {
        case .rest: return WatchAppColors.swimming
        case .light: return WatchAppColors.active
        case .moderate: return WatchAppColors.primary
        case .ready: return WatchAppColors.warning
        case .active: return WatchAppColors.running
        }
    }

    private var recommendationTitle: String {
        switch connectivityService.workload.recommendation {
        case .rest: return "Rest Day"
        case .light: return "Light Training"
        case .moderate: return "Moderate Day"
        case .ready: return "Ready to Train"
        case .active: return "Training Active"
        }
    }

    private var recommendationDescription: String {
        switch connectivityService.workload.recommendation {
        case .rest: return "Recovery recommended"
        case .light: return "Keep intensity low"
        case .moderate: return "Normal training OK"
        case .ready: return "Good to go!"
        case .active: return "Session in progress"
        }
    }
}

// MARK: - Mini Stat View

struct MiniStatView: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    WatchWorkloadView()
        .environment(WatchConnectivityService.shared)
}
