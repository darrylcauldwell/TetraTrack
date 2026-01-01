//
//  SegmentPBAnalyzer.swift
//  TetraTrack
//
//  Analyzes GPS location points to find best times for standard distances
//  within longer runs (e.g., best 1500m within a 5k run).
//

import Foundation
import CoreLocation

// MARK: - Segment PB Result

struct SegmentPBResult: Codable, Identifiable, Sendable {
    var id = UUID()
    var distance: Double          // Target distance (e.g., 1500)
    var time: TimeInterval        // Best time found for this distance
    var startIndex: Int           // Index of start point
    var endIndex: Int             // Index of end point
    var currentPB: TimeInterval   // Current PB for comparison
    var isNewPB: Bool             // Whether this beats the current PB

    var formattedTime: String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    var improvementSeconds: TimeInterval {
        guard currentPB > 0, isNewPB else { return 0 }
        return currentPB - time
    }

    var formattedImprovement: String {
        guard improvementSeconds > 0 else { return "" }
        return String(format: "-%.0fs", improvementSeconds)
    }

    var distanceLabel: String {
        if distance >= 1000 {
            return String(format: "%.0fm", distance)
        }
        return String(format: "%.0fm", distance)
    }
}

// MARK: - Segment PB Analyzer

enum SegmentPBAnalyzer {
    /// Standard distances to search for within longer runs
    static let trackedDistances: [Double] = [1000, 1500, 2000, 3000]

    /// Analyze GPS location points to find best segment times for tracked distances.
    /// Only analyzes runs longer than the target distance by >10% (skips dedicated time trials).
    /// Only reports results within 10% of PB to filter noise.
    static func analyze(
        locationPoints: [RunningLocationPoint],
        totalDistance: Double,
        personalBests: RunningPersonalBests
    ) -> [SegmentPBResult] {
        guard locationPoints.count > 10 else { return [] }

        let sortedPoints = locationPoints.sorted { $0.timestamp < $1.timestamp }
        var results: [SegmentPBResult] = []

        // Pre-compute cumulative distances between consecutive points
        var cumulativeDistances: [Double] = [0]
        for i in 1..<sortedPoints.count {
            let prev = CLLocation(latitude: sortedPoints[i-1].latitude, longitude: sortedPoints[i-1].longitude)
            let curr = CLLocation(latitude: sortedPoints[i].latitude, longitude: sortedPoints[i].longitude)
            let delta = curr.distance(from: prev)
            cumulativeDistances.append(cumulativeDistances.last! + delta)
        }

        let totalCumulativeDistance = cumulativeDistances.last ?? 0

        for targetDistance in trackedDistances {
            // Only analyze if run is >10% longer than target (skip dedicated time trials)
            guard totalCumulativeDistance > targetDistance * 1.1 else { continue }

            let currentPB = personalBests.personalBest(for: targetDistance)

            // Sliding window: find the fastest segment of exactly targetDistance
            var bestTime: TimeInterval = .infinity
            var bestStartIndex = 0
            var bestEndIndex = 0
            var endIdx = 1

            for startIdx in 0..<sortedPoints.count {
                // Advance end index until we reach target distance
                while endIdx < sortedPoints.count &&
                      (cumulativeDistances[endIdx] - cumulativeDistances[startIdx]) < targetDistance {
                    endIdx += 1
                }
                guard endIdx < sortedPoints.count else { break }

                let segmentDistance = cumulativeDistances[endIdx] - cumulativeDistances[startIdx]
                guard segmentDistance >= targetDistance else { continue }

                // Interpolate to get exact time at target distance
                let overshoot = segmentDistance - targetDistance
                let lastSegmentDist = cumulativeDistances[endIdx] - cumulativeDistances[endIdx - 1]
                let lastSegmentTime = sortedPoints[endIdx].timestamp.timeIntervalSince(sortedPoints[endIdx - 1].timestamp)
                let timeCorrection = lastSegmentDist > 0 ? (overshoot / lastSegmentDist) * lastSegmentTime : 0

                let rawTime = sortedPoints[endIdx].timestamp.timeIntervalSince(sortedPoints[startIdx].timestamp)
                let segmentTime = rawTime - timeCorrection

                // Filter out implausible segments (speed > 25 km/h or < 2 km/h suggests vehicle or standing)
                let avgSpeed = targetDistance / segmentTime // m/s
                guard avgSpeed > 0.56 && avgSpeed < 6.94 else { continue } // 2-25 km/h

                if segmentTime < bestTime {
                    bestTime = segmentTime
                    bestStartIndex = startIdx
                    bestEndIndex = endIdx
                }
            }

            guard bestTime < .infinity else { continue }

            // Only report if within 10% of PB (or if no PB exists)
            let isNewPB = currentPB == 0 || bestTime < currentPB
            let withinThreshold = currentPB == 0 || bestTime < currentPB * 1.1

            if withinThreshold {
                results.append(SegmentPBResult(
                    distance: targetDistance,
                    time: bestTime,
                    startIndex: bestStartIndex,
                    endIndex: bestEndIndex,
                    currentPB: currentPB,
                    isNewPB: isNewPB
                ))
            }
        }

        return results
    }
}
