//
//  TetraTrackWidget.swift
//  TetraTrack
//
//  Main widget bundle entry point for TetraTrack iOS widgets
//  Provides Competition Calendar, Tasks, and History widgets
//
//  IMPORTANT: To use these widgets, you must:
//  1. Create a Widget Extension target in Xcode (File > New > Target > Widget Extension)
//  2. Move or copy these widget files to the new extension
//  3. Ensure the @main attribute is on TetraTrackWidgetBundle in the extension
//  4. Add App Groups capability to both main app and widget extension
//  5. Use the same app group identifier: "group.dev.dreamfold.TetraTrack"
//

import WidgetKit
import SwiftUI

// MARK: - Widget Bundle
// NOTE: When creating a Widget Extension target, this becomes the entry point.
// The @main attribute should only be present in the Widget Extension target.

#if WIDGET_EXTENSION
@main
#endif
struct TetraTrackWidgetBundle: WidgetBundle {
    var body: some Widget {
        CompetitionCalendarWidget()
        CompetitionTasksWidget()
        RecentHistoryWidget()
    }
}

// MARK: - App Group for Data Sharing

/// App group identifier for sharing data between main app and widget extension
enum WidgetConstants {
    static let appGroupIdentifier = "group.dev.dreamfold.TetraTrack"
    static let competitionsKey = "widget_competitions"
    static let tasksKey = "widget_tasks"
    static let recentSessionsKey = "widget_recent_sessions"
}

// MARK: - Shared Data Models for Widgets

/// Lightweight competition data for widget display
struct WidgetCompetition: Codable, Identifiable {
    let id: UUID
    let name: String
    let date: Date
    let location: String
    let competitionType: String
    let level: String
    let isEntered: Bool
    let daysUntil: Int

    var countdownText: String {
        if daysUntil < 0 {
            return "\(abs(daysUntil))d ago"
        } else if daysUntil == 0 {
            return "Today!"
        } else if daysUntil == 1 {
            return "Tomorrow"
        } else if daysUntil < 7 {
            return "\(daysUntil) days"
        } else if daysUntil < 30 {
            let weeks = daysUntil / 7
            return "\(weeks)w"
        } else {
            let months = daysUntil / 30
            return "\(months)mo"
        }
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    var typeIcon: String {
        switch competitionType.lowercased() {
        case "tetrathlon": return "star.fill"
        case "triathlon": return "triangle.fill"
        case "eventing": return "figure.equestrian.sports"
        case "show jumping": return "arrow.up.forward"
        case "dressage": return "circle.hexagonpath"
        default: return "flag.fill"
        }
    }
}

/// Lightweight task data for widget display
struct WidgetTask: Codable, Identifiable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let competitionName: String?
    let competitionDate: Date?

    var formattedCompetitionDate: String? {
        guard let date = competitionDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

/// Lightweight session data for widget display
struct WidgetSession: Codable, Identifiable {
    let id: UUID
    let name: String
    let date: Date
    let sessionType: SessionType
    let duration: TimeInterval
    let distance: Double
    let horseName: String?

    enum SessionType: String, Codable {
        case ride = "Ride"
        case run = "Run"
        case swim = "Swim"
        case shoot = "Shoot"

        var icon: String {
            switch self {
            case .ride: return "figure.equestrian.sports"
            case .run: return "figure.run"
            case .swim: return "figure.pool.swim"
            case .shoot: return "target"
            }
        }

        var color: Color {
            switch self {
            case .ride: return .brown
            case .run: return .green
            case .swim: return .blue
            case .shoot: return .orange
            }
        }
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
        }
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var formattedDistance: String {
        if distance >= 1000 {
            return String(format: "%.1f km", distance / 1000)
        }
        return String(format: "%.0f m", distance)
    }
}

// MARK: - Data Provider Helper

struct WidgetDataProvider {
    static let shared = WidgetDataProvider()

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: WidgetConstants.appGroupIdentifier)
    }

    // MARK: - Competitions

    func getUpcomingCompetitions(limit: Int = 3) -> [WidgetCompetition] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: WidgetConstants.competitionsKey),
              let competitions = try? JSONDecoder().decode([WidgetCompetition].self, from: data) else {
            return sampleCompetitions(limit: limit)
        }
        return Array(competitions.prefix(limit))
    }

    func saveCompetitions(_ competitions: [WidgetCompetition]) {
        guard let defaults = sharedDefaults,
              let data = try? JSONEncoder().encode(competitions) else { return }
        defaults.set(data, forKey: WidgetConstants.competitionsKey)
    }

    // MARK: - Tasks

    func getPendingTasks(limit: Int = 5) -> [WidgetTask] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: WidgetConstants.tasksKey),
              let tasks = try? JSONDecoder().decode([WidgetTask].self, from: data) else {
            return sampleTasks(limit: limit)
        }
        return Array(tasks.filter { !$0.isCompleted }.prefix(limit))
    }

    func saveTasks(_ tasks: [WidgetTask]) {
        guard let defaults = sharedDefaults,
              let data = try? JSONEncoder().encode(tasks) else { return }
        defaults.set(data, forKey: WidgetConstants.tasksKey)
    }

    // MARK: - Sessions

    func getRecentSessions(limit: Int = 3) -> [WidgetSession] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: WidgetConstants.recentSessionsKey),
              let sessions = try? JSONDecoder().decode([WidgetSession].self, from: data) else {
            return sampleSessions(limit: limit)
        }
        return Array(sessions.prefix(limit))
    }

    func saveSessions(_ sessions: [WidgetSession]) {
        guard let defaults = sharedDefaults,
              let data = try? JSONEncoder().encode(sessions) else { return }
        defaults.set(data, forKey: WidgetConstants.recentSessionsKey)
    }

    // MARK: - Sample Data for Previews

    func sampleCompetitions(limit: Int = 3) -> [WidgetCompetition] {
        let calendar = Calendar.current
        let today = Date()

        return [
            WidgetCompetition(
                id: UUID(),
                name: "Area Tetrathlon",
                date: calendar.date(byAdding: .day, value: 12, to: today) ?? today,
                location: "Regional Centre",
                competitionType: "Tetrathlon",
                level: "Junior",
                isEntered: true,
                daysUntil: 12
            ),
            WidgetCompetition(
                id: UUID(),
                name: "Spring Triathlon",
                date: calendar.date(byAdding: .day, value: 28, to: today) ?? today,
                location: "County Showground",
                competitionType: "Triathlon",
                level: "Open",
                isEntered: false,
                daysUntil: 28
            ),
            WidgetCompetition(
                id: UUID(),
                name: "Zone Championships",
                date: calendar.date(byAdding: .day, value: 45, to: today) ?? today,
                location: "National Centre",
                competitionType: "Tetrathlon",
                level: "Intermediate",
                isEntered: false,
                daysUntil: 45
            )
        ].prefix(limit).map { $0 }
    }

    func sampleTasks(limit: Int = 5) -> [WidgetTask] {
        let calendar = Calendar.current
        let today = Date()

        return [
            WidgetTask(
                id: UUID(),
                title: "Submit entry form",
                isCompleted: false,
                competitionName: "Area Tetrathlon",
                competitionDate: calendar.date(byAdding: .day, value: 12, to: today)
            ),
            WidgetTask(
                id: UUID(),
                title: "Book horse transport",
                isCompleted: false,
                competitionName: "Area Tetrathlon",
                competitionDate: calendar.date(byAdding: .day, value: 12, to: today)
            ),
            WidgetTask(
                id: UUID(),
                title: "Practice 1500m time trial",
                isCompleted: false,
                competitionName: nil,
                competitionDate: nil
            ),
            WidgetTask(
                id: UUID(),
                title: "Check shooting equipment",
                isCompleted: false,
                competitionName: "Area Tetrathlon",
                competitionDate: calendar.date(byAdding: .day, value: 12, to: today)
            ),
            WidgetTask(
                id: UUID(),
                title: "Review dressage test",
                isCompleted: false,
                competitionName: nil,
                competitionDate: nil
            )
        ].prefix(limit).map { $0 }
    }

    func sampleSessions(limit: Int = 3) -> [WidgetSession] {
        let calendar = Calendar.current
        let today = Date()

        return [
            WidgetSession(
                id: UUID(),
                name: "Morning Flatwork",
                date: today,
                sessionType: .ride,
                duration: 2700, // 45 min
                distance: 8500,
                horseName: "Apollo"
            ),
            WidgetSession(
                id: UUID(),
                name: "Tempo Run",
                date: calendar.date(byAdding: .day, value: -1, to: today) ?? today,
                sessionType: .run,
                duration: 1800, // 30 min
                distance: 5200,
                horseName: nil
            ),
            WidgetSession(
                id: UUID(),
                name: "Pool Training",
                date: calendar.date(byAdding: .day, value: -2, to: today) ?? today,
                sessionType: .swim,
                duration: 2400, // 40 min
                distance: 1500,
                horseName: nil
            )
        ].prefix(limit).map { $0 }
    }
}

// MARK: - Widget Colors

struct WidgetColors {
    static let primary = Color(red: 0.15, green: 0.45, blue: 0.85)
    static let secondary = Color(red: 0.4, green: 0.65, blue: 0.95)
    static let accent = Color(red: 0.0, green: 0.5, blue: 1.0)
    static let background = Color(red: 0.94, green: 0.96, blue: 0.99)
    static let cardBackground = Color(red: 0.97, green: 0.98, blue: 1.0)

    static let success = Color.green
    static let warning = Color.orange
    static let urgent = Color.red
}
