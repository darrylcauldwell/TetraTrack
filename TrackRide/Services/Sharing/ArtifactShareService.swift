//
//  ArtifactShareService.swift
//  TrackRide
//
//  Actor-based service for sharing training artifacts with friends/coaches.
//  Manages ephemeral per-artifact CKShares with optional expiry.
//

import Foundation
import CloudKit
import os

// MARK: - Artifact Share

/// Represents an active CKShare for a training artifact
struct ArtifactShare: Identifiable, Codable {
    let id: UUID
    let artifactID: UUID
    let relationshipID: UUID          // SharingRelationship.id
    let shareRecordID: String         // CKShare record name
    var shareURL: URL?
    let createdAt: Date
    var expiresAt: Date?              // Optional auto-expiry

    init(
        id: UUID = UUID(),
        artifactID: UUID,
        relationshipID: UUID,
        shareRecordID: String,
        shareURL: URL? = nil,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.artifactID = artifactID
        self.relationshipID = relationshipID
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

// MARK: - Artifact Share Service

actor ArtifactShareService {
    // MARK: State

    private(set) var activeShares: [ArtifactShare] = []

    // CloudKit
    private let container: CKContainer
    private let zoneName: String
    private var zoneID: CKRecordZone.ID?

    // Persistence
    private let sharesKey = "activeArtifactShares"

    // Default share expiry (24 hours)
    let defaultExpiryDuration: TimeInterval = 24 * 60 * 60

    // MARK: Initialization

    init(
        container: CKContainer = .default(),
        zoneName: String = "FamilySharing"
    ) {
        self.container = container
        self.zoneName = zoneName
        // Load shares synchronously from UserDefaults
        if let data = UserDefaults.standard.data(forKey: sharesKey),
           let shares = try? JSONDecoder().decode([ArtifactShare].self, from: data) {
            self.activeShares = shares
        }
    }

    // MARK: - Configuration

    /// Configure with zone ID
    func configure(zoneID: CKRecordZone.ID) {
        self.zoneID = zoneID
    }

    // MARK: - Ensure Zone Exists

    private func ensureZoneExists() async throws {
        if zoneID != nil { return }

        let zone = CKRecordZone(zoneName: zoneName)
        zoneID = zone.zoneID

        do {
            _ = try await container.privateCloudDatabase.modifyRecordZones(
                saving: [zone],
                deleting: []
            )
        } catch {
            Log.family.error("ArtifactShareService: Failed to create zone: \(error)")
            throw error
        }
    }

    // MARK: - Share an Artifact

    /// Create a read-only ephemeral share for a specific artifact
    func shareArtifact(
        _ artifact: TrainingArtifact,
        with relationshipID: UUID,
        expiresIn: TimeInterval? = nil
    ) async throws -> ArtifactShare {
        try await ensureZoneExists()

        guard let zoneID = zoneID else {
            throw ArtifactShareError.zoneNotAvailable
        }

        // Create a CKShare for this specific artifact record
        let share = CKShare(rootRecord: artifact.toCKRecord(zoneID: zoneID))
        share.publicPermission = .readOnly
        share[CKShare.SystemFieldKey.title] = "Training Session" as CKRecordValue
        share[CKShare.SystemFieldKey.shareType] = artifact.discipline.rawValue as CKRecordValue

        // Save the share
        let savedRecord = try await container.privateCloudDatabase.save(share)
        guard let savedShare = savedRecord as? CKShare else {
            Log.family.error("CloudKit returned unexpected record type: \(type(of: savedRecord))")
            throw ArtifactShareError.shareCreationFailed
        }

        // Calculate expiry
        let expiryDuration = expiresIn ?? defaultExpiryDuration
        let expiresAt = Date().addingTimeInterval(expiryDuration)

        // Create local tracking record
        let artifactShare = ArtifactShare(
            artifactID: artifact.id,
            relationshipID: relationshipID,
            shareRecordID: savedShare.recordID.recordName,
            shareURL: savedShare.url,
            expiresAt: expiresAt
        )

        // Store locally
        activeShares.append(artifactShare)
        saveActiveShares()

        Log.family.info("Created share for artifact \(artifact.id) with relationship \(relationshipID)")

        return artifactShare
    }

    // MARK: - Revoke Shares

    /// Revoke a specific share
    func revokeShare(_ share: ArtifactShare) async throws {
        guard let zoneID = zoneID else {
            throw ArtifactShareError.zoneNotAvailable
        }

        let shareRecordID = CKRecord.ID(recordName: share.shareRecordID, zoneID: zoneID)

        do {
            _ = try await container.privateCloudDatabase.deleteRecord(withID: shareRecordID)
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

    /// Revoke all shares with a specific relationship
    func revokeAllShares(with relationshipID: UUID) async {
        let sharesToRevoke = activeShares.filter { $0.relationshipID == relationshipID }

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
    func shares(for artifactID: UUID) -> [ArtifactShare] {
        activeShares.filter { $0.artifactID == artifactID && !$0.isExpired }
    }

    /// Get all active shares with a relationship
    func shares(with relationshipID: UUID) -> [ArtifactShare] {
        activeShares.filter { $0.relationshipID == relationshipID && !$0.isExpired }
    }

    /// Check if artifact is shared with a specific relationship
    func isShared(artifactID: UUID, with relationshipID: UUID) -> Bool {
        activeShares.contains {
            $0.artifactID == artifactID &&
            $0.relationshipID == relationshipID &&
            !$0.isExpired
        }
    }

    // MARK: - Cleanup

    /// Remove expired shares from CloudKit and local storage
    func cleanupExpiredShares() async {
        let expiredShares = activeShares.filter { $0.isExpired }
        var successfullyRevoked = 0
        var failedToRevoke = 0

        for share in expiredShares {
            do {
                try await revokeShare(share)
                successfullyRevoked += 1
            } catch {
                // Keep in local storage for retry - don't orphan CloudKit records
                Log.family.warning("Failed to revoke expired share \(share.id), will retry later: \(error)")
                failedToRevoke += 1
            }
        }

        if successfullyRevoked > 0 || failedToRevoke > 0 {
            Log.family.info("Cleanup: revoked \(successfullyRevoked) shares, \(failedToRevoke) failed (will retry)")
        }
    }

    // MARK: - Persistence

    private func loadActiveShares() {
        if let data = UserDefaults.standard.data(forKey: sharesKey),
           let shares = try? JSONDecoder().decode([ArtifactShare].self, from: data) {
            activeShares = shares
        }
    }

    private func saveActiveShares() {
        if let data = try? JSONEncoder().encode(activeShares) {
            UserDefaults.standard.set(data, forKey: sharesKey)
        }
    }

    // MARK: - Invitation Message

    /// Generate an invitation message with share link
    func generateInvitationMessage(
        for share: ArtifactShare,
        contactName: String,
        artifactName: String
    ) -> String {
        let firstName = contactName.split(separator: " ").first.map(String.init) ?? "there"

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

// MARK: - Artifact Share Error

enum ArtifactShareError: Error, LocalizedError {
    case zoneNotAvailable
    case shareCreationFailed
    case shareRevocationFailed
    case artifactNotFound

    var errorDescription: String? {
        switch self {
        case .zoneNotAvailable:
            return "CloudKit zone is not available. Please check your iCloud connection."
        case .shareCreationFailed:
            return "Failed to create the share. Please try again."
        case .shareRevocationFailed:
            return "Failed to revoke the share. Please try again."
        case .artifactNotFound:
            return "Training artifact not found."
        }
    }
}
