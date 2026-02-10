//
//  PoleworkExerciseData.swift
//  TetraTrack
//
//  Pre-populated polework and grid exercises with stride length calculations
//

import Foundation

// MARK: - Polework Exercise Data Provider

struct PoleworkExerciseData {

    /// Creates all built-in polework exercises
    static func createBuiltInExercises() -> [PoleworkExercise] {
        var exercises: [PoleworkExercise] = []

        // MARK: - Ground Poles (Beginner)

        exercises.append(PoleworkExercise(
            name: "Basic Walk Poles",
            description: "Four ground poles at walk distance to encourage the horse to look down, pick up their feet, and develop rhythm.",
            difficulty: .beginner,
            category: .groundPoles,
            exerciseType: .walkPoles,
            numberOfPoles: 4,
            arrangement: .straight,
            instructions: [
                "Set 4 poles at walk distance apart",
                "Approach in a straight line with active walk",
                "Allow the horse to lower their head and look at the poles",
                "Maintain consistent rhythm through all poles",
                "Keep a light contact but don't restrict the neck"
            ],
            benefits: [
                "Encourages the horse to engage their core",
                "Improves proprioception and coordination",
                "Teaches horse to judge distances",
                "Great warm-up exercise"
            ],
            tips: [
                "Start with just 2 poles and build up",
                "Let the horse work it out - don't interfere too much",
                "If horse rushes, go back to fewer poles"
            ],
            safetyNotes: [
                "Ensure poles are heavy enough not to roll",
                "Check ground is level and non-slip"
            ],
            requiredGaits: [.walk]
        ))

        exercises.append(PoleworkExercise(
            name: "Basic Trot Poles",
            description: "The foundation of all polework - four ground poles at trot distance to develop rhythm and balance.",
            difficulty: .beginner,
            category: .groundPoles,
            exerciseType: .trotPoles,
            numberOfPoles: 4,
            arrangement: .straight,
            instructions: [
                "Set 4 poles at trot distance apart",
                "Establish a balanced working trot",
                "Look ahead, not down at the poles",
                "Maintain the same rhythm before, during, and after",
                "Rise to the trot - sitting can unbalance young horses"
            ],
            benefits: [
                "Develops rhythm and cadence",
                "Improves engagement of the hindquarters",
                "Encourages the horse to use their back",
                "Builds confidence for jumping"
            ],
            tips: [
                "Adjust distance slightly if horse is consistently hitting poles",
                "Count the rhythm out loud to maintain consistency",
                "The approach is as important as the poles themselves"
            ],
            safetyNotes: [
                "Use proper trot pole cups if raising",
                "Don't place poles on uneven ground"
            ],
            requiredGaits: [.trot]
        ))

        exercises.append(PoleworkExercise(
            name: "Six Trot Poles",
            description: "Extended trot pole sequence for developing sustained rhythm and focus.",
            difficulty: .beginner,
            category: .groundPoles,
            exerciseType: .trotPoles,
            numberOfPoles: 6,
            arrangement: .straight,
            instructions: [
                "Set 6 poles at trot distance apart",
                "Approach in a straight line with balanced trot",
                "Maintain steady rhythm throughout all poles",
                "Keep leg on to maintain impulsion",
                "Look to a point beyond the last pole"
            ],
            benefits: [
                "Develops sustained concentration",
                "Improves fitness and stamina",
                "Tests consistency of rhythm",
                "Builds core strength in horse"
            ],
            tips: [
                "If horse rushes through, slow down before the poles",
                "Use half-halts in the approach",
                "Quality over quantity - better 4 good poles than 6 rushed ones"
            ],
            safetyNotes: [
                "Ensure all poles are equally spaced",
                "Check for loose rails before each pass"
            ],
            requiredGaits: [.trot]
        ))

        exercises.append(PoleworkExercise(
            name: "Basic Canter Poles",
            description: "Three ground poles at canter distance to develop an adjustable, balanced canter.",
            difficulty: .intermediate,
            category: .groundPoles,
            exerciseType: .canterPoles,
            numberOfPoles: 3,
            arrangement: .straight,
            instructions: [
                "Set 3 poles at canter distance apart",
                "Establish a balanced working canter",
                "Approach straight and centered",
                "Maintain the canter lead throughout",
                "Keep a consistent rhythm - don't speed up"
            ],
            benefits: [
                "Develops adjustability in canter",
                "Improves balance and self-carriage",
                "Preparation for related distances in jumping",
                "Teaches horse to wait and not rush"
            ],
            tips: [
                "If horse rushes, the poles may be too close",
                "For green horses, start with just 1 pole",
                "Focus on straightness - drifting causes problems"
            ],
            safetyNotes: [
                "Canter poles need more space - check arena size",
                "Be prepared for horse to break to trot initially"
            ],
            requiredGaits: [.canter]
        ))

        // MARK: - Raised Poles

        exercises.append(PoleworkExercise(
            name: "Raised Trot Poles",
            description: "Trot poles raised to approximately 15-20cm to increase engagement and articulation.",
            difficulty: .intermediate,
            category: .raisedPoles,
            exerciseType: .raisedTrotPoles,
            numberOfPoles: 4,
            isRaised: true,
            raiseHeightCm: 15,
            arrangement: .straight,
            instructions: [
                "Set 4 poles at raised trot distance (slightly longer than ground poles)",
                "Raise both ends to approximately 15cm",
                "Establish an active, forward trot",
                "Allow horse to lower head slightly to see poles",
                "Maintain rhythm but expect increased suspension"
            ],
            benefits: [
                "Increases hock and stifle flexion",
                "Develops greater engagement",
                "Strengthens the hindquarters",
                "Improves jump technique"
            ],
            tips: [
                "Distance needs to be slightly longer than ground poles",
                "Horse may find this tiring - don't overdo it",
                "Build up height gradually over sessions"
            ],
            safetyNotes: [
                "Use proper pole cups - not blocks",
                "Ensure cups can break away if hit hard",
                "Start lower (10cm) for green horses"
            ],
            requiredGaits: [.trot]
        ))

        exercises.append(PoleworkExercise(
            name: "Alternating Height Poles",
            description: "A mix of ground and raised poles to encourage the horse to really look and think.",
            difficulty: .intermediate,
            category: .raisedPoles,
            exerciseType: .trotPoles,
            numberOfPoles: 5,
            isRaised: true,
            raiseHeightCm: 15,
            arrangement: .straight,
            instructions: [
                "Set pole 1, 3, 5 on the ground",
                "Raise poles 2 and 4 to 15cm",
                "Keep all poles at the same trot distance",
                "Approach in balanced trot",
                "Allow horse to adjust - don't micromanage"
            ],
            benefits: [
                "Encourages horse to look and think",
                "Develops adjustability",
                "Improves coordination",
                "More interesting for both horse and rider"
            ],
            tips: [
                "Watch for horse anticipating - vary the pattern",
                "Can reverse which poles are raised",
                "Progress to raising alternate ends"
            ],
            safetyNotes: [
                "Ensure all poles are secure",
                "Check cups after each pass"
            ],
            requiredGaits: [.trot]
        ))

        // MARK: - Cavaletti

        exercises.append(PoleworkExercise(
            name: "Cavaletti Grid",
            description: "Traditional cavaletti blocks set at trot height for gymnastic work.",
            difficulty: .intermediate,
            category: .cavaletti,
            exerciseType: .cavaletti,
            numberOfPoles: 4,
            isRaised: true,
            raiseHeightCm: 20,
            arrangement: .straight,
            instructions: [
                "Set 4 cavaletti at trot distance",
                "Height approximately 20cm (lowest setting)",
                "Approach in working trot",
                "Maintain steady rhythm throughout",
                "Can be ridden in rising or sitting trot"
            ],
            benefits: [
                "Classic gymnastic exercise",
                "Improves suppleness and strength",
                "Develops consistent rhythm",
                "Traditional training method"
            ],
            tips: [
                "Traditional cavaletti can be rotated to change height",
                "Start at lowest setting",
                "Can add more cavaletti as horse becomes confident"
            ],
            safetyNotes: [
                "Traditional cavaletti are safer than blocks",
                "Ensure end pieces are weighted",
                "Check for splinters on wooden cavaletti"
            ],
            requiredGaits: [.trot]
        ))

        // MARK: - Circle Work

        exercises.append(PoleworkExercise(
            name: "Trot Poles on a Circle",
            description: "Four poles arranged on a 20m circle to improve bend and balance.",
            difficulty: .intermediate,
            category: .circles,
            exerciseType: .trotPoles,
            numberOfPoles: 4,
            arrangement: .curved,
            instructions: [
                "Place 4 poles on a 20m circle, evenly spaced (at 12, 3, 6, and 9 o'clock)",
                "Each pole should be perpendicular to the circle line",
                "Aim to cross each pole at the same point each time",
                "Maintain consistent bend throughout the circle",
                "Use inside leg to maintain impulsion over each pole"
            ],
            benefits: [
                "Develops consistent bend",
                "Improves balance on a curve",
                "Tests accuracy and straightness within the bend",
                "Adds interest to circle work"
            ],
            tips: [
                "The horse should maintain the same rhythm between poles",
                "If drifting, the poles reveal the problem",
                "Can place on a 15m circle for more challenge"
            ],
            safetyNotes: [
                "Ensure poles are clearly visible",
                "Leave enough space between poles for steering"
            ],
            requiredGaits: [.trot]
        ))

        exercises.append(PoleworkExercise(
            name: "Fan Poles (Trot)",
            description: "Poles arranged in a fan shape allowing distance adjustment within the same exercise.",
            difficulty: .intermediate,
            category: .circles,
            exerciseType: .fanPoles,
            numberOfPoles: 4,
            arrangement: .fan,
            instructions: [
                "Arrange 4 poles in a fan pattern",
                "Inner edge: 70% of normal trot distance (shorter stride)",
                "Outer edge: 130% of normal trot distance (longer stride)",
                "Start by riding through the middle",
                "Move to inner edge for collection, outer for extension"
            ],
            benefits: [
                "One exercise, three different distances",
                "Develops adjustability without changing setup",
                "Teaches collection and extension",
                "Excellent for varying the horse's stride"
            ],
            tips: [
                "Mark the middle with tape or marker",
                "Horse should stay on the same arc throughout",
                "Don't change direction - will confuse distances"
            ],
            safetyNotes: [
                "Poles can pivot - weight the inside ends",
                "Leave enough space at the wide end"
            ],
            requiredGaits: [.trot]
        ))

        exercises.append(PoleworkExercise(
            name: "Fan Poles (Canter)",
            description: "Canter fan poles for developing adjustable stride length at canter.",
            difficulty: .advanced,
            category: .circles,
            exerciseType: .canterPoles,
            numberOfPoles: 3,
            arrangement: .fan,
            instructions: [
                "Arrange 3 poles in a fan pattern at canter distance",
                "Inner edge for collected canter (shorter stride)",
                "Outer edge for medium canter (longer stride)",
                "Maintain consistent lead throughout",
                "Keep the canter balanced - no rushing"
            ],
            benefits: [
                "Develops adjustable canter",
                "Essential skill for jumping courses",
                "Teaches feel for stride length",
                "Improves rider's eye for distances"
            ],
            tips: [
                "Start on the middle line until confident",
                "Count strides between poles to check consistency",
                "If horse rushes, use more half-halts"
            ],
            safetyNotes: [
                "Requires more space than trot fan",
                "Ensure good footing for canter work"
            ],
            requiredGaits: [.canter]
        ))

        // MARK: - Gymnastic Grids

        exercises.append(PoleworkExercise(
            name: "Trot to Cross-Pole",
            description: "A placing pole to a small cross-pole, teaching the horse to find the distance.",
            difficulty: .intermediate,
            category: .grids,
            exerciseType: .trotPoles,
            numberOfPoles: 2,
            arrangement: .straight,
            instructions: [
                "Set a trot placing pole one trot stride before a low cross-pole (40-50cm)",
                "Distance: approximately 2.4-2.7m depending on horse",
                "Approach in balanced trot",
                "Keep leg on but don't chase to the fence",
                "Allow horse to work out the distance"
            ],
            benefits: [
                "Teaches horse to judge distances",
                "Builds jumping confidence",
                "Develops consistent approach",
                "Foundation for grid work"
            ],
            tips: [
                "The cross-pole encourages jumping in the middle",
                "Keep fences small while learning",
                "Quality of approach matters more than fence height"
            ],
            safetyNotes: [
                "Cross-poles should be low (40-50cm)",
                "Use proper jump cups with pins",
                "Have ground poles as wings"
            ],
            requiredGaits: [.trot],
            isGrid: true,
            gridElements: [.pole, .fence]
        ))

        exercises.append(PoleworkExercise(
            name: "Bounce Grid",
            description: "Two small fences with no stride between - the horse lands and takes off immediately.",
            difficulty: .advanced,
            category: .grids,
            exerciseType: .bounce,
            numberOfPoles: 2,
            arrangement: .straight,
            instructions: [
                "Set two small cross-poles at bounce distance (no stride)",
                "Typical distance: 3.0-3.6m depending on horse size",
                "Approach in balanced canter or forward trot",
                "Keep leg on for impulsion",
                "Horse should land and immediately take off"
            ],
            benefits: [
                "Develops quick reflexes and athleticism",
                "Improves bascule (roundness over fences)",
                "Strengthens hindquarters",
                "Excellent gymnastic exercise"
            ],
            tips: [
                "Distance is critical - adjust if horse struggles",
                "Start from trot for green horses",
                "Keep fences small (50-60cm max)"
            ],
            safetyNotes: [
                "Only for horses comfortable with single fences",
                "Fences must have proper breakaway cups",
                "Don't attempt if horse is tired"
            ],
            requiredGaits: [.trot, .canter],
            isGrid: true,
            gridElements: [.fence, .bounce, .fence]
        ))

        exercises.append(PoleworkExercise(
            name: "One Stride Combination",
            description: "Two fences with one canter stride between - develops judgement and rhythm.",
            difficulty: .advanced,
            category: .grids,
            exerciseType: .oneStride,
            numberOfPoles: 2,
            arrangement: .straight,
            instructions: [
                "Set two fences at one stride distance (approximately 7.3m for average horse)",
                "Approach in balanced canter",
                "Land, take one canter stride, take off",
                "Maintain rhythm - don't chase or check",
                "Look up and ahead after landing"
            ],
            benefits: [
                "Essential skill for show jumping",
                "Develops feel for related distances",
                "Teaches horse to wait within combinations",
                "Improves canter quality"
            ],
            tips: [
                "A short one stride tests collection",
                "A long one stride tests extension",
                "Start with placing pole to first fence"
            ],
            safetyNotes: [
                "Ensure distances are accurate for your horse",
                "Use ground lines on both fences",
                "Have helper adjust if distance is wrong"
            ],
            requiredGaits: [.canter],
            isGrid: true,
            gridElements: [.fence, .oneStride, .fence]
        ))

        exercises.append(PoleworkExercise(
            name: "Trot In Grid",
            description: "Complete gymnastic: placing pole, cross-pole, bounce, one stride, oxer.",
            difficulty: .advanced,
            category: .grids,
            exerciseType: .grid,
            numberOfPoles: 5,
            arrangement: .straight,
            instructions: [
                "Set up: Placing pole → Cross-pole → Bounce → Cross-pole → One stride → Oxer",
                "All fences start small (50-60cm)",
                "Approach in balanced trot",
                "Keep leg on throughout",
                "Allow horse to find their rhythm"
            ],
            benefits: [
                "Complete gymnastic workout",
                "Develops strength, technique, and confidence",
                "Teaches horse to think through combinations",
                "Excellent preparation for courses"
            ],
            tips: [
                "Build one element at a time",
                "Only raise height when technique is confirmed",
                "Can remove elements if horse is struggling"
            ],
            safetyNotes: [
                "Advanced exercise - only for experienced combinations",
                "Have helper to adjust distances",
                "Stop if horse is tired or confused"
            ],
            requiredGaits: [.trot],
            isGrid: true,
            gridElements: [.pole, .fence, .bounce, .fence, .oneStride, .fence]
        ))

        // MARK: - Conditioning

        exercises.append(PoleworkExercise(
            name: "Pole Circuit",
            description: "A circuit of pole exercises around the arena for cardiovascular conditioning.",
            difficulty: .intermediate,
            category: .conditioning,
            exerciseType: .trotPoles,
            numberOfPoles: 12,
            arrangement: .straight,
            instructions: [
                "Set up 3 sets of 4 trot poles around the arena",
                "Ride a figure-of-eight or circuit pattern",
                "Maintain trot throughout",
                "Rest periods in walk between circuits",
                "Aim for 5-10 minutes of continuous work"
            ],
            benefits: [
                "Builds cardiovascular fitness",
                "Improves stamina and endurance",
                "Develops consistent rhythm under fatigue",
                "More interesting than endless circles"
            ],
            tips: [
                "Monitor horse's breathing",
                "Include walk breaks as needed",
                "Build duration gradually over weeks"
            ],
            safetyNotes: [
                "Ensure good footing throughout",
                "Watch for signs of fatigue",
                "Don't overwork - build up gradually"
            ],
            requiredGaits: [.walk, .trot]
        ))

        exercises.append(PoleworkExercise(
            name: "Raised Pole Workout",
            description: "Alternating raised poles at trot for strength and conditioning.",
            difficulty: .intermediate,
            category: .conditioning,
            exerciseType: .raisedTrotPoles,
            numberOfPoles: 6,
            isRaised: true,
            raiseHeightCm: 20,
            arrangement: .straight,
            instructions: [
                "Set 6 raised trot poles",
                "Work through in trot",
                "Rest in walk",
                "Repeat 4-6 times per session",
                "Focus on quality of movement"
            ],
            benefits: [
                "Strengthens hindquarters and core",
                "Develops carrying power",
                "Improves topline",
                "Effective conditioning without high impact"
            ],
            tips: [
                "Start with 2-3 repetitions",
                "Increase over several sessions",
                "Watch for dragging of hind feet (sign of tiredness)"
            ],
            safetyNotes: [
                "Do not overwork",
                "Maximum 10-15 minutes total",
                "Reduce height if horse struggles"
            ],
            requiredGaits: [.trot]
        ))

        exercises.append(PoleworkExercise(
            name: "Walk-Trot Pole Transitions",
            description: "Walking poles transitioning immediately to trotting poles for engagement.",
            difficulty: .beginner,
            category: .conditioning,
            exerciseType: .walkPoles,
            numberOfPoles: 8,
            arrangement: .straight,
            instructions: [
                "Set 4 walk poles, gap of 3m, then 4 trot poles",
                "Walk through walk poles, transition to trot",
                "Trot through trot poles",
                "Circle and approach again",
                "Focus on smooth, immediate transition"
            ],
            benefits: [
                "Improves transitions",
                "Develops responsiveness to aids",
                "Builds engagement through gait changes",
                "Good warm-up exercise"
            ],
            tips: [
                "The transition should happen in the gap",
                "Keep the horse's attention with your aids",
                "Can reverse: trot poles to walk poles"
            ],
            safetyNotes: [
                "Ensure clear gap between pole sets",
                "Mark the transition point clearly"
            ],
            requiredGaits: [.walk, .trot]
        ))

        return exercises
    }
}
