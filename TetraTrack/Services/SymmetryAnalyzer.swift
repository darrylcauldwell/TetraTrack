//
//  SymmetryAnalyzer.swift
//  TetraTrack
//
//  Comprehensive symmetry analysis using frequency-domain methods:
//  - RMS left vs RMS right lateral acceleration balance
//  - Coherence between forward (X) and lateral (Y) at stride frequency
//  - Roll angle consistency for rider balance
//
//  Symmetry measures how evenly the horse moves on both sides.
//  Uses frequency-domain analysis per gait-logic.md specification,
//  avoiding peak detection which fails when rider changes seat.

import Foundation

/// Analyzes motion data to calculate movement symmetry score using frequency-domain methods
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

    /// Window size for symmetry calculation (samples at ~100Hz)
    private let analysisWindowSize: Int = 256  // ~2.5 seconds

    /// Minimum samples needed before analyzing
    private let minimumSamples: Int = 128

    /// Analysis update interval
    private var lastAnalysisTime: Date = .distantPast
    private let analysisInterval: TimeInterval = 0.25  // 4 Hz

    // MARK: - Multi-Channel Sensor Buffers

    /// Vertical acceleration (Z)
    private var verticalBuffer: [Double] = []

    /// Lateral acceleration (Y) - positive = right, negative = left
    private var lateralBuffer: [Double] = []

    /// Forward acceleration (X)
    private var forwardBuffer: [Double] = []

    /// Roll angle for side-to-side tilt
    private var rollBuffer: [Double] = []

    // MARK: - DSP Components

    /// Coherence analyzer for X-Y correlation at stride frequency
    private let coherenceAnalyzer = CoherenceAnalyzer(segmentLength: 64, overlap: 32, sampleRate: 100)

    /// Current stride frequency from gait analyzer
    private var strideFrequency: Double = 2.0  // Default canter frequency

    // MARK: - Per-Rein Tracking

    private var reinScores = ReinScoreTracker()
    private var currentRein: ReinDirection = .straight

    // MARK: - Running Statistics

    private var verticalRMS: Double = 0
    private var lateralRMS: Double = 0
    private var leftRMS: Double = 0  // RMS of negative lateral samples
    private var rightRMS: Double = 0 // RMS of positive lateral samples

    init() {}

    // MARK: - Public Methods

    /// Configure with current stride frequency from gait analyzer
    func configure(strideFrequency: Double) {
        self.strideFrequency = strideFrequency
    }

    /// Process a motion sample for symmetry analysis using frequency-domain methods
    func processMotionSample(_ sample: MotionSample, currentRein: ReinDirection) {
        self.currentRein = currentRein
        let timestamp = sample.timestamp

        // Store sensor channels
        verticalBuffer.append(sample.verticalAcceleration)
        lateralBuffer.append(sample.lateralAcceleration)
        forwardBuffer.append(sample.forwardAcceleration)
        rollBuffer.append(sample.roll)

        // Maintain buffer size
        if verticalBuffer.count > analysisWindowSize {
            verticalBuffer.removeFirst()
            lateralBuffer.removeFirst()
            forwardBuffer.removeFirst()
            rollBuffer.removeFirst()
        }

        // Calculate symmetry at fixed rate
        if timestamp.timeIntervalSince(lastAnalysisTime) >= analysisInterval &&
           verticalBuffer.count >= minimumSamples {
            calculateSymmetryFrequencyDomain()
            lastAnalysisTime = timestamp
        }
    }

    /// Finalize symmetry scores for a rein segment (ReinAwareAnalyzer)
    func finalizeReinSegment() {
        reinScores.recordScore(currentSymmetryScore, for: currentRein)
    }

    /// Reset all state
    func reset() {
        verticalBuffer.removeAll()
        lateralBuffer.removeAll()
        forwardBuffer.removeAll()
        rollBuffer.removeAll()

        reinScores.reset()
        currentSymmetryScore = 0.0
        symmetryConfidence = 0.0
        currentRein = .straight

        verticalRMS = 0
        lateralRMS = 0
        leftRMS = 0
        rightRMS = 0
        strideFrequency = 2.0
        lastAnalysisTime = .distantPast
    }

    // MARK: - Frequency-Domain Symmetry Calculation

    /// Calculate symmetry using RMS balance and coherence (no peak detection)
    private func calculateSymmetryFrequencyDomain() {
        guard lateralBuffer.count >= minimumSamples else {
            currentSymmetryScore = 0.0
            symmetryConfidence = 0.0
            return
        }

        // 1. Rein balance from RMS(Y+) vs RMS(Y-)
        // Per spec: (left - right) / (left + right) where left = negative Y
        let reinBalance = calculateRMSBalance()

        // 2. X-Y coherence at stride frequency
        // Per spec: high coherence indicates good left-right symmetry
        let xyCoherence = calculateXYCoherence()

        // 3. Roll angle consistency
        let rollSymmetry = calculateRollConsistency()

        // 4. Vertical RMS consistency (coefficient of variation)
        let verticalConsistency = calculateVerticalConsistency()

        // Combine metrics with weights
        // Rein balance: 0 = perfect (left=right), 1 = completely asymmetric
        // Convert to 0-100 where 100 = perfect symmetry
        let reinSymmetryScore = max(0, (1.0 - abs(reinBalance)) * 100)

        // Coherence: 0-1 → 0-100
        let coherenceScore = xyCoherence * 100

        // Fused symmetry score with weights
        currentSymmetryScore = reinSymmetryScore * 0.35 +
                               coherenceScore * 0.30 +
                               rollSymmetry * 0.20 +
                               verticalConsistency * 0.15

        // Confidence based on data quality
        symmetryConfidence = calculateConfidence()
    }

    /// Calculate left-right RMS balance from lateral acceleration
    /// Per spec: (RMS_left - RMS_right) / (RMS_left + RMS_right)
    private func calculateRMSBalance() -> Double {
        // Separate positive (right) and negative (left) lateral samples
        let leftSamples = lateralBuffer.filter { $0 < 0 }
        let rightSamples = lateralBuffer.filter { $0 > 0 }

        // Compute RMS for each side
        if leftSamples.isEmpty {
            leftRMS = 0
        } else {
            leftRMS = sqrt(leftSamples.map { $0 * $0 }.reduce(0, +) / Double(leftSamples.count))
        }

        if rightSamples.isEmpty {
            rightRMS = 0
        } else {
            rightRMS = sqrt(rightSamples.map { $0 * $0 }.reduce(0, +) / Double(rightSamples.count))
        }

        // Compute balance: (left - right) / (left + right)
        let total = leftRMS + rightRMS
        guard total > 0.01 else { return 0 }

        // Positive = left bias, negative = right bias
        return (leftRMS - rightRMS) / total
    }

    /// Calculate X-Y coherence at stride frequency
    /// High coherence indicates coordinated left-right movement
    private func calculateXYCoherence() -> Double {
        guard forwardBuffer.count >= minimumSamples && lateralBuffer.count >= minimumSamples else {
            return 0.5  // Neutral when not enough data
        }

        return coherenceAnalyzer.coherence(
            signal1: forwardBuffer,
            signal2: lateralBuffer,
            atFrequency: strideFrequency
        )
    }

    /// Calculate roll angle consistency
    private func calculateRollConsistency() -> Double {
        guard rollBuffer.count >= minimumSamples else { return 50.0 }

        // Mean roll should be near zero for balanced rider
        let meanRoll = rollBuffer.reduce(0, +) / Double(rollBuffer.count)

        // Standard deviation for consistency
        let variance = rollBuffer.reduce(0) { $0 + ($1 - meanRoll) * ($1 - meanRoll) } / Double(rollBuffer.count)
        let stdDev = sqrt(variance)

        // Score based on mean (near 0) and consistency (low variance)
        let meanScore = max(0, 1.0 - abs(meanRoll) / 0.3) * 100  // Penalize if mean > 0.3 rad
        let consistencyScore = max(0, 1.0 - stdDev / 0.2) * 100  // Penalize high variance

        return meanScore * 0.6 + consistencyScore * 0.4
    }

    /// Calculate vertical acceleration consistency
    /// Consistent vertical RMS indicates regular footfalls
    private func calculateVerticalConsistency() -> Double {
        guard verticalBuffer.count >= minimumSamples else { return 50.0 }

        // Compute overall RMS
        verticalRMS = sqrt(verticalBuffer.map { $0 * $0 }.reduce(0, +) / Double(verticalBuffer.count))

        // Divide buffer into segments and check RMS consistency
        let segmentSize = 32
        var segmentRMS: [Double] = []

        for i in stride(from: 0, to: verticalBuffer.count - segmentSize, by: segmentSize) {
            let segment = Array(verticalBuffer[i..<(i + segmentSize)])
            let rms = sqrt(segment.map { $0 * $0 }.reduce(0, +) / Double(segment.count))
            segmentRMS.append(rms)
        }

        guard segmentRMS.count >= 2 else { return 50.0 }

        // Compute coefficient of variation
        let mean = segmentRMS.reduce(0, +) / Double(segmentRMS.count)
        guard mean > 0.01 else { return 0 }

        let variance = segmentRMS.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(segmentRMS.count)
        let cv = sqrt(variance) / mean

        // CV of 0 = perfect (100%), CV of 0.4 = poor (0%)
        return max(0, (1.0 - min(1.0, cv / 0.4)) * 100)
    }

    /// Calculate confidence based on data quality
    private func calculateConfidence() -> Double {
        // Data quantity confidence
        let dataConfidence = min(1.0, Double(lateralBuffer.count) / Double(analysisWindowSize))

        // Signal quality - lateral samples should have both positive and negative values
        let leftCount = lateralBuffer.filter { $0 < 0 }.count
        let rightCount = lateralBuffer.filter { $0 > 0 }.count
        let totalLateral = leftCount + rightCount
        let balanceConfidence = totalLateral > 0 ?
            Double(min(leftCount, rightCount)) / Double(max(leftCount, rightCount, 1)) : 0.5

        // RMS confidence - need meaningful signal
        let rmsConfidence = min(1.0, (leftRMS + rightRMS) / 0.2)

        return dataConfidence * 0.4 + balanceConfidence * 0.3 + rmsConfidence * 0.3
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

    /// Get rein balance value (-1 to +1, positive = left bias)
    func getReinBalance() -> Double {
        let total = leftRMS + rightRMS
        guard total > 0.01 else { return 0 }
        return (leftRMS - rightRMS) / total
    }
}
