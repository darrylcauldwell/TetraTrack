//
//  NotificationManager.swift
//  TrackRide
//

import UserNotifications
import CloudKit
import Observation
import SwiftData
import CoreLocation
import MessageUI
import os

@Observable
final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    var isAuthorized: Bool = false
    var pendingAlerts: [SafetyAlert] = []

    private let notificationCenter = UNUserNotificationCenter.current()

    // CloudKit enabled - iCloud entitlement configured in TrackRide.entitlements
    // Container: iCloud.MyHorse.TrackRide
    private let cloudKitEnabled = true

    private var container: CKContainer? {
        guard cloudKitEnabled else { return nil }
        return CKContainer.default()
    }

    // Alert thresholds
    static let stationaryWarningThreshold: TimeInterval = 120  // 2 minutes - warning
    static let stationaryAlertThreshold: TimeInterval = 300    // 5 minutes - urgent alert

    private override init() {
        super.init()
        notificationCenter.delegate = self
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge, .criticalAlert]
            let granted = try await notificationCenter.requestAuthorization(options: options)
            await MainActor.run {
                self.isAuthorized = granted
            }
            return granted
        } catch {
            Log.notifications.error("Notification authorization failed: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        await MainActor.run {
            self.isAuthorized = settings.authorizationStatus == .authorized
        }
    }

    // MARK: - Local Notifications

    func sendLocalStationaryWarning(riderName: String, duration: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Rider Stationary"
        content.body = "\(riderName) has stopped moving for \(Int(duration / 60)) minutes"
        content.sound = .default
        content.categoryIdentifier = "SAFETY_ALERT"
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "stationary-warning-\(UUID().uuidString)",
            content: content,
            trigger: nil  // Deliver immediately
        )

        notificationCenter.add(request) { error in
            if let error = error {
                Log.notifications.error("Failed to send notification: \(error)")
            }
        }
    }

    func sendLocalUrgentAlert(riderName: String, duration: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Safety Alert"
        content.body = "\(riderName) has been stationary for \(Int(duration / 60)) minutes. Check on them!"
        content.sound = .defaultCritical
        content.categoryIdentifier = "URGENT_SAFETY_ALERT"
        content.interruptionLevel = .critical

        // Add actions
        let callAction = UNNotificationAction(
            identifier: "CALL_RIDER",
            title: "Call Rider",
            options: .foreground
        )
        let viewAction = UNNotificationAction(
            identifier: "VIEW_LOCATION",
            title: "View Location",
            options: .foreground
        )
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: .destructive
        )

        let category = UNNotificationCategory(
            identifier: "URGENT_SAFETY_ALERT",
            actions: [callAction, viewAction, dismissAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        notificationCenter.setNotificationCategories([category])

        let request = UNNotificationRequest(
            identifier: "urgent-alert-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { error in
            if let error = error {
                Log.notifications.error("Failed to send urgent notification: \(error)")
            }
        }
    }

    func sendRideStartedNotification(riderName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Ride Started"
        content.body = "\(riderName) has started a ride"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "ride-started-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request)
    }

    func sendRideEndedNotification(riderName: String, distance: String, duration: String) {
        let content = UNMutableNotificationContent()
        content.title = "Ride Completed"
        content.body = "\(riderName) finished their ride: \(distance) in \(duration)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "ride-ended-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request)
    }

    // MARK: - AI-Powered Smart Notifications

    /// Send an AI-generated personalized ride completion notification
    func sendSmartRideCompletedNotification(ride: Ride) async {
        if #available(iOS 26.0, *) {
            let service = IntelligenceService.shared
            guard service.isAvailable else {
                // Fall back to standard notification
                sendRideEndedNotification(
                    riderName: "You",
                    distance: ride.formattedDistance,
                    duration: ride.formattedDuration
                )
                return
            }

            do {
                let summary = try await service.summarizeRide(ride)
                let content = UNMutableNotificationContent()
                content.title = "Great Ride!"
                content.subtitle = summary.headline
                content.body = summary.encouragement
                content.sound = .default

                let request = UNNotificationRequest(
                    identifier: "smart-ride-completed-\(UUID().uuidString)",
                    content: content,
                    trigger: nil
                )

                try await notificationCenter.add(request)
            } catch {
                // Fall back to standard notification
                sendRideEndedNotification(
                    riderName: "You",
                    distance: ride.formattedDistance,
                    duration: ride.formattedDuration
                )
            }
        } else {
            sendRideEndedNotification(
                riderName: "You",
                distance: ride.formattedDistance,
                duration: ride.formattedDuration
            )
        }
    }

    /// Send AI-generated training reminder based on patterns
    func scheduleSmartTrainingReminder(recentRides: [Ride]) async {
        guard !recentRides.isEmpty else { return }

        if #available(iOS 26.0, *) {
            let service = IntelligenceService.shared
            guard service.isAvailable else { return }

            do {
                let recommendations = try await service.generateRecommendations(
                    recentRides: recentRides,
                    goals: nil
                )

                guard let topRec = recommendations.first else { return }

                let content = UNMutableNotificationContent()
                content.title = "Training Suggestion"
                content.body = topRec.title + ": " + topRec.description
                content.sound = .default

                // Schedule for tomorrow morning
                var dateComponents = DateComponents()
                dateComponents.hour = 9
                dateComponents.minute = 0

                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: dateComponents,
                    repeats: false
                )

                let request = UNNotificationRequest(
                    identifier: "smart-training-reminder",
                    content: content,
                    trigger: trigger
                )

                try await notificationCenter.add(request)
            } catch {
                Log.notifications.error("Failed to generate training reminder: \(error)")
            }
        }
    }

    /// Send AI-generated recovery notification
    func sendSmartRecoveryNotification(readinessScore: Int, insights: RecoveryInsights?) async {
        let content = UNMutableNotificationContent()

        if let insights = insights {
            content.title = "Recovery Update"
            content.subtitle = insights.status
            content.body = insights.todayRecommendation
        } else {
            content.title = "Recovery Status"
            content.body = readinessScore >= 80
                ? "You're well recovered! Great day for an intense session."
                : readinessScore >= 60
                    ? "Moderate recovery. Consider a balanced workout today."
                    : "Low recovery detected. Take it easy today."
        }

        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "smart-recovery-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        try? await notificationCenter.add(request)
    }

    /// Send weekly AI-generated training summary
    func scheduleWeeklyTrainingSummary(rides: [Ride]) async {
        guard !rides.isEmpty else { return }

        if #available(iOS 26.0, *) {
            let service = IntelligenceService.shared
            guard service.isAvailable else { return }

            do {
                let narrative = try await service.generateWeeklyNarrative(
                    rides: rides,
                    recoveryData: nil
                )

                let content = UNMutableNotificationContent()
                content.title = "Weekly Training Summary"
                content.subtitle = narrative.weekSummary
                content.body = narrative.encouragement
                content.sound = .default

                // Schedule for Sunday evening
                var dateComponents = DateComponents()
                dateComponents.weekday = 1  // Sunday
                dateComponents.hour = 18
                dateComponents.minute = 0

                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: dateComponents,
                    repeats: true
                )

                let request = UNNotificationRequest(
                    identifier: "weekly-training-summary",
                    content: content,
                    trigger: trigger
                )

                try await notificationCenter.add(request)
            } catch {
                Log.notifications.error("Failed to generate weekly summary: \(error)")
            }
        }
    }

    /// Send balance improvement notification when milestones are reached
    func sendBalanceImprovementNotification(
        currentBalance: Int,
        previousBalance: Int,
        type: String
    ) {
        // Only notify on significant improvement toward 50%
        let currentDiff = abs(currentBalance - 50)
        let previousDiff = abs(previousBalance - 50)

        guard previousDiff - currentDiff >= 5 else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(type) Balance Improved!"
        content.body = "Great progress! Your \(type.lowercased()) balance is now \(currentBalance)% / \(100 - currentBalance)%, moving closer to the ideal 50/50 split."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "balance-improvement-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { error in
            if let error = error {
                Log.notifications.error("Failed to send balance notification: \(error)")
            }
        }
    }

    // MARK: - CloudKit Remote Notifications

    func setupCloudKitSubscriptions() async {
        guard isAuthorized, let container = container else { return }

        let privateDB = container.privateCloudDatabase

        // Subscribe to safety alerts
        let alertSubscription = CKQuerySubscription(
            recordType: "SafetyAlert",
            predicate: NSPredicate(value: true),
            subscriptionID: "safety-alert-subscription",
            options: [.firesOnRecordCreation]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.titleLocalizationKey = "%1$@"
        notificationInfo.titleLocalizationArgs = ["title"]
        notificationInfo.alertLocalizationKey = "%1$@"
        notificationInfo.alertLocalizationArgs = ["message"]
        notificationInfo.soundName = "default"
        notificationInfo.shouldBadge = true
        notificationInfo.shouldSendContentAvailable = true

        alertSubscription.notificationInfo = notificationInfo

        do {
            _ = try await privateDB.save(alertSubscription)
            Log.notifications.info("Safety alert subscription created")
        } catch {
            // Subscription may already exist
            Log.notifications.debug("Subscription setup: \(error.localizedDescription)")
        }
    }

    // MARK: - Create Remote Alert

    func createRemoteSafetyAlert(
        riderName: String,
        riderID: String,
        alertType: SafetyAlertType,
        location: (latitude: Double, longitude: Double),
        stationaryDuration: TimeInterval
    ) async {
        guard let container = container else { return }
        let privateDB = container.privateCloudDatabase

        let record = CKRecord(recordType: "SafetyAlert")
        record["riderName"] = riderName
        record["riderID"] = riderID
        record["alertType"] = alertType.rawValue
        record["latitude"] = location.latitude
        record["longitude"] = location.longitude
        record["stationaryDuration"] = stationaryDuration
        record["timestamp"] = Date()
        record["isResolved"] = false
        record["title"] = alertType == .urgent ? "⚠️ Safety Alert" : "Rider Stationary"
        record["message"] = "\(riderName) has been stationary for \(Int(stationaryDuration / 60)) minutes"

        do {
            _ = try await privateDB.save(record)
            Log.notifications.info("Remote safety alert created")
        } catch {
            Log.notifications.error("Failed to create remote alert: \(error)")
        }
    }

    // MARK: - Fall Detection Emergency Alerts

    func sendFallDetectionAlert(
        location: CLLocationCoordinate2D?,
        contacts: [EmergencyContact],
        riderName: String = "Rider"
    ) async {
        guard !contacts.isEmpty else {
            Log.notifications.warning("No emergency contacts configured")
            return
        }

        // Build location string
        var locationMessage = ""
        if let loc = location {
            // Create Apple Maps link for precise location
            let mapsURL = "https://maps.apple.com/?ll=\(loc.latitude),\(loc.longitude)"
            locationMessage = "\n\nLocation: \(mapsURL)\nCoordinates: \(String(format: "%.6f, %.6f", loc.latitude, loc.longitude))"
        }

        let alertMessage = """
⚠️ EMERGENCY ALERT from TrackRide

\(riderName) may have had a fall while riding and did not respond to the safety check.

Please try to contact them immediately or check on their location.\(locationMessage)

This is an automated message from TrackRide.
"""

        // Send SMS to all emergency contacts who have notifyOnFall enabled
        for contact in contacts where contact.notifyOnFall {
            await sendEmergencySMS(to: contact, message: alertMessage)
        }

        // Also send a local notification
        sendLocalFallAlert(riderName: riderName)

        // Create CloudKit record for family members
        if let loc = location {
            await createRemoteFallAlert(
                riderName: riderName,
                location: (latitude: loc.latitude, longitude: loc.longitude)
            )
        }
    }

    private func sendEmergencySMS(to contact: EmergencyContact, message: String) async {
        // On iOS, we can't send SMS programmatically without user interaction
        // However, we can prepare the SMS URL and open it
        guard let smsURL = contact.smsURLWithBody(message) else { return }

        // This will need to be handled by the UI layer to open the SMS compose view
        // Store pending SMS for UI to handle
        await MainActor.run {
            pendingEmergencySMS.append(PendingEmergencySMS(
                contact: contact,
                message: message,
                url: smsURL
            ))
        }

        // Post notification for UI to handle
        NotificationCenter.default.post(
            name: .emergencySMSPending,
            object: nil,
            userInfo: ["contact": contact.name, "url": smsURL]
        )
    }

    @MainActor
    var pendingEmergencySMS: [PendingEmergencySMS] = []

    func sendLocalFallAlert(riderName: String) {
        let content = UNMutableNotificationContent()
        content.title = "🚨 Fall Detected"
        content.body = "Emergency contacts have been notified. Help is on the way."
        content.sound = .defaultCritical
        content.categoryIdentifier = "FALL_ALERT"
        content.interruptionLevel = .critical

        let request = UNNotificationRequest(
            identifier: "fall-alert-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request)
    }

    private func createRemoteFallAlert(
        riderName: String,
        location: (latitude: Double, longitude: Double)
    ) async {
        guard let container = container else { return }
        let privateDB = container.privateCloudDatabase

        let record = CKRecord(recordType: "SafetyAlert")
        record["riderName"] = riderName
        record["riderID"] = UUID().uuidString
        record["alertType"] = "fall"
        record["latitude"] = location.latitude
        record["longitude"] = location.longitude
        record["stationaryDuration"] = 0.0
        record["timestamp"] = Date()
        record["isResolved"] = false
        record["title"] = "🚨 Fall Detected"
        record["message"] = "\(riderName) may have fallen. Emergency contacts notified."

        do {
            _ = try await privateDB.save(record)
            Log.notifications.info("Remote fall alert created")
        } catch {
            Log.notifications.error("Failed to create remote fall alert: \(error)")
        }
    }

    // MARK: - Clear Notifications

    func clearAllNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
        notificationCenter.removeAllPendingNotificationRequests()
    }

    func clearNotificationsForRider(_ riderID: String) {
        notificationCenter.getDeliveredNotifications { notifications in
            let idsToRemove = notifications
                .filter { $0.request.identifier.contains(riderID) }
                .map { $0.request.identifier }
            self.notificationCenter.removeDeliveredNotifications(withIdentifiers: idsToRemove)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show notifications even when app is in foreground
        return [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let actionIdentifier = response.actionIdentifier

        switch actionIdentifier {
        case "CALL_RIDER":
            // Handle call action - would need to store phone number
            Log.notifications.debug("Call rider action triggered")
        case "VIEW_LOCATION":
            // Handle view location - post notification to open map
            NotificationCenter.default.post(name: .openLiveTracking, object: nil)
        case "DISMISS":
            // User dismissed the alert
            Log.notifications.debug("Alert dismissed")
        default:
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openLiveTracking = Notification.Name("openLiveTracking")
    static let emergencySMSPending = Notification.Name("emergencySMSPending")
}

// MARK: - Pending Emergency SMS

struct PendingEmergencySMS: Identifiable {
    let id = UUID()
    let contact: EmergencyContact
    let message: String
    let url: URL
}

// MARK: - Safety Alert Type

enum SafetyAlertType: String, Codable {
    case warning = "warning"      // 2+ minutes stationary
    case urgent = "urgent"        // 5+ minutes stationary
    case rideStarted = "started"
    case rideEnded = "ended"
}

// MARK: - Safety Alert Model

struct SafetyAlert: Identifiable, Codable {
    var id: UUID = UUID()
    var riderName: String
    var riderID: String
    var alertType: SafetyAlertType
    var latitude: Double
    var longitude: Double
    var stationaryDuration: TimeInterval
    var timestamp: Date
    var isResolved: Bool

    var formattedDuration: String {
        "\(Int(stationaryDuration / 60)) min"
    }
}
