//
//  SyncStatusMonitor.swift
//  TetraTrack
//
//  Monitors CloudKit sync health and provides status updates for UI.
//  Allows users to see when sync is working or failing.
//
//  Note: The status enum is named CloudSyncStatus to avoid conflict
//  with the existing SyncStatus enum in TrainingArtifact.swift
//

import Foundation
import CloudKit
import Network
import Observation
import os

// MARK: - Sync Status

/// Represents the current state of CloudKit synchronization
enum CloudSyncStatus: Equatable {
    case syncing
    case synced
    case error(String)
    case offline
    case notSignedIn

    var icon: String {
        switch self {
        case .syncing:
            return "arrow.triangle.2.circlepath.icloud"
        case .synced:
            return "checkmark.icloud"
        case .error:
            return "exclamationmark.icloud"
        case .offline:
            return "icloud.slash"
        case .notSignedIn:
            return "person.crop.circle.badge.exclamationmark"
        }
    }

    var displayText: String {
        switch self {
        case .syncing:
            return "Syncing..."
        case .synced:
            return "Up to date"
        case .error(let message):
            return message
        case .offline:
            return "Offline"
        case .notSignedIn:
            return "Sign in to iCloud"
        }
    }

    var color: String {
        switch self {
        case .syncing:
            return "blue"
        case .synced:
            return "green"
        case .error:
            return "orange"
        case .offline:
            return "gray"
        case .notSignedIn:
            return "red"
        }
    }
}

// MARK: - Sync Status Monitor

@Observable
@MainActor
final class SyncStatusMonitor {
    static let shared = SyncStatusMonitor()

    // MARK: Published State

    /// Current sync status
    private(set) var status: CloudSyncStatus = .synced

    /// When the last successful sync occurred
    private(set) var lastSyncTime: Date?

    /// Number of pending CloudKit operations
    private(set) var pendingOperations: Int = 0

    /// Whether we're actively monitoring
    private(set) var isMonitoring: Bool = false

    /// Detailed error message (if any)
    private(set) var detailedError: String?

    // MARK: Private State

    private var monitoringTask: Task<Void, Never>?
    private let healthCheckInterval: TimeInterval = 30  // Check every 30 seconds
    private let container = CKContainer.default()
    private let networkMonitor = NWPathMonitor()
    private var isNetworkAvailable: Bool = true

    // MARK: Initialization

    private init() {
        setupNetworkMonitoring()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self = self else { return }
                let wasAvailable = self.isNetworkAvailable
                self.isNetworkAvailable = path.status == .satisfied

                if self.isNetworkAvailable && !wasAvailable {
                    // Network restored - trigger health check
                    Log.family.info("Network restored, checking sync health")
                    await self.checkSyncHealth()
                } else if !self.isNetworkAvailable && wasAvailable {
                    self.status = CloudSyncStatus.offline
                    Log.family.info("Network lost, status: offline")
                }
            }
        }
        networkMonitor.start(queue: DispatchQueue.global(qos: .utility))
    }

    // MARK: - Monitoring Control

    /// Start monitoring sync health
    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        Log.family.info("SyncStatusMonitor: Starting health monitoring")

        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }

                await self.checkSyncHealth()

                do {
                    try await Task.sleep(for: .seconds(self.healthCheckInterval))
                } catch {
                    break
                }
            }
        }
    }

    /// Stop monitoring sync health
    func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
        Log.family.info("SyncStatusMonitor: Stopped health monitoring")
    }

    // MARK: - Health Check

    /// Check CloudKit sync health
    func checkSyncHealth() async {
        // Check network first
        guard isNetworkAvailable else {
            status = CloudSyncStatus.offline
            return
        }

        // Check iCloud account status
        do {
            let accountStatus = try await container.accountStatus()

            switch accountStatus {
            case .available:
                // Account is available, verify we can access the database
                await verifyDatabaseAccess()

            case .noAccount:
                status = CloudSyncStatus.notSignedIn
                detailedError = "Please sign in to iCloud in Settings"
                Log.family.warning("iCloud: Not signed in")

            case .restricted:
                status = CloudSyncStatus.error("iCloud Restricted")
                detailedError = "iCloud access is restricted by parental controls or device management"
                Log.family.warning("iCloud: Restricted")

            case .couldNotDetermine:
                status = CloudSyncStatus.error("Unable to check iCloud")
                detailedError = "Could not determine iCloud account status"
                Log.family.warning("iCloud: Could not determine status")

            case .temporarilyUnavailable:
                status = CloudSyncStatus.error("iCloud Temporarily Unavailable")
                detailedError = "iCloud is temporarily unavailable. Please try again later."
                Log.family.warning("iCloud: Temporarily unavailable")

            @unknown default:
                status = CloudSyncStatus.error("Unknown iCloud Status")
                detailedError = "Unknown iCloud account status"
            }
        } catch {
            status = CloudSyncStatus.error("iCloud Error")
            detailedError = error.localizedDescription
            Log.family.error("Failed to check iCloud status: \(error.localizedDescription)")
        }
    }

    /// Verify we can actually access the CloudKit database
    private func verifyDatabaseAccess() async {
        let database = container.privateCloudDatabase

        do {
            // Try to fetch zones to verify access
            _ = try await database.allRecordZones()

            // Success - sync is working
            status = CloudSyncStatus.synced
            lastSyncTime = Date()
            detailedError = nil

        } catch let error as CKError {
            handleCloudKitError(error)
        } catch {
            status = CloudSyncStatus.error("Sync Error")
            detailedError = error.localizedDescription
            Log.family.error("Database access verification failed: \(error.localizedDescription)")
        }
    }

    /// Handle specific CloudKit errors
    private func handleCloudKitError(_ error: CKError) {
        switch error.code {
        case .networkUnavailable, .networkFailure:
            status = CloudSyncStatus.offline
            detailedError = "No internet connection"

        case .notAuthenticated:
            status = CloudSyncStatus.notSignedIn
            detailedError = "Please sign in to iCloud"

        case .quotaExceeded:
            status = CloudSyncStatus.error("iCloud Storage Full")
            detailedError = "Your iCloud storage is full. Sync may not work correctly."

        case .serverResponseLost:
            status = CloudSyncStatus.error("Server Error")
            detailedError = "Lost connection to iCloud servers"

        case .serviceUnavailable:
            status = CloudSyncStatus.error("iCloud Unavailable")
            detailedError = "iCloud services are temporarily unavailable"

        case .requestRateLimited:
            status = CloudSyncStatus.syncing
            detailedError = "Request rate limited, will retry"

        case .zoneBusy:
            status = CloudSyncStatus.syncing
            detailedError = "CloudKit zone is busy, will retry"

        default:
            status = CloudSyncStatus.error("Sync Error")
            detailedError = error.localizedDescription
        }

        Log.family.warning("CloudKit error: \(error.code.rawValue) - \(error.localizedDescription)")
    }

    // MARK: - Operation Tracking

    /// Call when a CloudKit operation starts
    func operationStarted() {
        pendingOperations += 1
        if pendingOperations == 1 {
            status = CloudSyncStatus.syncing
        }
    }

    /// Call when a CloudKit operation completes
    func operationCompleted(success: Bool) {
        pendingOperations = max(0, pendingOperations - 1)

        if success {
            lastSyncTime = Date()
            if pendingOperations == 0 {
                status = CloudSyncStatus.synced
                detailedError = nil
            }
        } else {
            // Keep error state if we had one
            if case CloudSyncStatus.error = status {
                // Already have an error
            } else if pendingOperations == 0 {
                status = CloudSyncStatus.error("Sync failed")
            }
        }
    }

    /// Force a status update (called when ModelContainer falls back to local-only)
    func setLocalOnlyMode(reason: String) {
        status = CloudSyncStatus.error("Local Storage Only")
        detailedError = reason
        Log.family.warning("SyncStatusMonitor: Local-only mode - \(reason)")
    }

    // MARK: - Formatted Properties

    /// Human-readable time since last sync
    var timeSinceLastSync: String? {
        guard let lastSync = lastSyncTime else { return nil }

        let interval = Date().timeIntervalSince(lastSync)

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
            return "\(days)d ago"
        }
    }
}
