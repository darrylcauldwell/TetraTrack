//
//  RunningSessionTests.swift
//  TetraTrackTests
//
//  Tests for Running session model and race predictor
//

import Testing
import Foundation
@testable import TetraTrack

struct RunningSessionTests {

    // MARK: - Basic Properties

    @Test func runningSessionInitialization() {
        let session = RunningSession()

        #expect(session.name == "")
        #expect(session.totalDistance == 0)
        #expect(session.totalDuration == 0)
    }

    @Test func runningSessionDefaults() {
        let session = RunningSession()

        #expect(session.totalDistance == 0)
        #expect(session.totalDuration == 0)
        #expect(session.averageCadence == 0)
    }

    // MARK: - Pace Calculations

    @Test func averagePaceCalculation() {
        let session = RunningSession()
        session.totalDistance = 5000 // 5km in meters
        session.totalDuration = 1500 // 25 minutes in seconds

        // Pace should be seconds per km = 1500 / 5 = 300 seconds per km (5:00/km)
        #expect(session.averagePace == 300)
    }

    @Test func averagePaceWithZeroDistance() {
        let session = RunningSession()
        session.totalDistance = 0
        session.totalDuration = 100

        #expect(session.averagePace == 0)
    }

    @Test func averageSpeedCalculation() {
        let session = RunningSession()
        session.totalDistance = 1000 // 1000 meters
        session.totalDuration = 250 // 250 seconds

        // Speed = 1000 / 250 = 4 m/s
        #expect(session.averageSpeed == 4.0)
    }

    // MARK: - Running Mode

    @Test func runningModeValues() {
        #expect(RunningMode.outdoor.rawValue == "Outdoor GPS")
        #expect(RunningMode.treadmill.rawValue == "Treadmill")
        #expect(RunningMode.track.rawValue == "Track")
        #expect(RunningMode.indoor.rawValue == "Indoor")
    }

    @Test func runningModeUsesGPS() {
        #expect(RunningMode.outdoor.usesGPS == true)
        #expect(RunningMode.treadmill.usesGPS == false)
        #expect(RunningMode.track.usesGPS == false)
        #expect(RunningMode.indoor.usesGPS == false)
    }

    // MARK: - Session Type

    @Test func runningSessionTypeValues() {
        #expect(RunningSessionType.easy.rawValue == "Easy Run")
        #expect(RunningSessionType.tempo.rawValue == "Tempo Run")
        #expect(RunningSessionType.intervals.rawValue == "Intervals")
        #expect(RunningSessionType.timeTrial.rawValue == "Time Trial")
    }

    @Test func runningSessionTypeCount() {
        #expect(RunningSessionType.allCases.count >= 8)
    }

    // MARK: - Pace Zones

    @Test func runningPaceZoneNames() {
        #expect(RunningPaceZone.recovery.name == "Recovery")
        #expect(RunningPaceZone.easy.name == "Easy")
        #expect(RunningPaceZone.aerobic.name == "Aerobic")
        #expect(RunningPaceZone.tempo.name == "Tempo")
        #expect(RunningPaceZone.threshold.name == "Threshold")
        #expect(RunningPaceZone.vo2max.name == "VO2max")
        #expect(RunningPaceZone.speed.name == "Speed")
    }

    @Test func runningPaceZoneCount() {
        #expect(RunningPaceZone.allCases.count == 7)
    }

    @Test func runningPaceZoneDetermination() {
        let thresholdPace: TimeInterval = 300 // 5:00/km

        // Speed zone: < 0.88 of threshold
        let speedPace: TimeInterval = 250
        #expect(RunningPaceZone.zone(for: speedPace, thresholdPace: thresholdPace) == .speed)

        // Threshold zone: 0.95-1.02 of threshold
        let thresholdZonePace: TimeInterval = 300
        #expect(RunningPaceZone.zone(for: thresholdZonePace, thresholdPace: thresholdPace) == .threshold)

        // Recovery zone: > 1.3 of threshold
        let recoveryPace: TimeInterval = 400
        #expect(RunningPaceZone.zone(for: recoveryPace, thresholdPace: thresholdPace) == .recovery)
    }

    // MARK: - Race Predictor

    @Test func racePredictorRiegelFormula() {
        // Riegel formula: T2 = T1 * (D2/D1)^1.06
        let timeTrial = TimeTrialResult(
            distance: 5000, // 5km
            time: 1200, // 20 minutes (20:00)
            date: Date()
        )
        let predictor = RacePredictor(recentTimeTrial: timeTrial)

        // Predict 1500m time
        let predicted1500 = predictor.predictTime(for: 1500)

        // Expected: 1200 * (1500/5000)^1.06 = 1200 * 0.3^1.06 ~ 341 seconds
        // Allow some tolerance for floating point
        #expect(predicted1500 > 300 && predicted1500 < 400)
    }

    @Test func racePredictorPaceCalculation() {
        let timeTrial = TimeTrialResult(
            distance: 5000,
            time: 1200,
            date: Date()
        )
        let predictor = RacePredictor(recentTimeTrial: timeTrial)

        // Predict pace for 5km (should match original)
        let pace = predictor.predictPace(for: 5000)

        // Original pace: 1200 / 5 = 240 seconds per km
        #expect(pace == 240)
    }

    // MARK: - Time Trial Result

    @Test func timeTrialResultPace() {
        let result = TimeTrialResult(
            distance: 5000,
            time: 1200,
            date: Date()
        )

        // Pace = 1200 / 5 = 240 seconds per km
        #expect(result.pace == 240)
    }

    // MARK: - 1500m Time Trial

    @Test func fifteenHundredTimeTrialPace() {
        let trial = FifteenHundredTimeTrial(
            time: 420, // 7 minutes
            date: Date(),
            splits: [84, 84, 84, 84, 84] // 5x 84s splits (300m each)
        )

        // Pace = 420 / 1.5 = 280 seconds per km (4:40/km)
        #expect(trial.pace == 280)
    }

    @Test func fifteenHundredTimeTrialFitnessLevel() {
        // Elite: under 4:00 (240 seconds)
        let eliteTrial = FifteenHundredTimeTrial(time: 230, date: Date(), splits: [])
        #expect(eliteTrial.fitnessLevel == "Elite")

        // Advanced: 4:00-4:30
        let advancedTrial = FifteenHundredTimeTrial(time: 260, date: Date(), splits: [])
        #expect(advancedTrial.fitnessLevel == "Advanced")

        // Intermediate: 4:30-5:00
        let intermediateTrial = FifteenHundredTimeTrial(time: 285, date: Date(), splits: [])
        #expect(intermediateTrial.fitnessLevel == "Intermediate")

        // Beginner: 5:00-6:00
        let beginnerTrial = FifteenHundredTimeTrial(time: 330, date: Date(), splits: [])
        #expect(beginnerTrial.fitnessLevel == "Beginner")

        // Novice: > 6:00
        let noviceTrial = FifteenHundredTimeTrial(time: 400, date: Date(), splits: [])
        #expect(noviceTrial.fitnessLevel == "Novice")
    }

    @Test func fifteenHundredTimeTrialRacePredictor() {
        let trial = FifteenHundredTimeTrial(
            time: 300, // 5 minutes
            date: Date(),
            splits: []
        )

        let predictor = trial.racePredictor

        // Should create predictor for 1500m with same time
        let predicted1500 = predictor.predictTime(for: 1500)
        #expect(predicted1500 == 300)
    }
}
