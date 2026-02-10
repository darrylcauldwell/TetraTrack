//
//  ArtifactStatisticsService.swift
//  TetraTrack
//
//  Computes training insights and statistics from CloudKit TrainingArtifacts.
//  Primary data source for iPad review mode - no SwiftData dependency.
//

import Foundation
import SwiftUI

// MARK: - Artifact Statistics

/// Aggregated statistics computed from TrainingArtifacts
struct ArtifactStatistics: Sendable {
    // MARK: - Overview
    let totalSessions: Int
    let totalDuration: TimeInterval
    let totalDistance: Double  // meters
    let sessionsThisWeek: Int
    let durationThisWeek: TimeInterval

    // MARK: - By Discipline
    let sessionsByDiscipline: [TrainingDiscipline: Int]
    let durationByDiscipline: [TrainingDiscipline: TimeInterval]
    let distanceByDiscipline: [TrainingDiscipline: Double]

    // MARK: - Recent Activity
    let recentSessions: [ArtifactSummary]
    let personalBests: [ArtifactSummary]
    let currentStreak: Int  // consecutive days with activity

    // MARK: - Trends
    let weeklyTrend: [WeeklyActivitySummary]

    // MARK: - Computed Properties

    var formattedTotalDistance: String {
        totalDistance.formattedDistance
    }

    var formattedTotalDuration: String {
        totalDuration.formattedDuration
    }

    var formattedWeeklyDuration: String {
        durationThisWeek.formattedDuration
    }

    var mostActiveDiscipline: TrainingDiscipline? {
        sessionsByDiscipline.max(by: { $0.value < $1.value })?.key
    }

    // MARK: - Empty State

    static let empty = ArtifactStatistics(
        totalSessions: 0,
        totalDuration: 0,
        totalDistance: 0,
        sessionsThisWeek: 0,
        durationThisWeek: 0,
        sessionsByDiscipline: [:],
        durationByDiscipline: [:],
        distanceByDiscipline: [:],
        recentSessions: [],
        personalBests: [],
        currentStreak: 0,
        weeklyTrend: []
    )
}

/// Summary of a single artifact for display
struct ArtifactSummary: Identifiable, Sendable {
    let id: UUID
    let name: String
    let discipline: TrainingDiscipline
    let sessionType: String
    let startTime: Date
    let duration: TimeInterval
    let distance: Double?
    let isPersonalBest: Bool
    let disciplineSummary: String  // e.g., "5km run at 5:30/km pace"

    var formattedDate: String {
        startTime.formatted(date: .abbreviated, time: .shortened)
    }

    var formattedDuration: String {
        duration.formattedDuration
    }
}

/// Weekly activity summary for trend charts
struct WeeklyActivitySummary: Identifiable, Sendable {
    let id: UUID = UUID()
    let weekStartDate: Date
    let sessionCount: Int
    let totalDuration: TimeInterval
    let totalDistance: Double
    let byDiscipline: [TrainingDiscipline: Int]

    var weekLabel: String {
        Formatters.shortMonthDay(weekStartDate)
    }
}

// MARK: - Artifact Statistics Service

/// Service that computes statistics from TrainingArtifacts.
/// Used by iPad for read-only review without SwiftData dependency.
/// Includes offline caching for immediate display on launch.
@Observable
final class ArtifactStatisticsService {

    // MARK: - Constants

    private static let cacheKey = "dev.dreamfold.tetratrack.artifactCache"
    private static let cacheTimestampKey = "dev.dreamfold.tetratrack.artifactCacheTimestamp"
    private static let maxCachedArtifacts = 50

    // MARK: - Published State

    private(set) var statistics: ArtifactStatistics = .empty
    private(set) var isLoading: Bool = false
    private(set) var lastUpdated: Date?
    private(set) var error: String?
    private(set) var isUsingCachedData: Bool = false

    // MARK: - Private State

    private var artifacts: [TrainingArtifact] = []

    // MARK: - Initialization

    init() {
        // Load cached data on init for immediate display
        loadFromCache()
    }

    // MARK: - Public Methods

    /// Updates statistics from a new set of artifacts and caches them
    func updateStatistics(from artifacts: [TrainingArtifact]) {
        self.artifacts = artifacts
        self.statistics = computeStatistics(from: artifacts)
        self.lastUpdated = Date()
        self.error = nil
        self.isUsingCachedData = false

        // Cache the most recent artifacts for offline access
        saveToCache(artifacts: artifacts)
    }

    // MARK: - Offline Cache

    /// Loads cached artifacts for immediate display
    private func loadFromCache() {
        guard let data = UserDefaults.standard.data(forKey: Self.cacheKey),
              let cachedArtifacts = try? JSONDecoder().decode([CachedArtifact].self, from: data) else {
            return
        }

        // Convert cached artifacts to TrainingArtifact models
        let loadedArtifacts = cachedArtifacts.compactMap { $0.toTrainingArtifact() }

        if !loadedArtifacts.isEmpty {
            self.artifacts = loadedArtifacts
            self.statistics = computeStatistics(from: loadedArtifacts)
            self.isUsingCachedData = true

            if let timestamp = UserDefaults.standard.object(forKey: Self.cacheTimestampKey) as? Date {
                self.lastUpdated = timestamp
            }
        }
    }

    /// Saves the most recent artifacts to cache
    private func saveToCache(artifacts: [TrainingArtifact]) {
        let recentArtifacts = artifacts
            .sorted { $0.startTime > $1.startTime }
            .prefix(Self.maxCachedArtifacts)
            .map { CachedArtifact(from: $0) }

        guard let data = try? JSONEncoder().encode(Array(recentArtifacts)) else { return }

        UserDefaults.standard.set(data, forKey: Self.cacheKey)
        UserDefaults.standard.set(Date(), forKey: Self.cacheTimestampKey)
    }

    /// Clears the offline cache
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: Self.cacheKey)
        UserDefaults.standard.removeObject(forKey: Self.cacheTimestampKey)
        isUsingCachedData = false
    }

    /// Returns the age of cached data
    var cacheAge: TimeInterval? {
        guard let timestamp = UserDefaults.standard.object(forKey: Self.cacheTimestampKey) as? Date else {
            return nil
        }
        return Date().timeIntervalSince(timestamp)
    }

    /// Whether cached data is stale (older than 1 hour)
    var isCacheStale: Bool {
        guard let age = cacheAge else { return true }
        return age > 3600  // 1 hour
    }

    /// Marks loading state
    func beginLoading() {
        isLoading = true
        error = nil
    }

    /// Marks loading complete
    func finishLoading() {
        isLoading = false
    }

    /// Marks loading failed
    func failLoading(message: String) {
        isLoading = false
        error = message
    }

    /// Gets filtered artifacts by discipline
    func artifacts(for discipline: TrainingDiscipline) -> [ArtifactSummary] {
        artifacts
            .filter { $0.discipline == discipline }
            .sorted { $0.startTime > $1.startTime }
            .map { createSummary(from: $0) }
    }

    /// Gets artifacts for a date range
    func artifacts(from startDate: Date, to endDate: Date) -> [ArtifactSummary] {
        artifacts
            .filter { $0.startTime >= startDate && $0.startTime <= endDate }
            .sorted { $0.startTime > $1.startTime }
            .map { createSummary(from: $0) }
    }

    /// Gets recent artifacts (last N)
    func recentArtifacts(limit: Int = 10) -> [ArtifactSummary] {
        artifacts
            .sorted { $0.startTime > $1.startTime }
            .prefix(limit)
            .map { createSummary(from: $0) }
    }

    // MARK: - Private Methods

    private func computeStatistics(from artifacts: [TrainingArtifact]) -> ArtifactStatistics {
        guard !artifacts.isEmpty else { return .empty }

        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now

        // Basic aggregations
        var totalDuration: TimeInterval = 0
        var totalDistance: Double = 0
        var weeklyDuration: TimeInterval = 0
        var weeklySessions = 0

        var sessionsByDiscipline: [TrainingDiscipline: Int] = [:]
        var durationByDiscipline: [TrainingDiscipline: TimeInterval] = [:]
        var distanceByDiscipline: [TrainingDiscipline: Double] = [:]

        var personalBests: [ArtifactSummary] = []

        // Track activity by day for streak calculation
        var activeDays: Set<Date> = []

        for artifact in artifacts {
            let duration = artifact.duration
            let distance = artifact.distance ?? 0
            let discipline = artifact.discipline

            totalDuration += duration
            totalDistance += distance

            sessionsByDiscipline[discipline, default: 0] += 1
            durationByDiscipline[discipline, default: 0] += duration
            distanceByDiscipline[discipline, default: 0] += distance

            // This week
            if artifact.startTime >= startOfWeek {
                weeklySessions += 1
                weeklyDuration += duration
            }

            // Personal bests
            if artifact.personalBest {
                personalBests.append(createSummary(from: artifact))
            }

            // Activity day
            let activityDay = calendar.startOfDay(for: artifact.startTime)
            activeDays.insert(activityDay)
        }

        // Calculate streak
        let currentStreak = calculateStreak(activeDays: activeDays, calendar: calendar)

        // Recent sessions
        let recentSessions = artifacts
            .sorted { $0.startTime > $1.startTime }
            .prefix(10)
            .map { createSummary(from: $0) }

        // Weekly trend (last 8 weeks)
        let weeklyTrend = calculateWeeklyTrend(artifacts: artifacts, calendar: calendar)

        return ArtifactStatistics(
            totalSessions: artifacts.count,
            totalDuration: totalDuration,
            totalDistance: totalDistance,
            sessionsThisWeek: weeklySessions,
            durationThisWeek: weeklyDuration,
            sessionsByDiscipline: sessionsByDiscipline,
            durationByDiscipline: durationByDiscipline,
            distanceByDiscipline: distanceByDiscipline,
            recentSessions: Array(recentSessions),
            personalBests: personalBests.sorted { $0.startTime > $1.startTime },
            currentStreak: currentStreak,
            weeklyTrend: weeklyTrend
        )
    }

    private func createSummary(from artifact: TrainingArtifact) -> ArtifactSummary {
        let disciplineSummary = createDisciplineSummary(from: artifact)

        return ArtifactSummary(
            id: artifact.id,
            name: artifact.name,
            discipline: artifact.discipline,
            sessionType: artifact.sessionType,
            startTime: artifact.startTime,
            duration: artifact.duration,
            distance: artifact.distance,
            isPersonalBest: artifact.personalBest,
            disciplineSummary: disciplineSummary
        )
    }

    private func createDisciplineSummary(from artifact: TrainingArtifact) -> String {
        switch artifact.discipline {
        case .riding:
            if let data = artifact.getRidingData() {
                let speed = data.averageSpeed * 3.6  // m/s to km/h
                if let horseName = data.horseName {
                    return "\(horseName) • \(String(format: "%.1f", speed)) km/h avg"
                }
                return "\(String(format: "%.1f", speed)) km/h average speed"
            }
            return artifact.formattedDistance

        case .running:
            if let data = artifact.getRunningData() {
                let paceMinutes = Int(data.averagePace) / 60
                let paceSeconds = Int(data.averagePace) % 60
                return "\(artifact.formattedDistance) at \(paceMinutes):\(String(format: "%02d", paceSeconds))/km"
            }
            return artifact.formattedDistance

        case .swimming:
            if let data = artifact.getSwimmingData() {
                return "\(data.lapCount) laps • \(String(format: "%.0f", data.averageSwolf)) SWOLF"
            }
            return artifact.formattedDistance

        case .shooting:
            if let data = artifact.getShootingData() {
                return "\(data.totalScore)/\(data.maxPossibleScore) • \(data.shotCount) shots"
            }
            return "\(artifact.sessionType)"
        }
    }

    private func calculateStreak(activeDays: Set<Date>, calendar: Calendar) -> Int {
        guard !activeDays.isEmpty else { return 0 }

        let sortedDays = activeDays.sorted(by: >)  // Most recent first
        var streak = 0
        var expectedDay = calendar.startOfDay(for: Date())

        for day in sortedDays {
            if day == expectedDay {
                streak += 1
                expectedDay = calendar.date(byAdding: .day, value: -1, to: expectedDay) ?? expectedDay
            } else if day < expectedDay {
                // Gap in streak
                break
            }
        }

        return streak
    }

    private func calculateWeeklyTrend(
        artifacts: [TrainingArtifact],
        calendar: Calendar
    ) -> [WeeklyActivitySummary] {
        let now = Date()
        var weeks: [WeeklyActivitySummary] = []

        // Go back 8 weeks
        for weekOffset in 0..<8 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: now),
                  let weekStartNormalized = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart)),
                  let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStartNormalized) else {
                continue
            }

            let weekArtifacts = artifacts.filter { artifact in
                artifact.startTime >= weekStartNormalized && artifact.startTime < weekEnd
            }

            var totalDuration: TimeInterval = 0
            var totalDistance: Double = 0
            var byDiscipline: [TrainingDiscipline: Int] = [:]

            for artifact in weekArtifacts {
                totalDuration += artifact.duration
                totalDistance += artifact.distance ?? 0
                byDiscipline[artifact.discipline, default: 0] += 1
            }

            weeks.append(WeeklyActivitySummary(
                weekStartDate: weekStartNormalized,
                sessionCount: weekArtifacts.count,
                totalDuration: totalDuration,
                totalDistance: totalDistance,
                byDiscipline: byDiscipline
            ))
        }

        return weeks.reversed()  // Oldest first for charts
    }
}

// MARK: - Discipline-Specific Statistics

extension ArtifactStatisticsService {

    /// Gets riding-specific statistics
    func ridingStatistics() -> RidingStatisticsSummary {
        let ridingArtifacts = artifacts.filter { $0.discipline == .riding }

        var totalWalkTime: TimeInterval = 0
        var totalTrotTime: TimeInterval = 0
        var totalCanterTime: TimeInterval = 0
        var totalGallopTime: TimeInterval = 0
        var horses: Set<String> = []

        for artifact in ridingArtifacts {
            if let data = artifact.getRidingData() {
                totalWalkTime += data.gaitDurations["walk"] ?? 0
                totalTrotTime += data.gaitDurations["trot"] ?? 0
                totalCanterTime += data.gaitDurations["canter"] ?? 0
                totalGallopTime += data.gaitDurations["gallop"] ?? 0
                if let horse = data.horseName {
                    horses.insert(horse)
                }
            }
        }

        return RidingStatisticsSummary(
            sessionCount: ridingArtifacts.count,
            totalWalkTime: totalWalkTime,
            totalTrotTime: totalTrotTime,
            totalCanterTime: totalCanterTime,
            totalGallopTime: totalGallopTime,
            uniqueHorses: horses.count
        )
    }

    /// Gets running-specific statistics
    func runningStatistics() -> RunningStatisticsSummary {
        let runningArtifacts = artifacts.filter { $0.discipline == .running }

        var totalDistance: Double = 0
        var bestPace: TimeInterval = .infinity
        var bestPaceArtifactName: String?

        for artifact in runningArtifacts {
            totalDistance += artifact.distance ?? 0
            if let data = artifact.getRunningData(), data.averagePace > 0 && data.averagePace < bestPace {
                bestPace = data.averagePace
                bestPaceArtifactName = artifact.name
            }
        }

        return RunningStatisticsSummary(
            sessionCount: runningArtifacts.count,
            totalDistance: totalDistance,
            bestPace: bestPace == .infinity ? nil : bestPace,
            bestPaceSessionName: bestPaceArtifactName
        )
    }

    /// Gets swimming-specific statistics
    func swimmingStatistics() -> SwimmingStatisticsSummary {
        let swimmingArtifacts = artifacts.filter { $0.discipline == .swimming }

        var totalLaps = 0
        var totalStrokes = 0
        var bestSwolf: Double = .infinity
        var bestSwolfArtifactName: String?

        for artifact in swimmingArtifacts {
            if let data = artifact.getSwimmingData() {
                totalLaps += data.lapCount
                totalStrokes += data.totalStrokes
                if data.averageSwolf > 0 && data.averageSwolf < bestSwolf {
                    bestSwolf = data.averageSwolf
                    bestSwolfArtifactName = artifact.name
                }
            }
        }

        return SwimmingStatisticsSummary(
            sessionCount: swimmingArtifacts.count,
            totalLaps: totalLaps,
            totalStrokes: totalStrokes,
            bestSwolf: bestSwolf == .infinity ? nil : bestSwolf,
            bestSwolfSessionName: bestSwolfArtifactName
        )
    }

    /// Gets shooting-specific statistics
    func shootingStatistics() -> ShootingStatisticsSummary {
        let shootingArtifacts = artifacts.filter { $0.discipline == .shooting }

        var totalShots = 0
        var totalScore = 0
        var totalMaxScore = 0
        var bestScore = 0
        var bestScoreArtifactName: String?

        for artifact in shootingArtifacts {
            if let data = artifact.getShootingData() {
                totalShots += data.shotCount
                totalScore += data.totalScore
                totalMaxScore += data.maxPossibleScore
                if data.totalScore > bestScore {
                    bestScore = data.totalScore
                    bestScoreArtifactName = artifact.name
                }
            }
        }

        let averageAccuracy = totalMaxScore > 0 ? Double(totalScore) / Double(totalMaxScore) * 100 : 0

        return ShootingStatisticsSummary(
            sessionCount: shootingArtifacts.count,
            totalShots: totalShots,
            totalScore: totalScore,
            averageAccuracy: averageAccuracy,
            bestScore: bestScore > 0 ? bestScore : nil,
            bestScoreSessionName: bestScoreArtifactName
        )
    }
}

// MARK: - Discipline Summary Structs

struct RidingStatisticsSummary: Sendable {
    let sessionCount: Int
    let totalWalkTime: TimeInterval
    let totalTrotTime: TimeInterval
    let totalCanterTime: TimeInterval
    let totalGallopTime: TimeInterval
    let uniqueHorses: Int

    var totalRidingTime: TimeInterval {
        totalWalkTime + totalTrotTime + totalCanterTime + totalGallopTime
    }
}

struct RunningStatisticsSummary: Sendable {
    let sessionCount: Int
    let totalDistance: Double
    let bestPace: TimeInterval?
    let bestPaceSessionName: String?

    var formattedTotalDistance: String {
        totalDistance.formattedDistance
    }

    var formattedBestPace: String? {
        guard let pace = bestPace else { return nil }
        return pace.formattedPace
    }
}

struct SwimmingStatisticsSummary: Sendable {
    let sessionCount: Int
    let totalLaps: Int
    let totalStrokes: Int
    let bestSwolf: Double?
    let bestSwolfSessionName: String?
}

struct ShootingStatisticsSummary: Sendable {
    let sessionCount: Int
    let totalShots: Int
    let totalScore: Int
    let averageAccuracy: Double
    let bestScore: Int?
    let bestScoreSessionName: String?

    var formattedAccuracy: String {
        String(format: "%.1f%%", averageAccuracy)
    }
}

// MARK: - Widget Data Support

extension ArtifactStatisticsService {

    /// Returns recent sessions in widget-ready format.
    /// This is the primary method for WidgetDataSyncService to get session data.
    func getWidgetRecentSessions(limit: Int = 5) -> [WidgetSessionData] {
        artifacts
            .sorted { $0.startTime > $1.startTime }
            .prefix(limit)
            .map { artifact in
                let sessionType: WidgetSessionData.WidgetSessionType = {
                    switch artifact.discipline {
                    case .riding: return .ride
                    case .running: return .run
                    case .swimming: return .swim
                    case .shooting: return .shoot
                    }
                }()

                let horseName: String? = {
                    if artifact.discipline == .riding,
                       let ridingData = artifact.getRidingData() {
                        return ridingData.horseName
                    }
                    return nil
                }()

                return WidgetSessionData(
                    id: artifact.id,
                    name: artifact.name.isEmpty ? artifact.discipline.rawValue : artifact.name,
                    date: artifact.startTime,
                    sessionType: sessionType,
                    duration: artifact.duration,
                    distance: artifact.distance ?? 0,
                    horseName: horseName
                )
            }
    }

    /// Returns sessions for a specific discipline in widget-ready format.
    func getWidgetSessions(for discipline: TrainingDiscipline, limit: Int = 5) -> [WidgetSessionData] {
        artifacts
            .filter { $0.discipline == discipline }
            .sorted { $0.startTime > $1.startTime }
            .prefix(limit)
            .map { artifact in
                let sessionType: WidgetSessionData.WidgetSessionType = {
                    switch artifact.discipline {
                    case .riding: return .ride
                    case .running: return .run
                    case .swimming: return .swim
                    case .shooting: return .shoot
                    }
                }()

                let horseName: String? = {
                    if artifact.discipline == .riding,
                       let ridingData = artifact.getRidingData() {
                        return ridingData.horseName
                    }
                    return nil
                }()

                return WidgetSessionData(
                    id: artifact.id,
                    name: artifact.name.isEmpty ? artifact.discipline.rawValue : artifact.name,
                    date: artifact.startTime,
                    sessionType: sessionType,
                    duration: artifact.duration,
                    distance: artifact.distance ?? 0,
                    horseName: horseName
                )
            }
    }

    /// Returns a summary suitable for widget display.
    struct WidgetStatsSummary {
        let totalSessions: Int
        let sessionsThisWeek: Int
        let currentStreak: Int
        let mostActiveDiscipline: TrainingDiscipline?
        let totalDurationThisWeek: TimeInterval
    }

    func getWidgetStatsSummary() -> WidgetStatsSummary {
        WidgetStatsSummary(
            totalSessions: statistics.totalSessions,
            sessionsThisWeek: statistics.sessionsThisWeek,
            currentStreak: statistics.currentStreak,
            mostActiveDiscipline: statistics.mostActiveDiscipline,
            totalDurationThisWeek: statistics.durationThisWeek
        )
    }

    /// Checks if cached data is available for widget use.
    var hasDataForWidgets: Bool {
        !artifacts.isEmpty
    }

    /// Returns the count of sessions by discipline for widget charts.
    var widgetDisciplineBreakdown: [TrainingDiscipline: Int] {
        statistics.sessionsByDiscipline
    }
}

// MARK: - Cached Artifact for Offline Storage

/// Lightweight Codable representation of TrainingArtifact for offline caching.
/// Stored in UserDefaults for immediate display on app launch.
struct CachedArtifact: Codable {
    let id: UUID
    let name: String
    let disciplineRaw: String  // Raw value of TrainingDiscipline
    let sessionType: String
    let startTime: Date
    let endTime: Date?
    let distance: Double?
    let averageHeartRate: Int?
    let caloriesBurned: Int?
    let personalBest: Bool
    let notes: String?

    // Discipline-specific data as JSON
    let disciplineData: Data?

    // Sync status
    let syncStatusRaw: String

    /// Creates a cached artifact from a TrainingArtifact
    init(from artifact: TrainingArtifact) {
        self.id = artifact.id
        self.name = artifact.name
        self.disciplineRaw = artifact.discipline.rawValue
        self.sessionType = artifact.sessionType
        self.startTime = artifact.startTime
        self.endTime = artifact.endTime
        self.distance = artifact.distance
        self.averageHeartRate = artifact.averageHeartRate
        self.caloriesBurned = artifact.caloriesBurned
        self.personalBest = artifact.personalBest
        self.notes = artifact.notes
        self.disciplineData = artifact.disciplineData
        self.syncStatusRaw = artifact.syncStatus.rawValue
    }

    /// Converts back to a TrainingArtifact model
    func toTrainingArtifact() -> TrainingArtifact? {
        guard let discipline = TrainingDiscipline(rawValue: disciplineRaw),
              let syncStatus = SyncStatus(rawValue: syncStatusRaw) else {
            return nil
        }

        let artifact = TrainingArtifact(
            discipline: discipline,
            sessionType: sessionType,
            name: name,
            startTime: startTime
        )
        artifact.id = id
        artifact.endTime = endTime
        artifact.distance = distance
        artifact.averageHeartRate = averageHeartRate
        artifact.caloriesBurned = caloriesBurned
        artifact.personalBest = personalBest
        artifact.notes = notes
        artifact.disciplineData = disciplineData
        artifact.syncStatus = syncStatus

        return artifact
    }
}
