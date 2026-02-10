//
//  UnifiedDrillType.swift
//  TetraTrack
//
//  All drill types unified across disciplines
//

import SwiftUI

/// Unified drill types across all disciplines (30 total)
enum UnifiedDrillType: String, CaseIterable, Codable, Identifiable {
    // MARK: - Riding Drills (10)
    case heelPosition = "Heel Position"
    case coreStability = "Core Stability"
    case twoPoint = "Two-Point"
    case balanceBoard = "Balance Board"
    case hipMobility = "Hip Mobility"
    case postingRhythm = "Posting Rhythm"
    case riderStillness = "Rider Stillness"
    case stirrupPressure = "Stirrup Pressure"
    case extendedSeatHold = "Extended Seat Hold"
    case mountedBreathing = "Mounted Breathing"

    // MARK: - Shooting Drills (9)
    case standingBalance = "Standing Balance"
    case boxBreathing = "Box Breathing"
    case dryFire = "Dry Fire"
    case reactionTime = "Reaction Time"
    case steadyHold = "Steady Hold"
    case recoilControl = "Recoil Control"
    case splitTime = "Split Time"
    case posturalDrift = "Postural Drift"
    case stressInoculation = "Stress Inoculation"

    // MARK: - Running Drills (6)
    case cadenceTraining = "Cadence Training"
    case runningHipMobility = "Running Hip Mobility"
    case runningCoreStability = "Running Core Stability"
    case breathingPatterns = "Breathing Patterns"
    case plyometrics = "Plyometrics"
    case singleLegBalance = "Single-Leg Balance"

    // MARK: - Swimming Drills (5)
    case breathingRhythm = "Breathing Rhythm"
    case swimmingCoreStability = "Swimming Core Stability"
    case shoulderMobility = "Shoulder Mobility"
    case streamlinePosition = "Streamline Position"
    case kickEfficiency = "Kick Efficiency"

    var id: String { rawValue }

    var displayName: String {
        rawValue
    }

    // MARK: - Discipline Mapping

    /// Primary discipline this drill belongs to
    var primaryDiscipline: Discipline {
        switch self {
        // Riding
        case .heelPosition, .coreStability, .twoPoint, .balanceBoard,
             .hipMobility, .postingRhythm, .riderStillness, .stirrupPressure,
             .extendedSeatHold, .mountedBreathing:
            return .riding

        // Shooting
        case .standingBalance, .boxBreathing, .dryFire, .reactionTime,
             .steadyHold, .recoilControl, .splitTime, .posturalDrift, .stressInoculation:
            return .shooting

        // Running
        case .cadenceTraining, .runningHipMobility, .runningCoreStability,
             .breathingPatterns, .plyometrics, .singleLegBalance:
            return .running

        // Swimming
        case .breathingRhythm, .swimmingCoreStability, .shoulderMobility,
             .streamlinePosition, .kickEfficiency:
            return .swimming
        }
    }

    /// All disciplines that benefit from this drill
    var benefitsDisciplines: Set<Discipline> {
        switch self {
        // Universal drills (benefit ALL)
        case .coreStability, .boxBreathing, .standingBalance:
            return [.riding, .running, .swimming, .shooting]

        // Riding + Shooting
        case .balanceBoard, .steadyHold, .riderStillness:
            return [.riding, .shooting]

        // Riding + Running
        case .hipMobility, .runningHipMobility:
            return [.riding, .running]

        // Running + Swimming (balance transfers)
        case .singleLegBalance:
            return [.running, .swimming]

        // Running + Swimming (breathing transfers)
        case .breathingPatterns, .breathingRhythm:
            return [.running, .swimming]

        // All stability drills transfer
        case .runningCoreStability, .swimmingCoreStability:
            return [.riding, .running, .swimming, .shooting]

        // Primary discipline only
        default:
            return [primaryDiscipline]
        }
    }

    // MARK: - Movement Category Mapping

    var primaryCategory: MovementCategory {
        switch self {
        // Stability
        case .coreStability, .riderStillness, .steadyHold, .runningCoreStability,
             .swimmingCoreStability, .streamlinePosition, .posturalDrift:
            return .stability

        // Balance
        case .standingBalance, .balanceBoard, .twoPoint, .heelPosition, .singleLegBalance:
            return .balance

        // Mobility
        case .hipMobility, .runningHipMobility, .shoulderMobility:
            return .mobility

        // Breathing
        case .boxBreathing, .breathingPatterns, .breathingRhythm, .mountedBreathing:
            return .breathing

        // Rhythm
        case .postingRhythm, .cadenceTraining, .kickEfficiency:
            return .rhythm

        // Reaction
        case .reactionTime, .splitTime:
            return .reaction

        // Recovery
        case .recoilControl:
            return .recovery

        // Power
        case .plyometrics, .stirrupPressure:
            return .power

        // Coordination
        case .dryFire:
            return .coordination

        // Endurance
        case .stressInoculation, .extendedSeatHold:
            return .endurance
        }
    }

    // MARK: - UI Properties

    var icon: String {
        switch self {
        // Riding
        case .heelPosition: return "figure.stand"
        case .coreStability: return "figure.core.training"
        case .twoPoint: return "figure.gymnastics"
        case .balanceBoard: return "figure.surfing"
        case .hipMobility: return "figure.flexibility"
        case .postingRhythm: return "metronome"
        case .riderStillness: return "person.and.background.dotted"
        case .stirrupPressure: return "arrow.down.to.line"
        case .extendedSeatHold: return "timer.circle"
        case .mountedBreathing: return "lungs.fill"

        // Shooting
        case .standingBalance: return "figure.stand"
        case .boxBreathing: return "wind"
        case .dryFire: return "hand.point.up.fill"
        case .reactionTime: return "bolt.fill"
        case .steadyHold: return "scope"
        case .recoilControl: return "arrow.uturn.backward"
        case .splitTime: return "timer"
        case .posturalDrift: return "figure.walk.motion"
        case .stressInoculation: return "heart.text.square"

        // Running
        case .cadenceTraining: return "metronome"
        case .runningHipMobility: return "figure.flexibility"
        case .runningCoreStability: return "figure.core.training"
        case .breathingPatterns: return "wind"
        case .plyometrics: return "figure.jumprope"
        case .singleLegBalance: return "figure.stand.line.dotted.figure.stand"

        // Swimming
        case .breathingRhythm: return "wind"
        case .swimmingCoreStability: return "figure.core.training"
        case .shoulderMobility: return "figure.flexibility"
        case .streamlinePosition: return "arrow.right"
        case .kickEfficiency: return "figure.pool.swim"
        }
    }

    var color: Color {
        primaryCategory.color
    }

    var description: String {
        switch self {
        // Riding
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
        case .extendedSeatHold:
            return "Build endurance by maintaining a balanced seat position for extended periods with degradation tracking."
        case .mountedBreathing:
            return "Practice calming breath patterns while maintaining seat stability - essential for nervous horses."

        // Shooting
        case .standingBalance:
            return "Build the stable platform needed for accurate shooting by challenging your balance."
        case .boxBreathing:
            return "Practice box breathing (4-4-4-4) to calm your nervous system and steady your aim."
        case .dryFire:
            return "Develop proper trigger control without recoil distraction. Focus on smooth pulls."
        case .reactionTime:
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

        // Running
        case .cadenceTraining:
            return "Match your steps to a 180 SPM metronome for optimal running efficiency."
        case .runningHipMobility:
            return "Single-leg hip circles to improve hip flexibility for longer strides."
        case .runningCoreStability:
            return "Plank holds with motion tracking to build the stable core runners need."
        case .breathingPatterns:
            return "Practice rhythmic breathing patterns coordinated with movement."
        case .plyometrics:
            return "Jump power measurement and training for explosive running performance."
        case .singleLegBalance:
            return "Build single-leg stability essential for running gait and swimming push-off power."

        // Swimming
        case .breathingRhythm:
            return "Practice bilateral breathing timing for efficient freestyle technique."
        case .swimmingCoreStability:
            return "Prone streamline hold to build the core stability swimmers need."
        case .shoulderMobility:
            return "Stroke-prep shoulder circles to improve range of motion and prevent injury."
        case .streamlinePosition:
            return "Perfect your streamline posture - the foundation of fast swimming."
        case .kickEfficiency:
            return "Flutter kick rhythm analysis to improve kick efficiency and reduce drag."
        }
    }

    /// Suggested duration for this drill in seconds
    var suggestedDuration: TimeInterval {
        switch self {
        case .boxBreathing, .breathingPatterns, .breathingRhythm, .mountedBreathing:
            return 180  // 3 minutes
        case .coreStability, .runningCoreStability, .swimmingCoreStability,
             .steadyHold, .streamlinePosition, .singleLegBalance:
            return 60   // 1 minute
        case .posturalDrift, .stressInoculation, .extendedSeatHold:
            return 300  // 5 minutes
        case .plyometrics:
            return 120  // 2 minutes
        default:
            return 60   // 1 minute default
        }
    }

    // MARK: - Static Helpers

    /// Get all drills for a specific discipline
    static func drills(for discipline: Discipline) -> [UnifiedDrillType] {
        if discipline == .all {
            return allCases
        }
        return allCases.filter { $0.benefitsDisciplines.contains(discipline) }
    }

    /// Get all drills for a specific movement category
    static func drills(for category: MovementCategory) -> [UnifiedDrillType] {
        allCases.filter { $0.primaryCategory == category }
    }

    /// Get drills filtered by both discipline and category
    static func drills(for discipline: Discipline, in category: MovementCategory) -> [UnifiedDrillType] {
        if discipline == .all {
            return drills(for: category)
        }
        return allCases.filter {
            $0.primaryCategory == category && $0.benefitsDisciplines.contains(discipline)
        }
    }

    // MARK: - Legacy Mapping

    /// Convert from legacy RidingDrillType
    static func from(ridingDrillType: RidingDrillType) -> UnifiedDrillType {
        switch ridingDrillType {
        case .heelPosition: return .heelPosition
        case .coreStability: return .coreStability
        case .twoPoint: return .twoPoint
        case .balanceBoard: return .balanceBoard
        case .hipMobility: return .hipMobility
        case .postingRhythm: return .postingRhythm
        case .riderStillness: return .riderStillness
        case .stirrupPressure: return .stirrupPressure
        }
    }

    /// Convert from legacy ShootingDrillType
    static func from(shootingDrillType: ShootingDrillType) -> UnifiedDrillType {
        switch shootingDrillType {
        case .balance: return .standingBalance
        case .breathing: return .boxBreathing
        case .dryFire: return .dryFire
        case .reaction: return .reactionTime
        case .steadyHold: return .steadyHold
        case .recoilControl: return .recoilControl
        case .splitTime: return .splitTime
        case .posturalDrift: return .posturalDrift
        case .stressInoculation: return .stressInoculation
        }
    }
}
