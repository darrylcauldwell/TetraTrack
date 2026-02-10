//
//  RunnerBiomechanicsTests.swift
//  TetraTrackTests
//
//  Tests for personalised running biomechanics calculations
//

import Testing
import Foundation
@testable import TetraTrack

struct RunnerBiomechanicsTests {

    // MARK: - Default Values

    @Test func defaultValuesMatchLegacyBehaviour() {
        let bio = RunnerBiomechanics()
        #expect(bio.bodyMassKg == 70.0)
        #expect(bio.heightCm == 170.0)
    }

    @Test func nilProfileUsesDefaults() {
        let bio = RunnerBiomechanics(profile: nil)
        #expect(bio.bodyMassKg == 70.0)
        #expect(bio.heightCm == 170.0)
        #expect(bio.maxHeartRate == 180)
        #expect(bio.restingHeartRate == 60)
    }

    // MARK: - Leg Length

    @Test func legLengthCalculation() {
        let bio = RunnerBiomechanics(heightCm: 180.0)
        let expected = 1.80 * 0.53
        #expect(abs(bio.legLengthM - expected) < 0.001)
    }

    @Test func legLengthScalesWithHeight() {
        let short = RunnerBiomechanics(heightCm: 155.0)
        let tall = RunnerBiomechanics(heightCm: 190.0)
        #expect(short.legLengthM < tall.legLengthM)
    }

    // MARK: - Frontal Area

    @Test func frontalAreaScalesWithHeight() {
        let short = RunnerBiomechanics(bodyMassKg: 70.0, heightCm: 155.0)
        let tall = RunnerBiomechanics(bodyMassKg: 70.0, heightCm: 190.0)
        #expect(short.frontalArea < tall.frontalArea)
    }

    @Test func frontalAreaScalesWithMass() {
        let light = RunnerBiomechanics(bodyMassKg: 55.0, heightCm: 170.0)
        let heavy = RunnerBiomechanics(bodyMassKg: 85.0, heightCm: 170.0)
        #expect(light.frontalArea < heavy.frontalArea)
    }

    @Test func frontalAreaReasonableRange() {
        // Typical frontal area for adult runner: 0.3-0.6 m^2
        let bio = RunnerBiomechanics(bodyMassKg: 70.0, heightCm: 170.0)
        #expect(bio.frontalArea > 0.3)
        #expect(bio.frontalArea < 0.6)
    }

    // MARK: - Running Power

    @Test func powerUsesActualBodyMass() {
        let session = RunningSession()
        session.totalDistance = 5000
        session.totalDuration = 1500  // 5:00/km

        let light = RunnerBiomechanics(bodyMassKg: 55.0, heightCm: 170.0)
        let heavy = RunnerBiomechanics(bodyMassKg: 85.0, heightCm: 170.0)

        let lightPower = light.estimatedRunningPower(from: session)
        let heavyPower = heavy.estimatedRunningPower(from: session)

        #expect(lightPower > 0)
        #expect(heavyPower > lightPower, "Heavier runner should require more power at same speed")
    }

    @Test func powerZeroForStationarySession() {
        let session = RunningSession()
        session.totalDistance = 0
        session.totalDuration = 100

        let bio = RunnerBiomechanics()
        #expect(bio.estimatedRunningPower(from: session) == 0)
    }

    // MARK: - Watts per kg

    @Test func wattsPerKgUsesActualMass() {
        let light = RunnerBiomechanics(bodyMassKg: 55.0)
        let heavy = RunnerBiomechanics(bodyMassKg: 85.0)

        let lightWpk = light.wattsPerKg(power: 200)
        let heavyWpk = heavy.wattsPerKg(power: 200)

        #expect(lightWpk > heavyWpk, "Lighter runner should have higher W/kg for same absolute power")
        #expect(abs(lightWpk - 200.0 / 55.0) < 0.01)
    }

    // MARK: - Training Stress (TSS)

    @Test func tssUsesLTHR() {
        // 1 hour at LTHR should give ~100 TSS
        let bio = RunnerBiomechanics(maxHeartRate: 190)
        let session = RunningSession()
        session.totalDuration = 3600 // 1 hour
        session.averageHeartRate = Int(bio.estimatedLTHR)

        let tss = bio.trainingStress(from: session)
        // TSS = 1 * (LTHR/LTHR)^2 * 100 = 100
        #expect(abs(tss - 100) < 1)
    }

    @Test func tssHigherAboveLTHR() {
        let bio = RunnerBiomechanics(maxHeartRate: 190)
        let easySession = RunningSession()
        easySession.totalDuration = 3600
        easySession.averageHeartRate = 130

        let hardSession = RunningSession()
        hardSession.totalDuration = 3600
        hardSession.averageHeartRate = 175

        let easyTSS = bio.trainingStress(from: easySession)
        let hardTSS = bio.trainingStress(from: hardSession)

        #expect(hardTSS > easyTSS, "Higher HR should produce higher TSS")
    }

    @Test func tssZeroWithNoHR() {
        let bio = RunnerBiomechanics()
        let session = RunningSession()
        session.totalDuration = 3600
        session.averageHeartRate = 0

        #expect(bio.trainingStress(from: session) == 0)
    }

    // MARK: - Intensity Factor

    @Test func intensityFactorRelativeToLTHR() {
        let bio = RunnerBiomechanics(maxHeartRate: 200)
        // LTHR = 0.85 * 200 = 170
        let if_ = bio.intensityFactor(averageHR: 170)
        #expect(abs(if_ - 1.0) < 0.01, "IF at LTHR should be 1.0")
    }

    // MARK: - Cadence

    @Test func referenceHeightGivesCadenceCenter180() {
        let bio = RunnerBiomechanics(heightCm: 170.0)
        #expect(abs(bio.optimalCadenceCenter - 180.0) < 0.5)
    }

    @Test func shorterRunnerHasHigherOptimalCadence() {
        let short = RunnerBiomechanics(heightCm: 155.0)
        let tall = RunnerBiomechanics(heightCm: 190.0)
        #expect(short.optimalCadenceCenter > tall.optimalCadenceCenter)
    }

    @Test func cadenceScoreOptimalInRange() {
        let bio = RunnerBiomechanics(heightCm: 170.0)
        // 180 should be optimal for 170cm
        #expect(bio.cadenceScore(cadence: 180) == 95)
    }

    @Test func cadenceScorePenalisesOutOfRange() {
        let bio = RunnerBiomechanics(heightCm: 170.0)
        let optimalScore = bio.cadenceScore(cadence: 180)
        let farScore = bio.cadenceScore(cadence: 140)
        #expect(farScore < optimalScore)
    }

    @Test func isCadenceOptimalWorks() {
        let bio = RunnerBiomechanics(heightCm: 170.0)
        #expect(bio.isCadenceOptimal(180) == true)
        #expect(bio.isCadenceOptimal(140) == false)
    }

    // MARK: - Stride Length

    @Test func strideScoreOptimalForMatchingLegLength() {
        let bio = RunnerBiomechanics(heightCm: 170.0)
        // Optimal: 1.8-2.5x leg length
        // Leg length at 170cm = 0.901m
        // Optimal stride: 1.62-2.25m
        let optimalStride = bio.legLengthM * 2.0
        #expect(bio.strideLengthScore(strideLength: optimalStride) == 90)
    }

    @Test func strideScorePenalisesShortForTallRunner() {
        let tall = RunnerBiomechanics(heightCm: 190.0)
        // Tall leg length = 1.007m, optimal stride = 1.81-2.52m
        // 1.0m stride should be short for tall runner
        let score = tall.strideLengthScore(strideLength: 1.0)
        #expect(score < 90, "Short stride for tall runner should score below optimal")
    }

    @Test func strideScoreAcceptsLongerStrideForTallRunner() {
        let tall = RunnerBiomechanics(heightCm: 190.0)
        // 2.0m stride is within optimal for tall runner
        let score = tall.strideLengthScore(strideLength: 2.0)
        #expect(score == 90, "2.0m stride should be optimal for 190cm runner")
    }

    // MARK: - Vertical Ratio

    @Test func verticalRatioCalculation() {
        let bio = RunnerBiomechanics()
        // 8cm oscillation, 1.0m stride
        // VR = (8/100) / 1.0 * 100 = 8%
        let vr = bio.verticalRatio(oscillation: 8.0, strideLength: 1.0)
        #expect(abs(vr - 8.0) < 0.01)
    }

    @Test func verticalRatioZeroWithNoStride() {
        let bio = RunnerBiomechanics()
        #expect(bio.verticalRatio(oscillation: 8.0, strideLength: 0) == 0)
    }

    // MARK: - Oscillation Score

    @Test func oscillationScoreUsesRatioWhenStrideAvailable() {
        let bio = RunnerBiomechanics()
        // With long stride, 8cm oscillation gives lower ratio -> better score
        let scoreWithStride = bio.oscillationScore(oscillation: 8.0, strideLength: 1.5)
        // VR = (8/100)/1.5*100 = 5.3% -> elite -> 95
        #expect(scoreWithStride == 95)
    }

    @Test func oscillationScoreFallsBackToAbsoluteWithoutStride() {
        let bio = RunnerBiomechanics()
        let score = bio.oscillationScore(oscillation: 9.0)
        // 9cm, no stride -> uses absolute: 8-10 range -> 70
        #expect(score == 70)
    }

    // MARK: - Stride Ratio

    @Test func strideRatioCalculation() {
        let bio = RunnerBiomechanics(heightCm: 170.0)
        let ratio = bio.strideRatio(strideLength: 1.8)
        let expected = 1.8 / bio.legLengthM
        #expect(abs(ratio - expected) < 0.001)
    }

    // MARK: - LTHR

    @Test func lthrIs85PercentOfMax() {
        let bio = RunnerBiomechanics(maxHeartRate: 200)
        #expect(abs(bio.estimatedLTHR - 170.0) < 0.01)
    }

    // MARK: - Formatted Ranges

    @Test func formattedCadenceRange() {
        let bio = RunnerBiomechanics(heightCm: 170.0)
        // Centre ~180, range 170-190
        #expect(bio.formattedCadenceRange == "170-190")
    }

    @Test func formattedStrideRange() {
        let bio = RunnerBiomechanics(heightCm: 170.0)
        // Leg = 0.901m, range = 1.62-2.25m
        let range = bio.formattedStrideRange
        #expect(range.contains("-"))
        #expect(range.hasSuffix("m"))
    }
}
