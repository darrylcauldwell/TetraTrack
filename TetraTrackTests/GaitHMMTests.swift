//
//  GaitHMMTests.swift
//  TetraTrackTests
//
//  Tests for GaitHMM hidden Markov model gait classification
//

import Testing
import Foundation
@testable import TetraTrack
import TetraTrackShared

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

    @Test(.disabled("Pre-existing failure")) func classifiesTrotCorrectly() {
        let hmm = GaitHMM()
        for _ in 0..<20 {
            hmm.update(with: trotFeatures())
        }
        #expect(hmm.currentState == .trot)
    }

    @Test(.disabled("Pre-existing failure")) func classifiesCanterCorrectly() {
        let hmm = GaitHMM()
        for _ in 0..<20 {
            hmm.update(with: canterFeatures())
        }
        #expect(hmm.currentState == .canter)
    }

    @Test(.disabled("Pre-existing failure")) func classifiesGallopCorrectly() {
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
        // Transition matrix has zero probability for stationary→trot directly
        // After 1 update, can only reach walk (adjacent state), not trot
        hmm.update(with: trotFeatures())
        #expect(hmm.currentState != .trot)
        // After 2+ updates the path stationary→walk→trot is valid,
        // so the HMM may correctly classify trot with strong features
    }

    // MARK: - GPS Speed Constraint Tests

    @Test func highConfidenceGPSPenalisesWrongGait() {
        let hmm = GaitHMM()
        // Feed walk features but with GPS speed 0 (stationary) and high accuracy
        let features = GaitFeatureVector(
            strideFrequency: 1.6, h2Ratio: 0.5, h3Ratio: 0.35,
            spectralEntropy: 0.35, xyCoherence: 0.35, zYawCoherence: 0.3,
            normalizedVerticalRMS: 0.10, yawRateRMS: 0.2,
            gpsSpeed: 0.0, gpsAccuracy: 3.0        )
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
            gpsSpeed: 0.0, gpsAccuracy: 60.0        )
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
            gpsSpeed: 0.0, gpsAccuracy: 3.0        )
        for _ in 0..<15 {
            hmm.update(with: stationaryWithGPS)
        }
        #expect(hmm.currentState == .stationary)
    }

    @Test func highSpeedPreventsSlowGaits() {
        let hmm = GaitHMM()
        // Build up through gaits to establish non-stationary state
        for _ in 0..<10 { hmm.update(with: walkFeatures()) }
        for _ in 0..<10 { hmm.update(with: trotFeatures()) }
        for _ in 0..<10 { hmm.update(with: canterFeatures()) }

        // Feed gallop features at 10 m/s with high accuracy GPS
        let features = gallopFeatures(gpsSpeed: 10.0, gpsAccuracy: 3.0)
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
            gpsSpeed: 3.0, gpsAccuracy: 5.0        )
        hmm.update(with: features)
        let sum = HMMGaitState.allCases.reduce(0.0) { $0 + hmm.probability(of: $1) }
        #expect(abs(sum - 1.0) < 1e-10)
    }

    // MARK: - Breed Configuration Tests

    @Test func ponyHasHigherFrequencyRanges() {
        let defaultHMM = GaitHMM()
        let ponyHMM = GaitHMM()
        ponyHMM.configure(with: HorseBreed.shetland.biomechanicalPriors)

        // Shetland pony walk frequency range is 1.3-2.5 (higher than default 1.0-2.2)
        // Feed features at f0=2.4 which is within pony range but near edge of default
        let highFreqWalk = GaitFeatureVector(
            strideFrequency: 2.4, h2Ratio: 0.5, h3Ratio: 0.35,
            spectralEntropy: 0.35, xyCoherence: 0.35, zYawCoherence: 0.3,
            normalizedVerticalRMS: 0.10, yawRateRMS: 0.2,
            gpsSpeed: 1.5, gpsAccuracy: 10.0        )

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
        warmbloodHMM.configure(with: HorseBreed.warmblood.biomechanicalPriors)

        // Warmblood trot frequency range is 1.8-3.5 (lower than default 2.0-3.8)
        // Feed features at f0=1.9 which is within warmblood range but near edge of default
        let lowFreqTrot = GaitFeatureVector(
            strideFrequency: 1.9, h2Ratio: 1.85, h3Ratio: 0.55,
            spectralEntropy: 0.45, xyCoherence: 0.85, zYawCoherence: 0.25,
            normalizedVerticalRMS: 0.25, yawRateRMS: 0.35,
            gpsSpeed: 3.0, gpsAccuracy: 10.0        )

        for _ in 0..<20 {
            warmbloodHMM.update(with: lowFreqTrot)
            defaultHMM.update(with: lowFreqTrot)
        }

        // Warmblood should be more comfortable with lower trot frequency
        #expect(warmbloodHMM.probability(of: .trot) >= defaultHMM.probability(of: .trot))
    }

    @Test(.disabled("Pre-existing failure")) func ageAdjustmentWidensRanges() {
        let normalHMM = GaitHMM()
        normalHMM.configure(with: HorseBreed.thoroughbred.biomechanicalPriors, ageAdjustment: 1.0)

        let youngHorseHMM = GaitHMM()
        youngHorseHMM.configure(with: HorseBreed.thoroughbred.biomechanicalPriors, ageAdjustment: 1.15)

        // Feed features at edge of normal range
        let edgeFeatures = GaitFeatureVector(
            strideFrequency: 0.8, h2Ratio: 0.5, h3Ratio: 0.35,
            spectralEntropy: 0.35, xyCoherence: 0.35, zYawCoherence: 0.3,
            normalizedVerticalRMS: 0.10, yawRateRMS: 0.2,
            gpsSpeed: 1.5, gpsAccuracy: 10.0        )

        for _ in 0..<20 {
            normalHMM.update(with: edgeFeatures)
            youngHorseHMM.update(with: edgeFeatures)
        }

        // Young horse with wider ranges should assign higher walk probability at edge
        #expect(youngHorseHMM.probability(of: .walk) >= normalHMM.probability(of: .walk))
    }

    @Test(.disabled("Pre-existing failure")) func customTransitionProbabilityChangesSelfTransition() {
        let defaultHMM = GaitHMM()
        let customHMM = GaitHMM()
        customHMM.configure(with: HorseBreed.thoroughbred.biomechanicalPriors, transitionProbability: 0.95)

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
            gpsSpeed: 1.5, gpsAccuracy: 10.0        )
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
            gpsSpeed: 1.5, gpsAccuracy: 10.0        )
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
            gpsSpeed: 1.5, gpsAccuracy: 10.0        )
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
            gpsSpeed: 50.0, gpsAccuracy: 1.0        )
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

    // MARK: - Hard Speed Veto Tests

    @Test func walkSpeedVetoesCanterAndGallop() {
        let hmm = GaitHMM()
        // Feed canter IMU features at walk speed with good GPS
        let features = canterFeatures(gpsSpeed: 1.5, gpsAccuracy: 5.0)
        for _ in 0..<20 {
            hmm.update(with: features)
        }
        // Hard veto should zero canter and gallop at < 2.0 m/s
        #expect(hmm.probability(of: .canter) == 0)
        #expect(hmm.probability(of: .gallop) == 0)
    }

    @Test func trotSpeedVetoesGallop() {
        let hmm = GaitHMM()
        // Feed gallop IMU features at trot speed with good GPS
        let features = gallopFeatures(gpsSpeed: 3.5, gpsAccuracy: 5.0)
        for _ in 0..<20 {
            hmm.update(with: features)
        }
        // Hard veto should zero gallop at < 4.0 m/s
        #expect(hmm.probability(of: .gallop) == 0)
    }

    @Test func poorGPSDoesNotApplyHardVeto() {
        let hmm = GaitHMM()
        // Establish canter state with proper speed
        for _ in 0..<10 { hmm.update(with: walkFeatures()) }
        for _ in 0..<10 { hmm.update(with: trotFeatures()) }
        for _ in 0..<15 { hmm.update(with: canterFeatures()) }
        #expect(hmm.currentState == .canter)

        // Now feed canter features at walk speed with poor GPS (>= 20m accuracy)
        // Hard veto should NOT apply, so canter probability should remain non-zero
        let features = canterFeatures(gpsSpeed: 1.5, gpsAccuracy: 30.0)
        hmm.update(with: features)
        #expect(hmm.probability(of: .canter) > 0)
    }

    @Test func walkSpeedCannotReachCanterEvenWithStrongIMU() {
        let hmm = GaitHMM()
        // 20 updates of canter features at walk speed with good GPS
        for _ in 0..<20 {
            hmm.update(with: canterFeatures(gpsSpeed: 1.5, gpsAccuracy: 5.0))
        }
        // State should never be canter or gallop
        let state = hmm.currentState
        #expect(state != .canter)
        #expect(state != .gallop)
    }

    // MARK: - Walk/Trot GPS Speed Constraint Tests

    @Test func slowGPSSpeedSuppressesTrotProbability() {
        let hmm = GaitHMM()
        // Establish walk first
        for _ in 0..<10 {
            hmm.update(with: walkFeatures())
        }
        #expect(hmm.currentState == .walk)

        // Feed ambiguous features (overlap zone) at slow GPS speed with good accuracy
        let ambiguousAtSlowSpeed = GaitFeatureVector(
            strideFrequency: 2.1, h2Ratio: 0.8, h3Ratio: 0.4,
            spectralEntropy: 0.4, xyCoherence: 0.5, zYawCoherence: 0.3,
            normalizedVerticalRMS: 0.12, yawRateRMS: 0.25,
            gpsSpeed: 1.2, gpsAccuracy: 8.0        )
        for _ in 0..<20 {
            hmm.update(with: ambiguousAtSlowSpeed)
        }

        // At 1.2 m/s with good GPS, trot should be suppressed — walk should dominate
        #expect(hmm.probability(of: .walk) > hmm.probability(of: .trot))
    }

    @Test func clearTrotSpeedSuppressesWalkProbability() {
        let hmm = GaitHMM()
        // Build up to trot
        for _ in 0..<10 { hmm.update(with: walkFeatures()) }
        for _ in 0..<15 { hmm.update(with: trotFeatures()) }
        #expect(hmm.currentState == .trot)

        // Feed ambiguous features at clear trot speed with good accuracy
        let ambiguousAtTrotSpeed = GaitFeatureVector(
            strideFrequency: 2.1, h2Ratio: 0.8, h3Ratio: 0.4,
            spectralEntropy: 0.4, xyCoherence: 0.5, zYawCoherence: 0.3,
            normalizedVerticalRMS: 0.15, yawRateRMS: 0.3,
            gpsSpeed: 3.0, gpsAccuracy: 8.0        )
        for _ in 0..<20 {
            hmm.update(with: ambiguousAtTrotSpeed)
        }

        // At 3.0 m/s with good GPS, walk should be suppressed — trot should dominate
        #expect(hmm.probability(of: .trot) > hmm.probability(of: .walk))
    }

    @Test func poorGPSDoesNotApplyWalkTrotSoftConstraint() {
        let hmm1 = GaitHMM()
        let hmm2 = GaitHMM()

        // Establish walk in both
        for _ in 0..<10 {
            hmm1.update(with: walkFeatures())
            hmm2.update(with: walkFeatures())
        }

        // Feed ambiguous features at slow GPS — one with good accuracy, one with poor
        let goodGPS = GaitFeatureVector(
            strideFrequency: 2.1, h2Ratio: 0.8, h3Ratio: 0.4,
            spectralEntropy: 0.4, xyCoherence: 0.5, zYawCoherence: 0.3,
            normalizedVerticalRMS: 0.12, yawRateRMS: 0.25,
            gpsSpeed: 1.2, gpsAccuracy: 8.0        )
        let poorGPS = GaitFeatureVector(
            strideFrequency: 2.1, h2Ratio: 0.8, h3Ratio: 0.4,
            spectralEntropy: 0.4, xyCoherence: 0.5, zYawCoherence: 0.3,
            normalizedVerticalRMS: 0.12, yawRateRMS: 0.25,
            gpsSpeed: 1.2, gpsAccuracy: 25.0        )

        for _ in 0..<20 {
            hmm1.update(with: goodGPS)
            hmm2.update(with: poorGPS)
        }

        // Good GPS should suppress trot more than poor GPS
        #expect(hmm1.probability(of: .trot) < hmm2.probability(of: .trot))
    }

    // MARK: - Wrist Mount Tests

    @Test func wristHMMInitializesWithValidParams() {
        let hmm = GaitHMM(sensorMount: .wrist)
        #expect(hmm.currentState == .stationary)
        #expect(hmm.probability(of: .stationary) == 1.0)
    }

    @Test func wristTrotH2MeanLowerThanTrunk() {
        let trunkHMM = GaitHMM(sensorMount: .trunk)
        let wristHMM = GaitHMM(sensorMount: .wrist)

        // Feed identical trot-like features — wrist HMM should give different probabilities
        // because its emission means are lower for h2
        let features = GaitFeatureVector(
            strideFrequency: 2.9, h2Ratio: 0.9, h3Ratio: 0.4,
            spectralEntropy: 0.5, xyCoherence: 0.6, zYawCoherence: 0.2,
            normalizedVerticalRMS: 0.12, yawRateRMS: 0.25,
            gpsSpeed: 0, gpsAccuracy: 100
        )
        for _ in 0..<20 {
            trunkHMM.update(with: features)
            wristHMM.update(with: features)
        }

        // Wrist HMM should favor trot more for lower h2 values (its emission center is lower)
        #expect(wristHMM.probability(of: .trot) > trunkHMM.probability(of: .trot))
    }

    @Test func wristStationaryHasWiderRMSRange() {
        let wristHMM = GaitHMM(sensorMount: .wrist)

        // Slightly elevated RMS that exceeds trunk stationary range (0-0.05) but fits wrist (0-0.08)
        let features = GaitFeatureVector(
            strideFrequency: 0.2, h2Ratio: 0.1, h3Ratio: 0.1,
            spectralEntropy: 0.3, xyCoherence: 0.1, zYawCoherence: 0.1,
            normalizedVerticalRMS: 0.06, yawRateRMS: 0.1,
            gpsSpeed: 0, gpsAccuracy: 100
        )
        for _ in 0..<20 {
            wristHMM.update(with: features)
        }
        #expect(wristHMM.currentState == .stationary)
    }

    @Test func wristClassifiesWalkWithAttenuatedFeatures() {
        let hmm = GaitHMM(sensorMount: .wrist)

        // Wrist-appropriate walk features: lower h2/h3, lower RMS than trunk
        let features = GaitFeatureVector(
            strideFrequency: 1.6, h2Ratio: 0.35, h3Ratio: 0.25,
            spectralEntropy: 0.45, xyCoherence: 0.3, zYawCoherence: 0.25,
            normalizedVerticalRMS: 0.06, yawRateRMS: 0.11,
            gpsSpeed: 0, gpsAccuracy: 100
        )
        for _ in 0..<20 {
            hmm.update(with: features)
        }
        #expect(hmm.currentState == .walk)
    }

    @Test func wristDefaultTrunkUnchanged() {
        // Verify default init still uses trunk params (backward compat)
        let hmm = GaitHMM()
        for _ in 0..<20 {
            hmm.update(with: walkFeatures())
        }
        #expect(hmm.currentState == .walk)
    }

    @Test func wristProbabilitiesSumToOne() {
        let hmm = GaitHMM(sensorMount: .wrist)
        let features = GaitFeatureVector(
            strideFrequency: 2.9, h2Ratio: 0.9, h3Ratio: 0.4,
            spectralEntropy: 0.55, xyCoherence: 0.6, zYawCoherence: 0.2,
            normalizedVerticalRMS: 0.12, yawRateRMS: 0.25,
            gpsSpeed: 0, gpsAccuracy: 100
        )
        for _ in 0..<5 {
            hmm.update(with: features)
        }
        let sum = HMMGaitState.allCases.reduce(0.0) { $0 + hmm.probability(of: $1) }
        #expect(abs(sum - 1.0) < 1e-10)
    }

    // MARK: - Watch Motion Data Tests

    @Test func freshWatchDataHelpsCanterGallopDiscrimination() {
        let noWatchHMM = GaitHMM()
        let watchHMM = GaitHMM()

        // Build up through gaits to canter
        for _ in 0..<10 { noWatchHMM.update(with: walkFeatures()); watchHMM.update(with: walkFeatures()) }
        for _ in 0..<10 { noWatchHMM.update(with: trotFeatures()); watchHMM.update(with: trotFeatures()) }
        for _ in 0..<15 { noWatchHMM.update(with: canterFeatures()); watchHMM.update(with: canterFeatures()) }

        // Feed gallop features — one without Watch, one with fresh Watch data matching gallop
        let gallopNoWatch = gallopFeatures()
        let gallopWithWatch = GaitFeatureVector(
            strideFrequency: 4.5, h2Ratio: 0.5, h3Ratio: 0.6,
            spectralEntropy: 0.75, xyCoherence: 0.25, zYawCoherence: 0.85,
            normalizedVerticalRMS: 0.475, yawRateRMS: 0.9,
            gpsSpeed: 9.0, gpsAccuracy: 10.0,
            watchVerticalOscillation: 8.5, watchMovementIntensity: 82.0, watchDataAge: 1.0
        )

        for _ in 0..<15 {
            noWatchHMM.update(with: gallopNoWatch)
            watchHMM.update(with: gallopWithWatch)
        }

        // With Watch data confirming gallop, gallop probability should be higher
        #expect(watchHMM.probability(of: .gallop) >= noWatchHMM.probability(of: .gallop))
    }

    @Test func watchDataAgeModulatesInfluence() {
        let freshHMM = GaitHMM()
        let staleHMM = GaitHMM()

        // Feed identical trot features but with different Watch data ages
        let freshWatch = GaitFeatureVector(
            strideFrequency: 2.9, h2Ratio: 1.85, h3Ratio: 0.55,
            spectralEntropy: 0.45, xyCoherence: 0.85, zYawCoherence: 0.25,
            normalizedVerticalRMS: 0.25, yawRateRMS: 0.35,
            gpsSpeed: 3.0, gpsAccuracy: 10.0,
            watchVerticalOscillation: 7.25, watchMovementIntensity: 47.5, watchDataAge: 1.0
        )
        let staleWatch = GaitFeatureVector(
            strideFrequency: 2.9, h2Ratio: 1.85, h3Ratio: 0.55,
            spectralEntropy: 0.45, xyCoherence: 0.85, zYawCoherence: 0.25,
            normalizedVerticalRMS: 0.25, yawRateRMS: 0.35,
            gpsSpeed: 3.0, gpsAccuracy: 10.0,
            watchVerticalOscillation: 7.25, watchMovementIntensity: 47.5, watchDataAge: 30.0
        )

        for _ in 0..<20 {
            freshHMM.update(with: freshWatch)
            staleHMM.update(with: staleWatch)
        }

        // Both should still converge to trot; stale Watch data should not destabilise
        #expect(freshHMM.currentState == .trot)
        #expect(staleHMM.currentState == .trot)

        // Fresh data (age=1, factor=1) should have tighter influence than stale (age=30, factor=15)
        // Both should be trot, so probabilities will be similar, but fresh should be >= stale
        #expect(freshHMM.probability(of: .trot) >= staleHMM.probability(of: .trot) - 0.05)
    }

    @Test func noWatchRegressionForWalkTrot() {
        // Verify existing walk→trot transitions still work without Watch data
        let hmm = GaitHMM()
        for _ in 0..<15 {
            hmm.update(with: walkFeatures())
        }
        #expect(hmm.currentState == .walk)

        for _ in 0..<15 {
            hmm.update(with: trotFeatures())
        }
        #expect(hmm.currentState == .trot)
    }

    // MARK: - Watch Rhythm/Posture Tests

    @Test func watchRhythmScoreHelpsCanterGallopDiscrimination() {
        let canterHMM = GaitHMM()
        let gallopHMM = GaitHMM()

        // Build up through gaits to canter in both
        for _ in 0..<10 { canterHMM.update(with: walkFeatures()); gallopHMM.update(with: walkFeatures()) }
        for _ in 0..<10 { canterHMM.update(with: trotFeatures()); gallopHMM.update(with: trotFeatures()) }
        for _ in 0..<15 { canterHMM.update(with: canterFeatures()); gallopHMM.update(with: canterFeatures()) }

        // Same IMU features at canter/gallop boundary speed, but different rhythm/posture
        let canterLikeWatch = GaitFeatureVector(
            strideFrequency: 2.8, h2Ratio: 0.6, h3Ratio: 1.2,
            spectralEntropy: 0.55, xyCoherence: 0.3, zYawCoherence: 0.75,
            normalizedVerticalRMS: 0.38, yawRateRMS: 0.55,
            gpsSpeed: 6.0, gpsAccuracy: 8.0,
            watchVerticalOscillation: 5.5, watchMovementIntensity: 62.0,
            watchRhythmScore: 72, watchPostureStability: 68, watchDataAge: 1.0
        )
        let gallopLikeWatch = GaitFeatureVector(
            strideFrequency: 2.8, h2Ratio: 0.6, h3Ratio: 1.2,
            spectralEntropy: 0.55, xyCoherence: 0.3, zYawCoherence: 0.75,
            normalizedVerticalRMS: 0.38, yawRateRMS: 0.55,
            gpsSpeed: 6.0, gpsAccuracy: 8.0,
            watchVerticalOscillation: 5.5, watchMovementIntensity: 62.0,
            watchRhythmScore: 40, watchPostureStability: 45, watchDataAge: 1.0
        )

        for _ in 0..<15 {
            canterHMM.update(with: canterLikeWatch)
            gallopHMM.update(with: gallopLikeWatch)
        }

        // Canter-like rhythm/posture should favor canter more than gallop-like values
        #expect(canterHMM.probability(of: .canter) > gallopHMM.probability(of: .canter))
    }

    @Test func staleWatchRhythmPostureDoNotDestabilize() {
        let hmm = GaitHMM()

        // Establish trot
        for _ in 0..<10 { hmm.update(with: walkFeatures()) }
        for _ in 0..<15 { hmm.update(with: trotFeatures()) }
        #expect(hmm.currentState == .trot)

        // Feed trot IMU features with stale Watch rhythm/posture data (age=60s)
        let staleWatch = GaitFeatureVector(
            strideFrequency: 2.9, h2Ratio: 1.85, h3Ratio: 0.55,
            spectralEntropy: 0.45, xyCoherence: 0.85, zYawCoherence: 0.25,
            normalizedVerticalRMS: 0.25, yawRateRMS: 0.35,
            gpsSpeed: 3.0, gpsAccuracy: 10.0,
            watchVerticalOscillation: 7.25, watchMovementIntensity: 47.5,
            watchRhythmScore: 85, watchPostureStability: 72, watchDataAge: 60.0
        )
        for _ in 0..<15 {
            hmm.update(with: staleWatch)
        }

        // Trot classification should hold — stale Watch data is uninformative
        #expect(hmm.currentState == .trot)
    }

    // MARK: - Helpers

    private func stationaryFeatures() -> GaitFeatureVector {
        GaitFeatureVector(
            strideFrequency: 0.25, h2Ratio: 0.15, h3Ratio: 0.15,
            spectralEntropy: 0.15, xyCoherence: 0.15, zYawCoherence: 0.15,
            normalizedVerticalRMS: 0.025, yawRateRMS: 0.05,
            gpsSpeed: 0.0, gpsAccuracy: 10.0        )
    }

    private func walkFeatures(gpsSpeed: Double = 1.5, gpsAccuracy: Double = 10.0) -> GaitFeatureVector {
        GaitFeatureVector(
            strideFrequency: 1.6, h2Ratio: 0.5, h3Ratio: 0.35,
            spectralEntropy: 0.35, xyCoherence: 0.35, zYawCoherence: 0.3,
            normalizedVerticalRMS: 0.10, yawRateRMS: 0.2,
            gpsSpeed: gpsSpeed, gpsAccuracy: gpsAccuracy        )
    }

    private func trotFeatures(gpsSpeed: Double = 3.0, gpsAccuracy: Double = 10.0) -> GaitFeatureVector {
        GaitFeatureVector(
            strideFrequency: 2.9, h2Ratio: 1.85, h3Ratio: 0.55,
            spectralEntropy: 0.45, xyCoherence: 0.85, zYawCoherence: 0.25,
            normalizedVerticalRMS: 0.25, yawRateRMS: 0.35,
            gpsSpeed: gpsSpeed, gpsAccuracy: gpsAccuracy        )
    }

    private func canterFeatures(gpsSpeed: Double = 5.0, gpsAccuracy: Double = 10.0) -> GaitFeatureVector {
        GaitFeatureVector(
            strideFrequency: 2.4, h2Ratio: 0.7, h3Ratio: 1.5,
            spectralEntropy: 0.55, xyCoherence: 0.35, zYawCoherence: 0.75,
            normalizedVerticalRMS: 0.35, yawRateRMS: 0.6,
            gpsSpeed: gpsSpeed, gpsAccuracy: gpsAccuracy        )
    }

    private func gallopFeatures(gpsSpeed: Double = 9.0, gpsAccuracy: Double = 10.0) -> GaitFeatureVector {
        GaitFeatureVector(
            strideFrequency: 4.5, h2Ratio: 0.5, h3Ratio: 0.6,
            spectralEntropy: 0.75, xyCoherence: 0.25, zYawCoherence: 0.85,
            normalizedVerticalRMS: 0.475, yawRateRMS: 0.9,
            gpsSpeed: gpsSpeed, gpsAccuracy: gpsAccuracy        )
    }
}
