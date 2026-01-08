//
//  RideModelTests.swift
//  TrackRideTests
//
//  Tests for Ride model properties and computed values
//

import Testing
import Foundation
@testable import TetraTrack

struct RideModelTests {

    // MARK: - Basic Properties

    @Test func rideInitialization() {
        let ride = Ride()

        #expect(ride.totalDistance == 0.0)
        #expect(ride.totalDuration == 0.0)
        #expect(ride.name == "")
        #expect(ride.notes == "")
        #expect(ride.elevationGain == 0.0)
        #expect(ride.elevationLoss == 0.0)
        #expect(ride.maxSpeed == 0.0)
    }

    // MARK: - Average Speed Calculation

    @Test func averageSpeedCalculation() {
        let ride = Ride()
        ride.totalDistance = 1000 // 1000 meters
        ride.totalDuration = 500 // 500 seconds

        // Speed = 1000 / 500 = 2 m/s
        #expect(ride.averageSpeed == 2.0)
    }

    @Test func averageSpeedWithZeroDuration() {
        let ride = Ride()
        ride.totalDistance = 1000
        ride.totalDuration = 0

        #expect(ride.averageSpeed == 0)
    }

    // MARK: - Turn Stats

    @Test func turnBalanceCalculation() {
        let ride = Ride()
        ride.leftTurns = 6
        ride.rightTurns = 4

        // Balance = 6 / 10 * 100 = 60%
        #expect(ride.turnBalancePercent == 60)
    }

    @Test func turnBalanceWithNoTurns() {
        let ride = Ride()
        ride.leftTurns = 0
        ride.rightTurns = 0

        #expect(ride.turnBalancePercent == 50)
    }

    @Test func turnStats() {
        let ride = Ride()
        ride.leftTurns = 5
        ride.rightTurns = 3
        ride.totalLeftAngle = 450.0
        ride.totalRightAngle = 270.0

        let stats = ride.turnStats

        #expect(stats.leftTurns == 5)
        #expect(stats.rightTurns == 3)
        #expect(stats.totalLeftAngle == 450.0)
        #expect(stats.totalRightAngle == 270.0)
    }

    // MARK: - Lead Balance

    @Test func leadBalanceCalculation() {
        let ride = Ride()
        ride.leftLeadDuration = 120 // 2 minutes
        ride.rightLeadDuration = 180 // 3 minutes

        // Balance = 120 / 300 = 0.4 (40%)
        #expect(ride.leadBalance == 0.4)
        #expect(ride.leadBalancePercent == 40)
    }

    @Test func leadBalanceWithNoLeadData() {
        let ride = Ride()
        ride.leftLeadDuration = 0
        ride.rightLeadDuration = 0

        #expect(ride.leadBalance == 0.5)
        #expect(ride.leadBalancePercent == 50)
    }

    @Test func totalLeadDuration() {
        let ride = Ride()
        ride.leftLeadDuration = 100
        ride.rightLeadDuration = 150

        #expect(ride.totalLeadDuration == 250)
    }

    // MARK: - Rein Balance

    @Test func reinBalanceCalculation() {
        let ride = Ride()
        ride.leftReinDuration = 300 // 5 minutes
        ride.rightReinDuration = 300 // 5 minutes

        // Balance = 300 / 600 = 0.5 (50%)
        #expect(ride.reinBalance == 0.5)
        #expect(ride.reinBalancePercent == 50)
    }

    @Test func reinBalanceWithNoReinData() {
        let ride = Ride()
        ride.leftReinDuration = 0
        ride.rightReinDuration = 0

        #expect(ride.reinBalance == 0.5)
        #expect(ride.reinBalancePercent == 50)
    }

    @Test func overallSymmetryCalculation() {
        let ride = Ride()
        ride.leftReinDuration = 100
        ride.rightReinDuration = 100
        ride.leftReinSymmetry = 80.0
        ride.rightReinSymmetry = 90.0

        // Weighted average: (80*100 + 90*100) / 200 = 85
        #expect(ride.overallSymmetry == 85.0)
    }

    @Test func overallRhythmCalculation() {
        let ride = Ride()
        ride.leftReinDuration = 100
        ride.rightReinDuration = 100
        ride.leftReinRhythm = 70.0
        ride.rightReinRhythm = 80.0

        // Weighted average: (70*100 + 80*100) / 200 = 75
        #expect(ride.overallRhythm == 75.0)
    }

    // MARK: - Heart Rate

    @Test func hasHeartRateDataWhenAverageSet() {
        let ride = Ride()
        ride.averageHeartRate = 140

        #expect(ride.hasHeartRateData == true)
    }

    @Test func hasNoHeartRateDataWhenEmpty() {
        let ride = Ride()

        #expect(ride.hasHeartRateData == false)
    }

    @Test func formattedHeartRateValues() {
        let ride = Ride()
        ride.averageHeartRate = 140
        ride.maxHeartRate = 175
        ride.minHeartRate = 95

        #expect(ride.formattedAverageHeartRate == "140 bpm")
        #expect(ride.formattedMaxHeartRate == "175 bpm")
        #expect(ride.formattedMinHeartRate == "95 bpm")
    }

    @Test func formattedHeartRateWhenEmpty() {
        let ride = Ride()

        #expect(ride.formattedAverageHeartRate == "--")
        #expect(ride.formattedMaxHeartRate == "--")
        #expect(ride.formattedMinHeartRate == "--")
    }

    // MARK: - Ride Type

    @Test func rideTypeDefault() {
        let ride = Ride()

        #expect(ride.rideType == .hack)
    }

    @Test func rideTypeAssignment() {
        let ride = Ride()
        ride.rideType = .schooling

        #expect(ride.rideType == .schooling)
        #expect(ride.rideTypeValue == "Flatwork")
    }

    // MARK: - Default Name

    @Test func defaultNameFormat() {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM"
        let expectedSuffix = formatter.string(from: date)

        let name = Ride.defaultName(for: date)

        #expect(name.hasPrefix("Ride - "))
        #expect(name.hasSuffix(expectedSuffix))
    }

    // MARK: - Transition Stats

    @Test func transitionCountEmpty() {
        let ride = Ride()

        #expect(ride.transitionCount == 0)
    }

    @Test func averageTransitionQualityEmpty() {
        let ride = Ride()

        #expect(ride.averageTransitionQuality == 0.0)
    }

    // MARK: - Weather Data

    @Test func hasWeatherDataWhenEmpty() {
        let ride = Ride()

        #expect(ride.hasWeatherData == false)
    }

    // MARK: - AI Summary

    @Test func hasAISummaryWhenEmpty() {
        let ride = Ride()

        #expect(ride.hasAISummary == false)
    }

    // MARK: - Voice Notes

    @Test func voiceNotesEmpty() {
        let ride = Ride()

        #expect(ride.voiceNotes.isEmpty)
    }
}

// MARK: - Ride Type Tests

struct RideTypeTests {

    @Test func rideTypeRawValues() {
        #expect(RideType.hack.rawValue == "Hack")
        #expect(RideType.schooling.rawValue == "Schooling")
        #expect(RideType.crossCountry.rawValue == "Cross Country")
    }

    @Test func rideTypeAllCasesCount() {
        #expect(RideType.allCases.count == 3)
    }

    @Test func rideTypeIsIndoor() {
        #expect(RideType.schooling.isIndoor == true)
        #expect(RideType.hack.isIndoor == false)
        #expect(RideType.crossCountry.isIndoor == false)
    }

    @Test func rideTypeOutdoorTypes() {
        let outdoorTypes = RideType.outdoorTypes
        #expect(outdoorTypes.count == 2)
        #expect(outdoorTypes.contains(.hack))
        #expect(outdoorTypes.contains(.crossCountry))
    }
}

// MARK: - Gait Type Tests

struct GaitTypeTests {

    @Test func gaitTypeRawValues() {
        #expect(GaitType.stationary.rawValue == "stationary")
        #expect(GaitType.walk.rawValue == "walk")
        #expect(GaitType.trot.rawValue == "trot")
        #expect(GaitType.canter.rawValue == "canter")
        #expect(GaitType.gallop.rawValue == "gallop")
    }

    @Test func gaitTypeAllCasesCount() {
        #expect(GaitType.allCases.count == 5)
    }
}
