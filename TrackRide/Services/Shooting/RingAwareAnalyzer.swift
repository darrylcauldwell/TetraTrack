//
//  RingAwareAnalyzer.swift
//  TrackRide
//
//  Ring-aware shot pattern analysis for Tetrathlon air pistol practice.
//  Uses scoring rings as the primary interpretive structure for human-aligned insights.
//

import Foundation
import CoreGraphics

// MARK: - Ring Classification Types

/// Tetrathlon scoring ring values
enum TetrathlonRing: Int, Codable, CaseIterable, Comparable {
    case ten = 10
    case eight = 8
    case six = 6
    case four = 4
    case two = 2
    case miss = 0

    static func < (lhs: TetrathlonRing, rhs: TetrathlonRing) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .ten: return "10 ring"
        case .eight: return "8 ring"
        case .six: return "6 ring"
        case .four: return "4 ring"
        case .two: return "2 ring"
        case .miss: return "off target"
        }
    }

    /// Ring weight for weighted calculations (central rings weighted higher)
    var weight: Double {
        switch self {
        case .ten: return 1.0
        case .eight: return 0.7
        case .six: return 0.4
        case .four: return 0.2
        case .two: return 0.1
        case .miss: return 0.05
        }
    }

    /// Normalized outer radius for this ring
    var normalizedRadius: Double {
        TetrathlonTargetGeometry.normalizedScoringRadii
            .first { $0.score == self.rawValue }?.normalizedRadius ?? 1.0
    }

    /// Adjacent inner ring (nil for 10)
    var innerRing: TetrathlonRing? {
        switch self {
        case .ten: return nil
        case .eight: return .ten
        case .six: return .eight
        case .four: return .six
        case .two: return .four
        case .miss: return .two
        }
    }

    /// Adjacent outer ring (nil for miss)
    var outerRing: TetrathlonRing? {
        switch self {
        case .ten: return .eight
        case .eight: return .six
        case .six: return .four
        case .four: return .two
        case .two: return .miss
        case .miss: return nil
        }
    }
}

/// A shot with its ring classification
struct ClassifiedShot: Codable, Identifiable {
    let id: UUID
    let position: CGPoint
    let ring: TetrathlonRing
    let ellipticalDistance: Double
    let isOutlier: Bool

    init(id: UUID = UUID(), position: CGPoint, ring: TetrathlonRing, ellipticalDistance: Double, isOutlier: Bool = false) {
        self.id = id
        self.position = position
        self.ring = ring
        self.ellipticalDistance = ellipticalDistance
        self.isOutlier = isOutlier
    }
}

/// Ring distribution metrics
struct RingDistribution: Codable, Equatable {
    let shotsByRing: [TetrathlonRing: Int]
    let percentageByRing: [TetrathlonRing: Double]
    let innermostRing: TetrathlonRing
    let outermostRing: TetrathlonRing
    let coreClusterRing: TetrathlonRing  // Innermost ring containing ≥70% of shots
    let ringSpread: Int  // Number of distinct rings occupied

    /// Shots in the core cluster ring and inner
    var coreClusterPercentage: Double {
        var cumulative = 0.0
        for ring in TetrathlonRing.allCases.reversed() {  // Start from 10
            cumulative += percentageByRing[ring] ?? 0
            if ring == coreClusterRing { break }
        }
        return cumulative
    }
}

// MARK: - Ring-Relative Grouping

/// Grouping quality based on ring containment
enum RingGroupingQuality: String, Codable {
    case veryTight    // All shots in one ring
    case tight        // Shots in two adjacent rings
    case moderate     // Shots across three rings
    case wide         // Shots across four or more rings

    var description: String {
        switch self {
        case .veryTight: return "very tight"
        case .tight: return "tight"
        case .moderate: return "moderate"
        case .wide: return "spread"
        }
    }

    var humanDescription: String {
        switch self {
        case .veryTight: return "Very tight grouping"
        case .tight: return "Tight grouping"
        case .moderate: return "Moderate grouping"
        case .wide: return "Wide grouping"
        }
    }
}

// MARK: - Directional Bias with Confidence Gating

/// Confidence-gated directional bias
struct GatedDirectionalBias: Codable, Equatable {
    let direction: BiasDirection
    let strength: BiasStrength
    let confidence: Double  // 0-1, percentage of shots on that side
    let isSignificant: Bool  // Meets threshold for reporting
    let ringDistance: TetrathlonRing  // Ring containing the MPI

    enum BiasStrength: String, Codable {
        case none
        case verySlightly  // Inside 10 ring
        case slightly      // Inside 8 ring
        case consistently  // Inside 6 ring or worse

        var description: String {
            switch self {
            case .none: return ""
            case .verySlightly: return "very slightly"
            case .slightly: return "slightly"
            case .consistently: return "consistently"
            }
        }
    }

    var humanDescription: String? {
        guard isSignificant, direction != .centered else { return nil }
        return "\(strength.description) \(direction.description)".trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Ring-Aware Cluster Analysis

/// Enhanced cluster analysis with ring-based metrics
struct RingAwareClusterAnalysis: Codable {
    // Core cluster data
    let coreClusterShots: [ClassifiedShot]
    let outlierShots: [ClassifiedShot]
    let allClassifiedShots: [ClassifiedShot]

    // Ring metrics
    let ringDistribution: RingDistribution
    let groupingQuality: RingGroupingQuality

    // Ring-weighted MPI
    let weightedMpiX: Double
    let weightedMpiY: Double
    let weightedMpiRing: TetrathlonRing

    // Directional bias with confidence gating
    let directionalBias: GatedDirectionalBias

    // Traditional metrics (for compatibility)
    let clusterRadius: Double
    let clusterOffset: Double

    var coreClusterCount: Int { coreClusterShots.count }
    var outlierCount: Int { outlierShots.count }
    var totalCount: Int { allClassifiedShots.count }
}

// MARK: - Ring-Aware Pattern Result

/// Analysis result with ring-aware insights
struct RingAwarePatternResult: Codable {
    // Ring metrics
    let ringDistribution: RingDistribution
    let groupingQuality: RingGroupingQuality
    let directionalBias: GatedDirectionalBias

    // Human-aligned insights
    let overallSummary: String
    let groupingDescription: String
    let positionTendency: String?
    let notableExceptions: String?
    let trainingHints: [String]

    // Confidence
    let insightConfidence: InsightConfidence

    // Metrics for storage
    let coreClusterRing: TetrathlonRing
    let weightedMpiX: Double
    let weightedMpiY: Double
    let coreClusterShotCount: Int
    let outlierCount: Int
    let totalShotCount: Int
}

/// Insight confidence scoring
struct InsightConfidence: Codable {
    let level: AnalysisConfidence
    let shotCountScore: Double      // 0-1
    let ringConcentrationScore: Double  // 0-1
    let outlierRatioScore: Double   // 0-1
    let overallScore: Double        // 0-1

    var disclaimerNeeded: Bool { overallScore < 0.5 }

    var disclaimer: String? {
        guard disclaimerNeeded else { return nil }
        if shotCountScore < 0.3 {
            return "Limited data — insights may be less reliable."
        } else if outlierRatioScore < 0.3 {
            return "High variation — patterns may still be developing."
        }
        return "These insights are based on a small sample."
    }
}

// MARK: - Ring-Aware Analyzer

final class RingAwareAnalyzer {

    // MARK: - Configuration

    private struct Config {
        // Core cluster threshold
        static let coreClusterPercentage = 0.70  // 70% of shots

        // Bias confidence thresholds
        static let biasConfidenceThreshold = 0.60  // 60% on same side
        static let biasMinimumRingFraction = 0.03  // Minimum offset as fraction of ring

        // Minimum shots for analysis
        static let minimumShots = 3

        // Confidence scoring
        static let highConfidenceShotCount = 15
        static let mediumConfidenceShotCount = 8
    }

    // MARK: - Main Analysis Entry Point

    /// Perform ring-aware analysis on normalized shots
    static func analyze(normalizedShots: [CGPoint]) -> RingAwareClusterAnalysis? {
        guard normalizedShots.count >= Config.minimumShots else { return nil }

        // Step 1: Classify all shots into rings
        let classifiedShots = classifyShots(normalizedShots)

        // Step 2: Calculate ring distribution
        let ringDistribution = calculateRingDistribution(classifiedShots)

        // Step 3: Identify core cluster (innermost ring containing ≥70% of shots)
        let (coreClusterShots, outlierShots) = identifyCoreCluster(
            classifiedShots,
            coreClusterRing: ringDistribution.coreClusterRing
        )

        // Step 4: Determine grouping quality from ring spread
        let groupingQuality = determineGroupingQuality(ringDistribution)

        // Step 5: Calculate ring-weighted MPI
        let (weightedMpiX, weightedMpiY) = calculateWeightedMPI(coreClusterShots)
        let weightedMpiRing = classifyPosition(x: weightedMpiX, y: weightedMpiY)

        // Step 6: Calculate directional bias with confidence gating
        let directionalBias = calculateGatedDirectionalBias(
            coreClusterShots: coreClusterShots,
            weightedMpiX: weightedMpiX,
            weightedMpiY: weightedMpiY,
            mpiRing: weightedMpiRing
        )

        // Step 7: Calculate traditional metrics for compatibility
        let clusterRadius = calculateClusterRadius(coreClusterShots, mpiX: weightedMpiX, mpiY: weightedMpiY)
        let clusterOffset = sqrt(weightedMpiX * weightedMpiX + weightedMpiY * weightedMpiY)

        return RingAwareClusterAnalysis(
            coreClusterShots: coreClusterShots,
            outlierShots: outlierShots,
            allClassifiedShots: classifiedShots,
            ringDistribution: ringDistribution,
            groupingQuality: groupingQuality,
            weightedMpiX: weightedMpiX,
            weightedMpiY: weightedMpiY,
            weightedMpiRing: weightedMpiRing,
            directionalBias: directionalBias,
            clusterRadius: clusterRadius,
            clusterOffset: clusterOffset
        )
    }

    // MARK: - Step 1: Shot Classification

    private static func classifyShots(_ normalizedShots: [CGPoint]) -> [ClassifiedShot] {
        return normalizedShots.map { shot in
            let ring = classifyPosition(x: shot.x, y: shot.y)
            let ellipticalDistance = calculateEllipticalDistance(x: shot.x, y: shot.y)
            return ClassifiedShot(
                position: shot,
                ring: ring,
                ellipticalDistance: ellipticalDistance
            )
        }
    }

    private static func classifyPosition(x: Double, y: Double) -> TetrathlonRing {
        let position = NormalizedTargetPosition(x: x, y: y)
        let score = TetrathlonTargetGeometry.score(from: position)
        return TetrathlonRing(rawValue: score) ?? .miss
    }

    private static func calculateEllipticalDistance(x: Double, y: Double) -> Double {
        let position = NormalizedTargetPosition(x: x, y: y)
        return position.ellipticalDistance(aspectRatio: TetrathlonTargetGeometry.aspectRatio)
    }

    // MARK: - Step 2: Ring Distribution

    private static func calculateRingDistribution(_ shots: [ClassifiedShot]) -> RingDistribution {
        var shotsByRing: [TetrathlonRing: Int] = [:]
        var innermostRing: TetrathlonRing = .miss
        var outermostRing: TetrathlonRing = .ten

        for shot in shots {
            shotsByRing[shot.ring, default: 0] += 1
            if shot.ring > innermostRing { innermostRing = shot.ring }
            if shot.ring < outermostRing { outermostRing = shot.ring }
        }

        let total = Double(shots.count)
        var percentageByRing: [TetrathlonRing: Double] = [:]
        for (ring, count) in shotsByRing {
            percentageByRing[ring] = Double(count) / total
        }

        // Find core cluster ring (innermost ring containing ≥70% of shots)
        let coreClusterRing = findCoreClusterRing(percentageByRing)

        // Count distinct rings occupied
        let ringSpread = shotsByRing.keys.count

        return RingDistribution(
            shotsByRing: shotsByRing,
            percentageByRing: percentageByRing,
            innermostRing: innermostRing,
            outermostRing: outermostRing,
            coreClusterRing: coreClusterRing,
            ringSpread: ringSpread
        )
    }

    private static func findCoreClusterRing(_ percentageByRing: [TetrathlonRing: Double]) -> TetrathlonRing {
        var cumulative = 0.0

        // Start from innermost ring (10) and work outward
        for ring in TetrathlonRing.allCases.reversed() {
            cumulative += percentageByRing[ring] ?? 0
            if cumulative >= Config.coreClusterPercentage {
                return ring
            }
        }

        // If we get here, return outermost ring with shots
        return TetrathlonRing.allCases.first { (percentageByRing[$0] ?? 0) > 0 } ?? .miss
    }

    // MARK: - Step 3: Core Cluster Isolation

    private static func identifyCoreCluster(
        _ shots: [ClassifiedShot],
        coreClusterRing: TetrathlonRing
    ) -> (coreCluster: [ClassifiedShot], outliers: [ClassifiedShot]) {
        var coreCluster: [ClassifiedShot] = []
        var outliers: [ClassifiedShot] = []

        for shot in shots {
            // Shots in core cluster ring or inner are part of core cluster
            if shot.ring >= coreClusterRing {
                coreCluster.append(ClassifiedShot(
                    id: shot.id,
                    position: shot.position,
                    ring: shot.ring,
                    ellipticalDistance: shot.ellipticalDistance,
                    isOutlier: false
                ))
            } else {
                outliers.append(ClassifiedShot(
                    id: shot.id,
                    position: shot.position,
                    ring: shot.ring,
                    ellipticalDistance: shot.ellipticalDistance,
                    isOutlier: true
                ))
            }
        }

        return (coreCluster, outliers)
    }

    // MARK: - Step 4: Grouping Quality

    private static func determineGroupingQuality(_ distribution: RingDistribution) -> RingGroupingQuality {
        let ringSpread = distribution.ringSpread

        switch ringSpread {
        case 1:
            return .veryTight
        case 2:
            // Check if rings are adjacent
            let rings = Array(distribution.shotsByRing.keys).sorted(by: >)
            if rings.count == 2 {
                let diff = abs(rings[0].rawValue - rings[1].rawValue)
                if diff == 2 {  // Adjacent rings differ by 2 (10, 8, 6, 4, 2)
                    return .tight
                }
            }
            return .moderate
        case 3:
            return .moderate
        default:
            return .wide
        }
    }

    // MARK: - Step 5: Ring-Weighted MPI

    private static func calculateWeightedMPI(_ shots: [ClassifiedShot]) -> (x: Double, y: Double) {
        guard !shots.isEmpty else { return (0, 0) }

        var weightedSumX = 0.0
        var weightedSumY = 0.0
        var totalWeight = 0.0

        for shot in shots {
            let weight = shot.ring.weight
            weightedSumX += shot.position.x * weight
            weightedSumY += shot.position.y * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else { return (0, 0) }

        return (weightedSumX / totalWeight, weightedSumY / totalWeight)
    }

    // MARK: - Step 6: Confidence-Gated Directional Bias

    private static func calculateGatedDirectionalBias(
        coreClusterShots: [ClassifiedShot],
        weightedMpiX: Double,
        weightedMpiY: Double,
        mpiRing: TetrathlonRing
    ) -> GatedDirectionalBias {
        guard !coreClusterShots.isEmpty else {
            return GatedDirectionalBias(
                direction: .centered,
                strength: .none,
                confidence: 0,
                isSignificant: false,
                ringDistance: .ten
            )
        }

        // Calculate percentage of shots on each side
        var leftCount = 0
        var rightCount = 0
        var highCount = 0
        var lowCount = 0

        for shot in coreClusterShots {
            if shot.position.x < 0 { leftCount += 1 } else { rightCount += 1 }
            if shot.position.y < 0 { highCount += 1 } else { lowCount += 1 }
        }

        let total = Double(coreClusterShots.count)
        let leftPct = Double(leftCount) / total
        let rightPct = Double(rightCount) / total
        let highPct = Double(highCount) / total
        let lowPct = Double(lowCount) / total

        // Determine dominant direction and confidence
        let horizontalBias = rightPct > leftPct ? (rightPct, BiasDirection.right) : (leftPct, BiasDirection.left)
        let verticalBias = lowPct > highPct ? (lowPct, BiasDirection.low) : (highPct, BiasDirection.high)

        // Check if bias meets confidence threshold
        let horizontalSignificant = horizontalBias.0 >= Config.biasConfidenceThreshold
        let verticalSignificant = verticalBias.0 >= Config.biasConfidenceThreshold

        // Check if MPI offset is meaningful relative to ring
        let offset = sqrt(weightedMpiX * weightedMpiX + weightedMpiY * weightedMpiY)
        let offsetMeetsThreshold = offset > Config.biasMinimumRingFraction

        // Determine final direction
        let direction: BiasDirection
        let confidence: Double

        if horizontalSignificant && verticalSignificant {
            // Combined bias
            let hDir = horizontalBias.1
            let vDir = verticalBias.1
            direction = combineDirections(horizontal: hDir, vertical: vDir)
            confidence = (horizontalBias.0 + verticalBias.0) / 2
        } else if horizontalSignificant {
            direction = horizontalBias.1
            confidence = horizontalBias.0
        } else if verticalSignificant {
            direction = verticalBias.1
            confidence = verticalBias.0
        } else {
            direction = .centered
            confidence = 0
        }

        // Determine strength based on ring distance
        let strength: GatedDirectionalBias.BiasStrength
        switch mpiRing {
        case .ten:
            strength = direction == .centered ? .none : .verySlightly
        case .eight:
            strength = direction == .centered ? .none : .slightly
        default:
            strength = direction == .centered ? .none : .consistently
        }

        let isSignificant = direction != .centered && offsetMeetsThreshold

        return GatedDirectionalBias(
            direction: direction,
            strength: strength,
            confidence: confidence,
            isSignificant: isSignificant,
            ringDistance: mpiRing
        )
    }

    private static func combineDirections(horizontal: BiasDirection, vertical: BiasDirection) -> BiasDirection {
        switch (horizontal, vertical) {
        case (.left, .high): return .highLeft
        case (.left, .low): return .lowLeft
        case (.right, .high): return .highRight
        case (.right, .low): return .lowRight
        default: return horizontal
        }
    }

    // MARK: - Traditional Metrics

    private static func calculateClusterRadius(_ shots: [ClassifiedShot], mpiX: Double, mpiY: Double) -> Double {
        guard !shots.isEmpty else { return 0 }

        let distances = shots.map { shot -> Double in
            let dx = shot.position.x - mpiX
            let dy = shot.position.y - mpiY
            return sqrt(dx * dx + dy * dy)
        }

        return distances.reduce(0, +) / Double(distances.count)
    }

    // MARK: - Insight Generation

    /// Generate ring-aware insights
    static func generateInsights(from analysis: RingAwareClusterAnalysis) -> RingAwarePatternResult {
        let distribution = analysis.ringDistribution
        let grouping = analysis.groupingQuality
        let bias = analysis.directionalBias

        // 1. Overall Summary (Ring-based)
        let overallSummary = generateOverallSummary(distribution: distribution, grouping: grouping)

        // 2. Grouping Quality Description
        let groupingDescription = generateGroupingDescription(
            distribution: distribution,
            grouping: grouping,
            outlierCount: analysis.outlierCount
        )

        // 3. Position Tendency (confidence-gated)
        let positionTendency = generatePositionTendency(bias: bias)

        // 4. Notable Exceptions (outliers)
        let notableExceptions = generateNotableExceptions(
            outlierShots: analysis.outlierShots,
            totalCount: analysis.totalCount
        )

        // 5. Training Hints
        let trainingHints = generateTrainingHints(
            grouping: grouping,
            bias: bias,
            distribution: distribution
        )

        // 6. Calculate confidence
        let confidence = calculateInsightConfidence(analysis)

        return RingAwarePatternResult(
            ringDistribution: distribution,
            groupingQuality: grouping,
            directionalBias: bias,
            overallSummary: overallSummary,
            groupingDescription: groupingDescription,
            positionTendency: positionTendency,
            notableExceptions: notableExceptions,
            trainingHints: trainingHints,
            insightConfidence: confidence,
            coreClusterRing: distribution.coreClusterRing,
            weightedMpiX: analysis.weightedMpiX,
            weightedMpiY: analysis.weightedMpiY,
            coreClusterShotCount: analysis.coreClusterCount,
            outlierCount: analysis.outlierCount,
            totalShotCount: analysis.totalCount
        )
    }

    // MARK: - Insight Text Generation

    private static func generateOverallSummary(
        distribution: RingDistribution,
        grouping: RingGroupingQuality
    ) -> String {
        let coreRing = distribution.coreClusterRing
        let innerPct = Int((distribution.percentageByRing[.ten] ?? 0) * 100)

        switch coreRing {
        case .ten:
            if innerPct >= 80 {
                return "Excellent shooting! Nearly all shots are grouped in the 10 ring."
            } else {
                return "Most shots are grouped in the 10 ring, indicating good overall control."
            }
        case .eight:
            return "Shots are well-grouped in the central rings, showing solid consistency."
        case .six:
            return "Your shots are landing in the scoring area with room to tighten the group."
        case .four, .two:
            return "You're hitting the target consistently. Focus on stability to move shots inward."
        case .miss:
            return "Keep working on your fundamentals — every practice session builds skill."
        }
    }

    private static func generateGroupingDescription(
        distribution: RingDistribution,
        grouping: RingGroupingQuality,
        outlierCount: Int
    ) -> String {
        let coreRing = distribution.coreClusterRing

        switch grouping {
        case .veryTight:
            return "All your shots fit within the \(coreRing.displayName) — that's excellent control."
        case .tight:
            if coreRing >= .eight {
                return "Your shots span two adjacent rings with most in the \(coreRing.displayName)."
            } else {
                return "Good grouping with shots in two adjacent rings."
            }
        case .moderate:
            return "Your shots are moderately grouped across three rings."
        case .wide:
            if outlierCount > 0 {
                return "Your core group shows potential, with a few shots landing wider."
            } else {
                return "Shots are spread across several rings — building consistency will help."
            }
        }
    }

    private static func generatePositionTendency(bias: GatedDirectionalBias) -> String? {
        guard bias.isSignificant else {
            return "No strong directional tendency detected."
        }

        guard let biasDesc = bias.humanDescription else { return nil }

        switch bias.ringDistance {
        case .ten:
            return "Shots are \(biasDesc) of center, but well within the 10 ring."
        case .eight:
            return "There's a \(biasDesc) tendency, placing shots in the 8 ring area."
        default:
            return "Shots are landing \(biasDesc) of center."
        }
    }

    private static func generateNotableExceptions(
        outlierShots: [ClassifiedShot],
        totalCount: Int
    ) -> String? {
        guard !outlierShots.isEmpty else { return nil }

        let count = outlierShots.count
        let percentage = Int((Double(count) / Double(totalCount)) * 100)

        if count == 1 {
            let ring = outlierShots[0].ring
            return "One shot landed in the \(ring.displayName) — these happen and don't define your group."
        } else if percentage < 20 {
            return "\(count) shots landed outside your main group. Staying relaxed often helps."
        } else {
            return "About \(percentage)% of shots landed outside the core group. A consistent routine can help."
        }
    }

    private static func generateTrainingHints(
        grouping: RingGroupingQuality,
        bias: GatedDirectionalBias,
        distribution: RingDistribution
    ) -> [String] {
        var hints: [String] = []

        // Grouping-based hints
        switch grouping {
        case .veryTight, .tight:
            hints.append("Maintain your current routine — it's working well.")
            if bias.isSignificant && bias.strength != .verySlightly {
                hints.append("A natural point of aim check may help center the group.")
            }
        case .moderate:
            hints.append("A consistent shot routine can help tighten groups.")
            hints.append("Focus on one element at a time during practice.")
        case .wide:
            hints.append("Stability exercises may help with consistency.")
            hints.append("Consider slowing down between shots.")
        }

        // Bias-based hints (gentle, probabilistic)
        if bias.isSignificant {
            switch bias.direction {
            case .low, .lowLeft, .lowRight:
                hints.append("Low groups can sometimes relate to trigger follow-through. A steady trigger drill may help.")
            case .high, .highLeft, .highRight:
                hints.append("Breathing and settle time before the shot often helps with high groups.")
            case .left, .right:
                hints.append("Grip consistency can influence horizontal placement.")
            default:
                break
            }
        }

        return Array(hints.prefix(3))
    }

    private static func calculateInsightConfidence(_ analysis: RingAwareClusterAnalysis) -> InsightConfidence {
        let total = analysis.totalCount
        let coreCount = analysis.coreClusterCount
        let outlierCount = analysis.outlierCount

        // Shot count score
        let shotCountScore: Double
        if total >= Config.highConfidenceShotCount {
            shotCountScore = 1.0
        } else if total >= Config.mediumConfidenceShotCount {
            shotCountScore = 0.7
        } else {
            shotCountScore = Double(total) / Double(Config.mediumConfidenceShotCount)
        }

        // Ring concentration score (higher = more concentrated)
        let ringConcentrationScore = analysis.ringDistribution.ringSpread <= 2 ? 1.0 :
            analysis.ringDistribution.ringSpread <= 3 ? 0.7 : 0.4

        // Outlier ratio score (lower outliers = higher score)
        let outlierRatio = Double(outlierCount) / Double(total)
        let outlierRatioScore = max(0, 1.0 - (outlierRatio * 3))

        // Overall score (weighted average)
        let overallScore = (shotCountScore * 0.4) + (ringConcentrationScore * 0.3) + (outlierRatioScore * 0.3)

        let level: AnalysisConfidence
        if overallScore >= 0.7 {
            level = .high
        } else if overallScore >= 0.4 {
            level = .medium
        } else {
            level = .low
        }

        return InsightConfidence(
            level: level,
            shotCountScore: shotCountScore,
            ringConcentrationScore: ringConcentrationScore,
            outlierRatioScore: outlierRatioScore,
            overallScore: overallScore
        )
    }
}

