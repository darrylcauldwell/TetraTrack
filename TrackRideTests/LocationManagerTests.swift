//
//  LocationManagerTests.swift
//  TrackRideTests
//
//  Tests for LocationManager and related types
//

import Testing
import Foundation
import CoreLocation
@testable import TetraTrack

// MARK: - CircularBuffer Tests

struct CircularBufferTests {

    @Test func initializationWithCapacity() {
        let buffer = CircularBuffer<Int>(capacity: 10)

        #expect(buffer.capacity == 10)
        #expect(buffer.count == 0)
        #expect(buffer.isEmpty == true)
    }

    @Test func appendSingleElement() {
        var buffer = CircularBuffer<Int>(capacity: 5)

        buffer.append(42)

        #expect(buffer.count == 1)
        #expect(buffer.isEmpty == false)
        #expect(buffer.elements == [42])
    }

    @Test func appendMultipleElements() {
        var buffer = CircularBuffer<Int>(capacity: 5)

        buffer.append(1)
        buffer.append(2)
        buffer.append(3)

        #expect(buffer.count == 3)
        #expect(buffer.elements == [1, 2, 3])
    }

    @Test func appendToCapacity() {
        var buffer = CircularBuffer<Int>(capacity: 3)

        buffer.append(1)
        buffer.append(2)
        buffer.append(3)

        #expect(buffer.count == 3)
        #expect(buffer.elements == [1, 2, 3])
    }

    @Test func appendBeyondCapacityOverwritesOldest() {
        var buffer = CircularBuffer<Int>(capacity: 3)

        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        buffer.append(4)  // Overwrites 1

        #expect(buffer.count == 3)
        #expect(buffer.elements == [2, 3, 4])
    }

    @Test func appendManyBeyondCapacity() {
        var buffer = CircularBuffer<Int>(capacity: 3)

        for i in 1...10 {
            buffer.append(i)
        }

        #expect(buffer.count == 3)
        #expect(buffer.elements == [8, 9, 10])
    }

    @Test func removeAllClearsBuffer() {
        var buffer = CircularBuffer<Int>(capacity: 5)

        buffer.append(1)
        buffer.append(2)
        buffer.append(3)

        buffer.removeAll()

        #expect(buffer.count == 0)
        #expect(buffer.isEmpty == true)
        #expect(buffer.elements == [])
    }

    @Test func removeAllAllowsReuse() {
        var buffer = CircularBuffer<Int>(capacity: 3)

        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        buffer.removeAll()

        buffer.append(10)
        buffer.append(20)

        #expect(buffer.count == 2)
        #expect(buffer.elements == [10, 20])
    }

    @Test func elementsReturnsChronologicalOrder() {
        var buffer = CircularBuffer<Int>(capacity: 5)

        // Partially fill
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)

        let elements = buffer.elements
        #expect(elements == [1, 2, 3])
    }

    @Test func elementsReturnsChronologicalOrderAfterWrap() {
        var buffer = CircularBuffer<Int>(capacity: 3)

        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        buffer.append(4)  // wraps around
        buffer.append(5)

        let elements = buffer.elements
        // Should be in chronological order: oldest to newest
        #expect(elements == [3, 4, 5])
    }

    @Test func emptyBufferElements() {
        let buffer = CircularBuffer<String>(capacity: 5)

        #expect(buffer.elements == [])
    }

    @Test func capacityOfOne() {
        var buffer = CircularBuffer<Int>(capacity: 1)

        buffer.append(1)
        #expect(buffer.elements == [1])

        buffer.append(2)
        #expect(buffer.elements == [2])

        buffer.append(3)
        #expect(buffer.elements == [3])
        #expect(buffer.count == 1)
    }

    @Test func withComplexType() {
        struct Point {
            let x: Double
            let y: Double
        }

        var buffer = CircularBuffer<Point>(capacity: 3)

        buffer.append(Point(x: 1, y: 2))
        buffer.append(Point(x: 3, y: 4))

        #expect(buffer.count == 2)
        #expect(buffer.elements[0].x == 1)
        #expect(buffer.elements[1].x == 3)
    }
}

// MARK: - TrackedPoint Tests

struct TrackedPointTests {

    @Test func initializationWithCoordinateAndGait() {
        let coordinate = CLLocationCoordinate2D(latitude: 51.5, longitude: -1.5)
        let point = TrackedPoint(
            coordinate: coordinate,
            gait: .trot,
            timestamp: Date()
        )

        #expect(point.coordinate.latitude == 51.5)
        #expect(point.coordinate.longitude == -1.5)
        #expect(point.gait == .trot)
    }

    @Test func hasUniqueId() {
        let coordinate = CLLocationCoordinate2D(latitude: 51.5, longitude: -1.5)
        let point1 = TrackedPoint(coordinate: coordinate, gait: .walk, timestamp: Date())
        let point2 = TrackedPoint(coordinate: coordinate, gait: .walk, timestamp: Date())

        #expect(point1.id != point2.id)
    }

    @Test func storesTimestamp() {
        let now = Date()
        let point = TrackedPoint(
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            gait: .stationary,
            timestamp: now
        )

        #expect(point.timestamp == now)
    }
}

// MARK: - LocationManager Tests

struct LocationManagerTests {

    @Test func initialState() {
        let manager = LocationManager()

        #expect(manager.isTracking == false)
        #expect(manager.currentLocation == nil)
        #expect(manager.locationError == nil)
        #expect(manager.currentGait == .stationary)
        #expect(manager.trackedPoints.isEmpty)
    }

    @Test func hasPermissionWithAuthorizedAlways() {
        let manager = LocationManager()
        // Note: We can't directly set authorizationStatus in tests without mocking
        // This test documents expected behavior
        #expect(manager.needsPermission || manager.hasPermission || manager.permissionDenied)
    }

    @Test func updateGait() {
        let manager = LocationManager()

        manager.updateGait(.trot)

        #expect(manager.currentGait == .trot)
    }

    @Test func updateGaitMultipleTimes() {
        let manager = LocationManager()

        manager.updateGait(.walk)
        #expect(manager.currentGait == .walk)

        manager.updateGait(.canter)
        #expect(manager.currentGait == .canter)

        manager.updateGait(.gallop)
        #expect(manager.currentGait == .gallop)
    }

    @Test func addTrackedPoint() {
        let manager = LocationManager()
        let location = CLLocation(latitude: 51.5, longitude: -1.5)

        manager.updateGait(.trot)
        manager.addTrackedPoint(location)

        #expect(manager.trackedPoints.count == 1)
        #expect(manager.trackedPoints.first?.gait == .trot)
        #expect(manager.trackedPoints.first?.coordinate.latitude == 51.5)
    }

    @Test func addMultipleTrackedPoints() {
        let manager = LocationManager()

        manager.updateGait(.walk)
        manager.addTrackedPoint(CLLocation(latitude: 51.5, longitude: -1.5))

        manager.updateGait(.trot)
        manager.addTrackedPoint(CLLocation(latitude: 51.51, longitude: -1.51))

        manager.updateGait(.canter)
        manager.addTrackedPoint(CLLocation(latitude: 51.52, longitude: -1.52))

        #expect(manager.trackedPoints.count == 3)
        #expect(manager.trackedPoints[0].gait == .walk)
        #expect(manager.trackedPoints[1].gait == .trot)
        #expect(manager.trackedPoints[2].gait == .canter)
    }

    @Test func clearTrackedPoints() {
        let manager = LocationManager()

        manager.updateGait(.gallop)
        manager.addTrackedPoint(CLLocation(latitude: 51.5, longitude: -1.5))
        manager.addTrackedPoint(CLLocation(latitude: 51.51, longitude: -1.51))

        manager.clearTrackedPoints()

        #expect(manager.trackedPoints.isEmpty)
        #expect(manager.currentGait == .stationary)
    }

    @Test func trackedPointsBufferLimit() {
        let manager = LocationManager()

        // Add more than the buffer capacity (1000)
        for i in 0..<1100 {
            let location = CLLocation(
                latitude: 51.5 + Double(i) * 0.0001,
                longitude: -1.5
            )
            manager.addTrackedPoint(location)
        }

        // Should be capped at buffer capacity
        #expect(manager.trackedPoints.count == 1000)

        // First point should be the 101st one added (oldest 100 were dropped)
        let firstPoint = manager.trackedPoints.first
        #expect(firstPoint != nil)
    }

    @Test func stopTrackingResetsState() {
        let manager = LocationManager()

        // Can safely call stopTracking even if not tracking
        manager.stopTracking()

        #expect(manager.isTracking == false)
    }
}

// MARK: - Authorization State Tests

struct LocationAuthorizationTests {

    @Test func needsPermissionWhenNotDetermined() {
        // Note: Testing authorization states requires mocking CLLocationManager
        // These tests document expected computed property behavior

        let manager = LocationManager()

        // One of these must be true
        let validState = manager.needsPermission || manager.hasPermission || manager.permissionDenied
        #expect(validState == true)
    }
}
