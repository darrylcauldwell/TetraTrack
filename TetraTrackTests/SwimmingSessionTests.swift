//
//  SwimmingSessionTests.swift
//  TetraTrackTests
//
//  Tests for Swimming session model and related functionality
//

import Testing
import Foundation
@testable import TetraTrack

struct SwimmingSessionTests {

    // MARK: - Basic Properties

    @Test func swimmingSessionInitialization() {
        let session = SwimmingSession(name: "Morning Swim", poolMode: .pool, poolLength: 25.0)

        #expect(session.name == "Morning Swim")
        #expect(session.poolMode == .pool)
        #expect(session.poolLength == 25.0)
        #expect(session.isIndoor == true)
    }

    @Test func swimmingSessionDefaultPoolLength() {
        let session = SwimmingSession()

        #expect(session.poolLength == 25.0)
    }

    // MARK: - Pace Calculations

    @Test func averagePaceCalculation() {
        let session = SwimmingSession(name: "Test")
        session.totalDistance = 400 // 400 meters
        session.totalDuration = 480 // 8 minutes = 480 seconds

        // Pace should be seconds per 100m
        // 480 seconds / 4 (100m segments) = 120 seconds per 100m
        #expect(session.averagePace == 120)
    }

    @Test func averagePaceWithZeroDistance() {
        let session = SwimmingSession(name: "Test")
        session.totalDistance = 0
        session.totalDuration = 100

        #expect(session.averagePace == 0)
    }

    // MARK: - SWOLF Calculation

    @Test func swolfCalculation() {
        let lap = SwimmingLap(orderIndex: 0, distance: 25.0)
        lap.strokeCount = 18
        lap.duration = 30

        // SWOLF = strokes + seconds = 18 + 30 = 48
        #expect(lap.swolf == 48)
    }

    @Test func averageSwolfCalculation() {
        let session = SwimmingSession(name: "Test")

        let lap1 = SwimmingLap(orderIndex: 0, distance: 25.0)
        lap1.strokeCount = 18
        lap1.duration = 30
        lap1.session = session

        let lap2 = SwimmingLap(orderIndex: 1, distance: 25.0)
        lap2.strokeCount = 20
        lap2.duration = 32
        lap2.session = session

        session.laps = [lap1, lap2]

        // Average SWOLF = ((18+30) + (20+32)) / 2 = (48 + 52) / 2 = 50
        #expect(session.averageSwolf == 50)
    }

    // MARK: - Stroke Rate

    @Test func strokeRateCalculation() {
        let lap = SwimmingLap(orderIndex: 0, distance: 25.0)
        lap.strokeCount = 18
        lap.duration = 30

        // Stroke rate = strokes / (duration in minutes) = 18 / 0.5 = 36 strokes per minute
        #expect(lap.strokeRate == 36)
    }

    // MARK: - Pool Mode

    @Test func poolModeValues() {
        #expect(SwimmingPoolMode.pool.rawValue == "Pool")
        #expect(SwimmingPoolMode.openWater.rawValue == "Open Water")
    }

    @Test func poolModeIcons() {
        #expect(SwimmingPoolMode.pool.icon == "square.fill")
        #expect(SwimmingPoolMode.openWater.icon == "water.waves")
    }

    // MARK: - Swimming Stroke

    @Test func swimmingStrokeAbbreviations() {
        #expect(SwimmingStroke.freestyle.abbreviation == "FR")
        #expect(SwimmingStroke.backstroke.abbreviation == "BK")
        #expect(SwimmingStroke.breaststroke.abbreviation == "BR")
        #expect(SwimmingStroke.butterfly.abbreviation == "FL")
        #expect(SwimmingStroke.individual.abbreviation == "IM")
    }

    // MARK: - Pace Zones

    @Test func swimmingPaceZoneNames() {
        #expect(SwimmingPaceZone.recovery.name == "Recovery")
        #expect(SwimmingPaceZone.endurance.name == "Endurance")
        #expect(SwimmingPaceZone.tempo.name == "Tempo")
        #expect(SwimmingPaceZone.threshold.name == "Threshold")
        #expect(SwimmingPaceZone.speed.name == "Speed")
    }

    @Test func swimmingPaceZoneDetermination() {
        let thresholdPace: TimeInterval = 100 // 1:40 per 100m

        // Speed zone: < 0.95 of threshold
        let speedPace: TimeInterval = 90
        #expect(SwimmingPaceZone.zone(for: speedPace, thresholdPace: thresholdPace) == .speed)

        // Threshold zone: 0.95-1.02 of threshold
        let thresholdZonePace: TimeInterval = 100
        #expect(SwimmingPaceZone.zone(for: thresholdZonePace, thresholdPace: thresholdPace) == .threshold)

        // Recovery zone: > 1.25 of threshold
        let recoveryPace: TimeInterval = 130
        #expect(SwimmingPaceZone.zone(for: recoveryPace, thresholdPace: thresholdPace) == .recovery)
    }

    // MARK: - Three Minute Test

    @Test func threeMinuteTestPaceCalculation() {
        let test = ThreeMinuteSwimTest(
            testDate: Date(),
            distance: 150, // 150m in 3 minutes
            strokeCount: 90,
            stroke: .freestyle
        )

        // Pace = 180 seconds / (150/100) = 180 / 1.5 = 120 seconds per 100m
        #expect(test.pace == 120)
    }

    @Test func threeMinuteTestFitnessLevels() {
        // Elite: pace < 90
        let eliteTest = ThreeMinuteSwimTest(testDate: Date(), distance: 220, strokeCount: 100, stroke: .freestyle)
        #expect(eliteTest.fitnessLevel == "Elite")

        // Beginner: pace 120-150
        let beginnerTest = ThreeMinuteSwimTest(testDate: Date(), distance: 130, strokeCount: 80, stroke: .freestyle)
        #expect(beginnerTest.fitnessLevel == "Beginner")
    }

    // MARK: - Dominant Stroke

    @Test func dominantStrokeCalculation() {
        let session = SwimmingSession(name: "Test")

        let lap1 = SwimmingLap(orderIndex: 0)
        lap1.stroke = .freestyle

        let lap2 = SwimmingLap(orderIndex: 1)
        lap2.stroke = .freestyle

        let lap3 = SwimmingLap(orderIndex: 2)
        lap3.stroke = .breaststroke

        session.laps = [lap1, lap2, lap3]

        #expect(session.dominantStroke == .freestyle)
    }

    // MARK: - Lap Count

    @Test func lapCountCalculation() {
        let session = SwimmingSession(name: "Test")
        session.laps = [
            SwimmingLap(orderIndex: 0),
            SwimmingLap(orderIndex: 1),
            SwimmingLap(orderIndex: 2),
            SwimmingLap(orderIndex: 3)
        ]

        #expect(session.lapCount == 4)
    }
}
