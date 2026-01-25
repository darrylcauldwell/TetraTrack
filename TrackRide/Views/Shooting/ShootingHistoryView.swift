//
//  ShootingHistoryView.swift
//  TrackRide
//
//  History and aggregation views for shooting analysis.
//  Displays trends, patterns, and improvement suggestions.
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Shooting History View

struct ShootingHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TargetScanAnalysis.scanDate, order: .reverse) private var analyses: [TargetScanAnalysis]

    @State private var selectedTimeRange: TimeRange = .month
    @State private var selectedAnalysis: TargetScanAnalysis?
    @State private var showingDetail = false

    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case threeMonths = "3 Months"
        case year = "Year"
        case all = "All Time"

        var startDate: Date {
            let calendar = Calendar.current
            switch self {
            case .week: return calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            case .month: return calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            case .threeMonths: return calendar.date(byAdding: .month, value: -3, to: Date()) ?? Date()
            case .year: return calendar.date(byAdding: .year, value: -1, to: Date()) ?? Date()
            case .all: return Date.distantPast
            }
        }
    }

    var filteredAnalyses: [TargetScanAnalysis] {
        analyses.filter { $0.scanDate >= selectedTimeRange.startDate }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Time range picker
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if filteredAnalyses.isEmpty {
                    emptyStateView
                } else {
                    // Summary cards
                    summarySection

                    // Trend chart
                    trendChartSection

                    // Consistency chart
                    consistencyChartSection

                    // Session list
                    sessionListSection

                    // Improvement suggestions
                    improvementSection
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Shooting History")
        .sheet(item: $selectedAnalysis) { analysis in
            NavigationStack {
                AnalysisDetailView(analysis: analysis)
            }
        }
        .presentationBackground(Color.black)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Shooting Data")
                .font(.headline)

            Text("Scan target cards to track your shooting patterns over time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    SummaryCard(
                        title: "Sessions",
                        value: "\(filteredAnalyses.count)",
                        icon: "target",
                        color: .blue
                    )

                    SummaryCard(
                        title: "Total Shots",
                        value: "\(totalShots)",
                        icon: "circle.fill",
                        color: .green
                    )

                    SummaryCard(
                        title: "Avg Score",
                        value: String(format: "%.1f", averageScore),
                        icon: "chart.bar.fill",
                        color: .orange
                    )

                    SummaryCard(
                        title: "Best Group",
                        value: bestGroupingQuality?.displayText ?? "-",
                        icon: "star.fill",
                        color: .yellow
                    )
                }
                .padding(.horizontal)
            }
        }
    }

    private var totalShots: Int {
        filteredAnalyses.reduce(0) { $0 + $1.shotCount }
    }

    private var averageScore: Double {
        guard totalShots > 0 else { return 0 }
        let totalScore = filteredAnalyses.reduce(0) { $0 + $1.totalScore }
        return Double(totalScore) / Double(totalShots)
    }

    private var bestGroupingQuality: GroupingQuality? {
        filteredAnalyses.map { $0.groupingQuality }.min { a, b in
            GroupingQuality.allCases.firstIndex(of: a)! < GroupingQuality.allCases.firstIndex(of: b)!
        }
    }

    // MARK: - Trend Chart

    private var trendChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Score Trend")
                .font(.headline)
                .padding(.horizontal)

            if filteredAnalyses.count >= 2 {
                Chart {
                    ForEach(filteredAnalyses.reversed()) { analysis in
                        LineMark(
                            x: .value("Date", analysis.scanDate),
                            y: .value("Avg Score", analysis.averageScore)
                        )
                        .foregroundStyle(.blue)
                        .symbol(Circle())

                        PointMark(
                            x: .value("Date", analysis.scanDate),
                            y: .value("Avg Score", analysis.averageScore)
                        )
                        .foregroundStyle(.blue)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartYScale(domain: 0...10)
                .frame(height: 200)
                .padding(.horizontal)
            } else {
                Text("Need at least 2 sessions to show trend")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Consistency Chart

    private var consistencyChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Consistency (Grouping Quality)")
                .font(.headline)
                .padding(.horizontal)

            if filteredAnalyses.count >= 2 {
                Chart {
                    ForEach(filteredAnalyses.reversed()) { analysis in
                        BarMark(
                            x: .value("Date", analysis.scanDate),
                            y: .value("Spread", analysis.totalSpread)
                        )
                        .foregroundStyle(groupingColor(for: analysis.groupingQuality))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 150)
                .padding(.horizontal)

                // Legend
                HStack(spacing: 16) {
                    ForEach(GroupingQuality.allCases, id: \.self) { quality in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(groupingColor(for: quality))
                                .frame(width: 8, height: 8)
                            Text(quality.displayText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
            } else {
                Text("Need at least 2 sessions to show consistency")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func groupingColor(for quality: GroupingQuality) -> Color {
        switch quality {
        case .excellent: return .yellow
        case .good: return .green
        case .fair: return .orange
        case .poor: return .red
        }
    }

    // MARK: - Session List

    private var sessionListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.headline)
                .padding(.horizontal)

            LazyVStack(spacing: 8) {
                ForEach(filteredAnalyses.prefix(10)) { analysis in
                    SessionRow(analysis: analysis)
                        .onTapGesture {
                            selectedAnalysis = analysis
                        }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Improvement Section

    private var improvementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("Improvement Suggestions")
                    .font(.headline)
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(improvementSuggestions, id: \.self) { suggestion in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.caption)
                        Text(suggestion)
                            .font(.subheadline)
                    }
                }
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    private var improvementSuggestions: [String] {
        guard !filteredAnalyses.isEmpty else { return [] }

        var suggestions: [String] = []

        // Analyze overall bias
        let avgHorizontalBias = filteredAnalyses.map { $0.horizontalBias }.reduce(0, +) / Double(filteredAnalyses.count)
        let avgVerticalBias = filteredAnalyses.map { $0.verticalBias }.reduce(0, +) / Double(filteredAnalyses.count)

        if avgHorizontalBias > 0.1 {
            suggestions.append("Consistent right bias detected - check sight alignment or grip")
        } else if avgHorizontalBias < -0.1 {
            suggestions.append("Consistent left bias detected - review trigger technique")
        }

        if avgVerticalBias > 0.1 {
            suggestions.append("Shots trending low - focus on follow-through")
        } else if avgVerticalBias < -0.1 {
            suggestions.append("Shots trending high - check front sight alignment")
        }

        // Analyze consistency trend
        if filteredAnalyses.count >= 3 {
            let recentSpread = filteredAnalyses.prefix(3).map { $0.totalSpread }.reduce(0, +) / 3
            let olderSpread = filteredAnalyses.dropFirst(3).map { $0.totalSpread }.reduce(0, +) / Double(max(1, filteredAnalyses.count - 3))

            if recentSpread > olderSpread * 1.2 {
                suggestions.append("Consistency declining recently - consider reviewing fundamentals")
            } else if recentSpread < olderSpread * 0.8 {
                suggestions.append("Great progress! Your consistency is improving")
            }
        }

        // Analyze grouping quality
        let poorCount = filteredAnalyses.filter { $0.groupingQuality == .poor }.count
        if poorCount > filteredAnalyses.count / 2 {
            suggestions.append("Focus on stability drills to improve grouping")
        }

        if suggestions.isEmpty {
            suggestions.append("Keep up the good work! Consider setting new goals")
        }

        return suggestions
    }
}

// MARK: - Summary Card

private struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title2.bold())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 80)
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Session Row

private struct SessionRow: View {
    let analysis: TargetScanAnalysis

    var body: some View {
        HStack {
            // Grouping indicator
            Circle()
                .fill(groupingColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(analysis.formattedDate)
                    .font(.subheadline)

                Text("\(analysis.shotCount) shots, avg \(String(format: "%.1f", analysis.averageScore))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(analysis.totalScore)")
                    .font(.headline)

                Text(analysis.groupingQuality.displayText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var groupingColor: Color {
        switch analysis.groupingQuality {
        case .excellent: return .yellow
        case .good: return .green
        case .fair: return .orange
        case .poor: return .red
        }
    }
}

// MARK: - Analysis Detail View

struct AnalysisDetailView: View {
    let analysis: TargetScanAnalysis
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text(analysis.formattedDate)
                        .font(.headline)

                    HStack(spacing: 16) {
                        StatBadge(label: "Shots", value: "\(analysis.shotCount)")
                        StatBadge(label: "Total", value: "\(analysis.totalScore)")
                        StatBadge(label: "Average", value: String(format: "%.1f", analysis.averageScore))
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Shot pattern visualization
                if !analysis.shotPositions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Shot Pattern")
                            .font(.headline)

                        PatternVisualizationView(shots: analysis.shotPositions)
                            .frame(height: 220)
                    }
                    .padding()
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Pattern analysis
                if let patternAnalysis = analysis.patternAnalysis {
                    EnhancedPatternAnalysisView(analysis: patternAnalysis)
                }

                // Bias analysis
                VStack(alignment: .leading, spacing: 12) {
                    Text("Position Analysis")
                        .font(.headline)

                    HStack {
                        BiasIndicator(
                            label: "Horizontal",
                            value: analysis.horizontalBias,
                            description: analysis.horizontalBias > 0.05 ? "Right" :
                                        analysis.horizontalBias < -0.05 ? "Left" : "Centered"
                        )

                        Divider()

                        BiasIndicator(
                            label: "Vertical",
                            value: analysis.verticalBias,
                            description: analysis.verticalBias > 0.05 ? "Low" :
                                        analysis.verticalBias < -0.05 ? "High" : "Centered"
                        )
                    }
                }
                .padding()
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Grouping quality
                VStack(alignment: .leading, spacing: 12) {
                    Text("Grouping Quality")
                        .font(.headline)

                    HStack {
                        Image(systemName: analysis.groupingQuality.icon)
                            .font(.title)
                            .foregroundStyle(groupingColor(for: analysis.groupingQuality))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(analysis.groupingQuality.displayText)
                                .font(.title3.bold())

                            Text("Spread: \(String(format: "%.3f", analysis.totalSpread))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                }
                .padding()
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Detection statistics
                if analysis.autoDetectedCount > 0 || analysis.userAddedCount > 0 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Detection Method")
                            .font(.headline)

                        Text(analysis.detectionBreakdown)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Notes
                if !analysis.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)

                        Text(analysis.notes)
                            .font(.subheadline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .navigationTitle("Session Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func groupingColor(for quality: GroupingQuality) -> Color {
        switch quality {
        case .excellent: return .yellow
        case .good: return .green
        case .fair: return .orange
        case .poor: return .red
        }
    }
}

// MARK: - Supporting Views

private struct StatBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct BiasIndicator: View {
    let label: String
    let value: Double
    let description: String

    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Visual indicator
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 8)

                Circle()
                    .fill(indicatorColor)
                    .frame(width: 12, height: 12)
                    .offset(x: value * 40)
            }

            Text(description)
                .font(.caption.bold())
                .foregroundStyle(indicatorColor)
        }
        .frame(maxWidth: .infinity)
    }

    private var indicatorColor: Color {
        if abs(value) < 0.05 { return .green }
        if abs(value) < 0.10 { return .orange }
        return .red
    }
}

private struct PatternVisualizationView: View {
    let shots: [ScanShot]

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxRadius = min(size.width, size.height) / 2

            ZStack {
                // Stadium-shaped scoring rings (from outer to inner)
                ForEach(TetrathlonTargetGeometry.normalizedScoringRadii.reversed(), id: \.score) { ring in
                    StadiumRingShape(normalizedRadius: ring.normalizedRadius, maxRadius: maxRadius)
                        .stroke(Color.secondary.opacity(ring.score == 10 ? 0.4 : 0.2), lineWidth: ring.score == 10 ? 2 : 1)
                        .frame(width: size.width, height: size.height)
                }

                // Center marker
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 12, height: 12)
                    .position(center)

                // Shots
                ForEach(shots) { shot in
                    let position = shot.normalizedPosition
                    let screenX = center.x + position.x * maxRadius
                    let screenY = center.y + position.y * maxRadius  // Normalized Y is already in screen space
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .position(x: screenX, y: screenY)
                }

                // MPI marker
                if shots.count >= 3 {
                    let avgX = shots.map { $0.normalizedPosition.x }.reduce(0, +) / Double(shots.count)
                    let avgY = shots.map { $0.normalizedPosition.y }.reduce(0, +) / Double(shots.count)

                    Circle()
                        .stroke(Color.orange, lineWidth: 2)
                        .frame(width: 16, height: 16)
                        .position(
                            x: center.x + avgX * maxRadius,
                            y: center.y + avgY * maxRadius
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }
}

private struct EnhancedPatternAnalysisView: View {
    let analysis: PatternAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pattern Analysis")
                .font(.headline)

            // Metrics grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetricTile(
                    label: "Standard Deviation",
                    value: String(format: "%.3f", analysis.standardDeviation),
                    rating: analysis.consistencyRating.rawValue
                )

                MetricTile(
                    label: "Extreme Spread",
                    value: String(format: "%.3f", analysis.extremeSpread),
                    rating: nil
                )

                MetricTile(
                    label: "CEP (50%)",
                    value: String(format: "%.3f", analysis.cep50),
                    rating: nil
                )

                MetricTile(
                    label: "CEP (90%)",
                    value: String(format: "%.3f", analysis.cep90),
                    rating: nil
                )
            }

            // Bias description
            if let biasDescription = analysis.directionalBias.description {
                HStack {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .foregroundStyle(.blue)
                    Text(biasDescription)
                        .font(.subheadline)
                }
            }

            // Coaching suggestion
            if let suggestion = analysis.directionalBias.coachingSuggestion {
                HStack(alignment: .top) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text(suggestion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct MetricTile: View {
    let label: String
    let value: String
    let rating: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text(value)
                    .font(.subheadline.bold())

                if let rating = rating {
                    Text(rating)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ratingColor.opacity(0.2))
                        .foregroundStyle(ratingColor)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(AppColors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var ratingColor: Color {
        switch rating {
        case "Excellent": return .yellow
        case "Good": return .green
        case "Fair": return .orange
        default: return .red
        }
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        ShootingHistoryView()
    }
}
