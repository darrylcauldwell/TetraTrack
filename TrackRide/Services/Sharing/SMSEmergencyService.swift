//
//  SMSEmergencyService.swift
//  TrackRide
//
//  SMS fallback service for safety alerts when push notifications fail.
//  Sends emergency SMS with GPS coordinates to emergency contacts.
//

import Foundation
import MessageUI
import CoreLocation
import os

// MARK: - SMS Emergency Service

actor SMSEmergencyService {

    // MARK: - Singleton

    static let shared = SMSEmergencyService()

    // MARK: - State

    /// Contacts that have been notified via SMS recently (to prevent spam)
    private var recentlySMSedContacts: [String: Date] = [:]

    /// Minimum time between SMS to same contact (5 minutes)
    private let smsThrottleInterval: TimeInterval = 300

    // MARK: - Public Interface

    /// Check if SMS is available on this device
    nonisolated func canSendSMS() -> Bool {
        MFMessageComposeViewController.canSendText()
    }

    /// Send emergency SMS to all emergency contacts with phone numbers
    /// Called when push notification delivery has failed for too long
    func sendEmergencySMS(
        riderName: String,
        alertType: SafetyAlertType,
        location: CLLocationCoordinate2D,
        contacts: [SMSContact]
    ) async -> SMSResult {
        guard canSendSMS() else {
            Log.family.warning("SMS not available on this device")
            return SMSResult(
                success: false,
                contactsNotified: [],
                failures: ["SMS not available on this device"]
            )
        }

        let eligibleContacts = contacts.filter { contact in
            guard let phone = contact.phoneNumber, !phone.isEmpty else {
                return false
            }
            return shouldSendSMS(to: contact.id)
        }

        guard !eligibleContacts.isEmpty else {
            Log.family.info("No eligible emergency contacts for SMS fallback")
            return SMSResult(
                success: false,
                contactsNotified: [],
                failures: ["No emergency contacts with phone numbers available"]
            )
        }

        // Generate the emergency message
        let message = generateEmergencyMessage(
            riderName: riderName,
            alertType: alertType,
            location: location
        )

        // Mark contacts as recently notified
        let now = Date()
        for contact in eligibleContacts {
            recentlySMSedContacts[contact.id] = now
        }

        // Return the message and contacts - actual sending requires UI
        let phoneNumbers = eligibleContacts.compactMap { $0.phoneNumber }

        Log.family.info("""
            Emergency SMS prepared for \(eligibleContacts.count) contact(s)
            Alert type: \(alertType.rawValue)
            Location: \(location.latitude), \(location.longitude)
            """)

        return SMSResult(
            success: true,
            contactsNotified: eligibleContacts.map { $0.name },
            failures: [],
            message: message,
            phoneNumbers: phoneNumbers
        )
    }

    /// Check if we should send SMS to a contact (throttle check)
    func shouldSendSMS(to contactID: String) -> Bool {
        guard let lastSent = recentlySMSedContacts[contactID] else {
            return true
        }
        return Date().timeIntervalSince(lastSent) >= smsThrottleInterval
    }

    /// Clear throttle state for a contact
    func clearThrottle(for contactID: String) {
        recentlySMSedContacts.removeValue(forKey: contactID)
    }

    /// Clear all throttle state
    func clearAllThrottles() {
        recentlySMSedContacts.removeAll()
    }

    // MARK: - Message Generation

    private func generateEmergencyMessage(
        riderName: String,
        alertType: SafetyAlertType,
        location: CLLocationCoordinate2D
    ) -> String {
        let alertDescription: String
        switch alertType {
        case .warning:
            alertDescription = "has stopped moving and may need assistance"
        case .urgent:
            alertDescription = "has been stationary for an extended period - URGENT"
        case .fall:
            alertDescription = "may have fallen - IMMEDIATE ATTENTION NEEDED"
        case .rideStarted, .rideEnded:
            // These are informational, not emergency alerts
            alertDescription = "ride status has changed"
        }

        // Generate Apple Maps link
        let mapsURL = "https://maps.apple.com/?ll=\(location.latitude),\(location.longitude)&q=\(riderName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Rider")"

        return """
        TETRATRACK SAFETY ALERT

        \(riderName) \(alertDescription).

        Location: \(mapsURL)

        GPS: \(String(format: "%.6f", location.latitude)), \(String(format: "%.6f", location.longitude))

        This message was sent automatically because push notification delivery failed.
        """
    }
}

// MARK: - SMS Contact

/// Lightweight contact struct for SMS operations
struct SMSContact {
    let id: String
    let name: String
    let phoneNumber: String?
    let isPrimary: Bool

    init(from relationship: SharingRelationship) {
        self.id = relationship.id.uuidString
        self.name = relationship.name
        self.phoneNumber = relationship.phoneNumber
        self.isPrimary = relationship.isPrimaryEmergency
    }

    init(id: String, name: String, phoneNumber: String?, isPrimary: Bool = false) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.isPrimary = isPrimary
    }
}

// MARK: - SMS Result

struct SMSResult {
    let success: Bool
    let contactsNotified: [String]
    let failures: [String]
    var message: String?
    var phoneNumbers: [String]?

    var summary: String {
        if success {
            return "SMS prepared for: \(contactsNotified.joined(separator: ", "))"
        } else {
            return "SMS failed: \(failures.joined(separator: "; "))"
        }
    }
}

// MARK: - SMS Composer View (SwiftUI)

import SwiftUI

/// SwiftUI wrapper for MFMessageComposeViewController
struct SMSComposerView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    var onComplete: ((MessageComposeResult) -> Void)?

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = recipients
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onComplete: ((MessageComposeResult) -> Void)?

        init(onComplete: ((MessageComposeResult) -> Void)?) {
            self.onComplete = onComplete
        }

        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            onComplete?(result)
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - SMS Alert Button (for UI integration)

struct EmergencySMSButton: View {
    let riderName: String
    let alertType: SafetyAlertType
    let location: CLLocationCoordinate2D
    let contacts: [SMSContact]

    @State private var showingSMSComposer = false
    @State private var smsMessage = ""
    @State private var smsRecipients: [String] = []
    @State private var showingNoSMSAlert = false

    var body: some View {
        Button {
            Task {
                await prepareAndShowSMS()
            }
        } label: {
            Label("Send Emergency SMS", systemImage: "message.fill")
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .sheet(isPresented: $showingSMSComposer) {
            SMSComposerView(
                recipients: smsRecipients,
                body: smsMessage
            ) { result in
                showingSMSComposer = false
                if result == .sent {
                    Log.family.info("Emergency SMS sent successfully")
                }
            }
        }
        .alert("SMS Not Available", isPresented: $showingNoSMSAlert) {
            Button("OK") {}
        } message: {
            Text("This device cannot send SMS messages. Please use a phone to contact emergency services.")
        }
    }

    private func prepareAndShowSMS() async {
        let result = await SMSEmergencyService.shared.sendEmergencySMS(
            riderName: riderName,
            alertType: alertType,
            location: location,
            contacts: contacts
        )

        await MainActor.run {
            if result.success, let message = result.message, let phones = result.phoneNumbers {
                smsMessage = message
                smsRecipients = phones
                showingSMSComposer = true
            } else {
                showingNoSMSAlert = true
            }
        }
    }
}
