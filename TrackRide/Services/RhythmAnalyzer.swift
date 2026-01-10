//
//  RhythmAnalyzer.swift
//  TrackRide
//
//  Comprehensive rhythm analysis using all available sensor data:
//  - Accelerometer (X, Y, Z axes) for stride impact and bounce detection
//  - Gyroscope (rotation rates) for body rotation patterns
//  - Attitude (pitch, roll) for rider movement patterns
//
//  Rhythm is calculated by analyzing the consistency of stride cycles
//  detected across multiple sensor channels and fusing them for accuracy.

import Foundation

/// Analyzes motion data to calculate rhythm consistency score using all available sensors
final class RhythmAnalyzer: Resettable, ReinAwareAnalyzer {
    // MARK: - Public Properties

    /// Current rhythm score (0-100%)
    private(set) var currentRhythmScore: Double = 0.0

    /// Current stride rate (strides per minute)
    private(set) var currentStrideRate: Double = 0.0

    /// Confidence in the current rhythm measurement (0-1)
    private(set) var rhythmConfidence: Double = 0.0

    /// Average rhythm on left rein (ReinAwareAnalyzer)
    var leftReinScore: Double { reinScores.leftReinAverage }

    /// Average rhythm on right rein (ReinAwareAnalyzer)
    var rightReinScore: Double { reinScores.rightReinAverage }

    /// Legacy accessors for compatibility
    var leftReinRhythm: Double { leftReinScore }
    var rightReinRhythm: Double { rightReinScore }

    // MARK: - Configuration

    /// Window size for rhythm analysis (samples at 50Hz)
    private let analysisWindowSize: Int = 300  // 6 seconds

    /// Minimum stride cycles needed for analysis
    private let minimumStrideCycles: Int = 4

    /// Expected stride rate ranges per gait (strides/minute)
    private let gaitStrideRates: [GaitType: ClosedRange<Double>] = [
        .walk: 50...65,
        .trot: 70...85,
        .canter: 90...110,
        .gallop: 110...140
    ]

    // MARK: - Multi-Channel Sensor Buffers

    /// Vertical acceleration (primary bounce signal)
    private var verticalAccelBuffer: TimestampedRollingBuffer<Double>

    /// Combined acceleration magnitude (overall movement intensity)
    private var accelMagnitudeBuffer: TimestampedRollingBuffer<Double>

    /// Forward acceleration (forward/back motion)
    private var forwardAccelBuffer: TimestampedRollingBuffer<Double>

    /// Pitch rate (forward/back tilting)
    private var pitchBuffer: TimestampedRollingBuffer<Double>

    /// Roll rate (side-to-side tilting)
    private var rollBuffer: TimestampedRollingBuffer<Double>

    /// Yaw rate (rotation around vertical axis)
    private var yawRateBuffer: TimestampedRollingBuffer<Double>

    /// Rotation magnitude (overall rotational movement)
    private var rotationMagnitudeBuffer: TimestampedRollingBuffer<Double>

    // MARK: - Stride Detection State

    /// Detected stride timestamps from each channel
    private var verticalStrideTimes: [Date] = []
    private var magnitudeStrideTimes: [Date] = []
    private var pitchStrideTimes: [Date] = []
    private var rotationStrideTimes: [Date] = []

    /// Per-rein rhythm tracking
    private var reinScores = ReinScoreTracker()

    /// Current rein and gait
    private var currentRein: ReinDirection = .straight
    private var currentGait: GaitType = .stationary

    /// Zero-crossing detection state for each channel
    private var verticalLastPositive: Bool = false
    private var magnitudeLastAboveThreshold: Bool = false
    private var pitchLastPositive: Bool = false
    private var rotationLastAboveThreshold: Bool = false

    /// Running statistics for adaptive thresholds
    private var verticalMean: Double = 0
    private var verticalStdDev: Double = 0.1
    private var magnitudeMean: Double = 0
    private var magnitudeStdDev: Double = 0.1

    init() {
        verticalAccelBuffer = TimestampedRollingBuffer(capacity: analysisWindowSize)
        accelMagnitudeBuffer = TimestampedRollingBuffer(capacity: analysisWindowSize)
        forwardAccelBuffer = TimestampedRollingBuffer(capacity: analysisWindowSize)
        pitchBuffer = TimestampedRollingBuffer(capacity: analysisWindowSize)
        rollBuffer = TimestampedRollingBuffer(capacity: analysisWindowSize)
        yawRateBuffer = TimestampedRollingBuffer(capacity: analysisWindowSize)
        rotationMagnitudeBuffer = TimestampedRollingBuffer(capacity: analysisWindowSize)
    }

    // MARK: - Public Methods

    /// Process a motion sample for rhythm analysis using all sensor channels
    func processMotionSample(_ sample: MotionSample, currentGait: GaitType) {
        self.currentGait = currentGait

        // Skip stationary
        guard currentGait != .stationary else {
            currentRhythmScore = 0.0
            currentStrideRate = 0.0
            rhythmConfidence = 0.0
            return
        }

        let timestamp = sample.timestamp

        // Store all sensor channels
        verticalAccelBuffer.append(sample.verticalAcceleration, at: timestamp)
        accelMagnitudeBuffer.append(sample.accelerationMagnitude, at: timestamp)
        forwardAccelBuffer.append(sample.forwardAcceleration, at: timestamp)
        pitchBuffer.append(sample.pitch, at: timestamp)
        rollBuffer.append(sample.roll, at: timestamp)
        yawRateBuffer.append(sample.yawRate, at: timestamp)
        rotationMagnitudeBuffer.append(sample.rotationMagnitude, at: timestamp)

        // Update running statistics for adaptive thresholds
        updateRunningStatistics(sample)

        // Detect stride cycles from multiple channels
        detectVerticalStride(sample.verticalAcceleration, timestamp: timestamp)
        detectMagnitudeStride(sample.accelerationMagnitude, timestamp: timestamp)
        detectPitchStride(sample.pitch, timestamp: timestamp)
        detectRotationStride(sample.rotationMagnitude, timestamp: timestamp)

        // Calculate fused rhythm from all channels
        if hasEnoughData() {
            calculateFusedRhythm()
        }
    }

    /// Update current rein for per-rein tracking
    func updateRein(_ rein: ReinDirection) {
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
        verticalAccelBuffer.removeAll()
        accelMagnitudeBuffer.removeAll()
        forwardAccelBuffer.removeAll()
        pitchBuffer.removeAll()
        rollBuffer.removeAll()
        yawRateBuffer.removeAll()
        rotationMagnitudeBuffer.removeAll()

        verticalStrideTimes.removeAll()
        magnitudeStrideTimes.removeAll()
        pitchStrideTimes.removeAll()
        rotationStrideTimes.removeAll()

        reinScores.reset()
        currentRhythmScore = 0.0
        currentStrideRate = 0.0
        rhythmConfidence = 0.0
        currentRein = .straight
        currentGait = .stationary

        verticalLastPositive = false
        magnitudeLastAboveThreshold = false
        pitchLastPositive = false
        rotationLastAboveThreshold = false

        verticalMean = 0
        verticalStdDev = 0.1
        magnitudeMean = 0
        magnitudeStdDev = 0.1
    }

    // MARK: - Running Statistics

    /// Update running mean and standard deviation for adaptive thresholds
    private func updateRunningStatistics(_ sample: MotionSample) {
        let alpha = 0.01  // Slow adaptation

        // Vertical acceleration statistics
        let vertDelta = sample.verticalAcceleration - verticalMean
        verticalMean += alpha * vertDelta
        verticalStdDev = sqrt((1 - alpha) * verticalStdDev * verticalStdDev + alpha * vertDelta * vertDelta)

        // Magnitude statistics
        let magDelta = sample.accelerationMagnitude - magnitudeMean
        magnitudeMean += alpha * magDelta
        magnitudeStdDev = sqrt((1 - alpha) * magnitudeStdDev * magnitudeStdDev + alpha * magDelta * magDelta)
    }

    // MARK: - Multi-Channel Stride Detection

    /// Detect stride from vertical acceleration (bounce pattern)
    private func detectVerticalStride(_ value: Double, timestamp: Date) {
        let isPositive = value > 0

        // Zero-crossing from negative to positive indicates upward phase of stride
        if isPositive && !verticalLastPositive {
            addStrideIfValid(to: &verticalStrideTimes, timestamp: timestamp)
        }
        verticalLastPositive = isPositive
    }

    /// Detect stride from acceleration magnitude (impact peaks)
    private func detectMagnitudeStride(_ value: Double, timestamp: Date) {
        // Adaptive threshold: mean + 0.5 * stdDev
        let threshold = max(0.15, magnitudeMean + 0.5 * magnitudeStdDev)
        let isAbove = value > threshold

        // Detect when crossing above threshold (impact moment)
        if isAbove && !magnitudeLastAboveThreshold {
            addStrideIfValid(to: &magnitudeStrideTimes, timestamp: timestamp)
        }
        magnitudeLastAboveThreshold = isAbove
    }

    /// Detect stride from pitch changes (rider tilting forward/back)
    private func detectPitchStride(_ value: Double, timestamp: Date) {
        let isPositive = value > 0

        // Pitch oscillates with each stride
        if isPositive && !pitchLastPositive {
            addStrideIfValid(to: &pitchStrideTimes, timestamp: timestamp)
        }
        pitchLastPositive = isPositive
    }

    /// Detect stride from rotation magnitude (overall rotational movement)
    private func detectRotationStride(_ value: Double, timestamp: Date) {
        let threshold: Double = 0.3  // rad/s threshold for significant rotation
        let isAbove = value > threshold

        if isAbove && !rotationLastAboveThreshold {
            addStrideIfValid(to: &rotationStrideTimes, timestamp: timestamp)
        }
        rotationLastAboveThreshold = isAbove
    }

    /// Add stride timestamp if interval is valid
    private func addStrideIfValid(to strideTimes: inout [Date], timestamp: Date) {
        let minInterval: TimeInterval = 0.25  // Max ~240 strides/min
        let maxInterval: TimeInterval = 2.0   // Min ~30 strides/min

        if let lastStride = strideTimes.last {
            let interval = timestamp.timeIntervalSince(lastStride)
            if interval >= minInterval && interval <= maxInterval {
                strideTimes.append(timestamp)
            }
        } else {
            strideTimes.append(timestamp)
        }

        // Keep only recent strides (6 seconds)
        let cutoffTime = Date().addingTimeInterval(-6.0)
        strideTimes.removeAll { $0 < cutoffTime }
    }

    // MARK: - Fused Rhythm Calculation

    private func hasEnoughData() -> Bool {
        // Need at least one channel with enough strides
        return verticalStrideTimes.count >= minimumStrideCycles ||
               magnitudeStrideTimes.count >= minimumStrideCycles ||
               pitchStrideTimes.count >= minimumStrideCycles
    }

    /// Calculate rhythm by fusing data from all sensor channels
    private func calculateFusedRhythm() {
        // Calculate rhythm from each channel
        let verticalRhythm = calculateChannelRhythm(strideTimes: verticalStrideTimes)
        let magnitudeRhythm = calculateChannelRhythm(strideTimes: magnitudeStrideTimes)
        let pitchRhythm = calculateChannelRhythm(strideTimes: pitchStrideTimes)
        let rotationRhythm = calculateChannelRhythm(strideTimes: rotationStrideTimes)

        // Weight channels by their data quality (number of detected strides)
        var totalWeight: Double = 0
        var weightedRhythm: Double = 0
        var weightedStrideRate: Double = 0

        if verticalRhythm.isValid {
            let weight = 2.0  // Vertical is primary signal for horse bounce
            totalWeight += weight
            weightedRhythm += verticalRhythm.score * weight
            weightedStrideRate += verticalRhythm.strideRate * weight
        }

        if magnitudeRhythm.isValid {
            let weight = 1.5  // Magnitude captures overall impact
            totalWeight += weight
            weightedRhythm += magnitudeRhythm.score * weight
            weightedStrideRate += magnitudeRhythm.strideRate * weight
        }

        if pitchRhythm.isValid {
            let weight = 1.0  // Pitch shows rider movement
            totalWeight += weight
            weightedRhythm += pitchRhythm.score * weight
            weightedStrideRate += pitchRhythm.strideRate * weight
        }

        if rotationRhythm.isValid {
            let weight = 0.5  // Rotation is secondary signal
            totalWeight += weight
            weightedRhythm += rotationRhythm.score * weight
            weightedStrideRate += rotationRhythm.strideRate * weight
        }

        guard totalWeight > 0 else {
            currentRhythmScore = 0.0
            currentStrideRate = 0.0
            rhythmConfidence = 0.0
            return
        }

        // Calculate weighted average
        let baseRhythm = weightedRhythm / totalWeight
        currentStrideRate = weightedStrideRate / totalWeight

        // Apply gait appropriateness bonus
        let gaitBonus = calculateGaitAppropriatenessScore()

        // Combined rhythm score (80% consistency, 20% gait appropriateness)
        currentRhythmScore = baseRhythm * 0.8 + gaitBonus * 0.2

        // Confidence based on channel agreement and data quantity
        rhythmConfidence = calculateConfidence(
            rhythms: [verticalRhythm, magnitudeRhythm, pitchRhythm, rotationRhythm]
        )
    }

    /// Calculate rhythm score for a single channel
    private func calculateChannelRhythm(strideTimes: [Date]) -> (score: Double, strideRate: Double, isValid: Bool) {
        guard strideTimes.count >= minimumStrideCycles else {
            return (0, 0, false)
        }

        // Calculate stride intervals
        var intervals: [TimeInterval] = []
        for i in 1..<strideTimes.count {
            let interval = strideTimes[i].timeIntervalSince(strideTimes[i - 1])
            intervals.append(interval)
        }

        guard !intervals.isEmpty else {
            return (0, 0, false)
        }

        // Calculate stride rate
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        let strideRate = avgInterval > 0 ? 60.0 / avgInterval : 0.0

        // Calculate rhythm score based on interval consistency (coefficient of variation)
        let mean = avgInterval
        let variance = intervals.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(intervals.count)
        let stdDev = sqrt(variance)
        let cv = mean > 0 ? stdDev / mean : 0.0

        // Convert CV to rhythm score
        // CV of 0 = perfect rhythm (100%)
        // CV of 0.2 = poor rhythm (0%)
        let score = max(0.0, (1.0 - min(1.0, cv / 0.2)) * 100)

        return (score, strideRate, true)
    }

    /// Calculate confidence based on channel agreement
    private func calculateConfidence(rhythms: [(score: Double, strideRate: Double, isValid: Bool)]) -> Double {
        let validRhythms = rhythms.filter { $0.isValid }
        guard validRhythms.count >= 2 else {
            return validRhythms.isEmpty ? 0.0 : 0.5
        }

        // Calculate variance in stride rates across channels
        let rates = validRhythms.map { $0.strideRate }
        let meanRate = rates.reduce(0, +) / Double(rates.count)
        let rateVariance = rates.reduce(0) { $0 + ($1 - meanRate) * ($1 - meanRate) } / Double(rates.count)
        let rateStdDev = sqrt(rateVariance)

        // Lower variance = higher confidence
        // If channels agree within 5 strides/min, high confidence
        let agreement = max(0.0, 1.0 - (rateStdDev / 10.0))

        // More valid channels = higher confidence
        let channelBonus = Double(validRhythms.count) / 4.0

        return min(1.0, agreement * 0.7 + channelBonus * 0.3)
    }

    /// Calculate bonus based on stride rate appropriateness for current gait
    private func calculateGaitAppropriatenessScore() -> Double {
        guard let expectedRange = gaitStrideRates[currentGait] else {
            return 50.0
        }

        if expectedRange.contains(currentStrideRate) {
            return 100.0
        }

        let midpoint = (expectedRange.lowerBound + expectedRange.upperBound) / 2
        let rangeSize = expectedRange.upperBound - expectedRange.lowerBound
        let deviation = abs(currentStrideRate - midpoint)

        return max(0.0, 100.0 - (deviation / rangeSize) * 50.0)
    }

    // MARK: - Public Accessors

    /// Get rhythm score for a specific gait
    func rhythmForGait(_ gait: GaitType) -> Double {
        return currentRhythmScore
    }

    /// Get expected stride rate range for a gait
    func expectedStrideRateRange(for gait: GaitType) -> ClosedRange<Double>? {
        return gaitStrideRates[gait]
    }

    /// Get current stride rate with confidence
    func strideRateWithConfidence() -> (rate: Double, confidence: Double) {
        return (currentStrideRate, rhythmConfidence)
    }
}
