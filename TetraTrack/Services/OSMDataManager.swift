//
//  OSMDataManager.swift
//  TetraTrack
//

import Foundation
import SwiftData
import CoreLocation
import os

/// Manages downloading and processing OSM regional data for offline routing
@Observable
@MainActor
final class OSMDataManager {

    // MARK: - State

    /// Currently downloading regions
    private(set) var activeDownloads: [String: DownloadProgress] = [:]

    /// Active download tasks for cancellation
    private var downloadTasks: [String: Task<Void, Never>] = [:]

    /// Last error message
    private(set) var lastError: String?

    // MARK: - Dependencies

    private var modelContext: ModelContext?
    private var modelContainer: ModelContainer?
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "dev.dreamfold.tetratrack", category: "OSMDataManager")

    // MARK: - Download Progress

    struct DownloadProgress: Equatable {
        var phase: Phase
        var progress: Double  // 0.0 to 1.0
        var message: String

        enum Phase: Equatable {
            case downloading
            case parsing
            case indexing
            case complete
            case failed
        }

        static let initial = DownloadProgress(phase: .downloading, progress: 0, message: "Starting download...")
    }

    // MARK: - Initialization

    init() {}

    func configure(with context: ModelContext, container: ModelContainer) {
        self.modelContext = context
        self.modelContainer = container
    }

    /// Restore activeDownloads state from persisted DownloadState
    /// Call this when app returns to foreground to sync UI with persisted state
    func restoreDownloadState() {
        let incompleteDownloads = DownloadState.getIncompleteDownloads()

        for state in incompleteDownloads {
            // Skip if already tracking
            guard activeDownloads[state.regionId] == nil else { continue }

            // Convert persisted phase to UI phase
            let uiPhase: DownloadProgress.Phase
            let progress: Double
            let message: String

            switch state.phase {
            case .downloading:
                uiPhase = .downloading
                progress = 0.1
                message = "Download in progress..."
            case .downloaded:
                uiPhase = .parsing
                progress = 0.15
                message = "Processing data..."
            case .processingNodes:
                let nodeProgress = state.totalNodes > 0 ? Double(state.nodesProcessed) / Double(state.totalNodes) : 0.3
                uiPhase = .parsing
                progress = 0.15 + nodeProgress * 0.4
                message = "Creating waypoints (\(state.nodesProcessed)/\(state.totalNodes))..."
            case .processingEdges:
                let edgeProgress = state.totalEdges > 0 ? Double(state.edgesProcessed) / Double(state.totalEdges) : 0.6
                uiPhase = .indexing
                progress = 0.55 + edgeProgress * 0.4
                message = "Building connections..."
            case .finalizing:
                uiPhase = .indexing
                progress = 0.95
                message = "Finalizing..."
            case .complete:
                uiPhase = .complete
                progress = 1.0
                message = "Complete"
            case .failed:
                uiPhase = .failed
                progress = 0
                message = "Failed - tap to retry"
            }

            activeDownloads[state.regionId] = DownloadProgress(
                phase: uiPhase,
                progress: progress,
                message: message
            )

            logger.info("Restored download state for \(state.regionId): \(state.phase.rawValue)")
        }

        // Also check for completed downloads that need UI cleanup
        let completedRegionIds = incompleteDownloads
            .filter { $0.phase == .complete }
            .map { $0.regionId }

        for regionId in completedRegionIds {
            // Remove from persisted state since it completed
            DownloadState.remove(regionId: regionId)
            DownloadState.deleteJsonFile(for: regionId)

            // Remove from UI after brief display
            Task {
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run {
                    self.activeDownloads.removeValue(forKey: regionId)
                }
            }
        }
    }

    // MARK: - Public API

    /// Download and process a region using Overpass API
    func downloadRegion(_ region: AvailableRegion) async throws {
        guard let context = modelContext, let container = modelContainer else {
            throw OSMDataError.notConfigured
        }

        // Check if already downloading
        guard activeDownloads[region.id] == nil else {
            throw OSMDataError.alreadyDownloading
        }

        // Check if already downloaded
        if try await isRegionDownloaded(region.id) {
            throw OSMDataError.alreadyDownloaded
        }

        // Clean up any orphaned data from previous failed attempts
        await cleanupOrphanedData(for: region.id)

        logger.info("Starting Overpass API download for region: \(region.id)")
        activeDownloads[region.id] = .initial

        // Store the download task for potential cancellation
        let downloadTask = Task { @MainActor in
            do {
                try await self.performDownload(region: region, context: context, container: container)
            } catch is CancellationError {
                self.logger.info("Download cancelled for region: \(region.id)")
                self.updateProgress(region.id, phase: .failed, progress: 0, message: "Cancelled")
                self.activeDownloads.removeValue(forKey: region.id)
            } catch {
                self.logger.error("Region download failed: \(error.localizedDescription)")
                self.updateProgress(region.id, phase: .failed, progress: 0, message: error.localizedDescription)
                self.lastError = error.localizedDescription

                // Remove failed download from active list after delay
                _ = Task {
                    try? await Task.sleep(for: .seconds(5))
                    await MainActor.run {
                        self.activeDownloads.removeValue(forKey: region.id)
                    }
                }
            }

            // Clean up task reference
            self.downloadTasks.removeValue(forKey: region.id)
        }

        downloadTasks[region.id] = downloadTask
    }

    /// Internal download implementation that can be cancelled
    private func performDownload(region: AvailableRegion, context: ModelContext, container: ModelContainer) async throws {
        // Fetch data via Overpass API (no PBF file needed)
        updateProgress(region.id, phase: .downloading, progress: 0, message: "Fetching bridleway data...")

        // Check for cancellation before starting
        try Task.checkCancellation()

        let fetcher = OverpassDataFetcher(regionId: region.id, displayName: region.displayName, modelContainer: container)
        let bounds = (minLat: region.minLat, maxLat: region.maxLat, minLon: region.minLon, maxLon: region.maxLon)

        let (nodeCount, edgeCount) = try await fetcher.fetch(bounds: bounds) { progress, message in
            Task { @MainActor in
                let phase: DownloadProgress.Phase = progress < 0.4 ? .downloading : (progress < 0.8 ? .parsing : .indexing)
                self.updateProgress(region.id, phase: phase, progress: progress, message: message)
            }
        }

        // Check for cancellation before finalizing
        try Task.checkCancellation()

        // Create region metadata
        updateProgress(region.id, phase: .indexing, progress: 0.95, message: "Finalizing...")
        let downloadedRegion = DownloadedRegion(regionId: region.id, displayName: region.displayName)
        downloadedRegion.nodeCount = nodeCount
        downloadedRegion.edgeCount = edgeCount
        downloadedRegion.minLat = region.minLat
        downloadedRegion.maxLat = region.maxLat
        downloadedRegion.minLon = region.minLon
        downloadedRegion.maxLon = region.maxLon
        downloadedRegion.isComplete = true

        // Calculate storage size based on node count (avoid expensive fetch)
        downloadedRegion.fileSizeBytes = Int64(nodeCount * 200)

        context.insert(downloadedRegion)
        try context.save()

        // Complete
        updateProgress(region.id, phase: .complete, progress: 1.0, message: "Ready")
        logger.info("Region download complete: \(region.id) - \(nodeCount) nodes, \(edgeCount) edges")

        // Remove from active downloads after a delay
        _ = Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                self.activeDownloads.removeValue(forKey: region.id)
            }
        }
    }

    /// Delete a downloaded region and all its nodes
    /// Uses batch deletion to avoid memory issues with large datasets
    func deleteRegion(_ regionId: String) async throws {
        guard let context = modelContext else {
            throw OSMDataError.notConfigured
        }

        logger.info("Deleting region: \(regionId)")

        // IMPORTANT: Delete region metadata FIRST
        // This way even if node deletion fails, the UI won't show the region as downloaded
        // This prevents the user from being stuck with an undeletable region
        do {
            // Fetch all regions and filter in Swift to avoid #Predicate capture issues
            let allRegionsDescriptor = FetchDescriptor<DownloadedRegion>()
            let allRegions = try context.fetch(allRegionsDescriptor)
            let regionsToDelete = allRegions.filter { $0.regionId == regionId }

            for region in regionsToDelete {
                context.delete(region)
            }
            try context.save()
            logger.info("Deleted region metadata for: \(regionId)")
        } catch {
            logger.error("Failed to delete region metadata: \(error.localizedDescription)")
            throw error
        }

        // Now delete nodes in small batches
        // Even if this fails, the region won't show as downloaded
        var totalDeletedNodes = 0
        let batchSize = 100

        do {
            while true {
                // Fetch ALL nodes and filter in Swift to avoid #Predicate variable capture issues
                // Use fetchLimit on the descriptor to avoid loading too many
                var nodeDescriptor = FetchDescriptor<OSMNode>()
                nodeDescriptor.fetchLimit = batchSize * 2  // Fetch a bit more to account for filtering

                let allNodes = try context.fetch(nodeDescriptor)
                let nodesToDelete = allNodes.filter { $0.regionId == regionId }

                if nodesToDelete.isEmpty {
                    break
                }

                // Delete this batch (up to batchSize)
                let batch = nodesToDelete.prefix(batchSize)
                for node in batch {
                    context.delete(node)
                }
                totalDeletedNodes += batch.count

                try context.save()

                // Yield to keep UI responsive
                await Task.yield()

                logger.debug("Deleted batch of \(batch.count) nodes, total: \(totalDeletedNodes)")
            }
        } catch {
            // Log but don't throw - region metadata is already deleted
            // Orphaned nodes won't affect functionality
            logger.warning("Failed to delete some nodes for region \(regionId): \(error.localizedDescription). Orphaned nodes: ~\(totalDeletedNodes) deleted before failure.")
        }

        logger.info("Region deleted: \(regionId), removed \(totalDeletedNodes) nodes")
    }

    /// Check if a region is already downloaded
    func isRegionDownloaded(_ regionId: String) async throws -> Bool {
        guard let context = modelContext else {
            throw OSMDataError.notConfigured
        }

        // Fetch all and filter in Swift to avoid #Predicate variable capture issues
        let descriptor = FetchDescriptor<DownloadedRegion>()
        let regions = try context.fetch(descriptor)
        return regions.contains { $0.regionId == regionId && $0.isComplete }
    }

    /// Fix bounds for an already downloaded region (if bounds were stored incorrectly)
    func fixRegionBounds(_ availableRegion: AvailableRegion) throws {
        guard let context = modelContext else {
            throw OSMDataError.notConfigured
        }

        // Fetch all and filter in Swift to avoid #Predicate variable capture issues
        let descriptor = FetchDescriptor<DownloadedRegion>()
        let regions = try context.fetch(descriptor)

        guard let downloadedRegion = regions.first(where: { $0.regionId == availableRegion.id }) else {
            return // Region not found, nothing to fix
        }

        // Update bounds to match AvailableRegion
        downloadedRegion.minLat = availableRegion.minLat
        downloadedRegion.maxLat = availableRegion.maxLat
        downloadedRegion.minLon = availableRegion.minLon
        downloadedRegion.maxLon = availableRegion.maxLon

        try context.save()
        logger.info("Fixed bounds for region: \(availableRegion.id)")
    }

    /// Get all downloaded regions
    func getDownloadedRegions() throws -> [DownloadedRegion] {
        guard let context = modelContext else {
            throw OSMDataError.notConfigured
        }

        let descriptor = FetchDescriptor<DownloadedRegion>(
            sortBy: [SortDescriptor(\.displayName)]
        )
        return try context.fetch(descriptor)
    }

    /// Find regions containing a coordinate
    func regionsContaining(_ coordinate: CLLocationCoordinate2D) throws -> [DownloadedRegion] {
        guard let context = modelContext else {
            throw OSMDataError.notConfigured
        }

        let lat = coordinate.latitude
        let lon = coordinate.longitude

        // Fetch all and filter in Swift to avoid #Predicate variable capture issues
        let descriptor = FetchDescriptor<DownloadedRegion>()
        let regions = try context.fetch(descriptor)
        return regions.filter {
            $0.isComplete &&
            $0.minLat <= lat && $0.maxLat >= lat &&
            $0.minLon <= lon && $0.maxLon >= lon
        }
    }

    // MARK: - Private Methods

    private func updateProgress(_ regionId: String, phase: DownloadProgress.Phase, progress: Double, message: String) {
        activeDownloads[regionId] = DownloadProgress(phase: phase, progress: progress, message: message)
    }

    private func downloadPBFFile(from url: URL, regionId: String) async throws -> URL {
        let tempDir = fileManager.temporaryDirectory
        let destURL = tempDir.appendingPathComponent("\(regionId).osm.pbf")

        // Remove existing temp file if present
        try? fileManager.removeItem(at: destURL)

        // Download with progress tracking
        let (tempURL, response) = try await URLSession.shared.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OSMDataError.downloadFailed("Server returned error")
        }

        // Move to our temp location
        try fileManager.moveItem(at: tempURL, to: destURL)

        return destURL
    }

    private func parsePBFFile(
        at url: URL,
        regionId: String,
        context: ModelContext
    ) async throws -> (nodeCount: Int, edgeCount: Int, bounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)) {

        // Create parser and process file
        let parser = OSMParser(regionId: regionId, modelContext: context)

        return try await parser.parse(fileURL: url) { progress, message in
            Task { @MainActor in
                self.updateProgress(regionId, phase: .parsing, progress: progress, message: message)
            }
        }
    }

    // MARK: - Resume & Cleanup

    /// Get list of incomplete downloads that can be resumed
    func getIncompleteDownloads() -> [DownloadState] {
        DownloadState.getResumableDownloads()
    }

    /// Resume an incomplete download
    func resumeDownload(_ state: DownloadState) async throws {
        guard let context = modelContext, let container = modelContainer else {
            throw OSMDataError.notConfigured
        }

        // Check if already downloading
        guard activeDownloads[state.regionId] == nil else {
            throw OSMDataError.alreadyDownloading
        }

        // Check if already completed
        if try await isRegionDownloaded(state.regionId) {
            // Clean up the state since it's already done
            DownloadState.remove(regionId: state.regionId)
            DownloadState.deleteJsonFile(for: state.regionId)
            throw OSMDataError.alreadyDownloaded
        }

        logger.info("Resuming download for region: \(state.regionId) from phase: \(state.phase.rawValue)")
        activeDownloads[state.regionId] = DownloadProgress(
            phase: .parsing,
            progress: Double(state.nodesProcessed) / Double(max(state.totalNodes, 1)),
            message: "Resuming..."
        )

        var mutableState = state

        do {
            let fetcher = OverpassDataFetcher(
                regionId: state.regionId,
                displayName: state.regionDisplayName,
                modelContainer: container
            )

            let (nodeCount, edgeCount) = try await fetcher.resumeFromState(&mutableState) { progress, message in
                Task { @MainActor in
                    let phase: DownloadProgress.Phase = progress < 0.6 ? .parsing : .indexing
                    self.updateProgress(state.regionId, phase: phase, progress: progress, message: message)
                }
            }

            // Create region metadata if not exists
            // Fetch all and filter in Swift to avoid #Predicate variable capture crash
            let allRegions = try context.fetch(FetchDescriptor<DownloadedRegion>())
            let existingRegion = allRegions.first { $0.regionId == state.regionId }

            if existingRegion == nil {
                let downloadedRegion = DownloadedRegion(regionId: state.regionId, displayName: state.regionDisplayName)
                downloadedRegion.nodeCount = nodeCount
                downloadedRegion.edgeCount = edgeCount
                downloadedRegion.minLat = state.bounds.minLat
                downloadedRegion.maxLat = state.bounds.maxLat
                downloadedRegion.minLon = state.bounds.minLon
                downloadedRegion.maxLon = state.bounds.maxLon
                downloadedRegion.isComplete = true
                downloadedRegion.fileSizeBytes = Int64(nodeCount * 200)

                context.insert(downloadedRegion)
                try context.save()
            }

            updateProgress(state.regionId, phase: .complete, progress: 1.0, message: "Ready")
            logger.info("Resume complete: \(state.regionId) - \(nodeCount) nodes, \(edgeCount) edges")

            // Remove from active downloads after a delay
            _ = Task {
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run {
                    self.activeDownloads.removeValue(forKey: state.regionId)
                }
            }

        } catch {
            logger.error("Resume failed: \(error.localizedDescription)")
            updateProgress(state.regionId, phase: .failed, progress: 0, message: error.localizedDescription)
            lastError = error.localizedDescription

            _ = Task {
                try? await Task.sleep(for: .seconds(5))
                await MainActor.run {
                    self.activeDownloads.removeValue(forKey: state.regionId)
                }
            }

            throw error
        }
    }

    /// Clean up orphaned data from a failed/incomplete download
    func cleanupOrphanedData(for regionId: String) async {
        guard let context = modelContext else { return }

        logger.info("Cleaning up orphaned data for region: \(regionId)")

        // Remove download state
        DownloadState.remove(regionId: regionId)

        // Delete JSON file if exists
        DownloadState.deleteJsonFile(for: regionId)

        // Delete orphaned nodes in batches
        var deletedCount = 0
        let batchSize = 500

        do {
            while true {
                var descriptor = FetchDescriptor<OSMNode>()
                descriptor.fetchLimit = batchSize

                let allNodes = try context.fetch(descriptor)
                let orphanedNodes = allNodes.filter { $0.regionId == regionId }

                if orphanedNodes.isEmpty {
                    break
                }

                for node in orphanedNodes {
                    context.delete(node)
                }
                deletedCount += orphanedNodes.count

                try context.save()
                await Task.yield()
            }

            if deletedCount > 0 {
                logger.info("Deleted \(deletedCount) orphaned nodes for region: \(regionId)")
            }
        } catch {
            logger.warning("Error cleaning up orphaned nodes: \(error.localizedDescription)")
        }
    }

    /// Clean up all incomplete downloads (call on app launch)
    func cleanupAllIncompleteDownloads() async {
        let incomplete = DownloadState.getIncompleteDownloads()

        for state in incomplete {
            // Only clean up failed downloads, not resumable ones
            if state.phase == .failed || state.phase == .downloading {
                await cleanupOrphanedData(for: state.regionId)
            }
        }
    }

    /// Cancel and clean up an in-progress or incomplete download
    func cancelDownload(_ regionId: String) async {
        // Cancel the running task if any
        if let task = downloadTasks[regionId] {
            task.cancel()
            downloadTasks.removeValue(forKey: regionId)
            logger.info("Cancelled download task for \(regionId)")
        }

        activeDownloads.removeValue(forKey: regionId)
        await cleanupOrphanedData(for: regionId)
    }
}

// MARK: - Errors

enum OSMDataError: LocalizedError {
    case notConfigured
    case alreadyDownloading
    case alreadyDownloaded
    case downloadFailed(String)
    case parsingFailed(String)
    case noRegionForLocation

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "OSM data manager not configured"
        case .alreadyDownloading:
            return "Region is already being downloaded"
        case .alreadyDownloaded:
            return "Region is already downloaded"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .parsingFailed(let message):
            return "Failed to process map data: \(message)"
        case .noRegionForLocation:
            return "No map data available for this location. Please download a region first."
        }
    }
}
