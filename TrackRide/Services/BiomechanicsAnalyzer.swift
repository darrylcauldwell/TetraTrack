//
//  BiomechanicsAnalyzer.swift
//  TrackRide
//
//  Computes physics-based biomechanical metrics from spectral features
//  including stride length, speed, impulsion, engagement, and training load.

import Foundation
import Observation

/// Computes biomechanical metrics from motion and gait analysis data
@Observable
final class BiomechanicsAnalyzer: Resettable {

    // MARK: - Output Metrics (Real-time, 2-4 Hz update)

    /// Estimated stride length in meters
    var strideLength: Double = 0

    /// Speed computed from stride × frequency (m/s)
    var strideSpeed: Double = 0

    /// Impulsion: ratio of forward to vertical energy (0-100)
    var impulsion: Double = 0

    /// Engagement: hindquarter energy proxy (0-100)
    var engagement: Double = 0

    /// Straightness: inverse of yaw deviation (0-100)
    var straightness: Double = 0

    /// Bend quality in turns (0-100)
    var bendQuality: Double = 0

    /// Rider stability: inverse of pitch + vertical variance (0-100)
    var riderStability: Double = 0

    /// Cumulative training load (RMS × f0 × time)
    var trainingLoad: Double = 0

    /// Mental state proxy: entropy + yaw noise (0-100)
    var mentalStateProxy: Double = 0

    /// Rhythm regularity from stride timing consistency (0-100)
    var rhythmRegularity: Double = 0

    /// Rein balance: left-right bias (-1 to +1)
    var reinBalance: Double = 0

    /// Turn balance: measured vs expected centripetal (0-100)
    var turnBalance: Double = 0

    /// Transition quality from recent gait changes (0-100)
    var transitionQuality: Double = 0

    /// Symmetry score as lameness/imbalance proxy (0-100)
    var symmetryScore: Double = 0

    // MARK: - Internal State

    private var horseProfile: Horse?
    private var lastUpdateTime: Date = .distantPast
    private let updateInterval: TimeInterval = 0.25  // 4 Hz

    // Rolling statistics
    private var strideTimings: [TimeInterval] = []
    private let maxStrideSamples = 20

    // Turn tracking
    private var recentYawRates: [Double] = []
    private var recentSpeeds: [Double] = []

    // Lateral sample buffer for rein balance calculation
    private var lateralSamples: [Double] = []
    private let maxLateralSamples = 100

    // Forward acceleration buffer for IMU displacement integration
    private var forwardAccelSamples: [Double] = []
    private var forwardVelocity: Double = 0
    private var integratedDisplacement: Double = 0
    private var strideStartTime: Date?
    private let sampleInterval: TimeInterval = 0.01  // 100Hz

    // High-pass filter state for drift compensation (2nd order Butterworth at 0.1 Hz)
    private var hpfStateX: (x1: Double, x2: Double, y1: Double, y2: Double) = (0, 0, 0, 0)
    // Filter coefficients for 0.1 Hz high-pass at 100 Hz sample rate
    private let hpfB: [Double] = [0.9911, -1.9822, 0.9911]  // Numerator coefficients
    private let hpfA: [Double] = [1.0, -1.9821, 0.9823]     // Denominator coefficients

    init() {}

    // MARK: - Configuration

    /// Configure with horse profile for breed-specific calculations
    func configure(for horse: Horse?) {
        self.horseProfile = horse
    }

    /// Reset all metrics
    func reset() {
        strideLength = 0
        strideSpeed = 0
        impulsion = 0
        engagement = 0
        straightness = 0
        bendQuality = 0
        riderStability = 0
        trainingLoad = 0
        mentalStateProxy = 0
        rhythmRegularity = 0
        reinBalance = 0
        turnBalance = 0
        transitionQuality = 0
        symmetryScore = 0
        strideTimings = []
        recentYawRates = []
        recentSpeeds = []
        lateralSamples = []
        forwardAccelSamples = []
        forwardVelocity = 0
        integratedDisplacement = 0
        strideStartTime = nil
        lastUpdateTime = .distantPast
        hpfStateX = (0, 0, 0, 0)  // Reset high-pass filter state
    }

    // MARK: - Update Methods

    /// Main update method - called at ~4Hz with current analysis data
    func update(
        strideFrequency: Double,
        gait: GaitType,
        verticalRMS: Double,
        forwardRMS: Double,
        lateralRMS: Double,
        yawRateMean: Double,
        yawRateStdDev: Double,
        pitchRMS: Double,
        spectralEntropy: Double,
        xyCoherence: Double,
        zYawCoherence: Double,
        gpsSpeed: Double,
        elapsedTime: TimeInterval
    ) {
        let now = Date()
        let dt = now.timeIntervalSince(lastUpdateTime)
        lastUpdateTime = now

        // Update rolling buffers
        recentYawRates.append(yawRateMean)
        recentSpeeds.append(gpsSpeed)
        if recentYawRates.count > 20 {
            recentYawRates.removeFirst()
            recentSpeeds.removeFirst()
        }

        // Compute stride length using physics formula
        let bioStrideLength = computeStrideLength(
            frequency: strideFrequency,
            gait: gait,
            verticalRMS: verticalRMS
        )

        // Blend 70% biomechanical estimate with 30% IMU-derived displacement
        let imuDisplacement = getIMUStrideDisplacement()
        if imuDisplacement > 0.1 && strideFrequency > 0 {
            // IMU displacement is per-stride, need to scale by frequency
            let imuStrideLength = imuDisplacement * strideFrequency
            strideLength = bioStrideLength * 0.7 + imuStrideLength * 0.3
            // Reset for next stride period
            resetStrideIntegration()
        } else {
            strideLength = bioStrideLength
        }

        // Speed from stride × frequency
        strideSpeed = strideLength * strideFrequency

        // Compute scaling factors from horse profile
        let heightScale = computeHeightScaleFactor()
        let breedScale = computeBreedScaleFactor(for: gait)

        // Impulsion: ratio of forward to vertical energy, scaled by breed and height
        // Spec: RMS(forward) at f0 / RMS(vertical), scaled by breed and height
        if verticalRMS > 0.01 {
            let ratio = forwardRMS / verticalRMS
            impulsion = min(100, ratio * 50 * heightScale * breedScale)
        } else {
            impulsion = 0
        }

        // Engagement: RMS forward at f0 / RMS vertical, scaled by breed and height
        // Higher engagement = more forward energy relative to vertical bounce
        if verticalRMS > 0.01 {
            let engagementRatio = forwardRMS / verticalRMS
            engagement = min(100, engagementRatio * 60 * heightScale * breedScale)
        } else {
            engagement = 0
        }

        // Straightness: low yaw rate mean = straight (scaled to 0-100)
        let yawDeviation = abs(yawRateMean)
        straightness = max(0, 100 - yawDeviation * 100)

        // Bend quality: coherence indicates coordinated turn
        bendQuality = xyCoherence * 100

        // Rider stability: inverse of pitch + vertical variance
        let instability = (pitchRMS + verticalRMS) * 50
        riderStability = max(0, 100 - instability)

        // Cumulative training load
        if strideFrequency > 0 && verticalRMS > 0.01 && dt > 0 && dt < 1.0 {
            trainingLoad += verticalRMS * strideFrequency * dt
        }

        // Mental state proxy (experimental): high entropy + yaw noise = tension
        mentalStateProxy = min(100, spectralEntropy * 50 + yawRateStdDev * 25)

        // Symmetry score from left-right coherence
        symmetryScore = xyCoherence * 100

        // Rein balance from lateral acceleration bias
        reinBalance = computeReinBalance(lateralRMS: lateralRMS, yawMean: yawRateMean)

        // Turn balance: compare measured lateral to expected centripetal
        turnBalance = computeTurnBalance(
            lateralRMS: lateralRMS,
            yawRate: yawRateMean,
            speed: gpsSpeed
        )
    }

    /// Update rhythm regularity from stride timing
    func updateStrideTiming(_ strideInterval: TimeInterval) {
        strideTimings.append(strideInterval)
        if strideTimings.count > maxStrideSamples {
            strideTimings.removeFirst()
        }

        // Compute coefficient of variation
        if strideTimings.count >= 5 {
            let mean = strideTimings.reduce(0, +) / Double(strideTimings.count)
            let variance = strideTimings.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(strideTimings.count)
            let stdDev = sqrt(variance)

            // CV of 0 = 100% rhythm, CV of 0.2 = 0% rhythm
            if mean > 0 {
                let cv = stdDev / mean
                rhythmRegularity = max(0, 100 * (1 - cv / 0.2))
            }
        }
    }

    /// Update transition quality after a gait change
    func updateTransitionQuality(
        stabilizationTime: TimeInterval,
        speedChange: Double,
        smoothness: Double
    ) {
        // Quality based on quick stabilization, appropriate speed change, smooth execution
        let timeScore = max(0, 100 - stabilizationTime * 50)
        let smoothScore = smoothness * 100

        transitionQuality = (timeScore * 0.5 + smoothScore * 0.5)
    }

    /// Add a lateral acceleration sample for rein balance calculation
    func addLateralSample(_ lateral: Double) {
        lateralSamples.append(lateral)
        if lateralSamples.count > maxLateralSamples {
            lateralSamples.removeFirst()
        }

        // Update rein balance when we have enough samples
        if lateralSamples.count >= 20 {
            reinBalance = computeReinBalanceFromSamples()
        }
    }

    /// Add a forward acceleration sample for IMU displacement integration
    /// Used to refine stride length estimate (70% bio + 30% IMU blend)
    func addForwardAccelSample(_ forward: Double) {
        // Apply 2nd-order Butterworth high-pass filter to remove DC drift and low-frequency noise
        // This is more robust than simple exponential decay for IMU drift compensation
        let filteredAccel = applyHighPassFilter(forward)

        forwardAccelSamples.append(forward)
        if forwardAccelSamples.count > maxLateralSamples {
            forwardAccelSamples.removeFirst()
        }

        // Integrate filtered acceleration to velocity
        // The high-pass filter removes DC offset that would cause velocity drift
        forwardVelocity += filteredAccel * sampleInterval * 9.81  // Convert g to m/s²

        // Apply mild velocity decay to prevent unbounded growth from residual drift
        // This is much gentler than before (0.999 vs 0.99) since HPF handles most drift
        forwardVelocity *= 0.999

        // Integrate velocity to displacement
        integratedDisplacement += abs(forwardVelocity) * sampleInterval
    }

    /// Apply 2nd-order Butterworth high-pass filter
    /// Removes DC offset and very low frequency drift from accelerometer
    private func applyHighPassFilter(_ input: Double) -> Double {
        // 2nd-order IIR filter: y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2] - a1*y[n-1] - a2*y[n-2]
        let output = hpfB[0] * input +
                     hpfB[1] * hpfStateX.x1 +
                     hpfB[2] * hpfStateX.x2 -
                     hpfA[1] * hpfStateX.y1 -
                     hpfA[2] * hpfStateX.y2

        // Update state
        hpfStateX.x2 = hpfStateX.x1
        hpfStateX.x1 = input
        hpfStateX.y2 = hpfStateX.y1
        hpfStateX.y1 = output

        return output
    }

    /// Reset IMU integration at start of new stride
    func resetStrideIntegration() {
        integratedDisplacement = 0
        forwardVelocity = 0
        strideStartTime = Date()
    }

    /// Get IMU-derived stride displacement
    func getIMUStrideDisplacement() -> Double {
        return integratedDisplacement
    }

    // MARK: - Private Calculations

    /// Compute height-based scaling factor for impulsion/engagement
    /// Larger horses naturally show lower acceleration values
    private func computeHeightScaleFactor() -> Double {
        guard let horse = horseProfile, let height = horse.heightHands else {
            return 1.0
        }
        // Normalize to 15.2hh reference horse
        // Taller horses get a boost, shorter horses get reduced
        let referenceHeight = 15.2
        return sqrt(height / referenceHeight)
    }

    /// Compute breed-based scaling factor for impulsion/engagement
    /// Different breeds have different natural movement styles
    private func computeBreedScaleFactor(for gait: GaitType) -> Double {
        guard let horse = horseProfile else {
            return 1.0
        }

        let breed = horse.typedBreed
        let priors = breed.biomechanicalPriors

        // Use typical weight as a proxy for breed characteristics
        // Lighter breeds (like Arabians) naturally show more animation
        // Heavier breeds (like drafts) show less relative acceleration
        let referenceWeight = 500.0
        let weightFactor = sqrt(referenceWeight / priors.typicalWeight)

        // Adjust based on breed category
        switch breed.category {
        case .pony:
            return weightFactor * 1.1  // Ponies are typically more animated
        case .sportHorse:
            return weightFactor * 1.0  // Reference category
        case .heavyType:
            return weightFactor * 0.9  // Heavy types move with less relative acceleration
        case .otherBreed, .other:
            return weightFactor * 1.0
        }
    }

    /// Compute stride length using physics-based formula
    /// stride = k × h × (Az/g)^0.25
    private func computeStrideLength(
        frequency: Double,
        gait: GaitType,
        verticalRMS: Double
    ) -> Double {
        guard frequency > 0 else { return 0 }

        // Use horse profile if available
        if let horse = horseProfile {
            return horse.computeStrideLength(for: gait, verticalRMS: verticalRMS)
        }

        // Default calculation for 15.2hh horse
        let priors = BiomechanicalPriors.default
        let coefficient: Double

        switch gait {
        case .walk: coefficient = priors.strideCoefficients.walk
        case .trot: coefficient = priors.strideCoefficients.trot
        case .canter: coefficient = priors.strideCoefficients.canter
        case .gallop: coefficient = priors.strideCoefficients.gallop
        case .stationary: return 0
        }

        let defaultHeight = 15.2
        let heightMeters = defaultHeight * 0.1016
        let gFactor = pow(max(verticalRMS, 0.01) / 1.0, 0.25)

        // Formula: stride = k × h × (Az/g)^0.25
        return coefficient * heightMeters * gFactor
    }

    /// Compute rein balance from lateral samples using RMS+/RMS- method
    /// Spec: (RMS_left - RMS_right) / (RMS_left + RMS_right)
    /// where left = negative Y values, right = positive Y values
    private func computeReinBalanceFromSamples() -> Double {
        guard lateralSamples.count >= 20 else { return 0 }

        // Separate positive (right) and negative (left) lateral samples
        let rightSamples = lateralSamples.filter { $0 > 0 }
        let leftSamples = lateralSamples.filter { $0 < 0 }

        // Compute RMS for each side
        let rightRMS: Double
        if rightSamples.isEmpty {
            rightRMS = 0
        } else {
            rightRMS = sqrt(rightSamples.map { $0 * $0 }.reduce(0, +) / Double(rightSamples.count))
        }

        let leftRMS: Double
        if leftSamples.isEmpty {
            leftRMS = 0
        } else {
            leftRMS = sqrt(leftSamples.map { $0 * $0 }.reduce(0, +) / Double(leftSamples.count))
        }

        // Compute balance: (left - right) / (left + right)
        let total = leftRMS + rightRMS
        guard total > 0.01 else { return 0 }

        // Positive = left bias, negative = right bias
        return (leftRMS - rightRMS) / total
    }

    /// Legacy rein balance from summary stats (used when samples not available)
    private func computeReinBalance(lateralRMS: Double, yawMean: Double) -> Double {
        // Fall back to yaw-based estimate if no samples
        let lateralBias = lateralRMS > 0.01 ? yawMean / lateralRMS : 0
        return max(-1, min(1, lateralBias))
    }

    /// Compute turn balance by comparing measured lateral to expected centripetal
    private func computeTurnBalance(lateralRMS: Double, yawRate: Double, speed: Double) -> Double {
        guard abs(yawRate) > 0.1 && speed > 0.5 else {
            // Not turning
            return 100
        }

        // Expected centripetal acceleration = v²/r = v × ω
        let expectedCentripetal = abs(speed * yawRate)

        // Compare to measured lateral
        let measured = lateralRMS

        // Good balance when measured ≈ expected
        let ratio = measured > 0.01 ? expectedCentripetal / measured : 0
        let deviation = abs(ratio - 1)

        // Score: 0 deviation = 100%, 0.5 deviation = 0%
        return max(0, 100 * (1 - deviation / 0.5))
    }

    // MARK: - Session Summary

    /// Get summary statistics for the session
    func getSessionSummary() -> BiomechanicsSummary {
        BiomechanicsSummary(
            averageStrideLength: strideLength,
            averageStrideSpeed: strideSpeed,
            averageImpulsion: impulsion,
            averageEngagement: engagement,
            averageStraightness: straightness,
            averageRiderStability: riderStability,
            totalTrainingLoad: trainingLoad,
            averageRhythmRegularity: rhythmRegularity,
            averageSymmetryScore: symmetryScore
        )
    }
}

/// Summary of biomechanical metrics for a session
struct BiomechanicsSummary {
    let averageStrideLength: Double
    let averageStrideSpeed: Double
    let averageImpulsion: Double
    let averageEngagement: Double
    let averageStraightness: Double
    let averageRiderStability: Double
    let totalTrainingLoad: Double
    let averageRhythmRegularity: Double
    let averageSymmetryScore: Double
}
