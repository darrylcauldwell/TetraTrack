//
//  ShootingHistoryAggregateView.swift
//  TetraTrack
//
//  Historical aggregate view for shooting patterns with filtering, visualization, and insights.
//

import SwiftUI
import Charts

// MARK: - Navigation Wrapper

/// Wrapper view for use in NavigationLink (uses dismiss instead of callback)
struct ShootingHistoryWrapperView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ShootingHistoryAggregateView(onDismiss: { dismiss() })
            .navigationTitle("Shooting History")
            .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Main Aggregate View

struct ShootingHistoryAggregateView: View {
    let onDismiss: () -> Void
    var initialDateFilter: DateFilterOption? = nil

    @State private var historyManager = ShotPatternHistoryManager()
    @State private var historyService: ShootingHistoryService?

    // Filter state
    @State private var selectedDateFilter: DateFilterOption = .lastTarget
    @State private var selectedSessionTypes: Set<ShootingSessionType> = Set(ShootingSessionType.allCases)

    // Display state
    @State private var displayMode: ShotDisplayMode = .points
    @State private var showingSessionList = false
    @State private var selectedPattern: StoredTargetPattern?
    @State private var showingPressureInsights = false

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
                    Button {
                        showingPressureInsights = true
                    } label: {
                        Image(systemName: "brain.head.profile")
                    }
                    .accessibilityLabel("Pressure Insights")
                    .accessibilityHint("Analyse performance by pressure context")
                }
                ToolbarItem(placement: .primaryAction) {
                    displayModeToggle
                }
            }
            .onAppear {
                historyService = ShootingHistoryService(historyManager: historyManager)
                // Apply initial date filter if provided (e.g., from post-practice navigation)
                if let initialFilter = initialDateFilter {
                    selectedDateFilter = initialFilter
                }
            }
            .sheet(item: $selectedPattern) { pattern in
                PatternDetailView(pattern: pattern)
            }
            .fullScreenCover(isPresented: $showingPressureInsights) {
                ShootingInsightsView(onDismiss: {
                    showingPressureInsights = false
                })
            }
            .presentationBackground(Color.black)
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
                    .background(AppColors.primary)
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

                // Target Thumbnail (shown prominently for Last Target)
                if selectedDateFilter == .lastTarget, let pattern = filteredPatterns.first {
                    lastTargetThumbnailSection(pattern: pattern)
                }

                // Scope and Confidence Header
                scopeHeaderSection

                // Statistics Summary
                statisticsSection

                // Context breakdown (show when filtering by all types)
                if selectedSessionTypes.count > 1 && filteredPatterns.count >= 3 {
                    contextBreakdownSection
                }

                // Visualization Section (hidden for Last Target - shown in thumbnail overlay)
                if selectedDateFilter != .lastTarget, let data = visualData {
                    visualizationSection(data: data)
                }

                // Trend Chart Section
                if metrics.radiusTrend.count >= 2 {
                    trendChartSection
                }

                // Insights Section
                insightsSection

                // Sessions List Section (hidden for Last Target since we show it above)
                if selectedDateFilter != .lastTarget {
                    sessionsListSection
                }
            }
            .padding()
        }
    }

    // MARK: - Last Target Thumbnail Section

    private func lastTargetThumbnailSection(pattern: StoredTargetPattern) -> some View {
        VStack(spacing: 12) {
            // Thumbnail image with hole markers overlaid
            LastTargetThumbnailView(pattern: pattern)

            // Session info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pattern.timestamp, format: .dateTime.weekday().month().day().hour().minute())
                        .font(.subheadline.weight(.medium))
                    Text(pattern.sessionType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    selectedPattern = pattern
                } label: {
                    Text("View Details")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.primary)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                            .foregroundStyle(label.bias == .centered ? AppColors.active : AppColors.warning)
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
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func tightnessColor(_ tightness: GroupTightness) -> Color {
        switch tightness {
        case .tight: return AppColors.groupTight
        case .moderate: return AppColors.groupModerate
        case .wide: return AppColors.groupWide
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
        .background(AppColors.cardBackground)
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
            HistoryStatCard(title: "Shots", value: "\(metrics.totalShots)", icon: "circle.fill", color: AppColors.shootingFreePractice)
            HistoryStatCard(title: "Sessions", value: "\(metrics.sessionCount)", icon: "target", color: AppColors.shootingTraining)
            HistoryStatCard(title: "Avg Spread", value: metrics.formattedGroupRadius, icon: "circle.dashed", color: AppColors.shootingCompetition)
            HistoryStatCard(title: "Outliers", value: "\(Int(metrics.outlierPercentage))%", icon: "exclamationmark.circle", color: AppColors.error)
        }
    }

    // MARK: - Context Breakdown Section

    private var contextBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("By Pressure Level")
                    .font(.headline)
                Text("How stress affects your shot grouping")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                // Low Pressure (Level 1)
                let lowPressure = filteredPatterns.filter { $0.sessionType.pressureLevel == 1 }
                ContextBreakdownCard(
                    title: "Relaxed",
                    subtitle: "Free practice",
                    patterns: lowPressure,
                    color: AppColors.shootingFreePractice
                )

                // Medium Pressure (Level 2)
                let medPressure = filteredPatterns.filter { $0.sessionType.pressureLevel == 2 }
                ContextBreakdownCard(
                    title: "Training",
                    subtitle: "Competition prep",
                    patterns: medPressure,
                    color: AppColors.shootingTraining
                )

                // High Pressure (Level 3)
                let highPressure = filteredPatterns.filter { $0.sessionType.pressureLevel == 3 }
                ContextBreakdownCard(
                    title: "Match Day",
                    subtitle: "Competition",
                    patterns: highPressure,
                    color: AppColors.shootingCompetition
                )
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
        }
        .padding()
        .background(AppColors.cardBackground)
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
                .foregroundStyle(AppColors.shootingCompetition.gradient)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Group Radius", dataPoint.radius)
                )
                .foregroundStyle(AppColors.shootingCompetition.opacity(0.1).gradient)
                .interpolationMethod(.catmullRom)
            }
            .chartYAxisLabel("Spread")
            .chartYScale(domain: 0...0.5)
            .frame(height: 150)
        }
        .padding()
        .background(AppColors.cardBackground)
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
                                .foregroundStyle(AppColors.active)
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
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Sessions List Section (Day-Grouped)

    /// Group patterns by day for display
    private var patternsByDay: [(date: Date, patterns: [StoredTargetPattern])] {
        let calendar = Calendar.current
        var grouped: [Date: [StoredTargetPattern]] = [:]

        for pattern in filteredPatterns {
            let day = calendar.startOfDay(for: pattern.timestamp)
            grouped[day, default: []].append(pattern)
        }

        // Sort days descending, patterns within each day by timestamp descending
        return grouped
            .map { (date: $0.key, patterns: $0.value.sorted { $0.timestamp > $1.timestamp }) }
            .sorted { $0.date > $1.date }
    }

    private var sessionsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                showingSessionList.toggle()
            } label: {
                HStack {
                    Text("Sessions by Day")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: showingSessionList ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }

            if showingSessionList {
                LazyVStack(spacing: 16) {
                    ForEach(patternsByDay.prefix(10), id: \.date) { dayGroup in
                        DaySessionGroup(
                            date: dayGroup.date,
                            patterns: dayGroup.patterns,
                            onSelectPattern: { pattern in
                                selectedPattern = pattern
                            }
                        )
                    }

                    if patternsByDay.count > 10 {
                        Text("+ \(patternsByDay.count - 10) more days")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Last Target Thumbnail View with Overlay

private struct LastTargetThumbnailView: View {
    let pattern: StoredTargetPattern

    @State private var thumbnailImage: UIImage?
    @State private var hasLoadedThumbnail = false

    var body: some View {
        VStack(spacing: 8) {
            if let thumbnail = thumbnailImage {
                // Show thumbnail with hole markers overlaid
                TargetImageWithHoleOverlay(
                    image: thumbnail,
                    normalizedShots: pattern.normalizedShots,
                    clusterMpi: CGPoint(x: pattern.clusterMpiX, y: pattern.clusterMpiY)
                )
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if !hasLoadedThumbnail {
                // Loading state
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .frame(height: 280)
                    .overlay {
                        ProgressView()
                    }
            } else {
                // No thumbnail available - show Canvas-based shot pattern
                shotPatternCanvas

                Text("Target photo not available on this device")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        thumbnailImage = TargetThumbnailService.shared.loadThumbnail(forPatternId: pattern.id)
        hasLoadedThumbnail = true
    }

    /// Canvas-based shot pattern visualization - self-contained fallback
    private var shotPatternCanvas: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxRadius = min(size.width, size.height) / 2 - 20

            // Draw target background
            let bgCircle = Path(ellipseIn: CGRect(
                x: center.x - maxRadius,
                y: center.y - maxRadius,
                width: maxRadius * 2,
                height: maxRadius * 2
            ))
            context.fill(bgCircle, with: .color(Color(.systemGray5)))

            // Draw concentric scoring rings
            for i in 1...5 {
                let radius = maxRadius * CGFloat(i) / 5
                let circle = Path(ellipseIn: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
                context.stroke(circle, with: .color(.gray.opacity(0.5)), lineWidth: 1)
            }

            // Draw center crosshair
            var hLine = Path()
            hLine.move(to: CGPoint(x: center.x - 10, y: center.y))
            hLine.addLine(to: CGPoint(x: center.x + 10, y: center.y))
            context.stroke(hLine, with: .color(.gray), lineWidth: 1)

            var vLine = Path()
            vLine.move(to: CGPoint(x: center.x, y: center.y - 10))
            vLine.addLine(to: CGPoint(x: center.x, y: center.y + 10))
            context.stroke(vLine, with: .color(.gray), lineWidth: 1)

            // Draw shot holes
            for shot in pattern.normalizedShots {
                let x = center.x + shot.x * maxRadius
                let y = center.y + shot.y * maxRadius

                // Outer ring
                let outerCircle = Path(ellipseIn: CGRect(x: x - 7, y: y - 7, width: 14, height: 14))
                context.stroke(outerCircle, with: .color(.white), lineWidth: 2)

                // Inner fill
                let innerCircle = Path(ellipseIn: CGRect(x: x - 5, y: y - 5, width: 10, height: 10))
                context.fill(innerCircle, with: .color(AppColors.shotHole))
            }

            // Draw MPI (Mean Point of Impact) marker
            let mpiX = center.x + pattern.clusterMpiX * maxRadius
            let mpiY = center.y + pattern.clusterMpiY * maxRadius

            // MPI outer ring
            let mpiOuter = Path(ellipseIn: CGRect(x: mpiX - 10, y: mpiY - 10, width: 20, height: 20))
            context.stroke(mpiOuter, with: .color(AppColors.shotMPI), lineWidth: 2)

            // MPI center dot
            let mpiCenter = Path(ellipseIn: CGRect(x: mpiX - 4, y: mpiY - 4, width: 8, height: 8))
            context.fill(mpiCenter, with: .color(AppColors.shotMPI))
        }
        .frame(height: 280)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

// MARK: - Target Image with Hole Overlay

private struct TargetImageWithHoleOverlay: View {
    let image: UIImage
    let normalizedShots: [CGPoint]
    let clusterMpi: CGPoint

    private func calculateLayout(frameSize: CGSize) -> (displaySize: CGSize, offset: CGSize) {
        let imageSize = image.size
        let imageAspect = imageSize.width / imageSize.height
        let frameAspect = frameSize.width / frameSize.height

        if imageAspect > frameAspect {
            // Image is wider - fit to width
            let width = frameSize.width
            let height = width / imageAspect
            return (CGSize(width: width, height: height), CGSize(width: 0, height: (frameSize.height - height) / 2))
        } else {
            // Image is taller - fit to height
            let height = frameSize.height
            let width = height * imageAspect
            return (CGSize(width: width, height: height), CGSize(width: (frameSize.width - width) / 2, height: 0))
        }
    }

    private func denormalizedPosition(_ normalized: CGPoint, displaySize: CGSize) -> CGPoint {
        let centerX = displaySize.width / 2
        let centerY = displaySize.height / 2
        let maxRadius = min(displaySize.width, displaySize.height) / 2
        return CGPoint(
            x: centerX + (normalized.x * maxRadius),
            y: centerY + (normalized.y * maxRadius)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = calculateLayout(frameSize: geometry.size)

            ZStack {
                // Background image
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: layout.displaySize.width, height: layout.displaySize.height)

                // Hole markers overlay
                ForEach(Array(normalizedShots.enumerated()), id: \.offset) { _, normalizedPoint in
                    let pos = denormalizedPosition(normalizedPoint, displaySize: layout.displaySize)
                    Circle()
                        .fill(AppColors.shotHole)
                        .frame(width: 10, height: 10)
                        .shadow(color: .black.opacity(0.5), radius: 1)
                        .position(x: pos.x, y: pos.y)
                }

                // MPI marker (cluster center)
                let mpiPos = denormalizedPosition(clusterMpi, displaySize: layout.displaySize)
                Circle()
                    .stroke(AppColors.shotMPI, lineWidth: 2)
                    .frame(width: 16, height: 16)
                    .position(x: mpiPos.x, y: mpiPos.y)

                Circle()
                    .fill(AppColors.shotMPI)
                    .frame(width: 6, height: 6)
                    .position(x: mpiPos.x, y: mpiPos.y)
            }
            .frame(width: layout.displaySize.width, height: layout.displaySize.height)
            .offset(x: layout.offset.width, y: layout.offset.height)
        }
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
                .background(isSelected ? AppColors.primary : AppColors.elevatedSurface)
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
        case "blue": return AppColors.shootingFreePractice
        case "orange": return AppColors.shootingTraining
        case "purple": return AppColors.shootingCompetition
        default: return AppColors.inactive
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.caption)
                Text(type.displayName)
                    .font(.subheadline)
                // Pressure level indicator
                HStack(spacing: 2) {
                    ForEach(1...3, id: \.self) { level in
                        Circle()
                            .fill(level <= type.pressureLevel
                                  ? (isSelected ? Color.white.opacity(0.8) : chipColor)
                                  : (isSelected ? Color.white.opacity(0.3) : AppColors.inactive.opacity(0.3)))
                            .frame(width: 5, height: 5)
                    }
                }
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? chipColor : AppColors.elevatedSurface)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Context Breakdown Card

private struct ContextBreakdownCard: View {
    let title: String
    let subtitle: String
    let patterns: [StoredTargetPattern]
    let color: Color

    private var avgSpread: Double {
        guard !patterns.isEmpty else { return 0 }
        return patterns.map { $0.clusterRadius }.reduce(0, +) / Double(patterns.count)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.vertical, 2)

            Text("\(patterns.count)")
                .font(.title2.bold())

            Text("targets")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(patterns.isEmpty ? " " : String(format: "%.2f", avgSpread))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .opacity(patterns.isEmpty ? 0 : 1)

            Text("avg spread")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .opacity(patterns.isEmpty ? 0 : 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(AppColors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
        .background(AppColors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Day Session Group

private struct DaySessionGroup: View {
    let date: Date
    let patterns: [StoredTargetPattern]
    let onSelectPattern: (StoredTargetPattern) -> Void

    private var dateHeader: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "EEEE, MMMM d"
            return formatter.string(from: date)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Day header
            HStack {
                Text(dateHeader)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(patterns.count) target\(patterns.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Sessions for this day - horizontal scroll if multiple, single card if one
            if patterns.count == 1 {
                SessionThumbnailCard(pattern: patterns[0], onTap: { onSelectPattern(patterns[0]) })
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(patterns) { pattern in
                            SessionThumbnailCard(pattern: pattern, onTap: { onSelectPattern(pattern) })
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Session Thumbnail Card

private struct SessionThumbnailCard: View {
    let pattern: StoredTargetPattern
    let onTap: () -> Void

    @State private var thumbnailImage: UIImage?

    private var sessionTypeColor: Color {
        switch pattern.sessionType.color {
        case "blue": return AppColors.shootingFreePractice
        case "orange": return AppColors.shootingTraining
        case "purple": return AppColors.shootingCompetition
        default: return AppColors.inactive
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail or placeholder
                ZStack {
                    if let thumbnail = thumbnailImage {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipped()
                    } else {
                        // Placeholder with target icon
                        Rectangle()
                            .fill(AppColors.elevatedSurface)
                            .frame(width: 120, height: 120)
                            .overlay {
                                Image(systemName: "target")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                            }
                    }

                    // Session type badge
                    VStack {
                        HStack {
                            Spacer()
                            Circle()
                                .fill(sessionTypeColor)
                                .frame(width: 10, height: 10)
                                .padding(6)
                        }
                        Spacer()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Session info
                VStack(alignment: .leading, spacing: 2) {
                    Text(pattern.timestamp, format: .dateTime.hour().minute())
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        Text("\(pattern.shotCount) shots")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Text(String(format: "%.2f", pattern.clusterRadius))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 120, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            thumbnailImage = TargetThumbnailService.shared.loadThumbnail(forPatternId: pattern.id)
        }
    }
}

// MARK: - Session Row View (Legacy - kept for compatibility)

private struct HistorySessionRowView: View {
    let pattern: StoredTargetPattern
    let onTap: () -> Void

    private var sessionTypeColor: Color {
        switch pattern.sessionType.color {
        case "blue": return AppColors.shootingFreePractice
        case "orange": return AppColors.shootingTraining
        case "purple": return AppColors.shootingCompetition
        default: return AppColors.inactive
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
            .background(AppColors.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Pattern Detail View

private struct PatternDetailView: View {
    let pattern: StoredTargetPattern

    @Environment(\.dismiss) private var dismiss
    @State private var thumbnailImage: UIImage?

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

                    // Target thumbnail (if available)
                    if let thumbnail = thumbnailImage {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                    }

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
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Visualization
                    ShotPatternVisualizationView(
                        visualData: visualData,
                        showAggregate: false
                    )
                    .padding()
                    .background(AppColors.cardBackground)
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
            .onAppear {
                // Load thumbnail from persistent storage
                thumbnailImage = TargetThumbnailService.shared.loadThumbnail(forPatternId: pattern.id)
            }
        }
    }
}

// MARK: - Confidence Badge

private struct ConfidenceBadge: View {
    let confidence: AnalysisConfidence

    private var color: Color {
        switch confidence {
        case .high: return AppColors.active
        case .medium: return AppColors.warning
        case .low: return AppColors.inactive
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
