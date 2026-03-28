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
}

@MainActor
final class WorkoutEnrichmentService {
    static let shared = WorkoutEnrichmentService()

    private let healthStore = HKHealthStore()

    private init() {}

    /// Fetch all enrichment data for a workout
    func enrich(workoutId: UUID, startDate: Date, endDate: Date) async -> WorkoutEnrichment {
        var enrichment = WorkoutEnrichment()

        // Run fetches concurrently
        async let hrTask = fetchHeartRateSamples(from: startDate, to: endDate)
        async let routeTask = fetchRouteLocations(workoutId: workoutId)
        async let walkingTask = fetchWalkingMetrics(from: startDate, to: endDate)

        enrichment.heartRateSamples = await hrTask
        enrichment.routeLocations = await routeTask
        enrichment.walkingMetrics = await walkingTask

        // Derive splits and elevation from route
        if !enrichment.routeLocations.isEmpty {
            enrichment.splits = deriveSplits(from: enrichment.routeLocations)
            let (gain, loss) = deriveElevation(from: enrichment.routeLocations)
            enrichment.elevationGain = gain
            enrichment.elevationLoss = loss
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
}
