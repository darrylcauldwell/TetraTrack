//
//  WalkingAnalysisService.swift
//  TetraTrack
//
//  Computes walking biomechanics from session + HealthKit data
//

import Foundation

@Observable
@MainActor
final class WalkingAnalysisService {

    // MARK: - Walking Scores

    struct WalkingScores {
        let symmetryScore: Double    // 0-100
        let rhythmScore: Double      // 0-100
        let stabilityScore: Double   // 0-100
        let cadenceConsistency: Double // coefficient of variation
    }

    // MARK: - Compute Scores

    /// Compute walking biomechanics scores from a completed walking session
    func computeScores(from session: RunningSession) -> WalkingScores {
        let symmetry = computeSymmetryScore(session: session)
        let rhythm = computeRhythmScore(session: session)
        let stability = computeStabilityScore(session: session)
        let cadenceCV = computeCadenceCV(session: session)

        return WalkingScores(
            symmetryScore: symmetry,
            rhythmScore: rhythm,
            stabilityScore: stability,
            cadenceConsistency: cadenceCV
        )
    }

    /// Apply computed scores to a walking session
    func applyScores(_ scores: WalkingScores, to session: RunningSession) {
        session.walkingSymmetryScore = scores.symmetryScore
        session.walkingRhythmScore = scores.rhythmScore
        session.walkingStabilityScore = scores.stabilityScore
        session.walkingCadenceConsistency = scores.cadenceConsistency
    }

    // MARK: - Individual Score Computations

    /// Symmetry: from HealthKit walking asymmetry percentage, blended with double support %
    /// <5% asymmetry = score >50, perfect symmetry (0%) = 100
    private func computeSymmetryScore(session: RunningSession) -> Double {
        if let asymmetry = session.healthKitAsymmetry {
            // asymmetry is a percentage (0 = perfect)
            // Score: max(0, 100 - (asymmetry * 10))
            let asymmetryScore = max(0, min(100, 100 - (asymmetry * 10)))

            // Blend with double support % when available (20% weight)
            // Normal double support is ~20-30%; lower = better balance
            if let doubleSupport = session.healthKitDoubleSupportPercentage, doubleSupport > 0 {
                let dsScore: Double
                if doubleSupport <= 20 { dsScore = 95 }
                else if doubleSupport <= 25 { dsScore = 80 }
                else if doubleSupport <= 30 { dsScore = 65 }
                else { dsScore = max(30, 65 - (doubleSupport - 30) * 3) }

                return asymmetryScore * 0.8 + dsScore * 0.2
            }

            return asymmetryScore
        }

        // Fallback: estimate from cadence consistency if no HealthKit data
        let splits = session.sortedSplits
        guard splits.count >= 2 else { return 0 }

        let cadences = splits.map { Double($0.cadence) }.filter { $0 > 0 }
        guard cadences.count >= 2 else { return 0 }

        let mean = cadences.reduce(0, +) / Double(cadences.count)
        let variance = cadences.map { pow($0 - mean, 2) }.reduce(0, +) / Double(cadences.count)
        let cv = sqrt(variance) / mean

        // Lower CV = better symmetry
        return max(0, min(100, 100 - (cv * 500)))
    }

    /// Rhythm: coefficient of variation of per-split cadence
    /// Lower CV = more consistent rhythm = higher score
    private func computeRhythmScore(session: RunningSession) -> Double {
        let cv = computeCadenceCV(session: session)
        guard cv > 0 else {
            // If we can't compute CV, use average cadence proximity to 120 SPM
            guard session.averageCadence > 0 else { return 0 }
            let deviation = abs(Double(session.averageCadence) - 120.0)
            return max(0, min(100, 100 - (deviation * 2.5)))
        }

        // CV -> score: CV of 0 = 100, CV of 0.2 = 0
        return max(0, min(100, 100 - (cv * 500)))
    }

    /// Stability: prefer Apple Walking Steadiness as primary input, fall back to speed CV
    private func computeStabilityScore(session: RunningSession) -> Double {
        // Prefer Apple's composite Walking Steadiness (0-100 scale)
        if let steadiness = session.healthKitWalkingSteadiness, steadiness > 0 {
            return steadiness
        }

        let splits = session.sortedSplits
        guard splits.count >= 2 else {
            // Fallback: if no splits, use overall metrics
            guard session.totalDuration > 60 else { return 0 }
            return 50 // baseline score for short sessions without splits
        }

        let speeds = splits.map(\.speed).filter { $0 > 0 }
        guard speeds.count >= 2 else { return 0 }

        let mean = speeds.reduce(0, +) / Double(speeds.count)
        guard mean > 0 else { return 0 }

        let variance = speeds.map { pow($0 - mean, 2) }.reduce(0, +) / Double(speeds.count)
        let cv = sqrt(variance) / mean

        // CV -> score: CV of 0 = 100, CV of 0.5 = 0
        return max(0, min(100, 100 - (cv * 200)))
    }

    /// Compute coefficient of variation of cadence across splits
    private func computeCadenceCV(session: RunningSession) -> Double {
        let splits = session.sortedSplits
        let cadences = splits.map { Double($0.cadence) }.filter { $0 > 0 }
        guard cadences.count >= 2 else { return 0 }

        let mean = cadences.reduce(0, +) / Double(cadences.count)
        guard mean > 0 else { return 0 }

        let variance = cadences.map { pow($0 - mean, 2) }.reduce(0, +) / Double(cadences.count)
        return sqrt(variance) / mean
    }

    // MARK: - Running Readiness

    /// Predict running readiness from walking biomechanics
    /// Walking symmetry and rhythm are strong predictors of running form quality
    func runningReadiness(from session: RunningSession) -> Double {
        guard session.hasWalkingScores else { return 0 }

        // When Apple Walking Steadiness is available, blend it in (15%)
        if let steadiness = session.healthKitWalkingSteadiness, steadiness > 0 {
            // Weighted: symmetry 35%, rhythm 30%, stability 20%, Apple steadiness 15%
            let readiness = session.walkingSymmetryScore * 0.35
                + session.walkingRhythmScore * 0.30
                + session.walkingStabilityScore * 0.20
                + steadiness * 0.15
            return min(100, readiness)
        }

        // Standard: symmetry 40%, rhythm 35%, stability 25%
        let readiness = session.walkingSymmetryScore * 0.40
            + session.walkingRhythmScore * 0.35
            + session.walkingStabilityScore * 0.25

        return min(100, readiness)
    }

    /// Running readiness label
    func runningReadinessLabel(score: Double) -> String {
        switch score {
        case 80...: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Fair"
        case 1..<40: return "Developing"
        default: return "No Data"
        }
    }
}
