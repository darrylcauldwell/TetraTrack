//
//  TurnAnalyzer.swift
//  TrackRide
//

import CoreLocation
import Foundation

final class TurnAnalyzer: Resettable {
    private var previousBearing: Double?
    private var bearingHistory: [Double] = []
    private let minTurnAngle: Double = 30  // Minimum angle to count as a turn

    private(set) var leftTurns: Int = 0
    private(set) var rightTurns: Int = 0
    private(set) var totalLeftAngle: Double = 0
    private(set) var totalRightAngle: Double = 0

    func reset() {
        previousBearing = nil
        bearingHistory = []
        leftTurns = 0
        rightTurns = 0
        totalLeftAngle = 0
        totalRightAngle = 0
    }

    // Process two consecutive locations to detect turns
    func processLocations(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) {
        let bearing = LocationMath.bearing(from: from, to: to)

        guard let prevBearing = previousBearing else {
            previousBearing = bearing
            return
        }

        // Calculate angle difference using LocationMath
        let angleDiff = LocationMath.bearingChange(from: prevBearing, to: bearing)

        // Track significant turns
        if abs(angleDiff) >= minTurnAngle {
            if angleDiff > 0 {
                // Right turn (positive bearing change)
                rightTurns += 1
                totalRightAngle += angleDiff
            } else {
                // Left turn (negative bearing change)
                leftTurns += 1
                totalLeftAngle += abs(angleDiff)
            }
        }

        previousBearing = bearing
    }

    var turnStats: TurnStats {
        TurnStats(
            leftTurns: leftTurns,
            rightTurns: rightTurns,
            totalLeftAngle: totalLeftAngle,
            totalRightAngle: totalRightAngle
        )
    }
}
