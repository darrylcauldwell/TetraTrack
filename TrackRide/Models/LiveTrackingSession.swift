//
//  LiveTrackingSession.swift
//  TrackRide
//

import Foundation
import SwiftData
import CoreLocation
import os

/// A point on the route with gait information for colored polyline display
struct RoutePoint: Codable {
    var latitude: Double
    var longitude: Double
    var gait: String
    var timestamp: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var gaitType: GaitType {
        GaitType(rawValue: gait) ?? .stationary
    }
}

/// Represents an active ride session being shared with family members
/// This is stored in a CloudKit shared zone for real-time family tracking
@Model
final class LiveTrackingSession {
    var id: UUID = UUID()
    var riderName: String = ""
    var riderID: String = ""  // iCloud user record ID

    // Current status
    var isActive: Bool = false
    var startTime: Date?
    var lastUpdateTime: Date = Date()

    // Current location
    var currentLatitude: Double = 0.0
    var currentLongitude: Double = 0.0
    var currentAltitude: Double = 0.0
    var currentSpeed: Double = 0.0  // m/s
    var currentGait: String = GaitType.stationary.rawValue

    // Route history for gait-colored polyline
    var routePointsData: Data?  // JSON encoded RoutePoint array

    // Cumulative stats
    var totalDistance: Double = 0.0  // meters
    var elapsedDuration: TimeInterval = 0.0  // seconds

    // Safety
    var lastMovementTime: Date = Date()
    var isStationary: Bool = false
    var stationaryDuration: TimeInterval = 0.0  // How long stationary

    // Route points (transient, decoded from routePointsData)
    @Transient var routePoints: [RoutePoint] = []

    // Track if route points have changed since last encode (for efficient sync)
    @Transient private var routePointsDirty: Bool = false

    // Number of points last time we encoded (for incremental detection)
    @Transient private var lastEncodedCount: Int = 0

    // Flag indicating old route data was dropped due to buffer limit
    @Transient var hasDroppedRouteData: Bool = false

    // Timestamp of oldest dropped data (for UI notification)
    @Transient var oldestDroppedDataTime: Date?

    init() {}

    init(riderName: String, riderID: String) {
        self.riderName = riderName
        self.riderID = riderID
    }

    // MARK: - Computed Properties

    var currentCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: currentLatitude, longitude: currentLongitude)
    }

    var gait: GaitType {
        GaitType(rawValue: currentGait) ?? .stationary
    }

    var formattedSpeed: String {
        currentSpeed.formattedSpeed
    }

    var formattedDistance: String {
        totalDistance.formattedDistance
    }

    var formattedDuration: String {
        elapsedDuration.formattedDuration
    }

    var timeSinceLastUpdate: TimeInterval {
        Date().timeIntervalSince(lastUpdateTime)
    }

    var isStale: Bool {
        timeSinceLastUpdate > 60  // No update for 1 minute
    }

    // MARK: - Update Methods

    func updateLocation(
        latitude: Double,
        longitude: Double,
        altitude: Double,
        speed: Double,
        gait: GaitType,
        distance: Double,
        duration: TimeInterval
    ) {
        currentLatitude = latitude
        currentLongitude = longitude
        currentAltitude = altitude
        currentSpeed = speed
        currentGait = gait.rawValue
        totalDistance = distance
        elapsedDuration = duration
        lastUpdateTime = Date()

        // Add route point for gait-colored route display
        let point = RoutePoint(
            latitude: latitude,
            longitude: longitude,
            gait: gait.rawValue,
            timestamp: Date()
        )
        routePoints.append(point)

        // Keep last 500 points to avoid excessive data (throttled to ~10s updates = ~80min of data)
        let maxRoutePoints = 500
        if routePoints.count > maxRoutePoints {
            // Track that we're dropping data (for UI notification)
            if !hasDroppedRouteData {
                hasDroppedRouteData = true
                oldestDroppedDataTime = routePoints.first?.timestamp
            }
            routePoints.removeFirst(routePoints.count - maxRoutePoints)
        }

        // Mark as dirty - will encode on next sync or when batch threshold reached
        routePointsDirty = true

        // Batch encode: only encode every 20 points to reduce CPU usage
        // This reduces JSON encoding overhead from 500 operations to ~25
        let encodeBatchSize = 20
        if routePoints.count - lastEncodedCount >= encodeBatchSize || routePoints.count <= 1 {
            encodeRoutePointsIfNeeded()
        }

        // Track stationary status for safety alerts
        if speed < 0.5 {
            if !isStationary {
                isStationary = true
            }
            stationaryDuration = Date().timeIntervalSince(lastMovementTime)
        } else {
            isStationary = false
            stationaryDuration = 0
            lastMovementTime = Date()
        }
    }

    func startSession() {
        isActive = true
        startTime = Date()
        lastUpdateTime = Date()
        lastMovementTime = Date()
        totalDistance = 0
        elapsedDuration = 0
        isStationary = false
        stationaryDuration = 0
        routePoints = []
        routePointsData = nil
        routePointsDirty = false
        lastEncodedCount = 0
    }

    func endSession() {
        isActive = false
    }

    // MARK: - Route Points Encoding

    /// Encode route points only if they've changed since last encode
    func encodeRoutePointsIfNeeded() {
        guard routePointsDirty else { return }

        do {
            // Release old data before creating new to reduce peak memory usage
            let newData = try JSONEncoder().encode(routePoints)
            routePointsData = nil  // Explicitly release old data first
            routePointsData = newData
            lastEncodedCount = routePoints.count
            routePointsDirty = false
        } catch {
            Log.family.error("Failed to encode route points: \(error)")
        }
    }

    /// Force encode route points (call before CloudKit sync)
    func encodeRoutePoints() {
        routePointsDirty = true
        encodeRoutePointsIfNeeded()
    }

    func decodeRoutePoints() {
        guard let data = routePointsData else {
            routePoints = []
            return
        }

        do {
            routePoints = try JSONDecoder().decode([RoutePoint].self, from: data)
            lastEncodedCount = routePoints.count
            routePointsDirty = false

            // Detect if route data was truncated by checking if first point is significantly after start
            if let sessionStart = startTime,
               let firstPoint = routePoints.first {
                let gap = firstPoint.timestamp.timeIntervalSince(sessionStart)
                // If first point is more than 2 minutes after session start, data was truncated
                if gap > 120 {
                    hasDroppedRouteData = true
                    oldestDroppedDataTime = sessionStart
                    Log.family.info("Detected truncated route data (gap: \(Int(gap))s)")
                }
            }
        } catch {
            Log.family.error("Failed to decode route points (\(data.count) bytes): \(error)")
            // Mark that decoding failed so UI can indicate data corruption
            hasDroppedRouteData = true
            routePoints = []
        }
    }

    /// Group route points by gait for efficient polyline rendering
    func groupedRouteSegments() -> [GaitRouteSegment] {
        guard routePoints.count > 1 else { return [] }

        var segments: [GaitRouteSegment] = []
        var currentGait = routePoints[0].gaitType
        var currentPoints: [CLLocationCoordinate2D] = [routePoints[0].coordinate]

        for i in 1..<routePoints.count {
            let point = routePoints[i]
            if point.gaitType == currentGait {
                currentPoints.append(point.coordinate)
            } else {
                // Finalize current segment
                if currentPoints.count > 1 {
                    segments.append(GaitRouteSegment(gait: currentGait, coordinates: currentPoints))
                }
                // Start new segment (include last point for continuity)
                currentGait = point.gaitType
                currentPoints = [routePoints[i-1].coordinate, point.coordinate]
            }
        }

        // Add final segment
        if currentPoints.count > 1 {
            segments.append(GaitRouteSegment(gait: currentGait, coordinates: currentPoints))
        }

        return segments
    }
}

/// A segment of the route with associated gait type for colour-coding
struct GaitRouteSegment: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let gaitType: GaitType

    // Convenience initializer matching the old API
    init(gait: GaitType, coordinates: [CLLocationCoordinate2D]) {
        self.coordinates = coordinates
        self.gaitType = gait
    }

    init(coordinates: [CLLocationCoordinate2D], gaitType: GaitType) {
        self.coordinates = coordinates
        self.gaitType = gaitType
    }
}

// MARK: - Family Member

/// Represents a family member who can view your live tracking
@Model
final class FamilyMember {
    var id: UUID = UUID()
    var name: String = ""
    var email: String = ""
    var cloudKitRecordID: String = ""  // Their iCloud user record ID
    var relationship: String = ""  // "Parent", "Child", "Spouse", etc.
    var canViewMyLocation: Bool = true
    var dateAdded: Date = Date()

    init() {}

    init(name: String, email: String, relationship: String) {
        self.name = name
        self.email = email
        self.relationship = relationship
    }
}
