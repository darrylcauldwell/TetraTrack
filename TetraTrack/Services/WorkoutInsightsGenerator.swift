//
//  WorkoutInsightsGenerator.swift
//  TetraTrack
//
//  Generates actionable insights from HealthKit workout data by comparing
//  against the user's recent workout history. No AI required — pure
//  deterministic analysis that works on all devices.
//

import HealthKit
import os

struct WorkoutInsight: Identifiable, Sendable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
    let sentiment: Sentiment

    enum Sentiment: Sendable {
        case positive   // green — improvement or good news
        case neutral    // blue — informational
        case attention  // orange — something to watch
    }
}

@MainActor
final class WorkoutInsightsGenerator {
    static let shared = WorkoutInsightsGenerator()

    private let healthStore = HKHealthStore()

    private init() {}

    /// Generate insights for a workout by comparing against recent history
    func generateInsights(
        for workout: ExternalWorkout,
        enrichment: WorkoutEnrichment
    ) async -> [WorkoutInsight] {
        var insights: [WorkoutInsight] = []

        // Fetch recent workouts of the same type for comparison
        let recentWorkouts = await fetchRecentWorkouts(
            activityType: workout.activityType,
            before: workout.startDate,
            limit: 10
        )

        // Pace insights (running, walking, hiking, cycling)
        if let distance = workout.totalDistance, distance > 0 {
            let currentPace = workout.duration / (distance / 1000) // sec/km
            insights.append(contentsOf: paceInsights(currentPace: currentPace, recentWorkouts: recentWorkouts))
        }

        // Distance insights
        if let distance = workout.totalDistance, distance > 0 {
            insights.append(contentsOf: distanceInsights(currentDistance: distance, recentWorkouts: recentWorkouts))
        }

        // Heart rate insights
        if !enrichment.heartRateSamples.isEmpty {
            insights.append(contentsOf: heartRateInsights(samples: enrichment.heartRateSamples, recentWorkouts: recentWorkouts))
        }

        // Walking-specific insights
        if let metrics = enrichment.walkingMetrics {
            insights.append(contentsOf: walkingInsights(metrics: metrics))
        }

        // Running-specific insights
        if let metrics = enrichment.runningMetrics {
            insights.append(contentsOf: runningInsights(metrics: metrics))
        }

        // Consistency insights
        insights.append(contentsOf: consistencyInsights(recentWorkouts: recentWorkouts, activityType: workout.activityType))

        // Elevation insights
        if let gain = enrichment.elevationGain, gain > 10 {
            insights.append(WorkoutInsight(
                icon: "mountain.2.fill",
                title: "Elevation Challenge",
                detail: String(format: "%.0f m of climbing — great for building strength and endurance.", gain),
                sentiment: .positive
            ))
        }

        return insights
    }

    // MARK: - Pace Insights

    private func paceInsights(currentPace: TimeInterval, recentWorkouts: [HKWorkout]) -> [WorkoutInsight] {
        var insights: [WorkoutInsight] = []

        let recentPaces = recentWorkouts.compactMap { workout -> TimeInterval? in
            guard let distance = workout.totalDistance?.doubleValue(for: .meter()), distance > 0 else { return nil }
            return workout.duration / (distance / 1000)
        }

        guard !recentPaces.isEmpty else { return insights }

        let averageRecentPace = recentPaces.reduce(0, +) / Double(recentPaces.count)
        let paceChange = ((averageRecentPace - currentPace) / averageRecentPace) * 100

        if paceChange > 5 {
            insights.append(WorkoutInsight(
                icon: "arrow.up.right",
                title: "Faster Than Usual",
                detail: String(format: "Your pace was %.0f%% faster than your recent average — strong session!", paceChange),
                sentiment: .positive
            ))
        } else if paceChange < -5 {
            insights.append(WorkoutInsight(
                icon: "tortoise.fill",
                title: "Easier Pace",
                detail: String(format: "%.0f%% slower than your recent average. Recovery sessions are important for avoiding burnout.", abs(paceChange)),
                sentiment: .neutral
            ))
        } else {
            insights.append(WorkoutInsight(
                icon: "equal.circle.fill",
                title: "Consistent Pace",
                detail: "Right in line with your recent average — great consistency.",
                sentiment: .positive
            ))
        }

        // Personal best check
        if let bestPace = recentPaces.min(), currentPace < bestPace {
            insights.append(WorkoutInsight(
                icon: "star.fill",
                title: "New Personal Best Pace!",
                detail: String(format: "Your fastest pace in the last %d sessions.", recentPaces.count),
                sentiment: .positive
            ))
        }

        return insights
    }

    // MARK: - Distance Insights

    private func distanceInsights(currentDistance: Double, recentWorkouts: [HKWorkout]) -> [WorkoutInsight] {
        var insights: [WorkoutInsight] = []

        let recentDistances = recentWorkouts.compactMap { $0.totalDistance?.doubleValue(for: .meter()) }.filter { $0 > 0 }

        guard !recentDistances.isEmpty else { return insights }

        let averageDistance = recentDistances.reduce(0, +) / Double(recentDistances.count)
        let distanceChange = ((currentDistance - averageDistance) / averageDistance) * 100

        if distanceChange > 20 {
            insights.append(WorkoutInsight(
                icon: "figure.walk.motion",
                title: "Longer Session",
                detail: String(format: "%.0f%% further than your recent average — pushing your limits.", distanceChange),
                sentiment: .positive
            ))
        }

        // Longest ever check
        if let maxDistance = recentDistances.max(), currentDistance > maxDistance {
            insights.append(WorkoutInsight(
                icon: "trophy.fill",
                title: "Longest Session!",
                detail: String(format: "Your furthest in the last %d sessions — %.2f km.", recentDistances.count, currentDistance / 1000),
                sentiment: .positive
            ))
        }

        return insights
    }

    // MARK: - Heart Rate Insights

    private func heartRateInsights(samples: [WorkoutEnrichment.HeartRateSamplePoint], recentWorkouts: [HKWorkout]) -> [WorkoutInsight] {
        var insights: [WorkoutInsight] = []
        let bpms = samples.map(\.bpm)

        guard let avgHR = bpms.isEmpty ? nil : bpms.reduce(0, +) / Double(bpms.count),
              let maxHR = bpms.max() else { return insights }

        // HR variability during workout (effort distribution)
        let hrRange = maxHR - (bpms.min() ?? 0)
        if hrRange > 50 {
            insights.append(WorkoutInsight(
                icon: "waveform.path.ecg",
                title: "Variable Intensity",
                detail: String(format: "Your HR ranged %.0f bpm — this interval-style effort builds both aerobic and anaerobic fitness.", hrRange),
                sentiment: .neutral
            ))
        } else if hrRange < 20 && bpms.count > 10 {
            insights.append(WorkoutInsight(
                icon: "heart.fill",
                title: "Steady Effort",
                detail: String(format: "Your HR stayed within a %.0f bpm range — great for building aerobic base.", hrRange),
                sentiment: .positive
            ))
        }

        // Max HR warning
        if maxHR > 190 {
            insights.append(WorkoutInsight(
                icon: "exclamationmark.heart.fill",
                title: "High Heart Rate",
                detail: String(format: "Your max HR hit %.0f bpm. Make sure you're recovering well between intense sessions.", maxHR),
                sentiment: .attention
            ))
        }

        return insights
    }

    // MARK: - Walking Insights

    private func walkingInsights(metrics: WorkoutEnrichment.WalkingMetrics) -> [WorkoutInsight] {
        var insights: [WorkoutInsight] = []

        if let asymmetry = metrics.asymmetryPercent {
            if asymmetry < 5 {
                insights.append(WorkoutInsight(
                    icon: "checkmark.seal.fill",
                    title: "Excellent Symmetry",
                    detail: String(format: "%.1f%% asymmetry — your gait is well balanced.", asymmetry),
                    sentiment: .positive
                ))
            } else if asymmetry > 10 {
                insights.append(WorkoutInsight(
                    icon: "arrow.left.arrow.right",
                    title: "Gait Asymmetry",
                    detail: String(format: "%.1f%% asymmetry detected. If this persists, consider consulting a physio.", asymmetry),
                    sentiment: .attention
                ))
            }
        }

        if let steadiness = metrics.steadiness {
            if steadiness > 80 {
                insights.append(WorkoutInsight(
                    icon: "figure.stand",
                    title: "Excellent Steadiness",
                    detail: String(format: "%.0f%% walking steadiness — your balance and coordination are strong.", steadiness),
                    sentiment: .positive
                ))
            } else if steadiness < 50 {
                insights.append(WorkoutInsight(
                    icon: "exclamationmark.triangle.fill",
                    title: "Steadiness Below Average",
                    detail: "Your walking steadiness is lower than usual. Fatigue or uneven terrain may be a factor.",
                    sentiment: .attention
                ))
            }
        }

        return insights
    }

    // MARK: - Running Insights

    private func runningInsights(metrics: WorkoutEnrichment.RunningMetrics) -> [WorkoutInsight] {
        var insights: [WorkoutInsight] = []

        if let gct = metrics.averageGroundContactTime {
            if gct < 250 {
                insights.append(WorkoutInsight(
                    icon: "hare.fill",
                    title: "Quick Turnover",
                    detail: String(format: "%.0f ms ground contact — efficient running form.", gct),
                    sentiment: .positive
                ))
            } else if gct > 300 {
                insights.append(WorkoutInsight(
                    icon: "figure.run",
                    title: "Longer Ground Contact",
                    detail: String(format: "%.0f ms ground contact time. Cadence drills can help improve this.", gct),
                    sentiment: .neutral
                ))
            }
        }

        if let vo = metrics.averageVerticalOscillation {
            if vo > 10 {
                insights.append(WorkoutInsight(
                    icon: "arrow.up.arrow.down",
                    title: "High Bounce",
                    detail: String(format: "%.1f cm vertical oscillation. Try focusing on forward propulsion to improve efficiency.", vo),
                    sentiment: .attention
                ))
            } else if vo < 7 {
                insights.append(WorkoutInsight(
                    icon: "checkmark.seal.fill",
                    title: "Smooth Running",
                    detail: String(format: "%.1f cm vertical oscillation — efficient, low-bounce form.", vo),
                    sentiment: .positive
                ))
            }
        }

        if let power = metrics.averagePower, let cadence = metrics.averageCadence {
            insights.append(WorkoutInsight(
                icon: "bolt.fill",
                title: "Power Output",
                detail: String(format: "%.0f W average power at %.0f spm cadence.", power, cadence),
                sentiment: .neutral
            ))
        }

        return insights
    }

    // MARK: - Consistency Insights

    private func consistencyInsights(recentWorkouts: [HKWorkout], activityType: HKWorkoutActivityType) -> [WorkoutInsight] {
        var insights: [WorkoutInsight] = []

        // Count sessions in the last 7 days
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let thisWeek = recentWorkouts.filter { $0.startDate >= weekAgo }.count + 1 // +1 for current

        if thisWeek >= 3 {
            insights.append(WorkoutInsight(
                icon: "flame.fill",
                title: "Strong Week",
                detail: "\(thisWeek) sessions this week — great training consistency!",
                sentiment: .positive
            ))
        }

        // Streak check
        if recentWorkouts.count >= 2 {
            let sortedDates = recentWorkouts.map(\.startDate).sorted(by: >)
            var streak = 1
            for i in 0..<(sortedDates.count - 1) {
                let gap = sortedDates[i].timeIntervalSince(sortedDates[i + 1])
                if gap < 86400 * 3 { // within 3 days
                    streak += 1
                } else {
                    break
                }
            }
            if streak >= 3 {
                insights.append(WorkoutInsight(
                    icon: "calendar.badge.checkmark",
                    title: "\(streak)-Session Streak",
                    detail: "You've been training consistently — keep the momentum going!",
                    sentiment: .positive
                ))
            }
        }

        return insights
    }

    // MARK: - HealthKit Queries

    private func fetchRecentWorkouts(activityType: HKWorkoutActivityType, before date: Date, limit: Int) async -> [HKWorkout] {
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: date) ?? date

        let typePredicate = HKQuery.predicateForWorkouts(with: activityType)
        let datePredicate = HKQuery.predicateForSamples(withStart: threeMonthsAgo, end: date, options: .strictEndDate)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [typePredicate, datePredicate])

        let descriptor = HKSampleQueryDescriptor<HKWorkout>(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: limit
        )

        do {
            return try await descriptor.result(for: healthStore)
        } catch {
            Log.health.error("Failed to fetch recent workouts: \(error.localizedDescription)")
            return []
        }
    }
}
