//
//  StatisticsComponents.swift
//  TrackRide
//
//  Extracted subviews from StatisticsView for better maintainability

import SwiftUI
import Charts

// MARK: - AI Narrative View

struct StatisticsAINarrativeView: View {
    let statistics: RideStatistics
    let narrative: StatisticsNarrative?
    let isLoading: Bool
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.purple)

                Text("AI Training Insights")
                    .font(.headline)

                Spacer()

                if !isLoading {
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline)
                    }
                }
            }

            if isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Analyzing your training data...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 16)
            } else if let narrative = narrative {
                VStack(alignment: .leading, spacing: 12) {
                    Text(narrative.summary)
                        .font(.subheadline)

                    if !narrative.achievements.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(narrative.achievements, id: \.self) { achievement in
                                Label(achievement, systemImage: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    if !narrative.focusAreas.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(narrative.focusAreas, id: \.self) { area in
                                Label(area, systemImage: "target")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    Text(narrative.trendAnalysis)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(narrative.motivation)
                        .font(.caption)
                        .italic()
                        .foregroundStyle(.purple)
                }
            } else {
                VStack(spacing: 8) {
                    Text("Tap refresh to generate AI-powered insights about your training patterns")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Generate Insights", action: onRefresh)
                        .font(.caption)
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .glassCard(material: .thin, cornerRadius: 20, padding: 20)
        .padding(.horizontal)
    }
}

// MARK: - Overview Cards

struct OverviewCardsView: View {
    let statistics: RideStatistics

    var body: some View {
        VStack(spacing: 16) {
            GlassSectionHeader("Overview", icon: "chart.bar.fill")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                GlassStatCard(
                    title: "Total Rides",
                    value: "\(statistics.totalRides)",
                    icon: "figure.equestrian.sports",
                    tint: AppColors.cardBlue
                )

                GlassStatCard(
                    title: "Total Distance",
                    value: statistics.formattedTotalDistance,
                    icon: "arrow.left.and.right",
                    tint: AppColors.cardGreen
                )

                GlassStatCard(
                    title: "Total Time",
                    value: statistics.formattedTotalDuration,
                    icon: "clock.fill",
                    tint: AppColors.cardOrange
                )

                GlassStatCard(
                    title: "Elevation",
                    value: String(format: "%.0f m", statistics.totalElevationGain),
                    icon: "mountain.2.fill",
                    tint: AppColors.cardPurple
                )

                GlassStatCard(
                    title: "Avg Distance",
                    value: statistics.formattedAverageDistance,
                    icon: "chart.line.uptrend.xyaxis",
                    tint: AppColors.cardTeal
                )

                GlassStatCard(
                    title: "Avg Speed",
                    value: statistics.formattedAverageSpeed,
                    icon: "speedometer",
                    tint: AppColors.cardRed
                )
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Weekly Activity Chart

struct WeeklyActivityChart: View {
    let data: [WeeklyDataPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassSectionHeader("Weekly Activity", icon: "chart.bar.xaxis")

            Chart(data) { week in
                BarMark(
                    x: .value("Week", week.formattedWeek),
                    y: .value("Distance", week.distanceKm)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.primary, AppColors.primary.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(6)
            }
            .chartYAxisLabel("Distance (km)")
            .frame(height: 200)

            HStack {
                ForEach(data) { week in
                    VStack(spacing: 4) {
                        Text("\(week.rideCount)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("rides")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .glassCard(material: .thin, cornerRadius: 20, padding: 20)
        .padding(.horizontal)
    }
}

// MARK: - Personal Records

struct PersonalRecordsView: View {
    let statistics: RideStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassSectionHeader("Personal Records", icon: "trophy.fill")

            VStack(spacing: 12) {
                if let longest = statistics.longestRide {
                    RecordRow(
                        icon: "arrow.left.and.right.circle.fill",
                        title: "Longest Ride",
                        value: longest.formattedDistance,
                        date: longest.formattedDate,
                        color: AppColors.cardGreen
                    )
                }

                if let fastest = statistics.fastestMaxSpeed {
                    RecordRow(
                        icon: "gauge.with.dots.needle.100percent",
                        title: "Top Speed",
                        value: fastest.formattedMaxSpeed,
                        date: fastest.formattedDate,
                        color: AppColors.cardRed
                    )
                }

                if let longestDuration = statistics.longestDuration {
                    RecordRow(
                        icon: "clock.fill",
                        title: "Longest Duration",
                        value: longestDuration.formattedDuration,
                        date: longestDuration.formattedDate,
                        color: AppColors.cardOrange
                    )
                }

                if let mostElevation = statistics.mostElevationGain {
                    RecordRow(
                        icon: "mountain.2.fill",
                        title: "Most Climbing",
                        value: mostElevation.formattedElevationGain,
                        date: mostElevation.formattedDate,
                        color: AppColors.cardPurple
                    )
                }
            }
        }
        .glassCard(material: .thin, cornerRadius: 20, padding: 20)
        .padding(.horizontal)
    }
}

struct RecordRow: View {
    let icon: String
    let title: String
    let value: String
    let date: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Streak Stats

struct StreakStatsView: View {
    let streak: TrainingStreak?
    let totalRides: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassSectionHeader("Training Streaks", icon: "flame.fill")

            if let streak = streak {
                VStack(spacing: 20) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(streakColor.opacity(0.2))
                                .frame(width: 72, height: 72)

                            Image(systemName: streak.streakIcon)
                                .font(.system(size: 32))
                                .foregroundStyle(streakColor)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Streak")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(streak.currentStreak)")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundStyle(streakColor)
                                Text("days")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }

                            Text(streak.streakMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    Divider()

                    HStack(spacing: 0) {
                        StreakStatItem(
                            icon: "trophy.fill",
                            title: "Longest Streak",
                            value: "\(streak.longestStreak)",
                            unit: "days",
                            color: AppColors.cardOrange
                        )

                        Divider()
                            .frame(height: 50)

                        StreakStatItem(
                            icon: "calendar",
                            title: "Training Days",
                            value: "\(streak.totalTrainingDays)",
                            unit: "total",
                            color: AppColors.cardBlue
                        )

                        Divider()
                            .frame(height: 50)

                        StreakStatItem(
                            icon: "figure.equestrian.sports",
                            title: "Total Rides",
                            value: "\(totalRides)",
                            unit: "rides",
                            color: AppColors.cardGreen
                        )
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "flame")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)

                    Text("Start riding to build your streak!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Complete rides on consecutive days to earn streak badges")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .glassCard(material: .thin, cornerRadius: 20, padding: 20)
        .padding(.horizontal)
    }

    private var streakColor: Color {
        guard let streak = streak else { return .gray }
        switch streak.currentStreak {
        case 0: return .gray
        case 1...6: return .orange
        case 7...29: return .yellow
        default: return .purple
        }
    }
}

struct StreakStatItem: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Gait Analysis

struct GaitAnalysisView: View {
    let statistics: RideStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassSectionHeader("Gait Distribution", icon: "figure.equestrian.sports")

            if statistics.gaitBreakdown.isEmpty {
                Text("No gait data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                HStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 130, height: 130)

                        Chart(statistics.gaitBreakdown, id: \.gait) { item in
                            SectorMark(
                                angle: .value("Duration", item.duration),
                                innerRadius: .ratio(0.55),
                                angularInset: 2
                            )
                            .foregroundStyle(gaitColor(item.gait))
                            .cornerRadius(4)
                        }
                        .frame(width: 120, height: 120)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(statistics.gaitBreakdown, id: \.gait) { item in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(gaitColor(item.gait))
                                    .frame(width: 12, height: 12)

                                Text(item.gait.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Spacer()

                                Text(String(format: "%.0f%%", item.percentage))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(gaitColor(item.gait))
                            }
                        }
                    }
                }

                Divider()
                    .padding(.vertical, 4)

                HStack {
                    Text("Total riding time")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatDuration(statistics.totalWalkTime + statistics.totalTrotTime + statistics.totalCanterTime + statistics.totalGallopTime))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .glassCard(material: .thin, cornerRadius: 20, padding: 20)
        .padding(.horizontal)
    }

    private func gaitColor(_ gait: GaitType) -> Color {
        AppColors.gait(gait)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }
}

// MARK: - Turn Balance Stats

struct TurnBalanceStatsView: View {
    let statistics: RideStatistics

    private var totalTurns: Int {
        statistics.totalLeftTurns + statistics.totalRightTurns
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassSectionHeader("Turn Balance", icon: "arrow.triangle.turn.up.right.diamond.fill")

            if totalTurns == 0 {
                Text("No turn data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 20) {
                    GlassProgressBar(
                        progress: Double(statistics.turnBalancePercent) / 100.0,
                        leftColor: AppColors.turnLeft,
                        rightColor: AppColors.turnRight,
                        height: 28
                    )

                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.turn.up.left")
                                    .foregroundStyle(AppColors.turnLeft)
                                Text("Left")
                                    .fontWeight(.medium)
                            }
                            .font(.subheadline)

                            Text("\(statistics.totalLeftTurns)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(AppColors.turnLeft)

                            Text("\(statistics.turnBalancePercent)%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(isBalanced ? AppColors.success.opacity(0.15) : AppColors.warning.opacity(0.15))
                                    .frame(width: 56, height: 56)

                                Image(systemName: isBalanced ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .font(.title)
                                    .foregroundStyle(isBalanced ? AppColors.success : AppColors.warning)
                            }
                            Text(isBalanced ? "Balanced" : "Uneven")
                                .font(.caption)
                                .fontWeight(.medium)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("Right")
                                    .fontWeight(.medium)
                                Image(systemName: "arrow.turn.up.right")
                                    .foregroundStyle(AppColors.turnRight)
                            }
                            .font(.subheadline)

                            Text("\(statistics.totalRightTurns)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(AppColors.turnRight)

                            Text("\(100 - statistics.turnBalancePercent)%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .glassCard(material: .thin, cornerRadius: 20, padding: 20)
        .padding(.horizontal)
    }

    private var isBalanced: Bool {
        statistics.turnBalancePercent >= 40 && statistics.turnBalancePercent <= 60
    }
}

// MARK: - Lead Balance Stats

struct LeadBalanceStatsView: View {
    let statistics: RideStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassSectionHeader("Lead Balance", icon: "arrow.left.arrow.right.circle.fill")

            VStack(spacing: 20) {
                GlassProgressBar(
                    progress: Double(statistics.leadBalancePercent) / 100.0,
                    leftColor: AppColors.turnLeft,
                    rightColor: AppColors.turnRight,
                    height: 28
                )

                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left.circle.fill")
                                .foregroundStyle(AppColors.turnLeft)
                            Text("Left Lead")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)

                        Text(formatDuration(statistics.totalLeftLeadDuration))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(AppColors.turnLeft)

                        Text("\(statistics.leadBalancePercent)%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(isBalanced ? AppColors.success.opacity(0.15) : AppColors.warning.opacity(0.15))
                                .frame(width: 56, height: 56)

                            Image(systemName: isBalanced ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.title)
                                .foregroundStyle(isBalanced ? AppColors.success : AppColors.warning)
                        }
                        Text(isBalanced ? "Balanced" : "Uneven")
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("Right Lead")
                                .fontWeight(.medium)
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(AppColors.turnRight)
                        }
                        .font(.subheadline)

                        Text(formatDuration(statistics.totalRightLeadDuration))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(AppColors.turnRight)

                        Text("\(100 - statistics.leadBalancePercent)%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .glassCard(material: .thin, cornerRadius: 20, padding: 20)
        .padding(.horizontal)
    }

    private var isBalanced: Bool {
        statistics.leadBalancePercent >= 40 && statistics.leadBalancePercent <= 60
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Quality Trends

struct QualityTrendsView: View {
    let weeklyTrends: [WeeklyTrendPoint]
    let statistics: RideStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassSectionHeader("Movement Quality", icon: "waveform.path.ecg")

            HStack(spacing: 24) {
                if statistics.averageSymmetry > 0 {
                    QualityStatCard(
                        title: "Avg Symmetry",
                        value: statistics.averageSymmetry,
                        icon: "arrow.left.and.right"
                    )
                }

                if statistics.averageRhythm > 0 {
                    QualityStatCard(
                        title: "Avg Rhythm",
                        value: statistics.averageRhythm,
                        icon: "metronome"
                    )
                }

                if statistics.totalTransitions > 0 {
                    VStack(spacing: 4) {
                        Text("\(statistics.totalTransitions)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(AppColors.primary)
                        Text("Transitions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(statistics.formattedTransitionQuality)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            if weeklyTrends.filter({ $0.rideCount > 0 }).count >= 2 {
                Divider()
                    .padding(.vertical, 4)

                Text("Weekly Trend")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Chart {
                    ForEach(weeklyTrends.filter { $0.averageSymmetry > 0 }) { week in
                        LineMark(
                            x: .value("Week", week.formattedWeek),
                            y: .value("Symmetry", week.averageSymmetry)
                        )
                        .foregroundStyle(AppColors.turnLeft)
                        .symbol(.circle)
                    }

                    ForEach(weeklyTrends.filter { $0.averageRhythm > 0 }) { week in
                        LineMark(
                            x: .value("Week", week.formattedWeek),
                            y: .value("Rhythm", week.averageRhythm)
                        )
                        .foregroundStyle(AppColors.turnRight)
                        .symbol(.diamond)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxisLabel("Score %")
                .frame(height: 150)

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppColors.turnLeft)
                            .frame(width: 8, height: 8)
                        Text("Symmetry")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "diamond.fill")
                            .font(.caption2)
                            .foregroundStyle(AppColors.turnRight)
                        Text("Rhythm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .glassCard(material: .thin, cornerRadius: 20, padding: 20)
        .padding(.horizontal)
    }
}

struct QualityStatCard: View {
    let title: String
    let value: Double
    let icon: String

    private var color: Color {
        switch value {
        case 0..<50: return AppColors.error
        case 50..<70: return AppColors.warning
        case 70..<85: return AppColors.success
        default: return AppColors.primary
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }

            Text(String(format: "%.0f%%", value))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
