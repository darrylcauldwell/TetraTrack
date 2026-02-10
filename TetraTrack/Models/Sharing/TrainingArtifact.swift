//
//  TrainingArtifact.swift
//  TetraTrack
//
//  Discipline-agnostic training artifact for CloudKit sharing between parent and child.
//

import Foundation
import SwiftData
import CloudKit
import CoreLocation

// MARK: - Sync Status

/// Synchronization status for CloudKit operations
enum SyncStatus: String, Codable {
    case pending    // Not yet synced to CloudKit
    case syncing    // Currently uploading
    case synced     // Successfully synced
    case conflict   // Requires manual resolution
}

// MARK: - Privacy Level

/// Privacy level for friend/coach sharing
enum PrivacyLevel: String, Codable {
    case `private`      // Owner only
    case summaryOnly    // Duration, distance, completion status
    case full           // All metrics including discipline-specific
}

// MARK: - Training Artifact

/// CloudKit-compatible training artifact for all disciplines.
/// Stored in child's private database FamilyData zone, shared with parent via CKShare.
@Model
final class TrainingArtifact {
    // MARK: Identity
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    // MARK: Discipline
    var disciplineRaw: String = TrainingDiscipline.riding.rawValue
    var sessionType: String = "training"  // freePractice, competition, training

    // MARK: Timing
    var startTime: Date = Date()
    var endTime: Date?

    // MARK: Common Metrics
    var distance: Double?               // meters (nil for shooting)
    var averageHeartRate: Int?
    var caloriesBurned: Int?
    var personalBest: Bool = false

    // MARK: Location
    var startLatitude: Double?
    var startLongitude: Double?
    var routeData: Data?                // Encoded [RoutePoint] for map display

    // MARK: Discipline-Specific Payload
    var disciplineData: Data?           // JSON-encoded discipline-specific data

    // MARK: Notes & Media
    var name: String = ""
    var notes: String?
    var photoAssetIDsData: Data?        // JSON-encoded [String] PHAsset identifiers

    // MARK: Sync
    var syncStatusRaw: String = SyncStatus.synced.rawValue
    var conflictData: Data?             // For conflict resolution UI

    // MARK: Friend Sharing
    var friendShareIDsData: Data?       // JSON-encoded [String] CKShare record IDs
    var privacyLevelRaw: String = PrivacyLevel.summaryOnly.rawValue

    // MARK: - Initializers

    init() {}

    init(
        discipline: TrainingDiscipline,
        sessionType: String,
        name: String,
        startTime: Date
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.disciplineRaw = discipline.rawValue
        self.sessionType = sessionType
        self.name = name
        self.startTime = startTime
    }

    // MARK: - Computed Properties

    var discipline: TrainingDiscipline {
        get { TrainingDiscipline(rawValue: disciplineRaw) ?? .riding }
        set { disciplineRaw = newValue.rawValue }
    }

    var duration: TimeInterval {
        endTime?.timeIntervalSince(startTime) ?? 0
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .synced }
        set { syncStatusRaw = newValue.rawValue }
    }

    var privacyLevel: PrivacyLevel {
        get { PrivacyLevel(rawValue: privacyLevelRaw) ?? .summaryOnly }
        set { privacyLevelRaw = newValue.rawValue }
    }

    var photoAssetIDs: [String] {
        get {
            guard let data = photoAssetIDsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            photoAssetIDsData = try? JSONEncoder().encode(newValue)
        }
    }

    var friendShareIDs: [String] {
        get {
            guard let data = friendShareIDsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            friendShareIDsData = try? JSONEncoder().encode(newValue)
        }
    }

    var startCoordinate: CLLocationCoordinate2D? {
        guard let lat = startLatitude, let lon = startLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var isCompleted: Bool {
        endTime != nil
    }

    // MARK: - Formatted Properties

    var formattedDistance: String {
        guard let d = distance else { return "--" }
        return d.formattedDistance
    }

    var formattedDuration: String {
        duration.formattedDuration
    }

    var formattedDate: String {
        startTime.formatted(date: .abbreviated, time: .shortened)
    }

    // MARK: - Discipline Data Helpers

    func setRidingData(_ data: RidingArtifactData) {
        disciplineData = try? JSONEncoder().encode(data)
    }

    func getRidingData() -> RidingArtifactData? {
        guard let data = disciplineData else { return nil }
        return try? JSONDecoder().decode(RidingArtifactData.self, from: data)
    }

    func setRunningData(_ data: RunningArtifactData) {
        disciplineData = try? JSONEncoder().encode(data)
    }

    func getRunningData() -> RunningArtifactData? {
        guard let data = disciplineData else { return nil }
        return try? JSONDecoder().decode(RunningArtifactData.self, from: data)
    }

    func setSwimmingData(_ data: SwimmingArtifactData) {
        disciplineData = try? JSONEncoder().encode(data)
    }

    func getSwimmingData() -> SwimmingArtifactData? {
        guard let data = disciplineData else { return nil }
        return try? JSONDecoder().decode(SwimmingArtifactData.self, from: data)
    }

    func setShootingData(_ data: ShootingArtifactData) {
        disciplineData = try? JSONEncoder().encode(data)
    }

    func getShootingData() -> ShootingArtifactData? {
        guard let data = disciplineData else { return nil }
        return try? JSONDecoder().decode(ShootingArtifactData.self, from: data)
    }

    // MARK: - Sync Helpers

    func markModified() {
        modifiedAt = Date()
        if syncStatus == .synced {
            syncStatus = .pending
        }
    }

    func markSynced() {
        syncStatus = .synced
    }

    func markConflict(serverData: Data) {
        syncStatus = .conflict
        conflictData = serverData
    }
}

// MARK: - Discipline-Specific Payloads

/// Riding-specific artifact data
struct RidingArtifactData: Codable {
    var gaitDurations: [String: TimeInterval]   // walk, trot, canter, gallop
    var leftLeadDuration: TimeInterval?
    var rightLeadDuration: TimeInterval?
    var averageSpeed: Double                    // m/s
    var maxSpeed: Double                        // m/s
    var elevationGain: Double                   // meters
    var turnCount: Int
    var horseName: String?

    init(
        gaitDurations: [String: TimeInterval] = [:],
        leftLeadDuration: TimeInterval? = nil,
        rightLeadDuration: TimeInterval? = nil,
        averageSpeed: Double = 0,
        maxSpeed: Double = 0,
        elevationGain: Double = 0,
        turnCount: Int = 0,
        horseName: String? = nil
    ) {
        self.gaitDurations = gaitDurations
        self.leftLeadDuration = leftLeadDuration
        self.rightLeadDuration = rightLeadDuration
        self.averageSpeed = averageSpeed
        self.maxSpeed = maxSpeed
        self.elevationGain = elevationGain
        self.turnCount = turnCount
        self.horseName = horseName
    }
}

/// Running-specific artifact data
struct RunningArtifactData: Codable {
    var averagePace: TimeInterval           // seconds per km
    var averageCadence: Int                 // steps per minute
    var elevationGain: Double               // meters
    var splits: [SplitSummary]              // Simplified split data
    var runMode: String                     // outdoor, treadmill, track

    init(
        averagePace: TimeInterval = 0,
        averageCadence: Int = 0,
        elevationGain: Double = 0,
        splits: [SplitSummary] = [],
        runMode: String = "outdoor"
    ) {
        self.averagePace = averagePace
        self.averageCadence = averageCadence
        self.elevationGain = elevationGain
        self.splits = splits
        self.runMode = runMode
    }
}

/// Split summary for running
struct SplitSummary: Codable, Identifiable {
    var id: UUID = UUID()
    var distance: Double                    // meters
    var duration: TimeInterval              // seconds
    var pace: TimeInterval                  // seconds per km

    init(distance: Double = 0, duration: TimeInterval = 0, pace: TimeInterval = 0) {
        self.distance = distance
        self.duration = duration
        self.pace = pace
    }
}

/// Swimming-specific artifact data
struct SwimmingArtifactData: Codable {
    var averagePace: TimeInterval           // seconds per 100m
    var averageSwolf: Double                // strokes + seconds per lap
    var totalStrokes: Int
    var lapCount: Int
    var dominantStroke: String              // freestyle, breaststroke, etc.
    var poolLength: Double?                 // meters (nil for open water)

    init(
        averagePace: TimeInterval = 0,
        averageSwolf: Double = 0,
        totalStrokes: Int = 0,
        lapCount: Int = 0,
        dominantStroke: String = "freestyle",
        poolLength: Double? = nil
    ) {
        self.averagePace = averagePace
        self.averageSwolf = averageSwolf
        self.totalStrokes = totalStrokes
        self.lapCount = lapCount
        self.dominantStroke = dominantStroke
        self.poolLength = poolLength
    }
}

/// Shooting-specific artifact data
struct ShootingArtifactData: Codable {
    var totalScore: Int
    var maxPossibleScore: Int
    var shotCount: Int
    var averageScore: Double
    var groupRadius: Double?                // Pattern analysis (normalized)
    var shootingSessionType: String         // freePractice, tetrathlon, competition

    init(
        totalScore: Int = 0,
        maxPossibleScore: Int = 0,
        shotCount: Int = 0,
        averageScore: Double = 0,
        groupRadius: Double? = nil,
        shootingSessionType: String = "freePractice"
    ) {
        self.totalScore = totalScore
        self.maxPossibleScore = maxPossibleScore
        self.shotCount = shotCount
        self.averageScore = averageScore
        self.groupRadius = groupRadius
        self.shootingSessionType = shootingSessionType
    }
}

// MARK: - CloudKit Record Extensions

extension TrainingArtifact {
    static let recordType = "TrainingArtifact"

    /// Create a CKRecord from this artifact
    func toCKRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)

        record["id"] = id.uuidString
        record["createdAt"] = createdAt
        record["modifiedAt"] = modifiedAt
        record["disciplineRaw"] = disciplineRaw
        record["sessionType"] = sessionType
        record["startTime"] = startTime
        record["endTime"] = endTime
        record["distance"] = distance
        record["averageHeartRate"] = averageHeartRate
        record["caloriesBurned"] = caloriesBurned
        record["personalBest"] = personalBest
        record["startLatitude"] = startLatitude
        record["startLongitude"] = startLongitude
        record["routeData"] = routeData
        record["disciplineData"] = disciplineData
        record["name"] = name
        record["notes"] = notes
        record["photoAssetIDsData"] = photoAssetIDsData
        record["friendShareIDsData"] = friendShareIDsData
        record["privacyLevelRaw"] = privacyLevelRaw

        return record
    }

    /// Update this artifact from a CKRecord
    func update(from record: CKRecord) {
        if let idString = record["id"] as? String, let uuid = UUID(uuidString: idString) {
            // ID should match, but verify
            assert(uuid == id, "CKRecord ID mismatch")
        }

        if let createdAt = record["createdAt"] as? Date {
            self.createdAt = createdAt
        }
        if let modifiedAt = record["modifiedAt"] as? Date {
            self.modifiedAt = modifiedAt
        }
        if let disciplineRaw = record["disciplineRaw"] as? String {
            self.disciplineRaw = disciplineRaw
        }
        if let sessionType = record["sessionType"] as? String {
            self.sessionType = sessionType
        }
        if let startTime = record["startTime"] as? Date {
            self.startTime = startTime
        }
        endTime = record["endTime"] as? Date
        distance = record["distance"] as? Double
        averageHeartRate = record["averageHeartRate"] as? Int
        caloriesBurned = record["caloriesBurned"] as? Int
        if let personalBest = record["personalBest"] as? Bool {
            self.personalBest = personalBest
        }
        startLatitude = record["startLatitude"] as? Double
        startLongitude = record["startLongitude"] as? Double
        routeData = record["routeData"] as? Data
        disciplineData = record["disciplineData"] as? Data
        if let name = record["name"] as? String {
            self.name = name
        }
        notes = record["notes"] as? String
        photoAssetIDsData = record["photoAssetIDsData"] as? Data
        friendShareIDsData = record["friendShareIDsData"] as? Data
        if let privacyLevelRaw = record["privacyLevelRaw"] as? String {
            self.privacyLevelRaw = privacyLevelRaw
        }
    }

    /// Create a TrainingArtifact from a CKRecord
    static func from(record: CKRecord) -> TrainingArtifact {
        let artifact = TrainingArtifact()

        if let idString = record["id"] as? String, let uuid = UUID(uuidString: idString) {
            artifact.id = uuid
        }
        artifact.update(from: record)
        artifact.syncStatus = .synced

        return artifact
    }
}
