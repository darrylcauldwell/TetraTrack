//
//  DrillScorer.swift
//  TetraTrack
//
//  Central scoring engine for all drills with physics-based subscores
//

import Foundation
import Observation

/// Physics-based drill scorer with multiple subscores
@Observable
final class DrillScorer {

    // MARK: - Subscores (0-100 each)

    /// Stability subscore - inverse of motion variance
    private(set) var stability: Double = 100

    /// Symmetry subscore - left/right balance (based on roll bias)
    private(set) var symmetry: Double = 100

    /// Endurance subscore - score degradation over time
    private(set) var endurance: Double = 100

    /// Coordination subscore - multi-axis timing correlation
    private(set) var coordination: Double = 100

    /// Overall score (weighted average of subscores)
    var overallScore: Double {
        let weights = (stability: 0.35, symmetry: 0.25, endurance: 0.20, coordination: 0.20)
        return (stability * weights.stability +
                symmetry * weights.symmetry +
                endurance * weights.endurance +
                coordination * weights.coordination)
    }

    // MARK: - Internal State

    /// Rolling buffer for stability calculation
    private var motionHistory: [DrillMotionSample] = []
    private let bufferSize = 60  // ~1 second at 60Hz

    /// For symmetry calculation
    private var rollBiasSum: Double = 0
    private var sampleCount: Int = 0

    /// For endurance calculation
    private var initialStabilityAvg: Double?
    private var recentStabilityAvg: Double = 100
    private var stabilityWindow: [Double] = []
    private let windowSize = 30

    /// For coordination calculation
    private var pitchRollCorrelation: Double = 0
    private var pitchBuffer: [Double] = []
    private var rollBuffer: [Double] = []
    private let correlationWindowSize = 30

    /// EMA smoothing factor
    private let emaAlpha: Double = 0.2

    // MARK: - Public Interface

    /// Process new motion data and update subscores
    /// - Parameters:
    ///   - pitch: Device pitch (radians)
    ///   - roll: Device roll (radians)
    ///   - yaw: Device yaw (radians)
    ///   - timestamp: Time since drill started
    func process(pitch: Double, roll: Double, yaw: Double, timestamp: TimeInterval) {
        sampleCount += 1

        let sample = DrillMotionSample(pitch: pitch, roll: roll, yaw: yaw, timestamp: timestamp)
        motionHistory.append(sample)

        // Keep buffer limited
        if motionHistory.count > bufferSize {
            motionHistory.removeFirst()
        }

        // Update each subscore
        updateStability()
        updateSymmetry(roll: roll)
        updateEndurance()
        updateCoordination(pitch: pitch, roll: roll)
    }

    /// Reset scorer for new drill session
    func reset() {
        stability = 100
        symmetry = 100
        endurance = 100
        coordination = 100

        motionHistory.removeAll()
        rollBiasSum = 0
        sampleCount = 0
        initialStabilityAvg = nil
        recentStabilityAvg = 100
        stabilityWindow.removeAll()
        pitchBuffer.removeAll()
        rollBuffer.removeAll()
    }

    // MARK: - Subscore Calculations

    private func updateStability() {
        guard motionHistory.count >= 2 else { return }

        // Calculate variance of motion magnitude over recent samples
        let movements = motionHistory.suffix(min(bufferSize, motionHistory.count)).map { sample -> Double in
            sqrt(sample.pitch * sample.pitch + sample.roll * sample.roll + sample.yaw * sample.yaw)
        }

        let mean = movements.reduce(0, +) / Double(movements.count)
        let variance = movements.map { pow($0 - mean, 2) }.reduce(0, +) / Double(movements.count)

        // Convert variance to score (lower variance = higher score)
        // Scale factor tuned for typical motion ranges
        let rawScore = max(0, 100 - (variance * 500))
        stability = stability * (1 - emaAlpha) + rawScore * emaAlpha
    }

    private func updateSymmetry(roll: Double) {
        // Track cumulative roll bias (positive = right lean, negative = left lean)
        rollBiasSum += roll

        // Calculate symmetry from how balanced the roll bias is
        let avgBias = abs(rollBiasSum / Double(max(sampleCount, 1)))

        // Convert bias to score (lower bias = higher symmetry)
        // Bias in radians, ~0.1 rad = noticeable lean
        let rawScore = max(0, 100 - (avgBias * 200))
        symmetry = symmetry * (1 - emaAlpha) + rawScore * emaAlpha
    }

    private func updateEndurance() {
        // Track stability over time windows
        stabilityWindow.append(stability)
        if stabilityWindow.count > windowSize {
            stabilityWindow.removeFirst()
        }

        // Store initial baseline after first window
        if stabilityWindow.count == windowSize && initialStabilityAvg == nil {
            initialStabilityAvg = stabilityWindow.reduce(0, +) / Double(windowSize)
        }

        // Calculate recent average
        if stabilityWindow.count >= windowSize / 2 {
            recentStabilityAvg = stabilityWindow.suffix(windowSize / 2).reduce(0, +) / Double(windowSize / 2)
        }

        // Endurance is how well you maintain initial stability
        guard let initial = initialStabilityAvg, initial > 0 else {
            endurance = 100
            return
        }

        let ratio = recentStabilityAvg / initial
        endurance = min(100, ratio * 100)
    }

    private func updateCoordination(pitch: Double, roll: Double) {
        // Track correlation between pitch and roll movements
        pitchBuffer.append(pitch)
        rollBuffer.append(roll)

        if pitchBuffer.count > correlationWindowSize {
            pitchBuffer.removeFirst()
            rollBuffer.removeFirst()
        }

        guard pitchBuffer.count >= 10 else {
            coordination = 100
            return
        }

        // Calculate Pearson correlation coefficient
        let n = Double(pitchBuffer.count)
        let sumPitch = pitchBuffer.reduce(0, +)
        let sumRoll = rollBuffer.reduce(0, +)
        let sumPitchRoll = zip(pitchBuffer, rollBuffer).map { $0 * $1 }.reduce(0, +)
        let sumPitchSq = pitchBuffer.map { $0 * $0 }.reduce(0, +)
        let sumRollSq = rollBuffer.map { $0 * $0 }.reduce(0, +)

        let numerator = (n * sumPitchRoll) - (sumPitch * sumRoll)
        let denominator = sqrt((n * sumPitchSq - sumPitch * sumPitch) * (n * sumRollSq - sumRoll * sumRoll))

        if denominator > 0.001 {
            pitchRollCorrelation = numerator / denominator
        }

        // Good coordination = low correlation (independent control of axes)
        // Bad coordination = high correlation (coupled movements)
        let rawScore = max(0, 100 - (abs(pitchRollCorrelation) * 100))
        coordination = coordination * (1 - emaAlpha) + rawScore * emaAlpha
    }
}

// MARK: - Supporting Types

private struct DrillMotionSample {
    let pitch: Double
    let roll: Double
    let yaw: Double
    let timestamp: TimeInterval
}
