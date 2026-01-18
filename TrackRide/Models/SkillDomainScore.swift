//
//  SkillDomainScore.swift
//  TrackRide
//
//  Historical skill domain scores computed from training sessions
//

import Foundation
import SwiftData

@Model
final class SkillDomainScore {
    var id: UUID = UUID()
    var timestamp: Date = Date()

    /// The skill domain being scored (stored as raw value for CloudKit)
    var domainRaw: String = SkillDomain.stability.rawValue

    /// Score value (0-100)
    var score: Double = 0

    /// Confidence in the score (0-1), based on data quality
    var confidence: Double = 0

    /// Source discipline that generated this score (stored as raw value for CloudKit)
    var disciplineRaw: String = TrainingDiscipline.riding.rawValue

    /// Source session ID (riding, running, swimming, or shooting)
    var sourceSessionId: UUID?

    /// JSON-encoded contributing metrics for debugging/analysis
    var contributingMetricsData: Data?

    // MARK: - Transient Cache

    @Transient private var _cachedContributingMetrics: [String: Double]?

    // MARK: - Computed Properties

    var domain: SkillDomain {
        get { SkillDomain(rawValue: domainRaw) ?? .stability }
        set { domainRaw = newValue.rawValue }
    }

    var discipline: TrainingDiscipline {
        get { TrainingDiscipline(rawValue: disciplineRaw) ?? .riding }
        set { disciplineRaw = newValue.rawValue }
    }

    /// Decoded contributing metrics
    var contributingMetrics: [String: Double] {
        get {
            if let cached = _cachedContributingMetrics { return cached }
            guard let data = contributingMetricsData else { return [:] }
            let decoded = (try? JSONDecoder().decode([String: Double].self, from: data)) ?? [:]
            _cachedContributingMetrics = decoded
            return decoded
        }
        set {
            contributingMetricsData = try? JSONEncoder().encode(newValue)
            _cachedContributingMetrics = newValue
        }
    }

    /// Formatted score for display
    var formattedScore: String {
        String(format: "%.0f", score)
    }

    /// Score quality description
    var scoreQuality: String {
        switch score {
        case 90...100: return "Excellent"
        case 75..<90: return "Good"
        case 60..<75: return "Average"
        case 40..<60: return "Below Average"
        default: return "Needs Work"
        }
    }

    // MARK: - Initializers

    init() {}

    convenience init(
        domain: SkillDomain,
        score: Double,
        confidence: Double,
        discipline: TrainingDiscipline,
        sourceSessionId: UUID?,
        contributingMetrics: [String: Double] = [:]
    ) {
        self.init()
        self.domainRaw = domain.rawValue
        self.score = min(100, max(0, score))  // Clamp to 0-100
        self.confidence = min(1, max(0, confidence))  // Clamp to 0-1
        self.disciplineRaw = discipline.rawValue
        self.sourceSessionId = sourceSessionId
        self.contributingMetrics = contributingMetrics
        self.timestamp = Date()
    }
}
