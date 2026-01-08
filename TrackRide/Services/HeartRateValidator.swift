//
//  HeartRateValidator.swift
//  TrackRide
//
//  Validates heart rate data and detects anomalies for fall detection integration
//

import Foundation

/// Validation result for heart rate samples
enum HeartRateValidationResult {
    case valid
    case outOfRange
    case rateOfChangeTooHigh
    case noHistory
}

/// Heart rate sample with timestamp for rate-of-change calculations
struct TimestampedHeartRate {
    let bpm: Int
    let timestamp: Date
}

/// Validates heart rate samples and detects spikes/anomalies
/// Used to adjust fall detection sensitivity based on physiological state
struct HeartRateValidator {
    // MARK: - Constants

    /// Valid heart rate range (30-220 BPM covers all normal human activity)
    static let validRange = 30...220

    /// Maximum reasonable rate of change in BPM per second
    /// Elite athletes can spike 20+ BPM in one second during max effort
    static let maxRateOfChange: Double = 20.0

    /// Threshold for detecting a sudden spike (BPM increase)
    static let spikeThreshold: Double = 15.0

    /// Window size for stability calculation (seconds)
    static let stabilityWindowSeconds: TimeInterval = 5.0

    // MARK: - State

    private var history: [TimestampedHeartRate] = []
    private let maxHistorySize = 60  // Keep ~1 minute of history at 1Hz

    // MARK: - Validation

    /// Validate a heart rate sample
    mutating func validate(_ bpm: Int, at timestamp: Date = Date()) -> HeartRateValidationResult {
        // Check range
        guard Self.validRange.contains(bpm) else {
            return .outOfRange
        }

        // Check rate of change if we have history
        if let lastSample = history.last {
            let timeDelta = timestamp.timeIntervalSince(lastSample.timestamp)
            if timeDelta > 0 {
                let bpmDelta = abs(Double(bpm - lastSample.bpm))
                let rateOfChange = bpmDelta / timeDelta

                if rateOfChange > Self.maxRateOfChange {
                    // Still add to history but flag as suspicious
                    addToHistory(bpm: bpm, timestamp: timestamp)
                    return .rateOfChangeTooHigh
                }
            }
        } else if history.isEmpty {
            addToHistory(bpm: bpm, timestamp: timestamp)
            return .noHistory
        }

        addToHistory(bpm: bpm, timestamp: timestamp)
        return .valid
    }

    private mutating func addToHistory(bpm: Int, timestamp: Date) {
        history.append(TimestampedHeartRate(bpm: bpm, timestamp: timestamp))

        // Trim old entries
        if history.count > maxHistorySize {
            history.removeFirst(history.count - maxHistorySize)
        }
    }

    // MARK: - Analysis

    /// Calculate recent rate of change (BPM/second over last few samples)
    func recentRateOfChange() -> Double? {
        guard history.count >= 2 else { return nil }

        let recent = history.suffix(5)
        guard let first = recent.first, let last = recent.last else { return nil }

        let timeDelta = last.timestamp.timeIntervalSince(first.timestamp)
        guard timeDelta > 0 else { return nil }

        let bpmDelta = Double(last.bpm - first.bpm)
        return bpmDelta / timeDelta
    }

    /// Detect if there was a recent sudden spike in heart rate
    /// A spike often occurs during/after physical trauma (like a fall)
    func detectSpike(threshold: Double = HeartRateValidator.spikeThreshold) -> Bool {
        guard history.count >= 2 else { return false }

        // Look at recent samples (last 3-5 seconds)
        let now = Date()
        let recentSamples = history.filter { now.timeIntervalSince($0.timestamp) <= 5.0 }

        guard recentSamples.count >= 2 else { return false }

        // Check if any consecutive pair shows a spike
        for i in 1..<recentSamples.count {
            let previous = recentSamples[i - 1]
            let current = recentSamples[i]
            let increase = Double(current.bpm - previous.bpm)

            if increase >= threshold {
                return true
            }
        }

        return false
    }

    /// Check if heart rate is stable (low variance over stability window)
    func isStable() -> Bool {
        let now = Date()
        let windowSamples = history.filter {
            now.timeIntervalSince($0.timestamp) <= Self.stabilityWindowSeconds
        }

        guard windowSamples.count >= 3 else { return false }

        let bpmValues = windowSamples.map { Double($0.bpm) }
        let mean = bpmValues.reduce(0, +) / Double(bpmValues.count)

        // Calculate standard deviation
        let variance = bpmValues.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(bpmValues.count)
        let stdDev = sqrt(variance)

        // HR is stable if std dev is less than 5 BPM
        return stdDev < 5.0
    }

    /// Get average heart rate over the stability window
    func averageHeartRate() -> Int? {
        let now = Date()
        let windowSamples = history.filter {
            now.timeIntervalSince($0.timestamp) <= Self.stabilityWindowSeconds
        }

        guard !windowSamples.isEmpty else { return nil }

        let sum = windowSamples.reduce(0) { $0 + $1.bpm }
        return sum / windowSamples.count
    }

    /// Get the most recent valid heart rate
    var latestHeartRate: Int? {
        history.last?.bpm
    }

    /// Reset the validator state
    mutating func reset() {
        history.removeAll()
    }
}
