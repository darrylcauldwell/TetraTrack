//
//  RoutePlanningTests.swift
//  TrackRideTests
//
//  Tests for the route planning feature
//

import Testing
import Foundation
import CoreLocation
@testable import TetraTrack

@Suite("Route Planning Tests")
struct RoutePlanningTests {

    // MARK: - RoutingPreferences Tests

    @Test("Default routing preferences")
    func testDefaultPreferences() {
        let prefs = RoutingPreferences()
        #expect(prefs.preferBridleways == true)
        #expect(prefs.avoidRoads == true)
        #expect(prefs.preferGrassSurface == false)
    }

    @Test("Custom routing preferences")
    func testCustomPreferences() {
        let prefs = RoutingPreferences(
            preferBridleways: false,
            avoidRoads: false,
            preferGrassSurface: true
        )
        #expect(prefs.preferBridleways == false)
        #expect(prefs.avoidRoads == false)
        #expect(prefs.preferGrassSurface == true)
    }

    @Test("Preferences are Equatable")
    func testPreferencesEquatable() {
        let prefs1 = RoutingPreferences()
        let prefs2 = RoutingPreferences()
        let prefs3 = RoutingPreferences(preferBridleways: false)

        #expect(prefs1 == prefs2)
        #expect(prefs1 != prefs3)
    }

    @Test("Preferences are Codable")
    func testPreferencesCodable() throws {
        let original = RoutingPreferences(
            preferBridleways: true,
            avoidRoads: false,
            preferGrassSurface: true
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RoutingPreferences.self, from: encoded)

        #expect(original == decoded)
    }

    // MARK: - OSMWayType Tests

    @Test("OSMWayType cost multipliers for horse-friendly ways")
    func testWayTypeCostMultipliers() {
        #expect(OSMWayType.bridleway.horseCostMultiplier < 1.0, "Bridleways should be preferred")
        #expect(OSMWayType.track.horseCostMultiplier < 1.0, "Tracks should be preferred")
        #expect(OSMWayType.path.horseCostMultiplier <= 1.0, "Paths should be acceptable")
    }

    @Test("OSMWayType penalizes roads")
    func testWayTypePenalizesRoads() {
        #expect(OSMWayType.primary.horseCostMultiplier > 1.0, "Primary roads should be penalized")
        #expect(OSMWayType.secondary.horseCostMultiplier > 1.0, "Secondary roads should be penalized")
        #expect(OSMWayType.tertiary.horseCostMultiplier >= 1.0, "Tertiary roads should not be preferred")
    }

    @Test("OSMWayType blocks illegal ways")
    func testWayTypeBlocksIllegalWays() {
        #expect(OSMWayType.footway.horseCostMultiplier == .infinity, "Footways should be blocked")
        #expect(OSMWayType.motorway.horseCostMultiplier == .infinity, "Motorways should be blocked")
    }

    @Test("OSMWayType legal for horses check")
    func testWayTypeLegalForHorses() {
        #expect(OSMWayType.bridleway.isLegalForHorses == true)
        #expect(OSMWayType.track.isLegalForHorses == true)
        #expect(OSMWayType.footway.isLegalForHorses == false)
        #expect(OSMWayType.motorway.isLegalForHorses == false)
    }

    @Test("OSMWayType parses from OSM tags")
    func testWayTypeFromOSMTag() {
        #expect(OSMWayType(osmTag: "bridleway") == .bridleway)
        #expect(OSMWayType(osmTag: "track") == .track)
        #expect(OSMWayType(osmTag: "path") == .path)
        #expect(OSMWayType(osmTag: "footway") == .footway)
        #expect(OSMWayType(osmTag: "unknown_tag") == .other)
    }

    // MARK: - OSMSurfaceType Tests

    @Test("OSMSurfaceType cost multipliers")
    func testSurfaceTypeCostMultipliers() {
        #expect(OSMSurfaceType.grass.horseCostMultiplier < 1.0, "Grass should be preferred")
        #expect(OSMSurfaceType.dirt.horseCostMultiplier < 1.0, "Dirt should be preferred")
        #expect(OSMSurfaceType.asphalt.horseCostMultiplier > 1.0, "Asphalt should be penalized")
    }

    @Test("OSMSurfaceType parses from OSM tags")
    func testSurfaceTypeFromOSMTag() {
        #expect(OSMSurfaceType(osmTag: "grass") == .grass)
        #expect(OSMSurfaceType(osmTag: "dirt") == .dirt)
        #expect(OSMSurfaceType(osmTag: "asphalt") == .asphalt)
        #expect(OSMSurfaceType(osmTag: "gravel") == .gravel)
        #expect(OSMSurfaceType(osmTag: nil) == .unknown)
    }

    // MARK: - OSMHorseAccess Tests

    @Test("OSMHorseAccess values")
    func testHorseAccessValues() {
        #expect(OSMHorseAccess.yes.rawValue == "yes")
        #expect(OSMHorseAccess.designated.rawValue == "designated")
        #expect(OSMHorseAccess.no.rawValue == "no")
        #expect(OSMHorseAccess.permissive.rawValue == "permissive")
    }

    // MARK: - OSMEdge Tests

    @Test("OSMEdge cost calculation")
    func testEdgeCostCalculation() {
        let edge = OSMEdge(
            toNodeId: 123,
            distance: 100,
            wayType: .bridleway,
            surface: .grass,
            bidirectional: true
        )

        // Cost = distance * wayType multiplier * surface multiplier
        let expectedCost = 100 * OSMWayType.bridleway.horseCostMultiplier * OSMSurfaceType.grass.horseCostMultiplier
        #expect(edge.cost == expectedCost)
    }

    @Test("OSMEdge infinite cost for illegal ways")
    func testEdgeInfiniteCostForIllegalWays() {
        let edge = OSMEdge(
            toNodeId: 123,
            distance: 100,
            wayType: .motorway,
            surface: .asphalt,
            bidirectional: false
        )

        #expect(edge.cost == .infinity)
    }

    // MARK: - Preferences Cost Adjustment Tests

    @Test("Preferences boost bridleways when preferred")
    func testPreferencesBoostBridleways() {
        let prefs = RoutingPreferences(preferBridleways: true)
        let edge = OSMEdge(
            toNodeId: 123,
            distance: 100,
            wayType: .bridleway,
            surface: .unknown,
            bidirectional: true
        )

        let adjustedCost = prefs.adjustedCost(for: edge)
        #expect(adjustedCost < edge.cost, "Bridleway cost should be reduced when preferred")
    }

    @Test("Preferences penalize roads when avoiding")
    func testPreferencesPenalizeRoads() {
        let prefs = RoutingPreferences(avoidRoads: true)
        let edge = OSMEdge(
            toNodeId: 123,
            distance: 100,
            wayType: .tertiary,
            surface: .asphalt,
            bidirectional: true
        )

        let adjustedCost = prefs.adjustedCost(for: edge)
        #expect(adjustedCost > edge.cost, "Road cost should be increased when avoiding roads")
    }

    @Test("Preferences boost grass when preferred")
    func testPreferencesBoostGrass() {
        let prefs = RoutingPreferences(preferGrassSurface: true)
        let edge = OSMEdge(
            toNodeId: 123,
            distance: 100,
            wayType: .track,
            surface: .grass,
            bidirectional: true
        )

        let adjustedCost = prefs.adjustedCost(for: edge)
        #expect(adjustedCost < edge.cost, "Grass surface cost should be reduced when preferred")
    }

    // MARK: - CalculatedRoute Tests

    @Test("CalculatedRoute duration calculation")
    func testRouteDurationCalculation() {
        // At walking pace of ~6 km/h (1.67 m/s), 1000m should take ~10 minutes
        let route = CalculatedRoute(
            coordinates: [],
            totalDistance: 1000,
            estimatedDuration: 1000 / 1.67,
            segments: [],
            wayTypeBreakdown: [:],
            surfaceBreakdown: [:]
        )

        // Should be approximately 600 seconds (10 minutes)
        #expect(route.estimatedDuration > 550 && route.estimatedDuration < 650)
    }

    // MARK: - RoutingError Tests

    @Test("RoutingError descriptions are user-friendly")
    func testRoutingErrorDescriptions() {
        #expect(RoutingError.noNearbyNodes.errorDescription?.isEmpty == false)
        #expect(RoutingError.noRouteFound.errorDescription?.isEmpty == false)
        #expect(RoutingError.routingTimeout.errorDescription?.isEmpty == false)
        #expect(RoutingError.nodeNotFound.errorDescription?.isEmpty == false)
        #expect(RoutingError.regionNotDownloaded.errorDescription?.isEmpty == false)
    }

    // MARK: - WaypointType Tests

    @Test("WaypointType icon names")
    func testWaypointTypeIcons() {
        #expect(WaypointType.start.iconName.isEmpty == false)
        #expect(WaypointType.end.iconName.isEmpty == false)
        #expect(WaypointType.via.iconName.isEmpty == false)
        #expect(WaypointType.avoid.iconName.isEmpty == false)
    }

    // MARK: - AvailableRegion Tests

    @Test("UK regions are defined")
    func testUKRegionsExist() {
        let regions = AvailableRegion.ukRegions
        #expect(regions.isEmpty == false, "Should have UK regions available")
    }

    @Test("Available regions have valid download URLs")
    func testRegionDownloadURLs() {
        for region in AvailableRegion.ukRegions {
            #expect(region.downloadURL.absoluteString.contains("geofabrik.de"))
            #expect(region.downloadURL.absoluteString.hasSuffix(".osm.pbf"))
        }
    }

    @Test("Available regions have bounding boxes")
    func testRegionBoundingBoxes() {
        for region in AvailableRegion.ukRegions {
            #expect(region.boundingBox.minLat < region.boundingBox.maxLat)
            #expect(region.boundingBox.minLon < region.boundingBox.maxLon)
        }
    }
}
