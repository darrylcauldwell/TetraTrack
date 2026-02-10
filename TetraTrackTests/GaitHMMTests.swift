//
//  GaitHMMTests.swift
//  TetraTrackTests
//
//  Tests for GaitHMM hidden Markov model gait classification
//

import Testing
import Foundation
@testable import TetraTrack

struct GaitHMMTests {

    // MARK: - GaussianEmission Tests

    @Test func gaussianEmissionPeaksAtMean() {
        let emission = GaussianEmission(mean: 2.0, variance: 0.25)
        let atMean = emission.probability(2.0)
        let awayFromMean = emission.probability(3.0)
        #expect(atMean > awayFromMean)
    }

    @Test func gaussianEmissionDecreasesWithDistance() {
        let emission = GaussianEmission(mean: 2.0, variance: 0.25)
        let close = emission.probability(2.2)
        let far = emission.probability(3.0)
        let veryFar = emission.probability(5.0)
        #expect(close > far)
        #expect(far > veryFar)
    }

    @Test func gaussianLogProbabilityMatchesLog() {
        let emission = GaussianEmission(mean: 2.0, variance: 0.25)
        let value = 2.5
        let prob = emission.probability(value)
        let logProb = emission.logProbability(value)
        #expect(abs(log(prob) - logProb) < 1e-10)
    }

    @Test func gaussianZeroVarianceEdgeCase() {
        let emission = GaussianEmission(mean: 2.0, variance: 0.0)
        let atMean = emission.probability(2.0)
        let notAtMean = emission.probability(2.1)
        #expect(atMean == 1.0)
        #expect(notAtMean == 0.0)
    }

    @Test func gaussianLargeValuesDoNotCrash() {
        let emission = GaussianEmission(mean: 0.0, variance: 1.0)
        let _ = emission.probability(100.0)
        let _ = emission.logProbability(100.0)
        let _ = emission.probability(-100.0)
        let _ = emission.logProbability(-100.0)
    }

    // MARK: - HMM Initialization & Reset Tests

    @Test func initialStateIsStationary() {
        let hmm = GaitHMM()
        #expect(hmm.currentState == .stationary)
        #expect(hmm.probability(of: .stationary) == 1.0)
    }

    @Test func resetReturnsToStationary() {
        let hmm = GaitHMM()
        // Move away from stationary
        for _ in 0..<20 {
            hmm.update(with: walkFeatures())
        }
        #expect(hmm.currentState != .stationary)

        hmm.reset()
        #expect(hmm.currentState == .stationary)
        #expect(hmm.probability(of: .stationary) == 1.0)
    }

    @Test func stateProbabilitiesSumToOne() {
        let hmm = GaitHMM()
        // Feed some data to get a non-trivial distribution
        for _ in 0..<5 {
            hmm.update(with: trotFeatures())
        }
        let sum = HMMGaitState.allCases.reduce(0.0) { $0 + hmm.probability(of: $1) }
        #expect(abs(sum - 1.0) < 1e-10)
    }

    // MARK: - Core Feature Vector Classification Tests

    @Test func classifiesStationaryCorrectly() {
        let hmm = GaitHMM()
        for _ in 0..<20 {
            hmm.update(with: stationaryFeatures())
        }
        #expect(hmm.currentState == .stationary)
    }

    @Test func classifiesWalkCorrectly() {
        let hmm = GaitHMM()
        for _ in 0..<20 {
            hmm.update(with: walkFeatures())
        }
        #expect(hmm.currentState == .walk)
    }

    @Test func classifiesTrotCorrectly() {
        let hmm = GaitHMM()
        for _ in 0..<20 {
            hmm.update(with: trotFeatures())
        }
        #expect(hmm.currentState == .trot)
    }

    @Test func classifiesCanterCorrectly() {
        let hmm = GaitHMM()
        for _ in 0..<20 {
            hmm.update(with: canterFeatures())
        }
        #expect(hmm.currentState == .canter)
    }

    @Test func classifiesGallopCorrectly() {
        let hmm = GaitHMM()
        for _ in 0..<20 {
            hmm.update(with: gallopFeatures())
        }
        #expect(hmm.currentState == .gallop)
    }

    // MARK: - Transition Dynamics Tests

    @Test func transitionStationaryToWalk() {
        let hmm = GaitHMM()
        // Start from stationary (default)
        for _ in 0..<10 {
            hmm.update(with: walkFeatures())
        }
        #expect(hmm.currentState == .walk)
    }

    @Test func transitionWalkToTrot() {
        let hmm = GaitHMM()
        // Establish walk
        for _ in 0..<15 {
            hmm.update(with: walkFeatures())
        }
        #expect(hmm.currentState == .walk)

        // Transition to trot
        for _ in 0..<15 {
            hmm.update(with: trotFeatures())
        }
        #expect(hmm.currentState == .trot)
    }

    @Test func transitionTrotToCanter() {
        let hmm = GaitHMM()
        // Establish trot (go through walk first)
        for _ in 0..<10 {
            hmm.update(with: walkFeatures())
        }
        for _ in 0..<15 {
            hmm.update(with: trotFeatures())
        }
        #expect(hmm.currentState == .trot)

        // Transition to canter
        for _ in 0..<15 {
            hmm.update(with: canterFeatures())
        }
        #expect(hmm.currentState == .canter)
    }

    @Test func transitionCanterToGallop() {
        let hmm = GaitHMM()
        // Build up through gaits
        for _ in 0..<10 { hmm.update(with: walkFeatures()) }
        for _ in 0..<10 { hmm.update(with: trotFeatures()) }
        for _ in 0..<15 { hmm.update(with: canterFeatures()) }
        #expect(hmm.currentState == .canter)

        // Transition to gallop
        for _ in 0..<15 {
            hmm.update(with: gallopFeatures())
        }
        #expect(hmm.currentState == .gallop)
    }

    @Test func reverseTransitionGallopToStationary() {
        let hmm = GaitHMM()
        // Build up to gallop
        for _ in 0..<10 { hmm.update(with: walkFeatures()) }
        for _ in 0..<10 { hmm.update(with: trotFeatures()) }
        for _ in 0..<10 { hmm.update(with: canterFeatures()) }
        for _ in 0..<15 { hmm.update(with: gallopFeatures()) }
        #expect(hmm.currentState == .gallop)

        // Come back down
        for _ in 0..<15 { hmm.update(with: canterFeatures()) }
        #expect(hmm.currentState == .canter)
        for _ in 0..<15 { hmm.update(with: trotFeatures()) }
        #expect(hmm.currentState == .trot)
        for _ in 0..<15 { hmm.update(with: walkFeatures()) }
        #expect(hmm.currentState == .walk)
        for _ in 0..<15 { hmm.update(with: stationaryFeatures()) }
        #expect(hmm.currentState == .stationary)
    }

    @Test func nonAdjacentTransitionRequiresIntermediateStates() {
        let hmm = GaitHMM()
        // From stationary, feed trot features
        // Due to transition constraints, must pass through walk first
        // After a few updates the HMM should not jump directly to trot
        hmm.update(with: trotFeatures())
        hmm.update(with: trotFeatures())
        // After only 2 updates, should not yet be in trot (must pass through walk)
        #expect(hmm.currentState != .trot)
    }

    // MARK: - GPS Speed Constraint Tests

    @Test func highConfidenceGPSPenalisesWrongGait() {
        let hmm = GaitHMM()
        // Feed walk features but with GPS speed 0 (stationary) and high accuracy
        let features = GaitFeatureVector(
            strideFrequency: 1.6, h2Ratio: 0.5, h3Ratio: 0.35,
            spectralEntropy: 0.35, xyCoherence: 0.35, zYawCoherence: 0.3,
            normalizedVerticalRMS: 0.10, yawRateRMS: 0.2,
            gpsSpeed: 0.0, gpsAccuracy: 3.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        for _ in 0..<20 {
            hmm.update(with: features)
        }
        // High-accuracy GPS says speed=0, should stay stationary despite walk features
        #expect(hmm.currentState == .stationary)
    }

    @Test func lowConfidenceGPSBarelyConstrains() {
        let hmm = GaitHMM()
        // Feed walk features with GPS speed 0 but very poor accuracy (50m+)
        let features = GaitFeatureVector(
            strideFrequency: 1.6, h2Ratio: 0.5, h3Ratio: 0.35,
            spectralEntropy: 0.35, xyCoherence: 0.35, zYawCoherence: 0.3,
            normalizedVerticalRMS: 0.10, yawRateRMS: 0.2,
            gpsSpeed: 0.0, gpsAccuracy: 60.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        for _ in 0..<20 {
            hmm.update(with: features)
        }
        // Low-accuracy GPS should barely constrain, walk features should win
        #expect(hmm.currentState == .walk)
    }

    @Test func zeroSpeedHighAccuracyForcesStationary() {
        let hmm = GaitHMM()
        for _ in 0..<10 { hmm.update(with: walkFeatures()) }
        #expect(hmm.currentState == .walk)

        // Now feed stationary speed with high accuracy
        let stationaryWithGPS = GaitFeatureVector(
            strideFrequency: 0.2, h2Ratio: 0.15, h3Ratio: 0.15,
            spectralEntropy: 0.15, xyCoherence: 0.15, zYawCoherence: 0.15,
            normalizedVerticalRMS: 0.02, yawRateRMS: 0.05,
            gpsSpeed: 0.0, gpsAccuracy: 3.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        for _ in 0..<15 {
            hmm.update(with: stationaryWithGPS)
        }
        #expect(hmm.currentState == .stationary)
    }

    @Test func highSpeedPreventsSlowGaits() {
        let hmm = GaitHMM()
        // Feed features with GPS speed 10 m/s (gallop territory) and high accuracy
        let features = GaitFeatureVector(
            strideFrequency: 4.5, h2Ratio: 0.5, h3Ratio: 0.6,
            spectralEntropy: 0.75, xyCoherence: 0.25, zYawCoherence: 0.85,
            normalizedVerticalRMS: 0.475, yawRateRMS: 0.9,
            gpsSpeed: 10.0, gpsAccuracy: 3.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        for _ in 0..<20 {
            hmm.update(with: features)
        }
        // At 10 m/s with high accuracy, should not be stationary, walk, or trot
        let state = hmm.currentState
        #expect(state == .canter || state == .gallop)
    }

    @Test func speedConstraintsPreserveNormalization() {
        let hmm = GaitHMM()
        let features = GaitFeatureVector(
            strideFrequency: 2.9, h2Ratio: 1.85, h3Ratio: 0.55,
            spectralEntropy: 0.45, xyCoherence: 0.85, zYawCoherence: 0.25,
            normalizedVerticalRMS: 0.25, yawRateRMS: 0.35,
            gpsSpeed: 3.0, gpsAccuracy: 5.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        hmm.update(with: features)
        let sum = HMMGaitState.allCases.reduce(0.0) { $0 + hmm.probability(of: $1) }
        #expect(abs(sum - 1.0) < 1e-10)
    }

    // MARK: - Breed Configuration Tests

    @Test func ponyHasHigherFrequencyRanges() {
        let defaultHMM = GaitHMM()
        let ponyHMM = GaitHMM()
        ponyHMM.configure(for: .shetland)

        // Shetland pony walk frequency range is 1.3-2.5 (higher than default 1.0-2.2)
        // Feed features at f0=2.4 which is within pony range but near edge of default
        let highFreqWalk = GaitFeatureVector(
            strideFrequency: 2.4, h2Ratio: 0.5, h3Ratio: 0.35,
            spectralEntropy: 0.35, xyCoherence: 0.35, zYawCoherence: 0.3,
            normalizedVerticalRMS: 0.10, yawRateRMS: 0.2,
            gpsSpeed: 1.5, gpsAccuracy: 10.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )

        for _ in 0..<20 {
            ponyHMM.update(with: highFreqWalk)
            defaultHMM.update(with: highFreqWalk)
        }

        // Pony HMM should be more comfortable with higher walk frequency
        #expect(ponyHMM.probability(of: .walk) >= defaultHMM.probability(of: .walk))
    }

    @Test func warmbloodHasLowerFrequencyRanges() {
        let defaultHMM = GaitHMM()
        let warmbloodHMM = GaitHMM()
        warmbloodHMM.configure(for: .warmblood)

        // Warmblood trot frequency range is 1.8-3.5 (lower than default 2.0-3.8)
        // Feed features at f0=1.9 which is within warmblood range but near edge of default
        let lowFreqTrot = GaitFeatureVector(
            strideFrequency: 1.9, h2Ratio: 1.85, h3Ratio: 0.55,
            spectralEntropy: 0.45, xyCoherence: 0.85, zYawCoherence: 0.25,
            normalizedVerticalRMS: 0.25, yawRateRMS: 0.35,
            gpsSpeed: 3.0, gpsAccuracy: 10.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )

        for _ in 0..<20 {
            warmbloodHMM.update(with: lowFreqTrot)
            defaultHMM.update(with: lowFreqTrot)
        }

        // Warmblood should be more comfortable with lower trot frequency
        #expect(warmbloodHMM.probability(of: .trot) >= defaultHMM.probability(of: .trot))
    }

    @Test func ageAdjustmentWidensRanges() {
        let normalHMM = GaitHMM()
        normalHMM.configure(for: .thoroughbred, ageAdjustment: 1.0)

        let youngHorseHMM = GaitHMM()
        youngHorseHMM.configure(for: .thoroughbred, ageAdjustment: 1.15)

        // Feed features at edge of normal range
        let edgeFeatures = GaitFeatureVector(
            strideFrequency: 0.8, h2Ratio: 0.5, h3Ratio: 0.35,
            spectralEntropy: 0.35, xyCoherence: 0.35, zYawCoherence: 0.3,
            normalizedVerticalRMS: 0.10, yawRateRMS: 0.2,
            gpsSpeed: 1.5, gpsAccuracy: 10.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )

        for _ in 0..<20 {
            normalHMM.update(with: edgeFeatures)
            youngHorseHMM.update(with: edgeFeatures)
        }

        // Young horse with wider ranges should assign higher walk probability at edge
        #expect(youngHorseHMM.probability(of: .walk) >= normalHMM.probability(of: .walk))
    }

    @Test func customTransitionProbabilityChangesSelfTransition() {
        let defaultHMM = GaitHMM()
        let customHMM = GaitHMM()
        customHMM.configure(for: .thoroughbred, transitionProbability: 0.95)

        // Both start stationary, feed walk features
        for _ in 0..<5 {
            defaultHMM.update(with: walkFeatures())
            customHMM.update(with: walkFeatures())
        }

        // Higher self-transition (0.95 vs 0.85) means slower to leave stationary
        // After 5 updates, default should have moved more toward walk
        #expect(defaultHMM.probability(of: .walk) > customHMM.probability(of: .walk))
    }

    // MARK: - Learned Parameter Blending Tests

    @Test func fewerThanThreeRidesNoBlending() {
        let hmm = GaitHMM()
        let learned = LearnedGaitParameters(
            walkFrequencyCenter: 5.0,  // Extreme value that would shift mean a lot
            rideCount: 2
        )
        hmm.applyLearnedParameters(learned)

        // Should still classify walk normally since blending was not applied
        for _ in 0..<20 {
            hmm.update(with: walkFeatures())
        }
        #expect(hmm.currentState == .walk)
    }

    @Test func threeRidesAppliesMinimalBlending() {
        let hmm1 = GaitHMM()
        let hmm2 = GaitHMM()

        let learned = LearnedGaitParameters(
            walkFrequencyCenter: 2.0,  // Shift walk center up
            rideCount: 3
        )
        hmm2.applyLearnedParameters(learned)

        // Feed features near the shifted center
        let features = GaitFeatureVector(
            strideFrequency: 2.0, h2Ratio: 0.5, h3Ratio: 0.35,
            spectralEntropy: 0.35, xyCoherence: 0.35, zYawCoherence: 0.3,
            normalizedVerticalRMS: 0.10, yawRateRMS: 0.2,
            gpsSpeed: 1.5, gpsAccuracy: 10.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        for _ in 0..<20 {
            hmm1.update(with: features)
            hmm2.update(with: features)
        }

        // hmm2 with blended params should assign slightly higher walk probability at f0=2.0
        #expect(hmm2.probability(of: .walk) >= hmm1.probability(of: .walk))
    }

    @Test func tenRidesAppliesStrongerBlending() {
        let hmm3 = GaitHMM()
        let hmm10 = GaitHMM()

        let learned3 = LearnedGaitParameters(walkFrequencyCenter: 2.0, rideCount: 3)
        let learned10 = LearnedGaitParameters(walkFrequencyCenter: 2.0, rideCount: 10)
        hmm3.applyLearnedParameters(learned3)
        hmm10.applyLearnedParameters(learned10)

        let features = GaitFeatureVector(
            strideFrequency: 2.0, h2Ratio: 0.5, h3Ratio: 0.35,
            spectralEntropy: 0.35, xyCoherence: 0.35, zYawCoherence: 0.3,
            normalizedVerticalRMS: 0.10, yawRateRMS: 0.2,
            gpsSpeed: 1.5, gpsAccuracy: 10.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        for _ in 0..<20 {
            hmm3.update(with: features)
            hmm10.update(with: features)
        }

        // 10 rides (blend=0.5) should shift more than 3 rides (blend=0.15)
        #expect(hmm10.probability(of: .walk) >= hmm3.probability(of: .walk))
    }

    @Test func blendingCapsAtFiftyPercent() {
        let hmm20 = GaitHMM()
        let hmm100 = GaitHMM()

        // Both should cap at blend=0.5
        let learned20 = LearnedGaitParameters(walkFrequencyCenter: 2.0, rideCount: 20)
        let learned100 = LearnedGaitParameters(walkFrequencyCenter: 2.0, rideCount: 100)
        hmm20.applyLearnedParameters(learned20)
        hmm100.applyLearnedParameters(learned100)

        let features = GaitFeatureVector(
            strideFrequency: 2.0, h2Ratio: 0.5, h3Ratio: 0.35,
            spectralEntropy: 0.35, xyCoherence: 0.35, zYawCoherence: 0.3,
            normalizedVerticalRMS: 0.10, yawRateRMS: 0.2,
            gpsSpeed: 1.5, gpsAccuracy: 10.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        for _ in 0..<20 {
            hmm20.update(with: features)
            hmm100.update(with: features)
        }

        // Both capped at 0.5 blend, should produce nearly identical results
        let diff = abs(hmm20.probability(of: .walk) - hmm100.probability(of: .walk))
        #expect(diff < 0.01)
    }

    // MARK: - Edge Case Tests

    @Test func allZeroFeatureVectorDoesNotCrash() {
        let hmm = GaitHMM()
        hmm.update(with: .zero)
        let sum = HMMGaitState.allCases.reduce(0.0) { $0 + hmm.probability(of: $1) }
        #expect(abs(sum - 1.0) < 1e-10)
    }

    @Test func extremeValuesDoNotCrash() {
        let hmm = GaitHMM()
        let extremeFeatures = GaitFeatureVector(
            strideFrequency: 100.0, h2Ratio: 50.0, h3Ratio: 50.0,
            spectralEntropy: 1.0, xyCoherence: 1.0, zYawCoherence: 1.0,
            normalizedVerticalRMS: 10.0, yawRateRMS: 10.0,
            gpsSpeed: 50.0, gpsAccuracy: 1.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        hmm.update(with: extremeFeatures)
        let sum = HMMGaitState.allCases.reduce(0.0) { $0 + hmm.probability(of: $1) }
        #expect(abs(sum - 1.0) < 1e-10)
    }

    @Test func repeatedIdenticalUpdatesMaintainStableState() {
        let hmm = GaitHMM()
        // Feed walk features until stable
        for _ in 0..<20 {
            hmm.update(with: walkFeatures())
        }
        let walkProb1 = hmm.probability(of: .walk)

        // Feed 20 more identical updates
        for _ in 0..<20 {
            hmm.update(with: walkFeatures())
        }
        let walkProb2 = hmm.probability(of: .walk)

        // Should converge and stabilize
        #expect(hmm.currentState == .walk)
        #expect(abs(walkProb1 - walkProb2) < 0.05)
    }

    // MARK: - Helpers

    private func stationaryFeatures() -> GaitFeatureVector {
        GaitFeatureVector(
            strideFrequency: 0.25, h2Ratio: 0.15, h3Ratio: 0.15,
            spectralEntropy: 0.15, xyCoherence: 0.15, zYawCoherence: 0.15,
            normalizedVerticalRMS: 0.025, yawRateRMS: 0.05,
            gpsSpeed: 0.0, gpsAccuracy: 10.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
    }

    private func walkFeatures(gpsSpeed: Double = 1.5, gpsAccuracy: Double = 10.0) -> GaitFeatureVector {
        GaitFeatureVector(
            strideFrequency: 1.6, h2Ratio: 0.5, h3Ratio: 0.35,
            spectralEntropy: 0.35, xyCoherence: 0.35, zYawCoherence: 0.3,
            normalizedVerticalRMS: 0.10, yawRateRMS: 0.2,
            gpsSpeed: gpsSpeed, gpsAccuracy: gpsAccuracy,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
    }

    private func trotFeatures(gpsSpeed: Double = 3.0, gpsAccuracy: Double = 10.0) -> GaitFeatureVector {
        GaitFeatureVector(
            strideFrequency: 2.9, h2Ratio: 1.85, h3Ratio: 0.55,
            spectralEntropy: 0.45, xyCoherence: 0.85, zYawCoherence: 0.25,
            normalizedVerticalRMS: 0.25, yawRateRMS: 0.35,
            gpsSpeed: gpsSpeed, gpsAccuracy: gpsAccuracy,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
    }

    private func canterFeatures(gpsSpeed: Double = 5.0, gpsAccuracy: Double = 10.0) -> GaitFeatureVector {
        GaitFeatureVector(
            strideFrequency: 2.4, h2Ratio: 0.7, h3Ratio: 1.5,
            spectralEntropy: 0.55, xyCoherence: 0.35, zYawCoherence: 0.75,
            normalizedVerticalRMS: 0.35, yawRateRMS: 0.6,
            gpsSpeed: gpsSpeed, gpsAccuracy: gpsAccuracy,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
    }

    private func gallopFeatures(gpsSpeed: Double = 9.0, gpsAccuracy: Double = 10.0) -> GaitFeatureVector {
        GaitFeatureVector(
            strideFrequency: 4.5, h2Ratio: 0.5, h3Ratio: 0.6,
            spectralEntropy: 0.75, xyCoherence: 0.25, zYawCoherence: 0.85,
            normalizedVerticalRMS: 0.475, yawRateRMS: 0.9,
            gpsSpeed: gpsSpeed, gpsAccuracy: gpsAccuracy,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
    }
}
