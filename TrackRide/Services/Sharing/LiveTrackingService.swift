//
//  LiveTrackingService.swift
//  TrackRide
//
//  Actor-based service for managing live location tracking sessions.
//  Handles starting, updating, and stopping shared location sessions.
//

import Foundation
import CloudKit
import CoreLocation
import Network
import os

// MARK: - Live Tracking Service

actor LiveTrackingService {
    // MARK: State

    private(set) var mySession: LiveTrackingSession?
    private(set) var sharedSessions: [LiveTrackingSession] = []

    // CloudKit
    private let container: CKContainer
    private let zoneName: String
    private var zoneID: CKRecordZone.ID?
    private var currentUserID: String = ""

    // Record type
    private let liveTrackingRecordType = "LiveTrackingSession"

    // MARK: Network Monitoring

    /// Network path monitor for connectivity checks
    private let networkMonitor = NWPathMonitor()

    /// Current network status
    private var isNetworkAvailable: Bool = true

    // MARK: Offline Queue & Retry

    /// Pending location update to retry
    private struct PendingUpdate {
        let session: LiveTrackingSession
        let attemptCount: Int
        let nextRetryTime: Date
    }

    /// Queue of pending updates to retry
    private var pendingUpdate: PendingUpdate?

    /// Maximum retry attempts before giving up
    private let maxRetryAttempts = 5

    /// Base delay for exponential backoff (seconds)
    private let baseRetryDelay: TimeInterval = 2

    /// Retry task
    private var retryTask: Task<Void, Never>?

    // MARK: Initialization

    init(
        container: CKContainer = .default(),
        zoneName: String = "FamilySharing"
    ) {
        self.container = container
        self.zoneName = zoneName
    }

    // MARK: - Configuration

    /// Configure with user information
    func configure(userID: String, zoneID: CKRecordZone.ID) {
        self.currentUserID = userID
        self.zoneID = zoneID

        // Start network monitoring
        startNetworkMonitoring()
    }

    /// Start monitoring network connectivity
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task {
                guard let self = self else {
                    // Service was deallocated - this is expected during cleanup
                    return
                }
                await self.updateNetworkStatus(path.status == .satisfied)
            }
        }
        networkMonitor.start(queue: DispatchQueue.global(qos: .utility))
    }

    /// Stop network monitoring (call during cleanup)
    private func stopNetworkMonitoring() {
        networkMonitor.cancel()
    }

    /// Clean up all resources (call before releasing the service)
    func cleanup() {
        retryTask?.cancel()
        retryTask = nil
        pendingUpdate = nil
        stopNetworkMonitoring()
    }

    /// Update network status (called from network monitor)
    private func updateNetworkStatus(_ available: Bool) async {
        let wasAvailable = isNetworkAvailable
        isNetworkAvailable = available

        if available && !wasAvailable {
            Log.family.info("Network restored - processing pending updates")
            // Trigger immediate retry if we have pending updates
            if pendingUpdate != nil {
                await processPendingRetry()
            }
        } else if !available && wasAvailable {
            Log.family.warning("Network lost - updates will be queued")
        }
    }

    // MARK: - Start Sharing Location

    /// Start sharing location with family members
    func startSharingLocation(riderName: String) async throws -> LiveTrackingSession {
        guard !currentUserID.isEmpty else {
            throw LiveTrackingError.notConfigured
        }

        guard let zoneID = zoneID else {
            throw LiveTrackingError.zoneNotAvailable
        }

        // Create session
        let session = LiveTrackingSession(riderName: riderName, riderID: currentUserID)
        session.startSession()

        // Create CloudKit record
        let recordID = CKRecord.ID(recordName: "live-\(currentUserID)", zoneID: zoneID)
        let record = CKRecord(recordType: liveTrackingRecordType, recordID: recordID)
        updateRecord(record, from: session)

        do {
            _ = try await container.privateCloudDatabase.save(record)
            mySession = session
            Log.family.info("Started sharing location")
            return session
        } catch {
            Log.family.error("Failed to start sharing: \(error)")
            throw LiveTrackingError.startFailed(underlying: error)
        }
    }

    // MARK: - Update Shared Location

    /// Update the current shared location
    func updateSharedLocation(
        location: CLLocation,
        gait: GaitType,
        distance: Double,
        duration: TimeInterval
    ) async throws {
        guard let session = mySession else {
            throw LiveTrackingError.noActiveSession
        }

        guard let zoneID = zoneID else {
            throw LiveTrackingError.zoneNotAvailable
        }

        // Update local session
        session.updateLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            speed: max(0, location.speed),
            gait: gait,
            distance: distance,
            duration: duration
        )

        // Force encode route points before CloudKit sync
        session.encodeRoutePoints()

        // Try to send update to CloudKit with confirmation
        let result = await sendLocationUpdateWithConfirmation(session: session, zoneID: zoneID)

        if !result.success {
            // Queue for retry with exponential backoff
            queueForRetry(session: session, previousAttempts: 0)
            throw LiveTrackingError.updateFailed(underlying: NSError(
                domain: "LiveTrackingService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Update queued for retry"]
            ))
        } else {
            // Clear any pending retries on success
            pendingUpdate = nil
            retryTask?.cancel()
            retryTask = nil

            // Store confirmation details
            lastConfirmedTimestamp = result.serverTimestamp
            lastChangeTag = result.recordChangeTag
        }
    }

    /// Result of a location update operation
    struct LocationUpdateResult {
        let success: Bool
        let serverTimestamp: Date?
        let recordChangeTag: String?
    }

    /// Send a location update to CloudKit with conflict resolution and confirmation
    private func sendLocationUpdate(session: LiveTrackingSession, zoneID: CKRecordZone.ID) async -> Bool {
        let result = await sendLocationUpdateWithConfirmation(session: session, zoneID: zoneID)
        return result.success
    }

    /// Send a location update with full confirmation details
    /// Returns the server timestamp when the update was confirmed
    private func sendLocationUpdateWithConfirmation(
        session: LiveTrackingSession,
        zoneID: CKRecordZone.ID
    ) async -> LocationUpdateResult {
        let recordID = CKRecord.ID(recordName: "live-\(currentUserID)", zoneID: zoneID)

        do {
            let record = try await container.privateCloudDatabase.record(for: recordID)
            updateRecord(record, from: session)

            // Use modifyRecords with changedKeys policy for better conflict handling
            let (savedResults, _) = try await container.privateCloudDatabase.modifyRecords(
                saving: [record],
                deleting: [],
                savePolicy: .changedKeys  // Only update changed fields to reduce conflicts
            )

            // Extract confirmation details from saved record
            var serverTimestamp: Date?
            var changeTag: String?

            for (recordID, result) in savedResults {
                switch result {
                case .success(let savedRecord):
                    // Extract server confirmation timestamp
                    serverTimestamp = savedRecord.modificationDate
                    changeTag = savedRecord.recordChangeTag

                    Log.family.info("Location update confirmed at \(serverTimestamp?.formatted() ?? "unknown") (tag: \(changeTag ?? "none"))")

                case .failure(let error):
                    // Handle specific conflict error
                    if let ckError = error as? CKError, ckError.code == .serverRecordChanged {
                        Log.family.warning("CloudKit conflict detected, will retry with fresh record")
                        return LocationUpdateResult(success: false, serverTimestamp: nil, recordChangeTag: nil)
                    }
                    throw error
                }
            }

            return LocationUpdateResult(
                success: true,
                serverTimestamp: serverTimestamp,
                recordChangeTag: changeTag
            )

        } catch let error as CKError {
            switch error.code {
            case .serverRecordChanged:
                Log.family.warning("CloudKit conflict - record changed on server")
            case .networkUnavailable, .networkFailure:
                Log.family.warning("Network unavailable for location update")
            case .quotaExceeded:
                Log.family.error("iCloud quota exceeded")
            default:
                Log.family.error("CloudKit error: \(error.localizedDescription)")
            }
            return LocationUpdateResult(success: false, serverTimestamp: nil, recordChangeTag: nil)
        } catch {
            Log.family.error("Failed to update shared location: \(error)")
            return LocationUpdateResult(success: false, serverTimestamp: nil, recordChangeTag: nil)
        }
    }

    /// Last confirmed server timestamp for location updates
    private(set) var lastConfirmedTimestamp: Date?

    /// Last change tag for optimistic concurrency
    private(set) var lastChangeTag: String?

    /// Queue a session update for retry with exponential backoff
    private func queueForRetry(session: LiveTrackingSession, previousAttempts: Int) {
        guard previousAttempts < maxRetryAttempts else {
            Log.family.warning("Max retry attempts reached, dropping location update")
            pendingUpdate = nil
            return
        }

        // Calculate delay with exponential backoff (2, 4, 8, 16, 32 seconds)
        let delay = baseRetryDelay * pow(2.0, Double(previousAttempts))
        let nextRetryTime = Date().addingTimeInterval(delay)

        pendingUpdate = PendingUpdate(
            session: session,
            attemptCount: previousAttempts + 1,
            nextRetryTime: nextRetryTime
        )

        // Check network before scheduling retry
        if !isNetworkAvailable {
            Log.family.info("Network unavailable - update queued, will retry when network returns")
            // Don't schedule retry - it will be triggered when network is restored
            return
        }

        Log.family.info("Queued update for retry (attempt \(previousAttempts + 1)/\(self.maxRetryAttempts), delay: \(delay)s)")

        // Schedule retry
        scheduleRetry(delay: delay)
    }

    /// Schedule a retry task
    private func scheduleRetry(delay: TimeInterval) {
        // Cancel previous retry task if any
        if let existingTask = retryTask {
            existingTask.cancel()
            retryTask = nil
        }

        retryTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                // Cancelled - clear task reference
                return
            }

            guard let self = self else { return }
            await self.processPendingRetry()

            // Clear task reference after completion
            await self.clearRetryTask()
        }
    }

    /// Clear the retry task reference (called after task completes)
    private func clearRetryTask() {
        retryTask = nil
    }

    /// Process the pending retry
    private func processPendingRetry() async {
        guard let pending = pendingUpdate, let zoneID = zoneID else { return }

        let success = await sendLocationUpdate(session: pending.session, zoneID: zoneID)

        if success {
            Log.family.info("Retry succeeded on attempt \(pending.attemptCount)")
            pendingUpdate = nil
        } else {
            // Queue for another retry
            queueForRetry(session: pending.session, previousAttempts: pending.attemptCount)
        }
    }

    // MARK: - Stop Sharing Location

    /// Stop sharing location
    func stopSharingLocation() async throws {
        // Cancel any pending retries
        retryTask?.cancel()
        retryTask = nil
        pendingUpdate = nil

        guard let zoneID = zoneID else {
            throw LiveTrackingError.zoneNotAvailable
        }

        mySession?.endSession()

        // Update CloudKit record to inactive
        let recordID = CKRecord.ID(recordName: "live-\(currentUserID)", zoneID: zoneID)

        do {
            let record = try await container.privateCloudDatabase.record(for: recordID)
            record["isActive"] = false
            _ = try await container.privateCloudDatabase.save(record)
            Log.family.info("Stopped sharing location")
        } catch {
            Log.family.error("Failed to stop sharing: \(error)")
        }

        mySession = nil
    }

    // MARK: - Fetch Family Locations

    /// Fetch live sessions from family members
    func fetchFamilyLocations() async -> [LiveTrackingSession] {
        let (sessions, _) = await fetchFamilyLocationsWithError()
        return sessions
    }

    /// Fetch live sessions from family members with error reporting
    /// - Returns: Tuple of (sessions, error) where error is nil on success
    func fetchFamilyLocationsWithError() async -> ([LiveTrackingSession], Error?) {
        var allSessions: [LiveTrackingSession] = []
        var lastError: Error?

        // Query shared database for accepted shares
        do {
            let zones = try await container.sharedCloudDatabase.allRecordZones()

            for zone in zones {
                let predicate = NSPredicate(value: true)
                let query = CKQuery(recordType: liveTrackingRecordType, predicate: predicate)

                let (results, _) = try await container.sharedCloudDatabase.records(
                    matching: query,
                    inZoneWith: zone.zoneID
                )

                for (_, result) in results {
                    if case .success(let record) = result {
                        if let session = sessionFromRecord(record) {
                            // Don't include our own session
                            if session.riderID != currentUserID {
                                allSessions.append(session)
                            }
                        }
                    }
                }
            }
        } catch {
            Log.family.error("Failed to fetch from shared database: \(error)")
            lastError = error
        }

        // Also check private database (for testing/development)
        if let zoneID = zoneID {
            do {
                let predicate = NSPredicate(value: true)
                let query = CKQuery(recordType: liveTrackingRecordType, predicate: predicate)

                let (results, _) = try await container.privateCloudDatabase.records(
                    matching: query,
                    inZoneWith: zoneID
                )

                for (_, result) in results {
                    if case .success(let record) = result {
                        if let session = sessionFromRecord(record) {
                            // Don't include our own session or duplicates
                            if session.riderID != currentUserID &&
                               !allSessions.contains(where: { $0.riderID == session.riderID }) {
                                allSessions.append(session)
                            }
                        }
                    }
                }
            } catch {
                Log.family.error("Failed to fetch from private database: \(error)")
                lastError = error
            }
        }

        sharedSessions = allSessions

        // Return error only if we got no sessions AND had an error
        // (partial success still counts as success)
        if allSessions.isEmpty && lastError != nil {
            return (allSessions, lastError)
        }

        return (allSessions, nil)
    }

    // MARK: - Active Sessions

    /// Get active sessions (currently riding)
    var activeSessions: [LiveTrackingSession] {
        sharedSessions.filter { $0.isActive }
    }

    /// Whether any linked rider is currently active
    var hasActiveRiders: Bool {
        !activeSessions.isEmpty
    }

    // MARK: - Record Helpers

    /// Validate session data before CloudKit transmission
    private func validateSessionData(_ session: LiveTrackingSession) -> Bool {
        // Check for valid coordinates
        guard session.currentLatitude >= -90, session.currentLatitude <= 90 else {
            Log.family.warning("Invalid latitude: \(session.currentLatitude)")
            return false
        }

        guard session.currentLongitude >= -180, session.currentLongitude <= 180 else {
            Log.family.warning("Invalid longitude: \(session.currentLongitude)")
            return false
        }

        // Check for non-negative values
        guard session.totalDistance >= 0 else {
            Log.family.warning("Invalid distance: \(session.totalDistance)")
            return false
        }

        guard session.elapsedDuration >= 0 else {
            Log.family.warning("Invalid duration: \(session.elapsedDuration)")
            return false
        }

        guard session.currentSpeed >= 0, session.currentSpeed < 100 else {
            Log.family.warning("Invalid speed: \(session.currentSpeed)")
            return false
        }

        // Check rider ID is not empty
        guard !session.riderID.isEmpty else {
            Log.family.warning("Empty riderID")
            return false
        }

        // Check route data size (CloudKit has 1MB limit per field)
        if let routeData = session.routePointsData, routeData.count > 900_000 {
            Log.family.warning("Route data too large: \(routeData.count) bytes")
            return false
        }

        return true
    }

    private func updateRecord(_ record: CKRecord, from session: LiveTrackingSession) {
        // Validate before updating record
        guard validateSessionData(session) else {
            Log.family.error("Session data validation failed, skipping record update")
            return
        }

        record["riderName"] = session.riderName
        record["riderID"] = session.riderID
        record["isActive"] = session.isActive
        record["startTime"] = session.startTime
        record["lastUpdateTime"] = session.lastUpdateTime
        record["currentLatitude"] = session.currentLatitude
        record["currentLongitude"] = session.currentLongitude
        record["currentAltitude"] = session.currentAltitude
        record["currentSpeed"] = session.currentSpeed
        record["currentGait"] = session.currentGait
        record["totalDistance"] = session.totalDistance
        record["elapsedDuration"] = session.elapsedDuration
        record["isStationary"] = session.isStationary
        record["stationaryDuration"] = session.stationaryDuration

        // Store route points as Data for gait-colored route display
        if let routeData = session.routePointsData {
            record["routePointsData"] = routeData
        }
    }

    private func sessionFromRecord(_ record: CKRecord) -> LiveTrackingSession? {
        let session = LiveTrackingSession()
        session.riderName = record["riderName"] as? String ?? ""
        session.riderID = record["riderID"] as? String ?? ""
        session.isActive = record["isActive"] as? Bool ?? false
        session.startTime = record["startTime"] as? Date
        session.lastUpdateTime = record["lastUpdateTime"] as? Date ?? Date()
        session.currentLatitude = record["currentLatitude"] as? Double ?? 0
        session.currentLongitude = record["currentLongitude"] as? Double ?? 0
        session.currentAltitude = record["currentAltitude"] as? Double ?? 0
        session.currentSpeed = record["currentSpeed"] as? Double ?? 0
        session.currentGait = record["currentGait"] as? String ?? GaitType.stationary.rawValue
        session.totalDistance = record["totalDistance"] as? Double ?? 0
        session.elapsedDuration = record["elapsedDuration"] as? TimeInterval ?? 0
        session.isStationary = record["isStationary"] as? Bool ?? false
        session.stationaryDuration = record["stationaryDuration"] as? TimeInterval ?? 0

        // Validate data before returning session
        // Check for required fields
        guard !session.riderID.isEmpty else {
            Log.family.warning("Invalid session from CloudKit: missing riderID")
            return nil
        }

        // Validate coordinates are in valid range
        guard session.currentLatitude >= -90, session.currentLatitude <= 90,
              session.currentLongitude >= -180, session.currentLongitude <= 180 else {
            Log.family.warning("Invalid session from CloudKit: coordinates out of range (lat: \(session.currentLatitude), lon: \(session.currentLongitude))")
            return nil
        }

        // Check for null island (0,0) which likely indicates missing data
        if session.currentLatitude == 0 && session.currentLongitude == 0 && session.isActive {
            Log.family.warning("Suspicious session from CloudKit: active session at 0,0 coordinates")
            // Don't reject, but log warning - could be legitimate edge case
        }

        // Validate non-negative values
        if session.currentSpeed < 0 || session.currentSpeed > 100 {
            session.currentSpeed = 0  // Clamp to reasonable value
        }
        if session.totalDistance < 0 {
            session.totalDistance = 0
        }
        if session.elapsedDuration < 0 {
            session.elapsedDuration = 0
        }

        // Decode route points for gait-colored route display
        if let routeData = record["routePointsData"] as? Data {
            // Validate route data size (CloudKit 1MB limit)
            if routeData.count < 1_000_000 {
                session.routePointsData = routeData
                session.decodeRoutePoints()
            } else {
                Log.family.warning("Route data too large (\(routeData.count) bytes), skipping")
            }
        }

        return session
    }
}

// MARK: - Live Tracking Error

enum LiveTrackingError: Error, LocalizedError {
    case notConfigured
    case zoneNotAvailable
    case noActiveSession
    case startFailed(underlying: Error)
    case updateFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Live tracking service is not configured."
        case .zoneNotAvailable:
            return "CloudKit zone is not available."
        case .noActiveSession:
            return "No active tracking session."
        case .startFailed(let error):
            return "Failed to start tracking: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "Failed to update location: \(error.localizedDescription)"
        }
    }
}
