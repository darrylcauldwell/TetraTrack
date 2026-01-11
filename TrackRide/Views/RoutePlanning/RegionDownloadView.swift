//
//  RegionDownloadView.swift
//  TrackRide
//

import SwiftUI
import MapKit

/// View for downloading regional OSM data for offline routing
struct RegionDownloadView: View {
    @Environment(\.routePlanning) private var routePlanning
    @Environment(\.dismiss) private var dismiss

    @State private var downloadedRegions: [DownloadedRegion] = []
    @State private var incompleteDownloads: [DownloadState] = []
    @State private var selectedRegion: AvailableRegion?
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        NavigationStack {
            List {
                // Incomplete downloads section (resumable)
                if !incompleteDownloads.isEmpty {
                    Section {
                        ForEach(incompleteDownloads, id: \.regionId) { state in
                            IncompleteDownloadRow(
                                state: state,
                                onResume: { resumeDownload(state) },
                                onCancel: { cancelDownload(state) }
                            )
                        }
                    } header: {
                        Text("Incomplete Downloads")
                    } footer: {
                        Text("These downloads were interrupted. Resume to continue or cancel to start fresh.")
                    }
                }

                // Downloaded regions section
                if !downloadedRegions.isEmpty {
                    Section("Downloaded Regions") {
                        ForEach(downloadedRegions, id: \.regionId) { region in
                            DownloadedRegionRow(region: region)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        // Delete immediately without confirmation
                                        // Swipe delete is already a deliberate gesture
                                        deleteRegion(region)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }

                // Available regions section
                Section("Available Regions") {
                    ForEach(AvailableRegion.ukRegions) { region in
                        AvailableRegionRow(
                            region: region,
                            isDownloaded: isDownloaded(region),
                            downloadProgress: routePlanning.activeDownloads[region.id],
                            onDownload: { downloadRegion(region) },
                            onCancel: { cancelActiveDownload(region.id) }
                        )
                    }
                }

                // Info section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Route Planning Data", systemImage: "map")
                            .font(.subheadline.weight(.semibold))
                        Text("Route planning requires OpenStreetMap data for bridleways, byways, tracks, and paths. Download once, then plan routes anytime — even without internet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Map Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                loadDownloadedRegions()
                loadIncompleteDownloads()
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
    }

    // MARK: - Actions

    private func loadDownloadedRegions() {
        do {
            downloadedRegions = try routePlanning.getDownloadedRegions()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func isDownloaded(_ region: AvailableRegion) -> Bool {
        downloadedRegions.contains { $0.regionId == region.id }
    }

    private func downloadRegion(_ region: AvailableRegion) {
        Task {
            do {
                try await routePlanning.downloadRegion(region)
                loadDownloadedRegions()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func deleteRegion(_ region: DownloadedRegion) {
        // CRITICAL: SwiftUI's swipe delete expects synchronous data source updates.
        // We must update the local state FIRST before any async work.
        // Using withAnimation helps SwiftUI properly coordinate with UICollectionView.

        // 1. Optimistically remove from local state IMMEDIATELY with animation
        let regionId = region.regionId
        withAnimation {
            downloadedRegions.removeAll { $0.regionId == regionId }
        }

        // 2. Perform actual deletion in background
        Task {
            do {
                try await routePlanning.deleteRegion(regionId)
                // Success - state is already correct
            } catch {
                // Failed - reload to restore state and show error
                await MainActor.run {
                    withAnimation {
                        loadDownloadedRegions()
                    }
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }

    private func loadIncompleteDownloads() {
        incompleteDownloads = DownloadState.getResumableDownloads()
    }

    private func resumeDownload(_ state: DownloadState) {
        Task {
            do {
                try await routePlanning.resumeDownload(state)
                loadDownloadedRegions()
                loadIncompleteDownloads()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func cancelDownload(_ state: DownloadState) {
        Task {
            await routePlanning.cancelDownload(state.regionId)
            loadIncompleteDownloads()
        }
    }

    private func cancelActiveDownload(_ regionId: String) {
        Task {
            await routePlanning.cancelDownload(regionId)
            loadIncompleteDownloads()
        }
    }
}

// MARK: - Supporting Views

private struct DownloadedRegionRow: View {
    let region: DownloadedRegion

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(region.displayName)
                    .font(.body.weight(.medium))
                Spacer()
                if region.isStale {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }

            HStack(spacing: 12) {
                Label(region.formattedNodeCount + " points", systemImage: "point.3.filled.connected.trianglepath.dotted")
                Label(region.formattedFileSize, systemImage: "internaldrive")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if region.isStale {
                Text("Data is over 30 days old")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct AvailableRegionRow: View {
    let region: AvailableRegion
    let isDownloaded: Bool
    let downloadProgress: OSMDataManager.DownloadProgress?
    let onDownload: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(region.displayName)
                    .font(.body.weight(.medium))
                Spacer()

                // Show status icon only when not actively downloading
                // During download, the progress bar below shows status
                if isDownloaded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                } else if let progress = downloadProgress {
                    // Only show icon for terminal states (complete/failed)
                    // In-progress states show the progress bar below instead
                    switch progress.phase {
                    case .complete:
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    case .failed:
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                    default:
                        // Show cancel button during active download
                        Button(action: onCancel) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Button(action: onDownload) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                }
            }

            if !isDownloaded && downloadProgress == nil {
                Text("~\(region.formattedEstimatedSize) download")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let progress = downloadProgress {
                // Show progress bar only during active download phases
                if progress.phase != .complete && progress.phase != .failed {
                    VStack(alignment: .leading, spacing: 2) {
                        ProgressView(value: progress.progress)
                        HStack {
                            Text(progress.message)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Cancel", action: onCancel)
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct IncompleteDownloadRow: View {
    let state: DownloadState
    let onResume: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.regionDisplayName)
                        .font(.body.weight(.medium))
                    Text(state.progressDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
            }

            // Progress indicator
            if state.totalNodes > 0 {
                let progress = Double(state.nodesProcessed + state.edgesProcessed) /
                               Double(state.totalNodes + state.totalEdges)
                VStack(alignment: .leading, spacing: 2) {
                    ProgressView(value: progress)
                    Text("\(Int(progress * 100))% complete")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: onResume) {
                    Label("Resume", systemImage: "play.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(role: .destructive, action: onCancel) {
                    Label("Cancel", systemImage: "xmark")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RegionDownloadView()
}
