//
//  FamilySharingManager.swift
//  TrackRide
//

import CloudKit
import SwiftData
import Observation
import CoreLocation
import os

@Observable
final class FamilySharingManager: FamilySharing {
    static let shared = FamilySharingManager()

    // State
    var isSignedIn: Bool = false
    var isCloudKitAvailable: Bool = false
    var currentUserID: String = ""
    var currentUserName: String = ""
    var sharedWithMe: [LiveTrackingSession] = []  // Sessions shared by family members
    var mySession: LiveTrackingSession?  // My current session being shared

    // Alert tracking
    private var sentWarningAlerts: Set<String> = []  // Rider IDs we've warned about
    private var sentUrgentAlerts: Set<String> = []   // Rider IDs we've sent urgent alerts for

    // CloudKit enabled - iCloud entitlement configured in TrackRide.entitlements
    // Container: iCloud.MyHorse.TrackRide
    private let cloudKitEnabled = true

    // Local trusted contacts (stored separately from CloudKit shares)
    @ObservationIgnored
    private var localContacts: [TrustedContact] = []
    private let contactsKey = "trustedContacts"

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

                // Try to get user's name
                if let identity = try? await container.userIdentity(forUserRecordID: userID) {
                    let name = identity.nameComponents?.formatted() ?? "Rider"
                    await MainActor.run {
                        self.currentUserName = name
                    }
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
        guard let privateDatabase = privateDatabase,
              let zoneID = familyZoneID else { return }

        let predicate = NSPredicate(format: "isActive == %@", NSNumber(value: true))
        let query = CKQuery(recordType: liveTrackingRecordType, predicate: predicate)

        do {
            let (results, _) = try await privateDatabase.records(matching: query, inZoneWith: zoneID)

            var sessions: [LiveTrackingSession] = []
            for (_, result) in results {
                if case .success(let record) = result {
                    if let session = sessionFromRecord(record) {
                        // Don't include our own session
                        if session.riderID != currentUserID {
                            sessions.append(session)

                            // Check for safety alerts
                            await checkForSafetyAlerts(session: session)
                        }
                    }
                }
            }

            await MainActor.run {
                self.sharedWithMe = sessions
            }

            // Clear alerts for riders who are no longer stationary
            clearResolvedAlerts(activeSessions: sessions)

        } catch {
            Log.family.error("Failed to fetch family locations: \(error)")
        }
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
    }

    private func saveContacts() {
        if let data = try? JSONEncoder().encode(localContacts) {
            UserDefaults.standard.set(data, forKey: contactsKey)
        }
    }

    func addContact(name: String, email: String?, relationship: String = "Family") {
        let contact = TrustedContact(
            name: name,
            email: email,
            relationship: relationship
        )
        localContacts.append(contact)
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
}

// MARK: - Trusted Contact Model

struct TrustedContact: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var email: String?
    var relationship: String
    var shareMyLocation: Bool
    var receiveAlerts: Bool
    var cloudKitShareURL: URL?
    var addedDate: Date

    init(
        id: UUID = UUID(),
        name: String,
        email: String? = nil,
        relationship: String = "Family",
        shareMyLocation: Bool = true,
        receiveAlerts: Bool = true,
        cloudKitShareURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.relationship = relationship
        self.shareMyLocation = shareMyLocation
        self.receiveAlerts = receiveAlerts
        self.cloudKitShareURL = cloudKitShareURL
        self.addedDate = Date()
    }

    var displayName: String {
        name.isEmpty ? (email ?? "Contact") : name
    }
}
