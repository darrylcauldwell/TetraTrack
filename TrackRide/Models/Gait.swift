//
//  Gait.swift
//  TrackRide
//

import Foundation
import SwiftData

// MARK: - Gait Type

enum GaitType: String, Codable, CaseIterable {
    case stationary = "Stationary"
    case walk = "Walk"
    case trot = "Trot"
    case canter = "Canter"
    case gallop = "Gallop"

    var color: String {
        switch self {
        case .stationary: return "gray"
        case .walk: return "green"
        case .trot: return "blue"
        case .canter: return "orange"
        case .gallop: return "red"
        }
    }

    var icon: String {
        switch self {
        case .stationary: return "pause.circle"
        case .walk: return "figure.walk"
        case .trot: return "gauge.with.dots.needle.33percent"
        case .canter: return "gauge.with.dots.needle.67percent"
        case .gallop: return "bolt.fill"
        }
    }

    // Typical speed ranges in m/s for horse gaits
    static func fromSpeed(_ speed: Double) -> GaitType {
        switch speed {
        case ..<0.5: return .stationary
        case 0.5..<2.2: return .walk       // ~2-8 km/h
        case 2.2..<4.5: return .trot       // ~8-16 km/h
        case 4.5..<7.0: return .canter     // ~16-25 km/h
        default: return .gallop            // >25 km/h
        }
    }
}

// MARK: - Gait Segment Model

@Model
final class GaitSegment {
    var id: UUID = UUID()
    var gaitType: String = GaitType.stationary.rawValue  // Store as string for SwiftData
    var startTime: Date = Date()
    var endTime: Date?
    var distance: Double = 0.0  // meters
    var averageSpeed: Double = 0.0  // m/s

    // Lead tracking (for canter/gallop)
    var leadValue: String = Lead.unknown.rawValue
    var leadConfidence: Double = 0.0  // 0-1 confidence score

    // Rhythm tracking
    var rhythmScore: Double = 0.0  // 0-100%

    // Relationship to ride - optional for CloudKit
    var ride: Ride?

    init() {}

    init(gaitType: GaitType, startTime: Date) {
        self.gaitType = gaitType.rawValue
        self.startTime = startTime
    }

    var gait: GaitType {
        get { GaitType(rawValue: gaitType) ?? .stationary }
        set { gaitType = newValue.rawValue }
    }

    /// The detected lead (for canter/gallop)
    var lead: Lead {
        get { Lead(rawValue: leadValue) ?? .unknown }
        set { leadValue = newValue.rawValue }
    }

    /// Whether lead detection is applicable for this gait
    var isLeadApplicable: Bool {
        gait == .canter || gait == .gallop
    }

    /// Whether lead was successfully detected
    var hasKnownLead: Bool {
        isLeadApplicable && lead != .unknown && leadConfidence >= 0.7
    }

    var duration: TimeInterval {
        guard let end = endTime else { return 0 }
        return end.timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        duration.formattedDuration
    }

    var formattedRhythm: String {
        String(format: "%.0f%%", rhythmScore)
    }

    var formattedLeadConfidence: String {
        String(format: "%.0f%%", leadConfidence * 100)
    }
}
