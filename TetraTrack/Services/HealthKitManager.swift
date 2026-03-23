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
    var authorizationDenied: Bool = false
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
        HKSeriesType.workoutRoute(),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.distanceSwimming),
        HKQuantityType(.swimmingStrokeCount),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.runningGroundContactTime),
        HKQuantityType(.runningVerticalOscillation),
        HKQuantityType(.runningSpeed),
        HKQuantityType(.runningPower),
        HKQuantityType(.runningStrideLength),
        HKQuantityType(.stepCount),
        HKQuantityType(.oxygenSaturation),
        HKQuantityType(.respiratoryRate),
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

        // Walking metrics (Apple Watch)
        HKQuantityType(.appleWalkingSteadiness),
        HKQuantityType(.walkingDoubleSupportPercentage),
        HKQuantityType(.walkingSpeed),
        HKQuantityType(.walkingStepLength),
        HKQuantityType(.walkingHeartRateAverage),

        // Recovery metrics
        HKQuantityType(.heartRateRecoveryOneMinute),

        // Sleep (for recovery insights)
        HKCategoryType(.sleepAnalysis),

        // Physiology (SpO2, breathing rate)
        HKQuantityType(.oxygenSaturation),
        HKQuantityType(.respiratoryRate),
    ]

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }

        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)

            // Check actual write access — requestAuthorization succeeds even when user denies
            let workoutStatus = healthStore.authorizationStatus(for: HKObjectType.workoutType())
            let hasWriteAccess = (workoutStatus == .sharingAuthorized)

            await MainActor.run {
                self.isAuthorized = hasWriteAccess
                self.authorizationDenied = !hasWriteAccess
                if hasWriteAccess {
                    self.hasConnectedToHealthKit = true
                }
            }

            if hasWriteAccess {
                await detectAppleWatchRunningData()
            }
            return hasWriteAccess
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

        let descriptor = HKSampleQueryDescriptor<HKQuantitySample>(
            predicates: [.quantitySample(type: gctType, predicate: predicate)],
            sortDescriptors: [],
            limit: 1
        )

        let hasWatchData: Bool
        do {
            let results = try await descriptor.result(for: healthStore)
            hasWatchData = !results.isEmpty
        } catch {
            hasWatchData = false
        }

        self.hasAppleWatchRunningData = hasWatchData
        Log.health.info("Apple Watch running data detected: \(hasWatchData)")
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
        if let kg = await fetchMostRecentQuantity(type: HKQuantityType(.bodyMass), unit: .gramUnit(with: .kilo)) {
            self.healthKitWeight = kg
        }
    }

    /// Fetch most recent height from HealthKit
    func fetchHeight() async {
        if let cm = await fetchMostRecentQuantity(type: HKQuantityType(.height), unit: .meterUnit(with: .centi)) {
            self.healthKitHeight = cm
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

    // MARK: - Calorie Calculations (used by WorkoutLifecycleService for custom samples)
    // Note: Post-session workout save methods (saveRideAsWorkout, saveRunningSessionAsWorkout,
    // saveSwimmingSessionAsWorkout) have been removed. All workout saving is now handled by
    // WorkoutLifecycleService which manages the full lifecycle: prepare → start → collect
    // live data → add route incrementally → end → save.

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

    // MARK: - Query Helpers

    /// Fetch the average value of a quantity type over a date range.
    /// Shared helper for the many "fetch all samples, compute average" queries.
    private func fetchAverageQuantity(
        type: HKQuantityType,
        unit: HKUnit,
        from startDate: Date,
        to endDate: Date,
        multiplier: Double = 1.0
    ) async -> Double? {
        guard isAvailable else { return nil }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor<HKQuantitySample>(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: []
        )

        do {
            let samples = try await descriptor.result(for: healthStore)
            guard !samples.isEmpty else { return nil }
            let total = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: unit) * multiplier }
            return total / Double(samples.count)
        } catch {
            Log.health.error("Failed to fetch \(type): \(error)")
            return nil
        }
    }

    /// Fetch the most recent single sample of a quantity type.
    private func fetchMostRecentQuantity(
        type: HKQuantityType,
        unit: HKUnit,
        predicate: NSPredicate? = nil
    ) async -> Double? {
        guard isAvailable else { return nil }

        let predicates: [HKSamplePredicate<HKQuantitySample>]
        if let predicate {
            predicates = [.quantitySample(type: type, predicate: predicate)]
        } else {
            predicates = [.quantitySample(type: type)]
        }

        let descriptor = HKSampleQueryDescriptor<HKQuantitySample>(
            predicates: predicates,
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )

        do {
            let samples = try await descriptor.result(for: healthStore)
            guard let sample = samples.first else { return nil }
            return sample.quantity.doubleValue(for: unit)
        } catch {
            Log.health.error("Failed to fetch \(type): \(error)")
            return nil
        }
    }

    // MARK: - Running Metrics from HealthKit (Apple Watch)

    /// Fetch average gait asymmetry from HealthKit for a time range
    /// Returns nil if no data available (e.g., no Apple Watch or no samples)
    func fetchRunningAsymmetry(from startDate: Date, to endDate: Date) async -> Double? {
        await fetchAverageQuantity(type: HKQuantityType(.walkingAsymmetryPercentage), unit: .percent(), from: startDate, to: endDate, multiplier: 100)
    }

    /// Fetch average ground contact time from HealthKit for a time range (milliseconds)
    func fetchRunningGroundContactTime(from startDate: Date, to endDate: Date) async -> Double? {
        await fetchAverageQuantity(type: HKQuantityType(.runningGroundContactTime), unit: .secondUnit(with: .milli), from: startDate, to: endDate)
    }

    /// Fetch average vertical oscillation from HealthKit for a time range (centimeters)
    func fetchRunningVerticalOscillation(from startDate: Date, to endDate: Date) async -> Double? {
        await fetchAverageQuantity(type: HKQuantityType(.runningVerticalOscillation), unit: .meterUnit(with: .centi), from: startDate, to: endDate)
    }

    /// Fetch average stride length from HealthKit for a time range (meters)
    func fetchRunningStrideLength(from startDate: Date, to endDate: Date) async -> Double? {
        await fetchAverageQuantity(type: HKQuantityType(.runningStrideLength), unit: .meter(), from: startDate, to: endDate)
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
        // HR recovery needs extra time window - Apple may delay writing
        async let hrRecovery = fetchHeartRateRecoveryOneMinute(from: startDate, to: endDate)

        let metrics = await HealthKitRunningMetrics(
            asymmetryPercentage: asymmetry,
            groundContactTime: gct,
            verticalOscillation: oscillation,
            strideLength: strideLength,
            power: power,
            speed: speed,
            stepCount: steps,
            heartRateRecoveryOneMinute: hrRecovery
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
        await fetchAverageQuantity(type: HKQuantityType(.runningPower), unit: .watt(), from: startDate, to: endDate)
    }

    // MARK: - Running Speed

    /// Fetch average running speed from HealthKit for a time range (m/s)
    func fetchRunningSpeed(from startDate: Date, to endDate: Date) async -> Double? {
        await fetchAverageQuantity(type: HKQuantityType(.runningSpeed), unit: .meter().unitDivided(by: .second()), from: startDate, to: endDate)
    }

    // MARK: - Step Count

    /// Fetch step count from HealthKit for a time range
    func fetchStepCount(from startDate: Date, to endDate: Date) async -> Int? {
        guard isAvailable else { return nil }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.stepCount), predicate: predicate),
            options: .cumulativeSum
        )

        do {
            let result = try await descriptor.result(for: healthStore)
            guard let sum = result?.sumQuantity() else { return nil }
            return Int(sum.doubleValue(for: .count()))
        } catch {
            Log.health.error("Failed to fetch step count: \(error)")
            return nil
        }
    }

    // MARK: - Walking Metrics from HealthKit (Apple Watch)

    /// Fetch walking double support percentage for a time range (% of stride with both feet on ground)
    func fetchWalkingDoubleSupportPercentage(from startDate: Date, to endDate: Date) async -> Double? {
        await fetchAverageQuantity(type: HKQuantityType(.walkingDoubleSupportPercentage), unit: .percent(), from: startDate, to: endDate, multiplier: 100)
    }

    /// Fetch walking speed for a time range (m/s)
    func fetchWalkingSpeed(from startDate: Date, to endDate: Date) async -> Double? {
        await fetchAverageQuantity(type: HKQuantityType(.walkingSpeed), unit: .meter().unitDivided(by: .second()), from: startDate, to: endDate)
    }

    /// Fetch walking step length for a time range (meters)
    func fetchWalkingStepLength(from startDate: Date, to endDate: Date) async -> Double? {
        await fetchAverageQuantity(type: HKQuantityType(.walkingStepLength), unit: .meter(), from: startDate, to: endDate)
    }

    /// Fetch most recent Apple Walking Steadiness (0-100 percentage, background metric)
    func fetchAppleWalkingSteadiness() async -> Double? {
        guard let value = await fetchMostRecentQuantity(type: HKQuantityType(.appleWalkingSteadiness), unit: .percent()) else { return nil }
        return value * 100
    }

    /// Fetch most recent walking heart rate average (bpm, background metric)
    func fetchWalkingHeartRateAverage() async -> Double? {
        await fetchMostRecentQuantity(type: HKQuantityType(.walkingHeartRateAverage), unit: .count().unitDivided(by: .minute()))
    }

    /// Fetch heart rate recovery one minute for a time range (bpm drop in 60s)
    /// Uses +5 min extension on end date since Apple may delay writing this metric
    func fetchHeartRateRecoveryOneMinute(from startDate: Date, to endDate: Date) async -> Double? {
        let extendedEnd = endDate.addingTimeInterval(5 * 60) // +5 min for Apple processing delay
        return await fetchAverageQuantity(type: HKQuantityType(.heartRateRecoveryOneMinute), unit: .count().unitDivided(by: .minute()), from: startDate, to: extendedEnd)
    }

    /// Fetch all walking metrics from HealthKit for a session
    func fetchWalkingMetrics(from startDate: Date, to endDate: Date) async -> HealthKitWalkingMetrics {
        async let doubleSupport = fetchWalkingDoubleSupportPercentage(from: startDate, to: endDate)
        async let walkSpeed = fetchWalkingSpeed(from: startDate, to: endDate)
        async let stepLength = fetchWalkingStepLength(from: startDate, to: endDate)
        async let steadiness = fetchAppleWalkingSteadiness()
        async let walkHR = fetchWalkingHeartRateAverage()

        return await HealthKitWalkingMetrics(
            doubleSupportPercentage: doubleSupport,
            walkingSpeed: walkSpeed,
            walkingStepLength: stepLength,
            walkingSteadiness: steadiness,
            walkingHeartRateAverage: walkHR
        )
    }

    // MARK: - Fitness & Recovery Metrics

    /// Fetch the most recent VO2 Max value
    func fetchVO2Max() async -> Double? {
        // VO2 Max unit: mL/(kg·min)
        let unit = HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo)).unitDivided(by: .minute())
        return await fetchMostRecentQuantity(type: HKQuantityType(.vo2Max), unit: unit)
    }

    /// Fetch the most recent resting heart rate
    func fetchRestingHeartRate() async -> Int? {
        guard let bpm = await fetchMostRecentQuantity(type: HKQuantityType(.restingHeartRate), unit: .count().unitDivided(by: .minute())) else { return nil }
        return Int(bpm)
    }

    /// Fetch the most recent heart rate variability (SDNN)
    func fetchHeartRateVariability() async -> Double? {
        await fetchMostRecentQuantity(type: HKQuantityType(.heartRateVariabilitySDNN), unit: .secondUnit(with: .milli))
    }

    /// Fetch sleep analysis for the past night (hours of sleep)
    func fetchLastNightSleep() async -> SleepAnalysis? {
        guard isAvailable else { return nil }

        let sleepType = HKCategoryType(.sleepAnalysis)

        // Look for sleep data from the past 24 hours
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .hour, value: -24, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now, options: .strictStartDate)

        let descriptor = HKSampleQueryDescriptor<HKCategorySample>(
            predicates: [.categorySample(type: sleepType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )

        do {
            let samples = try await descriptor.result(for: healthStore)
            guard !samples.isEmpty else { return nil }

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

            guard asleepDuration > 0 || inBedDuration > 0 else { return nil }

            return SleepAnalysis(
                totalSleepHours: asleepDuration / 3600,
                inBedHours: inBedDuration / 3600,
                remHours: remDuration / 3600,
                deepHours: deepDuration / 3600,
                coreHours: coreDuration / 3600
            )
        } catch {
            Log.health.error("Failed to fetch sleep data: \(error)")
            return nil
        }
    }

    /// Fetch resting heart rate trend over the past week
    func fetchRestingHeartRateTrend(days: Int = 7) async -> [Date: Int] {
        guard isAvailable else { return [:] }

        let rhrType = HKQuantityType(.restingHeartRate)
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)

        let descriptor = HKSampleQueryDescriptor<HKQuantitySample>(
            predicates: [.quantitySample(type: rhrType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )

        do {
            let samples = try await descriptor.result(for: healthStore)
            guard !samples.isEmpty else { return [:] }

            var trend: [Date: Int] = [:]
            for sample in samples {
                let day = Calendar.current.startOfDay(for: sample.startDate)
                let bpm = Int(sample.quantity.doubleValue(for: .count().unitDivided(by: .minute())))
                // Keep the most recent reading for each day
                trend[day] = bpm
            }
            return trend
        } catch {
            Log.health.error("Failed to fetch resting heart rate trend: \(error)")
            return [:]
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

        let descriptor = HKSampleQueryDescriptor<HKQuantitySample>(
            predicates: [.quantitySample(type: hrType, predicate: predicate)],
            sortDescriptors: []
        )

        do {
            let samples = try await descriptor.result(for: healthStore)
            guard !samples.isEmpty else { return (nil, nil, nil) }

            let unit = HKUnit.count().unitDivided(by: .minute())
            let values = samples.map { $0.quantity.doubleValue(for: unit) }
            let avg = values.reduce(0, +) / Double(values.count)
            return (avg, values.max(), values.min())
        } catch {
            Log.health.error("Failed to fetch heart rate samples: \(error)")
            return (nil, nil, nil)
        }
    }

    /// Fetch active calories burned in a time range
    private func fetchActiveCalories(from startDate: Date, to endDate: Date) async -> Double? {
        guard isAvailable else { return nil }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.activeEnergyBurned), predicate: predicate),
            options: .cumulativeSum
        )

        do {
            let result = try await descriptor.result(for: healthStore)
            return result?.sumQuantity()?.doubleValue(for: .kilocalorie())
        } catch {
            Log.health.error("Failed to fetch active calories: \(error)")
            return nil
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
    /// Heart rate recovery 1 minute (bpm drop in 60s post-exercise)
    let heartRateRecoveryOneMinute: Double?

    /// Whether any metrics are available from Apple Watch
    var hasData: Bool {
        asymmetryPercentage != nil || groundContactTime != nil ||
        verticalOscillation != nil || strideLength != nil ||
        power != nil || speed != nil || stepCount != nil ||
        heartRateRecoveryOneMinute != nil
    }
}

/// Walking metrics fetched from HealthKit (Apple Watch data)
struct HealthKitWalkingMetrics {
    /// Double support percentage (both feet on ground, lower = better)
    let doubleSupportPercentage: Double?
    /// Walking speed in m/s
    let walkingSpeed: Double?
    /// Walking step length in meters
    let walkingStepLength: Double?
    /// Apple Walking Steadiness (0-100 percentage)
    let walkingSteadiness: Double?
    /// Walking heart rate average in bpm
    let walkingHeartRateAverage: Double?

    var hasData: Bool {
        doubleSupportPercentage != nil || walkingSpeed != nil ||
        walkingStepLength != nil || walkingSteadiness != nil ||
        walkingHeartRateAverage != nil
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
