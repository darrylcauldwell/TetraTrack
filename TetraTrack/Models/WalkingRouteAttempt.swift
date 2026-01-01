//
//  WalkingRouteAttempt.swift
//  TetraTrack
//
//  One walk on a known route for progression tracking
//

import Foundation
import SwiftData

@Model
final class WalkingRouteAttempt {
    var id: UUID = UUID()
    var date: Date = Date()
    var durationSeconds: Double = 0
    var pacePerKm: Double = 0
    var averageCadence: Int = 0

    // Biomechanics scores
    var symmetryScore: Double = 0
    var rhythmScore: Double = 0
    var stabilityScore: Double = 0

    // Link to the actual running session
    var runningSessionId: UUID?

    // Relationship
    var route: WalkingRoute?

    init() {}

    init(
        date: Date = Date(),
        durationSeconds: Double,
        pacePerKm: Double,
        averageCadence: Int = 0,
        symmetryScore: Double = 0,
        rhythmScore: Double = 0,
        stabilityScore: Double = 0,
        runningSessionId: UUID? = nil
    ) {
        self.date = date
        self.durationSeconds = durationSeconds
        self.pacePerKm = pacePerKm
        self.averageCadence = averageCadence
        self.symmetryScore = symmetryScore
        self.rhythmScore = rhythmScore
        self.stabilityScore = stabilityScore
        self.runningSessionId = runningSessionId
    }

    var formattedPace: String {
        guard pacePerKm > 0 else { return "--" }
        let minutes = Int(pacePerKm) / 60
        let seconds = Int(pacePerKm) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    var formattedDuration: String {
        let minutes = Int(durationSeconds) / 60
        let seconds = Int(durationSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
