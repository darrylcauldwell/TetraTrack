//
//  UnifiedSharingCoordinator.swift
//  TetraTrack
//
//  Main @Observable facade for the unified sharing system.
//  Coordinates CloudKit account, share connections, live tracking, safety alerts,
//  and artifact sharing through a single interface.
//

import Foundation
import CloudKit
import CoreLocation
import SwiftData
import Observation
import os

// MARK: - Unified Sharing Coordinator

@Observable
@MainActor
final class UnifiedSharingCoordinator {
    static let shared = UnifiedSharingCoordinator()

    // MARK: - Published State

    /// Whether iCloud is signed in and available
    private(set) var isSignedIn: Bool = false

    /// Whether CloudKit is available
    private(set) var isCloudKitAvailable: Bool = false

    /// Current user's CloudKit ID
    private(set) var currentUserID: String = ""

    /// Current user's display name
    private(set) var currentUserName: String = ""

    /// My current live tracking session (if sharing)
    private(set) var mySession: LiveTrackingSession?

    /// Live sessions shared by family members
    private(set) var sharedWithMe: [LiveTrackingSession] = []

    /// Linked riders (people who share with you)
    private(set) var linkedRiders: [LinkedRider] = []

    /// Setup completion status
    private(set) var isSetupComplete: Bool = false

    /// Current error message (if any)
    private(set) var errorMessage: String?

    /// Whether location updates are failing (for UI indication)
    private(set) var hasLocationUpdateError: Bool = false

    /// Detailed description of current location error (for UI display)
    private(set) var locationErrorDescription: String?

    /// When location errors started (for staleness indication)
    private(set) var locationErrorStartTime: Date?

    /// Count of consecutive location update failures
    private var consecutiveUpdateFailures: Int = 0

    /// Threshold for showing error indication (2 consecutive failures = 20 seconds)
    private let errorThreshold = 2

    /// Whether the last artifacts fetch was truncated due to pagination limits
    private(set) var artifactsFetchTruncated: Bool = false

    /// Whether the last competitions fetch was truncated due to pagination limits
    private(set) var competitionsFetchTruncated: Bool = false

    /// Whether the refresh loop has stopped due to repeated errors
    /// When true, UI should show a warning and offer manual refresh
    private(set) var refreshLoopStopped: Bool = false

    // MARK: - Services (Actor-based)

    private let accountService: CloudKitAccountService
    private let shareConnectionService: ShareConnectionService
    private let liveTrackingService: LiveTrackingService
    private let safetyAlertService: SafetyAlertService
    private let artifactShareService: ArtifactShareService

    // MARK: - Repository

    private(set) var repository: SharingRelationshipRepository?

    // MARK: - CloudKit Zone

    private let zoneName = "FamilySharing"
    private var zoneID: CKRecordZone.ID?

    // MARK: - Centralized Refresh Timer

    /// Number of views actively watching for location updates
    private var activeWatcherCount: Int = 0

    /// Task for the refresh loop (cancellable)
    private var refreshTask: Task<Void, Never>?

    /// Refresh interval in seconds
    private let refreshInterval: TimeInterval = 10

    // MARK: - Share Link Rate Limiting

    /// Tracks last share link generation time per relationship ID
    private var lastShareLinkGeneration: [UUID: Date] = [:]

    /// Minimum interval between share link regenerations (60 seconds)
    private let shareLinkRateLimitInterval: TimeInterval = 60

    // MARK: - Initialization

    private init() {
        let container = CKContainer.default()
        self.accountService = CloudKitAccountService()
        self.shareConnectionService = ShareConnectionService(container: container, zoneName: zoneName)
        self.liveTrackingService = LiveTrackingService(container: container, zoneName: zoneName)
        self.safetyAlertService = SafetyAlertService()
        self.artifactShareService = ArtifactShareService(container: container, zoneName: zoneName)
    }

    // MARK: - Configuration

    /// Configure with ModelContext for SwiftData access
    func configure(with context: ModelContext) {
        let repo = SharingRelationshipRepository()
        repo.configure(with: context)
        self.repository = repo

        // Run migration if needed
        Task {
            do {
                try repository?.migrateFromUserDefaults()
            } catch {
                Log.family.error("Migration failed: \(error)")
            }
        }
    }

    // MARK: - Setup

    /// Initialize the sharing system
    func setup() async {
        Log.family.info("UnifiedSharingCoordinator: Starting setup...")

        // Check account status
        let signedIn = await accountService.checkAccountStatus()
        let userID = await accountService.currentUserID
        let userName = await accountService.currentUserName
        let available = await accountService.isAvailable

        await MainActor.run {
            self.isSignedIn = signedIn
            self.isCloudKitAvailable = available
            self.currentUserID = userID
            self.currentUserName = userName
        }

        guard isSignedIn else {
            isSetupComplete = true
            Log.family.info("UnifiedSharingCoordinator: Not signed in, setup complete")
            return
        }

        // Load persisted linked riders first
        loadLinkedRiders()

        // Setup zone - use the actual zone ID from CloudKit
        do {
            let actualZoneID = try await shareConnectionService.ensureZoneReady()
            zoneID = actualZoneID

            // Configure services with the actual CloudKit zone
            await liveTrackingService.configure(userID: currentUserID, zoneID: actualZoneID)
            await artifactShareService.configure(zoneID: actualZoneID)

            // Auto-refresh linked rider statuses on launch
            if !linkedRiders.isEmpty {
                Log.family.info("Auto-refreshing \(self.linkedRiders.count) linked riders...")
                await fetchFamilyLocations()
            }
        } catch {
            Log.family.error("Failed to setup zone: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to setup CloudKit zone"
            }
        }

        isSetupComplete = true
        Log.family.info("UnifiedSharingCoordinator: Setup complete")
    }

    // MARK: - Relationship Management

    /// Get all sharing relationships
    func fetchRelationships() throws -> [SharingRelationship] {
        try repository?.fetchAll() ?? []
    }

    /// Get relationships by type
    func fetchRelationships(type: RelationshipType) throws -> [SharingRelationship] {
        try repository?.fetch(type: type) ?? []
    }

    /// Get family members (contacts with safety permissions)
    func fetchFamilyMembers() throws -> [SharingRelationship] {
        try repository?.fetchFamilyMembers() ?? []
    }

    /// Get emergency contacts
    func fetchEmergencyContacts() throws -> [SharingRelationship] {
        try repository?.fetchEmergencyContacts() ?? []
    }

    /// Create a new relationship
    func createRelationship(
        name: String,
        type: RelationshipType,
        email: String? = nil,
        phoneNumber: String? = nil,
        preset: PermissionPreset? = nil
    ) -> SharingRelationship? {
        repository?.create(
            name: name,
            type: type,
            email: email,
            phoneNumber: phoneNumber,
            preset: preset
        )
    }

    /// Check and update invite statuses based on share acceptance
    /// Called periodically to detect when someone has accepted a share
    func updateInviteStatuses() async {
        guard let repository = repository else { return }

        // Get accepted participant IDs from CloudKit share
        let acceptedIDs = await shareConnectionService.checkShareAcceptance()

        guard !acceptedIDs.isEmpty else { return }

        Log.family.info("Found \(acceptedIDs.count) accepted participants, updating invite statuses")

        // Update relationships where the linked rider has accepted
        do {
            let relationships = try repository.fetchAll()
            var updatedCount = 0

            for relationship in relationships {
                // Only update pending invites
                guard relationship.inviteStatus == .pending else { continue }

                // Check if this relationship's connection corresponds to an accepted participant
                // We need to check if any of our linked riders match the accepted participants
                // The linked riders are people who accepted our shares

                // For now, if we have ANY accepted participants and the relationship is pending,
                // mark it as accepted (since we use zone-level sharing)
                relationship.inviteStatus = .accepted
                repository.update(relationship)
                updatedCount += 1
                Log.family.info("Updated invite status to accepted for \(relationship.name)")
            }

            if updatedCount > 0 {
                Log.family.info("Updated \(updatedCount) invite statuses to accepted")
            }
        } catch {
            Log.family.error("Failed to update invite statuses: \(error)")
        }
    }

    /// Delete a relationship
    func deleteRelationship(_ relationship: SharingRelationship) async {
        let relationshipID = relationship.id

        // Revoke live tracking share connection first (critical for security)
        do {
            _ = try await shareConnectionService.revokeConnection(for: relationshipID)
            Log.family.info("Revoked ShareConnection for deleted relationship")
        } catch {
            Log.family.error("Failed to revoke ShareConnection: \(error)")
            // Continue with deletion even if revocation fails
        }

        // Verify the CloudKit record was actually deleted
        // This prevents "record already exists" errors when recreating contacts
        let maxVerifyAttempts = 3
        for attempt in 1...maxVerifyAttempts {
            let isDeleted = await shareConnectionService.verifyConnectionDeleted(for: relationshipID)
            if isDeleted {
                Log.family.info("Verified ShareConnection deleted after \(attempt) attempt(s)")
                break
            }

            if attempt < maxVerifyAttempts {
                // Wait briefly and retry
                Log.family.warning("ShareConnection not yet deleted, retrying verification (attempt \(attempt))")
                try? await Task.sleep(for: .milliseconds(500))
            } else {
                Log.family.error("ShareConnection may not be fully deleted - could cause issues on recreation")
            }
        }

        // Revoke artifact shares
        await artifactShareService.revokeAllShares(with: relationshipID)

        // Delete from repository
        repository?.delete(relationship)
    }

    // MARK: - Share Link Generation (Critical Fix)

    /// Generate a share link for a relationship.
    /// This uses record-level shares instead of zone-wide shares.
    /// Rate limited to prevent excessive CloudKit API calls.
    func generateShareLink(for relationship: SharingRelationship) async -> URL? {
        // If not signed in, try refreshing account status first
        // This handles cases where setup() hasn't run or completed yet
        if !isSignedIn {
            Log.family.info("isSignedIn is false, refreshing account status...")
            let signedIn = await accountService.checkAccountStatus()
            let userID = await accountService.currentUserID
            self.isSignedIn = signedIn
            self.currentUserID = userID

            guard signedIn else {
                errorMessage = "Please sign in to iCloud to share"
                Log.family.error("Account status refresh failed - still not signed in")
                return nil
            }
            Log.family.info("Account status refreshed - now signed in")
        }

        // Rate limiting: check if we recently generated a link for this relationship
        // But don't return stale URLs (older than 24 hours should be regenerated)
        let maxCacheAge: TimeInterval = 24 * 60 * 60  // 24 hours

        if let lastGeneration = lastShareLinkGeneration[relationship.id] {
            let timeSinceLastGeneration = Date().timeIntervalSince(lastGeneration)

            // Only use cached URL if within rate limit window AND not too stale
            if timeSinceLastGeneration < shareLinkRateLimitInterval {
                if let existingURL = relationship.shareURLValue,
                   let inviteSentDate = relationship.inviteSentDate,
                   Date().timeIntervalSince(inviteSentDate) < maxCacheAge {
                    Log.family.debug("Rate limited: returning existing share URL (generated \(Int(timeSinceLastGeneration))s ago)")
                    return existingURL
                } else if relationship.shareURLValue != nil {
                    Log.family.debug("Cached URL is stale (>24h), regenerating")
                }
            }
        }

        do {
            Log.family.info("Creating share connection for relationship \(relationship.id), userID: \(self.currentUserID)")
            let connection = try await shareConnectionService.getOrCreateConnection(
                for: relationship.id,
                shareType: .liveTracking,
                ownerUserID: currentUserID
            )

            // Update relationship with connection info
            relationship.connectionRecordID = connection.cloudKitRecordID
            relationship.shareURLValue = connection.shareURL
            relationship.inviteStatus = .pending
            relationship.inviteSentDate = Date()

            // CRITICAL: Save to SwiftData so share URL persists across app restarts
            repository?.update(relationship)

            // Track generation time for rate limiting
            lastShareLinkGeneration[relationship.id] = Date()

            // Verify we got a valid share URL
            guard let shareURL = connection.shareURL else {
                Log.family.error("Share connection created but shareURL is nil")
                errorMessage = "Share was created but no URL was generated. Please try again."
                return nil
            }

            Log.family.info("Share link generated successfully: \(shareURL.absoluteString)")
            return shareURL

        } catch let error as ShareConnectionError {
            Log.family.error("ShareConnectionError: \(error)")
            switch error {
            case .notSignedIn:
                errorMessage = "iCloud authentication failed. Please sign out and back into iCloud in Settings."
            case .zoneNotAvailable:
                errorMessage = "Could not access iCloud storage. Please check your iCloud Drive is enabled."
            case .shareCreationFailed(let underlying):
                Log.family.error("Share creation underlying error: \(underlying)")
                errorMessage = "Failed to create share: \(underlying.localizedDescription)"
            case .shareNotFound:
                errorMessage = "Share not found. Please try again."
            case .recordNotFound:
                errorMessage = "Record not found in iCloud."
            case .invalidShareURL:
                errorMessage = "Invalid share URL generated."
            case .permissionDenied:
                errorMessage = "Permission denied. Please check your iCloud settings."
            }
            return nil
        } catch {
            Log.family.error("Failed to generate share link: \(error)")
            errorMessage = "Failed to generate share link: \(error.localizedDescription)"
            return nil
        }
    }

    /// Accept a share from a URL
    func acceptShare(from url: URL) async -> Bool {
        do {
            let (ownerID, ownerName) = try await shareConnectionService.acceptShare(from: url)

            // Add as linked rider
            addLinkedRider(riderID: ownerID, name: ownerName)

            // CRITICAL: Refresh CloudKit subscriptions for the newly shared zone
            // Without this, we won't receive push notifications for the new family member's alerts
            await NotificationManager.shared.setupCloudKitSubscriptions()
            Log.family.info("Refreshed CloudKit subscriptions after accepting share")

            // Fetch locations to populate status
            await fetchFamilyLocations()

            return true
        } catch {
            Log.family.error("Failed to accept share: \(error)")
            errorMessage = "Failed to accept share"
            return false
        }
    }

    /// Check if URL is a CloudKit share URL
    func isCloudKitShareURL(_ url: URL) -> Bool {
        shareConnectionService.isCloudKitShareURL(url)
    }

    // MARK: - Live Location Sharing

    /// Start sharing location
    func startSharingLocation(activityType: String = "riding") async {
        guard isSignedIn else { return }

        do {
            let session = try await liveTrackingService.startSharingLocation(riderName: currentUserName, activityType: activityType)
            await MainActor.run {
                self.mySession = session
            }
        } catch {
            Log.family.error("Failed to start sharing: \(error)")
            errorMessage = "Failed to start location sharing"
        }
    }

    /// Update shared location
    func updateSharedLocation(
        location: CLLocation,
        gait: GaitType,
        distance: Double,
        duration: TimeInterval
    ) async {
        do {
            try await liveTrackingService.updateSharedLocation(
                location: location,
                gait: gait,
                distance: distance,
                duration: duration
            )
            // Reset error state on success
            if consecutiveUpdateFailures > 0 {
                consecutiveUpdateFailures = 0
                hasLocationUpdateError = false
                locationErrorDescription = nil
                locationErrorStartTime = nil
                Log.family.info("Location update succeeded, error state cleared")
            }
        } catch {
            consecutiveUpdateFailures += 1
            Log.family.error("Location update failed (\(self.consecutiveUpdateFailures)/\(self.errorThreshold)): \(error)")

            // Show error indication after threshold consecutive failures
            if consecutiveUpdateFailures >= errorThreshold && !hasLocationUpdateError {
                hasLocationUpdateError = true
                locationErrorStartTime = Date()

                // Set user-friendly error description
                if let ckError = error as? CKError {
                    switch ckError.code {
                    case .networkUnavailable, .networkFailure:
                        locationErrorDescription = "No internet connection"
                    case .quotaExceeded:
                        locationErrorDescription = "iCloud storage full"
                    case .notAuthenticated:
                        locationErrorDescription = "Please sign in to iCloud"
                    default:
                        locationErrorDescription = "Unable to update location"
                    }
                } else {
                    locationErrorDescription = "Unable to update location"
                }

                Log.family.warning("Location updates failing - showing error indication to user")
            }
        }
    }

    /// Stop sharing location
    func stopSharingLocation() async {
        do {
            try await liveTrackingService.stopSharingLocation()
        } catch {
            Log.family.error("Failed to stop sharing: \(error)")
        }
        await MainActor.run {
            self.mySession = nil
            // Clear error state when stopping
            self.consecutiveUpdateFailures = 0
            self.hasLocationUpdateError = false
            self.locationErrorDescription = nil
            self.locationErrorStartTime = nil
        }
    }

    /// Fetch family member locations
    /// - Returns: true if fetch succeeded, false if it failed
    @discardableResult
    func fetchFamilyLocations() async -> Bool {
        let (sessions, fetchError) = await liveTrackingService.fetchFamilyLocationsWithError()

        // Track fetch failures for the refresh loop
        if let error = fetchError {
            Log.family.warning("Location fetch failed: \(error.localizedDescription)")
            return false
        }

        await MainActor.run {
            // Build a lookup dictionary for O(1) session access
            let sessionsByRiderID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.riderID, $0) })

            // Create updated riders array (copy-on-write safe)
            var updatedRiders = linkedRiders.map { rider -> LinkedRider in
                var updated = rider
                if let session = sessionsByRiderID[rider.riderID] {
                    updated.isCurrentlyRiding = session.isActive
                    updated.currentSession = session
                } else {
                    updated.isCurrentlyRiding = false
                    updated.currentSession = nil
                }
                return updated
            }

            // Add new riders discovered from shares
            let existingRiderIDs = Set(updatedRiders.map { $0.riderID })
            for session in sessions {
                if !existingRiderIDs.contains(session.riderID) {
                    var newRider = LinkedRider(riderID: session.riderID, name: session.riderName)
                    newRider.isCurrentlyRiding = session.isActive
                    newRider.currentSession = session
                    updatedRiders.append(newRider)
                }
            }

            // Atomic replacement of the array
            self.linkedRiders = updatedRiders
            self.sharedWithMe = sessions.filter { $0.isActive }

            // Save linked riders atomically with the update
            self.saveLinkedRiders()
        }

        // Check for safety alerts
        await safetyAlertService.checkSessions(sessions)

        return true
    }

    // MARK: - Linked Riders Management

    func addLinkedRider(riderID: String, name: String) {
        guard !linkedRiders.contains(where: { $0.riderID == riderID }) else { return }

        let rider = LinkedRider(riderID: riderID, name: name)
        linkedRiders.append(rider)
        saveLinkedRiderToSwiftData(rider)
    }

    func removeLinkedRider(id: UUID) {
        linkedRiders.removeAll { $0.id == id }
        deleteLinkedRiderFromSwiftData(id: id)
    }

    // MARK: - LinkedRider SwiftData Persistence

    private let linkedRidersUserDefaultsKey = "linkedRiders"
    private let linkedRidersMigrationKey = "linkedRidersMigrationCompleted"

    /// Save a single linked rider to SwiftData
    private func saveLinkedRiderToSwiftData(_ rider: LinkedRider) {
        guard let context = repository?.modelContext else {
            Log.family.warning("Cannot save linked rider: ModelContext not available")
            return
        }

        // Check if record already exists
        let riderID = rider.riderID
        let predicate = #Predicate<LinkedRiderRecord> { $0.riderID == riderID }
        var descriptor = FetchDescriptor<LinkedRiderRecord>(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            let existing = try context.fetch(descriptor)
            if existing.isEmpty {
                // Create new record
                let record = LinkedRiderRecord(
                    id: rider.id,
                    riderID: rider.riderID,
                    name: rider.name
                )
                record.lastSeenDate = rider.lastSeenDate
                context.insert(record)
                try context.save()
                Log.family.info("Saved linked rider to SwiftData: \(rider.name)")
            } else {
                // Update existing
                existing.first?.name = rider.name
                existing.first?.lastSeenDate = rider.lastSeenDate
                try context.save()
            }
        } catch {
            Log.family.error("Failed to save linked rider to SwiftData: \(error)")
        }
    }

    /// Delete a linked rider from SwiftData
    private func deleteLinkedRiderFromSwiftData(id: UUID) {
        guard let context = repository?.modelContext else { return }

        let predicate = #Predicate<LinkedRiderRecord> { $0.id == id }
        var descriptor = FetchDescriptor<LinkedRiderRecord>(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            let records = try context.fetch(descriptor)
            for record in records {
                context.delete(record)
            }
            try context.save()
            Log.family.info("Deleted linked rider from SwiftData")
        } catch {
            Log.family.error("Failed to delete linked rider from SwiftData: \(error)")
        }
    }

    /// Load linked riders from SwiftData (with migration from UserDefaults)
    func loadLinkedRiders() {
        // First, try to migrate from UserDefaults if not done yet
        if !UserDefaults.standard.bool(forKey: linkedRidersMigrationKey) {
            migrateLinkedRidersFromUserDefaults()
        }

        // Load from SwiftData
        guard let context = repository?.modelContext else {
            // Fall back to UserDefaults if SwiftData not available
            loadLinkedRidersFromUserDefaults()
            return
        }

        do {
            let descriptor = FetchDescriptor<LinkedRiderRecord>(
                sortBy: [SortDescriptor(\.addedDate, order: .reverse)]
            )
            let records = try context.fetch(descriptor)
            linkedRiders = records.map { $0.toLinkedRider() }
            Log.family.info("Loaded \(self.linkedRiders.count) linked riders from SwiftData")
        } catch {
            Log.family.error("Failed to load linked riders from SwiftData: \(error)")
            // Fall back to UserDefaults
            loadLinkedRidersFromUserDefaults()
        }
    }

    /// Migrate linked riders from UserDefaults to SwiftData
    private func migrateLinkedRidersFromUserDefaults() {
        guard let context = repository?.modelContext else { return }
        guard let data = UserDefaults.standard.data(forKey: linkedRidersUserDefaultsKey) else {
            // No data to migrate, mark as complete
            UserDefaults.standard.set(true, forKey: linkedRidersMigrationKey)
            return
        }

        do {
            let legacyRiders = try JSONDecoder().decode([LinkedRider].self, from: data)

            for rider in legacyRiders {
                let record = LinkedRiderRecord(
                    id: rider.id,
                    riderID: rider.riderID,
                    name: rider.name
                )
                record.lastSeenDate = rider.lastSeenDate
                context.insert(record)
            }

            try context.save()

            // Mark migration as complete and clear UserDefaults
            UserDefaults.standard.set(true, forKey: linkedRidersMigrationKey)
            UserDefaults.standard.removeObject(forKey: linkedRidersUserDefaultsKey)
            Log.family.info("Migrated \(legacyRiders.count) linked riders from UserDefaults to SwiftData")
        } catch {
            Log.family.error("Failed to migrate linked riders: \(error)")
        }
    }

    /// Fallback: Load linked riders from UserDefaults (legacy)
    private func loadLinkedRidersFromUserDefaults() {
        guard let data = UserDefaults.standard.data(forKey: linkedRidersUserDefaultsKey) else {
            return
        }

        do {
            linkedRiders = try JSONDecoder().decode([LinkedRider].self, from: data)
            Log.family.info("Loaded \(self.linkedRiders.count) linked riders from UserDefaults (fallback)")
        } catch {
            Log.family.error("Failed to load linked riders from UserDefaults: \(error)")
            UserDefaults.standard.removeObject(forKey: linkedRidersUserDefaultsKey)
        }
    }

    /// Save linked riders to SwiftData (batch update, used by fetchFamilyLocations)
    private func saveLinkedRiders() {
        guard let context = repository?.modelContext else { return }

        for rider in linkedRiders {
            saveLinkedRiderToSwiftData(rider)
        }
    }

    // MARK: - Artifact Sharing

    /// Share an artifact with a relationship
    func shareArtifact(
        _ artifact: TrainingArtifact,
        with relationship: SharingRelationship,
        expiresIn: TimeInterval? = nil
    ) async throws -> ArtifactShare {
        try await artifactShareService.shareArtifact(
            artifact,
            with: relationship.id,
            expiresIn: expiresIn
        )
    }

    /// Revoke artifact share
    func revokeArtifactShare(_ share: ArtifactShare) async throws {
        try await artifactShareService.revokeShare(share)
    }

    /// Get shares for an artifact
    func shares(for artifactID: UUID) async -> [ArtifactShare] {
        await artifactShareService.shares(for: artifactID)
    }

    /// Cleanup expired shares
    func cleanupExpiredShares() async {
        await artifactShareService.cleanupExpiredShares()
    }

    // MARK: - Family Data Fetching

    /// Fetch training artifacts shared by family members
    /// Returns artifacts from CloudKit shared database
    func fetchFamilyArtifacts() async -> [TrainingArtifact] {
        guard isSignedIn, let zoneID = zoneID else { return [] }

        do {
            let database = CKContainer.default().sharedCloudDatabase
            let query = CKQuery(
                recordType: "TrainingArtifact",
                predicate: NSPredicate(value: true)
            )
            query.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]

            var allArtifacts: [TrainingArtifact] = []
            var cursor: CKQueryOperation.Cursor?
            let pageSize = 100
            let maxPages = 10  // Limit to 1000 total artifacts

            // Fetch first page
            let (results, firstCursor) = try await database.records(matching: query, resultsLimit: pageSize)
            cursor = firstCursor

            for (_, result) in results {
                if case .success(let record) = result {
                    let artifact = TrainingArtifact.from(record: record)
                    allArtifacts.append(artifact)
                }
            }

            // Fetch remaining pages if cursor exists
            var pageCount = 1
            while let currentCursor = cursor, pageCount < maxPages {
                let (pageResults, nextCursor) = try await database.records(
                    continuingMatchFrom: currentCursor,
                    resultsLimit: pageSize
                )
                cursor = nextCursor
                pageCount += 1

                for (_, result) in pageResults {
                    if case .success(let record) = result {
                        let artifact = TrainingArtifact.from(record: record)
                        allArtifacts.append(artifact)
                    }
                }
            }

            // Track if data was truncated for UI indication
            artifactsFetchTruncated = cursor != nil
            if artifactsFetchTruncated {
                Log.family.warning("Artifact pagination limit reached (\(allArtifacts.count) items) - some data not shown")
            }

            return allArtifacts
        } catch {
            Log.family.error("Failed to fetch family artifacts: \(error)")
            artifactsFetchTruncated = false
            return []
        }
    }

    /// Fetch competitions shared by family members
    /// Returns competitions from CloudKit shared database
    func fetchFamilyCompetitions() async -> [SharedCompetition] {
        guard isSignedIn, let zoneID = zoneID else { return [] }

        do {
            let database = CKContainer.default().sharedCloudDatabase
            let query = CKQuery(
                recordType: "SharedCompetition",
                predicate: NSPredicate(value: true)
            )
            query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

            var allCompetitions: [SharedCompetition] = []
            var cursor: CKQueryOperation.Cursor?
            let pageSize = 100
            let maxPages = 10  // Limit to 1000 total competitions

            // Fetch first page
            let (results, firstCursor) = try await database.records(matching: query, resultsLimit: pageSize)
            cursor = firstCursor

            for (_, result) in results {
                if case .success(let record) = result {
                    let competition = SharedCompetition.from(record: record)
                    allCompetitions.append(competition)
                }
            }

            // Fetch remaining pages if cursor exists
            var pageCount = 1
            while let currentCursor = cursor, pageCount < maxPages {
                let (pageResults, nextCursor) = try await database.records(
                    continuingMatchFrom: currentCursor,
                    resultsLimit: pageSize
                )
                cursor = nextCursor
                pageCount += 1

                for (_, result) in pageResults {
                    if case .success(let record) = result {
                        let competition = SharedCompetition.from(record: record)
                        allCompetitions.append(competition)
                    }
                }
            }

            // Track if data was truncated for UI indication
            competitionsFetchTruncated = cursor != nil
            if competitionsFetchTruncated {
                Log.family.warning("Competition pagination limit reached (\(allCompetitions.count) items) - some data not shown")
            }

            return allCompetitions
        } catch {
            Log.family.error("Failed to fetch family competitions: \(error)")
            competitionsFetchTruncated = false
            return []
        }
    }

    // MARK: - Centralized Location Refresh

    /// Start watching for location updates. Call from view's onAppear.
    /// Multiple views can watch simultaneously - timer runs while any view is watching.
    func startWatchingLocations() {
        activeWatcherCount += 1
        Log.family.debug("Started watching locations (watchers: \(self.activeWatcherCount))")

        // Start refresh loop if this is the first watcher
        if activeWatcherCount == 1 {
            startRefreshLoop()
        }
    }

    /// Stop watching for location updates. Call from view's onDisappear.
    func stopWatchingLocations() {
        activeWatcherCount = max(0, activeWatcherCount - 1)
        Log.family.debug("Stopped watching locations (watchers: \(self.activeWatcherCount))")

        // Stop refresh loop if no more watchers
        if activeWatcherCount == 0 {
            stopRefreshLoop()
        }
    }

    /// Suspend the refresh loop when the app enters background.
    /// Call from ScenePhase.background handler. The watcher count is preserved
    /// so resumeWatchingForForeground() can restart without views re-registering
    /// (SwiftUI does not fire onAppear when returning from background).
    func suspendWatchingForBackground() {
        guard activeWatcherCount > 0 else { return }
        Log.family.info("Suspending refresh loop for background (watchers: \(self.activeWatcherCount))")
        stopRefreshLoop()
    }

    /// Resume the refresh loop when the app returns to foreground.
    /// Call from ScenePhase.active handler.
    func resumeWatchingForForeground() {
        guard activeWatcherCount > 0, refreshTask == nil else { return }
        Log.family.info("Resuming refresh loop for foreground (watchers: \(self.activeWatcherCount))")
        startRefreshLoop()
    }

    private func startRefreshLoop() {
        // Cancel any existing task
        refreshTask?.cancel()

        // Reset stopped flag when starting
        refreshLoopStopped = false

        refreshTask = Task { [weak self] in
            var consecutiveErrors = 0
            let maxConsecutiveErrors = 5

            while !Task.isCancelled {
                // Check self still exists
                guard let self = self else {
                    Log.family.warning("Refresh loop exiting - coordinator deallocated")
                    return
                }

                // Fetch with error tracking
                let success = await self.fetchFamilyLocations()
                if success {
                    consecutiveErrors = 0
                    // Clear stopped flag on successful fetch
                    if self.refreshLoopStopped {
                        await MainActor.run {
                            self.refreshLoopStopped = false
                        }
                    }
                } else {
                    consecutiveErrors += 1
                    Log.family.warning("Refresh loop fetch failed (\(consecutiveErrors)/\(maxConsecutiveErrors))")

                    // Exit loop if too many consecutive errors
                    if consecutiveErrors >= maxConsecutiveErrors {
                        Log.family.error("Refresh loop stopping due to repeated errors")
                        await MainActor.run {
                            self.refreshLoopStopped = true
                            self.errorMessage = "Unable to fetch family locations. Pull down to refresh."
                        }
                        break
                    }
                }

                // Wait for refresh interval, but check for cancellation
                do {
                    try await Task.sleep(for: .seconds(self.refreshInterval))
                } catch {
                    // Task was cancelled
                    Log.family.debug("Refresh loop cancelled during sleep")
                    break
                }
            }

            Log.family.info("Refresh loop exited")
        }
        Log.family.info("Refresh loop started (interval: \(self.refreshInterval)s)")
    }

    private func stopRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = nil
        Log.family.info("Refresh loop stopped")
    }

    /// Restart the refresh loop after it stopped due to errors
    /// Call this from UI when user pulls to refresh
    func restartRefreshLoopIfNeeded() {
        if refreshLoopStopped && activeWatcherCount > 0 {
            Log.family.info("Restarting refresh loop after user request")
            startRefreshLoop()
        }
    }

    // MARK: - Family Role

    /// Current role in family sharing
    var currentRole: FamilyRole {
        if !linkedRiders.isEmpty {
            return .parent
        }
        if mySession != nil {
            return .child
        }
        return .selfOnly
    }
}

// MARK: - FamilySharing Protocol Conformance

extension UnifiedSharingCoordinator: FamilySharing {
    var sharedWithMe_protocol: [LiveTrackingSession] { sharedWithMe }

    func shareWithFamilyMember(email: String) async -> URL? {
        // Create a temporary relationship and generate share link
        guard let relationship = createRelationship(name: email, type: .familyMember, email: email) else {
            return nil
        }
        return await generateShareLink(for: relationship)
    }
}
