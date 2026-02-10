//
//  RiderProfile.swift
//  TetraTrack
//

import Foundation
import SwiftData

@Model
final class RiderProfile {
    var id: UUID = UUID()
    var weight: Double = 70.0  // kg
    var height: Double = 170.0  // cm
    var dateOfBirth: Date?
    var sex: BiologicalSex = BiologicalSex.notSet
    var lastUpdatedFromHealthKit: Date?
    var useHealthKitData: Bool = true

    // Heart rate configuration
    var restingHeartRate: Int = 60  // bpm
    var customMaxHeartRate: Int?    // User-defined max HR (nil = use calculated)

    init() {}

    init(weight: Double = 70.0, height: Double = 170.0) {
        self.weight = weight
        self.height = height
    }

    // MARK: - Formatted Values

    var formattedWeight: String {
        String(format: "%.1f kg", weight)
    }

    var formattedHeight: String {
        String(format: "%.0f cm", height)
    }

    var bmi: Double {
        let heightM = height / 100.0
        guard heightM > 0 else { return 0 }
        return weight / (heightM * heightM)
    }

    var formattedBMI: String {
        String(format: "%.1f", bmi)
    }

    var age: Int? {
        guard let dob = dateOfBirth else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: dob, to: Date())
        return components.year
    }

    // MARK: - Heart Rate Zone Configuration

    /// Calculated max heart rate using Tanaka formula (208 - 0.7 x age)
    /// Returns nil if age is not set
    var calculatedMaxHeartRate: Int? {
        guard let age = age else { return nil }
        return MaxHeartRateCalculator.tanaka(age: age)
    }

    /// Effective max heart rate (uses custom if set, otherwise calculated)
    var maxHeartRate: Int {
        if let custom = customMaxHeartRate {
            return custom
        }
        return calculatedMaxHeartRate ?? 180 // Default fallback
    }

    /// Heart rate zone boundaries for this rider
    var zoneBoundaries: [(zone: HeartRateZone, minBPM: Int, maxBPM: Int)] {
        HeartRateZone.zoneBoundaries(for: maxHeartRate)
    }

    /// Get zone for a specific heart rate
    func zone(for heartRate: Int) -> HeartRateZone {
        HeartRateZone.zone(for: heartRate, maxHR: maxHeartRate)
    }

    /// Formatted resting heart rate
    var formattedRestingHeartRate: String {
        "\(restingHeartRate) bpm"
    }

    /// Formatted max heart rate
    var formattedMaxHeartRate: String {
        "\(maxHeartRate) bpm"
    }

    /// Whether max HR is user-defined or calculated
    var isMaxHeartRateCustom: Bool {
        customMaxHeartRate != nil
    }
}

// MARK: - Biological Sex

enum BiologicalSex: String, Codable, CaseIterable {
    case notSet = "Not Set"
    case female = "Female"
    case male = "Male"
    case other = "Other"
}

// MARK: - MET Values for Horse Riding

struct RidingMETValues {
    // MET (Metabolic Equivalent of Task) values for horse riding
    // Based on Compendium of Physical Activities

    static let stationary: Double = 1.5  // Sitting on horse, not moving
    static let walk: Double = 2.5        // Walking pace
    static let trot: Double = 5.5        // Trotting - moderate effort
    static let canter: Double = 7.0      // Cantering - vigorous effort
    static let gallop: Double = 8.5      // Galloping - very vigorous

    static func met(for gait: GaitType) -> Double {
        switch gait {
        case .stationary: return stationary
        case .walk: return walk
        case .trot: return trot
        case .canter: return canter
        case .gallop: return gallop
        }
    }

    /// Calculate calories burned
    /// Formula: Calories = MET × weight(kg) × duration(hours)
    static func calories(met: Double, weightKg: Double, durationSeconds: TimeInterval) -> Double {
        let hours = durationSeconds / 3600.0
        return met * weightKg * hours
    }
}
