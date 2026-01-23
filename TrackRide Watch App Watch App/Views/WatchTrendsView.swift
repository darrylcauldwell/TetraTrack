//
//  WatchTrendsView.swift
//  TrackRide Watch App
//
//  Glanceable trends view showing weekly/monthly progress
//  Part of Phase 2: Watch app as companion-only dashboard
//

import SwiftUI

/// Represents training progress data received from iPhone
struct TrainingTrends: Codable {
    let periodLabel: String  // "This Week" or "This Month"
    let sessionCount: Int
    let totalDuration: TimeInterval
    let ridingCount: Int
    let runningCount: Int
    let swimmingCount: Int
    let shootingCount: Int
    let comparedToPrevious: Double  // % change from previous period, e.g., +15 or -10
}

struct WatchTrendsView: View {
    @Environment(WatchConnectivityService.self) private var connectivityService
    @State private var sessionStore = WatchSessionStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header with period
                HStack {
                    Text(connectivityService.trends.periodLabel.isEmpty ? "This Week" : connectivityService.trends.periodLabel)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    trendBadge
                }
                .padding(.horizontal, 4)

                // Main stats cards
                HStack(spacing: 8) {
                    StatCard(
                        value: "\(combinedSessionCount)",
                        label: "Sessions",
                        color: WatchAppColors.primary
                    )

                    StatCard(
                        value: formattedTotalDuration,
                        label: "Duration",
                        color: WatchAppColors.accent
                    )
                }

                // Discipline breakdown
                VStack(spacing: 8) {
                    Text("By Discipline")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DisciplineProgressBar(
                        riding: combinedRidingCount,
                        running: combinedRunningCount,
                        swimming: combinedSwimmingCount,
                        shooting: connectivityService.trends.shootingCount
                    )

                    // Legend
                    disciplineLegend
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .background(WatchAppColors.cardBackground.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Combined Local + Synced Data

    /// Sessions from this week (pending local sessions)
    private var localSessionsThisWeek: [WatchSession] {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        return sessionStore.pendingSessions.filter { $0.startDate >= startOfWeek }
    }

    private var localSessionCount: Int {
        localSessionsThisWeek.count
    }

    private var localTotalDuration: TimeInterval {
        localSessionsThisWeek.reduce(0) { $0 + $1.duration }
    }

    private var localRidingCount: Int {
        localSessionsThisWeek.filter { $0.discipline == .riding }.count
    }

    private var localRunningCount: Int {
        localSessionsThisWeek.filter { $0.discipline == .running }.count
    }

    private var localSwimmingCount: Int {
        localSessionsThisWeek.filter { $0.discipline == .swimming }.count
    }

    private var combinedSessionCount: Int {
        connectivityService.trends.sessionCount + localSessionCount
    }

    private var combinedTotalDuration: TimeInterval {
        connectivityService.trends.totalDuration + localTotalDuration
    }

    private var combinedRidingCount: Int {
        connectivityService.trends.ridingCount + localRidingCount
    }

    private var combinedRunningCount: Int {
        connectivityService.trends.runningCount + localRunningCount
    }

    private var combinedSwimmingCount: Int {
        connectivityService.trends.swimmingCount + localSwimmingCount
    }

    // MARK: - Trend Badge

    @ViewBuilder
    private var trendBadge: some View {
        let change = connectivityService.trends.comparedToPrevious
        if change != 0 {
            HStack(spacing: 2) {
                Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2)
                Text(String(format: "%.0f%%", abs(change)))
                    .font(.caption2)
            }
            .foregroundStyle(change > 0 ? WatchAppColors.active : WatchAppColors.warning)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((change > 0 ? WatchAppColors.active : WatchAppColors.warning).opacity(0.2))
            .clipShape(Capsule())
        }
    }

    // MARK: - Formatted Duration

    private var formattedTotalDuration: String {
        let totalDuration = combinedTotalDuration
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 {
            return String(format: "%dh", hours)
        }
        return String(format: "%dm", minutes)
    }

    // MARK: - Discipline Legend

    private var disciplineLegend: some View {
        HStack(spacing: 8) {
            LegendItem(color: WatchAppColors.riding, count: combinedRidingCount)
            LegendItem(color: WatchAppColors.running, count: combinedRunningCount)
            LegendItem(color: WatchAppColors.swimming, count: combinedSwimmingCount)
            LegendItem(color: WatchAppColors.shooting, count: connectivityService.trends.shootingCount)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(WatchAppColors.cardBackground.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Discipline Progress Bar

struct DisciplineProgressBar: View {
    let riding: Int
    let running: Int
    let swimming: Int
    let shooting: Int

    private var total: Int {
        riding + running + swimming + shooting
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                if total > 0 {
                    if riding > 0 {
                        Rectangle()
                            .fill(WatchAppColors.riding)
                            .frame(width: geometry.size.width * CGFloat(riding) / CGFloat(total))
                    }
                    if running > 0 {
                        Rectangle()
                            .fill(WatchAppColors.running)
                            .frame(width: geometry.size.width * CGFloat(running) / CGFloat(total))
                    }
                    if swimming > 0 {
                        Rectangle()
                            .fill(WatchAppColors.swimming)
                            .frame(width: geometry.size.width * CGFloat(swimming) / CGFloat(total))
                    }
                    if shooting > 0 {
                        Rectangle()
                            .fill(WatchAppColors.shooting)
                            .frame(width: geometry.size.width * CGFloat(shooting) / CGFloat(total))
                    }
                } else {
                    Rectangle()
                        .fill(WatchAppColors.inactive.opacity(0.3))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .frame(height: 12)
    }
}

// MARK: - Legend Item

struct LegendItem: View {
    let color: Color
    let count: Int

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(count)")
                .font(.caption2)
                .foregroundStyle(count > 0 ? .primary : .secondary)
        }
    }
}

#Preview {
    WatchTrendsView()
        .environment(WatchConnectivityService.shared)
}
