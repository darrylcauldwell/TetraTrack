//
//  OverpassDataFetcher.swift
//  TrackRide
//
//  Fetches OSM routing data via Overpass API with resumable processing
//

import Foundation
import SwiftData
import os
#if canImport(UIKit)
import UIKit
#endif

/// Fetches OSM routing data using the Overpass API
/// Supports resumable downloads - saves JSON to disk and tracks progress
actor OverpassDataFetcher {

    private let regionId: String
    private let displayName: String
    private let modelContainer: ModelContainer
    private let logger = Logger(subsystem: "com.trackride", category: "OverpassFetcher")

    /// Actor-isolated ModelContext - created lazily to ensure it's bound to the actor's executor
    private lazy var modelContext: ModelContext = {
        ModelContext(modelContainer)
    }()

    // Overpass API endpoints (use multiple for redundancy)
    private let overpassEndpoints = [
        "https://overpass-api.de/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter"
    ]

    init(regionId: String, displayName: String, modelContainer: ModelContainer) {
        self.regionId = regionId
        self.displayName = displayName
        self.modelContainer = modelContainer
    }

    // MARK: - Background Task State

    /// Current state for background task expiration handler
    private var currentState: DownloadState?

    // MARK: - Main Entry Point

    /// Fetch routing data for a region using Overpass API
    /// Saves JSON to disk for resume capability
    func fetch(
        bounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double),
        progressCallback: @escaping (Double, String) -> Void
    ) async throws -> (nodeCount: Int, edgeCount: Int) {

        logger.info("Starting fetch for region: \(self.regionId)")

        // Keep screen awake and request background time with proper expiration handler
        #if canImport(UIKit)
        await MainActor.run {
            UIApplication.shared.isIdleTimerDisabled = true
        }

        // Create background task with expiration handler that saves state
        let backgroundTaskId = await MainActor.run { [weak self] () -> UIBackgroundTaskIdentifier in
            var taskId = UIBackgroundTaskIdentifier.invalid
            taskId = UIApplication.shared.beginBackgroundTask(withName: "OSMDataProcessing") {
                // Called when iOS is about to kill the task - save state for recovery
                Task { @MainActor in
                    if let self = self {
                        Task {
                            await self.handleBackgroundTaskExpiration()
                        }
                    }
                    if taskId != .invalid {
                        UIApplication.shared.endBackgroundTask(taskId)
                    }
                }
            }
            return taskId
        }

        defer {
            Task { @MainActor in
                UIApplication.shared.isIdleTimerDisabled = false
                if backgroundTaskId != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskId)
                }
            }
        }
        #endif

        // Initialize download state
        var state = DownloadState(
            regionId: regionId,
            regionDisplayName: displayName,
            bounds: DownloadState.Bounds(
                minLat: bounds.minLat,
                maxLat: bounds.maxLat,
                minLon: bounds.minLon,
                maxLon: bounds.maxLon
            ),
            phase: .downloading,
            nodesProcessed: 0,
            edgesProcessed: 0,
            totalNodes: 0,
            totalEdges: 0,
            jsonFilePath: nil,
            startedAt: Date(),
            lastUpdatedAt: Date()
        )
        currentState = state  // Track for background expiration handler
        await saveState(state)

        do {
            // Check for cancellation before starting
            try Task.checkCancellation()

            // Phase 1: Download JSON from Overpass API
            progressCallback(0.0, "Connecting to OpenStreetMap...")
            let jsonData = try await downloadData(bounds: bounds, progressCallback: { progress, message in
                progressCallback(progress * 0.15, message)  // 0-15%
            })

            // Check for cancellation after download
            try Task.checkCancellation()

            // Save JSON to disk for resume capability
            progressCallback(0.15, "Saving data...")
            let jsonPath = DownloadState.jsonFilePath(for: regionId)
            try jsonData.write(to: jsonPath)
            state.jsonFilePath = jsonPath.path
            state.phase = .downloaded
            state.lastUpdatedAt = Date()
            currentState = state
            await saveState(state)
            logger.info("Saved \(jsonData.count) bytes to \(jsonPath.path)")

            // Check for cancellation before processing
            try Task.checkCancellation()

            // Phase 2: Process the data
            let result = try await processFromFile(
                state: &state,
                progressCallback: { progress, message in
                    progressCallback(0.15 + progress * 0.85, message)  // 15-100%
                }
            )

            // Clean up
            state.phase = .complete
            state.lastUpdatedAt = Date()
            currentState = nil  // Clear - no longer needed
            await saveState(state)
            DownloadState.deleteJsonFile(for: regionId)
            DownloadState.remove(regionId: regionId)

            // Clean up temp coords file
            cleanupTempFiles()

            progressCallback(1.0, "Complete")
            return result

        } catch {
            state.phase = .failed
            state.lastUpdatedAt = Date()
            currentState = nil
            await saveState(state)
            cleanupTempFiles()
            throw error
        }
    }

    /// Handle background task expiration - save state for recovery
    private func handleBackgroundTaskExpiration() {
        logger.warning("Background task expiring - saving state for recovery")

        // Save current state so download can be resumed
        if var state = currentState {
            state.lastUpdatedAt = Date()
            // Force synchronous save to ensure it persists before termination
            DownloadState.save(state)
            UserDefaults.standard.synchronize()
            logger.info("Saved state for resume: phase=\(state.phase.rawValue), nodes=\(state.nodesProcessed)")
        }
    }

    /// Clean up temporary files
    private func cleanupTempFiles() {
        let coordsTempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(regionId)_coords.bin")
        try? FileManager.default.removeItem(at: coordsTempURL)
    }

    /// Resume processing from a saved JSON file
    func resumeFromState(
        _ state: inout DownloadState,
        progressCallback: @escaping (Double, String) -> Void
    ) async throws -> (nodeCount: Int, edgeCount: Int) {

        let phaseRawValue = state.phase.rawValue
        logger.info("Resuming from state: \(phaseRawValue) for region: \(self.regionId)")

        // Keep screen awake and request background time
        #if canImport(UIKit)
        await MainActor.run {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        let backgroundTaskId = await MainActor.run {
            UIApplication.shared.beginBackgroundTask(withName: "OSMDataProcessing") {}
        }
        defer {
            Task { @MainActor in
                UIApplication.shared.isIdleTimerDisabled = false
                if backgroundTaskId != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskId)
                }
            }
        }
        #endif

        do {
            let result = try await processFromFile(
                state: &state,
                progressCallback: progressCallback
            )

            // Clean up
            state.phase = .complete
            state.lastUpdatedAt = Date()
            await saveState(state)
            DownloadState.deleteJsonFile(for: regionId)
            DownloadState.remove(regionId: regionId)

            progressCallback(1.0, "Complete")
            return result

        } catch {
            state.phase = .failed
            state.lastUpdatedAt = Date()
            await saveState(state)
            throw error
        }
    }

    // MARK: - Download

    private func downloadData(
        bounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double),
        progressCallback: @escaping (Double, String) -> Void
    ) async throws -> Data {

        let query = buildOverpassQuery(bounds: bounds)
        var lastError: Error?
        let maxRetriesPerEndpoint = 3

        for (endpointIndex, endpoint) in overpassEndpoints.enumerated() {
            for attempt in 0..<maxRetriesPerEndpoint {
                do {
                    // Exponential backoff on retry: 2, 4, 8 seconds
                    if attempt > 0 {
                        let backoffSeconds = Double(1 << attempt)  // 2, 4, 8
                        logger.info("Retry \(attempt + 1)/\(maxRetriesPerEndpoint) after \(Int(backoffSeconds))s delay...")
                        progressCallback(0.0, "Retrying in \(Int(backoffSeconds))s...")
                        try await Task.sleep(nanoseconds: UInt64(backoffSeconds * 1_000_000_000))
                    }

                    return try await executeQuery(query, endpoint: endpoint, progressCallback: progressCallback)
                } catch {
                    lastError = error
                    let isLastAttempt = attempt == maxRetriesPerEndpoint - 1
                    let isLastEndpoint = endpointIndex == overpassEndpoints.count - 1

                    // Determine if error is retryable
                    let isRetryable = isRetryableError(error)

                    if isLastAttempt || !isRetryable {
                        logger.warning("Endpoint \(endpoint) failed after \(attempt + 1) attempts: \(error.localizedDescription)")
                        if !isLastEndpoint {
                            progressCallback(0.0, "Trying alternate server...")
                        }
                        break  // Move to next endpoint
                    } else {
                        logger.info("Endpoint \(endpoint) attempt \(attempt + 1) failed (will retry): \(error.localizedDescription)")
                    }
                }
            }
        }

        throw lastError ?? OSMDataError.downloadFailed("All Overpass endpoints failed after retries")
    }

    /// Determine if an error is retryable (network issues, timeouts, server errors)
    private nonisolated func isRetryableError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet,
                 .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return true
            default:
                return false
            }
        }

        // Retry on server errors (5xx) but not client errors (4xx)
        if let osmError = error as? OSMDataError {
            switch osmError {
            case .downloadFailed(let message):
                return message.contains("HTTP 5") || message.contains("HTTP 429")  // Server error or rate limited
            default:
                return false
            }
        }

        return true  // Retry unknown errors by default
    }

    private func buildOverpassQuery(bounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)) -> String {
        let bbox = "\(bounds.minLat),\(bounds.minLon),\(bounds.maxLat),\(bounds.maxLon)"
        return """
        [out:json][timeout:300];
        (
          way["highway"="bridleway"](\(bbox));
          way["highway"="byway"](\(bbox));
          way["highway"="track"](\(bbox));
          way["highway"="path"]["horse"!="no"](\(bbox));
          way["highway"="unclassified"](\(bbox));
          way["highway"="residential"](\(bbox));
          way["highway"="service"]["service"!="parking_aisle"]["service"!="driveway"](\(bbox));
          way["horse"="yes"](\(bbox));
          way["horse"="designated"](\(bbox));
          way["horse"="permissive"](\(bbox));
        );
        (._;>;);
        out body;
        """
    }

    private func executeQuery(
        _ query: String,
        endpoint: String,
        progressCallback: @escaping (Double, String) -> Void
    ) async throws -> Data {
        guard let url = URL(string: endpoint) else {
            throw OSMDataError.downloadFailed("Invalid endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("TrackRide/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 300
        request.httpBody = "data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)".data(using: .utf8)

        progressCallback(0.1, "Downloading from OpenStreetMap...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OSMDataError.downloadFailed("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            if let errorText = String(data: data.prefix(500), encoding: .utf8) {
                logger.error("Overpass error response: \(errorText)")
            }
            throw OSMDataError.downloadFailed("HTTP \(httpResponse.statusCode)")
        }

        progressCallback(0.9, "Downloaded \(formatBytes(Int64(data.count)))")
        return data
    }

    // MARK: - Processing (Streaming approach for large files)

    private func processFromFile(
        state: inout DownloadState,
        progressCallback: @escaping (Double, String) -> Void
    ) async throws -> (nodeCount: Int, edgeCount: Int) {

        guard let jsonPath = state.jsonFilePath else {
            throw OSMDataError.downloadFailed("No JSON file path in state")
        }

        let jsonURL = URL(fileURLWithPath: jsonPath)
        guard FileManager.default.fileExists(atPath: jsonPath) else {
            throw OSMDataError.downloadFailed("JSON file not found at \(jsonPath)")
        }

        // Get file size to estimate progress
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: jsonPath)[.size] as? Int64) ?? 0
        logger.info("Processing JSON file: \(self.formatBytes(fileSize))")

        // STREAMING APPROACH: Never load entire JSON into memory
        // Pass 1: Stream through JSON, collect node coords into binary temp file
        // Pass 2: Stream through JSON again, process ways using temp file lookups

        progressCallback(0.0, "Scanning map data (pass 1)...")

        // Create temp file for node coordinates (compact binary format)
        let coordsTempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(regionId)_coords.bin")
        try? FileManager.default.removeItem(at: coordsTempURL)

        // Pass 1: Extract nodes and ways metadata using streaming
        let (nodeCount, wayCount, routingNodeIds) = try await streamingPass1(
            jsonURL: jsonURL,
            coordsTempURL: coordsTempURL,
            fileSize: fileSize,
            progressCallback: { progress, message in
                progressCallback(progress * 0.3, message)  // 0-30%
            }
        )

        state.totalNodes = nodeCount
        state.totalEdges = wayCount
        currentState = state  // Keep in sync for background expiration
        await saveState(state)

        logger.info("Pass 1 complete: \(nodeCount) routing nodes, \(wayCount) ways")
        progressCallback(0.3, "Building waypoints (pass 2)...")

        // Load coordinate lookup from temp file (memory-mapped for efficiency)
        let coordLookup = try loadCoordinateLookup(from: coordsTempURL, nodeIds: routingNodeIds)

        // Pass 2: Create nodes in database
        try await streamingPass2CreateNodes(
            coordLookup: coordLookup,
            routingNodeIds: routingNodeIds,
            state: &state,
            progressCallback: { progress, message in
                progressCallback(0.3 + progress * 0.3, message)  // 30-60%
            }
        )

        progressCallback(0.6, "Building connections (pass 3)...")

        // Pass 3: Stream through JSON again to process ways and create edges
        let edgeCount = try await streamingPass3CreateEdges(
            jsonURL: jsonURL,
            coordLookup: coordLookup,
            fileSize: fileSize,
            state: &state,
            progressCallback: { progress, message in
                progressCallback(0.6 + progress * 0.35, message)  // 60-95%
            }
        )

        // Cleanup temp file
        try? FileManager.default.removeItem(at: coordsTempURL)

        // Finalize
        state.phase = .finalizing
        state.lastUpdatedAt = Date()
        await saveState(state)
        progressCallback(0.95, "Finalizing...")

        try modelContext.save()

        return (state.nodesProcessed, edgeCount)
    }

    // MARK: - Streaming Pass 1: Extract node coordinates

    /// Stream through JSON file, extract node coordinates to binary temp file
    /// Returns: (routingNodeCount, wayCount, routingNodeIds)
    private func streamingPass1(
        jsonURL: URL,
        coordsTempURL: URL,
        fileSize: Int64,
        progressCallback: @escaping (Double, String) -> Void
    ) async throws -> (Int, Int, Set<Int64>) {

        // Create output file for coordinates
        FileManager.default.createFile(atPath: coordsTempURL.path, contents: nil)
        let coordsHandle = try FileHandle(forWritingTo: coordsTempURL)
        defer { try? coordsHandle.close() }

        // Open input file for streaming
        let inputHandle = try FileHandle(forReadingFrom: jsonURL)
        defer { try? inputHandle.close() }

        var nodeCoordIndex: [Int64: (lat: Double, lon: Double)] = [:]  // Temp storage for coords
        var routingNodeIds = Set<Int64>()
        var wayCount = 0
        var bytesRead: Int64 = 0
        var buffer = Data()
        let chunkSize = 1024 * 1024  // 1MB chunks

        // Read and process in chunks
        while let chunk = try inputHandle.read(upToCount: chunkSize), !chunk.isEmpty {
            bytesRead += Int64(chunk.count)
            buffer.append(chunk)

            // Process complete JSON objects from buffer
            while let (element, remainingBuffer) = extractNextElement(from: buffer) {
                buffer = remainingBuffer

                autoreleasepool {
                    if let type = element["type"] as? String {
                        if type == "node" {
                            if let id = element["id"] as? Int64,
                               let lat = element["lat"] as? Double,
                               let lon = element["lon"] as? Double {
                                nodeCoordIndex[id] = (lat, lon)
                            }
                        } else if type == "way" {
                            wayCount += 1
                            if let nodes = element["nodes"] as? [Int64] {
                                for nodeId in nodes {
                                    routingNodeIds.insert(nodeId)
                                }
                            } else if let nodes = element["nodes"] as? [Int] {
                                for nodeId in nodes {
                                    routingNodeIds.insert(Int64(nodeId))
                                }
                            }
                        }
                    }
                }
            }

            // Progress update
            let progress = Double(bytesRead) / Double(max(fileSize, 1))
            progressCallback(progress, "Scanning (\(Int(progress * 100))%)...")

            await Task.yield()
        }

        // Write coordinates for routing nodes only to binary file
        var coordData = Data()
        for nodeId in routingNodeIds {
            if let (lat, lon) = nodeCoordIndex[nodeId] {
                var id = nodeId
                var latitude = lat
                var longitude = lon
                coordData.append(Data(bytes: &id, count: 8))
                coordData.append(Data(bytes: &latitude, count: 8))
                coordData.append(Data(bytes: &longitude, count: 8))
            }
        }
        try coordsHandle.write(contentsOf: coordData)

        let routingNodeCount = routingNodeIds.count
        nodeCoordIndex.removeAll()  // Release memory

        return (routingNodeCount, wayCount, routingNodeIds)
    }

    /// Extract next complete JSON element from buffer
    private nonisolated func extractNextElement(from buffer: Data) -> ([String: Any], Data)? {
        guard let string = String(data: buffer, encoding: .utf8) else { return nil }

        // Find start of an element (look for {"type": pattern)
        guard let typeRange = string.range(of: "\"type\"") else { return nil }

        // Find the opening brace before "type"
        let beforeType = string[..<typeRange.lowerBound]
        guard let braceIndex = beforeType.lastIndex(of: "{") else { return nil }

        // Find matching closing brace
        var depth = 0
        var endIndex: String.Index?
        var inString = false
        var escapeNext = false

        for i in string.indices[braceIndex...] {
            let char = string[i]

            if escapeNext {
                escapeNext = false
                continue
            }

            if char == "\\" {
                escapeNext = true
                continue
            }

            if char == "\"" {
                inString = !inString
                continue
            }

            if inString { continue }

            if char == "{" {
                depth += 1
            } else if char == "}" {
                depth -= 1
                if depth == 0 {
                    endIndex = string.index(after: i)
                    break
                }
            }
        }

        guard let end = endIndex else { return nil }

        let jsonString = String(string[braceIndex..<end])
        guard let jsonData = jsonString.data(using: .utf8),
              let element = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            // Skip malformed element, advance buffer
            let skipIndex = string.index(after: braceIndex)
            let remaining = String(string[skipIndex...])
            return extractNextElement(from: remaining.data(using: .utf8) ?? Data())
        }

        let remaining = String(string[end...])
        return (element, remaining.data(using: .utf8) ?? Data())
    }

    // MARK: - Load coordinate lookup from binary file

    private func loadCoordinateLookup(from url: URL, nodeIds: Set<Int64>) throws -> [Int64: (lat: Double, lon: Double)] {
        let data = try Data(contentsOf: url)
        var lookup: [Int64: (lat: Double, lon: Double)] = [:]
        lookup.reserveCapacity(nodeIds.count)

        var offset = 0
        while offset + 24 <= data.count {
            let id = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Int64.self) }
            let lat = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 8, as: Double.self) }
            let lon = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 16, as: Double.self) }
            lookup[id] = (lat, lon)
            offset += 24
        }

        return lookup
    }

    // MARK: - Streaming Pass 2: Create nodes in database

    private func streamingPass2CreateNodes(
        coordLookup: [Int64: (lat: Double, lon: Double)],
        routingNodeIds: Set<Int64>,
        state: inout DownloadState,
        progressCallback: @escaping (Double, String) -> Void
    ) async throws {

        state.phase = .processingNodes
        currentState = state
        await saveState(state)

        let sortedNodeIds = Array(routingNodeIds).sorted()
        let totalNodes = sortedNodeIds.count
        let batchSize = 1000
        var processedCount = 0
        var lastStateSaveTime = Date()

        for batchStart in stride(from: 0, to: totalNodes, by: batchSize) {
            // Check for cancellation every batch
            try Task.checkCancellation()

            let batchEnd = min(batchStart + batchSize, totalNodes)

            autoreleasepool {
                for index in batchStart..<batchEnd {
                    let nodeId = sortedNodeIds[index]
                    if let (lat, lon) = coordLookup[nodeId] {
                        let node = OSMNode(osmId: nodeId, latitude: lat, longitude: lon, regionId: regionId)
                        modelContext.insert(node)
                        processedCount += 1
                    }
                }

                try? modelContext.save()
            }

            // Save state every 3 seconds for robustness
            let now = Date()
            if now.timeIntervalSince(lastStateSaveTime) > 3.0 {
                state.nodesProcessed = processedCount
                state.lastUpdatedAt = now
                currentState = state
                await saveState(state)
                lastStateSaveTime = now
            }

            let progress = Double(processedCount) / Double(totalNodes)
            let percent = Int(progress * 100)
            progressCallback(progress, "Creating waypoints (\(percent)%)...")

            await Task.yield()
        }

        state.nodesProcessed = processedCount
        currentState = state
        await saveState(state)
    }

    // MARK: - Streaming Pass 3: Create edges by streaming JSON again
    // Memory-optimized: loads nodes in batches, processes ways, saves frequently

    private func streamingPass3CreateEdges(
        jsonURL: URL,
        coordLookup: [Int64: (lat: Double, lon: Double)],
        fileSize: Int64,
        state: inout DownloadState,
        progressCallback: @escaping (Double, String) -> Void
    ) async throws -> Int {

        state.phase = .processingEdges
        currentState = state
        await saveState(state)

        // CRITICAL: Aggressive memory management for large regions
        // Keep cache very small and save very frequently to avoid jetsam kills
        var nodeCache: [Int64: OSMNode] = [:]
        let maxCacheSize = 2000  // Very small cache - 2k nodes max to avoid memory pressure

        // Initial cache load
        nodeCache = loadNodeCacheBatch(limit: maxCacheSize)
        logger.info("Initial node cache loaded: \(nodeCache.count) nodes")

        let inputHandle = try FileHandle(forReadingFrom: jsonURL)
        defer { try? inputHandle.close() }

        var totalEdgeCount = 0
        var wayCount = 0
        var bytesRead: Int64 = 0
        var buffer = Data()
        let chunkSize = 128 * 1024  // Even smaller chunks: 128KB
        var lastSaveTime = Date()
        var edgesSinceLastSave = 0
        let saveEveryNEdges = 1000  // Save very frequently - every 1000 edges
        var cacheRefreshCounter = 0
        let cacheRefreshInterval = 3  // Refresh cache every 3 save cycles

        while let chunk = try inputHandle.read(upToCount: chunkSize), !chunk.isEmpty {
            // Check for cancellation during chunk processing
            try Task.checkCancellation()

            bytesRead += Int64(chunk.count)
            buffer.append(chunk)

            while let (element, remainingBuffer) = extractNextElement(from: buffer) {
                buffer = remainingBuffer

                autoreleasepool {
                    guard let type = element["type"] as? String, type == "way" else { return }

                    wayCount += 1

                    let tags = element["tags"] as? [String: String] ?? [:]
                    let wayType = OSMWayType(osmTag: tags["highway"] ?? "path")
                    let surface = OSMSurfaceType(osmTag: tags["surface"])
                    let isOneway = tags["oneway"] == "yes"
                    let horseAccess = OSMHorseAccess(tags: tags, wayType: wayType)

                    guard horseAccess != .no else { return }

                    // Get node IDs from way
                    var nodeIds: [Int64] = []
                    if let nodes = element["nodes"] as? [Int64] {
                        nodeIds = nodes
                    } else if let nodes = element["nodes"] as? [Int] {
                        nodeIds = nodes.map { Int64($0) }
                    }

                    guard nodeIds.count >= 2 else { return }

                    for i in 0..<(nodeIds.count - 1) {
                        let fromId = nodeIds[i]
                        let toId = nodeIds[i + 1]

                        guard let fromCoord = coordLookup[fromId],
                              let toCoord = coordLookup[toId],
                              let fromNode = nodeCache[fromId] else { continue }

                        let distance = haversineDistance(
                            lat1: fromCoord.lat, lon1: fromCoord.lon,
                            lat2: toCoord.lat, lon2: toCoord.lon
                        )

                        // Forward edge
                        let edge = OSMEdge(
                            toNodeId: toId,
                            distance: distance,
                            wayType: wayType,
                            surface: surface,
                            bidirectional: !isOneway
                        )

                        var edges = fromNode.edges
                        edges.append(edge)
                        fromNode.setEdges(edges)
                        totalEdgeCount += 1
                        edgesSinceLastSave += 1

                        // Reverse edge
                        if !isOneway, let toNode = nodeCache[toId] {
                            let reverseEdge = OSMEdge(
                                toNodeId: fromId,
                                distance: distance,
                                wayType: wayType,
                                surface: surface,
                                bidirectional: true
                            )
                            var toEdges = toNode.edges
                            toEdges.append(reverseEdge)
                            toNode.setEdges(toEdges)
                            totalEdgeCount += 1
                            edgesSinceLastSave += 1
                        }
                    }
                }

                // Save frequently - by edge count to manage memory
                if edgesSinceLastSave >= saveEveryNEdges {
                    try? modelContext.save()

                    let now = Date()
                    state.edgesProcessed = wayCount
                    state.lastUpdatedAt = now
                    currentState = state
                    await saveState(state)
                    lastSaveTime = now
                    edgesSinceLastSave = 0
                    cacheRefreshCounter += 1

                    // Periodically refresh cache to release memory
                    // Don't do it every save as that's expensive
                    if cacheRefreshCounter >= cacheRefreshInterval {
                        cacheRefreshCounter = 0

                        // Clear and rebuild cache - this releases the managed objects
                        // allowing ARC to free memory
                        nodeCache.removeAll(keepingCapacity: false)

                        // Force garbage collection pause
                        await Task.yield()

                        // Reload smaller cache
                        nodeCache = loadNodeCacheBatch(limit: maxCacheSize)

                        logger.debug("Cache refreshed after \(totalEdgeCount) edges, memory released")
                    }
                }
            }

            // Also save periodically by time
            let now = Date()
            if now.timeIntervalSince(lastSaveTime) > 3 {
                try? modelContext.save()
                state.edgesProcessed = wayCount
                state.lastUpdatedAt = now
                currentState = state
                await saveState(state)
                lastSaveTime = now
            }

            let progress = Double(bytesRead) / Double(max(fileSize, 1))
            let percent = Int(progress * 100)
            progressCallback(progress, "Building connections (\(percent)%)...")

            await Task.yield()
        }

        try modelContext.save()
        state.edgesProcessed = wayCount
        currentState = state
        await saveState(state)

        logger.info("Edge creation complete: \(totalEdgeCount) edges from \(wayCount) ways")
        return totalEdgeCount
    }

    /// Load a batch of nodes for the current region into cache
    /// Uses predicate and fetch limit to avoid loading all nodes into memory
    private func loadNodeCacheBatch(limit: Int) -> [Int64: OSMNode] {
        // Use predicate to filter at database level, not in memory
        var descriptor = FetchDescriptor<OSMNode>(
            predicate: #Predicate<OSMNode> { $0.regionId == regionId }
        )
        descriptor.fetchLimit = limit

        guard let nodes = try? modelContext.fetch(descriptor) else { return [:] }

        var cache: [Int64: OSMNode] = [:]
        cache.reserveCapacity(nodes.count)

        for node in nodes {
            cache[node.osmId] = node
        }
        return cache
    }

    private func processNodes(
        sortedNodeIds: [Int64],
        nodeCoords: [Int64: (lat: Double, lon: Double)],
        state: inout DownloadState,
        progressCallback: @escaping (Double, String) -> Void
    ) async throws -> [Int64: OSMNode] {

        state.phase = .processingNodes
        await saveState(state)

        var nodeModels: [Int64: OSMNode] = [:]
        let batchSize = 5000  // OPTIMIZATION: Increased from 500
        var batch: [OSMNode] = []
        batch.reserveCapacity(batchSize)
        let startIndex = state.nodesProcessed
        var lastStateSaveTime = Date()
        let totalNodes = sortedNodeIds.count

        // If resuming, load existing nodes into memory
        if startIndex > 0 {
            progressCallback(0.0, "Loading existing waypoints...")
            let existingNodes = try fetchExistingNodes()
            for node in existingNodes {
                nodeModels[node.osmId] = node
            }
            logger.info("Loaded \(existingNodes.count) existing nodes for resume")
        }

        // Reserve capacity for better memory performance
        nodeModels.reserveCapacity(totalNodes)

        for (index, nodeId) in sortedNodeIds.enumerated() {
            // Skip already processed nodes
            if index < startIndex {
                continue
            }

            guard let (lat, lon) = nodeCoords[nodeId] else { continue }

            let node = OSMNode(osmId: nodeId, latitude: lat, longitude: lon, regionId: regionId)
            nodeModels[nodeId] = node
            batch.append(node)

            // Save in larger batches
            if batch.count >= batchSize {
                for n in batch {
                    modelContext.insert(n)
                }
                try modelContext.save()
                batch.removeAll(keepingCapacity: true)

                // Only save state every 15 seconds (not every batch)
                let now = Date()
                if now.timeIntervalSince(lastStateSaveTime) > 15 {
                    state.nodesProcessed = index + 1
                    state.lastUpdatedAt = now
                    lastStateSaveTime = now
                    await saveState(state)
                }

                let progress = Double(index + 1) / Double(totalNodes)
                let percent = Int(progress * 100)
                progressCallback(progress, "Creating waypoints (\(percent)%)...")

                await Task.yield()
            }
        }

        // Save remaining batch
        if !batch.isEmpty {
            for n in batch {
                modelContext.insert(n)
            }
            try modelContext.save()
        }

        state.nodesProcessed = sortedNodeIds.count
        state.lastUpdatedAt = Date()
        await saveState(state)

        let nodesCreated = state.nodesProcessed
        logger.info("Created \(nodesCreated) routing nodes")
        return nodeModels
    }

    private func processEdges(
        ways: [OverpassWay],
        nodeCoords: [Int64: (lat: Double, lon: Double)],
        nodeModels: [Int64: OSMNode],
        state: inout DownloadState,
        progressCallback: @escaping (Double, String) -> Void
    ) async throws -> Int {

        state.phase = .processingEdges
        await saveState(state)

        progressCallback(0.0, "Building route graph...")

        // OPTIMIZATION: Use parallel processing to build edges
        let totalWays = ways.count
        let validNodeIds = Set(nodeModels.keys)

        // Phase 1: Build edges in parallel using all CPU cores
        let edgeResults = await withTaskGroup(of: (edges: [Int64: [OSMEdge]], count: Int).self) { group in
            // Split ways into chunks for parallel processing
            let chunkSize = max(1000, ways.count / ProcessInfo.processInfo.activeProcessorCount)
            let chunks = stride(from: 0, to: ways.count, by: chunkSize).map {
                Array(ways[$0..<min($0 + chunkSize, ways.count)])
            }

            for chunk in chunks {
                group.addTask {
                    var localEdges: [Int64: [OSMEdge]] = [:]
                    var localCount = 0

                    for way in chunk {
                        let wayType = OSMWayType(osmTag: way.tags["highway"] ?? "path")
                        let surface = OSMSurfaceType(osmTag: way.tags["surface"])
                        let isOneway = way.tags["oneway"] == "yes"
                        let horseAccess = OSMHorseAccess(tags: way.tags, wayType: wayType)

                        guard horseAccess != .no else { continue }

                        for i in 0..<(way.nodes.count - 1) {
                            let fromId = way.nodes[i]
                            let toId = way.nodes[i + 1]

                            guard let fromCoord = nodeCoords[fromId],
                                  let toCoord = nodeCoords[toId],
                                  validNodeIds.contains(fromId) else { continue }

                            let distance = self.haversineDistance(
                                lat1: fromCoord.lat, lon1: fromCoord.lon,
                                lat2: toCoord.lat, lon2: toCoord.lon
                            )

                            // Forward edge
                            let edge = OSMEdge(
                                toNodeId: toId,
                                distance: distance,
                                wayType: wayType,
                                surface: surface,
                                bidirectional: !isOneway
                            )
                            localEdges[fromId, default: []].append(edge)
                            localCount += 1

                            // Reverse edge if bidirectional
                            if !isOneway && validNodeIds.contains(toId) {
                                let reverseEdge = OSMEdge(
                                    toNodeId: fromId,
                                    distance: distance,
                                    wayType: wayType,
                                    surface: surface,
                                    bidirectional: true
                                )
                                localEdges[toId, default: []].append(reverseEdge)
                                localCount += 1
                            }
                        }
                    }

                    return (localEdges, localCount)
                }
            }

            // Merge results from all tasks
            var mergedEdges: [Int64: [OSMEdge]] = [:]
            var totalEdgeCount = 0

            for await result in group {
                totalEdgeCount += result.1
                for (nodeId, edges) in result.0 {
                    mergedEdges[nodeId, default: []].append(contentsOf: edges)
                }
            }

            return (mergedEdges, totalEdgeCount)
        }

        let edgesByNode = edgeResults.0
        let edgeCount = edgeResults.1

        progressCallback(0.4, "Saving connections...")

        // Phase 2: Assign edges to nodes in bulk (single binary encode per node)
        let nodesWithEdges = Array(edgesByNode.keys)
        let batchSize = 5000  // Larger batches
        var lastSaveTime = Date()
        var processedNodes = 0

        for nodeId in nodesWithEdges {
            guard let node = nodeModels[nodeId],
                  let edges = edgesByNode[nodeId] else { continue }

            node.setEdges(edges)  // Single binary encode per node
            processedNodes += 1

            // Save in larger batches
            if processedNodes % batchSize == 0 {
                try modelContext.save()

                let now = Date()
                if now.timeIntervalSince(lastSaveTime) > 15 {
                    state.edgesProcessed = processedNodes
                    state.lastUpdatedAt = now
                    lastSaveTime = now
                    await saveState(state)
                }

                let progress = 0.4 + (Double(processedNodes) / Double(nodesWithEdges.count)) * 0.6
                let percent = Int(progress * 100)
                progressCallback(progress, "Saving connections (\(percent)%)...")

                await Task.yield()
            }
        }

        // Final save
        try modelContext.save()
        state.edgesProcessed = ways.count
        await saveState(state)

        logger.info("Created \(edgeCount) edges across \(nodesWithEdges.count) nodes")
        return edgeCount
    }

    private func fetchExistingNodes() throws -> [OSMNode] {
        // Fetch all and filter in Swift to avoid #Predicate variable capture crash
        let descriptor = FetchDescriptor<OSMNode>()
        let allNodes = try modelContext.fetch(descriptor)
        return allNodes.filter { $0.regionId == regionId }
    }

    // MARK: - Memory-Efficient Processing (for large regions)

    /// Process nodes without keeping them all in memory - saves directly to DB
    private func processNodesMemoryEfficient(
        sortedNodeIds: [Int64],
        nodeCoords: [Int64: (lat: Double, lon: Double)],
        state: inout DownloadState,
        progressCallback: @escaping (Double, String) -> Void
    ) async throws {

        state.phase = .processingNodes
        await saveState(state)

        // Adaptive batch size based on data size:
        // - Small regions (<50K nodes): larger batches for speed
        // - Large regions (>50K nodes): smaller batches to avoid memory issues
        let totalNodes = sortedNodeIds.count
        let batchSize: Int
        if totalNodes < 50_000 {
            batchSize = 5000  // Fast for small regions
        } else if totalNodes < 200_000 {
            batchSize = 2000  // Medium regions
        } else {
            batchSize = 1000  // Large regions - conservative
        }

        let startIndex = state.nodesProcessed
        var lastStateSaveTime = Date()
        var processedCount = startIndex

        logger.info("Processing \(totalNodes) nodes starting from index \(startIndex) with batch size \(batchSize)")

        for batchStart in stride(from: startIndex, to: totalNodes, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, totalNodes)

            // Process batch in autoreleasepool to free memory
            try autoreleasepool {
                for index in batchStart..<batchEnd {
                    let nodeId = sortedNodeIds[index]
                    guard let (lat, lon) = nodeCoords[nodeId] else { continue }

                    let node = OSMNode(osmId: nodeId, latitude: lat, longitude: lon, regionId: regionId)
                    modelContext.insert(node)
                    processedCount += 1
                }

                try modelContext.save()
            }

            // Update progress
            let now = Date()
            if now.timeIntervalSince(lastStateSaveTime) > 10 {
                state.nodesProcessed = processedCount
                state.lastUpdatedAt = now
                lastStateSaveTime = now
                await saveState(state)
            }

            let progress = Double(processedCount) / Double(totalNodes)
            let percent = Int(progress * 100)
            progressCallback(progress, "Creating waypoints (\(percent)%)...")

            await Task.yield()
        }

        state.nodesProcessed = processedCount
        state.lastUpdatedAt = Date()
        await saveState(state)

        logger.info("Created \(processedCount) routing nodes")
    }

    /// Process edges without keeping all nodes in memory - fetches from DB in batches
    private func processEdgesMemoryEfficient(
        ways: [OverpassWay],
        nodeCoords: [Int64: (lat: Double, lon: Double)],
        state: inout DownloadState,
        progressCallback: @escaping (Double, String) -> Void
    ) async throws -> Int {

        state.phase = .processingEdges
        await saveState(state)

        progressCallback(0.0, "Building route connections...")

        let totalWays = ways.count
        var totalEdgeCount = 0

        // Adaptive batch sizes based on data size
        let wayBatchSize: Int
        let nodeCacheSize: Int
        if totalWays < 10_000 {
            wayBatchSize = 2000   // Fast for small regions
            nodeCacheSize = 100_000
        } else if totalWays < 50_000 {
            wayBatchSize = 1000   // Medium regions
            nodeCacheSize = 75_000
        } else {
            wayBatchSize = 500    // Large regions - conservative
            nodeCacheSize = 50_000
        }

        var lastSaveTime = Date()

        // Build a lookup of osmId -> node for current batch
        // We'll load nodes from DB in chunks as needed
        var nodeCache: [Int64: OSMNode] = [:]

        for wayBatchStart in stride(from: 0, to: totalWays, by: wayBatchSize) {
            let wayBatchEnd = min(wayBatchStart + wayBatchSize, totalWays)
            let wayBatch = Array(ways[wayBatchStart..<wayBatchEnd])

            // Collect all node IDs needed for this batch of ways
            var neededNodeIds = Set<Int64>()
            for way in wayBatch {
                for nodeId in way.nodes {
                    if nodeCache[nodeId] == nil {
                        neededNodeIds.insert(nodeId)
                    }
                }
            }

            // Load needed nodes from DB (that aren't already cached)
            if !neededNodeIds.isEmpty {
                // Clear cache if it's getting too big
                if nodeCache.count > nodeCacheSize {
                    nodeCache.removeAll(keepingCapacity: true)
                    // Re-add the needed nodes
                    neededNodeIds.removeAll()
                    for way in wayBatch {
                        for nodeId in way.nodes {
                            neededNodeIds.insert(nodeId)
                        }
                    }
                }

                // Fetch nodes from DB
                try autoreleasepool {
                    let descriptor = FetchDescriptor<OSMNode>()
                    let allNodes = try modelContext.fetch(descriptor)
                    for node in allNodes {
                        if neededNodeIds.contains(node.osmId) {
                            nodeCache[node.osmId] = node
                        }
                    }
                }
            }

            // Process this batch of ways
            var batchEdgeCount = 0
            try autoreleasepool {
                for way in wayBatch {
                    let wayType = OSMWayType(osmTag: way.tags["highway"] ?? "path")
                    let surface = OSMSurfaceType(osmTag: way.tags["surface"])
                    let isOneway = way.tags["oneway"] == "yes"
                    let horseAccess = OSMHorseAccess(tags: way.tags, wayType: wayType)

                    guard horseAccess != .no else { continue }

                    for i in 0..<(way.nodes.count - 1) {
                        let fromId = way.nodes[i]
                        let toId = way.nodes[i + 1]

                        guard let fromCoord = nodeCoords[fromId],
                              let toCoord = nodeCoords[toId],
                              let fromNode = nodeCache[fromId] else { continue }

                        let distance = haversineDistance(
                            lat1: fromCoord.lat, lon1: fromCoord.lon,
                            lat2: toCoord.lat, lon2: toCoord.lon
                        )

                        // Forward edge
                        let edge = OSMEdge(
                            toNodeId: toId,
                            distance: distance,
                            wayType: wayType,
                            surface: surface,
                            bidirectional: !isOneway
                        )

                        var currentEdges = fromNode.edges
                        currentEdges.append(edge)
                        fromNode.setEdges(currentEdges)
                        batchEdgeCount += 1

                        // Reverse edge if bidirectional
                        if !isOneway, let toNode = nodeCache[toId] {
                            let reverseEdge = OSMEdge(
                                toNodeId: fromId,
                                distance: distance,
                                wayType: wayType,
                                surface: surface,
                                bidirectional: true
                            )
                            var toEdges = toNode.edges
                            toEdges.append(reverseEdge)
                            toNode.setEdges(toEdges)
                            batchEdgeCount += 1
                        }
                    }
                }

                try modelContext.save()
            }

            totalEdgeCount += batchEdgeCount

            // Update progress
            let now = Date()
            if now.timeIntervalSince(lastSaveTime) > 10 {
                state.edgesProcessed = wayBatchEnd
                state.lastUpdatedAt = now
                lastSaveTime = now
                await saveState(state)
            }

            let progress = Double(wayBatchEnd) / Double(totalWays)
            let percent = Int(progress * 100)
            progressCallback(progress, "Building connections (\(percent)%)...")

            await Task.yield()
        }

        state.edgesProcessed = totalWays
        await saveState(state)

        logger.info("Created \(totalEdgeCount) edges from \(totalWays) ways")
        return totalEdgeCount
    }

    // MARK: - Utilities

    private func saveState(_ state: DownloadState) async {
        await MainActor.run {
            DownloadState.save(state)
        }
    }

    private nonisolated func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat/2) * sin(dLat/2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon/2) * sin(dLon/2)
        return R * 2 * atan2(sqrt(a), sqrt(1-a))
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        }
    }
}

// MARK: - Overpass Response Models

struct OverpassResponse: Decodable {
    let elements: [OverpassElement]
}

enum OverpassElement: Decodable {
    case node(OverpassNode)
    case way(OverpassWay)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "node":
            self = .node(try OverpassNode(from: decoder))
        case "way":
            self = .way(try OverpassWay(from: decoder))
        default:
            self = .node(OverpassNode(id: 0, lat: 0, lon: 0))
        }
    }

    enum CodingKeys: String, CodingKey {
        case type
    }
}

struct OverpassNode: Decodable {
    let id: Int64
    let lat: Double
    let lon: Double
}

struct OverpassWay: Decodable {
    let id: Int64
    let nodes: [Int64]
    let tags: [String: String]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        nodes = try container.decodeIfPresent([Int64].self, forKey: .nodes) ?? []
        tags = try container.decodeIfPresent([String: String].self, forKey: .tags) ?? [:]
    }

    enum CodingKeys: String, CodingKey {
        case id, nodes, tags
    }
}
