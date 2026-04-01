//
//  SessionTrackerTests.swift
//  TetraTrackTests
//
//  Tests for SessionTracker and RidingPlugin state and calculations
//

import Testing
import Foundation
@testable import TetraTrack

// MARK: - SessionState Tests (RideState is a typealias)

struct RideStateTests {

    @Test func allCases() {
        let cases: [RideState] = [.idle, .tracking, .paused]
        #expect(cases.count == 3)
    }

    @Test func idleIsNotActive() {
        let state = RideState.idle
        #expect(state.isActive == false)
    }

    @Test func trackingIsActive() {
        let state = RideState.tracking
        #expect(state.isActive == true)
    }

    @Test func pausedIsActive() {
        let state = RideState.paused
        #expect(state.isActive == true)
    }

    @Test func rawValues() {
        #expect(RideState.idle.rawValue == "idle")
        #expect(RideState.tracking.rawValue == "tracking")
        #expect(RideState.paused.rawValue == "paused")
    }

    @Test func codable() throws {
        let original = RideState.tracking
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RideState.self, from: data)

        #expect(decoded == original)
    }
}

// MARK: - SessionTracker Tests

@MainActor
struct SessionTrackerTests {

    @Test func initialState() {
        let locationManager = LocationManager()
        let gpsTracker = GPSSessionTracker(locationManager: locationManager)
        let tracker = SessionTracker(locationManager: locationManager, gpsTracker: gpsTracker)

        #expect(tracker.sessionState == .idle)
        #expect(tracker.elapsedTime == 0)
        #expect(tracker.totalDistance == 0)
        #expect(tracker.currentSpeed == 0)
    }

    @Test func initialElevationState() {
        let locationManager = LocationManager()
        let gpsTracker = GPSSessionTracker(locationManager: locationManager)
        let tracker = SessionTracker(locationManager: locationManager, gpsTracker: gpsTracker)

        #expect(tracker.currentElevation == 0)
        #expect(tracker.elevationGain == 0)
        #expect(tracker.elevationLoss == 0)
    }

    @Test func initialHeartRateState() {
        let locationManager = LocationManager()
        let gpsTracker = GPSSessionTracker(locationManager: locationManager)
        let tracker = SessionTracker(locationManager: locationManager, gpsTracker: gpsTracker)

        #expect(tracker.currentHeartRate == 0)
        #expect(tracker.averageHeartRate == 0)
        #expect(tracker.maxHeartRate == 0)
        #expect(tracker.currentHeartRateZone == .zone1)
    }

    @Test func initialFallDetectionState() {
        let locationManager = LocationManager()
        let gpsTracker = GPSSessionTracker(locationManager: locationManager)
        let tracker = SessionTracker(locationManager: locationManager, gpsTracker: gpsTracker)

        #expect(tracker.fallDetected == false)
        #expect(tracker.fallAlertCountdown == 30)
        #expect(tracker.showingFallAlert == false)
    }

    @Test func initialVehicleDetectionState() {
        let locationManager = LocationManager()
        let gpsTracker = GPSSessionTracker(locationManager: locationManager)
        let tracker = SessionTracker(locationManager: locationManager, gpsTracker: gpsTracker)

        #expect(tracker.showingVehicleAlert == false)
    }

    @Test func familySharingDisabledByDefault() {
        let locationManager = LocationManager()
        let gpsTracker = GPSSessionTracker(locationManager: locationManager)
        let tracker = SessionTracker(locationManager: locationManager, gpsTracker: gpsTracker)

        #expect(tracker.isSharingWithFamily == false)
    }

    @Test func initialWeatherState() {
        let locationManager = LocationManager()
        let gpsTracker = GPSSessionTracker(locationManager: locationManager)
        let tracker = SessionTracker(locationManager: locationManager, gpsTracker: gpsTracker)

        #expect(tracker.currentWeather == nil)
        #expect(tracker.weatherError == nil)
    }

    @Test func dismissVehicleAlert() {
        let locationManager = LocationManager()
        let gpsTracker = GPSSessionTracker(locationManager: locationManager)
        let tracker = SessionTracker(locationManager: locationManager, gpsTracker: gpsTracker)

        #expect(tracker.showingVehicleAlert == false)
        tracker.dismissVehicleAlert()
        #expect(tracker.showingVehicleAlert == false)
    }
}

// MARK: - RidingPlugin Tests

// RidingPluginTests removed — riding is now Watch-primary (#307)

// Gait, Rein, Turn, Lead, and XC timing tests removed — riding is now Watch-primary (#307)
