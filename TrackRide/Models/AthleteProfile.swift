//
//  AthleteProfile.swift
//  TrackRide
//
//  Aggregate skill profile with rolling averages across all disciplines
//

import Foundation
import SwiftData

@Model
final class AthleteProfile {
    var id: UUID = UUID()
    var lastUpdated: Date = Date()

    // MARK: - Rolling Averages (30-day window, 0-100)

    var stabilityAverage: Double = 0
    var balanceAverage: Double = 0
    var symmetryAverage: Double = 0
    var rhythmAverage: Double = 0
    var enduranceAverage: Double = 0
    var calmnessAverage: Double = 0

    // MARK: - Trend Direction (-1 declining, 0 stable, +1 improving)

    var stabilityTrend: Int = 0
    var balanceTrend: Int = 0
    var symmetryTrend: Int = 0
    var rhythmTrend: Int = 0
    var enduranceTrend: Int = 0
    var calmnessTrend: Int = 0

    // MARK: - Session Counts (for confidence weighting)

    var totalRidingSessions: Int = 0
    var totalRunningSessions: Int = 0
    var totalSwimmingSessions: Int = 0
    var totalShootingSessions: Int = 0

    // MARK: - Best Scores (all-time)

    var bestStability: Double = 0
    var bestBalance: Double = 0
    var bestSymmetry: Double = 0
    var bestRhythm: Double = 0
    var bestEndurance: Double = 0
    var bestCalmness: Double = 0

    init() {}

    // MARK: - Computed Properties

    /// Overall athlete score (average of all domains with data)
    var overallScore: Double {
        let scores = [
            stabilityAverage, balanceAverage, symmetryAverage,
            rhythmAverage, enduranceAverage, calmnessAverage
        ]
        let validScores = scores.filter { $0 > 0 }
        guard !validScores.isEmpty else { return 0 }
        return validScores.reduce(0, +) / Double(validScores.count)
    }

    /// Formatted overall score
    var formattedOverallScore: String {
        String(format: "%.0f", overallScore)
    }

    /// Strongest skill domain
    var strongestDomain: SkillDomain? {
        let domains: [(SkillDomain, Double)] = [
            (.stability, stabilityAverage),
            (.balance, balanceAverage),
            (.symmetry, symmetryAverage),
            (.rhythm, rhythmAverage),
            (.endurance, enduranceAverage),
            (.calmness, calmnessAverage)
        ]
        return domains.filter { $0.1 > 0 }.max { $0.1 < $1.1 }?.0
    }

    /// Weakest skill domain (opportunity for improvement)
    var weakestDomain: SkillDomain? {
        let domains: [(SkillDomain, Double)] = [
            (.stability, stabilityAverage),
            (.balance, balanceAverage),
            (.symmetry, symmetryAverage),
            (.rhythm, rhythmAverage),
            (.endurance, enduranceAverage),
            (.calmness, calmnessAverage)
        ]
        return domains.filter { $0.1 > 0 }.min { $0.1 < $1.1 }?.0
    }

    /// Total sessions across all disciplines
    var totalSessions: Int {
        totalRidingSessions + totalRunningSessions + totalSwimmingSessions + totalShootingSessions
    }

    /// Get score for a specific domain
    func score(for domain: SkillDomain) -> Double {
        switch domain {
        case .stability: return stabilityAverage
        case .balance: return balanceAverage
        case .symmetry: return symmetryAverage
        case .rhythm: return rhythmAverage
        case .endurance: return enduranceAverage
        case .calmness: return calmnessAverage
        }
    }

    /// Get trend for a specific domain
    func trend(for domain: SkillDomain) -> Int {
        switch domain {
        case .stability: return stabilityTrend
        case .balance: return balanceTrend
        case .symmetry: return symmetryTrend
        case .rhythm: return rhythmTrend
        case .endurance: return enduranceTrend
        case .calmness: return calmnessTrend
        }
    }

    /// Get best score for a specific domain
    func bestScore(for domain: SkillDomain) -> Double {
        switch domain {
        case .stability: return bestStability
        case .balance: return bestBalance
        case .symmetry: return bestSymmetry
        case .rhythm: return bestRhythm
        case .endurance: return bestEndurance
        case .calmness: return bestCalmness
        }
    }

    /// Trend icon for a domain
    func trendIcon(for domain: SkillDomain) -> String {
        let t = trend(for: domain)
        if t > 0 { return "arrow.up.right" }
        if t < 0 { return "arrow.down.right" }
        return "arrow.right"
    }

    /// Trend color for a domain
    func trendColor(for domain: SkillDomain) -> String {
        let t = trend(for: domain)
        if t > 0 { return "green" }
        if t < 0 { return "red" }
        return "gray"
    }

    /// Update a domain's average and trend
    func updateDomain(_ domain: SkillDomain, average: Double, trend: Int) {
        let clampedAverage = min(100, max(0, average))
        let clampedTrend = min(1, max(-1, trend))

        switch domain {
        case .stability:
            stabilityAverage = clampedAverage
            stabilityTrend = clampedTrend
            if clampedAverage > bestStability { bestStability = clampedAverage }
        case .balance:
            balanceAverage = clampedAverage
            balanceTrend = clampedTrend
            if clampedAverage > bestBalance { bestBalance = clampedAverage }
        case .symmetry:
            symmetryAverage = clampedAverage
            symmetryTrend = clampedTrend
            if clampedAverage > bestSymmetry { bestSymmetry = clampedAverage }
        case .rhythm:
            rhythmAverage = clampedAverage
            rhythmTrend = clampedTrend
            if clampedAverage > bestRhythm { bestRhythm = clampedAverage }
        case .endurance:
            enduranceAverage = clampedAverage
            enduranceTrend = clampedTrend
            if clampedAverage > bestEndurance { bestEndurance = clampedAverage }
        case .calmness:
            calmnessAverage = clampedAverage
            calmnessTrend = clampedTrend
            if clampedAverage > bestCalmness { bestCalmness = clampedAverage }
        }
        lastUpdated = Date()
    }

    /// Radar chart data for visualization (ordered for hexagon display)
    var radarChartData: [(domain: SkillDomain, value: Double)] {
        SkillDomain.allCases.map { ($0, score(for: $0)) }
    }

    /// Check if profile has meaningful data
    var hasData: Bool {
        totalSessions > 0 && overallScore > 0
    }
}
