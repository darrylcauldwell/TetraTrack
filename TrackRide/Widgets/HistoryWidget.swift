//
//  HistoryWidget.swift
//  TrackRide
//
//  Widget showing recent training history
//  Displays last 2-3 rides/sessions with basic stats
//

import WidgetKit
import SwiftUI

// MARK: - Recent History Widget

struct RecentHistoryWidget: Widget {
    let kind: String = "RecentHistoryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HistoryTimelineProvider()) { entry in
            HistoryEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Recent Training")
        .description("View your recent rides and training sessions.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Timeline Provider

struct HistoryTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> HistoryEntry {
        HistoryEntry(
            date: Date(),
            sessions: WidgetDataProvider.shared.sampleSessions(limit: 3),
            weeklyStats: WeeklyStats.sample
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (HistoryEntry) -> Void) {
        let sessions = WidgetDataProvider.shared.getRecentSessions(limit: 3)
        let entry = HistoryEntry(
            date: Date(),
            sessions: sessions,
            weeklyStats: WeeklyStats.calculate(from: sessions)
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HistoryEntry>) -> Void) {
        let sessions = WidgetDataProvider.shared.getRecentSessions(limit: 3)
        let entry = HistoryEntry(
            date: Date(),
            sessions: sessions,
            weeklyStats: WeeklyStats.calculate(from: sessions)
        )

        // Refresh hourly
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Weekly Stats

struct WeeklyStats {
    let totalSessions: Int
    let totalDuration: TimeInterval
    let totalDistance: Double
    let sessionTypes: [WidgetSession.SessionType: Int]

    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var formattedDistance: String {
        if totalDistance >= 1000 {
            return String(format: "%.1f km", totalDistance / 1000)
        }
        return String(format: "%.0f m", totalDistance)
    }

    var dominantSessionType: WidgetSession.SessionType? {
        sessionTypes.max(by: { $0.value < $1.value })?.key
    }

    static var sample: WeeklyStats {
        WeeklyStats(
            totalSessions: 5,
            totalDuration: 12600, // 3.5 hours
            totalDistance: 25000, // 25 km
            sessionTypes: [.ride: 3, .run: 1, .swim: 1]
        )
    }

    static func calculate(from sessions: [WidgetSession]) -> WeeklyStats {
        let totalDuration = sessions.reduce(0) { $0 + $1.duration }
        let totalDistance = sessions.reduce(0) { $0 + $1.distance }

        var sessionTypes: [WidgetSession.SessionType: Int] = [:]
        for session in sessions {
            sessionTypes[session.sessionType, default: 0] += 1
        }

        return WeeklyStats(
            totalSessions: sessions.count,
            totalDuration: totalDuration,
            totalDistance: totalDistance,
            sessionTypes: sessionTypes
        )
    }
}

// MARK: - Timeline Entry

struct HistoryEntry: TimelineEntry {
    let date: Date
    let sessions: [WidgetSession]
    let weeklyStats: WeeklyStats

    var mostRecentSession: WidgetSession? {
        sessions.first
    }
}

// MARK: - Entry View

struct HistoryEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: HistoryEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallHistoryView(entry: entry)
        case .systemMedium:
            MediumHistoryView(entry: entry)
        case .systemLarge:
            LargeHistoryView(entry: entry)
        default:
            SmallHistoryView(entry: entry)
        }
    }
}

// MARK: - Small Widget View

struct SmallHistoryView: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundColor(WidgetColors.primary)
                Text("RECENT")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }

            if let session = entry.mostRecentSession {
                Spacer()

                // Session type icon
                Image(systemName: session.sessionType.icon)
                    .font(.title)
                    .foregroundColor(session.sessionType.color)

                // Session name
                Text(session.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                // Stats
                HStack(spacing: 12) {
                    Label(session.formattedDuration, systemImage: "clock")
                        .font(.caption2)
                    Label(session.formattedDistance, systemImage: "figure.walk")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)

                Text(session.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()
            } else {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "figure.run")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("No recent sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .padding()
    }
}

// MARK: - Medium Widget View

struct MediumHistoryView: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.subheadline)
                    .foregroundColor(WidgetColors.primary)
                Text("RECENT TRAINING")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()

                // Weekly summary
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(entry.weeklyStats.totalSessions) sessions")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(entry.weeklyStats.formattedDuration)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(WidgetColors.primary)
                }
            }

            if entry.sessions.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "figure.run")
                            .font(.title)
                            .foregroundColor(.secondary)
                        Text("No recent sessions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Session list
                HStack(spacing: 12) {
                    ForEach(entry.sessions.prefix(2)) { session in
                        SessionCardView(session: session)
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Large Widget View

struct LargeHistoryView: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with stats
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title3)
                    .foregroundColor(WidgetColors.primary)
                Text("RECENT TRAINING")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }

            // Weekly stats bar
            WeeklyStatsBar(stats: entry.weeklyStats)

            Divider()

            if entry.sessions.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "figure.run")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No recent sessions")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Start a workout to track your progress")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Session list
                VStack(spacing: 8) {
                    ForEach(entry.sessions.prefix(3)) { session in
                        SessionRowView(session: session)
                    }
                }

                Spacer()
            }
        }
        .padding()
    }
}

// MARK: - Weekly Stats Bar

struct WeeklyStatsBar: View {
    let stats: WeeklyStats

    var body: some View {
        HStack(spacing: 16) {
            StatItem(
                icon: "number",
                value: "\(stats.totalSessions)",
                label: "Sessions"
            )

            StatItem(
                icon: "clock.fill",
                value: stats.formattedDuration,
                label: "Duration"
            )

            StatItem(
                icon: "figure.walk",
                value: stats.formattedDistance,
                label: "Distance"
            )

            if let dominant = stats.dominantSessionType {
                StatItem(
                    icon: dominant.icon,
                    value: "\(stats.sessionTypes[dominant] ?? 0)",
                    label: dominant.rawValue
                )
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(WidgetColors.primary)

            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Session Card View

struct SessionCardView: View {
    let session: WidgetSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Type and date
            HStack {
                Image(systemName: session.sessionType.icon)
                    .font(.caption)
                    .foregroundColor(session.sessionType.color)

                Spacer()

                Text(session.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Name
            Text(session.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)

            Spacer()

            // Stats
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(session.formattedDuration)
                        .font(.caption2)
                }

                HStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .font(.caption2)
                    Text(session.formattedDistance)
                        .font(.caption2)
                }
            }
            .foregroundColor(.secondary)

            if let horse = session.horseName {
                HStack(spacing: 4) {
                    Image(systemName: "pawprint.fill")
                        .font(.caption2)
                    Text(horse)
                        .font(.caption2)
                }
                .foregroundColor(WidgetColors.primary)
            }
        }
        .padding(10)
        .background(Color(.systemBackground).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Session Row View

struct SessionRowView: View {
    let session: WidgetSession

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            ZStack {
                Circle()
                    .fill(session.sessionType.color.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: session.sessionType.icon)
                    .font(.body)
                    .foregroundColor(session.sessionType.color)
            }

            // Session details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Spacer()

                    Text(session.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 12) {
                    Label(session.formattedDuration, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label(session.formattedDistance, systemImage: "figure.walk")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let horse = session.horseName {
                        Label(horse, systemImage: "pawprint.fill")
                            .font(.caption)
                            .foregroundColor(WidgetColors.primary)
                    }
                }
            }
        }
        .padding(10)
        .background(Color(.systemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Preview

#Preview("Small", as: .systemSmall) {
    RecentHistoryWidget()
} timeline: {
    HistoryEntry(
        date: Date(),
        sessions: WidgetDataProvider.shared.sampleSessions(),
        weeklyStats: WeeklyStats.sample
    )
}

#Preview("Medium", as: .systemMedium) {
    RecentHistoryWidget()
} timeline: {
    HistoryEntry(
        date: Date(),
        sessions: WidgetDataProvider.shared.sampleSessions(),
        weeklyStats: WeeklyStats.sample
    )
}

#Preview("Large", as: .systemLarge) {
    RecentHistoryWidget()
} timeline: {
    HistoryEntry(
        date: Date(),
        sessions: WidgetDataProvider.shared.sampleSessions(),
        weeklyStats: WeeklyStats.sample
    )
}

#Preview("Empty", as: .systemMedium) {
    RecentHistoryWidget()
} timeline: {
    HistoryEntry(
        date: Date(),
        sessions: [],
        weeklyStats: WeeklyStats(totalSessions: 0, totalDuration: 0, totalDistance: 0, sessionTypes: [:])
    )
}
