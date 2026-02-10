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

    private func processShareMetadata(_ metadata: CKShare.Metadata) async {
        let ownerName = metadata.ownerIdentity.nameComponents?.formatted() ?? "Family Member"
        let ownerID = metadata.share.owner.userIdentity.userRecordID?.recordName ?? "unknown"

        Log.family.info("Processing share from \(ownerName) (ID: \(ownerID))")
        Log.family.info("Container: \(metadata.containerIdentifier)")
        Log.family.info("Share record ID: \(metadata.share.recordID.recordName)")

        do {
            let container = CKContainer(identifier: metadata.containerIdentifier)
            try await container.accept(metadata)
            Log.family.info("✅ Share accepted successfully!")

            // Add linked rider
            await MainActor.run {
                UnifiedSharingCoordinator.shared.addLinkedRider(riderID: ownerID, name: ownerName)
            }

            // Show success alert
            await MainActor.run {
                showAlert(title: "Success!", message: "Connected with \(ownerName)! They should now appear in Shared With Me.")
            }
        } catch {
            Log.family.error("❌ Failed to accept share: \(error)")

            var errorMsg = error.localizedDescription
            if let ckError = error as? CKError {
                errorMsg = "CKError \(ckError.code.rawValue): \(ckError.localizedDescription)"

                // Check for more details
                if let underlying = ckError.userInfo[NSUnderlyingErrorKey] as? Error {
                    errorMsg += "\nUnderlying: \(underlying.localizedDescription)"
                }
            }

            // Show error alert
            await MainActor.run {
                showAlert(title: "Share Failed", message: errorMsg)
            }
        }
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
