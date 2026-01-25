//
//  CloudKitAccountService.swift
//  TrackRide
//
//  Actor-based service for CloudKit account status checking.
//  Provides thread-safe access to iCloud account information.
//

import Foundation
import CloudKit
import UIKit
import os

// MARK: - CloudKit Account Service

actor CloudKitAccountService {
    // MARK: State

    private(set) var isAvailable: Bool = false
    private(set) var isSignedIn: Bool = false
    private(set) var currentUserID: String = ""
    private(set) var currentUserName: String = ""
    private(set) var lastCheckDate: Date?
    private(set) var lastError: Error?

    // MARK: CloudKit Container

    private let container: CKContainer

    // MARK: Initialization

    init(containerIdentifier: String? = nil) {
        if let identifier = containerIdentifier {
            self.container = CKContainer(identifier: identifier)
        } else {
            self.container = CKContainer.default()
        }
    }

    // MARK: - Account Status

    /// Check and update the current iCloud account status
    @discardableResult
    func checkAccountStatus() async -> Bool {
        lastCheckDate = Date()
        lastError = nil

        do {
            let status = try await container.accountStatus()
            isAvailable = true
            isSignedIn = (status == .available)

            if isSignedIn {
                let userID = try await container.userRecordID()
                currentUserID = userID.recordName

                // Use device name as fallback since CloudKit sharing APIs have changed
                await MainActor.run {
                    self.setUserName(UIDevice.current.name)
                }
            } else {
                currentUserID = ""
                currentUserName = ""
            }

            Log.family.info("CloudKit account status: \(status == .available ? "signed in" : "not signed in")")
            return isSignedIn

        } catch {
            isAvailable = false
            isSignedIn = false
            currentUserID = ""
            currentUserName = ""
            lastError = error
            Log.family.error("CloudKit account check failed: \(error)")
            return false
        }
    }

    private nonisolated func setUserName(_ name: String) {
        Task { await updateUserName(name) }
    }

    private func updateUserName(_ name: String) {
        currentUserName = name
    }

    /// Get account status description for UI display
    var statusDescription: String {
        if !isAvailable {
            return "iCloud unavailable"
        } else if !isSignedIn {
            return "Not signed in to iCloud"
        } else {
            return "Signed in as \(currentUserName)"
        }
    }

    /// Whether sharing features are available
    var canShare: Bool {
        isAvailable && isSignedIn
    }

    // MARK: - Account Change Monitoring

    /// Subscribe to account status changes
    func startMonitoring() async {
        // Initial check
        await checkAccountStatus()

        // Note: In production, you would set up CKContainer.accountStatus(completionHandler:)
        // notifications or use NotificationCenter for CKAccountChanged notifications
        Log.family.info("Started monitoring CloudKit account status")
    }

    // MARK: - Container Access

    /// Get the CloudKit container for advanced operations
    var cloudKitContainer: CKContainer {
        container
    }

    /// Get the private database
    var privateDatabase: CKDatabase {
        container.privateCloudDatabase
    }

    /// Get the shared database
    var sharedDatabase: CKDatabase {
        container.sharedCloudDatabase
    }
}

// MARK: - Account Status Error

enum CloudKitAccountError: Error, LocalizedError {
    case notSignedIn
    case unavailable
    case restricted
    case unknown(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Please sign in to iCloud in Settings to use sharing features."
        case .unavailable:
            return "iCloud is not available on this device."
        case .restricted:
            return "iCloud access is restricted. Please check your device settings."
        case .unknown(let error):
            return "iCloud error: \(error.localizedDescription)"
        }
    }

    static func from(_ status: CKAccountStatus) -> CloudKitAccountError? {
        switch status {
        case .available:
            return nil
        case .noAccount:
            return .notSignedIn
        case .restricted:
            return .restricted
        case .couldNotDetermine, .temporarilyUnavailable:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }
}
