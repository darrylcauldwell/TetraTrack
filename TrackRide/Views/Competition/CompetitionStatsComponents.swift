//
//  CompetitionStatsComponents.swift
//  TrackRide
//
//  Extracted subviews for CompetitionStatsView
//

import SwiftUI
import Charts

// MARK: - Competition Type Filter

struct CompetitionTypeFilterView: View {
    @Binding var selectedType: CompetitionTypeFilter

    var body: some View {
        HStack {
            Text("Competition Type")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Menu {
                ForEach(CompetitionTypeFilter.allCases, id: \.self) { type in
                    Button {
                        selectedType = type
                    } label: {
                        if selectedType == type {
                            Label(type.displayName, systemImage: "checkmark")
                        } else {
                            Text(type.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedType.displayName)
                        .font(.subheadline.weight(.medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(AppColors.primary)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Overview Cards

struct CompetitionOverviewCards: View {
    let statistics: CompetitionStatistics

    var body: some View {
        VStack(spacing: 16) {
            GlassSectionHeader("Overview", icon: "chart.bar.fill")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                GlassStatCard(
                    title: "Completed",
                    value: "\(statistics.completedCompetitions)",
                    icon: "flag.checkered",
                    tint: AppColors.cardBlue
                )

                GlassStatCard(
                    title: "Avg Points",
                    value: statistics.formattedAverageTotalPoints,
                    icon: "chart.line.uptrend.xyaxis",
                    tint: AppColors.cardGreen
                )

                GlassStatCard(
                    title: "Total Points",
                    value: statistics.formattedTotalPoints,
                    icon: "sum",
                    tint: AppColors.cardOrange
                )

                GlassStatCard(
                    title: "Tetrathlons",
                    value: "\(statistics.tetrathlonCount)",
                    icon: "star.fill",
                    tint: AppColors.cardPurple
                )
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Personal Bests View

struct CompetitionPersonalBestsView: View {
    let statistics: CompetitionStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            GlassSectionHeader("Personal Bests", icon: "trophy.fill")

            VStack(spacing: 16) {
                if let bestShooting = statistics.bestShooting {
                    CompetitionPBRow(
                        pb: bestShooting,
                        icon: "target",
                        color: AppColors.cardRed
                    )
                }

                if let bestSwimming = statistics.bestSwimming {
                    CompetitionPBRow(
                        pb: bestSwimming,
                        icon: "figure.pool.swim",
                        color: AppColors.cardBlue
                    )
                }

                if let bestRunning = statistics.bestRunning {
                    CompetitionPBRow(
                        pb: bestRunning,
                        icon: "figure.run",
                        color: AppColors.cardGreen
                    )
                }

                if let bestRiding = statistics.bestRiding {
                    CompetitionPBRow(
                        pb: bestRiding,
                        icon: "figure.equestrian.sports",
                        color: AppColors.cardOrange
                    )
                }

                if let bestTotal = statistics.bestTotal {
                    Divider()
                        .padding(.vertical, 8)

                    CompetitionPBRow(
                        pb: bestTotal,
                        icon: "medal.fill",
                        color: AppColors.cardPurple
                    )
                }
            }
        }
        .glassCard(material: .thin, cornerRadius: 20, padding: 24)
        .padding(.horizontal)
    }
}

// MARK: - PB Row

struct CompetitionPBRow: View {
    let pb: CompetitionPB
    let icon: String
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
                Text(pb.discipline)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.caption2)
                    Text(pb.venue)
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(pb.formattedDate)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(pb.formattedValue)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Trend Chart

struct CompetitionTrendChart: View {
    let trendPoints: [DisciplineTrendPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassSectionHeader("Points Trend", icon: "chart.line.uptrend.xyaxis")

            Chart(trendPoints.filter { $0.totalPoints != nil }) { point in
                LineMark(
                    x: .value("Date", point.formattedDate),
                    y: .value("Points", point.totalPoints ?? 0)
                )
                .foregroundStyle(AppColors.primary)
                .symbol(.circle)

                AreaMark(
                    x: .value("Date", point.formattedDate),
                    y: .value("Points", point.totalPoints ?? 0)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.primary.opacity(0.3), AppColors.primary.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .frame(height: 200)
        }
        .glassCard(material: .thin, cornerRadius: 20, padding: 20)
        .padding(.horizontal)
    }
}

// MARK: - Discipline Breakdown Chart

struct DisciplineBreakdownChart: View {
    let statistics: CompetitionStatistics

    private var disciplineData: [(name: String, points: Double, color: Color)] {
        var data: [(name: String, points: Double, color: Color)] = []

        if statistics.averageShootingPoints > 0 {
            data.append(("Shooting", statistics.averageShootingPoints, AppColors.cardRed))
        }
        if statistics.averageSwimmingPoints > 0 {
            data.append(("Swimming", statistics.averageSwimmingPoints, AppColors.cardBlue))
        }
        if statistics.averageRunningPoints > 0 {
            data.append(("Running", statistics.averageRunningPoints, AppColors.cardGreen))
        }
        if statistics.averageRidingPoints > 0 {
            data.append(("Riding", statistics.averageRidingPoints, AppColors.cardOrange))
        }

        return data
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassSectionHeader("Average Points by Discipline", icon: "chart.bar.fill")

            if disciplineData.isEmpty {
                Text("No discipline data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                Chart(disciplineData, id: \.name) { item in
                    BarMark(
                        x: .value("Discipline", item.name),
                        y: .value("Points", item.points)
                    )
                    .foregroundStyle(item.color)
                    .cornerRadius(6)
                }
                .chartYAxisLabel("Avg Points")
                .frame(height: 200)

                // Legend
                HStack(spacing: 16) {
                    ForEach(disciplineData, id: \.name) { item in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 8, height: 8)
                            Text(item.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .glassCard(material: .thin, cornerRadius: 20, padding: 20)
        .padding(.horizontal)
    }
}

// MARK: - Apple Intelligence Insights Section

@available(iOS 26.0, *)
struct CompetitionInsightsSection: View {
    let performanceSummary: CompetitionPerformanceSummary?
    let trendAnalysis: CompetitionTrendAnalysis?
    let weatherAnalysis: WeatherImpactAnalysis?
    let isLoading: Bool
    let error: String?
    let onRefresh: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                GlassSectionHeader("Insights", icon: "sparkles")

                Spacer()

                Text("Apple Intelligence")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal)

            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing your performance...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .glassCard(material: .thin, cornerRadius: 16, padding: 16)
                .padding(.horizontal)
            } else if let error = error {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .glassCard(material: .thin, cornerRadius: 16, padding: 16)
                .padding(.horizontal)
            } else {
                VStack(spacing: 12) {
                    // Performance Summary Card
                    if let summary = performanceSummary {
                        InsightCard(
                            title: "Performance Summary",
                            icon: "chart.bar.fill",
                            color: AppColors.cardBlue,
                            content: summary.summary,
                            detail: "Strongest: \(summary.strongestDiscipline) (\(summary.strongestContribution)%)"
                        )
                    }

                    // Trend Analysis Card
                    if let trends = trendAnalysis {
                        InsightCard(
                            title: "Trend Analysis",
                            icon: trendIcon(for: trends.overallTrend),
                            color: trendColor(for: trends.overallTrend),
                            content: trends.summary,
                            detail: trends.actionableInsight
                        )
                    }

                    // Weather Impact Card
                    if let weather = weatherAnalysis {
                        InsightCard(
                            title: "Weather Impact",
                            icon: "cloud.sun.fill",
                            color: AppColors.cardOrange,
                            content: weather.summary,
                            detail: "Best: \(weather.bestConditions)"
                        )
                    }

                    // Refresh button
                    Button {
                        Task { await onRefresh() }
                    } label: {
                        Label("Refresh Insights", systemImage: "arrow.clockwise")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }
                .padding(.horizontal)
            }
        }
    }

    private func trendIcon(for trend: String) -> String {
        switch trend.lowercased() {
        case "improving": return "chart.line.uptrend.xyaxis"
        case "declining": return "chart.line.downtrend.xyaxis"
        default: return "chart.line.flattrend.xyaxis"
        }
    }

    private func trendColor(for trend: String) -> Color {
        switch trend.lowercased() {
        case "improving": return AppColors.cardGreen
        case "declining": return AppColors.cardRed
        default: return AppColors.cardOrange
        }
    }
}

// MARK: - Insight Card

struct InsightCard: View {
    let title: String
    let icon: String
    let color: Color
    let content: String
    let detail: String?

    init(title: String, icon: String, color: Color, content: String, detail: String? = nil) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(color)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Text(content)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let detail = detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
