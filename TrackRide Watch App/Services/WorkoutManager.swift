//
//  WorkoutManager.swift
//  TrackRide Watch App
//
//  Manages HKWorkoutSession for live heart rate streaming
//

import Foundation
import HealthKit
import Observation

@Observable
final class WorkoutManager: NSObject {
    // MARK: - State

    private(set) var isWorkoutActive: Bool = false
    private(set) var currentHeartRate: Int = 0
    private(set) var averageHeartRate: Int = 0
    private(set) var maxHeartRate: Int = 0
    private(set) var minHeartRate: Int = 0

    // MARK: - Private

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var heartRateSamples: [Int] = []

    // MARK: - Callbacks

    var onHeartRateUpdate: ((Int) -> Void)?

    // MARK: - Initialization

    override init() {
        super.init()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            return false
        }

        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.heartRate)
        ]

        let typesToShare: Set<HKSampleType> = [
            HKQuantityType.workoutType()
        ]

        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            return true
        } catch {
            print("WorkoutManager: Authorization failed - \(error)")
            return false
        }
    }

    // MARK: - Workout Control

    func startWorkout() async {
        guard !isWorkoutActive else { return }

        let authorized = await requestAuthorization()
        guard authorized else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .equestrianSports
        configuration.locationType = .outdoor

        do {
            workoutSession = try HKWorkoutSession(
                healthStore: healthStore,
                configuration: configuration
            )
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()

            workoutSession?.delegate = self
            workoutBuilder?.delegate = self
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            // Start the session and builder
            let startDate = Date()
            workoutSession?.startActivity(with: startDate)
            try await workoutBuilder?.beginCollection(at: startDate)

            isWorkoutActive = true
            heartRateSamples = []
            currentHeartRate = 0
            averageHeartRate = 0
            maxHeartRate = 0
            minHeartRate = 0

            // Trigger haptic
            HapticManager.shared.playStartHaptic()

        } catch {
            print("WorkoutManager: Failed to start workout - \(error)")
        }
    }

    func pauseWorkout() async {
        guard isWorkoutActive else { return }
        workoutSession?.pause()
        HapticManager.shared.playPauseHaptic()
    }

    func resumeWorkout() async {
        guard isWorkoutActive else { return }
        workoutSession?.resume()
        HapticManager.shared.playResumeHaptic()
    }

    func stopWorkout() async {
        guard isWorkoutActive else { return }

        workoutSession?.end()

        do {
            try await workoutBuilder?.endCollection(at: Date())
            try await workoutBuilder?.finishWorkout()
        } catch {
            print("WorkoutManager: Failed to end workout - \(error)")
        }

        isWorkoutActive = false
        HapticManager.shared.playStopHaptic()
    }

    // MARK: - Private Methods

    private func processHeartRate(_ value: Double) {
        let bpm = Int(value)
        guard bpm > 0 else { return }

        heartRateSamples.append(bpm)
        currentHeartRate = bpm

        // Update max
        if bpm > maxHeartRate {
            maxHeartRate = bpm
        }

        // Update min
        if minHeartRate == 0 || bpm < minHeartRate {
            minHeartRate = bpm
        }

        // Update average
        if !heartRateSamples.isEmpty {
            averageHeartRate = heartRateSamples.reduce(0, +) / heartRateSamples.count
        }

        // Notify callback
        onHeartRateUpdate?(bpm)
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        print("WorkoutManager: State changed from \(fromState.rawValue) to \(toState.rawValue)")
    }

    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        print("WorkoutManager: Session error - \(error)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  quantityType == HKQuantityType(.heartRate) else {
                continue
            }

            let statistics = workoutBuilder.statistics(for: quantityType)
            if let heartRate = statistics?.mostRecentQuantity()?.doubleValue(
                for: .count().unitDivided(by: .minute())
            ) {
                DispatchQueue.main.async {
                    self.processHeartRate(heartRate)
                }
            }
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }
}
