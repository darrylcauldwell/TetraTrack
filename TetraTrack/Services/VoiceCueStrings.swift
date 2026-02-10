//
//  VoiceCueStrings.swift
//  TetraTrack
//
//  Localized voice cue strings for audio coaching in English, German, and French
//

import Foundation

// MARK: - Voice Cue Keys

/// All voice cue keys used throughout the app
enum VoiceCueKey: String {
    // MARK: - Session
    case rideStarted = "ride_started"
    case rideComplete = "ride_complete"
    case runComplete = "run_complete"
    case swimmingStarted = "swimming_started"
    case swimmingComplete = "swimming_complete"
    case workoutComplete = "workout_complete"

    // MARK: - Gaits
    case walking = "walking"
    case trotting = "trotting"
    case cantering = "cantering"
    case galloping = "galloping"

    // MARK: - Distance
    case oneKilometre = "one_kilometre"
    case kilometres = "kilometres"
    case metres = "metres"

    // MARK: - Time
    case oneMinute = "one_minute"
    case minutes = "minutes"
    case hours = "hours"
    case seconds = "seconds"
    case secondsRemaining = "seconds_remaining"

    // MARK: - Heart Rate Zones
    case heartRateZone1 = "hr_zone_1"
    case heartRateZone2 = "hr_zone_2"
    case heartRateZone3 = "hr_zone_3"
    case heartRateZone4 = "hr_zone_4"
    case heartRateZone5 = "hr_zone_5"

    // MARK: - Safety
    case statusCheck = "status_check"
    case trackingActive = "tracking_active"
    case fallDetectionOn = "fall_detection_on"
    case allSystemsNormal = "all_systems_normal"

    // MARK: - Running Form
    case shortenStride = "shorten_stride"
    case focusOnCore = "focus_on_core"
    case weightOverCentre = "weight_over_centre"
    case highKnees = "high_knees"
    case lightFeet = "light_feet"
    case relaxShoulders = "relax_shoulders"
    case armsAt90 = "arms_at_90"
    case lookAhead = "look_ahead"
    case breatheRhythmically = "breathe_rhythmically"
    case quickTurnover = "quick_turnover"

    // MARK: - Running Feedback
    case currentPace = "current_pace"
    case lap = "lap"
    case fasterThan = "faster_than"
    case slowerThan = "slower_than"
    case evenPace = "even_pace"
    case fastestLap = "fastest_lap"
    case secondsAhead = "seconds_ahead"
    case secondsBehind = "seconds_behind"
    case metresAhead = "metres_ahead"
    case metresBehind = "metres_behind"
    case onTarget = "on_target"
    case averagePace = "average_pace"
    case toGo = "to_go"
    case targetPace = "target_pace"
    case restFor = "rest_for"

    // MARK: - Running Cadence
    case cadence = "cadence"
    case stepsPerMinute = "steps_per_minute"
    case goodRhythm = "good_rhythm"
    case tryShorterSteps = "try_shorter_steps"
    case slightlyHigh = "slightly_high"
    case increaseCadence = "increase_cadence"
    case slowCadence = "slow_cadence"

    // MARK: - Running Biomechanics
    case rightSideDominant = "right_side_dominant"
    case leftSideDominant = "left_side_dominant"
    case balanceStride = "balance_stride"
    case coreRotationDetected = "core_rotation_detected"
    case engageCore = "engage_core"
    case tooMuchBounce = "too_much_bounce"
    case runSmoother = "run_smoother"
    case unevenRhythm = "uneven_rhythm"
    case consistentFootStrikes = "consistent_foot_strikes"

    // MARK: - PB Racing
    case racingPB = "racing_pb"
    case goodLuck = "good_luck"
    case onPBPace = "on_pb_pace"
    case aheadExcellent = "ahead_excellent"
    case behindPushHarder = "behind_push_harder"
    case behindPickItUp = "behind_pick_it_up"
    case behindStayWithIt = "behind_stay_with_it"
    case finalPush = "final_push"
    case halfwayThere = "halfway_there"
    case newPB = "new_pb"
    case congratulations = "congratulations"
    case matchedPB = "matched_pb"
    case greatConsistency = "great_consistency"
    case goodEffort = "good_effort"

    // MARK: - Cross-Country
    case minuteApproaching = "minute_approaching"
    case timeFaultWarning = "time_fault_warning"
    case secondsSlow = "seconds_slow"
    case secondsFast = "seconds_fast"
    case slowDown = "slow_down"
    case speedingPenaltyRisk = "speeding_penalty_risk"
    case optimumTime = "optimum_time"
    case overOptimumTime = "over_optimum_time"
    case underOptimumTime = "under_optimum_time"

    // MARK: - Riding Biomechanics
    case asymmetryDetected = "asymmetry_detected"
    case checkPosition = "check_position"
    case slightImbalance = "slight_imbalance"
    case centreWeight = "centre_weight"
    case rhythmIrregular = "rhythm_irregular"
    case steadyPace = "steady_pace"
    case evenTempo = "even_tempo"
    case leaningLeft = "leaning_left"
    case leaningRight = "leaning_right"
    case smoothTransition = "smooth_transition"
    case wellDone = "well_done"
    case abruptTransition = "abrupt_transition"
    case prepareEarlier = "prepare_earlier"
    case useHalfHalts = "use_half_halts"

    // MARK: - Shooting
    case unstable = "unstable"
    case resetStance = "reset_stance"
    case steady = "steady"
    case controlBreathing = "control_breathing"
    case excellentStability = "excellent_stability"
    case holdAndShoot = "hold_and_shoot"
    case starting = "starting"
    case getReady = "get_ready"
    case excellent = "excellent"
    case score = "score"
    case outOf = "out_of"
    case percent = "percent"
    case goodShooting = "good_shooting"
    case keepPracticing = "keep_practicing"
    case breatheIn = "breathe_in"
    case hold = "hold"
    case squeeze = "squeeze"

    // MARK: - Swimming
    case lengths = "lengths"
    case averagePacePer100 = "average_pace_per_100"

    // MARK: - Encouragement
    case goodForm = "good_form"
    case keepItUp = "keep_it_up"
    case lookingStrong = "looking_strong"
    case stayRelaxed = "stay_relaxed"
    case niceRhythm = "nice_rhythm"
    case maintainPace = "maintain_pace"
    case greatRunning = "great_running"
    case stayFocused = "stay_focused"
    case excellentTechnique = "excellent_technique"
    case keepGoing = "keep_going"

    // MARK: - General
    case go = "go"
    case for_ = "for"
    case in_ = "in"
    case at = "at"
    case and = "and"
    case per = "per"
    case target = "target"
    case finished = "finished"
    case complete = "complete"
}

// MARK: - Voice Cue Strings

/// Provides localized voice cue strings for all supported languages
struct VoiceCueStrings {

    /// Get localized string for a voice cue key
    static func string(for key: VoiceCueKey, language: CoachLanguage) -> String {
        switch language {
        case .english:
            return englishStrings[key] ?? key.rawValue
        case .german:
            return germanStrings[key] ?? englishStrings[key] ?? key.rawValue
        case .french:
            return frenchStrings[key] ?? englishStrings[key] ?? key.rawValue
        }
    }

    // MARK: - English Strings

    private static let englishStrings: [VoiceCueKey: String] = [
        // Session
        .rideStarted: "Ride started. Have a great ride!",
        .rideComplete: "Ride complete",
        .runComplete: "Run complete",
        .swimmingStarted: "Swimming session started",
        .swimmingComplete: "Swimming complete",
        .workoutComplete: "Workout complete. Great job!",

        // Gaits
        .walking: "Walking",
        .trotting: "Trotting",
        .cantering: "Cantering",
        .galloping: "Galloping",

        // Distance
        .oneKilometre: "One kilometre",
        .kilometres: "kilometres",
        .metres: "metres",

        // Time
        .oneMinute: "One minute",
        .minutes: "minutes",
        .hours: "hours",
        .seconds: "seconds",
        .secondsRemaining: "seconds remaining",

        // Heart Rate Zones
        .heartRateZone1: "Heart rate zone 1. Recovery",
        .heartRateZone2: "Heart rate zone 2. Endurance",
        .heartRateZone3: "Heart rate zone 3. Tempo",
        .heartRateZone4: "Heart rate zone 4. Threshold",
        .heartRateZone5: "Heart rate zone 5. Maximum",

        // Safety
        .statusCheck: "Status check",
        .trackingActive: "Tracking active",
        .fallDetectionOn: "Fall detection on",
        .allSystemsNormal: "All systems normal",

        // Running Form
        .shortenStride: "Shorten your stride",
        .focusOnCore: "Focus on your core",
        .weightOverCentre: "Weight over centre of gravity",
        .highKnees: "High knees",
        .lightFeet: "Light feet",
        .relaxShoulders: "Relax your shoulders",
        .armsAt90: "Arms at ninety degrees",
        .lookAhead: "Look ahead, not down",
        .breatheRhythmically: "Breathe rhythmically",
        .quickTurnover: "Quick foot turnover",

        // Running Feedback
        .currentPace: "Current pace",
        .lap: "Lap",
        .fasterThan: "faster",
        .slowerThan: "slower",
        .evenPace: "Even pace",
        .fastestLap: "Fastest lap!",
        .secondsAhead: "seconds ahead",
        .secondsBehind: "seconds behind",
        .metresAhead: "metres ahead",
        .metresBehind: "metres behind",
        .onTarget: "On target",
        .averagePace: "Average pace",
        .toGo: "to go",
        .targetPace: "Target pace",
        .restFor: "Rest for",

        // Running Cadence
        .cadence: "Cadence",
        .stepsPerMinute: "steps per minute",
        .goodRhythm: "Good rhythm",
        .tryShorterSteps: "Try shorter, quicker steps",
        .slightlyHigh: "Slightly high",
        .increaseCadence: "Try to increase your step rate",
        .slowCadence: "You can slow your step rate",

        // Running Biomechanics
        .rightSideDominant: "Right-side dominant",
        .leftSideDominant: "Left-side dominant",
        .balanceStride: "Balance your stride",
        .coreRotationDetected: "Core rotation detected",
        .engageCore: "Engage your core and run tall",
        .tooMuchBounce: "Too much vertical bounce",
        .runSmoother: "Run smoother, push forward not up",
        .unevenRhythm: "Uneven rhythm",
        .consistentFootStrikes: "Focus on consistent foot strikes",

        // PB Racing
        .racingPB: "Racing your personal best",
        .goodLuck: "Good luck!",
        .onPBPace: "On PB pace",
        .aheadExcellent: "Excellent!",
        .behindPushHarder: "Push harder!",
        .behindPickItUp: "Pick it up",
        .behindStayWithIt: "Stay with it",
        .finalPush: "Final push!",
        .halfwayThere: "Halfway there",
        .newPB: "New personal best",
        .congratulations: "Congratulations!",
        .matchedPB: "Matched your personal best",
        .greatConsistency: "Great consistency!",
        .goodEffort: "Good effort!",

        // Cross-Country
        .minuteApproaching: "approaching",
        .timeFaultWarning: "Time fault warning",
        .secondsSlow: "seconds slow",
        .secondsFast: "seconds fast",
        .slowDown: "Slow down",
        .speedingPenaltyRisk: "Speeding penalty risk",
        .optimumTime: "Finished within optimum time",
        .overOptimumTime: "seconds over optimum time",
        .underOptimumTime: "seconds under optimum time. Possible speeding penalty",

        // Riding Biomechanics
        .asymmetryDetected: "Significant asymmetry detected",
        .checkPosition: "Check your position and your horse's movement",
        .slightImbalance: "Slight left-right imbalance",
        .centreWeight: "Centre your weight",
        .rhythmIrregular: "Rhythm very irregular",
        .steadyPace: "Steady your pace and establish a consistent tempo",
        .evenTempo: "Focus on maintaining an even tempo",
        .leaningLeft: "Leaning left",
        .leaningRight: "Leaning right",
        .smoothTransition: "Smooth transition",
        .wellDone: "Well done",
        .abruptTransition: "Abrupt transition",
        .prepareEarlier: "Prepare earlier",
        .useHalfHalts: "and use half-halts",

        // Shooting
        .unstable: "Unstable",
        .resetStance: "Reset your stance",
        .steady: "Steady",
        .controlBreathing: "Control your breathing",
        .excellentStability: "Excellent stability",
        .holdAndShoot: "Hold and shoot",
        .starting: "Starting",
        .getReady: "Get ready",
        .excellent: "Excellent!",
        .score: "Score",
        .outOf: "out of",
        .percent: "percent",
        .goodShooting: "Good shooting",
        .keepPracticing: "Keep practicing",
        .breatheIn: "Breathe in",
        .hold: "Hold",
        .squeeze: "Squeeze",

        // Swimming
        .lengths: "lengths",
        .averagePacePer100: "per 100",

        // Encouragement
        .goodForm: "Good form!",
        .keepItUp: "Keep it up",
        .lookingStrong: "Looking strong",
        .stayRelaxed: "Stay relaxed",
        .niceRhythm: "Nice rhythm",
        .maintainPace: "Maintain this pace",
        .greatRunning: "Great running",
        .stayFocused: "Stay focused",
        .excellentTechnique: "Excellent technique",
        .keepGoing: "Keep going",

        // General
        .go: "Go!",
        .for_: "for",
        .in_: "in",
        .at: "at",
        .and: "and",
        .per: "per",
        .target: "Target",
        .finished: "Finished",
        .complete: "complete",
    ]

    // MARK: - German Strings

    private static let germanStrings: [VoiceCueKey: String] = [
        // Session
        .rideStarted: "Ritt gestartet. Viel Spaß beim Reiten!",
        .rideComplete: "Ritt beendet",
        .runComplete: "Lauf beendet",
        .swimmingStarted: "Schwimmeinheit gestartet",
        .swimmingComplete: "Schwimmen beendet",
        .workoutComplete: "Training beendet. Gut gemacht!",

        // Gaits
        .walking: "Schritt",
        .trotting: "Trab",
        .cantering: "Galopp",
        .galloping: "Gestreckter Galopp",

        // Distance
        .oneKilometre: "Ein Kilometer",
        .kilometres: "Kilometer",
        .metres: "Meter",

        // Time
        .oneMinute: "Eine Minute",
        .minutes: "Minuten",
        .hours: "Stunden",
        .seconds: "Sekunden",
        .secondsRemaining: "Sekunden verbleibend",

        // Heart Rate Zones
        .heartRateZone1: "Herzfrequenzzone 1. Erholung",
        .heartRateZone2: "Herzfrequenzzone 2. Ausdauer",
        .heartRateZone3: "Herzfrequenzzone 3. Tempo",
        .heartRateZone4: "Herzfrequenzzone 4. Schwelle",
        .heartRateZone5: "Herzfrequenzzone 5. Maximum",

        // Safety
        .statusCheck: "Statusprüfung",
        .trackingActive: "Tracking aktiv",
        .fallDetectionOn: "Sturzerkennung aktiv",
        .allSystemsNormal: "Alle Systeme normal",

        // Running Form
        .shortenStride: "Verkürze deinen Schritt",
        .focusOnCore: "Konzentriere dich auf deine Körpermitte",
        .weightOverCentre: "Gewicht über dem Schwerpunkt",
        .highKnees: "Knie hoch",
        .lightFeet: "Leichte Füße",
        .relaxShoulders: "Entspanne deine Schultern",
        .armsAt90: "Arme im neunzig Grad Winkel",
        .lookAhead: "Schau nach vorne, nicht nach unten",
        .breatheRhythmically: "Atme rhythmisch",
        .quickTurnover: "Schneller Fußwechsel",

        // Running Feedback
        .currentPace: "Aktuelles Tempo",
        .lap: "Runde",
        .fasterThan: "schneller",
        .slowerThan: "langsamer",
        .evenPace: "Gleichmäßiges Tempo",
        .fastestLap: "Schnellste Runde!",
        .secondsAhead: "Sekunden voraus",
        .secondsBehind: "Sekunden zurück",
        .metresAhead: "Meter voraus",
        .metresBehind: "Meter zurück",
        .onTarget: "Im Ziel",
        .averagePace: "Durchschnittstempo",
        .toGo: "noch",
        .targetPace: "Zieltempo",
        .restFor: "Pause für",

        // Running Cadence
        .cadence: "Kadenz",
        .stepsPerMinute: "Schritte pro Minute",
        .goodRhythm: "Guter Rhythmus",
        .tryShorterSteps: "Versuche kürzere, schnellere Schritte",
        .slightlyHigh: "Etwas hoch",
        .increaseCadence: "Versuche deine Schrittfrequenz zu erhöhen",
        .slowCadence: "Du kannst deine Schrittfrequenz verlangsamen",

        // Running Biomechanics
        .rightSideDominant: "Rechtsseitig dominant",
        .leftSideDominant: "Linksseitig dominant",
        .balanceStride: "Balanciere deinen Schritt",
        .coreRotationDetected: "Rumpfrotation erkannt",
        .engageCore: "Spanne deine Körpermitte an und laufe aufrecht",
        .tooMuchBounce: "Zu viel vertikales Wippen",
        .runSmoother: "Laufe gleichmäßiger, schiebe nach vorne nicht nach oben",
        .unevenRhythm: "Ungleichmäßiger Rhythmus",
        .consistentFootStrikes: "Konzentriere dich auf gleichmäßige Fußaufsetzer",

        // PB Racing
        .racingPB: "Gegen deine persönliche Bestzeit",
        .goodLuck: "Viel Glück!",
        .onPBPace: "Im Bestzeit-Tempo",
        .aheadExcellent: "Ausgezeichnet!",
        .behindPushHarder: "Mehr Gas!",
        .behindPickItUp: "Tempo erhöhen",
        .behindStayWithIt: "Dranbleiben",
        .finalPush: "Endspurt!",
        .halfwayThere: "Halbzeit",
        .newPB: "Neue persönliche Bestzeit",
        .congratulations: "Herzlichen Glückwunsch!",
        .matchedPB: "Persönliche Bestzeit erreicht",
        .greatConsistency: "Tolle Konstanz!",
        .goodEffort: "Gute Leistung!",

        // Cross-Country
        .minuteApproaching: "kommt",
        .timeFaultWarning: "Zeitfehler-Warnung",
        .secondsSlow: "Sekunden zu langsam",
        .secondsFast: "Sekunden zu schnell",
        .slowDown: "Langsamer",
        .speedingPenaltyRisk: "Gefahr einer Geschwindigkeitsstrafe",
        .optimumTime: "Innerhalb der Optimalzeit beendet",
        .overOptimumTime: "Sekunden über Optimalzeit",
        .underOptimumTime: "Sekunden unter Optimalzeit. Mögliche Geschwindigkeitsstrafe",

        // Riding Biomechanics
        .asymmetryDetected: "Deutliche Asymmetrie erkannt",
        .checkPosition: "Überprüfe deine Position und die Bewegung deines Pferdes",
        .slightImbalance: "Leichte Links-Rechts-Ungleichheit",
        .centreWeight: "Zentriere dein Gewicht",
        .rhythmIrregular: "Rhythmus sehr unregelmäßig",
        .steadyPace: "Beruhige dein Tempo und etabliere ein gleichmäßiges Tempo",
        .evenTempo: "Konzentriere dich auf ein gleichmäßiges Tempo",
        .leaningLeft: "Neigung nach links",
        .leaningRight: "Neigung nach rechts",
        .smoothTransition: "Geschmeidiger Übergang",
        .wellDone: "Gut gemacht",
        .abruptTransition: "Abrupter Übergang",
        .prepareEarlier: "Bereite dich früher vor",
        .useHalfHalts: "und nutze halbe Paraden",

        // Shooting
        .unstable: "Instabil",
        .resetStance: "Setze deine Haltung zurück",
        .steady: "Ruhig",
        .controlBreathing: "Kontrolliere deine Atmung",
        .excellentStability: "Ausgezeichnete Stabilität",
        .holdAndShoot: "Halten und schießen",
        .starting: "Start",
        .getReady: "Mach dich bereit",
        .excellent: "Ausgezeichnet!",
        .score: "Punkte",
        .outOf: "von",
        .percent: "Prozent",
        .goodShooting: "Gut geschossen",
        .keepPracticing: "Weiter üben",
        .breatheIn: "Einatmen",
        .hold: "Halten",
        .squeeze: "Abziehen",

        // Swimming
        .lengths: "Bahnen",
        .averagePacePer100: "pro 100",

        // Encouragement
        .goodForm: "Gute Form!",
        .keepItUp: "Weiter so",
        .lookingStrong: "Du siehst stark aus",
        .stayRelaxed: "Bleib entspannt",
        .niceRhythm: "Schöner Rhythmus",
        .maintainPace: "Halte dieses Tempo",
        .greatRunning: "Tolles Laufen",
        .stayFocused: "Bleib konzentriert",
        .excellentTechnique: "Ausgezeichnete Technik",
        .keepGoing: "Weiter so",

        // General
        .go: "Los!",
        .for_: "für",
        .in_: "in",
        .at: "bei",
        .and: "und",
        .per: "pro",
        .target: "Ziel",
        .finished: "Beendet",
        .complete: "abgeschlossen",
    ]

    // MARK: - French Strings

    private static let frenchStrings: [VoiceCueKey: String] = [
        // Session
        .rideStarted: "Séance commencée. Bonne balade !",
        .rideComplete: "Balade terminée",
        .runComplete: "Course terminée",
        .swimmingStarted: "Séance de natation commencée",
        .swimmingComplete: "Natation terminée",
        .workoutComplete: "Entraînement terminé. Bravo !",

        // Gaits
        .walking: "Pas",
        .trotting: "Trot",
        .cantering: "Galop",
        .galloping: "Galop allongé",

        // Distance
        .oneKilometre: "Un kilomètre",
        .kilometres: "kilomètres",
        .metres: "mètres",

        // Time
        .oneMinute: "Une minute",
        .minutes: "minutes",
        .hours: "heures",
        .seconds: "secondes",
        .secondsRemaining: "secondes restantes",

        // Heart Rate Zones
        .heartRateZone1: "Zone cardiaque 1. Récupération",
        .heartRateZone2: "Zone cardiaque 2. Endurance",
        .heartRateZone3: "Zone cardiaque 3. Tempo",
        .heartRateZone4: "Zone cardiaque 4. Seuil",
        .heartRateZone5: "Zone cardiaque 5. Maximum",

        // Safety
        .statusCheck: "Vérification du statut",
        .trackingActive: "Suivi actif",
        .fallDetectionOn: "Détection de chute active",
        .allSystemsNormal: "Tous les systèmes normaux",

        // Running Form
        .shortenStride: "Raccourcis ta foulée",
        .focusOnCore: "Concentre-toi sur ton centre",
        .weightOverCentre: "Poids au-dessus du centre de gravité",
        .highKnees: "Genoux hauts",
        .lightFeet: "Pieds légers",
        .relaxShoulders: "Détends tes épaules",
        .armsAt90: "Bras à quatre-vingt-dix degrés",
        .lookAhead: "Regarde devant, pas en bas",
        .breatheRhythmically: "Respire de façon rythmée",
        .quickTurnover: "Rotation rapide des pieds",

        // Running Feedback
        .currentPace: "Allure actuelle",
        .lap: "Tour",
        .fasterThan: "plus rapide",
        .slowerThan: "plus lent",
        .evenPace: "Allure régulière",
        .fastestLap: "Tour le plus rapide !",
        .secondsAhead: "secondes d'avance",
        .secondsBehind: "secondes de retard",
        .metresAhead: "mètres d'avance",
        .metresBehind: "mètres de retard",
        .onTarget: "Dans les temps",
        .averagePace: "Allure moyenne",
        .toGo: "restant",
        .targetPace: "Allure cible",
        .restFor: "Repos de",

        // Running Cadence
        .cadence: "Cadence",
        .stepsPerMinute: "pas par minute",
        .goodRhythm: "Bon rythme",
        .tryShorterSteps: "Essaie des pas plus courts et rapides",
        .slightlyHigh: "Légèrement élevé",
        .increaseCadence: "Essaie d'augmenter ta cadence",
        .slowCadence: "Tu peux ralentir ta cadence",

        // Running Biomechanics
        .rightSideDominant: "Côté droit dominant",
        .leftSideDominant: "Côté gauche dominant",
        .balanceStride: "Équilibre ta foulée",
        .coreRotationDetected: "Rotation du tronc détectée",
        .engageCore: "Engage ton centre et cours droit",
        .tooMuchBounce: "Trop de rebond vertical",
        .runSmoother: "Cours plus fluide, pousse vers l'avant pas vers le haut",
        .unevenRhythm: "Rythme irrégulier",
        .consistentFootStrikes: "Concentre-toi sur des appuis réguliers",

        // PB Racing
        .racingPB: "Course contre ton record personnel",
        .goodLuck: "Bonne chance !",
        .onPBPace: "Dans l'allure du record",
        .aheadExcellent: "Excellent !",
        .behindPushHarder: "Pousse plus fort !",
        .behindPickItUp: "Accélère",
        .behindStayWithIt: "Tiens bon",
        .finalPush: "Dernier effort !",
        .halfwayThere: "À mi-chemin",
        .newPB: "Nouveau record personnel",
        .congratulations: "Félicitations !",
        .matchedPB: "Record personnel égalé",
        .greatConsistency: "Belle régularité !",
        .goodEffort: "Bel effort !",

        // Cross-Country
        .minuteApproaching: "approche",
        .timeFaultWarning: "Alerte faute de temps",
        .secondsSlow: "secondes trop lent",
        .secondsFast: "secondes trop rapide",
        .slowDown: "Ralentis",
        .speedingPenaltyRisk: "Risque de pénalité de vitesse",
        .optimumTime: "Terminé dans le temps optimal",
        .overOptimumTime: "secondes au-dessus du temps optimal",
        .underOptimumTime: "secondes en dessous du temps optimal. Possible pénalité de vitesse",

        // Riding Biomechanics
        .asymmetryDetected: "Asymétrie importante détectée",
        .checkPosition: "Vérifie ta position et le mouvement de ton cheval",
        .slightImbalance: "Léger déséquilibre gauche-droite",
        .centreWeight: "Centre ton poids",
        .rhythmIrregular: "Rythme très irrégulier",
        .steadyPace: "Stabilise ton allure et établis un tempo constant",
        .evenTempo: "Concentre-toi sur un tempo régulier",
        .leaningLeft: "Penché à gauche",
        .leaningRight: "Penché à droite",
        .smoothTransition: "Transition fluide",
        .wellDone: "Bien joué",
        .abruptTransition: "Transition brusque",
        .prepareEarlier: "Prépare plus tôt",
        .useHalfHalts: "et utilise des demi-arrêts",

        // Shooting
        .unstable: "Instable",
        .resetStance: "Reprends ta position",
        .steady: "Stable",
        .controlBreathing: "Contrôle ta respiration",
        .excellentStability: "Excellente stabilité",
        .holdAndShoot: "Maintiens et tire",
        .starting: "Début",
        .getReady: "Prépare-toi",
        .excellent: "Excellent !",
        .score: "Score",
        .outOf: "sur",
        .percent: "pourcent",
        .goodShooting: "Bon tir",
        .keepPracticing: "Continue à t'entraîner",
        .breatheIn: "Inspire",
        .hold: "Retiens",
        .squeeze: "Presse",

        // Swimming
        .lengths: "longueurs",
        .averagePacePer100: "aux 100",

        // Encouragement
        .goodForm: "Bonne forme !",
        .keepItUp: "Continue comme ça",
        .lookingStrong: "Tu as l'air fort",
        .stayRelaxed: "Reste détendu",
        .niceRhythm: "Bon rythme",
        .maintainPace: "Maintiens cette allure",
        .greatRunning: "Belle course",
        .stayFocused: "Reste concentré",
        .excellentTechnique: "Excellente technique",
        .keepGoing: "Continue",

        // General
        .go: "C'est parti !",
        .for_: "pour",
        .in_: "en",
        .at: "à",
        .and: "et",
        .per: "par",
        .target: "Objectif",
        .finished: "Terminé",
        .complete: "terminé",
    ]
}
