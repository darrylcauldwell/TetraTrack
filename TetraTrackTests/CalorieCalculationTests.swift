//
//  CalorieCalculationTests.swift
//  TetraTrackTests
//
//  Tests for calorie calculations across different activities
//

import Testing
import Foundation
@testable import TetraTrack

struct CalorieCalculationTests {

    // MARK: - Riding MET Values

    @Test func ridingMETValuesDefinition() {
        #expect(RidingMETValues.stationary == 1.5)
        #expect(RidingMETValues.walk == 2.5)
        #expect(RidingMETValues.trot == 5.5)
        #expect(RidingMETValues.canter == 7.0)
        #expect(RidingMETValues.gallop == 8.5)
    }

    @Test func ridingMETForGait() {
        #expect(RidingMETValues.met(for: .stationary) == 1.5)
        #expect(RidingMETValues.met(for: .walk) == 2.5)
        #expect(RidingMETValues.met(for: .trot) == 5.5)
        #expect(RidingMETValues.met(for: .canter) == 7.0)
        #expect(RidingMETValues.met(for: .gallop) == 8.5)
    }

    @Test func ridingCalorieCalculation() {
        // Calories = MET × weight (kg) × time (hours)
        let met = 5.5 // Trot
        let weightKg = 70.0
        let durationSeconds: TimeInterval = 3600 // 1 hour

        let calories = RidingMETValues.calories(met: met, weightKg: weightKg, durationSeconds: durationSeconds)

        // Expected: 5.5 × 70 × 1 = 385 calories
        #expect(calories == 385)
    }

    @Test func ridingCalorieCalculationHalfHour() {
        let met = 7.0 // Canter
        let weightKg = 60.0
        let durationSeconds: TimeInterval = 1800 // 30 minutes

        let calories = RidingMETValues.calories(met: met, weightKg: weightKg, durationSeconds: durationSeconds)

        // Expected: 7.0 × 60 × 0.5 = 210 calories
        #expect(calories == 210)
    }

    // MARK: - Gait Type

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

    // MARK: - Swimming MET Values (Conceptual - based on HealthKitManager)

    @Test func swimmingMETValueRanges() {
        // Base MET values for swimming strokes
        // Freestyle: 8.0, Backstroke: 7.0, Breaststroke: 8.5, Butterfly: 11.0

        let freestyleMET = 8.0
        let backstrokeMET = 7.0
        let breaststrokeMET = 8.5
        let butterflyMET = 11.0

        #expect(freestyleMET > backstrokeMET)
        #expect(butterflyMET > breaststrokeMET)
        #expect(butterflyMET > freestyleMET)
    }

    @Test func swimmingCalorieEstimate() {
        // Formula: Calories = MET × weight (kg) × time (hours)
        let met = 8.0 // Freestyle
        let weightKg = 70.0
        let durationSeconds: TimeInterval = 1800 // 30 minutes

        let hours = durationSeconds / 3600
        let calories = met * weightKg * hours

        // Expected: 8.0 × 70 × 0.5 = 280 calories
        #expect(calories == 280)
    }

    // MARK: - Running MET Values (Conceptual - based on HealthKitManager)

    @Test func runningMETValuesBySpeed() {
        // MET values vary by speed:
        // < 6 km/h: 4.0 (Walking)
        // 6-8 km/h: 6.0 (Fast walk/slow jog)
        // 8-10 km/h: 8.5 (Jogging)
        // 10-12 km/h: 10.0 (Running)
        // 12-14 km/h: 11.5 (Fast running)
        // > 14 km/h: 13.0 (Very fast running)

        let walkingMET = 4.0
        let joggingMET = 8.5
        let runningMET = 10.0
        let fastRunningMET = 11.5

        #expect(joggingMET > walkingMET)
        #expect(runningMET > joggingMET)
        #expect(fastRunningMET > runningMET)
    }

    @Test func runningInclineAdjustment() {
        // Incline adds ~0.9 MET per 1% grade
        let baseMET = 10.0
        let inclinePercent = 5.0
        let inclineAdjustment = inclinePercent * 0.9

        let adjustedMET = baseMET + inclineAdjustment

        // Expected: 10.0 + 4.5 = 14.5
        #expect(adjustedMET == 14.5)
    }

    @Test func runningCalorieEstimate() {
        // Formula: Calories = MET × weight (kg) × time (hours)
        let met = 10.0 // Running
        let weightKg = 70.0
        let durationSeconds: TimeInterval = 2700 // 45 minutes

        let hours = durationSeconds / 3600
        let calories = met * weightKg * hours

        // Expected: 10.0 × 70 × 0.75 = 525 calories
        #expect(calories == 525)
    }

    // MARK: - Weight Impact on Calories

    @Test func weightImpactOnCalories() {
        let met = 7.0
        let durationHours = 1.0

        let lightWeight = 55.0
        let heavyWeight = 85.0

        let lightCalories = met * lightWeight * durationHours
        let heavyCalories = met * heavyWeight * durationHours

        // Heavier person burns more calories
        #expect(heavyCalories > lightCalories)
        #expect(lightCalories == 385) // 7.0 × 55 × 1
        #expect(heavyCalories == 595) // 7.0 × 85 × 1
    }

    // MARK: - Duration Impact on Calories

    @Test func durationImpactOnCalories() {
        let met = 8.0
        let weightKg = 70.0

        let shortDuration: TimeInterval = 1800 // 30 minutes
        let longDuration: TimeInterval = 3600 // 60 minutes

        let shortCalories = met * weightKg * (shortDuration / 3600)
        let longCalories = met * weightKg * (longDuration / 3600)

        // Longer duration = more calories
        #expect(longCalories == shortCalories * 2)
    }

    // MARK: - Zero Duration Edge Case

    @Test func zeroDurationCalories() {
        let met = 7.0
        let weightKg = 70.0
        let durationSeconds: TimeInterval = 0

        let hours = durationSeconds / 3600
        let calories = met * weightKg * hours

        #expect(calories == 0)
    }
}
