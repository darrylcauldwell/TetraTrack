//
//  TrainingPlanService.swift
//  TetraTrack
//
//  Generates intelligent training plans based on athlete profile,
//  identified weaknesses, and optimal drill spacing.
//

import Foundation
import SwiftData
import Observation

/// Service for generating and managing training plans
@Observable
final class TrainingPlanService {

    // MARK: - Configuration

    /// Minimum days between same drill type
    private let minDrillSpacing: Int = 2

    /// Maximum drills per day
    private let maxDrillsPerDay: Int = 3

    /// Target weekly drill sessions
    private let targetWeeklyDrills: Int = 5

    /// Coaching engine for weakness identification
    private let coachingEngine = CoachingEngine()

    // MARK: - Plan Generation

    /// Generate a weekly training plan based on athlete profile and recent activity
    /// - Parameters:
    ///   - profile: The athlete's profile with skill scores
    ///   - recentSessions: Recent drill sessions for spacing calculation
    ///   - context: SwiftData model context
    ///   - weekStart: Optional start date of the week (defaults to Monday of current week)
    /// - Returns: Array of scheduled workouts for the week
    func generateWeeklyPlan(
        profile: AthleteProfile,
        recentSessions: [UnifiedDrillSession],
        context: ModelContext,
        weekStart: Date? = nil
    ) -> [ScheduledWorkout] {
        var workouts: [ScheduledWorkout] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Calculate week start (Monday) if not provided
        let startDate: Date
        if let providedStart = weekStart {
            startDate = providedStart
        } else {
            // Find Monday of current week
            let weekday = calendar.component(.weekday, from: today)
            let daysToMonday = (weekday == 1) ? -6 : (2 - weekday)
            startDate = calendar.date(byAdding: .day, value: daysToMonday, to: today) ?? today
        }

        // First, try to get weaknesses from CoachingEngine (drill history based)
        let coachingWeaknesses = coachingEngine.identifyWeaknesses(drillHistory: recentSessions)

        // Convert coaching weaknesses to our assessment format
        var weaknesses: [WeaknessAssessment]
        if !coachingWeaknesses.isEmpty {
            // Use coaching engine data - prioritizes declining/undertrained drills
            weaknesses = coachingWeaknesses.compactMap { weakness -> WeaknessAssessment? in
                // Find matching drill type
                let rawValue = weakness.recommendedDrills.first ?? ""
                guard let drillType = UnifiedDrillType(rawValue: rawValue) else {
                    return nil
                }
                let domain = domainForDrill(drillType)
                let priority = weakness.severity > 0.5 ? 1 : (weakness.severity > 0.25 ? 2 : 3)
                return WeaknessAssessment(
                    domain: domain,
                    currentScore: (1.0 - weakness.severity) * 100,
                    trend: -1,  // Coaching weaknesses imply decline
                    priority: priority,
                    recommendedDrills: weakness.recommendedDrills.compactMap { UnifiedDrillType(rawValue: $0) }
                )
            }
        } else {
            // Fall back to profile-based analysis for new users
            weaknesses = identifyWeaknesses(profile: profile)
        }

        // Additional fallback: if coaching weaknesses exist but all conversions failed, use profile
        if weaknesses.isEmpty {
            weaknesses = identifyWeaknesses(profile: profile)
        }

        let recentDrillTypes = Set(recentSessions.prefix(7).map { $0.drillType })

        // Generate plan for the week (Mon-Sun)
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else {
                continue
            }

            // Skip days that have already passed (only schedule from today onwards)
            if date < today {
                continue
            }

            // Determine drills for this day based on weaknesses and spacing
            let dailyDrills = selectDrillsForDay(
                date: date,
                weaknesses: weaknesses,
                existingWorkouts: workouts,
                recentDrillTypes: recentDrillTypes
            )

            workouts.append(contentsOf: dailyDrills)
        }

        // Save to database
        for workout in workouts {
            context.insert(workout)
        }

        return workouts
    }

    /// Map a drill type to its primary skill domain
    private func domainForDrill(_ drillType: UnifiedDrillType) -> SkillDomain {
        switch drillType {
        // Stability drills
        case .coreStability, .riderStillness, .steadyHold, .standingBalance,
             .runningCoreStability, .swimmingCoreStability, .streamlinePosition, .posturalDrift:
            return .stability

        // Balance drills
        case .balanceBoard, .heelPosition, .twoPoint, .singleLegBalance, .stirrupPressure:
            return .balance

        // Symmetry/Mobility drills
        case .hipMobility, .runningHipMobility, .shoulderMobility:
            return .symmetry

        // Rhythm drills
        case .postingRhythm, .cadenceTraining, .breathingRhythm, .kickEfficiency:
            return .rhythm

        // Endurance drills
        case .stressInoculation, .plyometrics, .extendedSeatHold:
            return .endurance

        // Calmness drills
        case .boxBreathing, .breathingPatterns, .dryFire, .mountedBreathing:
            return .calmness

        // Reaction drills -> map to rhythm for variety
        case .reactionTime, .splitTime, .recoilControl:
            return .rhythm
        }
    }

    /// Identify skill domains that need focus
    private func identifyWeaknesses(profile: AthleteProfile) -> [WeaknessAssessment] {
        var assessments: [WeaknessAssessment] = []

        // Check if profile has any meaningful data
        let hasData = profile.hasData

        for domain in SkillDomain.allCases {
            let score = profile.score(for: domain)
            let trend = profile.trend(for: domain)

            // Priority based on score and trend
            let priority: Int
            let needsWork: Bool

            if !hasData {
                // New user with no data - create balanced starter plan
                priority = 2
                needsWork = true
            } else if score < 50 {
                priority = 1
                needsWork = true
            } else if score < 70 || trend == -1 {
                priority = 2
                needsWork = true
            } else if trend == 0 && score < 85 {
                priority = 3
                needsWork = true
            } else {
                priority = 4
                needsWork = false
            }

            if needsWork {
                assessments.append(WeaknessAssessment(
                    domain: domain,
                    currentScore: score,
                    trend: trend,
                    priority: priority,
                    recommendedDrills: drillsForDomain(domain)
                ))
            }
        }

        // Fallback: If no weaknesses identified, create a balanced starter plan
        if assessments.isEmpty {
            for domain in SkillDomain.allCases {
                assessments.append(WeaknessAssessment(
                    domain: domain,
                    currentScore: 50,
                    trend: 0,
                    priority: 2,
                    recommendedDrills: drillsForDomain(domain)
                ))
            }
        }

        return assessments.sorted { $0.priority < $1.priority }
    }

    /// Get recommended drills for a skill domain
    private func drillsForDomain(_ domain: SkillDomain) -> [UnifiedDrillType] {
        switch domain {
        case .stability:
            return [.coreStability, .riderStillness, .steadyHold, .standingBalance]
        case .balance:
            return [.balanceBoard, .heelPosition, .standingBalance, .twoPoint]
        case .symmetry:
            return [.heelPosition, .balanceBoard, .hipMobility]
        case .rhythm:
            return [.postingRhythm, .cadenceTraining, .breathingRhythm]
        case .endurance:
            return [.posturalDrift, .stressInoculation, .twoPoint]
        case .calmness:
            return [.breathingRhythm, .stressInoculation, .steadyHold]
        }
    }

    /// Select drills for a specific day
    private func selectDrillsForDay(
        date: Date,
        weaknesses: [WeaknessAssessment],
        existingWorkouts: [ScheduledWorkout],
        recentDrillTypes: Set<UnifiedDrillType>
    ) -> [ScheduledWorkout] {
        var dailyWorkouts: [ScheduledWorkout] = []
        var usedDomains: Set<SkillDomain> = []

        // Prioritize weakest areas
        for weakness in weaknesses {
            guard dailyWorkouts.count < maxDrillsPerDay else { break }
            guard !usedDomains.contains(weakness.domain) else { continue }

            // Find a drill that hasn't been done recently
            for drillType in weakness.recommendedDrills {
                // Check spacing
                if !hasSufficientSpacing(drillType: drillType, date: date, existingWorkouts: existingWorkouts) {
                    continue
                }

                // Create workout
                let workout = createWorkout(
                    drillType: drillType,
                    date: date,
                    weakness: weakness
                )
                dailyWorkouts.append(workout)
                usedDomains.insert(weakness.domain)
                break
            }
        }

        return dailyWorkouts
    }

    /// Check if there's sufficient spacing from previous sessions of the same drill
    private func hasSufficientSpacing(
        drillType: UnifiedDrillType,
        date: Date,
        existingWorkouts: [ScheduledWorkout]
    ) -> Bool {
        let calendar = Calendar.current
        let recentSame = existingWorkouts.filter {
            $0.drillType == drillType &&
            abs(calendar.dateComponents([.day], from: $0.scheduledDate, to: date).day ?? 0) < minDrillSpacing
        }
        return recentSame.isEmpty
    }

    /// Create a scheduled workout with rationale
    private func createWorkout(
        drillType: UnifiedDrillType,
        date: Date,
        weakness: WeaknessAssessment
    ) -> ScheduledWorkout {
        // Determine intensity based on weakness severity
        let intensity: Int
        if weakness.priority == 1 {
            intensity = 3 // Moderate - build foundation
        } else if weakness.trend == -1 {
            intensity = 4 // Hard - reverse decline
        } else {
            intensity = 3 // Moderate - maintain progress
        }

        // Generate rationale
        let rationale = generateRationale(weakness: weakness, drillType: drillType)

        // Determine duration based on drill type
        let duration: TimeInterval
        switch drillType {
        case .coreStability, .steadyHold, .standingBalance:
            duration = weakness.priority == 1 ? 30 : 45
        case .postingRhythm, .cadenceTraining:
            duration = 60
        case .stressInoculation, .posturalDrift:
            duration = 90
        default:
            duration = 30
        }

        return ScheduledWorkout(
            drillType: drillType,
            scheduledDate: date,
            intensity: intensity,
            duration: duration,
            rationale: rationale,
            priority: weakness.priority,
            targetDomain: weakness.domain
        )
    }

    /// Generate human-readable rationale for the workout
    private func generateRationale(weakness: WeaknessAssessment, drillType: UnifiedDrillType) -> String {
        let domainName = weakness.domain.displayName.lowercased()

        // New user with no score data
        if weakness.currentScore == 0 || weakness.currentScore == 50 {
            let starterMessages = [
                "Start building your \(domainName) foundation. \(drillType.displayName) is perfect for beginners.",
                "Develop your \(domainName) skills with this essential drill.",
                "Begin your \(domainName) training journey with \(drillType.displayName).",
                "\(drillType.displayName) establishes core \(domainName) patterns for all disciplines."
            ]
            return starterMessages[abs(drillType.rawValue.hashValue) % starterMessages.count]
        }

        let scoreText = String(format: "%.0f", weakness.currentScore)
        let trendText: String
        switch weakness.trend {
        case 1: trendText = "improving"
        case -1: trendText = "declining"
        default: trendText = "stable"
        }

        if weakness.priority == 1 {
            return "Your \(domainName) score is \(scoreText), which needs focused attention. \(drillType.displayName) directly targets this weakness."
        } else if weakness.trend == -1 {
            return "Your \(domainName) has been \(trendText) recently (currently \(scoreText)). This drill helps reverse the decline."
        } else {
            return "Building on your \(domainName) foundation (score: \(scoreText), \(trendText)). Consistent practice maintains progress."
        }
    }

    // MARK: - Plan Management

    /// Clear existing unfinished workouts and regenerate plan
    /// - Parameters:
    ///   - context: SwiftData model context
    ///   - profile: Athlete profile for weakness assessment
    ///   - recentSessions: Recent drill sessions for trend analysis
    ///   - weekStart: Start of the week (Monday) to generate plan for
    func regeneratePlan(
        context: ModelContext,
        profile: AthleteProfile,
        recentSessions: [UnifiedDrillSession],
        weekStart: Date? = nil
    ) throws {
        // Calculate week boundaries
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Use provided weekStart or calculate Monday of current week
        let effectiveWeekStart: Date
        if let start = weekStart {
            effectiveWeekStart = start
        } else {
            let weekday = calendar.component(.weekday, from: today)
            let daysToMonday = (weekday == 1) ? -6 : (2 - weekday)
            effectiveWeekStart = calendar.date(byAdding: .day, value: daysToMonday, to: today) ?? today
        }

        let weekEnd = calendar.date(byAdding: .day, value: 7, to: effectiveWeekStart) ?? today

        // Delete incomplete workouts for this week only
        let descriptor = FetchDescriptor<ScheduledWorkout>(
            predicate: #Predicate { workout in
                !workout.isCompleted && workout.scheduledDate >= effectiveWeekStart && workout.scheduledDate < weekEnd
            }
        )

        let existingWorkouts = try context.fetch(descriptor)
        for workout in existingWorkouts {
            context.delete(workout)
        }

        // Generate new plan for this week
        _ = generateWeeklyPlan(
            profile: profile,
            recentSessions: recentSessions,
            context: context,
            weekStart: effectiveWeekStart
        )
    }

    /// Get workouts for a specific date range
    func fetchWorkouts(context: ModelContext, from startDate: Date, to endDate: Date) throws -> [ScheduledWorkout] {
        let descriptor = FetchDescriptor<ScheduledWorkout>(
            predicate: #Predicate { workout in
                workout.scheduledDate >= startDate && workout.scheduledDate <= endDate
            },
            sortBy: [SortDescriptor(\.scheduledDate), SortDescriptor(\.priority)]
        )
        return try context.fetch(descriptor)
    }

    /// Get today's workouts
    func fetchTodaysWorkouts(context: ModelContext) throws -> [ScheduledWorkout] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        return try fetchWorkouts(context: context, from: startOfDay, to: endOfDay)
    }

    /// Get this week's workouts
    func fetchWeekWorkouts(context: ModelContext) throws -> [ScheduledWorkout] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: today) ?? today

        return try fetchWorkouts(context: context, from: today, to: endOfWeek)
    }
}

// MARK: - Supporting Types

/// Assessment of a skill domain weakness
struct WeaknessAssessment {
    let domain: SkillDomain
    let currentScore: Double
    let trend: Int // -1 = declining, 0 = stable, 1 = improving
    let priority: Int // 1 = highest priority
    let recommendedDrills: [UnifiedDrillType]
}

// MARK: - WeeklyPlanSummary

/// Summary of a weekly training plan
struct WeeklyPlanSummary {
    let totalWorkouts: Int
    let completedWorkouts: Int
    let upcomingWorkouts: Int
    let overdueWorkouts: Int
    let focusDomains: [SkillDomain]

    var completionPercentage: Double {
        guard totalWorkouts > 0 else { return 0 }
        return Double(completedWorkouts) / Double(totalWorkouts) * 100
    }

    var progressDescription: String {
        if completedWorkouts == 0 {
            return "Start your week with the first workout!"
        } else if completedWorkouts == totalWorkouts {
            return "Great job! You've completed all scheduled workouts."
        } else if overdueWorkouts > 0 {
            return "You have \(overdueWorkouts) overdue workout\(overdueWorkouts > 1 ? "s" : ""). Catch up when you can!"
        } else {
            return "\(completedWorkouts) of \(totalWorkouts) workouts complete. Keep it up!"
        }
    }
}
