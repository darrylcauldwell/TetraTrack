//
//  TrainingSchedule.swift
//  TetraTrack
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

/// A scheduled training drill with recommendations
@Model
final class ScheduledWorkout {
    var id: UUID = UUID()
    var name: String = ""
    var scheduledDate: Date = Date()
    var isCompleted: Bool = false
    var completedDate: Date?

    /// Drill type to perform (stored as raw string for SwiftData)
    var drillTypeRaw: String = UnifiedDrillType.coreStability.rawValue

    /// Recommended intensity level (1-5)
    var recommendedIntensity: Int = 3

    /// Recommended duration in seconds
    var recommendedDuration: TimeInterval = 30

    /// AI-generated rationale for why this drill was scheduled
    var rationale: String = ""

    /// Priority level (1 = highest, 3 = lowest)
    var priority: Int = 2

    /// The skill domain this workout targets
    var targetDomainRaw: String = SkillDomain.stability.rawValue

    /// Order index for drag-and-drop within a day (lower = earlier)
    var orderIndex: Int = 0

    /// Whether this workout was manually added by user (vs auto-generated)
    var isManuallyAdded: Bool = false

    /// Whether this workout was skipped by the user
    var isSkipped: Bool = false

    init() {}

    /// Full initializer
    init(
        drillType: UnifiedDrillType,
        scheduledDate: Date,
        intensity: Int = 3,
        duration: TimeInterval = 30,
        rationale: String = "",
        priority: Int = 2,
        targetDomain: SkillDomain = .stability,
        orderIndex: Int = 0,
        isManuallyAdded: Bool = false
    ) {
        self.name = drillType.displayName
        self.drillTypeRaw = drillType.rawValue
        self.scheduledDate = scheduledDate
        self.recommendedIntensity = intensity
        self.recommendedDuration = duration
        self.rationale = rationale
        self.priority = priority
        self.targetDomainRaw = targetDomain.rawValue
        self.orderIndex = orderIndex
        self.isManuallyAdded = isManuallyAdded
    }

    // MARK: - Computed Properties

    var drillType: UnifiedDrillType {
        get { UnifiedDrillType(rawValue: drillTypeRaw) ?? .coreStability }
        set { drillTypeRaw = newValue.rawValue }
    }

    var targetDomain: SkillDomain {
        get { SkillDomain(rawValue: targetDomainRaw) ?? .stability }
        set { targetDomainRaw = newValue.rawValue }
    }

    var intensityDescription: String {
        switch recommendedIntensity {
        case 1: return "Recovery"
        case 2: return "Light"
        case 3: return "Moderate"
        case 4: return "Hard"
        case 5: return "Intense"
        default: return "Moderate"
        }
    }

    var formattedDuration: String {
        let minutes = Int(recommendedDuration) / 60
        let seconds = Int(recommendedDuration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(scheduledDate)
    }

    var isOverdue: Bool {
        !isCompleted && scheduledDate < Calendar.current.startOfDay(for: Date())
    }

    var isPending: Bool {
        !isCompleted && !isOverdue
    }

    /// Mark workout as completed
    func markCompleted() {
        isCompleted = true
        completedDate = Date()
    }

    /// Mark workout as skipped
    func markSkipped() {
        isSkipped = true
    }

    /// Move workout to a new date
    func moveToDate(_ newDate: Date) {
        scheduledDate = newDate
    }
}

// MARK: - Training Week Focus

/// Tracks the weekly focus area and rationale for training plans
@Model
final class TrainingWeekFocus {
    var id: UUID = UUID()

    /// Start date of the week (always a Monday)
    var weekStartDate: Date = Date()

    /// Primary focus domain for this week
    var focusDomainRaw: String = SkillDomain.stability.rawValue

    /// Secondary focus domain (optional)
    var secondaryFocusDomainRaw: String?

    /// Explanation of why this focus was selected
    var focusRationale: String = ""

    /// Key coaching insight driving this focus
    var coachingInsight: String = ""

    /// Target improvement areas (stored as comma-separated skill domain raw values)
    var targetAreasRaw: String = ""

    /// Whether this focus was set manually vs auto-generated
    var isManuallySet: Bool = false

    init() {}

    init(
        weekStartDate: Date,
        focusDomain: SkillDomain,
        secondaryFocusDomain: SkillDomain? = nil,
        focusRationale: String,
        coachingInsight: String = "",
        targetAreas: [SkillDomain] = [],
        isManuallySet: Bool = false
    ) {
        self.weekStartDate = weekStartDate
        self.focusDomainRaw = focusDomain.rawValue
        self.secondaryFocusDomainRaw = secondaryFocusDomain?.rawValue
        self.focusRationale = focusRationale
        self.coachingInsight = coachingInsight
        self.targetAreasRaw = targetAreas.map { $0.rawValue }.joined(separator: ",")
        self.isManuallySet = isManuallySet
    }

    // MARK: - Computed Properties

    var focusDomain: SkillDomain {
        get { SkillDomain(rawValue: focusDomainRaw) ?? .stability }
        set { focusDomainRaw = newValue.rawValue }
    }

    var secondaryFocusDomain: SkillDomain? {
        get {
            guard let raw = secondaryFocusDomainRaw else { return nil }
            return SkillDomain(rawValue: raw)
        }
        set { secondaryFocusDomainRaw = newValue?.rawValue }
    }

    var targetAreas: [SkillDomain] {
        get {
            guard !targetAreasRaw.isEmpty else { return [] }
            return targetAreasRaw.split(separator: ",").compactMap {
                SkillDomain(rawValue: String($0))
            }
        }
        set {
            targetAreasRaw = newValue.map { $0.rawValue }.joined(separator: ",")
        }
    }

    /// Week end date (Sunday of the same week)
    var weekEndDate: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: weekStartDate) ?? weekStartDate
    }

    /// Check if a date falls within this week
    func contains(date: Date) -> Bool {
        date >= weekStartDate && date <= weekEndDate
    }

    /// Formatted week range string
    var weekRangeDescription: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let startStr = formatter.string(from: weekStartDate)
        let endStr = formatter.string(from: weekEndDate)
        return "\(startStr) - \(endStr)"
    }
}

