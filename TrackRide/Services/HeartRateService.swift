//
//  HeartRateService.swift
//  TrackRide
//
//  Live heart rate tracking service
//

import Foundation
import HealthKit
import Observation
import os

@Observable
final class HeartRateService {
    // MARK: - Published State

    private(set) var currentHeartRate: Int = 0
    private(set) var averageHeartRate: Int = 0
    private(set) var maxHeartRate: Int = 0
    private(set) var minHeartRate: Int = 0
    private(set) var currentZone: HeartRateZone = .zone1
    private(set) var isMonitoring: Bool = false
    private(set) var samples: [HeartRateSample] = []

    // MARK: - Configuration

    private var riderMaxHeartRate: Int = 180
    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?
    private var anchoredQuery: HKAnchoredObjectQuery?
    private var queryAnchor: HKQueryAnchor?

    // MARK: - Fall Detection Integration

    private var validator = HeartRateValidator()

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Configure with rider's max heart rate for zone calculations
    func configure(maxHeartRate: Int) {
        self.riderMaxHeartRate = maxHeartRate
    }

    /// Start monitoring heart rate
    func startMonitoring() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            Log.health.warning("HeartRateService: HealthKit not available")
            return
        }

        // Request authorization if needed
        let heartRateType = HKQuantityType(.heartRate)
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [heartRateType])
        } catch {
            Log.health.error("HeartRateService: Authorization failed - \(error)")
            return
        }

        resetState()
        isMonitoring = true

        // Start observer query for real-time updates
        startObserverQuery()

        // Also start anchored query for batch updates
        startAnchoredQuery()
    }

    /// Stop monitoring heart rate
    func stopMonitoring() {
        isMonitoring = false

        if let query = observerQuery {
            healthStore.stop(query)
            observerQuery = nil
        }

        if let query = anchoredQuery {
            healthStore.stop(query)
            anchoredQuery = nil
        }
    }

    /// Process a heart rate value received from Watch
    func processHeartRate(_ bpm: Int) {
        guard isMonitoring, bpm > 0 else { return }

        // Validate the sample for fall detection
        let validation = validator.validate(bpm)
        if case .outOfRange = validation {
            // Skip out-of-range values
            return
        }

        let sample = HeartRateSample(
            timestamp: Date(),
            bpm: bpm,
            maxHeartRate: riderMaxHeartRate
        )

        samples.append(sample)
        updateStatistics(with: bpm)
    }

    /// Get final statistics for the ride
    func getFinalStatistics() -> HeartRateStatistics {
        HeartRateStatistics(samples: samples)
    }

    /// Reset all state
    func resetState() {
        currentHeartRate = 0
        averageHeartRate = 0
        maxHeartRate = 0
        minHeartRate = 0
        currentZone = .zone1
        samples = []
        queryAnchor = nil
        validator.reset()
    }

    // MARK: - Private Methods

    private func startObserverQuery() {
        let heartRateType = HKQuantityType(.heartRate)

        observerQuery = HKObserverQuery(
            sampleType: heartRateType,
            predicate: nil
        ) { [weak self] _, completionHandler, error in
            if let error = error {
                Log.health.error("HeartRateService: Observer error - \(error)")
                completionHandler()
                return
            }

            // Fetch latest sample
            self?.fetchLatestHeartRate()
            completionHandler()
        }

        if let query = observerQuery {
            healthStore.execute(query)
        }
    }

    private func startAnchoredQuery() {
        let heartRateType = HKQuantityType(.heartRate)
        let now = Date()
        let predicate = HKQuery.predicateForSamples(
            withStart: now,
            end: nil,
            options: .strictStartDate
        )

        anchoredQuery = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: queryAnchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, anchor, error in
            self?.handleAnchoredQueryResults(samples: samples, anchor: anchor, error: error)
        }

        anchoredQuery?.updateHandler = { [weak self] _, samples, _, anchor, error in
            self?.handleAnchoredQueryResults(samples: samples, anchor: anchor, error: error)
        }

        if let query = anchoredQuery {
            healthStore.execute(query)
        }
    }

    private func handleAnchoredQueryResults(
        samples: [HKSample]?,
        anchor: HKQueryAnchor?,
        error: Error?
    ) {
        if let error = error {
            Log.health.error("HeartRateService: Anchored query error - \(error)")
            return
        }

        queryAnchor = anchor

        guard let heartRateSamples = samples as? [HKQuantitySample] else { return }

        for sample in heartRateSamples {
            let bpm = Int(sample.quantity.doubleValue(for: .count().unitDivided(by: .minute())))
            processHeartRate(bpm)
        }
    }

    private func fetchLatestHeartRate() {
        let heartRateType = HKQuantityType(.heartRate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard error == nil,
                  let sample = samples?.first as? HKQuantitySample else {
                return
            }

            let bpm = Int(sample.quantity.doubleValue(for: .count().unitDivided(by: .minute())))

            DispatchQueue.main.async {
                self?.processHeartRate(bpm)
            }
        }

        healthStore.execute(query)
    }

    private func updateStatistics(with bpm: Int) {
        currentHeartRate = bpm
        currentZone = HeartRateZone.zone(for: bpm, maxHR: riderMaxHeartRate)

        // Update max
        if bpm > maxHeartRate {
            maxHeartRate = bpm
        }

        // Update min
        if minHeartRate == 0 || bpm < minHeartRate {
            minHeartRate = bpm
        }

        // Update average
        if !samples.isEmpty {
            averageHeartRate = samples.map(\.bpm).reduce(0, +) / samples.count
        }
    }

    // MARK: - Fall Detection Integration

    /// Get confidence modifier for fall detection based on heart rate state
    /// Returns 0.85-1.15 where:
    /// - 0.85 = stable HR, less likely to be a fall (raise threshold)
    /// - 1.0 = neutral
    /// - 1.15 = HR spike detected, more likely to be a fall (lower threshold)
    func getHeartRateConfidenceModifier() -> Double {
        // If we detect a spike, increase sensitivity
        if validator.detectSpike() {
            return 1.15
        }

        // If HR is stable, decrease sensitivity slightly
        if validator.isStable() {
            return 0.85
        }

        // Neutral modifier
        return 1.0
    }

    /// Check if there was a recent heart rate spike (potential fall indicator)
    func recentHeartRateSpike() -> Bool {
        validator.detectSpike()
    }

    /// Check if heart rate is currently stable
    func isHeartRateStable() -> Bool {
        validator.isStable()
    }

    /// Get recent rate of change in BPM/second
    func heartRateChangeRate() -> Double? {
        validator.recentRateOfChange()
    }
}
