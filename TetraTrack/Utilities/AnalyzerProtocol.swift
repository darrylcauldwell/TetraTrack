//
//  AnalyzerProtocol.swift
//  TetraTrack
//
//  Shared protocols for analyzer services
//

import Foundation

// MARK: - Resettable Protocol

/// Protocol for types that can reset their internal state
/// All analyzer services implement this to enable batch reset operations
protocol Resettable {
    /// Reset all internal state to initial values
    func reset()
}

// MARK: - Rein-Aware Analyzer Protocol

/// Protocol for analyzers that track per-rein metrics
protocol ReinAwareAnalyzer: Resettable {
    /// Average score on left rein
    var leftReinScore: Double { get }

    /// Average score on right rein
    var rightReinScore: Double { get }

    /// Finalize the current rein segment and record its score
    func finalizeReinSegment()
}

// MARK: - Rein Score Tracker

/// Utility for tracking per-rein scores with automatic averaging
/// Used by SymmetryAnalyzer and RhythmAnalyzer
struct ReinScoreTracker {
    private var leftScores: [Double] = []
    private var rightScores: [Double] = []

    /// Average score on left rein
    var leftReinAverage: Double {
        leftScores.isEmpty ? 0.0 : leftScores.reduce(0, +) / Double(leftScores.count)
    }

    /// Average score on right rein
    var rightReinAverage: Double {
        rightScores.isEmpty ? 0.0 : rightScores.reduce(0, +) / Double(rightScores.count)
    }

    /// Record a score for the specified rein
    mutating func recordScore(_ score: Double, for rein: ReinDirection) {
        switch rein {
        case .left:
            leftScores.append(score)
        case .right:
            rightScores.append(score)
        case .straight:
            break
        }
    }

    /// Reset all recorded scores
    mutating func reset() {
        leftScores.removeAll()
        rightScores.removeAll()
    }
}

// MARK: - Duration Tracker

/// Utility for tracking left/right durations
/// Used by LeadAnalyzer and ReinAnalyzer
struct DurationTracker {
    private(set) var leftDuration: TimeInterval = 0.0
    private(set) var rightDuration: TimeInterval = 0.0
    private var lastUpdateTime: Date?

    /// Total tracked duration
    var totalDuration: TimeInterval {
        leftDuration + rightDuration
    }

    /// Balance ratio (0.5 = balanced, 0 = all right, 1 = all left)
    var balance: Double {
        guard totalDuration > 0 else { return 0.5 }
        return leftDuration / totalDuration
    }

    /// Add elapsed time to the specified side
    mutating func addDuration(_ elapsed: TimeInterval, to side: BalanceSide) {
        switch side {
        case .left:
            leftDuration += elapsed
        case .right:
            rightDuration += elapsed
        case .neutral:
            break
        }
    }

    /// Calculate elapsed time since last update and track for the given side
    mutating func trackElapsed(for side: BalanceSide, at time: Date = Date()) {
        if let lastTime = lastUpdateTime {
            let elapsed = time.timeIntervalSince(lastTime)
            addDuration(elapsed, to: side)
        }
        lastUpdateTime = time
    }

    /// Reset all tracked durations
    mutating func reset() {
        leftDuration = 0.0
        rightDuration = 0.0
        lastUpdateTime = nil
    }

    enum BalanceSide {
        case left, right, neutral
    }
}

// MARK: - Analyzer Coordination

/// Coordinator for managing multiple resettable analyzers
enum AnalyzerCoordinator {
    /// Reset all analyzers in a collection
    static func resetAll(_ analyzers: [Resettable]) {
        analyzers.forEach { $0.reset() }
    }
}
