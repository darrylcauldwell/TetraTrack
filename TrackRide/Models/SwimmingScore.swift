//
//  SwimmingScore.swift
//  TrackRide
//
//  Post-swim subjective scoring with smart coaching suggestions
//

import Foundation
import SwiftData

@Model
final class SwimmingScore {
    var id: UUID = UUID()

    // Technique scores (1-5 scale)
    var strokeEfficiency: Int = 0    // Smoothness and power of strokes
    var bodyPosition: Int = 0        // Horizontal position in water
    var breathingRhythm: Int = 0     // Consistency of breathing pattern
    var turnQuality: Int = 0         // Flip turns and wall push-offs
    var kickEfficiency: Int = 0      // Leg kick power and rhythm

    // Performance scores
    var paceControl: Int = 0         // Maintaining target pace
    var splitConsistency: Int = 0    // Even splits across laps
    var intervalAdherence: Int = 0   // Hit interval targets

    // Physical state
    var enduranceFeel: Int = 0       // Energy levels throughout
    var armFatigue: Int = 0          // 1=exhausted, 5=fresh
    var legFatigue: Int = 0          // 1=exhausted, 5=fresh

    // Overall
    var overallFeeling: Int = 0      // General session satisfaction
    var poolConditions: Int = 0      // Water temp, lane availability, etc.

    // Notes
    var notes: String = ""
    var highlights: String = ""      // What went well
    var improvements: String = ""    // Areas to work on

    // Timestamp
    var scoredAt: Date = Date()

    // Relationship
    var session: SwimmingSession?

    init() {}

    // MARK: - Computed Properties

    /// Average of technique scores
    var techniqueAverage: Double {
        let scores = [strokeEfficiency, bodyPosition, breathingRhythm, turnQuality, kickEfficiency].filter { $0 > 0 }
        guard !scores.isEmpty else { return 0 }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    /// Average of performance scores
    var performanceAverage: Double {
        let scores = [paceControl, splitConsistency, intervalAdherence].filter { $0 > 0 }
        guard !scores.isEmpty else { return 0 }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    /// Average of all non-zero scores
    var overallAverage: Double {
        let allScores = [
            strokeEfficiency, bodyPosition, breathingRhythm, turnQuality, kickEfficiency,
            paceControl, splitConsistency, intervalAdherence,
            enduranceFeel, overallFeeling
        ].filter { $0 > 0 }
        guard !allScores.isEmpty else { return 0 }
        return Double(allScores.reduce(0, +)) / Double(allScores.count)
    }

    /// Check if any scores have been entered
    var hasScores: Bool {
        [strokeEfficiency, bodyPosition, breathingRhythm, turnQuality, kickEfficiency,
         paceControl, splitConsistency, intervalAdherence,
         enduranceFeel, armFatigue, legFatigue, overallFeeling, poolConditions].contains { $0 > 0 }
    }

    // MARK: - Smart Coaching Suggestions

    /// Generate coaching suggestions based on scores
    var coachingSuggestions: [SwimmingCoachingSuggestion] {
        var suggestions: [SwimmingCoachingSuggestion] = []

        // Low stroke efficiency with low body position → focus on streamline
        if strokeEfficiency <= 2 && bodyPosition <= 2 {
            suggestions.append(.init(
                title: "Focus on Streamline Position",
                message: "Low stroke efficiency often starts with body position. Practice streamline glides off the wall and keep your head neutral to improve both.",
                icon: "figure.pool.swim",
                priority: .high
            ))
        }

        // Poor breathing rhythm → add breathing drills
        if breathingRhythm <= 2 {
            suggestions.append(.init(
                title: "Breathing Drills Needed",
                message: "Work on bilateral breathing (every 3 strokes) and catch-up drill to improve breathing rhythm and timing.",
                icon: "wind",
                priority: .high
            ))
        }

        // Low turn quality → wall work
        if turnQuality <= 2 {
            suggestions.append(.init(
                title: "Improve Your Turns",
                message: "Practice flip turns in isolation. Focus on tight tucks, strong push-offs, and maintaining streamline off the wall.",
                icon: "arrow.turn.up.right",
                priority: .medium
            ))
        }

        // Poor pace control with good endurance → pacing strategy
        if paceControl <= 2 && enduranceFeel >= 4 {
            suggestions.append(.init(
                title: "Work on Pacing Strategy",
                message: "You have good endurance but struggle with pacing. Try using a tempo trainer or counting strokes per lap to maintain consistency.",
                icon: "speedometer",
                priority: .medium
            ))
        }

        // High fatigue with low kick efficiency → kick technique
        if legFatigue <= 2 && kickEfficiency <= 2 {
            suggestions.append(.init(
                title: "Improve Kick Efficiency",
                message: "Leg fatigue with inefficient kick suggests over-kicking. Focus on a compact flutter kick from the hips with pointed toes.",
                icon: "figure.walk",
                priority: .high
            ))
        }

        // Low stroke efficiency but good pace → SWOLF focus
        if strokeEfficiency <= 2 && paceControl >= 4 {
            suggestions.append(.init(
                title: "Reduce Stroke Count",
                message: "You maintain pace well but inefficiently. Focus on distance per stroke - try to reduce strokes per lap by 1-2 while maintaining the same time.",
                icon: "arrow.left.and.right",
                priority: .medium
            ))
        }

        // Arm fatigue higher than leg fatigue → kick more
        if armFatigue <= 2 && legFatigue >= 4 {
            suggestions.append(.init(
                title: "Engage Your Legs More",
                message: "Arm fatigue suggests you're over-relying on upper body. Use a consistent 6-beat kick to take pressure off your arms.",
                icon: "figure.run",
                priority: .medium
            ))
        }

        // Low endurance feel → aerobic base work
        if enduranceFeel <= 2 && overallFeeling >= 3 {
            suggestions.append(.init(
                title: "Build Aerobic Base",
                message: "Add more steady-state endurance swims at moderate pace. Try 10x100m at comfortable pace with short rest.",
                icon: "heart",
                priority: .medium
            ))
        }

        // Good scores overall → maintenance
        if overallAverage >= 4 {
            suggestions.append(.init(
                title: "Great Session!",
                message: "Excellent work! Maintain this quality by varying your training between technique, speed, and endurance sessions.",
                icon: "star.fill",
                priority: .low
            ))
        }

        return suggestions.sorted { $0.priority.rawValue < $1.priority.rawValue }
    }
}

// MARK: - Swimming Score Categories

enum SwimmingScoreCategory: String, CaseIterable {
    case strokeEfficiency = "Stroke Efficiency"
    case bodyPosition = "Body Position"
    case breathingRhythm = "Breathing Rhythm"
    case turnQuality = "Turn Quality"
    case kickEfficiency = "Kick Efficiency"
    case paceControl = "Pace Control"
    case splitConsistency = "Split Consistency"
    case intervalAdherence = "Interval Adherence"
    case enduranceFeel = "Endurance Feel"
    case armFatigue = "Arm Fatigue"
    case legFatigue = "Leg Fatigue"

    var icon: String {
        switch self {
        case .strokeEfficiency: return "water.waves"
        case .bodyPosition: return "figure.pool.swim"
        case .breathingRhythm: return "wind"
        case .turnQuality: return "arrow.turn.up.right"
        case .kickEfficiency: return "figure.walk"
        case .paceControl: return "speedometer"
        case .splitConsistency: return "chart.bar.fill"
        case .intervalAdherence: return "timer"
        case .enduranceFeel: return "battery.75percent"
        case .armFatigue: return "hand.raised.fill"
        case .legFatigue: return "figure.run"
        }
    }

    var description: String {
        switch self {
        case .strokeEfficiency:
            return "Power and smoothness of your stroke technique"
        case .bodyPosition:
            return "How horizontal and streamlined you are in the water"
        case .breathingRhythm:
            return "Consistency and timing of your breathing pattern"
        case .turnQuality:
            return "Speed and efficiency of flip turns and push-offs"
        case .kickEfficiency:
            return "Power and rhythm of your leg kick"
        case .paceControl:
            return "Ability to maintain target pace throughout"
        case .splitConsistency:
            return "How even your lap times were across the session"
        case .intervalAdherence:
            return "How well you hit your interval targets"
        case .enduranceFeel:
            return "Overall energy and stamina throughout the swim"
        case .armFatigue:
            return "How tired your arms felt (1=exhausted, 5=fresh)"
        case .legFatigue:
            return "How tired your legs felt (1=exhausted, 5=fresh)"
        }
    }
}

// MARK: - Coaching Suggestion

struct SwimmingCoachingSuggestion: Identifiable {
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
