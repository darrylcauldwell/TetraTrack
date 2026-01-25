//
//  GaitHMM.swift
//  TrackRide
//
//  Hidden Markov Model for gait state transitions with breed-configurable priors
//

import Foundation
import Observation
import os

// MARK: - Diagnostic Structures (DEBUG)

#if DEBUG
/// Diagnostic snapshot for gait classification analysis
struct GaitDiagnosticSnapshot: CustomStringConvertible {
    let timestamp: Date
    let currentGait: HMMGaitState
    let proposedGait: HMMGaitState
    let confidence: Double
    let stateProbs: [String: Double]
    let features: GaitFeatureSnapshot
    let horseProfile: HorseProfileSnapshot?
    let transitionInfo: String

    var description: String {
        let probsStr = stateProbs.map { "\($0.key)=\(String(format: "%.3f", $0.value))" }.joined(separator: ", ")
        return """
        [GAIT_DIAG] {
          "timestamp": "\(ISO8601DateFormatter().string(from: timestamp))",
          "current_gait": "\(currentGait.name)",
          "proposed_gait": "\(proposedGait.name)",
          "confidence": \(String(format: "%.3f", confidence)),
          "state_probs": {\(probsStr)},
          "features": \(features.jsonString),
          "horse_profile": \(horseProfile?.jsonString ?? "null"),
          "transition": "\(transitionInfo)"
        }
        """
    }
}

/// Feature snapshot for diagnostics
struct GaitFeatureSnapshot {
    let strideFrequency: Double
    let h2Ratio: Double
    let h3Ratio: Double
    let h3h2Ratio: Double
    let spectralEntropy: Double
    let verticalRMSRaw: Double
    let verticalRMSNormalized: Double
    let yawRMS: Double
    let xyCoherence: Double
    let zYawCoherence: Double
    let gpsSpeed: Double

    var jsonString: String {
        """
        {"f0": \(String(format: "%.2f", strideFrequency)), "H2": \(String(format: "%.3f", h2Ratio)), "H3": \(String(format: "%.3f", h3Ratio)), "H3/H2": \(String(format: "%.3f", h3h2Ratio)), "entropy": \(String(format: "%.3f", spectralEntropy)), "rms_raw": \(String(format: "%.4f", verticalRMSRaw)), "rms_norm": \(String(format: "%.4f", verticalRMSNormalized)), "yaw_rms": \(String(format: "%.3f", yawRMS)), "xy_coh": \(String(format: "%.3f", xyCoherence)), "z_yaw_coh": \(String(format: "%.3f", zYawCoherence)), "gps_speed": \(String(format: "%.2f", gpsSpeed))}
        """
    }
}

/// Horse profile snapshot for diagnostics
struct HorseProfileSnapshot {
    let present: Bool
    let breed: String?
    let heightHands: Double?
    let weightKg: Double?

    var jsonString: String {
        if !present { return "null" }
        return """
        {"present": true, "breed": "\(breed ?? "unknown")", "height": \(heightHands.map { String(format: "%.1f", $0) } ?? "null"), "weight": \(weightKg.map { String(format: "%.0f", $0) } ?? "null")}
        """
    }
}

/// Transition dynamics result for hypothesis testing
struct TransitionDynamicsResult {
    let fromState: HMMGaitState
    let toState: HMMGaitState
    let stepsToTransition: Int
    let timeToTransitionSeconds: Double
    let finalProbability: Double
    let probabilityHistory: [Double]

    var summary: String {
        """
        Transition \(fromState.name) → \(toState.name): \(stepsToTransition) steps (\(String(format: "%.2f", timeToTransitionSeconds))s), final P=\(String(format: "%.3f", finalProbability))
        """
    }
}

/// False gallop event for analysis
struct FalseGallopEvent {
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let avgH3H2Ratio: Double
    let avgStrideFrequency: Double
    let peakGallopProbability: Double
    let triggeringFeatures: GaitFeatureSnapshot
}

/// False gallop report summary
struct FalseGallopReport: CustomStringConvertible {
    let totalSessionDuration: TimeInterval
    let falseGallopEvents: [FalseGallopEvent]

    var falseGallopWindowCount: Int { falseGallopEvents.count }
    var totalFalseGallopDuration: TimeInterval { falseGallopEvents.reduce(0) { $0 + $1.duration } }
    var averageFalseGallopDuration: TimeInterval { falseGallopEvents.isEmpty ? 0 : totalFalseGallopDuration / Double(falseGallopEvents.count) }
    var maximumFalseGallopDuration: TimeInterval { falseGallopEvents.map(\.duration).max() ?? 0 }
    var averageH3H2RatioDuringFalseGallop: Double { falseGallopEvents.isEmpty ? 0 : falseGallopEvents.reduce(0) { $0 + $1.avgH3H2Ratio } / Double(falseGallopEvents.count) }
    var averageStrideFrequencyDuringFalseGallop: Double { falseGallopEvents.isEmpty ? 0 : falseGallopEvents.reduce(0) { $0 + $1.avgStrideFrequency } / Double(falseGallopEvents.count) }
    var falseGallopPercentage: Double { totalSessionDuration > 0 ? (totalFalseGallopDuration / totalSessionDuration) * 100 : 0 }

    var description: String {
        """
        ╔════════════════════════════════════════════════════════════════╗
        ║           FALSE GALLOP DETECTION REPORT                        ║
        ╠════════════════════════════════════════════════════════════════╣
        ║ Session Duration:              \(String(format: "%8.1f", totalSessionDuration)) s                     ║
        ║ False Gallop Window Count:     \(String(format: "%8d", falseGallopWindowCount))                       ║
        ║ Total False Gallop Duration:   \(String(format: "%8.2f", totalFalseGallopDuration)) s                     ║
        ║ False Gallop Percentage:       \(String(format: "%8.2f", falseGallopPercentage)) %%                     ║
        ║ Average False Gallop Duration: \(String(format: "%8.2f", averageFalseGallopDuration)) s                     ║
        ║ Maximum False Gallop Duration: \(String(format: "%8.2f", maximumFalseGallopDuration)) s                     ║
        ║ Avg H3/H2 During False Gallop: \(String(format: "%8.3f", averageH3H2RatioDuringFalseGallop))                       ║
        ║ Avg Stride Freq During Gallop: \(String(format: "%8.2f", averageStrideFrequencyDuringFalseGallop)) Hz                    ║
        ╚════════════════════════════════════════════════════════════════╝
        """
    }
}
#endif

/// Feature vector for gait classification
struct GaitFeatureVector {
    let strideFrequency: Double      // f0 from FFT (Hz)
    let h2Ratio: Double              // Harmonic ratio at 2*f0
    let h3Ratio: Double              // Harmonic ratio at 3*f0
    let spectralEntropy: Double      // Signal complexity (0-1)
    let xyCoherence: Double          // Left-right symmetry (0-1)
    let zYawCoherence: Double        // Vertical-rotational coupling (0-1)
    let normalizedVerticalRMS: Double // RMS(Z) normalized by weight
    let yawRateRMS: Double           // RMS of yaw rate (rad/s)
    let gpsSpeed: Double             // Speed from GPS (m/s) for sanity checking
    let gpsAccuracy: Double          // GPS horizontal accuracy in meters (lower = better)

    // Apple Watch data (optional - set to 0 if unavailable)
    let watchArmSymmetry: Double     // Left-right arm swing symmetry (0-1)
    let watchYawEnergy: Double       // Watch yaw energy (rad/s RMS)

    static let zero = GaitFeatureVector(
        strideFrequency: 0, h2Ratio: 0, h3Ratio: 0, spectralEntropy: 0,
        xyCoherence: 0, zYawCoherence: 0, normalizedVerticalRMS: 0,
        yawRateRMS: 0, gpsSpeed: 0, gpsAccuracy: 100, watchArmSymmetry: 0, watchYawEnergy: 0
    )
}

/// HMM gait state
enum HMMGaitState: Int, CaseIterable {
    case stationary = 0
    case walk = 1
    case trot = 2
    case canter = 3
    case gallop = 4

    var name: String {
        switch self {
        case .stationary: return "Stationary"
        case .walk: return "Walk"
        case .trot: return "Trot"
        case .canter: return "Canter"
        case .gallop: return "Gallop"
        }
    }
}

/// Gaussian emission parameters for a feature
struct GaussianEmission {
    var mean: Double
    var variance: Double

    /// Compute probability density for a value
    func probability(_ value: Double) -> Double {
        guard variance > 1e-10 else { return value == mean ? 1.0 : 0.0 }
        let exponent = -((value - mean) * (value - mean)) / (2 * variance)
        let coefficient = 1.0 / sqrt(2 * .pi * variance)
        return coefficient * exp(exponent)
    }

    /// Compute log probability density for a value
    /// Using log avoids underflow when multiplying many small probabilities
    func logProbability(_ value: Double) -> Double {
        guard variance > 1e-10 else { return value == mean ? 0.0 : -1000.0 }
        let logCoeff = -0.5 * log(2 * .pi * variance)
        let exponent = -((value - mean) * (value - mean)) / (2 * variance)
        return logCoeff + exponent
    }
}

/// Hidden Markov Model for gait state transitions
/// Uses forward algorithm with constrained transitions
@Observable
final class GaitHMM {

    // MARK: - State

    /// Current state probability distribution
    private(set) var stateProbs: [Double]

    /// Most likely current state
    var currentState: HMMGaitState {
        let maxIdx = stateProbs.enumerated().max { $0.element < $1.element }?.offset ?? 0
        return HMMGaitState(rawValue: maxIdx) ?? .stationary
    }

    /// Confidence in current state (probability of most likely state)
    var stateConfidence: Double {
        stateProbs.max() ?? 0
    }

    // MARK: - Model Parameters

    /// Transition probability matrix [from][to]
    /// Constrained: only adjacent transitions allowed (walk↔trot↔canter↔gallop)
    private var transitionMatrix: [[Double]]

    /// Emission parameters for each feature for each state
    /// [state][feature] where features are indexed by GaitFeature
    private var emissionParams: [[GaussianEmission]]

    /// Feature indices
    private enum FeatureIndex: Int, CaseIterable {
        case strideFrequency = 0
        case h2Ratio = 1
        case h3Ratio = 2
        case spectralEntropy = 3
        case xyCoherence = 4
        case zYawCoherence = 5
        case normalizedVerticalRMS = 6
        case yawRateRMS = 7
        case watchArmSymmetry = 8
        case watchYawEnergy = 9
    }

    // MARK: - Initialization

    init() {
        let numFeatures = FeatureIndex.allCases.count

        // Initialize to stationary
        self.stateProbs = [1.0, 0, 0, 0, 0]

        // Initialize transition matrix with constrained transitions
        self.transitionMatrix = Self.defaultTransitionMatrix()

        // Initialize emission parameters with default values
        self.emissionParams = Self.defaultEmissionParams(numFeatures: numFeatures)
    }

    // MARK: - Configuration

    // Custom tuning parameters from horse profile
    private var customSpeedBounds: [(min: Double, max: Double)]?
    private var canterMultiplier: Double = 1.0
    private var frequencyOffset: Double = 0.0

    /// Configure HMM for a specific horse breed with optional age adjustment and custom tuning
    /// - Parameters:
    ///   - breed: Horse breed for biomechanical priors
    ///   - ageAdjustment: Factor to widen thresholds (1.0 = normal, 1.15 = young horse, 1.1 = senior)
    ///   - customSpeedBounds: User-tuned speed bounds for each gait (optional)
    ///   - transitionProbability: User-tuned self-transition probability (optional)
    ///   - canterMultiplier: User-tuned canter detection sensitivity (optional)
    ///   - frequencyOffset: User-tuned frequency offset in Hz (optional)
    func configure(
        for breed: HorseBreed,
        ageAdjustment: Double = 1.0,
        customSpeedBounds: [(min: Double, max: Double)]? = nil,
        transitionProbability: Double? = nil,
        canterMultiplier: Double? = nil,
        frequencyOffset: Double? = nil
    ) {
        // Store custom parameters
        self.customSpeedBounds = customSpeedBounds
        self.canterMultiplier = canterMultiplier ?? 1.0
        self.frequencyOffset = frequencyOffset ?? 0.0

        // Update transition matrix if custom probability provided
        if let transProb = transitionProbability {
            let selfProb = transProb
            let otherProb = 1.0 - selfProb
            transitionMatrix = [
                [selfProb, otherProb, 0, 0, 0],
                [otherProb/2, selfProb, otherProb/2, 0, 0],
                [0, otherProb/2, selfProb, otherProb/2, 0],
                [0, 0, otherProb/2, selfProb, otherProb/2],
                [0, 0, 0, otherProb, selfProb]
            ]
        }

        let priors = breed.biomechanicalPriors
        let freqOffset = self.frequencyOffset

        // Apply age adjustment to widen frequency ranges
        // Young and old horses have more variable gaits
        let walkF0 = offsetAndWidenRange(priors.walkFrequencyRange, by: ageAdjustment, offset: freqOffset)
        let trotF0 = offsetAndWidenRange(priors.trotFrequencyRange, by: ageAdjustment, offset: freqOffset)
        let canterF0 = offsetAndWidenRange(priors.canterFrequencyRange, by: ageAdjustment, offset: freqOffset)
        let gallopF0 = offsetAndWidenRange(priors.gallopFrequencyRange, by: ageAdjustment, offset: freqOffset)

        emissionParams = [
            // Stationary
            Self.createEmissions(f0: 0...0.5, h2: 0...0.3, h3: 0...0.3, entropy: 0...0.3, xyC: 0...0.3, zYawC: 0...0.3, rms: 0...0.05, yaw: 0...0.1),
            // Walk - low coherence, low entropy
            Self.createEmissions(f0: walkF0, h2: 0.3...0.7, h3: 0.2...0.5, entropy: 0.2...0.5, xyC: 0.2...0.5, zYawC: 0.2...0.4, rms: 0.05...0.15, yaw: 0.1...0.3),
            // Trot - high H2 (2-beat), very high XY coherence, low Z-yaw coherence
            Self.createEmissions(f0: trotF0, h2: 1.2...2.5, h3: 0.3...0.8, entropy: 0.3...0.6, xyC: 0.7...1.0, zYawC: 0.1...0.4, rms: 0.15...0.35, yaw: 0.2...0.5),
            // Canter - high H3 (3-beat), low XY coherence, high Z-yaw coherence
            Self.createEmissions(f0: canterF0, h2: 0.4...1.0, h3: 1.0...2.0, entropy: 0.4...0.7, xyC: 0.2...0.5, zYawC: 0.6...0.9, rms: 0.25...0.45, yaw: 0.4...0.8),
            // Gallop - weak harmonics, high entropy, strong yaw coupling
            Self.createEmissions(f0: gallopF0, h2: 0.2...0.8, h3: 0.3...0.9, entropy: 0.6...0.9, xyC: 0.1...0.4, zYawC: 0.7...1.0, rms: 0.35...0.6, yaw: 0.6...1.2)
        ]
    }

    /// Widen a frequency range by an adjustment factor and apply offset
    /// Expands both lower and upper bounds symmetrically around the center
    private func offsetAndWidenRange(_ range: ClosedRange<Double>, by factor: Double, offset: Double) -> ClosedRange<Double> {
        let center = (range.lowerBound + range.upperBound) / 2 + offset
        let halfWidth = (range.upperBound - range.lowerBound) / 2
        let newHalfWidth = halfWidth * factor
        return max(0.1, center - newHalfWidth)...(center + newHalfWidth)
    }

    /// Widen a frequency range by an adjustment factor (legacy method for backwards compatibility)
    private func widenRange(_ range: ClosedRange<Double>, by factor: Double) -> ClosedRange<Double> {
        return offsetAndWidenRange(range, by: factor, offset: 0)
    }

    /// Reset to initial state (stationary)
    func reset() {
        stateProbs = [1.0, 0, 0, 0, 0]
    }

    // MARK: - Forward Algorithm

    /// Update state probabilities with new observation using forward algorithm
    func update(with features: GaitFeatureVector) {
        // Compute emission probabilities for each state
        var emissionProbs = [Double](repeating: 0, count: HMMGaitState.allCases.count)

        for state in HMMGaitState.allCases {
            emissionProbs[state.rawValue] = computeEmissionProbability(features, for: state)
        }

        // Forward step: alpha(t) = sum_i(alpha(t-1, i) * A(i,j)) * B(j, obs)
        var newProbs = [Double](repeating: 0, count: HMMGaitState.allCases.count)

        for toState in HMMGaitState.allCases {
            var sum = 0.0
            for fromState in HMMGaitState.allCases {
                sum += stateProbs[fromState.rawValue] * transitionMatrix[fromState.rawValue][toState.rawValue]
            }
            newProbs[toState.rawValue] = sum * emissionProbs[toState.rawValue]
        }

        // Normalize
        let total = newProbs.reduce(0, +)
        if total > 1e-10 {
            for i in 0..<newProbs.count {
                newProbs[i] /= total
            }
        } else {
            // No valid probabilities, stay in current state
            newProbs = stateProbs
        }

        // Apply GPS speed sanity checks (weighted by GPS accuracy)
        newProbs = applySpeedConstraints(newProbs, gpsSpeed: features.gpsSpeed, gpsAccuracy: features.gpsAccuracy)

        stateProbs = newProbs
    }

    /// Get probability of a specific state
    func probability(of state: HMMGaitState) -> Double {
        return stateProbs[state.rawValue]
    }

    // MARK: - Private Implementation

    /// Compute emission probability for a feature vector given a state
    /// Uses log-space computation to avoid numerical underflow when multiplying many small Gaussians
    private func computeEmissionProbability(_ features: GaitFeatureVector, for state: HMMGaitState) -> Double {
        let stateIdx = state.rawValue
        let params = emissionParams[stateIdx]

        // Sum log-probabilities of each feature (assuming independence)
        // Using log avoids underflow when multiplying 8+ small Gaussian densities
        var logProb = 0.0

        logProb += params[FeatureIndex.strideFrequency.rawValue].logProbability(features.strideFrequency)
        logProb += params[FeatureIndex.h2Ratio.rawValue].logProbability(features.h2Ratio)
        logProb += params[FeatureIndex.h3Ratio.rawValue].logProbability(features.h3Ratio)
        logProb += params[FeatureIndex.spectralEntropy.rawValue].logProbability(features.spectralEntropy)
        logProb += params[FeatureIndex.xyCoherence.rawValue].logProbability(features.xyCoherence)
        logProb += params[FeatureIndex.zYawCoherence.rawValue].logProbability(features.zYawCoherence)
        logProb += params[FeatureIndex.normalizedVerticalRMS.rawValue].logProbability(features.normalizedVerticalRMS)
        logProb += params[FeatureIndex.yawRateRMS.rawValue].logProbability(features.yawRateRMS)

        // Include Watch features if available (non-zero)
        // When Watch is not available, we don't penalize/reward these features
        if features.watchArmSymmetry > 0 {
            logProb += params[FeatureIndex.watchArmSymmetry.rawValue].logProbability(features.watchArmSymmetry)
        }
        if features.watchYawEnergy > 0 {
            logProb += params[FeatureIndex.watchYawEnergy.rawValue].logProbability(features.watchYawEnergy)
        }

        // Apply canter sensitivity multiplier (user tuning)
        // Higher canterMultiplier makes canter more likely to be detected
        if state == .canter && canterMultiplier != 1.0 {
            // Add log of multiplier (multiplicative in prob space = additive in log space)
            logProb += log(canterMultiplier)
        }

        // Convert back to probability space
        // Clamp to prevent underflow/overflow
        return exp(max(-100.0, min(100.0, logProb)))
    }

    /// Apply GPS speed constraints to state probabilities
    /// - Parameters:
    ///   - probs: Current state probabilities
    ///   - gpsSpeed: GPS speed in m/s
    ///   - gpsAccuracy: GPS horizontal accuracy in meters (lower = more reliable)
    /// - Returns: Constrained state probabilities
    private func applySpeedConstraints(_ probs: [Double], gpsSpeed: Double, gpsAccuracy: Double) -> [Double] {
        var constrained = probs

        // Use custom speed bounds if configured, otherwise use defaults
        let speedBounds: [(min: Double, max: Double)] = customSpeedBounds ?? [
            (0, 0.8),      // Stationary (widened upper bound)
            (0.2, 2.8),    // Walk (widened bounds)
            (1.2, 5.5),    // Trot (widened bounds)
            (2.5, 9.0),    // Canter (widened bounds)
            (5.0, 25.0)    // Gallop (widened bounds)
        ]

        // GPS accuracy weighting:
        // - Accuracy < 5m: full constraint weight (0.1 multiplier for violations)
        // - Accuracy 5-20m: reduced constraint weight
        // - Accuracy > 20m: minimal constraint weight (0.5 multiplier)
        // - Accuracy > 50m: almost no constraint (0.8 multiplier)
        let constraintStrength: Double
        if gpsAccuracy < 5.0 {
            constraintStrength = 0.1  // High confidence GPS, apply strong constraint
        } else if gpsAccuracy < 20.0 {
            // Linear interpolation between 0.1 and 0.5
            constraintStrength = 0.1 + (gpsAccuracy - 5.0) / 15.0 * 0.4
        } else if gpsAccuracy < 50.0 {
            // Linear interpolation between 0.5 and 0.8
            constraintStrength = 0.5 + (gpsAccuracy - 20.0) / 30.0 * 0.3
        } else {
            constraintStrength = 0.8  // Low confidence GPS, barely apply constraint
        }

        for state in HMMGaitState.allCases {
            let bounds = speedBounds[state.rawValue]
            if gpsSpeed < bounds.min || gpsSpeed > bounds.max {
                // Reduce probability based on GPS accuracy
                // With poor GPS, we trust IMU more
                constrained[state.rawValue] *= constraintStrength
            }
        }

        // Renormalize
        let total = constrained.reduce(0, +)
        if total > 1e-10 {
            for i in 0..<constrained.count {
                constrained[i] /= total
            }
        }

        return constrained
    }

    /// Default transition matrix with constrained transitions
    private static func defaultTransitionMatrix() -> [[Double]] {
        // [from][to] - only allow transitions to adjacent states
        // Self-transition probability: 0.90 provides good balance between
        // stability (removing flicker) and responsiveness to actual transitions.
        // At 4 Hz update rate, this allows transitions within 2-3 seconds of sustained change.
        let selfProb = 0.90
        let transProb = 0.10

        return [
            // From stationary: can only go to walk
            [selfProb, transProb, 0, 0, 0],
            // From walk: can go to stationary or trot
            [transProb/2, selfProb, transProb/2, 0, 0],
            // From trot: can go to walk or canter
            [0, transProb/2, selfProb, transProb/2, 0],
            // From canter: can go to trot or gallop
            [0, 0, transProb/2, selfProb, transProb/2],
            // From gallop: can only go to canter
            [0, 0, 0, transProb, selfProb]
        ]
    }

    /// Default emission parameters (standard horse)
    /// Frequency ranges per spec: Walk 1-2.2Hz, Trot 2-3.8Hz, Canter 1.8-3Hz, Gallop >3Hz
    private static func defaultEmissionParams(numFeatures: Int) -> [[GaussianEmission]] {
        // Default values for a 15.2hh horse
        return [
            // Stationary: no movement
            createEmissions(f0: 0...0.5, h2: 0...0.3, h3: 0...0.3, entropy: 0...0.3, xyC: 0...0.3, zYawC: 0...0.3, rms: 0...0.05, yaw: 0...0.1),
            // Walk: 1.0-2.2 Hz, H2 0.3-0.7, H3 0.2-0.5, low coherence, low entropy
            createEmissions(f0: 1.0...2.2, h2: 0.3...0.7, h3: 0.2...0.5, entropy: 0.2...0.5, xyC: 0.2...0.5, zYawC: 0.2...0.4, rms: 0.05...0.15, yaw: 0.1...0.3),
            // Trot: 2.0-3.8 Hz, H2 > 1.2, very high XY coherence, low Z-yaw coherence
            createEmissions(f0: 2.0...3.8, h2: 1.2...2.5, h3: 0.3...0.8, entropy: 0.3...0.6, xyC: 0.7...1.0, zYawC: 0.1...0.4, rms: 0.15...0.35, yaw: 0.2...0.5),
            // Canter: 1.8-3.0 Hz, H3 > H2, low XY coherence, high Z-yaw coherence
            createEmissions(f0: 1.8...3.0, h2: 0.4...1.0, h3: 1.0...2.0, entropy: 0.4...0.7, xyC: 0.2...0.5, zYawC: 0.6...0.9, rms: 0.25...0.45, yaw: 0.4...0.8),
            // Gallop: >3.0 Hz (3.0-6.0), weak harmonics, high entropy, strong yaw coupling
            createEmissions(f0: 3.0...6.0, h2: 0.2...0.8, h3: 0.3...0.9, entropy: 0.6...0.9, xyC: 0.1...0.4, zYawC: 0.7...1.0, rms: 0.35...0.6, yaw: 0.6...1.2)
        ]
    }

    /// Create emission parameters from ranges
    /// watchArm: expected arm symmetry (0-1), watchYaw: expected watch yaw energy
    private static func createEmissions(
        f0: ClosedRange<Double>,
        h2: ClosedRange<Double>,
        h3: ClosedRange<Double>,
        entropy: ClosedRange<Double>,
        xyC: ClosedRange<Double>,
        zYawC: ClosedRange<Double>,
        rms: ClosedRange<Double>,
        yaw: ClosedRange<Double>,
        watchArm: ClosedRange<Double> = 0.3...0.7,
        watchYaw: ClosedRange<Double> = 0.1...0.5
    ) -> [GaussianEmission] {
        func toGaussian(_ range: ClosedRange<Double>) -> GaussianEmission {
            let mean = (range.lowerBound + range.upperBound) / 2
            // Use range/3 for stddev so ~99% of values within range
            // This is more tolerant of sensor variability than range/4
            // With range/4, values outside range get extremely low probability
            let stddev = (range.upperBound - range.lowerBound) / 3
            return GaussianEmission(mean: mean, variance: stddev * stddev)
        }

        return [
            toGaussian(f0),
            toGaussian(h2),
            toGaussian(h3),
            toGaussian(entropy),
            toGaussian(xyC),
            toGaussian(zYawC),
            toGaussian(rms),
            toGaussian(yaw),
            toGaussian(watchArm),
            toGaussian(watchYaw)
        ]
    }

    // MARK: - Diagnostic Methods (DEBUG)

    #if DEBUG
    /// Get all state probabilities as a dictionary for logging
    func getAllStateProbabilities() -> [String: Double] {
        var result: [String: Double] = [:]
        for state in HMMGaitState.allCases {
            result[state.name] = stateProbs[state.rawValue]
        }
        return result
    }

    /// Get individual emission probabilities for each feature (for debugging which features drive classification)
    func getEmissionBreakdown(_ features: GaitFeatureVector, for state: HMMGaitState) -> [String: Double] {
        let stateIdx = state.rawValue
        let params = emissionParams[stateIdx]

        return [
            "strideFrequency": params[FeatureIndex.strideFrequency.rawValue].probability(features.strideFrequency),
            "h2Ratio": params[FeatureIndex.h2Ratio.rawValue].probability(features.h2Ratio),
            "h3Ratio": params[FeatureIndex.h3Ratio.rawValue].probability(features.h3Ratio),
            "spectralEntropy": params[FeatureIndex.spectralEntropy.rawValue].probability(features.spectralEntropy),
            "xyCoherence": params[FeatureIndex.xyCoherence.rawValue].probability(features.xyCoherence),
            "zYawCoherence": params[FeatureIndex.zYawCoherence.rawValue].probability(features.zYawCoherence),
            "normalizedVerticalRMS": params[FeatureIndex.normalizedVerticalRMS.rawValue].probability(features.normalizedVerticalRMS),
            "yawRateRMS": params[FeatureIndex.yawRateRMS.rawValue].probability(features.yawRateRMS)
        ]
    }

    /// Simulate transition dynamics: how many steps to transition from one state to another
    /// given features that favor the target state
    /// - Parameters:
    ///   - from: Starting state
    ///   - to: Target state
    ///   - favoringFeatures: Features that favor the target state
    ///   - maxSteps: Maximum steps to simulate
    ///   - updateRateHz: Update rate (default 4 Hz)
    /// - Returns: TransitionDynamicsResult describing the transition
    func simulateTransitionDynamics(
        from: HMMGaitState,
        to: HMMGaitState,
        favoringFeatures: GaitFeatureVector,
        maxSteps: Int = 100,
        updateRateHz: Double = 4.0
    ) -> TransitionDynamicsResult {
        // Save current state
        let savedProbs = stateProbs

        // Initialize to starting state
        stateProbs = [Double](repeating: 0, count: HMMGaitState.allCases.count)
        stateProbs[from.rawValue] = 1.0

        var probabilityHistory: [Double] = [stateProbs[to.rawValue]]
        var stepsToTransition = -1

        for step in 1...maxSteps {
            update(with: favoringFeatures)
            probabilityHistory.append(stateProbs[to.rawValue])

            // Check if we've transitioned (target probability > 0.5 and is max)
            if stepsToTransition == -1 && currentState == to {
                stepsToTransition = step
            }
        }

        let result = TransitionDynamicsResult(
            fromState: from,
            toState: to,
            stepsToTransition: stepsToTransition == -1 ? maxSteps : stepsToTransition,
            timeToTransitionSeconds: Double(stepsToTransition == -1 ? maxSteps : stepsToTransition) / updateRateHz,
            finalProbability: stateProbs[to.rawValue],
            probabilityHistory: probabilityHistory
        )

        // Restore state
        stateProbs = savedProbs

        return result
    }

    /// Get the transition probability from one state to another
    func getTransitionProbability(from: HMMGaitState, to: HMMGaitState) -> Double {
        return transitionMatrix[from.rawValue][to.rawValue]
    }

    /// Log emission probability comparison between canter and gallop for a feature vector
    func logCanterGallopComparison(_ features: GaitFeatureVector) {
        let canterEmission = getEmissionBreakdown(features, for: .canter)
        let gallopEmission = getEmissionBreakdown(features, for: .gallop)

        var comparison = "[CANTER_GALLOP_EMISSION_COMPARISON]\n"
        comparison += String(format: "%-20s %12s %12s %12s\n", "Feature", "Canter P", "Gallop P", "Ratio G/C")
        comparison += String(repeating: "-", count: 60) + "\n"

        for key in canterEmission.keys.sorted() {
            let canterP = canterEmission[key] ?? 0
            let gallopP = gallopEmission[key] ?? 0
            let ratio = canterP > 1e-10 ? gallopP / canterP : Double.infinity
            comparison += String(format: "%-20s %12.6f %12.6f %12.2f\n", key, canterP, gallopP, ratio)
        }

        Log.gait.debug("\(comparison)")
    }
    #endif
}
