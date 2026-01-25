//
//  SharingDiagnosticsView.swift
//  TrackRide
//
//  Diagnostic view for troubleshooting iCloud sharing issues.
//  Shows health check results, schema status, and allows testing the sharing flow.
//

import SwiftUI
import CloudKit

struct SharingDiagnosticsView: View {
    @State private var healthCheck = SharingHealthCheck.shared
    @State private var isRunningCheck = false
    @State private var result: SharingHealthCheckResult?
    @State private var showingSchemaDetails = false
    @State private var schemaResult: SchemaInitializationResult?

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
            } header: {
                Text("Actions")
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
