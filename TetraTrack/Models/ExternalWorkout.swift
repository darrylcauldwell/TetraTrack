//
//  ExternalWorkout.swift
//  TetraTrack
//
//  Lightweight struct representing a workout from an external app (Apple Fitness, Garmin, Strava, etc.)
//  NOT a SwiftData model — queried on-demand from HealthKit.
//

import Foundation
import HealthKit

struct ExternalWorkout: Identifiable, Hashable {
    let id: UUID
    let activityType: HKWorkoutActivityType
    let sourceName: String
    let sourceBundleIdentifier: String
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let totalDistance: Double?       // meters
    let totalEnergyBurned: Double?  // kcal
    let averageHeartRate: Double?
    let hasRoute: Bool
    var notes: String? = nil

    var activityName: String {
        switch activityType {
        case .running: return "Run"
        case .walking: return "Walk"
        case .cycling: return "Cycle"
        case .swimming: return "Swim"
        case .hiking: return "Hike"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Strength"
        case .traditionalStrengthTraining: return "Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .equestrianSports: return "Ride"
        case .crossTraining: return "Cross Training"
        case .elliptical: return "Elliptical"
        case .rowing: return "Row"
        case .coreTraining: return "Core"
        case .pilates: return "Pilates"
        case .dance: return "Dance"
        case .cooldown: return "Cooldown"
        case .mixedCardio: return "Cardio"
        default: return "Workout"
        }
    }

    var activityIcon: String {
        switch activityType {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .hiking: return "figure.hiking"
        case .yoga: return "figure.yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "figure.strengthtraining.functional"
        case .highIntensityIntervalTraining: return "flame.fill"
        case .equestrianSports: return "figure.equestrian.sports"
        case .elliptical: return "figure.elliptical"
        case .rowing: return "figure.rower"
        case .coreTraining: return "figure.core.training"
        case .pilates: return "figure.pilates"
        case .dance: return "figure.dance"
        case .cooldown: return "figure.cooldown"
        case .mixedCardio: return "figure.mixed.cardio"
        default: return "figure.mixed.cardio"
        }
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(minutes)m \(seconds)s"
    }

    var formattedDistance: String? {
        guard let distance = totalDistance, distance > 0 else { return nil }
        if distance >= 1000 {
            return String(format: "%.2f km", distance / 1000)
        }
        return String(format: "%.0f m", distance)
    }

    var formattedCalories: String? {
        guard let cal = totalEnergyBurned, cal > 0 else { return nil }
        return String(format: "%.0f kcal", cal)
    }
}
