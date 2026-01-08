//
//  EmergencyContact.swift
//  TrackRide
//
//  Emergency contact model for safety alerts
//

import Foundation
import SwiftData

@Model
final class EmergencyContact {
    var id: UUID = UUID()
    var name: String = ""
    var phoneNumber: String = ""
    var relationship: String = ""
    var isPrimary: Bool = false
    var notifyOnFall: Bool = true
    var notifyOnStationary: Bool = true
    var medicalNotes: String = ""

    init() {}

    init(
        name: String = "",
        phoneNumber: String = "",
        relationship: String = "",
        isPrimary: Bool = false
    ) {
        self.name = name
        self.phoneNumber = phoneNumber
        self.relationship = relationship
        self.isPrimary = isPrimary
    }

    // MARK: - Formatted Values

    var formattedPhoneNumber: String {
        // Basic formatting - could be enhanced for different regions
        phoneNumber
    }

    var displayName: String {
        if relationship.isEmpty {
            return name
        }
        return "\(name) (\(relationship))"
    }

    // MARK: - Actions

    var callURL: URL? {
        let cleaned = phoneNumber.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        return URL(string: "tel://\(cleaned)")
    }

    var smsURL: URL? {
        let cleaned = phoneNumber.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        return URL(string: "sms://\(cleaned)")
    }

    func smsURLWithBody(_ body: String) -> URL? {
        let cleaned = phoneNumber.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "sms://\(cleaned)&body=\(encodedBody)")
    }
}

// MARK: - Common Relationships

extension EmergencyContact {
    static let commonRelationships = [
        "Partner",
        "Spouse",
        "Parent",
        "Child",
        "Sibling",
        "Friend",
        "Yard Manager",
        "Instructor",
        "Other"
    ]
}
