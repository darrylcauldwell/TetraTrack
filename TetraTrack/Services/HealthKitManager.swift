//
//  HealthKitManager.swift
//  TetraTrack
//

import HealthKit
import Observation
import CoreLocation
import os

@Observable
@MainActor
final class HealthKitManager {
    static let shared = HealthKitManager()

    var isAuthorized: Bool = false
    var isAvailable: Bool = HKHealthStore.isHealthDataAvailable()

    // Cached body measurements from HealthKit
    var healthKitWeight: Double?
    var healthKitHeight: Double?
    var healthKitSex: BiologicalSex?
    var healthKitDateOfBirth: Date?

    /// Whether user has explicitly connected to HealthKit (persisted)
    var hasConnectedToHealthKit: Bool {
        get { UserDefaults.standard.bool(forKey: "hasConnectedToHealthKit") }
        set { UserDefaults.standard.set(newValue, forKey: "hasConnectedToHealthKit") }
    }

    /// Whether Apple Watch running metrics are available (cached)
    /// When true, we can rely on HealthKit for accurate post-session metrics
    /// When false, phone IMU provides the only running form data
    var hasAppleWatchRunningData: Bool {
        get { UserDefaults.standard.bool(forKey: "hasAppleWatchRunningData") }
        set { UserDefaults.standard.set(newValue, forKey: "hasAppleWatchRunningData") }
    }

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
        // Workouts
        HKObjectType.workoutType(),

        // Body measurements
        HKQuantityType(.bodyMass),
        HKQuantityType(.height),
        HKCharacteristicType(.biologicalSex),
        HKCharacteristicType(.dateOfBirth),

        // Heart metrics
        HKQuantityType(.heartRate),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.heartRateVariabilitySDNN),

        // Fitness metrics
        HKQuantityType(.vo2Max),
        HKQuantityType(.activeEnergyBurned),

        // Running metrics (Apple Watch)
        HKQuantityType(.walkingAsymmetryPercentage),
        HKQuantityType(.runningGroundContactTime),
        HKQuantityType(.runningVerticalOscillation),
        HKQuantityType(.runningStrideLength),
        HKQuantityType(.runningPower),
        HKQuantityType(.runningSpeed),
        HKQuantityType(.stepCount),

        // Sleep (for recovery insights)
        HKCategoryType(.sleepAnalysis),
    ]

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }

        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            await MainActor.run {
                self.isAuthorized = true
                self.hasConnectedToHealthKit = true
            }
            // Check if user has Apple Watch running data
            await detectAppleWatchRunningData()
            return true
        } catch {
            Log.health.error("HealthKit authorization failed: \(error)")
            return false
        }
    }

    // MARK: - Apple Watch Detection

    /// Check if user has Apple Watch running data in HealthKit
    /// Looks for watch-specific metrics (runningGroundContactTime, runningPower)
    /// that are only available from Apple Watch
    func detectAppleWatchRunningData() async {
        guard isAvailable else {
            hasAppleWatchRunningData = false
            return
        }

        // Check for running ground contact time in the last 90 days
        // This metric is ONLY available from Apple Watch
        let gctType = HKQuantityType(.runningGroundContactTime)
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: ninetyDaysAgo, end: Date(), options: .strictStartDate)

        let hasWatchData: Bool = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: gctType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, error in
                let hasData = (samples?.count ?? 0) > 0 && error == nil
                continuation.resume(returning: hasData)
            }
            healthStore.execute(query)
        }

        await MainActor.run {
            self.hasAppleWatchRunningData = hasWatchData
            Log.health.info("Apple Watch running data detected: \(hasWatchData)")
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

        let weightKg: Double? = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let sample = samples?.first as? HKQuantitySample, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: kg)
            }
            healthStore.execute(query)
        }

        if let weightKg {
            self.healthKitWeight = weightKg
        }
    }

    /// Fetch most recent height from HealthKit
    func fetchHeight() async {
        guard isAvailable else { return }

        let heightType = HKQuantityType(.height)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let heightCm: Double? = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heightType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let sample = samples?.first as? HKQuantitySample, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                let cm = sample.quantity.doubleValue(for: .meterUnit(with: .centi))
                continuation.resume(returning: cm)
            }
            healthStore.execute(query)
        }

        if let heightCm {
            self.healthKitHeight = heightCm
        }
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
        let hasWriteAccess = (status == .sharingAuthorized)

        // User is considered connected if they have write access OR previously connected
        // (HealthKit doesn't expose read authorization status for privacy, so we persist connection state)
        isAuthorized = hasWriteAccess || hasConnectedToHealthKit
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

    // MARK: - Running Metrics from HealthKit (Apple Watch)

    /// Fetch average gait asymmetry from HealthKit for a time range
    /// Returns nil if no data available (e.g., no Apple Watch or no samples)
    func fetchRunningAsymmetry(from startDate: Date, to endDate: Date) async -> Double? {
        guard isAvailable else { return nil }

        let asymmetryType = HKQuantityType(.walkingAsymmetryPercentage)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: asymmetryType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                // Calculate average asymmetry from all samples
                let total = samples.reduce(0.0) { sum, sample in
                    sum + sample.quantity.doubleValue(for: .percent()) * 100
                }
                let average = total / Double(samples.count)
                continuation.resume(returning: average)
            }
            healthStore.execute(query)
        }
    }

    /// Fetch average ground contact time from HealthKit for a time range (milliseconds)
    func fetchRunningGroundContactTime(from startDate: Date, to endDate: Date) async -> Double? {
        guard isAvailable else { return nil }

        let gctType = HKQuantityType(.runningGroundContactTime)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: gctType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                // Calculate average GCT from all samples (convert to ms)
                let total = samples.reduce(0.0) { sum, sample in
                    sum + sample.quantity.doubleValue(for: .secondUnit(with: .milli))
                }
                let average = total / Double(samples.count)
                continuation.resume(returning: average)
            }
            healthStore.execute(query)
        }
    }

    /// Fetch average vertical oscillation from HealthKit for a time range (centimeters)
    func fetchRunningVerticalOscillation(from startDate: Date, to endDate: Date) async -> Double? {
        guard isAvailable else { return nil }

        let oscillationType = HKQuantityType(.runningVerticalOscillation)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: oscillationType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                // Calculate average oscillation from all samples (convert to cm)
                let total = samples.reduce(0.0) { sum, sample in
                    sum + sample.quantity.doubleValue(for: .meterUnit(with: .centi))
                }
                let average = total / Double(samples.count)
                continuation.resume(returning: average)
            }
            healthStore.execute(query)
        }
    }

    /// Fetch average stride length from HealthKit for a time range (meters)
    func fetchRunningStrideLength(from startDate: Date, to endDate: Date) async -> Double? {
        guard isAvailable else { return nil }

        let strideType = HKQuantityType(.runningStrideLength)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: strideType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                // Calculate average stride length from all samples
                let total = samples.reduce(0.0) { sum, sample in
                    sum + sample.quantity.doubleValue(for: .meter())
                }
                let average = total / Double(samples.count)
                continuation.resume(returning: average)
            }
            healthStore.execute(query)
        }
    }

    /// Fetch all running metrics from HealthKit for a session
    /// Returns a struct with all available metrics (nil for any that aren't available)
    /// Also updates hasAppleWatchRunningData flag if watch-derived metrics are found
    func fetchRunningMetrics(from startDate: Date, to endDate: Date) async -> HealthKitRunningMetrics {
        async let asymmetry = fetchRunningAsymmetry(from: startDate, to: endDate)
        async let gct = fetchRunningGroundContactTime(from: startDate, to: endDate)
        async let oscillation = fetchRunningVerticalOscillation(from: startDate, to: endDate)
        async let strideLength = fetchRunningStrideLength(from: startDate, to: endDate)
        async let power = fetchRunningPower(from: startDate, to: endDate)
        async let speed = fetchRunningSpeed(from: startDate, to: endDate)
        async let steps = fetchStepCount(from: startDate, to: endDate)

        let metrics = await HealthKitRunningMetrics(
            asymmetryPercentage: asymmetry,
            groundContactTime: gct,
            verticalOscillation: oscillation,
            strideLength: strideLength,
            power: power,
            speed: speed,
            stepCount: steps
        )

        // Update Apple Watch detection if we got watch-specific metrics
        // GCT and power are only available from Apple Watch
        if metrics.groundContactTime != nil || metrics.power != nil {
            await MainActor.run {
                if !self.hasAppleWatchRunningData {
                    self.hasAppleWatchRunningData = true
                    Log.health.info("Apple Watch running data detected from session metrics")
                }
            }
        }

        return metrics
    }

    // MARK: - Running Power (Apple Watch Series 6+)

    /// Fetch average running power from HealthKit for a time range (watts)
    func fetchRunningPower(from startDate: Date, to endDate: Date) async -> Double? {
        guard isAvailable else { return nil }

        let powerType = HKQuantityType(.runningPower)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: powerType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                let total = samples.reduce(0.0) { sum, sample in
                    sum + sample.quantity.doubleValue(for: .watt())
                }
                let average = total / Double(samples.count)
                continuation.resume(returning: average)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Running Speed

    /// Fetch average running speed from HealthKit for a time range (m/s)
    func fetchRunningSpeed(from startDate: Date, to endDate: Date) async -> Double? {
        guard isAvailable else { return nil }

        let speedType = HKQuantityType(.runningSpeed)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: speedType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                let total = samples.reduce(0.0) { sum, sample in
                    sum + sample.quantity.doubleValue(for: .meter().unitDivided(by: .second()))
                }
                let average = total / Double(samples.count)
                continuation.resume(returning: average)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Step Count

    /// Fetch step count from HealthKit for a time range
    func fetchStepCount(from startDate: Date, to endDate: Date) async -> Int? {
        guard isAvailable else { return nil }

        let stepType = HKQuantityType(.stepCount)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: stepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                let total = samples.reduce(0.0) { sum, sample in
                    sum + sample.quantity.doubleValue(for: .count())
                }
                continuation.resume(returning: Int(total))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Fitness & Recovery Metrics

    /// Fetch the most recent VO2 Max value
    func fetchVO2Max() async -> Double? {
        guard isAvailable else { return nil }

        let vo2Type = HKQuantityType(.vo2Max)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: vo2Type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let sample = samples?.first as? HKQuantitySample, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                // VO2 Max unit: mL/(kg·min)
                let unit = HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo)).unitDivided(by: .minute())
                let value = sample.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    /// Fetch the most recent resting heart rate
    func fetchRestingHeartRate() async -> Int? {
        guard isAvailable else { return nil }

        let rhrType = HKQuantityType(.restingHeartRate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: rhrType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let sample = samples?.first as? HKQuantitySample, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                let bpm = sample.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
                continuation.resume(returning: Int(bpm))
            }
            healthStore.execute(query)
        }
    }

    /// Fetch the most recent heart rate variability (SDNN)
    func fetchHeartRateVariability() async -> Double? {
        guard isAvailable else { return nil }

        let hrvType = HKQuantityType(.heartRateVariabilitySDNN)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let sample = samples?.first as? HKQuantitySample, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                let ms = sample.quantity.doubleValue(for: .secondUnit(with: .milli))
                continuation.resume(returning: ms)
            }
            healthStore.execute(query)
        }
    }

    /// Fetch sleep analysis for the past night (hours of sleep)
    func fetchLastNightSleep() async -> SleepAnalysis? {
        guard isAvailable else { return nil }

        let sleepType = HKCategoryType(.sleepAnalysis)

        // Look for sleep data from the past 24 hours
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .hour, value: -24, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                var asleepDuration: TimeInterval = 0
                var inBedDuration: TimeInterval = 0
                var remDuration: TimeInterval = 0
                var deepDuration: TimeInterval = 0
                var coreDuration: TimeInterval = 0

                for sample in samples {
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)

                    switch sample.value {
                    case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                        asleepDuration += duration
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                        coreDuration += duration
                        asleepDuration += duration
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        deepDuration += duration
                        asleepDuration += duration
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        remDuration += duration
                        asleepDuration += duration
                    case HKCategoryValueSleepAnalysis.inBed.rawValue:
                        inBedDuration += duration
                    default:
                        break
                    }
                }

                guard asleepDuration > 0 || inBedDuration > 0 else {
                    continuation.resume(returning: nil)
                    return
                }

                let analysis = SleepAnalysis(
                    totalSleepHours: asleepDuration / 3600,
                    inBedHours: inBedDuration / 3600,
                    remHours: remDuration / 3600,
                    deepHours: deepDuration / 3600,
                    coreHours: coreDuration / 3600
                )
                continuation.resume(returning: analysis)
            }
            healthStore.execute(query)
        }
    }

    /// Fetch resting heart rate trend over the past week
    func fetchRestingHeartRateTrend(days: Int = 7) async -> [Date: Int] {
        guard isAvailable else { return [:] }

        let rhrType = HKQuantityType(.restingHeartRate)
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: rhrType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty, error == nil else {
                    continuation.resume(returning: [:])
                    return
                }

                var trend: [Date: Int] = [:]
                for sample in samples {
                    let day = Calendar.current.startOfDay(for: sample.startDate)
                    let bpm = Int(sample.quantity.doubleValue(for: .count().unitDivided(by: .minute())))
                    // Keep the most recent reading for each day
                    trend[day] = bpm
                }
                continuation.resume(returning: trend)
            }
            healthStore.execute(query)
        }
    }

    /// Fetch all fitness/recovery metrics for training readiness
    func fetchFitnessMetrics() async -> HealthKitFitnessMetrics {
        async let vo2 = fetchVO2Max()
        async let rhr = fetchRestingHeartRate()
        async let hrv = fetchHeartRateVariability()
        async let sleep = fetchLastNightSleep()
        async let rhrTrend = fetchRestingHeartRateTrend()

        return await HealthKitFitnessMetrics(
            vo2Max: vo2,
            restingHeartRate: rhr,
            heartRateVariability: hrv,
            lastNightSleep: sleep,
            restingHeartRateTrend: rhrTrend
        )
    }

    // MARK: - Competition Retrospective Metrics

    /// Fetch health metrics for a competition discipline time window
    func fetchCompetitionMetrics(from startDate: Date, to endDate: Date) async -> CompetitionHealthMetrics {
        async let hr = fetchHeartRateSamples(from: startDate, to: endDate)
        async let calories = fetchActiveCalories(from: startDate, to: endDate)
        async let running = fetchRunningMetrics(from: startDate, to: endDate)

        let heartRateData = await hr
        let runningMetrics = await running

        return await CompetitionHealthMetrics(
            averageHeartRate: heartRateData.average,
            maxHeartRate: heartRateData.max,
            minHeartRate: heartRateData.min,
            activeCalories: calories,
            runningMetrics: runningMetrics
        )
    }

    /// Fetch heart rate samples for a time range, returning average/max/min
    private func fetchHeartRateSamples(from startDate: Date, to endDate: Date) async -> (average: Double?, max: Double?, min: Double?) {
        guard isAvailable else { return (nil, nil, nil) }

        let hrType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty, error == nil else {
                    continuation.resume(returning: (nil, nil, nil))
                    return
                }

                let unit = HKUnit.count().unitDivided(by: .minute())
                let values = samples.map { $0.quantity.doubleValue(for: unit) }
                let avg = values.reduce(0, +) / Double(values.count)
                let maxVal = values.max()
                let minVal = values.min()
                continuation.resume(returning: (avg, maxVal, minVal))
            }
            healthStore.execute(query)
        }
    }

    /// Fetch active calories burned in a time range
    private func fetchActiveCalories(from startDate: Date, to endDate: Date) async -> Double? {
        guard isAvailable else { return nil }

        let calorieType = HKQuantityType(.activeEnergyBurned)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: calorieType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                let total = samples.reduce(0.0) { sum, sample in
                    sum + sample.quantity.doubleValue(for: .kilocalorie())
                }
                continuation.resume(returning: total)
            }
            healthStore.execute(query)
        }
    }
}

// MARK: - HealthKit Data Structures

/// Running metrics fetched from HealthKit (Apple Watch data)
struct HealthKitRunningMetrics {
    /// Gait asymmetry percentage (0 = perfect symmetry)
    let asymmetryPercentage: Double?
    /// Ground contact time in milliseconds
    let groundContactTime: Double?
    /// Vertical oscillation in centimeters
    let verticalOscillation: Double?
    /// Stride length in meters
    let strideLength: Double?
    /// Running power in watts (Series 6+)
    let power: Double?
    /// Running speed in m/s
    let speed: Double?
    /// Step count during session
    let stepCount: Int?

    /// Whether any metrics are available from Apple Watch
    var hasData: Bool {
        asymmetryPercentage != nil || groundContactTime != nil ||
        verticalOscillation != nil || strideLength != nil ||
        power != nil || speed != nil || stepCount != nil
    }
}

/// Fitness and recovery metrics from HealthKit
struct HealthKitFitnessMetrics {
    /// VO2 Max in mL/(kg·min) - aerobic fitness capacity
    let vo2Max: Double?
    /// Resting heart rate in bpm
    let restingHeartRate: Int?
    /// Heart rate variability (SDNN) in milliseconds
    let heartRateVariability: Double?
    /// Last night's sleep analysis
    let lastNightSleep: SleepAnalysis?
    /// Resting heart rate trend (date -> bpm)
    let restingHeartRateTrend: [Date: Int]

    /// Whether sufficient data exists for training readiness
    var hasRecoveryData: Bool {
        restingHeartRate != nil || heartRateVariability != nil || lastNightSleep != nil
    }

    /// Computed training readiness score (0-100)
    /// Based on HRV, RHR trend, and sleep quality
    var trainingReadinessScore: Int? {
        guard hasRecoveryData else { return nil }

        var score: Double = 70 // Base score

        // HRV contribution (higher is better)
        if let hrv = heartRateVariability {
            if hrv >= 50 { score += 15 }       // Excellent
            else if hrv >= 35 { score += 10 }  // Good
            else if hrv >= 20 { score += 5 }   // Fair
            else { score -= 10 }               // Low (fatigue/stress)
        }

        // RHR trend contribution (lower/stable is better)
        if restingHeartRateTrend.count >= 3 {
            let values = restingHeartRateTrend.values.sorted()
            let recent = Array(values.suffix(3))
            let older = Array(values.prefix(3))
            let recentAvg = Double(recent.reduce(0, +)) / Double(recent.count)
            let olderAvg = Double(older.reduce(0, +)) / Double(older.count)

            if recentAvg < olderAvg - 3 { score += 10 }  // Improving
            else if recentAvg > olderAvg + 5 { score -= 15 } // Elevated (potential issue)
        }

        // Sleep contribution
        if let sleep = lastNightSleep {
            if sleep.totalSleepHours >= 7.5 { score += 10 }
            else if sleep.totalSleepHours >= 6.5 { score += 5 }
            else if sleep.totalSleepHours < 5.5 { score -= 15 }

            // Bonus for good deep sleep
            if sleep.deepHours >= 1.0 { score += 5 }
        }

        return max(0, min(100, Int(score)))
    }

    /// Text description of readiness
    var readinessDescription: String {
        guard let score = trainingReadinessScore else {
            return "Insufficient data"
        }

        switch score {
        case 85...100: return "Excellent - Ready for high intensity"
        case 70..<85: return "Good - Normal training"
        case 55..<70: return "Moderate - Consider lighter session"
        case 40..<55: return "Low - Prioritize recovery"
        default: return "Very Low - Rest recommended"
        }
    }
}

/// Sleep analysis from HealthKit
struct SleepAnalysis {
    let totalSleepHours: Double
    let inBedHours: Double
    let remHours: Double
    let deepHours: Double
    let coreHours: Double

    var sleepEfficiency: Double {
        guard inBedHours > 0 else { return 0 }
        return (totalSleepHours / inBedHours) * 100
    }

    var qualityDescription: String {
        if totalSleepHours >= 7.5 && deepHours >= 1.0 {
            return "Excellent"
        } else if totalSleepHours >= 6.5 {
            return "Good"
        } else if totalSleepHours >= 5.5 {
            return "Fair"
        } else {
            return "Poor"
        }
    }
}

/// Health metrics fetched retrospectively for a competition discipline
struct CompetitionHealthMetrics {
    let averageHeartRate: Double?
    let maxHeartRate: Double?
    let minHeartRate: Double?
    let activeCalories: Double?
    let runningMetrics: HealthKitRunningMetrics?

    var hasData: Bool {
        averageHeartRate != nil || activeCalories != nil || (runningMetrics?.hasData ?? false)
    }
}
