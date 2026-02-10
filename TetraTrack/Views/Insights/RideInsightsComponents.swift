//
//  RideInsightsComponents.swift
//  TetraTrack
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

// MARK: - Elevation Profile Section (1.2)

struct RideElevationProfileChart: View {
    let elevationProfile: [(distance: Double, altitude: Double)]
    let elevationGain: Double
    let elevationLoss: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Elevation Profile")
                    .font(.subheadline.weight(.medium))
                Spacer()
                HStack(spacing: 12) {
                    Label(String(format: "%.0fm", elevationGain), systemImage: "arrow.up")
                        .font(.caption)
                        .foregroundStyle(AppColors.success)
                    Label(String(format: "%.0fm", elevationLoss), systemImage: "arrow.down")
                        .font(.caption)
                        .foregroundStyle(AppColors.error)
                }
            }

            if elevationProfile.count >= 2 {
                Chart {
                    ForEach(Array(elevationProfile.enumerated()), id: \.offset) { index, point in
                        AreaMark(
                            x: .value("Distance", point.distance),
                            y: .value("Altitude", point.altitude)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.success.opacity(0.3), AppColors.success.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Distance", point.distance),
                            y: .value("Altitude", point.altitude)
                        )
                        .foregroundStyle(AppColors.success)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .chartXAxisLabel("Distance (m)")
                .chartYAxisLabel("Altitude (m)")
                .frame(height: 120)
            } else {
                Text("Insufficient elevation data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Heart Rate By Gait Card (1.5)

struct HeartRateByGaitCard: View {
    let gaitHRData: [(gait: String, avgHR: Int, duration: TimeInterval)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heart Rate by Gait")
                .font(.subheadline.weight(.medium))

            if !gaitHRData.isEmpty {
                Chart {
                    ForEach(gaitHRData, id: \.gait) { item in
                        BarMark(
                            x: .value("HR", item.avgHR),
                            y: .value("Gait", item.gait)
                        )
                        .foregroundStyle(hrColor(item.avgHR))
                        .annotation(position: .trailing) {
                            Text("\(item.avgHR) bpm")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .chartXAxisLabel("Average HR (bpm)")
                .frame(height: CGFloat(gaitHRData.count) * 40 + 20)
            }
        }
    }

    private func hrColor(_ hr: Int) -> Color {
        switch hr {
        case 0..<100: return AppColors.success
        case 100..<140: return AppColors.warning
        default: return AppColors.error
        }
    }
}

// MARK: - Missing Ride Metrics Grid (1.6)

struct RideMetricsGrid: View {
    let minHeartRate: Int
    let maxHeartRate: Int
    let averageHeartRate: Int
    let maxSpeed: Double
    let elevationGain: Double
    let elevationLoss: Double

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if minHeartRate > 0 {
                RideMetricCell(label: "Min HR", value: "\(minHeartRate)", unit: "bpm", icon: "heart", color: AppColors.success)
            }
            if maxHeartRate > 0 {
                RideMetricCell(label: "Max HR", value: "\(maxHeartRate)", unit: "bpm", icon: "heart.fill", color: AppColors.error)
            }
            if averageHeartRate > 0 {
                RideMetricCell(label: "Avg HR", value: "\(averageHeartRate)", unit: "bpm", icon: "heart.circle", color: AppColors.warning)
            }
            if maxSpeed > 0 {
                RideMetricCell(label: "Max Speed", value: maxSpeed.formattedSpeed, unit: "", icon: "speedometer", color: AppColors.primary)
            }
            if elevationGain > 0 {
                RideMetricCell(label: "Ascent", value: String(format: "%.0f", elevationGain), unit: "m", icon: "arrow.up.right", color: AppColors.success)
            }
            if elevationLoss > 0 {
                RideMetricCell(label: "Descent", value: String(format: "%.0f", elevationLoss), unit: "m", icon: "arrow.down.right", color: AppColors.error)
            }
        }
    }
}

struct RideMetricCell: View {
    let label: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.weight(.bold))
            if !unit.isEmpty {
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Symmetry Drift Chart (2.5)

struct SymmetryDriftChart: View {
    let startSymmetry: Double
    let midSymmetry: Double
    let endSymmetry: Double

    private var hasDegradation: Bool {
        startSymmetry - endSymmetry > 10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Symmetry Over Time")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if hasDegradation {
                    Text("Degraded \(Int(startSymmetry - endSymmetry))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.warning)
                }
            }

            Chart {
                LineMark(x: .value("Phase", "Start"), y: .value("Symmetry", startSymmetry))
                    .foregroundStyle(AppColors.primary)
                LineMark(x: .value("Phase", "Mid"), y: .value("Symmetry", midSymmetry))
                    .foregroundStyle(AppColors.primary)
                LineMark(x: .value("Phase", "End"), y: .value("Symmetry", endSymmetry))
                    .foregroundStyle(AppColors.primary)

                PointMark(x: .value("Phase", "Start"), y: .value("Symmetry", startSymmetry))
                    .foregroundStyle(AppColors.success)
                PointMark(x: .value("Phase", "Mid"), y: .value("Symmetry", midSymmetry))
                    .foregroundStyle(AppColors.warning)
                PointMark(x: .value("Phase", "End"), y: .value("Symmetry", endSymmetry))
                    .foregroundStyle(hasDegradation ? AppColors.error : AppColors.success)
            }
            .chartYScale(domain: 0...100)
            .frame(height: 100)

            HStack {
                Text("Start: \(Int(startSymmetry))%")
                    .font(.caption2)
                Spacer()
                Text("Mid: \(Int(midSymmetry))%")
                    .font(.caption2)
                Spacer()
                Text("End: \(Int(endSymmetry))%")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Rein By Gait Breakdown Card (2.7)

struct ReinByGaitBreakdownCard: View {
    let reinGaitData: [(gait: String, leftRhythm: Double, rightRhythm: Double, leftSymmetry: Double, rightSymmetry: Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Per-Rein by Gait")
                .font(.subheadline.weight(.medium))

            ForEach(reinGaitData, id: \.gait) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.gait)
                        .font(.caption.weight(.medium))

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Left Rein")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Text("R:\(Int(item.leftRhythm)) S:\(Int(item.leftSymmetry))")
                                .font(.caption.monospacedDigit())
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Right Rein")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Text("R:\(Int(item.rightRhythm)) S:\(Int(item.rightSymmetry))")
                                .font(.caption.monospacedDigit())
                        }

                        Spacer()

                        let diff = abs(item.leftRhythm - item.rightRhythm)
                        if diff > 10 {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(AppColors.warning)
                        }
                    }
                }
                Divider()
            }
        }
    }
}

// MARK: - Transition Quality Breakdown (2.8)

struct TransitionBreakdownCard: View {
    let upwardQuality: Double
    let downwardQuality: Double
    let upwardCount: Int
    let downwardCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transition Breakdown")
                .font(.subheadline.weight(.medium))

            HStack(spacing: 20) {
                TransitionDirectionStat(
                    label: "Upward",
                    icon: "arrow.up.circle.fill",
                    quality: upwardQuality,
                    count: upwardCount,
                    color: AppColors.success
                )

                TransitionDirectionStat(
                    label: "Downward",
                    icon: "arrow.down.circle.fill",
                    quality: downwardQuality,
                    count: downwardCount,
                    color: AppColors.warning
                )
            }

            if upwardQuality > 0 && downwardQuality > 0 {
                let weaker = upwardQuality < downwardQuality ? "Upward" : "Downward"
                Text("\(weaker) transitions need smoother preparation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
    }
}

private struct TransitionDirectionStat: View {
    let label: String
    let icon: String
    let quality: Double
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text("\(Int(quality * 100))/100")
                .font(.headline)
            Text("\(label) (\(count))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Jump Event Timeline (2.13)

struct JumpEventTimeline: View {
    let jumpCount: Int
    let rideDuration: TimeInterval

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.up.forward.circle.fill")
                .font(.title3)
                .foregroundStyle(AppColors.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(jumpCount) jumps detected")
                    .font(.subheadline.weight(.medium))
                Text("Distributed across \(rideDuration.formattedDuration) ride")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(AppColors.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
