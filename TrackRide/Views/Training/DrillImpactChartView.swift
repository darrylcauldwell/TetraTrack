//
//  DrillImpactChartView.swift
//  TrackRide
//
//  Visualizes correlations between drill performance and sport outcomes
//  Makes cross-sport transfer tangible by overlaying time series data.
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Drill Impact Chart View

/// Visualizes the relationship between drill training and sport performance
struct DrillImpactChartView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \UnifiedDrillSession.startDate, order: .forward)
    private var drillSessions: [UnifiedDrillSession]

    @Query(sort: \Ride.startDate, order: .forward)
    private var rides: [Ride]

    @State private var selectedDrillType: UnifiedDrillType?
    @State private var selectedMetric: PerformanceMetric = .riderStability
    @State private var showCorrelationDetails = false
    @State private var timeWindow: TimeWindow = .month3

    private let correlator = DrillPerformanceCorrelator()
    private let correlationService = CrossSportCorrelationService()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with metric selector
                headerSection

                // Main correlation chart
                if let drillType = selectedDrillType {
                    correlationChartSection(for: drillType)
                } else {
                    emptyStateView
                }

                // Correlation insights
                if !significantCorrelations.isEmpty {
                    correlationInsightsSection
                }

                // Drill type selector
                drillTypeSelectorSection
            }
            .padding()
        }
        .navigationTitle("Training Impact")
        .onAppear {
            // Auto-select first drill type with sufficient data
            if selectedDrillType == nil {
                selectedDrillType = drillTypesWithData.first
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Drill-to-Performance Correlation")
                .font(.headline)

            HStack {
                // Metric picker
                Menu {
                    ForEach(PerformanceMetric.allCases, id: \.self) { metric in
                        Button {
                            selectedMetric = metric
                        } label: {
                            Label(metric.displayName, systemImage: metric.icon)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: selectedMetric.icon)
                        Text(selectedMetric.displayName)
                        Image(systemName: "chevron.down")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppColors.cardBackground)
                    .clipShape(Capsule())
                }

                Spacer()

                // Time window picker
                Picker("Time Window", selection: $timeWindow) {
                    ForEach(TimeWindow.allCases, id: \.self) { window in
                        Text(window.displayName).tag(window)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Correlation Chart Section

    @ViewBuilder
    private func correlationChartSection(for drillType: UnifiedDrillType) -> some View {
        let drillData = filteredDrillData(for: drillType)
        let performanceData = filteredPerformanceData()
        let correlation = calculateCorrelation(drillData: drillData, performanceData: performanceData)

        VStack(alignment: .leading, spacing: 16) {
            // Chart header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(drillType.displayName)
                        .font(.title3.bold())
                    Text("vs \(selectedMetric.displayName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Correlation badge
                CorrelationBadge(coefficient: correlation.coefficient, sampleSize: correlation.sampleSize)
            }

            // Dual-axis chart
            if !drillData.isEmpty && !performanceData.isEmpty {
                DualAxisCorrelationChart(
                    drillData: drillData,
                    performanceData: performanceData,
                    drillLabel: drillType.displayName,
                    performanceLabel: selectedMetric.displayName
                )
                .frame(height: 240)
            } else {
                insufficientDataView
            }

            // Correlation interpretation
            if correlation.coefficient != 0 {
                CorrelationInterpretation(
                    coefficient: correlation.coefficient,
                    drillName: drillType.displayName,
                    metricName: selectedMetric.displayName,
                    sampleSize: correlation.sampleSize
                )
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Correlation Insights Section

    private var correlationInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Findings")
                .font(.headline)

            ForEach(significantCorrelations.prefix(3)) { correlation in
                CorrelationInsightRow(correlation: correlation)
            }

            if significantCorrelations.count > 3 {
                Button {
                    showCorrelationDetails = true
                } label: {
                    Text("View all \(significantCorrelations.count) correlations")
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showCorrelationDetails) {
            CorrelationDetailSheet(correlations: significantCorrelations)
        }
        .presentationBackground(Color.black)
    }

    // MARK: - Drill Type Selector

    private var drillTypeSelectorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Drill Type")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(drillTypesWithData, id: \.self) { drillType in
                    DrillTypeCard(
                        drillType: drillType,
                        sessionCount: sessionCount(for: drillType),
                        isSelected: selectedDrillType == drillType
                    ) {
                        selectedDrillType = drillType
                    }
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Empty States

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Drill Data Yet")
                .font(.headline)

            Text("Complete some training drills to see how they correlate with your riding performance.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var insufficientDataView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.orange)

            Text("Insufficient Data")
                .font(.subheadline.bold())

            Text("Need at least 5 drill sessions and 5 rides to calculate meaningful correlations.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Data Helpers

    private var drillTypesWithData: [UnifiedDrillType] {
        let grouped = Dictionary(grouping: drillSessions) { $0.drillType }
        return grouped.keys.sorted { $0.displayName < $1.displayName }
    }

    private func sessionCount(for drillType: UnifiedDrillType) -> Int {
        drillSessions.filter { $0.drillType == drillType }.count
    }

    private func filteredDrillData(for drillType: UnifiedDrillType) -> [TimeSeriesPoint] {
        let cutoff = timeWindow.cutoffDate
        return drillSessions
            .filter { $0.drillType == drillType && $0.startDate >= cutoff }
            .map { TimeSeriesPoint(date: $0.startDate, value: $0.score) }
    }

    private func filteredPerformanceData() -> [TimeSeriesPoint] {
        let cutoff = timeWindow.cutoffDate
        return rides
            .filter { $0.startDate >= cutoff }
            .compactMap { ride -> TimeSeriesPoint? in
                let value = selectedMetric.value(from: ride)
                guard value > 0 else { return nil }
                return TimeSeriesPoint(date: ride.startDate, value: value)
            }
    }

    private func calculateCorrelation(
        drillData: [TimeSeriesPoint],
        performanceData: [TimeSeriesPoint]
    ) -> (coefficient: Double, sampleSize: Int) {
        guard drillData.count >= 3, performanceData.count >= 3 else {
            return (0, 0)
        }

        // Align by week
        let calendar = Calendar.current
        func weekKey(_ date: Date) -> Int {
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return (components.yearForWeekOfYear ?? 0) * 100 + (components.weekOfYear ?? 0)
        }

        var drillByWeek: [Int: [Double]] = [:]
        var perfByWeek: [Int: [Double]] = [:]

        for point in drillData {
            drillByWeek[weekKey(point.date), default: []].append(point.value)
        }
        for point in performanceData {
            perfByWeek[weekKey(point.date), default: []].append(point.value)
        }

        // Find overlapping weeks
        var drillValues: [Double] = []
        var perfValues: [Double] = []

        for (week, drillScores) in drillByWeek {
            if let perfScores = perfByWeek[week] {
                drillValues.append(drillScores.reduce(0, +) / Double(drillScores.count))
                perfValues.append(perfScores.reduce(0, +) / Double(perfScores.count))
            }
        }

        guard drillValues.count >= 3 else { return (0, 0) }

        let coefficient = pearsonCorrelation(drillValues, perfValues)
        return (coefficient, drillValues.count)
    }

    private func pearsonCorrelation(_ x: [Double], _ y: [Double]) -> Double {
        guard x.count == y.count, x.count >= 3 else { return 0 }

        let n = Double(x.count)
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).map { $0 * $1 }.reduce(0, +)
        let sumX2 = x.map { $0 * $0 }.reduce(0, +)
        let sumY2 = y.map { $0 * $0 }.reduce(0, +)

        let numerator = (n * sumXY) - (sumX * sumY)
        let denominator = sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY))

        guard denominator > 0.001 else { return 0 }

        return numerator / denominator
    }

    private var significantCorrelations: [DrillCorrelationResult] {
        var results: [DrillCorrelationResult] = []

        for drillType in drillTypesWithData {
            let drillData = filteredDrillData(for: drillType)

            for metric in PerformanceMetric.allCases {
                let perfData = rides
                    .filter { $0.startDate >= timeWindow.cutoffDate }
                    .compactMap { ride -> TimeSeriesPoint? in
                        let value = metric.value(from: ride)
                        guard value > 0 else { return nil }
                        return TimeSeriesPoint(date: ride.startDate, value: value)
                    }

                let correlation = calculateCorrelation(drillData: drillData, performanceData: perfData)
                let significance = CorrelationSignificance(
                    coefficient: correlation.coefficient,
                    sampleSize: correlation.sampleSize
                )

                if significance != .none {
                    results.append(DrillCorrelationResult(
                        drillType: drillType,
                        metric: metric,
                        coefficient: correlation.coefficient,
                        significance: significance,
                        sampleSize: correlation.sampleSize
                    ))
                }
            }
        }

        return results.sorted { abs($0.coefficient) > abs($1.coefficient) }
    }
}

// MARK: - Supporting Types

struct TimeSeriesPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

enum TimeWindow: CaseIterable {
    case month1
    case month3
    case month6
    case year1

    var displayName: String {
        switch self {
        case .month1: return "1M"
        case .month3: return "3M"
        case .month6: return "6M"
        case .year1: return "1Y"
        }
    }

    var cutoffDate: Date {
        let calendar = Calendar.current
        switch self {
        case .month1: return calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        case .month3: return calendar.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        case .month6: return calendar.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        case .year1: return calendar.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        }
    }
}

enum PerformanceMetric: CaseIterable {
    case riderStability
    case impulsion
    case engagement
    case straightness
    case rhythmConsistency

    var displayName: String {
        switch self {
        case .riderStability: return "Rider Stability"
        case .impulsion: return "Impulsion"
        case .engagement: return "Engagement"
        case .straightness: return "Straightness"
        case .rhythmConsistency: return "Rhythm"
        }
    }

    var icon: String {
        switch self {
        case .riderStability: return "figure.equestrian.sports"
        case .impulsion: return "arrow.forward"
        case .engagement: return "arrow.up.forward"
        case .straightness: return "arrow.up"
        case .rhythmConsistency: return "metronome"
        }
    }

    func value(from ride: Ride) -> Double {
        switch self {
        case .riderStability: return ride.averageRiderStability
        case .impulsion: return ride.averageImpulsion
        case .engagement: return ride.averageEngagement
        case .straightness: return ride.averageStraightness
        case .rhythmConsistency:
            let avgRhythm = (ride.leftReinRhythm + ride.rightReinRhythm) / 2
            return avgRhythm > 0 ? avgRhythm : 0
        }
    }
}

struct DrillCorrelationResult: Identifiable {
    let id = UUID()
    let drillType: UnifiedDrillType
    let metric: PerformanceMetric
    let coefficient: Double
    let significance: CorrelationSignificance
    let sampleSize: Int

    var isPositive: Bool { coefficient > 0 }
}

// MARK: - Dual Axis Chart

struct DualAxisCorrelationChart: View {
    let drillData: [TimeSeriesPoint]
    let performanceData: [TimeSeriesPoint]
    let drillLabel: String
    let performanceLabel: String

    var body: some View {
        Chart {
            // Drill data (primary axis)
            ForEach(drillData) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Score", point.value),
                    series: .value("Series", "Drill")
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Score", point.value)
                )
                .foregroundStyle(.blue)
                .symbolSize(30)
            }

            // Performance data (scaled to same axis)
            ForEach(performanceData) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Score", point.value),
                    series: .value("Series", "Performance")
                )
                .foregroundStyle(.green)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Score", point.value)
                )
                .foregroundStyle(.green)
                .symbolSize(30)
            }
        }
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartLegend(position: .top, alignment: .leading) {
            HStack(spacing: 16) {
                LegendItem(color: .blue, label: drillLabel, style: .solid)
                LegendItem(color: .green, label: performanceLabel, style: .dashed)
            }
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    let style: LineStyle

    enum LineStyle {
        case solid, dashed
    }

    var body: some View {
        HStack(spacing: 4) {
            if style == .dashed {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(color)
                            .frame(width: 6, height: 2)
                    }
                }
                .frame(width: 20)
            } else {
                Rectangle()
                    .fill(color)
                    .frame(width: 20, height: 2)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Correlation Badge

struct CorrelationBadge: View {
    let coefficient: Double
    let sampleSize: Int

    private var significance: CorrelationSignificance {
        CorrelationSignificance(coefficient: coefficient, sampleSize: sampleSize)
    }

    private var color: Color {
        switch significance {
        case .strong: return coefficient > 0 ? .green : .red
        case .moderate: return coefficient > 0 ? .blue : .orange
        case .weak: return .gray
        case .none: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: coefficient > 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2)
                Text(String(format: "r = %.2f", coefficient))
                    .font(.caption.monospaced())
            }
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())

            Text("\(significance.rawValue) (\(sampleSize) pts)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Correlation Interpretation

struct CorrelationInterpretation: View {
    let coefficient: Double
    let drillName: String
    let metricName: String
    let sampleSize: Int

    private var significance: CorrelationSignificance {
        CorrelationSignificance(coefficient: coefficient, sampleSize: sampleSize)
    }

    private var message: String {
        let direction = coefficient > 0 ? "positive" : "negative"
        let impact = coefficient > 0 ? "improves" : "inversely affects"

        switch significance {
        case .strong:
            return "Strong \(direction) correlation: Your \(drillName) training \(impact) your \(metricName). This is a key training relationship to maintain."
        case .moderate:
            return "Moderate \(direction) correlation: There's a meaningful connection between \(drillName) practice and \(metricName). Continue this training focus."
        case .weak:
            return "Weak \(direction) correlation: Some relationship exists between \(drillName) and \(metricName), but other factors may be more influential."
        case .none:
            return "No significant correlation detected yet. More data points needed for reliable analysis."
        }
    }

    private var icon: String {
        switch significance {
        case .strong: return coefficient > 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
        case .moderate: return "arrow.triangle.2.circlepath"
        case .weak: return "questionmark.circle"
        case .none: return "minus.circle"
        }
    }

    private var iconColor: Color {
        switch significance {
        case .strong: return coefficient > 0 ? .green : .red
        case .moderate: return .blue
        case .weak: return .orange
        case .none: return .gray
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(iconColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Drill Type Card

struct DrillTypeCard: View {
    let drillType: UnifiedDrillType
    let sessionCount: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: drillType.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : .primary)

                Text(drillType.displayName)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isSelected ? .white : .primary)

                Text("\(sessionCount) sessions")
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue : AppColors.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Correlation Insight Row

struct CorrelationInsightRow: View {
    let correlation: DrillCorrelationResult

    var body: some View {
        HStack(spacing: 12) {
            // Direction indicator
            Image(systemName: correlation.isPositive ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                .font(.title3)
                .foregroundStyle(correlation.isPositive ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(correlation.drillType.displayName) \u{2192} \(correlation.metric.displayName)")
                    .font(.subheadline.bold())

                Text("\(correlation.significance.rawValue) \(correlation.isPositive ? "positive" : "negative") correlation (r = \(String(format: "%.2f", correlation.coefficient)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(AppColors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Correlation Detail Sheet

struct CorrelationDetailSheet: View {
    let correlations: [DrillCorrelationResult]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(correlations.filter { $0.significance == .strong }) { correlation in
                        CorrelationInsightRow(correlation: correlation)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("Strong Correlations")
                }

                Section {
                    ForEach(correlations.filter { $0.significance == .moderate }) { correlation in
                        CorrelationInsightRow(correlation: correlation)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("Moderate Correlations")
                }

                Section {
                    ForEach(correlations.filter { $0.significance == .weak }) { correlation in
                        CorrelationInsightRow(correlation: correlation)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("Weak Correlations")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("All Correlations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DrillImpactChartView()
    }
    .modelContainer(for: [UnifiedDrillSession.self, Ride.self], inMemory: true)
}
