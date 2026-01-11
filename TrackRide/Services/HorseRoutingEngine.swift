//
//  HorseRoutingEngine.swift
//  TrackRide
//

import Foundation
import SwiftData
import CoreLocation
import os

/// User preferences for route calculation
struct RoutingPreferences: Codable, Equatable, Sendable {
    nonisolated init(
        preferBridleways: Bool = true,
        avoidRoads: Bool = true,
        preferGrassSurface: Bool = false
    ) {
        self.preferBridleways = preferBridleways
        self.avoidRoads = avoidRoads
        self.preferGrassSurface = preferGrassSurface
    }
    var preferBridleways: Bool = true
    var avoidRoads: Bool = true
    var preferGrassSurface: Bool = false

    /// Multiplier adjustments based on preferences
    nonisolated func adjustedCost(for edge: OSMEdge) -> Double {
        var cost = edge.cost

        // Boost bridleways if preferred
        if preferBridleways && edge.wayType == .bridleway {
            cost *= 0.7
        }

        // Penalize roads if avoiding
        if avoidRoads {
            switch edge.wayType {
            case .tertiary, .secondary, .primary:
                cost *= 2.0
            case .residential:
                cost *= 1.5
            default:
                break
            }
        }

        // Boost grass surfaces if preferred
        if preferGrassSurface && edge.surface == .grass {
            cost *= 0.8
        }

        return cost
    }
}

/// Result of a route calculation
struct CalculatedRoute: Sendable {
    let coordinates: [CLLocationCoordinate2D]
    let totalDistance: Double  // meters
    let estimatedDuration: Double  // seconds at walk (~6 km/h)
    let segments: [RouteSegmentInfo]
    let wayTypeBreakdown: [String: Double]  // way type -> meters
    let surfaceBreakdown: [String: Double]  // surface -> meters

    struct RouteSegmentInfo: Sendable {
        let startIndex: Int
        let endIndex: Int
        let wayType: OSMWayType
        let surface: OSMSurfaceType
        let distance: Double
    }
}

/// Lightweight node data for background thread A* computation
/// This is Sendable and can be safely passed to background threads
private struct CachedNodeData: Sendable {
    let osmId: Int64
    let latitude: Double
    let longitude: Double
    let edges: [OSMEdge]

    nonisolated var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// On-device A* routing engine optimized for horse riding
/// Note: Uses @MainActor for ModelContext access, but performs heavy A* computation on background thread.
/// The node cache is built on main thread, then copied to Sendable structs for background processing.
@MainActor
final class HorseRoutingEngine {

    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.trackride", category: "HorseRoutingEngine")

    /// Maximum nodes to explore before giving up
    private let maxIterations = 100_000

    /// Search radius for finding nearest node (in degrees, ~500m)
    private let nearestNodeSearchRadius = 0.005

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Build a Sendable node cache for background A* computation
    /// This is called on main thread to access ModelContext, then the data is copied
    private func buildSendableNodeCache() throws -> [Int64: CachedNodeData] {
        let descriptor = FetchDescriptor<OSMNode>()
        let allNodes = try modelContext.fetch(descriptor)

        var cache: [Int64: CachedNodeData] = [:]
        cache.reserveCapacity(allNodes.count)

        for node in allNodes {
            cache[node.osmId] = CachedNodeData(
                osmId: node.osmId,
                latitude: node.latitude,
                longitude: node.longitude,
                edges: node.edges
            )
        }

        logger.info("Built sendable node cache with \(allNodes.count) nodes")
        return cache
    }

    // MARK: - Public API

    /// Calculate a route between waypoints
    func calculateRoute(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        via waypoints: [CLLocationCoordinate2D] = [],
        preferences: RoutingPreferences = RoutingPreferences()
    ) async throws -> CalculatedRoute {

        // Build sendable node cache on main thread (ModelContext access)
        let nodeCache = try buildSendableNodeCache()
        let maxIter = maxIterations
        let searchRadius = nearestNodeSearchRadius

        // Run heavy A* computation on background thread
        return try await Task.detached(priority: .userInitiated) {
            try await BackgroundRouter.performRouteCalculation(
                from: start,
                to: end,
                via: waypoints,
                preferences: preferences,
                nodeCache: nodeCache,
                maxIterations: maxIter,
                nearestNodeSearchRadius: searchRadius
            )
        }.value
    }

    /// Calculate a loop route from a starting point
    func calculateLoopRoute(
        from start: CLLocationCoordinate2D,
        targetDistance: Double,
        preferences: RoutingPreferences = RoutingPreferences()
    ) async throws -> CalculatedRoute {

        // Build sendable node cache on main thread
        let nodeCache = try buildSendableNodeCache()
        let maxIter = maxIterations
        let searchRadius = nearestNodeSearchRadius

        // Run on background thread
        return try await Task.detached(priority: .userInitiated) {
            // Generate candidate turnaround points at approximately half the target distance
            let turnaroundDistance = targetDistance / 2
            let candidates = BackgroundRouter.findReachablePoints(
                from: start,
                atDistance: turnaroundDistance,
                count: 8,
                nodeCache: nodeCache,
                nearestNodeSearchRadius: searchRadius
            )

            // Try each candidate and find best loop
            var bestRoute: CalculatedRoute?
            var bestDistanceError = Double.infinity

            for candidate in candidates {
                do {
                    let route = try await BackgroundRouter.performRouteCalculation(
                        from: start,
                        to: start,
                        via: [candidate],
                        preferences: preferences,
                        nodeCache: nodeCache,
                        maxIterations: maxIter,
                        nearestNodeSearchRadius: searchRadius
                    )

                    let error = abs(route.totalDistance - targetDistance)
                    if error < bestDistanceError {
                        bestDistanceError = error
                        bestRoute = route
                    }
                } catch {
                    // Try next candidate
                    continue
                }
            }

            guard let route = bestRoute else {
                throw RoutingError.noRouteFound
            }

            return route
        }.value
    }
}

// MARK: - Background Router (runs off main thread)

/// Static methods for A* routing that can run on any thread
/// Uses nonisolated to ensure this code runs on background thread, not main actor
private enum BackgroundRouter: Sendable {

    struct SegmentResult: Sendable {
        let coordinates: [CLLocationCoordinate2D]
        let distance: Double
        let segments: [CalculatedRoute.RouteSegmentInfo]
    }

    /// Perform the actual route calculation on background thread
    nonisolated static func performRouteCalculation(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        via waypoints: [CLLocationCoordinate2D],
        preferences: RoutingPreferences,
        nodeCache: [Int64: CachedNodeData],
        maxIterations: Int,
        nearestNodeSearchRadius: Double
    ) async throws -> CalculatedRoute {

        // Build full waypoint list
        let allPoints = [start] + waypoints + [end]

        // Route between consecutive waypoints
        var fullCoordinates: [CLLocationCoordinate2D] = []
        var totalDistance: Double = 0
        var allSegments: [CalculatedRoute.RouteSegmentInfo] = []
        var wayTypeDistances: [String: Double] = [:]
        var surfaceDistances: [String: Double] = [:]

        for i in 0..<(allPoints.count - 1) {
            let segmentResult = try routeSegment(
                from: allPoints[i],
                to: allPoints[i + 1],
                preferences: preferences,
                nodeCache: nodeCache,
                maxIterations: maxIterations,
                nearestNodeSearchRadius: nearestNodeSearchRadius
            )

            // Avoid duplicating junction coordinates
            let startIdx = fullCoordinates.isEmpty ? 0 : 1
            fullCoordinates.append(contentsOf: segmentResult.coordinates.dropFirst(startIdx))

            totalDistance += segmentResult.distance

            // Adjust segment indices for full path
            let indexOffset = fullCoordinates.count - segmentResult.coordinates.count
            for segment in segmentResult.segments {
                allSegments.append(CalculatedRoute.RouteSegmentInfo(
                    startIndex: segment.startIndex + indexOffset,
                    endIndex: segment.endIndex + indexOffset,
                    wayType: segment.wayType,
                    surface: segment.surface,
                    distance: segment.distance
                ))

                // Accumulate breakdowns
                wayTypeDistances[segment.wayType.rawValue, default: 0] += segment.distance
                surfaceDistances[segment.surface.rawValue, default: 0] += segment.distance
            }

            // Yield periodically to allow cancellation
            await Task.yield()
        }

        // Estimate duration at walking pace (~6 km/h = 1.67 m/s)
        let estimatedDuration = totalDistance / 1.67

        return CalculatedRoute(
            coordinates: fullCoordinates,
            totalDistance: totalDistance,
            estimatedDuration: estimatedDuration,
            segments: allSegments,
            wayTypeBreakdown: wayTypeDistances,
            surfaceBreakdown: surfaceDistances
        )
    }

    // MARK: - Core A* Implementation

    private nonisolated static func routeSegment(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        preferences: RoutingPreferences,
        nodeCache: [Int64: CachedNodeData],
        maxIterations: Int,
        nearestNodeSearchRadius: Double
    ) throws -> SegmentResult {

        // Find nearest graph nodes to start/end (using cache)
        let startNode = try findNearestNode(to: start, nodeCache: nodeCache, searchRadius: nearestNodeSearchRadius)
        let endNode = try findNearestNode(to: end, nodeCache: nodeCache, searchRadius: nearestNodeSearchRadius)

        // A* data structures
        var openSet = PriorityQueue<AStarNode>()
        var closedSet = Set<Int64>()
        var cameFrom: [Int64: (nodeId: Int64, edge: OSMEdge)] = [:]
        var gScore: [Int64: Double] = [:]

        // Initialize
        gScore[startNode.osmId] = 0
        let initialF = heuristic(from: startNode.coordinate, to: endNode.coordinate)
        openSet.insert(AStarNode(nodeId: startNode.osmId, fScore: initialF))

        var iterations = 0

        while let current = openSet.extractMin() {
            iterations += 1

            if iterations > maxIterations {
                throw RoutingError.routingTimeout
            }

            // Found the goal
            if current.nodeId == endNode.osmId {
                return reconstructPath(
                    cameFrom: cameFrom,
                    endNodeId: current.nodeId,
                    nodeCache: nodeCache
                )
            }

            closedSet.insert(current.nodeId)

            // Get current node and its edges (O(1) cache lookup)
            guard let currentNode = nodeCache[current.nodeId] else {
                continue
            }

            for edge in currentNode.edges {
                // Skip if already evaluated
                if closedSet.contains(edge.toNodeId) {
                    continue
                }

                // Skip illegal edges
                guard edge.cost < .infinity else {
                    continue
                }

                // Calculate adjusted cost based on preferences
                let edgeCost = preferences.adjustedCost(for: edge)
                let tentativeG = gScore[current.nodeId, default: .infinity] + edgeCost

                if tentativeG < gScore[edge.toNodeId, default: .infinity] {
                    // This path is better
                    cameFrom[edge.toNodeId] = (current.nodeId, edge)
                    gScore[edge.toNodeId] = tentativeG

                    if let toNode = nodeCache[edge.toNodeId] {
                        let h = heuristic(from: toNode.coordinate, to: endNode.coordinate)
                        let f = tentativeG + h
                        openSet.insert(AStarNode(nodeId: edge.toNodeId, fScore: f))
                    }
                }
            }
        }

        throw RoutingError.noRouteFound
    }

    /// Haversine heuristic - admissible for A*
    private nonisolated static func heuristic(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let distance = haversineDistance(from: from, to: to)
        // Multiply by minimum possible cost factor to ensure admissibility
        return distance * 0.5
    }

    // MARK: - Path Reconstruction

    private nonisolated static func reconstructPath(
        cameFrom: [Int64: (nodeId: Int64, edge: OSMEdge)],
        endNodeId: Int64,
        nodeCache: [Int64: CachedNodeData]
    ) -> SegmentResult {

        var coordinates: [CLLocationCoordinate2D] = []
        var segments: [CalculatedRoute.RouteSegmentInfo] = []
        var totalDistance: Double = 0

        var nodeId = endNodeId
        var pathEdges: [(coord: CLLocationCoordinate2D, edge: OSMEdge?)] = []

        // Walk back through the path
        while let (prevId, edge) = cameFrom[nodeId] {
            if let node = nodeCache[nodeId] {
                pathEdges.append((node.coordinate, edge))
                totalDistance += edge.distance
            }
            nodeId = prevId
        }

        // Add start node
        if let startNode = nodeCache[nodeId] {
            pathEdges.append((startNode.coordinate, nil))
        }

        // Reverse to get start-to-end order
        pathEdges.reverse()

        // Build coordinates and segments
        var currentWayType: OSMWayType?
        var currentSurface: OSMSurfaceType?
        var segmentStartIndex = 0
        var segmentDistance: Double = 0

        for (index, item) in pathEdges.enumerated() {
            coordinates.append(item.coord)

            if let edge = item.edge {
                // Check if we need to start a new segment
                if edge.wayType != currentWayType || edge.surface != currentSurface {
                    // Save previous segment if exists
                    if currentWayType != nil && index > 0 {
                        segments.append(CalculatedRoute.RouteSegmentInfo(
                            startIndex: segmentStartIndex,
                            endIndex: index - 1,
                            wayType: currentWayType!,
                            surface: currentSurface ?? .unknown,
                            distance: segmentDistance
                        ))
                    }

                    // Start new segment
                    currentWayType = edge.wayType
                    currentSurface = edge.surface
                    segmentStartIndex = index
                    segmentDistance = edge.distance
                } else {
                    segmentDistance += edge.distance
                }
            }
        }

        // Add final segment
        if let wayType = currentWayType {
            segments.append(CalculatedRoute.RouteSegmentInfo(
                startIndex: segmentStartIndex,
                endIndex: coordinates.count - 1,
                wayType: wayType,
                surface: currentSurface ?? .unknown,
                distance: segmentDistance
            ))
        }

        return SegmentResult(
            coordinates: coordinates,
            distance: totalDistance,
            segments: segments
        )
    }

    // MARK: - Node Lookup

    private nonisolated static func findNearestNode(
        to coordinate: CLLocationCoordinate2D,
        nodeCache: [Int64: CachedNodeData],
        searchRadius: Double
    ) throws -> CachedNodeData {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        let delta = searchRadius

        // Filter nodes within search radius
        let candidates = nodeCache.values.filter { node in
            node.latitude >= lat - delta &&
            node.latitude <= lat + delta &&
            node.longitude >= lon - delta &&
            node.longitude <= lon + delta
        }

        guard let nearest = candidates.min(by: {
            haversineDistance(from: $0.coordinate, to: coordinate) <
            haversineDistance(from: $1.coordinate, to: coordinate)
        }) else {
            throw RoutingError.noNearbyNodes
        }

        return nearest
    }

    /// Find reachable points at approximately a given distance (for loop routing)
    nonisolated static func findReachablePoints(
        from start: CLLocationCoordinate2D,
        atDistance targetDistance: Double,
        count: Int,
        nodeCache: [Int64: CachedNodeData],
        nearestNodeSearchRadius: Double
    ) -> [CLLocationCoordinate2D] {

        // Generate candidate points in 8 directions
        let bearings: [Double] = [0, 45, 90, 135, 180, 225, 270, 315]
        var candidates: [CLLocationCoordinate2D] = []

        for bearing in bearings {
            // Calculate approximate target coordinate
            let targetCoord = destinationPoint(
                from: start,
                distance: targetDistance,
                bearing: bearing
            )

            // Find nearest routable node to that point (using cache)
            if let node = try? findNearestNode(to: targetCoord, nodeCache: nodeCache, searchRadius: nearestNodeSearchRadius) {
                candidates.append(node.coordinate)
            }
        }

        return Array(candidates.prefix(count))
    }

    // MARK: - Utilities

    private nonisolated static func haversineDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let R = 6371000.0 // Earth radius in meters
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLat = (to.latitude - from.latitude) * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180

        let a = sin(dLat/2) * sin(dLat/2) +
                cos(lat1) * cos(lat2) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))

        return R * c
    }

    private nonisolated static func destinationPoint(
        from: CLLocationCoordinate2D,
        distance: Double,
        bearing: Double
    ) -> CLLocationCoordinate2D {
        let R = 6371000.0
        let d = distance / R
        let brng = bearing * .pi / 180

        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180

        let lat2 = asin(sin(lat1) * cos(d) + cos(lat1) * sin(d) * cos(brng))
        let lon2 = lon1 + atan2(sin(brng) * sin(d) * cos(lat1), cos(d) - sin(lat1) * sin(lat2))

        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
    }
}

// MARK: - Supporting Types (nonisolated for background thread use)

private struct AStarNode: Comparable, Sendable {
    let nodeId: Int64
    let fScore: Double

    nonisolated static func < (lhs: AStarNode, rhs: AStarNode) -> Bool {
        lhs.fScore < rhs.fScore
    }

    nonisolated static func == (lhs: AStarNode, rhs: AStarNode) -> Bool {
        lhs.nodeId == rhs.nodeId && lhs.fScore == rhs.fScore
    }
}

/// Min-heap priority queue for A*
private struct PriorityQueue<T: Comparable & Sendable>: Sendable {
    nonisolated(unsafe) private var heap: [T] = []

    nonisolated var isEmpty: Bool { heap.isEmpty }

    nonisolated mutating func insert(_ element: T) {
        heap.append(element)
        siftUp(heap.count - 1)
    }

    nonisolated mutating func extractMin() -> T? {
        guard !heap.isEmpty else { return nil }

        if heap.count == 1 {
            return heap.removeLast()
        }

        let min = heap[0]
        heap[0] = heap.removeLast()
        siftDown(0)
        return min
    }

    private nonisolated mutating func siftUp(_ index: Int) {
        var child = index
        var parent = (child - 1) / 2

        while child > 0 && heap[child] < heap[parent] {
            heap.swapAt(child, parent)
            child = parent
            parent = (child - 1) / 2
        }
    }

    private nonisolated mutating func siftDown(_ index: Int) {
        var parent = index

        while true {
            let left = 2 * parent + 1
            let right = 2 * parent + 2
            var smallest = parent

            if left < heap.count && heap[left] < heap[smallest] {
                smallest = left
            }
            if right < heap.count && heap[right] < heap[smallest] {
                smallest = right
            }

            if smallest == parent { return }

            heap.swapAt(parent, smallest)
            parent = smallest
        }
    }
}

// MARK: - Errors

enum RoutingError: LocalizedError {
    case noNearbyNodes
    case noRouteFound
    case routingTimeout
    case nodeNotFound
    case regionNotDownloaded

    var errorDescription: String? {
        switch self {
        case .noNearbyNodes:
            return "No bridleways found near this location. Try a different starting point."
        case .noRouteFound:
            return "No horse-safe route found between these points."
        case .routingTimeout:
            return "Route calculation took too long. Try shorter distances."
        case .nodeNotFound:
            return "Route data error. Please re-download the region."
        case .regionNotDownloaded:
            return "Please download map data for this area first."
        }
    }
}
