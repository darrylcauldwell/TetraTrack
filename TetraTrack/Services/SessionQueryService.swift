//
//  SessionQueryService.swift
//  TetraTrack
//
//  Centralised cross-discipline session fetching
//

import Foundation
import SwiftData

enum SessionQueryService {

    // MARK: - Fetch Combined History

    /// Fetch combined history items across all disciplines, sorted by date descending.
    static func fetchHistory(
        context: ModelContext,
        discipline: TrainingDiscipline? = nil,
        from startDate: Date? = nil,
        limit: Int? = nil
    ) -> [SessionHistoryItem] {
        let (rides, runs, swims, shoots) = fetchByDiscipline(
            context: context,
            discipline: discipline,
            from: startDate
        )
        var items = SessionHistoryItem.combined(
            rides: rides, runs: runs, swims: swims, shoots: shoots
        )
        if let limit {
            items = Array(items.prefix(limit))
        }
        return items
    }

    // MARK: - Fetch by Discipline

    /// Fetch all four discipline arrays, optionally filtered by date and/or discipline.
    static func fetchByDiscipline(
        context: ModelContext,
        discipline: TrainingDiscipline? = nil,
        from startDate: Date? = nil
    ) -> (rides: [Ride], runs: [RunningSession], swims: [SwimmingSession], shoots: [ShootingSession]) {
        var rides: [Ride] = []
        var runs: [RunningSession] = []
        var swims: [SwimmingSession] = []
        var shoots: [ShootingSession] = []

        if discipline == nil || discipline == .riding {
            rides = fetchRides(context: context, from: startDate)
        }
        if discipline == nil || discipline == .running {
            runs = fetchRuns(context: context, from: startDate)
        }
        if discipline == nil || discipline == .swimming {
            swims = fetchSwims(context: context, from: startDate)
        }
        if discipline == nil || discipline == .shooting {
            shoots = fetchShoots(context: context, from: startDate)
        }

        return (rides, runs, swims, shoots)
    }

    // MARK: - Statistics

    /// Compute unified statistics across disciplines.
    static func statistics(
        context: ModelContext,
        discipline: TrainingDiscipline? = nil,
        from startDate: Date? = nil
    ) -> SessionStatistics {
        let (rides, runs, swims, shoots) = fetchByDiscipline(
            context: context,
            discipline: discipline,
            from: startDate
        )
        var sessions: [any TrainingSessionProtocol] = []
        sessions += rides
        sessions += runs
        sessions += swims
        sessions += shoots
        return SessionStatistics(sessions: sessions)
    }

    // MARK: - Private Fetch Helpers

    private static func fetchRides(context: ModelContext, from startDate: Date? = nil) -> [Ride] {
        let descriptor = FetchDescriptor<Ride>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        guard let startDate else { return all }
        return all.filter { $0.startDate >= startDate }
    }

    private static func fetchRuns(context: ModelContext, from startDate: Date? = nil) -> [RunningSession] {
        let descriptor = FetchDescriptor<RunningSession>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        guard let startDate else { return all }
        return all.filter { $0.startDate >= startDate }
    }

    private static func fetchSwims(context: ModelContext, from startDate: Date? = nil) -> [SwimmingSession] {
        let descriptor = FetchDescriptor<SwimmingSession>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        guard let startDate else { return all }
        return all.filter { $0.startDate >= startDate }
    }

    private static func fetchShoots(context: ModelContext, from startDate: Date? = nil) -> [ShootingSession] {
        let descriptor = FetchDescriptor<ShootingSession>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        guard let startDate else { return all }
        return all.filter { $0.startDate >= startDate }
    }

    // MARK: - Session Lookup by UUID

    /// Find a session by UUID and discipline for Competition→Session navigation.
    static func fetchSession(id: UUID, discipline: String, context: ModelContext) -> (any PersistentModel)? {
        switch discipline {
        case "riding":
            let idString = id.uuidString
            let descriptor = FetchDescriptor<Ride>(
                predicate: #Predicate<Ride> { $0.id.uuidString == idString }
            )
            return try? context.fetch(descriptor).first
        case "running", "walking":
            let idString = id.uuidString
            let descriptor = FetchDescriptor<RunningSession>(
                predicate: #Predicate<RunningSession> { $0.id.uuidString == idString }
            )
            return try? context.fetch(descriptor).first
        case "swimming":
            let idString = id.uuidString
            let descriptor = FetchDescriptor<SwimmingSession>(
                predicate: #Predicate<SwimmingSession> { $0.id.uuidString == idString }
            )
            return try? context.fetch(descriptor).first
        case "shooting":
            let idString = id.uuidString
            let descriptor = FetchDescriptor<ShootingSession>(
                predicate: #Predicate<ShootingSession> { $0.id.uuidString == idString }
            )
            return try? context.fetch(descriptor).first
        default:
            return nil
        }
    }

    /// Find sessions near a given date for auto-linking from Competition results.
    static func findNearbySession(discipline: String, near date: Date, tolerance: TimeInterval = 1800, context: ModelContext) -> (id: UUID, model: any PersistentModel)? {
        let windowStart = date.addingTimeInterval(-tolerance)
        let windowEnd = date.addingTimeInterval(tolerance)

        switch discipline {
        case "riding":
            let descriptor = FetchDescriptor<Ride>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
            let rides = (try? context.fetch(descriptor)) ?? []
            if let match = rides.first(where: { $0.startDate >= windowStart && $0.startDate <= windowEnd }) {
                return (match.id, match)
            }
        case "running", "walking":
            let descriptor = FetchDescriptor<RunningSession>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
            let sessions = (try? context.fetch(descriptor)) ?? []
            if let match = sessions.first(where: { $0.startDate >= windowStart && $0.startDate <= windowEnd }) {
                return (match.id, match)
            }
        case "swimming":
            let descriptor = FetchDescriptor<SwimmingSession>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
            let sessions = (try? context.fetch(descriptor)) ?? []
            if let match = sessions.first(where: { $0.startDate >= windowStart && $0.startDate <= windowEnd }) {
                return (match.id, match)
            }
        case "shooting":
            let descriptor = FetchDescriptor<ShootingSession>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
            let sessions = (try? context.fetch(descriptor)) ?? []
            if let match = sessions.first(where: { $0.startDate >= windowStart && $0.startDate <= windowEnd }) {
                return (match.id, match)
            }
        default:
            break
        }
        return nil
    }
}
