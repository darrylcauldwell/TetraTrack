//
//  TasksWidget.swift
//  TrackRide
//
//  Widget showing competition preparation to-do list
//  Displays pending tasks for upcoming competitions
//

import WidgetKit
import SwiftUI

// MARK: - Competition Tasks Widget

struct CompetitionTasksWidget: Widget {
    let kind: String = "CompetitionTasksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TasksTimelineProvider()) { entry in
            TasksEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Competition Tasks")
        .description("Track your competition preparation to-do list.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Timeline Provider

struct TasksTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TasksEntry {
        TasksEntry(
            date: Date(),
            tasks: WidgetDataProvider.shared.sampleTasks(limit: 5),
            totalPending: 5
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TasksEntry) -> Void) {
        let tasks = WidgetDataProvider.shared.getPendingTasks(limit: 5)
        let entry = TasksEntry(
            date: Date(),
            tasks: tasks,
            totalPending: tasks.count
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TasksEntry>) -> Void) {
        let tasks = WidgetDataProvider.shared.getPendingTasks(limit: 5)
        let entry = TasksEntry(
            date: Date(),
            tasks: tasks,
            totalPending: tasks.count
        )

        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct TasksEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTask]
    let totalPending: Int
}

// MARK: - Entry View

struct TasksEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: TasksEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallTasksView(entry: entry)
        case .systemMedium:
            MediumTasksView(entry: entry)
        case .systemLarge:
            LargeTasksView(entry: entry)
        default:
            SmallTasksView(entry: entry)
        }
    }
}

// MARK: - Small Widget View

struct SmallTasksView: View {
    let entry: TasksEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "checklist")
                    .font(.caption)
                    .foregroundColor(WidgetColors.primary)
                Text("TO-DO")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }

            if entry.tasks.isEmpty {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                        .foregroundColor(.green)
                    Text("All done!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                // Task count
                Text("\(entry.totalPending)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(WidgetColors.primary)

                Text(entry.totalPending == 1 ? "task pending" : "tasks pending")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // First task preview
                if let firstTask = entry.tasks.first {
                    HStack(spacing: 4) {
                        Image(systemName: "circle")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(firstTask.title)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Medium Widget View

struct MediumTasksView: View {
    let entry: TasksEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "checklist")
                    .font(.subheadline)
                    .foregroundColor(WidgetColors.primary)
                Text("COMPETITION TASKS")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()

                // Badge
                if entry.totalPending > 0 {
                    Text("\(entry.totalPending)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(WidgetColors.primary)
                        .clipShape(Capsule())
                }
            }

            if entry.tasks.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.green)
                        Text("All tasks completed!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Task list
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.tasks.prefix(3)) { task in
                        TaskRowCompactView(task: task)
                    }

                    if entry.totalPending > 3 {
                        Text("+ \(entry.totalPending - 3) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Large Widget View

struct LargeTasksView: View {
    let entry: TasksEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "checklist")
                    .font(.title3)
                    .foregroundColor(WidgetColors.primary)
                Text("COMPETITION TASKS")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()

                // Progress indicator
                if entry.totalPending > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "circle.badge.exclamationmark")
                            .font(.caption)
                        Text("\(entry.totalPending) pending")
                            .font(.caption)
                    }
                    .foregroundColor(WidgetColors.warning)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text("All done")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                }
            }

            if entry.tasks.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "party.popper")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                        Text("All tasks completed!")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("You're ready for competition")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Task list
                VStack(spacing: 8) {
                    ForEach(entry.tasks.prefix(5)) { task in
                        TaskRowDetailedView(task: task)
                    }
                }

                if entry.totalPending > 5 {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("+ \(entry.totalPending - 5) more tasks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }

                Spacer()
            }
        }
        .padding()
    }
}

// MARK: - Task Row Compact View

struct TaskRowCompactView: View {
    let task: WidgetTask

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundColor(task.isCompleted ? .green : .secondary)

            Text(task.title)
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(task.isCompleted ? .secondary : .primary)
                .strikethrough(task.isCompleted)

            Spacer()

            if let competitionDate = task.formattedCompetitionDate {
                Text(competitionDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Task Row Detailed View

struct TaskRowDetailedView: View {
    let task: WidgetTask

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.body)
                .foregroundColor(task.isCompleted ? .green : WidgetColors.primary)

            // Task details
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted)

                if let competitionName = task.competitionName {
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                            .font(.caption2)
                        Text(competitionName)
                            .font(.caption)

                        if let date = task.formattedCompetitionDate {
                            Text("-")
                                .font(.caption)
                            Text(date)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(AppColors.cardBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Priority Badge

struct PriorityBadge: View {
    let priority: TaskPriority

    enum TaskPriority {
        case high, medium, low

        var color: Color {
            switch self {
            case .high: return .red
            case .medium: return .orange
            case .low: return .blue
            }
        }

        var icon: String {
            switch self {
            case .high: return "exclamationmark"
            case .medium: return "arrow.up"
            case .low: return "arrow.down"
            }
        }
    }

    var body: some View {
        Image(systemName: priority.icon)
            .font(.caption2)
            .foregroundColor(priority.color)
    }
}

// MARK: - Preview

#Preview("Small", as: .systemSmall) {
    CompetitionTasksWidget()
} timeline: {
    TasksEntry(
        date: Date(),
        tasks: WidgetDataProvider.shared.sampleTasks(),
        totalPending: 5
    )
}

#Preview("Medium", as: .systemMedium) {
    CompetitionTasksWidget()
} timeline: {
    TasksEntry(
        date: Date(),
        tasks: WidgetDataProvider.shared.sampleTasks(),
        totalPending: 5
    )
}

#Preview("Large", as: .systemLarge) {
    CompetitionTasksWidget()
} timeline: {
    TasksEntry(
        date: Date(),
        tasks: WidgetDataProvider.shared.sampleTasks(),
        totalPending: 5
    )
}

#Preview("Empty", as: .systemMedium) {
    CompetitionTasksWidget()
} timeline: {
    TasksEntry(
        date: Date(),
        tasks: [],
        totalPending: 0
    )
}
