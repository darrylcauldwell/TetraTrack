//
//  SceneDelegate.swift
//  TetraTrack
//
//  Handles CloudKit share acceptance in scene-based SwiftUI apps.
//  Required because WindowGroup uses UIScene lifecycle.
//

import UIKit
import CloudKit
import os

class SceneDelegate: NSObject, UIWindowSceneDelegate {

    // MARK: - CloudKit Share Handling

    /// Called when user accepts a CloudKit share via iCloud.com share URL
    /// This is the scene-based equivalent of application(_:userDidAcceptCloudKitShareWith:)
    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Log.family.info("SceneDelegate: userDidAcceptCloudKitShareWith called")
        Log.family.info("Share container: \(cloudKitShareMetadata.containerIdentifier)")
        Log.family.info("Share owner: \(cloudKitShareMetadata.ownerIdentity.nameComponents?.formatted() ?? "Unknown")")

        // Store metadata for processing
        SceneDelegate.pendingShareMetadata = cloudKitShareMetadata

        // Post notification for SwiftUI to handle
        NotificationCenter.default.post(
            name: .didAcceptCloudKitShare,
            object: nil,
            userInfo: ["metadata": cloudKitShareMetadata]
        )

        // Process immediately
        Task {
            await processShareMetadata(cloudKitShareMetadata)
        }
    }

    /// Single point of share acceptance — called by both `userDidAcceptCloudKitShareWith`
    /// and the cold-launch path in `scene(_:willConnectTo:options:)`.
    /// Guard ensures only ONE accept attempt runs per share URL.
    private static var acceptingShareURL: String?

    private func processShareMetadata(_ metadata: CKShare.Metadata) async {
        let shareURL = metadata.share.url?.absoluteString ?? metadata.share.recordID.recordName

        // Prevent duplicate accepts (SceneDelegate + TetraTrackApp can both fire)
        guard SceneDelegate.acceptingShareURL != shareURL else {
            Log.family.debug("Share already being processed, skipping duplicate: \(shareURL)")
            return
        }
        SceneDelegate.acceptingShareURL = shareURL
        defer { SceneDelegate.acceptingShareURL = nil }

        let ownerName = metadata.ownerIdentity.nameComponents?.formatted() ?? "Family Member"
        let ownerID = metadata.share.owner.userIdentity.userRecordID?.recordName ?? "unknown"

        Log.family.info("Processing share from \(ownerName) (ID: \(ownerID))")
        Log.family.info("Container: \(metadata.containerIdentifier)")
        Log.family.info("Share record ID: \(metadata.share.recordID.recordName)")
        Log.family.info("Build type: \(Self.buildEnvironmentDescription)")

        do {
            // Use the app's default container — this ensures we accept in the
            // same environment the app is running in.
            let container = CKContainer.default()
            try await container.accept(metadata)
            Log.family.info("Share accepted successfully!")

            // Add linked rider
            await MainActor.run {
                UnifiedSharingCoordinator.shared.addLinkedRider(riderID: ownerID, name: ownerName)
            }

            // Refresh subscriptions for the new shared zone
            await NotificationManager.shared.setupCloudKitSubscriptions()

            // Fetch locations to populate status
            await UnifiedSharingCoordinator.shared.fetchFamilyLocations()

            await MainActor.run {
                showAlert(
                    title: "Connected!",
                    message: "You're now linked with \(ownerName). Their live location will appear in Shared With Me when they ride."
                )
            }
        } catch {
            Log.family.error("Failed to accept share: \(error)")

            let errorMsg: String
            if let ckError = error as? CKError {
                switch ckError.code {
                case .unknownItem:
                    // CKError 11 — most common cause is environment mismatch
                    errorMsg = "Share not found.\n\nThis usually means the share was created on a different build type." +
                        " Both phones must use the same type:\n• Both from Xcode, OR\n• Both from TestFlight" +
                        "\n\nYour build: \(Self.buildEnvironmentDescription)"
                case .alreadyShared:
                    errorMsg = "You're already connected with \(ownerName)."
                case .networkUnavailable, .networkFailure:
                    errorMsg = "No internet connection. Please try again."
                case .notAuthenticated:
                    errorMsg = "Please sign in to iCloud in Settings."
                case .participantMayNeedVerification:
                    errorMsg = "Your iCloud account needs verification. Check Settings > Apple ID."
                default:
                    errorMsg = "CKError \(ckError.code.rawValue): \(ckError.localizedDescription)"
                }
            } else {
                errorMsg = error.localizedDescription
            }

            await MainActor.run {
                showAlert(title: "Share Failed", message: errorMsg)
            }
        }
    }

    /// Detect whether this is a Development (Xcode) or Production (TestFlight/App Store) build.
    /// CloudKit shares only work within the same environment.
    static var buildEnvironmentDescription: String {
        #if DEBUG
        return "Xcode (Development)"
        #else
        if let receiptURL = Bundle.main.appStoreReceiptURL {
            if receiptURL.lastPathComponent == "sandboxReceipt" {
                return "TestFlight (Production)"
            }
            return "App Store (Production)"
        }
        return "Release (Production)"
        #endif
    }

    private func showAlert(title: String, message: String) {
        // Find the active window scene and show alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            // Dismiss any existing alert first
            rootVC.dismiss(animated: false)

            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))

            // Find the topmost presented controller
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(alert, animated: true)
        }
    }

    // Static storage for pending share metadata
    static var pendingShareMetadata: CKShare.Metadata?

    // MARK: - Scene Lifecycle

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        Log.family.info("🔗 SceneDelegate: scene willConnectTo called")

        // Check for CloudKit share in connection options
        if let cloudKitShareMetadata = connectionOptions.cloudKitShareMetadata {
            Log.family.info("Found CloudKit share metadata in connection options!")
            Log.family.info("Owner: \(cloudKitShareMetadata.ownerIdentity.nameComponents?.formatted() ?? "Unknown")")

            // Process the share
            Task {
                await processShareMetadata(cloudKitShareMetadata)
            }
        }

        // Check for URL contexts
        if !connectionOptions.urlContexts.isEmpty {
            Log.family.info("Found \(connectionOptions.urlContexts.count) URL contexts")
            for urlContext in connectionOptions.urlContexts {
                Log.family.info("URL context: \(urlContext.url.absoluteString)")
                NotificationCenter.default.post(
                    name: .didReceiveShareURL,
                    object: nil,
                    userInfo: ["url": urlContext.url]
                )
            }
        }

        // Check for user activities
        if !connectionOptions.userActivities.isEmpty {
            Log.family.info("Found \(connectionOptions.userActivities.count) user activities")
            for activity in connectionOptions.userActivities {
                Log.family.info("User activity: \(activity.activityType)")
                if activity.activityType == NSUserActivityTypeBrowsingWeb,
                   let url = activity.webpageURL {
                    Log.family.info("Web URL from activity: \(url.absoluteString)")
                    NotificationCenter.default.post(
                        name: .didReceiveShareURL,
                        object: nil,
                        userInfo: ["url": url]
                    )
                }
            }
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        Log.family.info("🔗 SceneDelegate: openURLContexts called with \(URLContexts.count) URLs")

        for urlContext in URLContexts {
            let url = urlContext.url
            Log.family.info("URL: \(url.absoluteString)")

            NotificationCenter.default.post(
                name: .didReceiveShareURL,
                object: nil,
                userInfo: ["url": url]
            )
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        Log.family.info("🔄 SceneDelegate: continue userActivity called")
        Log.family.info("Activity type: \(userActivity.activityType)")

        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            Log.family.info("Web URL: \(url.absoluteString)")
            NotificationCenter.default.post(
                name: .didReceiveShareURL,
                object: nil,
                userInfo: ["url": url]
            )
        }
    }
}
