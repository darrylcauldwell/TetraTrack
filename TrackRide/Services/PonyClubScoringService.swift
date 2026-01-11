//
//  PonyClubScoringService.swift
//  TrackRide
//
//  Pony Club Tetrathlon/Triathlon scoring calculator
//  Based on Pony Club handbook scoring tables
//

import Foundation

/// Age categories for Pony Club competitions
enum PonyClubAgeCategory: String, CaseIterable, Codable {
    case mini = "Mini"           // Under 9
    case minimus = "Minimus"     // 9-10
    case junior = "Junior"       // 11-12
    case intermediate = "Intermediate" // 13-14
    case senior = "Senior"       // 15+
    case open = "Open"
}

/// Pony Club Tetrathlon/Triathlon scoring service
enum PonyClubScoringService {

    // MARK: - Shooting Scoring

    /// Calculate shooting points
    /// Shooting is typically 1:1 - raw score equals points
    /// Max score varies by category (typically 1000 for seniors, 700 for juniors)
    static func calculateShootingPoints(rawScore: Int) -> Double {
        // Shooting score is direct - 1 point per hit
        // Laser shooting: 10 shots × 10 points per target area × 10 targets = 1000 max
        return Double(rawScore)
    }

    // MARK: - Swimming Scoring

    /// Calculate swimming points based on time and distance
    /// Uses Pony Club par times and scoring multipliers
    static func calculateSwimmingPoints(
        timeInSeconds: TimeInterval,
        distanceMeters: Double,
        ageCategory: PonyClubAgeCategory = .open
    ) -> Double {
        // Par times (in seconds) for different distances and age groups
        // These are approximate - actual tables vary by year
        let parTime: TimeInterval
        let pointsPerSecond: Double

        switch distanceMeters {
        case 0..<75: // 50m swim
            parTime = getSwimParTime50m(for: ageCategory)
            pointsPerSecond = 24.0 // Points lost/gained per second from par

        case 75..<150: // 100m swim
            parTime = getSwimParTime100m(for: ageCategory)
            pointsPerSecond = 12.0

        default: // 200m or other
            parTime = getSwimParTime200m(for: ageCategory)
            pointsPerSecond = 6.0
        }

        // Calculate points: Start from 1000, subtract points for time over par
        // Add points for time under par (capped at 1000)
        let timeDifference = timeInSeconds - parTime
        let points = 1000.0 - (timeDifference * pointsPerSecond)

        // Minimum 0 points, maximum typically around 1300-1400
        return max(0, points)
    }

    private static func getSwimParTime50m(for category: PonyClubAgeCategory) -> TimeInterval {
        switch category {
        case .mini: return 75.0      // 1:15
        case .minimus: return 60.0   // 1:00
        case .junior: return 50.0    // 0:50
        case .intermediate: return 45.0 // 0:45
        case .senior, .open: return 40.0 // 0:40
        }
    }

    private static func getSwimParTime100m(for category: PonyClubAgeCategory) -> TimeInterval {
        switch category {
        case .mini: return 150.0     // 2:30
        case .minimus: return 120.0  // 2:00
        case .junior: return 100.0   // 1:40
        case .intermediate: return 90.0 // 1:30
        case .senior, .open: return 80.0 // 1:20
        }
    }

    private static func getSwimParTime200m(for category: PonyClubAgeCategory) -> TimeInterval {
        switch category {
        case .mini: return 300.0     // 5:00
        case .minimus: return 250.0  // 4:10
        case .junior: return 210.0   // 3:30
        case .intermediate: return 180.0 // 3:00
        case .senior, .open: return 160.0 // 2:40
        }
    }

    // MARK: - Running Scoring

    /// Calculate running points based on time and distance
    static func calculateRunningPoints(
        timeInSeconds: TimeInterval,
        distanceMeters: Double = 1500,
        ageCategory: PonyClubAgeCategory = .open
    ) -> Double {
        let parTime = getRunParTime(for: ageCategory, distance: distanceMeters)
        let pointsPerSecond: Double

        switch distanceMeters {
        case 0..<1000: // 800m
            pointsPerSecond = 3.0
        case 1000..<2000: // 1500m
            pointsPerSecond = 2.0
        default: // 3000m+
            pointsPerSecond = 1.0
        }

        let timeDifference = timeInSeconds - parTime
        let points = 1000.0 - (timeDifference * pointsPerSecond)

        return max(0, points)
    }

    private static func getRunParTime(for category: PonyClubAgeCategory, distance: Double) -> TimeInterval {
        // Par times for 1500m (most common)
        if distance >= 1000 && distance < 2000 {
            switch category {
            case .mini: return 480.0      // 8:00
            case .minimus: return 420.0   // 7:00
            case .junior: return 390.0    // 6:30
            case .intermediate: return 360.0 // 6:00
            case .senior, .open: return 330.0 // 5:30
            }
        } else if distance < 1000 { // 800m
            switch category {
            case .mini: return 240.0      // 4:00
            case .minimus: return 210.0   // 3:30
            case .junior: return 195.0    // 3:15
            case .intermediate: return 180.0 // 3:00
            case .senior, .open: return 165.0 // 2:45
            }
        } else { // 3000m
            switch category {
            case .mini: return 960.0      // 16:00
            case .minimus: return 840.0   // 14:00
            case .junior: return 780.0    // 13:00
            case .intermediate: return 720.0 // 12:00
            case .senior, .open: return 660.0 // 11:00
            }
        }
    }

    // MARK: - Riding Scoring (Tetrathlon only)

    /// Calculate riding points
    /// Typically starts at 1000 and deducts penalties
    static func calculateRidingPoints(penalties: Double) -> Double {
        // Riding scoring: 1000 - penalties
        // Penalties include: time faults, knockdowns, refusals, etc.
        return max(0, 1000.0 - penalties)
    }

    // MARK: - Total Score

    /// Calculate total points for Triathlon (3 disciplines)
    static func calculateTriathlonTotal(
        shootingPoints: Double?,
        swimmingPoints: Double?,
        runningPoints: Double?
    ) -> Double? {
        guard let shooting = shootingPoints,
              let swimming = swimmingPoints,
              let running = runningPoints else {
            return nil
        }
        return shooting + swimming + running
    }

    /// Calculate total points for Tetrathlon (4 disciplines)
    static func calculateTetrathlonTotal(
        shootingPoints: Double?,
        swimmingPoints: Double?,
        runningPoints: Double?,
        ridingPoints: Double?
    ) -> Double? {
        guard let shooting = shootingPoints,
              let swimming = swimmingPoints,
              let running = runningPoints,
              let riding = ridingPoints else {
            return nil
        }
        return shooting + swimming + running + riding
    }

    // MARK: - Formatting Helpers

    /// Format time as MM:SS.ss
    static func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = seconds.truncatingRemainder(dividingBy: 60)
        if minutes > 0 {
            return String(format: "%d:%05.2f", minutes, secs)
        } else {
            return String(format: "%.2f", secs)
        }
    }

    /// Format points with no decimal places
    static func formatPoints(_ points: Double) -> String {
        return String(format: "%.0f", points)
    }
}
