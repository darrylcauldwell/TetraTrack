//
//  SwimmingLocationPoint.swift
//  TetraTrack
//
//  GPS location point for open water swimming sessions
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class SwimmingLocationPoint {
    // All properties have defaults for CloudKit compatibility
    var id: UUID = UUID()
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var altitude: Double = 0.0
    var timestamp: Date = Date()
    var speed: Double = 0.0  // m/s from CLLocation
    var horizontalAccuracy: Double = 0.0

    // Relationship back to swimming session
    var session: SwimmingSession?

    init() {}

    convenience init(
        latitude: Double,
        longitude: Double,
        altitude: Double,
        timestamp: Date,
        speed: Double,
        horizontalAccuracy: Double
    ) {
        self.init()
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
        self.speed = speed
        self.horizontalAccuracy = horizontalAccuracy
    }

    /// Convenience initializer from CLLocation
    convenience init(from location: CLLocation) {
        self.init(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            timestamp: location.timestamp,
            speed: max(0, location.speed),
            horizontalAccuracy: location.horizontalAccuracy
        )
    }

    /// Coordinate for MapKit
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Convert to CLLocation
    var clLocation: CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: -1,
            timestamp: timestamp
        )
    }
}
