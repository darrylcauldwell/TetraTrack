//
//  PonyClubScoringService.swift
//  TrackRide
//
//  Pony Club Tetrathlon/Triathlon scoring calculator
//  Based on 2025/2026 Pony Club Tetrathlon Rule Book
//

import Foundation

/// Age categories for Pony Club competitions
enum PonyClubAgeCategory: String, CaseIterable, Codable {
    case beanies = "Beanies"
    case tadpole = "Tadpole"
    case minimus = "Minimus"
    case junior = "Junior"
    case intermediate = "Intermediate"
    case open = "Open"
}

/// Gender for scoring (some categories have different standards)
enum PonyClubGender: String, CaseIterable, Codable {
    case boys = "Boys"
    case girls = "Girls"
}

/// Pony Club Tetrathlon/Triathlon scoring service
/// Based on 2025/2026 Pony Club Tetrathlon Rule Book
enum PonyClubScoringService {

    // MARK: - Shooting Scoring

    /// Calculate shooting points
    /// Scoring: Bull=10, Inner=8, Magpie=6, Outer=4, Outside outer=2, Border=0
    /// Scores are always even numbers, max 100 for 10 shots
    static func calculateShootingPoints(rawScore: Int) -> Double {
        // Raw score is direct points (e.g., 80 out of 100 = 800 competition points)
        // The input is already the total score, multiply by 10 for competition points
        return Double(rawScore)
    }

    // MARK: - Swimming Scoring

    /// Calculate swimming points based on distance swum in fixed time
    /// Formula: 1000 + ((actual distance - standard distance) × 3)
    /// 3 points per metre added/subtracted for each metre over/under standard
    static func calculateSwimmingPoints(
        distanceMeters: Double,
        ageCategory: PonyClubAgeCategory = .open,
        gender: PonyClubGender = .girls
    ) -> Double {
        let standardDistance = getSwimStandardDistance(for: ageCategory, gender: gender)
        let pointsPerMeter = 3.0

        let distanceDifference = distanceMeters - standardDistance
        let points = 1000.0 + (distanceDifference * pointsPerMeter)

        return max(0, points)
    }

    /// Get standard distance (for 1000 points) by category
    /// Time allowed varies: Open Boys 4min, most others 3min, younger 2min
    private static func getSwimStandardDistance(for category: PonyClubAgeCategory, gender: PonyClubGender) -> Double {
        switch category {
        case .open:
            return gender == .boys ? 285.0 : 225.0  // Boys 4min, Girls 3min
        case .intermediate:
            return 225.0  // 3 minutes, both genders
        case .junior:
            return 185.0  // 3 minutes, both genders
        case .minimus, .tadpole, .beanies:
            return 125.0  // 2 minutes, both genders
        }
    }

    /// Get swim time allowance in seconds
    static func getSwimTimeAllowance(for category: PonyClubAgeCategory, gender: PonyClubGender) -> TimeInterval {
        switch category {
        case .open:
            return gender == .boys ? 240.0 : 180.0  // 4 min boys, 3 min girls
        case .intermediate, .junior:
            return 180.0  // 3 minutes
        case .minimus, .tadpole, .beanies:
            return 120.0  // 2 minutes
        }
    }

    // MARK: - Running Scoring

    /// Calculate running points based on time
    /// Formula: 1000 - ((actual time - standard time) × 3)
    /// 3 points per second added/subtracted
    /// Times rounded up to next whole second
    /// Special: Open Boys reduces to 1 pt/sec after 13:16
    static func calculateRunningPoints(
        timeInSeconds: TimeInterval,
        ageCategory: PonyClubAgeCategory = .open,
        gender: PonyClubGender = .girls
    ) -> Double {
        // Round up to next whole second
        let roundedTime = ceil(timeInSeconds)

        let standardTime = getRunStandardTime(for: ageCategory, gender: gender)
        let timeDifference = roundedTime - standardTime

        var points: Double

        // Special case: Open Boys reduces to 1 pt/sec after 13:16 (796 seconds)
        if ageCategory == .open && gender == .boys && roundedTime > 796 {
            // First part at 3 pts/sec up to 13:16
            let firstPartDiff = 796 - standardTime
            let secondPartDiff = roundedTime - 796
            points = 1000.0 - (firstPartDiff * 3.0) - (secondPartDiff * 1.0)
        } else {
            points = 1000.0 - (timeDifference * 3.0)
        }

        return max(0, points)
    }

    /// Get standard time (for 1000 points) by category and gender
    private static func getRunStandardTime(for category: PonyClubAgeCategory, gender: PonyClubGender) -> TimeInterval {
        switch category {
        case .open:
            // Open Boys: 3000m in 10:30, Open Girls: 1500m in 5:20
            return gender == .boys ? 630.0 : 320.0
        case .intermediate:
            // Intermediate Boys: 2000m in 7:00, Intermediate Girls: 1500m in 5:20
            return gender == .boys ? 420.0 : 320.0
        case .junior:
            // Junior Boys and Girls: 1500m in 5:40
            return 340.0
        case .minimus, .tadpole:
            // Minimus/Tadpole Boys and Girls: 1000m in 4:00
            return 240.0
        case .beanies:
            // Beanies Boys and Girls: 500m in 2:00
            return 120.0
        }
    }

    /// Get running distance by category and gender
    static func getRunDistance(for category: PonyClubAgeCategory, gender: PonyClubGender) -> Double {
        switch category {
        case .open:
            return gender == .boys ? 3000.0 : 1500.0
        case .intermediate:
            return gender == .boys ? 2000.0 : 1500.0
        case .junior:
            return 1500.0
        case .minimus, .tadpole:
            return 1000.0
        case .beanies:
            return 500.0
        }
    }

    // MARK: - Riding Scoring (Tetrathlon only)

    /// Calculate riding points
    /// Clear round within time = 1400 points
    /// Deductions for jumping penalties, retirement, fences not attempted
    static func calculateRidingPoints(
        jumpingPenalties: Double,
        retired: Bool = false,
        fencesNotAttempted: Int = 0
    ) -> Double {
        var totalPenalties = jumpingPenalties

        if retired {
            totalPenalties += 500.0  // Retirement penalty
        }

        totalPenalties += Double(fencesNotAttempted) * 50.0  // 50 per fence not attempted

        let points = 1400.0 - totalPenalties
        return max(0, points)
    }

    /// Simple riding calculation from total penalties (for UI input)
    static func calculateRidingPoints(penalties: Double) -> Double {
        return max(0, 1400.0 - penalties)
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

    /// Format time as MM:SS (rounded up to whole seconds as per rules)
    static func formatTime(_ seconds: TimeInterval) -> String {
        let roundedSeconds = Int(ceil(seconds))
        let minutes = roundedSeconds / 60
        let secs = roundedSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Format points with no decimal places
    static func formatPoints(_ points: Double) -> String {
        return String(format: "%.0f", points)
    }
}
