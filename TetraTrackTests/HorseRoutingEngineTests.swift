//
//  HorseRoutingEngineTests.swift
//  TetraTrackTests
//
//  Tests for HorseRoutingEngine and related routing components
//

import Testing
import Foundation
import CoreLocation
@testable import TetraTrack

// MARK: - RoutingPreferences Tests

struct RoutingPreferencesTests {

    @Test func defaultPreferences() {
        let prefs = RoutingPreferences()

        #expect(prefs.preferBridleways == true)
        #expect(prefs.avoidRoads == true)
        #expect(prefs.preferGrassSurface == false)
    }

    @Test func customPreferences() {
        let prefs = RoutingPreferences(
            preferBridleways: false,
            avoidRoads: false,
            preferGrassSurface: true
        )

        #expect(prefs.preferBridleways == false)
        #expect(prefs.avoidRoads == false)
        #expect(prefs.preferGrassSurface == true)
    }

    @Test func adjustedCostForBridleway() {
        let prefs = RoutingPreferences(preferBridleways: true)
        let edge = OSMEdge(
            toNodeId: 1,
            distance: 100,
            wayType: .bridleway,
            surface: .grass
        )

        let adjustedCost = prefs.adjustedCost(for: edge)

        // Should be reduced by 30% (0.7 multiplier)
        #expect(adjustedCost < edge.cost)
        #expect(adjustedCost == edge.cost * 0.7)
    }

    @Test func adjustedCostForBridlewayWhenNotPreferred() {
        let prefs = RoutingPreferences(preferBridleways: false)
        let edge = OSMEdge(
            toNodeId: 1,
            distance: 100,
            wayType: .bridleway,
            surface: .grass
        )

        let adjustedCost = prefs.adjustedCost(for: edge)

        // Should be unchanged
        #expect(adjustedCost == edge.cost)
    }

    @Test func adjustedCostPenalizesRoads() {
        let prefs = RoutingPreferences(avoidRoads: true)

        let tertiaryEdge = OSMEdge(toNodeId: 1, distance: 100, wayType: .tertiary, surface: .asphalt)
        let secondaryEdge = OSMEdge(toNodeId: 2, distance: 100, wayType: .secondary, surface: .asphalt)
        let primaryEdge = OSMEdge(toNodeId: 3, distance: 100, wayType: .primary, surface: .asphalt)
        let residentialEdge = OSMEdge(toNodeId: 4, distance: 100, wayType: .residential, surface: .asphalt)

        #expect(prefs.adjustedCost(for: tertiaryEdge) == tertiaryEdge.cost * 2.0)
        #expect(prefs.adjustedCost(for: secondaryEdge) == secondaryEdge.cost * 2.0)
        #expect(prefs.adjustedCost(for: primaryEdge) == primaryEdge.cost * 2.0)
        #expect(prefs.adjustedCost(for: residentialEdge) == residentialEdge.cost * 1.5)
    }

    @Test func adjustedCostDoesNotPenalizeRoadsWhenNotAvoiding() {
        let prefs = RoutingPreferences(avoidRoads: false)
        let edge = OSMEdge(toNodeId: 1, distance: 100, wayType: .tertiary, surface: .asphalt)

        let adjustedCost = prefs.adjustedCost(for: edge)

        #expect(adjustedCost == edge.cost)
    }

    @Test func adjustedCostPreferGrassSurface() {
        let prefs = RoutingPreferences(preferGrassSurface: true)
        let edge = OSMEdge(
            toNodeId: 1,
            distance: 100,
            wayType: .track,
            surface: .grass
        )

        let adjustedCost = prefs.adjustedCost(for: edge)

        // Should be reduced by 20% (0.8 multiplier)
        #expect(adjustedCost < edge.cost)
        #expect(adjustedCost == edge.cost * 0.8)
    }

    @Test func preferencesAreEquatable() {
        let prefs1 = RoutingPreferences(preferBridleways: true, avoidRoads: true)
        let prefs2 = RoutingPreferences(preferBridleways: true, avoidRoads: true)
        let prefs3 = RoutingPreferences(preferBridleways: false, avoidRoads: true)

        #expect(prefs1 == prefs2)
        #expect(prefs1 != prefs3)
    }
}

// MARK: - OSMWayType Tests

struct OSMWayTypeTests {

    @Test func allCasesExist() {
        #expect(OSMWayType.allCases.count == 14)
    }

    @Test func bridlewayProperties() {
        let wayType = OSMWayType.bridleway

        #expect(wayType.horseCostMultiplier == 0.5)
        #expect(wayType.isLegalForHorses == true)
        #expect(wayType.displayName == "Bridleway")
    }

    @Test func bywayProperties() {
        let wayType = OSMWayType.byway

        #expect(wayType.horseCostMultiplier == 0.6)
        #expect(wayType.isLegalForHorses == true)
        #expect(wayType.displayName == "Byway")
    }

    @Test func trackProperties() {
        let wayType = OSMWayType.track

        #expect(wayType.horseCostMultiplier == 0.7)
        #expect(wayType.isLegalForHorses == true)
        #expect(wayType.displayName == "Track")
    }

    @Test func footwayIsIllegal() {
        let wayType = OSMWayType.footway

        #expect(wayType.isLegalForHorses == false)
        #expect(wayType.horseCostMultiplier == .infinity)
    }

    @Test func motorwayIsIllegal() {
        let wayType = OSMWayType.motorway

        #expect(wayType.isLegalForHorses == false)
        #expect(wayType.horseCostMultiplier == .infinity)
    }

    @Test func trunkIsIllegal() {
        let wayType = OSMWayType.trunk

        #expect(wayType.isLegalForHorses == false)
        #expect(wayType.horseCostMultiplier == .infinity)
    }

    @Test func initFromOSMTag() {
        #expect(OSMWayType(osmTag: "bridleway") == .bridleway)
        #expect(OSMWayType(osmTag: "byway") == .byway)
        #expect(OSMWayType(osmTag: "track") == .track)
        #expect(OSMWayType(osmTag: "path") == .path)
        #expect(OSMWayType(osmTag: "unclassified") == .unclassified)
        #expect(OSMWayType(osmTag: "tertiary") == .tertiary)
        #expect(OSMWayType(osmTag: "tertiary_link") == .tertiary)
        #expect(OSMWayType(osmTag: "secondary") == .secondary)
        #expect(OSMWayType(osmTag: "secondary_link") == .secondary)
        #expect(OSMWayType(osmTag: "primary") == .primary)
        #expect(OSMWayType(osmTag: "primary_link") == .primary)
        #expect(OSMWayType(osmTag: "residential") == .residential)
        #expect(OSMWayType(osmTag: "living_street") == .residential)
        #expect(OSMWayType(osmTag: "footway") == .footway)
        #expect(OSMWayType(osmTag: "pedestrian") == .footway)
        #expect(OSMWayType(osmTag: "cycleway") == .cycleway)
        #expect(OSMWayType(osmTag: "motorway") == .motorway)
        #expect(OSMWayType(osmTag: "motorway_link") == .motorway)
        #expect(OSMWayType(osmTag: "unknown_tag") == .other)
    }

    @Test func roadsCostMoreThanBridleways() {
        #expect(OSMWayType.bridleway.horseCostMultiplier < OSMWayType.tertiary.horseCostMultiplier)
        #expect(OSMWayType.bridleway.horseCostMultiplier < OSMWayType.secondary.horseCostMultiplier)
        #expect(OSMWayType.bridleway.horseCostMultiplier < OSMWayType.primary.horseCostMultiplier)
    }
}

// MARK: - OSMSurfaceType Tests

struct OSMSurfaceTypeTests {

    @Test func allCasesExist() {
        #expect(OSMSurfaceType.allCases.count == 14)
    }

    @Test func grassIsPreferred() {
        let surface = OSMSurfaceType.grass

        #expect(surface.horseCostMultiplier == 0.8)
        #expect(surface.displayName == "Grass")
    }

    @Test func groundIsPreferred() {
        let surface = OSMSurfaceType.ground

        #expect(surface.horseCostMultiplier == 0.8)
        #expect(surface.displayName == "Earth")
    }

    @Test func asphaltIsPenalized() {
        let surface = OSMSurfaceType.asphalt

        #expect(surface.horseCostMultiplier == 1.3)
        #expect(surface.displayName == "Asphalt")
    }

    @Test func cobblestoneIsHeavilyPenalized() {
        let surface = OSMSurfaceType.cobblestone

        #expect(surface.horseCostMultiplier == 2.0)
        #expect(surface.displayName == "Cobblestone")
    }

    @Test func mudIsPenalized() {
        let surface = OSMSurfaceType.mud

        #expect(surface.horseCostMultiplier == 1.8)
        #expect(surface.displayName == "Mud")
    }

    @Test func unknownIsNeutral() {
        let surface = OSMSurfaceType.unknown

        #expect(surface.horseCostMultiplier == 1.0)
        #expect(surface.displayName == "Unknown")
    }

    @Test func initFromOSMTag() {
        #expect(OSMSurfaceType(osmTag: "grass") == .grass)
        #expect(OSMSurfaceType(osmTag: "ground") == .ground)
        #expect(OSMSurfaceType(osmTag: "earth") == .ground)
        #expect(OSMSurfaceType(osmTag: "dirt") == .dirt)
        #expect(OSMSurfaceType(osmTag: "gravel") == .gravel)
        #expect(OSMSurfaceType(osmTag: "fine_gravel") == .fineGravel)
        #expect(OSMSurfaceType(osmTag: "compacted") == .compacted)
        #expect(OSMSurfaceType(osmTag: "sand") == .sand)
        #expect(OSMSurfaceType(osmTag: "asphalt") == .asphalt)
        #expect(OSMSurfaceType(osmTag: "paved") == .paved)
        #expect(OSMSurfaceType(osmTag: "concrete") == .concrete)
        #expect(OSMSurfaceType(osmTag: "cobblestone") == .cobblestone)
        #expect(OSMSurfaceType(osmTag: "sett") == .cobblestone)
        #expect(OSMSurfaceType(osmTag: "paving_stones") == .cobblestone)
        #expect(OSMSurfaceType(osmTag: "mud") == .mud)
        #expect(OSMSurfaceType(osmTag: nil) == .unknown)
        #expect(OSMSurfaceType(osmTag: "some_unknown_surface") == .unknown)
    }

    @Test func naturalSurfacesCostLessThanPaved() {
        #expect(OSMSurfaceType.grass.horseCostMultiplier < OSMSurfaceType.asphalt.horseCostMultiplier)
        #expect(OSMSurfaceType.ground.horseCostMultiplier < OSMSurfaceType.concrete.horseCostMultiplier)
        #expect(OSMSurfaceType.dirt.horseCostMultiplier < OSMSurfaceType.paved.horseCostMultiplier)
    }
}

// MARK: - OSMEdge Tests

struct OSMEdgeTests {

    @Test func edgeInitialization() {
        let edge = OSMEdge(
            toNodeId: 12345,
            distance: 500,
            wayType: .bridleway,
            surface: .grass
        )

        #expect(edge.toNodeId == 12345)
        #expect(edge.distance == 500)
        #expect(edge.wayType == .bridleway)
        #expect(edge.surface == .grass)
        #expect(edge.bidirectional == true) // default
    }

    @Test func edgeWithOneWay() {
        let edge = OSMEdge(
            toNodeId: 1,
            distance: 100,
            wayType: .path,
            surface: .gravel,
            bidirectional: false
        )

        #expect(edge.bidirectional == false)
    }

    @Test func costCalculation() {
        let distance = 1000.0 // 1km
        let wayType = OSMWayType.bridleway
        let surface = OSMSurfaceType.grass

        let edge = OSMEdge(
            toNodeId: 1,
            distance: distance,
            wayType: wayType,
            surface: surface
        )

        let expectedCost = distance * wayType.horseCostMultiplier * surface.horseCostMultiplier
        #expect(edge.cost == expectedCost)
    }

    @Test func costIsInfiniteForIllegalWays() {
        let edge = OSMEdge(
            toNodeId: 1,
            distance: 100,
            wayType: .footway,
            surface: .asphalt
        )

        #expect(edge.cost == .infinity)
    }

    @Test func bridlewayWithGrassCheaperThanRoadWithAsphalt() {
        let bridlewayEdge = OSMEdge(
            toNodeId: 1,
            distance: 100,
            wayType: .bridleway,
            surface: .grass
        )

        let roadEdge = OSMEdge(
            toNodeId: 2,
            distance: 100,
            wayType: .tertiary,
            surface: .asphalt
        )

        #expect(bridlewayEdge.cost < roadEdge.cost)
    }

    @Test func staticCostCalculation() {
        let cost = OSMEdge.calculateCost(
            distance: 1000,
            wayType: .track,
            surface: .gravel
        )

        // 1000 * 0.7 (track) * 0.9 (gravel) = 630
        #expect(cost == 630)
    }

    @Test func staticCostForIllegalWay() {
        let cost = OSMEdge.calculateCost(
            distance: 100,
            wayType: .motorway,
            surface: .asphalt
        )

        #expect(cost == .infinity)
    }
}

// MARK: - RoutingError Tests

struct RoutingErrorTests {

    @Test func noNearbyNodesError() {
        let error = RoutingError.noNearbyNodes

        #expect(error.errorDescription?.contains("No bridleways found") == true)
    }

    @Test func noRouteFoundError() {
        let error = RoutingError.noRouteFound

        #expect(error.errorDescription?.contains("No horse-safe route") == true)
    }

    @Test func routingTimeoutError() {
        let error = RoutingError.routingTimeout

        #expect(error.errorDescription?.contains("too long") == true)
    }

    @Test func nodeNotFoundError() {
        let error = RoutingError.nodeNotFound

        #expect(error.errorDescription?.contains("Route data error") == true)
    }

    @Test func regionNotDownloadedError() {
        let error = RoutingError.regionNotDownloaded

        #expect(error.errorDescription?.contains("download map data") == true)
    }
}

// MARK: - OSMHorseAccess Tests

struct OSMHorseAccessTests {

    @Test func bridlewayIsDesignated() {
        let access = OSMHorseAccess(tags: [:], wayType: .bridleway)

        #expect(access == .designated)
    }

    @Test func bywayIsDesignated() {
        let access = OSMHorseAccess(tags: [:], wayType: .byway)

        #expect(access == .designated)
    }

    @Test func privateAccessIsNo() {
        let access = OSMHorseAccess(tags: ["access": "private"], wayType: .track)

        #expect(access == .no)
    }

    @Test func permissiveAccess() {
        let access = OSMHorseAccess(tags: ["access": "permissive"], wayType: .path)

        #expect(access == .permissive)
    }

    @Test func footwayIsNo() {
        let access = OSMHorseAccess(tags: [:], wayType: .footway)

        #expect(access == .no)
    }

    @Test func trackIsYes() {
        let access = OSMHorseAccess(tags: [:], wayType: .track)

        #expect(access == .yes)
    }
}

// MARK: - CalculatedRoute Tests

struct CalculatedRouteTests {

    @Test func routeSegmentInfoProperties() {
        let segment = CalculatedRoute.RouteSegmentInfo(
            startIndex: 0,
            endIndex: 5,
            wayType: .bridleway,
            surface: .grass,
            distance: 500
        )

        #expect(segment.startIndex == 0)
        #expect(segment.endIndex == 5)
        #expect(segment.wayType == .bridleway)
        #expect(segment.surface == .grass)
        #expect(segment.distance == 500)
    }

    @Test func calculatedRouteProperties() {
        let coords = [
            CLLocationCoordinate2D(latitude: 51.5, longitude: -1.5),
            CLLocationCoordinate2D(latitude: 51.51, longitude: -1.51)
        ]

        let segments = [
            CalculatedRoute.RouteSegmentInfo(
                startIndex: 0,
                endIndex: 1,
                wayType: .bridleway,
                surface: .grass,
                distance: 1000
            )
        ]

        let route = CalculatedRoute(
            coordinates: coords,
            totalDistance: 1000,
            estimatedDuration: 598.8, // 1000m at 1.67m/s
            segments: segments,
            wayTypeBreakdown: ["bridleway": 1000],
            surfaceBreakdown: ["grass": 1000]
        )

        #expect(route.coordinates.count == 2)
        #expect(route.totalDistance == 1000)
        #expect(route.segments.count == 1)
        #expect(route.wayTypeBreakdown["bridleway"] == 1000)
        #expect(route.surfaceBreakdown["grass"] == 1000)
    }
}
