//
//  FlatworkExerciseData.swift
//  TrackRide
//
//  Pre-populated flatwork/dressage exercises for the exercise library
//

import Foundation

// MARK: - Flatwork Exercise Data Provider

struct FlatworkExerciseData {

    /// Creates all built-in flatwork exercises
    static func createBuiltInExercises() -> [FlatworkExercise] {
        var exercises: [FlatworkExercise] = []

        // MARK: - Circles & Curves

        exercises.append(FlatworkExercise(
            name: "20m Circle",
            description: "A large circle using half the arena width, fundamental for developing bend and balance.",
            difficulty: .beginner,
            category: .circles,
            instructions: [
                "At A or C, turn onto the circle",
                "Pass through X at the centre of the arena",
                "Maintain consistent bend throughout the horse's body",
                "Keep your inside leg at the girth, outside leg slightly behind",
                "Look where you're going, not at your horse",
                "Return to the track after one full circle"
            ],
            benefits: [
                "Develops correct bend through the horse's body",
                "Improves balance and rhythm",
                "Foundation for all lateral work",
                "Helps establish consistent contact"
            ],
            tips: [
                "Imagine you're sitting on the outside of the saddle",
                "Keep your shoulders aligned with your horse's shoulders",
                "The circle should be round, not egg-shaped",
                "Maintain the same rhythm throughout"
            ],
            requiredGaits: [.walk, .trot, .canter]
        ))

        exercises.append(FlatworkExercise(
            name: "15m Circle",
            description: "A medium-sized circle requiring more collection and balance than the 20m circle.",
            difficulty: .intermediate,
            category: .circles,
            instructions: [
                "Begin between the markers on the long side",
                "The circle should touch the track and pass 2.5m inside X",
                "Prepare with a half-halt before starting",
                "Maintain consistent bend and rhythm",
                "Use your inside leg to maintain impulsion",
                "Outside rein controls the size of the circle"
            ],
            benefits: [
                "Increases collection",
                "Improves bend through a tighter arc",
                "Prepares horse for smaller circles",
                "Develops engagement of the hindquarters"
            ],
            tips: [
                "Half-halt before you begin to prepare the horse",
                "Don't let the horse fall onto the inside shoulder",
                "Keep your weight slightly to the inside"
            ],
            requiredGaits: [.walk, .trot, .canter]
        ))

        exercises.append(FlatworkExercise(
            name: "10m Circle",
            description: "A small circle requiring good collection and balance, introducing pirouette-like movement.",
            difficulty: .advanced,
            category: .circles,
            instructions: [
                "Prepare with several half-halts before starting",
                "Begin at walk or collected trot initially",
                "Maintain forward energy despite the smaller circle",
                "Keep the horse upright, not leaning in",
                "Think of your inside leg as a post the horse bends around",
                "Outside leg prevents the quarters from swinging out"
            ],
            benefits: [
                "Develops collection and engagement",
                "Builds carrying power in the hindquarters",
                "Preparation for canter pirouettes",
                "Improves horse's ability to shorten stride while maintaining activity"
            ],
            tips: [
                "Only attempt in canter when horse is confirmed in collection",
                "If horse loses balance, return to a larger circle",
                "Focus on quality over quantity - a few good steps are better than many poor ones"
            ],
            requiredGaits: [.walk, .trot]
        ))

        // MARK: - School Figures

        exercises.append(FlatworkExercise(
            name: "Serpentine (3 loops)",
            description: "Three equal loops across the arena, teaching changes of bend and straightness on the centreline.",
            difficulty: .beginner,
            category: .figures,
            instructions: [
                "Start at A or C",
                "Make three equal loops touching each long side",
                "Cross the centre line at a right angle each time",
                "Change bend as you cross the centre line",
                "Straighten for 1-2 strides on the centre line before new bend",
                "Finish at the opposite end of the arena"
            ],
            benefits: [
                "Improves suppleness in both directions",
                "Teaches clean changes of bend",
                "Develops straightness when crossing centre line",
                "Encourages even rein contact"
            ],
            tips: [
                "Plan your loops before you start",
                "The change of bend should be smooth, not abrupt",
                "In canter, this becomes a simple change exercise"
            ],
            requiredGaits: [.walk, .trot, .canter]
        ))

        exercises.append(FlatworkExercise(
            name: "Figure of Eight",
            description: "Two circles of equal size joined at the centre, developing suppleness and changes of bend.",
            difficulty: .intermediate,
            category: .figures,
            instructions: [
                "Begin with a circle on one rein (left or right)",
                "At X (centre), straighten briefly for 1-2 strides",
                "Change bend and begin circle on opposite rein",
                "Both circles should be the same size (typically 20m)",
                "Return to X and repeat or continue on track"
            ],
            benefits: [
                "Improves suppleness equally on both reins",
                "Teaches clean changes of direction",
                "Develops feel for correct bend",
                "Preparation for flying changes"
            ],
            tips: [
                "The moment of straightness at X is crucial",
                "Make both circles exactly equal in size",
                "In canter, practise with simple changes first"
            ],
            requiredGaits: [.walk, .trot, .canter]
        ))

        exercises.append(FlatworkExercise(
            name: "Shallow Loop (5m)",
            description: "A gentle loop 5 metres from the track and back, introducing counter-flexion concepts.",
            difficulty: .beginner,
            category: .figures,
            instructions: [
                "Leave the track after a corner marker",
                "Loop 5m into the arena (to the quarter line)",
                "Return to the track before the next corner marker",
                "Maintain bend in the direction of travel",
                "Keep the same rhythm throughout"
            ],
            benefits: [
                "Introduces counter-flexion concepts",
                "Prepares horse for counter-canter",
                "Improves balance and control",
                "Tests straightness of the horse"
            ],
            tips: [
                "In canter, maintain the original lead for counter-canter practice",
                "Don't let the loop become too deep or too shallow",
                "Focus on maintaining the rhythm"
            ],
            requiredGaits: [.walk, .trot, .canter]
        ))

        exercises.append(FlatworkExercise(
            name: "Diagonals",
            description: "Riding across the arena from one corner to the opposite corner, changing rein.",
            difficulty: .beginner,
            category: .figures,
            instructions: [
                "After the corner at K, H, M, or F, turn onto the diagonal",
                "Aim for the marker at the opposite end (e.g., K to M)",
                "Straighten the horse as you cross X",
                "Change bend as you approach the new track",
                "Join the track after the letter"
            ],
            benefits: [
                "Changes the rein efficiently",
                "Develops straightness",
                "Allows for extended gaits across the diagonal",
                "Natural place for trot/canter transitions"
            ],
            tips: [
                "Look at the marker you're aiming for",
                "Use the diagonal for lengthening in trot or canter",
                "In rising trot, change your diagonal at X"
            ],
            requiredGaits: [.walk, .trot, .canter]
        ))

        // MARK: - Transitions

        exercises.append(FlatworkExercise(
            name: "Walk-Trot Transitions",
            description: "Smooth transitions between walk and trot, fundamental for developing responsiveness.",
            difficulty: .beginner,
            category: .transitions,
            instructions: [
                "Establish a good, active working walk",
                "Prepare with a half-halt",
                "Apply both legs together for upward transition",
                "Maintain contact - don't throw the reins away",
                "After 20 metres, prepare and transition back to walk",
                "Use your seat and core to ask for downward transition"
            ],
            benefits: [
                "Develops responsiveness to leg aids",
                "Improves balance through transitions",
                "Builds engagement of the hindquarters",
                "Foundation for all other transitions"
            ],
            tips: [
                "Think 'forward into the transition'",
                "The transition should be immediate but not explosive",
                "Quality of the gait after the transition matters most"
            ],
            requiredGaits: [.walk, .trot]
        ))

        exercises.append(FlatworkExercise(
            name: "Trot-Canter Transitions",
            description: "Developing smooth upward and downward transitions between trot and canter.",
            difficulty: .intermediate,
            category: .transitions,
            instructions: [
                "Establish a balanced working trot",
                "Position for the correct lead (inside flexion)",
                "Half-halt to rebalance",
                "Outside leg back, inside leg at girth",
                "After one circle, half-halt to trot",
                "Maintain rhythm in the trot after downward transition"
            ],
            benefits: [
                "Develops balance through gait changes",
                "Improves canter depart quality",
                "Builds responsiveness to the aids",
                "Prepares for more advanced movements"
            ],
            tips: [
                "Ask in a corner where the horse is already positioned correctly",
                "Don't let the horse run into canter - ask for a jump",
                "In downward transition, don't pull - use your seat"
            ],
            requiredGaits: [.trot, .canter]
        ))

        exercises.append(FlatworkExercise(
            name: "Progressive Transitions",
            description: "Moving through all three gaits in sequence: walk-trot-canter-trot-walk.",
            difficulty: .intermediate,
            category: .transitions,
            instructions: [
                "Begin in walk on a 20m circle",
                "Transition to trot for half the circle",
                "Transition to canter for one full circle",
                "Return to trot for half a circle",
                "Return to walk",
                "Each gait should be established before moving to the next"
            ],
            benefits: [
                "Develops obedience and throughness",
                "Improves self-carriage",
                "Tests rider's feel for correct timing",
                "Builds horse's understanding of the aids"
            ],
            tips: [
                "Don't rush through the gaits",
                "Quality in each gait is more important than speed of transitions",
                "The horse should stay round through all transitions"
            ],
            requiredGaits: [.walk, .trot, .canter]
        ))

        exercises.append(FlatworkExercise(
            name: "Direct Transitions (Walk-Canter)",
            description: "Transitions directly from walk to canter and back, requiring collection and engagement.",
            difficulty: .advanced,
            category: .transitions,
            instructions: [
                "Establish a collected, active walk",
                "Create energy in the walk without jogging",
                "Half-halt, position for the lead",
                "Apply the canter aid clearly",
                "Horse should step into canter without trot steps",
                "For downward, half-halt to walk without trot"
            ],
            benefits: [
                "Develops maximum collection",
                "Improves engagement of hindquarters",
                "Preparation for piaffe and passage",
                "Tests true acceptance of the aids"
            ],
            tips: [
                "The walk must be very active before the transition",
                "Think 'up and forward' not just 'forward'",
                "This requires significant hindquarter strength"
            ],
            requiredGaits: [.walk, .canter]
        ))

        // MARK: - Half-Halts & Collection

        exercises.append(FlatworkExercise(
            name: "Half-Halts",
            description: "Brief rebalancing aids that prepare the horse and improve self-carriage.",
            difficulty: .intermediate,
            category: .collection,
            instructions: [
                "Sit tall and engage your core",
                "Close your fingers on the reins briefly",
                "Apply a brief squeeze with both legs",
                "Release almost immediately",
                "Feel the horse shift weight to the hindquarters",
                "Repeat every few strides as needed"
            ],
            benefits: [
                "Rebalances the horse",
                "Prepares for transitions and movements",
                "Develops self-carriage",
                "Prevents horse from falling onto forehand"
            ],
            tips: [
                "The release is as important as the ask",
                "Think 'momentary pause' not 'pull back'",
                "The horse should feel more uphill after a half-halt"
            ],
            requiredGaits: [.walk, .trot, .canter]
        ))

        exercises.append(FlatworkExercise(
            name: "Collected/Extended Gaits",
            description: "Developing the range of stride length within each gait, from short to long.",
            difficulty: .advanced,
            category: .collection,
            instructions: [
                "Begin in working gait on a 20m circle",
                "Use half-halts to shorten the stride (collection)",
                "Maintain activity and elevation",
                "Across the diagonal, allow the stride to lengthen",
                "Keep the rhythm the same - only stride length changes",
                "Return to working gait before the corner"
            ],
            benefits: [
                "Develops full range of movement",
                "Builds carrying power",
                "Improves throughness",
                "Showcases the horse's athleticism"
            ],
            tips: [
                "Collection is not slow - it's short and elevated",
                "Extension is not fast - it's long and covering ground",
                "The rhythm should stay constant in both"
            ],
            requiredGaits: [.trot, .canter]
        ))

        exercises.append(FlatworkExercise(
            name: "Counter-Canter",
            description: "Cantering on the 'wrong' lead deliberately to develop balance and straightness.",
            difficulty: .advanced,
            category: .collection,
            instructions: [
                "Establish true canter on a 20m circle",
                "Ride a shallow loop (3-5m) maintaining the lead",
                "Keep the horse straight, slight flexion to the leading leg",
                "Use outside aids to maintain the lead",
                "Progress to changing rein through X while maintaining lead",
                "Eventually ride full 20m circles in counter-canter"
            ],
            benefits: [
                "Improves balance and collection",
                "Develops straightness in canter",
                "Strengthens the carrying capacity",
                "Preparation for flying changes"
            ],
            tips: [
                "Start with shallow loops before attempting full arena",
                "Keep the horse calm - tension will cause lead changes",
                "Slight flexion should always be toward the leading leg"
            ],
            requiredGaits: [.canter]
        ))

        // MARK: - Lateral Work

        exercises.append(FlatworkExercise(
            name: "Leg Yield",
            description: "Horse moves forward and sideways from the rider's leg pressure, basic lateral movement.",
            difficulty: .intermediate,
            category: .lateral,
            instructions: [
                "In walk or trot, position slight flexion away from direction of travel",
                "Apply inside leg at the girth",
                "Horse should step forward and sideways",
                "Outside leg and rein prevent too much sideways movement",
                "Aim for a 35-degree angle to the track",
                "Maintain forward momentum throughout"
            ],
            benefits: [
                "Teaches horse to move from the leg",
                "Improves suppleness and obedience",
                "Foundation for all lateral work",
                "Useful for opening and closing gates"
            ],
            tips: [
                "Think more forward than sideways",
                "The crossing of legs should be clear but not exaggerated",
                "If the horse rushes, use half-halts"
            ],
            requiredGaits: [.walk, .trot]
        ))

        exercises.append(FlatworkExercise(
            name: "Shoulder-In",
            description: "The horse is bent around the rider's inside leg, shoulders brought in from the track.",
            difficulty: .advanced,
            category: .lateral,
            instructions: [
                "Coming out of a corner, maintain the bend",
                "Bring the shoulders in so horse moves on three tracks",
                "Inside leg at girth maintains bend and impulsion",
                "Outside rein controls the degree of angle (about 30 degrees)",
                "Outside leg prevents quarters from swinging out",
                "Look down the long side, not at the shoulder"
            ],
            benefits: [
                "Called 'the mother of all exercises'",
                "Develops collection and engagement",
                "Improves straightness paradoxically through bend",
                "Supples the shoulders and ribcage"
            ],
            tips: [
                "Start with a few steps, gradually increase",
                "Think of riding the inside hind toward the outside shoulder",
                "The bend should be through the whole body, not just neck"
            ],
            requiredGaits: [.walk, .trot]
        ))

        exercises.append(FlatworkExercise(
            name: "Turn on the Forehand",
            description: "The horse's hindquarters move around the forehand, teaching response to lateral leg aids.",
            difficulty: .beginner,
            category: .lateral,
            instructions: [
                "Halt on the track, parallel to the fence",
                "Position slight flexion in direction of turn",
                "Inside leg behind the girth pushes quarters over",
                "Front legs step small circle, hinds step larger circle",
                "Keep slight forward tendency",
                "Complete a quarter or half turn"
            ],
            benefits: [
                "Teaches response to lateral leg aids",
                "Good introduction to lateral work",
                "Useful for opening gates",
                "Develops coordination of the aids"
            ],
            tips: [
                "Don't let the horse step backward",
                "One step at a time - don't rush",
                "Keep light contact to prevent forward movement"
            ],
            requiredGaits: [.walk]
        ))

        exercises.append(FlatworkExercise(
            name: "Turn on the Haunches",
            description: "The horse's forehand moves around the hindquarters, developing collection and control.",
            difficulty: .advanced,
            category: .lateral,
            instructions: [
                "Establish collected walk",
                "Half-halt to engage hindquarters",
                "Inside leg at girth maintains bend and impulsion",
                "Outside leg behind girth prevents quarters from swinging",
                "Outside rein brings shoulders around",
                "Hind legs should mark time on the spot or small circle"
            ],
            benefits: [
                "Develops collection and carrying power",
                "Preparation for canter pirouettes",
                "Improves response to the outside rein",
                "Tests true engagement of hindquarters"
            ],
            tips: [
                "Maintain the walk rhythm - hind legs must keep moving",
                "Start with quarter turns before attempting half or full",
                "If the horse steps backward, add more leg"
            ],
            requiredGaits: [.walk]
        ))

        exercises.append(FlatworkExercise(
            name: "Haunches-In (Travers)",
            description: "The horse's hindquarters are brought in from the track, moving on four tracks.",
            difficulty: .advanced,
            category: .lateral,
            instructions: [
                "Coming out of a corner, keep the bend",
                "Bring the quarters in from the track",
                "Inside leg at girth maintains impulsion",
                "Outside leg behind girth positions the quarters",
                "Horse looks in the direction of travel",
                "Shoulders stay on the track"
            ],
            benefits: [
                "Develops engagement of the inside hind",
                "Preparation for half-pass",
                "Improves suppleness of the quarters",
                "Teaches horse to carry weight on inside hind"
            ],
            tips: [
                "The angle should be about 30 degrees",
                "Don't let the shoulders drift off the track",
                "This is harder than shoulder-in - ensure that is confirmed first"
            ],
            requiredGaits: [.walk, .trot, .canter]
        ))

        // MARK: - Suppleness

        exercises.append(FlatworkExercise(
            name: "Stretching on a Long Rein",
            description: "Allowing the horse to stretch forward and down while maintaining contact and rhythm.",
            difficulty: .beginner,
            category: .suppleness,
            instructions: [
                "In working trot on a 20m circle",
                "Gradually allow the reins to slip through your fingers",
                "Horse should follow the contact down and forward",
                "Maintain leg to keep forward movement",
                "Horse's nose should reach toward the ground",
                "Gather the reins again gradually"
            ],
            benefits: [
                "Tests and develops true connection",
                "Rewards the horse for working correctly",
                "Stretches and relaxes the topline",
                "Proves the horse is working through the back"
            ],
            tips: [
                "The horse should seek the contact down, not drop it",
                "Maintain the same rhythm and circle size",
                "This is often called 'chewing the reins out of the hand'"
            ],
            requiredGaits: [.walk, .trot]
        ))

        exercises.append(FlatworkExercise(
            name: "Spiral In and Out",
            description: "Gradually decreasing then increasing circle size to develop bend and balance.",
            difficulty: .intermediate,
            category: .suppleness,
            instructions: [
                "Begin on a 20m circle in trot or canter",
                "Gradually spiral in using inside leg",
                "Decrease to 15m, then 10m circle",
                "At smallest circle, use outside leg to spiral out",
                "Return to 20m circle",
                "Maintain rhythm and bend throughout"
            ],
            benefits: [
                "Develops adjustability of stride",
                "Improves response to inside and outside leg",
                "Tests and develops balance",
                "Increases engagement as circles get smaller"
            ],
            tips: [
                "Don't rush the spiral - take several circles at each size",
                "Inside leg pushes out, outside leg brings in",
                "Keep the same rhythm - only the bend changes"
            ],
            requiredGaits: [.trot, .canter]
        ))

        exercises.append(FlatworkExercise(
            name: "Change of Bend through Circle",
            description: "Changing the flexion and bend within a figure, developing suppleness equally both ways.",
            difficulty: .intermediate,
            category: .suppleness,
            instructions: [
                "Begin on a 20m circle with correct inside bend",
                "At a specific point, change to outside bend (counter-bend)",
                "Maintain the circle shape while flexed the wrong way",
                "After half a circle, return to correct bend",
                "This tests independent bend from direction"
            ],
            benefits: [
                "Supples the horse equally both ways",
                "Develops independent aids",
                "Prevents horse from leaning on one rein",
                "Prepares for more advanced movements"
            ],
            tips: [
                "Keep the circle the same size despite the bend change",
                "The change should be smooth, not sudden",
                "This is advanced - only attempt when basic bend is confirmed"
            ],
            requiredGaits: [.walk, .trot]
        ))

        // MARK: - Straightness

        exercises.append(FlatworkExercise(
            name: "Centre Line",
            description: "Riding down the centre of the arena to develop straightness and balance.",
            difficulty: .beginner,
            category: .straightness,
            instructions: [
                "At A, turn onto the centre line",
                "Keep the horse straight between both reins and both legs",
                "Look at C - your body follows your eyes",
                "Maintain equal contact on both reins",
                "At C, turn left or right onto the track"
            ],
            benefits: [
                "Develops true straightness",
                "Tests even rein contact",
                "Important for dressage tests",
                "Reveals any crookedness in the horse"
            ],
            tips: [
                "Have someone watch to tell you if you're drifting",
                "Think of riding between two walls",
                "The turn onto centre line is a half 10m circle"
            ],
            requiredGaits: [.walk, .trot, .canter]
        ))

        exercises.append(FlatworkExercise(
            name: "Quarter Lines",
            description: "Riding on the lines between the track and centre line to develop independence from the rail.",
            difficulty: .intermediate,
            category: .straightness,
            instructions: [
                "Turn onto the quarter line (between E/B and the track)",
                "Maintain straightness without the wall to guide you",
                "Keep even contact on both reins",
                "The horse should not drift toward the track",
                "Rejoin the track at the end of the long side"
            ],
            benefits: [
                "Develops true straightness away from the wall",
                "Tests rider's ability to guide with seat and legs",
                "Reveals horse's tendency to lean on the track",
                "Preparation for movements requiring independence"
            ],
            tips: [
                "If the horse drifts, use the appropriate leg to correct",
                "Don't over-correct - small adjustments only",
                "This is harder than it looks!"
            ],
            requiredGaits: [.walk, .trot, .canter]
        ))

        return exercises
    }
}
