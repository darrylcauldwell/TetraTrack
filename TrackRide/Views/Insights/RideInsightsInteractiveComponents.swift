//
//  RideInsightsInteractiveComponents.swift
//  TrackRide
//
//  Interactive components for Ride Insights view
//  Includes timestamp highlighting, zoom controls, and comparison views
//

import SwiftUI

// MARK: - Timestamp Highlight Line

/// Vertical line overlay that shows the currently selected timestamp across all charts
struct TimestampHighlightLine: View {
    let timestamp: Date
    let rideStart: Date
    let rideDuration: TimeInterval
    let height: CGFloat

    private var positionRatio: Double {
        guard rideDuration > 0 else { return 0 }
        let elapsed = timestamp.timeIntervalSince(rideStart)
        return min(max(elapsed / rideDuration, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            let xPosition = geometry.size.width * CGFloat(positionRatio)

            ZStack {
                // Main highlight line
                Rectangle()
                    .fill(AppColors.primary)
                    .frame(width: 2, height: height)
                    .position(x: xPosition, y: height / 2)

                // Top indicator circle
                Circle()
                    .fill(AppColors.primary)
                    .frame(width: 8, height: 8)
                    .position(x: xPosition, y: 4)

                // Bottom indicator circle
                Circle()
                    .fill(AppColors.primary)
                    .frame(width: 8, height: 8)
                    .position(x: xPosition, y: height - 4)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Zoom Control Bar

/// Horizontal bar with zoom controls for timeline charts
struct ZoomControlBar: View {
    @Bindable var coordinator: InsightsCoordinator

    var body: some View {
        HStack(spacing: 12) {
            // Zoom out button
            Button {
                coordinator.zoomOut()
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(coordinator.zoomLevel <= InsightsCoordinator.minZoom ? .tertiary : .primary)
            }
            .disabled(coordinator.zoomLevel <= InsightsCoordinator.minZoom)

            // Zoom slider
            Slider(
                value: $coordinator.zoomLevel,
                in: InsightsCoordinator.minZoom...InsightsCoordinator.maxZoom,
                step: InsightsCoordinator.zoomStep
            )
            .tint(AppColors.primary)
            .frame(width: 120)

            // Zoom in button
            Button {
                coordinator.zoomIn()
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(coordinator.zoomLevel >= InsightsCoordinator.maxZoom ? .tertiary : .primary)
            }
            .disabled(coordinator.zoomLevel >= InsightsCoordinator.maxZoom)

            // Zoom level indicator
            Text(String(format: "%.1fx", coordinator.zoomLevel))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 35)

            // Reset button
            if coordinator.zoomLevel != InsightsCoordinator.minZoom {
                Button {
                    coordinator.resetZoom()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Comparison Mode Toggle

/// Button to toggle comparison mode
struct ComparisonModeToggle: View {
    @Bindable var coordinator: InsightsCoordinator
    let rideStart: Date
    let rideEnd: Date

    var body: some View {
        Button {
            coordinator.toggleComparisonMode()
            if coordinator.comparisonMode {
                coordinator.setDefaultComparisonRanges(rideStart: rideStart, rideEnd: rideEnd)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: coordinator.comparisonMode ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
                    .font(.system(size: 14))
                Text("Compare")
                    .font(.caption)
            }
            .foregroundStyle(coordinator.comparisonMode ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(coordinator.comparisonMode ? AppColors.primary : Color.secondary.opacity(0.15))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Comparison Range Selector

/// Visual range selector for comparison mode
struct ComparisonRangeSelector: View {
    @Bindable var coordinator: InsightsCoordinator
    let rideStart: Date
    let rideDuration: TimeInterval

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Range A (first half - blue)
                if let startA = coordinator.comparisonStartA,
                   let endA = coordinator.comparisonEndA {
                    let startRatio = positionRatio(for: startA)
                    let endRatio = positionRatio(for: endA)
                    let width = (endRatio - startRatio) * geometry.size.width

                    Rectangle()
                        .fill(AppColors.primary.opacity(0.2))
                        .frame(width: width)
                        .position(
                            x: geometry.size.width * CGFloat(startRatio) + width / 2,
                            y: geometry.size.height / 2
                        )
                        .overlay(
                            Text("A")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(AppColors.primary)
                                .position(
                                    x: geometry.size.width * CGFloat(startRatio) + width / 2,
                                    y: geometry.size.height / 2
                                )
                        )
                }

                // Range B (second half - orange)
                if let startB = coordinator.comparisonStartB,
                   let endB = coordinator.comparisonEndB {
                    let startRatio = positionRatio(for: startB)
                    let endRatio = positionRatio(for: endB)
                    let width = (endRatio - startRatio) * geometry.size.width

                    Rectangle()
                        .fill(AppColors.cardOrange.opacity(0.2))
                        .frame(width: width)
                        .position(
                            x: geometry.size.width * CGFloat(startRatio) + width / 2,
                            y: geometry.size.height / 2
                        )
                        .overlay(
                            Text("B")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(AppColors.cardOrange)
                                .position(
                                    x: geometry.size.width * CGFloat(startRatio) + width / 2,
                                    y: geometry.size.height / 2
                                )
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func positionRatio(for timestamp: Date) -> Double {
        guard rideDuration > 0 else { return 0 }
        return timestamp.timeIntervalSince(rideStart) / rideDuration
    }
}

// MARK: - Comparison Stats View

/// Side-by-side stats comparison for comparison mode
struct ComparisonStatsView: View {
    let statsA: InsightsCoordinator.RangeStats
    let statsB: InsightsCoordinator.RangeStats

    var body: some View {
        VStack(spacing: 12) {
            Text("Comparison")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                // Range A stats
                VStack(spacing: 8) {
                    Text("First Half")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.primary)

                    comparisonStatRow(
                        label: "Rhythm",
                        valueA: statsA.averageRhythm,
                        valueB: statsB.averageRhythm,
                        showA: true
                    )

                    comparisonStatRow(
                        label: "Engagement",
                        valueA: statsA.averageEngagement,
                        valueB: statsB.averageEngagement,
                        showA: true
                    )
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 60)

                // Range B stats
                VStack(spacing: 8) {
                    Text("Second Half")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.cardOrange)

                    comparisonStatRow(
                        label: "Rhythm",
                        valueA: statsA.averageRhythm,
                        valueB: statsB.averageRhythm,
                        showA: false
                    )

                    comparisonStatRow(
                        label: "Engagement",
                        valueA: statsA.averageEngagement,
                        valueB: statsB.averageEngagement,
                        showA: false
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func comparisonStatRow(label: String, valueA: Double, valueB: Double, showA: Bool) -> some View {
        let value = showA ? valueA : valueB
        let comparison = valueB - valueA
        let showComparison = !showA && abs(comparison) > 0.1

        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 4) {
                Text(String(format: "%.0f%%", value))
                    .font(.caption)
                    .fontWeight(.medium)

                if showComparison {
                    Image(systemName: comparison > 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 8))
                        .foregroundStyle(comparison > 0 ? AppColors.success : AppColors.error)
                }
            }
        }
    }
}

// MARK: - Deviation Marker

/// Severity level for deviations
enum DeviationSeverity {
    case moderate
    case severe

    var color: Color {
        switch self {
        case .moderate: return AppColors.warning
        case .severe: return AppColors.error
        }
    }
}

/// Exclamation icon marker for notable deviations in balance charts
struct DeviationMarker: View {
    let timestamp: Date
    let severity: DeviationSeverity
    let rideStart: Date
    let rideDuration: TimeInterval
    var onTap: (() -> Void)?

    private var positionRatio: Double {
        guard rideDuration > 0 else { return 0 }
        return timestamp.timeIntervalSince(rideStart) / rideDuration
    }

    var body: some View {
        GeometryReader { geometry in
            let xPosition = geometry.size.width * CGFloat(positionRatio)

            Button {
                onTap?()
            } label: {
                ZStack {
                    Circle()
                        .fill(severity.color.opacity(0.2))
                        .frame(width: 20, height: 20)

                    Image(systemName: "exclamationmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(severity.color)
                }
            }
            .buttonStyle(.plain)
            .position(x: xPosition, y: geometry.size.height / 2)
        }
    }
}

// MARK: - Vertical Energy Waveform

/// Waveform overlay showing rider vertical movement energy
struct VerticalEnergyWaveform: View {
    let segments: [GaitSegment]
    let rideDuration: TimeInterval

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let points = generateWaveformPoints(in: geometry.size)
                guard let first = points.first else { return }

                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(
                AppColors.warning.opacity(0.7),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func generateWaveformPoints(in size: CGSize) -> [CGPoint] {
        guard !segments.isEmpty else { return [] }

        var points: [CGPoint] = []
        let count = min(40, segments.count * 2)

        for i in 0..<count {
            let x = size.width * CGFloat(i) / CGFloat(count - 1)

            // Map index to segment
            let segmentIndex = min(i * segments.count / count, segments.count - 1)
            let segment = segments[segmentIndex]

            // Use harmonicRatioH2 as bounce amplitude indicator
            // Higher H2 = more pronounced bounce = higher waveform
            let amplitude = segment.harmonicRatioH2 * 0.8 + 0.1
            let baseY = size.height * 0.5

            // Add some variation based on spectral entropy
            let variation = sin(Double(i) * 0.5) * segment.spectralEntropy * 0.2
            let y = baseY - CGFloat(amplitude + variation) * size.height * 0.4

            points.append(CGPoint(x: x, y: max(0, min(size.height, y))))
        }

        return points
    }
}

// MARK: - Heart Rate Pacing Bars

/// Vertical bars showing heart rate zones over time
struct HeartRatePacingBars: View {
    let samples: [HeartRateSample]
    let rideDuration: TimeInterval
    let rideStartDate: Date

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard !samples.isEmpty, rideDuration > 0 else { return }

                let barWidth: CGFloat = max(2, size.width / CGFloat(samples.count))

                for sample in samples {
                    let elapsed = sample.timestamp.timeIntervalSince(rideStartDate)
                    let xRatio = elapsed / rideDuration
                    let x = size.width * CGFloat(xRatio)

                    // Height based on heart rate (50-200 bpm range)
                    let hrNormalized = Double(min(max(sample.bpm, 50), 200) - 50) / 150.0
                    let barHeight = size.height * CGFloat(hrNormalized)

                    let rect = CGRect(
                        x: x - barWidth / 2,
                        y: size.height - barHeight,
                        width: barWidth,
                        height: barHeight
                    )

                    // Color by zone
                    let color = zoneColor(for: sample.zone)
                    context.fill(Path(rect), with: .color(color.opacity(0.6)))
                }
            }
        }
    }

    private func zoneColor(for zone: HeartRateZone) -> Color {
        switch zone {
        case .zone1: return AppColors.success   // Recovery
        case .zone2: return .green              // Light/Fat burn
        case .zone3: return AppColors.warning   // Moderate
        case .zone4: return AppColors.error     // Hard
        case .zone5: return .red                // Maximum
        }
    }
}

// MARK: - Expanded Metric Detail View

/// Detailed timeline view shown when a header score card is expanded
struct ExpandedMetricDetailView: View {
    let metricType: InsightSection
    let segments: [GaitSegment]
    let rideDuration: TimeInterval
    let rideStart: Date
    @Binding var selectedTimestamp: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(metricType.detailTitle)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            // Mini timeline specific to the metric
            GeometryReader { geometry in
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))

                    // Metric-specific visualization
                    metricVisualization(in: geometry.size)

                    // Highlight line if timestamp selected
                    if let timestamp = selectedTimestamp {
                        TimestampHighlightLine(
                            timestamp: timestamp,
                            rideStart: rideStart,
                            rideDuration: rideDuration,
                            height: geometry.size.height
                        )
                    }
                }
            }
            .frame(height: 60)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let ratio = value.location.x / 300 // Approximate width
                        let timestamp = rideStart.addingTimeInterval(rideDuration * Double(ratio))
                        selectedTimestamp = timestamp
                    }
            )
        }
        .padding()
        .background(metricType.color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func metricVisualization(in size: CGSize) -> some View {
        switch metricType {
        case .rhythm:
            rhythmVisualization(in: size)
        case .stability:
            stabilityVisualization(in: size)
        case .straightness:
            straightnessVisualization(in: size)
        case .leadQuality:
            leadQualityVisualization(in: size)
        case .engagement:
            engagementVisualization(in: size)
        }
    }

    private func rhythmVisualization(in size: CGSize) -> some View {
        HStack(spacing: 1) {
            ForEach(0..<20, id: \.self) { index in
                let rhythmValue = rhythmForIndex(index)
                Rectangle()
                    .fill(rhythmColor(rhythmValue))
                    .frame(width: size.width / 20 - 1)
            }
        }
    }

    private func stabilityVisualization(in size: CGSize) -> some View {
        Path { path in
            let points = segments.enumerated().compactMap { index, segment -> CGPoint? in
                let x = size.width * CGFloat(index) / CGFloat(max(segments.count - 1, 1))
                let y = size.height * (1 - CGFloat(segment.harmonicRatioH2))
                return CGPoint(x: x, y: y)
            }
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
        .stroke(AppColors.primary, lineWidth: 1.5)
    }

    private func straightnessVisualization(in size: CGSize) -> some View {
        Path { path in
            let points = segments.enumerated().compactMap { index, segment -> CGPoint? in
                let x = size.width * CGFloat(index) / CGFloat(max(segments.count - 1, 1))
                // Use spectral entropy as inverse straightness indicator
                let straightness = 1 - segment.spectralEntropy
                let y = size.height * (1 - CGFloat(straightness))
                return CGPoint(x: x, y: y)
            }
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
        .stroke(AppColors.success, lineWidth: 1.5)
    }

    private func leadQualityVisualization(in size: CGSize) -> some View {
        HStack(spacing: 1) {
            ForEach(segments.filter { $0.isLeadApplicable }, id: \.id) { segment in
                Rectangle()
                    .fill(segment.isCorrectLead ? AppColors.success : AppColors.error)
                    .frame(width: max(4, size.width / CGFloat(segments.count)))
            }
        }
    }

    private func engagementVisualization(in size: CGSize) -> some View {
        Path { path in
            let points = segments.enumerated().compactMap { index, segment -> CGPoint? in
                let x = size.width * CGFloat(index) / CGFloat(max(segments.count - 1, 1))
                let y = size.height * (1 - CGFloat(segment.engagement / 100))
                return CGPoint(x: x, y: y)
            }
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
        .stroke(AppColors.cardOrange, lineWidth: 1.5)
    }

    private func rhythmForIndex(_ index: Int) -> Double {
        guard !segments.isEmpty else { return 0.5 }
        let segmentIndex = min(index * segments.count / 20, segments.count - 1)
        return 1 - segments[segmentIndex].spectralEntropy
    }

    private func rhythmColor(_ value: Double) -> Color {
        switch value {
        case 0..<0.4: return AppColors.error
        case 0.4..<0.6: return AppColors.warning
        case 0.6..<0.8: return AppColors.success.opacity(0.7)
        default: return AppColors.success
        }
    }
}

// MARK: - InsightSection Extension

extension InsightSection {
    var detailTitle: String {
        switch self {
        case .rhythm: return "Rhythm over time (stride regularity)"
        case .stability: return "Stability over time (vertical bounce)"
        case .straightness: return "Straightness over time (yaw deviation)"
        case .leadQuality: return "Lead correctness by segment"
        case .engagement: return "Engagement level over time"
        }
    }

    var color: Color {
        switch self {
        case .rhythm: return AppColors.primary
        case .stability: return AppColors.success
        case .straightness: return AppColors.warning
        case .leadQuality: return AppColors.cardOrange
        case .engagement: return AppColors.error
        }
    }
}

// MARK: - Preview

#Preview("Zoom Control Bar") {
    ZoomControlBar(coordinator: InsightsCoordinator())
        .padding()
}

#Preview("Deviation Marker") {
    DeviationMarker(
        timestamp: Date(),
        severity: .severe,
        rideStart: Date().addingTimeInterval(-1800),
        rideDuration: 3600
    )
    .frame(height: 40)
    .padding()
}
