//
//  AppDelegate.swift
//  TetraTrack
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

    // MARK: - Scene Configuration

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        Log.family.info("🔧 AppDelegate: configurationForConnecting called")

        // Check for CloudKit share metadata in options
        if let metadata = options.cloudKitShareMetadata {
            Log.family.info("Found CloudKit share metadata in scene options!")
            Log.family.info("Owner: \(metadata.ownerIdentity.nameComponents?.formatted() ?? "Unknown")")
        }

        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
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

    // MARK: - CloudKit Sharing

    /// Called when user accepts a CloudKit share via iCloud.com share URL
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Log.family.info("🎯 AppDelegate: userDidAcceptCloudKitShareWith CALLED!")
        Log.family.info("Share container: \(cloudKitShareMetadata.containerIdentifier)")
        Log.family.info("Share owner: \(cloudKitShareMetadata.ownerIdentity.nameComponents?.formatted() ?? "Unknown")")

        // Post notification for SwiftUI to handle
        NotificationCenter.default.post(
            name: .didAcceptCloudKitShare,
            object: nil,
            userInfo: ["metadata": cloudKitShareMetadata]
        )
    }

    // MARK: - URL Handling (fallback for share URLs)

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        Log.family.info("🔗 AppDelegate: open URL called: \(url.absoluteString)")

        // Post notification for SwiftUI to handle
        NotificationCenter.default.post(
            name: .didReceiveShareURL,
            object: nil,
            userInfo: ["url": url]
        )

        return true
    }

    // MARK: - User Activity (alternative for CloudKit shares)

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        Log.family.info("🔄 AppDelegate: continue userActivity called")
        Log.family.info("Activity type: \(userActivity.activityType)")

        // Check for CloudKit share
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            Log.family.info("Web URL from activity: \(url.absoluteString)")

            // Check if it's a CloudKit share URL
            if url.host?.contains("icloud.com") == true {
                NotificationCenter.default.post(
                    name: .didReceiveShareURL,
                    object: nil,
                    userInfo: ["url": url]
                )
                return true
            }
        }

        // Check for CloudKit share metadata in userInfo
        if let metadata = userActivity.userInfo?["CKShareMetadata"] as? CKShare.Metadata {
            Log.family.info("Found CKShare.Metadata in userActivity")
            NotificationCenter.default.post(
                name: .didAcceptCloudKitShare,
                object: nil,
                userInfo: ["metadata": metadata]
            )
            return true
        }

        return false
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let didAcceptCloudKitShare = Notification.Name("didAcceptCloudKitShare")
    static let didReceiveShareURL = Notification.Name("didReceiveShareURL")
}
