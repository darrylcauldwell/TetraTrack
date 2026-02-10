//
//  OSMNode.swift
//  TetraTrack
//

import Foundation
import SwiftData
import CoreLocation

/// Way type from OpenStreetMap highway tag
enum OSMWayType: String, Codable, CaseIterable, Sendable {
    case bridleway
    case byway
    case track
    case path
    case unclassified
    case tertiary
    case secondary
    case primary
    case residential
    case footway      // Illegal for horses
    case cycleway
    case motorway     // Illegal for horses
    case trunk        // Illegal for horses
    case other

    /// Cost multiplier for horse routing (lower = preferred)
    nonisolated var horseCostMultiplier: Double {
        switch self {
        case .bridleway: return 0.5    // Strongly preferred
        case .byway: return 0.6
        case .track: return 0.7
        case .path: return 0.9
        case .unclassified: return 1.0
        case .residential: return 1.2
        case .tertiary: return 1.5
        case .secondary: return 2.5
        case .primary: return 4.0
        case .cycleway: return 1.3
        case .footway, .motorway, .trunk: return .infinity  // Illegal
        case .other: return 1.5
        }
    }

    /// Whether horses are legally allowed
    nonisolated var isLegalForHorses: Bool {
        switch self {
        case .footway, .motorway, .trunk: return false
        default: return true
        }
    }

    /// Display name for UI
    var displayName: String {
        switch self {
        case .bridleway: return "Bridleway"
        case .byway: return "Byway"
        case .track: return "Track"
        case .path: return "Path"
        case .unclassified: return "Unclassified Road"
        case .tertiary: return "Tertiary Road"
        case .secondary: return "Secondary Road"
        case .primary: return "Primary Road"
        case .residential: return "Residential"
        case .footway: return "Footway"
        case .cycleway: return "Cycleway"
        case .motorway: return "Motorway"
        case .trunk: return "Trunk Road"
        case .other: return "Other"
        }
    }

    /// Initialize from OSM highway tag value
    nonisolated init(osmTag: String) {
        switch osmTag {
        case "bridleway": self = .bridleway
        case "byway": self = .byway
        case "track": self = .track
        case "path": self = .path
        case "unclassified": self = .unclassified
        case "tertiary", "tertiary_link": self = .tertiary
        case "secondary", "secondary_link": self = .secondary
        case "primary", "primary_link": self = .primary
        case "residential", "living_street": self = .residential
        case "footway", "pedestrian": self = .footway
        case "cycleway": self = .cycleway
        case "motorway", "motorway_link": self = .motorway
        case "trunk", "trunk_link": self = .trunk
        default: self = .other
        }
    }
}

/// Surface type from OpenStreetMap surface tag
enum OSMSurfaceType: String, Codable, CaseIterable, Sendable {
    case grass
    case ground
    case earth
    case dirt
    case gravel
    case fineGravel = "fine_gravel"
    case compacted
    case sand
    case asphalt
    case paved
    case concrete
    case cobblestone
    case sett
    case mud
    case unknown

    /// Cost multiplier for horse routing (lower = preferred)
    nonisolated var horseCostMultiplier: Double {
        switch self {
        case .grass, .ground, .earth: return 0.8
        case .dirt: return 0.85
        case .gravel, .fineGravel, .compacted: return 0.9
        case .sand: return 1.0
        case .asphalt, .paved: return 1.3
        case .concrete: return 1.4
        case .cobblestone, .sett: return 2.0  // Hard on hooves
        case .mud: return 1.8  // Slippery/difficult
        case .unknown: return 1.0
        }
    }

    /// Display name for UI
    var displayName: String {
        switch self {
        case .grass: return "Grass"
        case .ground, .earth: return "Earth"
        case .dirt: return "Dirt"
        case .gravel: return "Gravel"
        case .fineGravel: return "Fine Gravel"
        case .compacted: return "Compacted"
        case .sand: return "Sand"
        case .asphalt: return "Asphalt"
        case .paved: return "Paved"
        case .concrete: return "Concrete"
        case .cobblestone, .sett: return "Cobblestone"
        case .mud: return "Mud"
        case .unknown: return "Unknown"
        }
    }

    /// Initialize from OSM surface tag value
    nonisolated init(osmTag: String?) {
        guard let tag = osmTag else {
            self = .unknown
            return
        }

        switch tag {
        case "grass": self = .grass
        case "ground", "earth": self = .ground
        case "dirt": self = .dirt
        case "gravel": self = .gravel
        case "fine_gravel": self = .fineGravel
        case "compacted": self = .compacted
        case "sand": self = .sand
        case "asphalt": self = .asphalt
        case "paved": self = .paved
        case "concrete": self = .concrete
        case "cobblestone", "sett", "paving_stones": self = .cobblestone
        case "mud": self = .mud
        default: self = .unknown
        }
    }
}

/// Horse access type from OSM tags
enum OSMHorseAccess: String, Codable, Sendable {
    case yes
    case no
    case permissive
    case designated
    case unknown

    /// Initialize from OSM tags
    nonisolated init(tags: [String: String], wayType: OSMWayType) {
        // Explicit horse tag takes precedence
        if let horse = tags["horse"] {
            switch horse {
            case "yes", "designated": self = .designated
            case "no": self = .no
            case "permissive": self = .permissive
            default: break
            }
        }

        // Bridleways are designated for horses
        if wayType == .bridleway || wayType == .byway {
            self = .designated
            return
        }

        // Check general access
        if let access = tags["access"] {
            switch access {
            case "private", "no":
                self = .no
                return
            case "permissive":
                self = .permissive
                return
            default: break
            }
        }

        self = wayType.isLegalForHorses ? .yes : .no
    }
}

/// A single edge in the routing graph
struct OSMEdge: Codable, Sendable {
    var toNodeId: Int64
    var distance: Double          // meters
    var wayType: OSMWayType
    var surface: OSMSurfaceType
    var cost: Double              // Pre-computed routing cost
    var bidirectional: Bool

    nonisolated init(
        toNodeId: Int64,
        distance: Double,
        wayType: OSMWayType,
        surface: OSMSurfaceType,
        bidirectional: Bool = true
    ) {
        self.toNodeId = toNodeId
        self.distance = distance
        self.wayType = wayType
        self.surface = surface
        self.bidirectional = bidirectional
        self.cost = Self.calculateCost(distance: distance, wayType: wayType, surface: surface)
    }

    /// Calculate routing cost for this edge
    nonisolated static func calculateCost(
        distance: Double,
        wayType: OSMWayType,
        surface: OSMSurfaceType
    ) -> Double {
        // Illegal ways have infinite cost
        guard wayType.isLegalForHorses else { return .infinity }

        return distance * wayType.horseCostMultiplier * surface.horseCostMultiplier
    }
}

/// A node in the routing graph (from OSM data)
@Model
final class OSMNode {
    // Use compound index for efficient spatial queries
    #Index<OSMNode>([\.regionId], [\.latitude], [\.longitude])

    var osmId: Int64 = 0
    var latitude: Double = 0
    var longitude: Double = 0
    var regionId: String = ""  // Which downloaded region this belongs to

    // Edges stored as binary Data (much faster than JSON string)
    // Using PropertyListEncoder for speed - ~3x faster than JSON
    var edgesData: Data = Data()

    // Legacy JSON field for migration (will be removed in future)
    var edgesJSON: String?

    // Cached transient properties
    @Transient private var _cachedEdges: [OSMEdge]?

    // Shared encoders/decoders for performance (avoid repeated allocation)
    @Transient private static let encoder: PropertyListEncoder = {
        let e = PropertyListEncoder()
        e.outputFormat = .binary  // Binary is faster than XML
        return e
    }()
    @Transient private static let decoder = PropertyListDecoder()

    init() {}

    convenience init(osmId: Int64, latitude: Double, longitude: Double, regionId: String) {
        self.init()
        self.osmId = osmId
        self.latitude = latitude
        self.longitude = longitude
        self.regionId = regionId
    }

    // MARK: - Computed Properties

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Decoded edges from this node
    var edges: [OSMEdge] {
        get {
            if let cached = _cachedEdges { return cached }

            // Try binary format first (new format)
            if !edgesData.isEmpty {
                if let decoded = try? Self.decoder.decode([OSMEdge].self, from: edgesData) {
                    _cachedEdges = decoded
                    return decoded
                }
            }

            // Fall back to legacy JSON format for migration
            if let json = edgesJSON,
               let data = json.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([OSMEdge].self, from: data) {
                _cachedEdges = decoded
                // Migrate to binary format
                if let binaryData = try? Self.encoder.encode(decoded) {
                    edgesData = binaryData
                    edgesJSON = nil  // Clear legacy data
                }
                return decoded
            }

            return []
        }
        set {
            if let data = try? Self.encoder.encode(newValue) {
                edgesData = data
                edgesJSON = nil  // Clear legacy format
            }
            _cachedEdges = newValue
        }
    }

    /// Add an edge from this node
    /// WARNING: This is slow for repeated calls - use setEdges() for bulk operations
    func addEdge(_ edge: OSMEdge) {
        var currentEdges = edges
        currentEdges.append(edge)
        edges = currentEdges
    }

    /// Set all edges at once (much faster than repeated addEdge calls)
    func setEdges(_ newEdges: [OSMEdge]) {
        if let data = try? Self.encoder.encode(newEdges) {
            edgesData = data
            edgesJSON = nil
            _cachedEdges = newEdges
        }
    }
}
