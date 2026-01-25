//
//  CompetitionWidget.swift
//  TrackRide
//
//  Widget showing upcoming competition calendar
//  Displays next 2-3 competitions with dates and countdown
//

import WidgetKit
import SwiftUI

// MARK: - Competition Calendar Widget

struct CompetitionCalendarWidget: Widget {
    let kind: String = "CompetitionCalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CompetitionTimelineProvider()) { entry in
            CompetitionCalendarEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Competition Calendar")
        .description("View your upcoming competitions and countdowns.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Timeline Provider

struct CompetitionTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> CompetitionEntry {
        CompetitionEntry(
            date: Date(),
            competitions: WidgetDataProvider.shared.sampleCompetitions(limit: 3)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CompetitionEntry) -> Void) {
        let entry = CompetitionEntry(
            date: Date(),
            competitions: WidgetDataProvider.shared.getUpcomingCompetitions(limit: 3)
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CompetitionEntry>) -> Void) {
        let competitions = WidgetDataProvider.shared.getUpcomingCompetitions(limit: 3)
        let entry = CompetitionEntry(date: Date(), competitions: competitions)

        // Refresh at midnight to update countdown
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())

        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct CompetitionEntry: TimelineEntry {
    let date: Date
    let competitions: [WidgetCompetition]

    var nextCompetition: WidgetCompetition? {
        competitions.first
    }
}

// MARK: - Entry View

struct CompetitionCalendarEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: CompetitionEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallCompetitionView(entry: entry)
        case .systemMedium:
            MediumCompetitionView(entry: entry)
        case .systemLarge:
            LargeCompetitionView(entry: entry)
        default:
            SmallCompetitionView(entry: entry)
        }
    }
}

// MARK: - Small Widget View

struct SmallCompetitionView: View {
    let entry: CompetitionEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(WidgetColors.primary)
                Text("NEXT EVENT")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }

            if let competition = entry.nextCompetition {
                Spacer()

                // Countdown
                Text(competition.countdownText)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(countdownColor(for: competition.daysUntil))

                // Competition name
                Text(competition.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.primary)

                // Date
                Text(competition.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            } else {
                Spacer()
                Text("No upcoming events")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
    }

    private func countdownColor(for days: Int) -> Color {
        if days <= 0 {
            return WidgetColors.urgent
        } else if days <= 7 {
            return WidgetColors.warning
        } else {
            return WidgetColors.primary
        }
    }
}

// MARK: - Medium Widget View

struct MediumCompetitionView: View {
    let entry: CompetitionEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "calendar")
                    .font(.subheadline)
                    .foregroundColor(WidgetColors.primary)
                Text("UPCOMING COMPETITIONS")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }

            if entry.competitions.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("No upcoming events")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                Spacer()
            } else {
                // Competition list
                HStack(spacing: 12) {
                    ForEach(entry.competitions.prefix(2)) { competition in
                        CompetitionCardView(competition: competition)
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Large Widget View

struct LargeCompetitionView: View {
    let entry: CompetitionEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "calendar")
                    .font(.title3)
                    .foregroundColor(WidgetColors.primary)
                Text("COMPETITION CALENDAR")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()

                // Total count
                if !entry.competitions.isEmpty {
                    Text("\(entry.competitions.count) upcoming")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if entry.competitions.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No upcoming events")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Competition list
                VStack(spacing: 10) {
                    ForEach(entry.competitions.prefix(3)) { competition in
                        WidgetCompetitionRowView(competition: competition)
                    }
                }

                Spacer()
            }
        }
        .padding()
    }
}

// MARK: - Competition Card View (for Medium widget)

struct CompetitionCardView: View {
    let competition: WidgetCompetition

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Countdown badge
            HStack {
                Text(competition.countdownText)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(countdownColor)
                    .clipShape(Capsule())

                Spacer()

                if competition.isEntered {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            Text(competition.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .foregroundColor(.primary)

            HStack(spacing: 4) {
                Image(systemName: competition.typeIcon)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(competition.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(competition.location)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(10)
        .background(AppColors.cardBackground.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(maxWidth: .infinity)
    }

    private var countdownColor: Color {
        if competition.daysUntil <= 0 {
            return WidgetColors.urgent
        } else if competition.daysUntil <= 7 {
            return WidgetColors.warning
        } else {
            return WidgetColors.primary
        }
    }
}

// MARK: - Widget Competition Row View (for Large widget)

struct WidgetCompetitionRowView: View {
    let competition: WidgetCompetition

    var body: some View {
        HStack(spacing: 12) {
            // Countdown
            VStack {
                Text(competition.countdownText)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(countdownColor)
            }
            .frame(width: 60)

            // Divider
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 1)

            // Competition details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(competition.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    if competition.isEntered {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                HStack(spacing: 8) {
                    Label(competition.formattedDate, systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("|")
                        .foregroundColor(.secondary)

                    Label(competition.location, systemImage: "mappin")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Image(systemName: competition.typeIcon)
                        .font(.caption2)
                    Text(competition.competitionType)
                        .font(.caption2)
                    Text("-")
                        .font(.caption2)
                    Text(competition.level)
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(10)
        .background(AppColors.cardBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var countdownColor: Color {
        if competition.daysUntil <= 0 {
            return WidgetColors.urgent
        } else if competition.daysUntil <= 7 {
            return WidgetColors.warning
        } else {
            return WidgetColors.primary
        }
    }
}

// MARK: - Preview

#Preview("Small", as: .systemSmall) {
    CompetitionCalendarWidget()
} timeline: {
    CompetitionEntry(date: Date(), competitions: WidgetDataProvider.shared.sampleCompetitions())
}

#Preview("Medium", as: .systemMedium) {
    CompetitionCalendarWidget()
} timeline: {
    CompetitionEntry(date: Date(), competitions: WidgetDataProvider.shared.sampleCompetitions())
}

#Preview("Large", as: .systemLarge) {
    CompetitionCalendarWidget()
} timeline: {
    CompetitionEntry(date: Date(), competitions: WidgetDataProvider.shared.sampleCompetitions())
}
