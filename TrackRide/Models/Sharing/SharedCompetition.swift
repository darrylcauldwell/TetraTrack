//
//  SharedCompetition.swift
//  TrackRide
//
//  Competition sync model with ownership for parent-child sharing.
//

import Foundation
import SwiftData
import CloudKit

// MARK: - Ownership Mode

/// Determines who has edit rights for a shared competition
enum OwnershipMode: String, Codable {
    case parentPrimary      // Parent creates/edits, child views
    case childPrimary       // Child creates/edits, parent views
    case shared             // Both can edit (last-write-wins)
}

// MARK: - Competition Results

/// Results from a completed competition
struct CompetitionResults: Codable {
    var overallPlacing: Int?
    var shootingScore: Int?
    var shootingPoints: Int?
    var swimmingTime: TimeInterval?
    var swimmingPoints: Int?
    var runningTime: TimeInterval?
    var runningPoints: Int?
    var ridingScore: Double?
    var ridingPoints: Int?
    var totalPoints: Int?

    init(
        overallPlacing: Int? = nil,
        shootingScore: Int? = nil,
        shootingPoints: Int? = nil,
        swimmingTime: TimeInterval? = nil,
        swimmingPoints: Int? = nil,
        runningTime: TimeInterval? = nil,
        runningPoints: Int? = nil,
        ridingScore: Double? = nil,
        ridingPoints: Int? = nil,
        totalPoints: Int? = nil
    ) {
        self.overallPlacing = overallPlacing
        self.shootingScore = shootingScore
        self.shootingPoints = shootingPoints
        self.swimmingTime = swimmingTime
        self.swimmingPoints = swimmingPoints
        self.runningTime = runningTime
        self.runningPoints = runningPoints
        self.ridingScore = ridingScore
        self.ridingPoints = ridingPoints
        self.totalPoints = totalPoints
    }
}

// MARK: - Shared Competition

/// CloudKit-compatible competition for sharing between parent and child.
/// Stored in FamilyData zone, ownership determines edit rights.
@Model
final class SharedCompetition {
    // MARK: Identity
    var id: UUID = UUID()
    var name: String = ""
    var date: Date = Date()
    var endDate: Date?

    // MARK: Location
    var location: String = ""
    var venue: String = ""
    var venueLatitude: Double?
    var venueLongitude: Double?

    // MARK: Competition Details
    var competitionType: String = ""    // tetrathlon, triathlon, biathlon
    var level: String = ""              // local, regional, national

    // MARK: Ownership
    var primaryOwnerID: String = ""     // CloudKit user record ID
    var ownershipModeRaw: String = OwnershipMode.shared.rawValue

    // MARK: Entry Details
    var isEntered: Bool = false
    var entryDeadline: Date?
    var entryFee: Double?

    // MARK: Discipline Start Times
    var shootingStartTime: Date?
    var runningStartTime: Date?
    var swimmingStartTime: Date?
    var ridingStartTime: Date?

    // MARK: Status
    var isCompleted: Bool = false
    var resultsData: Data?              // JSON-encoded CompetitionResults

    // MARK: Sync
    var modifiedAt: Date = Date()
    var modifiedBy: String = ""         // Last editor's CloudKit user ID
    var syncStatusRaw: String = SyncStatus.synced.rawValue

    // MARK: Linked Artifacts
    var linkedArtifactIDsData: Data?    // JSON-encoded [UUID]

    // MARK: - Initializers

    init() {}

    init(
        name: String,
        date: Date,
        location: String,
        venue: String,
        competitionType: String,
        level: String,
        ownerID: String
    ) {
        self.id = UUID()
        self.name = name
        self.date = date
        self.location = location
        self.venue = venue
        self.competitionType = competitionType
        self.level = level
        self.primaryOwnerID = ownerID
        self.modifiedAt = Date()
        self.modifiedBy = ownerID
    }

    // MARK: - Computed Properties

    var ownershipMode: OwnershipMode {
        get { OwnershipMode(rawValue: ownershipModeRaw) ?? .shared }
        set { ownershipModeRaw = newValue.rawValue }
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .synced }
        set { syncStatusRaw = newValue.rawValue }
    }

    var results: CompetitionResults? {
        get {
            guard let data = resultsData else { return nil }
            return try? JSONDecoder().decode(CompetitionResults.self, from: data)
        }
        set {
            resultsData = try? JSONEncoder().encode(newValue)
        }
    }

    var linkedArtifactIDs: [UUID] {
        get {
            guard let data = linkedArtifactIDsData else { return [] }
            return (try? JSONDecoder().decode([UUID].self, from: data)) ?? []
        }
        set {
            linkedArtifactIDsData = try? JSONEncoder().encode(newValue)
        }
    }

    var daysUntilCompetition: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let competitionDay = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: today, to: competitionDay).day ?? 0
    }

    var isUpcoming: Bool {
        daysUntilCompetition >= 0 && !isCompleted
    }

    var isPast: Bool {
        daysUntilCompetition < 0 || isCompleted
    }

    // MARK: - Formatted Properties

    var formattedDate: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    var formattedDateRange: String {
        guard let end = endDate, end != date else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
        let startStr = date.formatted(date: .abbreviated, time: .omitted)
        let endStr = end.formatted(date: .abbreviated, time: .omitted)
        return "\(startStr) - \(endStr)"
    }

    var formattedDaysUntil: String {
        let days = daysUntilCompetition
        if days == 0 {
            return "Today"
        } else if days == 1 {
            return "Tomorrow"
        } else if days > 0 {
            return "In \(days) days"
        } else if days == -1 {
            return "Yesterday"
        } else {
            return "\(abs(days)) days ago"
        }
    }

    // MARK: - Permissions

    func canEdit(userID: String) -> Bool {
        switch ownershipMode {
        case .parentPrimary:
            return userID == primaryOwnerID
        case .childPrimary:
            return userID != primaryOwnerID  // Child is non-owner
        case .shared:
            return true
        }
    }

    // MARK: - Modification

    func markModified(by userID: String) {
        modifiedAt = Date()
        modifiedBy = userID
        if syncStatus == .synced {
            syncStatus = .pending
        }
    }

    func linkArtifact(_ artifactID: UUID) {
        var ids = linkedArtifactIDs
        if !ids.contains(artifactID) {
            ids.append(artifactID)
            linkedArtifactIDs = ids
        }
    }

    func unlinkArtifact(_ artifactID: UUID) {
        var ids = linkedArtifactIDs
        ids.removeAll { $0 == artifactID }
        linkedArtifactIDs = ids
    }
}

// MARK: - CloudKit Record Extensions

extension SharedCompetition {
    static let recordType = "SharedCompetition"

    /// Create a CKRecord from this competition
    func toCKRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)

        record["id"] = id.uuidString
        record["name"] = name
        record["date"] = date
        record["endDate"] = endDate
        record["location"] = location
        record["venue"] = venue
        record["venueLatitude"] = venueLatitude
        record["venueLongitude"] = venueLongitude
        record["competitionType"] = competitionType
        record["level"] = level
        record["primaryOwnerID"] = primaryOwnerID
        record["ownershipModeRaw"] = ownershipModeRaw
        record["isEntered"] = isEntered
        record["entryDeadline"] = entryDeadline
        record["entryFee"] = entryFee
        record["shootingStartTime"] = shootingStartTime
        record["runningStartTime"] = runningStartTime
        record["swimmingStartTime"] = swimmingStartTime
        record["ridingStartTime"] = ridingStartTime
        record["isCompleted"] = isCompleted
        record["resultsData"] = resultsData
        record["modifiedAt"] = modifiedAt
        record["modifiedBy"] = modifiedBy
        record["linkedArtifactIDsData"] = linkedArtifactIDsData

        return record
    }

    /// Update this competition from a CKRecord
    func update(from record: CKRecord) {
        if let name = record["name"] as? String {
            self.name = name
        }
        if let date = record["date"] as? Date {
            self.date = date
        }
        endDate = record["endDate"] as? Date
        if let location = record["location"] as? String {
            self.location = location
        }
        if let venue = record["venue"] as? String {
            self.venue = venue
        }
        venueLatitude = record["venueLatitude"] as? Double
        venueLongitude = record["venueLongitude"] as? Double
        if let competitionType = record["competitionType"] as? String {
            self.competitionType = competitionType
        }
        if let level = record["level"] as? String {
            self.level = level
        }
        if let primaryOwnerID = record["primaryOwnerID"] as? String {
            self.primaryOwnerID = primaryOwnerID
        }
        if let ownershipModeRaw = record["ownershipModeRaw"] as? String {
            self.ownershipModeRaw = ownershipModeRaw
        }
        if let isEntered = record["isEntered"] as? Bool {
            self.isEntered = isEntered
        }
        entryDeadline = record["entryDeadline"] as? Date
        entryFee = record["entryFee"] as? Double
        shootingStartTime = record["shootingStartTime"] as? Date
        runningStartTime = record["runningStartTime"] as? Date
        swimmingStartTime = record["swimmingStartTime"] as? Date
        ridingStartTime = record["ridingStartTime"] as? Date
        if let isCompleted = record["isCompleted"] as? Bool {
            self.isCompleted = isCompleted
        }
        resultsData = record["resultsData"] as? Data
        if let modifiedAt = record["modifiedAt"] as? Date {
            self.modifiedAt = modifiedAt
        }
        if let modifiedBy = record["modifiedBy"] as? String {
            self.modifiedBy = modifiedBy
        }
        linkedArtifactIDsData = record["linkedArtifactIDsData"] as? Data
    }

    /// Create a SharedCompetition from a CKRecord
    static func from(record: CKRecord) -> SharedCompetition {
        let competition = SharedCompetition()

        if let idString = record["id"] as? String, let uuid = UUID(uuidString: idString) {
            competition.id = uuid
        }
        competition.update(from: record)
        competition.syncStatus = .synced

        return competition
    }
}
