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
    @State private var selectedRegion: AvailableRegion?
    @State private var showingDeleteConfirmation = false
    @State private var regionToDelete: DownloadedRegion?
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        NavigationStack {
            List {
                // Downloaded regions section
                if !downloadedRegions.isEmpty {
                    Section("Downloaded Regions") {
                        ForEach(downloadedRegions, id: \.regionId) { region in
                            DownloadedRegionRow(region: region)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        regionToDelete = region
                                        showingDeleteConfirmation = true
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
                            onDownload: { downloadRegion(region) }
                        )
                    }
                }

                // Info section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Offline Routing", systemImage: "wifi.slash")
                            .font(.subheadline.weight(.semibold))
                        Text("Download map data to plan routes without internet. Data includes bridleways, byways, tracks, and paths from OpenStreetMap.")
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
            .onAppear { loadDownloadedRegions() }
            .alert("Delete Region?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let region = regionToDelete {
                        deleteRegion(region)
                    }
                }
            } message: {
                if let region = regionToDelete {
                    Text("This will remove all routing data for \(region.displayName). You can re-download it later.")
                }
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
        Task {
            do {
                try await routePlanning.deleteRegion(region.regionId)
                loadDownloadedRegions()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(region.displayName)
                    .font(.body.weight(.medium))
                Spacer()

                if isDownloaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if let progress = downloadProgress {
                    downloadStatusView(progress)
                } else {
                    Button(action: onDownload) {
                        Label("Download", systemImage: "arrow.down.circle")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if !isDownloaded {
                Text("~\(region.formattedEstimatedSize) download")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let progress = downloadProgress {
                VStack(alignment: .leading, spacing: 2) {
                    ProgressView(value: progress.progress)
                    Text(progress.message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func downloadStatusView(_ progress: OSMDataManager.DownloadProgress) -> some View {
        switch progress.phase {
        case .downloading, .parsing, .indexing:
            ProgressView()
                .controlSize(.small)
        case .complete:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    RegionDownloadView()
}
