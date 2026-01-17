//
//  ShotPatternAnalyzer.swift
//  TrackRide
//
//  Practice-focused shot pattern analysis for air pistol / tetrathlon free practice.
//  Uses clustering and outlier detection so a single stray shot doesn't misrepresent performance.
//  Provides observations and practice focus suggestions - NOT scoring or technique diagnosis.
//

import Foundation
import SwiftUI

// MARK: - Session Type

/// Session type for categorizing shooting patterns
enum ShootingSessionType: String, Codable, CaseIterable {
    case freePractice
    case tetrathlonPractice
    case competition

    var displayName: String {
        switch self {
        case .freePractice: return "Free Practice"
        case .tetrathlonPractice: return "Tetrathlon"
        case .competition: return "Competition"
        }
    }

    var icon: String {
        switch self {
        case .freePractice: return "target"
        case .tetrathlonPractice: return "trophy.fill"
        case .competition: return "medal.fill"
        }
    }

    var color: String {
        switch self {
        case .freePractice: return "blue"
        case .tetrathlonPractice: return "orange"
        case .competition: return "purple"
        }
    }
}

// MARK: - Analysis Output Models

/// Confidence level for analysis results
enum AnalysisConfidence: String, Codable {
    case low
    case medium
    case high
}

/// Pattern classification for shot groups
enum GroupTightness: String, Codable {
    case tight      // groupRadius ≤ 0.12
    case moderate   // 0.12 < groupRadius ≤ 0.22
    case wide       // groupRadius > 0.22

    var description: String {
        switch self {
        case .tight: return "tight"
        case .moderate: return "moderate"
        case .wide: return "spread out"
        }
    }
}

/// Bias severity for cluster offset from center
enum BiasSeverity: String, Codable {
    case centered       // offset ≤ 0.05
    case slight         // 0.05 < offset ≤ 0.15
    case significant    // offset > 0.15

    var description: String {
        switch self {
        case .centered: return "centered"
        case .slight: return "slightly off"
        case .significant: return "noticeably off"
        }
    }
}

/// Bias direction for shot groups
enum BiasDirection: String, Codable {
    case centered
    case high
    case low
    case left
    case right
    case highLeft
    case highRight
    case lowLeft
    case lowRight

    var description: String {
        switch self {
        case .centered: return "centered"
        case .high: return "high"
        case .low: return "low"
        case .left: return "left"
        case .right: return "right"
        case .highLeft: return "high and left"
        case .highRight: return "high and right"
        case .lowLeft: return "low and left"
        case .lowRight: return "low and right"
        }
    }

    var shortDescription: String {
        switch self {
        case .centered: return "center"
        case .high: return "above"
        case .low: return "below"
        case .left: return "left of"
        case .right: return "right of"
        case .highLeft: return "high-left of"
        case .highRight: return "high-right of"
        case .lowLeft: return "low-left of"
        case .lowRight: return "low-right of"
        }
    }
}

/// Complete pattern label combining tightness and bias
struct PatternLabel: Codable, Equatable {
    let tightness: GroupTightness
    let bias: BiasDirection
    let biasSeverity: BiasSeverity

    var description: String {
        if bias == .centered {
            return "\(tightness.description.capitalized) & Centered"
        } else {
            return "\(tightness.description.capitalized) & \(biasSeverity.description.capitalized) \(bias.description.capitalized)"
        }
    }
}

/// Cluster analysis result
struct ClusterAnalysis {
    let clusterShots: [CGPoint]       // Shots in main cluster
    let outlierShots: [CGPoint]       // Shots outside cluster
    let clusterMpiX: Double           // MPI of cluster only
    let clusterMpiY: Double
    let clusterRadius: Double         // Group radius of cluster
    let clusterOffset: Double         // Distance from target center to cluster MPI
    let outlierCount: Int
    let totalCount: Int

    var clusterCount: Int { clusterShots.count }
}

/// Analysis result for a single target or aggregate history
struct PatternAnalysisResult: Codable {
    let patternLabel: PatternLabel
    let observationText: String
    let practiceFocusText: String
    let suggestedDrills: [String]
    let confidence: AnalysisConfidence

    // Cluster metrics
    let clusterMpiDistance: Double    // Distance from center to cluster MPI
    let clusterRadius: Double         // Group radius of main cluster
    let clusterShotCount: Int         // Shots in cluster
    let outlierCount: Int             // Shots outside cluster
    let totalShotCount: Int           // Total shots
}

/// Stored target for history
struct StoredTargetPattern: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let normalizedShots: [CGPoint]    // All shots normalized
    let clusterMpiX: Double           // MPI of main cluster
    let clusterMpiY: Double
    let clusterRadius: Double
    let clusterShotCount: Int
    let outlierCount: Int
    let sessionType: ShootingSessionType  // Type of practice session

    var shotCount: Int { normalizedShots.count }

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        normalizedShots: [CGPoint],
        clusterMpiX: Double,
        clusterMpiY: Double,
        clusterRadius: Double,
        clusterShotCount: Int,
        outlierCount: Int,
        sessionType: ShootingSessionType = .freePractice
    ) {
        self.id = id
        self.timestamp = timestamp
        self.normalizedShots = normalizedShots
        self.clusterMpiX = clusterMpiX
        self.clusterMpiY = clusterMpiY
        self.clusterRadius = clusterRadius
        self.clusterShotCount = clusterShotCount
        self.outlierCount = outlierCount
        self.sessionType = sessionType
    }

    // MARK: - Codable with backward compatibility

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, normalizedShots, clusterMpiX, clusterMpiY
        case clusterRadius, clusterShotCount, outlierCount, sessionType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        normalizedShots = try container.decode([CGPoint].self, forKey: .normalizedShots)
        clusterMpiX = try container.decode(Double.self, forKey: .clusterMpiX)
        clusterMpiY = try container.decode(Double.self, forKey: .clusterMpiY)
        clusterRadius = try container.decode(Double.self, forKey: .clusterRadius)
        clusterShotCount = try container.decode(Int.self, forKey: .clusterShotCount)
        outlierCount = try container.decode(Int.self, forKey: .outlierCount)
        // Backward compatibility: default to freePractice if not present
        sessionType = try container.decodeIfPresent(ShootingSessionType.self, forKey: .sessionType) ?? .freePractice
    }
}

/// Visual data for rendering shot patterns
struct VisualPatternData {
    let currentTargetShots: [NormalizedShotPoint]
    let historicalShots: [NormalizedShotPoint]
    let mpiCurrent: CGPoint?
    let mpiAggregate: CGPoint?
    let groupRadiusCurrent: Double?
    let groupRadiusAggregate: Double?

    struct NormalizedShotPoint: Identifiable, Codable {
        let id: UUID
        let position: CGPoint
        let isCurrentTarget: Bool
        let isOutlier: Bool
        let timestamp: Date?

        init(id: UUID = UUID(), position: CGPoint, isCurrentTarget: Bool, isOutlier: Bool = false, timestamp: Date? = nil) {
            self.id = id
            self.position = position
            self.isCurrentTarget = isCurrentTarget
            self.isOutlier = isOutlier
            self.timestamp = timestamp
        }
    }
}

/// Complete analysis output
struct ShotPatternAnalysis {
    let currentTarget: PatternAnalysisResult?
    let aggregateHistory: PatternAnalysisResult?
    let visualData: VisualPatternData?
    let suppressionReason: String?

    var isValid: Bool { currentTarget != nil }
}

// MARK: - Shot Pattern Analyzer

final class ShotPatternAnalyzer {

    // MARK: - Thresholds (Normalized to target radius)

    /// Analysis thresholds - shared across shooting analysis services
    struct Thresholds {
        // Minimum requirements
        static let minimumShots = 5
        static let minimumSpread = 0.03

        // Clustering
        static let outlierTrimPercentage = 0.15   // Exclude top 15% most distant for initial cluster
        static let outlierStdDevThreshold = 2.0  // Shots > 2 std devs from cluster = outlier

        // Group tightness thresholds
        static let tightGroup = 0.12              // cluster radius ≤ this = tight
        static let moderateGroup = 0.22           // cluster radius ≤ this = moderate

        // Bias offset thresholds (from target center)
        static let centeredOffset = 0.05          // offset ≤ this = centered
        static let slightOffset = 0.15            // offset ≤ this = slight bias

        // Direction detection dead zone
        static let directionDeadZone = 0.03
    }

    // MARK: - Main Analysis Entry Point

    /// Analyze current target shots with optional historical context
    static func analyze(
        shots: [CGPoint],
        centerPoint: CGPoint,
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        history: [StoredTargetPattern] = []
    ) -> ShotPatternAnalysis {

        // Guardrail: Center point required
        guard centerPoint.x > 0 && centerPoint.y > 0 else {
            return ShotPatternAnalysis(
                currentTarget: nil,
                aggregateHistory: nil,
                visualData: nil,
                suppressionReason: "Mark the target center to unlock practice insights."
            )
        }

        // Guardrail: Minimum shots required
        guard shots.count >= Thresholds.minimumShots else {
            let remaining = Thresholds.minimumShots - shots.count
            return ShotPatternAnalysis(
                currentTarget: nil,
                aggregateHistory: nil,
                visualData: nil,
                suppressionReason: "Mark \(remaining) more shot\(remaining == 1 ? "" : "s") to unlock practice insights."
            )
        }

        // Step 1: Normalize shots
        let maxTargetRadius = min(imageWidth, imageHeight) / 2
        let normalizedShots = normalizeShots(shots, center: centerPoint, maxRadius: maxTargetRadius)

        // Step 2: Clustering and outlier detection
        let clusterAnalysis = performClustering(normalizedShots)

        // Guardrail: Minimum spread (using cluster radius)
        guard clusterAnalysis.clusterRadius >= Thresholds.minimumSpread else {
            return ShotPatternAnalysis(
                currentTarget: nil,
                aggregateHistory: nil,
                visualData: nil,
                suppressionReason: "Great consistency! Shoot a few more varied shots to get practice insights."
            )
        }

        // Step 3-6: Generate current target analysis
        let currentAnalysis = generateAnalysis(
            cluster: clusterAnalysis,
            isAggregate: false
        )

        // Step 7: Aggregate history analysis (if available)
        var aggregateAnalysis: PatternAnalysisResult? = nil
        var aggregateCluster: ClusterAnalysis? = nil

        if !history.isEmpty {
            // Combine all historical shots with current for aggregate clustering
            var allNormalizedShots: [CGPoint] = normalizedShots
            for pattern in history {
                allNormalizedShots.append(contentsOf: pattern.normalizedShots)
            }

            if allNormalizedShots.count >= Thresholds.minimumShots {
                aggregateCluster = performClustering(allNormalizedShots)
                aggregateAnalysis = generateAnalysis(
                    cluster: aggregateCluster!,
                    isAggregate: true
                )
            }
        }

        // Generate visual data with outlier marking
        let outlierSet = Set(clusterAnalysis.outlierShots.map { "\($0.x),\($0.y)" })
        let currentShotPoints = normalizedShots.map { point in
            let isOutlier = outlierSet.contains("\(point.x),\(point.y)")
            return VisualPatternData.NormalizedShotPoint(
                position: point,
                isCurrentTarget: true,
                isOutlier: isOutlier,
                timestamp: Date()
            )
        }

        var historicalShotPoints: [VisualPatternData.NormalizedShotPoint] = []
        for pattern in history {
            for point in pattern.normalizedShots {
                historicalShotPoints.append(VisualPatternData.NormalizedShotPoint(
                    position: point,
                    isCurrentTarget: false,
                    isOutlier: false,  // Historical outliers not tracked individually
                    timestamp: pattern.timestamp
                ))
            }
        }

        let visualData = VisualPatternData(
            currentTargetShots: currentShotPoints,
            historicalShots: historicalShotPoints,
            mpiCurrent: CGPoint(x: clusterAnalysis.clusterMpiX, y: clusterAnalysis.clusterMpiY),
            mpiAggregate: aggregateCluster.map { CGPoint(x: $0.clusterMpiX, y: $0.clusterMpiY) },
            groupRadiusCurrent: clusterAnalysis.clusterRadius,
            groupRadiusAggregate: aggregateCluster?.clusterRadius
        )

        return ShotPatternAnalysis(
            currentTarget: currentAnalysis,
            aggregateHistory: aggregateAnalysis,
            visualData: visualData,
            suppressionReason: nil
        )
    }

    /// Create a stored pattern for history
    static func createStoredPattern(
        shots: [CGPoint],
        centerPoint: CGPoint,
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        sessionType: ShootingSessionType = .freePractice
    ) -> StoredTargetPattern? {
        guard shots.count >= Thresholds.minimumShots else { return nil }

        let maxTargetRadius = min(imageWidth, imageHeight) / 2
        let normalizedShots = normalizeShots(shots, center: centerPoint, maxRadius: maxTargetRadius)
        let cluster = performClustering(normalizedShots)

        return StoredTargetPattern(
            normalizedShots: normalizedShots,
            clusterMpiX: cluster.clusterMpiX,
            clusterMpiY: cluster.clusterMpiY,
            clusterRadius: cluster.clusterRadius,
            clusterShotCount: cluster.clusterCount,
            outlierCount: cluster.outlierCount,
            sessionType: sessionType
        )
    }

    // MARK: - Step 1: Normalization

    private static func normalizeShots(_ shots: [CGPoint], center: CGPoint, maxRadius: CGFloat) -> [CGPoint] {
        return shots.map { shot in
            let dx = (shot.x - center.x) / maxRadius
            let dy = (shot.y - center.y) / maxRadius
            return CGPoint(x: dx, y: dy)
        }
    }

    // MARK: - Step 2: Clustering and Outlier Detection

    private static func performClustering(_ normalizedShots: [CGPoint]) -> ClusterAnalysis {
        guard !normalizedShots.isEmpty else {
            return ClusterAnalysis(
                clusterShots: [],
                outlierShots: [],
                clusterMpiX: 0,
                clusterMpiY: 0,
                clusterRadius: 0,
                clusterOffset: 0,
                outlierCount: 0,
                totalCount: 0
            )
        }

        // Step 2a: Calculate initial MPI using all shots
        let initialMpiX = normalizedShots.reduce(0.0) { $0 + $1.x } / Double(normalizedShots.count)
        let initialMpiY = normalizedShots.reduce(0.0) { $0 + $1.y } / Double(normalizedShots.count)

        // Step 2b: Calculate distances from initial MPI
        var shotsWithDistances: [(shot: CGPoint, distance: Double)] = normalizedShots.map { shot in
            let dx = shot.x - initialMpiX
            let dy = shot.y - initialMpiY
            let distance = sqrt(dx * dx + dy * dy)
            return (shot, distance)
        }

        // Sort by distance
        shotsWithDistances.sort { $0.distance < $1.distance }

        // Step 2c: Trim top 15% for initial cluster identification
        let trimCount = max(1, Int(Double(shotsWithDistances.count) * Thresholds.outlierTrimPercentage))
        let trimmedShots = Array(shotsWithDistances.dropLast(trimCount))

        // If we trimmed everything (very few shots), use all shots
        let coreShots = trimmedShots.isEmpty ? shotsWithDistances : trimmedShots

        // Step 2d: Calculate cluster MPI from core shots
        let clusterMpiX = coreShots.reduce(0.0) { $0 + $1.shot.x } / Double(coreShots.count)
        let clusterMpiY = coreShots.reduce(0.0) { $0 + $1.shot.y } / Double(coreShots.count)

        // Step 2e: Calculate distances from cluster MPI
        let clusterDistances = normalizedShots.map { shot -> Double in
            let dx = shot.x - clusterMpiX
            let dy = shot.y - clusterMpiY
            return sqrt(dx * dx + dy * dy)
        }

        // Step 2f: Calculate standard deviation
        let meanDistance = clusterDistances.reduce(0, +) / Double(clusterDistances.count)
        let variance = clusterDistances.reduce(0.0) { $0 + pow($1 - meanDistance, 2) } / Double(clusterDistances.count)
        let stdDev = sqrt(variance)

        // Step 2g: Identify outliers (> 2 std devs from cluster MPI)
        let outlierThreshold = meanDistance + (Thresholds.outlierStdDevThreshold * stdDev)

        var clusterShots: [CGPoint] = []
        var outlierShots: [CGPoint] = []

        for (index, shot) in normalizedShots.enumerated() {
            if clusterDistances[index] > outlierThreshold {
                outlierShots.append(shot)
            } else {
                clusterShots.append(shot)
            }
        }

        // Step 2h: Recalculate final cluster MPI using only cluster shots
        let finalMpiX: Double
        let finalMpiY: Double
        let clusterRadius: Double

        if !clusterShots.isEmpty {
            finalMpiX = clusterShots.reduce(0.0) { $0 + $1.x } / Double(clusterShots.count)
            finalMpiY = clusterShots.reduce(0.0) { $0 + $1.y } / Double(clusterShots.count)

            // Calculate cluster radius (mean distance from cluster MPI)
            let finalDistances = clusterShots.map { shot -> Double in
                let dx = shot.x - finalMpiX
                let dy = shot.y - finalMpiY
                return sqrt(dx * dx + dy * dy)
            }
            clusterRadius = finalDistances.reduce(0, +) / Double(finalDistances.count)
        } else {
            // Fallback if no cluster (shouldn't happen)
            finalMpiX = clusterMpiX
            finalMpiY = clusterMpiY
            clusterRadius = meanDistance
        }

        // Calculate cluster offset from target center (which is 0,0 in normalized space)
        let clusterOffset = sqrt(finalMpiX * finalMpiX + finalMpiY * finalMpiY)

        return ClusterAnalysis(
            clusterShots: clusterShots,
            outlierShots: outlierShots,
            clusterMpiX: finalMpiX,
            clusterMpiY: finalMpiY,
            clusterRadius: clusterRadius,
            clusterOffset: clusterOffset,
            outlierCount: outlierShots.count,
            totalCount: normalizedShots.count
        )
    }

    // MARK: - Step 3: Pattern Classification

    private static func classifyTightness(_ clusterRadius: Double) -> GroupTightness {
        if clusterRadius <= Thresholds.tightGroup {
            return .tight
        } else if clusterRadius <= Thresholds.moderateGroup {
            return .moderate
        } else {
            return .wide
        }
    }

    private static func classifyBiasSeverity(_ offset: Double) -> BiasSeverity {
        if offset <= Thresholds.centeredOffset {
            return .centered
        } else if offset <= Thresholds.slightOffset {
            return .slight
        } else {
            return .significant
        }
    }

    private static func determineBiasDirection(mpiX: Double, mpiY: Double, offset: Double) -> BiasDirection {
        // Dead zone check
        if offset < Thresholds.directionDeadZone {
            return .centered
        }

        let absX = abs(mpiX)
        let absY = abs(mpiY)

        // Determine if bias is significant in each axis
        let hasHorizontalBias = absX > Thresholds.directionDeadZone
        let hasVerticalBias = absY > Thresholds.directionDeadZone

        let isLeft = mpiX < 0
        let isHigh = mpiY < 0  // Y increases downward in image coordinates

        if hasHorizontalBias && hasVerticalBias {
            // Combined bias
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

    // MARK: - Step 4-6: Generate Analysis with Insights

    private static func generateAnalysis(
        cluster: ClusterAnalysis,
        isAggregate: Bool
    ) -> PatternAnalysisResult {

        // Try ring-aware analysis first for human-aligned insights
        let allShots = cluster.clusterShots + cluster.outlierShots
        if let ringAnalysis = RingAwareAnalyzer.analyze(normalizedShots: allShots) {
            let ringInsights = RingAwareAnalyzer.generateInsights(from: ringAnalysis)

            // Map ring grouping to traditional tightness for compatibility
            let tightness: GroupTightness
            switch ringInsights.groupingQuality {
            case .veryTight, .tight:
                tightness = .tight
            case .moderate:
                tightness = .moderate
            case .wide:
                tightness = .wide
            }

            // Use ring-aware bias
            let biasDirection = ringAnalysis.directionalBias.direction
            let biasSeverity: BiasSeverity
            switch ringAnalysis.directionalBias.strength {
            case .none, .verySlightly:
                biasSeverity = .centered
            case .slightly:
                biasSeverity = .slight
            case .consistently:
                biasSeverity = .significant
            }

            let pattern = PatternLabel(
                tightness: tightness,
                bias: biasDirection,
                biasSeverity: biasSeverity
            )

            // Build observation from ring-aware insights
            var observationParts: [String] = [ringInsights.overallSummary]
            if let position = ringInsights.positionTendency {
                observationParts.append(position)
            }
            if let exceptions = ringInsights.notableExceptions {
                observationParts.append(exceptions)
            }
            let observation = observationParts.joined(separator: " ")

            // Use ring-aware training hints
            let drills = ringInsights.trainingHints

            return PatternAnalysisResult(
                patternLabel: pattern,
                observationText: observation,
                practiceFocusText: ringInsights.groupingDescription,
                suggestedDrills: drills,
                confidence: ringInsights.insightConfidence.level,
                clusterMpiDistance: cluster.clusterOffset,
                clusterRadius: cluster.clusterRadius,
                clusterShotCount: ringInsights.coreClusterShotCount,
                outlierCount: ringInsights.outlierCount,
                totalShotCount: ringInsights.totalShotCount
            )
        }

        // Fallback to traditional analysis if ring-aware fails
        let tightness = classifyTightness(cluster.clusterRadius)
        let biasSeverity = classifyBiasSeverity(cluster.clusterOffset)
        let biasDirection = determineBiasDirection(
            mpiX: cluster.clusterMpiX,
            mpiY: cluster.clusterMpiY,
            offset: cluster.clusterOffset
        )

        let pattern = PatternLabel(
            tightness: tightness,
            bias: biasDirection,
            biasSeverity: biasSeverity
        )

        // Determine confidence based on cluster size
        let confidence: AnalysisConfidence
        if cluster.clusterCount >= 15 {
            confidence = .high
        } else if cluster.clusterCount >= 8 {
            confidence = .medium
        } else {
            confidence = .low
        }

        // Generate outlier-aware observation
        let observation = generateObservation(
            pattern: pattern,
            cluster: cluster,
            isAggregate: isAggregate
        )

        // Generate practice focus
        let practiceFocus = generatePracticeFocus(pattern: pattern, outlierCount: cluster.outlierCount)

        // Map to drills
        let drills = mapToDrills(pattern: pattern)

        return PatternAnalysisResult(
            patternLabel: pattern,
            observationText: observation,
            practiceFocusText: practiceFocus,
            suggestedDrills: drills,
            confidence: confidence,
            clusterMpiDistance: cluster.clusterOffset,
            clusterRadius: cluster.clusterRadius,
            clusterShotCount: cluster.clusterCount,
            outlierCount: cluster.outlierCount,
            totalShotCount: cluster.totalCount
        )
    }

    // MARK: - Step 5: Observation Generation (Outlier-Aware)

    private static func generateObservation(pattern: PatternLabel, cluster: ClusterAnalysis, isAggregate: Bool) -> String {
        var parts: [String] = []

        // Part 1: Describe the main cluster
        let clusterDescription = describeCluster(pattern: pattern, cluster: cluster, isAggregate: isAggregate)
        parts.append(clusterDescription)

        // Part 2: Describe outliers if present
        if cluster.outlierCount > 0 {
            let outlierDescription = describeOutliers(count: cluster.outlierCount, total: cluster.totalCount)
            parts.append(outlierDescription)
        }

        return parts.joined(separator: " ")
    }

    private static func describeCluster(pattern: PatternLabel, cluster: ClusterAnalysis, isAggregate: Bool) -> String {
        let context = isAggregate ? "Across your practice sessions" : "Great job"
        let shotWord = cluster.clusterCount == 1 ? "shot is" : "shots are"

        switch (pattern.tightness, pattern.biasSeverity) {
        case (.tight, .centered):
            return "\(context)! \(cluster.clusterCount) of \(cluster.totalCount) \(shotWord) nicely grouped near the bullseye."

        case (.tight, .slight):
            return "\(context)! \(cluster.clusterCount) of \(cluster.totalCount) \(shotWord) tightly grouped, just slightly \(pattern.bias.shortDescription) center."

        case (.tight, .significant):
            return "\(context)! Your shots form a tight cluster — they're consistently landing \(pattern.bias.shortDescription) center."

        case (.moderate, .centered):
            return "\(context)! \(cluster.clusterCount) of \(cluster.totalCount) \(shotWord) grouped around the center area."

        case (.moderate, .slight):
            return "\(cluster.clusterCount) of \(cluster.totalCount) \(shotWord) showing a moderate group, slightly \(pattern.bias.shortDescription) center."

        case (.moderate, .significant):
            return "\(cluster.clusterCount) of \(cluster.totalCount) \(shotWord) moderately grouped, landing \(pattern.bias.shortDescription) center."

        case (.wide, .centered):
            return "\(cluster.clusterCount) of \(cluster.totalCount) \(shotWord) spread out but balanced around the center."

        case (.wide, _):
            return "\(cluster.clusterCount) of \(cluster.totalCount) \(shotWord) spread across the target with a tendency toward the \(pattern.bias.description) side."
        }
    }

    private static func describeOutliers(count: Int, total: Int) -> String {
        if count == 1 {
            return "One shot landed outside the main group — that happens! Focus on your trigger control to keep it smooth."
        } else if count == 2 {
            return "A couple of shots strayed from the group — staying relaxed through the shot can help."
        } else {
            return "\(count) shots landed outside the main cluster. Taking your time between shots often helps with consistency."
        }
    }

    // MARK: - Practice Focus Generation

    private static func generatePracticeFocus(pattern: PatternLabel, outlierCount: Int) -> String {
        var focus: String

        switch (pattern.tightness, pattern.biasSeverity) {
        case (.tight, .centered):
            focus = "You're showing excellent consistency! Many athletes at this level focus on maintaining their routine and staying relaxed."

        case (.tight, .slight):
            focus = "Your grouping is great! With a tight cluster like this, small adjustments to your natural point of aim often help center the group."

        case (.tight, .significant):
            focus = "Excellent grouping consistency! Your shots are landing together, which is the first goal. Athletes often explore their natural point of aim to shift the group."

        case (.moderate, .centered):
            focus = "You're building good habits with your shots balanced around center. Developing a consistent shot routine often helps tighten groups."

        case (.moderate, .slight), (.moderate, .significant):
            focus = "Building consistency is the focus at this stage. Many athletes benefit from slowing down and focusing on one element at a time."

        case (.wide, .centered):
            focus = "Your shots are balanced around center, which is a good foundation. Working on stability and developing a repeatable routine often helps tighten groups."

        case (.wide, _):
            focus = "Developing a steady, repeatable routine is often helpful. Many athletes focus on stability and taking their time between shots."
        }

        // Add outlier-specific advice if needed
        if outlierCount >= 2 {
            focus += " When occasional shots stray, a focus on smooth trigger control often helps."
        }

        return focus
    }

    // MARK: - Drill Mapping

    private static func mapToDrills(pattern: PatternLabel) -> [String] {
        switch (pattern.tightness, pattern.biasSeverity) {
        case (.tight, .centered):
            return ["Maintain your current routine", "Try holding longer before each shot to build confidence"]

        case (.tight, .slight):
            return ["Natural point of aim check", "Dry fire with focus on hold", "Blank target slow fire"]

        case (.tight, .significant):
            return ["Natural point of aim adjustment drill", "Position check exercise", "Aiming area hold drill"]

        case (.moderate, .centered):
            return ["Develop a shot routine checklist", "Slow fire practice", "Breathing and settle drill"]

        case (.moderate, _):
            return ["One-element focus drill", "Slow fire on blank target", "Position and hold drill"]

        case (.wide, .centered):
            return ["Stability hold drill", "Develop consistent pre-shot routine", "Balance and stance check"]

        case (.wide, _):
            return ["Position fundamentals review", "Stability exercises", "Slow deliberate practice"]
        }
    }
}

// MARK: - History Storage Manager

/// Date filter options for history queries
enum DateFilterOption: String, CaseIterable {
    case lastSession = "Last Session"
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case allTime = "All Time"

    /// Short display name for compact UI
    var shortName: String {
        switch self {
        case .lastSession: return "Last"
        case .today: return "Today"
        case .thisWeek: return "Week"
        case .thisMonth: return "Month"
        case .allTime: return "All"
        }
    }

    /// Returns the date range for this filter option
    func dateRange(from patterns: [StoredTargetPattern]) -> ClosedRange<Date>? {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .lastSession:
            // Get the most recent session's date
            guard let lastPattern = patterns.max(by: { $0.timestamp < $1.timestamp }) else {
                return nil
            }
            let startOfDay = calendar.startOfDay(for: lastPattern.timestamp)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
            return startOfDay...endOfDay

        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            return startOfDay...now

        case .thisWeek:
            guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
                return nil
            }
            return weekStart...now

        case .thisMonth:
            guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
                return nil
            }
            return monthStart...now

        case .allTime:
            return nil  // No date restriction
        }
    }
}

@Observable
final class ShotPatternHistoryManager {
    private let storageKey = "shotPatternHistory"
    private(set) var history: [StoredTargetPattern] = []

    init() {
        loadHistory()
    }

    func addPattern(_ pattern: StoredTargetPattern) {
        history.append(pattern)
        saveHistory()
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    /// Get recent history with optional limit
    func getRecentHistory(limit: Int = 50) -> [StoredTargetPattern] {
        return Array(history.suffix(limit))
    }

    /// Get filtered history by date range and/or session types
    func getHistory(
        dateRange: ClosedRange<Date>? = nil,
        sessionTypes: Set<ShootingSessionType>? = nil,
        limit: Int = 200
    ) -> [StoredTargetPattern] {
        var filtered = history

        // Apply date filter
        if let range = dateRange {
            filtered = filtered.filter { range.contains($0.timestamp) }
        }

        // Apply session type filter
        if let types = sessionTypes, !types.isEmpty {
            filtered = filtered.filter { types.contains($0.sessionType) }
        }

        // Sort by timestamp (most recent first) and apply limit
        filtered.sort { $0.timestamp > $1.timestamp }
        return Array(filtered.prefix(limit))
    }

    /// Get history using a date filter option
    func getHistory(
        dateFilter: DateFilterOption,
        sessionTypes: Set<ShootingSessionType>? = nil,
        limit: Int = 200
    ) -> [StoredTargetPattern] {
        let dateRange = dateFilter.dateRange(from: history)
        return getHistory(dateRange: dateRange, sessionTypes: sessionTypes, limit: limit)
    }

    /// Get unique session dates for timeline display
    func getSessionDates() -> [Date] {
        let calendar = Calendar.current
        let uniqueDays = Set(history.map { calendar.startOfDay(for: $0.timestamp) })
        return uniqueDays.sorted(by: >)
    }

    /// Get patterns grouped by day
    func getPatternsByDay() -> [Date: [StoredTargetPattern]] {
        let calendar = Calendar.current
        var grouped: [Date: [StoredTargetPattern]] = [:]

        for pattern in history {
            let day = calendar.startOfDay(for: pattern.timestamp)
            grouped[day, default: []].append(pattern)
        }

        return grouped
    }

    /// Get session type distribution
    func getSessionTypeDistribution() -> [ShootingSessionType: Int] {
        var distribution: [ShootingSessionType: Int] = [:]
        for pattern in history {
            distribution[pattern.sessionType, default: 0] += 1
        }
        return distribution
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([StoredTargetPattern].self, from: data) else {
            return
        }
        history = decoded
    }

    private func saveHistory() {
        guard let encoded = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }
}
