//
//  ShootingSensorAnalyzer.swift
//  TetraTrack
//
//  Analyzes Watch sensor data for shooting sessions.
//  Computes session-level metrics and GRACE pillar scores from per-shot data.
//

import Foundation
import TetraTrackShared

enum ShootingSensorAnalyzer {

    // MARK: - Session Analysis

    struct SessionAnalysis {
        // Session averages
        let averageHoldSteadiness: Double
        let averageHoldDuration: Double
        let shotTimingConsistencyCV: Double
        let firstHalfSteadiness: Double
        let secondHalfSteadiness: Double
        let steadinessDegradation: Double

        // GRACE pillar scores (0-100)
        let graceStandTallScore: Double
        let graceShotTimingScore: Double
        let graceAimTrueScore: Double
        let graceShotEconomyScore: Double
        let graceComposureScore: Double
        let graceOverallScore: Double
    }

    /// Analyze a collection of per-shot metrics from a shooting session
    static func analyzeSession(
        shotMetrics: [DetectedShotMetrics],
        sessionStanceStability: Double = 0,
        averageHeartRate: Int = 0
    ) -> SessionAnalysis {
        guard !shotMetrics.isEmpty else {
            return SessionAnalysis(
                averageHoldSteadiness: 0, averageHoldDuration: 0,
                shotTimingConsistencyCV: 0, firstHalfSteadiness: 0,
                secondHalfSteadiness: 0, steadinessDegradation: 0,
                graceStandTallScore: 0, graceShotTimingScore: 0,
                graceAimTrueScore: 0, graceShotEconomyScore: 0,
                graceComposureScore: 0, graceOverallScore: 0
            )
        }

        // Session averages
        let avgSteadiness = shotMetrics.map(\.holdSteadiness).average
        let avgHoldDuration = shotMetrics.map(\.holdDuration).average
        let timingCV = computeTimingCV(shotMetrics)

        // Fatigue tracking
        let midpoint = shotMetrics.count / 2
        let firstHalf = Array(shotMetrics.prefix(max(1, midpoint)))
        let secondHalf = Array(shotMetrics.suffix(max(1, shotMetrics.count - midpoint)))
        let firstHalfSteadiness = firstHalf.map(\.holdSteadiness).average
        let secondHalfSteadiness = secondHalf.map(\.holdSteadiness).average
        let degradation = firstHalfSteadiness > 0
            ? max(0, (firstHalfSteadiness - secondHalfSteadiness) / firstHalfSteadiness * 100)
            : 0

        // GRACE pillars
        let standTall = computeStandTallScore(
            sessionStanceStability: sessionStanceStability,
            shotMetrics: shotMetrics
        )
        let shotTiming = computeShotTimingScore(timingCV: timingCV)
        let aimTrue = computeAimTrueScore(shotMetrics: shotMetrics)
        let shotEconomy = computeShotEconomyScore(shotMetrics: shotMetrics)
        let composure = computeComposureScore(
            shotMetrics: shotMetrics,
            averageHeartRate: averageHeartRate,
            degradation: degradation
        )

        let pillars = [standTall, shotTiming, aimTrue, shotEconomy, composure]
        let nonZero = pillars.filter { $0 > 0 }
        let overall = nonZero.isEmpty ? 0 : nonZero.average

        return SessionAnalysis(
            averageHoldSteadiness: avgSteadiness,
            averageHoldDuration: avgHoldDuration,
            shotTimingConsistencyCV: timingCV,
            firstHalfSteadiness: firstHalfSteadiness,
            secondHalfSteadiness: secondHalfSteadiness,
            steadinessDegradation: degradation,
            graceStandTallScore: standTall,
            graceShotTimingScore: shotTiming,
            graceAimTrueScore: aimTrue,
            graceShotEconomyScore: shotEconomy,
            graceComposureScore: composure,
            graceOverallScore: overall
        )
    }

    /// Apply analysis results to a ShootingSession model
    static func applyAnalysis(_ analysis: SessionAnalysis, to session: ShootingSession) {
        session.averageHoldSteadiness = analysis.averageHoldSteadiness
        session.averageHoldDuration = analysis.averageHoldDuration
        session.shotTimingConsistencyCV = analysis.shotTimingConsistencyCV
        session.firstHalfSteadiness = analysis.firstHalfSteadiness
        session.secondHalfSteadiness = analysis.secondHalfSteadiness
        session.steadinessDegradation = analysis.steadinessDegradation
        session.graceStandTallScore = analysis.graceStandTallScore
        session.graceShotTimingScore = analysis.graceShotTimingScore
        session.graceAimTrueScore = analysis.graceAimTrueScore
        session.graceShotEconomyScore = analysis.graceShotEconomyScore
        session.graceComposureScore = analysis.graceComposureScore
        session.graceOverallScore = analysis.graceOverallScore
    }

    /// Apply per-shot sensor data to Shot models (matching by index)
    static func applyShotSensorData(
        _ metrics: [DetectedShotMetrics],
        to shots: [Shot]
    ) {
        let sortedShots = shots.sorted { $0.orderIndex < $1.orderIndex }
        for metric in metrics {
            // Match by shot index (1-based from detector, 0-based in model)
            let targetIndex = metric.shotIndex - 1
            guard targetIndex >= 0, targetIndex < sortedShots.count else { continue }
            let shot = sortedShots[targetIndex]
            shot.holdSteadiness = metric.holdSteadiness
            shot.holdDuration = metric.holdDuration
            shot.raiseSmoothness = metric.raiseSmoothness
            shot.settleDuration = metric.settleDuration
            shot.tremorIntensity = metric.tremorIntensity
            shot.driftMagnitude = metric.driftMagnitude
            shot.totalCycleTime = metric.totalCycleTime
            shot.heartRateAtShot = metric.heartRateAtShot ?? 0
            shot.holdPitchVariance = metric.holdPitchVariance
            shot.holdYawVariance = metric.holdYawVariance
        }
    }

    // MARK: - GRACE Pillar Calculations

    /// G "Stand Tall" — Posture: session stance stability (60%) + pitch/roll variance (40%)
    private static func computeStandTallScore(
        sessionStanceStability: Double,
        shotMetrics: [DetectedShotMetrics]
    ) -> Double {
        var total: Double = 0
        var weight: Double = 0

        // Session stance stability (60%)
        if sessionStanceStability > 0 {
            total += sessionStanceStability * 0.6
            weight += 0.6
        }

        // Pitch/roll variance from shot data (40%)
        if !shotMetrics.isEmpty {
            let avgPitchVar = shotMetrics.map(\.holdPitchVariance).average
            let avgYawVar = shotMetrics.map(\.holdYawVariance).average
            let combinedVar = avgPitchVar + avgYawVar
            // Lower variance = better score
            let varScore = max(0, min(100, 100 * (1.0 - combinedVar / 0.01)))
            total += varScore * 0.4
            weight += 0.4
        }

        return weight > 0 ? total / weight : 0
    }

    /// R "Shot Timing" — Rhythm: timing CV score (CV <0.15 = 90+, >0.3 = poor)
    private static func computeShotTimingScore(timingCV: Double) -> Double {
        guard timingCV > 0 else { return 0 }
        // CV <0.10 = 100, 0.15 = 90, 0.20 = 70, 0.30 = 40, >0.40 = 10
        if timingCV < 0.10 { return 100 }
        if timingCV < 0.15 { return 90 + (0.15 - timingCV) / 0.05 * 10 }
        if timingCV < 0.20 { return 70 + (0.20 - timingCV) / 0.05 * 20 }
        if timingCV < 0.30 { return 40 + (0.30 - timingCV) / 0.10 * 30 }
        if timingCV < 0.40 { return 10 + (0.40 - timingCV) / 0.10 * 30 }
        return max(5, 10 * (1.0 - timingCV))
    }

    /// A "Aim True" — Precision: hold steadiness (70%) + inverse drift (30%)
    private static func computeAimTrueScore(shotMetrics: [DetectedShotMetrics]) -> Double {
        guard !shotMetrics.isEmpty else { return 0 }

        let steadiness = shotMetrics.map(\.holdSteadiness).average
        let inverseDrift = shotMetrics.map { max(0, 100 - $0.driftMagnitude) }.average

        return steadiness * 0.7 + inverseDrift * 0.3
    }

    /// C "Shot Economy" — Efficiency: cycle time optimality (50%) + raise smoothness (50%)
    private static func computeShotEconomyScore(shotMetrics: [DetectedShotMetrics]) -> Double {
        guard !shotMetrics.isEmpty else { return 0 }

        // Cycle time optimality: ideal 5-10 seconds
        let avgCycleTime = shotMetrics.map(\.totalCycleTime).average
        let cycleScore: Double
        if avgCycleTime >= 5.0 && avgCycleTime <= 10.0 {
            cycleScore = 100
        } else if avgCycleTime < 5.0 {
            // Too fast: rushing
            cycleScore = max(20, avgCycleTime / 5.0 * 100)
        } else {
            // Too slow: hesitating (>10s)
            cycleScore = max(20, 100 - (avgCycleTime - 10.0) / 10.0 * 80)
        }

        // Raise smoothness
        let smoothness = shotMetrics.map(\.raiseSmoothness).average

        return cycleScore * 0.5 + smoothness * 0.5
    }

    /// E "Composure" — Under Pressure: HR management (30%) + fatigue resistance (35%) + tremor control (35%)
    private static func computeComposureScore(
        shotMetrics: [DetectedShotMetrics],
        averageHeartRate: Int,
        degradation: Double
    ) -> Double {
        var total: Double = 0
        var weight: Double = 0

        // HR management (30%): lower is better for shooting
        // Ideal range 60-80 bpm for shooting
        if averageHeartRate > 0 {
            let hrScore: Double
            if averageHeartRate <= 70 { hrScore = 100 }
            else if averageHeartRate <= 80 { hrScore = 90 }
            else if averageHeartRate <= 90 { hrScore = 75 }
            else if averageHeartRate <= 100 { hrScore = 55 }
            else if averageHeartRate <= 120 { hrScore = 35 }
            else { hrScore = 15 }
            total += hrScore * 0.3
            weight += 0.3
        }

        // Fatigue resistance (35%): less degradation = better
        let fatigueScore = max(0, min(100, 100 - degradation * 2))
        total += fatigueScore * 0.35
        weight += 0.35

        // Tremor control (35%): lower tremor = better
        if !shotMetrics.isEmpty {
            let avgTremor = shotMetrics.map(\.tremorIntensity).average
            let tremorScore = max(0, 100 - avgTremor)
            total += tremorScore * 0.35
            weight += 0.35
        }

        return weight > 0 ? total / weight : 0
    }

    // MARK: - Helpers

    /// Compute coefficient of variation of inter-shot intervals
    private static func computeTimingCV(_ metrics: [DetectedShotMetrics]) -> Double {
        guard metrics.count >= 3 else { return 0 }

        let sorted = metrics.sorted { $0.timestamp < $1.timestamp }
        var intervals: [Double] = []
        for i in 1..<sorted.count {
            let interval = sorted[i].timestamp.timeIntervalSince(sorted[i-1].timestamp)
            if interval > 0 && interval < 120 { // Ignore gaps > 2 minutes
                intervals.append(interval)
            }
        }

        guard intervals.count >= 2 else { return 0 }
        let mean = intervals.average
        guard mean > 0 else { return 0 }

        let stdDev = sqrt(intervals.map { ($0 - mean) * ($0 - mean) }.average)
        return stdDev / mean
    }
}

// MARK: - Array Average Extension

private extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
