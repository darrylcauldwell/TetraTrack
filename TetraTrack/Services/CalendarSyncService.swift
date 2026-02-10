//
//  CalendarSyncService.swift
//  TetraTrack
//
//  Syncs competitions to Apple Calendar via EventKit
//

import EventKit
import SwiftUI
import CoreLocation

@Observable
@MainActor
final class CalendarSyncService {

    static let shared = CalendarSyncService()

    // MARK: - State

    private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    private(set) var isSyncing = false
    private(set) var lastError: String?

    private let eventStore = EKEventStore()
    private let calendarTitle = "TetraTrack"

    var isAuthorized: Bool {
        authorizationStatus == .fullAccess
    }

    // MARK: - Init

    private init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    // MARK: - Authorization

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            if !granted {
                lastError = "Calendar access was denied. You can enable it in Settings."
            }
            return granted
        } catch {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            lastError = "Failed to request calendar access: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Calendar Management

    private func findOrCreateCalendar() -> EKCalendar? {
        // Look for an existing TetraTrack calendar
        let calendars = eventStore.calendars(for: .event)
        if let existing = calendars.first(where: { $0.title == calendarTitle }) {
            return existing
        }

        // Create a new calendar
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = calendarTitle

        // Use a distinctive blue color matching the app's primary theme
        calendar.cgColor = UIColor(red: 0.15, green: 0.45, blue: 0.85, alpha: 1.0).cgColor

        // Find the best source for the calendar (prefer iCloud, then local)
        let sources = eventStore.sources
        if let iCloudSource = sources.first(where: { $0.sourceType == .calDAV }) {
            calendar.source = iCloudSource
        } else if let localSource = sources.first(where: { $0.sourceType == .local }) {
            calendar.source = localSource
        } else if let defaultSource = sources.first {
            calendar.source = defaultSource
        } else {
            lastError = "No calendar source available."
            return nil
        }

        do {
            try eventStore.saveCalendar(calendar, commit: true)
            return calendar
        } catch {
            lastError = "Failed to create TetraTrack calendar: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Sync Single Competition

    @discardableResult
    func syncCompetition(_ competition: Competition) async -> Bool {
        if !isAuthorized {
            let granted = await requestAccess()
            if !granted { return false }
        }

        isSyncing = true
        lastError = nil
        defer { isSyncing = false }

        guard let calendar = findOrCreateCalendar() else {
            return false
        }

        // Check if event already exists
        var event: EKEvent?
        if !competition.calendarEventIdentifier.isEmpty {
            event = eventStore.event(withIdentifier: competition.calendarEventIdentifier)
        }

        // Create new event if needed
        if event == nil {
            event = EKEvent(eventStore: eventStore)
            event?.calendar = calendar
        }

        guard let ekEvent = event else {
            lastError = "Failed to create calendar event."
            return false
        }

        // Map competition properties to event
        configureEvent(ekEvent, from: competition)

        do {
            try eventStore.save(ekEvent, span: .thisEvent, commit: true)

            // Store the event identifier back on the competition
            if let identifier = ekEvent.eventIdentifier {
                competition.calendarEventIdentifier = identifier
            }

            return true
        } catch {
            lastError = "Failed to save calendar event: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Remove Competition from Calendar

    @discardableResult
    func removeCompetition(_ competition: Competition) async -> Bool {
        guard isAuthorized else { return false }

        guard !competition.calendarEventIdentifier.isEmpty,
              let event = eventStore.event(withIdentifier: competition.calendarEventIdentifier) else {
            // No event to remove, clear identifier
            competition.calendarEventIdentifier = ""
            return true
        }

        do {
            try eventStore.remove(event, span: .thisEvent, commit: true)
            competition.calendarEventIdentifier = ""
            return true
        } catch {
            lastError = "Failed to remove calendar event: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Sync All Competitions

    func syncAllCompetitions(_ competitions: [Competition]) async -> (synced: Int, failed: Int) {
        if !isAuthorized {
            let granted = await requestAccess()
            if !granted { return (0, 0) }
        }

        isSyncing = true
        lastError = nil
        defer { isSyncing = false }

        var synced = 0
        var failed = 0

        for competition in competitions {
            let success = await syncCompetition(competition)
            if success {
                synced += 1
            } else {
                failed += 1
            }
        }

        return (synced, failed)
    }

    // MARK: - Check if Competition is Synced

    func isCompetitionSynced(_ competition: Competition) -> Bool {
        guard !competition.calendarEventIdentifier.isEmpty else { return false }
        return eventStore.event(withIdentifier: competition.calendarEventIdentifier) != nil
    }

    // MARK: - Event Configuration

    private func configureEvent(_ event: EKEvent, from competition: Competition) {
        event.title = competition.name.isEmpty ? "Competition" : competition.name

        // Start date
        event.startDate = competition.date

        // End date: use endDate for multi-day, otherwise same day
        if let endDate = competition.endDate {
            event.endDate = endDate
            event.isAllDay = true
        } else {
            event.isAllDay = true
            event.endDate = competition.date
        }

        // Location
        var locationParts: [String] = []
        if !competition.venue.isEmpty {
            locationParts.append(competition.venue)
        }
        if !competition.location.isEmpty && competition.location != competition.venue {
            locationParts.append(competition.location)
        }
        event.location = locationParts.isEmpty ? nil : locationParts.joined(separator: ", ")

        // Structured location with coordinates
        if let lat = competition.venueLatitude, let lon = competition.venueLongitude {
            let structuredLocation = EKStructuredLocation(title: competition.venue.isEmpty ? "Competition Venue" : competition.venue)
            structuredLocation.geoLocation = CLLocation(latitude: lat, longitude: lon)
            event.structuredLocation = structuredLocation
        }

        // Notes with competition details
        var noteLines: [String] = []
        noteLines.append("Type: \(competition.competitionType.rawValue)")
        noteLines.append("Level: \(competition.level.rawValue)")

        if !competition.competitionType.disciplines.isEmpty {
            noteLines.append("Disciplines: \(competition.competitionType.disciplines.joined(separator: ", "))")
        }

        if let fee = competition.entryFee {
            noteLines.append(String(format: "Entry Fee: \u{00A3}%.2f", fee))
        }

        if !competition.websiteURL.isEmpty {
            noteLines.append("Website: \(competition.websiteURL)")
        }

        if !competition.notes.isEmpty {
            noteLines.append("")
            noteLines.append(competition.notes)
        }

        event.notes = noteLines.joined(separator: "\n")

        // Add an alert 1 day before
        event.alarms = [EKAlarm(relativeOffset: -86400)]
    }
}
