//
//  ShootingInsightsView.swift
//  TetraTrack
//
//  Pressure analysis view showing performance trends by context.
//  Helps athletes understand how pressure affects their shooting.
//

import SwiftUI
import Charts

// MARK: - Shooting Insights View

struct ShootingInsightsView: View {
    let onDismiss: () -> Void

    @State private var historyManager = ShotPatternHistoryManager()
    @State private var selectedTimeRange: TimeRange = .allTime

    enum TimeRange: String, CaseIterable {
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case allTime = "All Time"

        var dateFilter: DateFilterOption {
            switch self {
            case .thisWeek: return .thisWeek
            case .thisMonth: return .thisMonth
            case .allTime: return .allTime
            }
        }
    }

    private var allPatterns: [StoredTargetPattern] {
        historyManager.getHistory(dateFilter: selectedTimeRange.dateFilter)
    }

    private var freePracticePatterns: [StoredTargetPattern] {
        allPatterns.filter { $0.sessionType == .freePractice }
    }

    private var trainingPatterns: [StoredTargetPattern] {
        allPatterns.filter { $0.sessionType == .competitionTraining || $0.sessionType == .tetrathlonPractice }
    }

    private var competitionPatterns: [StoredTargetPattern] {
        allPatterns.filter { $0.sessionType == .competition }
    }

    var body: some View {
        NavigationStack {
            Group {
                if allPatterns.isEmpty {
                    emptyStateView
                } else {
                    contentView
                }
            }
            .navigationTitle("Pressure Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onDismiss)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No Data Yet")
                .font(.title2.bold())

            Text("Complete some shooting sessions to see how pressure affects your performance.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: onDismiss) {
                Text("Start Practicing")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(AppColors.primary)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Content View

    private var contentView: some View {
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

                // Pressure level chart
                pressureLevelChartSection

                // Context comparison cards
                contextComparisonSection

                // Pattern comparison (if multiple contexts have data)
                if freePracticePatterns.count >= 3 && (trainingPatterns.count >= 3 || competitionPatterns.count >= 3) {
                    patternComparisonSection
                }

                // Key insights
                keyInsightsSection
            }
            .padding(.vertical)
        }
    }

    // MARK: - Pressure Level Chart

    private var pressureLevelChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance by Pressure Level")
                .font(.headline)
                .padding(.horizontal)

            Chart {
                // Free Practice (Level 1)
                if !freePracticePatterns.isEmpty {
                    let avgRadius = freePracticePatterns.map { $0.clusterRadius }.reduce(0, +) / Double(freePracticePatterns.count)
                    BarMark(
                        x: .value("Context", "Free Practice"),
                        y: .value("Avg Spread", avgRadius)
                    )
                    .foregroundStyle(AppColors.shootingFreePractice)
                    .annotation(position: .top) {
                        Text(String(format: "%.2f", avgRadius))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Training (Level 2)
                if !trainingPatterns.isEmpty {
                    let avgRadius = trainingPatterns.map { $0.clusterRadius }.reduce(0, +) / Double(trainingPatterns.count)
                    BarMark(
                        x: .value("Context", "Training"),
                        y: .value("Avg Spread", avgRadius)
                    )
                    .foregroundStyle(AppColors.shootingTraining)
                    .annotation(position: .top) {
                        Text(String(format: "%.2f", avgRadius))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Competition (Level 3)
                if !competitionPatterns.isEmpty {
                    let avgRadius = competitionPatterns.map { $0.clusterRadius }.reduce(0, +) / Double(competitionPatterns.count)
                    BarMark(
                        x: .value("Context", "Competition"),
                        y: .value("Avg Spread", avgRadius)
                    )
                    .foregroundStyle(AppColors.shootingCompetition)
                    .annotation(position: .top) {
                        Text(String(format: "%.2f", avgRadius))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartYAxisLabel("Average Spread (lower = tighter)")
            .frame(height: 200)
            .padding(.horizontal)

            // Legend
            HStack(spacing: 16) {
                PressureLegendItem(color: AppColors.shootingFreePractice, label: "Free Practice", level: 1)
                PressureLegendItem(color: AppColors.shootingTraining, label: "Training", level: 2)
                PressureLegendItem(color: AppColors.shootingCompetition, label: "Competition", level: 3)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Context Comparison Cards

    private var contextComparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Context")
                .font(.headline)
                .padding(.horizontal)

            HStack(spacing: 12) {
                ContextStatCard(
                    title: "Free Practice",
                    icon: "target",
                    color: AppColors.shootingFreePractice,
                    patterns: freePracticePatterns
                )

                ContextStatCard(
                    title: "Training",
                    icon: "figure.run",
                    color: AppColors.shootingTraining,
                    patterns: trainingPatterns
                )

                ContextStatCard(
                    title: "Competition",
                    icon: "trophy.fill",
                    color: AppColors.shootingCompetition,
                    patterns: competitionPatterns
                )
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Pattern Comparison Section

    private var patternComparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pattern Comparison")
                .font(.headline)
                .padding(.horizontal)

            HStack(spacing: 20) {
                // Free Practice Pattern
                if freePracticePatterns.count >= 3 {
                    PatternPreviewCard(
                        title: "Free Practice",
                        color: AppColors.shootingFreePractice,
                        patterns: freePracticePatterns
                    )
                }

                // Higher Pressure Pattern
                let higherPressurePatterns = competitionPatterns.isEmpty ? trainingPatterns : competitionPatterns
                let higherPressureTitle = competitionPatterns.isEmpty ? "Training" : "Competition"
                let higherPressureColor: Color = competitionPatterns.isEmpty ? AppColors.shootingTraining : AppColors.shootingCompetition

                if higherPressurePatterns.count >= 3 {
                    PatternPreviewCard(
                        title: higherPressureTitle,
                        color: higherPressureColor,
                        patterns: higherPressurePatterns
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Key Insights Section

    private var keyInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(AppColors.tipIndicator)
                Text("Key Insights")
                    .font(.headline)
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(generateInsights(), id: \.self) { insight in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(AppColors.primary)
                            .font(.caption)
                        Text(insight)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    // MARK: - Insight Generation

    private func generateInsights() -> [String] {
        var insights: [String] = []

        // Compare free practice vs higher pressure
        if !freePracticePatterns.isEmpty && (!trainingPatterns.isEmpty || !competitionPatterns.isEmpty) {
            let fpAvg = freePracticePatterns.map { $0.clusterRadius }.reduce(0, +) / Double(freePracticePatterns.count)

            let higherPressurePatterns = competitionPatterns.isEmpty ? trainingPatterns : competitionPatterns
            let higherPressureLabel = competitionPatterns.isEmpty ? "training" : "competition"

            if !higherPressurePatterns.isEmpty {
                let hpAvg = higherPressurePatterns.map { $0.clusterRadius }.reduce(0, +) / Double(higherPressurePatterns.count)

                let percentChange = ((hpAvg - fpAvg) / fpAvg) * 100

                if percentChange > 15 {
                    insights.append("Your groups widen by \(Int(percentChange))% under \(higherPressureLabel) pressure. Mental preparation exercises may help.")
                } else if percentChange < -10 {
                    insights.append("Interestingly, you shoot tighter groups under \(higherPressureLabel) pressure - you may thrive with some stakes!")
                } else {
                    insights.append("Your consistency stays steady across pressure levels - that's a great sign of mental resilience.")
                }
            }
        }

        // Session count insights
        if freePracticePatterns.count > 10 && trainingPatterns.isEmpty && competitionPatterns.isEmpty {
            insights.append("Consider adding some competition training sessions to practice under pressure.")
        }

        if competitionPatterns.count >= 5 && trainingPatterns.count < 3 {
            insights.append("Competition training sessions can bridge the gap between free practice and competitions.")
        }

        // Data sufficiency
        if allPatterns.count < 10 {
            insights.append("Keep practicing! More data will provide more accurate insights.")
        }

        if insights.isEmpty {
            insights.append("Keep up the consistent practice across different contexts.")
        }

        return insights
    }
}

// MARK: - Supporting Views

private struct PressureLegendItem: View {
    let color: Color
    let label: String
    let level: Int

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            // Pressure dots
            HStack(spacing: 1) {
                ForEach(1...3, id: \.self) { i in
                    Circle()
                        .fill(i <= level ? color : AppColors.inactive.opacity(0.3))
                        .frame(width: 4, height: 4)
                }
            }
        }
    }
}

private struct ContextStatCard: View {
    let title: String
    let icon: String
    let color: Color
    let patterns: [StoredTargetPattern]

    private var avgSpread: Double {
        guard !patterns.isEmpty else { return 0 }
        return patterns.map { $0.clusterRadius }.reduce(0, +) / Double(patterns.count)
    }

    private var totalShots: Int {
        patterns.map { $0.shotCount }.reduce(0, +)
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text("\(patterns.count)")
                .font(.title2.bold())

            Text("sessions")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !patterns.isEmpty {
                Divider()
                    .padding(.vertical, 4)

                VStack(spacing: 2) {
                    Text(String(format: "%.2f", avgSpread))
                        .font(.subheadline.bold())
                    Text("avg spread")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppColors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct PatternPreviewCard: View {
    let title: String
    let color: Color
    let patterns: [StoredTargetPattern]

    private var avgMpiX: Double {
        patterns.map { $0.clusterMpiX }.reduce(0, +) / Double(patterns.count)
    }

    private var avgMpiY: Double {
        patterns.map { $0.clusterMpiY }.reduce(0, +) / Double(patterns.count)
    }

    private var avgRadius: Double {
        patterns.map { $0.clusterRadius }.reduce(0, +) / Double(patterns.count)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(color)

            // Mini target visualization
            GeometryReader { geometry in
                let size = geometry.size
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxRadius = min(size.width, size.height) / 2 - 4

                ZStack {
                    // Target rings
                    ForEach(1...3, id: \.self) { ring in
                        Circle()
                            .stroke(AppColors.inactive.opacity(0.3), lineWidth: 1)
                            .frame(width: CGFloat(ring) * maxRadius * 2 / 3, height: CGFloat(ring) * maxRadius * 2 / 3)
                    }

                    // Center point
                    Circle()
                        .fill(AppColors.autoCenter.opacity(0.5))
                        .frame(width: 6, height: 6)
                        .position(center)

                    // Aggregate MPI
                    let mpiX = center.x + avgMpiX * maxRadius
                    let mpiY = center.y + avgMpiY * maxRadius

                    Circle()
                        .fill(color)
                        .frame(width: 10, height: 10)
                        .position(x: mpiX, y: mpiY)

                    // Group radius indicator
                    Circle()
                        .stroke(color.opacity(0.5), lineWidth: 2)
                        .frame(width: avgRadius * maxRadius * 2, height: avgRadius * maxRadius * 2)
                        .position(x: mpiX, y: mpiY)
                }
            }
            .frame(width: 100, height: 100)

            // Stats
            VStack(spacing: 2) {
                Text(String(format: "%.2f", avgRadius))
                    .font(.subheadline.bold())
                Text("spread")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Preview

#Preview {
    ShootingInsightsView(onDismiss: {})
}
