//
//  WatchSessionSyncService.swift
//  TrackRide Watch App
//
//  Syncs completed Watch sessions to iPhone via WatchConnectivity
//  Sessions are stored locally until successfully synced
//

import Foundation
import WatchConnectivity
import Observation
import os

/// Manages syncing Watch sessions to iPhone
@Observable
final class WatchSessionSyncService: NSObject {
    static let shared = WatchSessionSyncService()

    // MARK: - State

    private(set) var isSyncing = false
    private(set) var lastSyncTime: Date?
    private(set) var lastSyncError: String?

    // MARK: - Dependencies

    private let sessionStore = WatchSessionStore.shared
    private let connectivityService = WatchConnectivityService.shared

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Sync Control

    /// Attempt to sync all pending sessions to iPhone
    func syncPendingSessions() {
        guard !isSyncing else {
            Log.sync.debug("Sync already in progress")
            return
        }

        guard connectivityService.isReachable else {
            Log.sync.debug("iPhone not reachable")
            lastSyncError = "iPhone not connected"
            return
        }

        let sessionsToSync = sessionStore.getSessionsForSync()
        guard !sessionsToSync.isEmpty else {
            Log.sync.debug("No sessions to sync")
            return
        }

        isSyncing = true
        lastSyncError = nil

        Log.sync.info("Starting sync of \(sessionsToSync.count) sessions")

        for session in sessionsToSync {
            syncSession(session)
        }
    }

    /// Sync a single session to iPhone
    private func syncSession(_ session: WatchSession) {
        // Encode session for transfer
        guard let sessionData = encodeSession(session) else {
            Log.sync.error("Failed to encode session \(session.id)")
            sessionStore.markSyncAttemptFailed(id: session.id)
            return
        }

        // Create message for WatchConnectivity
        let message: [String: Any] = [
            "type": "watchSessionSync",
            "sessionId": session.id.uuidString,
            "sessionData": sessionData,
            "timestamp": Date().timeIntervalSince1970
        ]

        // Send via WatchConnectivity
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: { [weak self] reply in
                // Handle success
                if let success = reply["success"] as? Bool, success {
                    DispatchQueue.main.async {
                        self?.sessionStore.markSessionSynced(id: session.id)
                        self?.lastSyncTime = Date()
                        Log.sync.info("Session \(session.id) synced successfully")
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.sessionStore.markSyncAttemptFailed(id: session.id)
                        self?.lastSyncError = reply["error"] as? String ?? "Unknown error"
                    }
                }

                // Check if sync is complete
                DispatchQueue.main.async {
                    self?.checkSyncComplete()
                }
            }, errorHandler: { [weak self] error in
                DispatchQueue.main.async {
                    self?.sessionStore.markSyncAttemptFailed(id: session.id)
                    self?.lastSyncError = error.localizedDescription
                    Log.sync.error("Sync error: \(error.localizedDescription)")
                    self?.checkSyncComplete()
                }
            })
        } else {
            // Fall back to transferUserInfo for background delivery
            WCSession.default.transferUserInfo(message)
            Log.sync.info("Queued session \(session.id) for background transfer")
            checkSyncComplete()
        }
    }

    private func checkSyncComplete() {
        let remaining = sessionStore.getSessionsForSync().count
        if remaining == 0 {
            isSyncing = false
            Log.sync.info("Sync complete")
        }
    }

    // MARK: - Encoding

    private func encodeSession(_ session: WatchSession) -> String? {
        // Create a transfer-friendly dictionary
        var dict: [String: Any] = [
            "id": session.id.uuidString,
            "discipline": session.discipline.rawValue,
            "startDate": session.startDate.timeIntervalSince1970,
            "duration": session.duration,
            "distance": session.distance,
            "elevationGain": session.elevationGain,
            "elevationLoss": session.elevationLoss,
            "averageSpeed": session.averageSpeed,
            "maxSpeed": session.maxSpeed
        ]

        if let endDate = session.endDate {
            dict["endDate"] = endDate.timeIntervalSince1970
        }

        if let avgHR = session.averageHeartRate {
            dict["averageHeartRate"] = avgHR
        }
        if let maxHR = session.maxHeartRate {
            dict["maxHeartRate"] = maxHR
        }
        if let minHR = session.minHeartRate {
            dict["minHeartRate"] = minHR
        }

        // Encode location points as base64 string
        if let locationData = session.locationPointsData {
            dict["locationPoints"] = locationData.base64EncodedString()
        }

        // Convert to JSON string
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }

        return jsonString
    }

    // MARK: - Auto Sync

    /// Called when iPhone becomes reachable
    func onPhoneReachable() {
        // Auto-sync pending sessions when phone connects
        let pendingCount = sessionStore.pendingCount
        if pendingCount > 0 {
            Log.sync.info("iPhone connected, syncing \(pendingCount) pending sessions")
            syncPendingSessions()
        }
    }

    /// Cleanup old failed sessions
    func cleanup() {
        sessionStore.cleanupFailedSessions(maxAttempts: 10)
    }
}
