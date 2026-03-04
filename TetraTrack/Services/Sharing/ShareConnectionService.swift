//
//  ShareConnectionService.swift
//  TetraTrack
//
//  Actor-based service for creating zone-level CloudKit shares.
//
//  Zone-level shares expose ALL records in the zone to accepted participants,
//  which is required for LiveTrackingSession visibility. The ShareConnection
//  record is saved first to ensure the zone is non-empty before creating
//  the zone-level share (CloudKit cannot generate URLs for empty zones).
//

import Foundation
import CloudKit
import os

// MARK: - Share Connection Service

actor ShareConnectionService {
    // MARK: State

    private var zoneID: CKRecordZone.ID?
    private var isZoneReady: Bool = false

    // CloudKit
    private let container: CKContainer
    private let zoneName: String

    // Cache of created connections
    private var connectionCache: [UUID: ShareConnection] = [:]

    // MARK: Initialization

    init(
        container: CKContainer = .default(),
        zoneName: String = "FamilySharing"
    ) {
        self.container = container
        self.zoneName = zoneName
    }

    // MARK: - Zone Setup

    /// Ensure the sharing zone exists and return the zone ID
    @discardableResult
    func ensureZoneReady() async throws -> CKRecordZone.ID {
        if isZoneReady, let existingZoneID = zoneID {
            return existingZoneID
        }

        let zone = CKRecordZone(zoneName: zoneName)
        zoneID = zone.zoneID

        do {
            let (savedZones, _) = try await container.privateCloudDatabase.modifyRecordZones(
                saving: [zone],
                deleting: []
            )

            // Use the actual zone ID from CloudKit response
            for (_, result) in savedZones {
                if case .success(let savedZone) = result {
                    zoneID = savedZone.zoneID
                    break
                }
            }

            isZoneReady = true
            Log.family.info("ShareConnectionService: Zone '\(self.zoneName)' ready")

            guard let finalZoneID = zoneID else {
                throw ShareConnectionError.zoneNotAvailable
            }
            return finalZoneID
        } catch let error as ShareConnectionError {
            throw error
        } catch {
            Log.family.error("ShareConnectionService: Failed to create zone: \(error)")
            throw ShareConnectionError.zoneNotAvailable
        }
    }

    /// Get the current zone ID (nil if zone not ready)
    func getZoneID() -> CKRecordZone.ID? {
        zoneID
    }

    // MARK: - Create Share Connection

    /// Create a ShareConnection record with a zone-level CKShare.
    /// The record is saved first to ensure the zone is non-empty,
    /// then a zone-level share is created so ALL records in the zone
    /// (including LiveTrackingSession) are visible to accepted participants.
    ///
    /// - Parameters:
    ///   - relationshipID: The SharingRelationship this share is for
    ///   - shareType: Type of content being shared
    ///   - ownerUserID: CloudKit user ID of the share owner
    /// - Returns: ShareConnection with a valid share URL
    func createShareConnection(
        for relationshipID: UUID,
        shareType: ShareType,
        ownerUserID: String
    ) async throws -> ShareConnection {
        // Validate permission: verify the caller is the actual CloudKit user
        do {
            let userRecordID = try await container.userRecordID()
            let actualUserID = userRecordID.recordName
            guard actualUserID == ownerUserID else {
                Log.family.error("Permission denied: ownerUserID \(ownerUserID) doesn't match actual user \(actualUserID)")
                throw ShareConnectionError.notSignedIn
            }
        } catch let error as ShareConnectionError {
            throw error
        } catch {
            Log.family.error("Failed to verify user identity: \(error)")
            throw ShareConnectionError.notSignedIn
        }

        try await ensureZoneReady()

        guard let zoneID = zoneID else {
            throw ShareConnectionError.zoneNotAvailable
        }

        // Clean up any stale ShareConnection records for this relationship
        // from previous failed attempts or old app versions
        await cleanupStaleConnections(for: relationshipID, zoneID: zoneID)

        // 1. Save the ShareConnection record FIRST (without CKShare).
        // This ensures the zone is non-empty before creating a zone-level share,
        // which avoids the empty-zone URL generation bug.
        var connection = ShareConnection(
            relationshipID: relationshipID,
            shareType: shareType,
            ownerUserID: ownerUserID
        )
        let connectionRecord = connection.toCKRecord(zoneID: zoneID)

        do {
            let savedRecord = try await container.privateCloudDatabase.save(connectionRecord)
            connection.cloudKitRecordID = savedRecord.recordID.recordName
            Log.family.info("ShareConnection record saved (pre-share)")
        } catch {
            Log.family.error("Failed to save ShareConnection record: \(error)")
            throw ShareConnectionError.shareCreationFailed(underlying: error)
        }

        // 2. Create or reuse a ZONE-LEVEL share.
        // Zone-level shares expose ALL records in the zone to participants,
        // which is required for LiveTrackingSession visibility.
        let share = try await getOrCreateZoneShare(zoneID: zoneID, shareType: shareType)
        connection.shareURL = share.url
        connection.shareRecordID = share.recordID.recordName

        // Cache the connection
        connectionCache[relationshipID] = connection

        guard connection.shareURL != nil else {
            throw ShareConnectionError.shareCreationFailed(
                underlying: NSError(
                    domain: "ShareConnectionService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Share saved but no URL generated. This can happen if iCloud Drive is disabled."]
                )
            )
        }

        Log.family.info("Zone-level ShareConnection created successfully for relationship \(relationshipID)")
        return connection
    }

    /// Get or create a zone-level share, handling migration from record-level shares.
    /// If an existing zone-level share is found with a valid URL, it's reused.
    /// If creation fails (e.g. due to old record-level shares), cleans up all shares
    /// in the zone and retries once.
    private func getOrCreateZoneShare(
        zoneID: CKRecordZone.ID,
        shareType: ShareType
    ) async throws -> CKShare {
        // First, try to fetch an existing zone-level share
        if let existingShare = try? await fetchExistingZoneShare(zoneID: zoneID) {
            if let url = existingShare.url {
                Log.family.info("Reusing existing zone share with URL: \(url.absoluteString)")
                return existingShare
            }

            // Stale share with no URL - delete it and create fresh
            Log.family.warning("Found stale zone share with nil URL, deleting...")
            do {
                try await container.privateCloudDatabase.deleteRecord(withID: existingShare.recordID)
                Log.family.info("Deleted stale zone share")
            } catch {
                Log.family.warning("Failed to delete stale share: \(error.localizedDescription), proceeding anyway")
            }
        }

        // Create a new zone-level share
        let share = CKShare(recordZoneID: zoneID)
        share.publicPermission = .readOnly
        share[CKShare.SystemFieldKey.title] = "TetraTrack Family Sharing" as CKRecordValue
        share[CKShare.SystemFieldKey.shareType] = shareType.rawValue as CKRecordValue
        Log.family.info("Creating new zone-level share")

        do {
            let saved = try await container.privateCloudDatabase.save(share)
            guard let savedShare = saved as? CKShare else {
                throw ShareConnectionError.shareCreationFailed(
                    underlying: NSError(
                        domain: "ShareConnectionService",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Save returned non-CKShare record"]
                    )
                )
            }
            Log.family.info("Zone share saved. URL: \(savedShare.url?.absoluteString ?? "nil")")
            return savedShare
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Zone-level share already exists (race condition or stale delete failed)
            Log.family.warning("Zone share conflict, retrying fetch...")
            if let existingShare = try await fetchExistingZoneShare(zoneID: zoneID) {
                Log.family.info("Retrieved existing zone share on retry. URL: \(existingShare.url?.absoluteString ?? "nil")")
                return existingShare
            }
            throw ShareConnectionError.shareCreationFailed(underlying: error)
        } catch {
            // Creation failed — likely due to existing record-level shares from
            // the old implementation blocking zone-level share creation.
            // Clean up ALL shares in the zone and retry once.
            Log.family.warning("Zone share creation failed, cleaning up old shares for migration: \(error)")
            await cleanupAllShares(zoneID: zoneID)

            let retryShare = CKShare(recordZoneID: zoneID)
            retryShare.publicPermission = .readOnly
            retryShare[CKShare.SystemFieldKey.title] = "TetraTrack Family Sharing" as CKRecordValue
            retryShare[CKShare.SystemFieldKey.shareType] = shareType.rawValue as CKRecordValue

            let saved = try await container.privateCloudDatabase.save(retryShare)
            guard let savedShare = saved as? CKShare else {
                throw ShareConnectionError.shareCreationFailed(
                    underlying: NSError(
                        domain: "ShareConnectionService",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "Retry save returned non-CKShare record"]
                    )
                )
            }
            Log.family.info("Zone share saved after migration cleanup. URL: \(savedShare.url?.absoluteString ?? "nil")")
            return savedShare
        }
    }

    /// Fetch an existing zone-level share for a zone
    private func fetchExistingZoneShare(zoneID: CKRecordZone.ID) async throws -> CKShare? {
        // Query for cloudkit.share records in the zone
        let query = CKQuery(recordType: "cloudkit.share", predicate: NSPredicate(value: true))

        do {
            let (results, _) = try await container.privateCloudDatabase.records(
                matching: query,
                inZoneWith: zoneID,
                resultsLimit: 1
            )

            for (_, result) in results {
                if case .success(let record) = result {
                    if let share = record as? CKShare {
                        return share
                    }
                }
            }
            return nil
        } catch let error as CKError where error.code == .unknownItem {
            // No shares exist, which is fine
            return nil
        } catch {
            // Query might fail if no shares exist - that's OK
            Log.family.debug("Zone share query returned error (may be normal): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Cleanup Helpers

    /// Delete ALL CKShare records in the zone (both zone-level and record-level).
    /// Used for one-time migration from record-level to zone-level shares.
    private func cleanupAllShares(zoneID: CKRecordZone.ID) async {
        let query = CKQuery(recordType: "cloudkit.share", predicate: NSPredicate(value: true))
        do {
            let (results, _) = try await container.privateCloudDatabase.records(
                matching: query, inZoneWith: zoneID
            )
            let ids = results.compactMap { (id, result) -> CKRecord.ID? in
                if case .success = result { return id }
                return nil
            }
            guard !ids.isEmpty else { return }
            let (_, deleteResults) = try await container.privateCloudDatabase.modifyRecords(
                saving: [], deleting: ids
            )
            let failedCount = deleteResults.filter { if case .failure = $0.value { return true }; return false }.count
            if failedCount > 0 {
                Log.family.warning("Failed to delete \(failedCount) of \(ids.count) share(s) during migration cleanup")
            }
            Log.family.info("Cleaned up \(ids.count - failedCount) old share(s) for zone-level migration")
        } catch {
            Log.family.warning("Share cleanup query failed: \(error.localizedDescription)")
        }
    }

    /// Remove stale ShareConnection records for a relationship from previous failed attempts.
    /// This prevents "record already exists" conflicts during batch saves.
    private func cleanupStaleConnections(for relationshipID: UUID, zoneID: CKRecordZone.ID) async {
        let predicate = NSPredicate(format: "relationshipID == %@", relationshipID.uuidString)
        let query = CKQuery(recordType: ShareConnection.recordType, predicate: predicate)

        do {
            let (results, _) = try await container.privateCloudDatabase.records(
                matching: query,
                inZoneWith: zoneID
            )

            var recordsToDelete: [CKRecord.ID] = []
            for (recordID, result) in results {
                if case .success = result {
                    recordsToDelete.append(recordID)
                }
            }

            guard !recordsToDelete.isEmpty else { return }

            Log.family.info("Found \(recordsToDelete.count) stale ShareConnection record(s) for relationship \(relationshipID), cleaning up")

            let (_, deleteResults) = try await container.privateCloudDatabase.modifyRecords(
                saving: [],
                deleting: recordsToDelete
            )

            // Log any deletion failures (non-blocking)
            for (recordID, result) in deleteResults {
                if case .failure(let error) = result {
                    Log.family.warning("Failed to delete stale record \(recordID): \(error.localizedDescription)")
                }
            }

            Log.family.info("Stale ShareConnection cleanup complete")
        } catch {
            Log.family.debug("No stale connections to clean up: \(error.localizedDescription)")
        }
    }

    // MARK: - Fetch Existing Share Connection

    /// Fetch an existing ShareConnection for a relationship
    func fetchConnection(for relationshipID: UUID) async throws -> ShareConnection? {
        // Check cache first
        if let cached = connectionCache[relationshipID] {
            return cached
        }

        guard let zoneID = zoneID else {
            try await ensureZoneReady()
            guard let zoneID = self.zoneID else {
                throw ShareConnectionError.zoneNotAvailable
            }
            return try await fetchConnectionFromCloudKit(relationshipID: relationshipID, zoneID: zoneID)
        }

        return try await fetchConnectionFromCloudKit(relationshipID: relationshipID, zoneID: zoneID)
    }

    private func fetchConnectionFromCloudKit(
        relationshipID: UUID,
        zoneID: CKRecordZone.ID
    ) async throws -> ShareConnection? {
        let predicate = NSPredicate(format: "relationshipID == %@", relationshipID.uuidString)
        let query = CKQuery(recordType: ShareConnection.recordType, predicate: predicate)

        do {
            let (results, _) = try await container.privateCloudDatabase.records(
                matching: query,
                inZoneWith: zoneID
            )

            for (_, result) in results {
                if case .success(let record) = result {
                    if var connection = ShareConnection.from(record: record) {
                        // Try to get the share URL from the record's share reference
                        // (works for both record-level and zone-level shares)
                        if let shareRef = record.share {
                            do {
                                let shareRecord = try await container.privateCloudDatabase.record(for: shareRef.recordID)
                                if let share = shareRecord as? CKShare {
                                    connection.shareURL = share.url
                                    connection.shareRecordID = share.recordID.recordName
                                }
                            } catch {
                                Log.family.debug("Could not fetch share via record reference: \(error.localizedDescription)")
                            }
                        }

                        // Fallback: try explicit shareRecordID if we still don't have a URL
                        if connection.shareURL == nil, let shareRecordID = connection.shareRecordID {
                            let shareID = CKRecord.ID(recordName: shareRecordID, zoneID: zoneID)
                            do {
                                let shareRecord = try await container.privateCloudDatabase.record(for: shareID)
                                if let share = shareRecord as? CKShare {
                                    connection.shareURL = share.url
                                }
                            } catch {
                                Log.family.warning("Failed to fetch share for \(shareRecordID): \(error.localizedDescription)")
                            }
                        }

                        connectionCache[relationshipID] = connection
                        return connection
                    }
                }
            }
        } catch {
            Log.family.error("Failed to fetch connection: \(error)")
        }

        return nil
    }

    // MARK: - Get or Create Share Connection

    /// Get an existing share connection or create a new one
    /// Validates that existing connections still have valid shares
    func getOrCreateConnection(
        for relationshipID: UUID,
        shareType: ShareType,
        ownerUserID: String
    ) async throws -> ShareConnection {
        // Try to fetch existing
        if let existing = try await fetchConnection(for: relationshipID),
           existing.shareURL != nil {

            // Validate the share is still valid in CloudKit
            if let isValid = try? await validateShareExists(existing),
               isValid {
                return existing
            }

            // Share no longer valid - clear cache and create new
            Log.family.warning("Existing share for \(relationshipID) is no longer valid, creating new")
            connectionCache.removeValue(forKey: relationshipID)
        }

        // Create new
        return try await createShareConnection(
            for: relationshipID,
            shareType: shareType,
            ownerUserID: ownerUserID
        )
    }

    /// Validate that a share connection's CloudKit share still exists
    private func validateShareExists(_ connection: ShareConnection) async throws -> Bool {
        guard let shareRecordID = connection.shareRecordID,
              let zoneID = zoneID else {
            return false
        }

        let recordID = CKRecord.ID(recordName: shareRecordID, zoneID: zoneID)

        do {
            _ = try await container.privateCloudDatabase.record(for: recordID)
            return true
        } catch let error as CKError where error.code == .unknownItem {
            return false
        } catch {
            // Other errors - assume valid to avoid unnecessary regeneration
            Log.family.debug("Share validation error (assuming valid): \(error.localizedDescription)")
            return true
        }
    }

    // MARK: - Revoke Share Connection

    /// Revoke and delete a ShareConnection
    /// - Returns: true if successfully deleted, false if already deleted or doesn't exist
    @discardableResult
    func revokeConnection(for relationshipID: UUID) async throws -> Bool {
        // Ensure zone is ready first
        do {
            try await ensureZoneReady()
        } catch {
            // Zone not available - may already be deleted or never existed
            connectionCache.removeValue(forKey: relationshipID)
            Log.family.info("Zone not available during revoke - assuming already cleaned up")
            return false
        }

        guard let zoneID = zoneID else {
            connectionCache.removeValue(forKey: relationshipID)
            return false
        }

        // Find the connection
        guard let connection = try await fetchConnection(for: relationshipID),
              let recordID = connection.cloudKitRecordID else {
            // Already deleted or doesn't exist
            connectionCache.removeValue(forKey: relationshipID)
            Log.family.info("No connection found for \(relationshipID) - already deleted")
            return false
        }

        let ckRecordID = CKRecord.ID(recordName: recordID, zoneID: zoneID)

        do {
            // Delete the connection record (share is deleted automatically)
            _ = try await container.privateCloudDatabase.deleteRecord(withID: ckRecordID)
            connectionCache.removeValue(forKey: relationshipID)
            Log.family.info("Revoked share connection for relationship \(relationshipID)")
            return true
        } catch let error as CKError where error.code == .unknownItem {
            // Record doesn't exist - already deleted
            connectionCache.removeValue(forKey: relationshipID)
            Log.family.info("Connection record already deleted for \(relationshipID)")
            return false
        } catch {
            Log.family.error("Failed to revoke share connection: \(error)")
            throw error
        }
    }

    /// Verify that a connection has been fully deleted from CloudKit
    /// Use this before allowing recreation of a contact
    func verifyConnectionDeleted(for relationshipID: UUID) async -> Bool {
        guard let zoneID = zoneID else {
            // No zone = no connections
            return true
        }

        // Clear cache first to force fresh fetch
        connectionCache.removeValue(forKey: relationshipID)

        do {
            let connection = try await fetchConnectionFromCloudKit(relationshipID: relationshipID, zoneID: zoneID)
            return connection == nil
        } catch {
            // Error fetching = assume deleted
            Log.family.debug("Verify connection deleted query error (assuming deleted): \(error.localizedDescription)")
            return true
        }
    }

    // MARK: - Share Metadata

    /// Fetch share metadata from a URL WITHOUT accepting it
    /// Used to get owner info for displaying pending requests
    func fetchShareMetadata(from url: URL) async throws -> (ownerID: String, ownerName: String) {
        do {
            let metadata = try await container.shareMetadata(for: url)

            // Extract owner info from metadata
            let ownerIdentity = metadata.ownerIdentity

            // Use deterministic ID based on URL if userRecordID is unavailable
            // This ensures duplicate detection works even without CloudKit identity
            let ownerID: String
            if let recordName = ownerIdentity.userRecordID?.recordName {
                ownerID = recordName
            } else {
                // Use a hash of the share URL as a stable identifier
                ownerID = "share-\(url.absoluteString.hashValue)"
                Log.family.warning("Owner identity unavailable, using URL-based ID")
            }

            let ownerName = ownerIdentity.nameComponents?.formatted() ?? "Unknown User"

            Log.family.info("Fetched share metadata from \(ownerName) (not accepting yet)")
            return (ownerID, ownerName)

        } catch {
            Log.family.error("Failed to fetch share metadata: \(error)")
            throw ShareConnectionError.shareCreationFailed(underlying: error)
        }
    }

    // MARK: - Accept Share

    /// Accept a share from a URL
    func acceptShare(from url: URL) async throws -> (ownerID: String, ownerName: String) {
        do {
            let metadata = try await container.shareMetadata(for: url)
            let acceptedShare = try await container.accept(metadata)

            let ownerIdentity = acceptedShare.owner.userIdentity

            // Use deterministic ID - prefer real ID, fallback to URL-based
            let ownerID: String
            if let recordName = ownerIdentity.userRecordID?.recordName {
                ownerID = recordName
            } else {
                ownerID = "share-\(url.absoluteString.hashValue)"
                Log.family.warning("Owner identity unavailable after accept, using URL-based ID")
            }

            let ownerName = ownerIdentity.nameComponents?.formatted() ?? "Unknown User"

            Log.family.info("Accepted share from \(ownerName)")
            return (ownerID, ownerName)

        } catch {
            Log.family.error("Failed to accept share: \(error)")
            throw ShareConnectionError.shareCreationFailed(underlying: error)
        }
    }

    // MARK: - Check if URL is CloudKit Share

    nonisolated func isCloudKitShareURL(_ url: URL) -> Bool {
        // CloudKit share URLs can come in several formats:
        // 1. cloudkit:// scheme (direct CloudKit URL)
        // 2. https://www.icloud.com/share/... (web share URL)
        // 3. cloudkit-iCloud.dev.dreamfold.TetraTrack:// (app-specific URL scheme)
        let scheme = url.scheme?.lowercased() ?? ""
        let host = url.host?.lowercased() ?? ""

        return scheme == "cloudkit" ||
               scheme.hasPrefix("cloudkit-") ||
               host.contains("icloud.com") ||
               host.contains("icloud-content.com")
    }

    // MARK: - Check Share Acceptance Status

    /// Check if the zone share has any accepted non-owner participants.
    /// Does not rely on userIdentity.userRecordID, which CloudKit often leaves nil
    /// for zone-level shares fetched via query.
    func hasAnyAcceptedParticipants() async -> Bool {
        guard let zoneID = zoneID else { return false }

        do {
            guard let share = try await fetchExistingZoneShare(zoneID: zoneID) else {
                return false
            }

            let accepted = share.participants.contains {
                $0.role != .owner && $0.acceptanceStatus == .accepted
            }

            if accepted {
                Log.family.debug("Zone share has at least one accepted participant")
            }

            return accepted
        } catch {
            Log.family.debug("Failed to check share acceptance: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Cache Management

    /// Clear the connection cache
    func clearCache() {
        connectionCache.removeAll()
    }

    /// Get cached connection (for synchronous access)
    func getCachedConnection(for relationshipID: UUID) -> ShareConnection? {
        connectionCache[relationshipID]
    }

    /// Full reset: clear all in-memory state so the service starts fresh.
    /// Call this after deleting the FamilySharing zone.
    func resetState() {
        connectionCache.removeAll()
        zoneID = nil
        isZoneReady = false
        Log.family.info("ShareConnectionService: State reset")
    }
}
