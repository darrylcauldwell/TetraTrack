//
//  DownloadState.swift
//  TrackRide
//
//  Persistent state for resumable OSM downloads
//

import Foundation

/// Tracks the state of an in-progress OSM region download
/// Stored in UserDefaults to survive app termination
struct DownloadState: Codable, Sendable {
    let regionId: String
    let regionDisplayName: String
    let bounds: Bounds
    var phase: Phase
    var nodesProcessed: Int
    var edgesProcessed: Int
    var totalNodes: Int
    var totalEdges: Int
    var jsonFilePath: String?
    var startedAt: Date
    var lastUpdatedAt: Date

    struct Bounds: Codable, Sendable {
        let minLat: Double
        let maxLat: Double
        let minLon: Double
        let maxLon: Double
    }

    enum Phase: String, Codable, Sendable {
        case downloading        // Fetching from Overpass API
        case downloaded         // JSON saved to disk, ready to process
        case processingNodes    // Creating OSMNode records
        case processingEdges    // Creating edge connections
        case finalizing         // Creating DownloadedRegion record
        case complete           // Successfully finished
        case failed             // Failed with error
    }

    nonisolated var isResumable: Bool {
        switch phase {
        case .downloaded, .processingNodes, .processingEdges:
            return jsonFilePath != nil
        default:
            return false
        }
    }

    var progressDescription: String {
        switch phase {
        case .downloading:
            return "Downloading..."
        case .downloaded:
            return "Ready to process"
        case .processingNodes:
            return "Processing nodes (\(nodesProcessed)/\(totalNodes))"
        case .processingEdges:
            return "Processing edges (\(edgesProcessed)/\(totalEdges))"
        case .finalizing:
            return "Finalizing..."
        case .complete:
            return "Complete"
        case .failed:
            return "Failed"
        }
    }
}

// MARK: - Persistence

extension DownloadState {
    nonisolated(unsafe) private static let userDefaultsKey = "com.trackride.downloadStates"

    /// Get all persisted download states
    nonisolated static func loadAll() -> [String: DownloadState] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let states = try? JSONDecoder().decode([String: DownloadState].self, from: data) else {
            return [:]
        }
        return states
    }

    /// Save a download state
    nonisolated static func save(_ state: DownloadState) {
        var states = loadAll()
        states[state.regionId] = state
        if let data = try? JSONEncoder().encode(states) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    /// Remove a download state
    nonisolated static func remove(regionId: String) {
        var states = loadAll()
        states.removeValue(forKey: regionId)
        if let data = try? JSONEncoder().encode(states) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    /// Get incomplete downloads that can be resumed
    nonisolated static func getResumableDownloads() -> [DownloadState] {
        loadAll().values.filter { $0.isResumable }
    }

    /// Get failed or incomplete downloads that need cleanup
    nonisolated static func getIncompleteDownloads() -> [DownloadState] {
        loadAll().values.filter { state in
            switch state.phase {
            case .complete:
                return false
            default:
                return true
            }
        }
    }
}

// MARK: - JSON File Management

extension DownloadState {
    /// Directory for storing downloaded JSON files
    nonisolated static var jsonCacheDirectory: URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let osmDir = cacheDir.appendingPathComponent("OSMDownloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: osmDir, withIntermediateDirectories: true)
        return osmDir
    }

    /// Generate path for a region's JSON file
    nonisolated static func jsonFilePath(for regionId: String) -> URL {
        jsonCacheDirectory.appendingPathComponent("\(regionId).json")
    }

    /// Delete the JSON file for a region
    nonisolated static func deleteJsonFile(for regionId: String) {
        let path = jsonFilePath(for: regionId)
        try? FileManager.default.removeItem(at: path)
    }

    /// Check if JSON file exists for a region
    nonisolated static func jsonFileExists(for regionId: String) -> Bool {
        FileManager.default.fileExists(atPath: jsonFilePath(for: regionId).path)
    }
}
