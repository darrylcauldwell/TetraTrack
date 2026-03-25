//
//  CloudKitDiagnosticsView.swift
//  TetraTrack
//
//  CloudKit sync diagnostics for debugging sync issues,
//  especially on Mac Catalyst where sync can silently fail.
//

import SwiftUI
import SwiftData
import CloudKit
import os

struct CloudKitDiagnosticsView: View {
    @Environment(\.modelContext) private var modelContext
    private let syncMonitor = SyncStatusMonitor.shared

    @State private var iCloudStatus: String = "Checking..."
    @State private var recordZones: [String] = []
    @State private var zoneError: String?
    @State private var rideCounts: Int?
    @State private var runningCounts: Int?
    @State private var swimmingCounts: Int?
    @State private var shootingCounts: Int?
    @State private var horseCounts: Int?
    @State private var isChecking = false

    var body: some View {
        List {
            containerModeSection
            iCloudAccountSection
            syncStatusSection
            recordCountsSection
            recordZonesSection
            actionsSection
        }
        .navigationTitle("CloudKit Sync")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await runFullDiagnostics()
        }
    }

    // MARK: - Sections

    private var containerModeSection: some View {
        Section("Container Mode") {
            if syncMonitor.isLocalOnlyMode {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Local Storage Only")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if let error = syncMonitor.detailedError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("Restart the app to retry CloudKit connection")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.icloud.fill")
                        .foregroundStyle(.green)
                    Text("CloudKit Enabled")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
    }

    private var iCloudAccountSection: some View {
        Section("iCloud Account") {
            diagnosticRow("Status", value: iCloudStatus)
            diagnosticRow("Container", value: "iCloud.dev.dreamfold.TetraTrack")

            #if targetEnvironment(macCatalyst)
            diagnosticRow("Platform", value: "Mac Catalyst")
            #else
            diagnosticRow("Platform", value: "iOS")
            #endif
        }
    }

    private var syncStatusSection: some View {
        Section("Sync Health") {
            HStack {
                Image(systemName: syncMonitor.status.icon)
                    .foregroundStyle(statusColor)
                Text(syncMonitor.status.displayText)
                    .font(.subheadline)
            }

            if let lastSync = syncMonitor.timeSinceLastSync {
                diagnosticRow("Last Check", value: lastSync)
            }

            if syncMonitor.pendingOperations > 0 {
                diagnosticRow("Pending Ops", value: "\(syncMonitor.pendingOperations)")
            }

            diagnosticRow("Network", value: syncMonitor.status == .offline ? "Offline" : "Connected")
        }
    }

    private var recordCountsSection: some View {
        Section("Local Records") {
            if let rides = rideCounts {
                diagnosticRow("Rides", value: "\(rides)")
            }
            if let running = runningCounts {
                diagnosticRow("Running Sessions", value: "\(running)")
            }
            if let swimming = swimmingCounts {
                diagnosticRow("Swimming Sessions", value: "\(swimming)")
            }
            if let shooting = shootingCounts {
                diagnosticRow("Shooting Sessions", value: "\(shooting)")
            }
            if let horses = horseCounts {
                diagnosticRow("Horses", value: "\(horses)")
            }

            if rideCounts == nil && runningCounts == nil {
                Text("Counting...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var recordZonesSection: some View {
        Section("CloudKit Record Zones") {
            if let error = zoneError {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if recordZones.isEmpty {
                Text("Fetching...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recordZones, id: \.self) { zone in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text(zone)
                            .font(.caption.monospaced())
                    }
                }
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                Task {
                    await runFullDiagnostics()
                }
            } label: {
                HStack {
                    Label("Check Status", systemImage: "arrow.clockwise")
                    Spacer()
                    if isChecking {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(isChecking)
        }
    }

    // MARK: - Helpers

    private func diagnosticRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch syncMonitor.status {
        case .syncing: .blue
        case .synced: .green
        case .error: .orange
        case .offline: .gray
        case .notSignedIn: .red
        }
    }

    // MARK: - Diagnostics

    private func runFullDiagnostics() async {
        isChecking = true
        defer { isChecking = false }

        // Check iCloud account
        await checkiCloudAccount()

        // Check sync health
        await syncMonitor.checkSyncHealth()

        // Fetch record zones
        await fetchRecordZones()

        // Count local records
        countLocalRecords()
    }

    private func checkiCloudAccount() async {
        let container = CKContainer(identifier: "iCloud.dev.dreamfold.TetraTrack")
        do {
            let accountStatus = try await container.accountStatus()
            switch accountStatus {
            case .available:
                iCloudStatus = "Available"
            case .noAccount:
                iCloudStatus = "Not Signed In"
            case .restricted:
                iCloudStatus = "Restricted"
            case .couldNotDetermine:
                iCloudStatus = "Could Not Determine"
            case .temporarilyUnavailable:
                iCloudStatus = "Temporarily Unavailable"
            @unknown default:
                iCloudStatus = "Unknown"
            }
        } catch {
            iCloudStatus = "Error: \(error.localizedDescription)"
        }
    }

    private func fetchRecordZones() async {
        let container = CKContainer(identifier: "iCloud.dev.dreamfold.TetraTrack")
        let database = container.privateCloudDatabase

        do {
            let zones = try await database.allRecordZones()
            recordZones = zones.map { $0.zoneID.zoneName }
            zoneError = nil
        } catch {
            recordZones = []
            zoneError = error.localizedDescription
        }
    }

    private func countLocalRecords() {
        do {
            let rideDescriptor = FetchDescriptor<Ride>()
            rideCounts = try modelContext.fetchCount(rideDescriptor)

            let runningDescriptor = FetchDescriptor<RunningSession>()
            runningCounts = try modelContext.fetchCount(runningDescriptor)

            let swimmingDescriptor = FetchDescriptor<SwimmingSession>()
            swimmingCounts = try modelContext.fetchCount(swimmingDescriptor)

            let shootingDescriptor = FetchDescriptor<ShootingSession>()
            shootingCounts = try modelContext.fetchCount(shootingDescriptor)

            let horseDescriptor = FetchDescriptor<Horse>()
            horseCounts = try modelContext.fetchCount(horseDescriptor)
        } catch {
            Log.storage.error("Failed to count local records: \(error.localizedDescription)")
        }
    }
}

#Preview {
    NavigationStack {
        CloudKitDiagnosticsView()
    }
}
