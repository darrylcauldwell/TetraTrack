//
//  DownloadedRegion.swift
//  TrackRide
//

import Foundation
import SwiftData
import CoreLocation

/// Metadata for a downloaded OSM region
@Model
final class DownloadedRegion {
    // All properties have defaults for CloudKit compatibility
    var regionId: String = ""           // e.g., "england-south-east"
    var displayName: String = ""        // e.g., "South East England"
    var downloadDate: Date = Date()
    var nodeCount: Int = 0
    var edgeCount: Int = 0
    var fileSizeBytes: Int64 = 0        // Size of processed graph data

    // Bounding box
    var minLat: Double = 0
    var maxLat: Double = 0
    var minLon: Double = 0
    var maxLon: Double = 0

    // Download/processing state
    var isComplete: Bool = false
    var lastError: String?

    init() {}

    convenience init(regionId: String, displayName: String) {
        self.init()
        self.regionId = regionId
        self.displayName = displayName
    }

    // MARK: - Computed Properties

    /// Whether a coordinate is within this region's bounding box
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        coordinate.latitude >= minLat && coordinate.latitude <= maxLat &&
        coordinate.longitude >= minLon && coordinate.longitude <= maxLon
    }

    /// Center coordinate of the region
    var centerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
    }

    /// Formatted file size
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }

    /// Formatted download date
    var formattedDownloadDate: String {
        downloadDate.formatted(date: .abbreviated, time: .shortened)
    }

    /// Formatted node count
    var formattedNodeCount: String {
        nodeCount.formatted(.number)
    }

    /// Age of the data in days
    var dataAgeDays: Int {
        Calendar.current.dateComponents([.day], from: downloadDate, to: Date()).day ?? 0
    }

    /// Whether the data is considered stale (older than 30 days)
    var isStale: Bool {
        dataAgeDays > 30
    }
}

// MARK: - Available Regions

/// Information about an available region for download
struct AvailableRegion: Identifiable, Codable {
    let id: String              // e.g., "england-south-east"
    let displayName: String     // e.g., "South East England"
    let downloadURL: URL
    let estimatedSizeBytes: Int64
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double

    var formattedEstimatedSize: String {
        ByteCountFormatter.string(fromByteCount: estimatedSizeBytes, countStyle: .file)
    }

    var boundingBox: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        (minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
    }

    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        coordinate.latitude >= minLat && coordinate.latitude <= maxLat &&
        coordinate.longitude >= minLon && coordinate.longitude <= maxLon
    }
}

/// Predefined UK regions available for download from Geofabrik
extension AvailableRegion {
    static let ukRegions: [AvailableRegion] = [
        AvailableRegion(
            id: "england-south-east",
            displayName: "South East England",
            downloadURL: URL(string: "https://download.geofabrik.de/europe/great-britain/england/south-east-latest.osm.pbf")!,
            estimatedSizeBytes: 280_000_000,
            minLat: 50.5, maxLat: 52.0, minLon: -2.0, maxLon: 1.5
        ),
        AvailableRegion(
            id: "england-south-west",
            displayName: "South West England",
            downloadURL: URL(string: "https://download.geofabrik.de/europe/great-britain/england/south-west-latest.osm.pbf")!,
            estimatedSizeBytes: 180_000_000,
            minLat: 49.9, maxLat: 51.7, minLon: -6.5, maxLon: -1.5
        ),
        AvailableRegion(
            id: "england-east",
            displayName: "East of England",
            downloadURL: URL(string: "https://download.geofabrik.de/europe/great-britain/england/east-latest.osm.pbf")!,
            estimatedSizeBytes: 150_000_000,
            minLat: 51.3, maxLat: 53.1, minLon: -0.5, maxLon: 2.0
        ),
        AvailableRegion(
            id: "england-east-midlands",
            displayName: "East Midlands",
            downloadURL: URL(string: "https://download.geofabrik.de/europe/great-britain/england/east-midlands-latest.osm.pbf")!,
            estimatedSizeBytes: 120_000_000,
            minLat: 52.0, maxLat: 53.6, minLon: -2.0, maxLon: 0.5
        ),
        AvailableRegion(
            id: "england-west-midlands",
            displayName: "West Midlands",
            downloadURL: URL(string: "https://download.geofabrik.de/europe/great-britain/england/west-midlands-latest.osm.pbf")!,
            estimatedSizeBytes: 100_000_000,
            minLat: 51.8, maxLat: 53.2, minLon: -3.2, maxLon: -1.2
        ),
        AvailableRegion(
            id: "england-yorkshire-and-the-humber",
            displayName: "Yorkshire & Humber",
            downloadURL: URL(string: "https://download.geofabrik.de/europe/great-britain/england/yorkshire-and-the-humber-latest.osm.pbf")!,
            estimatedSizeBytes: 130_000_000,
            minLat: 53.2, maxLat: 54.6, minLon: -2.6, maxLon: 0.2
        ),
        AvailableRegion(
            id: "england-north-west",
            displayName: "North West England",
            downloadURL: URL(string: "https://download.geofabrik.de/europe/great-britain/england/north-west-latest.osm.pbf")!,
            estimatedSizeBytes: 140_000_000,
            minLat: 53.0, maxLat: 55.8, minLon: -3.6, maxLon: -1.8
        ),
        AvailableRegion(
            id: "england-north-east",
            displayName: "North East England",
            downloadURL: URL(string: "https://download.geofabrik.de/europe/great-britain/england/north-east-latest.osm.pbf")!,
            estimatedSizeBytes: 60_000_000,
            minLat: 54.4, maxLat: 55.8, minLon: -2.7, maxLon: -1.4
        ),
        AvailableRegion(
            id: "scotland",
            displayName: "Scotland",
            downloadURL: URL(string: "https://download.geofabrik.de/europe/great-britain/scotland-latest.osm.pbf")!,
            estimatedSizeBytes: 200_000_000,
            minLat: 54.6, maxLat: 60.9, minLon: -8.0, maxLon: -0.7
        ),
        AvailableRegion(
            id: "wales",
            displayName: "Wales",
            downloadURL: URL(string: "https://download.geofabrik.de/europe/great-britain/wales-latest.osm.pbf")!,
            estimatedSizeBytes: 80_000_000,
            minLat: 51.3, maxLat: 53.4, minLon: -5.4, maxLon: -2.6
        ),
        // Small region for testing
        AvailableRegion(
            id: "isle-of-wight",
            displayName: "Isle of Wight",
            downloadURL: URL(string: "https://download.geofabrik.de/europe/great-britain/england/isle-of-wight-latest.osm.pbf")!,
            estimatedSizeBytes: 8_000_000,
            minLat: 50.57, maxLat: 50.77, minLon: -1.6, maxLon: -1.05
        )
    ]

    /// Find region containing a coordinate
    static func region(containing coordinate: CLLocationCoordinate2D) -> AvailableRegion? {
        ukRegions.first { $0.contains(coordinate) }
    }
}
