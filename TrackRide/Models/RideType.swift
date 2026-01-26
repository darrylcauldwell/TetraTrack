//
//  RideType.swift
//  TrackRide
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

    /// Whether this is an indoor ride type (arena work)
    var isIndoor: Bool {
        self == .schooling || self == .dressage
    }

    /// Whether this is a dressage/collected work session
    /// These sessions use adjusted gait detection for slow, controlled movements
    var isDressageMode: Bool {
        self == .dressage
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
        }
    }

    /// All outdoor ride types
    static var outdoorTypes: [RideType] {
        [.hack, .crossCountry]
    }

    /// All indoor ride types
    static var indoorTypes: [RideType] {
        [.schooling, .dressage]
    }
}
