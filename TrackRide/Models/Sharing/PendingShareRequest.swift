//
//  PendingShareRequest.swift
//  TrackRide
//
//  SwiftData model for pending share requests that haven't been accepted yet.
//  Replaces the UserDefaults-based struct in FamilySharingManager.
//

import Foundation
import SwiftData

// MARK: - Pending Share Request

/// Represents an incoming share request that hasn't been accepted yet.
/// Stored in SwiftData for persistence across app launches.
@Model
final class PendingShareRequest {
    // MARK: Identity
    var id: UUID = UUID()

    /// CloudKit user ID of the person who shared
    var ownerID: String = ""

    /// Display name of the person who shared
    var ownerName: String = ""

    /// CloudKit share URL (stored as string for SwiftData compatibility)
    var shareURLString: String?

    /// When this request was received
    var receivedDate: Date = Date()

    /// Whether this request has been viewed
    var hasBeenViewed: Bool = false

    // MARK: - Initializers

    init() {}

    init(
        id: UUID = UUID(),
        ownerID: String,
        ownerName: String,
        shareURL: URL? = nil
    ) {
        self.id = id
        self.ownerID = ownerID
        self.ownerName = ownerName
        self.shareURLString = shareURL?.absoluteString
        self.receivedDate = Date()
        self.hasBeenViewed = false
    }

    // MARK: - Computed Properties

    var shareURL: URL? {
        get {
            guard let urlString = shareURLString else { return nil }
            return URL(string: urlString)
        }
        set {
            shareURLString = newValue?.absoluteString
        }
    }

    var initials: String {
        let parts = ownerName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return ownerName.prefix(2).uppercased()
    }

    var timeSinceReceived: String {
        let interval = Date().timeIntervalSince(receivedDate)

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

    /// Display text showing who shared and when
    var displayDescription: String {
        "\(ownerName) wants to share their training with you"
    }
}

// MARK: - Migration Helper

extension PendingShareRequest {
    /// Create from the legacy PendingShareRequest struct stored in UserDefaults
    static func fromLegacy(
        ownerID: String,
        ownerName: String,
        shareURL: URL?,
        receivedDate: Date
    ) -> PendingShareRequest {
        let request = PendingShareRequest(
            ownerID: ownerID,
            ownerName: ownerName,
            shareURL: shareURL
        )
        request.receivedDate = receivedDate
        return request
    }
}
