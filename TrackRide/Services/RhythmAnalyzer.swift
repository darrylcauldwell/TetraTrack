//
//  RhythmAnalyzer.swift
//  TrackRide
//
//  Analyzes stride rhythm by detecting stride cycles from
//  acceleration patterns and calculating rhythm consistency.

import Foundation

/// Analyzes motion data to calculate rhythm consistency score
final class RhythmAnalyzer: Resettable, ReinAwareAnalyzer {
    // MARK: - Public Properties

    /// Current rhythm score (0-100%)
    private(set) var currentRhythmScore: Double = 0.0

    /// Current stride rate (strides per minute)
    private(set) var currentStrideRate: Double = 0.0

    /// Average rhythm on left rein (ReinAwareAnalyzer)
    var leftReinScore: Double { reinScores.leftReinAverage }

    /// Average rhythm on right rein (ReinAwareAnalyzer)
    var rightReinScore: Double { reinScores.rightReinAverage }

    /// Legacy accessors for compatibility
    var leftReinRhythm: Double { leftReinScore }
    var rightReinRhythm: Double { rightReinScore }

    // MARK: - Configuration

    /// Window size for rhythm analysis (samples)
    private let analysisWindowSize: Int = 300  // 6 seconds at 50Hz

    /// Minimum stride cycles needed for analysis
    private let minimumStrideCycles: Int = 3

    /// Expected stride rate ranges per gait (strides/minute)
    private let gaitStrideRates: [GaitType: ClosedRange<Double>] = [
        .walk: 50...65,
        .trot: 70...85,
        .canter: 90...110,
        .gallop: 110...140
    ]

    // MARK: - Internal State

    /// Vertical acceleration history (using RollingBuffer)
    private var accelBuffer: TimestampedRollingBuffer<Double>

    /// Detected stride timestamps
    private var strideTimes: [Date] = []

    /// Per-rein rhythm tracking (using ReinScoreTracker)
    private var reinScores = ReinScoreTracker()

    /// Current rein and gait
    private var currentRein: ReinDirection = .straight
    private var currentGait: GaitType = .stationary

    /// Last zero-crossing detection state
    private var lastWasPositive: Bool = false

    init() {
        accelBuffer = TimestampedRollingBuffer(capacity: analysisWindowSize)
    }

    // MARK: - Public Methods

    /// Process a motion sample for rhythm analysis
    /// - Parameters:
    ///   - sample: Motion sample from MotionManager
    ///   - currentGait: Current detected gait type
    func processMotionSample(_ sample: MotionSample, currentGait: GaitType) {
        self.currentGait = currentGait

        // Skip stationary
        guard currentGait != .stationary else {
            currentRhythmScore = 0.0
            currentStrideRate = 0.0
            return
        }

        // Use vertical acceleration (Z-axis) for stride detection
        accelBuffer.append(sample.verticalAcceleration, at: sample.timestamp)

        // Detect stride cycles via zero-crossings
        detectStrideCycle(accel: sample.verticalAcceleration, timestamp: sample.timestamp)

        // Calculate rhythm
        if strideTimes.count >= minimumStrideCycles {
            calculateRhythm()
        }
    }

    /// Update current rein for per-rein tracking
    func updateRein(_ rein: ReinDirection) {
        // Finalize previous rein if changing
        if currentRein != rein && currentRein != .straight {
            finalizeReinSegment()
        }
        currentRein = rein
    }

    /// Finalize rhythm scores for current rein segment (ReinAwareAnalyzer)
    func finalizeReinSegment() {
        reinScores.recordScore(currentRhythmScore, for: currentRein)
    }

    /// Reset all state
    func reset() {
        accelBuffer.removeAll()
        strideTimes.removeAll()
        reinScores.reset()
        currentRhythmScore = 0.0
        currentStrideRate = 0.0
        currentRein = .straight
        currentGait = .stationary
        lastWasPositive = false
    }

    // MARK: - Stride Detection

    /// Detect stride cycles using zero-crossing detection
    /// A complete stride cycle is detected when acceleration crosses from
    /// negative to positive (upward phase of stride)
    private func detectStrideCycle(accel: Double, timestamp: Date) {
        let isPositive = accel > 0

        // Detect zero-crossing from negative to positive
        if isPositive && !lastWasPositive {
            // Filter out noise: require minimum interval between strides
            let minInterval: TimeInterval = 0.3  // Max ~200 strides/min
            let maxInterval: TimeInterval = 2.0  // Min ~30 strides/min

            if let lastStride = strideTimes.last {
                let interval = timestamp.timeIntervalSince(lastStride)
                if interval >= minInterval && interval <= maxInterval {
                    strideTimes.append(timestamp)
                }
            } else {
                strideTimes.append(timestamp)
            }

            // Keep only recent strides
            let cutoffTime = Date().addingTimeInterval(-6.0)
            strideTimes.removeAll { $0 < cutoffTime }
        }

        lastWasPositive = isPositive
    }

    // MARK: - Rhythm Calculation

    private func calculateRhythm() {
        guard strideTimes.count >= minimumStrideCycles else {
            currentRhythmScore = 0.0
            return
        }

        // Calculate stride intervals
        var intervals: [TimeInterval] = []
        for i in 1..<strideTimes.count {
            let interval = strideTimes[i].timeIntervalSince(strideTimes[i - 1])
            intervals.append(interval)
        }

        guard !intervals.isEmpty else {
            currentRhythmScore = 0.0
            return
        }

        // Calculate stride rate
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        currentStrideRate = avgInterval > 0 ? 60.0 / avgInterval : 0.0

        // Calculate rhythm score based on interval consistency
        let rhythmScore = calculateIntervalConsistency(intervals)

        // Bonus/penalty based on expected gait stride rate
        let gaitBonus = calculateGaitAppropriatenessScore()

        // Combined rhythm score
        currentRhythmScore = rhythmScore * 0.8 + gaitBonus * 0.2
    }

    /// Calculate how consistent the stride intervals are
    private func calculateIntervalConsistency(_ intervals: [TimeInterval]) -> Double {
        guard intervals.count >= 2 else { return 50.0 }

        // Calculate coefficient of variation
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        let variance = intervals.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(intervals.count)
        let stdDev = sqrt(variance)
        let cv = mean > 0 ? stdDev / mean : 0.0

        // Convert CV to rhythm score
        // CV of 0 = perfect rhythm (100%)
        // CV of 0.2 = poor rhythm (0%)
        let score = (1.0 - min(1.0, cv / 0.2)) * 100

        return max(0.0, score)
    }

    /// Calculate bonus based on stride rate appropriateness for current gait
    private func calculateGaitAppropriatenessScore() -> Double {
        guard let expectedRange = gaitStrideRates[currentGait] else {
            return 50.0  // Neutral score if gait not in range map
        }

        if expectedRange.contains(currentStrideRate) {
            return 100.0  // Perfect if within expected range
        }

        // Calculate how far outside the range
        let midpoint = (expectedRange.lowerBound + expectedRange.upperBound) / 2
        let rangeSize = expectedRange.upperBound - expectedRange.lowerBound
        let deviation = abs(currentStrideRate - midpoint)

        // Score decreases with distance from expected range
        // One range-width away = 50% score
        let score = max(0.0, 100.0 - (deviation / rangeSize) * 50.0)

        return score
    }

    // MARK: - Gait-Specific Analysis

    /// Get rhythm score for current segment
    func rhythmForGait(_ gait: GaitType) -> Double {
        return currentRhythmScore
    }

    /// Get expected stride rate range for a gait
    func expectedStrideRateRange(for gait: GaitType) -> ClosedRange<Double>? {
        return gaitStrideRates[gait]
    }
}
