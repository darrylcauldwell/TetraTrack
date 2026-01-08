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
struct CalculatedRoute {
    let coordinates: [CLLocationCoordinate2D]
    let totalDistance: Double  // meters
    let estimatedDuration: Double  // seconds at walk (~6 km/h)
    let segments: [RouteSegmentInfo]
    let wayTypeBreakdown: [String: Double]  // way type -> meters
    let surfaceBreakdown: [String: Double]  // surface -> meters

    struct RouteSegmentInfo {
        let startIndex: Int
        let endIndex: Int
        let wayType: OSMWayType
        let surface: OSMSurfaceType
        let distance: Double
    }
}

/// On-device A* routing engine optimized for horse riding
actor HorseRoutingEngine {

    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.trackride", category: "HorseRoutingEngine")

    /// Maximum nodes to explore before giving up
    private let maxIterations = 100_000

    /// Search radius for finding nearest node (in degrees, ~500m)
    private let nearestNodeSearchRadius = 0.005

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public API

    /// Calculate a route between waypoints
    func calculateRoute(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        via waypoints: [CLLocationCoordinate2D] = [],
        preferences: RoutingPreferences = RoutingPreferences()
    ) async throws -> CalculatedRoute {

        // Build full waypoint list
        var allPoints = [start] + waypoints + [end]

        // Route between consecutive waypoints
        var fullCoordinates: [CLLocationCoordinate2D] = []
        var totalDistance: Double = 0
        var allSegments: [CalculatedRoute.RouteSegmentInfo] = []
        var wayTypeDistances: [String: Double] = [:]
        var surfaceDistances: [String: Double] = [:]

        for i in 0..<(allPoints.count - 1) {
            let segmentResult = try await routeSegment(
                from: allPoints[i],
                to: allPoints[i + 1],
                preferences: preferences
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

    /// Calculate a loop route from a starting point
    func calculateLoopRoute(
        from start: CLLocationCoordinate2D,
        targetDistance: Double,
        preferences: RoutingPreferences = RoutingPreferences()
    ) async throws -> CalculatedRoute {

        // Generate candidate turnaround points at approximately half the target distance
        let turnaroundDistance = targetDistance / 2
        let candidates = try await findReachablePoints(
            from: start,
            atDistance: turnaroundDistance,
            count: 8
        )

        // Try each candidate and find best loop
        var bestRoute: CalculatedRoute?
        var bestDistanceError = Double.infinity

        for candidate in candidates {
            do {
                let route = try await calculateRoute(
                    from: start,
                    to: start,
                    via: [candidate],
                    preferences: preferences
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
    }

    // MARK: - Core A* Implementation

    private struct SegmentResult {
        let coordinates: [CLLocationCoordinate2D]
        let distance: Double
        let segments: [CalculatedRoute.RouteSegmentInfo]
    }

    private func routeSegment(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        preferences: RoutingPreferences
    ) async throws -> SegmentResult {

        // Find nearest graph nodes to start/end
        let startNode = try await findNearestNode(to: start)
        let endNode = try await findNearestNode(to: end)

        logger.debug("Routing from node \(startNode.osmId) to \(endNode.osmId)")

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
                logger.warning("Route calculation timed out after \(iterations) iterations")
                throw RoutingError.routingTimeout
            }

            // Found the goal
            if current.nodeId == endNode.osmId {
                logger.debug("Route found after \(iterations) iterations")
                return try await reconstructPath(
                    cameFrom: cameFrom,
                    endNodeId: current.nodeId,
                    startCoord: start,
                    endCoord: end
                )
            }

            closedSet.insert(current.nodeId)

            // Get current node and its edges
            guard let currentNode = try await getNode(by: current.nodeId) else {
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

                    if let toCoord = try? await getNodeCoordinate(edge.toNodeId) {
                        let h = heuristic(from: toCoord, to: endNode.coordinate)
                        let f = tentativeG + h
                        openSet.insert(AStarNode(nodeId: edge.toNodeId, fScore: f))
                    }
                }
            }
        }

        logger.warning("No route found after \(iterations) iterations")
        throw RoutingError.noRouteFound
    }

    /// Haversine heuristic - admissible for A*
    private func heuristic(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let distance = haversineDistance(from: from, to: to)
        // Multiply by minimum possible cost factor to ensure admissibility
        return distance * 0.5
    }

    // MARK: - Path Reconstruction

    private func reconstructPath(
        cameFrom: [Int64: (nodeId: Int64, edge: OSMEdge)],
        endNodeId: Int64,
        startCoord: CLLocationCoordinate2D,
        endCoord: CLLocationCoordinate2D
    ) async throws -> SegmentResult {

        var coordinates: [CLLocationCoordinate2D] = []
        var segments: [CalculatedRoute.RouteSegmentInfo] = []
        var totalDistance: Double = 0

        var nodeId = endNodeId
        var pathEdges: [(coord: CLLocationCoordinate2D, edge: OSMEdge?)] = []

        // Walk back through the path
        while let (prevId, edge) = cameFrom[nodeId] {
            if let coord = try? await getNodeCoordinate(nodeId) {
                pathEdges.append((coord, edge))
                totalDistance += edge.distance
            }
            nodeId = prevId
        }

        // Add start node
        if let startNodeCoord = try? await getNodeCoordinate(nodeId) {
            pathEdges.append((startNodeCoord, nil))
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

    // MARK: - Database Queries

    private func findNearestNode(to coordinate: CLLocationCoordinate2D) async throws -> OSMNode {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        let delta = nearestNodeSearchRadius

        let descriptor = FetchDescriptor<OSMNode>(
            predicate: #Predicate { node in
                node.latitude >= lat - delta &&
                node.latitude <= lat + delta &&
                node.longitude >= lon - delta &&
                node.longitude <= lon + delta
            }
        )

        let candidates = try modelContext.fetch(descriptor)

        guard let nearest = candidates.min(by: {
            haversineDistance(from: $0.coordinate, to: coordinate) <
            haversineDistance(from: $1.coordinate, to: coordinate)
        }) else {
            throw RoutingError.noNearbyNodes
        }

        return nearest
    }

    private func getNode(by osmId: Int64) async throws -> OSMNode? {
        let descriptor = FetchDescriptor<OSMNode>(
            predicate: #Predicate { $0.osmId == osmId }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func getNodeCoordinate(_ osmId: Int64) async throws -> CLLocationCoordinate2D {
        guard let node = try await getNode(by: osmId) else {
            throw RoutingError.nodeNotFound
        }
        return node.coordinate
    }

    /// Find reachable points at approximately a given distance (for loop routing)
    private func findReachablePoints(
        from start: CLLocationCoordinate2D,
        atDistance targetDistance: Double,
        count: Int
    ) async throws -> [CLLocationCoordinate2D] {

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

            // Find nearest routable node to that point
            if let node = try? await findNearestNode(to: targetCoord) {
                candidates.append(node.coordinate)
            }
        }

        return Array(candidates.prefix(count))
    }

    // MARK: - Utilities

    private func haversineDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
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

    private func destinationPoint(
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

// MARK: - Supporting Types

private struct AStarNode: Comparable, Sendable {
    nonisolated init(nodeId: Int64, fScore: Double) {
        self.nodeId = nodeId
        self.fScore = fScore
    }
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
    private var heap: [T] = []

    nonisolated init() {
        self.heap = []
    }

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
