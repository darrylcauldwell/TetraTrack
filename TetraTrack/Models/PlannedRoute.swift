//
//  PlannedRoute.swift
//  TetraTrack
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class PlannedRoute {
    // All properties have defaults for CloudKit compatibility
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()

    // Route geometry stored as JSON array of [lat, lon] pairs
    var coordinatesJSON: String = ""

    // Stats
    var totalDistance: Double = 0  // meters
    var estimatedDurationWalk: Double = 0  // seconds at walk (~6 km/h)
    var elevationGain: Double = 0
    var elevationLoss: Double = 0

    // Surface breakdown: {"grass": 1200.5, "gravel": 800.0, ...}
    var surfaceBreakdownJSON: String = "{}"

    // Way type breakdown: {"bridleway": 1500.0, "track": 500.0, ...}
    var wayTypeBreakdownJSON: String = "{}"

    // Loop route settings (if applicable)
    var isLoopRoute: Bool = false
    var targetLoopDistance: Double = 0  // meters, 0 if point-to-point

    // Relationships - MUST be optional for CloudKit
    @Relationship(deleteRule: .cascade, inverse: \RouteWaypoint.route)
    var waypoints: [RouteWaypoint]? = []

    // Track which rides used this route
    var linkedRideIdsJSON: String = "[]"

    // Cached transient properties
    @Transient private var _cachedCoordinates: [CLLocationCoordinate2D]?
    @Transient private var _cachedSurfaceBreakdown: [String: Double]?
    @Transient private var _cachedWayTypeBreakdown: [String: Double]?
    @Transient private var _cachedLinkedRideIds: [UUID]?

    init() {}

    // MARK: - Computed Properties

    /// Decoded route coordinates
    var coordinates: [CLLocationCoordinate2D] {
        get {
            if let cached = _cachedCoordinates { return cached }
            guard let data = coordinatesJSON.data(using: .utf8),
                  let pairs = try? JSONDecoder().decode([[Double]].self, from: data) else {
                return []
            }
            let coords = pairs.compactMap { pair -> CLLocationCoordinate2D? in
                guard pair.count == 2 else { return nil }
                return CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
            }
            _cachedCoordinates = coords
            return coords
        }
        set {
            let pairs = newValue.map { [$0.latitude, $0.longitude] }
            coordinatesJSON = (try? String(data: JSONEncoder().encode(pairs), encoding: .utf8)) ?? "[]"
            _cachedCoordinates = newValue
        }
    }

    /// Decoded surface breakdown
    var surfaceBreakdown: [String: Double] {
        get {
            if let cached = _cachedSurfaceBreakdown { return cached }
            guard let data = surfaceBreakdownJSON.data(using: .utf8),
                  let breakdown = try? JSONDecoder().decode([String: Double].self, from: data) else {
                return [:]
            }
            _cachedSurfaceBreakdown = breakdown
            return breakdown
        }
        set {
            surfaceBreakdownJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "{}"
            _cachedSurfaceBreakdown = newValue
        }
    }

    /// Decoded way type breakdown
    var wayTypeBreakdown: [String: Double] {
        get {
            if let cached = _cachedWayTypeBreakdown { return cached }
            guard let data = wayTypeBreakdownJSON.data(using: .utf8),
                  let breakdown = try? JSONDecoder().decode([String: Double].self, from: data) else {
                return [:]
            }
            _cachedWayTypeBreakdown = breakdown
            return breakdown
        }
        set {
            wayTypeBreakdownJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "{}"
            _cachedWayTypeBreakdown = newValue
        }
    }

    /// Linked ride IDs
    var linkedRideIds: [UUID] {
        get {
            if let cached = _cachedLinkedRideIds { return cached }
            guard let data = linkedRideIdsJSON.data(using: .utf8),
                  let ids = try? JSONDecoder().decode([UUID].self, from: data) else {
                return []
            }
            _cachedLinkedRideIds = ids
            return ids
        }
        set {
            linkedRideIdsJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]"
            _cachedLinkedRideIds = newValue
        }
    }

    /// Sorted waypoints by order
    var sortedWaypoints: [RouteWaypoint] {
        (waypoints ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Formatted distance
    var formattedDistance: String {
        totalDistance.formattedDistance
    }

    /// Formatted duration at walk
    var formattedDuration: String {
        estimatedDurationWalk.formattedDuration
    }

    /// Formatted elevation gain
    var formattedElevationGain: String {
        elevationGain.formattedElevation
    }

    /// Primary way type (most distance)
    var primaryWayType: String? {
        wayTypeBreakdown.max(by: { $0.value < $1.value })?.key
    }

    /// Primary surface type (most distance)
    var primarySurface: String? {
        surfaceBreakdown.max(by: { $0.value < $1.value })?.key
    }

    /// Percentage of route on bridleways
    var bridlewayPercentage: Double {
        guard totalDistance > 0 else { return 0 }
        let bridlewayDistance = wayTypeBreakdown["bridleway"] ?? 0
        return (bridlewayDistance / totalDistance) * 100
    }

    /// Bounding box for the route
    var boundingBox: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? {
        let coords = coordinates
        guard !coords.isEmpty else { return nil }

        let lats = coords.map { $0.latitude }
        let lons = coords.map { $0.longitude }

        return (
            minLat: lats.min() ?? 0,
            maxLat: lats.max() ?? 0,
            minLon: lons.min() ?? 0,
            maxLon: lons.max() ?? 0
        )
    }

    /// Default name for a new route
    static func defaultName(for date: Date) -> String {
        "Route - \(Formatters.fullDayMonth(date))"
    }

    // MARK: - Link Management

    /// Link a ride to this route
    func linkRide(_ rideId: UUID) {
        var ids = linkedRideIds
        if !ids.contains(rideId) {
            ids.append(rideId)
            linkedRideIds = ids
        }
    }

    /// Unlink a ride from this route
    func unlinkRide(_ rideId: UUID) {
        var ids = linkedRideIds
        ids.removeAll { $0 == rideId }
        linkedRideIds = ids
    }
}
