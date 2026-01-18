//
//  CrossSportCorrelationService.swift
//  TrackRide
//
//  Discovers cross-discipline correlations and generates actionable insights
//

import Foundation
import SwiftData
import Observation

// MARK: - Correlation Result

/// Cross-discipline correlation result
struct CrossSportCorrelation: Identifiable {
    let id = UUID()
    let sourceDiscipline: TrainingDiscipline
    let targetDiscipline: TrainingDiscipline
    let sourceMetric: String
    let targetMetric: String
    let correlationCoefficient: Double
    let significance: CorrelationSignificance
    let sampleSize: Int
    let lagWeeks: Int  // 0 = same week, 1+ = delayed effect

    var isPositive: Bool { correlationCoefficient > 0 }

    var insightText: String {
        let direction = isPositive ? "improves" : "inversely affects"
        let lag = lagWeeks > 0 ? " (with \(lagWeeks)-week delay)" : ""
        return "\(sourceDiscipline.rawValue) \(sourceMetric) \(direction) \(targetDiscipline.rawValue) \(targetMetric)\(lag)"
    }

    var strengthDescription: String {
        switch significance {
        case .strong: return "Strong"
        case .moderate: return "Moderate"
        case .weak: return "Weak"
        case .none: return "No"
        }
    }
}

// MARK: - Correlation Significance

enum CorrelationSignificance: String {
    case strong = "Strong"
    case moderate = "Moderate"
    case weak = "Weak"
    case none = "None"

    init(coefficient: Double, sampleSize: Int) {
        let absCoef = abs(coefficient)
        // Require more samples for weaker correlations
        if sampleSize < 5 {
            self = .none
        } else if absCoef >= 0.7 {
            self = .strong
        } else if absCoef >= 0.4 {
            self = .moderate
        } else if absCoef >= 0.2 {
            self = .weak
        } else {
            self = .none
        }
    }

    var color: String {
        switch self {
        case .strong: return "green"
        case .moderate: return "blue"
        case .weak: return "orange"
        case .none: return "gray"
        }
    }
}

// MARK: - Training Insight

/// Actionable insight generated from correlations
struct TrainingInsight: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let icon: String
    let priority: InsightPriority
    let sourceDomains: [SkillDomain]
    let relatedDisciplines: [TrainingDiscipline]

    enum InsightPriority: Int, Comparable {
        case high = 1
        case medium = 2
        case low = 3

        static func < (lhs: InsightPriority, rhs: InsightPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var color: String {
            switch self {
            case .high: return "red"
            case .medium: return "orange"
            case .low: return "blue"
            }
        }
    }
}

// MARK: - Cross-Sport Correlation Service

@Observable
final class CrossSportCorrelationService {

    // MARK: - Known Transfer Effects

    /// Evidence-based cross-discipline correlations
    static let knownTransfers: [(source: TrainingDiscipline, target: TrainingDiscipline, mechanism: String, domain: SkillDomain)] = [
        (.running, .swimming, "Cadence consistency transfers to swimming rhythm", .rhythm),
        (.swimming, .running, "Breathing control improves running breath efficiency", .calmness),
        (.shooting, .riding, "Balance work improves rider stability", .stability),
        (.riding, .shooting, "Balance challenges enhance shooting platform control", .balance),
        (.running, .riding, "Running endurance supports longer rides", .endurance),
        (.swimming, .shooting, "Breath control aids shooting steadiness", .calmness),
        (.riding, .running, "Core stability improves running form", .stability),
        (.swimming, .riding, "Body position awareness transfers to rider posture", .balance)
    ]

    // MARK: - Correlation Analysis

    /// Find correlations between skill domain scores across disciplines
    func findCrossDisciplineCorrelations(
        scores: [SkillDomainScore],
        minSamples: Int = 5
    ) -> [CrossSportCorrelation] {
        var results: [CrossSportCorrelation] = []

        // Group scores by domain and discipline
        let grouped = Dictionary(grouping: scores) { score in
            "\(score.domain.rawValue)_\(score.discipline.rawValue)"
        }

        // For each domain, look for cross-discipline correlations
        for domain in SkillDomain.allCases {
            let disciplines = TrainingDiscipline.allCases

            for i in 0..<disciplines.count {
                for j in (i+1)..<disciplines.count {
                    let disc1 = disciplines[i]
                    let disc2 = disciplines[j]

                    let key1 = "\(domain.rawValue)_\(disc1.rawValue)"
                    let key2 = "\(domain.rawValue)_\(disc2.rawValue)"

                    guard let scores1 = grouped[key1], let scores2 = grouped[key2],
                          scores1.count >= minSamples, scores2.count >= minSamples else {
                        continue
                    }

                    // Same-week correlation
                    if let correlation = computeTemporalCorrelation(
                        source: scores1,
                        target: scores2,
                        lagWeeks: 0
                    ) {
                        let significance = CorrelationSignificance(
                            coefficient: correlation.coefficient,
                            sampleSize: correlation.sampleSize
                        )
                        if significance != .none {
                            results.append(CrossSportCorrelation(
                                sourceDiscipline: disc1,
                                targetDiscipline: disc2,
                                sourceMetric: domain.displayName,
                                targetMetric: domain.displayName,
                                correlationCoefficient: correlation.coefficient,
                                significance: significance,
                                sampleSize: correlation.sampleSize,
                                lagWeeks: 0
                            ))
                        }
                    }

                    // 1-week lag correlation (does disc1 improvement predict disc2?)
                    if let lagCorrelation = computeTemporalCorrelation(
                        source: scores1,
                        target: scores2,
                        lagWeeks: 1
                    ) {
                        let significance = CorrelationSignificance(
                            coefficient: lagCorrelation.coefficient,
                            sampleSize: lagCorrelation.sampleSize
                        )
                        if significance != .none {
                            results.append(CrossSportCorrelation(
                                sourceDiscipline: disc1,
                                targetDiscipline: disc2,
                                sourceMetric: domain.displayName,
                                targetMetric: domain.displayName,
                                correlationCoefficient: lagCorrelation.coefficient,
                                significance: significance,
                                sampleSize: lagCorrelation.sampleSize,
                                lagWeeks: 1
                            ))
                        }
                    }
                }
            }
        }

        return results.sorted { abs($0.correlationCoefficient) > abs($1.correlationCoefficient) }
    }

    // MARK: - Insight Generation

    /// Generate actionable insights from correlations and profile
    func generateInsights(
        correlations: [CrossSportCorrelation],
        profile: AthleteProfile,
        recentScores: [SkillDomainScore]
    ) -> [TrainingInsight] {
        var insights: [TrainingInsight] = []

        // Strong positive correlations -> highlight training transfer
        for correlation in correlations where correlation.significance == .strong && correlation.isPositive {
            let domain = SkillDomain(rawValue: correlation.sourceMetric.lowercased()) ?? .stability
            insights.append(TrainingInsight(
                title: "Training Transfer Detected",
                message: "Your \(correlation.sourceDiscipline.rawValue) \(correlation.sourceMetric.lowercased()) is strongly correlated with \(correlation.targetDiscipline.rawValue) performance. Keep up the cross-training!",
                icon: "arrow.triangle.2.circlepath",
                priority: .medium,
                sourceDomains: [domain],
                relatedDisciplines: [correlation.sourceDiscipline, correlation.targetDiscipline]
            ))
        }

        // Weak domain + strong correlation = opportunity
        if let weakest = profile.weakestDomain {
            let relevantCorrelations = correlations.filter {
                $0.sourceMetric.lowercased() == weakest.rawValue && $0.isPositive && $0.significance != .none
            }
            if let best = relevantCorrelations.first {
                insights.append(TrainingInsight(
                    title: "Improvement Opportunity",
                    message: "Your \(weakest.displayName) is your weakest skill. \(best.sourceDiscipline.rawValue) training shows promise for improvement based on your cross-sport patterns.",
                    icon: "arrow.up.right",
                    priority: .high,
                    sourceDomains: [weakest],
                    relatedDisciplines: [best.sourceDiscipline]
                ))
            }
        }

        // Declining domain + lagged correlation = warning
        for domain in SkillDomain.allCases {
            if profile.trend(for: domain) == -1 {
                let laggedCorrelations = correlations.filter {
                    $0.targetMetric.lowercased() == domain.rawValue && $0.lagWeeks > 0 && $0.isPositive
                }
                if let predictor = laggedCorrelations.first {
                    insights.append(TrainingInsight(
                        title: "\(domain.displayName) Declining",
                        message: "Your \(domain.displayName) has been declining. Based on patterns, increasing \(predictor.sourceDiscipline.rawValue) training may help reverse this trend.",
                        icon: "exclamationmark.triangle",
                        priority: .high,
                        sourceDomains: [domain],
                        relatedDisciplines: [predictor.sourceDiscipline]
                    ))
                }
            }
        }

        // Balance across disciplines
        let disciplineCounts: [TrainingDiscipline: Int] = Dictionary(
            grouping: recentScores,
            by: { $0.discipline }
        ).mapValues { $0.count }

        let maxCount = disciplineCounts.values.max() ?? 0

        if maxCount > 0 {
            let undertrainedDisciplines = TrainingDiscipline.allCases.filter {
                (disciplineCounts[$0] ?? 0) < maxCount / 2
            }
            if !undertrainedDisciplines.isEmpty && undertrainedDisciplines.count < TrainingDiscipline.allCases.count {
                insights.append(TrainingInsight(
                    title: "Training Balance",
                    message: "Consider adding more \(undertrainedDisciplines.map { $0.rawValue }.joined(separator: " and ")) sessions for balanced multi-sport development.",
                    icon: "scale.3d",
                    priority: .low,
                    sourceDomains: [],
                    relatedDisciplines: undertrainedDisciplines
                ))
            }
        }

        // Strong domain celebration
        if let strongest = profile.strongestDomain, profile.score(for: strongest) >= 80 {
            insights.append(TrainingInsight(
                title: "Strength: \(strongest.displayName)",
                message: "Your \(strongest.displayName) is excellent at \(String(format: "%.0f", profile.score(for: strongest)))! This strength likely transfers to better performance across all disciplines.",
                icon: "star.fill",
                priority: .low,
                sourceDomains: [strongest],
                relatedDisciplines: strongest.primaryDisciplines
            ))
        }

        // Known transfer suggestions for undertrained areas
        for transfer in Self.knownTransfers {
            let sourceCount = disciplineCounts[transfer.source] ?? 0
            let targetCount = disciplineCounts[transfer.target] ?? 0

            if sourceCount > 3 && targetCount < 2 {
                // User trains source but not target - suggest transfer
                insights.append(TrainingInsight(
                    title: "Cross-Training Opportunity",
                    message: "\(transfer.mechanism). Your \(transfer.source.rawValue) training could benefit your \(transfer.target.rawValue) \(transfer.domain.displayName.lowercased()).",
                    icon: "arrow.right.arrow.left",
                    priority: .low,
                    sourceDomains: [transfer.domain],
                    relatedDisciplines: [transfer.source, transfer.target]
                ))
            }
        }

        return insights.sorted { $0.priority < $1.priority }
    }

    /// Generate a correlation insight message with concrete coefficient
    func generateCorrelationInsight(results: [CrossSportCorrelation]) -> String? {
        guard let strongest = results.first(where: {
            $0.significance == .strong || $0.significance == .moderate
        }) else {
            return nil
        }

        let correlationStr = String(format: "%.2f", strongest.correlationCoefficient)

        if strongest.isPositive {
            return "Your \(strongest.sourceDiscipline.rawValue) \(strongest.sourceMetric.lowercased()) shows a \(strongest.significance.rawValue.lowercased()) positive correlation (r=\(correlationStr)) with \(strongest.targetDiscipline.rawValue). Cross-training is working!"
        } else {
            return "Your \(strongest.sourceDiscipline.rawValue) \(strongest.sourceMetric.lowercased()) has an inverse relationship (r=\(correlationStr)) with \(strongest.targetDiscipline.rawValue). Consider varying your training approach."
        }
    }

    /// Generate enhanced insights with concrete score differences
    func generateEnhancedInsights(
        correlations: [CrossSportCorrelation],
        profile: AthleteProfile,
        recentScores: [SkillDomainScore]
    ) -> [TrainingInsight] {
        var insights: [TrainingInsight] = []

        // Strong positive correlations with score details
        for correlation in correlations where correlation.significance == .strong && correlation.isPositive {
            let domain = SkillDomain(rawValue: correlation.sourceMetric.lowercased()) ?? .stability
            let correlationStr = String(format: "%.2f", correlation.correlationCoefficient)
            insights.append(TrainingInsight(
                title: "Training Transfer Detected",
                message: "Your \(correlation.sourceDiscipline.rawValue) \(correlation.sourceMetric.lowercased()) shows strong correlation (r=\(correlationStr)) with \(correlation.targetDiscipline.rawValue) performance. This is based on \(correlation.sampleSize) data points.",
                icon: "arrow.triangle.2.circlepath",
                priority: .medium,
                sourceDomains: [domain],
                relatedDisciplines: [correlation.sourceDiscipline, correlation.targetDiscipline]
            ))
        }

        // Weak domain + correlation = specific improvement opportunity with scores
        if let weakest = profile.weakestDomain {
            let score = profile.score(for: weakest)
            let target = profile.score(for: profile.strongestDomain ?? .stability)
            let gap = target - score

            let relevantCorrelations = correlations.filter {
                $0.sourceMetric.lowercased() == weakest.rawValue && $0.isPositive && $0.significance != .none
            }
            if let best = relevantCorrelations.first {
                insights.append(TrainingInsight(
                    title: "Close the Gap: \(weakest.displayName)",
                    message: "Your \(weakest.displayName) is at \(String(format: "%.0f", score)) pts, \(String(format: "%.0f", gap)) pts behind your strongest skill. \(best.sourceDiscipline.rawValue) training shows promise for improvement (r=\(String(format: "%.2f", best.correlationCoefficient))).",
                    icon: "arrow.up.right",
                    priority: .high,
                    sourceDomains: [weakest],
                    relatedDisciplines: [best.sourceDiscipline]
                ))
            } else {
                insights.append(TrainingInsight(
                    title: "Focus Area: \(weakest.displayName)",
                    message: "Your \(weakest.displayName) is at \(String(format: "%.0f", score)) pts, \(String(format: "%.0f", gap)) pts behind your strongest skill. Target improvement through focused drills.",
                    icon: "target",
                    priority: .high,
                    sourceDomains: [weakest],
                    relatedDisciplines: weakest.primaryDisciplines
                ))
            }
        }

        // Declining domain with specific numbers
        for domain in SkillDomain.allCases {
            if profile.trend(for: domain) == -1 {
                let currentScore = profile.score(for: domain)
                let laggedCorrelations = correlations.filter {
                    $0.targetMetric.lowercased() == domain.rawValue && $0.lagWeeks > 0 && $0.isPositive
                }
                if let predictor = laggedCorrelations.first {
                    insights.append(TrainingInsight(
                        title: "\(domain.displayName) Declining",
                        message: "Your \(domain.displayName) has dropped to \(String(format: "%.0f", currentScore)) pts and trending down. Based on lagged correlations, increasing \(predictor.sourceDiscipline.rawValue) training may help reverse this in \(predictor.lagWeeks) week\(predictor.lagWeeks > 1 ? "s" : "").",
                        icon: "exclamationmark.triangle",
                        priority: .high,
                        sourceDomains: [domain],
                        relatedDisciplines: [predictor.sourceDiscipline]
                    ))
                }
            }
        }

        return insights.sorted { $0.priority < $1.priority }
    }

    // MARK: - Fetch All Scores

    /// Fetch all skill domain scores for analysis
    func fetchAllScores(context: ModelContext, withinDays: Int = 90) -> [SkillDomainScore] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -withinDays, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<SkillDomainScore>(
            predicate: #Predicate { $0.timestamp >= cutoffDate },
            sortBy: [SortDescriptor(\.timestamp)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    /// Fetch or create athlete profile
    func fetchOrCreateProfile(context: ModelContext) -> AthleteProfile {
        let descriptor = FetchDescriptor<AthleteProfile>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let profile = AthleteProfile()
        context.insert(profile)
        return profile
    }

    // MARK: - Private Helpers

    private func computeTemporalCorrelation(
        source: [SkillDomainScore],
        target: [SkillDomainScore],
        lagWeeks: Int
    ) -> (coefficient: Double, sampleSize: Int)? {
        let calendar = Calendar.current

        // Group by week
        func weekKey(_ date: Date) -> DateComponents {
            calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        }

        var sourceByWeek: [DateComponents: [Double]] = [:]
        var targetByWeek: [DateComponents: [Double]] = [:]

        for score in source {
            let week = weekKey(score.timestamp)
            sourceByWeek[week, default: []].append(score.score)
        }

        for score in target {
            let week = weekKey(score.timestamp)
            targetByWeek[week, default: []].append(score.score)
        }

        // Compute weekly averages and align
        var sourceValues: [Double] = []
        var targetValues: [Double] = []

        for (week, scores) in sourceByWeek {
            let sourceAvg = scores.reduce(0, +) / Double(scores.count)

            // Find target week (potentially lagged)
            var targetWeek = week
            if lagWeeks > 0, let date = calendar.date(from: week) {
                if let laggedDate = calendar.date(byAdding: .weekOfYear, value: lagWeeks, to: date) {
                    targetWeek = weekKey(laggedDate)
                }
            }

            if let targetScores = targetByWeek[targetWeek] {
                let targetAvg = targetScores.reduce(0, +) / Double(targetScores.count)
                sourceValues.append(sourceAvg)
                targetValues.append(targetAvg)
            }
        }

        guard sourceValues.count >= 3 else { return nil }

        let coefficient = pearsonCorrelation(sourceValues, targetValues)
        return (coefficient, sourceValues.count)
    }

    private func pearsonCorrelation(_ x: [Double], _ y: [Double]) -> Double {
        guard x.count == y.count, x.count >= 3 else { return 0 }

        let n = Double(x.count)
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).map { $0 * $1 }.reduce(0, +)
        let sumX2 = x.map { $0 * $0 }.reduce(0, +)
        let sumY2 = y.map { $0 * $0 }.reduce(0, +)

        let numerator = (n * sumXY) - (sumX * sumY)
        let denominator = sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY))

        guard denominator > 0.001 else { return 0 }

        return numerator / denominator
    }
}
