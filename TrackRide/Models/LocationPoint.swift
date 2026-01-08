//
//  LocationPoint.swift
//  TrackRide
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class LocationPoint {
    var id: UUID = UUID()
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var altitude: Double = 0.0
    @Attribute(.spotlight)
    var timestamp: Date = Date()
    var horizontalAccuracy: Double = 0.0
    var speed: Double = 0.0  // m/s from CLLocation

    // Relationship back to ride - MUST be optional for CloudKit
    var ride: Ride?

    init() {}

    init(
        latitude: Double,
        longitude: Double,
        altitude: Double,
        timestamp: Date,
        horizontalAccuracy: Double,
        speed: Double
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
        self.horizontalAccuracy = horizontalAccuracy
        self.speed = speed
    }

    // Convenience initializer from CLLocation
    convenience init(from location: CLLocation) {
        self.init(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            timestamp: location.timestamp,
            horizontalAccuracy: location.horizontalAccuracy,
            speed: max(0, location.speed)
        )
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
