//
//  SkillDomain.swift
//  TetraTrack
//
//  Six universal skill domains for cross-discipline athlete profiling
//

import Foundation
import SwiftUI

/// Universal skill domains that apply across all training disciplines
enum SkillDomain: String, CaseIterable, Codable, Identifiable {
    case stability = "stability"
    case balance = "balance"
    case symmetry = "symmetry"
    case rhythm = "rhythm"
    case endurance = "endurance"
    case calmness = "calmness"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .stability: return "Stability"
        case .balance: return "Balance"
        case .symmetry: return "Symmetry"
        case .rhythm: return "Rhythm"
        case .endurance: return "Endurance"
        case .calmness: return "Calmness"
        }
    }

    var icon: String {
        switch self {
        case .stability: return "figure.stand"
        case .balance: return "scale.3d"
        case .symmetry: return "arrow.left.and.right"
        case .rhythm: return "metronome.fill"
        case .endurance: return "battery.100percent"
        case .calmness: return "heart.text.square"
        }
    }

    var description: String {
        switch self {
        case .stability:
            return "Ability to stay still while external forces act on you. Measured through motion variance and postural control."
        case .balance:
            return "Ability to stay centered over your base of support. Measured through lateral deviation and weight distribution."
        case .symmetry:
            return "Left-right equality in movement patterns. Measured through timing and force magnitude differences."
        case .rhythm:
            return "Consistency of timing in repetitive movements. Measured through cadence variance and tempo regularity."
        case .endurance:
            return "Ability to maintain quality over time. Measured through form degradation and recovery metrics."
        case .calmness:
            return "Nervous system steadiness under pressure. Measured through heart rate variability and motion entropy."
        }
    }

    var color: String {
        switch self {
        case .stability: return "purple"
        case .balance: return "blue"
        case .symmetry: return "green"
        case .rhythm: return "orange"
        case .endurance: return "red"
        case .calmness: return "teal"
        }
    }

    /// SwiftUI Color value for use in views
    var colorValue: Color {
        switch self {
        case .stability: return .purple
        case .balance: return .blue
        case .symmetry: return .green
        case .rhythm: return .orange
        case .endurance: return .red
        case .calmness: return .teal
        }
    }

    /// Which disciplines primarily contribute to this domain
    var primaryDisciplines: [TrainingDiscipline] {
        switch self {
        case .stability: return [.riding, .shooting]
        case .balance: return [.riding, .shooting, .swimming]
        case .symmetry: return [.riding, .running, .swimming]
        case .rhythm: return [.riding, .running, .swimming]
        case .endurance: return [.running, .swimming, .riding]
        case .calmness: return [.shooting, .riding]
        }
    }

    /// Short coaching tip for improving this domain
    var coachingTip: String {
        switch self {
        case .stability:
            return "Focus on core engagement and quiet hands/seat during movement."
        case .balance:
            return "Practice weight distribution exercises and single-leg stability work."
        case .symmetry:
            return "Work both directions equally and monitor left-right differences."
        case .rhythm:
            return "Use a metronome or music to maintain consistent timing."
        case .endurance:
            return "Build gradually with progressive overload while maintaining form."
        case .calmness:
            return "Practice breathing techniques and visualisation before performance."
        }
    }
}
