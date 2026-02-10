//
//  HeartRateTests.swift
//  TetraTrackTests
//
//  Tests for Heart Rate zones, samples, statistics, and validator
//

import Testing
import Foundation
@testable import TetraTrack

struct HeartRateTests {

    // MARK: - Heart Rate Zone Tests

    @Test func heartRateZoneNames() {
        #expect(HeartRateZone.zone1.name == "Recovery")
        #expect(HeartRateZone.zone2.name == "Light")
        #expect(HeartRateZone.zone3.name == "Moderate")
        #expect(HeartRateZone.zone4.name == "Hard")
        #expect(HeartRateZone.zone5.name == "Maximum")
    }

    @Test func heartRateZoneDescriptions() {
        #expect(HeartRateZone.zone1.description == "Warm-up & recovery")
        #expect(HeartRateZone.zone2.description == "Light activity, fat burning")
        #expect(HeartRateZone.zone3.description == "Aerobic endurance")
        #expect(HeartRateZone.zone4.description == "Anaerobic training")
        #expect(HeartRateZone.zone5.description == "Peak performance")
    }

    @Test func heartRateZoneColors() {
        #expect(HeartRateZone.zone1.colorName == "gray")
        #expect(HeartRateZone.zone2.colorName == "blue")
        #expect(HeartRateZone.zone3.colorName == "green")
        #expect(HeartRateZone.zone4.colorName == "orange")
        #expect(HeartRateZone.zone5.colorName == "red")
    }

    @Test func heartRateZonePercentageRanges() {
        #expect(HeartRateZone.zone1.percentageRange == 0.50...0.60)
        #expect(HeartRateZone.zone2.percentageRange == 0.60...0.70)
        #expect(HeartRateZone.zone3.percentageRange == 0.70...0.80)
        #expect(HeartRateZone.zone4.percentageRange == 0.80...0.90)
        #expect(HeartRateZone.zone5.percentageRange == 0.90...1.00)
    }

    @Test func heartRateZoneCount() {
        #expect(HeartRateZone.allCases.count == 5)
    }

    // MARK: - Zone Calculation Tests

    @Test func zoneCalculationForMaxHR180() {
        let maxHR = 180

        // Zone 1: 50-60% = 90-108 BPM
        #expect(HeartRateZone.zone(for: 100, maxHR: maxHR) == .zone1)

        // Zone 2: 60-70% = 108-126 BPM
        #expect(HeartRateZone.zone(for: 115, maxHR: maxHR) == .zone2)

        // Zone 3: 70-80% = 126-144 BPM
        #expect(HeartRateZone.zone(for: 135, maxHR: maxHR) == .zone3)

        // Zone 4: 80-90% = 144-162 BPM
        #expect(HeartRateZone.zone(for: 150, maxHR: maxHR) == .zone4)

        // Zone 5: 90-100% = 162-180 BPM
        #expect(HeartRateZone.zone(for: 170, maxHR: maxHR) == .zone5)
    }

    @Test func zoneCalculationBelowZone1() {
        // Very low HR should still be zone 1
        #expect(HeartRateZone.zone(for: 60, maxHR: 180) == .zone1)
    }

    @Test func zoneCalculationWithZeroMaxHR() {
        // Edge case: zero max HR should default to zone 1
        #expect(HeartRateZone.zone(for: 100, maxHR: 0) == .zone1)
    }

    @Test func zoneBoundariesCalculation() {
        let boundaries = HeartRateZone.zoneBoundaries(for: 200)

        #expect(boundaries.count == 5)
        #expect(boundaries[0].zone == .zone1)
        #expect(boundaries[0].minBPM == 100) // 50% of 200
        #expect(boundaries[0].maxBPM == 120) // 60% of 200
    }

    // MARK: - Max Heart Rate Calculator Tests

    @Test func tanakaFormula() {
        // Tanaka: 208 - (0.7 × age)
        #expect(MaxHeartRateCalculator.tanaka(age: 40) == 180) // 208 - 28 = 180
        #expect(MaxHeartRateCalculator.tanaka(age: 30) == 187) // 208 - 21 = 187
        #expect(MaxHeartRateCalculator.tanaka(age: 50) == 173) // 208 - 35 = 173
    }

    @Test func traditionalFormula() {
        // Traditional: 220 - age
        #expect(MaxHeartRateCalculator.traditional(age: 40) == 180)
        #expect(MaxHeartRateCalculator.traditional(age: 30) == 190)
        #expect(MaxHeartRateCalculator.traditional(age: 50) == 170)
    }

    @Test func gulatiFormula() {
        // Gulati (women): 206 - (0.88 × age)
        #expect(MaxHeartRateCalculator.gulati(age: 40) == 170) // 206 - 35.2 = 170
        #expect(MaxHeartRateCalculator.gulati(age: 30) == 179) // 206 - 26.4 = 179
    }

    // MARK: - Heart Rate Sample Tests

    @Test func heartRateSampleCreation() {
        let sample = HeartRateSample(bpm: 140, maxHeartRate: 180)

        #expect(sample.bpm == 140)
        #expect(sample.zone == .zone3) // 140/180 = 77.8% = Zone 3
    }

    @Test func heartRateSampleWithHighBPM() {
        let sample = HeartRateSample(bpm: 175, maxHeartRate: 180)

        #expect(sample.bpm == 175)
        #expect(sample.zone == .zone5) // 175/180 = 97.2% = Zone 5
    }

    // MARK: - Heart Rate Statistics Tests

    @Test func heartRateStatisticsEmpty() {
        let stats = HeartRateStatistics(samples: [])

        #expect(stats.minBPM == 0)
        #expect(stats.maxBPM == 0)
        #expect(stats.averageBPM == 0)
        #expect(stats.samples.isEmpty)
    }

    @Test func heartRateStatisticsWithSamples() {
        let samples = [
            HeartRateSample(bpm: 120, maxHeartRate: 180),
            HeartRateSample(bpm: 140, maxHeartRate: 180),
            HeartRateSample(bpm: 160, maxHeartRate: 180)
        ]

        let stats = HeartRateStatistics(samples: samples)

        #expect(stats.minBPM == 120)
        #expect(stats.maxBPM == 160)
        #expect(stats.averageBPM == 140) // (120 + 140 + 160) / 3
    }

    @Test func heartRateStatisticsPrimaryZone() {
        // Create samples mostly in zone 3
        var samples: [HeartRateSample] = []
        for _ in 0..<10 {
            samples.append(HeartRateSample(bpm: 135, maxHeartRate: 180)) // Zone 3
        }
        samples.append(HeartRateSample(bpm: 110, maxHeartRate: 180)) // Zone 2

        let stats = HeartRateStatistics(samples: samples)

        #expect(stats.primaryZone == .zone3)
    }

    // MARK: - Heart Rate Validator Tests

    @Test func heartRateValidatorValidRange() {
        #expect(HeartRateValidator.validRange == 30...220)
    }

    @Test func heartRateValidatorMaxRateOfChange() {
        #expect(HeartRateValidator.maxRateOfChange == 20.0)
    }

    @Test func heartRateValidatorSpikeThreshold() {
        #expect(HeartRateValidator.spikeThreshold == 15.0)
    }

    @Test func heartRateValidatorStabilityWindow() {
        #expect(HeartRateValidator.stabilityWindowSeconds == 5.0)
    }

    @Test func heartRateValidatorValidSample() {
        var validator = HeartRateValidator()

        let result1 = validator.validate(100)
        #expect(result1 == .noHistory) // First sample has no history

        let result2 = validator.validate(105)
        #expect(result2 == .valid)
    }

    @Test func heartRateValidatorOutOfRange() {
        var validator = HeartRateValidator()

        let tooLow = validator.validate(20)
        #expect(tooLow == .outOfRange)

        let tooHigh = validator.validate(250)
        #expect(tooHigh == .outOfRange)
    }

    @Test func heartRateValidatorReset() {
        var validator = HeartRateValidator()
        _ = validator.validate(100)
        _ = validator.validate(110)

        #expect(validator.latestHeartRate == 110)

        validator.reset()

        #expect(validator.latestHeartRate == nil)
    }

    @Test func heartRateValidatorLatestHeartRate() {
        var validator = HeartRateValidator()

        #expect(validator.latestHeartRate == nil)

        _ = validator.validate(100)
        #expect(validator.latestHeartRate == 100)

        _ = validator.validate(120)
        #expect(validator.latestHeartRate == 120)
    }
}
