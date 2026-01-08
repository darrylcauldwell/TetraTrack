//
//  LiveTrackingSession.swift
//  TrackRide
//

import Foundation
import SwiftData
import CoreLocation

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
        if routePoints.count > 500 {
            routePoints.removeFirst(routePoints.count - 500)
        }

        // Encode route points to Data for persistence
        encodeRoutePoints()

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
    }

    func endSession() {
        isActive = false
    }

    // MARK: - Route Points Encoding

    func encodeRoutePoints() {
        routePointsData = try? JSONEncoder().encode(routePoints)
    }

    func decodeRoutePoints() {
        guard let data = routePointsData else {
            routePoints = []
            return
        }
        routePoints = (try? JSONDecoder().decode([RoutePoint].self, from: data)) ?? []
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
