//
//  SharingDiagnosticsView.swift
//  TetraTrack
//
//  Diagnostic view for troubleshooting iCloud sharing issues.
//  Shows health check results, schema status, and allows testing the sharing flow.
//

import SwiftUI
import CloudKit
import os

struct SharingDiagnosticsView: View {
    private let healthCheck = SharingHealthCheck.shared
    @State private var isRunningCheck = false
    @State private var result: SharingHealthCheckResult?
    @State private var showingSchemaDetails = false
    @State private var schemaResult: SchemaInitializationResult?
    @State private var showingResetConfirmation = false
    @State private var isResetting = false
    @State private var resetResultMessage: String?

    var body: some View {
        List {
            // Overall Status Section
            Section {
                overallStatusView
            } header: {
                Text("Overall Status")
            }

            // Health Check Items
            if let result = result {
                Section {
                    ForEach(result.items) { item in
                        HealthCheckItemRow(item: item)
                    }
                } header: {
                    Text("Health Checks")
                }

                // Critical Issues
                if !result.criticalIssues.isEmpty {
                    Section {
                        ForEach(result.criticalIssues, id: \.self) { issue in
                            Label(issue, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    } header: {
                        Text("Critical Issues")
                    }
                }

                // Warnings
                if !result.warnings.isEmpty {
                    Section {
                        ForEach(result.warnings, id: \.self) { warning in
                            Label(warning, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    } header: {
                        Text("Warnings")
                    }
                }
            }

            // Actions Section
            Section {
                Button {
                    Task {
                        await runHealthCheck()
                    }
                } label: {
                    HStack {
                        Label("Run Health Check", systemImage: "stethoscope")
                        Spacer()
                        if isRunningCheck {
                            ProgressView()
                        }
                    }
                }
                .disabled(isRunningCheck)

                Button {
                    Task {
                        await initializeSchema()
                    }
                } label: {
                    Label("Initialize Schema", systemImage: "square.grid.3x3.topleft.filled")
                }

                Button {
                    Task {
                        await refreshSubscriptions()
                    }
                } label: {
                    Label("Refresh Subscriptions", systemImage: "bell.badge")
                }

                Button(role: .destructive) {
                    showingResetConfirmation = true
                } label: {
                    HStack {
                        Label("Reset Sharing Data", systemImage: "trash")
                        Spacer()
                        if isResetting {
                            ProgressView()
                        }
                    }
                }
                .disabled(isResetting)
            } header: {
                Text("Actions")
            } footer: {
                Text("Reset Sharing Data will delete all CloudKit sharing records. Use this to fix 'record already exists' errors.")
            }

            // Schema Details
            if let schemaResult = schemaResult {
                Section {
                    HStack {
                        Text("Success")
                        Spacer()
                        Image(systemName: schemaResult.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(schemaResult.success ? .green : .red)
                    }

                    if schemaResult.zoneCreated {
                        HStack {
                            Text("Zone Created")
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }

                    if !schemaResult.recordTypesCreated.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Record Types Created:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(schemaResult.recordTypesCreated.joined(separator: ", "))
                                .font(.caption)
                        }
                    }

                    if !schemaResult.errors.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Errors:")
                                .font(.caption)
                                .foregroundStyle(.red)
                            ForEach(schemaResult.errors, id: \.self) { error in
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                } header: {
                    Text("Schema Status")
                }
            }

            // Info Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Troubleshooting Tips")
                        .font(.headline)

                    BulletPoint(text: "Ensure you're signed into iCloud in Settings")
                    BulletPoint(text: "Check that iCloud Drive is enabled")
                    BulletPoint(text: "Verify the app has permission for iCloud")
                    BulletPoint(text: "Try toggling Airplane Mode to reset network")
                    BulletPoint(text: "Wait 30 seconds after sharing before checking")
                }
                .padding(.vertical, 4)
            } header: {
                Text("Help")
            }
        }
        .navigationTitle("Sharing Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Auto-run health check on appear if no recent result
            if result == nil {
                await runHealthCheck()
            }
        }
        .confirmationDialog(
            "Reset Sharing Data?",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                Task {
                    await resetSharingData()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all CloudKit sharing records in the FamilySharing zone. You will need to recreate any sharing relationships.")
        }
        .alert("Reset Complete", isPresented: .init(
            get: { resetResultMessage != nil },
            set: { if !$0 { resetResultMessage = nil } }
        )) {
            Button("OK") { resetResultMessage = nil }
        } message: {
            Text(resetResultMessage ?? "")
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var overallStatusView: some View {
        if let result = result {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: result.overallStatus.icon)
                            .foregroundStyle(colorForStatus(result.overallStatus))
                            .font(.title2)
                        Text(result.overallStatus.rawValue)
                            .font(.headline)
                    }

                    Text("Last checked: \(result.timestamp.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if result.canShareSafely {
                    Label("Ready to Share", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Label("Not Ready", systemImage: "xmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        } else {
            HStack {
                Text("No health check run yet")
                    .foregroundStyle(.secondary)
                Spacer()
                if isRunningCheck {
                    ProgressView()
                }
            }
        }
    }

    // MARK: - Actions

    private func runHealthCheck() async {
        isRunningCheck = true
        result = await healthCheck.runFullHealthCheck()
        isRunningCheck = false
    }

    private func initializeSchema() async {
        let initializer = CloudKitSchemaInitializer()
        schemaResult = await initializer.initializeSchema()
    }

    private func refreshSubscriptions() async {
        await NotificationManager.shared.setupCloudKitSubscriptions()
    }

    private func resetSharingData() async {
        isResetting = true
        defer { isResetting = false }

        let container = CKContainer.default()
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: "FamilySharing", ownerName: CKCurrentUserDefaultName)

        var errors: [String] = []

        // Delete the entire FamilySharing zone - this removes ALL records and shares
        do {
            let (_, deleteResults) = try await database.modifyRecordZones(saving: [], deleting: [zoneID])

            for (zoneIDKey, result) in deleteResults {
                if case .failure(let error) = result {
                    // Ignore "zone not found" - means nothing to delete
                    if let ckError = error as? CKError, ckError.code == .zoneNotFound {
                        continue
                    }
                    errors.append("Zone delete: \(error.localizedDescription)")
                }
            }
        } catch {
            if let ckError = error as? CKError, ckError.code == .zoneNotFound {
                // Zone doesn't exist, that's fine
            } else {
                errors.append("Zone delete: \(error.localizedDescription)")
            }
        }

        // Clear linked riders from UserDefaults
        UserDefaults.standard.removeObject(forKey: "linkedRiders")

        // Clear coordinator cache and reload
        await MainActor.run {
            UnifiedSharingCoordinator.shared.loadLinkedRiders()

            // Clear cached connection info from all relationships
            if let repository = UnifiedSharingCoordinator.shared.repository {
                do {
                    let relationships = try repository.fetchAll()
                    for relationship in relationships {
                        relationship.connectionRecordID = nil
                        relationship.shareURLValue = nil
                        relationship.inviteStatus = .notSent
                        relationship.inviteSentDate = nil
                        repository.update(relationship)
                    }
                } catch {
                    Log.family.error("Failed to clear relationship cache: \(error)")
                }
            }
        }

        if errors.isEmpty {
            resetResultMessage = "Successfully deleted FamilySharing zone and all records. You can now create new sharing relationships."
        } else {
            resetResultMessage = "Reset completed with some errors:\n\(errors.joined(separator: "\n"))"
        }
    }

    // MARK: - Helpers

    private func colorForStatus(_ status: HealthCheckStatus) -> Color {
        switch status {
        case .passed: return .green
        case .warning: return .orange
        case .failed: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Health Check Item Row

private struct HealthCheckItemRow: View {
    let item: HealthCheckItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: item.status.icon)
                    .foregroundStyle(colorForStatus(item.status))
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(item.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let details = item.details {
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let action = item.action {
                Text(action)
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 2)
    }

    private func colorForStatus(_ status: HealthCheckStatus) -> Color {
        switch status {
        case .passed: return .green
        case .warning: return .orange
        case .failed: return .red
        case .unknown: return .gray
        }
    }
}

#Preview {
    NavigationStack {
        SharingDiagnosticsView()
    }
}
