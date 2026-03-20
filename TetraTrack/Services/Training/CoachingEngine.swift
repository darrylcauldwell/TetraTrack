//
//  CoachingEngine.swift
//  TetraTrack
//
//  Adaptive coaching engine that identifies weaknesses and recommends drills
//

import Foundation
import SwiftData

/// Priority level for drill recommendations
enum DrillPriority: Int, Comparable {
    case high = 3
    case medium = 2
    case low = 1

    static func < (lhs: DrillPriority, rhs: DrillPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .high: return "High Priority"
        case .medium: return "Recommended"
        case .low: return "Optional"
        }
    }
}

/// Represents an identified weakness in performance
struct Weakness: Identifiable {
    let id = UUID()
    let area: String           // e.g., "Core Stability"
    let severity: Double       // 0-1 (1 being most severe)
    let evidence: String       // e.g., "Your scores dropped 20%..."
    let recommendedDrills: [String]
    let discipline: Discipline

    init(area: String, severity: Double, evidence: String, recommendedDrills: [String], discipline: Discipline) {
        self.area = area
        self.severity = severity
        self.evidence = evidence
        self.recommendedDrills = recommendedDrills
        self.discipline = discipline
    }

}

/// A specific drill recommendation
struct DrillRecommendation: Identifiable {
    let id = UUID()
    let drillType: String
    let drillName: String
    let reason: String
    let priority: DrillPriority
    let suggestedDuration: TimeInterval
    let discipline: Discipline
    let benefitsDisciplines: Set<Discipline>
    let crossTrainingNote: String?

    /// Full initializer with cross-training support
    init(
        drillType: String,
        drillName: String,
        reason: String,
        priority: DrillPriority,
        suggestedDuration: TimeInterval,
        discipline: Discipline,
        benefitsDisciplines: Set<Discipline> = [],
        crossTrainingNote: String? = nil
    ) {
        self.drillType = drillType
        self.drillName = drillName
        self.reason = reason
        self.priority = priority
        self.suggestedDuration = suggestedDuration
        self.discipline = discipline
        self.benefitsDisciplines = benefitsDisciplines.isEmpty ? [discipline] : benefitsDisciplines
        self.crossTrainingNote = crossTrainingNote
    }

    var formattedDuration: String {
        if suggestedDuration < 60 {
            return "\(Int(suggestedDuration))s"
        } else {
            return "\(Int(suggestedDuration / 60))m"
        }
    }

    /// Whether this drill benefits multiple disciplines
    var isCrossTraining: Bool {
        benefitsDisciplines.count > 1
    }
}

/// Main coaching engine for adaptive training recommendations
@Observable
final class CoachingEngine {

    // MARK: - Dependencies

    private let trendAnalyzer = DrillTrendAnalyzer()
    private let correlator = DrillPerformanceCorrelator()

    // MARK: - Unified Weakness Detection

    /// Identify weaknesses across unified drill history
    func identifyWeaknesses(
        drillHistory: [UnifiedDrillSession],
        focusDiscipline: Discipline? = nil
    ) -> [Weakness] {
        var weaknesses: [Weakness] = []

        // Filter by discipline if specified
        let sessions: [UnifiedDrillSession]
        if let focus = focusDiscipline, focus != .all {
            sessions = drillHistory.filter { $0.primaryDiscipline == focus }
        } else {
            sessions = drillHistory
        }

        // Check each drill type for declining performance
        for drillType in UnifiedDrillType.allCases {
            // Skip drills not in focus discipline
            if let focus = focusDiscipline, focus != .all, !drillType.benefitsDisciplines.contains(focus) {
                continue
            }

            let trend = trendAnalyzer.weekOverWeekTrend(
                for: drillType,
                sessions: sessions
            )

            if case .declining(let pct) = trend, pct > 10 {
                let severity = min(1.0, pct / 50.0)
                weaknesses.append(Weakness(
                    area: drillType.displayName,
                    severity: severity,
                    evidence: "Your \(drillType.displayName) scores have declined \(String(format: "%.0f", pct))% recently.",
                    recommendedDrills: [drillType.rawValue],
                    discipline: drillType.primaryDiscipline
                ))
            }
        }

        // Check subscores for systemic weaknesses
        if let weakSubscore = trendAnalyzer.weakestSubscore(sessions: sessions) {
            let recentScores = sessions.suffix(10)
            let avgScore = averageSubscore(weakSubscore, from: Array(recentScores))

            if avgScore < 60 {
                let recommendedDrills = unifiedDrillsForSubscore(weakSubscore)
                weaknesses.append(Weakness(
                    area: "\(weakSubscore) (Subscore)",
                    severity: (60 - avgScore) / 60,
                    evidence: "Your \(weakSubscore.lowercased()) subscore averages \(String(format: "%.0f", avgScore))% across recent drills.",
                    recommendedDrills: recommendedDrills,
                    discipline: .all
                ))
            }
        }

        // Check for undertraining (neglected drill types)
        let sessionsByType = Dictionary(grouping: sessions) { $0.drillType }
        for drillType in UnifiedDrillType.allCases {
            // Skip drills not in focus discipline
            if let focus = focusDiscipline, focus != .all, !drillType.benefitsDisciplines.contains(focus) {
                continue
            }

            let count = sessionsByType[drillType]?.count ?? 0
            if count < 2 {
                weaknesses.append(Weakness(
                    area: "\(drillType.displayName) (Undertrained)",
                    severity: 0.4,
                    evidence: "You've only completed \(count) \(drillType.displayName) drill\(count == 1 ? "" : "s"). More practice recommended.",
                    recommendedDrills: [drillType.rawValue],
                    discipline: drillType.primaryDiscipline
                ))
            }
        }

        return weaknesses.sorted { $0.severity > $1.severity }
    }

    // MARK: - Unified Recommendations

    /// Generate drill recommendations based on unified weaknesses
    func recommendDrills(
        weaknesses: [Weakness],
        recentDrills: [UnifiedDrillSession],
        focusDiscipline: Discipline? = nil
    ) -> [DrillRecommendation] {
        var recommendations: [DrillRecommendation] = []

        // Prioritize universal drills when no specific focus
        let prioritizeUniversal = focusDiscipline == nil || focusDiscipline == .all

        // High priority: address severe weaknesses
        for weakness in weaknesses where weakness.severity > 0.5 {
            for drillTypeRaw in weakness.recommendedDrills {
                if let drillType = UnifiedDrillType(rawValue: drillTypeRaw) {
                    let isUniversal = drillType.benefitsDisciplines.count == 4
                    let crossNote = isUniversal ? "This drill benefits all four disciplines." : nil

                    recommendations.append(DrillRecommendation(
                        drillType: drillTypeRaw,
                        drillName: drillType.displayName,
                        reason: weakness.evidence,
                        priority: .high,
                        suggestedDuration: drillType.suggestedDuration,
                        discipline: drillType.primaryDiscipline,
                        benefitsDisciplines: drillType.benefitsDisciplines,
                        crossTrainingNote: crossNote
                    ))
                }
            }
        }

        // Medium priority: moderate weaknesses
        for weakness in weaknesses where weakness.severity > 0.25 && weakness.severity <= 0.5 {
            for drillTypeRaw in weakness.recommendedDrills {
                if let drillType = UnifiedDrillType(rawValue: drillTypeRaw) {
                    if !recommendations.contains(where: { $0.drillType == drillTypeRaw }) {
                        recommendations.append(DrillRecommendation(
                            drillType: drillTypeRaw,
                            drillName: drillType.displayName,
                            reason: weakness.evidence,
                            priority: .medium,
                            suggestedDuration: drillType.suggestedDuration,
                            discipline: drillType.primaryDiscipline,
                            benefitsDisciplines: drillType.benefitsDisciplines
                        ))
                    }
                }
            }
        }

        // Low priority: maintenance and universal recommendations
        if let strongest = trendAnalyzer.strongestDrill(sessions: recentDrills, discipline: focusDiscipline) {
            if !recommendations.contains(where: { $0.drillType == strongest.rawValue }) {
                recommendations.append(DrillRecommendation(
                    drillType: strongest.rawValue,
                    drillName: strongest.displayName,
                    reason: "Maintain your strong \(strongest.displayName) performance.",
                    priority: .low,
                    suggestedDuration: strongest.suggestedDuration / 2,
                    discipline: strongest.primaryDiscipline,
                    benefitsDisciplines: strongest.benefitsDisciplines
                ))
            }
        }

        // Add universal drills for cross-training if no specific focus
        if prioritizeUniversal {
            let universalDrills: [UnifiedDrillType] = [.coreStability, .boxBreathing, .standingBalance]
            for drill in universalDrills {
                if !recommendations.contains(where: { $0.drillType == drill.rawValue }) {
                    recommendations.append(DrillRecommendation(
                        drillType: drill.rawValue,
                        drillName: drill.displayName,
                        reason: "Universal drill that benefits all disciplines.",
                        priority: .low,
                        suggestedDuration: drill.suggestedDuration,
                        discipline: drill.primaryDiscipline,
                        benefitsDisciplines: drill.benefitsDisciplines,
                        crossTrainingNote: "Core training for all four disciplines."
                    ))
                }
            }
        }

        return recommendations.sorted { $0.priority > $1.priority }
    }

    /// Generate today's recommended workout from unified recommendations
    func generateDailyWorkout(
        recommendations: [DrillRecommendation],
        maxDuration: TimeInterval = 600  // 10 minutes
    ) -> [DrillRecommendation] {
        var workout: [DrillRecommendation] = []
        var totalDuration: TimeInterval = 0

        // Add high priority first
        for rec in recommendations where rec.priority == .high {
            if totalDuration + rec.suggestedDuration <= maxDuration {
                workout.append(rec)
                totalDuration += rec.suggestedDuration
            }
        }

        // Then medium
        for rec in recommendations where rec.priority == .medium {
            if totalDuration + rec.suggestedDuration <= maxDuration {
                workout.append(rec)
                totalDuration += rec.suggestedDuration
            }
        }

        // Fill remaining with low priority
        for rec in recommendations where rec.priority == .low {
            if totalDuration + rec.suggestedDuration <= maxDuration {
                workout.append(rec)
                totalDuration += rec.suggestedDuration
            }
        }

        return workout
    }

    // MARK: - Private Helpers

    private func averageSubscore(_ subscore: String, from sessions: [UnifiedDrillSession]) -> Double {
        guard !sessions.isEmpty else { return 0 }
        let count = Double(sessions.count)

        switch subscore {
        case "Stability": return sessions.map(\.stabilityScore).reduce(0, +) / count
        case "Symmetry": return sessions.map(\.symmetryScore).reduce(0, +) / count
        case "Endurance": return sessions.map(\.enduranceScore).reduce(0, +) / count
        case "Coordination": return sessions.map(\.coordinationScore).reduce(0, +) / count
        case "Breathing": return sessions.map(\.breathingScore).reduce(0, +) / count
        case "Rhythm": return sessions.map(\.rhythmScore).reduce(0, +) / count
        case "Reaction": return sessions.map(\.reactionScore).reduce(0, +) / count
        default: return 0
        }
    }

    private func unifiedDrillsForSubscore(_ subscore: String) -> [String] {
        switch subscore {
        case "Stability":
            return [UnifiedDrillType.coreStability.rawValue, UnifiedDrillType.riderStillness.rawValue,
                    UnifiedDrillType.steadyHold.rawValue, UnifiedDrillType.streamlinePosition.rawValue]
        case "Symmetry":
            return [UnifiedDrillType.balanceBoard.rawValue, UnifiedDrillType.hipMobility.rawValue]
        case "Endurance":
            return [UnifiedDrillType.posturalDrift.rawValue, UnifiedDrillType.stressInoculation.rawValue]
        case "Coordination":
            return [UnifiedDrillType.hipMobility.rawValue, UnifiedDrillType.kickEfficiency.rawValue]
        case "Breathing":
            return [UnifiedDrillType.boxBreathing.rawValue, UnifiedDrillType.breathingPatterns.rawValue,
                    UnifiedDrillType.breathingRhythm.rawValue]
        case "Rhythm":
            return [UnifiedDrillType.postingRhythm.rawValue, UnifiedDrillType.cadenceTraining.rawValue]
        case "Reaction":
            return [UnifiedDrillType.reactionTime.rawValue, UnifiedDrillType.splitTime.rawValue]
        default:
            return []
        }
    }

}
