//
//  SharingRelationshipRepository.swift
//  TrackRide
//
//  SwiftData CRUD operations for sharing relationships.
//  Includes migration from UserDefaults-based TrustedContact storage.
//

import Foundation
import SwiftData
import os

// MARK: - Sharing Relationship Repository

@MainActor
final class SharingRelationshipRepository {
    private var modelContext: ModelContext?

    // UserDefaults keys for migration
    private let trustedContactsKey = "trustedContacts"
    private let linkedRidersKey = "linkedRiders"
    private let pendingRequestsKey = "pendingShareRequests"
    private let migrationCompletedKey = "sharingRelationshipMigrationCompleted"

    init() {}

    /// Configure with a ModelContext
    func configure(with context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Relationship CRUD

    /// Fetch all sharing relationships
    func fetchAll() throws -> [SharingRelationship] {
        guard let context = modelContext else {
            Log.family.error("SharingRelationshipRepository: ModelContext not configured")
            return []
        }

        let descriptor = FetchDescriptor<SharingRelationship>(
            sortBy: [SortDescriptor(\.addedDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Fetch relationships by type
    func fetch(type: RelationshipType) throws -> [SharingRelationship] {
        guard let context = modelContext else { return [] }

        let typeRaw = type.rawValue
        let predicate = #Predicate<SharingRelationship> { $0.relationshipTypeRaw == typeRaw }
        let descriptor = FetchDescriptor<SharingRelationship>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.addedDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Fetch family members (contacts with emergency/safety permissions)
    func fetchFamilyMembers() throws -> [SharingRelationship] {
        guard let context = modelContext else { return [] }

        let predicate = #Predicate<SharingRelationship> {
            $0.isEmergencyContact || $0.receiveFallAlerts || $0.receiveStationaryAlerts
        }
        let descriptor = FetchDescriptor<SharingRelationship>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.addedDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Fetch emergency contacts
    func fetchEmergencyContacts() throws -> [SharingRelationship] {
        guard let context = modelContext else { return [] }

        let predicate = #Predicate<SharingRelationship> { $0.isEmergencyContact }
        var descriptor = FetchDescriptor<SharingRelationship>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.name)]
        let contacts = try context.fetch(descriptor)

        // Sort with primary emergency contacts first
        return contacts.sorted { $0.isPrimaryEmergency && !$1.isPrimaryEmergency }
    }

    /// Get primary emergency contact
    func fetchPrimaryEmergencyContact() throws -> SharingRelationship? {
        guard let context = modelContext else { return nil }

        let predicate = #Predicate<SharingRelationship> { $0.isPrimaryEmergency && $0.isEmergencyContact }
        var descriptor = FetchDescriptor<SharingRelationship>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Fetch relationship by ID
    func fetch(id: UUID) throws -> SharingRelationship? {
        guard let context = modelContext else { return nil }

        let predicate = #Predicate<SharingRelationship> { $0.id == id }
        var descriptor = FetchDescriptor<SharingRelationship>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Check if a relationship with the same name already exists
    func hasExistingRelationship(name: String) throws -> Bool {
        guard let context = modelContext else { return false }

        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let descriptor = FetchDescriptor<SharingRelationship>()
        let all = try context.fetch(descriptor)

        return all.contains { existing in
            existing.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedName
        }
    }

    /// Check if a relationship with the same email or phone already exists
    func hasExistingRelationship(email: String?, phoneNumber: String?) throws -> Bool {
        guard let context = modelContext else { return false }

        let descriptor = FetchDescriptor<SharingRelationship>()
        let all = try context.fetch(descriptor)

        return all.contains { existing in
            // Check email match
            if let email = email, !email.isEmpty,
               let existingEmail = existing.email, !existingEmail.isEmpty {
                if email.lowercased() == existingEmail.lowercased() {
                    return true
                }
            }

            // Check phone match
            if let phone = phoneNumber, !phone.isEmpty,
               let existingPhone = existing.phoneNumber, !existingPhone.isEmpty {
                // Normalize phone numbers for comparison (remove spaces, dashes, etc.)
                let normalizedPhone = phone.filter { $0.isNumber }
                let normalizedExisting = existingPhone.filter { $0.isNumber }
                if normalizedPhone == normalizedExisting && !normalizedPhone.isEmpty {
                    return true
                }
            }

            return false
        }
    }

    /// Create a new relationship
    /// - Parameters:
    ///   - name: Contact name
    ///   - type: Relationship type
    ///   - email: Optional email address
    ///   - phoneNumber: Optional phone number
    ///   - preset: Permission preset to apply
    ///   - allowDuplicates: If false, returns nil if duplicate exists
    /// - Returns: The new relationship, or nil if duplicate found and not allowed
    func create(
        name: String,
        type: RelationshipType,
        email: String? = nil,
        phoneNumber: String? = nil,
        preset: PermissionPreset? = nil,
        allowDuplicates: Bool = false
    ) -> SharingRelationship? {
        guard let context = modelContext else {
            Log.family.error("SharingRelationshipRepository: ModelContext not configured")
            return nil
        }

        // Check for duplicates if not allowed
        if !allowDuplicates {
            do {
                if try hasExistingRelationship(name: name) {
                    Log.family.warning("Duplicate relationship name '\(name)' - skipping creation")
                    return nil
                }
                if try hasExistingRelationship(email: email, phoneNumber: phoneNumber) {
                    Log.family.warning("Duplicate relationship with same email/phone - skipping creation")
                    return nil
                }
            } catch {
                Log.family.error("Failed to check for duplicates: \(error)")
                // Continue with creation if check fails
            }
        }

        let relationship = SharingRelationship(name: name, relationshipType: type)
        relationship.email = email
        relationship.phoneNumber = phoneNumber

        // Apply preset if provided
        if let preset = preset {
            relationship.applyPreset(preset)
        } else {
            // Apply default permissions based on type
            switch type {
            case .familyMember:
                relationship.applyPreset(.fullAccess)
            case .coach:
                relationship.applyPreset(.coachMode)
            case .friend:
                relationship.applyPreset(.summariesOnly)
            }
        }

        context.insert(relationship)

        // Save immediately
        do {
            try context.save()
        } catch {
            Log.family.error("Failed to save new relationship: \(error)")
        }

        return relationship
    }

    /// Update an existing relationship
    func update(_ relationship: SharingRelationship) {
        // SwiftData automatically tracks changes
        // Just ensure we save if needed
        try? modelContext?.save()
    }

    /// Delete a relationship
    func delete(_ relationship: SharingRelationship) {
        guard let context = modelContext else { return }
        context.delete(relationship)

        // Save the deletion
        do {
            try context.save()
        } catch {
            Log.family.error("Failed to save after deleting relationship: \(error)")
        }
    }

    /// Delete by ID
    func delete(id: UUID) throws {
        if let relationship = try fetch(id: id) {
            delete(relationship)
        }
    }

    /// Set a relationship as the primary emergency contact
    func setPrimaryEmergencyContact(_ relationship: SharingRelationship) throws {
        guard let context = modelContext else { return }

        // Clear existing primary
        let allEmergency = try fetchEmergencyContacts()
        for contact in allEmergency {
            contact.isPrimaryEmergency = false
        }

        // Set new primary
        relationship.isPrimaryEmergency = true
        try context.save()
    }

    // MARK: - Pending Request CRUD

    /// Fetch all pending share requests
    func fetchPendingRequests() throws -> [PendingShareRequest] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<PendingShareRequest>(
            sortBy: [SortDescriptor(\.receivedDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Create a pending request
    func createPendingRequest(
        ownerID: String,
        ownerName: String,
        shareURL: URL?
    ) -> PendingShareRequest {
        guard let context = modelContext else {
            fatalError("SharingRelationshipRepository: ModelContext not configured")
        }

        let request = PendingShareRequest(
            ownerID: ownerID,
            ownerName: ownerName,
            shareURL: shareURL
        )
        context.insert(request)

        // CRITICAL: Save immediately so pending request persists across app restarts
        do {
            try context.save()
        } catch {
            Log.family.error("Failed to save pending request: \(error)")
        }

        return request
    }

    /// Delete a pending request
    func deletePendingRequest(_ request: PendingShareRequest) {
        guard let context = modelContext else { return }
        context.delete(request)

        // Save the deletion
        do {
            try context.save()
        } catch {
            Log.family.error("Failed to save after deleting pending request: \(error)")
        }
    }

    /// Check if a pending request already exists from this owner
    func hasPendingRequest(fromOwnerID ownerID: String) throws -> Bool {
        guard let context = modelContext else { return false }

        let predicate = #Predicate<PendingShareRequest> { $0.ownerID == ownerID }
        var descriptor = FetchDescriptor<PendingShareRequest>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first != nil
    }

    // MARK: - Migration from UserDefaults

    /// Check if migration has already been completed
    var isMigrationCompleted: Bool {
        UserDefaults.standard.bool(forKey: migrationCompletedKey)
    }

    /// Migrate legacy TrustedContact data from UserDefaults
    func migrateFromUserDefaults() throws {
        guard let context = modelContext else {
            Log.family.error("Cannot migrate: ModelContext not configured")
            return
        }

        guard !isMigrationCompleted else {
            Log.family.debug("Migration already completed, skipping")
            return
        }

        Log.family.info("Starting migration from UserDefaults...")

        // Migrate TrustedContacts (doesn't delete source yet)
        let migratedContacts = migrateTrustedContactsSafely(context: context)

        // Migrate pending share requests (doesn't delete source yet)
        let migratedRequests = migratePendingRequestsSafely(context: context)

        // Save all changes - MUST succeed before deleting source data
        do {
            try context.save()

            // Only delete source data AFTER successful save
            if migratedContacts > 0 {
                UserDefaults.standard.removeObject(forKey: trustedContactsKey)
                Log.family.info("Migrated \(migratedContacts) trusted contacts")
            }
            if migratedRequests > 0 {
                UserDefaults.standard.removeObject(forKey: pendingRequestsKey)
                Log.family.info("Migrated \(migratedRequests) pending requests")
            }

            // Mark migration as complete
            UserDefaults.standard.set(true, forKey: migrationCompletedKey)
            Log.family.info("Migration from UserDefaults completed")

        } catch {
            // Save failed - do NOT delete source data so we can retry
            Log.family.error("Migration save failed, source data preserved: \(error)")
            throw error
        }
    }

    /// Migrate trusted contacts without deleting source data
    /// Returns the number of contacts migrated
    private func migrateTrustedContactsSafely(context: ModelContext) -> Int {
        guard let data = UserDefaults.standard.data(forKey: trustedContactsKey) else {
            Log.family.debug("No trusted contacts to migrate")
            return 0
        }

        // Decode legacy TrustedContact struct
        guard let contacts = try? JSONDecoder().decode([LegacyTrustedContact].self, from: data) else {
            Log.family.error("Failed to decode legacy trusted contacts")
            return 0
        }

        for legacy in contacts {
            let relationship = SharingRelationship(name: legacy.name, relationshipType: .familyMember)
            relationship.phoneNumber = legacy.phoneNumber
            relationship.email = legacy.email

            // Map permissions
            relationship.canViewLiveRiding = legacy.canViewLiveTracking
            relationship.receiveFallAlerts = legacy.receiveFallAlerts
            relationship.receiveStationaryAlerts = legacy.receiveStationaryAlerts
            relationship.isEmergencyContact = legacy.isEmergencyContact
            relationship.isPrimaryEmergency = legacy.isPrimaryEmergency

            // Map invite status
            relationship.inviteStatus = legacy.inviteStatus
            relationship.inviteSentDate = legacy.inviteSentDate
            relationship.lastReminderDate = legacy.lastReminderDate
            relationship.reminderCount = legacy.reminderCount

            // Map medical notes
            relationship.medicalNotes = legacy.medicalNotes

            // Map share URL
            relationship.shareURLValue = legacy.cloudKitShareURL

            context.insert(relationship)
            Log.family.debug("Migrated contact: \(legacy.name)")
        }

        // DO NOT delete source data here - let caller do it after save succeeds
        return contacts.count
    }

    /// Migrate pending requests without deleting source data
    /// Returns the number of requests migrated
    private func migratePendingRequestsSafely(context: ModelContext) -> Int {
        guard let data = UserDefaults.standard.data(forKey: pendingRequestsKey) else {
            Log.family.debug("No pending requests to migrate")
            return 0
        }

        guard let requests = try? JSONDecoder().decode([LegacyPendingRequest].self, from: data) else {
            Log.family.error("Failed to decode legacy pending requests")
            return 0
        }

        for legacy in requests {
            let request = PendingShareRequest(
                ownerID: legacy.ownerID,
                ownerName: legacy.ownerName,
                shareURL: legacy.shareURL
            )
            request.receivedDate = legacy.receivedDate
            context.insert(request)
        }

        // DO NOT delete source data here - let caller do it after save succeeds
        return requests.count
    }
}

// MARK: - Legacy Data Structures (for migration)

/// Legacy TrustedContact structure for migration
private struct LegacyTrustedContact: Codable {
    let id: UUID
    var name: String
    var phoneNumber: String
    var email: String?
    var canViewLiveTracking: Bool
    var receiveFallAlerts: Bool
    var receiveStationaryAlerts: Bool
    var isEmergencyContact: Bool
    var isPrimaryEmergency: Bool
    var inviteStatus: InviteStatus
    var inviteSentDate: Date?
    var lastReminderDate: Date?
    var reminderCount: Int
    var medicalNotes: String?
    var cloudKitShareURL: URL?
}

/// Legacy PendingShareRequest structure for migration
private struct LegacyPendingRequest: Codable {
    let id: UUID
    var ownerID: String
    var ownerName: String
    var shareURL: URL?
    var receivedDate: Date
}
