//
//  LocationMath.swift
//  TetraTrack
//
//  Unified location mathematics utilities for bearing, distance, and coordinate calculations
//

import Foundation
import CoreLocation

// MARK: - Location Math Utilities

enum LocationMath {
    // MARK: - Bearing Calculations

    /// Calculate bearing between two coordinates (in degrees, 0-360)
    /// - Parameters:
    ///   - from: Starting coordinate
    ///   - to: Ending coordinate
    /// - Returns: Bearing in degrees (0 = North, 90 = East, 180 = South, 270 = West)
    static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude.radians
        let lat2 = to.latitude.radians
        let deltaLon = (to.longitude - from.longitude).radians

        let x = sin(deltaLon) * cos(lat2)
        let y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)

        var bearing = atan2(x, y).degrees

        // Normalize to 0-360
        if bearing < 0 {
            bearing += 360
        }

        return bearing
    }

    /// Calculate the change in bearing (turn angle) between two bearings
    /// - Parameters:
    ///   - from: Starting bearing (degrees)
    ///   - to: Ending bearing (degrees)
    /// - Returns: Signed turn angle (-180 to 180, positive = right turn, negative = left turn)
    static func bearingChange(from: Double, to: Double) -> Double {
        var change = to - from

        // Normalize to -180 to 180
        while change > 180 { change -= 360 }
        while change < -180 { change += 360 }

        return change
    }

    // MARK: - Distance Calculations

    /// Calculate distance between two coordinates in meters
    /// - Parameters:
    ///   - from: Starting coordinate
    ///   - to: Ending coordinate
    /// - Returns: Distance in meters
    static func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }

    /// Calculate distance between two CLLocations in meters
    static func distance(from: CLLocation, to: CLLocation) -> Double {
        from.distance(from: to)
    }

    /// Calculate total distance along a path of coordinates
    static func totalDistance(along coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count > 1 else { return 0 }

        var total: Double = 0
        for i in 1..<coordinates.count {
            total += distance(from: coordinates[i - 1], to: coordinates[i])
        }
        return total
    }

    // MARK: - Coordinate Calculations

    /// Calculate the midpoint between two coordinates
    static func midpoint(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let lat1 = from.latitude.radians
        let lon1 = from.longitude.radians
        let lat2 = to.latitude.radians
        let lon2 = to.longitude.radians

        let dLon = lon2 - lon1

        let bx = cos(lat2) * cos(dLon)
        let by = cos(lat2) * sin(dLon)

        let lat3 = atan2(sin(lat1) + sin(lat2), sqrt((cos(lat1) + bx) * (cos(lat1) + bx) + by * by))
        let lon3 = lon1 + atan2(by, cos(lat1) + bx)

        return CLLocationCoordinate2D(latitude: lat3.degrees, longitude: lon3.degrees)
    }

    /// Calculate a destination coordinate given start, bearing, and distance
    /// - Parameters:
    ///   - start: Starting coordinate
    ///   - bearing: Bearing in degrees
    ///   - distance: Distance in meters
    /// - Returns: Destination coordinate
    static func destination(from start: CLLocationCoordinate2D, bearing: Double, distance: Double) -> CLLocationCoordinate2D {
        let earthRadius = 6371000.0 // meters

        let lat1 = start.latitude.radians
        let lon1 = start.longitude.radians
        let bearingRad = bearing.radians
        let angularDistance = distance / earthRadius

        let lat2 = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(bearingRad))
        let lon2 = lon1 + atan2(
            sin(bearingRad) * sin(angularDistance) * cos(lat1),
            cos(angularDistance) - sin(lat1) * sin(lat2)
        )

        return CLLocationCoordinate2D(latitude: lat2.degrees, longitude: lon2.degrees)
    }

    /// Calculate the center of a bounding box containing all coordinates
    static func center(of coordinates: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D? {
        guard !coordinates.isEmpty else { return nil }

        var totalLat: Double = 0
        var totalLon: Double = 0

        for coord in coordinates {
            totalLat += coord.latitude
            totalLon += coord.longitude
        }

        return CLLocationCoordinate2D(
            latitude: totalLat / Double(coordinates.count),
            longitude: totalLon / Double(coordinates.count)
        )
    }

    /// Calculate bounding box for coordinates
    static func boundingBox(of coordinates: [CLLocationCoordinate2D]) -> (min: CLLocationCoordinate2D, max: CLLocationCoordinate2D)? {
        guard let first = coordinates.first else { return nil }

        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        return (
            CLLocationCoordinate2D(latitude: minLat, longitude: minLon),
            CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon)
        )
    }

    // MARK: - Turn Detection

    /// Determine turn direction from bearing change
    static func turnDirection(bearingChange: Double) -> TurnDirection {
        if bearingChange > 15 {
            return .right
        } else if bearingChange < -15 {
            return .left
        }
        return .straight
    }

    /// Determine turn severity from bearing change magnitude
    static func turnSeverity(bearingChange: Double) -> TurnSeverity {
        let magnitude = abs(bearingChange)
        if magnitude < 30 {
            return .gentle
        } else if magnitude < 60 {
            return .moderate
        } else if magnitude < 90 {
            return .sharp
        }
        return .uTurn
    }
}

// MARK: - Turn Types

enum TurnSeverity {
    case gentle    // < 30 degrees
    case moderate  // 30-60 degrees
    case sharp     // 60-90 degrees
    case uTurn     // > 90 degrees
}

// MARK: - Angle Conversions

extension Double {
    /// Convert degrees to radians
    var radians: Double {
        self * .pi / 180
    }

    /// Convert radians to degrees
    var degrees: Double {
        self * 180 / .pi
    }
}

// MARK: - CLLocationCoordinate2D Extensions

extension CLLocationCoordinate2D {
    /// Calculate bearing to another coordinate
    func bearing(to: CLLocationCoordinate2D) -> Double {
        LocationMath.bearing(from: self, to: to)
    }

    /// Calculate distance to another coordinate in meters
    func distance(to: CLLocationCoordinate2D) -> Double {
        LocationMath.distance(from: self, to: to)
    }

    /// Check if coordinate is valid (not 0,0 and within bounds)
    var isValid: Bool {
        latitude >= -90 && latitude <= 90 &&
        longitude >= -180 && longitude <= 180 &&
        !(latitude == 0 && longitude == 0)
    }
}

// MARK: - CLLocation Extensions

extension CLLocation {
    /// Calculate bearing to another location
    func bearing(to location: CLLocation) -> Double {
        LocationMath.bearing(from: self.coordinate, to: location.coordinate)
    }
}
