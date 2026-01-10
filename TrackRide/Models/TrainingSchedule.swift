//
//  TrainingSchedule.swift
//  TrackRide
//
//  Training streak tracking and scheduled workout models
//

import Foundation
import SwiftData

// MARK: - Training Streak

/// Tracks training consistency and streaks across disciplines
@Model
final class TrainingStreak {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var totalTrainingDays: Int = 0
    var lastActivityDate: Date?

    init() {}

    /// Returns the effective current streak, accounting for missed days
    /// If more than one day has passed since last activity, streak should show as 0
    var effectiveCurrentStreak: Int {
        guard let lastDate = lastActivityDate else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDay = calendar.startOfDay(for: lastDate)
        let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

        // If same day or consecutive day, streak is valid
        if daysDiff <= 1 {
            return currentStreak
        }

        // More than 1 day missed - streak is broken
        return 0
    }

    /// Record an activity and update streak
    func recordActivity() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastDate = lastActivityDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysDiff == 0 {
                // Same day, already counted
                return
            } else if daysDiff == 1 {
                // Consecutive day, extend streak
                currentStreak += 1
            } else {
                // Streak broken, restart
                currentStreak = 1
            }
        } else {
            // First activity
            currentStreak = 1
        }

        totalTrainingDays += 1
        lastActivityDate = today

        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }
    }

    /// Icon based on current streak level
    var streakIcon: String {
        switch currentStreak {
        case 0:
            return "flame"
        case 1...6:
            return "flame.fill"
        case 7...13:
            return "flame.fill"
        case 14...29:
            return "flame.fill"
        default:
            return "flame.fill"
        }
    }

    /// Motivational message based on streak
    var streakMessage: String {
        switch currentStreak {
        case 0:
            return "Start your training streak today!"
        case 1:
            return "Great start! Keep it up tomorrow."
        case 2...6:
            return "Building momentum! \(7 - currentStreak) more days to a week."
        case 7:
            return "One week streak! Fantastic dedication."
        case 8...13:
            return "Over a week strong! Keep going."
        case 14:
            return "Two weeks! You're on fire!"
        case 15...29:
            return "Amazing consistency! Almost a month."
        case 30:
            return "One month streak! Incredible!"
        default:
            return "Legendary \(currentStreak) day streak!"
        }
    }
}

// MARK: - Scheduled Workout

/// Placeholder model for scheduled workouts (reserved for future use)
@Model
final class ScheduledWorkout {
    var id: UUID = UUID()
    var name: String = ""
    var scheduledDate: Date = Date()
    var isCompleted: Bool = false

    init() {}
}
