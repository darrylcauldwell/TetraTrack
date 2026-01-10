//
//  IntelligenceService.swift
//  TrackRide
//
//  Apple Intelligence integration using Foundation Models framework
//  Provides on-device AI for ride analysis, insights, and recommendations
//

import Foundation
import os
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Intelligence Service

/// Service for Apple Intelligence features using Foundation Models
@available(iOS 26.0, *)
final class IntelligenceService {
    static let shared = IntelligenceService()

    #if canImport(FoundationModels)
    private let session: LanguageModelSession?
    #endif

    private init() {
        #if canImport(FoundationModels)
        // Initialize with system language model
        session = LanguageModelSession()
        #endif
    }

    /// Check if Apple Intelligence is available on this device
    var isAvailable: Bool {
        #if canImport(FoundationModels)
        return session != nil
        #else
        return false
        #endif
    }
}

// MARK: - Ride Analysis

@available(iOS 26.0, *)
extension IntelligenceService {
    /// Generate a natural language summary of a ride
    func summarizeRide(_ ride: Ride) async throws -> RideSummary {
        #if canImport(FoundationModels)
        guard let session = session else {
            throw IntelligenceError.notAvailable
        }

        let prompt = buildRideSummaryPrompt(ride)
        let response = try await session.respond(to: prompt, generating: RideSummary.self)
        return response.content
        #else
        throw IntelligenceError.notAvailable
        #endif
    }

    /// Analyze ride patterns and provide training insights
    func analyzeTrainingPatterns(rides: [Ride]) async throws -> TrainingInsights {
        #if canImport(FoundationModels)
        guard let session = session else {
            throw IntelligenceError.notAvailable
        }

        let prompt = buildTrainingAnalysisPrompt(rides)
        let response = try await session.respond(to: prompt, generating: TrainingInsights.self)
        return response.content
        #else
        throw IntelligenceError.notAvailable
        #endif
    }

    /// Generate personalized training recommendations
    func generateRecommendations(
        recentRides: [Ride],
        goals: TrainingGoals?
    ) async throws -> [TrainingRecommendation] {
        #if canImport(FoundationModels)
        guard let session = session else {
            throw IntelligenceError.notAvailable
        }

        let prompt = buildRecommendationsPrompt(rides: recentRides, goals: goals)
        let response = try await session.respond(to: prompt, generating: RecommendationList.self)
        return response.content.recommendations
        #else
        throw IntelligenceError.notAvailable
        #endif
    }

    /// Compare two rides and provide analysis
    func compareRides(_ ride1: Ride, _ ride2: Ride) async throws -> RideComparison {
        #if canImport(FoundationModels)
        guard let session = session else {
            throw IntelligenceError.notAvailable
        }

        let prompt = buildComparisonPrompt(ride1: ride1, ride2: ride2)
        let response = try await session.respond(to: prompt, generating: RideComparison.self)
        return response.content
        #else
        throw IntelligenceError.notAvailable
        #endif
    }

    /// Generate narrative summary for statistics
    func generateStatisticsNarrative(stats: StatisticsData) async throws -> StatisticsNarrative {
        #if canImport(FoundationModels)
        guard let session = session else {
            throw IntelligenceError.notAvailable
        }

        let prompt = buildStatisticsPrompt(stats)
        let response = try await session.respond(to: prompt, generating: StatisticsNarrative.self)
        return response.content
        #else
        throw IntelligenceError.notAvailable
        #endif
    }

    /// Analyze recovery data and provide insights
    func analyzeRecovery(data: RecoveryData) async throws -> RecoveryInsights {
        #if canImport(FoundationModels)
        guard let session = session else {
            throw IntelligenceError.notAvailable
        }

        let prompt = buildRecoveryPrompt(data)
        let response = try await session.respond(to: prompt, generating: RecoveryInsights.self)
        return response.content
        #else
        throw IntelligenceError.notAvailable
        #endif
    }

    /// Natural language search across rides
    func searchRides(query: String, rides: [Ride]) async throws -> SearchResults {
        #if canImport(FoundationModels)
        guard let session = session else {
            throw IntelligenceError.notAvailable
        }

        let prompt = buildSearchPrompt(query: query, rides: rides)
        let response = try await session.respond(to: prompt, generating: SearchResults.self)
        return response.content
        #else
        throw IntelligenceError.notAvailable
        #endif
    }

    /// Generate weekly training narrative
    func generateWeeklyNarrative(rides: [Ride], recoveryData: [RecoveryDataPoint]?) async throws -> WeeklyNarrative {
        #if canImport(FoundationModels)
        guard let session = session else {
            throw IntelligenceError.notAvailable
        }

        let prompt = buildWeeklyNarrativePrompt(rides: rides, recoveryData: recoveryData)
        let response = try await session.respond(to: prompt, generating: WeeklyNarrative.self)
        return response.content
        #else
        throw IntelligenceError.notAvailable
        #endif
    }

    /// Analyze shooting pattern and provide coaching feedback
    func analyzeShootingPattern(data: ShootingPatternData) async throws -> ShootingCoachingInsights {
        #if canImport(FoundationModels)
        guard let session = session else {
            throw IntelligenceError.notAvailable
        }

        let prompt = buildShootingPatternPrompt(data)
        let response = try await session.respond(to: prompt, generating: ShootingCoachingInsights.self)
        return response.content
        #else
        throw IntelligenceError.notAvailable
        #endif
    }
}

// MARK: - Prompt Builders

@available(iOS 26.0, *)
private extension IntelligenceService {
    func buildRideSummaryPrompt(_ ride: Ride) -> String {
        """
        Analyze this equestrian training session and provide a brief, encouraging summary:

        Date: \(ride.formattedDate)
        Duration: \(ride.formattedDuration)
        Distance: \(ride.formattedDistance)
        Ride Type: \(ride.rideType.rawValue)

        Gait breakdown:
        - Walk: \(ride.gaitDuration(for: .walk).formattedDuration) (\(Int(ride.gaitPercentage(for: .walk)))%)
        - Trot: \(ride.gaitDuration(for: .trot).formattedDuration) (\(Int(ride.gaitPercentage(for: .trot)))%)
        - Canter: \(ride.gaitDuration(for: .canter).formattedDuration) (\(Int(ride.gaitPercentage(for: .canter)))%)
        - Gallop: \(ride.gaitDuration(for: .gallop).formattedDuration) (\(Int(ride.gaitPercentage(for: .gallop)))%)

        Turn balance: \(ride.turnBalancePercent)% left / \(100 - ride.turnBalancePercent)% right
        Lead balance: \(ride.leadBalancePercent)% left / \(100 - ride.leadBalancePercent)% right

        Elevation gain: \(ride.formattedElevationGain)
        Max speed: \(ride.formattedMaxSpeed)

        Notes: \(ride.notes.isEmpty ? "None" : ride.notes)
        """
    }

    func buildTrainingAnalysisPrompt(_ rides: [Ride]) -> String {
        let recentRides = rides.prefix(10)
        let totalDistance = recentRides.reduce(0) { $0 + $1.totalDistance }
        let totalDuration = recentRides.reduce(0) { $0 + $1.totalDuration }
        let avgBalance = recentRides.reduce(0) { $0 + $1.turnBalancePercent } / max(1, recentRides.count)

        return """
        Analyze these recent equestrian training sessions and identify patterns:

        Total sessions: \(recentRides.count)
        Total distance: \(totalDistance.formattedDistance)
        Total riding time: \(totalDuration.formattedDuration)
        Average turn balance: \(avgBalance)% left

        Session types: \(Dictionary(grouping: recentRides, by: { $0.rideType }).mapValues { $0.count })

        Provide insights about training consistency, balance, and areas for improvement.
        """
    }

    func buildRecommendationsPrompt(rides: [Ride], goals: TrainingGoals?) -> String {
        """
        Based on recent training data, provide personalized recommendations:

        Recent rides: \(rides.count)
        Training frequency: \(calculateFrequency(rides))
        Primary ride type: \(dominantRideType(rides))

        Goals: \(goals?.description ?? "General fitness and balance")

        Suggest specific exercises, duration, and focus areas for the next session.
        """
    }

    func buildComparisonPrompt(ride1: Ride, ride2: Ride) -> String {
        """
        Compare these two riding sessions:

        Session 1 (\(ride1.formattedDate)):
        - Duration: \(ride1.formattedDuration)
        - Distance: \(ride1.formattedDistance)
        - Type: \(ride1.rideType.rawValue)

        Session 2 (\(ride2.formattedDate)):
        - Duration: \(ride2.formattedDuration)
        - Distance: \(ride2.formattedDistance)
        - Type: \(ride2.rideType.rawValue)

        Highlight improvements and areas that need attention.
        """
    }

    func calculateFrequency(_ rides: [Ride]) -> String {
        guard rides.count >= 2,
              let first = rides.first?.startDate,
              let last = rides.last?.startDate else {
            return "Unknown"
        }
        let days = Calendar.current.dateComponents([.day], from: last, to: first).day ?? 1
        let perWeek = Double(rides.count) / max(1, Double(days) / 7)
        return String(format: "%.1f sessions/week", perWeek)
    }

    func dominantRideType(_ rides: [Ride]) -> String {
        let grouped = Dictionary(grouping: rides, by: { $0.rideType })
        return grouped.max(by: { $0.value.count < $1.value.count })?.key.rawValue ?? "Mixed"
    }

    func buildStatisticsPrompt(_ stats: StatisticsData) -> String {
        """
        Generate a natural language narrative for these equestrian training statistics:

        Period: \(stats.periodName)
        Total rides: \(stats.totalRides)
        Total distance: \(stats.totalDistance) km
        Total duration: \(stats.totalDurationHours) hours
        Average ride distance: \(stats.averageDistance) km
        Average speed: \(stats.averageSpeed) km/h

        Turn balance: \(stats.turnBalancePercent)% left / \(100 - stats.turnBalancePercent)% right
        Lead balance: \(stats.leadBalancePercent)% left / \(100 - stats.leadBalancePercent)% right

        Gait distribution:
        - Walk: \(stats.walkPercent)%
        - Trot: \(stats.trotPercent)%
        - Canter: \(stats.canterPercent)%
        - Gallop: \(stats.gallopPercent)%

        Provide a conversational summary highlighting achievements, trends, and suggestions.
        """
    }

    func buildRecoveryPrompt(_ data: RecoveryData) -> String {
        """
        Analyze this rider's recovery and readiness data:

        Current readiness score: \(data.currentReadiness)
        Average readiness (7 days): \(data.weeklyAverageReadiness)
        HRV trend: \(data.hrvTrend)
        Resting HR trend: \(data.rhrTrend)
        Sleep quality average: \(data.avgSleepQuality)/5
        Fatigue level: \(data.fatigueLevel)

        Days since last rest: \(data.daysSinceRest)
        Training load this week: \(data.weeklyTrainingLoad) sessions

        Provide personalized recovery insights and training recommendations based on current readiness.
        """
    }

    func buildSearchPrompt(query: String, rides: [Ride]) -> String {
        let ridesList = rides.prefix(20).enumerated().map { idx, ride in
            "[\(idx)]: \(ride.formattedDate), \(ride.rideType.rawValue), \(ride.formattedDistance), \(ride.formattedDuration), balance: \(ride.turnBalancePercent)%"
        }.joined(separator: "\n")

        return """
        Search through these rides for: "\(query)"

        Available rides:
        \(ridesList)

        Return the indices of rides that match the query, ranked by relevance.
        Consider: ride type, distance, duration, date, balance metrics.
        """
    }

    func buildWeeklyNarrativePrompt(rides: [Ride], recoveryData: [RecoveryDataPoint]?) -> String {
        let ridesInfo = rides.map { "\($0.formattedDate): \($0.rideType.rawValue), \($0.formattedDistance), \($0.formattedDuration)" }.joined(separator: "\n")
        let recoveryInfo = recoveryData?.map { "Readiness: \($0.readiness), HRV: \($0.hrv)" }.joined(separator: ", ") ?? "Not available"

        return """
        Generate a weekly training narrative:

        This week's rides:
        \(ridesInfo)

        Recovery data: \(recoveryInfo)

        Write a coach-like summary of the week's training, highlighting progress, consistency, and areas to focus on next week.
        """
    }

    func buildShootingPatternPrompt(_ data: ShootingPatternData) -> String {
        let shotsDescription = data.shotPositions.enumerated().map { idx, pos in
            "Shot \(idx + 1): x=\(String(format: "%.2f", pos.x)), y=\(String(format: "%.2f", pos.y))"
        }.joined(separator: "\n")

        return """
        You are a tetrathlon shooting coach analyzing a target card. Provide personalized coaching feedback based on the shot pattern.

        Shot count: \(data.shotCount)
        Target center: x=\(String(format: "%.2f", data.targetCenterX)), y=\(String(format: "%.2f", data.targetCenterY))

        Shot positions (normalized 0-1, center is 0.5,0.5):
        \(shotsDescription)

        Pattern metrics:
        - Average position: x=\(String(format: "%.2f", data.averageX)), y=\(String(format: "%.2f", data.averageY))
        - Horizontal spread: \(String(format: "%.3f", data.spreadX))
        - Vertical spread: \(String(format: "%.3f", data.spreadY))
        - Total spread (grouping): \(String(format: "%.3f", data.totalSpread))
        - Horizontal bias from center: \(String(format: "%.3f", data.horizontalBias))
        - Vertical bias from center: \(String(format: "%.3f", data.verticalBias))

        Provide coaching feedback that:
        1. Assesses grouping quality (tight cluster = good consistency)
        2. Identifies any directional bias (pulling left/right, high/low)
        3. Suggests specific technique corrections
        4. Gives an encouraging overall assessment
        5. Provides 2-3 specific drills or focus points for improvement

        Use shooting terminology appropriate for tetrathlon pistol shooting. Be encouraging but honest.
        """
    }
}

// MARK: - Generable Types for Guided Generation

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct RideSummary: Codable, Sendable {
    /// Brief one-sentence summary
    let headline: String

    /// Key achievements from the session
    let achievements: [String]

    /// Areas that could be improved
    let improvements: [String]

    /// Encouraging closing remark
    let encouragement: String

    /// Overall session rating (1-5)
    let rating: Int
}

@available(iOS 26.0, *)
@Generable
struct TrainingInsights: Codable, Sendable {
    /// Overall training trend (improving, maintaining, declining)
    let trend: String

    /// Key observations about training patterns
    let observations: [String]

    /// Identified strengths
    let strengths: [String]

    /// Areas needing attention
    let areasForImprovement: [String]

    /// Balance assessment (turns, leads, reins)
    let balanceAssessment: String
}

@available(iOS 26.0, *)
@Generable
struct TrainingRecommendation: Codable, Sendable, Identifiable {
    var id: String { title }

    /// Recommendation title
    let title: String

    /// Detailed description
    let description: String

    /// Suggested duration in minutes
    let durationMinutes: Int

    /// Priority level (high, medium, low)
    let priority: String

    /// Focus area (balance, fitness, technique, etc.)
    let focusArea: String
}

@available(iOS 26.0, *)
@Generable
struct RecommendationList: Codable, Sendable {
    let recommendations: [TrainingRecommendation]
}

@available(iOS 26.0, *)
@Generable
struct RideComparison: Codable, Sendable {
    /// Summary of comparison
    let summary: String

    /// Improvements from session 1 to 2
    let improvements: [String]

    /// Areas that declined
    let declines: [String]

    /// Consistent aspects
    let consistentAreas: [String]

    /// Overall progress assessment
    let progressAssessment: String
}

@available(iOS 26.0, *)
@Generable
struct StatisticsNarrative: Codable, Sendable {
    /// Main narrative summary (2-3 sentences)
    let summary: String

    /// Key achievements to highlight
    let achievements: [String]

    /// Areas that need attention
    let focusAreas: [String]

    /// Comparison to previous period
    let trendAnalysis: String

    /// Encouraging closing message
    let motivation: String
}

@available(iOS 26.0, *)
@Generable
struct RecoveryInsights: Codable, Sendable {
    /// Current recovery status assessment
    let status: String

    /// Detailed explanation of recovery state
    let explanation: String

    /// Training recommendation for today
    let todayRecommendation: String

    /// Suggested intensity level (1-10)
    let suggestedIntensity: Int

    /// Tips for improving recovery
    let recoveryTips: [String]

    /// Warning signs to watch for
    let warnings: [String]
}

@available(iOS 26.0, *)
@Generable
struct SearchResults: Codable, Sendable {
    /// Indices of matching rides
    let matchingIndices: [Int]

    /// Explanation of why these rides match
    let explanation: String

    /// Suggested refinements to the search
    let suggestions: [String]
}

@available(iOS 26.0, *)
@Generable
struct WeeklyNarrative: Codable, Sendable {
    /// Opening summary of the week
    let weekSummary: String

    /// Highlights from training
    let highlights: [String]

    /// Areas for improvement identified
    let improvements: [String]

    /// Focus areas for next week
    let nextWeekFocus: [String]

    /// Motivational closing
    let encouragement: String
}

@available(iOS 26.0, *)
@Generable
struct ShootingCoachingInsights: Codable, Sendable {
    /// Overall assessment of the shot group
    let overallAssessment: String

    /// Description of grouping quality
    let groupingQuality: String

    /// Identified directional bias (if any)
    let directionalBias: String

    /// Specific technique suggestions
    let techniqueSuggestions: [String]

    /// Recommended drills or exercises
    let recommendedDrills: [String]

    /// Encouraging feedback
    let encouragement: String

    /// Confidence level in the analysis (1-5)
    let confidenceLevel: Int
}
#else
// Fallback types when Foundation Models not available
struct RideSummary: Codable, Sendable {
    let headline: String
    let achievements: [String]
    let improvements: [String]
    let encouragement: String
    let rating: Int
}

struct TrainingInsights: Codable, Sendable {
    let trend: String
    let observations: [String]
    let strengths: [String]
    let areasForImprovement: [String]
    let balanceAssessment: String
}

struct TrainingRecommendation: Codable, Sendable, Identifiable {
    var id: String { title }
    let title: String
    let description: String
    let durationMinutes: Int
    let priority: String
    let focusArea: String
}

struct RecommendationList: Codable, Sendable {
    let recommendations: [TrainingRecommendation]
}

struct RideComparison: Codable, Sendable {
    let summary: String
    let improvements: [String]
    let declines: [String]
    let consistentAreas: [String]
    let progressAssessment: String
}

struct StatisticsNarrative: Codable, Sendable {
    let summary: String
    let achievements: [String]
    let focusAreas: [String]
    let trendAnalysis: String
    let motivation: String
}

struct RecoveryInsights: Codable, Sendable {
    let status: String
    let explanation: String
    let todayRecommendation: String
    let suggestedIntensity: Int
    let recoveryTips: [String]
    let warnings: [String]
}

struct SearchResults: Codable, Sendable {
    let matchingIndices: [Int]
    let explanation: String
    let suggestions: [String]
}

struct WeeklyNarrative: Codable, Sendable {
    let weekSummary: String
    let highlights: [String]
    let improvements: [String]
    let nextWeekFocus: [String]
    let encouragement: String
}

struct ShootingCoachingInsights: Codable, Sendable {
    let overallAssessment: String
    let groupingQuality: String
    let directionalBias: String
    let techniqueSuggestions: [String]
    let recommendedDrills: [String]
    let encouragement: String
    let confidenceLevel: Int
}
#endif

// MARK: - Input Data Types

struct StatisticsData {
    let periodName: String
    let totalRides: Int
    let totalDistance: Double
    let totalDurationHours: Double
    let averageDistance: Double
    let averageSpeed: Double
    let turnBalancePercent: Int
    let leadBalancePercent: Int
    let walkPercent: Double
    let trotPercent: Double
    let canterPercent: Double
    let gallopPercent: Double
}

struct RecoveryData {
    let currentReadiness: Int
    let weeklyAverageReadiness: Double
    let hrvTrend: String
    let rhrTrend: String
    let avgSleepQuality: Double
    let fatigueLevel: String
    let daysSinceRest: Int
    let weeklyTrainingLoad: Int
}

struct RecoveryDataPoint {
    let readiness: Int
    let hrv: Double
}

struct ShootingPatternData {
    let shotCount: Int
    let shotPositions: [CGPoint]
    let targetCenterX: Double
    let targetCenterY: Double
    let averageX: Double
    let averageY: Double
    let spreadX: Double
    let spreadY: Double
    let totalSpread: Double
    let horizontalBias: Double
    let verticalBias: Double
}

// MARK: - Training Goals

struct TrainingGoals: Codable {
    let focusAreas: [String]
    let weeklyTargetSessions: Int
    let weeklyTargetDuration: TimeInterval
    let primaryDiscipline: String

    var description: String {
        "Focus on \(focusAreas.joined(separator: ", ")). " +
        "Target: \(weeklyTargetSessions) sessions/week, " +
        "\(Int(weeklyTargetDuration / 3600)) hours total. " +
        "Discipline: \(primaryDiscipline)"
    }
}

// MARK: - Errors

enum IntelligenceError: Error, LocalizedError {
    case notAvailable
    case generationFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Apple Intelligence is not available on this device"
        case .generationFailed(let reason):
            return "AI generation failed: \(reason)"
        case .invalidResponse:
            return "Invalid response from AI model"
        }
    }
}
