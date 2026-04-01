//
//  RideType.swift
//  TetraTrack
//
//  Ride type categorization for outdoor and indoor riding

import SwiftUI

// MARK: - Ride Type

enum RideType: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }

    case ride = "Ride"
    case dressage = "Dressage"
    case showjumping = "Showjumping"

    // Legacy cases for CloudKit backward compatibility (historical rides)
    case hack = "Hack"
    case schooling = "Schooling"
    case crossCountry = "Cross Country"
    case gaitTesting = "Gait Testing"

    /// Active ride types shown in UI (excludes legacy)
    static var activeCases: [RideType] {
        [.ride, .dressage, .showjumping]
    }

    /// SF Symbol icon for the ride type
    var icon: String {
        switch self {
        case .ride, .hack, .schooling:
            return "figure.equestrian.sports"
        case .dressage:
            return "figure.equestrian.sports"
        case .showjumping:
            return "arrow.up.forward"
        case .crossCountry:
            return "mountain.2.fill"
        case .gaitTesting:
            return "waveform.path.ecg"
        }
    }

    /// Color associated with ride type
    var color: Color {
        switch self {
        case .ride, .hack, .schooling:
            return Color.green
        case .dressage:
            return Color.indigo
        case .showjumping:
            return Color.orange
        case .crossCountry:
            return Color.red
        case .gaitTesting:
            return Color.cyan
        }
    }

    /// Whether this is an indoor ride type (legacy, for backward compat with tracking views)
    var isIndoor: Bool {
        self == .dressage
    }

    /// Whether this is an outdoor ride type
    var isOutdoor: Bool {
        !isIndoor
    }

    /// Description of the ride type
    var description: String {
        switch self {
        case .ride, .hack, .schooling:
            return "General riding — hacking, schooling, trail"
        case .dressage:
            return "Dressage tests and collected work"
        case .showjumping:
            return "Showjumping with jump counting"
        case .crossCountry:
            return "Cross country jumping"
        case .gaitTesting:
            return "Diagnostic gait testing"
        }
    }
}
