//
//  CloudKitSchemaInitializer.swift
//  TrackRide
//
//  Ensures CloudKit schema exists with all required record types.
//  CloudKit automatically creates schema from records saved in development mode.
//  This service creates "template" records to initialize the schema.
//

import Foundation
import CloudKit
import os

// MARK: - Schema Definition

/// Defines all CloudKit record types and their fields
enum CloudKitSchema {

    // MARK: Record Types

    static let liveTrackingSession = RecordTypeDefinition(
        name: "LiveTrackingSession",
        fields: [
            .string("riderName"),
            .string("riderID"),
            .bool("isActive"),
            .date("startTime"),
            .date("lastUpdateTime"),
            .double("currentLatitude"),
            .double("currentLongitude"),
            .double("currentAltitude"),
            .double("currentSpeed"),
            .string("currentGait"),
            .double("totalDistance"),
            .double("elapsedDuration"),
            .bool("isStationary"),
            .double("stationaryDuration"),
            .data("routePointsData")
        ]
    )

    static let safetyAlert = RecordTypeDefinition(
        name: "SafetyAlert",
        fields: [
            .string("riderName"),
            .string("riderID"),
            .string("alertType"),
            .double("latitude"),
            .double("longitude"),
            .double("stationaryDuration"),
            .date("timestamp"),
            .bool("isResolved"),
            .string("title"),
            .string("message")
        ]
    )

    static let shareConnection = RecordTypeDefinition(
        name: "ShareConnection",
        fields: [
            .string("id"),
            .string("relationshipID"),
            .string("shareType"),
            .string("ownerUserID"),
            .date("createdAt"),
            .date("modifiedAt"),
            .string("shareRecordID")
        ]
    )

    static var allRecordTypes: [RecordTypeDefinition] {
        [liveTrackingSession, safetyAlert, shareConnection]
    }
}

// MARK: - Record Type Definition

struct RecordTypeDefinition {
    let name: String
    let fields: [FieldDefinition]
}

struct FieldDefinition {
    let name: String
    let type: FieldType

    enum FieldType {
        case string
        case double
        case bool
        case date
        case data
        case reference
    }

    static func string(_ name: String) -> FieldDefinition {
        FieldDefinition(name: name, type: .string)
    }

    static func double(_ name: String) -> FieldDefinition {
        FieldDefinition(name: name, type: .double)
    }

    static func bool(_ name: String) -> FieldDefinition {
        FieldDefinition(name: name, type: .bool)
    }

    static func date(_ name: String) -> FieldDefinition {
        FieldDefinition(name: name, type: .date)
    }

    static func data(_ name: String) -> FieldDefinition {
        FieldDefinition(name: name, type: .data)
    }
}

// MARK: - Schema Initializer

actor CloudKitSchemaInitializer {

    private let container: CKContainer
    private let zoneName: String
    private var zoneID: CKRecordZone.ID?

    // Track initialization status
    private var isInitialized = false
    private var initializationErrors: [String] = []

    init(container: CKContainer = .default(), zoneName: String = "FamilySharing") {
        self.container = container
        self.zoneName = zoneName
    }

    // MARK: - Public Interface

    /// Initialize CloudKit schema by creating template records
    /// Call this at app launch to ensure schema exists
    func initializeSchema() async -> SchemaInitializationResult {
        Log.family.info("CloudKitSchemaInitializer: Starting schema initialization")

        initializationErrors = []

        // 1. Check iCloud account status
        let accountStatus = await checkAccountStatus()
        guard accountStatus == .available else {
            let error = "iCloud account not available: \(accountStatus)"
            initializationErrors.append(error)
            return SchemaInitializationResult(
                success: false,
                errors: initializationErrors,
                recordTypesCreated: [],
                zoneCreated: false
            )
        }

        // 2. Ensure zone exists
        let zoneCreated = await ensureZoneExists()

        // 3. Create template records for each record type
        var createdTypes: [String] = []

        for recordType in CloudKitSchema.allRecordTypes {
            let created = await ensureRecordTypeExists(recordType)
            if created {
                createdTypes.append(recordType.name)
            }
        }

        isInitialized = initializationErrors.isEmpty

        let result = SchemaInitializationResult(
            success: isInitialized,
            errors: initializationErrors,
            recordTypesCreated: createdTypes,
            zoneCreated: zoneCreated
        )

        Log.family.info("CloudKitSchemaInitializer: Initialization complete. Success: \(result.success)")

        return result
    }

    /// Validate that schema matches expected definition
    func validateSchema() async -> SchemaValidationResult {
        var validTypes: [String] = []
        var invalidTypes: [String] = []
        var errors: [String] = []

        guard let zoneID = zoneID else {
            return SchemaValidationResult(
                isValid: false,
                validRecordTypes: [],
                invalidRecordTypes: CloudKitSchema.allRecordTypes.map { $0.name },
                errors: ["Zone not initialized"]
            )
        }

        for recordType in CloudKitSchema.allRecordTypes {
            let isValid = await validateRecordType(recordType, zoneID: zoneID)
            if isValid {
                validTypes.append(recordType.name)
            } else {
                invalidTypes.append(recordType.name)
                errors.append("Record type '\(recordType.name)' validation failed")
            }
        }

        return SchemaValidationResult(
            isValid: invalidTypes.isEmpty,
            validRecordTypes: validTypes,
            invalidRecordTypes: invalidTypes,
            errors: errors
        )
    }

    // MARK: - Private Helpers

    private func checkAccountStatus() async -> CKAccountStatus {
        do {
            return try await container.accountStatus()
        } catch {
            Log.family.error("Failed to check account status: \(error)")
            return .couldNotDetermine
        }
    }

    private func ensureZoneExists() async -> Bool {
        let zone = CKRecordZone(zoneName: zoneName)
        zoneID = zone.zoneID

        do {
            _ = try await container.privateCloudDatabase.save(zone)
            Log.family.info("Zone '\(self.zoneName)' created/verified")
            return true
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // Zone might already exist, try to fetch it
            Log.family.debug("Zone might already exist, continuing")
            return false
        } catch {
            Log.family.error("Failed to create zone: \(error)")
            initializationErrors.append("Failed to create zone: \(error.localizedDescription)")
            return false
        }
    }

    private func ensureRecordTypeExists(_ definition: RecordTypeDefinition) async -> Bool {
        guard let zoneID = zoneID else {
            initializationErrors.append("Zone not available for \(definition.name)")
            return false
        }

        // Create a template record with all fields populated
        // CloudKit will create the schema from this record in development mode
        let recordID = CKRecord.ID(
            recordName: "__schema_template_\(definition.name)",
            zoneID: zoneID
        )
        let record = CKRecord(recordType: definition.name, recordID: recordID)

        // Populate all fields with placeholder values
        for field in definition.fields {
            switch field.type {
            case .string:
                record[field.name] = "__template__" as CKRecordValue
            case .double:
                record[field.name] = 0.0 as CKRecordValue
            case .bool:
                record[field.name] = false as CKRecordValue
            case .date:
                record[field.name] = Date() as CKRecordValue
            case .data:
                record[field.name] = Data() as CKRecordValue
            case .reference:
                // Skip references for template
                break
            }
        }

        do {
            // Save to create schema
            _ = try await container.privateCloudDatabase.save(record)

            // Delete the template record (we just needed it to create schema)
            try? await container.privateCloudDatabase.deleteRecord(withID: recordID)

            Log.family.info("Schema created for record type: \(definition.name)")
            return true

        } catch let error as CKError {
            // Handle specific errors
            switch error.code {
            case .serverRejectedRequest:
                // Schema might already exist, which is fine
                Log.family.debug("Record type \(definition.name) may already exist")
                return false
            case .invalidArguments:
                // Field type mismatch - schema exists but is different
                initializationErrors.append("Schema mismatch for \(definition.name): \(error.localizedDescription)")
                return false
            default:
                initializationErrors.append("Failed to create \(definition.name): \(error.localizedDescription)")
                return false
            }
        } catch {
            initializationErrors.append("Failed to create \(definition.name): \(error.localizedDescription)")
            return false
        }
    }

    private func validateRecordType(_ definition: RecordTypeDefinition, zoneID: CKRecordZone.ID) async -> Bool {
        // Try to query for the record type
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: definition.name, predicate: predicate)

        do {
            // Just try to execute the query - if the record type doesn't exist, it will fail
            let (results, _) = try await container.privateCloudDatabase.records(
                matching: query,
                inZoneWith: zoneID,
                resultsLimit: 1
            )

            // Query succeeded, record type exists
            Log.family.debug("Record type \(definition.name) validated")
            return true

        } catch let error as CKError {
            if error.code == .unknownItem {
                Log.family.warning("Record type \(definition.name) does not exist")
                return false
            }
            // Other errors might be permission issues, not schema issues
            Log.family.debug("Query for \(definition.name) returned error (may still be valid): \(error)")
            return true
        } catch {
            Log.family.error("Validation failed for \(definition.name): \(error)")
            return false
        }
    }
}

// MARK: - Result Types

struct SchemaInitializationResult {
    let success: Bool
    let errors: [String]
    let recordTypesCreated: [String]
    let zoneCreated: Bool

    var summary: String {
        if success {
            return "Schema initialized successfully. Created: \(recordTypesCreated.joined(separator: ", "))"
        } else {
            return "Schema initialization failed: \(errors.joined(separator: "; "))"
        }
    }
}

struct SchemaValidationResult {
    let isValid: Bool
    let validRecordTypes: [String]
    let invalidRecordTypes: [String]
    let errors: [String]

    var summary: String {
        if isValid {
            return "All record types valid: \(validRecordTypes.joined(separator: ", "))"
        } else {
            return "Invalid record types: \(invalidRecordTypes.joined(separator: ", ")). Errors: \(errors.joined(separator: "; "))"
        }
    }
}
