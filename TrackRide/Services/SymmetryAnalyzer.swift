//
//  SymmetryAnalyzer.swift
//  TrackRide
//
//  Comprehensive symmetry analysis using all available sensor data:
//  - Accelerometer (X, Y, Z) for footfall impact patterns
//  - Gyroscope for rotational symmetry
//  - Attitude (roll) for side-to-side balance
//
//  Symmetry measures how evenly the horse moves on both sides,
//  comparing left/right impact forces and movement patterns.

import Foundation

/// Analyzes motion data to calculate movement symmetry score using all available sensors
final class SymmetryAnalyzer: Resettable, ReinAwareAnalyzer {
    // MARK: - Public Properties

    /// Current symmetry score (0-100%)
    private(set) var currentSymmetryScore: Double = 0.0

    /// Confidence in the current symmetry measurement (0-1)
    private(set) var symmetryConfidence: Double = 0.0

    /// Average symmetry on left rein (ReinAwareAnalyzer)
    var leftReinScore: Double { reinScores.leftReinAverage }

    /// Average symmetry on right rein (ReinAwareAnalyzer)
    var rightReinScore: Double { reinScores.rightReinAverage }

    /// Legacy accessors for compatibility
    var leftReinSymmetry: Double { leftReinScore }
    var rightReinSymmetry: Double { rightReinScore }

    // MARK: - Configuration

    /// Minimum vertical acceleration for footfall detection (g-force)
    private let footfallThreshold: Double = 0.25

    /// Window size for symmetry calculation (samples at 50Hz)
    private let analysisWindowSize: Int = 250  // 5 seconds

    /// Minimum impacts needed for analysis
    private let minimumImpacts: Int = 6

    // MARK: - Multi-Channel Sensor Buffers

    /// Vertical acceleration for impact detection
    private var verticalAccelBuffer: TimestampedRollingBuffer<Double>

    /// Lateral acceleration for left/right movement
    private var lateralAccelBuffer: TimestampedRollingBuffer<Double>

    /// Acceleration magnitude for overall impact
    private var magnitudeBuffer: TimestampedRollingBuffer<Double>

    /// Roll angle for side-to-side tilt
    private var rollBuffer: TimestampedRollingBuffer<Double>

    /// Lateral rotation rate
    private var lateralRotationBuffer: TimestampedRollingBuffer<Double>

    // MARK: - Impact Tracking

    /// Detected impact events with full sensor context
    private var impactEvents: [ImpactEvent] = []

    /// Per-rein symmetry tracking
    private var reinScores = ReinScoreTracker()

    /// Current rein being tracked
    private var currentRein: ReinDirection = .straight

    /// Running statistics for adaptive thresholds
    private var verticalMean: Double = 0
    private var verticalStdDev: Double = 0.15
    private var lateralMean: Double = 0
    private var lateralStdDev: Double = 0.1

    /// State for peak detection
    private var inPotentialImpact: Bool = false
    private var peakValue: Double = 0
    private var peakTimestamp: Date = Date()
    private var peakLateral: Double = 0
    private var peakRoll: Double = 0

    struct ImpactEvent {
        let timestamp: Date
        let verticalMagnitude: Double
        let lateralAccel: Double      // Positive = right, negative = left
        let rollAngle: Double         // Positive = right tilt, negative = left tilt
        let totalMagnitude: Double
        let rein: ReinDirection

        /// Estimated side of impact based on lateral acceleration and roll
        var estimatedSide: ImpactSide {
            // Combine lateral acceleration and roll to estimate which side
            let lateralScore = lateralAccel
            let rollScore = rollAngle * 0.5  // Roll is less direct indicator

            let combinedScore = lateralScore + rollScore
            if combinedScore > 0.05 {
                return .right
            } else if combinedScore < -0.05 {
                return .left
            }
            return .center
        }
    }

    enum ImpactSide {
        case left, right, center
    }

    init() {
        verticalAccelBuffer = TimestampedRollingBuffer(capacity: analysisWindowSize)
        lateralAccelBuffer = TimestampedRollingBuffer(capacity: analysisWindowSize)
        magnitudeBuffer = TimestampedRollingBuffer(capacity: analysisWindowSize)
        rollBuffer = TimestampedRollingBuffer(capacity: analysisWindowSize)
        lateralRotationBuffer = TimestampedRollingBuffer(capacity: analysisWindowSize)
    }

    // MARK: - Public Methods

    /// Process a motion sample for symmetry analysis using all sensor channels
    func processMotionSample(_ sample: MotionSample, currentRein: ReinDirection) {
        self.currentRein = currentRein
        let timestamp = sample.timestamp

        // Store all sensor channels
        verticalAccelBuffer.append(sample.verticalAcceleration, at: timestamp)
        lateralAccelBuffer.append(sample.lateralAcceleration, at: timestamp)
        magnitudeBuffer.append(sample.accelerationMagnitude, at: timestamp)
        rollBuffer.append(sample.roll, at: timestamp)
        lateralRotationBuffer.append(sample.rotationX, at: timestamp)

        // Update running statistics
        updateRunningStatistics(sample)

        // Detect footfall impacts using peak detection
        detectFootfallImpacts(sample: sample)

        // Calculate symmetry periodically
        if verticalAccelBuffer.count >= analysisWindowSize / 2 {
            calculateSymmetry()
        }
    }

    /// Finalize symmetry scores for a rein segment (ReinAwareAnalyzer)
    func finalizeReinSegment() {
        reinScores.recordScore(currentSymmetryScore, for: currentRein)
    }

    /// Reset all state
    func reset() {
        verticalAccelBuffer.removeAll()
        lateralAccelBuffer.removeAll()
        magnitudeBuffer.removeAll()
        rollBuffer.removeAll()
        lateralRotationBuffer.removeAll()

        impactEvents.removeAll()
        reinScores.reset()
        currentSymmetryScore = 0.0
        symmetryConfidence = 0.0
        currentRein = .straight

        verticalMean = 0
        verticalStdDev = 0.15
        lateralMean = 0
        lateralStdDev = 0.1

        inPotentialImpact = false
        peakValue = 0
        peakTimestamp = Date()
        peakLateral = 0
        peakRoll = 0
    }

    // MARK: - Running Statistics

    private func updateRunningStatistics(_ sample: MotionSample) {
        let alpha = 0.01

        let vertDelta = sample.verticalAcceleration - verticalMean
        verticalMean += alpha * vertDelta
        verticalStdDev = sqrt((1 - alpha) * verticalStdDev * verticalStdDev + alpha * vertDelta * vertDelta)

        let latDelta = sample.lateralAcceleration - lateralMean
        lateralMean += alpha * latDelta
        lateralStdDev = sqrt((1 - alpha) * lateralStdDev * lateralStdDev + alpha * latDelta * latDelta)
    }

    // MARK: - Footfall Detection

    private func detectFootfallImpacts(sample: MotionSample) {
        // Adaptive threshold based on running statistics
        let threshold = max(footfallThreshold, verticalMean + verticalStdDev)

        if sample.verticalAcceleration > threshold {
            // We're in a potential impact zone
            if !inPotentialImpact {
                // Start of new potential impact
                inPotentialImpact = true
                peakValue = sample.verticalAcceleration
                peakTimestamp = sample.timestamp
                peakLateral = sample.lateralAcceleration
                peakRoll = sample.roll
            } else if sample.verticalAcceleration > peakValue {
                // Update peak
                peakValue = sample.verticalAcceleration
                peakTimestamp = sample.timestamp
                peakLateral = sample.lateralAcceleration
                peakRoll = sample.roll
            }
        } else if inPotentialImpact {
            // End of impact zone - record the peak
            inPotentialImpact = false

            // Validate timing
            let minInterval: TimeInterval = 0.15
            if let lastImpact = impactEvents.last {
                let interval = peakTimestamp.timeIntervalSince(lastImpact.timestamp)
                guard interval >= minInterval else { return }
            }

            let impact = ImpactEvent(
                timestamp: peakTimestamp,
                verticalMagnitude: peakValue,
                lateralAccel: peakLateral,
                rollAngle: peakRoll,
                totalMagnitude: sqrt(peakValue * peakValue + peakLateral * peakLateral),
                rein: currentRein
            )
            impactEvents.append(impact)

            // Keep recent impacts only
            let cutoffTime = Date().addingTimeInterval(-5.0)
            impactEvents.removeAll { $0.timestamp < cutoffTime }
        }
    }

    // MARK: - Symmetry Calculation

    private func calculateSymmetry() {
        guard impactEvents.count >= minimumImpacts else {
            currentSymmetryScore = 0.0
            symmetryConfidence = 0.0
            return
        }

        // Calculate multiple symmetry metrics and fuse them

        // 1. Impact magnitude symmetry (are all footfalls equal force?)
        let magnitudeSymmetry = calculateMagnitudeSymmetry()

        // 2. Timing symmetry (are stride intervals consistent?)
        let timingSymmetry = calculateTimingSymmetry()

        // 3. Left/right balance (are impacts evenly distributed?)
        let lateralBalance = calculateLateralBalance()

        // 4. Roll symmetry (is the rider balanced?)
        let rollSymmetry = calculateRollSymmetry()

        // Fused symmetry score with weights
        currentSymmetryScore = magnitudeSymmetry * 0.30 +
                               timingSymmetry * 0.30 +
                               lateralBalance * 0.25 +
                               rollSymmetry * 0.15

        // Calculate confidence based on data quality
        symmetryConfidence = calculateConfidence()
    }

    /// Calculate symmetry based on impact magnitudes
    private func calculateMagnitudeSymmetry() -> Double {
        let magnitudes = impactEvents.map { $0.verticalMagnitude }
        guard magnitudes.count >= 2 else { return 0.0 }

        let mean = magnitudes.reduce(0, +) / Double(magnitudes.count)
        let variance = magnitudes.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(magnitudes.count)
        let stdDev = sqrt(variance)
        let cv = mean > 0 ? stdDev / mean : 0.0

        // CV of 0 = perfect (100%), CV of 0.4 = poor (0%)
        return max(0.0, (1.0 - min(1.0, cv / 0.4)) * 100)
    }

    /// Calculate symmetry based on stride timing intervals
    private func calculateTimingSymmetry() -> Double {
        guard impactEvents.count >= 3 else { return 0.0 }

        var intervals: [TimeInterval] = []
        for i in 1..<impactEvents.count {
            let interval = impactEvents[i].timestamp.timeIntervalSince(impactEvents[i - 1].timestamp)
            if interval > 0.1 && interval < 2.0 {
                intervals.append(interval)
            }
        }

        guard intervals.count >= 2 else { return 0.0 }

        let mean = intervals.reduce(0, +) / Double(intervals.count)
        let variance = intervals.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(intervals.count)
        let stdDev = sqrt(variance)
        let cv = mean > 0 ? stdDev / mean : 0.0

        // CV of 0 = perfect (100%), CV of 0.25 = poor (0%)
        return max(0.0, (1.0 - min(1.0, cv / 0.25)) * 100)
    }

    /// Calculate left/right balance from lateral acceleration
    private func calculateLateralBalance() -> Double {
        let leftImpacts = impactEvents.filter { $0.estimatedSide == .left }
        let rightImpacts = impactEvents.filter { $0.estimatedSide == .right }

        // If we can't distinguish sides, return neutral
        guard !leftImpacts.isEmpty || !rightImpacts.isEmpty else {
            return 50.0
        }

        // Calculate average magnitude for each side
        let leftAvg = leftImpacts.isEmpty ? 0 : leftImpacts.map { $0.totalMagnitude }.reduce(0, +) / Double(leftImpacts.count)
        let rightAvg = rightImpacts.isEmpty ? 0 : rightImpacts.map { $0.totalMagnitude }.reduce(0, +) / Double(rightImpacts.count)

        // Also consider count balance
        let totalCount = leftImpacts.count + rightImpacts.count
        let countBalance = totalCount > 0 ? Double(min(leftImpacts.count, rightImpacts.count)) / Double(max(leftImpacts.count, rightImpacts.count, 1)) : 0.5

        // Magnitude balance
        let maxAvg = max(leftAvg, rightAvg, 0.01)
        let minAvg = min(leftAvg, rightAvg)
        let magnitudeBalance = minAvg / maxAvg

        // Combined balance score
        let balance = (countBalance * 0.4 + magnitudeBalance * 0.6)
        return balance * 100
    }

    /// Calculate roll angle symmetry
    private func calculateRollSymmetry() -> Double {
        let rollValues = impactEvents.map { $0.rollAngle }
        guard rollValues.count >= 2 else { return 50.0 }

        // Calculate mean roll - should be near zero for balanced rider
        let meanRoll = rollValues.reduce(0, +) / Double(rollValues.count)

        // Calculate variance - should be low for consistent balance
        let variance = rollValues.reduce(0) { $0 + ($1 - meanRoll) * ($1 - meanRoll) } / Double(rollValues.count)
        let stdDev = sqrt(variance)

        // Score based on mean roll (should be near 0) and consistency
        let meanScore = max(0.0, 1.0 - abs(meanRoll) / 0.3) * 100  // Penalize if mean > 0.3 rad
        let consistencyScore = max(0.0, 1.0 - stdDev / 0.2) * 100  // Penalize high variance

        return meanScore * 0.6 + consistencyScore * 0.4
    }

    /// Calculate confidence based on data quality
    private func calculateConfidence() -> Double {
        // More impacts = higher confidence
        let impactConfidence = min(1.0, Double(impactEvents.count) / 12.0)

        // Better side detection = higher confidence
        let leftCount = impactEvents.filter { $0.estimatedSide == .left }.count
        let rightCount = impactEvents.filter { $0.estimatedSide == .right }.count
        _ = impactEvents.filter { $0.estimatedSide == .center }.count  // Center impacts tracked but not used in confidence
        let sideConfidence = Double(leftCount + rightCount) / Double(max(impactEvents.count, 1))

        return impactConfidence * 0.6 + sideConfidence * 0.4
    }

    // MARK: - Public Accessors

    /// Get symmetry score for a specific gait type
    func symmetryForGait(_ gait: GaitType) -> Double {
        return currentSymmetryScore
    }

    /// Get symmetry with confidence
    func symmetryWithConfidence() -> (score: Double, confidence: Double) {
        return (currentSymmetryScore, symmetryConfidence)
    }
}
