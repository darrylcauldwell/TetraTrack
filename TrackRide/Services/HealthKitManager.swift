//
//  HealthKitManager.swift
//  TrackRide
//

import HealthKit
import Observation
import CoreLocation
import os

@Observable
final class HealthKitManager {
    static let shared = HealthKitManager()

    var isAuthorized: Bool = false
    var isAvailable: Bool = HKHealthStore.isHealthDataAvailable()

    // Cached body measurements from HealthKit
    var healthKitWeight: Double?
    var healthKitHeight: Double?
    var healthKitSex: BiologicalSex?
    var healthKitDateOfBirth: Date?

    private let healthStore = HKHealthStore()

    // Data types we want to write
    private let writeTypes: Set<HKSampleType> = [
        HKObjectType.workoutType(),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.distanceSwimming),
        HKQuantityType(.swimmingStrokeCount),
        HKQuantityType(.activeEnergyBurned),
    ]

    // Data types we want to read
    private let readTypes: Set<HKObjectType> = [
        HKObjectType.workoutType(),
        HKQuantityType(.heartRate),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.bodyMass),
        HKQuantityType(.height),
        HKCharacteristicType(.biologicalSex),
        HKCharacteristicType(.dateOfBirth),
    ]

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }

        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            await MainActor.run {
                self.isAuthorized = true
            }
            return true
        } catch {
            Log.health.error("HealthKit authorization failed: \(error)")
            return false
        }
    }

    // MARK: - Read Body Measurements

    /// Fetch all body measurements from HealthKit
    func fetchBodyMeasurements() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchWeight() }
            group.addTask { await self.fetchHeight() }
            group.addTask { await self.fetchBiologicalSex() }
            group.addTask { await self.fetchDateOfBirth() }
        }
    }

    /// Fetch most recent weight from HealthKit
    func fetchWeight() async {
        guard isAvailable else { return }

        let weightType = HKQuantityType(.bodyMass)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: weightType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample, error == nil else {
                return
            }
            let weightKg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
            Task { @MainActor in
                self?.healthKitWeight = weightKg
            }
        }
        healthStore.execute(query)
    }

    /// Fetch most recent height from HealthKit
    func fetchHeight() async {
        guard isAvailable else { return }

        let heightType = HKQuantityType(.height)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: heightType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample, error == nil else {
                return
            }
            let heightCm = sample.quantity.doubleValue(for: .meterUnit(with: .centi))
            Task { @MainActor in
                self?.healthKitHeight = heightCm
            }
        }
        healthStore.execute(query)
    }

    /// Fetch biological sex from HealthKit
    func fetchBiologicalSex() async {
        guard isAvailable else { return }

        do {
            let biologicalSex = try healthStore.biologicalSex().biologicalSex
            let sex: BiologicalSex
            switch biologicalSex {
            case .female: sex = .female
            case .male: sex = .male
            case .other: sex = .other
            default: sex = .notSet
            }
            await MainActor.run {
                self.healthKitSex = sex
            }
        } catch {
            Log.health.debug("Could not fetch biological sex: \(error)")
        }
    }

    /// Fetch date of birth from HealthKit
    func fetchDateOfBirth() async {
        guard isAvailable else { return }

        do {
            let dateOfBirth = try healthStore.dateOfBirthComponents()
            if let date = Calendar.current.date(from: dateOfBirth) {
                await MainActor.run {
                    self.healthKitDateOfBirth = date
                }
            }
        } catch {
            Log.health.debug("Could not fetch date of birth: \(error)")
        }
    }

    /// Update a RiderProfile with HealthKit data
    func updateProfileFromHealthKit(_ profile: RiderProfile) async {
        await fetchBodyMeasurements()

        await MainActor.run {
            if let weight = healthKitWeight {
                profile.weight = weight
            }
            if let height = healthKitHeight {
                profile.height = height
            }
            if let sex = healthKitSex {
                profile.sex = sex
            }
            if let dob = healthKitDateOfBirth {
                profile.dateOfBirth = dob
            }
            profile.lastUpdatedFromHealthKit = Date()
        }
    }

    // MARK: - Save Workout

    func saveRideAsWorkout(_ ride: Ride, riderWeight: Double = 70.0) async -> Bool {
        guard isAvailable else {
            Log.health.warning("HealthKit not available")
            return false
        }

        guard let endDate = ride.endDate else {
            Log.health.warning("Ride has no end date")
            return false
        }

        do {
            // Create workout configuration
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .equestrianSports
            configuration.locationType = .outdoor

            // Create workout builder
            let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())

            try await builder.beginCollection(at: ride.startDate)

            // Add distance sample
            if ride.totalDistance > 0 {
                let distanceType = HKQuantityType(.distanceWalkingRunning)
                let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: ride.totalDistance)
                let distanceSample = HKQuantitySample(
                    type: distanceType,
                    quantity: distanceQuantity,
                    start: ride.startDate,
                    end: endDate
                )
                try await builder.addSamples([distanceSample])
            }

            // Calculate gait-adjusted calories using MET values
            let estimatedCalories = calculateGaitAdjustedCalories(ride: ride, weightKg: riderWeight)

            if estimatedCalories > 0 {
                let calorieType = HKQuantityType(.activeEnergyBurned)
                let calorieQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: estimatedCalories)
                let calorieSample = HKQuantitySample(
                    type: calorieType,
                    quantity: calorieQuantity,
                    start: ride.startDate,
                    end: endDate
                )
                try await builder.addSamples([calorieSample])
            }

            // Add route data if available
            if let locationPoints = ride.locationPoints, !locationPoints.isEmpty {
                let routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: .local())

                let locations = ride.sortedLocationPoints.map { point in
                    CLLocation(
                        coordinate: point.coordinate,
                        altitude: point.altitude,
                        horizontalAccuracy: point.horizontalAccuracy,
                        verticalAccuracy: point.horizontalAccuracy,
                        timestamp: point.timestamp
                    )
                }

                // Add locations in batches (HealthKit has limits)
                let batchSize = 100
                for i in stride(from: 0, to: locations.count, by: batchSize) {
                    let batch = Array(locations[i..<min(i + batchSize, locations.count)])
                    try await routeBuilder.insertRouteData(batch)
                }

                // Finish collection and get workout
                try await builder.endCollection(at: endDate)
                let workout = try await builder.finishWorkout()

                // Finish route and attach to workout
                if let workout = workout {
                    try await routeBuilder.finishRoute(with: workout, metadata: nil)
                }

                Log.health.info("Saved ride to HealthKit with route: \(workout?.uuid.uuidString ?? "unknown")")
                return true
            } else {
                // No route data, just save the workout
                try await builder.endCollection(at: endDate)
                let workout = try await builder.finishWorkout()
                Log.health.info("Saved ride to HealthKit: \(workout?.uuid.uuidString ?? "unknown")")
                return true
            }
        } catch {
            Log.health.error("Failed to save workout to HealthKit: \(error)")
            return false
        }
    }

    // MARK: - Save Running Session (including Treadmill)

    func saveRunningSessionAsWorkout(_ session: RunningSession, riderWeight: Double = 70.0) async -> Bool {
        guard isAvailable else {
            Log.health.warning("HealthKit not available")
            return false
        }

        guard let endDate = session.endDate else {
            Log.health.warning("Running session has no end date")
            return false
        }

        do {
            // Create workout configuration
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .running

            // Set location type based on run mode
            switch session.runMode {
            case .treadmill, .indoor:
                configuration.locationType = .indoor
            case .outdoor, .track:
                configuration.locationType = .outdoor
            }

            // Create workout builder
            let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())

            try await builder.beginCollection(at: session.startDate)

            // Add distance sample
            if session.totalDistance > 0 {
                let distanceType = HKQuantityType(.distanceWalkingRunning)
                let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: session.totalDistance)
                let distanceSample = HKQuantitySample(
                    type: distanceType,
                    quantity: distanceQuantity,
                    start: session.startDate,
                    end: endDate
                )
                try await builder.addSamples([distanceSample])
            }

            // Calculate calories using running MET values
            let estimatedCalories = calculateRunningCalories(
                duration: session.totalDuration,
                distanceMeters: session.totalDistance,
                incline: session.treadmillIncline,
                weightKg: riderWeight
            )

            if estimatedCalories > 0 {
                let calorieType = HKQuantityType(.activeEnergyBurned)
                let calorieQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: estimatedCalories)
                let calorieSample = HKQuantitySample(
                    type: calorieType,
                    quantity: calorieQuantity,
                    start: session.startDate,
                    end: endDate
                )
                try await builder.addSamples([calorieSample])
            }

            // Finish collection and save workout
            try await builder.endCollection(at: endDate)

            // Add metadata for treadmill workouts
            var metadata: [String: Any] = [
                HKMetadataKeyIndoorWorkout: (session.runMode == .treadmill || session.runMode == .indoor)
            ]

            if let incline = session.treadmillIncline, incline > 0 {
                metadata["TreadmillIncline"] = incline
            }

            let workout = try await builder.finishWorkout()
            Log.health.info("Saved running session to HealthKit: \(workout?.uuid.uuidString ?? "unknown")")
            return true
        } catch {
            Log.health.error("Failed to save running session to HealthKit: \(error)")
            return false
        }
    }

    // MARK: - Save Swimming Session

    func saveSwimmingSessionAsWorkout(_ session: SwimmingSession, riderWeight: Double = 70.0) async -> Bool {
        guard isAvailable else {
            Log.health.warning("HealthKit not available")
            return false
        }

        guard let endDate = session.endDate else {
            Log.health.warning("Swimming session has no end date")
            return false
        }

        do {
            // Create workout configuration
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .swimming

            // Set location type based on pool mode
            switch session.poolMode {
            case .pool:
                configuration.locationType = .indoor
                configuration.swimmingLocationType = .pool
                configuration.lapLength = HKQuantity(unit: .meter(), doubleValue: session.poolLength)
            case .openWater:
                configuration.locationType = .outdoor
                configuration.swimmingLocationType = .openWater
            }

            // Create workout builder
            let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())

            try await builder.beginCollection(at: session.startDate)

            // Add distance sample
            if session.totalDistance > 0 {
                let distanceType = HKQuantityType(.distanceSwimming)
                let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: session.totalDistance)
                let distanceSample = HKQuantitySample(
                    type: distanceType,
                    quantity: distanceQuantity,
                    start: session.startDate,
                    end: endDate
                )
                try await builder.addSamples([distanceSample])
            }

            // Add stroke count sample
            if session.totalStrokes > 0 {
                let strokeType = HKQuantityType(.swimmingStrokeCount)
                let strokeQuantity = HKQuantity(unit: .count(), doubleValue: Double(session.totalStrokes))
                let strokeSample = HKQuantitySample(
                    type: strokeType,
                    quantity: strokeQuantity,
                    start: session.startDate,
                    end: endDate
                )
                try await builder.addSamples([strokeSample])
            }

            // Calculate calories using swimming MET values
            let estimatedCalories = calculateSwimmingCalories(
                duration: session.totalDuration,
                distanceMeters: session.totalDistance,
                stroke: session.dominantStroke,
                weightKg: riderWeight
            )

            if estimatedCalories > 0 {
                let calorieType = HKQuantityType(.activeEnergyBurned)
                let calorieQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: estimatedCalories)
                let calorieSample = HKQuantitySample(
                    type: calorieType,
                    quantity: calorieQuantity,
                    start: session.startDate,
                    end: endDate
                )
                try await builder.addSamples([calorieSample])
            }

            // Finish collection and save workout
            try await builder.endCollection(at: endDate)

            // Add metadata
            var metadata: [String: Any] = [
                HKMetadataKeyIndoorWorkout: session.isIndoor,
                HKMetadataKeyLapLength: session.poolLength
            ]

            if session.averageSwolf > 0 {
                metadata["AverageSwolf"] = session.averageSwolf
            }

            let workout = try await builder.finishWorkout()
            Log.health.info("Saved swimming session to HealthKit: \(workout?.uuid.uuidString ?? "unknown")")
            return true
        } catch {
            Log.health.error("Failed to save swimming session to HealthKit: \(error)")
            return false
        }
    }

    /// Calculate calories for swimming workouts based on stroke type and intensity
    private func calculateSwimmingCalories(duration: TimeInterval, distanceMeters: Double, stroke: SwimmingStroke, weightKg: Double) -> Double {
        guard duration > 0 else { return 0 }

        // Calculate pace to determine intensity (seconds per 100m)
        let pace = distanceMeters > 0 ? duration / (distanceMeters / 100) : 180 // default 3:00/100m

        // Base MET values for swimming strokes at moderate intensity
        var baseMET: Double
        switch stroke {
        case .freestyle:
            baseMET = 8.0
        case .backstroke:
            baseMET = 7.0
        case .breaststroke:
            baseMET = 8.5
        case .butterfly:
            baseMET = 11.0
        case .individual, .mixed:
            baseMET = 8.5
        }

        // Adjust MET based on pace/intensity
        // Slower pace = lower MET, faster pace = higher MET
        var met: Double
        switch pace {
        case ..<90:
            // Very fast (elite) - increase MET by 30%
            met = baseMET * 1.3
        case 90..<105:
            // Fast (advanced) - increase MET by 15%
            met = baseMET * 1.15
        case 105..<120:
            // Moderate (intermediate) - base MET
            met = baseMET
        case 120..<150:
            // Slow (beginner) - decrease MET by 15%
            met = baseMET * 0.85
        default:
            // Very slow (novice) - decrease MET by 30%
            met = baseMET * 0.7
        }

        // Calories = MET × weight (kg) × time (hours)
        let hours = duration / 3600
        return met * weightKg * hours
    }

    /// Calculate calories for running workouts
    private func calculateRunningCalories(duration: TimeInterval, distanceMeters: Double, incline: Double?, weightKg: Double) -> Double {
        // Base MET for running varies by speed
        // Walking: 3-4 MET, Jogging: 7 MET, Running: 8-12 MET

        guard duration > 0 else { return 0 }

        let speedKmh = (distanceMeters / 1000) / (duration / 3600)
        var met: Double

        // Estimate MET based on speed
        switch speedKmh {
        case ..<6:
            met = 4.0  // Walking
        case 6..<8:
            met = 6.0  // Fast walk / slow jog
        case 8..<10:
            met = 8.5  // Jogging
        case 10..<12:
            met = 10.0 // Running
        case 12..<14:
            met = 11.5 // Fast running
        default:
            met = 13.0 // Very fast running
        }

        // Adjust for incline (adds ~0.9 MET per 1% grade)
        if let incline = incline, incline > 0 {
            met += incline * 0.9
        }

        // Calories = MET × weight (kg) × time (hours)
        let hours = duration / 3600
        return met * weightKg * hours
    }

    // MARK: - Check Authorization Status

    func checkAuthorizationStatus() {
        guard isAvailable else {
            isAuthorized = false
            return
        }

        // Check if we can write workouts
        let workoutType = HKObjectType.workoutType()
        let status = healthStore.authorizationStatus(for: workoutType)
        isAuthorized = (status == .sharingAuthorized)
    }

    // MARK: - Calorie Calculation

    /// Calculate calories using gait-specific MET values
    /// More accurate than a fixed calorie-per-hour estimate
    func calculateGaitAdjustedCalories(ride: Ride, weightKg: Double) -> Double {
        guard let gaitSegments = ride.gaitSegments, !gaitSegments.isEmpty else {
            // Fallback: use average MET if no gait data
            let averageMET = 4.0  // Moderate riding effort
            return RidingMETValues.calories(met: averageMET, weightKg: weightKg, durationSeconds: ride.totalDuration)
        }

        var totalCalories = 0.0

        for segment in gaitSegments {
            let met = RidingMETValues.met(for: segment.gait)
            let segmentCalories = RidingMETValues.calories(met: met, weightKg: weightKg, durationSeconds: segment.duration)
            totalCalories += segmentCalories
        }

        return totalCalories
    }

    /// Estimate calories for a ride (for display purposes)
    func estimateCalories(ride: Ride, weightKg: Double) -> Double {
        return calculateGaitAdjustedCalories(ride: ride, weightKg: weightKg)
    }

    /// Get calorie breakdown by gait
    func calorieBreakdownByGait(ride: Ride, weightKg: Double) -> [(gait: GaitType, calories: Double, percentage: Double)] {
        guard let gaitSegments = ride.gaitSegments, !gaitSegments.isEmpty else {
            return []
        }

        var caloriesByGait: [GaitType: Double] = [:]

        for segment in gaitSegments {
            let met = RidingMETValues.met(for: segment.gait)
            let segmentCalories = RidingMETValues.calories(met: met, weightKg: weightKg, durationSeconds: segment.duration)
            caloriesByGait[segment.gait, default: 0] += segmentCalories
        }

        let totalCalories = caloriesByGait.values.reduce(0, +)
        guard totalCalories > 0 else { return [] }

        return caloriesByGait.map { gait, calories in
            (gait: gait, calories: calories, percentage: (calories / totalCalories) * 100)
        }.sorted { $0.calories > $1.calories }
    }
}
