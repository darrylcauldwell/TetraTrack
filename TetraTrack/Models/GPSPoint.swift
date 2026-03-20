//
//  GPSPoint.swift
//  TetraTrack
//
//  Unified GPS location point for all disciplines.
//  Replaces LocationPoint, RunningLocationPoint, and SwimmingLocationPoint.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class GPSPoint {
    var id: UUID = UUID()
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var altitude: Double = 0.0
    @Attribute(.spotlight)
    var timestamp: Date = Date()
    var horizontalAccuracy: Double = 0.0
    var speed: Double = 0.0  // m/s from CLLocation

    // Parent relationships — only one is populated per point. MUST be optional for CloudKit.
    var ride: Ride?
    var runningSession: RunningSession?
    var swimmingSession: SwimmingSession?

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
