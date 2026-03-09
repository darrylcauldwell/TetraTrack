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

@MainActor
struct RidingPluginTests {

    @Test func initialGaitState() {
        let plugin = RidingPlugin()

        #expect(plugin.currentGait == .stationary)
        #expect(plugin.walkTime == 0)
        #expect(plugin.trotTime == 0)
        #expect(plugin.canterTime == 0)
        #expect(plugin.gallopTime == 0)
    }

    @Test func initialXCState() {
        let plugin = RidingPlugin()

        #expect(plugin.xcOptimumTime == 0)
        #expect(plugin.xcCourseDistance == 0)
    }

    @Test func initialLiveMetricsState() {
        let plugin = RidingPlugin()

        #expect(plugin.currentLead == .unknown)
        #expect(plugin.currentRein == .straight)
        #expect(plugin.currentSymmetry == 0.0)
        #expect(plugin.currentRhythm == 0.0)
    }

    @Test func defaultRideType() {
        let plugin = RidingPlugin()

        #expect(plugin.selectedRideType == .hack)
    }

    @Test func selectedHorseIsNil() {
        let plugin = RidingPlugin()

        #expect(plugin.selectedHorse == nil)
    }

    @Test func currentRideIsNil() {
        let plugin = RidingPlugin()

        #expect(plugin.currentRide == nil)
    }
}

// MARK: - Gait Percentage Calculation Tests

@MainActor
struct GaitPercentageCalculationTests {

    @Test func totalMovingTimeCalculation() {
        let plugin = RidingPlugin()

        #expect(plugin.totalMovingTime == 0)
    }

    @Test func gaitPercentagesWithNoTime() {
        let plugin = RidingPlugin()

        let percentages = plugin.gaitPercentages

        #expect(percentages.walk == 0)
        #expect(percentages.trot == 0)
        #expect(percentages.canter == 0)
        #expect(percentages.gallop == 0)
    }

    @Test func individualGaitPercentagesWithNoTime() {
        let plugin = RidingPlugin()

        #expect(plugin.walkPercent == 0)
        #expect(plugin.trotPercent == 0)
        #expect(plugin.canterPercent == 0)
        #expect(plugin.gallopPercent == 0)
    }
}

// MARK: - Rein Percentage Tests

@MainActor
struct ReinPercentageTests {

    @Test func reinPercentagesWithNoData() {
        let plugin = RidingPlugin()

        let percentages = plugin.reinPercentages

        #expect(percentages.left == 0)
        #expect(percentages.right == 0)
    }

    @Test func individualReinPercentagesWithNoData() {
        let plugin = RidingPlugin()

        #expect(plugin.leftReinPercent == 0)
        #expect(plugin.rightReinPercent == 0)
    }
}

// MARK: - Turn Percentage Tests

@MainActor
struct TurnPercentageTests {

    @Test func turnPercentagesWithNoData() {
        let plugin = RidingPlugin()

        let percentages = plugin.turnPercentages

        #expect(percentages.left == 0)
        #expect(percentages.right == 0)
    }

    @Test func individualTurnPercentagesWithNoData() {
        let plugin = RidingPlugin()

        #expect(plugin.leftTurnPercent == 0)
        #expect(plugin.rightTurnPercent == 0)
    }
}

// MARK: - Lead Percentage Tests

@MainActor
struct LeadPercentageTests {

    @Test func leadPercentagesWithNoData() {
        let plugin = RidingPlugin()

        let percentages = plugin.leadPercentages

        #expect(percentages.left == 0)
        #expect(percentages.right == 0)
    }

    @Test func individualLeadPercentagesWithNoData() {
        let plugin = RidingPlugin()

        #expect(plugin.leftLeadPercent == 0)
        #expect(plugin.rightLeadPercent == 0)
    }
}

// MARK: - XC Timing Tests

@MainActor
struct XCTimingTests {

    @Test func xcTimeDifferenceWithNoData() {
        let plugin = RidingPlugin()

        #expect(plugin.xcTimeDifference == 0)
    }

    @Test func xcIsAheadOfTimeWithNoData() {
        let plugin = RidingPlugin()

        // With 0 difference, not ahead
        #expect(plugin.xcIsAheadOfTime == false)
    }
}
