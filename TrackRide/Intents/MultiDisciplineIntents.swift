//
//  MultiDisciplineIntents.swift
//  TrackRide
//
//  App Intents for running, swimming, and shooting disciplines
//

import AppIntents
import SwiftUI
import SwiftData

// MARK: - Discipline Enum

enum DisciplineEnum: String, AppEnum {
    case riding = "Riding"
    case running = "Running"
    case swimming = "Swimming"
    case shooting = "Shooting"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Training Discipline")
    }

    static var caseDisplayRepresentations: [DisciplineEnum: DisplayRepresentation] {
        [
            .riding: DisplayRepresentation(title: "Riding", image: .init(systemName: "figure.equestrian.sports")),
            .running: DisplayRepresentation(title: "Running", image: .init(systemName: "figure.run")),
            .swimming: DisplayRepresentation(title: "Swimming", image: .init(systemName: "figure.pool.swim")),
            .shooting: DisplayRepresentation(title: "Shooting", image: .init(systemName: "target"))
        ]
    }
}

// MARK: - Start Training Session Intent

struct StartTrainingSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Training Session"
    static var description = IntentDescription("Start a training session in any discipline")

    static var openAppWhenRun: Bool = true

    @Parameter(title: "Discipline")
    var discipline: DisciplineEnum?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let selectedDiscipline = discipline ?? .riding

        await MainActor.run {
            NotificationCenter.default.post(
                name: .startSessionFromSiri,
                object: nil,
                userInfo: ["discipline": selectedDiscipline.rawValue]
            )
        }

        return .result(dialog: IntentDialog("Starting your \(selectedDiscipline.rawValue.lowercased()) session. Good luck!"))
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Start a \(\.$discipline) session")
    }
}

// MARK: - Get Running Stats Intent

struct GetRunningStatsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Running Stats"
    static var description = IntentDescription("Get your running statistics")

    @Parameter(title: "Time Period")
    var period: StatsPeriodEnum?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let selectedPeriod = period ?? .week
        let (stats, distStr, durStr, paceStr) = try await MainActor.run {
            let s = try MultiDisciplineDataManager.shared.fetchRunningStats(for: selectedPeriod)
            return (s, s.totalDistance.formattedDistance, s.totalDuration.formattedDuration, s.averagePace.formattedPace)
        }

        guard stats.totalSessions > 0 else {
            return .result(dialog: IntentDialog("No running sessions recorded this \(selectedPeriod.rawValue). Let's change that!"))
        }

        return .result(dialog: IntentDialog("""
            This \(selectedPeriod.rawValue) you ran \(stats.totalSessions) times, \
            covering \(distStr) \
            in \(durStr). \
            Average pace: \(paceStr). \
            Great job staying active!
            """))
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Get my \(\.$period) running stats")
    }
}

// MARK: - Get Swimming Stats Intent

struct GetSwimmingStatsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Swimming Stats"
    static var description = IntentDescription("Get your swimming statistics")

    @Parameter(title: "Time Period")
    var period: StatsPeriodEnum?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let selectedPeriod = period ?? .week
        let stats = try await MainActor.run {
            try MultiDisciplineDataManager.shared.fetchSwimmingStats(for: selectedPeriod)
        }

        guard stats.totalSessions > 0 else {
            return .result(dialog: IntentDialog("No swimming sessions this \(selectedPeriod.rawValue). Time to hit the pool!"))
        }

        return .result(dialog: IntentDialog("""
            This \(selectedPeriod.rawValue) you swam \(stats.totalSessions) times, \
            completing \(Int(stats.totalDistance)) meters \
            with an average SWOLF of \(Int(stats.averageSwolf)). \
            Keep improving that efficiency!
            """))
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Get my \(\.$period) swimming stats")
    }
}

// MARK: - Get Shooting Stats Intent

struct GetShootingStatsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Shooting Stats"
    static var description = IntentDescription("Get your shooting/archery statistics")

    @Parameter(title: "Time Period")
    var period: StatsPeriodEnum?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let selectedPeriod = period ?? .week
        let stats = try await MainActor.run {
            try MultiDisciplineDataManager.shared.fetchShootingStats(for: selectedPeriod)
        }

        guard stats.totalSessions > 0 else {
            return .result(dialog: IntentDialog("No shooting sessions this \(selectedPeriod.rawValue). Time to practice!"))
        }

        return .result(dialog: IntentDialog("""
            This \(selectedPeriod.rawValue) you had \(stats.totalSessions) shooting sessions. \
            Average score: \(Int(stats.averageScore))%. \
            Total X's: \(stats.totalXCount). \
            \(stats.averageScore >= 80 ? "Excellent accuracy!" : "Keep practicing!")
            """))
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Get my \(\.$period) shooting stats")
    }
}

// MARK: - Get Combined Training Stats Intent

struct GetCombinedTrainingStatsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get All Training Stats"
    static var description = IntentDescription("Get a summary of all your training activities")

    @Parameter(title: "Time Period")
    var period: StatsPeriodEnum?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let selectedPeriod = period ?? .week
        let allStats = try await MainActor.run {
            try MultiDisciplineDataManager.shared.fetchAllDisciplineStats(for: selectedPeriod)
        }

        let totalSessions = allStats.values.reduce(0) { $0 + $1.sessions }

        guard totalSessions > 0 else {
            return .result(dialog: IntentDialog("No training sessions this \(selectedPeriod.rawValue). Let's get started!"))
        }

        var summary = "This \(selectedPeriod.rawValue): "
        var details: [String] = []

        for (discipline, stats) in allStats where stats.sessions > 0 {
            details.append("\(stats.sessions) \(discipline.rawValue.lowercased())")
        }

        summary += details.joined(separator: ", ")
        summary += ". Total: \(totalSessions) sessions. Keep up the great work!"

        return .result(dialog: IntentDialog(stringLiteral: summary))
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Get my \(\.$period) training summary")
    }
}

// MARK: - Data Manager

@MainActor
final class MultiDisciplineDataManager {
    static let shared = MultiDisciplineDataManager()

    private var modelContainer: ModelContainer?

    nonisolated init() {}

    func configure(with container: ModelContainer) {
        self.modelContainer = container
    }

    struct RunningStatsData {
        let totalSessions: Int
        let totalDistance: Double
        let totalDuration: TimeInterval
        let averagePace: TimeInterval

        static let empty = RunningStatsData(
            totalSessions: 0,
            totalDistance: 0,
            totalDuration: 0,
            averagePace: 0
        )
    }

    struct SwimmingStatsData {
        let totalSessions: Int
        let totalDistance: Double
        let totalDuration: TimeInterval
        let averageSwolf: Double

        static let empty = SwimmingStatsData(
            totalSessions: 0,
            totalDistance: 0,
            totalDuration: 0,
            averageSwolf: 0
        )
    }

    struct ShootingStatsData {
        let totalSessions: Int
        let totalShots: Int
        let averageScore: Double
        let totalXCount: Int

        static let empty = ShootingStatsData(
            totalSessions: 0,
            totalShots: 0,
            averageScore: 0,
            totalXCount: 0
        )
    }

    struct DisciplineStats {
        let sessions: Int
        let duration: TimeInterval
    }

    func fetchRunningStats(for period: StatsPeriodEnum) throws -> RunningStatsData {
        guard let container = modelContainer else { return .empty }

        let context = container.mainContext
        let range = period.dateRange

        let descriptor = FetchDescriptor<RunningSession>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let allSessions = try context.fetch(descriptor)
        let sessions = allSessions.filter { $0.startDate >= range.start && $0.startDate <= range.end }

        guard !sessions.isEmpty else { return .empty }

        let totalDistance = sessions.reduce(0) { $0 + $1.totalDistance }
        let totalDuration = sessions.reduce(0) { $0 + $1.totalDuration }
        let avgPace = sessions.reduce(0) { $0 + $1.averagePace } / Double(sessions.count)

        return RunningStatsData(
            totalSessions: sessions.count,
            totalDistance: totalDistance,
            totalDuration: totalDuration,
            averagePace: avgPace
        )
    }

    func fetchSwimmingStats(for period: StatsPeriodEnum) throws -> SwimmingStatsData {
        guard let container = modelContainer else { return .empty }

        let context = container.mainContext
        let range = period.dateRange

        let descriptor = FetchDescriptor<SwimmingSession>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let allSessions = try context.fetch(descriptor)
        let sessions = allSessions.filter { $0.startDate >= range.start && $0.startDate <= range.end }

        guard !sessions.isEmpty else { return .empty }

        let totalDistance = sessions.reduce(0) { $0 + $1.totalDistance }
        let totalDuration = sessions.reduce(0) { $0 + $1.totalDuration }
        let avgSwolf = sessions.reduce(0) { $0 + $1.averageSwolf } / Double(sessions.count)

        return SwimmingStatsData(
            totalSessions: sessions.count,
            totalDistance: totalDistance,
            totalDuration: totalDuration,
            averageSwolf: avgSwolf
        )
    }

    func fetchShootingStats(for period: StatsPeriodEnum) throws -> ShootingStatsData {
        guard let container = modelContainer else { return .empty }

        let context = container.mainContext
        let range = period.dateRange

        let descriptor = FetchDescriptor<ShootingSession>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let allSessions = try context.fetch(descriptor)
        let sessions = allSessions.filter { $0.startDate >= range.start && $0.startDate <= range.end }

        guard !sessions.isEmpty else { return .empty }

        let totalShots = sessions.reduce(0) { $0 + $1.ends.flatMap { $0.shots }.count }
        let avgScore = sessions.reduce(0) { $0 + $1.scorePercentage } / Double(sessions.count)
        let totalX = sessions.reduce(0) { $0 + $1.xCount }

        return ShootingStatsData(
            totalSessions: sessions.count,
            totalShots: totalShots,
            averageScore: avgScore,
            totalXCount: totalX
        )
    }

    func fetchAllDisciplineStats(for period: StatsPeriodEnum) throws -> [DisciplineEnum: DisciplineStats] {
        var results: [DisciplineEnum: DisciplineStats] = [:]

        // Riding
        let rideStats = try IntentDataManager.shared.fetchStatsSync(for: period)
        results[.riding] = DisciplineStats(sessions: rideStats.totalRides, duration: rideStats.totalDuration)

        // Running
        let runStats = try fetchRunningStats(for: period)
        results[.running] = DisciplineStats(sessions: runStats.totalSessions, duration: runStats.totalDuration)

        // Swimming
        let swimStats = try fetchSwimmingStats(for: period)
        results[.swimming] = DisciplineStats(sessions: swimStats.totalSessions, duration: swimStats.totalDuration)

        // Shooting
        let shootStats = try fetchShootingStats(for: period)
        results[.shooting] = DisciplineStats(sessions: shootStats.totalSessions, duration: 0)

        return results
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let startSessionFromSiri = Notification.Name("startSessionFromSiri")
}

// Note: All App Shortcuts are consolidated in TrackRideShortcuts in RideIntents.swift
