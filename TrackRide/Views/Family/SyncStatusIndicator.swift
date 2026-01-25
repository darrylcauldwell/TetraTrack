//
//  SyncStatusIndicator.swift
//  TrackRide
//
//  Visual indicator for CloudKit sync status in the Family view.
//  Shows users when sync is working or failing.
//

import SwiftUI

struct SyncStatusIndicator: View {
    @State private var syncMonitor = SyncStatusMonitor.shared
    @State private var showingDetails = false

    var body: some View {
        Button {
            showingDetails = true
        } label: {
            HStack(spacing: 6) {
                statusIcon
                    .font(.body)
                    .foregroundStyle(statusColor)

                if syncMonitor.status == .syncing {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetails) {
            SyncStatusDetailView(syncMonitor: syncMonitor)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var statusIcon: some View {
        Image(systemName: syncMonitor.status.icon)
    }

    private var statusColor: Color {
        switch syncMonitor.status {
        case .syncing:
            return .blue
        case .synced:
            return .green
        case .error:
            return .orange
        case .offline:
            return .gray
        case .notSignedIn:
            return .red
        }
    }
}

// MARK: - Sync Status Detail View

struct SyncStatusDetailView: View {
    let syncMonitor: SyncStatusMonitor
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Status Icon
                    statusIconView

                    // Status Text
                    VStack(spacing: 8) {
                        Text(syncMonitor.status.displayText)
                            .font(.title2)
                            .fontWeight(.semibold)

                        if let error = syncMonitor.detailedError {
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        if let lastSync = syncMonitor.timeSinceLastSync {
                            Text("Last synced: \(lastSync)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Divider()

                    // Status Details
                    VStack(alignment: .leading, spacing: 16) {
                        statusDetailRow(
                            icon: "icloud",
                            title: "iCloud Account",
                            value: iCloudStatusText
                        )

                        statusDetailRow(
                            icon: "wifi",
                            title: "Network",
                            value: networkStatusText
                        )

                        if syncMonitor.pendingOperations > 0 {
                            statusDetailRow(
                                icon: "arrow.triangle.2.circlepath",
                                title: "Pending Operations",
                                value: "\(syncMonitor.pendingOperations)"
                            )
                        }
                    }
                    .padding(.horizontal)

                    Spacer()

                    // Refresh Button
                    Button {
                        Task {
                            await syncMonitor.checkSyncHealth()
                        }
                    } label: {
                        Label("Check Status", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                }
                .padding(.top, 32)
            }
            .navigationTitle("Sync Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var statusIconView: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.1))
                .frame(width: 80, height: 80)

            Image(systemName: syncMonitor.status.icon)
                .font(.system(size: 36))
                .foregroundStyle(statusColor)
        }
    }

    private var statusColor: Color {
        switch syncMonitor.status {
        case .syncing:
            return .blue
        case .synced:
            return .green
        case .error:
            return .orange
        case .offline:
            return .gray
        case .notSignedIn:
            return .red
        }
    }

    private var iCloudStatusText: String {
        switch syncMonitor.status {
        case .notSignedIn:
            return "Not signed in"
        case .synced, .syncing:
            return "Connected"
        case .offline:
            return "Offline"
        case .error:
            return "Error"
        }
    }

    private var networkStatusText: String {
        switch syncMonitor.status {
        case .offline:
            return "No connection"
        default:
            return "Connected"
        }
    }

    private func statusDetailRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .font(.body)

            Spacer()

            Text(value)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    SyncStatusIndicator()
}
