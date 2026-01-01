//
//  RecoveryMetrics.swift
//  TetraTrackShared
//
//  Post-ride recovery analysis types
//

import Foundation

// MARK: - Recovery Metrics

public struct RecoveryMetrics: Codable, Sendable {
    public let rideEndTime: Date
    public let peakHeartRate: Int
    public let heartRateAtEnd: Int
    public let oneMinuteRecovery: Int?     // HR drop after 1 minute
    public let twoMinuteRecovery: Int?     // HR drop after 2 minutes
    public let recoveryQuality: RecoveryQuality
    public let timeToRestingHR: TimeInterval?  // Time to return to resting HR (if measured)

    public init(
        rideEndTime: Date = Date(),
        peakHeartRate: Int,
        heartRateAtEnd: Int,
        oneMinuteRecovery: Int? = nil,
        twoMinuteRecovery: Int? = nil,
        timeToRestingHR: TimeInterval? = nil
    ) {
        self.rideEndTime = rideEndTime
        self.peakHeartRate = peakHeartRate
        self.heartRateAtEnd = heartRateAtEnd
        self.oneMinuteRecovery = oneMinuteRecovery
        self.twoMinuteRecovery = twoMinuteRecovery
        self.timeToRestingHR = timeToRestingHR

        // Calculate recovery quality based on 1-minute recovery
        if let recovery = oneMinuteRecovery {
            self.recoveryQuality = RecoveryQuality.quality(for: recovery)
        } else {
            self.recoveryQuality = .unknown
        }
    }

    // MARK: - Formatted Values

    public var formattedOneMinuteRecovery: String {
        guard let recovery = oneMinuteRecovery else { return "--" }
        return "\(recovery) bpm"
    }

    public var formattedTwoMinuteRecovery: String {
        guard let recovery = twoMinuteRecovery else { return "--" }
        return "\(recovery) bpm"
    }

    public var formattedTimeToResting: String {
        guard let time = timeToRestingHR else { return "--" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Recovery Quality

public enum RecoveryQuality: String, Codable, CaseIterable, Sendable {
    case excellent
    case good
    case average
    case belowAverage
    case poor
    case unknown

    public var displayName: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .average: return "Average"
        case .belowAverage: return "Below Average"
        case .poor: return "Poor"
        case .unknown: return "Unknown"
        }
    }

    public var description: String {
        switch self {
        case .excellent:
            return "Outstanding cardiovascular fitness"
        case .good:
            return "Above average heart rate recovery"
        case .average:
            return "Normal heart rate recovery"
        case .belowAverage:
            return "Consider more aerobic training"
        case .poor:
            return "May indicate fatigue or overtraining"
        case .unknown:
            return "Recovery data not available"
        }
    }

    public var colorName: String {
        switch self {
        case .excellent: return "green"
        case .good: return "teal"
        case .average: return "blue"
        case .belowAverage: return "orange"
        case .poor: return "red"
        case .unknown: return "gray"
        }
    }

    public var iconName: String {
        switch self {
        case .excellent: return "star.fill"
        case .good: return "checkmark.circle.fill"
        case .average: return "circle.fill"
        case .belowAverage: return "exclamationmark.circle.fill"
        case .poor: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    /// Calculate recovery quality from 1-minute heart rate drop
    /// Based on exercise physiology standards:
    /// - Excellent: >40 bpm drop
    /// - Good: 30-40 bpm drop
    /// - Average: 20-29 bpm drop
    /// - Below Average: 12-19 bpm drop
    /// - Poor: <12 bpm drop
    public static func quality(for oneMinuteRecovery: Int) -> RecoveryQuality {
        switch oneMinuteRecovery {
        case 40...: return .excellent
        case 30..<40: return .good
        case 20..<30: return .average
        case 12..<20: return .belowAverage
        default: return .poor
        }
    }
}

// MARK: - Recovery Sample (for tracking post-ride HR)

public struct RecoverySample: Codable, Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let bpm: Int
    public let secondsSinceRideEnd: TimeInterval

    public init(timestamp: Date, bpm: Int, rideEndTime: Date) {
        self.id = UUID()
        self.timestamp = timestamp
        self.bpm = bpm
        self.secondsSinceRideEnd = timestamp.timeIntervalSince(rideEndTime)
    }
}

// MARK: - Recovery Session

public struct RecoverySession: Codable, Sendable {
    public let rideEndTime: Date
    public let samples: [RecoverySample]
    public let peakHeartRate: Int
    public let restingHeartRate: Int?

    public init(
        rideEndTime: Date,
        samples: [RecoverySample] = [],
        peakHeartRate: Int,
        restingHeartRate: Int? = nil
    ) {
        self.rideEndTime = rideEndTime
        self.samples = samples
        self.peakHeartRate = peakHeartRate
        self.restingHeartRate = restingHeartRate
    }

    /// Get HR at a specific time after ride end
    public func heartRate(at secondsAfterEnd: TimeInterval) -> Int? {
        let targetTime = rideEndTime.addingTimeInterval(secondsAfterEnd)
        let tolerance: TimeInterval = 5.0 // 5 second tolerance

        return samples
            .filter { abs($0.timestamp.timeIntervalSince(targetTime)) < tolerance }
            .min { abs($0.timestamp.timeIntervalSince(targetTime)) < abs($1.timestamp.timeIntervalSince(targetTime)) }?
            .bpm
    }

    /// Calculate 1-minute recovery (HR drop)
    public var oneMinuteRecovery: Int? {
        guard let hrAtEnd = samples.first?.bpm,
              let hrAt1Min = heartRate(at: 60) else {
            return nil
        }
        return hrAtEnd - hrAt1Min
    }

    /// Calculate 2-minute recovery (HR drop)
    public var twoMinuteRecovery: Int? {
        guard let hrAtEnd = samples.first?.bpm,
              let hrAt2Min = heartRate(at: 120) else {
            return nil
        }
        return hrAtEnd - hrAt2Min
    }

    /// Calculate time to return to resting HR
    public var timeToRestingHR: TimeInterval? {
        guard let restingHR = restingHeartRate else { return nil }
        let targetHR = restingHR + 10 // Within 10 bpm of resting

        let sortedSamples = samples.sorted { $0.timestamp < $1.timestamp }
        for sample in sortedSamples {
            if sample.bpm <= targetHR {
                return sample.secondsSinceRideEnd
            }
        }
        return nil
    }

    /// Build final recovery metrics
    public func buildMetrics() -> RecoveryMetrics {
        let hrAtEnd = samples.first?.bpm ?? 0

        return RecoveryMetrics(
            rideEndTime: rideEndTime,
            peakHeartRate: peakHeartRate,
            heartRateAtEnd: hrAtEnd,
            oneMinuteRecovery: oneMinuteRecovery,
            twoMinuteRecovery: twoMinuteRecovery,
            timeToRestingHR: timeToRestingHR
        )
    }
}
