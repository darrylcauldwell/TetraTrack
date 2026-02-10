//
//  GaitClassificationTests.swift
//  TetraTrackTests
//
//  End-to-end gait classification tests using GaitAnalyzer with synthetic features
//

import Testing
import Foundation
@testable import TetraTrack

struct GaitClassificationTests {

    // MARK: - Canonical Gait Recognition Tests

    @Test func recognizesWalkThroughAnalyzer() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()
        analyzer.startAnalyzing(for: ride)

        for _ in 0..<20 {
            analyzer.injectSyntheticFeatures(walkFeatures())
        }
        #expect(analyzer.currentGait == .walk)
    }

    @Test func recognizesTrotThroughAnalyzer() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()
        analyzer.startAnalyzing(for: ride)

        // Walk first to get through adjacency constraint
        for _ in 0..<10 {
            analyzer.injectSyntheticFeatures(walkFeatures())
        }
        for _ in 0..<20 {
            analyzer.injectSyntheticFeatures(trotFeatures())
        }
        #expect(analyzer.currentGait == .trot)
    }

    @Test func recognizesCanterThroughAnalyzer() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()
        analyzer.startAnalyzing(for: ride)

        for _ in 0..<10 { analyzer.injectSyntheticFeatures(walkFeatures()) }
        for _ in 0..<10 { analyzer.injectSyntheticFeatures(trotFeatures()) }
        for _ in 0..<20 { analyzer.injectSyntheticFeatures(canterFeatures()) }
        #expect(analyzer.currentGait == .canter)
    }

    @Test func recognizesGallopThroughAnalyzer() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()
        analyzer.startAnalyzing(for: ride)

        for _ in 0..<10 { analyzer.injectSyntheticFeatures(walkFeatures()) }
        for _ in 0..<10 { analyzer.injectSyntheticFeatures(trotFeatures()) }
        for _ in 0..<10 { analyzer.injectSyntheticFeatures(canterFeatures()) }
        for _ in 0..<20 { analyzer.injectSyntheticFeatures(gallopFeatures()) }
        #expect(analyzer.currentGait == .gallop)
    }

    @Test func recognizesStationaryThroughAnalyzer() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()
        analyzer.startAnalyzing(for: ride)

        for _ in 0..<20 {
            analyzer.injectSyntheticFeatures(stationaryFeatures())
        }
        #expect(analyzer.currentGait == .stationary)
    }

    // MARK: - Gait Boundary Edge Case Tests

    @Test func walkTrotBoundaryDisambiguatedByH2() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()
        analyzer.startAnalyzing(for: ride)

        // f0=2.1 is in the overlap zone between walk and trot
        // High H2 (>1.2) should favor trot (2-beat diagonal symmetry)
        for _ in 0..<10 { analyzer.injectSyntheticFeatures(walkFeatures()) }

        let trotAtBoundary = GaitFeatureVector(
            strideFrequency: 2.1, h2Ratio: 1.8, h3Ratio: 0.5,
            spectralEntropy: 0.45, xyCoherence: 0.85, zYawCoherence: 0.25,
            normalizedVerticalRMS: 0.20, yawRateRMS: 0.35,
            gpsSpeed: 2.5, gpsAccuracy: 10.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        for _ in 0..<20 {
            analyzer.injectSyntheticFeatures(trotAtBoundary)
        }
        #expect(analyzer.currentGait == .trot)
    }

    @Test func trotCanterBoundaryDisambiguatedByCoherence() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()
        analyzer.startAnalyzing(for: ride)

        for _ in 0..<10 { analyzer.injectSyntheticFeatures(walkFeatures()) }
        for _ in 0..<10 { analyzer.injectSyntheticFeatures(trotFeatures()) }

        // f0=2.5 overlap zone. High H3 + high zYawCoherence + low xyCoherence = canter
        let canterAtBoundary = GaitFeatureVector(
            strideFrequency: 2.5, h2Ratio: 0.7, h3Ratio: 1.5,
            spectralEntropy: 0.55, xyCoherence: 0.3, zYawCoherence: 0.75,
            normalizedVerticalRMS: 0.35, yawRateRMS: 0.6,
            gpsSpeed: 4.5, gpsAccuracy: 10.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        for _ in 0..<20 {
            analyzer.injectSyntheticFeatures(canterAtBoundary)
        }
        #expect(analyzer.currentGait == .canter)
    }

    @Test func canterGallopBoundaryDisambiguatedByEntropy() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()
        analyzer.startAnalyzing(for: ride)

        for _ in 0..<10 { analyzer.injectSyntheticFeatures(walkFeatures()) }
        for _ in 0..<10 { analyzer.injectSyntheticFeatures(trotFeatures()) }
        for _ in 0..<10 { analyzer.injectSyntheticFeatures(canterFeatures()) }

        // f0=3.5, high entropy + high zYawCoherence = gallop
        let gallopAtBoundary = GaitFeatureVector(
            strideFrequency: 3.5, h2Ratio: 0.5, h3Ratio: 0.6,
            spectralEntropy: 0.75, xyCoherence: 0.25, zYawCoherence: 0.85,
            normalizedVerticalRMS: 0.45, yawRateRMS: 0.9,
            gpsSpeed: 8.0, gpsAccuracy: 10.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        for _ in 0..<20 {
            analyzer.injectSyntheticFeatures(gallopAtBoundary)
        }
        #expect(analyzer.currentGait == .gallop)
    }

    @Test func stationaryWalkBoundaryVeryLowRMS() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()
        analyzer.startAnalyzing(for: ride)

        // f0=0.5, very low RMS = stationary even with slight frequency
        let nearStationary = GaitFeatureVector(
            strideFrequency: 0.5, h2Ratio: 0.2, h3Ratio: 0.2,
            spectralEntropy: 0.2, xyCoherence: 0.2, zYawCoherence: 0.2,
            normalizedVerticalRMS: 0.03, yawRateRMS: 0.08,
            gpsSpeed: 0.2, gpsAccuracy: 10.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        for _ in 0..<20 {
            analyzer.injectSyntheticFeatures(nearStationary)
        }
        #expect(analyzer.currentGait == .stationary)
    }

    @Test func collectedTrotAtSlowSpeed() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()
        analyzer.startAnalyzing(for: ride)

        for _ in 0..<10 { analyzer.injectSyntheticFeatures(walkFeatures()) }

        // Collected trot: lower frequency but strong H2, moderate speed
        let collectedTrot = GaitFeatureVector(
            strideFrequency: 2.2, h2Ratio: 1.8, h3Ratio: 0.5,
            spectralEntropy: 0.4, xyCoherence: 0.85, zYawCoherence: 0.2,
            normalizedVerticalRMS: 0.20, yawRateRMS: 0.3,
            gpsSpeed: 2.0, gpsAccuracy: 10.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        for _ in 0..<20 {
            analyzer.injectSyntheticFeatures(collectedTrot)
        }
        #expect(analyzer.currentGait == .trot)
    }

    @Test func extendedCanterAtHighSpeed() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()
        analyzer.startAnalyzing(for: ride)

        for _ in 0..<10 { analyzer.injectSyntheticFeatures(walkFeatures()) }
        for _ in 0..<10 { analyzer.injectSyntheticFeatures(trotFeatures()) }

        // Extended canter at high speed, still has canter pattern (high H3, high zYaw)
        let extendedCanter = GaitFeatureVector(
            strideFrequency: 2.8, h2Ratio: 0.7, h3Ratio: 1.5,
            spectralEntropy: 0.55, xyCoherence: 0.35, zYawCoherence: 0.75,
            normalizedVerticalRMS: 0.40, yawRateRMS: 0.65,
            gpsSpeed: 7.0, gpsAccuracy: 10.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        for _ in 0..<20 {
            analyzer.injectSyntheticFeatures(extendedCanter)
        }
        #expect(analyzer.currentGait == .canter)
    }

    // MARK: - Confidence Threshold Behaviour Tests

    @Test func lowConfidenceDoesNotTriggerTransition() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()
        analyzer.startAnalyzing(for: ride)

        // Feed ambiguous features that might not reach 0.65 confidence
        // Mix of walk and trot characteristics
        let ambiguous = GaitFeatureVector(
            strideFrequency: 2.1, h2Ratio: 0.8, h3Ratio: 0.4,
            spectralEntropy: 0.4, xyCoherence: 0.5, zYawCoherence: 0.3,
            normalizedVerticalRMS: 0.12, yawRateRMS: 0.25,
            gpsSpeed: 1.5, gpsAccuracy: 10.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        // Just 2-3 updates shouldn't trigger a confident transition
        analyzer.injectSyntheticFeatures(ambiguous)
        analyzer.injectSyntheticFeatures(ambiguous)
        analyzer.injectSyntheticFeatures(ambiguous)
        // Should still be stationary or the confidence requirement prevents transition
        // (The HMM needs many consistent samples to build confidence)
        #expect(analyzer.currentGait == .stationary || analyzer.gaitConfidence < 0.65)
    }

    @Test func highConfidenceTriggerTransition() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()
        analyzer.startAnalyzing(for: ride)

        // Feed strong, unambiguous walk features many times
        for _ in 0..<20 {
            analyzer.injectSyntheticFeatures(walkFeatures())
        }
        #expect(analyzer.gaitConfidence >= 0.65)
        #expect(analyzer.currentGait == .walk)
    }

    @Test func flickeringFeaturesDoNotCauseRapidTransitions() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()
        analyzer.startAnalyzing(for: ride)

        // Establish walk
        for _ in 0..<15 {
            analyzer.injectSyntheticFeatures(walkFeatures())
        }
        #expect(analyzer.currentGait == .walk)

        // Alternate between walk and trot features rapidly
        var transitionCount = 0
        var lastGait = analyzer.currentGait
        analyzer.onGaitChange = { _, to in
            transitionCount += 1
            lastGait = to
        }

        for i in 0..<10 {
            if i % 2 == 0 {
                analyzer.injectSyntheticFeatures(trotFeatures())
            } else {
                analyzer.injectSyntheticFeatures(walkFeatures())
            }
        }

        // HMM self-transition probability (0.85) should prevent rapid flickering
        // At most 1 transition should happen (if any)
        #expect(transitionCount <= 1)
    }

    // MARK: - Gait Change Callback Tests

    @Test func callbackFiresOnFirstTransition() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()

        var callbackFired = false
        analyzer.onGaitChange = { _, _ in
            callbackFired = true
        }

        analyzer.startAnalyzing(for: ride)

        for _ in 0..<20 {
            analyzer.injectSyntheticFeatures(walkFeatures())
        }
        #expect(callbackFired)
    }

    @Test func callbackProvidesCorrectGaits() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()

        var fromGait: GaitType?
        var toGait: GaitType?
        analyzer.onGaitChange = { from, to in
            fromGait = from
            toGait = to
        }

        analyzer.startAnalyzing(for: ride)

        for _ in 0..<20 {
            analyzer.injectSyntheticFeatures(walkFeatures())
        }
        #expect(fromGait == .stationary)
        #expect(toGait == .walk)
    }

    @Test func callbackDoesNotFireWhenGaitStaysSame() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()

        var callbackCount = 0
        analyzer.onGaitChange = { _, _ in
            callbackCount += 1
        }

        analyzer.startAnalyzing(for: ride)

        // Establish walk
        for _ in 0..<20 {
            analyzer.injectSyntheticFeatures(walkFeatures())
        }
        let countAfterEstablish = callbackCount

        // Continue with walk - should not fire again
        for _ in 0..<20 {
            analyzer.injectSyntheticFeatures(walkFeatures())
        }
        #expect(callbackCount == countAfterEstablish)
    }

    // MARK: - Breed-Configured Classification Tests

    @Test func shetlandAcceptsHigherFrequencyWalk() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()

        let horse = Horse()
        horse.breedType = HorseBreed.shetland.rawValue
        ride.horse = horse
        analyzer.startAnalyzing(for: ride)

        // Higher frequency walk (2.4 Hz) typical for small pony
        let ponyWalk = GaitFeatureVector(
            strideFrequency: 2.4, h2Ratio: 0.5, h3Ratio: 0.35,
            spectralEntropy: 0.35, xyCoherence: 0.35, zYawCoherence: 0.3,
            normalizedVerticalRMS: 0.10, yawRateRMS: 0.2,
            gpsSpeed: 1.5, gpsAccuracy: 10.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        for _ in 0..<20 {
            analyzer.injectSyntheticFeatures(ponyWalk)
        }
        // With Shetland breed config, higher walk frequency should be accepted
        #expect(analyzer.currentGait == .walk)
    }

    @Test func warmbloodAcceptsLowerFrequencyTrot() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()

        let horse = Horse()
        horse.breedType = HorseBreed.warmblood.rawValue
        ride.horse = horse
        analyzer.startAnalyzing(for: ride)

        for _ in 0..<10 { analyzer.injectSyntheticFeatures(walkFeatures()) }

        // Lower frequency trot (1.9 Hz) typical for warmblood
        let warmbloodTrot = GaitFeatureVector(
            strideFrequency: 1.9, h2Ratio: 1.85, h3Ratio: 0.55,
            spectralEntropy: 0.45, xyCoherence: 0.85, zYawCoherence: 0.25,
            normalizedVerticalRMS: 0.25, yawRateRMS: 0.35,
            gpsSpeed: 3.0, gpsAccuracy: 10.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        for _ in 0..<20 {
            analyzer.injectSyntheticFeatures(warmbloodTrot)
        }
        #expect(analyzer.currentGait == .trot)
    }

    @Test func canterSensitivityAffectsDetection() {
        let highSens = GaitAnalyzer()
        let lowSens = GaitAnalyzer()
        let ride1 = Ride()
        let ride2 = Ride()

        let horse1 = Horse()
        horse1.breedType = HorseBreed.thoroughbred.rawValue
        horse1.canterSensitivity = 1.5
        horse1.hasCustomGaitSettings = true
        ride1.horse = horse1

        let horse2 = Horse()
        horse2.breedType = HorseBreed.thoroughbred.rawValue
        horse2.canterSensitivity = 0.5
        horse2.hasCustomGaitSettings = true
        ride2.horse = horse2

        highSens.startAnalyzing(for: ride1)
        lowSens.startAnalyzing(for: ride2)

        for _ in 0..<10 {
            highSens.injectSyntheticFeatures(walkFeatures())
            lowSens.injectSyntheticFeatures(walkFeatures())
        }
        for _ in 0..<10 {
            highSens.injectSyntheticFeatures(trotFeatures())
            lowSens.injectSyntheticFeatures(trotFeatures())
        }

        // Feed borderline canter features
        let borderlineCanter = GaitFeatureVector(
            strideFrequency: 2.4, h2Ratio: 0.7, h3Ratio: 1.2,
            spectralEntropy: 0.50, xyCoherence: 0.40, zYawCoherence: 0.65,
            normalizedVerticalRMS: 0.30, yawRateRMS: 0.5,
            gpsSpeed: 4.0, gpsAccuracy: 10.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        for _ in 0..<20 {
            highSens.injectSyntheticFeatures(borderlineCanter)
            lowSens.injectSyntheticFeatures(borderlineCanter)
        }

        // Higher sensitivity should be more likely to detect canter
        #expect(highSens.getCanterProbability() >= lowSens.getCanterProbability())
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
