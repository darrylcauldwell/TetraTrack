//
//  GaitHMM.swift
//  TrackRide
//
//  Hidden Markov Model for gait state transitions with breed-configurable priors
//

import Foundation
import Observation

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

    // Apple Watch data (optional - set to 0 if unavailable)
    let watchArmSymmetry: Double     // Left-right arm swing symmetry (0-1)
    let watchYawEnergy: Double       // Watch yaw energy (rad/s RMS)

    static let zero = GaitFeatureVector(
        strideFrequency: 0, h2Ratio: 0, h3Ratio: 0, spectralEntropy: 0,
        xyCoherence: 0, zYawCoherence: 0, normalizedVerticalRMS: 0,
        yawRateRMS: 0, gpsSpeed: 0, watchArmSymmetry: 0, watchYawEnergy: 0
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

    /// Configure HMM for a specific horse breed with optional age adjustment
    /// - Parameters:
    ///   - breed: Horse breed for biomechanical priors
    ///   - ageAdjustment: Factor to widen thresholds (1.0 = normal, 1.15 = young horse, 1.1 = senior)
    func configure(for breed: HorseBreed, ageAdjustment: Double = 1.0) {
        let priors = breed.biomechanicalPriors

        // Apply age adjustment to widen frequency ranges
        // Young and old horses have more variable gaits
        let walkF0 = widenRange(priors.walkFrequencyRange, by: ageAdjustment)
        let trotF0 = widenRange(priors.trotFrequencyRange, by: ageAdjustment)
        let canterF0 = widenRange(priors.canterFrequencyRange, by: ageAdjustment)
        let gallopF0 = widenRange(priors.gallopFrequencyRange, by: ageAdjustment)

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

    /// Widen a frequency range by an adjustment factor
    /// Expands both lower and upper bounds symmetrically around the center
    private func widenRange(_ range: ClosedRange<Double>, by factor: Double) -> ClosedRange<Double> {
        let center = (range.lowerBound + range.upperBound) / 2
        let halfWidth = (range.upperBound - range.lowerBound) / 2
        let newHalfWidth = halfWidth * factor
        return max(0, center - newHalfWidth)...(center + newHalfWidth)
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

        // Apply GPS speed sanity checks
        newProbs = applySpeedConstraints(newProbs, gpsSpeed: features.gpsSpeed)

        stateProbs = newProbs
    }

    /// Get probability of a specific state
    func probability(of state: HMMGaitState) -> Double {
        return stateProbs[state.rawValue]
    }

    // MARK: - Private Implementation

    /// Compute emission probability for a feature vector given a state
    private func computeEmissionProbability(_ features: GaitFeatureVector, for state: HMMGaitState) -> Double {
        let stateIdx = state.rawValue
        let params = emissionParams[stateIdx]

        // Multiply probabilities of each feature (assuming independence)
        var prob = 1.0

        prob *= params[FeatureIndex.strideFrequency.rawValue].probability(features.strideFrequency)
        prob *= params[FeatureIndex.h2Ratio.rawValue].probability(features.h2Ratio)
        prob *= params[FeatureIndex.h3Ratio.rawValue].probability(features.h3Ratio)
        prob *= params[FeatureIndex.spectralEntropy.rawValue].probability(features.spectralEntropy)
        prob *= params[FeatureIndex.xyCoherence.rawValue].probability(features.xyCoherence)
        prob *= params[FeatureIndex.zYawCoherence.rawValue].probability(features.zYawCoherence)
        prob *= params[FeatureIndex.normalizedVerticalRMS.rawValue].probability(features.normalizedVerticalRMS)
        prob *= params[FeatureIndex.yawRateRMS.rawValue].probability(features.yawRateRMS)

        // Include Watch features if available (non-zero)
        if features.watchArmSymmetry > 0 {
            prob *= params[FeatureIndex.watchArmSymmetry.rawValue].probability(features.watchArmSymmetry)
        }
        if features.watchYawEnergy > 0 {
            prob *= params[FeatureIndex.watchYawEnergy.rawValue].probability(features.watchYawEnergy)
        }

        return prob
    }

    /// Apply GPS speed constraints to state probabilities
    private func applySpeedConstraints(_ probs: [Double], gpsSpeed: Double) -> [Double] {
        var constrained = probs

        // Speed bounds for each gait (m/s)
        // These are hard constraints - can't be in a gait if speed doesn't match
        let speedBounds: [(min: Double, max: Double)] = [
            (0, 0.5),      // Stationary
            (0.3, 2.5),    // Walk
            (1.5, 5.0),    // Trot
            (3.0, 8.0),    // Canter
            (6.0, 20.0)    // Gallop
        ]

        for state in HMMGaitState.allCases {
            let bounds = speedBounds[state.rawValue]
            if gpsSpeed < bounds.min || gpsSpeed > bounds.max {
                // Reduce probability significantly but don't eliminate completely
                // (GPS can be inaccurate)
                constrained[state.rawValue] *= 0.1
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
        // High self-transition probability (stay in current gait)
        let selfProb = 0.95
        let transProb = 0.05

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
            let stddev = (range.upperBound - range.lowerBound) / 4  // 95% within range
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
}
