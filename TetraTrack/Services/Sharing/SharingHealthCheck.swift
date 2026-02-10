//
//  SharingHealthCheck.swift
//  TetraTrack
//
//  Comprehensive health check for the iCloud sharing system.
//  Validates all components and provides actionable diagnostics.
//

import Foundation
import CloudKit
import UserNotifications
import Network
import os

// MARK: - Health Check Status

enum HealthCheckStatus: String {
    case passed = "Passed"
    case warning = "Warning"
    case failed = "Failed"
    case unknown = "Unknown"

    var icon: String {
        switch self {
        case .passed: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .failed: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Health Check Item

struct HealthCheckItem: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    var status: HealthCheckStatus
    var message: String
    var details: String?
    var action: String?
}

// MARK: - Health Check Result

struct SharingHealthCheckResult {
    let timestamp: Date
    let overallStatus: HealthCheckStatus
    let items: [HealthCheckItem]
    let criticalIssues: [String]
    let warnings: [String]

    var isHealthy: Bool {
        overallStatus == .passed || overallStatus == .warning
    }

    var canShareSafely: Bool {
        // Check if critical sharing components are working
        let criticalItems = items.filter { item in
            ["iCloud Account", "CloudKit Zone", "Schema Validation", "Push Notifications"].contains(item.name)
        }
        return criticalItems.allSatisfy { $0.status != .failed }
    }
}

// MARK: - Sharing Health Check Service

@Observable
@MainActor
final class SharingHealthCheck {
    static let shared = SharingHealthCheck()

    // Published state
    private(set) var isRunning = false
    private(set) var lastResult: SharingHealthCheckResult?
    private(set) var lastCheckTime: Date?

    // Dependencies
    private let container = CKContainer.default()
    private let schemaInitializer = CloudKitSchemaInitializer()
    private let networkMonitor = NWPathMonitor()
    private var isNetworkAvailable = true

    private init() {
        setupNetworkMonitoring()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isNetworkAvailable = path.status == .satisfied
            }
        }
        networkMonitor.start(queue: DispatchQueue.global(qos: .utility))
    }

    // MARK: - Run Health Check

    func runFullHealthCheck() async -> SharingHealthCheckResult {
        isRunning = true
        defer { isRunning = false }

        Log.family.info("SharingHealthCheck: Starting full health check")

        var items: [HealthCheckItem] = []
        var criticalIssues: [String] = []
        var warnings: [String] = []

        // 1. Network Connectivity
        let networkItem = checkNetworkConnectivity()
        items.append(networkItem)
        if networkItem.status == .failed {
            criticalIssues.append("No network connection")
        }

        // 2. iCloud Account Status
        let accountItem = await checkiCloudAccount()
        items.append(accountItem)
        if accountItem.status == .failed {
            criticalIssues.append("iCloud account not available")
        }

        // 3. CloudKit Container Access
        let containerItem = await checkCloudKitContainer()
        items.append(containerItem)
        if containerItem.status == .failed {
            criticalIssues.append("Cannot access CloudKit container")
        }

        // 4. FamilySharing Zone
        let zoneItem = await checkFamilySharingZone()
        items.append(zoneItem)
        if zoneItem.status == .failed {
            criticalIssues.append("FamilySharing zone not accessible")
        }

        // 5. Schema Validation
        let schemaItem = await checkSchema()
        items.append(schemaItem)
        if schemaItem.status == .failed {
            criticalIssues.append("CloudKit schema invalid or missing")
        } else if schemaItem.status == .warning {
            warnings.append("Some record types may need initialization")
        }

        // 6. Push Notification Permission
        let pushItem = await checkPushNotifications()
        items.append(pushItem)
        if pushItem.status == .failed {
            warnings.append("Push notifications not enabled - safety alerts may not work")
        }

        // 7. CloudKit Subscriptions
        let subscriptionItem = await checkSubscriptions()
        items.append(subscriptionItem)
        if subscriptionItem.status == .failed {
            warnings.append("CloudKit subscriptions not set up")
        }

        // 8. Existing Shares
        let sharesItem = await checkExistingShares()
        items.append(sharesItem)

        // Determine overall status
        let overallStatus: HealthCheckStatus
        if !criticalIssues.isEmpty {
            overallStatus = .failed
        } else if !warnings.isEmpty {
            overallStatus = .warning
        } else {
            overallStatus = .passed
        }

        let result = SharingHealthCheckResult(
            timestamp: Date(),
            overallStatus: overallStatus,
            items: items,
            criticalIssues: criticalIssues,
            warnings: warnings
        )

        lastResult = result
        lastCheckTime = Date()

        Log.family.info("SharingHealthCheck: Complete. Status: \(overallStatus.rawValue)")

        return result
    }

    // MARK: - Individual Checks

    private func checkNetworkConnectivity() -> HealthCheckItem {
        HealthCheckItem(
            name: "Network",
            category: "Connectivity",
            status: isNetworkAvailable ? .passed : .failed,
            message: isNetworkAvailable ? "Connected" : "No network connection",
            details: isNetworkAvailable ? nil : "Check WiFi or cellular connection",
            action: isNetworkAvailable ? nil : "Open Settings"
        )
    }

    private func checkiCloudAccount() async -> HealthCheckItem {
        do {
            let status = try await container.accountStatus()

            switch status {
            case .available:
                return HealthCheckItem(
                    name: "iCloud Account",
                    category: "Account",
                    status: .passed,
                    message: "Signed in",
                    details: nil,
                    action: nil
                )
            case .noAccount:
                return HealthCheckItem(
                    name: "iCloud Account",
                    category: "Account",
                    status: .failed,
                    message: "Not signed in",
                    details: "Sign in to iCloud in Settings to enable sharing",
                    action: "Open Settings → Apple ID → iCloud"
                )
            case .restricted:
                return HealthCheckItem(
                    name: "iCloud Account",
                    category: "Account",
                    status: .failed,
                    message: "Restricted",
                    details: "iCloud access is restricted by device management or parental controls",
                    action: "Contact administrator"
                )
            case .couldNotDetermine:
                return HealthCheckItem(
                    name: "iCloud Account",
                    category: "Account",
                    status: .warning,
                    message: "Could not determine status",
                    details: "Try again later",
                    action: nil
                )
            case .temporarilyUnavailable:
                return HealthCheckItem(
                    name: "iCloud Account",
                    category: "Account",
                    status: .warning,
                    message: "Temporarily unavailable",
                    details: "iCloud services are temporarily unavailable",
                    action: "Try again later"
                )
            @unknown default:
                return HealthCheckItem(
                    name: "iCloud Account",
                    category: "Account",
                    status: .unknown,
                    message: "Unknown status",
                    details: nil,
                    action: nil
                )
            }
        } catch {
            return HealthCheckItem(
                name: "iCloud Account",
                category: "Account",
                status: .failed,
                message: "Error checking account",
                details: error.localizedDescription,
                action: nil
            )
        }
    }

    private func checkCloudKitContainer() async -> HealthCheckItem {
        do {
            // Try to get user record ID as a connectivity test
            let userRecordID = try await container.userRecordID()

            return HealthCheckItem(
                name: "CloudKit Container",
                category: "CloudKit",
                status: .passed,
                message: "Connected",
                details: "User ID: \(userRecordID.recordName.prefix(8))...",
                action: nil
            )
        } catch {
            return HealthCheckItem(
                name: "CloudKit Container",
                category: "CloudKit",
                status: .failed,
                message: "Cannot access CloudKit",
                details: error.localizedDescription,
                action: "Check iCloud settings"
            )
        }
    }

    private func checkFamilySharingZone() async -> HealthCheckItem {
        let zoneID = CKRecordZone.ID(zoneName: "FamilySharing", ownerName: CKCurrentUserDefaultName)

        do {
            // Try to fetch the zone
            let zone = try await container.privateCloudDatabase.recordZone(for: zoneID)

            return HealthCheckItem(
                name: "FamilySharing Zone",
                category: "CloudKit",
                status: .passed,
                message: "Zone exists",
                details: "Zone: \(zone.zoneID.zoneName)",
                action: nil
            )
        } catch let error as CKError where error.code == .zoneNotFound {
            // Zone doesn't exist - try to create it
            let zone = CKRecordZone(zoneID: zoneID)
            do {
                _ = try await container.privateCloudDatabase.save(zone)
                return HealthCheckItem(
                    name: "FamilySharing Zone",
                    category: "CloudKit",
                    status: .passed,
                    message: "Zone created",
                    details: "Zone was created successfully",
                    action: nil
                )
            } catch {
                return HealthCheckItem(
                    name: "FamilySharing Zone",
                    category: "CloudKit",
                    status: .failed,
                    message: "Cannot create zone",
                    details: error.localizedDescription,
                    action: nil
                )
            }
        } catch {
            return HealthCheckItem(
                name: "FamilySharing Zone",
                category: "CloudKit",
                status: .failed,
                message: "Zone check failed",
                details: error.localizedDescription,
                action: nil
            )
        }
    }

    private func checkSchema() async -> HealthCheckItem {
        let result = await schemaInitializer.initializeSchema()

        if result.success {
            return HealthCheckItem(
                name: "CloudKit Schema",
                category: "CloudKit",
                status: .passed,
                message: "Schema valid",
                details: "All record types available",
                action: nil
            )
        } else if result.recordTypesCreated.isEmpty && result.errors.isEmpty {
            // Schema likely already exists
            return HealthCheckItem(
                name: "CloudKit Schema",
                category: "CloudKit",
                status: .passed,
                message: "Schema exists",
                details: "Record types: LiveTrackingSession, SafetyAlert, ShareConnection",
                action: nil
            )
        } else {
            return HealthCheckItem(
                name: "CloudKit Schema",
                category: "CloudKit",
                status: result.errors.isEmpty ? .warning : .failed,
                message: result.errors.isEmpty ? "Partial initialization" : "Schema errors",
                details: result.errors.joined(separator: "; "),
                action: "Re-run health check"
            )
        }
    }

    private func checkPushNotifications() async -> HealthCheckItem {
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        switch settings.authorizationStatus {
        case .authorized:
            return HealthCheckItem(
                name: "Push Notifications",
                category: "Notifications",
                status: .passed,
                message: "Enabled",
                details: nil,
                action: nil
            )
        case .denied:
            return HealthCheckItem(
                name: "Push Notifications",
                category: "Notifications",
                status: .failed,
                message: "Denied",
                details: "Enable notifications in Settings to receive safety alerts",
                action: "Open Settings → Notifications → TetraTrack"
            )
        case .notDetermined:
            return HealthCheckItem(
                name: "Push Notifications",
                category: "Notifications",
                status: .warning,
                message: "Not requested",
                details: "Notification permission not yet requested",
                action: nil
            )
        case .provisional, .ephemeral:
            return HealthCheckItem(
                name: "Push Notifications",
                category: "Notifications",
                status: .warning,
                message: "Provisional",
                details: "Limited notification delivery",
                action: "Enable full notifications in Settings"
            )
        @unknown default:
            return HealthCheckItem(
                name: "Push Notifications",
                category: "Notifications",
                status: .unknown,
                message: "Unknown status",
                details: nil,
                action: nil
            )
        }
    }

    private func checkSubscriptions() async -> HealthCheckItem {
        do {
            let subscriptions = try await container.privateCloudDatabase.allSubscriptions()
            let sharedSubscriptions = try await container.sharedCloudDatabase.allSubscriptions()

            let totalCount = subscriptions.count + sharedSubscriptions.count

            if totalCount > 0 {
                return HealthCheckItem(
                    name: "CloudKit Subscriptions",
                    category: "CloudKit",
                    status: .passed,
                    message: "\(totalCount) active",
                    details: "Private: \(subscriptions.count), Shared: \(sharedSubscriptions.count)",
                    action: nil
                )
            } else {
                return HealthCheckItem(
                    name: "CloudKit Subscriptions",
                    category: "CloudKit",
                    status: .warning,
                    message: "No subscriptions",
                    details: "Push notifications for sharing events may not work",
                    action: "Subscriptions will be created when sharing is set up"
                )
            }
        } catch {
            return HealthCheckItem(
                name: "CloudKit Subscriptions",
                category: "CloudKit",
                status: .warning,
                message: "Could not check",
                details: error.localizedDescription,
                action: nil
            )
        }
    }

    private func checkExistingShares() async -> HealthCheckItem {
        do {
            let zones = try await container.sharedCloudDatabase.allRecordZones()

            if zones.isEmpty {
                return HealthCheckItem(
                    name: "Shared Zones",
                    category: "Sharing",
                    status: .passed,
                    message: "No active shares",
                    details: "You haven't accepted any shares yet",
                    action: nil
                )
            } else {
                return HealthCheckItem(
                    name: "Shared Zones",
                    category: "Sharing",
                    status: .passed,
                    message: "\(zones.count) shared zone(s)",
                    details: "Receiving data from \(zones.count) family member(s)",
                    action: nil
                )
            }
        } catch {
            return HealthCheckItem(
                name: "Shared Zones",
                category: "Sharing",
                status: .warning,
                message: "Could not check shares",
                details: error.localizedDescription,
                action: nil
            )
        }
    }
}
