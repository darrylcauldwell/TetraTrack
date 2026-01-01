//
//  ExternalWorkoutService.swift
//  TetraTrack
//
//  Queries HealthKit for workouts recorded by external apps (Apple Fitness, Garmin, Strava, etc.)
//  Filters out TetraTrack's own workouts to avoid duplicates.
//

import HealthKit
import Observation
import CoreLocation
import os

@Observable
@MainActor
final class ExternalWorkoutService {
    static let shared = ExternalWorkoutService()

    var workouts: [ExternalWorkout] = []
    var isLoading = false

    private let healthStore = HKHealthStore()
    private static let tetraTrackBundlePrefix = "dev.dreamfold.TetraTrack"

    private init() {}

    // MARK: - Fetch Workouts

    /// Fetch external workouts from HealthKit within a date range.
    /// Filters out TetraTrack's own workouts by bundle identifier and UUID cross-reference.
    func fetchWorkouts(from startDate: Date, to endDate: Date, knownUUIDs: Set<String> = []) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        isLoading = true
        defer { isLoading = false }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        let hkWorkouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    Log.health.error("Failed to fetch external workouts: \(error)")
                }
                let results = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: results)
            }
            healthStore.execute(query)
        }

        // Filter out TetraTrack's own workouts by bundle ID and UUID cross-reference
        let externalOnly = hkWorkouts.filter { workout in
            let bundleId = workout.sourceRevision.source.bundleIdentifier
            if bundleId.hasPrefix(Self.tetraTrackBundlePrefix) { return false }
            if knownUUIDs.contains(workout.uuid.uuidString) { return false }
            return true
        }

        // Fetch HR and route availability in parallel
        var results: [ExternalWorkout] = []
        for workout in externalOnly {
            let avgHR = await fetchAverageHeartRate(for: workout)
            let hasRoute = await checkRouteAvailability(for: workout)

            let external = ExternalWorkout(
                id: workout.uuid,
                activityType: workout.workoutActivityType,
                sourceName: workout.sourceRevision.source.name,
                sourceBundleIdentifier: workout.sourceRevision.source.bundleIdentifier,
                startDate: workout.startDate,
                endDate: workout.endDate,
                duration: workout.duration,
                totalDistance: workout.totalDistance?.doubleValue(for: .meter()),
                totalEnergyBurned: workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()),
                averageHeartRate: avgHR,
                hasRoute: hasRoute
            )
            results.append(external)
        }

        workouts = results
    }

    // MARK: - Heart Rate

    /// Fetch average heart rate for a specific workout
    private func fetchAverageHeartRate(for workout: HKWorkout) async -> Double? {
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let total = samples.reduce(0.0) { sum, sample in
                    sum + sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                }
                continuation.resume(returning: total / Double(samples.count))
            }
            self.healthStore.execute(query)
        }
    }

    // MARK: - Route Availability

    /// Check whether a workout has an associated GPS route
    private func checkRouteAvailability(for workout: HKWorkout) async -> Bool {
        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: (samples?.count ?? 0) > 0)
            }
            self.healthStore.execute(query)
        }
    }

    // MARK: - Route Data (Issue 3.2)

    /// Fetch GPS route coordinates for an external workout
    func fetchRouteCoordinates(for workoutId: UUID, startDate: Date, endDate: Date) async -> [CLLocationCoordinate2D] {
        // First find the workout
        let predicate = HKQuery.predicateForObject(with: workoutId)

        let workout: HKWorkout? = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: samples?.first as? HKWorkout)
            }
            healthStore.execute(query)
        }

        guard let workout else { return [] }

        // Fetch route samples
        let routeType = HKSeriesType.workoutRoute()
        let routePredicate = HKQuery.predicateForObjects(from: workout)

        let routes: [HKWorkoutRoute] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: routePredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkoutRoute]) ?? [])
            }
            healthStore.execute(query)
        }

        // Extract coordinates from each route
        var allCoordinates: [CLLocationCoordinate2D] = []
        for route in routes {
            let coords = await fetchLocations(from: route)
            allCoordinates.append(contentsOf: coords)
        }

        return allCoordinates
    }

    /// Extract CLLocation data from an HKWorkoutRoute
    private func fetchLocations(from route: HKWorkoutRoute) async -> [CLLocationCoordinate2D] {
        await withCheckedContinuation { continuation in
            var coordinates: [CLLocationCoordinate2D] = []

            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                if let error {
                    Log.health.error("Route query error: \(error)")
                }
                if let locations {
                    coordinates.append(contentsOf: locations.map { $0.coordinate })
                }
                if done {
                    continuation.resume(returning: coordinates)
                }
            }
            self.healthStore.execute(query)
        }
    }
}
