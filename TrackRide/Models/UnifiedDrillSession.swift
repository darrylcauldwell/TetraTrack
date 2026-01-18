//
//  UnifiedDrillSession.swift
//  TrackRide
//
//  Unified drill session model for all disciplines
//

import Foundation
import SwiftData

/// Records a completed training drill session across all disciplines
@Model
final class UnifiedDrillSession {
    var id: UUID = UUID()
    var startDate: Date = Date()
    var drillTypeRaw: String = UnifiedDrillType.coreStability.rawValue
    var duration: TimeInterval = 0
    var score: Double = 0  // 0-100 overall score
    var notes: String = ""

    // MARK: - Universal Subscores (0-100)

    /// Stability subscore - inverse of motion variance
    var stabilityScore: Double = 0

    /// Symmetry subscore - left/right balance
    var symmetryScore: Double = 0

    /// Endurance subscore - score degradation over time
    var enduranceScore: Double = 0

    /// Coordination subscore - multi-axis timing correlation
    var coordinationScore: Double = 0

    /// Breathing subscore - breath control quality
    var breathingScore: Double = 0

    /// Rhythm subscore - timing consistency
    var rhythmScore: Double = 0

    /// Reaction subscore - response time quality
    var reactionScore: Double = 0

    // MARK: - Raw Metrics

    /// Average root mean square motion during drill
    var averageRMS: Double = 0

    /// Average wobble during hold (radians)
    var averageWobble: Double = 0

    /// Peak deviation from stable position (radians)
    var peakDeviation: Double = 0

    /// Best reaction time (seconds)
    var bestReactionTime: Double = 0

    /// Average reaction time (seconds)
    var averageReactionTime: Double = 0

    /// Average split time between targets (seconds)
    var averageSplitTime: Double = 0

    /// Rhythm accuracy for rhythm drills (0-100)
    var rhythmAccuracy: Double = 0

    /// Cadence (steps/beats per minute)
    var cadence: Int = 0

    /// Heart rate at start of drill (for stress inoculation)
    var startHeartRate: Double = 0

    /// Heart rate at end of drill
    var endHeartRate: Double = 0

    // MARK: - Computed Properties

    /// Computed drill type from raw string
    var drillType: UnifiedDrillType {
        get { UnifiedDrillType(rawValue: drillTypeRaw) ?? .coreStability }
        set { drillTypeRaw = newValue.rawValue }
    }

    /// Primary movement category for this drill
    var primaryCategory: MovementCategory {
        drillType.primaryCategory
    }

    /// All disciplines that benefit from this drill
    var benefitsDisciplines: Set<Discipline> {
        drillType.benefitsDisciplines
    }

    /// Primary discipline for this drill
    var primaryDiscipline: Discipline {
        drillType.primaryDiscipline
    }

    // MARK: - Initializers

    init() {}

    convenience init(drillType: UnifiedDrillType, duration: TimeInterval, score: Double) {
        self.init()
        self.drillTypeRaw = drillType.rawValue
        self.duration = duration
        self.score = score
        self.startDate = Date()
    }

    /// Full initializer with all subscores
    convenience init(
        drillType: UnifiedDrillType,
        duration: TimeInterval,
        score: Double,
        stabilityScore: Double = 0,
        symmetryScore: Double = 0,
        enduranceScore: Double = 0,
        coordinationScore: Double = 0,
        breathingScore: Double = 0,
        rhythmScore: Double = 0,
        reactionScore: Double = 0,
        averageRMS: Double = 0,
        averageWobble: Double = 0,
        peakDeviation: Double = 0,
        bestReactionTime: Double = 0,
        averageReactionTime: Double = 0,
        averageSplitTime: Double = 0,
        rhythmAccuracy: Double = 0,
        cadence: Int = 0,
        startHeartRate: Double = 0,
        endHeartRate: Double = 0
    ) {
        self.init()
        self.drillTypeRaw = drillType.rawValue
        self.duration = duration
        self.score = score
        self.stabilityScore = stabilityScore
        self.symmetryScore = symmetryScore
        self.enduranceScore = enduranceScore
        self.coordinationScore = coordinationScore
        self.breathingScore = breathingScore
        self.rhythmScore = rhythmScore
        self.reactionScore = reactionScore
        self.averageRMS = averageRMS
        self.averageWobble = averageWobble
        self.peakDeviation = peakDeviation
        self.bestReactionTime = bestReactionTime
        self.averageReactionTime = averageReactionTime
        self.averageSplitTime = averageSplitTime
        self.rhythmAccuracy = rhythmAccuracy
        self.cadence = cadence
        self.startHeartRate = startHeartRate
        self.endHeartRate = endHeartRate
        self.startDate = Date()
    }

    // MARK: - Formatted Properties

    var name: String {
        drillType.displayName
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    var formattedScore: String {
        "\(Int(score))%"
    }

    var gradeString: String {
        if score >= 90 { return "Excellent" }
        if score >= 80 { return "Great" }
        if score >= 70 { return "Good" }
        if score >= 60 { return "Fair" }
        return "Keep Practicing"
    }

    /// Primary subscore for this drill type
    var primarySubscore: Double {
        switch drillType.primaryCategory {
        case .stability: return stabilityScore
        case .balance: return stabilityScore
        case .mobility: return coordinationScore
        case .breathing: return breathingScore
        case .rhythm: return rhythmScore
        case .reaction: return reactionScore
        case .recovery: return reactionScore
        case .power: return coordinationScore
        case .coordination: return coordinationScore
        case .endurance: return enduranceScore
        }
    }

    /// All relevant subscores for display
    var relevantSubscores: [(name: String, value: Double)] {
        var scores: [(String, Double)] = []

        if stabilityScore > 0 { scores.append(("Stability", stabilityScore)) }
        if symmetryScore > 0 { scores.append(("Symmetry", symmetryScore)) }
        if enduranceScore > 0 { scores.append(("Endurance", enduranceScore)) }
        if coordinationScore > 0 { scores.append(("Coordination", coordinationScore)) }
        if breathingScore > 0 { scores.append(("Breathing", breathingScore)) }
        if rhythmScore > 0 { scores.append(("Rhythm", rhythmScore)) }
        if reactionScore > 0 { scores.append(("Reaction", reactionScore)) }

        return scores
    }
}

// MARK: - Protocol Conformance

extension UnifiedDrillSession: DrillSessionProtocol {}
