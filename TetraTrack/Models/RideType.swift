//
//  RideType.swift
//  TetraTrack
//
//  Ride type categorization for outdoor and indoor riding

import SwiftUI

// MARK: - Ride Type

enum RideType: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    // Most common at top
    case hack = "Hack"
    case schooling = "Schooling"
    case dressage = "Dressage"
    case crossCountry = "Cross Country"
    case gaitTesting = "Gait Testing"

    /// Whether this is an indoor ride type (arena work)
    var isIndoor: Bool {
        switch self {
        case .schooling, .dressage:
            return true
        default:
            return false
        }
    }

    /// Whether this is an outdoor ride type
    var isOutdoor: Bool {
        !isIndoor
    }

    /// SF Symbol icon for the ride type
    var icon: String {
        switch self {
        case .hack:
            return "leaf.fill"
        case .crossCountry:
            return "mountain.2.fill"
        case .schooling:
            return "rectangle.portrait.fill"
        case .dressage:
            return "figure.equestrian.sports"
        case .gaitTesting:
            return "waveform.path.ecg"
        }
    }

    /// Color associated with ride type
    var color: Color {
        switch self {
        case .hack:
            return Color.green
        case .crossCountry:
            return Color.red
        case .schooling:
            return Color.purple
        case .dressage:
            return Color.indigo
        case .gaitTesting:
            return Color.cyan
        }
    }

    /// Description of the ride type
    var description: String {
        switch self {
        case .hack:
            return "Trail riding and hacking out"
        case .crossCountry:
            return "Cross country jumping"
        case .schooling:
            return "Arena schooling and flatwork"
        case .dressage:
            return "Dressage tests and collected work"
        case .gaitTesting:
            return "Diagnostic ride for validating gait detection accuracy"
        }
    }

    /// All outdoor ride types
    static var outdoorTypes: [RideType] {
        [.hack, .crossCountry, .gaitTesting]
    }

    /// All indoor ride types
    static var indoorTypes: [RideType] {
        [.schooling, .dressage]
    }
}
