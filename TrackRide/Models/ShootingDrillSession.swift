//
//  ShootingDrillSession.swift
//  TrackRide
//
//  Model for storing completed shooting training drills
//

import Foundation
import SwiftData

/// Types of shooting drills available
enum ShootingDrillType: String, Codable, CaseIterable {
    // Existing drills
    case balance = "Balance"
    case breathing = "Breathing"
    case dryFire = "Dry Fire"
    case reaction = "Reaction"
    case steadyHold = "Steady Hold"

    // New movement-science drills
    case recoilControl = "Recoil Control"
    case splitTime = "Split Time"
    case posturalDrift = "Postural Drift"
    case stressInoculation = "Stress Inoculation"

    var displayName: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .balance: return "figure.stand"
        case .breathing: return "wind"
        case .dryFire: return "hand.point.up.fill"
        case .reaction: return "bolt.fill"
        case .steadyHold: return "scope"
        case .recoilControl: return "arrow.uturn.backward"
        case .splitTime: return "timer"
        case .posturalDrift: return "figure.walk.motion"
        case .stressInoculation: return "heart.text.square"
        }
    }

    var color: String {
        switch self {
        case .balance: return "purple"
        case .breathing: return "blue"
        case .dryFire: return "green"
        case .reaction: return "orange"
        case .steadyHold: return "cyan"
        case .recoilControl: return "red"
        case .splitTime: return "yellow"
        case .posturalDrift: return "indigo"
        case .stressInoculation: return "pink"
        }
    }

    var description: String {
        switch self {
        case .balance:
            return "Build the stable platform needed for accurate shooting by challenging your balance."
        case .breathing:
            return "Practice box breathing (4-4-4-4) to calm your nervous system and steady your aim."
        case .dryFire:
            return "Develop proper trigger control without recoil distraction. Focus on smooth pulls."
        case .reaction:
            return "Build quick reflexes for rapid target acquisition with voice-guided commands."
        case .steadyHold:
            return "Measure and improve your ability to maintain a stable aim point."
        case .recoilControl:
            return "Practice returning to target after simulated recoil. Speed and accuracy matter."
        case .splitTime:
            return "Train rapid transitions between multiple targets while maintaining accuracy."
        case .posturalDrift:
            return "Extended hold drill measuring how your stability degrades over time."
        case .stressInoculation:
            return "Perform shooting drills at elevated heart rate to simulate competition stress."
        }
    }
}

/// Records a completed shooting training drill session
@Model
final class ShootingDrillSession {
    var id: UUID = UUID()
    var startDate: Date = Date()
    var drillTypeRaw: String = ShootingDrillType.balance.rawValue
    var duration: TimeInterval = 0
    var score: Double = 0  // 0-100 score
    var notes: String = ""

    // MARK: - Subscores (physics-based)

    /// Stability subscore - steadiness during aim (0-100)
    var stabilityScore: Double = 0

    /// Recovery subscore - return-to-target speed for recoil control (0-100)
    var recoveryScore: Double = 0

    /// Transition subscore - target-to-target speed for split time (0-100)
    var transitionScore: Double = 0

    /// Endurance subscore - stability degradation for postural drift (0-100)
    var enduranceScore: Double = 0

    // MARK: - Detailed Metrics

    /// Average wobble during hold (radians)
    var averageWobble: Double = 0

    /// Best reaction time (seconds)
    var bestReactionTime: Double = 0

    /// Average split time between targets (seconds)
    var averageSplitTime: Double = 0

    /// Heart rate at start of drill (for stress inoculation)
    var startHeartRate: Double = 0

    /// Computed drill type from raw string
    var drillType: ShootingDrillType {
        get { ShootingDrillType(rawValue: drillTypeRaw) ?? .balance }
        set { drillTypeRaw = newValue.rawValue }
    }

    init() {}

    convenience init(drillType: ShootingDrillType, duration: TimeInterval, score: Double) {
        self.init()
        self.drillTypeRaw = drillType.rawValue
        self.duration = duration
        self.score = score
        self.startDate = Date()
    }

    /// Full initializer with subscores
    convenience init(
        drillType: ShootingDrillType,
        duration: TimeInterval,
        score: Double,
        stabilityScore: Double,
        recoveryScore: Double = 0,
        transitionScore: Double = 0,
        enduranceScore: Double = 0,
        averageWobble: Double = 0,
        bestReactionTime: Double = 0,
        averageSplitTime: Double = 0,
        startHeartRate: Double = 0
    ) {
        self.init()
        self.drillTypeRaw = drillType.rawValue
        self.duration = duration
        self.score = score
        self.stabilityScore = stabilityScore
        self.recoveryScore = recoveryScore
        self.transitionScore = transitionScore
        self.enduranceScore = enduranceScore
        self.averageWobble = averageWobble
        self.bestReactionTime = bestReactionTime
        self.averageSplitTime = averageSplitTime
        self.startHeartRate = startHeartRate
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
