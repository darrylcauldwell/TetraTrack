//
//  ShareConnection.swift
//  TetraTrack
//
//  CKRecord wrapper that serves as the root record for CloudKit shares.
//  This fixes the bug where zone-wide shares on empty zones don't generate URLs.
//  Each ShareConnection has a CKShare attached to it for record-level sharing.
//

import Foundation
import CloudKit

// MARK: - Share Type

/// Type of sharing connection
enum ShareType: String, Codable {
    case liveTracking   // Real-time location sharing (family primarily)
    case artifact       // Training session sharing (friends/coaches)
    case competition    // Competition data sharing
}

// MARK: - Share Connection

/// CloudKit record that serves as the root for a CKShare.
/// Each contact gets one ShareConnection record with a share attached.
struct ShareConnection: Identifiable, Codable {
    static let recordType = "ShareConnection"

    // MARK: Identity
    let id: UUID
    let relationshipID: UUID  // Links to SharingRelationship.id
    let shareType: ShareType
    let ownerUserID: String   // CloudKit user ID of the share owner

    // MARK: Timestamps
    let createdAt: Date
    var modifiedAt: Date

    // MARK: CloudKit Reference
    var cloudKitRecordID: String?  // CKRecord.ID.recordName
    var shareRecordID: String?     // CKShare.recordID.recordName
    var shareURL: URL?

    // MARK: Initialization

    init(
        id: UUID = UUID(),
        relationshipID: UUID,
        shareType: ShareType,
        ownerUserID: String
    ) {
        self.id = id
        self.relationshipID = relationshipID
        self.shareType = shareType
        self.ownerUserID = ownerUserID
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    // MARK: - CloudKit Serialization

    /// Convert to CKRecord for saving to CloudKit
    func toCKRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(
            recordName: cloudKitRecordID ?? id.uuidString,
            zoneID: zoneID
        )
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)

        record["id"] = id.uuidString
        record["relationshipID"] = relationshipID.uuidString
        record["shareType"] = shareType.rawValue
        record["ownerUserID"] = ownerUserID
        record["createdAt"] = createdAt
        record["modifiedAt"] = modifiedAt

        return record
    }

    /// Create from CKRecord
    static func from(record: CKRecord) -> ShareConnection? {
        guard
            let idString = record["id"] as? String,
            let id = UUID(uuidString: idString),
            let relationshipIDString = record["relationshipID"] as? String,
            let relationshipID = UUID(uuidString: relationshipIDString),
            let shareTypeRaw = record["shareType"] as? String,
            let shareType = ShareType(rawValue: shareTypeRaw),
            let ownerUserID = record["ownerUserID"] as? String
        else {
            return nil
        }

        var connection = ShareConnection(
            id: id,
            relationshipID: relationshipID,
            shareType: shareType,
            ownerUserID: ownerUserID
        )
        connection.cloudKitRecordID = record.recordID.recordName
        connection.modifiedAt = (record["modifiedAt"] as? Date) ?? Date()

        return connection
    }

    /// Update from CKRecord (preserves local-only fields)
    mutating func update(from record: CKRecord) {
        cloudKitRecordID = record.recordID.recordName
        modifiedAt = (record["modifiedAt"] as? Date) ?? Date()
    }
}

// MARK: - Share Connection Error

enum ShareConnectionError: Error, LocalizedError {
    case notSignedIn
    case zoneNotAvailable
    case shareCreationFailed(underlying: Error)
    case shareNotFound
    case recordNotFound
    case invalidShareURL
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "You must be signed in to iCloud to share."
        case .zoneNotAvailable:
            return "CloudKit zone is not available. Please check your iCloud connection."
        case .shareCreationFailed(let error):
            return "Failed to create share: \(error.localizedDescription)"
        case .shareNotFound:
            return "Share not found. It may have been revoked."
        case .recordNotFound:
            return "Connection record not found."
        case .invalidShareURL:
            return "Invalid share URL."
        case .permissionDenied:
            return "You don't have permission to perform this action."
        }
    }
}
