//
//  LinkedRider.swift
//  TetraTrack
//
//  Represents a family member who shares their live tracking with you.
//  LinkedRiderRecord is persisted in SwiftData for CloudKit sync.
//  LinkedRider struct is used for in-memory/transient data with live sessions.
//

import Foundation
import SwiftData

// MARK: - Family Role

/// Role in the family sharing system
enum FamilyRole {
    /// Not sharing with anyone
    case selfOnly

    /// Sharing location with family (child/athlete)
    case child

    /// Watching family members (parent/guardian)
    case parent
}

// MARK: - Linked Rider Record (SwiftData)

/// Persistent record of a rider who shares their location with you.
/// Stored in SwiftData for CloudKit sync across devices.
@Model
final class LinkedRiderRecord {
    // MARK: Identity
    var id: UUID = UUID()

    /// CloudKit user ID of the rider
    var riderID: String = ""

    /// Display name of the rider
    var name: String = ""

    /// When this rider was added
    var addedDate: Date = Date()

    /// When we last saw activity from this rider
    var lastSeenDate: Date?

    // MARK: - Initializers

    init() {}

    init(
        id: UUID = UUID(),
        riderID: String,
        name: String
    ) {
        self.id = id
        self.riderID = riderID
        self.name = name
        self.addedDate = Date()
    }

    // MARK: - Computed Properties

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return name.prefix(2).uppercased()
    }

    /// Convert to transient LinkedRider struct for use with live session data
    func toLinkedRider() -> LinkedRider {
        var rider = LinkedRider(id: id, riderID: riderID, name: name)
        rider.lastSeenDate = lastSeenDate
        return rider
    }
}

// MARK: - Linked Rider (Transient)

/// Represents a rider whose location you can view (they've shared with you)
/// This struct is used for in-memory operations with live session data.
struct LinkedRider: Identifiable, Codable, Equatable {
    let id: UUID
    let riderID: String  // CloudKit user ID
    var name: String

    // Status
    var isCurrentlyRiding: Bool = false
    var lastSeenDate: Date?

    // Current session (not persisted)
    var currentSession: LiveTrackingSession?

    // MARK: - Initializers

    init(
        id: UUID = UUID(),
        riderID: String,
        name: String
    ) {
        self.id = id
        self.riderID = riderID
        self.name = name
    }

    // MARK: - Computed Properties

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return name.prefix(2).uppercased()
    }

    var displayStatus: String {
        if isCurrentlyRiding {
            return "Riding Now"
        } else if let lastSeen = lastSeenDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Last seen \(formatter.localizedString(for: lastSeen, relativeTo: Date()))"
        }
        return "Not connected"
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, riderID, name, isCurrentlyRiding, lastSeenDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        riderID = try container.decode(String.self, forKey: .riderID)
        name = try container.decode(String.self, forKey: .name)
        isCurrentlyRiding = try container.decodeIfPresent(Bool.self, forKey: .isCurrentlyRiding) ?? false
        lastSeenDate = try container.decodeIfPresent(Date.self, forKey: .lastSeenDate)
        currentSession = nil  // Not persisted
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(riderID, forKey: .riderID)
        try container.encode(name, forKey: .name)
        try container.encode(isCurrentlyRiding, forKey: .isCurrentlyRiding)
        try container.encodeIfPresent(lastSeenDate, forKey: .lastSeenDate)
        // currentSession not encoded
    }

    // MARK: - Equatable

    static func == (lhs: LinkedRider, rhs: LinkedRider) -> Bool {
        lhs.id == rhs.id && lhs.riderID == rhs.riderID
    }
}
