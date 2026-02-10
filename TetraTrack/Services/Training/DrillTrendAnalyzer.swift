//
//  DrillTrendAnalyzer.swift
//  TetraTrack
//
//  Analyzes drill session history to detect trends and identify weaknesses
//

import Foundation
import SwiftData

/// Detailed trend analysis result with concrete deltas
struct DetailedTrendAnalysis {
    let currentAverage: Double
    let previousAverage: Double
    let absoluteDelta: Double
    let percentageChange: Double
    let bestScore: Double
    let worstScore: Double
    let totalSessions: Int
    let trendDirection: TrendDirection

    /// Formatted delta text like "+15 pts (+12%)"
    var deltaText: String {
        let sign = absoluteDelta >= 0 ? "+" : ""
        let pctSign = percentageChange >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.0f", absoluteDelta)) pts (\(pctSign)\(String(format: "%.0f", percentageChange))%)"
    }

    /// Short direction indicator
    var directionIndicator: String {
        switch trendDirection {
        case .improving: return "Improving"
        case .declining: return "Declining"
        case .stable: return "Stable"
        case .insufficient: return "Need data"
        }
    }
}

/// Trend direction with percentage change
enum TrendDirection {
    case improving(percentage: Double)
    case declining(percentage: Double)
    case stable
    case insufficient  // Not enough data

    var description: String {
        switch self {
        case .improving(let pct):
            return "Improving \(String(format: "%.0f", pct))%"
        case .declining(let pct):
            return "Declining \(String(format: "%.0f", pct))%"
        case .stable:
            return "Stable"
        case .insufficient:
            return "Need more data"
        }
    }

    var isPositive: Bool {
        if case .improving = self { return true }
        return false
    }

    var isInsufficient: Bool {
        if case .insufficient = self { return true }
        return false
    }
}

/// Analyzer for detecting trends and insights in drill performance
@Observable
final class DrillTrendAnalyzer {

    // MARK: - Configuration

    /// Minimum sessions required for trend analysis
    private let minimumSessionsForTrend = 3

    /// Threshold for "stable" classification (percentage change)
    private let stableThreshold: Double = 5.0

    // MARK: - Unified Drill Trends

    /// Calculate week-over-week trend for a unified drill type
    func weekOverWeekTrend(
        for drillType: UnifiedDrillType,
        sessions: [UnifiedDrillSession]
    ) -> TrendDirection {
        let filtered = sessions.filter { $0.drillType == drillType }
        return calculateTrendFromSessions(filtered.map { ($0.startDate, $0.score) })
    }

    /// Calculate trend for a movement category
    func categoryTrend(
        for category: MovementCategory,
        sessions: [UnifiedDrillSession]
    ) -> TrendDirection {
        let filtered = sessions.filter { $0.primaryCategory == category }
        return calculateTrendFromSessions(filtered.map { ($0.startDate, $0.score) })
    }

    /// Calculate trend for a discipline
    func disciplineTrend(
        for discipline: Discipline,
        sessions: [UnifiedDrillSession]
    ) -> TrendDirection {
        let filtered: [UnifiedDrillSession]
        if discipline == .all {
            filtered = sessions
        } else {
            filtered = sessions.filter { $0.primaryDiscipline == discipline }
        }
        return calculateTrendFromSessions(filtered.map { ($0.startDate, $0.score) })
    }

    /// Find best performance in a time period for a unified drill type
    func bestPerformance(
        for drillType: UnifiedDrillType,
        sessions: [UnifiedDrillSession],
        in period: DateInterval
    ) -> UnifiedDrillSession? {
        sessions
            .filter { $0.drillType == drillType && period.contains($0.startDate) }
            .max { $0.score < $1.score }
    }

    /// Find the strongest drill type based on recent sessions
    func strongestDrill(sessions: [UnifiedDrillSession], discipline: Discipline? = nil) -> UnifiedDrillType? {
        var filteredSessions = Array(sessions.suffix(20))
        if let discipline = discipline, discipline != .all {
            filteredSessions = filteredSessions.filter { $0.primaryDiscipline == discipline }
        }

        var typeScores: [UnifiedDrillType: [Double]] = [:]
        for session in filteredSessions {
            typeScores[session.drillType, default: []].append(session.score)
        }

        return typeScores
            .filter { $0.value.count >= 2 }
            .max { lhs, rhs in
                let lhsAvg = lhs.value.reduce(0, +) / Double(lhs.value.count)
                let rhsAvg = rhs.value.reduce(0, +) / Double(rhs.value.count)
                return lhsAvg < rhsAvg
            }?.key
    }

    /// Find the weakest drill type that needs more practice
    func weakestDrill(sessions: [UnifiedDrillSession], discipline: Discipline? = nil) -> UnifiedDrillType? {
        var filteredSessions = Array(sessions.suffix(20))
        if let discipline = discipline, discipline != .all {
            filteredSessions = filteredSessions.filter { $0.primaryDiscipline == discipline }
        }

        var typeScores: [UnifiedDrillType: [Double]] = [:]
        for session in filteredSessions {
            typeScores[session.drillType, default: []].append(session.score)
        }

        return typeScores
            .filter { $0.value.count >= 2 }
            .min { lhs, rhs in
                let lhsAvg = lhs.value.reduce(0, +) / Double(lhs.value.count)
                let rhsAvg = rhs.value.reduce(0, +) / Double(rhs.value.count)
                return lhsAvg < rhsAvg
            }?.key
    }

    /// Identify weakest subscore across recent sessions
    func weakestSubscore(sessions: [UnifiedDrillSession]) -> String? {
        let recentSessions = sessions.suffix(10)
        guard !recentSessions.isEmpty else { return nil }

        let count = Double(recentSessions.count)
        let subscores = [
            ("Stability", recentSessions.map(\.stabilityScore).reduce(0, +) / count),
            ("Symmetry", recentSessions.map(\.symmetryScore).reduce(0, +) / count),
            ("Endurance", recentSessions.map(\.enduranceScore).reduce(0, +) / count),
            ("Coordination", recentSessions.map(\.coordinationScore).reduce(0, +) / count),
            ("Breathing", recentSessions.map(\.breathingScore).reduce(0, +) / count),
            ("Rhythm", recentSessions.map(\.rhythmScore).reduce(0, +) / count),
            ("Reaction", recentSessions.map(\.reactionScore).reduce(0, +) / count)
        ].filter { $0.1 > 0 }  // Only include subscores that have data

        return subscores.min { $0.1 < $1.1 }?.0
    }

    /// Get overall improvement percentage over a time period
    func overallImprovement(
        sessions: [UnifiedDrillSession],
        days: Int = 30
    ) -> Double? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let midpoint = Calendar.current.date(byAdding: .day, value: -days / 2, to: Date()) ?? Date()

        let oldScores = sessions
            .filter { $0.startDate >= cutoff && $0.startDate < midpoint }
            .map(\.score)
        let newScores = sessions
            .filter { $0.startDate >= midpoint }
            .map(\.score)

        guard !oldScores.isEmpty, !newScores.isEmpty else { return nil }

        let oldAvg = oldScores.reduce(0, +) / Double(oldScores.count)
        let newAvg = newScores.reduce(0, +) / Double(newScores.count)

        guard oldAvg > 0 else { return nil }

        return ((newAvg - oldAvg) / oldAvg) * 100
    }

    // MARK: - Cross-Discipline Insights

    /// Generate cross-discipline insights about training transfer
    func generateCrossDisciplineInsights(sessions: [UnifiedDrillSession]) -> String {
        var insights: [String] = []

        // Count universal drills
        let universalDrills = sessions.filter { $0.benefitsDisciplines.count == 4 }
        if universalDrills.count >= 5 {
            insights.append("Your \(universalDrills.count) core stability and breathing sessions benefit all four disciplines.")
        }

        // Check for cross-training opportunities
        let ridingCount = sessions.filter { $0.primaryDiscipline == .riding }.count
        let shootingCount = sessions.filter { $0.primaryDiscipline == .shooting }.count
        let runningCount = sessions.filter { $0.primaryDiscipline == .running }.count
        let swimmingCount = sessions.filter { $0.primaryDiscipline == .swimming }.count

        let counts = [ridingCount, shootingCount, runningCount, swimmingCount]
        let maxCount = counts.max() ?? 0
        let minCount = counts.min() ?? 0

        if maxCount > 0 && minCount == 0 {
            let neglected = [
                ("Riding", ridingCount),
                ("Shooting", shootingCount),
                ("Running", runningCount),
                ("Swimming", swimmingCount)
            ].filter { $0.1 == 0 }.map { $0.0 }

            if !neglected.isEmpty {
                insights.append("Consider adding \(neglected.joined(separator: " and ")) drills for more balanced training.")
            }
        }

        // Category-based transfer insights
        let balanceSessions = sessions.filter { $0.primaryCategory == .balance }
        if balanceSessions.count >= 3 {
            let avgScore = balanceSessions.map(\.score).reduce(0, +) / Double(balanceSessions.count)
            if avgScore >= 80 {
                insights.append("Your balance work transfers between riding and shooting platforms.")
            }
        }

        let breathingSessions = sessions.filter { $0.primaryCategory == .breathing }
        if breathingSessions.count >= 3 {
            insights.append("Breathing control from drills improves performance in all disciplines.")
        }

        if insights.isEmpty {
            return "Complete more drills across different categories to unlock cross-discipline insights."
        }

        return insights.joined(separator: " ")
    }

    /// Generate a human-readable insight summary for unified sessions with concrete deltas
    func generateInsightSummary(sessions: [UnifiedDrillSession]) -> String {
        var insights: [String] = []

        // Check overall improvement with concrete numbers
        if let improvement = overallImprovement(sessions: sessions) {
            let recentAvg = calculateRecentAverage(sessions: sessions)
            if improvement > 10 {
                insights.append("Your overall drill performance has improved +\(String(format: "%.0f", improvement))% recently (now averaging \(String(format: "%.0f", recentAvg)) pts).")
            } else if improvement < -10 {
                insights.append("Your drill scores have declined \(String(format: "%.0f", abs(improvement)))% - now averaging \(String(format: "%.0f", recentAvg)) pts. Consider focusing on fundamentals.")
            }
        }

        // Check for weaknesses with specific scores
        if let weakDrill = weakestDrill(sessions: sessions) {
            let avgScore = averageScore(for: weakDrill, sessions: sessions)
            insights.append("\(weakDrill.displayName) (avg: \(String(format: "%.0f", avgScore)) pts) needs more practice - it's your lowest scoring drill.")
        }

        // Check for strengths with specific scores
        if let strongDrill = strongestDrill(sessions: sessions) {
            let avgScore = averageScore(for: strongDrill, sessions: sessions)
            insights.append("You're excelling at \(strongDrill.displayName) (avg: \(String(format: "%.0f", avgScore)) pts) - keep up the good work!")
        }

        // Check subscores with specific values
        if let (weakSubscoreName, weakSubscoreValue) = weakestSubscoreWithValue(sessions: sessions) {
            insights.append("Focus on improving your \(weakSubscoreName.lowercased()) (currently \(String(format: "%.0f", weakSubscoreValue)) pts) in drills.")
        }

        // Add cross-discipline insights
        let crossInsight = generateCrossDisciplineInsights(sessions: sessions)
        if !crossInsight.contains("Complete more") {
            insights.append(crossInsight)
        }

        if insights.isEmpty {
            return "Complete more drills to receive personalized insights."
        }

        return insights.joined(separator: " ")
    }

    /// Calculate recent average score
    private func calculateRecentAverage(sessions: [UnifiedDrillSession], days: Int = 14) -> Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let recent = sessions.filter { $0.startDate >= cutoff }
        guard !recent.isEmpty else { return 0 }
        return recent.map(\.score).reduce(0, +) / Double(recent.count)
    }

    /// Calculate average score for a specific drill type
    func averageScore(for drillType: UnifiedDrillType, sessions: [UnifiedDrillSession]) -> Double {
        let filtered = sessions.filter { $0.drillType == drillType }.suffix(10)
        guard !filtered.isEmpty else { return 0 }
        return filtered.map(\.score).reduce(0, +) / Double(filtered.count)
    }

    /// Identify weakest subscore with its value
    func weakestSubscoreWithValue(sessions: [UnifiedDrillSession]) -> (String, Double)? {
        let recentSessions = sessions.suffix(10)
        guard !recentSessions.isEmpty else { return nil }

        let count = Double(recentSessions.count)
        let subscores = [
            ("Stability", recentSessions.map(\.stabilityScore).reduce(0, +) / count),
            ("Symmetry", recentSessions.map(\.symmetryScore).reduce(0, +) / count),
            ("Endurance", recentSessions.map(\.enduranceScore).reduce(0, +) / count),
            ("Coordination", recentSessions.map(\.coordinationScore).reduce(0, +) / count),
            ("Breathing", recentSessions.map(\.breathingScore).reduce(0, +) / count),
            ("Rhythm", recentSessions.map(\.rhythmScore).reduce(0, +) / count),
            ("Reaction", recentSessions.map(\.reactionScore).reduce(0, +) / count)
        ].filter { $0.1 > 0 }  // Only include subscores that have data

        return subscores.min { $0.1 < $1.1 }
    }

    /// Generate detailed trend analysis with concrete deltas
    func generateDetailedTrendAnalysis(sessions: [UnifiedDrillSession]) -> DetailedTrendAnalysis {
        let recentAvg = calculateRecentAverage(sessions: sessions, days: 14)
        let olderAvg = calculateOlderAverage(sessions: sessions, days: 30)
        let delta = recentAvg - olderAvg
        let percentChange = olderAvg > 0 ? (delta / olderAvg) * 100 : 0

        let bestSession = sessions.max { $0.score < $1.score }
        let worstSession = sessions.min { $0.score < $1.score }

        return DetailedTrendAnalysis(
            currentAverage: recentAvg,
            previousAverage: olderAvg,
            absoluteDelta: delta,
            percentageChange: percentChange,
            bestScore: bestSession?.score ?? 0,
            worstScore: worstSession?.score ?? 0,
            totalSessions: sessions.count,
            trendDirection: percentChange > 5 ? .improving(percentage: percentChange) :
                           (percentChange < -5 ? .declining(percentage: abs(percentChange)) : .stable)
        )
    }

    private func calculateOlderAverage(sessions: [UnifiedDrillSession], days: Int) -> Double {
        let recentCutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let olderCutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let older = sessions.filter { $0.startDate >= olderCutoff && $0.startDate < recentCutoff }
        guard !older.isEmpty else { return 0 }
        return older.map(\.score).reduce(0, +) / Double(older.count)
    }

    // MARK: - Legacy Support (Riding)

    /// Calculate week-over-week trend for a riding drill type
    func weekOverWeekTrend(
        for drillType: RidingDrillType,
        sessions: [RidingDrillSession]
    ) -> TrendDirection {
        let filtered = sessions.filter { $0.drillType == drillType }
        return calculateTrendFromSessions(filtered.map { ($0.startDate, $0.score) })
    }

    /// Find best riding drill performance in a time period
    func bestRidingPerformance(
        for drillType: RidingDrillType,
        sessions: [RidingDrillSession],
        in period: DateInterval
    ) -> RidingDrillSession? {
        sessions
            .filter { $0.drillType == drillType && period.contains($0.startDate) }
            .max { $0.score < $1.score }
    }

    /// Identify weakest subscore across recent riding drill sessions
    func weakestRidingSubscore(sessions: [RidingDrillSession]) -> String? {
        let recentSessions = sessions.suffix(10)
        guard !recentSessions.isEmpty else { return nil }

        let avgStability = recentSessions.map(\.stabilityScore).reduce(0, +) / Double(recentSessions.count)
        let avgSymmetry = recentSessions.map(\.symmetryScore).reduce(0, +) / Double(recentSessions.count)
        let avgEndurance = recentSessions.map(\.enduranceScore).reduce(0, +) / Double(recentSessions.count)
        let avgCoordination = recentSessions.map(\.coordinationScore).reduce(0, +) / Double(recentSessions.count)

        let subscores = [
            ("Stability", avgStability),
            ("Symmetry", avgSymmetry),
            ("Endurance", avgEndurance),
            ("Coordination", avgCoordination)
        ]

        return subscores.min { $0.1 < $1.1 }?.0
    }

    /// Find the strongest riding drill type
    func strongestRidingDrill(sessions: [RidingDrillSession]) -> RidingDrillType? {
        let recentSessions = sessions.suffix(20)

        var typeScores: [RidingDrillType: [Double]] = [:]
        for session in recentSessions {
            typeScores[session.drillType, default: []].append(session.score)
        }

        return typeScores
            .filter { $0.value.count >= 2 }
            .max { lhs, rhs in
                let lhsAvg = lhs.value.reduce(0, +) / Double(lhs.value.count)
                let rhsAvg = rhs.value.reduce(0, +) / Double(rhs.value.count)
                return lhsAvg < rhsAvg
            }?.key
    }

    /// Find the weakest riding drill type
    func weakestRidingDrill(sessions: [RidingDrillSession]) -> RidingDrillType? {
        let recentSessions = sessions.suffix(20)

        var typeScores: [RidingDrillType: [Double]] = [:]
        for session in recentSessions {
            typeScores[session.drillType, default: []].append(session.score)
        }

        return typeScores
            .filter { $0.value.count >= 2 }
            .min { lhs, rhs in
                let lhsAvg = lhs.value.reduce(0, +) / Double(lhs.value.count)
                let rhsAvg = rhs.value.reduce(0, +) / Double(rhs.value.count)
                return lhsAvg < rhsAvg
            }?.key
    }

    // MARK: - Legacy Support (Shooting)

    /// Calculate week-over-week trend for a shooting drill type
    func weekOverWeekTrend(
        for drillType: ShootingDrillType,
        sessions: [ShootingDrillSession]
    ) -> TrendDirection {
        let filtered = sessions.filter { $0.drillType == drillType }
        return calculateTrendFromSessions(filtered.map { ($0.startDate, $0.score) })
    }

    /// Find best shooting drill performance in a time period
    func bestShootingPerformance(
        for drillType: ShootingDrillType,
        sessions: [ShootingDrillSession],
        in period: DateInterval
    ) -> ShootingDrillSession? {
        sessions
            .filter { $0.drillType == drillType && period.contains($0.startDate) }
            .max { $0.score < $1.score }
    }

    /// Identify weakest subscore across recent shooting drill sessions
    func weakestShootingSubscore(sessions: [ShootingDrillSession]) -> String? {
        let recentSessions = sessions.suffix(10)
        guard !recentSessions.isEmpty else { return nil }

        let avgStability = recentSessions.map(\.stabilityScore).reduce(0, +) / Double(recentSessions.count)
        let avgRecovery = recentSessions.map(\.recoveryScore).reduce(0, +) / Double(recentSessions.count)
        let avgTransition = recentSessions.map(\.transitionScore).reduce(0, +) / Double(recentSessions.count)
        let avgEndurance = recentSessions.map(\.enduranceScore).reduce(0, +) / Double(recentSessions.count)

        let subscores = [
            ("Stability", avgStability),
            ("Recovery", avgRecovery),
            ("Transitions", avgTransition),
            ("Endurance", avgEndurance)
        ]

        return subscores.min { $0.1 < $1.1 }?.0
    }

    /// Find the strongest shooting drill type
    func strongestShootingDrill(sessions: [ShootingDrillSession]) -> ShootingDrillType? {
        let recentSessions = sessions.suffix(20)

        var typeScores: [ShootingDrillType: [Double]] = [:]
        for session in recentSessions {
            typeScores[session.drillType, default: []].append(session.score)
        }

        return typeScores
            .filter { $0.value.count >= 2 }
            .max { lhs, rhs in
                let lhsAvg = lhs.value.reduce(0, +) / Double(lhs.value.count)
                let rhsAvg = rhs.value.reduce(0, +) / Double(rhs.value.count)
                return lhsAvg < rhsAvg
            }?.key
    }

    /// Find the weakest shooting drill type
    func weakestShootingDrill(sessions: [ShootingDrillSession]) -> ShootingDrillType? {
        let recentSessions = sessions.suffix(20)

        var typeScores: [ShootingDrillType: [Double]] = [:]
        for session in recentSessions {
            typeScores[session.drillType, default: []].append(session.score)
        }

        return typeScores
            .filter { $0.value.count >= 2 }
            .min { lhs, rhs in
                let lhsAvg = lhs.value.reduce(0, +) / Double(lhs.value.count)
                let rhsAvg = rhs.value.reduce(0, +) / Double(rhs.value.count)
                return lhsAvg < rhsAvg
            }?.key
    }

    /// Get overall improvement percentage over a time period (legacy)
    func overallImprovement(
        ridingSessions: [RidingDrillSession],
        shootingSessions: [ShootingDrillSession],
        days: Int = 30
    ) -> Double? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        // Get all scores before and after midpoint
        let midpoint = Calendar.current.date(byAdding: .day, value: -days / 2, to: Date()) ?? Date()

        let oldRidingScores = ridingSessions
            .filter { $0.startDate >= cutoff && $0.startDate < midpoint }
            .map(\.score)
        let newRidingScores = ridingSessions
            .filter { $0.startDate >= midpoint }
            .map(\.score)

        let oldShootingScores = shootingSessions
            .filter { $0.startDate >= cutoff && $0.startDate < midpoint }
            .map(\.score)
        let newShootingScores = shootingSessions
            .filter { $0.startDate >= midpoint }
            .map(\.score)

        let allOld = oldRidingScores + oldShootingScores
        let allNew = newRidingScores + newShootingScores

        guard !allOld.isEmpty, !allNew.isEmpty else { return nil }

        let oldAvg = allOld.reduce(0, +) / Double(allOld.count)
        let newAvg = allNew.reduce(0, +) / Double(allNew.count)

        guard oldAvg > 0 else { return nil }

        return ((newAvg - oldAvg) / oldAvg) * 100
    }

    /// Generate a human-readable insight summary (legacy)
    func generateInsightSummary(
        ridingSessions: [RidingDrillSession],
        shootingSessions: [ShootingDrillSession]
    ) -> String {
        var insights: [String] = []

        // Check overall improvement
        if let improvement = overallImprovement(
            ridingSessions: ridingSessions,
            shootingSessions: shootingSessions
        ) {
            if improvement > 10 {
                insights.append("Your overall drill performance has improved \(String(format: "%.0f", improvement))% recently.")
            } else if improvement < -10 {
                insights.append("Your drill scores have dipped \(String(format: "%.0f", abs(improvement)))% - consider focusing on fundamentals.")
            }
        }

        // Check for riding weaknesses
        if let weakRiding = weakestRidingDrill(sessions: ridingSessions) {
            insights.append("\(weakRiding.displayName) needs more practice - it's your lowest scoring riding drill.")
        }

        // Check for shooting strengths
        if let strongShooting = strongestShootingDrill(sessions: shootingSessions) {
            insights.append("You're excelling at \(strongShooting.displayName) - keep up the good work!")
        }

        // Check subscores
        if let weakSubscore = weakestRidingSubscore(sessions: ridingSessions) {
            insights.append("Focus on improving your \(weakSubscore.lowercased()) in riding drills.")
        }

        if insights.isEmpty {
            return "Complete more drills to receive personalized insights."
        }

        return insights.joined(separator: " ")
    }

    // MARK: - Statistical Analysis

    /// Calculate moving average for a sequence of scores
    func movingAverage(scores: [Double], window: Int) -> [Double] {
        guard scores.count >= window else { return [] }

        var result: [Double] = []
        for i in (window - 1)..<scores.count {
            let windowScores = scores[(i - window + 1)...i]
            let avg = windowScores.reduce(0, +) / Double(window)
            result.append(avg)
        }
        return result
    }

    /// Calculate percentile rank of a score among sessions
    func percentileRank(score: Double, among scores: [Double]) -> Double {
        guard !scores.isEmpty else { return 0 }

        let belowCount = scores.filter { $0 < score }.count
        let equalCount = scores.filter { $0 == score }.count

        return Double(belowCount + equalCount / 2) / Double(scores.count) * 100
    }

    // MARK: - Private Helpers

    private func calculateTrendFromSessions(_ sessions: [(Date, Double)]) -> TrendDirection {
        guard sessions.count >= minimumSessionsForTrend else { return .insufficient }

        // Sort by date
        let sorted = sessions.sorted { $0.0 < $1.0 }

        // Compare first half to second half averages
        let halfPoint = sorted.count / 2
        let firstHalf = sorted.prefix(halfPoint)
        let secondHalf = sorted.suffix(sorted.count - halfPoint)

        let firstAvg = firstHalf.map(\.1).reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.map(\.1).reduce(0, +) / Double(secondHalf.count)

        guard firstAvg > 0 else { return .stable }

        let percentChange = ((secondAvg - firstAvg) / firstAvg) * 100

        if percentChange > stableThreshold {
            return .improving(percentage: percentChange)
        } else if percentChange < -stableThreshold {
            return .declining(percentage: abs(percentChange))
        } else {
            return .stable
        }
    }
}
