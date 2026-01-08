//
//  OSMDataManager.swift
//  TrackRide
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

    /// Last error message
    private(set) var lastError: String?

    // MARK: - Dependencies

    private var modelContext: ModelContext?
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.trackride", category: "OSMDataManager")

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

    func configure(with context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Public API

    /// Download and process a region
    func downloadRegion(_ region: AvailableRegion) async throws {
        guard let context = modelContext else {
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

        logger.info("Starting download for region: \(region.id)")
        activeDownloads[region.id] = .initial

        do {
            // Phase 1: Download PBF file
            updateProgress(region.id, phase: .downloading, progress: 0, message: "Downloading map data...")
            let pbfURL = try await downloadPBFFile(from: region.downloadURL, regionId: region.id)

            // Phase 2: Parse PBF file
            updateProgress(region.id, phase: .parsing, progress: 0, message: "Processing bridleways...")
            let (nodeCount, edgeCount, bounds) = try await parsePBFFile(
                at: pbfURL,
                regionId: region.id,
                context: context
            )

            // Phase 3: Create region metadata
            updateProgress(region.id, phase: .indexing, progress: 0.9, message: "Finalizing...")
            let downloadedRegion = DownloadedRegion(regionId: region.id, displayName: region.displayName)
            downloadedRegion.nodeCount = nodeCount
            downloadedRegion.edgeCount = edgeCount
            downloadedRegion.minLat = bounds.minLat
            downloadedRegion.maxLat = bounds.maxLat
            downloadedRegion.minLon = bounds.minLon
            downloadedRegion.maxLon = bounds.maxLon
            downloadedRegion.isComplete = true

            // Calculate storage size
            downloadedRegion.fileSizeBytes = try estimateStorageSize(regionId: region.id, context: context)

            context.insert(downloadedRegion)
            try context.save()

            // Cleanup temp file
            try? fileManager.removeItem(at: pbfURL)

            // Complete
            updateProgress(region.id, phase: .complete, progress: 1.0, message: "Ready")
            logger.info("Region download complete: \(region.id) - \(nodeCount) nodes, \(edgeCount) edges")

            // Remove from active downloads after a delay
            Task {
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run {
                    self.activeDownloads.removeValue(forKey: region.id)
                }
            }

        } catch {
            logger.error("Region download failed: \(error.localizedDescription)")
            updateProgress(region.id, phase: .failed, progress: 0, message: error.localizedDescription)
            lastError = error.localizedDescription

            // Remove failed download from active list after delay
            Task {
                try? await Task.sleep(for: .seconds(5))
                await MainActor.run {
                    self.activeDownloads.removeValue(forKey: region.id)
                }
            }

            throw error
        }
    }

    /// Delete a downloaded region and all its nodes
    func deleteRegion(_ regionId: String) async throws {
        guard let context = modelContext else {
            throw OSMDataError.notConfigured
        }

        logger.info("Deleting region: \(regionId)")

        // Delete all nodes for this region
        let nodeDescriptor = FetchDescriptor<OSMNode>(
            predicate: #Predicate { $0.regionId == regionId }
        )
        let nodes = try context.fetch(nodeDescriptor)
        for node in nodes {
            context.delete(node)
        }

        // Delete region metadata
        let regionDescriptor = FetchDescriptor<DownloadedRegion>(
            predicate: #Predicate { $0.regionId == regionId }
        )
        let regions = try context.fetch(regionDescriptor)
        for region in regions {
            context.delete(region)
        }

        try context.save()
        logger.info("Region deleted: \(regionId)")
    }

    /// Check if a region is already downloaded
    func isRegionDownloaded(_ regionId: String) async throws -> Bool {
        guard let context = modelContext else {
            throw OSMDataError.notConfigured
        }

        let descriptor = FetchDescriptor<DownloadedRegion>(
            predicate: #Predicate { $0.regionId == regionId && $0.isComplete == true }
        )
        let count = try context.fetchCount(descriptor)
        return count > 0
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

        let descriptor = FetchDescriptor<DownloadedRegion>(
            predicate: #Predicate {
                $0.isComplete == true &&
                $0.minLat <= lat && $0.maxLat >= lat &&
                $0.minLon <= lon && $0.maxLon >= lon
            }
        )
        return try context.fetch(descriptor)
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

    private func estimateStorageSize(regionId: String, context: ModelContext) throws -> Int64 {
        // Rough estimate: ~200 bytes per node on average
        let nodeDescriptor = FetchDescriptor<OSMNode>(
            predicate: #Predicate { $0.regionId == regionId }
        )
        let nodeCount = try context.fetchCount(nodeDescriptor)
        return Int64(nodeCount * 200)
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
