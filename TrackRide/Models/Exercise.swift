//
//  Exercise.swift
//  TrackRide
//
//  Arena exercises and schooling figures
//

import Foundation
import SwiftData

@Model
final class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    var exerciseDescription: String = ""
    var disciplineRaw: String = "flatwork"
    var difficultyRaw: String = "Beginner"
    var categoryRaw: String = "School Figures"
    var instructions: String = ""
    var tips: String = ""
    var commonMistakes: String = ""
    var benefits: String = ""
    var diagramName: String = "" // Asset catalog image name
    var isBuiltIn: Bool = true
    var isFavorite: Bool = false

    // Pole work specific properties
    var isPoleExercise: Bool = false
    var numberOfPoles: Int = 0
    var basePoleSpacingMeters: Double = 0 // Base spacing for medium horse (15hh)
    var poleLayoutRaw: String = "" // straight, curved, fan, etc.

    var discipline: RideType {
        get { RideType(rawValue: disciplineRaw) ?? .schooling }
        set { disciplineRaw = newValue.rawValue }
    }

    var difficulty: ExerciseDifficulty {
        get { ExerciseDifficulty(rawValue: difficultyRaw) ?? .beginner }
        set { difficultyRaw = newValue.rawValue }
    }

    var category: ExerciseCategory {
        get { ExerciseCategory(rawValue: categoryRaw) ?? .figures }
        set { categoryRaw = newValue.rawValue }
    }

    init() {}

    init(
        name: String,
        description: String,
        discipline: RideType = .schooling,
        difficulty: ExerciseDifficulty = .beginner,
        category: ExerciseCategory = .figures,
        instructions: String = "",
        tips: String = "",
        commonMistakes: String = "",
        benefits: String = ""
    ) {
        self.name = name
        self.exerciseDescription = description
        self.disciplineRaw = discipline.rawValue
        self.difficultyRaw = difficulty.rawValue
        self.categoryRaw = category.rawValue
        self.instructions = instructions
        self.tips = tips
        self.commonMistakes = commonMistakes
        self.benefits = benefits
        self.isBuiltIn = true
    }
}

// MARK: - Exercise Difficulty

enum ExerciseDifficulty: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case novice = "Novice"
    case elementary = "Elementary"
    case medium = "Medium"
    case advanced = "Advanced"

    var sortOrder: Int {
        switch self {
        case .beginner: return 0
        case .novice: return 1
        case .elementary: return 2
        case .medium: return 3
        case .advanced: return 4
        }
    }
}

// MARK: - Exercise Category

enum ExerciseCategory: String, Codable, CaseIterable {
    case figures = "School Figures"
    case transitions = "Transitions"
    case lateral = "Lateral Work"
    case jumping = "Jumping"
    case polework = "Pole Work"
    case warmup = "Warm-up"
    case cooldown = "Cool-down"

    var icon: String {
        switch self {
        case .figures: return "circle"
        case .transitions: return "arrow.up.arrow.down"
        case .lateral: return "arrow.left.arrow.right"
        case .jumping: return "figure.equestrian.sports"
        case .polework: return "line.3.horizontal"
        case .warmup: return "flame.fill"
        case .cooldown: return "snowflake"
        }
    }
}

// MARK: - Pole Layout

enum PoleLayout: String, Codable, CaseIterable {
    case straight = "Straight Line"
    case curved = "Curved/Arc"
    case fan = "Fan"
    case raised = "Raised"
    case bounce = "Bounce"
    case grid = "Grid"

    var icon: String {
        switch self {
        case .straight: return "line.3.horizontal"
        case .curved: return "arrow.up.right.and.arrow.down.left"
        case .fan: return "chevron.up"
        case .raised: return "arrow.up"
        case .bounce: return "arrow.up.arrow.down"
        case .grid: return "square.grid.3x3"
        }
    }
}

// MARK: - Pole Spacing Calculator

struct PoleSpacingCalculator {
    /// Base pole spacings for a 15hh horse (in meters)
    static let walkSpacing: Double = 0.75  // 75cm
    static let trotSpacing: Double = 1.30  // 1.3m
    static let canterSpacing: Double = 3.0 // 3m
    static let bounceSpacing: Double = 3.3 // 3.3m (one non-jumping stride)

    /// Calculate adjusted spacing based on horse height
    /// - Parameters:
    ///   - baseSpacing: The base spacing for a 15hh horse
    ///   - horseHeightHands: The horse's height in hands
    /// - Returns: Adjusted spacing in meters
    static func adjustedSpacing(baseSpacing: Double, forHeightHands horseHeightHands: Double) -> Double {
        // Adjustment factor: approximately 5cm per hand difference from 15hh
        let baseHeight: Double = 15.0
        let adjustmentPerHand: Double = 0.05 // 5cm per hand
        let heightDifference = horseHeightHands - baseHeight
        let adjustment = heightDifference * adjustmentPerHand

        return baseSpacing + adjustment
    }

    /// Get recommended pole spacings for a horse
    static func recommendedSpacings(forHeightHands height: Double) -> PoleSpacings {
        PoleSpacings(
            walk: adjustedSpacing(baseSpacing: walkSpacing, forHeightHands: height),
            trot: adjustedSpacing(baseSpacing: trotSpacing, forHeightHands: height),
            canter: adjustedSpacing(baseSpacing: canterSpacing, forHeightHands: height),
            bounce: adjustedSpacing(baseSpacing: bounceSpacing, forHeightHands: height)
        )
    }

    /// Format spacing for display
    static func formatSpacing(_ meters: Double) -> String {
        if meters < 1.0 {
            return String(format: "%.0fcm", meters * 100)
        }
        return String(format: "%.2fm", meters)
    }
}

struct PoleSpacings {
    let walk: Double
    let trot: Double
    let canter: Double
    let bounce: Double

    var formattedWalk: String { PoleSpacingCalculator.formatSpacing(walk) }
    var formattedTrot: String { PoleSpacingCalculator.formatSpacing(trot) }
    var formattedCanter: String { PoleSpacingCalculator.formatSpacing(canter) }
    var formattedBounce: String { PoleSpacingCalculator.formatSpacing(bounce) }
}

// MARK: - Built-in Exercises

extension Exercise {
    static func createBuiltInExercises() -> [Exercise] {
        var exercises: [Exercise] = []

        // School Figures
        exercises.append(Exercise(
            name: "20m Circle",
            description: "A large circle using half the arena width",
            discipline: .schooling,
            difficulty: .beginner,
            category: .figures,
            instructions: """
            1. At A or C, turn onto the circle
            2. Pass through X at the centre
            3. Maintain consistent bend throughout
            4. Return to the track after one full circle
            """,
            tips: "Look where you're going, not at your horse. Use your inside leg at the girth and outside leg slightly behind.",
            commonMistakes: "Egg-shaped circles, losing rhythm, horse falling in or out",
            benefits: "Develops bend, balance, and rhythm. Foundation for all lateral work."
        ))

        exercises.append(Exercise(
            name: "15m Circle",
            description: "A medium circle requiring more collection",
            discipline: .schooling,
            difficulty: .novice,
            category: .figures,
            instructions: """
            1. Begin between the markers
            2. The circle should touch the track and pass 2.5m inside X
            3. Maintain consistent bend and rhythm
            4. Gradually decrease then increase speed if needed
            """,
            tips: "Prepare your horse with a half-halt before starting. Keep your shoulders aligned with your horse's shoulders.",
            commonMistakes: "Circle too large, horse falling onto inside shoulder, inconsistent tempo",
            benefits: "Increases collection, improves bend, prepares for smaller circles."
        ))

        exercises.append(Exercise(
            name: "10m Circle",
            description: "A small circle requiring good collection and balance",
            discipline: .schooling,
            difficulty: .elementary,
            category: .figures,
            instructions: """
            1. Prepare with half-halts before starting
            2. Circle should be ridden at walk or collected trot initially
            3. Maintain forward energy despite the smaller circle
            4. Keep the horse upright, not leaning in
            """,
            tips: "Think of your inside leg as a post the horse bends around. Only attempt in canter when horse is confirmed in collection.",
            commonMistakes: "Horse falling in, losing impulsion, breaking gait, uneven circle",
            benefits: "Develops collection, engagement, and carrying power."
        ))

        exercises.append(Exercise(
            name: "Serpentine (3 loops)",
            description: "Three equal loops across the arena",
            discipline: .schooling,
            difficulty: .beginner,
            category: .figures,
            instructions: """
            1. Start at A or C
            2. Make three equal loops touching each long side
            3. Change bend as you cross the centre line
            4. Finish at the opposite end of the arena
            """,
            tips: "Plan your loops before you start. The change of bend should be smooth, not abrupt.",
            commonMistakes: "Uneven loops, rushed changes of bend, losing rhythm",
            benefits: "Improves suppleness, teaches changes of bend, develops straightness on centre line."
        ))

        exercises.append(Exercise(
            name: "Figure of Eight",
            description: "Two circles joined at the centre",
            discipline: .schooling,
            difficulty: .novice,
            category: .figures,
            instructions: """
            1. Begin with a circle on one rein
            2. At X, straighten briefly
            3. Change bend and begin circle on opposite rein
            4. Return to X and repeat or continue on track
            """,
            tips: "The moment of straightness at X is crucial - it prepares for the new bend.",
            commonMistakes: "No moment of straightness, wobbly change of direction, unequal circles",
            benefits: "Improves suppleness both ways, teaches clean changes of bend."
        ))

        exercises.append(Exercise(
            name: "Shallow Loop",
            description: "5m loop from the track and back",
            discipline: .schooling,
            difficulty: .beginner,
            category: .figures,
            instructions: """
            1. Leave the track after a corner
            2. Loop 5m into the arena (to the quarter line)
            3. Return to the track before the next corner
            4. Maintain bend in direction of travel
            """,
            tips: "Use this to introduce counter-canter by maintaining the original lead.",
            commonMistakes: "Loop too deep or shallow, losing balance, breaking in canter",
            benefits: "Introduces counter-flexion, prepares for counter-canter, improves balance."
        ))

        // Transitions
        exercises.append(Exercise(
            name: "Walk-Trot Transitions",
            description: "Practice smooth transitions between walk and trot",
            discipline: .schooling,
            difficulty: .beginner,
            category: .transitions,
            instructions: """
            1. Establish a good working walk
            2. Prepare with a half-halt
            3. Apply leg aids for trot
            4. After 20m, prepare and transition back to walk
            """,
            tips: "Think 'forward into the transition'. Don't throw away the contact.",
            commonMistakes: "Abrupt transitions, losing contact, horse rushing or resisting",
            benefits: "Develops responsiveness to aids, improves balance and engagement."
        ))

        exercises.append(Exercise(
            name: "Trot-Canter Transitions",
            description: "Develop smooth upward and downward canter transitions",
            discipline: .schooling,
            difficulty: .novice,
            category: .transitions,
            instructions: """
            1. Establish a balanced working trot
            2. Position for the correct lead (inside flexion)
            3. Half-halt, then apply canter aid
            4. After one circle, half-halt to trot
            """,
            tips: "Ask in a corner where the horse is already positioned correctly.",
            commonMistakes: "Wrong lead, running into canter, falling onto forehand in downward",
            benefits: "Develops balance, responsiveness, and correct positioning."
        ))

        exercises.append(Exercise(
            name: "Progressive Transitions",
            description: "Walk-trot-canter-trot-walk in sequence",
            discipline: .schooling,
            difficulty: .elementary,
            category: .transitions,
            instructions: """
            1. Begin in walk on a 20m circle
            2. Transition to trot for half the circle
            3. Transition to canter for one full circle
            4. Return to trot, then walk
            """,
            tips: "Each gait should be established before moving to the next. Don't rush.",
            commonMistakes: "Rushing through gaits, losing balance, breaking sequence",
            benefits: "Develops obedience, throughness, and self-carriage."
        ))

        // Lateral Work
        exercises.append(Exercise(
            name: "Leg Yield",
            description: "Horse moves forward and sideways from leg pressure",
            discipline: .schooling,
            difficulty: .novice,
            category: .lateral,
            instructions: """
            1. In walk or trot, position slight flexion away from direction of travel
            2. Apply inside leg at the girth
            3. Horse should step forward and sideways
            4. Outside leg and rein prevent too much sideways movement
            """,
            tips: "Think more forward than sideways. The crossing of legs should be clear but not exaggerated.",
            commonMistakes: "Too much bend, losing forward momentum, quarters leading",
            benefits: "Teaches horse to move from the leg, improves suppleness and obedience."
        ))

        exercises.append(Exercise(
            name: "Shoulder-In",
            description: "Horse bent around inside leg, shoulders brought in from track",
            discipline: .schooling,
            difficulty: .elementary,
            category: .lateral,
            instructions: """
            1. Coming out of a corner, maintain the bend
            2. Bring the shoulders in so horse moves on three tracks
            3. Inside leg at girth maintains bend and impulsion
            4. Outside rein controls the degree of angle
            """,
            tips: "Start with a few steps, gradually increase. Think of riding the inside hind toward the outside shoulder.",
            commonMistakes: "Too much angle, losing impulsion, neck bend only",
            benefits: "The 'mother of all exercises'. Develops collection, engagement, and straightness."
        ))

        exercises.append(Exercise(
            name: "Turn on the Forehand",
            description: "Quarters move around the forehand",
            discipline: .schooling,
            difficulty: .beginner,
            category: .lateral,
            instructions: """
            1. Halt on the track, parallel to the fence
            2. Slight flexion in direction of turn
            3. Inside leg behind girth pushes quarters over
            4. Front legs step small circle, hinds step larger circle
            """,
            tips: "Keep slight forward tendency - don't let horse step back. One step at a time.",
            commonMistakes: "Walking forward, stepping back, rushing",
            benefits: "Teaches response to lateral leg aids, good introduction to lateral work."
        ))

        // Pole Work
        exercises.append(Exercise(
            name: "Trotting Poles",
            description: "4-6 poles set for trot stride length",
            discipline: .schooling,
            difficulty: .beginner,
            category: .polework,
            instructions: """
            1. Set 4-6 poles approximately 1.2-1.4m apart
            2. Approach in rising trot on a straight line
            3. Maintain rhythm before, over, and after poles
            4. Look ahead, not down at the poles
            """,
            tips: "Adjust spacing to your horse's stride. Aim for the middle of each pole.",
            commonMistakes: "Looking down, changing rhythm, approaching at an angle",
            benefits: "Improves rhythm, encourages engagement, develops eye for distance."
        ))

        exercises.append(Exercise(
            name: "Canter Poles",
            description: "3-4 poles set for canter stride",
            discipline: .schooling,
            difficulty: .novice,
            category: .polework,
            instructions: """
            1. Set 3-4 poles approximately 3-3.5m apart
            2. Approach in balanced canter
            3. Maintain canter rhythm throughout
            4. Keep straight line through the poles
            """,
            tips: "Start with 3 poles and add more as horse becomes confident.",
            commonMistakes: "Breaking to trot, rushing, chipping in extra stride",
            benefits: "Develops adjustability, teaches horse to judge distances."
        ))

        // Warm-up
        exercises.append(Exercise(
            name: "Free Walk on Long Rein",
            description: "Allow horse to stretch and relax",
            discipline: .schooling,
            difficulty: .beginner,
            category: .warmup,
            instructions: """
            1. Allow the reins to slip through your fingers
            2. Maintain contact but let horse stretch neck down and forward
            3. Walk on a large circle or around the arena
            4. Horse should track up or overtrack
            """,
            tips: "This should be genuinely relaxing - don't ask for anything except forward movement.",
            commonMistakes: "Restricting stretch, letting horse fall onto forehand completely",
            benefits: "Warms up muscles, allows horse to relax, stretches topline."
        ))

        return exercises
    }
}
