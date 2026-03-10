//
//  HeartRateService.swift
//  TetraTrack
//
//  Live heart rate tracking service
//

import Foundation
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
    private(set) var samples: [HeartRateSample] = []

    // MARK: - Configuration

    private var riderMaxHeartRate: Int = 180

    // MARK: - Fall Detection Integration

    private var validator = HeartRateValidator()

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Configure with rider's max heart rate for zone calculations
    func configure(maxHeartRate: Int) {
        self.riderMaxHeartRate = maxHeartRate
    }

    /// Process a heart rate value received from Watch
    func processHeartRate(_ bpm: Int) {
        guard bpm > 0 else { return }

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
        validator.reset()
    }

    // MARK: - Private Methods

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
