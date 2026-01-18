//
//  RideInsightsComponents.swift
//  TrackRide
//
//  Reusable components for the Ride Insights view
//  Includes charts, timelines, gauges, and interactive elements
//

import SwiftUI
import Charts

// MARK: - Insight Score Card

struct InsightScoreCard: View {
    let title: String
    let score: Double
    let icon: String
    let isExpanded: Bool
    let onTap: () -> Void

    private var scoreColor: Color {
        switch score {
        case 0..<50: return AppColors.error
        case 50..<70: return AppColors.warning
        case 70..<85: return AppColors.success
        default: return AppColors.primary
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Icon
                ZStack {
                    Circle()
                        .fill(scoreColor.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(scoreColor)
                }

                // Score bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.2))

                        RoundedRectangle(cornerRadius: 3)
                            .fill(scoreColor)
                            .frame(width: geo.size.width * min(score / 100, 1))
                    }
                }
                .frame(height: 6)

                // Title and score
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("\(Int(score))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(scoreColor)
            }
            .frame(width: 70)
            .padding(10)
            .background(isExpanded ? scoreColor.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isExpanded ? scoreColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Gait Timeline Strip

struct GaitTimelineStrip: View {
    let segments: [GaitSegment]
    let rideDuration: TimeInterval
    @Binding var selectedTimestamp: Date?
    let onSegmentTap: (GaitSegment) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))

                // Gait segments
                ForEach(segments, id: \.id) { segment in
                    let startOffset = segmentOffset(segment, in: geometry.size.width)
                    let width = segmentWidth(segment, in: geometry.size.width)

                    ZStack {
                        // Segment bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.gait(segment.gait))
                            .frame(width: max(2, width), height: 40)

                        // Lead indicator for canter
                        if segment.gait == .canter || segment.gait == .gallop {
                            let lead = segment.lead
                            if lead != .unknown {
                                Image(systemName: lead == .left ? "arrowtriangle.left.fill" : "arrowtriangle.right.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.white)
                                    .offset(y: 12)
                            }
                        }
                    }
                    .offset(x: startOffset)
                    .onTapGesture {
                        onSegmentTap(segment)
                    }
                }
            }
        }
    }

    private func segmentOffset(_ segment: GaitSegment, in width: CGFloat) -> CGFloat {
        guard rideDuration > 0, let first = segments.first else { return 0 }
        let elapsed = segment.startTime.timeIntervalSince(first.startTime)
        return CGFloat(elapsed / rideDuration) * width
    }

    private func segmentWidth(_ segment: GaitSegment, in width: CGFloat) -> CGFloat {
        guard rideDuration > 0 else { return 0 }
        return CGFloat(segment.duration / rideDuration) * width
    }
}

// MARK: - Time Axis Labels

struct TimeAxisLabels: View {
    let duration: TimeInterval

    var body: some View {
        HStack {
            Text("0:00")
            Spacer()
            Text(formatDuration(duration / 2))
            Spacer()
            Text(formatDuration(duration))
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Insights Gait Legend

struct InsightsGaitLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            ForEach(GaitType.allCases.filter { $0 != .stationary }, id: \.self) { gait in
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppColors.gait(gait))
                        .frame(width: 8, height: 8)
                    Text(gait.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Balance Line Chart

struct BalanceLineChart: View {
    let title: String
    let segments: [BalanceDataPoint]
    let positiveLabel: String
    let negativeLabel: String
    let rideDuration: TimeInterval
    var rideStart: Date = Date()
    var showDeviationMarkers: Bool = true
    var onDeviationTap: ((Date) -> Void)?

    // Detect deviations where |value| > threshold
    private var deviations: [(timestamp: Date, severity: DeviationSeverity)] {
        segments.compactMap { point in
            if abs(point.value) > 0.7 {
                return (point.timestamp, DeviationSeverity.severe)
            } else if abs(point.value) > 0.5 {
                return (point.timestamp, DeviationSeverity.moderate)
            }
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                // Deviation count badge
                if showDeviationMarkers && !deviations.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                        Text("\(deviations.count)")
                            .font(.caption2)
                    }
                    .foregroundStyle(AppColors.warning)
                }
            }

            ZStack {
                // Optimal zone
                Rectangle()
                    .fill(AppColors.success.opacity(0.1))
                    .frame(height: 40)

                // Warning zones
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(AppColors.error.opacity(0.1))
                        .frame(height: 30)
                    Spacer()
                        .frame(height: 60)
                    Rectangle()
                        .fill(AppColors.error.opacity(0.1))
                        .frame(height: 30)
                }

                // Center line
                Divider()

                // Balance line
                Chart(segments) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Balance", point.value)
                    )
                    .foregroundStyle(AppColors.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Balance", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.primary.opacity(0.3), AppColors.primary.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartYScale(domain: -1...1)
                .chartYAxis(.hidden)
                .chartXAxis(.hidden)

                // Deviation markers overlay
                if showDeviationMarkers {
                    ForEach(deviations, id: \.timestamp) { deviation in
                        DeviationMarker(
                            timestamp: deviation.timestamp,
                            severity: deviation.severity,
                            rideStart: rideStart,
                            rideDuration: rideDuration,
                            onTap: { onDeviationTap?(deviation.timestamp) }
                        )
                    }
                }
            }

            // Labels
            HStack {
                Text(negativeLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("Balanced")
                    .font(.caption2)
                    .foregroundStyle(AppColors.success)
                Spacer()
                Text(positiveLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Summary Stat Badge

struct SummaryStatBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Symmetry Line Chart

struct SymmetryLineChart: View {
    let symmetryScore: Double
    let straightnessScore: Double
    let segments: [GaitSegment]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Threshold overlay
                Rectangle()
                    .fill(AppColors.warning.opacity(0.1))
                    .frame(height: geometry.size.height * 0.4)
                    .offset(y: -geometry.size.height * 0.3)

                Rectangle()
                    .fill(AppColors.warning.opacity(0.1))
                    .frame(height: geometry.size.height * 0.4)
                    .offset(y: geometry.size.height * 0.3)

                // Center optimal zone
                Rectangle()
                    .fill(AppColors.success.opacity(0.15))
                    .frame(height: geometry.size.height * 0.3)

                // Symmetry line
                Path { path in
                    let points = generateSymmetryPoints(in: geometry.size)
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(AppColors.primary, lineWidth: 2)
            }
        }
    }

    private func generateSymmetryPoints(in size: CGSize) -> [CGPoint] {
        guard !segments.isEmpty else { return [] }
        var points: [CGPoint] = []
        let count = min(20, segments.count)

        for i in 0..<count {
            let x = size.width * CGFloat(i) / CGFloat(count - 1)
            // Simulate symmetry variation
            let variation = sin(Double(i) * 0.5) * 0.3 + (1 - symmetryScore / 100) * 0.5
            let y = size.height * 0.5 + CGFloat(variation) * size.height * 0.4
            points.append(CGPoint(x: x, y: y))
        }

        return points
    }
}

// MARK: - Rhythm Heatmap

struct RhythmHeatmap: View {
    let segments: [GaitSegment]
    let rideDuration: TimeInterval
    var showEnergyWaveform: Bool = true

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Heatmap cells
                HStack(spacing: 1) {
                    ForEach(0..<20, id: \.self) { index in
                        let rhythmValue = rhythmForIndex(index)
                        Rectangle()
                            .fill(rhythmColor(rhythmValue))
                            .frame(width: geometry.size.width / 20 - 1)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))

                // Vertical energy waveform overlay
                if showEnergyWaveform {
                    VerticalEnergyWaveform(
                        segments: segments,
                        rideDuration: rideDuration
                    )
                }
            }
        }
    }

    private func rhythmForIndex(_ index: Int) -> Double {
        guard !segments.isEmpty else { return 0.5 }
        // Map index to segment range and get rhythm value
        let segmentIndex = min(index * segments.count / 20, segments.count - 1)
        // Use spectral entropy as inverse rhythm indicator
        let segment = segments[segmentIndex]
        return 1 - segment.spectralEntropy // Higher = better rhythm
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

// MARK: - Transition Quality Strip

struct TransitionQualityStrip: View {
    let transitions: [GaitTransition]
    let rideDuration: TimeInterval
    let onTransitionTap: (GaitTransition) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background timeline
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.1))

                // Transition markers
                ForEach(transitions, id: \.id) { transition in
                    let offset = transitionOffset(transition, in: geometry.size.width)

                    Circle()
                        .fill(transitionColor(transition.transitionQuality))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Image(systemName: transition.isUpwardTransition ? "arrow.up" : "arrow.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .offset(x: offset - 8)
                        .onTapGesture {
                            onTransitionTap(transition)
                        }
                }
            }
        }
    }

    private func transitionOffset(_ transition: GaitTransition, in width: CGFloat) -> CGFloat {
        guard rideDuration > 0, let first = transitions.first else { return 0 }
        let elapsed = transition.timestamp.timeIntervalSince(first.timestamp)
        return CGFloat(elapsed / rideDuration) * width
    }

    private func transitionColor(_ quality: Double) -> Color {
        switch quality {
        case 0..<0.5: return AppColors.error
        case 0.5..<0.75: return AppColors.warning
        default: return AppColors.success
        }
    }
}

// MARK: - Transition Stat Badge

struct TransitionStatBadge: View {
    let label: String
    let count: Int
    let icon: String
    let color: Color
    var isPercentage: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(isPercentage ? "\(count)%" : "\(count)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Lead Distribution Chart

struct LeadDistributionChart: View {
    let leftLeadDuration: TimeInterval
    let rightLeadDuration: TimeInterval
    var correctLeadDuration: TimeInterval = 0
    var crossCanterDuration: TimeInterval = 0
    var showCorrectness: Bool = false

    private var simpleData: [(String, Double, Color)] {
        [
            ("Left", leftLeadDuration, AppColors.turnLeft),
            ("Right", rightLeadDuration, AppColors.turnRight)
        ]
    }

    private var correctnessData: [(String, Double, Color)] {
        [
            ("Correct", correctLeadDuration, AppColors.success),
            ("Cross-Canter", crossCanterDuration, AppColors.error)
        ]
    }

    var body: some View {
        VStack(spacing: 8) {
            // Main chart - shows either left/right or correct/incorrect
            Chart(showCorrectness ? correctnessData : simpleData, id: \.0) { item in
                SectorMark(
                    angle: .value("Duration", item.1),
                    innerRadius: .ratio(0.5),
                    angularInset: 2
                )
                .foregroundStyle(item.2)
                .cornerRadius(4)
            }

            // Cross-canter indicator (when showing left/right but cross-canter exists)
            if !showCorrectness && crossCanterDuration > 0 {
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppColors.error)
                        .frame(width: 6, height: 6)
                    Text("Cross-canter: \(crossCanterDuration.formattedDuration)")
                        .font(.caption2)
                        .foregroundStyle(AppColors.error)
                }
            }
        }
    }
}

// MARK: - Enhanced Lead Distribution Chart (with coupling score)

struct EnhancedLeadDistributionChart: View {
    let ride: Ride

    private var leftDuration: TimeInterval { ride.leftLeadDuration }
    private var rightDuration: TimeInterval { ride.rightLeadDuration }
    private var crossCanter: TimeInterval { ride.crossCanterDuration }
    private var correctDuration: TimeInterval { ride.totalLeadDuration - crossCanter }
    private var coherenceScore: Double { ride.averageVerticalYawCoherence * 100 }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                // Lead distribution pie chart
                LeadDistributionChart(
                    leftLeadDuration: leftDuration,
                    rightLeadDuration: rightDuration,
                    correctLeadDuration: correctDuration,
                    crossCanterDuration: crossCanter
                )
                .frame(width: 100, height: 100)

                VStack(alignment: .leading, spacing: 12) {
                    LeadStatRow(
                        label: "Left Lead",
                        duration: leftDuration,
                        percentage: ride.leadBalance * 100,
                        color: AppColors.turnLeft
                    )
                    LeadStatRow(
                        label: "Right Lead",
                        duration: rightDuration,
                        percentage: (1 - ride.leadBalance) * 100,
                        color: AppColors.turnRight
                    )

                    if crossCanter > 0 {
                        Divider()
                        HStack {
                            Circle()
                                .fill(AppColors.error)
                                .frame(width: 10, height: 10)
                            Text("Cross-canter")
                                .font(.caption)
                            Spacer()
                            Text(crossCanter.formattedDuration)
                                .font(.caption)
                                .monospacedDigit()
                            Text("(\(Int(ride.correctLeadPercentage))% correct)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    // Vertical-yaw coupling score
                    HStack {
                        Text("Coupling Quality")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        ScoreBadge(score: coherenceScore)
                    }
                }
            }
        }
    }
}

// MARK: - Lead Stat Row

struct LeadStatRow: View {
    let label: String
    let duration: TimeInterval
    let percentage: Double
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(label)
                .font(.caption)

            Spacer()

            Text(duration.formattedDuration)
                .font(.caption)
                .monospacedDigit()

            Text("(\(Int(percentage))%)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Score Badge

struct ScoreBadge: View {
    let score: Double
    var label: String? = nil

    private var color: Color {
        switch score {
        case 0..<50: return AppColors.error
        case 50..<70: return AppColors.warning
        case 70..<85: return AppColors.success
        default: return AppColors.primary
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            if let label = label {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text("\(Int(score))%")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Engagement Area Chart

struct EngagementAreaChart: View {
    let impulsion: Double
    let engagement: Double
    let segments: [GaitSegment]
    var showEnergyRatio: Bool = true

    // Forward/vertical ratio from impulsion (impulsion = forward/vertical * 50)
    private var forwardVerticalRatio: Double {
        impulsion / 50.0  // 1.0 = equal, >1 = more forward, <1 = more vertical
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Engagement bands background
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(AppColors.success.opacity(0.1))
                        .frame(height: 40)
                    Rectangle()
                        .fill(AppColors.warning.opacity(0.1))
                        .frame(height: 40)
                    Rectangle()
                        .fill(AppColors.error.opacity(0.1))
                        .frame(height: 40)
                }

                // Engagement line and area
                GeometryReader { geometry in
                    // Forward energy line (blue)
                    if showEnergyRatio {
                        Path { path in
                            let points = generateForwardEnergyPoints(in: geometry.size)
                            guard let first = points.first else { return }
                            path.move(to: first)
                            for point in points.dropFirst() {
                                path.addLine(to: point)
                            }
                        }
                        .stroke(AppColors.primary.opacity(0.6), lineWidth: 1.5)
                    }

                    // Vertical energy line (orange)
                    if showEnergyRatio {
                        Path { path in
                            let points = generateVerticalEnergyPoints(in: geometry.size)
                            guard let first = points.first else { return }
                            path.move(to: first)
                            for point in points.dropFirst() {
                                path.addLine(to: point)
                            }
                        }
                        .stroke(AppColors.cardOrange.opacity(0.6), lineWidth: 1.5)
                    }

                    // Main engagement line
                    Path { path in
                        let points = generateEngagementPoints(in: geometry.size)
                        guard let first = points.first else { return }
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(AppColors.primary, lineWidth: 2)

                    // Fill area
                    Path { path in
                        let points = generateEngagementPoints(in: geometry.size)
                        guard let first = points.first else { return }
                        path.move(to: CGPoint(x: first.x, y: geometry.size.height))
                        path.addLine(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                        path.addLine(to: CGPoint(x: points.last?.x ?? geometry.size.width, y: geometry.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [AppColors.primary.opacity(0.4), AppColors.primary.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Energy ratio display
            if showEnergyRatio {
                HStack {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppColors.primary)
                            .frame(width: 8, height: 8)
                        Text("Forward")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("Ratio: \(String(format: "%.1f", forwardVerticalRatio)):1")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(forwardVerticalRatio > 0.8 ? AppColors.success : AppColors.warning)

                    Spacer()

                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppColors.cardOrange)
                            .frame(width: 8, height: 8)
                        Text("Vertical")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func generateEngagementPoints(in size: CGSize) -> [CGPoint] {
        var points: [CGPoint] = []
        let count = 20

        for i in 0..<count {
            let x = size.width * CGFloat(i) / CGFloat(count - 1)
            // Base engagement with some variation
            let baseY = (100 - engagement) / 100
            let variation = sin(Double(i) * 0.8) * 0.1
            let y = size.height * CGFloat(baseY + variation)
            points.append(CGPoint(x: x, y: max(0, min(size.height, y))))
        }

        return points
    }

    private func generateForwardEnergyPoints(in size: CGSize) -> [CGPoint] {
        var points: [CGPoint] = []
        let count = 20

        for i in 0..<count {
            let x = size.width * CGFloat(i) / CGFloat(count - 1)
            let segmentIndex = min(i * segments.count / count, max(segments.count - 1, 0))
            let segmentImpulsion = segments.isEmpty ? impulsion : segments[segmentIndex].impulsion
            let y = size.height * (1 - CGFloat(segmentImpulsion / 100))
            points.append(CGPoint(x: x, y: max(0, min(size.height, y))))
        }

        return points
    }

    private func generateVerticalEnergyPoints(in size: CGSize) -> [CGPoint] {
        var points: [CGPoint] = []
        let count = 20

        for i in 0..<count {
            let x = size.width * CGFloat(i) / CGFloat(count - 1)
            let segmentIndex = min(i * segments.count / count, max(segments.count - 1, 0))
            // Vertical energy is inverse of impulsion (higher vertical when impulsion is lower)
            let segmentImpulsion = segments.isEmpty ? impulsion : segments[segmentIndex].impulsion
            let verticalEnergy = 100 - segmentImpulsion  // Inverse relationship
            let y = size.height * (1 - CGFloat(verticalEnergy / 100))
            points.append(CGPoint(x: x, y: max(0, min(size.height, y))))
        }

        return points
    }
}

// MARK: - Engagement Band Label

struct EngagementBandLabel: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(color)
                .frame(width: 12, height: 12)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Training Load Chart

struct TrainingLoadChart: View {
    let totalLoad: Double
    let segments: [GaitSegment]
    let rideDuration: TimeInterval
    var heartRateSamples: [HeartRateSample] = []
    var rideStartDate: Date = Date()
    var showHeartRate: Bool = true

    // MET values for intensity coloring
    private func metForGait(_ gait: GaitType) -> Double {
        switch gait {
        case .stationary: return 1.0
        case .walk: return 3.0
        case .trot: return 5.5
        case .canter: return 7.5
        case .gallop: return 12.0
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Variable intensity cumulative area
                Canvas { context, size in
                    let count = 20
                    var previousX: CGFloat = 0

                    for i in 0..<count {
                        let x = size.width * CGFloat(i) / CGFloat(count - 1)
                        let progress = Double(i) / Double(count - 1)
                        let load = pow(progress, 1.3)
                        let y = size.height * (1 - CGFloat(load))

                        // Get gait for this segment
                        let segmentIndex = min(i * segments.count / count, max(segments.count - 1, 0))
                        let gait = segments.isEmpty ? GaitType.walk : segments[segmentIndex].gait
                        let met = metForGait(gait)

                        // Intensity color based on MET value
                        let intensity = min(met / 12.0, 1.0)  // Normalize to 0-1
                        let color = Color(
                            red: 1.0,
                            green: 0.6 - intensity * 0.4,
                            blue: 0.2
                        ).opacity(0.3 + intensity * 0.4)

                        // Draw segment
                        let rect = CGRect(
                            x: previousX,
                            y: y,
                            width: max(1, x - previousX + 1),
                            height: size.height - y
                        )
                        context.fill(Path(rect), with: .color(color))

                        previousX = x
                    }
                }

                // Line
                Path { path in
                    let points = generateLoadPoints(in: geometry.size)
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(AppColors.cardOrange, lineWidth: 2)

                // Heart rate pacing bars overlay
                if showHeartRate && !heartRateSamples.isEmpty {
                    HeartRatePacingBars(
                        samples: heartRateSamples,
                        rideDuration: rideDuration,
                        rideStartDate: rideStartDate
                    )
                    .opacity(0.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func generateLoadPoints(in size: CGSize) -> [CGPoint] {
        var points: [CGPoint] = []
        let count = 20

        for i in 0..<count {
            let x = size.width * CGFloat(i) / CGFloat(count - 1)
            // Cumulative load (exponential growth pattern)
            let progress = Double(i) / Double(count - 1)
            let load = pow(progress, 1.3) // Slight acceleration
            let y = size.height * (1 - CGFloat(load))
            points.append(CGPoint(x: x, y: max(0, y)))
        }

        return points
    }
}

// MARK: - Calmness Badge

struct CalmnessBadge: View {
    let score: Double

    private var color: Color {
        switch score {
        case 0..<40: return AppColors.error
        case 40..<60: return AppColors.warning
        default: return AppColors.success
        }
    }

    private var label: String {
        switch score {
        case 0..<40: return "Tense"
        case 40..<60: return "Alert"
        default: return "Calm"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.caption)
                .fontWeight(.medium)

            Text("\(Int(score))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Tension Heatmap

struct TensionHeatmap: View {
    let segments: [GaitSegment]
    let rideDuration: TimeInterval

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 1) {
                ForEach(0..<20, id: \.self) { index in
                    let tensionValue = tensionForIndex(index)
                    Rectangle()
                        .fill(tensionColor(tensionValue))
                        .frame(width: geometry.size.width / 20 - 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func tensionForIndex(_ index: Int) -> Double {
        guard !segments.isEmpty else { return 0.5 }
        let segmentIndex = min(index * segments.count / 20, segments.count - 1)
        // Use spectral entropy as tension proxy
        return segments[segmentIndex].spectralEntropy
    }

    private func tensionColor(_ value: Double) -> Color {
        switch value {
        case 0..<0.3: return AppColors.success
        case 0.3..<0.6: return AppColors.warning
        default: return AppColors.error
        }
    }
}

// MARK: - Tension Legend Item

struct TensionLegendItem: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Insight Row

struct InsightRow: View {
    let insight: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.caption)
                .foregroundStyle(AppColors.warning)

            Text(insight)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Insight Popup View

struct InsightPopupView: View {
    let insight: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(insight)
                    .font(.body)
                    .padding()

                Spacer()
            }
            .navigationTitle("Segment Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Insight Score Card") {
    HStack {
        InsightScoreCard(
            title: "Rhythm",
            score: 85,
            icon: "metronome",
            isExpanded: false
        ) {}

        InsightScoreCard(
            title: "Stability",
            score: 65,
            icon: "figure.equestrian.sports",
            isExpanded: true
        ) {}

        InsightScoreCard(
            title: "Lead",
            score: 45,
            icon: "arrow.left.arrow.right",
            isExpanded: false
        ) {}
    }
    .padding()
    .background(AppColors.cardBackground)
}
