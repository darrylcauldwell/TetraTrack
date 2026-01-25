//
//  LinkedRider.swift
//  TrackRide
//
//  Represents a family member who shares their live tracking with you.
//  Stored in UserDefaults for persistence.
//

import Foundation

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

// MARK: - Linked Rider

/// Represents a rider whose location you can view (they've shared with you)
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
