//
//  ArtifactSyncService.swift
//  TrackRide
//
//  Offline queue, conflict resolution, and batch sync for training artifacts.
//

import Foundation
import CloudKit
import SwiftData
import Network
import os

// MARK: - Sync Operation

/// Queued sync operation for offline resilience
struct SyncOperation: Codable, Identifiable {
    let id: UUID
    let type: OperationType
    let recordType: String          // "TrainingArtifact" or "SharedCompetition"
    let recordID: UUID
    let data: Data
    let timestamp: Date
    var retryCount: Int

    enum OperationType: String, Codable {
        case create
        case update
        case delete
    }

    init(
        id: UUID = UUID(),
        type: OperationType,
        recordType: String,
        recordID: UUID,
        data: Data,
        retryCount: Int = 0
    ) {
        self.id = id
        self.type = type
        self.recordType = recordType
        self.recordID = recordID
        self.data = data
        self.timestamp = Date()
        self.retryCount = retryCount
    }
}

// MARK: - Artifact Sync Service

@Observable
final class ArtifactSyncService {
    static let shared = ArtifactSyncService()

    // State
    var isSyncing: Bool = false
    var pendingOperationCount: Int = 0
    var lastSyncDate: Date?
    var lastSyncError: String?
    var isOnline: Bool = true

    // Queue
    private var pendingOperations: [SyncOperation] = []
    private let operationsKey = "pendingArtifactSyncOperations"
    private let maxRetryCount = 3

    // CloudKit
    private let familyZoneName = "FamilySharing"
    private var familyZoneID: CKRecordZone.ID?

    private var container: CKContainer {
        CKContainer.default()
    }

    private var privateDatabase: CKDatabase {
        container.privateCloudDatabase
    }

    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "com.tetratrack.network")

    private init() {
        loadPendingOperations()
        startNetworkMonitoring()
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOnline = self?.isOnline ?? false
                self?.isOnline = (path.status == .satisfied)

                // If we just came online, process pending operations
                if !wasOnline && (self?.isOnline ?? false) {
                    await self?.processPendingOperations()
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }

    // MARK: - Zone Setup

    func ensureZoneExists() async throws {
        if familyZoneID != nil { return }

        let zone = CKRecordZone(zoneName: familyZoneName)
        familyZoneID = zone.zoneID

        do {
            _ = try await privateDatabase.modifyRecordZones(saving: [zone], deleting: [])
            Log.family.info("ArtifactSyncService: Zone verified")
        } catch {
            Log.family.error("ArtifactSyncService: Failed to create zone: \(error)")
            throw error
        }
    }

    // MARK: - Artifact Operations

    /// Save or update an artifact to CloudKit
    func saveArtifact(_ artifact: TrainingArtifact) async {
        do {
            try await ensureZoneExists()
            guard let zoneID = familyZoneID else { return }

            artifact.markModified()
            let record = artifact.toCKRecord(zoneID: zoneID)

            if isOnline {
                artifact.syncStatus = .syncing
                _ = try await privateDatabase.save(record)
                artifact.markSynced()
                lastSyncDate = Date()
                Log.family.info("Artifact saved to CloudKit: \(artifact.id)")
            } else {
                queueOperation(
                    type: .update,
                    recordType: TrainingArtifact.recordType,
                    recordID: artifact.id,
                    artifact: artifact
                )
            }
        } catch {
            Log.family.error("Failed to save artifact: \(error)")
            lastSyncError = error.localizedDescription

            // Queue for retry
            queueOperation(
                type: .update,
                recordType: TrainingArtifact.recordType,
                recordID: artifact.id,
                artifact: artifact
            )
        }
    }

    /// Delete an artifact from CloudKit
    func deleteArtifact(_ artifact: TrainingArtifact) async {
        do {
            try await ensureZoneExists()
            guard let zoneID = familyZoneID else { return }

            if isOnline {
                let recordID = CKRecord.ID(recordName: artifact.id.uuidString, zoneID: zoneID)
                _ = try await privateDatabase.deleteRecord(withID: recordID)
                Log.family.info("Artifact deleted from CloudKit: \(artifact.id)")
            } else {
                queueOperation(
                    type: .delete,
                    recordType: TrainingArtifact.recordType,
                    recordID: artifact.id,
                    artifact: artifact
                )
            }
        } catch {
            Log.family.error("Failed to delete artifact: \(error)")
            lastSyncError = error.localizedDescription

            queueOperation(
                type: .delete,
                recordType: TrainingArtifact.recordType,
                recordID: artifact.id,
                artifact: artifact
            )
        }
    }

    /// Fetch all artifacts from CloudKit
    func fetchArtifacts() async -> [TrainingArtifact] {
        do {
            try await ensureZoneExists()
            guard let zoneID = familyZoneID else { return [] }

            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: TrainingArtifact.recordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]

            let (results, _) = try await privateDatabase.records(matching: query, inZoneWith: zoneID)

            var artifacts: [TrainingArtifact] = []
            for (_, result) in results {
                if case .success(let record) = result {
                    let artifact = TrainingArtifact.from(record: record)
                    artifacts.append(artifact)
                }
            }

            lastSyncDate = Date()
            Log.family.info("Fetched \(artifacts.count) artifacts from CloudKit")
            return artifacts
        } catch {
            Log.family.error("Failed to fetch artifacts: \(error)")
            lastSyncError = error.localizedDescription
            return []
        }
    }

    // MARK: - Competition Operations

    /// Save or update a competition to CloudKit
    func saveCompetition(_ competition: SharedCompetition, userID: String) async {
        do {
            try await ensureZoneExists()
            guard let zoneID = familyZoneID else { return }

            competition.markModified(by: userID)
            let record = competition.toCKRecord(zoneID: zoneID)

            if isOnline {
                competition.syncStatus = .syncing
                _ = try await privateDatabase.save(record)
                competition.syncStatus = .synced
                lastSyncDate = Date()
                Log.family.info("Competition saved to CloudKit: \(competition.id)")
            } else {
                queueCompetitionOperation(
                    type: .update,
                    competition: competition
                )
            }
        } catch {
            Log.family.error("Failed to save competition: \(error)")
            lastSyncError = error.localizedDescription

            queueCompetitionOperation(
                type: .update,
                competition: competition
            )
        }
    }

    /// Fetch all competitions from CloudKit
    func fetchCompetitions() async -> [SharedCompetition] {
        do {
            try await ensureZoneExists()
            guard let zoneID = familyZoneID else { return [] }

            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: SharedCompetition.recordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

            let (results, _) = try await privateDatabase.records(matching: query, inZoneWith: zoneID)

            var competitions: [SharedCompetition] = []
            for (_, result) in results {
                if case .success(let record) = result {
                    let competition = SharedCompetition.from(record: record)
                    competitions.append(competition)
                }
            }

            lastSyncDate = Date()
            Log.family.info("Fetched \(competitions.count) competitions from CloudKit")
            return competitions
        } catch {
            Log.family.error("Failed to fetch competitions: \(error)")
            lastSyncError = error.localizedDescription
            return []
        }
    }

    // MARK: - Queue Management

    private func queueOperation(
        type: SyncOperation.OperationType,
        recordType: String,
        recordID: UUID,
        artifact: TrainingArtifact
    ) {
        guard let data = try? JSONEncoder().encode(artifact) else {
            Log.family.error("Failed to encode artifact for queue")
            return
        }

        let operation = SyncOperation(
            type: type,
            recordType: recordType,
            recordID: recordID,
            data: data
        )

        // Remove any existing operation for the same record
        pendingOperations.removeAll { $0.recordID == recordID && $0.recordType == recordType }
        pendingOperations.append(operation)
        savePendingOperations()

        artifact.syncStatus = .pending
        pendingOperationCount = pendingOperations.count

        Log.family.info("Queued \(type.rawValue) operation for artifact \(recordID)")
    }

    private func queueCompetitionOperation(
        type: SyncOperation.OperationType,
        competition: SharedCompetition
    ) {
        guard let data = try? JSONEncoder().encode(competition) else {
            Log.family.error("Failed to encode competition for queue")
            return
        }

        let operation = SyncOperation(
            type: type,
            recordType: SharedCompetition.recordType,
            recordID: competition.id,
            data: data
        )

        // Remove any existing operation for the same record
        pendingOperations.removeAll { $0.recordID == competition.id && $0.recordType == SharedCompetition.recordType }
        pendingOperations.append(operation)
        savePendingOperations()

        competition.syncStatus = .pending
        pendingOperationCount = pendingOperations.count

        Log.family.info("Queued \(type.rawValue) operation for competition \(competition.id)")
    }

    /// Process all pending operations when online
    func processPendingOperations() async {
        guard isOnline, !pendingOperations.isEmpty else { return }

        isSyncing = true
        let operationCount = pendingOperations.count
        Log.family.info("Processing \(operationCount) pending operations")

        var remainingOperations: [SyncOperation] = []

        for operation in pendingOperations {
            do {
                try await executeOperation(operation)
                Log.family.info("Executed queued operation \(operation.id)")
            } catch {
                Log.family.error("Failed to execute operation \(operation.id): \(error)")

                var retryOperation = operation
                retryOperation.retryCount += 1

                if retryOperation.retryCount <= maxRetryCount {
                    remainingOperations.append(retryOperation)
                } else {
                    Log.family.error("Operation \(operation.id) exceeded max retries, marking as conflict")
                    await markAsConflict(operation)
                }
            }
        }

        pendingOperations = remainingOperations
        savePendingOperations()
        pendingOperationCount = pendingOperations.count
        isSyncing = false
        lastSyncDate = Date()
    }

    private func executeOperation(_ operation: SyncOperation) async throws {
        guard let zoneID = familyZoneID else {
            try await ensureZoneExists()
            guard let zoneID = familyZoneID else {
                throw NSError(domain: "ArtifactSyncService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Zone not available"])
            }
            return try await executeOperationWithZone(operation, zoneID: zoneID)
        }
        try await executeOperationWithZone(operation, zoneID: zoneID)
    }

    private func executeOperationWithZone(_ operation: SyncOperation, zoneID: CKRecordZone.ID) async throws {
        let recordID = CKRecord.ID(recordName: operation.recordID.uuidString, zoneID: zoneID)

        switch operation.type {
        case .create, .update:
            if operation.recordType == TrainingArtifact.recordType {
                guard let artifact = try? JSONDecoder().decode(TrainingArtifact.self, from: operation.data) else {
                    throw NSError(domain: "ArtifactSyncService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to decode artifact"])
                }
                let record = artifact.toCKRecord(zoneID: zoneID)
                _ = try await privateDatabase.save(record)
            } else if operation.recordType == SharedCompetition.recordType {
                guard let competition = try? JSONDecoder().decode(SharedCompetition.self, from: operation.data) else {
                    throw NSError(domain: "ArtifactSyncService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to decode competition"])
                }
                let record = competition.toCKRecord(zoneID: zoneID)
                _ = try await privateDatabase.save(record)
            }

        case .delete:
            _ = try await privateDatabase.deleteRecord(withID: recordID)
        }
    }

    private func markAsConflict(_ operation: SyncOperation) async {
        // For now, just log the conflict
        // In a full implementation, this would update the local model with conflict status
        Log.family.warning("Conflict detected for \(operation.recordType) \(operation.recordID)")
    }

    // MARK: - Conflict Resolution

    /// Resolve a conflict using last-write-wins strategy
    func resolveConflict(
        localArtifact: TrainingArtifact,
        serverRecord: CKRecord
    ) -> TrainingArtifact {
        let serverModified = serverRecord["modifiedAt"] as? Date ?? Date.distantPast

        if localArtifact.modifiedAt > serverModified {
            // Local wins - keep local data
            Log.family.info("Conflict resolved: local wins for \(localArtifact.id)")
            return localArtifact
        } else {
            // Server wins - update from server
            Log.family.info("Conflict resolved: server wins for \(localArtifact.id)")
            let merged = TrainingArtifact.from(record: serverRecord)

            // Preserve local-only fields that might be newer
            if let localNotes = localArtifact.notes, localArtifact.modifiedAt > serverModified {
                merged.notes = localNotes
            }

            return merged
        }
    }

    // MARK: - Persistence

    private func loadPendingOperations() {
        if let data = UserDefaults.standard.data(forKey: operationsKey),
           let operations = try? JSONDecoder().decode([SyncOperation].self, from: data) {
            pendingOperations = operations
            pendingOperationCount = operations.count
        }
    }

    private func savePendingOperations() {
        if let data = try? JSONEncoder().encode(pendingOperations) {
            UserDefaults.standard.set(data, forKey: operationsKey)
        }
    }

    // MARK: - Batch Operations

    /// Sync all local artifacts to CloudKit
    func syncAllArtifacts(_ artifacts: [TrainingArtifact]) async {
        guard isOnline else {
            Log.family.info("Offline - queuing all artifacts for sync")
            for artifact in artifacts {
                queueOperation(
                    type: .update,
                    recordType: TrainingArtifact.recordType,
                    recordID: artifact.id,
                    artifact: artifact
                )
            }
            return
        }

        isSyncing = true

        do {
            try await ensureZoneExists()
            guard let zoneID = familyZoneID else { return }

            let records = artifacts.map { $0.toCKRecord(zoneID: zoneID) }

            // CloudKit batch save (up to 400 records)
            let chunkSize = 400
            for chunk in stride(from: 0, to: records.count, by: chunkSize) {
                let end = min(chunk + chunkSize, records.count)
                let recordChunk = Array(records[chunk..<end])

                let (saved, _) = try await privateDatabase.modifyRecords(
                    saving: recordChunk,
                    deleting: []
                )

                Log.family.info("Batch saved \(saved.count) artifacts")
            }

            for artifact in artifacts {
                artifact.markSynced()
            }

            lastSyncDate = Date()
        } catch {
            Log.family.error("Batch sync failed: \(error)")
            lastSyncError = error.localizedDescription

            // Queue failed artifacts
            for artifact in artifacts where artifact.syncStatus != .synced {
                queueOperation(
                    type: .update,
                    recordType: TrainingArtifact.recordType,
                    recordID: artifact.id,
                    artifact: artifact
                )
            }
        }

        isSyncing = false
    }

    // MARK: - Status

    var syncStatusDescription: String {
        if isSyncing {
            return "Syncing..."
        } else if !isOnline {
            return "Offline (\(pendingOperationCount) pending)"
        } else if pendingOperationCount > 0 {
            return "\(pendingOperationCount) pending"
        } else if let date = lastSyncDate {
            return "Last synced \(date.formatted(date: .omitted, time: .shortened))"
        } else {
            return "Not synced"
        }
    }
}

// MARK: - TrainingArtifact Codable Conformance

extension TrainingArtifact: Codable {
    enum CodingKeys: String, CodingKey {
        case id, createdAt, modifiedAt, disciplineRaw, sessionType
        case startTime, endTime, distance, averageHeartRate, caloriesBurned
        case personalBest, startLatitude, startLongitude, routeData
        case disciplineData, name, notes, photoAssetIDsData
        case syncStatusRaw, conflictData, friendShareIDsData, privacyLevelRaw
    }

    convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
        disciplineRaw = try container.decode(String.self, forKey: .disciplineRaw)
        sessionType = try container.decode(String.self, forKey: .sessionType)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        distance = try container.decodeIfPresent(Double.self, forKey: .distance)
        averageHeartRate = try container.decodeIfPresent(Int.self, forKey: .averageHeartRate)
        caloriesBurned = try container.decodeIfPresent(Int.self, forKey: .caloriesBurned)
        personalBest = try container.decode(Bool.self, forKey: .personalBest)
        startLatitude = try container.decodeIfPresent(Double.self, forKey: .startLatitude)
        startLongitude = try container.decodeIfPresent(Double.self, forKey: .startLongitude)
        routeData = try container.decodeIfPresent(Data.self, forKey: .routeData)
        disciplineData = try container.decodeIfPresent(Data.self, forKey: .disciplineData)
        name = try container.decode(String.self, forKey: .name)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        photoAssetIDsData = try container.decodeIfPresent(Data.self, forKey: .photoAssetIDsData)
        syncStatusRaw = try container.decode(String.self, forKey: .syncStatusRaw)
        conflictData = try container.decodeIfPresent(Data.self, forKey: .conflictData)
        friendShareIDsData = try container.decodeIfPresent(Data.self, forKey: .friendShareIDsData)
        privacyLevelRaw = try container.decode(String.self, forKey: .privacyLevelRaw)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modifiedAt, forKey: .modifiedAt)
        try container.encode(disciplineRaw, forKey: .disciplineRaw)
        try container.encode(sessionType, forKey: .sessionType)
        try container.encode(startTime, forKey: .startTime)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        try container.encodeIfPresent(distance, forKey: .distance)
        try container.encodeIfPresent(averageHeartRate, forKey: .averageHeartRate)
        try container.encodeIfPresent(caloriesBurned, forKey: .caloriesBurned)
        try container.encode(personalBest, forKey: .personalBest)
        try container.encodeIfPresent(startLatitude, forKey: .startLatitude)
        try container.encodeIfPresent(startLongitude, forKey: .startLongitude)
        try container.encodeIfPresent(routeData, forKey: .routeData)
        try container.encodeIfPresent(disciplineData, forKey: .disciplineData)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(photoAssetIDsData, forKey: .photoAssetIDsData)
        try container.encode(syncStatusRaw, forKey: .syncStatusRaw)
        try container.encodeIfPresent(conflictData, forKey: .conflictData)
        try container.encodeIfPresent(friendShareIDsData, forKey: .friendShareIDsData)
        try container.encode(privacyLevelRaw, forKey: .privacyLevelRaw)
    }
}

// MARK: - SharedCompetition Codable Conformance

extension SharedCompetition: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, date, endDate, location, venue
        case venueLatitude, venueLongitude, competitionType, level
        case primaryOwnerID, ownershipModeRaw, isEntered, entryDeadline, entryFee
        case shootingStartTime, runningStartTime, swimmingStartTime, ridingStartTime
        case isCompleted, resultsData, modifiedAt, modifiedBy, syncStatusRaw
        case linkedArtifactIDsData
    }

    convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        date = try container.decode(Date.self, forKey: .date)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        location = try container.decode(String.self, forKey: .location)
        venue = try container.decode(String.self, forKey: .venue)
        venueLatitude = try container.decodeIfPresent(Double.self, forKey: .venueLatitude)
        venueLongitude = try container.decodeIfPresent(Double.self, forKey: .venueLongitude)
        competitionType = try container.decode(String.self, forKey: .competitionType)
        level = try container.decode(String.self, forKey: .level)
        primaryOwnerID = try container.decode(String.self, forKey: .primaryOwnerID)
        ownershipModeRaw = try container.decode(String.self, forKey: .ownershipModeRaw)
        isEntered = try container.decode(Bool.self, forKey: .isEntered)
        entryDeadline = try container.decodeIfPresent(Date.self, forKey: .entryDeadline)
        entryFee = try container.decodeIfPresent(Double.self, forKey: .entryFee)
        shootingStartTime = try container.decodeIfPresent(Date.self, forKey: .shootingStartTime)
        runningStartTime = try container.decodeIfPresent(Date.self, forKey: .runningStartTime)
        swimmingStartTime = try container.decodeIfPresent(Date.self, forKey: .swimmingStartTime)
        ridingStartTime = try container.decodeIfPresent(Date.self, forKey: .ridingStartTime)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        resultsData = try container.decodeIfPresent(Data.self, forKey: .resultsData)
        modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
        modifiedBy = try container.decode(String.self, forKey: .modifiedBy)
        syncStatusRaw = try container.decode(String.self, forKey: .syncStatusRaw)
        linkedArtifactIDsData = try container.decodeIfPresent(Data.self, forKey: .linkedArtifactIDsData)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encode(location, forKey: .location)
        try container.encode(venue, forKey: .venue)
        try container.encodeIfPresent(venueLatitude, forKey: .venueLatitude)
        try container.encodeIfPresent(venueLongitude, forKey: .venueLongitude)
        try container.encode(competitionType, forKey: .competitionType)
        try container.encode(level, forKey: .level)
        try container.encode(primaryOwnerID, forKey: .primaryOwnerID)
        try container.encode(ownershipModeRaw, forKey: .ownershipModeRaw)
        try container.encode(isEntered, forKey: .isEntered)
        try container.encodeIfPresent(entryDeadline, forKey: .entryDeadline)
        try container.encodeIfPresent(entryFee, forKey: .entryFee)
        try container.encodeIfPresent(shootingStartTime, forKey: .shootingStartTime)
        try container.encodeIfPresent(runningStartTime, forKey: .runningStartTime)
        try container.encodeIfPresent(swimmingStartTime, forKey: .swimmingStartTime)
        try container.encodeIfPresent(ridingStartTime, forKey: .ridingStartTime)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encodeIfPresent(resultsData, forKey: .resultsData)
        try container.encode(modifiedAt, forKey: .modifiedAt)
        try container.encode(modifiedBy, forKey: .modifiedBy)
        try container.encode(syncStatusRaw, forKey: .syncStatusRaw)
        try container.encodeIfPresent(linkedArtifactIDsData, forKey: .linkedArtifactIDsData)
    }
}
