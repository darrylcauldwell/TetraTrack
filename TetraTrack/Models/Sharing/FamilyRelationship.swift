//
//  FamilyRelationship.swift
//  TetraTrack
//
//  CloudKit-backed parent-child relationship model.
//  Stored in child's private database, shared with parent via zone share.
//  Enables automatic relationship discovery across all parent devices.
//

import Foundation
import CloudKit

// MARK: - Relationship Status

/// Status of the family relationship
enum FamilyRelationshipStatus: String, Codable, Sendable {
    case pending    // Invitation sent, not yet accepted
    case active     // Both parties connected
    case revoked    // Relationship ended
}

// MARK: - Family Relationship

/// Represents a parent-child relationship for data sharing.
/// Stored as a CloudKit record in the FamilySharing zone.
struct FamilyRelationship: Codable, Identifiable, Sendable {

    // MARK: - CloudKit Constants

    static let recordType = "FamilyRelationship"

    enum FieldKey {
        static let parentUserID = "parentUserID"
        static let childUserID = "childUserID"
        static let childName = "childName"
        static let parentName = "parentName"
        static let status = "status"
        static let createdAt = "createdAt"
        static let createdBy = "createdBy"
        static let modifiedAt = "modifiedAt"
    }

    // MARK: - Properties

    /// Unique identifier
    let id: UUID

    /// CloudKit user record ID of the parent
    let parentUserID: String

    /// CloudKit user record ID of the child (athlete)
    let childUserID: String

    /// Display name of the child
    var childName: String

    /// Display name of the parent
    var parentName: String

    /// Current status of the relationship
    var status: FamilyRelationshipStatus

    /// When the relationship was created
    let createdAt: Date

    /// Who created the relationship (child or parent user ID)
    let createdBy: String

    /// Last modification timestamp
    var modifiedAt: Date

    /// CloudKit record ID (for updates)
    var cloudKitRecordID: String?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        parentUserID: String,
        childUserID: String,
        childName: String,
        parentName: String,
        status: FamilyRelationshipStatus = .pending,
        createdAt: Date = Date(),
        createdBy: String,
        modifiedAt: Date = Date(),
        cloudKitRecordID: String? = nil
    ) {
        self.id = id
        self.parentUserID = parentUserID
        self.childUserID = childUserID
        self.childName = childName
        self.parentName = parentName
        self.status = status
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.modifiedAt = modifiedAt
        self.cloudKitRecordID = cloudKitRecordID
    }

    // MARK: - Computed Properties

    /// Whether this relationship is currently active
    var isActive: Bool {
        status == .active
    }

    /// Whether the current user is the parent in this relationship
    func isParent(currentUserID: String) -> Bool {
        parentUserID == currentUserID
    }

    /// Whether the current user is the child in this relationship
    func isChild(currentUserID: String) -> Bool {
        childUserID == currentUserID
    }

    // MARK: - CloudKit Conversion

    /// Creates a CloudKit record from this relationship
    func toCKRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID: CKRecord.ID
        if let existingID = cloudKitRecordID {
            recordID = CKRecord.ID(recordName: existingID, zoneID: zoneID)
        } else {
            recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        }

        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        record[FieldKey.parentUserID] = parentUserID
        record[FieldKey.childUserID] = childUserID
        record[FieldKey.childName] = childName
        record[FieldKey.parentName] = parentName
        record[FieldKey.status] = status.rawValue
        record[FieldKey.createdAt] = createdAt
        record[FieldKey.createdBy] = createdBy
        record[FieldKey.modifiedAt] = modifiedAt

        return record
    }

    /// Creates a FamilyRelationship from a CloudKit record
    static func from(record: CKRecord) -> FamilyRelationship? {
        guard record.recordType == recordType,
              let parentUserID = record[FieldKey.parentUserID] as? String,
              let childUserID = record[FieldKey.childUserID] as? String,
              let childName = record[FieldKey.childName] as? String,
              let statusRaw = record[FieldKey.status] as? String,
              let status = FamilyRelationshipStatus(rawValue: statusRaw),
              let createdAt = record[FieldKey.createdAt] as? Date,
              let createdBy = record[FieldKey.createdBy] as? String else {
            return nil
        }

        let parentName = record[FieldKey.parentName] as? String ?? "Parent"
        let modifiedAt = record[FieldKey.modifiedAt] as? Date ?? createdAt

        // Extract UUID from record name
        let idString = record.recordID.recordName
        let id = UUID(uuidString: idString) ?? UUID()

        return FamilyRelationship(
            id: id,
            parentUserID: parentUserID,
            childUserID: childUserID,
            childName: childName,
            parentName: parentName,
            status: status,
            createdAt: createdAt,
            createdBy: createdBy,
            modifiedAt: modifiedAt,
            cloudKitRecordID: record.recordID.recordName
        )
    }

    /// Updates this relationship from a CloudKit record
    mutating func update(from record: CKRecord) {
        if let childName = record[FieldKey.childName] as? String {
            self.childName = childName
        }
        if let parentName = record[FieldKey.parentName] as? String {
            self.parentName = parentName
        }
        if let statusRaw = record[FieldKey.status] as? String,
           let status = FamilyRelationshipStatus(rawValue: statusRaw) {
            self.status = status
        }
        if let modifiedAt = record[FieldKey.modifiedAt] as? Date {
            self.modifiedAt = modifiedAt
        }
        self.cloudKitRecordID = record.recordID.recordName
    }
}

// MARK: - Local Cache

extension FamilyRelationship {
    private static let cacheKey = "dev.dreamfold.tetratrack.familyRelationship"

    /// Saves the relationship to local cache for offline access
    func saveToCache() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.cacheKey)
    }

    /// Loads the cached relationship (for offline startup)
    static func loadFromCache() -> FamilyRelationship? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let relationship = try? JSONDecoder().decode(FamilyRelationship.self, from: data) else {
            return nil
        }
        return relationship
    }

    /// Clears the cached relationship
    static func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }
}
