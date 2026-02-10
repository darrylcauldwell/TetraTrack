//
//  GaitLearningService.swift
//  TetraTrack
//
//  Learns gait characteristics from completed rides and updates horse profile
//  using exponential moving average for adaptive per-horse HMM tuning
//

import Foundation

/// Learns gait characteristics from completed rides and updates horse profile
final class GaitLearningService {

    /// Analyze a completed ride and update the horse's learned gait parameters
    func learnFromRide(_ ride: Ride, horse: Horse) {
        let segments = ride.sortedGaitSegments
        guard !segments.isEmpty else { return }

        // Group segments by gait, compute duration-weighted averages
        var gaitStats: [GaitType: GaitObservation] = [:]

        for segment in segments {
            let gait = segment.gait
            let duration = segment.duration
            guard duration > 2.0 else { continue }  // Skip very short segments

            var obs = gaitStats[gait] ?? GaitObservation()
            obs.totalDuration += duration
            obs.weightedFrequencySum += segment.strideFrequency * duration
            obs.weightedH2Sum += segment.harmonicRatioH2 * duration
            obs.weightedH3Sum += segment.harmonicRatioH3 * duration
            obs.weightedEntropySum += segment.spectralEntropy * duration
            obs.weightedCoherenceSum += segment.verticalYawCoherence * duration
            obs.segmentCount += 1
            gaitStats[gait] = obs
        }

        // Decode existing learned params or start fresh
        var learned = horse.learnedGaitParameters ?? LearnedGaitParameters()

        // EMA alpha: starts high (0.5) for first rides, decreases to 0.1 as data accumulates
        let alpha = max(0.1, 0.5 / Double(max(1, learned.rideCount + 1)))

        // Update per-gait learned parameters
        for (gait, obs) in gaitStats {
            guard obs.totalDuration > 5.0 else { continue }  // Need meaningful data

            let avgFreq = obs.weightedFrequencySum / obs.totalDuration
            let avgH2 = obs.weightedH2Sum / obs.totalDuration
            let avgH3 = obs.weightedH3Sum / obs.totalDuration
            let avgEntropy = obs.weightedEntropySum / obs.totalDuration

            switch gait {
            case .walk:
                learned.walkFrequencyCenter = ema(old: learned.walkFrequencyCenter, new: avgFreq, alpha: alpha)
                learned.walkH2Mean = ema(old: learned.walkH2Mean, new: avgH2, alpha: alpha)
            case .trot:
                learned.trotFrequencyCenter = ema(old: learned.trotFrequencyCenter, new: avgFreq, alpha: alpha)
                learned.trotH2Mean = ema(old: learned.trotH2Mean, new: avgH2, alpha: alpha)
            case .canter:
                learned.canterFrequencyCenter = ema(old: learned.canterFrequencyCenter, new: avgFreq, alpha: alpha)
                learned.canterH3Mean = ema(old: learned.canterH3Mean, new: avgH3, alpha: alpha)
            case .gallop:
                learned.gallopFrequencyCenter = ema(old: learned.gallopFrequencyCenter, new: avgFreq, alpha: alpha)
                learned.gallopEntropyMean = ema(old: learned.gallopEntropyMean, new: avgEntropy, alpha: alpha)
            case .stationary:
                break
            }
        }

        learned.rideCount += 1
        learned.lastUpdate = Date()

        horse.learnedGaitParameters = learned
        horse.updatedAt = Date()
    }

    private func ema(old: Double?, new: Double, alpha: Double) -> Double {
        guard let old = old else { return new }
        return alpha * new + (1 - alpha) * old
    }
}

/// Accumulator for duration-weighted gait feature observations
private struct GaitObservation {
    var totalDuration: TimeInterval = 0
    var weightedFrequencySum: Double = 0
    var weightedH2Sum: Double = 0
    var weightedH3Sum: Double = 0
    var weightedEntropySum: Double = 0
    var weightedCoherenceSum: Double = 0
    var segmentCount: Int = 0
}
