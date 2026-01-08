//
//  IntelligentIntents.swift
//  TrackRide
//
//  Enhanced App Intents with Apple Intelligence integration
//  Enables natural language queries about training sessions
//

import AppIntents
import SwiftUI
import SwiftData

// MARK: - Get Last Ride Summary Intent

/// Intent for querying the last ride with AI-generated summary
struct GetLastRideSummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Last Ride Summary"
    static var description = IntentDescription("Get an AI-powered summary of your most recent ride")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let ride = try await MainActor.run {
            try IntentDataManager.shared.fetchLastRideSync()
        }

        guard let ride = ride else {
            return .result(dialog: IntentDialog("You haven't recorded any rides yet. Would you like to start one?"))
        }

        let dateStr = await MainActor.run { ride.formattedDate }
        let distanceStr = await MainActor.run { ride.formattedDistance }
        let durationStr = await MainActor.run { ride.formattedDuration }

        return .result(dialog: IntentDialog("Your last ride on \(dateStr): \(distanceStr) in \(durationStr). Great job!"))
    }
}

// MARK: - Get Training Stats Intent

/// Intent for querying weekly/monthly training statistics
struct GetTrainingStatsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Training Stats"
    static var description = IntentDescription("Get your training statistics for a time period")

    @Parameter(title: "Time Period")
    var period: StatsPeriodEnum?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let selectedPeriod = period ?? .week
        let (stats, distStr, durStr) = try await MainActor.run {
            let s = try IntentDataManager.shared.fetchStatsSync(for: selectedPeriod)
            return (s, s.totalDistance.formattedDistance, s.totalDuration.formattedDuration)
        }

        let message = "This \(selectedPeriod.rawValue): \(stats.totalRides) rides, \(distStr) covered, \(durStr) total riding time. Keep it up!"
        return .result(dialog: IntentDialog(stringLiteral: message))
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Get my \(\.$period) training stats")
    }
}

// MARK: - Compare Rides Intent

/// Intent for comparing two rides
struct CompareRidesIntent: AppIntent {
    static var title: LocalizedStringResource = "Compare Rides"
    static var description = IntentDescription("Compare your recent rides to see progress")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let rides = try await MainActor.run {
            try IntentDataManager.shared.fetchRecentRidesSync(limit: 2)
        }

        guard rides.count >= 2 else {
            return .result(dialog: IntentDialog("You need at least 2 rides to compare. Keep riding!"))
        }

        let comparison = await MainActor.run {
            compareRides(rides[0], rides[1])
        }

        return .result(dialog: IntentDialog(stringLiteral: comparison))
    }

    @MainActor
    private func compareRides(_ recent: Ride, _ previous: Ride) -> String {
        let distanceDiff = recent.totalDistance - previous.totalDistance
        let durationDiff = recent.totalDuration - previous.totalDuration

        var result = "Comparing your last two rides: "

        if distanceDiff > 0 {
            result += "You rode \(distanceDiff.formattedDistanceShort) farther! "
        } else if distanceDiff < 0 {
            result += "Distance was \(abs(distanceDiff).formattedDistanceShort) less. "
        }

        if durationDiff > 60 {
            result += "Duration increased by \(Int(durationDiff / 60)) minutes. "
        } else if durationDiff < -60 {
            result += "Duration decreased by \(Int(abs(durationDiff) / 60)) minutes. "
        }

        result += "Great progress!"
        return result
    }
}

// MARK: - Get Horse Stats Intent

/// Intent for querying a specific horse's statistics
struct GetHorseStatsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Horse Stats"
    static var description = IntentDescription("Get training statistics for a specific horse")

    @Parameter(title: "Horse Name")
    var horseName: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let name = horseName else {
            return .result(dialog: IntentDialog("Which horse would you like stats for?"))
        }

        let result = try await MainActor.run { () -> (stats: HorseStatsData, distStr: String, durStr: String)? in
            guard let s = try IntentDataManager.shared.fetchHorseStatsByName(name) else { return nil }
            return (s, s.totalDistance.formattedDistance, s.totalDuration.formattedDuration)
        }

        guard let (stats, distStr, durStr) = result else {
            return .result(dialog: IntentDialog("I couldn't find a horse named \(name)."))
        }

        let message = "\(name) has completed \(stats.totalRides) rides covering \(distStr) over \(durStr). Keep up the great training!"
        return .result(dialog: IntentDialog(stringLiteral: message))
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Get stats for \(\.$horseName)")
    }
}

// MARK: - Quick Log Ride Note Intent

/// Intent for quickly adding a note to the last ride via Siri
struct AddRideNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Ride Note"
    static var description = IntentDescription("Add a note to your last ride")

    @Parameter(title: "Note")
    var note: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let success = try await MainActor.run {
            try IntentDataManager.shared.addNoteToLastRideSync(note)
        }

        guard success else {
            return .result(dialog: IntentDialog("No recent ride found to add the note to."))
        }

        return .result(dialog: IntentDialog("Note added to your last ride: \"\(note)\""))
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Add note \(\.$note) to last ride")
    }
}

// MARK: - Get Training Recommendation Intent

/// Intent for getting training recommendations
struct GetTrainingRecommendationIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Training Recommendation"
    static var description = IntentDescription("Get a training recommendation based on your recent rides")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let rides = try await MainActor.run {
            try IntentDataManager.shared.fetchRecentRidesSync(limit: 5)
        }

        guard !rides.isEmpty else {
            return .result(dialog: IntentDialog("Start riding to get personalized recommendations!"))
        }

        let suggestion = await MainActor.run {
            generateRecommendation(from: rides)
        }

        return .result(dialog: IntentDialog(stringLiteral: suggestion))
    }

    @MainActor
    private func generateRecommendation(from rides: [Ride]) -> String {
        let avgDuration = rides.reduce(0) { $0 + $1.totalDuration } / Double(rides.count)
        let avgTurnBalance = rides.reduce(0) { $0 + $1.turnBalancePercent } / rides.count

        var recommendation = "Based on your recent \(rides.count) rides: "

        if avgTurnBalance < 40 || avgTurnBalance > 60 {
            recommendation += "Focus on turn balance - you're at \(avgTurnBalance)% left. Try more exercises in the opposite direction. "
        }

        if avgDuration < 1800 {
            recommendation += "Consider longer sessions of 45+ minutes for better conditioning. "
        }

        let canterTime = rides.reduce(0) { $0 + $1.gaitDuration(for: .canter) }
        let totalTime = rides.reduce(0) { $0 + $1.totalDuration }
        let canterPercent = totalTime > 0 ? (canterTime / totalTime) * 100 : 0

        if canterPercent < 15 {
            recommendation += "Include more canter work to build strength and fitness."
        }

        return recommendation.isEmpty ? "Great balance in your training! Keep it up!" : recommendation
    }
}

// MARK: - Stats Period Enum

enum StatsPeriodEnum: String, AppEnum {
    case week = "week"
    case month = "month"
    case year = "year"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Time Period")
    }

    static var caseDisplayRepresentations: [StatsPeriodEnum: DisplayRepresentation] {
        [
            .week: DisplayRepresentation(title: "This Week"),
            .month: DisplayRepresentation(title: "This Month"),
            .year: DisplayRepresentation(title: "This Year")
        ]
    }

    var displayName: String {
        switch self {
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        }
    }

    var dateRange: (start: Date, end: Date) {
        let now = Date()
        let calendar = Calendar.current

        switch self {
        case .week:
            let start = calendar.date(byAdding: .day, value: -7, to: now)!
            return (start, now)
        case .month:
            let start = calendar.date(byAdding: .month, value: -1, to: now)!
            return (start, now)
        case .year:
            let start = calendar.date(byAdding: .year, value: -1, to: now)!
            return (start, now)
        }
    }
}

// MARK: - Data Manager for Intents

/// Manager for accessing ride data in intents
@MainActor
final class IntentDataManager {
    static let shared = IntentDataManager()

    private var modelContainer: ModelContainer?

    nonisolated init() {}

    func configure(with container: ModelContainer) {
        self.modelContainer = container
    }

    func fetchLastRideSync() throws -> Ride? {
        guard let container = modelContainer else { return nil }
        let context = container.mainContext
        var descriptor = FetchDescriptor<Ride>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func fetchRecentRidesSync(limit: Int) throws -> [Ride] {
        guard let container = modelContainer else { return [] }
        let context = container.mainContext
        var descriptor = FetchDescriptor<Ride>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func fetchStatsSync(for period: StatsPeriodEnum) throws -> TrainingStatsData {
        guard let container = modelContainer else {
            return TrainingStatsData.empty
        }

        let context = container.mainContext
        let range = period.dateRange
        let startDate = range.start
        let endDate = range.end

        let descriptor = FetchDescriptor<Ride>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let allRides = try context.fetch(descriptor)

        // Filter in memory to avoid predicate issues
        let rides = allRides.filter { ride in
            ride.startDate >= startDate && ride.startDate <= endDate
        }

        return TrainingStatsData(
            totalRides: rides.count,
            totalDistance: rides.reduce(0) { $0 + $1.totalDistance },
            totalDuration: rides.reduce(0) { $0 + $1.totalDuration },
            avgDistance: rides.isEmpty ? 0 : rides.reduce(0) { $0 + $1.totalDistance } / Double(rides.count),
            avgDuration: rides.isEmpty ? 0 : rides.reduce(0) { $0 + $1.totalDuration } / Double(rides.count)
        )
    }

    func fetchHorseStatsByName(_ name: String) throws -> HorseStatsData? {
        guard let container = modelContainer else { return nil }
        let context = container.mainContext

        let horseDescriptor = FetchDescriptor<Horse>()
        let horses = try context.fetch(horseDescriptor)

        guard let horse = horses.first(where: { $0.name.lowercased() == name.lowercased() }) else {
            return nil
        }

        let rideDescriptor = FetchDescriptor<Ride>()
        let allRides = try context.fetch(rideDescriptor)
        let rides = allRides.filter { $0.horse?.id == horse.id }

        return HorseStatsData(
            totalRides: rides.count,
            totalDistance: rides.reduce(0) { $0 + $1.totalDistance },
            totalDuration: rides.reduce(0) { $0 + $1.totalDuration }
        )
    }

    func addNoteToLastRideSync(_ note: String) throws -> Bool {
        guard let ride = try fetchLastRideSync() else { return false }
        ride.notes = ride.notes.isEmpty ? note : "\(ride.notes)\n\(note)"
        try modelContainer?.mainContext.save()
        return true
    }
}

// MARK: - Data Structs

struct TrainingStatsData {
    let totalRides: Int
    let totalDistance: Double
    let totalDuration: TimeInterval
    let avgDistance: Double
    let avgDuration: TimeInterval

    static let empty = TrainingStatsData(
        totalRides: 0,
        totalDistance: 0,
        totalDuration: 0,
        avgDistance: 0,
        avgDuration: 0
    )
}

struct HorseStatsData {
    let totalRides: Int
    let totalDistance: Double
    let totalDuration: TimeInterval

    static let empty = HorseStatsData(totalRides: 0, totalDistance: 0, totalDuration: 0)
}

// Note: All App Shortcuts are consolidated in TrackRideShortcuts in RideIntents.swift
