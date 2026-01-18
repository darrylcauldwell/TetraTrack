//
//  SharingRelationship.swift
//  TrackRide
//
//  Friend/coach relationship model with permissions for ephemeral sharing.
//

import Foundation
import SwiftData

// MARK: - Relationship Type

/// Type of sharing relationship
enum RelationshipType: String, Codable, CaseIterable {
    case friend
    case coach
    case familyMember

    var displayName: String {
        switch self {
        case .friend: return "Friend"
        case .coach: return "Coach"
        case .familyMember: return "Family Member"
        }
    }

    var icon: String {
        switch self {
        case .friend: return "person.2.fill"
        case .coach: return "figure.walk.motion"
        case .familyMember: return "house.fill"
        }
    }
}

// MARK: - Sharing Relationship

/// Local model for friend/coach relationships.
/// Stored in SwiftData, CKShares generated per-artifact.
@Model
final class SharingRelationship {
    // MARK: Identity
    var id: UUID = UUID()
    var name: String = ""
    var email: String?
    var phoneNumber: String?
    var relationshipTypeRaw: String = RelationshipType.friend.rawValue
    var addedDate: Date = Date()

    // MARK: Permissions
    var canViewLiveRiding: Bool = false
    var canViewTrainingSummaries: Bool = true
    var canViewCompetitions: Bool = true
    var receiveCompletionAlerts: Bool = false
    var receiveCompetitionReminders: Bool = false

    // MARK: Per-Discipline Visibility
    var visibleDisciplinesData: Data?   // JSON-encoded Set<String> of discipline raw values

    // MARK: Notification Preferences
    var quietHoursStart: Int?           // Hour (0-23)
    var quietHoursEnd: Int?

    // MARK: Active Shares
    var activeShareIDsData: Data?       // JSON-encoded [String] CKShare record IDs

    // MARK: - Initializers

    init() {
        // Set default visible disciplines
        let allDisciplines = TrainingDiscipline.allCases.map { $0.rawValue }
        visibleDisciplinesData = try? JSONEncoder().encode(Set(allDisciplines))
    }

    init(name: String, relationshipType: RelationshipType) {
        self.id = UUID()
        self.name = name
        self.relationshipTypeRaw = relationshipType.rawValue
        self.addedDate = Date()

        // Set default visible disciplines
        let allDisciplines = TrainingDiscipline.allCases.map { $0.rawValue }
        visibleDisciplinesData = try? JSONEncoder().encode(Set(allDisciplines))
    }

    // MARK: - Computed Properties

    var relationshipType: RelationshipType {
        get { RelationshipType(rawValue: relationshipTypeRaw) ?? .friend }
        set { relationshipTypeRaw = newValue.rawValue }
    }

    var visibleDisciplines: Set<TrainingDiscipline> {
        get {
            guard let data = visibleDisciplinesData,
                  let rawValues = try? JSONDecoder().decode(Set<String>.self, from: data) else {
                return Set(TrainingDiscipline.allCases)
            }
            return Set(rawValues.compactMap { TrainingDiscipline(rawValue: $0) })
        }
        set {
            let rawValues = Set(newValue.map { $0.rawValue })
            visibleDisciplinesData = try? JSONEncoder().encode(rawValues)
        }
    }

    var activeShareIDs: [String] {
        get {
            guard let data = activeShareIDsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            activeShareIDsData = try? JSONEncoder().encode(newValue)
        }
    }

    // MARK: - Notification Helpers

    var hasQuietHours: Bool {
        quietHoursStart != nil && quietHoursEnd != nil
    }

    /// Check if current time falls within quiet hours
    func isInQuietHours(at date: Date = Date()) -> Bool {
        guard let start = quietHoursStart, let end = quietHoursEnd else {
            return false
        }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)

        // Handle overnight quiet hours (e.g., 22:00 - 07:00)
        if start > end {
            return hour >= start || hour < end
        } else {
            return hour >= start && hour < end
        }
    }

    // MARK: - Permission Helpers

    /// Check if this relationship can view a specific discipline
    func canView(discipline: TrainingDiscipline) -> Bool {
        guard canViewTrainingSummaries else { return false }
        return visibleDisciplines.contains(discipline)
    }

    /// Check if this relationship should receive an alert for a discipline
    func shouldReceiveAlert(for discipline: TrainingDiscipline, alertType: AlertType) -> Bool {
        switch alertType {
        case .sessionCompleted:
            return receiveCompletionAlerts && canView(discipline: discipline)
        case .liveTracking:
            return canViewLiveRiding && discipline == .riding
        case .competitionReminder:
            return receiveCompetitionReminders && canViewCompetitions
        case .safety:
            return canViewLiveRiding  // Safety alerts always sent if live tracking enabled
        }
    }

    enum AlertType: String, CustomStringConvertible {
        case sessionCompleted = "sessionCompleted"
        case liveTracking = "liveTracking"
        case competitionReminder = "competitionReminder"
        case safety = "safety"

        var description: String { rawValue }
    }

    // MARK: - Share Management

    func addActiveShare(_ shareID: String) {
        var ids = activeShareIDs
        if !ids.contains(shareID) {
            ids.append(shareID)
            activeShareIDs = ids
        }
    }

    func removeActiveShare(_ shareID: String) {
        var ids = activeShareIDs
        ids.removeAll { $0 == shareID }
        activeShareIDs = ids
    }

    func clearActiveShares() {
        activeShareIDs = []
    }

    var activeShareCount: Int {
        activeShareIDs.count
    }
}

// MARK: - Notification Preferences

/// User preferences for notification routing
struct NotificationPreferences: Codable {
    // Per-discipline completion alerts (for parent-child)
    var sessionCompletionAlerts: [String: Bool] = [
        TrainingDiscipline.riding.rawValue: true,
        TrainingDiscipline.running.rawValue: true,
        TrainingDiscipline.swimming.rawValue: true,
        TrainingDiscipline.shooting.rawValue: false
    ]

    // Live tracking enabled disciplines
    var liveTrackingDisciplinesRaw: Set<String> = [
        TrainingDiscipline.riding.rawValue,
        TrainingDiscipline.running.rawValue
    ]

    // Safety & competition
    var safetyAlertsEnabled: Bool = true
    var competitionReminders: Bool = true
    var competitionReminderDays: [Int] = [7, 1]  // Days before

    // Quiet hours
    var quietHoursEnabled: Bool = false
    var quietHoursStart: Int = 22  // 10 PM
    var quietHoursEnd: Int = 7     // 7 AM

    // Throttling
    var maxAlertsPerHour: Int = 5

    // MARK: - Computed Properties

    var liveTrackingDisciplines: Set<TrainingDiscipline> {
        get {
            Set(liveTrackingDisciplinesRaw.compactMap { TrainingDiscipline(rawValue: $0) })
        }
        set {
            liveTrackingDisciplinesRaw = Set(newValue.map { $0.rawValue })
        }
    }

    func shouldSendCompletionAlert(for discipline: TrainingDiscipline) -> Bool {
        sessionCompletionAlerts[discipline.rawValue] ?? true
    }

    func isLiveTrackingEnabled(for discipline: TrainingDiscipline) -> Bool {
        liveTrackingDisciplines.contains(discipline)
    }

    /// Check if current time falls within quiet hours
    func isInQuietHours(at date: Date = Date()) -> Bool {
        guard quietHoursEnabled else { return false }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)

        // Handle overnight quiet hours
        if quietHoursStart > quietHoursEnd {
            return hour >= quietHoursStart || hour < quietHoursEnd
        } else {
            return hour >= quietHoursStart && hour < quietHoursEnd
        }
    }

    // MARK: - Static Defaults

    static var `default`: NotificationPreferences {
        NotificationPreferences()
    }
}
