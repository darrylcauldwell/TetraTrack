//
//  WorkoutEnrichmentService.swift
//  TetraTrack
//
//  Fetches detailed HealthKit metrics for a completed workout.
//  Used to enrich external workout detail views with HR timeseries,
//  pace splits, walking metrics, route locations, and elevation data.
//

import HealthKit
import CoreLocation
import os

struct WorkoutEnrichment: Sendable {
    var heartRateSamples: [HeartRateSamplePoint] = []
    var splits: [PaceSplit] = []
    var walkingMetrics: WalkingMetrics?
    var runningMetrics: RunningMetrics?
    var swimmingMetrics: SwimmingMetrics?
    var cyclingMetrics: CyclingMetrics?
    var generalMetrics: GeneralMetrics?
    var routeLocations: [CLLocation] = []
    var elevationGain: Double?
    var elevationLoss: Double?

    struct HeartRateSamplePoint: Sendable {
        let date: Date
        let bpm: Double
    }

    struct PaceSplit: Identifiable, Sendable {
        let id: Int          // split number (1-based)
        let distance: Double // meters
        let duration: TimeInterval
        let pace: TimeInterval // seconds per km
    }

    struct WalkingMetrics: Sendable {
        var averageCadence: Double?        // steps per minute
        var averageSpeed: Double?          // m/s
        var averageStepLength: Double?     // meters
        var asymmetryPercent: Double?      // percentage
        var doubleSupportPercent: Double?  // percentage
        var steadiness: Double?            // 0-100
    }

    struct RunningMetrics: Sendable {
        var averageCadence: Double?            // steps per minute
        var averageStrideLength: Double?       // meters
        var averageGroundContactTime: Double?  // milliseconds
        var averageVerticalOscillation: Double? // centimeters
        var averagePower: Double?              // watts
        var averageSpeed: Double?              // m/s
    }

    struct SwimmingMetrics: Sendable {
        var totalStrokeCount: Double?    // total strokes
        var averageSWOLF: Double?        // SWOLF score
        var lapCount: Int?               // number of laps
        var poolLength: Double?          // meters (from workout metadata)
        var laps: [SwimLap] = []         // per-lap breakdown
        var averageSpO2: Double?         // blood oxygen percentage
        var averageBreathingRate: Double? // breaths per minute
    }

    struct SwimLap: Identifiable, Sendable {
        let id: Int               // lap number (1-based)
        let duration: TimeInterval
        let strokeCount: Int?
        let swolf: Double?        // duration + strokes
        let strokeType: String?   // freestyle, backstroke, etc.
    }

    struct CyclingMetrics: Sendable {
        var averageCadence: Double?  // rpm
        var averagePower: Double?    // watts
        var averageSpeed: Double?    // m/s
    }

    struct GeneralMetrics: Sendable {
        var averageHeartRate: Double?   // bpm
        var maxHeartRate: Double?       // bpm
        var minHeartRate: Double?       // bpm
        var activeCalories: Double?     // kcal
        var heartRateRecovery: Double?  // bpm drop in 1 min post-workout
    }
}

@MainActor
final class WorkoutEnrichmentService {
    static let shared = WorkoutEnrichmentService()

    private let healthStore = HKHealthStore()

    private init() {}

    /// Fetch all enrichment data for a workout, with activity-specific metrics
    func enrich(workoutId: UUID, startDate: Date, endDate: Date, activityType: HKWorkoutActivityType = .walking) async -> WorkoutEnrichment {
        var enrichment = WorkoutEnrichment()

        // Common data — always fetch HR, route
        async let hrTask = fetchHeartRateSamples(from: startDate, to: endDate)
        async let routeTask = fetchRouteLocations(workoutId: workoutId)

        enrichment.heartRateSamples = await hrTask
        enrichment.routeLocations = await routeTask

        // Derive splits and elevation from route
        if !enrichment.routeLocations.isEmpty {
            enrichment.splits = deriveSplits(from: enrichment.routeLocations)
            let (gain, loss) = deriveElevation(from: enrichment.routeLocations)
            enrichment.elevationGain = gain
            enrichment.elevationLoss = loss
        }

        // General metrics (HR stats) — useful for all workout types
        enrichment.generalMetrics = deriveGeneralMetrics(from: enrichment.heartRateSamples)

        // Activity-specific metrics
        switch activityType {
        case .walking, .hiking:
            enrichment.walkingMetrics = await fetchWalkingMetrics(from: startDate, to: endDate)
        case .running:
            enrichment.runningMetrics = await fetchRunningMetrics(from: startDate, to: endDate)
        case .swimming:
            enrichment.swimmingMetrics = await fetchSwimmingMetrics(workoutId: workoutId, from: startDate, to: endDate)
        case .cycling:
            enrichment.cyclingMetrics = await fetchCyclingMetrics(from: startDate, to: endDate)
        default:
            // For other types (yoga, HIIT, strength, etc.), HR + route is sufficient
            break
        }

        return enrichment
    }

    // MARK: - Heart Rate Samples

    private func fetchHeartRateSamples(from start: Date, to end: Date) async -> [WorkoutEnrichment.HeartRateSamplePoint] {
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let unit = HKUnit.count().unitDivided(by: .minute())

        let descriptor = HKSampleQueryDescriptor<HKQuantitySample>(
            predicates: [.quantitySample(type: heartRateType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )

        do {
            let samples = try await descriptor.result(for: healthStore)
            return samples.map { sample in
                WorkoutEnrichment.HeartRateSamplePoint(
                    date: sample.startDate,
                    bpm: sample.quantity.doubleValue(for: unit)
                )
            }
        } catch {
            Log.health.error("Failed to fetch HR samples: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Route Locations (full CLLocation for elevation)

    private func fetchRouteLocations(workoutId: UUID) async -> [CLLocation] {
        let predicate = HKQuery.predicateForObject(with: workoutId)

        let workoutDescriptor = HKSampleQueryDescriptor<HKWorkout>(
            predicates: [.workout(predicate)],
            sortDescriptors: [],
            limit: 1
        )

        guard let workout = try? await workoutDescriptor.result(for: healthStore).first else {
            return []
        }

        let routeType = HKSeriesType.workoutRoute()
        let routePredicate = HKQuery.predicateForObjects(from: workout)

        let routeDescriptor = HKSampleQueryDescriptor<HKSample>(
            predicates: [.sample(type: routeType, predicate: routePredicate)],
            sortDescriptors: []
        )

        let routeSamples = (try? await routeDescriptor.result(for: healthStore)) ?? []
        let routes = routeSamples.compactMap { $0 as? HKWorkoutRoute }

        var allLocations: [CLLocation] = []
        for route in routes {
            let descriptor = HKWorkoutRouteQueryDescriptor(route)
            do {
                for try await location in descriptor.results(for: healthStore) {
                    allLocations.append(location)
                }
            } catch {
                Log.health.error("Route location query error: \(error.localizedDescription)")
            }
        }

        return allLocations
    }

    // MARK: - Walking Metrics

    private func fetchWalkingMetrics(from start: Date, to end: Date) async -> WorkoutEnrichment.WalkingMetrics? {
        var metrics = WorkoutEnrichment.WalkingMetrics()
        var hasAnyData = false

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        // Fetch each metric type
        if let cadence = await fetchAverageQuantity(.stepCount, predicate: predicate, unit: .count(), convertToCadence: true, duration: end.timeIntervalSince(start)) {
            metrics.averageCadence = cadence
            hasAnyData = true
        }

        if let speed = await fetchAverageQuantity(.walkingSpeed, predicate: predicate, unit: HKUnit.meter().unitDivided(by: .second())) {
            metrics.averageSpeed = speed
            hasAnyData = true
        }

        if let stepLength = await fetchAverageQuantity(.walkingStepLength, predicate: predicate, unit: .meter()) {
            metrics.averageStepLength = stepLength
            hasAnyData = true
        }

        if let asymmetry = await fetchAverageQuantity(.walkingAsymmetryPercentage, predicate: predicate, unit: .percent()) {
            metrics.asymmetryPercent = asymmetry * 100 // Convert from 0-1 to percentage
            hasAnyData = true
        }

        if let doubleSupport = await fetchAverageQuantity(.walkingDoubleSupportPercentage, predicate: predicate, unit: .percent()) {
            metrics.doubleSupportPercent = doubleSupport * 100
            hasAnyData = true
        }

        if let steadiness = await fetchAverageQuantity(.appleWalkingSteadiness, predicate: predicate, unit: .percent()) {
            metrics.steadiness = steadiness * 100
            hasAnyData = true
        }

        return hasAnyData ? metrics : nil
    }

    private func fetchAverageQuantity(
        _ typeIdentifier: HKQuantityTypeIdentifier,
        predicate: NSPredicate,
        unit: HKUnit,
        convertToCadence: Bool = false,
        duration: TimeInterval = 0
    ) async -> Double? {
        let quantityType = HKQuantityType(typeIdentifier)

        let descriptor = HKSampleQueryDescriptor<HKQuantitySample>(
            predicates: [.quantitySample(type: quantityType, predicate: predicate)],
            sortDescriptors: []
        )

        do {
            let samples = try await descriptor.result(for: healthStore)
            guard !samples.isEmpty else { return nil }

            if convertToCadence && duration > 0 {
                // Sum step count and convert to steps/min
                let totalSteps = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: unit) }
                return (totalSteps / duration) * 60
            }

            let total = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: unit) }
            return total / Double(samples.count)
        } catch {
            // Many metrics are Watch-only; failing silently is expected
            return nil
        }
    }

    // MARK: - Running Metrics

    private func fetchRunningMetrics(from start: Date, to end: Date) async -> WorkoutEnrichment.RunningMetrics? {
        var metrics = WorkoutEnrichment.RunningMetrics()
        var hasAnyData = false
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let duration = end.timeIntervalSince(start)

        if let cadence = await fetchAverageQuantity(.stepCount, predicate: predicate, unit: .count(), convertToCadence: true, duration: duration) {
            metrics.averageCadence = cadence
            hasAnyData = true
        }

        if let stride = await fetchAverageQuantity(.runningStrideLength, predicate: predicate, unit: .meter()) {
            metrics.averageStrideLength = stride
            hasAnyData = true
        }

        if let gct = await fetchAverageQuantity(.runningGroundContactTime, predicate: predicate, unit: .secondUnit(with: .milli)) {
            metrics.averageGroundContactTime = gct
            hasAnyData = true
        }

        if let vo = await fetchAverageQuantity(.runningVerticalOscillation, predicate: predicate, unit: .meterUnit(with: .centi)) {
            metrics.averageVerticalOscillation = vo
            hasAnyData = true
        }

        if let power = await fetchAverageQuantity(.runningPower, predicate: predicate, unit: .watt()) {
            metrics.averagePower = power
            hasAnyData = true
        }

        if let speed = await fetchAverageQuantity(.runningSpeed, predicate: predicate, unit: HKUnit.meter().unitDivided(by: .second())) {
            metrics.averageSpeed = speed
            hasAnyData = true
        }

        return hasAnyData ? metrics : nil
    }

    // MARK: - Swimming Metrics

    private func fetchSwimmingMetrics(workoutId: UUID, from start: Date, to end: Date) async -> WorkoutEnrichment.SwimmingMetrics? {
        var metrics = WorkoutEnrichment.SwimmingMetrics()
        var hasAnyData = false
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        // Stroke count
        if let strokes = await fetchSumQuantity(.swimmingStrokeCount, predicate: predicate, unit: .count()) {
            metrics.totalStrokeCount = strokes
            hasAnyData = true
        }

        // SpO2
        if let spo2 = await fetchAverageQuantity(.oxygenSaturation, predicate: predicate, unit: .percent()) {
            metrics.averageSpO2 = spo2 * 100
            hasAnyData = true
        }

        // Breathing rate
        if let breathing = await fetchAverageQuantity(.respiratoryRate, predicate: predicate, unit: HKUnit.count().unitDivided(by: .minute())) {
            metrics.averageBreathingRate = breathing
            hasAnyData = true
        }

        // Get lap data, pool length from the HKWorkout
        let workoutPredicate = HKQuery.predicateForObject(with: workoutId)
        let workoutDescriptor = HKSampleQueryDescriptor<HKWorkout>(
            predicates: [.workout(workoutPredicate)],
            sortDescriptors: [],
            limit: 1
        )

        if let workout = try? await workoutDescriptor.result(for: healthStore).first {
            // Pool length from metadata
            if let poolLength = workout.metadata?[HKMetadataKeyLapLength] as? HKQuantity {
                metrics.poolLength = poolLength.doubleValue(for: .meter())
                hasAnyData = true
            }

            // Build per-lap breakdown from lap events
            let lapEvents = workout.workoutEvents?.filter { $0.type == .lap } ?? []
            if !lapEvents.isEmpty {
                metrics.lapCount = lapEvents.count
                hasAnyData = true

                // Fetch per-lap stroke samples for stroke count per lap
                let strokeSamples = await fetchStrokeSamples(from: start, to: end)

                var laps: [WorkoutEnrichment.SwimLap] = []
                var previousTime = workout.startDate

                for (index, event) in lapEvents.enumerated() {
                    let lapDuration = event.dateInterval.start.timeIntervalSince(previousTime)

                    // Count strokes in this lap's time window
                    let lapStrokes = strokeSamples.filter {
                        $0.startDate >= previousTime && $0.startDate < event.dateInterval.start
                    }
                    let strokeCount = lapStrokes.isEmpty ? nil : Int(lapStrokes.reduce(0.0) { $0 + $1.quantity.doubleValue(for: .count()) })

                    // Stroke type from metadata
                    let strokeType = event.metadata?[HKMetadataKeySwimmingStrokeStyle] as? String

                    // SWOLF for this lap
                    let swolf: Double? = strokeCount.map { Double(lapDuration) + Double($0) }

                    laps.append(WorkoutEnrichment.SwimLap(
                        id: index + 1,
                        duration: lapDuration,
                        strokeCount: strokeCount,
                        swolf: swolf,
                        strokeType: strokeType
                    ))

                    previousTime = event.dateInterval.start
                }

                metrics.laps = laps

                // Average SWOLF from per-lap data
                let swolfValues = laps.compactMap(\.swolf)
                if !swolfValues.isEmpty {
                    metrics.averageSWOLF = swolfValues.reduce(0, +) / Double(swolfValues.count)
                }
            }
        }

        return hasAnyData ? metrics : nil
    }

    private func fetchStrokeSamples(from start: Date, to end: Date) async -> [HKQuantitySample] {
        let strokeType = HKQuantityType(.swimmingStrokeCount)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let descriptor = HKSampleQueryDescriptor<HKQuantitySample>(
            predicates: [.quantitySample(type: strokeType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )

        return (try? await descriptor.result(for: healthStore)) ?? []
    }

    // MARK: - Cycling Metrics

    private func fetchCyclingMetrics(from start: Date, to end: Date) async -> WorkoutEnrichment.CyclingMetrics? {
        var metrics = WorkoutEnrichment.CyclingMetrics()
        var hasAnyData = false
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        if let cadence = await fetchAverageQuantity(.cyclingCadence, predicate: predicate, unit: HKUnit.count().unitDivided(by: .minute())) {
            metrics.averageCadence = cadence
            hasAnyData = true
        }

        if let power = await fetchAverageQuantity(.cyclingPower, predicate: predicate, unit: .watt()) {
            metrics.averagePower = power
            hasAnyData = true
        }

        if let speed = await fetchAverageQuantity(.cyclingSpeed, predicate: predicate, unit: HKUnit.meter().unitDivided(by: .second())) {
            metrics.averageSpeed = speed
            hasAnyData = true
        }

        return hasAnyData ? metrics : nil
    }

    // MARK: - Sum Quantity Helper

    private func fetchSumQuantity(
        _ typeIdentifier: HKQuantityTypeIdentifier,
        predicate: NSPredicate,
        unit: HKUnit
    ) async -> Double? {
        let quantityType = HKQuantityType(typeIdentifier)

        let descriptor = HKSampleQueryDescriptor<HKQuantitySample>(
            predicates: [.quantitySample(type: quantityType, predicate: predicate)],
            sortDescriptors: []
        )

        do {
            let samples = try await descriptor.result(for: healthStore)
            guard !samples.isEmpty else { return nil }
            return samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: unit) }
        } catch {
            return nil
        }
    }

    // MARK: - Derived Data

    private func deriveSplits(from locations: [CLLocation]) -> [WorkoutEnrichment.PaceSplit] {
        guard locations.count >= 2 else { return [] }

        var splits: [WorkoutEnrichment.PaceSplit] = []
        var splitDistance: Double = 0
        var splitStartTime = locations[0].timestamp
        var splitNumber = 1

        for i in 1..<locations.count {
            let distance = locations[i].distance(from: locations[i - 1])
            splitDistance += distance

            if splitDistance >= 1000 { // 1 km split
                let splitDuration = locations[i].timestamp.timeIntervalSince(splitStartTime)
                let pacePerKm = splitDuration / (splitDistance / 1000)

                splits.append(WorkoutEnrichment.PaceSplit(
                    id: splitNumber,
                    distance: splitDistance,
                    duration: splitDuration,
                    pace: pacePerKm
                ))

                splitNumber += 1
                splitDistance = 0
                splitStartTime = locations[i].timestamp
            }
        }

        // Add partial final split if significant distance
        if splitDistance >= 200, let lastLocation = locations.last {
            let splitDuration = lastLocation.timestamp.timeIntervalSince(splitStartTime)
            let pacePerKm = splitDuration / (splitDistance / 1000)

            splits.append(WorkoutEnrichment.PaceSplit(
                id: splitNumber,
                distance: splitDistance,
                duration: splitDuration,
                pace: pacePerKm
            ))
        }

        return splits
    }

    private func deriveElevation(from locations: [CLLocation]) -> (gain: Double, loss: Double) {
        guard locations.count >= 2 else { return (0, 0) }

        var gain: Double = 0
        var loss: Double = 0

        for i in 1..<locations.count {
            let delta = locations[i].altitude - locations[i - 1].altitude
            // Filter out GPS noise — only count changes > 1m
            if delta > 1 {
                gain += delta
            } else if delta < -1 {
                loss += abs(delta)
            }
        }

        return (gain, loss)
    }

    private func deriveGeneralMetrics(from samples: [WorkoutEnrichment.HeartRateSamplePoint]) -> WorkoutEnrichment.GeneralMetrics? {
        guard !samples.isEmpty else { return nil }

        let bpms = samples.map(\.bpm)
        return WorkoutEnrichment.GeneralMetrics(
            averageHeartRate: bpms.reduce(0, +) / Double(bpms.count),
            maxHeartRate: bpms.max(),
            minHeartRate: bpms.min(),
            activeCalories: nil,
            heartRateRecovery: nil
        )
    }
}
