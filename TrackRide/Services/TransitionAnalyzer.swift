//
//  TransitionAnalyzer.swift
//  TrackRide
//
//  Detects and tracks gait transitions with quality scoring
//  based on speed smoothness during the transition.

import Foundation

/// Analyzes gait transitions and calculates transition quality scores
final class TransitionAnalyzer: Resettable {
    // MARK: - Public Properties

    /// Recorded transitions during the ride
    private(set) var transitions: [RecordedTransition] = []

    /// Callback when a new transition is detected
    var onTransitionDetected: ((RecordedTransition) -> Void)?

    // MARK: - Configuration

    /// Number of speed samples to track for quality calculation
    private let speedHistorySize: Int = 20

    /// Minimum speed change to consider a valid transition
    private let minimumSpeedChange: Double = 0.5  // m/s

    // MARK: - Internal State

    /// Recent speed samples for quality calculation
    private var speedHistory: [(timestamp: Date, speed: Double)] = []

    /// Last recorded gait for transition detection
    private var lastGait: GaitType?

    /// Timestamp of last gait for minimum duration check
    private var lastGaitStartTime: Date?

    /// Minimum duration in a gait before transition is recorded (debounce)
    private let minimumGaitDuration: TimeInterval = 1.0

    // MARK: - Recorded Transition Structure

    struct RecordedTransition {
        let from: GaitType
        let to: GaitType
        let timestamp: Date
        let quality: Double  // 0-1 score
    }

    // MARK: - Public Methods

    /// Process a gait change
    /// - Parameters:
    ///   - from: Previous gait type
    ///   - to: New gait type
    ///   - timestamp: Time of the transition
    func processGaitChange(from: GaitType, to: GaitType, timestamp: Date = Date()) {
        // Ignore if same gait
        guard from != to else { return }

        // Debounce: require minimum duration in previous gait
        if let startTime = lastGaitStartTime {
            let duration = timestamp.timeIntervalSince(startTime)
            guard duration >= minimumGaitDuration else {
                // Too fast, likely noise - ignore
                return
            }
        }

        // Calculate transition quality
        let quality = calculateTransitionQuality()

        // Record the transition
        let transition = RecordedTransition(
            from: from,
            to: to,
            timestamp: timestamp,
            quality: quality
        )
        transitions.append(transition)

        // Notify callback
        onTransitionDetected?(transition)

        // Update state
        lastGait = to
        lastGaitStartTime = timestamp
    }

    /// Update speed history for quality calculations
    /// - Parameters:
    ///   - speed: Current speed in m/s
    ///   - timestamp: Time of the speed reading
    func updateSpeed(_ speed: Double, timestamp: Date = Date()) {
        speedHistory.append((timestamp, speed))

        // Keep only recent samples
        if speedHistory.count > speedHistorySize {
            speedHistory.removeFirst(speedHistory.count - speedHistorySize)
        }
    }

    /// Get all transitions as model objects ready for persistence
    func getTransitionModels() -> [(from: GaitType, to: GaitType, timestamp: Date, quality: Double)] {
        transitions.map { ($0.from, $0.to, $0.timestamp, $0.quality) }
    }

    /// Reset all state
    func reset() {
        transitions.removeAll()
        speedHistory.removeAll()
        lastGait = nil
        lastGaitStartTime = nil
    }

    // MARK: - Quality Calculation

    /// Calculate transition quality based on speed smoothness
    /// Higher quality = smoother speed change (gradual acceleration/deceleration)
    /// Lower quality = abrupt speed change (jerky transition)
    private func calculateTransitionQuality() -> Double {
        guard speedHistory.count >= 5 else {
            // Not enough data, return neutral quality
            return 0.5
        }

        // Get recent speed samples
        let recentSpeeds = speedHistory.suffix(10).map { $0.speed }

        // Calculate speed change characteristics
        let speedDeltas = calculateSpeedDeltas(recentSpeeds)

        guard !speedDeltas.isEmpty else { return 0.5 }

        // Calculate jerk (rate of change of acceleration)
        // Lower jerk = smoother transition = higher quality
        let jerkScore = calculateJerkScore(speedDeltas)

        // Calculate consistency (variance in speed changes)
        // Lower variance = more consistent = higher quality
        let consistencyScore = calculateConsistencyScore(speedDeltas)

        // Combined quality score
        let quality = (jerkScore * 0.6 + consistencyScore * 0.4)

        return min(1.0, max(0.0, quality))
    }

    /// Calculate speed changes between samples
    private func calculateSpeedDeltas(_ speeds: [Double]) -> [Double] {
        guard speeds.count >= 2 else { return [] }

        var deltas: [Double] = []
        for i in 1..<speeds.count {
            deltas.append(speeds[i] - speeds[i - 1])
        }
        return deltas
    }

    /// Calculate jerk score (smoothness of acceleration)
    private func calculateJerkScore(_ deltas: [Double]) -> Double {
        guard deltas.count >= 2 else { return 0.5 }

        // Calculate acceleration changes (jerk)
        var jerks: [Double] = []
        for i in 1..<deltas.count {
            jerks.append(abs(deltas[i] - deltas[i - 1]))
        }

        guard !jerks.isEmpty else { return 0.5 }

        // Average absolute jerk
        let avgJerk = jerks.reduce(0, +) / Double(jerks.count)

        // Convert to score (lower jerk = higher score)
        // Jerk of 0 = perfect (1.0), jerk of 1.0 m/s³ or more = poor (0.0)
        let score = 1.0 - min(1.0, avgJerk / 1.0)

        return score
    }

    /// Calculate consistency score (uniformity of speed changes)
    private func calculateConsistencyScore(_ deltas: [Double]) -> Double {
        guard deltas.count >= 2 else { return 0.5 }

        // Calculate variance of speed deltas
        let mean = deltas.reduce(0, +) / Double(deltas.count)
        let variance = deltas.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(deltas.count)
        let stdDev = sqrt(variance)

        // Convert to score (lower variance = higher score)
        // StdDev of 0 = perfect (1.0), stdDev of 0.5 or more = poor (0.0)
        let score = 1.0 - min(1.0, stdDev / 0.5)

        return score
    }

    // MARK: - Statistics

    /// Average quality of all transitions
    var averageTransitionQuality: Double {
        guard !transitions.isEmpty else { return 0.0 }
        return transitions.reduce(0) { $0 + $1.quality } / Double(transitions.count)
    }

    /// Number of upward transitions (to faster gait)
    var upwardTransitionCount: Int {
        transitions.filter { isUpwardTransition(from: $0.from, to: $0.to) }.count
    }

    /// Number of downward transitions (to slower gait)
    var downwardTransitionCount: Int {
        transitions.filter { isDownwardTransition(from: $0.from, to: $0.to) }.count
    }

    private func isUpwardTransition(from: GaitType, to: GaitType) -> Bool {
        let gaitOrder: [GaitType] = [.stationary, .walk, .trot, .canter, .gallop]
        guard let fromIndex = gaitOrder.firstIndex(of: from),
              let toIndex = gaitOrder.firstIndex(of: to) else {
            return false
        }
        return toIndex > fromIndex
    }

    private func isDownwardTransition(from: GaitType, to: GaitType) -> Bool {
        let gaitOrder: [GaitType] = [.stationary, .walk, .trot, .canter, .gallop]
        guard let fromIndex = gaitOrder.firstIndex(of: from),
              let toIndex = gaitOrder.firstIndex(of: to) else {
            return false
        }
        return toIndex < fromIndex
    }
}
