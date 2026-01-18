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

// MARK: - Multi-Discipline Training Analysis

@available(iOS 26.0, *)
extension IntelligenceService {
    /// Analyze running training sessions
    func analyzeRunningTraining(sessions: [RunningSession]) async throws -> RunningTrainingInsights {
        #if canImport(FoundationModels)
        guard let session = session else {
            throw IntelligenceError.notAvailable
        }

        let prompt = buildRunningAnalysisPrompt(sessions)
        let response = try await session.respond(to: prompt, generating: RunningTrainingInsights.self)
        return response.content
        #else
        throw IntelligenceError.notAvailable
        #endif
    }

    /// Analyze swimming training sessions
    func analyzeSwimmingTraining(sessions: [SwimmingSession]) async throws -> SwimmingTrainingInsights {
        #if canImport(FoundationModels)
        guard let session = session else {
            throw IntelligenceError.notAvailable
        }

        let prompt = buildSwimmingAnalysisPrompt(sessions)
        let response = try await session.respond(to: prompt, generating: SwimmingTrainingInsights.self)
        return response.content
        #else
        throw IntelligenceError.notAvailable
        #endif
    }

    /// Analyze shooting training sessions
    func analyzeShootingTraining(sessions: [ShootingSession]) async throws -> ShootingTrainingInsights {
        #if canImport(FoundationModels)
        guard let session = session else {
            throw IntelligenceError.notAvailable
        }

        let prompt = buildShootingTrainingPrompt(sessions)
        let response = try await session.respond(to: prompt, generating: ShootingTrainingInsights.self)
        return response.content
        #else
        throw IntelligenceError.notAvailable
        #endif
    }

    /// Analyze drill sessions for biomechanics and skill development
    func analyzeDrillSessions(sessions: [UnifiedDrillSession]) async throws -> DrillTrainingInsights {
        #if canImport(FoundationModels)
        guard let session = session else {
            throw IntelligenceError.notAvailable
        }

        let prompt = buildDrillAnalysisPrompt(sessions)
        let response = try await session.respond(to: prompt, generating: DrillTrainingInsights.self)
        return response.content
        #else
        throw IntelligenceError.notAvailable
        #endif
    }

    /// Comprehensive multi-discipline tetrathlon training analysis
    func analyzeMultiDisciplineTraining(
        rides: [Ride],
        runningSessions: [RunningSession],
        swimmingSessions: [SwimmingSession],
        shootingSessions: [ShootingSession],
        drillSessions: [UnifiedDrillSession]
    ) async throws -> MultiDisciplineInsights {
        #if canImport(FoundationModels)
        guard let session = session else {
            throw IntelligenceError.notAvailable
        }

        let prompt = buildMultiDisciplinePrompt(
            rides: rides,
            running: runningSessions,
            swimming: swimmingSessions,
            shooting: shootingSessions,
            drills: drillSessions
        )
        let response = try await session.respond(to: prompt, generating: MultiDisciplineInsights.self)
        return response.content
        #else
        throw IntelligenceError.notAvailable
        #endif
    }
}

// MARK: - Competition Insights (Apple Intelligence)

@available(iOS 26.0, *)
extension IntelligenceService {
    /// Generate performance summary for triathlon/tetrathlon competitions
    func generateCompetitionPerformanceSummary(stats: CompetitionStatistics) async throws -> CompetitionPerformanceSummary {
        #if canImport(FoundationModels)
        guard let session = session else {
            throw IntelligenceError.notAvailable
        }

        let prompt = buildCompetitionPerformancePrompt(stats)
        let response = try await session.respond(to: prompt, generating: CompetitionPerformanceSummary.self)
        return response.content
        #else
        throw IntelligenceError.notAvailable
        #endif
    }

    /// Analyze trends across competition data
    func analyzeCompetitionTrends(competitions: [Competition]) async throws -> CompetitionTrendAnalysis {
        #if canImport(FoundationModels)
        guard let session = session else {
            throw IntelligenceError.notAvailable
        }

        let prompt = buildCompetitionTrendsPrompt(competitions)
        let response = try await session.respond(to: prompt, generating: CompetitionTrendAnalysis.self)
        return response.content
        #else
        throw IntelligenceError.notAvailable
        #endif
    }

    /// Analyze weather impact on competition performance
    func analyzeWeatherImpact(competitions: [Competition]) async throws -> WeatherImpactAnalysis {
        #if canImport(FoundationModels)
        guard let session = session else {
            throw IntelligenceError.notAvailable
        }

        let prompt = buildWeatherImpactPrompt(competitions)
        let response = try await session.respond(to: prompt, generating: WeatherImpactAnalysis.self)
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

    // MARK: - Multi-Discipline Prompt Builders

    func buildRunningAnalysisPrompt(_ sessions: [RunningSession]) -> String {
        let recentSessions = sessions.prefix(10)
        let totalDistance = recentSessions.reduce(0) { $0 + $1.totalDistance }
        let totalDuration = recentSessions.reduce(0) { $0 + $1.totalDuration }
        let avgPace = recentSessions.isEmpty ? 0 : recentSessions.reduce(0) { $0 + $1.averagePace } / Double(recentSessions.count)
        let avgCadence = recentSessions.isEmpty ? 0 : recentSessions.reduce(0) { $0 + $1.averageCadence } / recentSessions.count

        let sessionTypes = Dictionary(grouping: recentSessions, by: { $0.sessionType })
            .mapValues { $0.count }
            .map { "\($0.key.rawValue): \($0.value)" }
            .joined(separator: ", ")

        return """
        Analyze these recent running training sessions for a tetrathlon athlete:

        Total sessions: \(recentSessions.count)
        Total distance: \(String(format: "%.1f", totalDistance / 1000)) km
        Total running time: \(totalDuration.formattedDuration)
        Average pace: \(avgPace.formattedPace) /km
        Average cadence: \(avgCadence) spm

        Session types: \(sessionTypes.isEmpty ? "None" : sessionTypes)

        For tetrathlon, the running discipline is typically 1500m or cross-country.
        Provide insights about:
        1. Training consistency and volume
        2. Pace development and efficiency
        3. Cadence optimization (ideal: 170-180 spm)
        4. Recommendations for tetrathlon race day
        """
    }

    func buildSwimmingAnalysisPrompt(_ sessions: [SwimmingSession]) -> String {
        let recentSessions = sessions.prefix(10)
        let totalDistance = recentSessions.reduce(0) { $0 + $1.totalDistance }
        let totalDuration = recentSessions.reduce(0) { $0 + $1.totalDuration }
        let avgPace = recentSessions.isEmpty ? 0 : recentSessions.reduce(0) { $0 + $1.averagePace } / Double(recentSessions.count)
        let avgSwolf = recentSessions.isEmpty ? 0 : recentSessions.reduce(0) { $0 + $1.averageSwolf } / Double(recentSessions.count)

        let strokes = Dictionary(grouping: recentSessions, by: { $0.dominantStroke })
            .mapValues { $0.count }
            .map { "\($0.key.rawValue): \($0.value)" }
            .joined(separator: ", ")

        return """
        Analyze these recent swimming training sessions for a tetrathlon athlete:

        Total sessions: \(recentSessions.count)
        Total distance: \(String(format: "%.0f", totalDistance)) meters
        Total swim time: \(totalDuration.formattedDuration)
        Average pace: \(avgPace.formattedSwimPace) /100m
        Average SWOLF: \(String(format: "%.1f", avgSwolf))

        Dominant strokes: \(strokes.isEmpty ? "None" : strokes)

        For tetrathlon, swimming is typically 100-200m freestyle.
        Provide insights about:
        1. Stroke efficiency (SWOLF improvement)
        2. Pace consistency
        3. Technique observations from SWOLF data
        4. Sprint vs endurance balance for tetrathlon swimming
        """
    }

    func buildShootingTrainingPrompt(_ sessions: [ShootingSession]) -> String {
        let recentSessions = sessions.prefix(10)
        let avgScore = recentSessions.isEmpty ? 0 : recentSessions.reduce(0) { $0 + $1.scorePercentage } / Double(recentSessions.count)
        let avgPerArrow = recentSessions.isEmpty ? 0 : recentSessions.reduce(0) { $0 + $1.averageScorePerArrow } / Double(recentSessions.count)
        let totalXCount = recentSessions.reduce(0) { $0 + $1.xCount }

        return """
        Analyze these recent shooting training sessions for a tetrathlon athlete:

        Total sessions: \(recentSessions.count)
        Average score: \(String(format: "%.1f", avgScore))%
        Average per arrow: \(String(format: "%.2f", avgPerArrow))
        Total X-ring hits: \(totalXCount)

        For tetrathlon, shooting uses air pistols at 10m with time pressure.
        Provide insights about:
        1. Accuracy consistency across sessions
        2. Mental focus indicators (X-ring concentration)
        3. Score progression trends
        4. Recommendations for competition shooting under pressure
        """
    }

    func buildDrillAnalysisPrompt(_ sessions: [UnifiedDrillSession]) -> String {
        let recentSessions = sessions.prefix(20)

        // Group by category/movement type
        let byCategory = Dictionary(grouping: recentSessions, by: { $0.drillType.primaryCategory.displayName })
        let categoryStats = byCategory.map { category, sessions in
            let avgScore = sessions.reduce(0) { $0 + $1.score } / Double(sessions.count)
            return "\(category): \(sessions.count) sessions, avg \(String(format: "%.0f", avgScore))%"
        }.joined(separator: "\n")

        // Overall stats
        let avgScore = recentSessions.isEmpty ? 0 : recentSessions.reduce(0) { $0 + $1.score } / Double(recentSessions.count)
        let avgCoordination = recentSessions.isEmpty ? 0 : recentSessions.reduce(0) { $0 + $1.coordinationScore } / Double(recentSessions.count)

        return """
        Analyze these biomechanics and skill drill sessions for a tetrathlon athlete:

        Total drill sessions: \(recentSessions.count)
        Average score: \(String(format: "%.0f", avgScore))%
        Average coordination: \(String(format: "%.0f", avgCoordination))%

        Breakdown by movement category:
        \(categoryStats.isEmpty ? "No data" : categoryStats)

        These drills develop foundational movement skills that transfer across all four tetrathlon disciplines.
        Provide insights about:
        1. Stability and balance development
        2. Coordination and rhythm patterns
        3. Cross-discipline skill transfer
        4. Areas needing focused drill work
        """
    }

    func buildMultiDisciplinePrompt(
        rides: [Ride],
        running: [RunningSession],
        swimming: [SwimmingSession],
        shooting: [ShootingSession],
        drills: [UnifiedDrillSession]
    ) -> String {
        // Calculate discipline-specific stats
        let rideStats = rides.isEmpty ? "No data" :
            "\(rides.count) rides, \(String(format: "%.1f", rides.reduce(0) { $0 + $1.totalDistance } / 1000)) km total"

        let runStats = running.isEmpty ? "No data" :
            "\(running.count) runs, avg pace \((running.reduce(0) { $0 + $1.averagePace } / Double(running.count)).formattedPace) /km"

        let swimStats = swimming.isEmpty ? "No data" :
            "\(swimming.count) swims, avg SWOLF \(String(format: "%.1f", swimming.reduce(0) { $0 + $1.averageSwolf } / Double(swimming.count)))"

        let shootStats = shooting.isEmpty ? "No data" :
            "\(shooting.count) sessions, avg \(String(format: "%.1f", shooting.reduce(0) { $0 + $1.scorePercentage } / Double(shooting.count)))%"

        let drillStats = drills.isEmpty ? "No data" :
            "\(drills.count) drills, avg score \(String(format: "%.0f", drills.reduce(0) { $0 + $1.score } / Double(drills.count)))%"

        // Identify training balance
        let totalSessions = rides.count + running.count + swimming.count + shooting.count
        let ridePercent = totalSessions > 0 ? Double(rides.count) / Double(totalSessions) * 100 : 0
        let runPercent = totalSessions > 0 ? Double(running.count) / Double(totalSessions) * 100 : 0
        let swimPercent = totalSessions > 0 ? Double(swimming.count) / Double(totalSessions) * 100 : 0
        let shootPercent = totalSessions > 0 ? Double(shooting.count) / Double(totalSessions) * 100 : 0

        return """
        Provide a comprehensive tetrathlon training analysis:

        DISCIPLINE BREAKDOWN:
        - Riding: \(rideStats) (\(String(format: "%.0f", ridePercent))% of training)
        - Running: \(runStats) (\(String(format: "%.0f", runPercent))% of training)
        - Swimming: \(swimStats) (\(String(format: "%.0f", swimPercent))% of training)
        - Shooting: \(shootStats) (\(String(format: "%.0f", shootPercent))% of training)

        SKILL DRILLS: \(drillStats)

        Total training sessions: \(totalSessions)

        Analyze:
        1. Overall training balance across disciplines
        2. Strongest and weakest disciplines based on data
        3. Cross-training opportunities (how skills transfer between disciplines)
        4. Specific recommendations for tetrathlon competition readiness
        5. One key insight about the athlete's training pattern

        Be encouraging but honest. Focus on actionable advice.
        """
    }

    // MARK: - Competition Prompt Builders

    func buildCompetitionPerformancePrompt(_ stats: CompetitionStatistics) -> String {
        var disciplineInfo = ""
        if stats.averageShootingPoints > 0 {
            disciplineInfo += "- Shooting: avg \(String(format: "%.0f", stats.averageShootingPoints)) pts"
            if let best = stats.bestShooting {
                disciplineInfo += " (PB: \(best.formattedValue) at \(best.venue))"
            }
            disciplineInfo += "\n"
        }
        if stats.averageSwimmingPoints > 0 {
            disciplineInfo += "- Swimming: avg \(String(format: "%.0f", stats.averageSwimmingPoints)) pts"
            if let best = stats.bestSwimming {
                disciplineInfo += " (PB: \(best.formattedValue) at \(best.venue))"
            }
            disciplineInfo += "\n"
        }
        if stats.averageRunningPoints > 0 {
            disciplineInfo += "- Running: avg \(String(format: "%.0f", stats.averageRunningPoints)) pts"
            if let best = stats.bestRunning {
                disciplineInfo += " (PB: \(best.formattedValue) at \(best.venue))"
            }
            disciplineInfo += "\n"
        }
        if stats.averageRidingPoints > 0 {
            disciplineInfo += "- Riding: avg \(String(format: "%.0f", stats.averageRidingPoints)) pts"
            if let best = stats.bestRiding {
                disciplineInfo += " (PB: \(best.formattedValue) at \(best.venue))"
            }
            disciplineInfo += "\n"
        }

        return """
        Generate a performance summary for this Pony Club tetrathlon/triathlon competitor:

        Completed competitions: \(stats.completedCompetitions)
        Tetrathlons: \(stats.tetrathlonCount)
        Triathlons: \(stats.triathlonCount)
        Average total points: \(String(format: "%.0f", stats.averageTotalPoints))
        Best total points: \(stats.bestTotal?.formattedValue ?? "N/A") at \(stats.bestTotal?.venue ?? "unknown")

        Discipline breakdown:
        \(disciplineInfo)

        Provide a brief, encouraging 2-3 sentence summary highlighting:
        1. Overall performance level
        2. Strongest discipline (contributes most to score)
        3. One encouraging observation about their progress
        """
    }

    func buildCompetitionTrendsPrompt(_ competitions: [Competition]) -> String {
        let completedComps = competitions.filter { $0.isCompleted }.sorted { $0.date < $1.date }
        guard completedComps.count >= 2 else {
            return "Not enough data for trend analysis. Need at least 2 completed competitions."
        }

        var compList = ""
        for comp in completedComps.suffix(10) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            let date = dateFormatter.string(from: comp.date)
            let venue = comp.venue.isEmpty ? "Unknown" : comp.venue
            let total = comp.storedTotalPoints ?? 0

            compList += "- \(date) at \(venue): \(String(format: "%.0f", total)) pts"
            if let shooting = comp.shootingPoints { compList += ", Shoot: \(String(format: "%.0f", shooting))" }
            if let swimming = comp.swimmingPoints { compList += ", Swim: \(String(format: "%.0f", swimming))" }
            if let running = comp.runningPoints { compList += ", Run: \(String(format: "%.0f", running))" }
            if let riding = comp.ridingPoints { compList += ", Ride: \(String(format: "%.0f", riding))" }
            compList += "\n"
        }

        return """
        Analyze trends in this tetrathlon/triathlon competitor's recent performances:

        Recent competitions (oldest to newest):
        \(compList)

        Identify:
        1. Overall scoring trend (improving, maintaining, declining)
        2. Which disciplines are improving most
        3. Any patterns (better at certain venues, seasonal variations)
        4. One specific observation that could help the athlete

        Be concise and insightful. Focus on actionable patterns.
        """
    }

    func buildWeatherImpactPrompt(_ competitions: [Competition]) -> String {
        let compsWithWeather = competitions.filter { $0.isCompleted && $0.hasWeatherData }
        guard compsWithWeather.count >= 2 else {
            return "Not enough weather data for analysis. Need at least 2 competitions with recorded weather."
        }

        var weatherData = ""
        for comp in compsWithWeather.suffix(10) {
            guard let weather = comp.weather else { continue }
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            let date = dateFormatter.string(from: comp.date)
            let total = comp.storedTotalPoints ?? 0

            weatherData += "- \(date): \(String(format: "%.0f", total)) pts | "
            weatherData += "Temp: \(weather.formattedTemperature), "
            weatherData += "Wind: \(weather.formattedWindSpeed), "
            weatherData += "Conditions: \(weather.condition)"
            if let riding = comp.ridingPoints { weatherData += " | Riding: \(String(format: "%.0f", riding))" }
            weatherData += "\n"
        }

        return """
        Analyze how weather affects this tetrathlon/triathlon competitor's performance:

        Competition data with weather:
        \(weatherData)

        Consider:
        1. Does temperature affect performance?
        2. Do wind conditions impact scores (especially riding)?
        3. Are there patterns in wet vs dry conditions?
        4. Any recommendations for adapting to different weather?

        Provide brief, practical insights about weather impact. Focus on patterns that could help preparation.
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

// MARK: - Multi-Discipline Training Insight Types

@available(iOS 26.0, *)
@Generable
struct RunningTrainingInsights: Codable, Sendable {
    /// Overall running trend (improving, maintaining, declining)
    let trend: String

    /// Summary of running performance
    let summary: String

    /// Pace assessment and recommendations
    let paceAnalysis: String

    /// Cadence optimization feedback
    let cadenceFeedback: String

    /// Tetrathlon-specific running tips
    let tetrathlonTips: [String]

    /// Encouraging message
    let encouragement: String
}

@available(iOS 26.0, *)
@Generable
struct SwimmingTrainingInsights: Codable, Sendable {
    /// Overall swimming trend (improving, maintaining, declining)
    let trend: String

    /// Summary of swimming performance
    let summary: String

    /// SWOLF/efficiency analysis
    let efficiencyAnalysis: String

    /// Stroke technique observations
    let techniqueObservations: String

    /// Tetrathlon-specific swimming tips
    let tetrathlonTips: [String]

    /// Encouraging message
    let encouragement: String
}

@available(iOS 26.0, *)
@Generable
struct ShootingTrainingInsights: Codable, Sendable {
    /// Overall shooting trend (improving, maintaining, declining)
    let trend: String

    /// Summary of shooting performance
    let summary: String

    /// Accuracy and consistency analysis
    let accuracyAnalysis: String

    /// Mental focus observations
    let mentalFocusObservations: String

    /// Tetrathlon-specific shooting tips
    let tetrathlonTips: [String]

    /// Encouraging message
    let encouragement: String
}

@available(iOS 26.0, *)
@Generable
struct DrillTrainingInsights: Codable, Sendable {
    /// Overall biomechanics trend
    let trend: String

    /// Summary of drill performance
    let summary: String

    /// Stability and balance assessment
    let stabilityAssessment: String

    /// Coordination and rhythm analysis
    let coordinationAnalysis: String

    /// Cross-discipline transfer benefits
    let crossDisciplineBenefits: [String]

    /// Areas needing focused work
    let focusAreas: [String]

    /// Encouraging message
    let encouragement: String
}

@available(iOS 26.0, *)
@Generable
struct MultiDisciplineInsights: Codable, Sendable {
    /// Overall tetrathlon readiness trend
    let trend: String

    /// Comprehensive training summary
    let summary: String

    /// Strongest discipline identified
    let strongestDiscipline: String

    /// Discipline needing most work
    let weakestDiscipline: String

    /// Training balance assessment
    let balanceAssessment: String

    /// Cross-training opportunities
    let crossTrainingOpportunities: [String]

    /// Specific recommendations
    let recommendations: [String]

    /// Key insight about training pattern
    let keyInsight: String

    /// Encouraging message
    let encouragement: String
}

// MARK: - Competition Insight Types (Apple Intelligence)

@available(iOS 26.0, *)
@Generable
struct CompetitionPerformanceSummary: Codable, Sendable {
    /// Brief 2-3 sentence performance summary
    let summary: String

    /// The athlete's strongest discipline
    let strongestDiscipline: String

    /// Percentage contribution of strongest discipline
    let strongestContribution: Int

    /// Overall performance level (beginner, intermediate, advanced, elite)
    let performanceLevel: String

    /// Encouraging observation
    let encouragement: String
}

@available(iOS 26.0, *)
@Generable
struct CompetitionTrendAnalysis: Codable, Sendable {
    /// Overall trend direction (improving, maintaining, declining)
    let overallTrend: String

    /// Brief trend summary
    let summary: String

    /// Disciplines showing most improvement
    let improvingDisciplines: [String]

    /// Identified patterns
    let patterns: [String]

    /// Actionable insight for the athlete
    let actionableInsight: String
}

@available(iOS 26.0, *)
@Generable
struct WeatherImpactAnalysis: Codable, Sendable {
    /// Brief summary of weather impact
    let summary: String

    /// Best performing conditions
    let bestConditions: String

    /// Challenging conditions identified
    let challengingConditions: String

    /// Weather-related patterns
    let patterns: [String]

    /// Practical recommendations
    let recommendations: [String]
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

// Multi-discipline insight fallback types
struct RunningTrainingInsights: Codable, Sendable {
    let trend: String
    let summary: String
    let paceAnalysis: String
    let cadenceFeedback: String
    let tetrathlonTips: [String]
    let encouragement: String
}

struct SwimmingTrainingInsights: Codable, Sendable {
    let trend: String
    let summary: String
    let efficiencyAnalysis: String
    let techniqueObservations: String
    let tetrathlonTips: [String]
    let encouragement: String
}

struct ShootingTrainingInsights: Codable, Sendable {
    let trend: String
    let summary: String
    let accuracyAnalysis: String
    let mentalFocusObservations: String
    let tetrathlonTips: [String]
    let encouragement: String
}

struct DrillTrainingInsights: Codable, Sendable {
    let trend: String
    let summary: String
    let stabilityAssessment: String
    let coordinationAnalysis: String
    let crossDisciplineBenefits: [String]
    let focusAreas: [String]
    let encouragement: String
}

struct MultiDisciplineInsights: Codable, Sendable {
    let trend: String
    let summary: String
    let strongestDiscipline: String
    let weakestDiscipline: String
    let balanceAssessment: String
    let crossTrainingOpportunities: [String]
    let recommendations: [String]
    let keyInsight: String
    let encouragement: String
}

// Competition insight fallback types
struct CompetitionPerformanceSummary: Codable, Sendable {
    let summary: String
    let strongestDiscipline: String
    let strongestContribution: Int
    let performanceLevel: String
    let encouragement: String
}

struct CompetitionTrendAnalysis: Codable, Sendable {
    let overallTrend: String
    let summary: String
    let improvingDisciplines: [String]
    let patterns: [String]
    let actionableInsight: String
}

struct WeatherImpactAnalysis: Codable, Sendable {
    let summary: String
    let bestConditions: String
    let challengingConditions: String
    let patterns: [String]
    let recommendations: [String]
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
