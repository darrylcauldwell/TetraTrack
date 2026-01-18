//
//  FamilySharingManager.swift
//  TrackRide
//

import CloudKit
import SwiftData
import Observation
import CoreLocation
import UIKit
import os

@Observable
final class FamilySharingManager: FamilySharing {
    static let shared = FamilySharingManager()

    // State
    var isSignedIn: Bool = false
    var isCloudKitAvailable: Bool = false
    var currentUserID: String = ""
    var currentUserName: String = ""
    var sharedWithMe: [LiveTrackingSession] = []  // Active sessions shared by family members
    var mySession: LiveTrackingSession?  // My current session being shared
    var linkedRiders: [LinkedRider] = []  // People who share their rides with you (always visible)

    // CloudKit-backed family relationship (replaces UserDefaults discovery)
    private(set) var familyRelationship: FamilyRelationship?
    private(set) var isLoadingRelationship: Bool = false
    private(set) var relationshipError: String?

    // Alert tracking
    private var sentWarningAlerts: Set<String> = []  // Rider IDs we've warned about
    private var sentUrgentAlerts: Set<String> = []   // Rider IDs we've sent urgent alerts for

    // CloudKit enabled - iCloud entitlement configured in TrackRide.entitlements
    // Container: iCloud.MyHorse.TrackRide
    private let cloudKitEnabled = true

    // Local trusted contacts (stored separately from CloudKit shares)
    private var localContacts: [TrustedContact] = []
    private let contactsKey = "trustedContacts"
    private let linkedRidersKey = "linkedRiders"
    private let pendingRequestsKey = "pendingShareRequests"

    // Pending share requests (requests received but not yet accepted)
    private(set) var pendingRequests: [PendingShareRequest] = []

    private var container: CKContainer? {
        guard cloudKitEnabled else { return nil }
        return CKContainer.default()
    }

    private var privateDatabase: CKDatabase? {
        container?.privateCloudDatabase
    }

    private var sharedDatabase: CKDatabase? {
        container?.sharedCloudDatabase
    }

    private let liveTrackingRecordType = "LiveTrackingSession"
    private let familyZoneName = "FamilySharing"
    private var familyZoneID: CKRecordZone.ID?
    private var subscription: CKSubscription?

    private let notificationManager = NotificationManager.shared

    private init() {
        // CloudKit is initialized lazily - nothing to do here
    }

    // MARK: - Setup

    func setup() async {
        // Early exit if CloudKit is disabled - don't even attempt to check status
        guard cloudKitEnabled else {
            Log.family.debug("CloudKit disabled - skipping setup")
            return
        }
        await checkiCloudStatus()
        if isCloudKitAvailable {
            await setupFamilyZone()
            await subscribeToChanges()
            await discoverFamilyRelationship()
        }
    }

    private func checkiCloudStatus() async {
        guard let container = container else {
            Log.family.debug("CloudKit container not available")
            return
        }

        do {
            let status = try await container.accountStatus()
            await MainActor.run {
                self.isCloudKitAvailable = true
                self.isSignedIn = (status == .available)
            }

            if isSignedIn {
                let userID = try await container.userRecordID()
                await MainActor.run {
                    self.currentUserID = userID.recordName
                }

                // Try to get user's name (deprecated API, but no replacement available)
                // Use device name as fallback since CloudKit sharing APIs have changed
                await MainActor.run {
                    self.currentUserName = UIDevice.current.name
                }
            }
        } catch {
            Log.family.error("iCloud status check failed: \(error)")
            await MainActor.run {
                self.isCloudKitAvailable = false
            }
        }
    }

    private func setupFamilyZone() async {
        guard let privateDatabase = privateDatabase else { return }

        let zone = CKRecordZone(zoneName: familyZoneName)
        familyZoneID = zone.zoneID

        do {
            _ = try await privateDatabase.modifyRecordZones(saving: [zone], deleting: [])
            Log.family.info("Family zone created/verified")
        } catch {
            Log.family.error("Failed to create family zone: \(error)")
        }
    }

    private func subscribeToChanges() async {
        guard let privateDatabase = privateDatabase,
              let zoneID = familyZoneID else { return }

        let subscription = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: "family-tracking-changes")
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        do {
            _ = try await privateDatabase.modifySubscriptions(saving: [subscription], deleting: [])
            Log.family.info("Subscribed to family tracking changes")
        } catch {
            Log.family.error("Failed to subscribe: \(error)")
        }
    }

    // MARK: - CloudKit Family Relationship Discovery

    /// Discovers and loads the family relationship from CloudKit.
    /// Works for both parent and child - relationship is shared via zone share.
    func discoverFamilyRelationship() async {
        // First try to load from cache for immediate UI
        if let cached = FamilyRelationship.loadFromCache() {
            await MainActor.run {
                self.familyRelationship = cached
            }
        }

        await MainActor.run {
            self.isLoadingRelationship = true
            self.relationshipError = nil
        }

        // Query private database first (for child's own relationship record)
        if let relationship = await fetchRelationshipFromPrivate() {
            await MainActor.run {
                self.familyRelationship = relationship
                self.isLoadingRelationship = false
            }
            relationship.saveToCache()
            Log.family.info("Found relationship in private database")
            return
        }

        // Query shared database (for parent viewing child's shared zone)
        if let relationship = await fetchRelationshipFromShared() {
            await MainActor.run {
                self.familyRelationship = relationship
                self.isLoadingRelationship = false
            }
            relationship.saveToCache()
            Log.family.info("Found relationship in shared database")
            return
        }

        await MainActor.run {
            self.isLoadingRelationship = false
        }
        Log.family.debug("No family relationship found")
    }

    private func fetchRelationshipFromPrivate() async -> FamilyRelationship? {
        guard let privateDatabase = privateDatabase,
              let zoneID = familyZoneID else { return nil }

        do {
            let predicate = NSPredicate(format: "childUserID == %@ OR parentUserID == %@",
                                        currentUserID, currentUserID)
            let query = CKQuery(recordType: FamilyRelationship.recordType, predicate: predicate)

            let (results, _) = try await privateDatabase.records(matching: query, inZoneWith: zoneID)

            for (_, result) in results {
                if case .success(let record) = result {
                    if let relationship = FamilyRelationship.from(record: record) {
                        return relationship
                    }
                }
            }
        } catch {
            Log.family.error("Failed to fetch relationship from private: \(error)")
        }

        return nil
    }

    private func fetchRelationshipFromShared() async -> FamilyRelationship? {
        guard let sharedDatabase = sharedDatabase else { return nil }

        do {
            let zones = try await sharedDatabase.allRecordZones()

            for zone in zones {
                let predicate = NSPredicate(format: "parentUserID == %@", currentUserID)
                let query = CKQuery(recordType: FamilyRelationship.recordType, predicate: predicate)

                let (results, _) = try await sharedDatabase.records(matching: query, inZoneWith: zone.zoneID)

                for (_, result) in results {
                    if case .success(let record) = result {
                        if let relationship = FamilyRelationship.from(record: record) {
                            return relationship
                        }
                    }
                }
            }
        } catch {
            Log.family.error("Failed to fetch relationship from shared: \(error)")
        }

        return nil
    }

    /// Creates a new family relationship (called by child when linking with parent).
    /// - Parameters:
    ///   - parentUserID: CloudKit user ID of the parent
    ///   - parentName: Display name of the parent
    ///   - childName: Display name of the child (current user)
    /// - Returns: The created relationship, or nil if creation failed
    func createFamilyRelationship(
        parentUserID: String,
        parentName: String,
        childName: String
    ) async -> FamilyRelationship? {
        guard let privateDatabase = privateDatabase,
              let zoneID = familyZoneID else { return nil }

        let relationship = FamilyRelationship(
            parentUserID: parentUserID,
            childUserID: currentUserID,
            childName: childName,
            parentName: parentName,
            status: .pending,
            createdBy: currentUserID
        )

        let record = relationship.toCKRecord(zoneID: zoneID)

        do {
            _ = try await privateDatabase.save(record)
            await MainActor.run {
                self.familyRelationship = relationship
            }
            relationship.saveToCache()
            Log.family.info("Created family relationship with parent \(parentName)")
            return relationship
        } catch {
            Log.family.error("Failed to create family relationship: \(error)")
            await MainActor.run {
                self.relationshipError = "Failed to create relationship: \(error.localizedDescription)"
            }
            return nil
        }
    }

    /// Activates a pending family relationship (called when parent accepts share).
    func activateFamilyRelationship() async -> Bool {
        guard var relationship = familyRelationship,
              let privateDatabase = privateDatabase,
              let zoneID = familyZoneID else { return false }

        relationship.status = .active
        relationship.modifiedAt = Date()

        let record = relationship.toCKRecord(zoneID: zoneID)

        do {
            _ = try await privateDatabase.save(record)
            await MainActor.run {
                self.familyRelationship = relationship
            }
            relationship.saveToCache()
            Log.family.info("Activated family relationship")
            return true
        } catch {
            Log.family.error("Failed to activate family relationship: \(error)")
            return false
        }
    }

    /// Revokes the family relationship.
    func revokeFamilyRelationship() async -> Bool {
        guard var relationship = familyRelationship,
              let privateDatabase = privateDatabase,
              let zoneID = familyZoneID else { return false }

        relationship.status = .revoked
        relationship.modifiedAt = Date()

        let record = relationship.toCKRecord(zoneID: zoneID)

        do {
            _ = try await privateDatabase.save(record)
            await MainActor.run {
                self.familyRelationship = relationship
            }
            FamilyRelationship.clearCache()
            Log.family.info("Revoked family relationship")
            return true
        } catch {
            Log.family.error("Failed to revoke family relationship: \(error)")
            return false
        }
    }

    /// Whether the current user has an active family relationship as a parent.
    var isParentInRelationship: Bool {
        guard let relationship = familyRelationship else { return false }
        return relationship.isActive && relationship.isParent(currentUserID: currentUserID)
    }

    /// Whether the current user has an active family relationship as a child.
    var isChildInRelationship: Bool {
        guard let relationship = familyRelationship else { return false }
        return relationship.isActive && relationship.isChild(currentUserID: currentUserID)
    }

    /// The linked family member's name (child's name for parent, parent's name for child).
    var linkedFamilyMemberName: String? {
        guard let relationship = familyRelationship, relationship.isActive else { return nil }
        if relationship.isParent(currentUserID: currentUserID) {
            return relationship.childName
        } else {
            return relationship.parentName
        }
    }

    // MARK: - Share Live Location (Child's device)

    func startSharingLocation() async {
        guard isSignedIn,
              let privateDatabase = privateDatabase,
              let zoneID = familyZoneID else { return }

        let session = LiveTrackingSession(riderName: currentUserName, riderID: currentUserID)
        session.startSession()

        await MainActor.run {
            self.mySession = session
        }

        // Create CloudKit record
        let recordID = CKRecord.ID(recordName: "live-\(currentUserID)", zoneID: zoneID)
        let record = CKRecord(recordType: liveTrackingRecordType, recordID: recordID)
        updateRecord(record, from: session)

        do {
            _ = try await privateDatabase.save(record)
            Log.family.info("Started sharing location")
        } catch {
            Log.family.error("Failed to start sharing: \(error)")
        }
    }

    func updateSharedLocation(
        location: CLLocation,
        gait: GaitType,
        distance: Double,
        duration: TimeInterval
    ) async {
        guard let session = mySession,
              let privateDatabase = privateDatabase,
              let zoneID = familyZoneID else { return }

        // Update local session
        session.updateLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            speed: max(0, location.speed),
            gait: gait,
            distance: distance,
            duration: duration
        )

        // Update CloudKit record
        let recordID = CKRecord.ID(recordName: "live-\(currentUserID)", zoneID: zoneID)

        do {
            let record = try await privateDatabase.record(for: recordID)
            updateRecord(record, from: session)
            _ = try await privateDatabase.save(record)
        } catch {
            Log.family.error("Failed to update shared location: \(error)")
        }
    }

    func stopSharingLocation() async {
        guard let privateDatabase = privateDatabase,
              let zoneID = familyZoneID else { return }

        mySession?.endSession()

        // Update CloudKit record to inactive
        let recordID = CKRecord.ID(recordName: "live-\(currentUserID)", zoneID: zoneID)

        do {
            let record = try await privateDatabase.record(for: recordID)
            record["isActive"] = false
            _ = try await privateDatabase.save(record)
            Log.family.info("Stopped sharing location")
        } catch {
            Log.family.error("Failed to stop sharing: \(error)")
        }

        await MainActor.run {
            self.mySession = nil
        }
    }

    // MARK: - View Family Locations (Parent's device)

    func fetchFamilyLocations() async {
        var allSessions: [LiveTrackingSession] = []

        // Query shared database for accepted shares
        if let sharedDatabase = sharedDatabase {
            do {
                // Fetch all shared zones
                let zones = try await sharedDatabase.allRecordZones()

                for zone in zones {
                    let predicate = NSPredicate(value: true)  // Get all records
                    let query = CKQuery(recordType: liveTrackingRecordType, predicate: predicate)

                    let (results, _) = try await sharedDatabase.records(matching: query, inZoneWith: zone.zoneID)

                    for (_, result) in results {
                        if case .success(let record) = result {
                            if let session = sessionFromRecord(record) {
                                // Don't include our own session
                                if session.riderID != currentUserID {
                                    allSessions.append(session)
                                }
                            }
                        }
                    }
                }
            } catch {
                Log.family.error("Failed to fetch from shared database: \(error)")
            }
        }

        // Also check private database (for testing/development)
        if let privateDatabase = privateDatabase, let zoneID = familyZoneID {
            do {
                let predicate = NSPredicate(value: true)
                let query = CKQuery(recordType: liveTrackingRecordType, predicate: predicate)

                let (results, _) = try await privateDatabase.records(matching: query, inZoneWith: zoneID)

                for (_, result) in results {
                    if case .success(let record) = result {
                        if let session = sessionFromRecord(record) {
                            // Don't include our own session or duplicates
                            if session.riderID != currentUserID &&
                               !allSessions.contains(where: { $0.riderID == session.riderID }) {
                                allSessions.append(session)
                            }
                        }
                    }
                }
            } catch {
                Log.family.error("Failed to fetch from private database: \(error)")
            }
        }

        // Update linked riders with their current session status
        await MainActor.run {
            // Update existing linked riders
            for i in linkedRiders.indices {
                if let session = allSessions.first(where: { $0.riderID == linkedRiders[i].riderID }) {
                    linkedRiders[i].isCurrentlyRiding = session.isActive
                    linkedRiders[i].currentSession = session
                } else {
                    linkedRiders[i].isCurrentlyRiding = false
                    linkedRiders[i].currentSession = nil
                }
            }

            // Add any new riders we discovered from shares
            for session in allSessions {
                if !linkedRiders.contains(where: { $0.riderID == session.riderID }) {
                    var newRider = LinkedRider(riderID: session.riderID, name: session.riderName)
                    newRider.isCurrentlyRiding = session.isActive
                    newRider.currentSession = session
                    linkedRiders.append(newRider)
                }
            }

            // Filter to active sessions for sharedWithMe
            self.sharedWithMe = allSessions.filter { $0.isActive }
        }

        // Check for safety alerts on active sessions
        for session in allSessions where session.isActive {
            await checkForSafetyAlerts(session: session)
        }

        // Clear alerts for riders who are no longer stationary
        clearResolvedAlerts(activeSessions: allSessions.filter { $0.isActive })

        // Save linked riders
        saveLinkedRiders()
    }

    // MARK: - Safety Alerts

    private func checkForSafetyAlerts(session: LiveTrackingSession) async {
        guard session.isActive && session.isStationary else {
            // Rider is moving, clear any pending alerts
            sentWarningAlerts.remove(session.riderID)
            sentUrgentAlerts.remove(session.riderID)
            return
        }

        let duration = session.stationaryDuration

        // Urgent alert (5+ minutes)
        if duration >= NotificationManager.stationaryAlertThreshold {
            if !sentUrgentAlerts.contains(session.riderID) {
                sentUrgentAlerts.insert(session.riderID)

                // Send local notification
                notificationManager.sendLocalUrgentAlert(
                    riderName: session.riderName,
                    duration: duration
                )

                // Create remote alert for other family members
                await notificationManager.createRemoteSafetyAlert(
                    riderName: session.riderName,
                    riderID: session.riderID,
                    alertType: .urgent,
                    location: (session.currentLatitude, session.currentLongitude),
                    stationaryDuration: duration
                )

                Log.family.info("Sent urgent alert for \(session.riderName)")
            }
        }
        // Warning alert (2+ minutes)
        else if duration >= NotificationManager.stationaryWarningThreshold {
            if !sentWarningAlerts.contains(session.riderID) {
                sentWarningAlerts.insert(session.riderID)

                // Send local notification
                notificationManager.sendLocalStationaryWarning(
                    riderName: session.riderName,
                    duration: duration
                )

                Log.family.info("Sent warning alert for \(session.riderName)")
            }
        }
    }

    private func clearResolvedAlerts(activeSessions: [LiveTrackingSession]) {
        let activeRiderIDs = Set(activeSessions.map { $0.riderID })
        let movingRiderIDs = Set(activeSessions.filter { !$0.isStationary }.map { $0.riderID })

        // Clear alerts for riders who are moving again or no longer active
        for riderID in sentWarningAlerts {
            if !activeRiderIDs.contains(riderID) || movingRiderIDs.contains(riderID) {
                sentWarningAlerts.remove(riderID)
                notificationManager.clearNotificationsForRider(riderID)
            }
        }

        for riderID in sentUrgentAlerts {
            if !activeRiderIDs.contains(riderID) || movingRiderIDs.contains(riderID) {
                sentUrgentAlerts.remove(riderID)
                notificationManager.clearNotificationsForRider(riderID)
            }
        }
    }

    // MARK: - Share with Family Member

    func shareWithFamilyMember(email: String) async -> Bool {
        guard let privateDatabase = privateDatabase,
              let zoneID = familyZoneID else { return false }

        do {
            // Create share for the zone
            let share = CKShare(recordZoneID: zoneID)
            share.publicPermission = .none

            // Use UICloudSharingController for proper sharing flow
            // For now, create a basic share that can be accepted via link
            _ = try await privateDatabase.save(share)

            Log.family.info("Share created for zone - use system sharing UI to invite: \(email)")
            return true
        } catch {
            Log.family.error("Failed to create share: \(error)")
            return false
        }
    }

    // MARK: - Helper Methods

    private func updateRecord(_ record: CKRecord, from session: LiveTrackingSession) {
        record["riderName"] = session.riderName
        record["riderID"] = session.riderID
        record["isActive"] = session.isActive
        record["startTime"] = session.startTime
        record["lastUpdateTime"] = session.lastUpdateTime
        record["currentLatitude"] = session.currentLatitude
        record["currentLongitude"] = session.currentLongitude
        record["currentAltitude"] = session.currentAltitude
        record["currentSpeed"] = session.currentSpeed
        record["currentGait"] = session.currentGait
        record["totalDistance"] = session.totalDistance
        record["elapsedDuration"] = session.elapsedDuration
        record["isStationary"] = session.isStationary
        record["stationaryDuration"] = session.stationaryDuration

        // Store route points as Data for gait-colored route display
        if let routeData = session.routePointsData {
            record["routePointsData"] = routeData
        }
    }

    private func sessionFromRecord(_ record: CKRecord) -> LiveTrackingSession? {
        let session = LiveTrackingSession()
        session.riderName = record["riderName"] as? String ?? ""
        session.riderID = record["riderID"] as? String ?? ""
        session.isActive = record["isActive"] as? Bool ?? false
        session.startTime = record["startTime"] as? Date
        session.lastUpdateTime = record["lastUpdateTime"] as? Date ?? Date()
        session.currentLatitude = record["currentLatitude"] as? Double ?? 0
        session.currentLongitude = record["currentLongitude"] as? Double ?? 0
        session.currentAltitude = record["currentAltitude"] as? Double ?? 0
        session.currentSpeed = record["currentSpeed"] as? Double ?? 0
        session.currentGait = record["currentGait"] as? String ?? GaitType.stationary.rawValue
        session.totalDistance = record["totalDistance"] as? Double ?? 0
        session.elapsedDuration = record["elapsedDuration"] as? TimeInterval ?? 0
        session.isStationary = record["isStationary"] as? Bool ?? false
        session.stationaryDuration = record["stationaryDuration"] as? TimeInterval ?? 0

        // Decode route points for gait-colored route display
        if let routeData = record["routePointsData"] as? Data {
            session.routePointsData = routeData
            session.decodeRoutePoints()
        }

        return session
    }

    var familyMembers: [String] {
        localContacts.map { $0.displayName }
    }

    var trustedContacts: [TrustedContact] {
        localContacts
    }

    // MARK: - Local Contact Management

    func loadContacts() {
        if let data = UserDefaults.standard.data(forKey: contactsKey),
           let contacts = try? JSONDecoder().decode([TrustedContact].self, from: data) {
            localContacts = contacts
        }
        loadLinkedRiders()
        loadPendingRequests()
    }

    private func saveContacts() {
        if let data = try? JSONEncoder().encode(localContacts) {
            UserDefaults.standard.set(data, forKey: contactsKey)
        }
    }

    // MARK: - Linked Riders Management

    private func loadLinkedRiders() {
        if let data = UserDefaults.standard.data(forKey: linkedRidersKey),
           let riders = try? JSONDecoder().decode([LinkedRider].self, from: data) {
            linkedRiders = riders
        }
    }

    private func saveLinkedRiders() {
        // Create copies without the non-codable currentSession
        var ridersToSave = linkedRiders
        for i in ridersToSave.indices {
            ridersToSave[i].currentSession = nil
        }
        if let data = try? JSONEncoder().encode(ridersToSave) {
            UserDefaults.standard.set(data, forKey: linkedRidersKey)
        }
    }

    func addLinkedRider(riderID: String, name: String) {
        // Don't add duplicates
        guard !linkedRiders.contains(where: { $0.riderID == riderID }) else { return }

        let rider = LinkedRider(riderID: riderID, name: name)
        linkedRiders.append(rider)
        saveLinkedRiders()
    }

    func removeLinkedRider(id: UUID) {
        linkedRiders.removeAll { $0.id == id }
        saveLinkedRiders()
    }

    // MARK: - Pending Share Requests Management

    private func loadPendingRequests() {
        if let data = UserDefaults.standard.data(forKey: pendingRequestsKey),
           let requests = try? JSONDecoder().decode([PendingShareRequest].self, from: data) {
            pendingRequests = requests
        }
    }

    private func savePendingRequests() {
        if let data = try? JSONEncoder().encode(pendingRequests) {
            UserDefaults.standard.set(data, forKey: pendingRequestsKey)
        }
    }

    /// Add a pending share request (called when a share URL is opened)
    func addPendingRequest(from metadata: CKShare.Metadata) {
        let ownerIdentity = metadata.ownerIdentity
        let ownerID = ownerIdentity.userRecordID?.recordName ?? UUID().uuidString
        let ownerName = ownerIdentity.nameComponents?.formatted() ?? "Unknown"

        // Don't add duplicates
        guard !pendingRequests.contains(where: { $0.ownerID == ownerID }) else {
            Log.family.info("Pending request from \(ownerName) already exists")
            return
        }

        // Don't add if already a linked rider
        guard !linkedRiders.contains(where: { $0.riderID == ownerID }) else {
            Log.family.info("Already linked with \(ownerName)")
            return
        }

        let request = PendingShareRequest(
            ownerID: ownerID,
            ownerName: ownerName,
            shareURL: metadata.share.url
        )
        pendingRequests.append(request)
        savePendingRequests()
        Log.family.info("Added pending request from \(ownerName)")
    }

    /// Accept a pending share request
    func acceptPendingRequest(_ request: PendingShareRequest) async -> Bool {
        guard let url = request.shareURL else {
            Log.family.error("No share URL for pending request")
            return false
        }

        let success = await acceptShare(from: url)

        if success {
            // Remove from pending
            pendingRequests.removeAll { $0.id == request.id }
            savePendingRequests()
        }

        return success
    }

    /// Decline a pending share request
    func declinePendingRequest(_ request: PendingShareRequest) {
        pendingRequests.removeAll { $0.id == request.id }
        savePendingRequests()
        Log.family.info("Declined request from \(request.ownerName)")
    }

    func addContact(
        name: String,
        phoneNumber: String = "",
        email: String? = nil,
        isEmergencyContact: Bool = true,
        isPrimaryEmergency: Bool = false,
        inviteStatus: InviteStatus = .notSent,
        inviteSentDate: Date? = nil
    ) {
        // If this is the first contact, make it primary
        let shouldBePrimary = isPrimaryEmergency || localContacts.isEmpty

        let contact = TrustedContact(
            name: name,
            phoneNumber: phoneNumber,
            email: email,
            isEmergencyContact: isEmergencyContact,
            isPrimaryEmergency: shouldBePrimary,
            inviteStatus: inviteStatus,
            inviteSentDate: inviteSentDate
        )
        localContacts.append(contact)
        saveContacts()
    }

    /// Get contacts configured for emergency alerts
    var emergencyContacts: [TrustedContact] {
        localContacts.filter { $0.isEmergencyContact && !$0.phoneNumber.isEmpty }
    }

    /// Get the primary emergency contact
    var primaryEmergencyContact: TrustedContact? {
        localContacts.first { $0.isPrimaryEmergency && $0.isEmergencyContact }
            ?? emergencyContacts.first
    }

    /// Set a contact as the primary emergency contact
    func setPrimaryEmergencyContact(id: UUID) {
        for i in localContacts.indices {
            localContacts[i].isPrimaryEmergency = (localContacts[i].id == id)
        }
        saveContacts()
    }

    func removeContact(id: UUID) {
        localContacts.removeAll { $0.id == id }
        saveContacts()
    }

    func updateContact(_ contact: TrustedContact) {
        if let index = localContacts.firstIndex(where: { $0.id == contact.id }) {
            localContacts[index] = contact
            saveContacts()
        }
    }

    // MARK: - Invite Status Management

    func markInviteSent(contactID: UUID) {
        if let index = localContacts.firstIndex(where: { $0.id == contactID }) {
            localContacts[index].inviteStatus = .pending
            localContacts[index].inviteSentDate = Date()
            saveContacts()
        }
    }

    func markReminderSent(contactID: UUID) {
        if let index = localContacts.firstIndex(where: { $0.id == contactID }) {
            localContacts[index].lastReminderDate = Date()
            localContacts[index].reminderCount += 1
            saveContacts()
        }
    }

    func markInviteAccepted(contactID: UUID) {
        if let index = localContacts.firstIndex(where: { $0.id == contactID }) {
            localContacts[index].inviteStatus = .accepted
            saveContacts()
        }
    }

    // MARK: - Share Link Generation

    func generateShareLink() async -> URL? {
        guard let privateDatabase = privateDatabase,
              let zoneID = familyZoneID else { return nil }

        do {
            // Create or fetch existing share for the zone
            let share = CKShare(recordZoneID: zoneID)
            share.publicPermission = .readOnly
            share[CKShare.SystemFieldKey.title] = "TetraTrack Live Location" as CKRecordValue
            share[CKShare.SystemFieldKey.shareType] = "Live Ride Tracking" as CKRecordValue

            _ = try await privateDatabase.save(share)

            Log.family.info("Share link generated")
            return share.url
        } catch {
            Log.family.error("Failed to generate share link: \(error)")
            return nil
        }
    }

    // MARK: - Share Acceptance

    /// Accept a CloudKit share from a URL (called when app opens via share link)
    func acceptShare(from url: URL) async -> Bool {
        guard let container = container else {
            Log.family.error("CloudKit container not available for share acceptance")
            return false
        }

        do {
            // Extract share metadata from URL
            let metadata = try await container.shareMetadata(for: url)

            // Accept the share
            let acceptedShare = try await container.accept(metadata)

            // Get the owner's info to create a linked rider
            let ownerIdentity = acceptedShare.owner.userIdentity
            if let ownerID = ownerIdentity.userRecordID?.recordName {
                let ownerName = ownerIdentity.nameComponents?.formatted() ?? "Unknown Rider"

                await MainActor.run {
                    addLinkedRider(riderID: ownerID, name: ownerName)
                }

                Log.family.info("Accepted share from \(ownerName)")
            }

            // Fetch locations to populate the linked rider's status
            await fetchFamilyLocations()

            return true
        } catch {
            Log.family.error("Failed to accept share: \(error)")
            return false
        }
    }

    /// Check if URL is a CloudKit share URL
    func isCloudKitShareURL(_ url: URL) -> Bool {
        url.scheme == "cloudkit" || url.host?.contains("icloud") == true
    }

    // MARK: - Multi-Discipline Artifact Support

    /// Current role in family sharing (determined by CloudKit relationship)
    var currentRole: FamilyRole {
        // Use CloudKit relationship as primary source
        if let relationship = familyRelationship, relationship.isActive {
            if relationship.isParent(currentUserID: currentUserID) {
                return .parent
            } else if relationship.isChild(currentUserID: currentUserID) {
                return .child
            }
        }

        // Fallback to legacy detection for backwards compatibility
        if !linkedRiders.isEmpty {
            return .parent
        }
        if mySession != nil || !localContacts.isEmpty {
            return .child
        }
        return .selfOnly
    }

    /// Creates a ViewContext appropriate for the current user's role and relationship.
    func createViewContext() -> ViewContext {
        switch currentRole {
        case .parent:
            let childName = linkedFamilyMemberName ?? "Athlete"
            return ViewContext.parentReview(childName: childName)
        case .child:
            return ViewContext.athleteCapture()
        case .selfOnly:
            return ViewContext.athleteCapture()
        }
    }

    /// Fetch artifacts from linked riders (parent view)
    func fetchFamilyArtifacts() async -> [TrainingArtifact] {
        guard let sharedDatabase = sharedDatabase else { return [] }

        var allArtifacts: [TrainingArtifact] = []

        do {
            // Fetch all shared zones
            let zones = try await sharedDatabase.allRecordZones()

            for zone in zones {
                let predicate = NSPredicate(value: true)
                let query = CKQuery(recordType: TrainingArtifact.recordType, predicate: predicate)
                query.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]

                let (results, _) = try await sharedDatabase.records(matching: query, inZoneWith: zone.zoneID)

                for (_, result) in results {
                    if case .success(let record) = result {
                        let artifact = TrainingArtifact.from(record: record)
                        allArtifacts.append(artifact)
                    }
                }
            }

            Log.family.info("Fetched \(allArtifacts.count) artifacts from family members")
        } catch {
            Log.family.error("Failed to fetch family artifacts: \(error)")
        }

        return allArtifacts
    }

    /// Fetch competitions from linked family members
    func fetchFamilyCompetitions() async -> [SharedCompetition] {
        guard let sharedDatabase = sharedDatabase else { return [] }

        var allCompetitions: [SharedCompetition] = []

        do {
            let zones = try await sharedDatabase.allRecordZones()

            for zone in zones {
                let predicate = NSPredicate(value: true)
                let query = CKQuery(recordType: SharedCompetition.recordType, predicate: predicate)
                query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

                let (results, _) = try await sharedDatabase.records(matching: query, inZoneWith: zone.zoneID)

                for (_, result) in results {
                    if case .success(let record) = result {
                        let competition = SharedCompetition.from(record: record)
                        allCompetitions.append(competition)
                    }
                }
            }

            Log.family.info("Fetched \(allCompetitions.count) competitions from family members")
        } catch {
            Log.family.error("Failed to fetch family competitions: \(error)")
        }

        return allCompetitions
    }

    /// Subscribe to artifact and competition changes
    func subscribeToArtifactChanges() async {
        guard let privateDatabase = privateDatabase,
              let zoneID = familyZoneID else { return }

        // Artifact subscription
        let artifactSubscription = CKRecordZoneSubscription(
            zoneID: zoneID,
            subscriptionID: "family-artifact-changes"
        )
        let artifactNotificationInfo = CKSubscription.NotificationInfo()
        artifactNotificationInfo.shouldSendContentAvailable = true
        artifactSubscription.notificationInfo = artifactNotificationInfo

        do {
            _ = try await privateDatabase.modifySubscriptions(
                saving: [artifactSubscription],
                deleting: []
            )
            Log.family.info("Subscribed to artifact and competition changes")
        } catch {
            Log.family.error("Failed to subscribe to changes: \(error)")
        }
    }

    /// Send completion notification to family members
    func notifyFamilyOfCompletion(
        artifact: TrainingArtifact,
        summary: String
    ) async {
        // This would integrate with the notification system
        // For now, log the notification
        Log.family.info("Notifying family of completion: \(artifact.discipline.rawValue) - \(summary)")

        // In a full implementation, this would:
        // 1. Create a notification record in CloudKit
        // 2. Trigger push notifications to family members
        // 3. Update the artifact with notification status
    }
}

// MARK: - Family Role

/// Role in the family sharing relationship
enum FamilyRole {
    case parent     // Viewing child's data
    case child      // Sharing own data
    case selfOnly   // No family sharing active

    var displayName: String {
        switch self {
        case .parent: return "Parent View"
        case .child: return "Athlete View"
        case .selfOnly: return "Personal"
        }
    }
}

// MARK: - Trusted Contact Model

// MARK: - Linked Rider Model (people who share their rides with you)

struct LinkedRider: Identifiable, Codable {
    let id: UUID
    var riderID: String           // CloudKit user ID
    var name: String
    var addedDate: Date

    // Current status (not persisted)
    var isCurrentlyRiding: Bool = false
    var currentSession: LiveTrackingSession?

    init(
        id: UUID = UUID(),
        riderID: String,
        name: String
    ) {
        self.id = id
        self.riderID = riderID
        self.name = name
        self.addedDate = Date()
    }

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return name.prefix(2).uppercased()
    }

    // Codable conformance - exclude non-codable currentSession
    enum CodingKeys: String, CodingKey {
        case id, riderID, name, addedDate, isCurrentlyRiding
    }
}

extension LinkedRider: Equatable {
    static func == (lhs: LinkedRider, rhs: LinkedRider) -> Bool {
        lhs.id == rhs.id &&
        lhs.riderID == rhs.riderID &&
        lhs.name == rhs.name &&
        lhs.isCurrentlyRiding == rhs.isCurrentlyRiding
    }
}

// MARK: - Invite Status

enum InviteStatus: String, Codable, Equatable {
    case notSent = "not_sent"
    case pending = "pending"
    case accepted = "accepted"

    var displayText: String {
        switch self {
        case .notSent: return "Invite not sent"
        case .pending: return "Invite pending"
        case .accepted: return "Connected"
        }
    }

    var icon: String {
        switch self {
        case .notSent: return "envelope"
        case .pending: return "clock"
        case .accepted: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Trusted Contact Model

struct TrustedContact: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var phoneNumber: String
    var email: String?
    var addedDate: Date

    // Feature permissions (granular control)
    var canViewLiveTracking: Bool      // Can see live location during rides
    var receiveFallAlerts: Bool        // Receives fall detection notifications
    var receiveStationaryAlerts: Bool  // Receives stationary/stopped alerts
    var isEmergencyContact: Bool       // Receives emergency SOS (SMS with location)
    var isPrimaryEmergency: Bool       // First to be contacted in emergency

    // Legacy property for compatibility
    var shareMyLocation: Bool {
        get { canViewLiveTracking }
        set { canViewLiveTracking = newValue }
    }

    // Invite tracking
    var inviteStatus: InviteStatus
    var inviteSentDate: Date?
    var lastReminderDate: Date?
    var reminderCount: Int

    // Medical info (for emergency contacts)
    var medicalNotes: String?

    // CloudKit sharing
    var cloudKitShareURL: URL?

    init(
        id: UUID = UUID(),
        name: String,
        phoneNumber: String = "",
        email: String? = nil,
        canViewLiveTracking: Bool = true,
        receiveFallAlerts: Bool = true,
        receiveStationaryAlerts: Bool = true,
        isEmergencyContact: Bool = true,
        isPrimaryEmergency: Bool = false,
        inviteStatus: InviteStatus = .notSent,
        inviteSentDate: Date? = nil,
        medicalNotes: String? = nil,
        cloudKitShareURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.email = email
        self.canViewLiveTracking = canViewLiveTracking
        self.receiveFallAlerts = receiveFallAlerts
        self.receiveStationaryAlerts = receiveStationaryAlerts
        self.isEmergencyContact = isEmergencyContact
        self.isPrimaryEmergency = isPrimaryEmergency
        self.inviteStatus = inviteStatus
        self.inviteSentDate = inviteSentDate
        self.lastReminderDate = nil
        self.reminderCount = 0
        self.medicalNotes = medicalNotes
        self.cloudKitShareURL = cloudKitShareURL
        self.addedDate = Date()
    }

    // Count of enabled features
    var enabledFeatureCount: Int {
        [canViewLiveTracking, receiveFallAlerts, receiveStationaryAlerts, isEmergencyContact]
            .filter { $0 }.count
    }

    var displayName: String {
        name.isEmpty ? (email ?? phoneNumber) : name
    }

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return name.prefix(2).uppercased()
    }

    // For emergency SMS/calls
    var callURL: URL? {
        guard !phoneNumber.isEmpty else { return nil }
        let cleaned = phoneNumber.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        return URL(string: "tel://\(cleaned)")
    }

    var smsURL: URL? {
        guard !phoneNumber.isEmpty else { return nil }
        let cleaned = phoneNumber.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        return URL(string: "sms://\(cleaned)")
    }

    // Time since invite was sent
    var timeSinceInvite: String? {
        guard let sentDate = inviteSentDate else { return nil }
        let interval = Date().timeIntervalSince(sentDate)

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
            return days == 1 ? "Yesterday" : "\(days) days ago"
        }
    }

    // Generate invite message
    func inviteMessage(isReminder: Bool = false, shareURL: URL? = nil) -> String {
        let greeting = isReminder ? "Reminder: " : ""
        let firstName = name.split(separator: " ").first.map(String.init) ?? "there"

        var message = """
        \(greeting)Hi \(firstName)! I've added you as a trusted contact on TetraTrack.

        You can follow my horse rides live and receive safety alerts if I need help.

        Download TetraTrack: https://apps.apple.com/app/tetratrack
        """

        if let url = shareURL {
            message += "\n\nTap to connect: \(url.absoluteString)"
        }

        return message
    }
}

// MARK: - Pending Share Request Model

struct PendingShareRequest: Identifiable, Codable, Equatable {
    let id: UUID
    var ownerID: String           // CloudKit user ID of the person sharing
    var ownerName: String         // Name of the person sharing
    var shareURL: URL?            // CloudKit share URL
    var receivedDate: Date

    init(
        id: UUID = UUID(),
        ownerID: String,
        ownerName: String,
        shareURL: URL? = nil
    ) {
        self.id = id
        self.ownerID = ownerID
        self.ownerName = ownerName
        self.shareURL = shareURL
        self.receivedDate = Date()
    }

    var initials: String {
        let parts = ownerName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return ownerName.prefix(2).uppercased()
    }

    var timeSinceReceived: String {
        let interval = Date().timeIntervalSince(receivedDate)

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
            return days == 1 ? "Yesterday" : "\(days) days ago"
        }
    }
}
