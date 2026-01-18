//
//  ShootingHistoryAggregateView.swift
//  TrackRide
//
//  Historical aggregate view for shooting patterns with filtering, visualization, and insights.
//

import SwiftUI
import Charts

// MARK: - Main Aggregate View

struct ShootingHistoryAggregateView: View {
    let onDismiss: () -> Void

    @State private var historyManager = ShotPatternHistoryManager()
    @State private var historyService: ShootingHistoryService?

    // Filter state
    @State private var selectedDateFilter: DateFilterOption = .allTime
    @State private var selectedSessionTypes: Set<ShootingSessionType> = Set(ShootingSessionType.allCases)

    // Display state
    @State private var displayMode: ShotDisplayMode = .points
    @State private var showingSessionList = false
    @State private var selectedPattern: StoredTargetPattern?

    // Computed filtered patterns
    private var filteredPatterns: [StoredTargetPattern] {
        historyManager.getHistory(
            dateFilter: selectedDateFilter,
            sessionTypes: selectedSessionTypes.isEmpty ? nil : selectedSessionTypes
        )
    }

    private var metrics: AggregatedShootingMetrics {
        historyService?.computeMetrics(patterns: filteredPatterns) ?? AggregatedShootingMetrics(
            averageImpactPoint: .zero,
            groupRadius: 0,
            offset: 0,
            outliersCount: 0,
            totalShots: 0,
            clusterShots: 0,
            sessionCount: 0,
            shotsByDay: [:],
            radiusTrend: []
        )
    }

    private var insights: ShootingInsights {
        historyService?.generateInsights(metrics: metrics, patterns: filteredPatterns) ?? ShootingInsights(
            clusterDescription: "Loading...",
            trendDescription: "",
            outlierDescription: nil,
            biasDescription: nil,
            suggestedDrills: []
        )
    }

    private var patternLabel: PatternLabel? {
        guard let service = historyService, metrics.totalShots > 0 else { return nil }
        return service.computePatternLabel(metrics: metrics)
    }

    private var visualData: VisualPatternData? {
        guard !filteredPatterns.isEmpty else { return nil }
        return historyService?.generateVisualData(patterns: filteredPatterns)
    }

    var body: some View {
        NavigationStack {
            Group {
                if historyManager.history.isEmpty {
                    emptyStateView
                } else {
                    contentView
                }
            }
            .navigationTitle("Shooting History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onDismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    displayModeToggle
                }
            }
            .onAppear {
                historyService = ShootingHistoryService(historyManager: historyManager)
            }
            .sheet(item: $selectedPattern) { pattern in
                PatternDetailView(pattern: pattern)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "target")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No Shooting History Yet")
                .font(.title2.bold())

            Text("Complete some free practice or tetrathlon sessions to see your shot patterns here.")
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
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Filters Section
                filterSection

                // Scope and Confidence Header
                scopeHeaderSection

                // Statistics Summary
                statisticsSection

                // Visualization Section
                if let data = visualData {
                    visualizationSection(data: data)
                }

                // Trend Chart Section
                if metrics.radiusTrend.count >= 2 {
                    trendChartSection
                }

                // Insights Section
                insightsSection

                // Sessions List Section
                sessionsListSection
            }
            .padding()
        }
    }

    // MARK: - Scope Header Section

    private var scopeHeaderSection: some View {
        VStack(spacing: 12) {
            // Top row: scope and confidence
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Showing: \(selectedDateFilter.rawValue)")
                        .font(.subheadline.weight(.medium))
                    Text("\(metrics.totalShots) shot\(metrics.totalShots == 1 ? "" : "s") from \(metrics.sessionCount) target\(metrics.sessionCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ConfidenceBadge(confidence: metrics.confidence)
            }

            // Bottom row: grouping quality and position badges (like initial insights view)
            if let label = patternLabel {
                HStack(spacing: 16) {
                    // Grouping quality badge
                    VStack(spacing: 4) {
                        Text(label.tightness.description.capitalized)
                            .font(.title3.bold())
                            .foregroundStyle(tightnessColor(label.tightness))
                        Text("Grouping")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider()
                        .frame(height: 40)

                    // Position bias badge
                    VStack(spacing: 4) {
                        Text(label.bias.description.capitalized)
                            .font(.title3.bold())
                            .foregroundStyle(label.bias == .centered ? .green : .orange)
                        Text("Position")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func tightnessColor(_ tightness: GroupTightness) -> Color {
        switch tightness {
        case .tight: return .green
        case .moderate: return .blue
        case .wide: return .orange
        }
    }

    // MARK: - Display Mode Toggle

    private var displayModeToggle: some View {
        Menu {
            Button {
                displayMode = .points
            } label: {
                Label("Points", systemImage: displayMode == .points ? "checkmark" : "")
            }
            Button {
                displayMode = .heatMap
            } label: {
                Label("Heat Map", systemImage: displayMode == .heatMap ? "checkmark" : "")
            }
        } label: {
            Image(systemName: displayMode == .points ? "circle.grid.3x3" : "square.grid.3x3.fill")
        }
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date filter
            HStack {
                Text("Time Period")
                    .font(.subheadline.weight(.medium))
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DateFilterOption.allCases, id: \.self) { option in
                        DateFilterChip(
                            option: option,
                            isSelected: selectedDateFilter == option,
                            action: { selectedDateFilter = option }
                        )
                    }
                }
            }

            // Session type filter
            HStack {
                Text("Session Type")
                    .font(.subheadline.weight(.medium))
                Spacer()
            }
            .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ShootingSessionType.allCases, id: \.self) { type in
                        SessionTypeChip(
                            type: type,
                            isSelected: selectedSessionTypes.contains(type),
                            action: {
                                if selectedSessionTypes.contains(type) {
                                    selectedSessionTypes.remove(type)
                                } else {
                                    selectedSessionTypes.insert(type)
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            HistoryStatCard(title: "Shots", value: "\(metrics.totalShots)", icon: "circle.fill", color: .blue)
            HistoryStatCard(title: "Sessions", value: "\(metrics.sessionCount)", icon: "target", color: .orange)
            HistoryStatCard(title: "Avg Spread", value: metrics.formattedGroupRadius, icon: "circle.dashed", color: .purple)
            HistoryStatCard(title: "Outliers", value: "\(Int(metrics.outlierPercentage))%", icon: "exclamationmark.circle", color: .red)
        }
    }

    // MARK: - Visualization Section

    private func visualizationSection(data: VisualPatternData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Shot Pattern")
                    .font(.headline)
                Spacer()
                Text("\(filteredPatterns.count) target\(filteredPatterns.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ShotPatternVisualizationView(
                visualData: data,
                showAggregate: true
            )
            .frame(height: 320)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Trend Chart Section

    private var trendChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Consistency Trend")
                    .font(.headline)
                Spacer()

                let trend = historyService?.calculateTrend(metrics: metrics) ?? .stable
                HStack(spacing: 4) {
                    Image(systemName: trend.icon)
                    Text(trend.description.capitalized)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(trend.color)
            }

            Chart(metrics.radiusTrend, id: \.date) { dataPoint in
                LineMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Group Radius", dataPoint.radius)
                )
                .foregroundStyle(Color.purple.gradient)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Group Radius", dataPoint.radius)
                )
                .foregroundStyle(Color.purple.opacity(0.1).gradient)
                .interpolationMethod(.catmullRom)
            }
            .chartYAxisLabel("Spread")
            .chartYScale(domain: 0...0.5)
            .frame(height: 150)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Text("Practice Insights")
                    .font(.headline)
                Spacer()
                ConfidenceBadge(confidence: metrics.confidence)
            }

            // 1. Observation (what the pattern shows)
            VStack(alignment: .leading, spacing: 6) {
                Label("Observation", systemImage: "eye")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Text(insights.clusterDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)

                // Include trend if available
                if !insights.trendDescription.isEmpty {
                    Text(insights.trendDescription)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                // Include outlier info if available
                if let outlierDesc = insights.outlierDescription {
                    Text(outlierDesc)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // 2. Practice Focus (what to work on)
            VStack(alignment: .leading, spacing: 6) {
                Label("Practice Focus", systemImage: "target")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Text(insights.practiceFocusText)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // 3. Suggested Drills
            if !insights.suggestedDrills.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Try These Drills", systemImage: "list.bullet.clipboard")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    ForEach(insights.suggestedDrills, id: \.self) { drill in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text(drill)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Sessions List Section

    private var sessionsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                showingSessionList.toggle()
            } label: {
                HStack {
                    Text("Recent Sessions")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: showingSessionList ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }

            if showingSessionList {
                LazyVStack(spacing: 8) {
                    ForEach(filteredPatterns.prefix(10)) { pattern in
                        HistorySessionRowView(pattern: pattern) {
                            selectedPattern = pattern
                        }
                    }

                    if filteredPatterns.count > 10 {
                        Text("+ \(filteredPatterns.count - 10) more sessions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Filter Chip Components

private struct DateFilterChip: View {
    let option: DateFilterOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(option.rawValue)
                .font(.subheadline)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.tertiarySystemBackground))
                .clipShape(Capsule())
        }
    }
}

private struct SessionTypeChip: View {
    let type: ShootingSessionType
    let isSelected: Bool
    let action: () -> Void

    private var chipColor: Color {
        switch type.color {
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        default: return .gray
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.caption)
                Text(type.displayName)
                    .font(.subheadline)
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? chipColor : Color(.tertiarySystemBackground))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Stat Card

private struct HistoryStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Session Row View

private struct HistorySessionRowView: View {
    let pattern: StoredTargetPattern
    let onTap: () -> Void

    private var sessionTypeColor: Color {
        switch pattern.sessionType.color {
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        default: return .gray
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack {
                // Session type indicator
                Circle()
                    .fill(sessionTypeColor)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(pattern.timestamp, format: .dateTime.month().day().hour().minute())
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Text("\(pattern.shotCount) shots • \(pattern.sessionType.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Group radius indicator
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.2f", pattern.clusterRadius))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("spread")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Pattern Detail View

private struct PatternDetailView: View {
    let pattern: StoredTargetPattern

    @Environment(\.dismiss) private var dismiss

    private var visualData: VisualPatternData {
        let shots = pattern.normalizedShots.map { shot in
            VisualPatternData.NormalizedShotPoint(
                position: shot,
                isCurrentTarget: true,
                isOutlier: false,
                timestamp: pattern.timestamp
            )
        }

        return VisualPatternData(
            currentTargetShots: shots,
            historicalShots: [],
            mpiCurrent: CGPoint(x: pattern.clusterMpiX, y: pattern.clusterMpiY),
            mpiAggregate: nil,
            groupRadiusCurrent: pattern.clusterRadius,
            groupRadiusAggregate: nil
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Session info
                    VStack(spacing: 8) {
                        Text(pattern.timestamp, format: .dateTime.weekday().month().day().year())
                            .font(.headline)
                        Text(pattern.sessionType.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()

                    // Stats
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(pattern.shotCount)")
                                .font(.title2.bold())
                            Text("Shots")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()
                            .frame(height: 40)

                        VStack {
                            Text(String(format: "%.2f", pattern.clusterRadius))
                                .font(.title2.bold())
                            Text("Spread")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()
                            .frame(height: 40)

                        VStack {
                            Text("\(pattern.outlierCount)")
                                .font(.title2.bold())
                            Text("Outliers")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Visualization
                    ShotPatternVisualizationView(
                        visualData: visualData,
                        showAggregate: false
                    )
                    .frame(height: 320)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .navigationTitle("Session Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Confidence Badge

private struct ConfidenceBadge: View {
    let confidence: AnalysisConfidence

    private var color: Color {
        switch confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .gray
        }
    }

    private var icon: String {
        switch confidence {
        case .high: return "checkmark.seal.fill"
        case .medium: return "chart.bar.fill"
        case .low: return "ellipsis.circle"
        }
    }

    private var label: String {
        switch confidence {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(label)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview("With Data") {
    ShootingHistoryAggregateView(onDismiss: {})
}

#Preview("Empty State") {
    ShootingHistoryAggregateView(onDismiss: {})
}
