//
//  AppDelegate.swift
//  TrackRide
//
//  UIApplicationDelegate for APNs registration and remote notification handling.
//  Critical for receiving CloudKit push notifications for safety alerts.
//

import UIKit
import CloudKit
import os

class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - Application Lifecycle

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Register for remote notifications (required for CloudKit push)
        application.registerForRemoteNotifications()
        Log.notifications.info("Requested APNs registration for CloudKit push notifications")
        return true
    }

    // MARK: - Remote Notification Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        Log.notifications.info("APNs registration successful. Token: \(tokenString.prefix(16))...")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Log.notifications.error("APNs registration failed: \(error.localizedDescription)")

        // Check for specific errors
        if let nsError = error as NSError? {
            switch nsError.code {
            case 3010:
                // Simulator - expected behavior
                Log.notifications.debug("Running on simulator - APNs not available")
            default:
                Log.notifications.error("APNs error code: \(nsError.code), domain: \(nsError.domain)")
            }
        }
    }

    // MARK: - Remote Notification Handling

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Log.notifications.info("Received remote notification")

        Task {
            let result = await NotificationManager.shared.handleRemoteNotification(userInfo)
            completionHandler(result)
        }
    }
}
