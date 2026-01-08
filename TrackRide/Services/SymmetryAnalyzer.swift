//
//  SymmetryAnalyzer.swift
//  TrackRide
//
//  Analyzes movement symmetry by detecting footfall patterns
//  and comparing left/right stride consistency.

import Foundation

/// Analyzes motion data to calculate movement symmetry score
final class SymmetryAnalyzer: Resettable, ReinAwareAnalyzer {
    // MARK: - Public Properties

    /// Current symmetry score (0-100%)
    private(set) var currentSymmetryScore: Double = 0.0

    /// Average symmetry on left rein (ReinAwareAnalyzer)
    var leftReinScore: Double { reinScores.leftReinAverage }

    /// Average symmetry on right rein (ReinAwareAnalyzer)
    var rightReinScore: Double { reinScores.rightReinAverage }

    /// Legacy accessors for compatibility
    var leftReinSymmetry: Double { leftReinScore }
    var rightReinSymmetry: Double { rightReinScore }

    // MARK: - Configuration

    /// Minimum vertical acceleration for footfall detection (g-force)
    private let footfallThreshold: Double = 0.3

    /// Window size for symmetry calculation (samples)
    private let analysisWindowSize: Int = 200  // 4 seconds at 50Hz

    /// Minimum impacts needed for analysis
    private let minimumImpacts: Int = 4

    // MARK: - Internal State

    /// Vertical acceleration history (using RollingBuffer)
    private var accelBuffer: TimestampedRollingBuffer<Double>

    /// Detected impact events
    private var impactEvents: [ImpactEvent] = []

    /// Per-rein symmetry tracking (using ReinScoreTracker)
    private var reinScores = ReinScoreTracker()

    /// Current rein being tracked
    private var currentRein: ReinDirection = .straight

    struct ImpactEvent {
        let timestamp: Date
        let magnitude: Double
        let rein: ReinDirection
    }

    init() {
        accelBuffer = TimestampedRollingBuffer(capacity: analysisWindowSize)
    }

    // MARK: - Public Methods

    /// Process a motion sample for symmetry analysis
    /// - Parameters:
    ///   - sample: Motion sample from MotionManager
    ///   - currentRein: Current rein direction
    func processMotionSample(_ sample: MotionSample, currentRein: ReinDirection) {
        self.currentRein = currentRein

        // Track vertical acceleration using rolling buffer
        accelBuffer.append(sample.verticalAcceleration, at: sample.timestamp)

        // Detect footfall impacts
        detectFootfallImpacts(sample: sample)

        // Calculate symmetry periodically
        if accelBuffer.count >= analysisWindowSize / 2 {
            calculateSymmetry()
        }
    }

    /// Finalize symmetry scores for a rein segment (ReinAwareAnalyzer)
    func finalizeReinSegment() {
        reinScores.recordScore(currentSymmetryScore, for: currentRein)
    }

    /// Reset all state
    func reset() {
        accelBuffer.removeAll()
        impactEvents.removeAll()
        reinScores.reset()
        currentSymmetryScore = 0.0
        currentRein = .straight
    }

    // MARK: - Footfall Detection

    private func detectFootfallImpacts(sample: MotionSample) {
        let history = accelBuffer.items

        guard history.count >= 3 else { return }

        // Look for local maximum (impact peak)
        let currentIndex = history.count - 2  // Second to last
        guard currentIndex >= 1 else { return }

        let prev = history[currentIndex - 1].value
        let curr = history[currentIndex].value
        let next = history[currentIndex + 1].value

        // Detect positive peak above threshold
        if curr > prev && curr > next && curr > footfallThreshold {
            // This is an impact event
            let impact = ImpactEvent(
                timestamp: history[currentIndex].timestamp,
                magnitude: curr,
                rein: currentRein
            )
            impactEvents.append(impact)

            // Keep recent impacts only
            let cutoffTime = Date().addingTimeInterval(-4.0)
            impactEvents.removeAll { $0.timestamp < cutoffTime }
        }
    }

    // MARK: - Symmetry Calculation

    private func calculateSymmetry() {
        // Need enough impact events
        guard impactEvents.count >= minimumImpacts else {
            currentSymmetryScore = 0.0
            return
        }

        // Calculate impact magnitude symmetry
        let magnitudeSymmetry = calculateMagnitudeSymmetry()

        // Calculate timing symmetry (stride interval regularity)
        let timingSymmetry = calculateTimingSymmetry()

        // Combined symmetry score
        currentSymmetryScore = (magnitudeSymmetry * 0.5 + timingSymmetry * 0.5)
    }

    /// Calculate symmetry based on impact magnitudes
    /// Symmetry = how consistent the impact forces are (left vs right footfalls)
    private func calculateMagnitudeSymmetry() -> Double {
        let magnitudes = impactEvents.map { $0.magnitude }

        guard magnitudes.count >= 2 else { return 0.0 }

        // Calculate mean and variance
        let mean = magnitudes.reduce(0, +) / Double(magnitudes.count)
        let variance = magnitudes.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(magnitudes.count)
        let stdDev = sqrt(variance)

        // Coefficient of variation (CV)
        let cv = mean > 0 ? stdDev / mean : 0.0

        // Convert to symmetry score (lower CV = higher symmetry)
        // CV of 0 = perfect symmetry (100%)
        // CV of 0.5 = poor symmetry (0%)
        let score = (1.0 - min(1.0, cv / 0.5)) * 100

        return max(0.0, score)
    }

    /// Calculate symmetry based on stride timing intervals
    /// Perfect symmetry = equal time between all footfalls
    private func calculateTimingSymmetry() -> Double {
        guard impactEvents.count >= 3 else { return 0.0 }

        // Calculate intervals between impacts
        var intervals: [TimeInterval] = []
        for i in 1..<impactEvents.count {
            let interval = impactEvents[i].timestamp.timeIntervalSince(impactEvents[i - 1].timestamp)
            if interval > 0.1 && interval < 2.0 {  // Filter reasonable intervals
                intervals.append(interval)
            }
        }

        guard intervals.count >= 2 else { return 0.0 }

        // Calculate variance of intervals
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        let variance = intervals.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(intervals.count)
        let stdDev = sqrt(variance)

        // Coefficient of variation
        let cv = mean > 0 ? stdDev / mean : 0.0

        // Convert to symmetry score
        // CV of 0 = perfect timing (100%)
        // CV of 0.3 = poor timing (0%)
        let score = (1.0 - min(1.0, cv / 0.3)) * 100

        return max(0.0, score)
    }

    // MARK: - Gait-Specific Analysis

    /// Get symmetry score for a specific gait type
    /// Different gaits have different expected symmetry patterns
    func symmetryForGait(_ gait: GaitType) -> Double {
        // Currently using the same calculation for all gaits
        // Could be extended to use gait-specific thresholds
        return currentSymmetryScore
    }
}
