//
//  FriendSharingService.swift
//  TrackRide
//
//  CKShare management for ephemeral friend/coach sharing.
//

import Foundation
import CloudKit
import SwiftData
import os

// MARK: - Friend Share

/// Represents an active CKShare with a friend
struct FriendShare: Identifiable, Codable {
    let id: UUID
    let artifactID: UUID
    let friendID: UUID                  // SharingRelationship ID
    let shareRecordID: String           // CKShare record name
    var shareURL: URL?
    let createdAt: Date
    var expiresAt: Date?                // Optional auto-expiry

    init(
        artifactID: UUID,
        friendID: UUID,
        shareRecordID: String,
        shareURL: URL? = nil,
        expiresAt: Date? = nil
    ) {
        self.id = UUID()
        self.artifactID = artifactID
        self.friendID = friendID
        self.shareRecordID = shareRecordID
        self.shareURL = shareURL
        self.createdAt = Date()
        self.expiresAt = expiresAt
    }

    var isExpired: Bool {
        guard let expires = expiresAt else { return false }
        return Date() > expires
    }
}

// MARK: - Friend Sharing Service

@Observable
final class FriendSharingService {
    static let shared = FriendSharingService()

    // State
    var activeShares: [FriendShare] = []

    // CloudKit
    private let familyZoneName = "FamilySharing"
    private var familyZoneID: CKRecordZone.ID?

    private var container: CKContainer {
        CKContainer.default()
    }

    private var privateDatabase: CKDatabase {
        container.privateCloudDatabase
    }

    // Persistence
    private let sharesKey = "activeFriendShares"
    private let relationshipsKey = "friendSharingRelationships"

    // Default share expiry (24 hours)
    private let defaultExpiryDuration: TimeInterval = 24 * 60 * 60

    private init() {
        loadActiveShares()
        Task {
            await cleanupExpiredShares()
        }
    }

    // MARK: - Zone Setup

    private func ensureZoneExists() async throws {
        if familyZoneID != nil { return }

        let zone = CKRecordZone(zoneName: familyZoneName)
        familyZoneID = zone.zoneID

        do {
            _ = try await privateDatabase.modifyRecordZones(saving: [zone], deleting: [])
        } catch {
            Log.family.error("FriendSharingService: Failed to create zone: \(error)")
            throw error
        }
    }

    // MARK: - Share an Artifact with Friend

    /// Create a read-only ephemeral share for a specific artifact
    func shareArtifact(
        _ artifact: TrainingArtifact,
        with friend: SharingRelationship,
        expiresIn: TimeInterval? = nil
    ) async throws -> FriendShare {
        try await ensureZoneExists()
        guard let zoneID = familyZoneID else {
            throw FriendSharingError.zoneNotAvailable
        }

        // Get or create the artifact record
        let artifactRecordID = CKRecord.ID(recordName: artifact.id.uuidString, zoneID: zoneID)

        // Create a CKShare for this specific record
        let share = CKShare(rootRecord: artifact.toCKRecord(zoneID: zoneID))
        share.publicPermission = .readOnly
        share[CKShare.SystemFieldKey.title] = "Training Session" as CKRecordValue
        share[CKShare.SystemFieldKey.shareType] = artifact.discipline.rawValue as CKRecordValue

        // Save the share
        let savedShare = try await privateDatabase.save(share) as! CKShare

        // Calculate expiry
        let expiryDuration = expiresIn ?? defaultExpiryDuration
        let expiresAt = Date().addingTimeInterval(expiryDuration)

        // Create local tracking record
        let friendShare = FriendShare(
            artifactID: artifact.id,
            friendID: friend.id,
            shareRecordID: savedShare.recordID.recordName,
            shareURL: savedShare.url,
            expiresAt: expiresAt
        )

        // Update artifact with friend share ID
        var shareIDs = artifact.friendShareIDs
        shareIDs.append(savedShare.recordID.recordName)
        artifact.friendShareIDs = shareIDs

        // Update friend relationship
        friend.addActiveShare(savedShare.recordID.recordName)

        // Store locally
        activeShares.append(friendShare)
        saveActiveShares()

        Log.family.info("Created share for artifact \(artifact.id) with friend \(friend.name)")

        return friendShare
    }

    /// Revoke a specific share
    func revokeShare(_ share: FriendShare) async throws {
        guard let zoneID = familyZoneID else {
            throw FriendSharingError.zoneNotAvailable
        }

        let shareRecordID = CKRecord.ID(recordName: share.shareRecordID, zoneID: zoneID)

        do {
            _ = try await privateDatabase.deleteRecord(withID: shareRecordID)
            Log.family.info("Revoked share \(share.shareRecordID)")
        } catch {
            Log.family.error("Failed to revoke share: \(error)")
            throw error
        }

        // Remove from local tracking
        activeShares.removeAll { $0.id == share.id }
        saveActiveShares()
    }

    /// Revoke all shares for a specific artifact
    func revokeAllShares(for artifactID: UUID) async {
        let sharesToRevoke = activeShares.filter { $0.artifactID == artifactID }

        for share in sharesToRevoke {
            do {
                try await revokeShare(share)
            } catch {
                Log.family.error("Failed to revoke share \(share.id): \(error)")
            }
        }
    }

    /// Revoke all shares with a specific friend
    func revokeAllShares(with friendID: UUID) async {
        let sharesToRevoke = activeShares.filter { $0.friendID == friendID }

        for share in sharesToRevoke {
            do {
                try await revokeShare(share)
            } catch {
                Log.family.error("Failed to revoke share \(share.id): \(error)")
            }
        }
    }

    // MARK: - Share Queries

    /// Get all active shares for an artifact
    func shares(for artifactID: UUID) -> [FriendShare] {
        activeShares.filter { $0.artifactID == artifactID && !$0.isExpired }
    }

    /// Get all active shares with a friend
    func shares(with friendID: UUID) -> [FriendShare] {
        activeShares.filter { $0.friendID == friendID && !$0.isExpired }
    }

    /// Check if artifact is shared with a specific friend
    func isShared(artifactID: UUID, with friendID: UUID) -> Bool {
        activeShares.contains { $0.artifactID == artifactID && $0.friendID == friendID && !$0.isExpired }
    }

    // MARK: - Cleanup

    /// Remove expired shares from CloudKit and local storage
    func cleanupExpiredShares() async {
        let expiredShares = activeShares.filter { $0.isExpired }

        for share in expiredShares {
            do {
                try await revokeShare(share)
            } catch {
                // If CloudKit delete fails, still remove from local tracking
                activeShares.removeAll { $0.id == share.id }
            }
        }

        saveActiveShares()
        Log.family.info("Cleaned up \(expiredShares.count) expired shares")
    }

    // MARK: - Persistence

    private func loadActiveShares() {
        if let data = UserDefaults.standard.data(forKey: sharesKey),
           let shares = try? JSONDecoder().decode([FriendShare].self, from: data) {
            activeShares = shares
        }
    }

    private func saveActiveShares() {
        if let data = try? JSONEncoder().encode(activeShares) {
            UserDefaults.standard.set(data, forKey: sharesKey)
        }
    }

    // MARK: - Relationship Management

    /// Load all sharing relationships from SwiftData context
    func loadRelationships(from context: ModelContext) -> [SharingRelationship] {
        let descriptor = FetchDescriptor<SharingRelationship>(
            sortBy: [SortDescriptor(\.addedDate, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Create a new sharing relationship
    func createRelationship(
        name: String,
        type: RelationshipType,
        email: String? = nil,
        phoneNumber: String? = nil,
        context: ModelContext
    ) -> SharingRelationship {
        let relationship = SharingRelationship(name: name, relationshipType: type)
        relationship.email = email
        relationship.phoneNumber = phoneNumber
        context.insert(relationship)
        return relationship
    }

    /// Delete a sharing relationship and revoke all associated shares
    func deleteRelationship(_ relationship: SharingRelationship, context: ModelContext) async {
        // Revoke all active shares first
        await revokeAllShares(with: relationship.id)

        // Delete from SwiftData
        context.delete(relationship)
    }
}

// MARK: - Errors

enum FriendSharingError: Error, LocalizedError {
    case zoneNotAvailable
    case shareCreationFailed
    case shareRevocationFailed
    case friendNotFound

    var errorDescription: String? {
        switch self {
        case .zoneNotAvailable:
            return "CloudKit zone is not available. Please check your iCloud connection."
        case .shareCreationFailed:
            return "Failed to create the share. Please try again."
        case .shareRevocationFailed:
            return "Failed to revoke the share. Please try again."
        case .friendNotFound:
            return "Friend relationship not found."
        }
    }
}

// MARK: - Share Invitation Helper

extension FriendSharingService {
    /// Generate an invitation message with share link
    func generateInvitationMessage(
        for share: FriendShare,
        friendName: String,
        artifactName: String
    ) -> String {
        let firstName = friendName.split(separator: " ").first.map(String.init) ?? "there"

        var message = """
        Hi \(firstName)!

        I've shared my \(artifactName) training session with you on TetraTrack.
        """

        if let url = share.shareURL {
            message += """


            Tap to view: \(url.absoluteString)
            """
        }

        if let expiresAt = share.expiresAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            message += """


            This link expires on \(formatter.string(from: expiresAt)).
            """
        }

        message += """


        Download TetraTrack: https://apps.apple.com/app/tetratrack
        """

        return message
    }
}
