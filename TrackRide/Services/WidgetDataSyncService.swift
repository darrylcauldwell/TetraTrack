//
//  WidgetDataSyncService.swift
//  TrackRide
//
//  Service to sync data from the main app to widgets via App Groups
//  Call methods on this service when data changes to update widgets
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

    private let appGroupIdentifier = "group.MyHorse.TrackRide"
    private let competitionsKey = "widget_competitions"
    private let tasksKey = "widget_tasks"
    private let recentSessionsKey = "widget_recent_sessions"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private init() {}

    // MARK: - Sync All Data

    /// Syncs all widget data from the model context
    func syncAllWidgetData(context: ModelContext) {
        syncCompetitions(context: context)
        syncTasks(context: context)
        syncRecentSessions(context: context)

        // Reload all widget timelines
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Competition Sync

    /// Syncs upcoming competitions to the widget
    func syncCompetitions(context: ModelContext) {
        do {
            let now = Date()
            var descriptor = FetchDescriptor<Competition>(
                predicate: #Predicate<Competition> { competition in
                    competition.date > now
                },
                sortBy: [SortDescriptor(\.date, order: .forward)]
            )
            descriptor.fetchLimit = 5

            let competitions = try context.fetch(descriptor)
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

    // MARK: - Recent Sessions Sync

    /// Syncs recent sessions (rides, runs, swims) to the widget
    func syncRecentSessions(context: ModelContext) {
        var sessions: [WidgetSessionData] = []

        // Fetch recent rides
        do {
            var rideDescriptor = FetchDescriptor<Ride>(
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            )
            rideDescriptor.fetchLimit = 5

            let rides = try context.fetch(rideDescriptor)
            for ride in rides {
                sessions.append(WidgetSessionData(
                    id: ride.id,
                    name: ride.name.isEmpty ? "Ride" : ride.name,
                    date: ride.startDate,
                    sessionType: .ride,
                    duration: ride.totalDuration,
                    distance: ride.totalDistance,
                    horseName: ride.horse?.name
                ))
            }
        } catch {
            Log.widgets.error("Failed to fetch rides: \(error)")
        }

        // Fetch recent running sessions
        do {
            var runDescriptor = FetchDescriptor<RunningSession>(
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            )
            runDescriptor.fetchLimit = 5

            let runs = try context.fetch(runDescriptor)
            for run in runs {
                sessions.append(WidgetSessionData(
                    id: run.id,
                    name: run.name.isEmpty ? "Run" : run.name,
                    date: run.startDate,
                    sessionType: .run,
                    duration: run.totalDuration,
                    distance: run.totalDistance,
                    horseName: nil
                ))
            }
        } catch {
            Log.widgets.error("Failed to fetch runs: \(error)")
        }

        // Fetch recent swimming sessions
        do {
            var swimDescriptor = FetchDescriptor<SwimmingSession>(
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            )
            swimDescriptor.fetchLimit = 5

            let swims = try context.fetch(swimDescriptor)
            for swim in swims {
                sessions.append(WidgetSessionData(
                    id: swim.id,
                    name: swim.name.isEmpty ? "Swim" : swim.name,
                    date: swim.startDate,
                    sessionType: .swim,
                    duration: swim.totalDuration,
                    distance: swim.totalDistance,
                    horseName: nil
                ))
            }
        } catch {
            Log.widgets.error("Failed to fetch swims: \(error)")
        }

        // Sort by date and take most recent
        sessions.sort { $0.date > $1.date }
        let recentSessions = Array(sessions.prefix(5))

        saveSessions(recentSessions)
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
