//
//  ShootingHistoryService.swift
//  TrackRide
//
//  Aggregation service for historical shooting patterns with trend analysis and insights generation.
//

import Foundation
import SwiftUI

// MARK: - Aggregated Metrics

/// Aggregated metrics computed from multiple shooting patterns
struct AggregatedShootingMetrics {
    let averageImpactPoint: CGPoint     // Weighted average impact point (formerly MPI)
    let groupRadius: Double             // Weighted average group radius
    let offset: Double                  // Distance from center to average impact point
    let outliersCount: Int              // Total outliers across all patterns
    let totalShots: Int                 // Total shots across all patterns
    let clusterShots: Int               // Total shots in clusters
    let sessionCount: Int               // Number of sessions/patterns
    let shotsByDay: [Date: Int]         // Shot counts by day
    let radiusTrend: [(date: Date, radius: Double)]  // Group radius over time

    /// Analysis confidence level based on data quality
    var confidence: AnalysisConfidence {
        // High confidence: 15+ shots with consistent spread
        if totalShots >= 15 && sessionCount >= 2 {
            return .high
        }
        // Medium confidence: 8-14 shots or single session with good count
        else if totalShots >= 8 {
            return .medium
        }
        // Low confidence: less than 8 shots
        else {
            return .low
        }
    }

    /// Confidence explanation for display
    var confidenceExplanation: String {
        switch confidence {
        case .high:
            return "Based on \(totalShots) shots across \(sessionCount) session\(sessionCount == 1 ? "" : "s")"
        case .medium:
            return "Based on \(totalShots) shots - more practice will improve accuracy"
        case .low:
            return "Limited data (\(totalShots) shots) - keep practicing for better insights"
        }
    }

    /// Whether bias is significant enough to report (above 5-7% of target)
    var hasMeaningfulBias: Bool {
        offset > 0.07  // 7% of normalized target radius
    }

    /// Percentage of shots that are outliers
    var outlierPercentage: Double {
        guard totalShots > 0 else { return 0 }
        return Double(outliersCount) / Double(totalShots) * 100
    }

    /// Formatted group radius for display
    var formattedGroupRadius: String {
        String(format: "%.2f", groupRadius)
    }

    /// Formatted offset for display
    var formattedOffset: String {
        String(format: "%.2f", offset)
    }

    // MARK: - Backward Compatibility

    /// Alias for averageImpactPoint (backward compatibility)
    var mpi: CGPoint { averageImpactPoint }
}

// MARK: - Shooting Insights

/// Generated insights from shooting history analysis
struct ShootingInsights {
    let clusterDescription: String      // Description of shot cluster quality (Observation)
    let trendDescription: String        // Trend over time
    let outlierDescription: String?     // Outlier explanation if relevant
    let biasDescription: String?        // Bias direction explanation
    let practiceFocusText: String       // What to focus on in practice
    let suggestedDrills: [String]       // Recommended drills

    /// Combined insight text for display
    var combinedText: String {
        var parts = [clusterDescription, trendDescription]
        if let outlier = outlierDescription {
            parts.append(outlier)
        }
        if let bias = biasDescription {
            parts.append(bias)
        }
        return parts.joined(separator: " ")
    }

    /// Backward-compatible initializer
    init(
        clusterDescription: String,
        trendDescription: String,
        outlierDescription: String?,
        biasDescription: String?,
        suggestedDrills: [String],
        practiceFocusText: String = ""
    ) {
        self.clusterDescription = clusterDescription
        self.trendDescription = trendDescription
        self.outlierDescription = outlierDescription
        self.biasDescription = biasDescription
        self.practiceFocusText = practiceFocusText
        self.suggestedDrills = suggestedDrills
    }
}

// MARK: - Trend Direction

enum ShootingTrendDirection {
    case improving
    case declining
    case stable

    var description: String {
        switch self {
        case .improving: return "improving"
        case .declining: return "getting wider"
        case .stable: return "staying consistent"
        }
    }

    var icon: String {
        switch self {
        case .improving: return "arrow.down.right"
        case .declining: return "arrow.up.right"
        case .stable: return "arrow.right"
        }
    }

    var color: Color {
        switch self {
        case .improving: return .green
        case .declining: return .orange
        case .stable: return .blue
        }
    }
}

// MARK: - Shooting History Service

@Observable
final class ShootingHistoryService {
    private let historyManager: ShotPatternHistoryManager

    init(historyManager: ShotPatternHistoryManager = ShotPatternHistoryManager()) {
        self.historyManager = historyManager
    }

    // MARK: - Metric Computation

    /// Compute aggregated metrics from a collection of patterns
    func computeMetrics(patterns: [StoredTargetPattern]) -> AggregatedShootingMetrics {
        guard !patterns.isEmpty else {
            return AggregatedShootingMetrics(
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

        // Calculate weighted average impact point
        var totalMpiX = 0.0
        var totalMpiY = 0.0
        var totalGroupRadius = 0.0
        var totalWeight = 0.0
        var totalOutliers = 0
        var totalShots = 0
        var totalClusterShots = 0

        let calendar = Calendar.current
        var shotsByDay: [Date: Int] = [:]
        var radiusByDate: [(date: Date, radius: Double)] = []

        for pattern in patterns {
            let weight = Double(pattern.shotCount)
            totalMpiX += pattern.clusterMpiX * weight
            totalMpiY += pattern.clusterMpiY * weight
            totalGroupRadius += pattern.clusterRadius * weight
            totalWeight += weight
            totalOutliers += pattern.outlierCount
            totalShots += pattern.shotCount
            totalClusterShots += pattern.clusterShotCount

            // Aggregate by day
            let day = calendar.startOfDay(for: pattern.timestamp)
            shotsByDay[day, default: 0] += pattern.shotCount

            // Track radius trend
            radiusByDate.append((date: pattern.timestamp, radius: pattern.clusterRadius))
        }

        let mpiX = totalWeight > 0 ? totalMpiX / totalWeight : 0
        let mpiY = totalWeight > 0 ? totalMpiY / totalWeight : 0
        let avgRadius = totalWeight > 0 ? totalGroupRadius / totalWeight : 0
        let offset = sqrt(mpiX * mpiX + mpiY * mpiY)

        // Sort trend data by date
        radiusByDate.sort { $0.date < $1.date }

        return AggregatedShootingMetrics(
            averageImpactPoint: CGPoint(x: mpiX, y: mpiY),
            groupRadius: avgRadius,
            offset: offset,
            outliersCount: totalOutliers,
            totalShots: totalShots,
            clusterShots: totalClusterShots,
            sessionCount: patterns.count,
            shotsByDay: shotsByDay,
            radiusTrend: radiusByDate
        )
    }

    // MARK: - Insight Generation

    /// Generate youth-friendly insights from metrics and patterns
    /// Uses ring-aware analysis for human-aligned descriptions
    func generateInsights(
        metrics: AggregatedShootingMetrics,
        patterns: [StoredTargetPattern]
    ) -> ShootingInsights {
        // Collect all shots for ring-aware analysis
        var allShots: [CGPoint] = []
        for pattern in patterns {
            allShots.append(contentsOf: pattern.normalizedShots)
        }

        // Try ring-aware analysis first for better insights
        if let ringAnalysis = RingAwareAnalyzer.analyze(normalizedShots: allShots) {
            let ringInsights = RingAwareAnalyzer.generateInsights(from: ringAnalysis)

            // Build cluster description from ring analysis
            let clusterDescription = ringInsights.overallSummary

            // Build trend description
            let trendDescription = generateTrendDescription(metrics: metrics)

            // Ring-aware outlier description
            let outlierDescription = ringInsights.notableExceptions

            // Ring-aware bias description
            let biasDescription = ringInsights.positionTendency

            // Ring-aware drill suggestions
            let suggestedDrills = ringInsights.trainingHints

            // Generate practice focus
            let practiceFocus = ringInsights.groupingDescription

            return ShootingInsights(
                clusterDescription: clusterDescription,
                trendDescription: trendDescription,
                outlierDescription: outlierDescription,
                biasDescription: biasDescription,
                suggestedDrills: suggestedDrills,
                practiceFocusText: practiceFocus
            )
        }

        // Fallback to traditional analysis
        let clusterDescription = generateClusterDescription(metrics: metrics)
        let trendDescription = generateTrendDescription(metrics: metrics)
        let outlierDescription = generateOutlierDescription(metrics: metrics)
        let biasDescription = generateBiasDescription(metrics: metrics)
        let suggestedDrills = generateDrillSuggestions(metrics: metrics)
        let practiceFocus = generatePracticeFocus(metrics: metrics)

        return ShootingInsights(
            clusterDescription: clusterDescription,
            trendDescription: trendDescription,
            outlierDescription: outlierDescription,
            biasDescription: biasDescription,
            suggestedDrills: suggestedDrills,
            practiceFocusText: practiceFocus
        )
    }

    // MARK: - Trend Analysis

    /// Calculate the trend direction based on group radius over time
    func calculateTrend(metrics: AggregatedShootingMetrics) -> ShootingTrendDirection {
        let trend = metrics.radiusTrend
        guard trend.count >= 3 else { return .stable }

        // Compare first half average to second half average
        let midpoint = trend.count / 2
        let firstHalf = Array(trend.prefix(midpoint))
        let secondHalf = Array(trend.suffix(midpoint))

        let firstAvg = firstHalf.isEmpty ? 0 : firstHalf.reduce(0) { $0 + $1.radius } / Double(firstHalf.count)
        let secondAvg = secondHalf.isEmpty ? 0 : secondHalf.reduce(0) { $0 + $1.radius } / Double(secondHalf.count)

        let difference = secondAvg - firstAvg
        let threshold = 0.02  // 2% change threshold

        if difference < -threshold {
            return .improving  // Smaller radius = tighter group = improvement
        } else if difference > threshold {
            return .declining  // Larger radius = wider group = declining
        }
        return .stable
    }

    // MARK: - Visual Data Generation

    /// Generate visual pattern data for the aggregate view
    func generateVisualData(patterns: [StoredTargetPattern]) -> VisualPatternData {
        var allShots: [VisualPatternData.NormalizedShotPoint] = []

        for pattern in patterns {
            for shot in pattern.normalizedShots {
                allShots.append(VisualPatternData.NormalizedShotPoint(
                    position: shot,
                    isCurrentTarget: false,
                    isOutlier: false,  // Individual outlier status not tracked in aggregate
                    timestamp: pattern.timestamp
                ))
            }
        }

        let metrics = computeMetrics(patterns: patterns)

        return VisualPatternData(
            currentTargetShots: [],
            historicalShots: allShots,
            mpiCurrent: nil,
            mpiAggregate: metrics.mpi,
            groupRadiusCurrent: nil,
            groupRadiusAggregate: metrics.groupRadius
        )
    }

    // MARK: - Pattern Label Computation

    /// Compute a pattern label from aggregate metrics
    func computePatternLabel(metrics: AggregatedShootingMetrics) -> PatternLabel {
        let tightness = classifyTightness(metrics.groupRadius)
        let biasSeverity = classifyBiasSeverity(metrics.offset)
        let biasDirection = determineBiasDirectionEnum(mpi: metrics.averageImpactPoint, offset: metrics.offset)

        return PatternLabel(
            tightness: tightness,
            bias: biasDirection,
            biasSeverity: biasSeverity
        )
    }

    private func classifyBiasSeverity(_ offset: Double) -> BiasSeverity {
        if offset <= ShotPatternAnalyzer.Thresholds.centeredOffset {
            return .centered
        } else if offset <= ShotPatternAnalyzer.Thresholds.slightOffset {
            return .slight
        } else {
            return .significant
        }
    }

    private func determineBiasDirectionEnum(mpi: CGPoint, offset: Double) -> BiasDirection {
        let threshold = ShotPatternAnalyzer.Thresholds.directionDeadZone

        guard offset >= threshold else { return .centered }

        let absX = abs(mpi.x)
        let absY = abs(mpi.y)

        let hasHorizontalBias = absX > threshold
        let hasVerticalBias = absY > threshold

        let isLeft = mpi.x < 0
        let isHigh = mpi.y < 0

        if hasHorizontalBias && hasVerticalBias {
            if isHigh && isLeft { return .highLeft }
            if isHigh && !isLeft { return .highRight }
            if !isHigh && isLeft { return .lowLeft }
            return .lowRight
        } else if hasHorizontalBias {
            return isLeft ? .left : .right
        } else if hasVerticalBias {
            return isHigh ? .high : .low
        }

        return .centered
    }

    // MARK: - Private Helpers

    private func generateClusterDescription(metrics: AggregatedShootingMetrics) -> String {
        guard metrics.sessionCount > 0 else {
            return "Start practicing to see your shot patterns!"
        }

        let tightness = classifyTightness(metrics.groupRadius)

        // Observational descriptions - state facts, not judgments
        switch tightness {
        case .tight:
            return "Your shots form a tight cluster across \(metrics.sessionCount) target\(metrics.sessionCount == 1 ? "" : "s")."
        case .moderate:
            return "\(metrics.totalShots) shots across \(metrics.sessionCount) target\(metrics.sessionCount == 1 ? "" : "s") show a moderate spread."
        case .wide:
            return "\(metrics.totalShots) shots across \(metrics.sessionCount) target\(metrics.sessionCount == 1 ? "" : "s") are widely distributed."
        }
    }

    private func generateTrendDescription(metrics: AggregatedShootingMetrics) -> String {
        let trend = calculateTrend(metrics: metrics)

        // Observational trend descriptions
        switch trend {
        case .improving:
            return "Recent sessions show tighter groupings than earlier ones."
        case .declining:
            return "Recent sessions show wider groupings than earlier ones."
        case .stable:
            return "Grouping spread has been consistent across sessions."
        }
    }

    private func generateOutlierDescription(metrics: AggregatedShootingMetrics) -> String? {
        guard metrics.outliersCount > 0 else { return nil }

        let percentage = metrics.outlierPercentage

        // Observational descriptions without judgment
        if percentage < 10 {
            return "\(metrics.outliersCount) shot\(metrics.outliersCount == 1 ? "" : "s") landed outside the main cluster."
        } else if percentage < 20 {
            return "\(metrics.outliersCount) shots (\(Int(percentage))%) fell outside your main groups."
        } else {
            return "About \(Int(percentage))% of shots landed away from the main cluster."
        }
    }

    private func generateBiasDescription(metrics: AggregatedShootingMetrics) -> String? {
        // Only report bias if it's meaningful (above 7% of target radius)
        guard metrics.hasMeaningfulBias else { return nil }

        let direction = determineBiasDirection(mpi: metrics.averageImpactPoint)
        let offset = metrics.offset

        // Observational descriptions without judgment
        if offset > 0.15 {
            return "Your average impact point is \(direction) of center."
        } else {
            return "Shots tend toward the \(direction) side of the target."
        }
    }

    private func generatePracticeFocus(metrics: AggregatedShootingMetrics) -> String {
        let tightness = classifyTightness(metrics.groupRadius)
        let biasSeverity = classifyBiasSeverity(metrics.offset)

        switch (tightness, biasSeverity) {
        case (.tight, .centered):
            return "You're showing excellent consistency! Many athletes at this level focus on maintaining their routine and staying relaxed."

        case (.tight, .slight):
            return "Your grouping is great! With a tight cluster like this, small adjustments to your natural point of aim often help center the group."

        case (.tight, .significant):
            return "Excellent grouping consistency! Your shots are landing together, which is the first goal. Athletes often explore their natural point of aim to shift the group."

        case (.moderate, .centered):
            return "You're building good habits with your shots balanced around center. Developing a consistent shot routine often helps tighten groups."

        case (.moderate, .slight), (.moderate, .significant):
            return "Building consistency is the focus at this stage. Many athletes benefit from slowing down and focusing on one element at a time."

        case (.wide, .centered):
            return "Your shots are balanced around center, which is a good foundation. Working on stability and developing a repeatable routine often helps tighten groups."

        case (.wide, _):
            return "Developing a steady, repeatable routine is often helpful. Many athletes focus on stability and taking their time between shots."
        }
    }

    private func generateDrillSuggestions(metrics: AggregatedShootingMetrics) -> [String] {
        var drills: [String] = []

        let tightness = classifyTightness(metrics.groupRadius)
        let offset = metrics.offset

        // Based on tightness
        switch tightness {
        case .tight:
            drills.append("Maintain your current routine")
            if offset > 0.1 {
                drills.append("Natural point of aim adjustment")
            }
        case .moderate:
            drills.append("Develop a shot routine checklist")
            drills.append("Breathing and settle drill")
        case .wide:
            drills.append("Stability hold drill")
            drills.append("Balance and stance check")
        }

        // Based on outliers
        if metrics.outlierPercentage > 15 {
            drills.append("Smooth trigger control practice")
        }

        // Based on bias
        if offset > 0.15 {
            drills.append("Natural point of aim check")
        }

        return Array(drills.prefix(3))  // Return top 3 suggestions
    }

    private func classifyTightness(_ radius: Double) -> GroupTightness {
        // Use canonical thresholds from ShotPatternAnalyzer
        if radius <= ShotPatternAnalyzer.Thresholds.tightGroup {
            return .tight
        } else if radius <= ShotPatternAnalyzer.Thresholds.moderateGroup {
            return .moderate
        } else {
            return .wide
        }
    }

    private func determineBiasDirection(mpi: CGPoint) -> String {
        // Use canonical threshold from ShotPatternAnalyzer
        let threshold = ShotPatternAnalyzer.Thresholds.directionDeadZone

        let horizontal: String? = {
            if mpi.x < -threshold { return "left" }
            if mpi.x > threshold { return "right" }
            return nil
        }()

        let vertical: String? = {
            if mpi.y < -threshold { return "high" }
            if mpi.y > threshold { return "low" }
            return nil
        }()

        switch (vertical, horizontal) {
        case (let v?, let h?): return "\(v) and \(h)"
        case (let v?, nil): return v
        case (nil, let h?): return h
        default: return "center"
        }
    }
}
