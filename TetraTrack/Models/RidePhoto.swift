//
//  RidePhoto.swift
//  TetraTrack
//
//  Photos taken during rides with location metadata
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class RidePhoto {
    var id: UUID = UUID()

    // Photo reference
    var localIdentifier: String = "" // PHAsset local identifier
    var capturedAt: Date = Date()

    // Location at time of capture
    var latitude: Double = 0
    var longitude: Double = 0
    var hasLocation: Bool = false

    // Metadata
    var caption: String = ""
    var isFavorite: Bool = false

    // Relationship
    var ride: Ride?

    init(
        localIdentifier: String,
        capturedAt: Date,
        latitude: Double = 0,
        longitude: Double = 0
    ) {
        self.localIdentifier = localIdentifier
        self.capturedAt = capturedAt
        self.latitude = latitude
        self.longitude = longitude
        self.hasLocation = latitude != 0 || longitude != 0
    }

    var coordinate: CLLocationCoordinate2D? {
        guard hasLocation else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Fatigue/Recovery Metrics

@Model
final class FatigueIndicator {
    var id: UUID = UUID()
    var recordedAt: Date = Date()

    // HRV metrics
    var hrvValue: Double = 0 // RMSSD in milliseconds
    var hrvBaseline: Double = 0 // 7-day rolling average

    // Recovery metrics
    var restingHeartRate: Int = 0
    var restingHRBaseline: Int = 0

    // Calculated readiness
    var readinessScore: Int = 0 // 0-100

    // Context
    var sleepQuality: Int = 0 // 1-5 scale
    var perceivedFatigue: Int = 0 // 1-5 scale
    var notes: String = ""

    init() {}

    /// Calculate readiness based on HRV and RHR compared to baselines
    func calculateReadiness() {
        var score = 50 // Start neutral

        // HRV contribution (higher is better)
        if hrvBaseline > 0 && hrvValue > 0 {
            let hrvRatio = hrvValue / hrvBaseline
            if hrvRatio > 1.1 {
                score += 20 // Well above baseline
            } else if hrvRatio > 1.0 {
                score += 10 // Above baseline
            } else if hrvRatio > 0.9 {
                score -= 5 // Slightly below
            } else if hrvRatio > 0.8 {
                score -= 15 // Below baseline
            } else {
                score -= 25 // Well below baseline
            }
        }

        // RHR contribution (lower is better)
        if restingHRBaseline > 0 && restingHeartRate > 0 {
            let rhrDiff = restingHeartRate - restingHRBaseline
            if rhrDiff < -5 {
                score += 15 // Well below baseline
            } else if rhrDiff < 0 {
                score += 5 // Below baseline
            } else if rhrDiff < 5 {
                score -= 5 // Slightly elevated
            } else if rhrDiff < 10 {
                score -= 15 // Elevated
            } else {
                score -= 25 // Significantly elevated
            }
        }

        // Subjective factors
        if sleepQuality > 0 {
            score += (sleepQuality - 3) * 5 // -10 to +10
        }
        if perceivedFatigue > 0 {
            score -= (perceivedFatigue - 3) * 5 // -10 to +10
        }

        // Clamp to 0-100
        readinessScore = max(0, min(100, score))
    }

    var readinessLabel: String {
        switch readinessScore {
        case 80...100: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Moderate"
        case 20..<40: return "Low"
        default: return "Poor"
        }
    }

    var readinessColor: String {
        switch readinessScore {
        case 80...100: return "green"
        case 60..<80: return "blue"
        case 40..<60: return "yellow"
        case 20..<40: return "orange"
        default: return "red"
        }
    }

    var recommendation: String {
        switch readinessScore {
        case 80...100: return "Great day for hard training or competition"
        case 60..<80: return "Good for moderate training"
        case 40..<60: return "Consider lighter work today"
        case 20..<40: return "Rest or very light activity recommended"
        default: return "Focus on recovery today"
        }
    }
}
