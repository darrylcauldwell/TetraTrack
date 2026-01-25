//
//  SharingRelationship.swift
//  TrackRide
//
//  Friend/coach relationship model with permissions for ephemeral sharing.
//

import Foundation
import SwiftData

// MARK: - Invite Status

/// Status of share invitation
enum InviteStatus: String, Codable, Equatable {
    case notSent = "not_sent"
    case pending = "pending"
    case accepted = "accepted"

    var displayText: String {
        switch self {
        case .notSent: return "Invite not sent"
        case .pending: return "Invite pending"
        case .accepted: return "Connected"
        }
    }

    var icon: String {
        switch self {
        case .notSent: return "envelope"
        case .pending: return "clock"
        case .accepted: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Permission Preset

/// Preset permission configurations for quick setup
enum PermissionPreset: String, CaseIterable {
    case fullAccess       // Everything - typical for parents/guardians
    case liveTrackingOnly // Just live location - safety-focused contact
    case summariesOnly    // Just completed sessions - friends
    case coachMode        // Summaries + specific disciplines

    var displayName: String {
        switch self {
        case .fullAccess: return "Full Access"
        case .liveTrackingOnly: return "Live Tracking Only"
        case .summariesOnly: return "Summaries Only"
        case .coachMode: return "Coach Mode"
        }
    }

    var description: String {
        switch self {
        case .fullAccess:
            return "Live tracking, all summaries, all alerts"
        case .liveTrackingOnly:
            return "Real-time location only, safety alerts"
        case .summariesOnly:
            return "Completed session summaries, no live tracking"
        case .coachMode:
            return "Summaries for selected disciplines"
        }
    }
}

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

    // MARK: Family-Specific Fields (unified from TrustedContact)

    /// Whether this contact should receive emergency alerts
    var isEmergencyContact: Bool = false

    /// Whether this is the primary emergency contact (first to be called)
    var isPrimaryEmergency: Bool = false

    /// Receives fall detection notifications
    var receiveFallAlerts: Bool = true

    /// Receives stationary/stopped alerts
    var receiveStationaryAlerts: Bool = true

    // MARK: Invite Tracking

    /// Current invite status (notSent, pending, accepted)
    var inviteStatusRaw: String = InviteStatus.notSent.rawValue

    /// When the invite was sent
    var inviteSentDate: Date?

    /// When the last reminder was sent
    var lastReminderDate: Date?

    /// Number of reminders sent
    var reminderCount: Int = 0

    // MARK: CloudKit Connection

    /// CKRecord.ID.recordName of the ShareConnection record
    var connectionRecordID: String?

    /// The CloudKit share URL for this relationship
    var shareURL: String?

    // MARK: Medical Information (for emergency contacts)

    /// Medical notes to share with emergency contacts
    var medicalNotes: String?

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

    var inviteStatus: InviteStatus {
        get { InviteStatus(rawValue: inviteStatusRaw) ?? .notSent }
        set { inviteStatusRaw = newValue.rawValue }
    }

    var shareURLValue: URL? {
        get {
            guard let urlString = shareURL else { return nil }
            return URL(string: urlString)
        }
        set {
            shareURL = newValue?.absoluteString
        }
    }

    /// Time since invite was sent (for display)
    var timeSinceInvite: String? {
        guard let sentDate = inviteSentDate else { return nil }
        let interval = Date().timeIntervalSince(sentDate)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return days == 1 ? "Yesterday" : "\(days) days ago"
        }
    }

    /// Display initials for avatar
    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return name.prefix(2).uppercased()
    }

    /// Whether this contact has connection information
    var isConnected: Bool {
        inviteStatus == .accepted && connectionRecordID != nil
    }

    // MARK: - Permission Preset Application

    /// Apply a permission preset to this relationship
    func applyPreset(_ preset: PermissionPreset) {
        switch preset {
        case .fullAccess:
            canViewLiveRiding = true
            canViewTrainingSummaries = true
            canViewCompetitions = true
            receiveCompletionAlerts = true
            receiveCompetitionReminders = true
            isEmergencyContact = true
            receiveFallAlerts = true
            receiveStationaryAlerts = true

        case .liveTrackingOnly:
            canViewLiveRiding = true
            canViewTrainingSummaries = false
            canViewCompetitions = false
            receiveCompletionAlerts = false
            receiveCompetitionReminders = false
            isEmergencyContact = false
            receiveFallAlerts = true
            receiveStationaryAlerts = true

        case .summariesOnly:
            canViewLiveRiding = false
            canViewTrainingSummaries = true
            canViewCompetitions = true
            receiveCompletionAlerts = true
            receiveCompetitionReminders = false
            isEmergencyContact = false
            receiveFallAlerts = false
            receiveStationaryAlerts = false

        case .coachMode:
            canViewLiveRiding = false
            canViewTrainingSummaries = true
            canViewCompetitions = true
            receiveCompletionAlerts = true
            receiveCompetitionReminders = true
            isEmergencyContact = false
            receiveFallAlerts = false
            receiveStationaryAlerts = false
        }
    }

    // MARK: - Invite Message Generation

    /// Generate an invite message with optional share link
    func generateInviteMessage(isReminder: Bool = false) -> String {
        let greeting = isReminder ? "Reminder: " : ""
        let firstName = name.split(separator: " ").first.map(String.init) ?? "there"

        var message = """
        \(greeting)Hi \(firstName)! I've added you as a trusted contact on TetraTrack.

        You can follow my training sessions and receive safety alerts if I need help.

        Download TetraTrack: https://apps.apple.com/app/tetratrack
        """

        if let url = shareURLValue {
            message += "\n\nTap to connect: \(url.absoluteString)"
        }

        return message
    }

    /// Count of enabled features (for display)
    var enabledFeatureCount: Int {
        [canViewLiveRiding, canViewTrainingSummaries, canViewCompetitions,
         receiveCompletionAlerts, receiveCompetitionReminders,
         receiveFallAlerts, receiveStationaryAlerts, isEmergencyContact]
            .filter { $0 }.count
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
