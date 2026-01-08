//
//  RunningScore.swift
//  TrackRide
//
//  Post-run subjective scoring with smart coaching suggestions
//

import Foundation
import SwiftData

@Model
final class RunningScore {
    var id: UUID = UUID()

    // Running form scores (1-5 scale)
    var runningForm: Int = 0         // Posture, arm swing, foot strike
    var cadenceConsistency: Int = 0  // Step turnover consistency
    var breathingControl: Int = 0    // Breathing rhythm and comfort
    var footStrike: Int = 0          // Landing pattern quality
    var armSwing: Int = 0            // Arm movement efficiency

    // Performance scores
    var paceControl: Int = 0         // Maintaining target pace/effort
    var hillTechnique: Int = 0       // Uphill and downhill form
    var splitConsistency: Int = 0    // Even km splits
    var finishStrength: Int = 0      // Ability to maintain/increase pace at end

    // Physical state
    var energyLevel: Int = 0         // Overall energy throughout
    var legFatigue: Int = 0          // 1=exhausted, 5=fresh
    var cardiovascularFeel: Int = 0  // Heart/breathing comfort

    // Mental state
    var mentalFocus: Int = 0         // Concentration and motivation
    var perceivedEffort: Int = 0     // RPE (1=very easy, 5=maximum)

    // Overall
    var overallFeeling: Int = 0      // General session satisfaction
    var terrainDifficulty: Int = 0   // Route challenge level
    var weatherImpact: Int = 0       // How weather affected the run

    // Notes
    var notes: String = ""
    var highlights: String = ""      // What went well
    var improvements: String = ""    // Areas to work on

    // Timestamp
    var scoredAt: Date = Date()

    // Relationship
    var session: RunningSession?

    init() {}

    // MARK: - Computed Properties

    /// Average of form scores
    var formAverage: Double {
        let scores = [runningForm, cadenceConsistency, breathingControl, footStrike, armSwing].filter { $0 > 0 }
        guard !scores.isEmpty else { return 0 }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    /// Average of performance scores
    var performanceAverage: Double {
        let scores = [paceControl, hillTechnique, splitConsistency, finishStrength].filter { $0 > 0 }
        guard !scores.isEmpty else { return 0 }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    /// Average of all non-zero scores
    var overallAverage: Double {
        let allScores = [
            runningForm, cadenceConsistency, breathingControl, footStrike, armSwing,
            paceControl, hillTechnique, splitConsistency, finishStrength,
            energyLevel, mentalFocus, overallFeeling
        ].filter { $0 > 0 }
        guard !allScores.isEmpty else { return 0 }
        return Double(allScores.reduce(0, +)) / Double(allScores.count)
    }

    /// Check if any scores have been entered
    var hasScores: Bool {
        [runningForm, cadenceConsistency, breathingControl, footStrike, armSwing,
         paceControl, hillTechnique, splitConsistency, finishStrength,
         energyLevel, legFatigue, cardiovascularFeel, mentalFocus, perceivedEffort,
         overallFeeling, terrainDifficulty, weatherImpact].contains { $0 > 0 }
    }

    // MARK: - Smart Coaching Suggestions

    /// Generate coaching suggestions based on scores
    var coachingSuggestions: [RunningCoachingSuggestion] {
        var suggestions: [RunningCoachingSuggestion] = []

        // Poor form with high fatigue → form drills needed
        if runningForm <= 2 && legFatigue <= 2 {
            suggestions.append(.init(
                title: "Focus on Running Form",
                message: "Poor form leads to inefficiency and fatigue. Practice high knees, butt kicks, and A-skips before runs to reinforce good mechanics.",
                icon: "figure.run",
                priority: .high
            ))
        }

        // Low cadence consistency → use metronome
        if cadenceConsistency <= 2 {
            suggestions.append(.init(
                title: "Work on Cadence",
                message: "Aim for 170-180 steps per minute. Use a metronome app during easy runs to build consistent turnover.",
                icon: "metronome.fill",
                priority: .medium
            ))
        }

        // Poor breathing → breathing exercises
        if breathingControl <= 2 && cardiovascularFeel <= 2 {
            suggestions.append(.init(
                title: "Improve Breathing Pattern",
                message: "Try rhythmic breathing: inhale for 3 steps, exhale for 2. This helps with oxygen delivery and reduces side stitches.",
                icon: "wind",
                priority: .high
            ))
        }

        // Poor pace control with good energy → pacing strategy
        if paceControl <= 2 && energyLevel >= 4 {
            suggestions.append(.init(
                title: "Develop Pacing Awareness",
                message: "Start runs slower than you think you need to. Use a GPS watch to check pace every km and resist going out too fast.",
                icon: "speedometer",
                priority: .medium
            ))
        }

        // Low finish strength → negative split training
        if finishStrength <= 2 && paceControl >= 3 {
            suggestions.append(.init(
                title: "Train for Strong Finishes",
                message: "Practice negative splits: run the second half faster than the first. Start with easy runs, then apply to tempo and long runs.",
                icon: "arrow.up.right",
                priority: .medium
            ))
        }

        // Poor hill technique → hill repeats
        if hillTechnique <= 2 {
            suggestions.append(.init(
                title: "Add Hill Training",
                message: "Include hill repeats weekly. Focus on short, quick steps uphill and controlled, quick turnover downhill.",
                icon: "mountain.2.fill",
                priority: .medium
            ))
        }

        // High perceived effort with low cardiovascular feel → aerobic base
        if perceivedEffort >= 4 && cardiovascularFeel <= 2 {
            suggestions.append(.init(
                title: "Build Aerobic Base",
                message: "You're working too hard. Add more easy runs at conversational pace to build your aerobic foundation.",
                icon: "heart.fill",
                priority: .high
            ))
        }

        // Low mental focus → mental training
        if mentalFocus <= 2 && overallFeeling >= 3 {
            suggestions.append(.init(
                title: "Mental Running Strategies",
                message: "Break runs into segments, use mantras, or focus on form cues. Practice mindfulness to stay present during runs.",
                icon: "brain.head.profile",
                priority: .low
            ))
        }

        // Poor arm swing → upper body work
        if armSwing <= 2 {
            suggestions.append(.init(
                title: "Improve Arm Mechanics",
                message: "Keep arms at 90 degrees, swing from shoulders (not elbows), hands relaxed. Add arm swing drills to warm-ups.",
                icon: "hand.raised.fill",
                priority: .low
            ))
        }

        // Good split consistency but poor finish → fuel/hydration
        if splitConsistency >= 4 && finishStrength <= 2 {
            suggestions.append(.init(
                title: "Check Fueling Strategy",
                message: "Fading at the end despite even pacing suggests nutrition/hydration issues. Fuel properly before and during long efforts.",
                icon: "drop.fill",
                priority: .medium
            ))
        }

        // Good scores overall → celebration
        if overallAverage >= 4 {
            suggestions.append(.init(
                title: "Excellent Run!",
                message: "Great session! Continue mixing easy runs with quality workouts. Consider increasing weekly mileage by 10% to build further.",
                icon: "star.fill",
                priority: .low
            ))
        }

        return suggestions.sorted { $0.priority.rawValue < $1.priority.rawValue }
    }
}

// MARK: - Running Score Categories

enum RunningScoreCategory: String, CaseIterable {
    case runningForm = "Running Form"
    case cadenceConsistency = "Cadence Consistency"
    case breathingControl = "Breathing Control"
    case footStrike = "Foot Strike"
    case armSwing = "Arm Swing"
    case paceControl = "Pace Control"
    case hillTechnique = "Hill Technique"
    case splitConsistency = "Split Consistency"
    case finishStrength = "Finish Strength"
    case energyLevel = "Energy Level"
    case legFatigue = "Leg Fatigue"
    case cardiovascularFeel = "Cardiovascular Feel"
    case mentalFocus = "Mental Focus"
    case perceivedEffort = "Perceived Effort"

    var icon: String {
        switch self {
        case .runningForm: return "figure.run"
        case .cadenceConsistency: return "metronome.fill"
        case .breathingControl: return "wind"
        case .footStrike: return "shoe.fill"
        case .armSwing: return "hand.raised.fill"
        case .paceControl: return "speedometer"
        case .hillTechnique: return "mountain.2.fill"
        case .splitConsistency: return "chart.bar.fill"
        case .finishStrength: return "arrow.up.right"
        case .energyLevel: return "battery.75percent"
        case .legFatigue: return "figure.walk"
        case .cardiovascularFeel: return "heart.fill"
        case .mentalFocus: return "brain.head.profile"
        case .perceivedEffort: return "gauge.with.dots.needle.67percent"
        }
    }

    var description: String {
        switch self {
        case .runningForm:
            return "Overall posture, alignment, and running mechanics"
        case .cadenceConsistency:
            return "Consistency of step turnover and rhythm"
        case .breathingControl:
            return "Breathing pattern comfort and efficiency"
        case .footStrike:
            return "Landing pattern quality and ground contact"
        case .armSwing:
            return "Arm movement efficiency and coordination"
        case .paceControl:
            return "Ability to maintain target pace or effort"
        case .hillTechnique:
            return "Form and efficiency on uphills and downhills"
        case .splitConsistency:
            return "How even your km splits were"
        case .finishStrength:
            return "Ability to maintain or increase pace at the end"
        case .energyLevel:
            return "Overall energy and stamina throughout"
        case .legFatigue:
            return "How tired your legs felt (1=exhausted, 5=fresh)"
        case .cardiovascularFeel:
            return "Heart rate and breathing comfort"
        case .mentalFocus:
            return "Concentration and motivation levels"
        case .perceivedEffort:
            return "How hard the run felt (1=very easy, 5=maximum)"
        }
    }
}

// MARK: - Coaching Suggestion

struct RunningCoachingSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let icon: String
    let priority: CoachingPriority

    enum CoachingPriority: Int {
        case high = 1
        case medium = 2
        case low = 3

        var color: String {
            switch self {
            case .high: return "red"
            case .medium: return "orange"
            case .low: return "green"
            }
        }
    }
}
