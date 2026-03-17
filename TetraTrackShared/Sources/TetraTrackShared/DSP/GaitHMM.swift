//
//  GaitHMM.swift
//  TetraTrackShared
//
//  Hidden Markov Model for gait state transitions with breed-configurable priors
//

import Foundation
import Observation
import os

private let logger = Logger(subsystem: "dev.dreamfold.TetraTrack", category: "GaitHMM")

/// Hidden Markov Model for gait state transitions
/// Uses forward algorithm with constrained transitions
@Observable
public final class GaitHMM {

    // MARK: - State

    /// Current state probability distribution
    public private(set) var stateProbs: [Double]

    /// Most likely current state
    public var currentState: HMMGaitState {
        let maxIdx = stateProbs.enumerated().max { $0.element < $1.element }?.offset ?? 0
        return HMMGaitState(rawValue: maxIdx) ?? .stationary
    }

    /// Confidence in current state (probability of most likely state)
    public var stateConfidence: Double {
        stateProbs.max() ?? 0
    }

    /// State probabilities as a dictionary (state name -> probability)
    public var stateProbabilitiesDict: [String: Double] {
        var result: [String: Double] = [:]
        for state in HMMGaitState.allCases {
            result[state.name] = stateProbs[state.rawValue]
        }
        return result
    }

    // MARK: - Model Parameters

    /// Transition probability matrix [from][to]
    private var transitionMatrix: [[Double]]

    /// Emission parameters for each feature for each state
    /// [state][feature]
    private var emissionParams: [[GaussianEmission]]

    /// Sensor mounting position (affects emission parameter tuning)
    private let sensorMount: SensorMount

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
        case watchVerticalOscillation = 8
        case watchMovementIntensity = 9
        case gpsSpeed = 10
    }

    /// Default GPS speed ranges (m/s) per gait state
    private static let defaultGPSSpeedRanges: [ClosedRange<Double>] = [
        0.0...0.5,    // Stationary
        0.3...2.5,    // Walk
        1.5...5.0,    // Trot
        3.0...8.0,    // Canter
        6.0...20.0    // Gallop
    ]

    // MARK: - Initialization

    public init(sensorMount: SensorMount = .trunk) {
        let numFeatures = FeatureIndex.allCases.count

        self.sensorMount = sensorMount
        self.stateProbs = [1.0, 0, 0, 0, 0]
        self.transitionMatrix = Self.defaultTransitionMatrix()
        self.emissionParams = sensorMount == .wrist
            ? Self.wristEmissionParams(numFeatures: numFeatures)
            : Self.defaultEmissionParams(numFeatures: numFeatures)
    }

    // MARK: - Configuration

    private var canterMultiplier: Double = 1.0
    private var frequencyOffset: Double = 0.0

    /// Configure HMM with biomechanical priors and optional tuning parameters
    /// - Parameters:
    ///   - priors: Biomechanical priors for the horse breed
    ///   - ageAdjustment: Factor to widen thresholds (1.0 = normal, 1.15 = young horse, 1.1 = senior)
    ///   - customSpeedBounds: User-tuned speed bounds for each gait (optional)
    ///   - transitionProbability: User-tuned self-transition probability (optional)
    ///   - canterMultiplier: User-tuned canter detection sensitivity (optional)
    ///   - frequencyOffset: User-tuned frequency offset in Hz (optional)
    public func configure(
        with priors: BiomechanicalPriors,
        ageAdjustment: Double = 1.0,
        customSpeedBounds: [(min: Double, max: Double)]? = nil,
        transitionProbability: Double? = nil,
        canterMultiplier: Double? = nil,
        frequencyOffset: Double? = nil
    ) {
        self.canterMultiplier = canterMultiplier ?? 1.0
        self.frequencyOffset = frequencyOffset ?? 0.0

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

        let freqOffset = self.frequencyOffset

        let walkF0 = offsetAndWidenRange(priors.walkFrequencyRange, by: ageAdjustment, offset: freqOffset)
        let trotF0 = offsetAndWidenRange(priors.trotFrequencyRange, by: ageAdjustment, offset: freqOffset)
        let canterF0 = offsetAndWidenRange(priors.canterFrequencyRange, by: ageAdjustment, offset: freqOffset)
        let gallopF0 = offsetAndWidenRange(priors.gallopFrequencyRange, by: ageAdjustment, offset: freqOffset)

        // Convert customSpeedBounds to GPS emission ranges, or use defaults
        let gpsRanges: [ClosedRange<Double>]
        if let bounds = customSpeedBounds {
            gpsRanges = bounds.map { $0.min...$0.max }
        } else {
            gpsRanges = Self.defaultGPSSpeedRanges
        }

        emissionParams = [
            // Stationary
            Self.createEmissions(f0: 0...0.5, h2: 0...0.3, h3: 0...0.3, entropy: 0...0.3, xyC: 0...0.3, zYawC: 0...0.3, rms: 0...0.05, yaw: 0...0.1, watchVO: 0...1.0, watchMI: 0...10.0, gps: gpsRanges[0]),
            // Walk
            Self.createEmissions(f0: walkF0, h2: 0.3...0.7, h3: 0.2...0.5, entropy: 0.2...0.5, xyC: 0.2...0.5, zYawC: 0.2...0.4, rms: 0.03...0.12, yaw: 0.05...0.20, watchVO: 2.0...4.5, watchMI: 10.0...35.0, gps: gpsRanges[1]),
            // Trot
            Self.createEmissions(f0: trotF0, h2: 1.2...2.5, h3: 0.3...0.8, entropy: 0.3...0.6, xyC: 0.7...1.0, zYawC: 0.1...0.4, rms: 0.12...0.28, yaw: 0.20...0.45, watchVO: 4.5...10.0, watchMI: 30.0...65.0, gps: gpsRanges[2]),
            // Canter
            Self.createEmissions(f0: canterF0, h2: 0.4...1.0, h3: 1.0...2.0, entropy: 0.4...0.7, xyC: 0.2...0.5, zYawC: 0.6...0.9, rms: 0.28...0.50, yaw: 0.40...0.80, watchVO: 3.5...7.5, watchMI: 45.0...80.0, gps: gpsRanges[3]),
            // Gallop
            Self.createEmissions(f0: gallopF0, h2: 0.2...0.8, h3: 0.3...0.9, entropy: 0.6...0.9, xyC: 0.1...0.4, zYawC: 0.7...1.0, rms: 0.40...0.70, yaw: 0.60...1.20, watchVO: 5.0...12.0, watchMI: 65.0...100.0, gps: gpsRanges[4])
        ]

        if sensorMount == .wrist {
            emissionParams = Self.applyWristScaling(emissionParams)
        }
    }

    /// Widen a frequency range by an adjustment factor and apply offset
    private func offsetAndWidenRange(_ range: ClosedRange<Double>, by factor: Double, offset: Double) -> ClosedRange<Double> {
        let center = (range.lowerBound + range.upperBound) / 2 + offset
        let halfWidth = (range.upperBound - range.lowerBound) / 2
        let newHalfWidth = halfWidth * factor
        return max(0.1, center - newHalfWidth)...(center + newHalfWidth)
    }

    /// Reset to initial state (stationary)
    public func reset() {
        stateProbs = [1.0, 0, 0, 0, 0]
    }

    // MARK: - Adaptive Learning

    /// Apply learned per-horse parameters to shift emission means toward observed values
    public func applyLearnedParameters(_ learned: LearnedGaitParameters) {
        guard learned.rideCount >= 3 else { return }

        let blend = min(0.5, Double(learned.rideCount) / 20.0)

        if let learnedF0 = learned.walkFrequencyCenter {
            blendEmissionMean(state: .walk, feature: .strideFrequency, toward: learnedF0, by: blend)
        }
        if let learnedH2 = learned.walkH2Mean {
            blendEmissionMean(state: .walk, feature: .h2Ratio, toward: learnedH2, by: blend)
        }
        if let learnedF0 = learned.trotFrequencyCenter {
            blendEmissionMean(state: .trot, feature: .strideFrequency, toward: learnedF0, by: blend)
        }
        if let learnedH2 = learned.trotH2Mean {
            blendEmissionMean(state: .trot, feature: .h2Ratio, toward: learnedH2, by: blend)
        }
        if let learnedF0 = learned.canterFrequencyCenter {
            blendEmissionMean(state: .canter, feature: .strideFrequency, toward: learnedF0, by: blend)
        }
        if let learnedH3 = learned.canterH3Mean {
            blendEmissionMean(state: .canter, feature: .h3Ratio, toward: learnedH3, by: blend)
        }
        if let learnedF0 = learned.gallopFrequencyCenter {
            blendEmissionMean(state: .gallop, feature: .strideFrequency, toward: learnedF0, by: blend)
        }
        if let learnedEntropy = learned.gallopEntropyMean {
            blendEmissionMean(state: .gallop, feature: .spectralEntropy, toward: learnedEntropy, by: blend)
        }
    }

    private func blendEmissionMean(state: HMMGaitState, feature: FeatureIndex, toward target: Double, by blend: Double) {
        let current = emissionParams[state.rawValue][feature.rawValue].mean
        emissionParams[state.rawValue][feature.rawValue].mean = current + blend * (target - current)
    }

    // MARK: - Forward Algorithm

    /// Update state probabilities with new observation using log-space forward algorithm.
    /// All intermediate computations use log probabilities to avoid numerical underflow.
    public func update(with features: GaitFeatureVector) {
        let numStates = HMMGaitState.allCases.count

        // Compute log emission probabilities (stay in log-space)
        var logEmission = [Double](repeating: 0, count: numStates)
        for state in HMMGaitState.allCases {
            logEmission[state.rawValue] = computeLogEmissionProbability(features, for: state)
        }

        // Convert current stateProbs to log-space
        let logStateProbs = stateProbs.map { $0 > 0 ? log($0) : -1000.0 }

        // Forward step in log-space:
        // log(alpha(t, j)) = logSumExp_i(log(alpha(t-1, i)) + log(A(i,j))) + log(B(j, obs))
        var logNewProbs = [Double](repeating: -Double.infinity, count: numStates)

        for toState in HMMGaitState.allCases {
            var terms = [Double]()
            for fromState in HMMGaitState.allCases {
                let transProb = transitionMatrix[fromState.rawValue][toState.rawValue]
                if transProb > 0 {
                    terms.append(logStateProbs[fromState.rawValue] + log(transProb))
                }
            }
            if !terms.isEmpty {
                logNewProbs[toState.rawValue] = logSumExp(terms) + logEmission[toState.rawValue]
            }
        }

        // Normalize in log-space: P(i) = exp(logP(i) - logTotal)
        let logTotal = logSumExp(Array(logNewProbs))

        if logTotal > -500 {
            var newProbs = [Double](repeating: 0, count: numStates)
            for i in 0..<numStates {
                newProbs[i] = exp(logNewProbs[i] - logTotal)
            }
            stateProbs = newProbs
        }
        // else: keep previous stateProbs (total underflow = all states equally unlikely)
    }

    /// Log-sum-exp trick: log(sum(exp(x_i))) = max(x) + log(sum(exp(x_i - max(x))))
    /// Avoids overflow/underflow by factoring out the maximum value.
    private func logSumExp(_ values: [Double]) -> Double {
        guard let maxVal = values.max(), maxVal > -Double.infinity else { return -Double.infinity }
        let sum = values.reduce(0.0) { $0 + exp($1 - maxVal) }
        return maxVal + log(sum)
    }

    /// Get probability of a specific state
    public func probability(of state: HMMGaitState) -> Double {
        return stateProbs[state.rawValue]
    }

    // MARK: - Private Implementation

    /// Compute log emission probability for a state given observed features.
    /// Returns the sum of log-Gaussian probabilities across all features.
    /// Watch features use age-modulated variance: stale/missing Watch data (age=999) inflates
    /// variance ~250000x, making the Gaussian flat and the feature uninformative.
    private func computeLogEmissionProbability(_ features: GaitFeatureVector, for state: HMMGaitState) -> Double {
        let stateIdx = state.rawValue
        let params = emissionParams[stateIdx]

        var logProb = 0.0

        logProb += params[FeatureIndex.strideFrequency.rawValue].logProbability(features.strideFrequency)
        logProb += params[FeatureIndex.h2Ratio.rawValue].logProbability(features.h2Ratio)
        logProb += params[FeatureIndex.h3Ratio.rawValue].logProbability(features.h3Ratio)
        logProb += params[FeatureIndex.spectralEntropy.rawValue].logProbability(features.spectralEntropy)
        logProb += params[FeatureIndex.xyCoherence.rawValue].logProbability(features.xyCoherence)
        logProb += params[FeatureIndex.zYawCoherence.rawValue].logProbability(features.zYawCoherence)
        logProb += params[FeatureIndex.normalizedVerticalRMS.rawValue].logProbability(features.normalizedVerticalRMS)
        logProb += params[FeatureIndex.yawRateRMS.rawValue].logProbability(features.yawRateRMS)

        // Watch features: age-modulated variance makes stale data uninformative
        let watchAgeFactor = max(1.0, features.watchDataAge / 2.0)
        let watchVarianceScale = watchAgeFactor * watchAgeFactor

        let voParam = params[FeatureIndex.watchVerticalOscillation.rawValue]
        let voScaled = GaussianEmission(mean: voParam.mean, variance: voParam.variance * watchVarianceScale)
        logProb += voScaled.logProbability(features.watchVerticalOscillation)

        let miParam = params[FeatureIndex.watchMovementIntensity.rawValue]
        let miScaled = GaussianEmission(mean: miParam.mean, variance: miParam.variance * watchVarianceScale)
        logProb += miScaled.logProbability(features.watchMovementIntensity)

        // GPS speed: accuracy-modulated variance makes poor GPS uninformative
        let gpsEmission = params[FeatureIndex.gpsSpeed.rawValue]
        let accuracyFactor = max(1.0, features.gpsAccuracy / 5.0)
        let adjustedVariance = gpsEmission.variance * accuracyFactor * accuracyFactor
        let adjustedGPS = GaussianEmission(mean: gpsEmission.mean, variance: adjustedVariance)
        logProb += adjustedGPS.logProbability(features.gpsSpeed)

        if state == .canter && canterMultiplier != 1.0 {
            logProb += log(canterMultiplier)
        }

        return logProb
    }

    private static func defaultTransitionMatrix() -> [[Double]] {
        let selfProb = 0.85
        let transProb = 0.15

        return [
            [selfProb, transProb, 0, 0, 0],
            [transProb/2, selfProb, transProb/2, 0, 0],
            [0, transProb/2, selfProb, transProb/2, 0],
            [0, 0, transProb/2, selfProb, transProb/2],
            [0, 0, 0, transProb, selfProb]
        ]
    }

    private static func defaultEmissionParams(numFeatures: Int) -> [[GaussianEmission]] {
        let gps = defaultGPSSpeedRanges
        return [
            // Stationary
            createEmissions(f0: 0...0.5, h2: 0...0.3, h3: 0...0.3, entropy: 0...0.3, xyC: 0...0.3, zYawC: 0...0.3, rms: 0...0.05, yaw: 0...0.1, watchVO: 0...1.0, watchMI: 0...10.0, gps: gps[0]),
            // Walk
            createEmissions(f0: 1.0...2.2, h2: 0.3...0.7, h3: 0.2...0.5, entropy: 0.2...0.5, xyC: 0.2...0.5, zYawC: 0.2...0.4, rms: 0.03...0.12, yaw: 0.05...0.20, watchVO: 2.0...4.5, watchMI: 10.0...35.0, gps: gps[1]),
            // Trot
            createEmissions(f0: 2.0...3.8, h2: 1.2...2.5, h3: 0.3...0.8, entropy: 0.3...0.6, xyC: 0.7...1.0, zYawC: 0.1...0.4, rms: 0.12...0.28, yaw: 0.20...0.45, watchVO: 4.5...10.0, watchMI: 30.0...65.0, gps: gps[2]),
            // Canter
            createEmissions(f0: 1.8...3.0, h2: 0.4...1.0, h3: 1.0...2.0, entropy: 0.4...0.7, xyC: 0.2...0.5, zYawC: 0.6...0.9, rms: 0.28...0.50, yaw: 0.40...0.80, watchVO: 3.5...7.5, watchMI: 45.0...80.0, gps: gps[3]),
            // Gallop
            createEmissions(f0: 3.0...6.0, h2: 0.2...0.8, h3: 0.3...0.9, entropy: 0.6...0.9, xyC: 0.1...0.4, zYawC: 0.7...1.0, rms: 0.40...0.70, yaw: 0.60...1.20, watchVO: 5.0...12.0, watchMI: 65.0...100.0, gps: gps[4])
        ]
    }

    private static func wristEmissionParams(numFeatures: Int) -> [[GaussianEmission]] {
        // Wrist-tuned parameters: h2/h3 ~0.5x, RMS ~0.6x, entropy +0.1, coherence widened, noise floor raised
        // Watch VO/MI ranges same as trunk — these come from the Watch itself regardless of iPhone mount
        // GPS speed ranges same as trunk — GPS is independent of phone mount position
        let gps = defaultGPSSpeedRanges
        return [
            // Stationary — raised noise floor for wrist movement artifacts
            createEmissions(f0: 0...0.5, h2: 0...0.3, h3: 0...0.3, entropy: 0.1...0.5, xyC: 0...0.3, zYawC: 0...0.3, rms: 0...0.08, yaw: 0...0.15, watchVO: 0...1.0, watchMI: 0...10.0, gps: gps[0]),
            // Walk — attenuated harmonics, lower RMS
            createEmissions(f0: 1.0...2.2, h2: 0.2...0.5, h3: 0.1...0.4, entropy: 0.3...0.6, xyC: 0.15...0.45, zYawC: 0.15...0.35, rms: 0.02...0.10, yaw: 0.04...0.18, watchVO: 2.0...4.5, watchMI: 10.0...35.0, gps: gps[1]),
            // Trot — harmonics heavily attenuated through arm chain
            createEmissions(f0: 2.0...3.8, h2: 0.6...1.5, h3: 0.2...0.6, entropy: 0.4...0.7, xyC: 0.3...0.9, zYawC: 0.1...0.35, rms: 0.06...0.18, yaw: 0.15...0.38, watchVO: 4.5...10.0, watchMI: 30.0...65.0, gps: gps[2]),
            // Canter — asymmetric gait, yaw dominates at wrist
            createEmissions(f0: 1.8...3.0, h2: 0.3...0.8, h3: 0.5...1.2, entropy: 0.5...0.8, xyC: 0.15...0.45, zYawC: 0.4...0.8, rms: 0.15...0.35, yaw: 0.30...0.65, watchVO: 3.5...7.5, watchMI: 45.0...80.0, gps: gps[3]),
            // Gallop — high entropy, strong yaw, attenuated bounce
            createEmissions(f0: 3.0...6.0, h2: 0.15...0.6, h3: 0.2...0.7, entropy: 0.7...0.95, xyC: 0.1...0.35, zYawC: 0.5...0.9, rms: 0.20...0.45, yaw: 0.45...0.95, watchVO: 5.0...12.0, watchMI: 65.0...100.0, gps: gps[4])
        ]
    }

    /// Apply wrist scaling to breed-configured (trunk-derived) emission params
    private static func applyWristScaling(_ params: [[GaussianEmission]]) -> [[GaussianEmission]] {
        // Scale factors: h2 0.5x, h3 0.5x, entropy +0.1 offset, xyCoherence widened, rms 0.65x
        params.enumerated().map { stateIdx, stateParams in
            stateParams.enumerated().map { featureIdx, emission in
                guard let feature = FeatureIndex(rawValue: featureIdx) else { return emission }
                var scaled = emission
                switch feature {
                case .h2Ratio:
                    scaled.mean *= 0.5
                    scaled.variance *= 0.25  // variance scales as square of mean scale
                case .h3Ratio:
                    scaled.mean *= 0.5
                    scaled.variance *= 0.25
                case .spectralEntropy:
                    scaled.mean = min(scaled.mean + 0.1, 0.95)
                case .normalizedVerticalRMS:
                    scaled.mean *= 0.65
                    scaled.variance *= 0.42  // 0.65^2
                case .yawRateRMS:
                    scaled.mean *= 0.8
                    scaled.variance *= 0.64  // 0.8^2
                default:
                    break
                }
                return scaled
            }
        }
    }

    private static func createEmissions(
        f0: ClosedRange<Double>,
        h2: ClosedRange<Double>,
        h3: ClosedRange<Double>,
        entropy: ClosedRange<Double>,
        xyC: ClosedRange<Double>,
        zYawC: ClosedRange<Double>,
        rms: ClosedRange<Double>,
        yaw: ClosedRange<Double>,
        watchVO: ClosedRange<Double> = 0...1.0,
        watchMI: ClosedRange<Double> = 0...10.0,
        gps: ClosedRange<Double> = 0...20.0
    ) -> [GaussianEmission] {
        func toGaussian(_ range: ClosedRange<Double>) -> GaussianEmission {
            let mean = (range.lowerBound + range.upperBound) / 2
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
            toGaussian(watchVO),
            toGaussian(watchMI),
            toGaussian(gps)
        ]
    }

    // MARK: - Diagnostic Methods (DEBUG)

    #if DEBUG
    /// Get all state probabilities as a dictionary for logging
    public func getAllStateProbabilities() -> [String: Double] {
        var result: [String: Double] = [:]
        for state in HMMGaitState.allCases {
            result[state.name] = stateProbs[state.rawValue]
        }
        return result
    }

    /// Get individual emission probabilities for each feature
    public func getEmissionBreakdown(_ features: GaitFeatureVector, for state: HMMGaitState) -> [String: Double] {
        let stateIdx = state.rawValue
        let params = emissionParams[stateIdx]

        let watchAgeFactor = max(1.0, features.watchDataAge / 2.0)
        let watchVarianceScale = watchAgeFactor * watchAgeFactor

        let voParam = params[FeatureIndex.watchVerticalOscillation.rawValue]
        let voScaled = GaussianEmission(mean: voParam.mean, variance: voParam.variance * watchVarianceScale)

        let miParam = params[FeatureIndex.watchMovementIntensity.rawValue]
        let miScaled = GaussianEmission(mean: miParam.mean, variance: miParam.variance * watchVarianceScale)

        let gpsParam = params[FeatureIndex.gpsSpeed.rawValue]
        let gpsFactor = max(1.0, features.gpsAccuracy / 5.0)
        let gpsScaled = GaussianEmission(mean: gpsParam.mean, variance: gpsParam.variance * gpsFactor * gpsFactor)

        return [
            "strideFrequency": params[FeatureIndex.strideFrequency.rawValue].probability(features.strideFrequency),
            "h2Ratio": params[FeatureIndex.h2Ratio.rawValue].probability(features.h2Ratio),
            "h3Ratio": params[FeatureIndex.h3Ratio.rawValue].probability(features.h3Ratio),
            "spectralEntropy": params[FeatureIndex.spectralEntropy.rawValue].probability(features.spectralEntropy),
            "xyCoherence": params[FeatureIndex.xyCoherence.rawValue].probability(features.xyCoherence),
            "zYawCoherence": params[FeatureIndex.zYawCoherence.rawValue].probability(features.zYawCoherence),
            "normalizedVerticalRMS": params[FeatureIndex.normalizedVerticalRMS.rawValue].probability(features.normalizedVerticalRMS),
            "yawRateRMS": params[FeatureIndex.yawRateRMS.rawValue].probability(features.yawRateRMS),
            "watchVerticalOscillation": voScaled.probability(features.watchVerticalOscillation),
            "watchMovementIntensity": miScaled.probability(features.watchMovementIntensity),
            "gpsSpeed": gpsScaled.probability(features.gpsSpeed)
        ]
    }

    /// Simulate transition dynamics
    public func simulateTransitionDynamics(
        from: HMMGaitState,
        to: HMMGaitState,
        favoringFeatures: GaitFeatureVector,
        maxSteps: Int = 100,
        updateRateHz: Double = 4.0
    ) -> TransitionDynamicsResult {
        let savedProbs = stateProbs

        stateProbs = [Double](repeating: 0, count: HMMGaitState.allCases.count)
        stateProbs[from.rawValue] = 1.0

        var probabilityHistory: [Double] = [stateProbs[to.rawValue]]
        var stepsToTransition = -1

        for step in 1...maxSteps {
            update(with: favoringFeatures)
            probabilityHistory.append(stateProbs[to.rawValue])

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

        stateProbs = savedProbs

        return result
    }

    /// Get the transition probability from one state to another
    public func getTransitionProbability(from: HMMGaitState, to: HMMGaitState) -> Double {
        return transitionMatrix[from.rawValue][to.rawValue]
    }

    /// Log emission probability comparison between canter and gallop
    public func logCanterGallopComparison(_ features: GaitFeatureVector) {
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

        logger.debug("\(comparison)")
    }
    #endif
}
