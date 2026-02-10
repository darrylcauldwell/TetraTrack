//
//  SafetyAlertService.swift
//  TetraTrack
//
//  Actor-based service for managing safety alerts (stationary/fall detection).
//  Monitors linked riders and sends alerts when they've been stationary too long.
//

import Foundation
import CoreLocation
import os

// MARK: - Safety Alert Service

actor SafetyAlertService {
    // MARK: Thresholds

    /// Time before warning alert (2 minutes)
    static let warningThreshold: TimeInterval = 120

    /// Time before urgent alert (5 minutes)
    static let urgentThreshold: TimeInterval = 300

    /// Time before logging warning about unacknowledged alerts (30 seconds)
    static let acknowledgmentTimeout: TimeInterval = 30

    /// Time before triggering SMS fallback (2 minutes)
    static let smsFallbackTimeout: TimeInterval = 120

    // MARK: State

    /// Rider IDs we've sent warning alerts for
    private var sentWarningAlerts: Set<String> = []

    /// Rider IDs we've sent urgent alerts for
    private var sentUrgentAlerts: Set<String> = []

    /// Notification manager reference
    private let notificationManager: NotificationManager

    // MARK: Delivery Verification

    /// Pending alert acknowledgments with timestamps and location
    /// Key: alertID (riderID + timestamp), Value: PendingAlert with full details
    private var pendingAcknowledgments: [String: PendingAlert] = [:]

    /// Task for checking acknowledgment timeouts
    private var acknowledgmentCheckTask: Task<Void, Never>?

    /// Callback to get emergency contacts (set by coordinator)
    var emergencyContactsProvider: (() async -> [SMSContact])?

    /// Track alerts that have already triggered SMS fallback
    private var smsTriggeredAlerts: Set<String> = []

    // MARK: Initialization

    init(notificationManager: NotificationManager = .shared) {
        self.notificationManager = notificationManager
    }

    // MARK: - Pending Alert

    struct PendingAlert {
        let riderID: String
        let riderName: String
        let sentTime: Date
        let alertType: SafetyAlertType
        let location: CLLocationCoordinate2D
    }

    // MARK: - Check for Safety Alerts

    /// Check a session for safety alerts and send if needed
    func checkSession(_ session: LiveTrackingSession) async {
        guard session.isActive else {
            // Session is inactive - DO NOT clear alerts automatically
            // If the rider was stationary and their device went offline, that's MORE concerning
            // Only manual dismissal or confirmed movement should clear alerts
            return
        }

        guard session.isStationary else {
            // Rider is confirmed moving - safe to clear alerts
            clearAlertsForRider(session.riderID)
            return
        }

        let duration = session.stationaryDuration

        // Urgent alert (5+ minutes)
        if duration >= Self.urgentThreshold {
            // Use atomic insert - returns (inserted: Bool, memberAfterInsert: Element)
            // This is safer than check-then-act pattern
            let (inserted, _) = sentUrgentAlerts.insert(session.riderID)
            if inserted {
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

                // Track delivery for verification with location for SMS fallback
                trackAlertDelivery(
                    riderID: session.riderID,
                    riderName: session.riderName,
                    alertType: .urgent,
                    location: CLLocationCoordinate2D(
                        latitude: session.currentLatitude,
                        longitude: session.currentLongitude
                    )
                )

                Log.family.info("Sent urgent alert for \(session.riderName)")
            }
        }
        // Warning alert (2+ minutes)
        else if duration >= Self.warningThreshold {
            // Use atomic insert - returns (inserted: Bool, memberAfterInsert: Element)
            let (inserted, _) = sentWarningAlerts.insert(session.riderID)
            if inserted {
                // Send local notification
                notificationManager.sendLocalStationaryWarning(
                    riderName: session.riderName,
                    duration: duration
                )

                // Track delivery for verification with location for SMS fallback
                trackAlertDelivery(
                    riderID: session.riderID,
                    riderName: session.riderName,
                    alertType: .warning,
                    location: CLLocationCoordinate2D(
                        latitude: session.currentLatitude,
                        longitude: session.currentLongitude
                    )
                )

                Log.family.info("Sent warning alert for \(session.riderName)")
            }
        }
    }

    // MARK: - Check Multiple Sessions

    /// Check all provided sessions for safety alerts
    func checkSessions(_ sessions: [LiveTrackingSession]) async {
        for session in sessions where session.isActive {
            await checkSession(session)
        }

        // Clear alerts for riders who are no longer active or stationary
        clearResolvedAlerts(activeSessions: sessions.filter { $0.isActive })
    }

    // MARK: - Clear Alerts

    /// Clear alerts for a specific rider
    private func clearAlertsForRider(_ riderID: String) {
        if sentWarningAlerts.remove(riderID) != nil {
            notificationManager.clearNotificationsForRider(riderID)
        }
        if sentUrgentAlerts.remove(riderID) != nil {
            notificationManager.clearNotificationsForRider(riderID)
        }
    }

    /// Clear alerts for riders who are confirmed moving again.
    /// IMPORTANT: Does NOT clear alerts when session goes inactive - that could be an emergency
    private func clearResolvedAlerts(activeSessions: [LiveTrackingSession]) {
        // Only clear alerts for riders who are actively confirmed moving
        // If a session disappears (device offline), keep the alert - this is MORE concerning
        let confirmedMovingRiderIDs = Set(
            activeSessions
                .filter { $0.isActive && !$0.isStationary }
                .map { $0.riderID }
        )

        // Clear warning alerts only for riders confirmed to be moving
        for riderID in sentWarningAlerts {
            if confirmedMovingRiderIDs.contains(riderID) {
                sentWarningAlerts.remove(riderID)
                notificationManager.clearNotificationsForRider(riderID)
                Log.family.info("Cleared warning alert for \(riderID) - confirmed moving")
            }
        }

        // Clear urgent alerts only for riders confirmed to be moving
        for riderID in sentUrgentAlerts {
            if confirmedMovingRiderIDs.contains(riderID) {
                sentUrgentAlerts.remove(riderID)
                notificationManager.clearNotificationsForRider(riderID)
                Log.family.info("Cleared urgent alert for \(riderID) - confirmed moving")
            }
        }
    }

    /// Manually dismiss an alert (user confirmed they're OK)
    func dismissAlert(for riderID: String) {
        sentWarningAlerts.remove(riderID)
        sentUrgentAlerts.remove(riderID)
        notificationManager.clearNotificationsForRider(riderID)
        Log.family.info("User dismissed alert for \(riderID)")
    }

    // MARK: - Alert State

    /// Check if a rider has a pending warning
    func hasWarning(for riderID: String) -> Bool {
        sentWarningAlerts.contains(riderID)
    }

    /// Check if a rider has a pending urgent alert
    func hasUrgentAlert(for riderID: String) -> Bool {
        sentUrgentAlerts.contains(riderID)
    }

    /// Clear all alerts (e.g., when session ends)
    func clearAllAlerts() {
        for riderID in sentWarningAlerts {
            notificationManager.clearNotificationsForRider(riderID)
        }
        for riderID in sentUrgentAlerts {
            notificationManager.clearNotificationsForRider(riderID)
        }
        sentWarningAlerts.removeAll()
        sentUrgentAlerts.removeAll()

        // Clear pending acknowledgments and SMS tracking
        pendingAcknowledgments.removeAll()
        smsTriggeredAlerts.removeAll()
        acknowledgmentCheckTask?.cancel()
        acknowledgmentCheckTask = nil
    }

    // MARK: - Delivery Verification

    /// Track an alert that was sent and needs acknowledgment
    /// Called after sending alert to CloudKit
    func trackAlertDelivery(
        riderID: String,
        riderName: String,
        alertType: SafetyAlertType,
        location: CLLocationCoordinate2D
    ) {
        let alertID = "\(riderID)-\(Date().timeIntervalSince1970)"
        pendingAcknowledgments[alertID] = PendingAlert(
            riderID: riderID,
            riderName: riderName,
            sentTime: Date(),
            alertType: alertType,
            location: location
        )

        Log.family.info("Tracking alert delivery for \(riderName), type: \(alertType.rawValue)")

        // Start acknowledgment check if not already running
        startAcknowledgmentCheck()
    }

    /// Mark an alert as acknowledged (family member received it)
    /// Called when we receive confirmation of delivery
    func acknowledgeAlert(for riderID: String) {
        // Remove all pending alerts for this rider
        let keysToRemove = pendingAcknowledgments.keys.filter { key in
            pendingAcknowledgments[key]?.riderID == riderID
        }

        for key in keysToRemove {
            if let pending = pendingAcknowledgments.removeValue(forKey: key) {
                let deliveryTime = Date().timeIntervalSince(pending.sentTime)
                Log.family.info("Alert acknowledged for \(riderID) after \(String(format: "%.1f", deliveryTime))s")

                // Also clear from SMS triggered set
                let alertID = key
                smsTriggeredAlerts.remove(alertID)
            }
        }
    }

    /// Start the acknowledgment timeout check task
    private func startAcknowledgmentCheck() {
        guard acknowledgmentCheckTask == nil else { return }

        acknowledgmentCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(10))  // Check every 10 seconds
                } catch {
                    break
                }

                guard let self = self else { break }
                await self.checkAcknowledgmentTimeouts()
            }
        }
    }

    /// Check for alerts that haven't been acknowledged within the timeout
    private func checkAcknowledgmentTimeouts() async {
        let now = Date()
        var expiredAlerts: [(alertID: String, pending: PendingAlert, waitTime: TimeInterval)] = []

        for (alertID, pending) in pendingAcknowledgments {
            let waitTime = now.timeIntervalSince(pending.sentTime)
            if waitTime >= Self.acknowledgmentTimeout {
                expiredAlerts.append((alertID, pending, waitTime))
            }
        }

        for expired in expiredAlerts {
            Log.family.warning("""
                SAFETY ALERT DELIVERY NOT CONFIRMED
                - Rider: \(expired.pending.riderName)
                - Alert Type: \(expired.pending.alertType.rawValue)
                - Waiting: \(String(format: "%.0f", expired.waitTime)) seconds
                - Family members may not have received this alert!
                """)

            // After SMS fallback timeout, trigger SMS to emergency contacts
            if expired.waitTime >= Self.smsFallbackTimeout && !smsTriggeredAlerts.contains(expired.alertID) {
                Log.family.error("""
                    CRITICAL: Safety alert for \(expired.pending.riderName) undelivered for \(String(format: "%.0f", expired.waitTime))s
                    Triggering SMS fallback to emergency contacts
                    """)

                // Mark as SMS triggered to prevent duplicate sends
                smsTriggeredAlerts.insert(expired.alertID)

                // Send a local notification to the rider about delivery failure
                await notificationManager.sendAlertDeliveryWarning(riderName: expired.pending.riderName)

                // Trigger SMS fallback if emergency contacts are available
                await triggerSMSFallback(for: expired.pending)

                // Remove from tracking after SMS fallback
                pendingAcknowledgments.removeValue(forKey: expired.alertID)
            }
        }

        // Stop checking if no pending alerts
        if pendingAcknowledgments.isEmpty {
            acknowledgmentCheckTask?.cancel()
            acknowledgmentCheckTask = nil
        }
    }

    /// Trigger SMS fallback for an undelivered alert
    private func triggerSMSFallback(for alert: PendingAlert) async {
        // Get emergency contacts
        guard let provider = emergencyContactsProvider else {
            Log.family.warning("No emergency contacts provider configured for SMS fallback")
            return
        }

        let contacts = await provider()
        let emergencyContacts = contacts.filter { $0.phoneNumber != nil && !$0.phoneNumber!.isEmpty }

        guard !emergencyContacts.isEmpty else {
            Log.family.warning("No emergency contacts with phone numbers for SMS fallback")
            return
        }

        // Prepare and send SMS
        let result = await SMSEmergencyService.shared.sendEmergencySMS(
            riderName: alert.riderName,
            alertType: alert.alertType,
            location: alert.location,
            contacts: emergencyContacts
        )

        if result.success {
            Log.family.info("SMS fallback prepared for \(result.contactsNotified.count) contact(s)")
            // Note: Actual SMS sending requires UI - the result contains the message and recipients
            // The app will need to present an SMS composer or use background SMS if available
        } else {
            Log.family.error("SMS fallback failed: \(result.failures.joined(separator: ", "))")
        }
    }

    /// Get count of alerts pending delivery confirmation
    func pendingDeliveryCount() -> Int {
        pendingAcknowledgments.count
    }

    /// Check if there are any alerts with potential delivery issues
    func hasDeliveryIssues() -> Bool {
        let now = Date()
        return pendingAcknowledgments.values.contains { pending in
            now.timeIntervalSince(pending.sentTime) >= Self.acknowledgmentTimeout
        }
    }
}
