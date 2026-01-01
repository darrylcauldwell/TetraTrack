//
//  RideScore.swift
//  TetraTrack
//
//  Post-ride subjective scoring for training quality
//

import Foundation
import SwiftData

@Model
final class RideScore {
    var id: UUID = UUID()

    // Core scores (1-5 scale)
    var relaxation: Int = 0      // Horse's mental relaxation
    var impulsion: Int = 0       // Forward energy and engagement
    var straightness: Int = 0    // Alignment and balance
    var rhythm: Int = 0          // Regularity and tempo
    var riderPosition: Int = 0   // Rider's own position and aids

    // Additional scores
    var connection: Int = 0      // Contact and throughness
    var suppleness: Int = 0      // Lateral and longitudinal flexibility
    var collection: Int = 0      // Self-carriage and balance

    // Overall feel
    var overallFeeling: Int = 0  // General satisfaction with the ride
    var horseEnergy: Int = 0     // Horse's energy level (1=sluggish, 5=fresh)
    var horseMood: Int = 0       // Horse's attitude (1=resistant, 5=willing)

    // Notes
    var notes: String = ""
    var highlights: String = ""  // What went well
    var improvements: String = "" // Areas to work on

    // Timestamp
    var scoredAt: Date = Date()

    // Relationship
    var ride: Ride?

    init() {}

    /// Average of the core training scale scores
    var trainingScaleAverage: Double {
        let scores = [relaxation, impulsion, straightness, rhythm].filter { $0 > 0 }
        guard !scores.isEmpty else { return 0 }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    /// Average of all non-zero scores
    var overallAverage: Double {
        let allScores = [
            relaxation, impulsion, straightness, rhythm,
            riderPosition, connection, suppleness, collection,
            overallFeeling
        ].filter { $0 > 0 }
        guard !allScores.isEmpty else { return 0 }
        return Double(allScores.reduce(0, +)) / Double(allScores.count)
    }

    /// Check if any scores have been entered
    var hasScores: Bool {
        [relaxation, impulsion, straightness, rhythm,
         riderPosition, connection, suppleness, collection,
         overallFeeling, horseEnergy, horseMood].contains { $0 > 0 }
    }
}

// MARK: - Score Categories

enum ScoreCategory: String, CaseIterable {
    case relaxation = "Relaxation"
    case impulsion = "Impulsion"
    case straightness = "Straightness"
    case rhythm = "Rhythm"
    case riderPosition = "Rider Position"
    case connection = "Connection"
    case suppleness = "Suppleness"
    case collection = "Collection"

    var icon: String {
        switch self {
        case .relaxation: return "leaf.fill"
        case .impulsion: return "bolt.fill"
        case .straightness: return "arrow.up"
        case .rhythm: return "metronome.fill"
        case .riderPosition: return "person.fill"
        case .connection: return "link"
        case .suppleness: return "figure.flexibility"
        case .collection: return "arrow.up.and.down.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .relaxation:
            return "Mental and physical relaxation, absence of tension"
        case .impulsion:
            return "Forward energy, engagement from behind, desire to move"
        case .straightness:
            return "Alignment of the horse from poll to tail"
        case .rhythm:
            return "Regularity and tempo of the gaits"
        case .riderPosition:
            return "Your position, balance, and effectiveness of aids"
        case .connection:
            return "Elastic contact, throughness, acceptance of the bit"
        case .suppleness:
            return "Lateral bend and longitudinal flexibility"
        case .collection:
            return "Self-carriage, engagement, lightening of forehand"
        }
    }
}

// MARK: - Score Label

extension Int {
    var scoreLabel: String {
        switch self {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Very Good"
        case 5: return "Excellent"
        default: return "Not Rated"
        }
    }

    var scoreEmoji: String {
        switch self {
        case 1: return "1"
        case 2: return "2"
        case 3: return "3"
        case 4: return "4"
        case 5: return "5"
        default: return "-"
        }
    }
}
