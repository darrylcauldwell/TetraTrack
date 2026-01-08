//
//  ReinSegment.swift
//  TrackRide
//
//  Model for tracking rein segments during flatwork

import Foundation
import SwiftData

// MARK: - Rein Segment Model

@Model
final class ReinSegment {
    var id: UUID = UUID()
    var reinDirectionType: String = ReinDirection.straight.rawValue
    var startTime: Date = Date()
    var endTime: Date?
    var distance: Double = 0.0  // meters traveled on this rein
    var symmetryScore: Double = 0.0  // 0-100% symmetry during this segment
    var rhythmScore: Double = 0.0  // 0-100% rhythm consistency during this segment

    // Relationship to ride - optional for CloudKit
    var ride: Ride?

    init() {}

    init(direction: ReinDirection, startTime: Date) {
        self.reinDirectionType = direction.rawValue
        self.startTime = startTime
    }

    // MARK: - Computed Properties

    /// The rein direction as enum
    var reinDirection: ReinDirection {
        get { ReinDirection(rawValue: reinDirectionType) ?? .straight }
        set { reinDirectionType = newValue.rawValue }
    }

    /// Duration of this rein segment
    var duration: TimeInterval {
        guard let end = endTime else { return 0 }
        return end.timeIntervalSince(startTime)
    }

    /// Formatted duration string
    var formattedDuration: String {
        duration.formattedDuration
    }

    /// Formatted symmetry score
    var formattedSymmetry: String {
        String(format: "%.0f%%", symmetryScore)
    }

    /// Formatted rhythm score
    var formattedRhythm: String {
        String(format: "%.0f%%", rhythmScore)
    }

    /// Formatted distance
    var formattedDistance: String {
        distance.formattedDistance
    }
}
