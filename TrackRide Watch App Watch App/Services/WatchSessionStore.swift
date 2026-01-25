//
//  WatchSessionStore.swift
//  TrackRide Watch App
//
//  Local storage for Watch autonomous sessions
//  Stores sessions until they can be synced to iPhone
//

import Foundation
import Observation
import os

/// Discipline type for Watch sessions
enum WatchSessionDiscipline: String, Codable {
    case riding
    case running
    case swimming
}

/// A complete session recorded on Watch
struct WatchSession: Codable, Identifiable {
    let id: UUID
    let discipline: WatchSessionDiscipline
    let startDate: Date
    var endDate: Date?

    // Core metrics
    var duration: TimeInterval
    var distance: Double  // meters
    var elevationGain: Double  // meters
    var elevationLoss: Double  // meters

    // Speed metrics
    var averageSpeed: Double  // m/s
    var maxSpeed: Double  // m/s

    // Heart rate metrics
    var averageHeartRate: Int?
    var maxHeartRate: Int?
    var minHeartRate: Int?

    // Location data (encoded for efficiency)
    var locationPointsData: Data?

    // Sync status
    var isSynced: Bool = false
    var syncAttempts: Int = 0
    var lastSyncAttempt: Date?

    init(discipline: WatchSessionDiscipline) {
        self.id = UUID()
        self.discipline = discipline
        self.startDate = Date()
        self.duration = 0
        self.distance = 0
        self.elevationGain = 0
        self.elevationLoss = 0
        self.averageSpeed = 0
        self.maxSpeed = 0
    }

    /// Decode location points from stored data
    func decodeLocationPoints() -> [WatchLocationPoint]? {
        guard let data = locationPointsData else { return nil }
        return try? JSONDecoder().decode([WatchLocationPoint].self, from: data)
    }
}

/// Manages local storage of Watch sessions
@Observable
final class WatchSessionStore {
    static let shared = WatchSessionStore()

    // MARK: - State

    /// Sessions pending sync to iPhone
    private(set) var pendingSessions: [WatchSession] = []

    /// Currently active session (if any)
    private(set) var activeSession: WatchSession?

    /// Number of sessions waiting to sync
    var pendingCount: Int { pendingSessions.count }

    /// Whether there's an active recording session
    var hasActiveSession: Bool { activeSession != nil }

    // MARK: - Private

    private let fileManager = FileManager.default
    private let sessionsFileName = "pending_sessions.json"

    private var sessionsFileURL: URL? {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsURL.appendingPathComponent(sessionsFileName)
    }

    // MARK: - Initialization

    private init() {
        loadPendingSessions()
    }

    // MARK: - Session Lifecycle

    /// Start a new session
    func startSession(discipline: WatchSessionDiscipline) -> WatchSession {
        let session = WatchSession(discipline: discipline)
        activeSession = session
        Log.storage.info("Started \(discipline.rawValue) session")
        return session
    }

    /// Update the active session with current metrics
    func updateActiveSession(
        duration: TimeInterval,
        distance: Double,
        elevationGain: Double,
        elevationLoss: Double,
        averageSpeed: Double,
        maxSpeed: Double,
        averageHeartRate: Int? = nil,
        maxHeartRate: Int? = nil,
        minHeartRate: Int? = nil
    ) {
        guard var session = activeSession else { return }

        session.duration = duration
        session.distance = distance
        session.elevationGain = elevationGain
        session.elevationLoss = elevationLoss
        session.averageSpeed = averageSpeed
        session.maxSpeed = maxSpeed
        session.averageHeartRate = averageHeartRate
        session.maxHeartRate = maxHeartRate
        session.minHeartRate = minHeartRate

        activeSession = session
    }

    /// Complete and save the active session
    func completeSession(locationPointsData: Data?) {
        guard var session = activeSession else {
            Log.storage.warning("No active session to complete")
            return
        }

        session.endDate = Date()
        session.locationPointsData = locationPointsData

        // Add to pending sessions
        pendingSessions.append(session)
        activeSession = nil

        // Persist to disk
        savePendingSessions()

        Log.storage.info("Completed session - \(self.pendingSessions.count) pending sync")
    }

    /// Discard the active session without saving
    func discardSession() {
        guard activeSession != nil else { return }
        activeSession = nil
        Log.storage.info("Discarded active session")
    }

    // MARK: - Sync Management

    /// Get sessions ready for sync
    func getSessionsForSync() -> [WatchSession] {
        pendingSessions.filter { !$0.isSynced }
    }

    /// Mark a session as successfully synced
    func markSessionSynced(id: UUID) {
        if let index = pendingSessions.firstIndex(where: { $0.id == id }) {
            pendingSessions[index].isSynced = true
            // Remove synced sessions
            pendingSessions.removeAll { $0.isSynced }
            savePendingSessions()
            Log.storage.info("Session \(id) synced and removed")
        }
    }

    /// Record a failed sync attempt
    func markSyncAttemptFailed(id: UUID) {
        if let index = pendingSessions.firstIndex(where: { $0.id == id }) {
            pendingSessions[index].syncAttempts += 1
            pendingSessions[index].lastSyncAttempt = Date()
            savePendingSessions()
        }
    }

    /// Remove old sessions that failed to sync too many times
    func cleanupFailedSessions(maxAttempts: Int = 10) {
        let beforeCount = pendingSessions.count
        pendingSessions.removeAll { $0.syncAttempts >= maxAttempts }
        if pendingSessions.count < beforeCount {
            savePendingSessions()
            Log.storage.info("Cleaned up \(beforeCount - self.pendingSessions.count) failed sessions")
        }
    }

    // MARK: - Persistence

    private func savePendingSessions() {
        guard let url = sessionsFileURL else {
            Log.storage.error("Cannot get file URL for saving")
            return
        }

        do {
            let data = try JSONEncoder().encode(pendingSessions)
            try data.write(to: url, options: .atomic)
            Log.storage.debug("Saved \(self.pendingSessions.count) sessions to disk")
        } catch {
            Log.storage.error("Failed to save sessions: \(error.localizedDescription)")
        }
    }

    private func loadPendingSessions() {
        guard let url = sessionsFileURL,
              fileManager.fileExists(atPath: url.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            pendingSessions = try JSONDecoder().decode([WatchSession].self, from: data)
            Log.storage.info("Loaded \(self.pendingSessions.count) pending sessions")
        } catch {
            Log.storage.error("Failed to load sessions: \(error.localizedDescription)")
            pendingSessions = []
        }
    }

    /// Clear all stored data (for testing/reset)
    func clearAll() {
        pendingSessions = []
        activeSession = nil
        if let url = sessionsFileURL {
            try? fileManager.removeItem(at: url)
        }
        Log.storage.info("Cleared all sessions")
    }

    // MARK: - Storage Info

    /// Approximate storage used by pending sessions (bytes)
    var storageUsed: Int {
        guard let url = sessionsFileURL,
              let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int else {
            return 0
        }
        return size
    }

    /// Formatted storage string
    var formattedStorageUsed: String {
        let bytes = storageUsed
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        }
    }

    // MARK: - Streak Calculation

    /// Calculate consecutive training days from pending sessions
    var localStreakDays: Int {
        guard !pendingSessions.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Get unique training days from pending sessions
        var trainingDays = Set<Date>()
        for session in pendingSessions {
            let dayStart = calendar.startOfDay(for: session.startDate)
            trainingDays.insert(dayStart)
        }

        // Count consecutive days ending with today (or yesterday)
        var streak = 0
        var checkDate = today

        // First check if we trained today
        if trainingDays.contains(today) {
            streak = 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        } else {
            // Check yesterday
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            if trainingDays.contains(yesterday) {
                streak = 1
                checkDate = calendar.date(byAdding: .day, value: -2, to: today) ?? today
            } else {
                return 0
            }
        }

        // Count backwards
        while trainingDays.contains(checkDate) {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }

        return streak
    }

    /// Check if there are sessions from today
    var hasSessionsToday: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return pendingSessions.contains { session in
            calendar.startOfDay(for: session.startDate) == today
        }
    }
}
