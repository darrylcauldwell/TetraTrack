//
//  RemindersSyncService.swift
//  TetraTrack
//
//  Syncs CompetitionTask items to Apple Reminders via EventKit.
//  Creates a dedicated "TetraTrack" reminders list and keeps tasks in sync.
//

import EventKit
import SwiftData
import Observation
import os

// MARK: - Reminders Sync Status

enum RemindersSyncStatus: Equatable {
    case idle
    case syncing
    case synced(count: Int)
    case error(String)

    var displayText: String {
        switch self {
        case .idle:
            return "Not synced"
        case .syncing:
            return "Syncing..."
        case .synced(let count):
            return "\(count) synced"
        case .error(let message):
            return message
        }
    }

    var icon: String {
        switch self {
        case .idle:
            return "arrow.triangle.2.circlepath"
        case .syncing:
            return "arrow.triangle.2.circlepath"
        case .synced:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Reminders Sync Service

@MainActor
@Observable
final class RemindersSyncService {
    static let shared = RemindersSyncService()

    private let eventStore = EKEventStore()
    private let listTitle = "TetraTrack"
    private let logger = Logger(subsystem: "dev.dreamfold.tetratrack", category: "RemindersSyncService")

    var syncStatus: RemindersSyncStatus = .idle
    var hasAccess: Bool = false

    private init() {
        checkCurrentAuthorizationStatus()
    }

    // MARK: - Authorization

    private func checkCurrentAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        hasAccess = (status == .fullAccess)
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToReminders()
            hasAccess = granted
            if !granted {
                logger.warning("Reminders access not granted by user")
            }
            return granted
        } catch {
            logger.error("Failed to request Reminders access: \(error.localizedDescription)")
            hasAccess = false
            return false
        }
    }

    // MARK: - Reminders List Management

    private func findOrCreateTetraTrackList() -> EKCalendar? {
        let calendars = eventStore.calendars(for: .reminder)

        // Look for existing TetraTrack list
        if let existing = calendars.first(where: { $0.title == listTitle }) {
            return existing
        }

        // Create a new list
        let newCalendar = EKCalendar(for: .reminder, eventStore: eventStore)
        newCalendar.title = listTitle

        // Use the default reminder source
        if let defaultSource = eventStore.defaultCalendarForNewReminders()?.source {
            newCalendar.source = defaultSource
        } else if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            newCalendar.source = localSource
        } else if let firstSource = eventStore.sources.first(where: { $0.sourceType == .calDAV }) {
            newCalendar.source = firstSource
        } else {
            logger.error("No suitable source found for creating Reminders list")
            return nil
        }

        do {
            try eventStore.saveCalendar(newCalendar, commit: true)
            logger.info("Created TetraTrack reminders list")
            return newCalendar
        } catch {
            logger.error("Failed to create TetraTrack reminders list: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Task Sync

    func syncTask(_ task: CompetitionTask) {
        guard hasAccess else {
            syncStatus = .error("No access")
            return
        }

        guard let calendar = findOrCreateTetraTrackList() else {
            syncStatus = .error("Cannot create list")
            return
        }

        let reminder: EKReminder

        // Try to find existing reminder by stored identifier
        if !task.reminderIdentifier.isEmpty,
           let existing = eventStore.calendarItem(withIdentifier: task.reminderIdentifier) as? EKReminder {
            reminder = existing
        } else {
            // Create a new reminder
            reminder = EKReminder(eventStore: eventStore)
            reminder.calendar = calendar
        }

        // Map task properties to reminder
        reminder.title = task.title
        reminder.isCompleted = task.isCompleted
        reminder.completionDate = task.completedAt

        // Map priority
        switch task.priority {
        case .high:
            reminder.priority = Int(EKReminderPriority.high.rawValue)
        case .medium:
            reminder.priority = Int(EKReminderPriority.medium.rawValue)
        case .low:
            reminder.priority = Int(EKReminderPriority.low.rawValue)
        }

        // Set due date as alarm and due date components
        if let dueDate = task.dueDate {
            let dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
            reminder.dueDateComponents = dueDateComponents

            // Add an alarm for the due date if none exists
            if reminder.alarms == nil || reminder.alarms?.isEmpty == true {
                reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
            }
        } else {
            reminder.dueDateComponents = nil
            if let alarms = reminder.alarms {
                for alarm in alarms {
                    reminder.removeAlarm(alarm)
                }
            }
        }

        // Build notes including competition name if linked
        var notesText = task.notes
        if let competition = task.competition {
            let competitionInfo = "Competition: \(competition.name)"
            if !notesText.isEmpty {
                notesText = "\(competitionInfo)\n\n\(notesText)"
            } else {
                notesText = competitionInfo
            }
        }
        reminder.notes = notesText.isEmpty ? nil : notesText

        do {
            try eventStore.save(reminder, commit: true)
            // Store the reminder identifier back on the task
            task.reminderIdentifier = reminder.calendarItemIdentifier
            logger.info("Synced task '\(task.title)' to Reminders")
        } catch {
            logger.error("Failed to save reminder: \(error.localizedDescription)")
            syncStatus = .error("Sync failed")
        }
    }

    func removeTask(_ task: CompetitionTask) {
        guard hasAccess else { return }
        guard !task.reminderIdentifier.isEmpty else { return }

        guard let reminder = eventStore.calendarItem(withIdentifier: task.reminderIdentifier) as? EKReminder else {
            // Reminder already deleted or not found - clear the identifier
            task.reminderIdentifier = ""
            return
        }

        do {
            try eventStore.remove(reminder, commit: true)
            task.reminderIdentifier = ""
            logger.info("Removed reminder for task '\(task.title)'")
        } catch {
            logger.error("Failed to remove reminder: \(error.localizedDescription)")
        }
    }

    func syncAllTasks(_ tasks: [CompetitionTask]) {
        guard hasAccess else {
            syncStatus = .error("No access")
            return
        }

        syncStatus = .syncing
        var syncedCount = 0

        for task in tasks {
            syncTask(task)
            syncedCount += 1
        }

        syncStatus = .synced(count: syncedCount)
        logger.info("Synced \(syncedCount) tasks to Reminders")
    }

    // MARK: - Fetch Completion Updates

    func fetchCompletionUpdates(_ tasks: [CompetitionTask]) {
        guard hasAccess else { return }

        var updatedCount = 0

        for task in tasks {
            guard !task.reminderIdentifier.isEmpty else { continue }

            guard let reminder = eventStore.calendarItem(withIdentifier: task.reminderIdentifier) as? EKReminder else {
                continue
            }

            // Check if completion status changed in Reminders app
            if reminder.isCompleted != task.isCompleted {
                task.isCompleted = reminder.isCompleted
                task.completedAt = reminder.isCompleted ? (reminder.completionDate ?? Date()) : nil
                updatedCount += 1
                logger.info("Updated task '\(task.title)' completion from Reminders: \(reminder.isCompleted)")
            }
        }

        if updatedCount > 0 {
            logger.info("Updated \(updatedCount) tasks from Reminders completions")
        }
    }
}
