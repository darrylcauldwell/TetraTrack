//
//  RideTrackerTests.swift
//  TetraTrackTests
//
//  Tests for RideTracker state and calculations
//

import Testing
import Foundation
@testable import TetraTrack

// MARK: - RideState Tests

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

// MARK: - RideTracker Tests

struct RideTrackerTests {

    // Note: RideTracker requires LocationManager and other dependencies
    // These tests focus on initialization and state properties

    @Test func initialState() {
        let locationManager = LocationManager()
        let tracker = RideTracker(locationManager: locationManager)

        #expect(tracker.rideState == .idle)
        #expect(tracker.currentRide == nil)
        #expect(tracker.elapsedTime == 0)
        #expect(tracker.totalDistance == 0)
        #expect(tracker.currentSpeed == 0)
        #expect(tracker.currentGait == .stationary)
    }

    @Test func initialElevationState() {
        let locationManager = LocationManager()
        let tracker = RideTracker(locationManager: locationManager)

        #expect(tracker.currentElevation == 0)
        #expect(tracker.elevationGain == 0)
        #expect(tracker.elevationLoss == 0)
    }

    @Test func initialGaitTimeState() {
        let locationManager = LocationManager()
        let tracker = RideTracker(locationManager: locationManager)

        #expect(tracker.walkTime == 0)
        #expect(tracker.trotTime == 0)
        #expect(tracker.canterTime == 0)
        #expect(tracker.gallopTime == 0)
    }

    @Test func initialHeartRateState() {
        let locationManager = LocationManager()
        let tracker = RideTracker(locationManager: locationManager)

        #expect(tracker.currentHeartRate == 0)
        #expect(tracker.averageHeartRate == 0)
        #expect(tracker.maxHeartRate == 0)
        #expect(tracker.currentHeartRateZone == .zone1)
    }

    @Test func initialXCState() {
        let locationManager = LocationManager()
        let tracker = RideTracker(locationManager: locationManager)

        #expect(tracker.xcOptimumTime == 0)
        #expect(tracker.xcCourseDistance == 0)
    }

    @Test func initialLiveMetricsState() {
        let locationManager = LocationManager()
        let tracker = RideTracker(locationManager: locationManager)

        #expect(tracker.currentLead == .unknown)
        #expect(tracker.currentRein == .straight)
        #expect(tracker.currentSymmetry == 0.0)
        #expect(tracker.currentRhythm == 0.0)
    }

    @Test func initialFallDetectionState() {
        let locationManager = LocationManager()
        let tracker = RideTracker(locationManager: locationManager)

        #expect(tracker.fallDetected == false)
        #expect(tracker.fallAlertCountdown == 30)
        #expect(tracker.showingFallAlert == false)
    }

    @Test func initialVehicleDetectionState() {
        let locationManager = LocationManager()
        let tracker = RideTracker(locationManager: locationManager)

        #expect(tracker.showingVehicleAlert == false)
    }

    @Test func defaultRideType() {
        let locationManager = LocationManager()
        let tracker = RideTracker(locationManager: locationManager)

        #expect(tracker.selectedRideType == .hack)
    }

    @Test func selectedHorseIsNil() {
        let locationManager = LocationManager()
        let tracker = RideTracker(locationManager: locationManager)

        #expect(tracker.selectedHorse == nil)
    }

    @Test func familySharingDisabledByDefault() {
        let locationManager = LocationManager()
        let tracker = RideTracker(locationManager: locationManager)

        #expect(tracker.isSharingWithFamily == false)
    }
}

// MARK: - Gait Percentage Calculation Tests

struct GaitPercentageCalculationTests {

    @Test func totalMovingTimeCalculation() {
        let locationManager = LocationManager()
        let tracker = RideTracker(locationManager: locationManager)

        // Access internal state through reflection or by testing computed properties
        // Since we can't directly set internal state, test the formula via the computed property
        #expect(tracker.totalMovingTime == 0)
    }

    @Test func gaitPercentagesWithNoTime() {
        let locationManager = LocationManager()
        let tracker = RideTracker(locationManager: locationManager)

        let percentages = tracker.gaitPercentages

        #expect(percentages.walk == 0)
        #expect(percentages.trot == 0)
        #expect(percentages.canter == 0)
        #expect(percentages.gallop == 0)
    }

    @Test func individualGaitPercentagesWithNoTime() {
        let locationManager = LocationManager()
        let tracker = RideTracker(locationManager: locationManager)

        #expect(tracker.walkPercent == 0)
        #expect(tracker.trotPercent == 0)
        #expect(tracker.canterPercent == 0)
        #expect(tracker.gallopPercent == 0)
    }
}

// MARK: - Rein Percentage Tests

struct ReinPercentageTests {

    @Test func reinPercentagesWithNoData() {
        let locationManager = LocationManager()
        let tracker = RideTracker(locationManager: locationManager)

        let percentages = tracker.reinPercentages

        #expect(percentages.left == 0)
        #expect(percentages.right == 0)
    }

    @Test func individualReinPercentagesWithNoData() {
        let locationManager = LocationManager()
        let tracker = RideTracker(locationManager: locationManager)

        #expect(tracker.leftReinPercent == 0)
        #expect(tracker.rightReinPercent == 0)
    }
}

// MARK: - Turn Percentage Tests

struct TurnPercentageTests {

    @Test func turnPercentagesWithNoData() {
        let locationManager = LocationManager()
        let tracker = RideTracker(locationManager: locationManager)

        let percentages = tracker.turnPercentages

        #expect(percentages.left == 0)
        #expect(percentages.right == 0)
    }

    @Test func individualTurnPercentagesWithNoData() {
        let locationManager = LocationManager()
        let tracker = RideTracker(locationManager: locationManager)

        #expect(tracker.leftTurnPercent == 0)
        #expect(tracker.rightTurnPercent == 0)
    }
}

// MARK: - Lead Percentage Tests

struct LeadPercentageTests {

    @Test func leadPercentagesWithNoData() {
        let locationManager = LocationManager()
        let tracker = RideTracker(locationManager: locationManager)

        let percentages = tracker.leadPercentages

        #expect(percentages.left == 0)
        #expect(percentages.right == 0)
    }

    @Test func individualLeadPercentagesWithNoData() {
        let locationManager = LocationManager()
        let tracker = RideTracker(locationManager: locationManager)

        #expect(tracker.leftLeadPercent == 0)
        #expect(tracker.rightLeadPercent == 0)
    }
}

// MARK: - XC Timing Tests

struct XCTimingTests {

    @Test func xcTimeDifferenceWithNoData() {
        let locationManager = LocationManager()
        let tracker = RideTracker(locationManager: locationManager)

        #expect(tracker.xcTimeDifference == 0)
    }

    @Test func xcIsAheadOfTimeWithNoData() {
        let locationManager = LocationManager()
        let tracker = RideTracker(locationManager: locationManager)

        // With 0 difference, not ahead
        #expect(tracker.xcIsAheadOfTime == false)
    }
}

// MARK: - Weather State Tests

struct RideWeatherStateTests {

    @Test func initialWeatherState() {
        let locationManager = LocationManager()
        let tracker = RideTracker(locationManager: locationManager)

        #expect(tracker.currentWeather == nil)
        #expect(tracker.weatherError == nil)
    }
}

// MARK: - Dismiss Vehicle Alert Tests

struct VehicleAlertTests {

    @Test func dismissVehicleAlert() {
        let locationManager = LocationManager()
        let tracker = RideTracker(locationManager: locationManager)

        // Initially not showing
        #expect(tracker.showingVehicleAlert == false)

        // Dismiss is safe to call even when not showing
        tracker.dismissVehicleAlert()

        #expect(tracker.showingVehicleAlert == false)
    }
}
