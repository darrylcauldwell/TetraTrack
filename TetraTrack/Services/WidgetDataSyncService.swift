//
//  WidgetDataSyncService.swift
//  TetraTrack
//
//  Service to sync data from the main app to widgets via App Groups.
//  Uses ArtifactStatisticsService as the primary source for cross-device session data.
//  Competitions and tasks use SwiftData directly since they are iPhone-only.
//

import Foundation
import SwiftData
import WidgetKit
import Observation
import os

// MARK: - Widget Data Sync Service

@MainActor
@Observable
final class WidgetDataSyncService {
    static let shared = WidgetDataSyncService()

    private let appGroupIdentifier = "group.dev.dreamfold.TetraTrack"
    private let competitionsKey = "widget_competitions"
    private let tasksKey = "widget_tasks"
    private let recentSessionsKey = "widget_recent_sessions"

    /// Reference to ArtifactStatisticsService for cross-device session statistics.
    /// This is the single source of truth for training session data across devices.
    private var artifactStatisticsService: ArtifactStatisticsService?

    /// Cached UserDefaults instance for App Group (avoids creating new instance on each access)
    private var _sharedDefaults: UserDefaults?
    private var sharedDefaults: UserDefaults? {
        if _sharedDefaults == nil {
            _sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)
        }
        return _sharedDefaults
    }

    private init() {}

    /// Configures the service with an ArtifactStatisticsService instance.
    /// Call this during app initialization to enable artifact-based session sync.
    func configure(with artifactService: ArtifactStatisticsService) {
        self.artifactStatisticsService = artifactService
    }

    // MARK: - Sync All Data

    /// Syncs all widget data from the model context.
    /// Uses ArtifactStatisticsService for sessions when available (cross-device compatible).
    /// Falls back to SwiftData for sessions if artifact service not configured.
    func syncAllWidgetData(context: ModelContext) {
        // Competitions and tasks are iPhone-only, so SwiftData access is appropriate
        syncCompetitions(context: context)
        syncTasks(context: context)

        // Sessions: prefer ArtifactStatisticsService for cross-device consistency
        if let artifactService = artifactStatisticsService, artifactService.hasDataForWidgets {
            syncRecentSessionsFromArtifacts()
        } else {
            // Fallback to SwiftData when artifacts not available
            syncRecentSessions(context: context)
        }

        // Reload all widget timelines
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Syncs recent sessions using ArtifactStatisticsService as the source of truth.
    /// This ensures widget data is consistent across iPhone, iPad, and Watch.
    func syncRecentSessionsFromArtifacts() {
        guard let artifactService = artifactStatisticsService else {
            Log.widgets.warning("ArtifactStatisticsService not configured, skipping artifact-based sync")
            return
        }

        let sessions = artifactService.getWidgetRecentSessions(limit: 5)
        saveSessions(sessions)
        WidgetCenter.shared.reloadTimelines(ofKind: "RecentHistoryWidget")
    }

    // MARK: - Competition Sync

    /// Syncs upcoming competitions to the widget
    func syncCompetitions(context: ModelContext) {
        do {
            let now = Date()
            // Fetch all and filter in Swift to avoid #Predicate variable capture crash
            var descriptor = FetchDescriptor<Competition>(
                sortBy: [SortDescriptor(\.date, order: .forward)]
            )

            let allCompetitions = try context.fetch(descriptor)
            let competitions = allCompetitions.filter { $0.date > now }.prefix(5)
            let widgetCompetitions = competitions.map { competition in
                WidgetCompetitionData(
                    id: competition.id,
                    name: competition.name,
                    date: competition.date,
                    location: competition.location,
                    competitionType: competition.competitionType.rawValue,
                    level: competition.level.rawValue,
                    isEntered: competition.isEntered,
                    daysUntil: competition.daysUntil
                )
            }

            saveCompetitions(widgetCompetitions)
            WidgetCenter.shared.reloadTimelines(ofKind: "CompetitionCalendarWidget")

        } catch {
            Log.widgets.error("Failed to sync competitions: \(error)")
        }
    }

    private func saveCompetitions(_ competitions: [WidgetCompetitionData]) {
        guard let defaults = sharedDefaults,
              let data = try? JSONEncoder().encode(competitions) else { return }
        defaults.set(data, forKey: competitionsKey)
    }

    // MARK: - Tasks Sync

    /// Syncs pending tasks to the widget
    func syncTasks(context: ModelContext) {
        do {
            var descriptor = FetchDescriptor<CompetitionTask>(
                predicate: #Predicate<CompetitionTask> { task in
                    !task.isCompleted
                },
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
            descriptor.fetchLimit = 10

            let tasks = try context.fetch(descriptor)
            let widgetTasks = tasks.map { task in
                WidgetTaskData(
                    id: task.id,
                    title: task.title,
                    isCompleted: task.isCompleted,
                    competitionName: task.competition?.name,
                    competitionDate: task.competition?.date
                )
            }

            saveTasks(widgetTasks)
            WidgetCenter.shared.reloadTimelines(ofKind: "CompetitionTasksWidget")

        } catch {
            Log.widgets.error("Failed to sync tasks: \(error)")
        }
    }

    private func saveTasks(_ tasks: [WidgetTaskData]) {
        guard let defaults = sharedDefaults,
              let data = try? JSONEncoder().encode(tasks) else { return }
        defaults.set(data, forKey: tasksKey)
    }

    // MARK: - Recent Sessions Sync (SwiftData Fallback)

    /// Syncs recent sessions (rides, runs, swims, shoots) to the widget using SwiftData.
    /// This is the fallback path when ArtifactStatisticsService is not available.
    /// Prefer using syncRecentSessionsFromArtifacts() for cross-device consistency.
    func syncRecentSessions(context: ModelContext) {
        let items = SessionQueryService.fetchHistory(context: context, limit: 5)

        let sessions = items.map { item -> WidgetSessionData in
            let sessionType: WidgetSessionData.WidgetSessionType
            var horseName: String?
            switch item.discipline {
            case .riding:
                sessionType = .ride
                horseName = item.ride?.horse?.name
            case .running:
                sessionType = .run
            case .swimming:
                sessionType = .swim
            case .shooting:
                sessionType = .shoot
            }
            return WidgetSessionData(
                id: item.id,
                name: item.name,
                date: item.date,
                sessionType: sessionType,
                duration: item.duration,
                distance: item.ride?.totalDistance ?? item.runningSession?.totalDistance ?? item.swimmingSession?.totalDistance ?? 0,
                horseName: horseName
            )
        }

        saveSessions(sessions)
        WidgetCenter.shared.reloadTimelines(ofKind: "RecentHistoryWidget")
    }

    private func saveSessions(_ sessions: [WidgetSessionData]) {
        guard let defaults = sharedDefaults,
              let data = try? JSONEncoder().encode(sessions) else { return }
        defaults.set(data, forKey: recentSessionsKey)
    }
}

// MARK: - Widget Data Types (Shared with Widget Extension)

/// Lightweight competition data for widget display
struct WidgetCompetitionData: Codable, Identifiable {
    let id: UUID
    let name: String
    let date: Date
    let location: String
    let competitionType: String
    let level: String
    let isEntered: Bool
    let daysUntil: Int
}

/// Lightweight task data for widget display
struct WidgetTaskData: Codable, Identifiable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let competitionName: String?
    let competitionDate: Date?
}

/// Lightweight session data for widget display
struct WidgetSessionData: Codable, Identifiable {
    let id: UUID
    let name: String
    let date: Date
    let sessionType: WidgetSessionType
    let duration: TimeInterval
    let distance: Double
    let horseName: String?

    enum WidgetSessionType: String, Codable {
        case ride = "Ride"
        case run = "Run"
        case swim = "Swim"
        case shoot = "Shoot"
    }
}
