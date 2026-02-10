//
//  MovementCategory.swift
//  TetraTrack
//
//  Movement pattern categories that transfer across disciplines
//

import SwiftUI

/// Movement pattern categories - the foundation of cross-discipline training
/// "You're not training sports. You're training movement patterns."
enum MovementCategory: String, CaseIterable, Codable, Identifiable {
    case stability = "Stability"
    case balance = "Balance"
    case mobility = "Mobility"
    case breathing = "Breathing"
    case rhythm = "Rhythm"
    case reaction = "Reaction"
    case recovery = "Recovery"
    case power = "Power"
    case coordination = "Coordination"
    case endurance = "Endurance"

    var id: String { rawValue }

    var displayName: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .stability: return "figure.stand"
        case .balance: return "figure.surfing"
        case .mobility: return "figure.flexibility"
        case .breathing: return "wind"
        case .rhythm: return "metronome"
        case .reaction: return "bolt.horizontal.fill"
        case .recovery: return "arrow.counterclockwise"
        case .power: return "bolt.fill"
        case .coordination: return "figure.dance"
        case .endurance: return "clock.arrow.circlepath"
        }
    }

    var color: Color {
        switch self {
        case .stability: return .blue
        case .balance: return .purple
        case .mobility: return .pink
        case .breathing: return .cyan
        case .rhythm: return .indigo
        case .reaction: return .orange
        case .recovery: return .green
        case .power: return .red
        case .coordination: return .teal
        case .endurance: return .yellow
        }
    }

    var description: String {
        switch self {
        case .stability:
            return "Hold steady positions under load - the foundation of all athletic performance."
        case .balance:
            return "Maintain equilibrium through dynamic movement and external forces."
        case .mobility:
            return "Achieve full range of motion for fluid, efficient movement patterns."
        case .breathing:
            return "Control your breath to manage stress and optimize oxygen delivery."
        case .rhythm:
            return "Develop consistent timing for smooth, efficient movement patterns."
        case .reaction:
            return "Respond quickly and accurately to visual and auditory cues."
        case .recovery:
            return "Return to ready position rapidly after explosive movements."
        case .power:
            return "Generate explosive force through coordinated muscle activation."
        case .coordination:
            return "Synchronize multiple body systems for complex movements."
        case .endurance:
            return "Maintain performance quality under sustained physical stress."
        }
    }

    /// Which disciplines benefit from this movement category
    var benefitsDisciplines: Set<Discipline> {
        switch self {
        case .stability, .balance, .breathing, .coordination, .endurance:
            return [.riding, .running, .swimming, .shooting]
        case .mobility:
            return [.riding, .running, .swimming]
        case .rhythm:
            return [.riding, .running, .swimming]
        case .reaction:
            return [.riding, .shooting]
        case .recovery:
            return [.shooting, .running]
        case .power:
            return [.running, .swimming]
        }
    }
}

/// Training discipline filter options
enum Discipline: String, CaseIterable, Codable, Identifiable {
    case all = "All"
    case riding = "Riding"
    case running = "Running"
    case swimming = "Swimming"
    case shooting = "Shooting"

    var id: String { rawValue }

    var displayName: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .riding: return "figure.equestrian.sports"
        case .running: return "figure.run"
        case .swimming: return "figure.pool.swim"
        case .shooting: return "scope"
        }
    }

    var color: Color {
        switch self {
        case .all: return .mint
        case .riding: return .purple
        case .running: return .green
        case .swimming: return .blue
        case .shooting: return .red
        }
    }
}
