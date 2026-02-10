//
//  GaitAnalyzerTests.swift
//  TetraTrackTests
//
//  Tests for GaitAnalyzer gait detection functionality
//

import Testing
import Foundation
@testable import TetraTrack

struct GaitAnalyzerTests {

    // MARK: - Initialization Tests

    @Test func initialization() {
        let analyzer = GaitAnalyzer()

        #expect(analyzer.currentGait == .stationary)
        #expect(analyzer.isAnalyzing == false)
        #expect(analyzer.detectedBounceFrequency == 0)
        #expect(analyzer.bounceAmplitude == 0)
    }

    // MARK: - Start/Stop Analyzing Tests

    @Test func startAnalyzingSetsState() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()

        analyzer.startAnalyzing(for: ride)

        #expect(analyzer.isAnalyzing == true)
        #expect(analyzer.currentGait == .stationary)
    }

    @Test func startAnalyzingDoesNotRestartIfAlreadyAnalyzing() {
        let analyzer = GaitAnalyzer()
        let ride1 = Ride()
        let ride2 = Ride()

        analyzer.startAnalyzing(for: ride1)

        // Simulate some state change
        for _ in 0..<10 {
            analyzer.processLocation(speed: 2.5, distance: 1.0)
        }

        // Try starting again - should be ignored
        analyzer.startAnalyzing(for: ride2)

        #expect(analyzer.isAnalyzing == true)
    }

    @Test func stopAnalyzingClearsState() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()

        analyzer.startAnalyzing(for: ride)
        analyzer.stopAnalyzing()

        #expect(analyzer.isAnalyzing == false)
    }

    @Test func stopAnalyzingWhenNotAnalyzingIsNoOp() {
        let analyzer = GaitAnalyzer()

        // Should not crash
        analyzer.stopAnalyzing()

        #expect(analyzer.isAnalyzing == false)
    }

    // MARK: - Reset Tests

    @Test func resetClearsAllState() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()

        analyzer.startAnalyzing(for: ride)

        // Feed some data
        for _ in 0..<10 {
            analyzer.processLocation(speed: 2.5, distance: 1.0)
        }

        analyzer.reset()

        #expect(analyzer.isAnalyzing == false)
        #expect(analyzer.currentGait == .stationary)
        #expect(analyzer.detectedBounceFrequency == 0)
        #expect(analyzer.bounceAmplitude == 0)
    }

    // MARK: - Process Location Tests

    @Test func processLocationIgnoredWhenNotAnalyzing() {
        let analyzer = GaitAnalyzer()

        // Should not crash and should not change state
        analyzer.processLocation(speed: 5.0, distance: 10.0)

        #expect(analyzer.currentGait == .stationary)
    }

    @Test func processLocationWithZeroSpeedStaysStationary() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()

        analyzer.startAnalyzing(for: ride)

        // Feed zero speed multiple times to trigger confirmation
        for _ in 0..<10 {
            analyzer.processLocation(speed: 0.0, distance: 0.0)
        }

        #expect(analyzer.currentGait == .stationary)
    }

    @Test func processLocationWithWalkSpeed() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()

        analyzer.startAnalyzing(for: ride)

        // Walk speed: ~1.5 m/s, need multiple samples for confirmation
        for _ in 0..<10 {
            analyzer.processLocation(speed: 1.5, distance: 1.5)
        }

        // With only GPS data (no motion), should detect walk
        #expect(analyzer.currentGait == .walk)
    }

    @Test func processLocationWithTrotSpeed() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()

        analyzer.startAnalyzing(for: ride)

        // Trot speed: 1.7 to 3.5 m/s, use 2.5 m/s (clearly in range)
        for _ in 0..<10 {
            analyzer.processLocation(speed: 2.5, distance: 2.5)
        }

        #expect(analyzer.currentGait == .trot)
    }

    @Test func processLocationWithCanterSpeed() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()

        analyzer.startAnalyzing(for: ride)

        // Canter speed: 3.5 to 5.5 m/s, use 4.5 m/s (clearly in range)
        for _ in 0..<10 {
            analyzer.processLocation(speed: 4.5, distance: 4.5)
        }

        #expect(analyzer.currentGait == .canter)
    }

    @Test func processLocationWithGallopSpeed() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()

        analyzer.startAnalyzing(for: ride)

        // Gallop speed: ~9 m/s
        for _ in 0..<10 {
            analyzer.processLocation(speed: 9.0, distance: 9.0)
        }

        #expect(analyzer.currentGait == .gallop)
    }

    // MARK: - Motion Processing Tests

    @Test func processMotionIgnoredWhenNotAnalyzing() {
        let analyzer = GaitAnalyzer()

        let sample = createMotionSample(verticalAccel: 0.5)

        // Should not crash
        analyzer.processMotion(sample)

        #expect(analyzer.bounceAmplitude == 0)
    }

    @Test func processMotionUpdatesBounceAmplitude() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()

        analyzer.startAnalyzing(for: ride)

        // Feed enough samples to calculate RMS (needs >= 20)
        for i in 0..<25 {
            let sample = createMotionSample(
                verticalAccel: sin(Double(i) * 0.5) * 0.3,
                timestamp: Date().addingTimeInterval(Double(i) * 0.02)
            )
            analyzer.processMotion(sample)
        }

        #expect(analyzer.bounceAmplitude > 0)
    }

    // MARK: - Gait Change Callback Tests

    @Test func onGaitChangeCalledWhenGaitChanges() async {
        let analyzer = GaitAnalyzer()
        let ride = Ride()

        var callbackCalled = false
        var fromGait: GaitType?
        var toGait: GaitType?

        analyzer.onGaitChange = { from, to in
            callbackCalled = true
            fromGait = from
            toGait = to
        }

        analyzer.startAnalyzing(for: ride)

        // Transition from stationary to walk
        for _ in 0..<10 {
            analyzer.processLocation(speed: 1.5, distance: 1.5)
        }

        #expect(callbackCalled == true)
        #expect(fromGait == .stationary)
        #expect(toGait == .walk)
    }

    // MARK: - Gait Confirmation Logic Tests

    @Test func gaitRequiresConfirmationBeforeChanging() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()

        analyzer.startAnalyzing(for: ride)

        // Single walk sample should not change gait (needs confirmation)
        analyzer.processLocation(speed: 1.5, distance: 1.5)

        // Should still be stationary until confirmed
        #expect(analyzer.currentGait == .stationary)

        // Feed more samples for confirmation (threshold is 3)
        analyzer.processLocation(speed: 1.5, distance: 1.5)
        analyzer.processLocation(speed: 1.5, distance: 1.5)
        analyzer.processLocation(speed: 1.5, distance: 1.5)

        // Now should be walk
        #expect(analyzer.currentGait == .walk)
    }

    @Test func inconsistentGaitsResetConfirmation() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()

        analyzer.startAnalyzing(for: ride)

        // Start moving toward walk
        analyzer.processLocation(speed: 1.5, distance: 1.5)
        analyzer.processLocation(speed: 1.5, distance: 1.5)

        // But then trot speed - should reset confirmation
        analyzer.processLocation(speed: 3.5, distance: 3.5)

        // And back to walk - needs fresh confirmation
        analyzer.processLocation(speed: 1.5, distance: 1.5)

        // Not yet confirmed
        #expect(analyzer.currentGait == .stationary)
    }

    // MARK: - Speed Averaging Tests

    @Test func speedUsesRollingAverage() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()

        analyzer.startAnalyzing(for: ride)

        // Feed mix of speeds - should average
        analyzer.processLocation(speed: 1.0, distance: 1.0)
        analyzer.processLocation(speed: 2.0, distance: 1.0)
        analyzer.processLocation(speed: 1.5, distance: 1.0)
        analyzer.processLocation(speed: 1.5, distance: 1.0)
        analyzer.processLocation(speed: 1.5, distance: 1.0)
        analyzer.processLocation(speed: 1.5, distance: 1.0)

        // Average should be around walk speed
        #expect(analyzer.currentGait == .walk)
    }

    // MARK: - Update Lead Tests

    @Test func updateLeadWhenNotAnalyzingIsNoOp() {
        let analyzer = GaitAnalyzer()

        // Should not crash
        analyzer.updateLead(.left, confidence: 0.9)
    }

    // MARK: - Update Rhythm Tests

    @Test func updateRhythmWhenNotAnalyzingIsNoOp() {
        let analyzer = GaitAnalyzer()

        // Should not crash
        analyzer.updateRhythm(0.85)
    }

    // MARK: - Spectral Integration via injectSyntheticFeatures Tests

    @Test func injectWalkFeaturesChangesGaitToWalk() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()
        analyzer.startAnalyzing(for: ride)

        let walkFeatures = GaitFeatureVector(
            strideFrequency: 1.6, h2Ratio: 0.5, h3Ratio: 0.35,
            spectralEntropy: 0.35, xyCoherence: 0.35, zYawCoherence: 0.3,
            normalizedVerticalRMS: 0.10, yawRateRMS: 0.2,
            gpsSpeed: 1.5, gpsAccuracy: 10.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        for _ in 0..<20 {
            analyzer.injectSyntheticFeatures(walkFeatures)
        }
        #expect(analyzer.currentGait == .walk)
        #expect(analyzer.strideFrequency == 1.6)
    }

    @Test func injectTrotFeaturesChangesGaitToTrot() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()
        analyzer.startAnalyzing(for: ride)

        let walkFeatures = GaitFeatureVector(
            strideFrequency: 1.6, h2Ratio: 0.5, h3Ratio: 0.35,
            spectralEntropy: 0.35, xyCoherence: 0.35, zYawCoherence: 0.3,
            normalizedVerticalRMS: 0.10, yawRateRMS: 0.2,
            gpsSpeed: 1.5, gpsAccuracy: 10.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        for _ in 0..<10 {
            analyzer.injectSyntheticFeatures(walkFeatures)
        }

        let trotFeatures = GaitFeatureVector(
            strideFrequency: 2.9, h2Ratio: 1.85, h3Ratio: 0.55,
            spectralEntropy: 0.45, xyCoherence: 0.85, zYawCoherence: 0.25,
            normalizedVerticalRMS: 0.25, yawRateRMS: 0.35,
            gpsSpeed: 3.0, gpsAccuracy: 10.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        for _ in 0..<20 {
            analyzer.injectSyntheticFeatures(trotFeatures)
        }
        #expect(analyzer.currentGait == .trot)
    }

    @Test func injectFeaturesWhileNotAnalyzingDoesNotCrash() {
        let analyzer = GaitAnalyzer()
        // Not started - should not crash
        let features = GaitFeatureVector(
            strideFrequency: 1.6, h2Ratio: 0.5, h3Ratio: 0.35,
            spectralEntropy: 0.35, xyCoherence: 0.35, zYawCoherence: 0.3,
            normalizedVerticalRMS: 0.10, yawRateRMS: 0.2,
            gpsSpeed: 1.5, gpsAccuracy: 10.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        analyzer.injectSyntheticFeatures(features)
        #expect(analyzer.currentGait == .stationary)
    }

    @Test func injectStationaryAfterWalkReturnsToStationary() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()
        analyzer.startAnalyzing(for: ride)

        let walkFeatures = GaitFeatureVector(
            strideFrequency: 1.6, h2Ratio: 0.5, h3Ratio: 0.35,
            spectralEntropy: 0.35, xyCoherence: 0.35, zYawCoherence: 0.3,
            normalizedVerticalRMS: 0.10, yawRateRMS: 0.2,
            gpsSpeed: 1.5, gpsAccuracy: 10.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        for _ in 0..<20 {
            analyzer.injectSyntheticFeatures(walkFeatures)
        }
        #expect(analyzer.currentGait == .walk)

        let stationaryFeatures = GaitFeatureVector(
            strideFrequency: 0.25, h2Ratio: 0.15, h3Ratio: 0.15,
            spectralEntropy: 0.15, xyCoherence: 0.15, zYawCoherence: 0.15,
            normalizedVerticalRMS: 0.025, yawRateRMS: 0.05,
            gpsSpeed: 0.0, gpsAccuracy: 10.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        for _ in 0..<20 {
            analyzer.injectSyntheticFeatures(stationaryFeatures)
        }
        #expect(analyzer.currentGait == .stationary)
    }

    // MARK: - Mount Position Configuration Tests

    @Test func jodhpurThighCalibrationDelay() {
        let analyzer = GaitAnalyzer()
        analyzer.configure(mountPosition: .jodhpurThigh)
        #expect(analyzer.mountPosition == .jodhpurThigh)
        #expect(PhoneMountPosition.jodhpurThigh.calibrationDelay == 100)
    }

    @Test func jacketChestCalibrationDelay() {
        let analyzer = GaitAnalyzer()
        analyzer.configure(mountPosition: .jacketChest)
        #expect(analyzer.mountPosition == .jacketChest)
        #expect(PhoneMountPosition.jacketChest.calibrationDelay == 50)
    }

    // MARK: - Horse Configuration Tests

    @Test func configureWithHorseAppliesBreedPriors() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()

        let horse = Horse()
        horse.breedType = HorseBreed.shetland.rawValue
        ride.horse = horse
        analyzer.startAnalyzing(for: ride)

        // Shetland pony should accept higher walk frequencies
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
        #expect(analyzer.currentGait == .walk)
    }

    @Test func configureWithNilHorseUsesDefaults() {
        let analyzer = GaitAnalyzer()
        analyzer.configure(for: nil)

        let ride = Ride()
        analyzer.startAnalyzing(for: ride)

        // Standard walk features should work with defaults
        let walkFeatures = GaitFeatureVector(
            strideFrequency: 1.6, h2Ratio: 0.5, h3Ratio: 0.35,
            spectralEntropy: 0.35, xyCoherence: 0.35, zYawCoherence: 0.3,
            normalizedVerticalRMS: 0.10, yawRateRMS: 0.2,
            gpsSpeed: 1.5, gpsAccuracy: 10.0,
            watchArmSymmetry: 0, watchYawEnergy: 0
        )
        for _ in 0..<20 {
            analyzer.injectSyntheticFeatures(walkFeatures)
        }
        #expect(analyzer.currentGait == .walk)
    }

    // MARK: - Helper Functions

    private func createMotionSample(
        verticalAccel: Double,
        timestamp: Date = Date()
    ) -> MotionSample {
        MotionSample(
            timestamp: timestamp,
            accelerationX: 0,
            accelerationY: 0,
            accelerationZ: verticalAccel,
            rotationX: 0,
            rotationY: 0,
            rotationZ: 0,
            pitch: 0,
            roll: 0,
            yaw: 0,
            quaternionW: 1.0,
            quaternionX: 0.0,
            quaternionY: 0.0,
            quaternionZ: 0.0
        )
    }
}

// MARK: - GaitType Speed Classification Tests

struct GaitTypeSpeedTests {

    @Test func stationarySpeed() {
        let gait = GaitType.fromSpeed(0.0)
        #expect(gait == .stationary)
    }

    @Test func verySlowSpeedIsStationary() {
        let gait = GaitType.fromSpeed(0.3)
        #expect(gait == .stationary)
    }

    @Test func walkSpeed() {
        let gait = GaitType.fromSpeed(1.5)
        #expect(gait == .walk)
    }

    @Test func trotSpeed() {
        // Trot: 1.7 to 3.5 m/s
        let gait = GaitType.fromSpeed(2.5)
        #expect(gait == .trot)
    }

    @Test func canterSpeed() {
        // Canter: 3.5 to 5.5 m/s
        let gait = GaitType.fromSpeed(4.5)
        #expect(gait == .canter)
    }

    @Test func gallopSpeed() {
        // Gallop: > 5.5 m/s
        let gait = GaitType.fromSpeed(7.0)
        #expect(gait == .gallop)
    }

    @Test func borderlineTrotCanter() {
        // Test at the boundaries
        // 3.5 is the boundary, should be canter (case 3.5..<5.5)
        let atBoundary = GaitType.fromSpeed(3.5)
        let clearCanter = GaitType.fromSpeed(4.0)

        #expect(atBoundary == .canter)
        #expect(clearCanter == .canter)
    }
}
