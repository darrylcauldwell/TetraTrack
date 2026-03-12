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

        let hkWorkouts: [HKWorkout]
        do {
            let descriptor = HKSampleQueryDescriptor<HKWorkout>(
                predicates: [.workout(predicate)],
                sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
            )
            hkWorkouts = try await descriptor.result(for: healthStore)
        } catch {
            Log.health.error("Failed to fetch external workouts: \(error)")
            return
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

        let descriptor = HKSampleQueryDescriptor<HKQuantitySample>(
            predicates: [.quantitySample(type: heartRateType, predicate: predicate)],
            sortDescriptors: []
        )

        do {
            let samples = try await descriptor.result(for: healthStore)
            guard !samples.isEmpty else { return nil }
            let total = samples.reduce(0.0) { sum, sample in
                sum + sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            }
            return total / Double(samples.count)
        } catch {
            Log.health.error("Failed to fetch heart rate: \(error)")
            return nil
        }
    }

    // MARK: - Route Availability

    /// Check whether a workout has an associated GPS route
    private func checkRouteAvailability(for workout: HKWorkout) async -> Bool {
        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)

        let descriptor = HKSampleQueryDescriptor<HKSample>(
            predicates: [.sample(type: routeType, predicate: predicate)],
            sortDescriptors: [],
            limit: 1
        )

        do {
            let results = try await descriptor.result(for: healthStore)
            return !results.isEmpty
        } catch {
            return false
        }
    }

    // MARK: - Route Data (Issue 3.2)

    /// Fetch GPS route coordinates for an external workout
    func fetchRouteCoordinates(for workoutId: UUID, startDate: Date, endDate: Date) async -> [CLLocationCoordinate2D] {
        // First find the workout
        let predicate = HKQuery.predicateForObject(with: workoutId)

        let workoutDescriptor = HKSampleQueryDescriptor<HKWorkout>(
            predicates: [.workout(predicate)],
            sortDescriptors: [],
            limit: 1
        )

        guard let workout = try? await workoutDescriptor.result(for: healthStore).first else {
            return []
        }

        // Fetch route samples
        let routeType = HKSeriesType.workoutRoute()
        let routePredicate = HKQuery.predicateForObjects(from: workout)

        let routeDescriptor = HKSampleQueryDescriptor<HKSample>(
            predicates: [.sample(type: routeType, predicate: routePredicate)],
            sortDescriptors: []
        )

        let routeSamples = (try? await routeDescriptor.result(for: healthStore)) ?? []
        let routes = routeSamples.compactMap { $0 as? HKWorkoutRoute }

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
        let descriptor = HKWorkoutRouteQueryDescriptor(route)
        var coordinates: [CLLocationCoordinate2D] = []

        do {
            for try await location in descriptor.results(for: healthStore) {
                coordinates.append(location.coordinate)
            }
        } catch {
            Log.health.error("Route query error: \(error)")
        }

        return coordinates
    }
}
