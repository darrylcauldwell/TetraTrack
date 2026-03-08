//
//  SessionTracker+Formatters.swift
//  TetraTrack
//
//  Formatted value extensions for SessionTracker (common metrics)
//

import Foundation

extension SessionTracker {
    // MARK: - Time Formatting

    var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Distance Formatting

    var formattedDistance: String {
        let km = totalDistance / 1000.0
        if km < 1 {
            return String(format: "%.0f m", totalDistance)
        }
        return String(format: "%.2f km", km)
    }

    // MARK: - Speed Formatting

    var formattedSpeed: String {
        let kmh = currentSpeed * 3.6
        return String(format: "%.1f km/h", kmh)
    }

    var formattedAverageSpeed: String {
        guard elapsedTime > 0 else { return "0.0 km/h" }
        let avgSpeedMS = totalDistance / elapsedTime
        let kmh = avgSpeedMS * 3.6
        return String(format: "%.1f km/h", kmh)
    }

    // MARK: - Elevation Formatting

    var formattedElevation: String {
        return String(format: "%.0f m", currentElevation)
    }

    var formattedElevationGain: String {
        return String(format: "+%.0f m", elevationGain)
    }

    var formattedElevationLoss: String {
        return String(format: "-%.0f m", elevationLoss)
    }
}
