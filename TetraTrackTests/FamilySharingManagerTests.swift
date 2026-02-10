//
//  FamilySharingManagerTests.swift
//  TetraTrackTests
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

