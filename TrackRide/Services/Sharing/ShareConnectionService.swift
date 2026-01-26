//
//  ShareConnectionService.swift
//  TrackRide
//
//  Actor-based service for creating record-level CloudKit shares.
//  This is the CRITICAL FIX: uses record-level shares instead of zone-wide shares.
//
//  The previous implementation used CKShare(recordZoneID:) which creates a zone-wide
//  share. However, CloudKit cannot generate valid share URLs for empty zones.
//  This service creates a ShareConnection record first, then attaches a CKShare to it.
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
            for (zoneIDKey, result) in savedZones {
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

    // MARK: - Create Share Connection (Critical Fix)

    /// Create a ShareConnection record with an attached CKShare.
    /// This is the fix for the empty zone share URL bug.
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

        // 1. Create the ShareConnection record FIRST
        // This ensures the zone is not empty before creating the zone-level share
        var connection = ShareConnection(
            relationshipID: relationshipID,
            shareType: shareType,
            ownerUserID: ownerUserID
        )
        let connectionRecord = connection.toCKRecord(zoneID: zoneID)

        // Save the connection record first to ensure zone is not empty
        do {
            _ = try await container.privateCloudDatabase.save(connectionRecord)
            connection.cloudKitRecordID = connectionRecord.recordID.recordName
            Log.family.info("ShareConnection record created in zone")
        } catch {
            Log.family.error("Failed to save ShareConnection record: \(error)")
            throw ShareConnectionError.shareCreationFailed(underlying: error)
        }

        // 2. Get or create a ZONE-LEVEL share
        // This shares ALL records in the FamilySharing zone, including:
        // - LiveTrackingSession records
        // - SafetyAlert records
        // - ShareConnection records
        //
        // IMPORTANT: A zone can only have one zone-level share, so we must
        // check if one already exists and re-use it.

        var share: CKShare
        var existingShareURL: URL?

        // First, try to fetch an existing zone-level share
        do {
            let existingShare = try await fetchExistingZoneShare(zoneID: zoneID)
            if let existingShare = existingShare {
                share = existingShare
                existingShareURL = existingShare.url
                Log.family.info("Found existing zone-level share. URL: \(existingShareURL?.absoluteString ?? "nil")")
            } else {
                // No existing share, create a new one
                share = CKShare(recordZoneID: zoneID)
                share.publicPermission = .readOnly
                share[CKShare.SystemFieldKey.title] = "TetraTrack Family Sharing" as CKRecordValue
                share[CKShare.SystemFieldKey.shareType] = shareType.rawValue as CKRecordValue
                Log.family.info("Creating new zone-level share")
            }
        } catch {
            // Error fetching, try creating new share
            Log.family.warning("Could not fetch existing share, creating new: \(error.localizedDescription)")
            share = CKShare(recordZoneID: zoneID)
            share.publicPermission = .readOnly
            share[CKShare.SystemFieldKey.title] = "TetraTrack Family Sharing" as CKRecordValue
            share[CKShare.SystemFieldKey.shareType] = shareType.rawValue as CKRecordValue
        }

        // 3. Save the share (or re-save existing to get updated URL)
        do {
            let savedShare: CKShare
            if existingShareURL != nil {
                // Existing share - just use it
                savedShare = share
            } else {
                // New share - save it
                do {
                    savedShare = try await container.privateCloudDatabase.save(share) as! CKShare
                } catch let error as CKError where error.code == .serverRecordChanged {
                    // Zone-level share already exists (race condition or query failed to find it)
                    // Retry fetching the existing share
                    Log.family.warning("Zone share already exists, retrying fetch...")
                    if let existingShare = try await fetchExistingZoneShare(zoneID: zoneID) {
                        savedShare = existingShare
                        Log.family.info("Successfully retrieved existing zone share on retry")
                    } else {
                        throw ShareConnectionError.shareCreationFailed(underlying: error)
                    }
                }
            }

            connection.shareRecordID = savedShare.recordID.recordName
            connection.shareURL = savedShare.url
            Log.family.info("Zone-level share ready. URL: \(savedShare.url?.absoluteString ?? "nil")")

            // Update the connection record with share info
            connectionRecord["shareRecordID"] = connection.shareRecordID
            _ = try? await container.privateCloudDatabase.save(connectionRecord)

            // Cache the connection
            connectionCache[relationshipID] = connection

            guard connection.shareURL != nil else {
                throw ShareConnectionError.shareCreationFailed(
                    underlying: NSError(
                        domain: "ShareConnectionService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Share saved but no URL generated"]
                    )
                )
            }

            Log.family.info("Zone-level ShareConnection created successfully for relationship \(relationshipID)")
            return connection

        } catch let error as ShareConnectionError {
            throw error
        } catch {
            Log.family.error("Failed to create zone-level share: \(error)")
            throw ShareConnectionError.shareCreationFailed(underlying: error)
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
                        // Try to get the share URL from the associated share
                        if let shareRecordID = connection.shareRecordID {
                            let shareID = CKRecord.ID(recordName: shareRecordID, zoneID: zoneID)
                            do {
                                let shareRecord = try await container.privateCloudDatabase.record(for: shareID)
                                if let share = shareRecord as? CKShare {
                                    connection.shareURL = share.url
                                } else {
                                    Log.family.warning("Share record exists but is not a CKShare: \(shareRecordID)")
                                }
                            } catch {
                                Log.family.warning("Failed to fetch share metadata for \(shareRecordID): \(error.localizedDescription)")
                                // Connection is still valid, just without a cached URL
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
        if var existing = try await fetchConnection(for: relationshipID),
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
        // 3. cloudkit-iCloud.MyHorse.TrackRide:// (app-specific URL scheme)
        let scheme = url.scheme?.lowercased() ?? ""
        let host = url.host?.lowercased() ?? ""

        return scheme == "cloudkit" ||
               scheme.hasPrefix("cloudkit-") ||
               host.contains("icloud.com") ||
               host.contains("icloud-content.com")
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
}
