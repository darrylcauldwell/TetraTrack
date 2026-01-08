//
//  TrackRideWidgetExtension.swift
//  TrackRideWidgetExtension
//
//  Widget Extension entry point for TrackRide iOS widgets
//

import WidgetKit
import SwiftUI

// MARK: - App Group for Data Sharing

enum WidgetConstants {
    static let appGroupIdentifier = "group.MyHorse.TrackRide"
    static let competitionsKey = "widget_competitions"
    static let tasksKey = "widget_tasks"
    static let recentSessionsKey = "widget_recent_sessions"
}

// MARK: - Shared Data Models

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

// MARK: - Data Provider

struct WidgetDataProvider {
    static let shared = WidgetDataProvider()

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: WidgetConstants.appGroupIdentifier)
    }

    func getUpcomingCompetitions(limit: Int = 3) -> [WidgetCompetition] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: WidgetConstants.competitionsKey),
              let competitions = try? JSONDecoder().decode([WidgetCompetition].self, from: data) else {
            return sampleCompetitions(limit: limit)
        }
        return Array(competitions.prefix(limit))
    }

    func getPendingTasks(limit: Int = 5) -> [WidgetTask] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: WidgetConstants.tasksKey),
              let tasks = try? JSONDecoder().decode([WidgetTask].self, from: data) else {
            return sampleTasks(limit: limit)
        }
        return Array(tasks.filter { !$0.isCompleted }.prefix(limit))
    }

    func getRecentSessions(limit: Int = 3) -> [WidgetSession] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: WidgetConstants.recentSessionsKey),
              let sessions = try? JSONDecoder().decode([WidgetSession].self, from: data) else {
            return sampleSessions(limit: limit)
        }
        return Array(sessions.prefix(limit))
    }

    // Sample data for previews
    func sampleCompetitions(limit: Int = 3) -> [WidgetCompetition] {
        let today = Date()
        return [
            WidgetCompetition(id: UUID(), name: "Area Tetrathlon", date: Calendar.current.date(byAdding: .day, value: 12, to: today)!, location: "Regional Centre", competitionType: "Tetrathlon", level: "Junior", isEntered: true, daysUntil: 12),
            WidgetCompetition(id: UUID(), name: "Spring Triathlon", date: Calendar.current.date(byAdding: .day, value: 28, to: today)!, location: "County Showground", competitionType: "Triathlon", level: "Open", isEntered: false, daysUntil: 28),
        ].prefix(limit).map { $0 }
    }

    func sampleTasks(limit: Int = 5) -> [WidgetTask] {
        return [
            WidgetTask(id: UUID(), title: "Submit entry form", isCompleted: false, competitionName: "Area Tetrathlon", competitionDate: Date().addingTimeInterval(86400 * 12)),
            WidgetTask(id: UUID(), title: "Book transport", isCompleted: false, competitionName: "Area Tetrathlon", competitionDate: nil),
        ].prefix(limit).map { $0 }
    }

    func sampleSessions(limit: Int = 3) -> [WidgetSession] {
        return [
            WidgetSession(id: UUID(), name: "Morning Flatwork", date: Date(), sessionType: .ride, duration: 2700, distance: 8500, horseName: "Apollo"),
            WidgetSession(id: UUID(), name: "Tempo Run", date: Date().addingTimeInterval(-86400), sessionType: .run, duration: 1800, distance: 5200, horseName: nil),
        ].prefix(limit).map { $0 }
    }
}

// MARK: - Widget Colors

struct WidgetColors {
    static let primary = Color(red: 0.15, green: 0.45, blue: 0.85)
    static let secondary = Color(red: 0.4, green: 0.65, blue: 0.95)
    static let success = Color.green
    static let warning = Color.orange
    static let urgent = Color.red
}

// MARK: - Competition Calendar Widget

struct CompetitionCalendarWidget: Widget {
    let kind: String = "CompetitionCalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CompetitionTimelineProvider()) { entry in
            CompetitionWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Competition Calendar")
        .description("View upcoming competitions and countdowns.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CompetitionTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> CompetitionTimelineEntry {
        CompetitionTimelineEntry(date: Date(), competitions: WidgetDataProvider.shared.sampleCompetitions())
    }

    func getSnapshot(in context: Context, completion: @escaping (CompetitionTimelineEntry) -> Void) {
        let entry = CompetitionTimelineEntry(date: Date(), competitions: WidgetDataProvider.shared.getUpcomingCompetitions())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CompetitionTimelineEntry>) -> Void) {
        let competitions = WidgetDataProvider.shared.getUpcomingCompetitions()
        let entry = CompetitionTimelineEntry(date: Date(), competitions: competitions)
        let tomorrow = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }
}

struct CompetitionTimelineEntry: TimelineEntry {
    let date: Date
    let competitions: [WidgetCompetition]
}

struct CompetitionWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: CompetitionTimelineEntry

    var body: some View {
        if let competition = entry.competitions.first {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(WidgetColors.primary)
                    Text("NEXT EVENT")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                Spacer()

                Text(competition.countdownText)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(competition.daysUntil <= 7 ? WidgetColors.warning : WidgetColors.primary)

                Text(competition.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Text(competition.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
        } else {
            VStack {
                Image(systemName: "calendar.badge.plus")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No upcoming events")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

// MARK: - Tasks Widget

struct CompetitionTasksWidget: Widget {
    let kind: String = "CompetitionTasksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TasksTimelineProvider()) { entry in
            TasksWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Competition Tasks")
        .description("Track your competition preparation tasks.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TasksTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TasksTimelineEntry {
        TasksTimelineEntry(date: Date(), tasks: WidgetDataProvider.shared.sampleTasks())
    }

    func getSnapshot(in context: Context, completion: @escaping (TasksTimelineEntry) -> Void) {
        let entry = TasksTimelineEntry(date: Date(), tasks: WidgetDataProvider.shared.getPendingTasks())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TasksTimelineEntry>) -> Void) {
        let tasks = WidgetDataProvider.shared.getPendingTasks()
        let entry = TasksTimelineEntry(date: Date(), tasks: tasks)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct TasksTimelineEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTask]
}

struct TasksWidgetView: View {
    var entry: TasksTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundColor(WidgetColors.primary)
                Text("TASKS")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(entry.tasks.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(WidgetColors.primary)
            }

            if entry.tasks.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack {
                        Image(systemName: "checkmark.circle")
                            .font(.title)
                            .foregroundColor(.green)
                        Text("All done!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(entry.tasks.prefix(3)) { task in
                    HStack(spacing: 8) {
                        Image(systemName: "circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(task.title)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                    }
                }
                Spacer()
            }
        }
        .padding()
    }
}

// MARK: - Recent History Widget

struct RecentHistoryWidget: Widget {
    let kind: String = "RecentHistoryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HistoryTimelineProvider()) { entry in
            HistoryWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Recent Training")
        .description("View your recent training sessions.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct HistoryTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> HistoryTimelineEntry {
        HistoryTimelineEntry(date: Date(), sessions: WidgetDataProvider.shared.sampleSessions())
    }

    func getSnapshot(in context: Context, completion: @escaping (HistoryTimelineEntry) -> Void) {
        let entry = HistoryTimelineEntry(date: Date(), sessions: WidgetDataProvider.shared.getRecentSessions())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HistoryTimelineEntry>) -> Void) {
        let sessions = WidgetDataProvider.shared.getRecentSessions()
        let entry = HistoryTimelineEntry(date: Date(), sessions: sessions)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct HistoryTimelineEntry: TimelineEntry {
    let date: Date
    let sessions: [WidgetSession]
}

struct HistoryWidgetView: View {
    var entry: HistoryTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(WidgetColors.primary)
                Text("RECENT")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }

            if entry.sessions.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack {
                        Image(systemName: "figure.run")
                            .font(.title)
                            .foregroundColor(.secondary)
                        Text("No sessions yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(entry.sessions.prefix(3)) { session in
                    HStack(spacing: 8) {
                        Image(systemName: session.sessionType.icon)
                            .font(.caption)
                            .foregroundColor(session.sessionType.color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text(session.formattedDuration)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(session.formattedDate)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
        }
        .padding()
    }
}

// MARK: - Widget Bundle

@main
struct TrackRideWidgetBundle: WidgetBundle {
    var body: some Widget {
        CompetitionCalendarWidget()
        CompetitionTasksWidget()
        RecentHistoryWidget()
    }
}
