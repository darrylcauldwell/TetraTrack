//
//  RidingDrillSession.swift
//  TetraTrack
//
//  Model for storing completed off-horse riding training drills
//

import Foundation
import SwiftData

/// Types of riding drills available
enum RidingDrillType: String, Codable, CaseIterable {
    // Existing drills
    case heelPosition = "Heel Position"
    case coreStability = "Core Stability"
    case twoPoint = "Two-Point"
    case balanceBoard = "Balance Board"

    // New movement-science drills
    case hipMobility = "Hip Mobility"
    case postingRhythm = "Posting Rhythm"
    case riderStillness = "Rider Stillness"
    case stirrupPressure = "Stirrup Pressure"

    var displayName: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .heelPosition: return "figure.stand"
        case .coreStability: return "figure.core.training"
        case .twoPoint: return "figure.gymnastics"
        case .balanceBoard: return "figure.surfing"
        case .hipMobility: return "figure.flexibility"
        case .postingRhythm: return "metronome"
        case .riderStillness: return "person.and.background.dotted"
        case .stirrupPressure: return "arrow.down.to.line"
        }
    }

    var color: String {
        switch self {
        case .heelPosition: return "green"
        case .coreStability: return "blue"
        case .twoPoint: return "orange"
        case .balanceBoard: return "purple"
        case .hipMobility: return "pink"
        case .postingRhythm: return "indigo"
        case .riderStillness: return "teal"
        case .stirrupPressure: return "mint"
        }
    }

    var description: String {
        switch self {
        case .heelPosition:
            return "Practice maintaining proper heel-down position for stability and security in the stirrups."
        case .coreStability:
            return "Develop core strength for an independent seat that follows the horse's movement."
        case .twoPoint:
            return "Build leg strength and balance in the forward jumping position."
        case .balanceBoard:
            return "Challenge proprioception and build reflexes for maintaining balance."
        case .hipMobility:
            return "Practice hip circles while keeping your upper body still - essential for following the horse."
        case .postingRhythm:
            return "Train to a metronome to develop consistent posting rhythm for the rising trot."
        case .riderStillness:
            return "Challenge yourself to minimize all movement - the foundation of quiet, effective aids."
        case .stirrupPressure:
            return "Practice maintaining consistent weight through your heels and stirrups."
        }
    }
}

/// Records a completed off-horse riding drill session
@Model
final class RidingDrillSession {
    var id: UUID = UUID()
    var startDate: Date = Date()
    var drillTypeRaw: String = RidingDrillType.coreStability.rawValue
    var duration: TimeInterval = 0
    var score: Double = 0  // 0-100 score
    var notes: String = ""

    // MARK: - Subscores (physics-based)

    /// Stability subscore - inverse of motion variance (0-100)
    var stabilityScore: Double = 0

    /// Symmetry subscore - left/right balance (0-100)
    var symmetryScore: Double = 0

    /// Endurance subscore - score degradation over time (0-100)
    var enduranceScore: Double = 0

    /// Coordination subscore - multi-axis timing correlation (0-100)
    var coordinationScore: Double = 0

    // MARK: - Detailed Metrics

    /// Average root mean square motion during drill
    var averageRMS: Double = 0

    /// Peak deviation from stable position (radians)
    var peakDeviation: Double = 0

    /// Rhythm accuracy for posting rhythm drill (0-100)
    var rhythmAccuracy: Double = 0

    /// Computed drill type from raw string
    var drillType: RidingDrillType {
        get { RidingDrillType(rawValue: drillTypeRaw) ?? .coreStability }
        set { drillTypeRaw = newValue.rawValue }
    }

    init() {}

    convenience init(drillType: RidingDrillType, duration: TimeInterval, score: Double) {
        self.init()
        self.drillTypeRaw = drillType.rawValue
        self.duration = duration
        self.score = score
        self.startDate = Date()
    }

    /// Full initializer with subscores
    convenience init(
        drillType: RidingDrillType,
        duration: TimeInterval,
        score: Double,
        stabilityScore: Double,
        symmetryScore: Double,
        enduranceScore: Double,
        coordinationScore: Double,
        averageRMS: Double = 0,
        peakDeviation: Double = 0,
        rhythmAccuracy: Double = 0
    ) {
        self.init()
        self.drillTypeRaw = drillType.rawValue
        self.duration = duration
        self.score = score
        self.stabilityScore = stabilityScore
        self.symmetryScore = symmetryScore
        self.enduranceScore = enduranceScore
        self.coordinationScore = coordinationScore
        self.averageRMS = averageRMS
        self.peakDeviation = peakDeviation
        self.rhythmAccuracy = rhythmAccuracy
        self.startDate = Date()
    }

    // MARK: - Formatted Properties

    var name: String {
        drillType.rawValue
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
}
