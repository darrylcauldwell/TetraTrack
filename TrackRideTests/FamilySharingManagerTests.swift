//
//  FamilySharingManagerTests.swift
//  TrackRideTests
//
//  Tests for FamilySharingManager and related types
//

import Testing
import Foundation
@testable import TetraTrack

// MARK: - InviteStatus Tests

struct InviteStatusTests {

    @Test func allCasesExist() {
        let cases: [InviteStatus] = [.notSent, .pending, .accepted]
        #expect(cases.count == 3)
    }

    @Test func rawValues() {
        #expect(InviteStatus.notSent.rawValue == "not_sent")
        #expect(InviteStatus.pending.rawValue == "pending")
        #expect(InviteStatus.accepted.rawValue == "accepted")
    }

    @Test func displayText() {
        #expect(InviteStatus.notSent.displayText == "Invite not sent")
        #expect(InviteStatus.pending.displayText == "Invite pending")
        #expect(InviteStatus.accepted.displayText == "Connected")
    }

    @Test func icons() {
        #expect(InviteStatus.notSent.icon == "envelope")
        #expect(InviteStatus.pending.icon == "clock")
        #expect(InviteStatus.accepted.icon == "checkmark.circle.fill")
    }

    @Test func codable() throws {
        let original = InviteStatus.pending
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(InviteStatus.self, from: data)

        #expect(decoded == original)
    }
}

// MARK: - LinkedRider Tests

struct LinkedRiderTests {

    @Test func initialization() {
        let rider = LinkedRider(riderID: "user123", name: "Jane Smith")

        #expect(rider.riderID == "user123")
        #expect(rider.name == "Jane Smith")
        #expect(rider.isCurrentlyRiding == false)
        #expect(rider.currentSession == nil)
    }

    @Test func initialsWithTwoNames() {
        let rider = LinkedRider(riderID: "1", name: "John Doe")

        #expect(rider.initials == "JD")
    }

    @Test func initialsWithSingleName() {
        let rider = LinkedRider(riderID: "1", name: "Jo")

        #expect(rider.initials == "JO")
    }

    @Test func initialsWithLongName() {
        let rider = LinkedRider(riderID: "1", name: "Mary Jane Watson Parker")

        #expect(rider.initials == "MJ")
    }

    @Test func equatable() {
        let rider1 = LinkedRider(id: UUID(), riderID: "user1", name: "Alice")
        var rider2 = LinkedRider(id: rider1.id, riderID: "user1", name: "Alice")

        #expect(rider1 == rider2)

        rider2.isCurrentlyRiding = true
        #expect(rider1 != rider2)
    }

    @Test func codable() throws {
        let original = LinkedRider(riderID: "abc123", name: "Test User")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LinkedRider.self, from: data)

        #expect(decoded.riderID == original.riderID)
        #expect(decoded.name == original.name)
    }
}

// MARK: - TrustedContact Tests

struct TrustedContactTests {

    @Test func initializationWithDefaults() {
        let contact = TrustedContact(name: "John Doe")

        #expect(contact.name == "John Doe")
        #expect(contact.phoneNumber == "")
        #expect(contact.email == nil)
        #expect(contact.canViewLiveTracking == true)
        #expect(contact.receiveFallAlerts == true)
        #expect(contact.receiveStationaryAlerts == true)
        #expect(contact.isEmergencyContact == true)
        #expect(contact.isPrimaryEmergency == false)
        #expect(contact.inviteStatus == .notSent)
    }

    @Test func initializationWithAllParameters() {
        let contact = TrustedContact(
            name: "Jane Smith",
            phoneNumber: "+44 7700 900123",
            email: "jane@example.com",
            canViewLiveTracking: false,
            receiveFallAlerts: true,
            receiveStationaryAlerts: false,
            isEmergencyContact: true,
            isPrimaryEmergency: true,
            inviteStatus: .accepted
        )

        #expect(contact.name == "Jane Smith")
        #expect(contact.phoneNumber == "+44 7700 900123")
        #expect(contact.email == "jane@example.com")
        #expect(contact.canViewLiveTracking == false)
        #expect(contact.isPrimaryEmergency == true)
        #expect(contact.inviteStatus == .accepted)
    }

    @Test func displayNameWithName() {
        let contact = TrustedContact(name: "Alice Brown", email: "alice@example.com")

        #expect(contact.displayName == "Alice Brown")
    }

    @Test func displayNameWithoutName() {
        let contact = TrustedContact(name: "", email: "alice@example.com")

        #expect(contact.displayName == "alice@example.com")
    }

    @Test func displayNameWithPhoneOnly() {
        let contact = TrustedContact(name: "", phoneNumber: "07700900123")

        #expect(contact.displayName == "07700900123")
    }

    @Test func initialsWithTwoNames() {
        let contact = TrustedContact(name: "Bob Smith")

        #expect(contact.initials == "BS")
    }

    @Test func initialsWithSingleName() {
        let contact = TrustedContact(name: "Bo")

        #expect(contact.initials == "BO")
    }

    @Test func enabledFeatureCount() {
        let contactAll = TrustedContact(
            name: "Test",
            canViewLiveTracking: true,
            receiveFallAlerts: true,
            receiveStationaryAlerts: true,
            isEmergencyContact: true
        )
        #expect(contactAll.enabledFeatureCount == 4)

        let contactNone = TrustedContact(
            name: "Test",
            canViewLiveTracking: false,
            receiveFallAlerts: false,
            receiveStationaryAlerts: false,
            isEmergencyContact: false
        )
        #expect(contactNone.enabledFeatureCount == 0)

        let contactSome = TrustedContact(
            name: "Test",
            canViewLiveTracking: true,
            receiveFallAlerts: false,
            receiveStationaryAlerts: true,
            isEmergencyContact: false
        )
        #expect(contactSome.enabledFeatureCount == 2)
    }

    @Test func callURLWithValidPhone() {
        let contact = TrustedContact(name: "Test", phoneNumber: "+44 7700 900-123")

        #expect(contact.callURL != nil)
        #expect(contact.callURL?.absoluteString == "tel://+447700900123")
    }

    @Test func callURLWithEmptyPhone() {
        let contact = TrustedContact(name: "Test", phoneNumber: "")

        #expect(contact.callURL == nil)
    }

    @Test func smsURLWithValidPhone() {
        let contact = TrustedContact(name: "Test", phoneNumber: "(07700) 900123")

        #expect(contact.smsURL != nil)
        #expect(contact.smsURL?.absoluteString == "sms://07700900123")
    }

    @Test func smsURLWithEmptyPhone() {
        let contact = TrustedContact(name: "Test", phoneNumber: "")

        #expect(contact.smsURL == nil)
    }

    @Test func shareMyLocationLegacyProperty() {
        var contact = TrustedContact(name: "Test", canViewLiveTracking: true)

        #expect(contact.shareMyLocation == true)

        contact.shareMyLocation = false
        #expect(contact.canViewLiveTracking == false)
    }

    @Test func inviteMessage() {
        let contact = TrustedContact(name: "Alice Smith")
        let message = contact.inviteMessage()

        #expect(message.contains("Hi Alice"))
        #expect(message.contains("trusted contact"))
        #expect(message.contains("TetraTrack"))
    }

    @Test func inviteMessageReminder() {
        let contact = TrustedContact(name: "Bob Jones")
        let message = contact.inviteMessage(isReminder: true)

        #expect(message.contains("Reminder:"))
        #expect(message.contains("Hi Bob"))
    }

    @Test func inviteMessageWithShareURL() {
        let contact = TrustedContact(name: "Charlie")
        let url = URL(string: "https://share.example.com/abc123")!
        let message = contact.inviteMessage(shareURL: url)

        #expect(message.contains("Tap to connect:"))
        #expect(message.contains("abc123"))
    }

    @Test func codable() throws {
        let original = TrustedContact(
            name: "Test User",
            phoneNumber: "+44123456789",
            email: "test@example.com",
            isEmergencyContact: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TrustedContact.self, from: data)

        #expect(decoded.name == original.name)
        #expect(decoded.phoneNumber == original.phoneNumber)
        #expect(decoded.email == original.email)
        #expect(decoded.isEmergencyContact == original.isEmergencyContact)
    }
}

// MARK: - PendingShareRequest Tests

struct PendingShareRequestTests {

    @Test func initialization() {
        let request = PendingShareRequest(
            ownerID: "owner123",
            ownerName: "Alice Smith"
        )

        #expect(request.ownerID == "owner123")
        #expect(request.ownerName == "Alice Smith")
        #expect(request.shareURL == nil)
    }

    @Test func initializationWithURL() {
        let url = URL(string: "https://share.example.com/test")!
        let request = PendingShareRequest(
            ownerID: "owner123",
            ownerName: "Bob Jones",
            shareURL: url
        )

        #expect(request.shareURL == url)
    }

    @Test func initialsWithTwoNames() {
        let request = PendingShareRequest(ownerID: "1", ownerName: "John Doe")

        #expect(request.initials == "JD")
    }

    @Test func initialsWithSingleName() {
        let request = PendingShareRequest(ownerID: "1", ownerName: "Jo")

        #expect(request.initials == "JO")
    }

    @Test func timeSinceReceivedJustNow() {
        let request = PendingShareRequest(
            ownerID: "1",
            ownerName: "Test"
        )
        // Just created, should be "Just now"
        #expect(request.timeSinceReceived == "Just now")
    }

    @Test func codable() throws {
        let original = PendingShareRequest(
            ownerID: "user456",
            ownerName: "Charlie Brown"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PendingShareRequest.self, from: data)

        #expect(decoded.ownerID == original.ownerID)
        #expect(decoded.ownerName == original.ownerName)
    }

    @Test func equatable() {
        // Test that requests with different IDs are not equal
        let request1 = PendingShareRequest(
            id: UUID(),
            ownerID: "user1",
            ownerName: "Alice"
        )
        let request2 = PendingShareRequest(
            id: UUID(),
            ownerID: "user2",
            ownerName: "Bob"
        )

        #expect(request1 != request2)
        #expect(request1 == request1)  // Same instance should be equal
    }
}

// MARK: - FamilySharingManager State Tests

struct FamilySharingManagerStateTests {

    @Test func sharedInstance() {
        let manager = FamilySharingManager.shared

        #expect(manager != nil)
    }

    @Test func initialState() {
        let manager = FamilySharingManager.shared

        // Initial state before setup
        #expect(manager.currentUserID == "" || manager.isSignedIn == true)
        #expect(manager.mySession == nil)
    }
}
