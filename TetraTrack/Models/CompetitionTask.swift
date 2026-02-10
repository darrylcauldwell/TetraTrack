//
//  CompetitionTask.swift
//  TetraTrack
//
//  Competition to-do list feature for tracking competition preparation tasks
//

import Foundation
import SwiftData

// MARK: - Task Category

enum TaskCategory: String, Codable, CaseIterable, Identifiable {
    case venue = "Venue"
    case travel = "Travel"
    case equipment = "Equipment"
    case entries = "Entries"
    case rosettes = "Rosettes"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .venue: return "building.2"
        case .travel: return "car"
        case .equipment: return "bag"
        case .entries: return "doc.text"
        case .rosettes: return "rosette"
        case .other: return "ellipsis.circle"
        }
    }

    var displayName: String {
        rawValue
    }
}

// MARK: - Task Priority

enum TaskPriority: String, Codable, CaseIterable, Comparable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }

    var icon: String {
        switch self {
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "arrow.up"
        }
    }

    static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - Competition Task Model

@Model
final class CompetitionTask {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var dueDate: Date?
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    var completedAt: Date?

    // Stored as raw values for SwiftData compatibility
    var priorityRaw: String = TaskPriority.medium.rawValue
    var categoryRaw: String = TaskCategory.other.rawValue

    // Apple Reminders sync identifier
    var reminderIdentifier: String = ""

    // Optional link to Competition
    var competition: Competition?

    init() {}

    init(
        title: String = "",
        notes: String = "",
        dueDate: Date? = nil,
        priority: TaskPriority = .medium,
        category: TaskCategory = .other,
        competition: Competition? = nil
    ) {
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.priorityRaw = priority.rawValue
        self.categoryRaw = category.rawValue
        self.competition = competition
    }

    // MARK: - Computed Properties

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var isOverdue: Bool {
        guard let due = dueDate, !isCompleted else { return false }
        return due < Date()
    }

    var isDueToday: Bool {
        guard let due = dueDate else { return false }
        return Calendar.current.isDateInToday(due)
    }

    var isDueSoon: Bool {
        guard let due = dueDate, !isCompleted else { return false }
        let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
        return daysUntilDue >= 0 && daysUntilDue <= 3
    }

    var daysUntilDue: Int? {
        guard let due = dueDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: due)).day
    }

    var dueDateText: String? {
        guard let due = dueDate else { return nil }

        if isDueToday {
            return "Today"
        }

        if let days = daysUntilDue {
            if days < 0 {
                return "\(abs(days)) \(abs(days) == 1 ? "day" : "days") overdue"
            } else if days == 1 {
                return "Tomorrow"
            } else if days < 7 {
                return "In \(days) days"
            }
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: due)
    }

    var formattedDueDate: String {
        guard let due = dueDate else { return "No due date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: due)
    }

    // MARK: - Actions

    func toggleCompletion() {
        isCompleted.toggle()
        completedAt = isCompleted ? Date() : nil
    }
}

// MARK: - Task Grouping Helpers

extension Array where Element == CompetitionTask {

    /// Group tasks by category
    var groupedByCategory: [TaskCategory: [CompetitionTask]] {
        Dictionary(grouping: self) { $0.category }
    }

    /// Group tasks by due date proximity
    var groupedByDueDate: [String: [CompetitionTask]] {
        var groups: [String: [CompetitionTask]] = [:]

        for task in self {
            let key: String
            if task.isOverdue {
                key = "Overdue"
            } else if task.isDueToday {
                key = "Today"
            } else if let days = task.daysUntilDue, days == 1 {
                key = "Tomorrow"
            } else if let days = task.daysUntilDue, days <= 7 {
                key = "This Week"
            } else if let days = task.daysUntilDue, days <= 30 {
                key = "This Month"
            } else if task.dueDate != nil {
                key = "Later"
            } else {
                key = "No Due Date"
            }

            groups[key, default: []].append(task)
        }

        return groups
    }

    /// Sort tasks by priority and due date
    var sortedByPriorityAndDate: [CompetitionTask] {
        sorted { task1, task2 in
            // First by completion status
            if task1.isCompleted != task2.isCompleted {
                return !task1.isCompleted
            }
            // Then by priority
            if task1.priority != task2.priority {
                return task1.priority < task2.priority
            }
            // Then by due date
            if let date1 = task1.dueDate, let date2 = task2.dueDate {
                return date1 < date2
            }
            // Tasks with due dates come before those without
            if task1.dueDate != nil && task2.dueDate == nil {
                return true
            }
            if task1.dueDate == nil && task2.dueDate != nil {
                return false
            }
            // Finally by creation date
            return task1.createdAt < task2.createdAt
        }
    }

    /// Pending tasks only
    var pending: [CompetitionTask] {
        filter { !$0.isCompleted }
    }

    /// Completed tasks only
    var completed: [CompetitionTask] {
        filter { $0.isCompleted }
    }
}
