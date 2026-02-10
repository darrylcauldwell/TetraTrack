//
//  GaitCalculator.swift
//  TetraTrack
//
//  Shared gait calculation utilities for statistics
//

import Foundation

// MARK: - Gait Time Data

/// Protocol for types that track gait times
protocol GaitTimeTracking {
    var totalWalkTime: TimeInterval { get }
    var totalTrotTime: TimeInterval { get }
    var totalCanterTime: TimeInterval { get }
    var totalGallopTime: TimeInterval { get }
}

// MARK: - Default Implementation

extension GaitTimeTracking {
    /// Total gait time across all gaits
    var totalGaitTime: TimeInterval {
        totalWalkTime + totalTrotTime + totalCanterTime + totalGallopTime
    }

    /// Gait breakdown with percentages
    var gaitBreakdown: [(gait: GaitType, duration: TimeInterval, percentage: Double)] {
        GaitCalculator.breakdown(
            walk: totalWalkTime,
            trot: totalTrotTime,
            canter: totalCanterTime,
            gallop: totalGallopTime
        )
    }

    /// Dominant gait (most time spent)
    var dominantGait: GaitType? {
        let gaits: [(GaitType, TimeInterval)] = [
            (.walk, totalWalkTime),
            (.trot, totalTrotTime),
            (.canter, totalCanterTime),
            (.gallop, totalGallopTime)
        ]
        return gaits.max(by: { $0.1 < $1.1 })?.0
    }

    /// Percentage of time at a specific gait
    func gaitPercentage(_ gait: GaitType) -> Double {
        guard totalGaitTime > 0 else { return 0 }
        let gaitTime: TimeInterval
        switch gait {
        case .walk: gaitTime = totalWalkTime
        case .trot: gaitTime = totalTrotTime
        case .canter: gaitTime = totalCanterTime
        case .gallop: gaitTime = totalGallopTime
        case .stationary: gaitTime = 0
        }
        return (gaitTime / totalGaitTime) * 100
    }
}

// MARK: - Gait Calculator

enum GaitCalculator {
    /// Calculate gait breakdown with percentages
    static func breakdown(
        walk: TimeInterval,
        trot: TimeInterval,
        canter: TimeInterval,
        gallop: TimeInterval
    ) -> [(gait: GaitType, duration: TimeInterval, percentage: Double)] {
        let total = walk + trot + canter + gallop
        guard total > 0 else { return [] }

        var breakdown: [(GaitType, TimeInterval, Double)] = []

        if walk > 0 {
            breakdown.append((.walk, walk, (walk / total) * 100))
        }
        if trot > 0 {
            breakdown.append((.trot, trot, (trot / total) * 100))
        }
        if canter > 0 {
            breakdown.append((.canter, canter, (canter / total) * 100))
        }
        if gallop > 0 {
            breakdown.append((.gallop, gallop, (gallop / total) * 100))
        }

        return breakdown
    }

    /// Calculate gait balance score (0-100)
    /// Higher score = more balanced across gaits
    static func balanceScore(
        walk: TimeInterval,
        trot: TimeInterval,
        canter: TimeInterval,
        gallop: TimeInterval
    ) -> Double {
        let total = walk + trot + canter + gallop
        guard total > 0 else { return 0 }

        let times = [walk, trot, canter, gallop].filter { $0 > 0 }
        guard times.count > 1 else { return 100 } // Single gait = perfectly balanced for that gait

        let average = total / Double(times.count)
        let variance = times.reduce(0) { $0 + pow($1 - average, 2) } / Double(times.count)
        let stdDev = sqrt(variance)

        // Normalize: lower std deviation relative to average = higher balance
        let coefficient = stdDev / average
        return max(0, min(100, (1 - coefficient) * 100))
    }
}
