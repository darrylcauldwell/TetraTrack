//
//  GaitAnalyzerTests.swift
//  TrackRideTests
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

// MARK: - Gallop Over-Classification Hypothesis Tests

/// Tests to validate the hypothesis that gallop is being over-classified during energetic canter
struct GallopOverClassificationTests {

    // MARK: - Synthetic Canter Stress Test

    /// This test simulates a ride with walk, trot, and canter ONLY (no gallop).
    /// It injects energetic canter features near the canter-gallop boundary.
    /// The test SHOULD FAIL if the hypothesis is correct (gallop being over-classified).
    ///
    /// Assertions:
    /// - Gallop probability may briefly increase
    /// - Total gallop time must be < 2% of session
    /// - Gallop must not persist for > 1 second
    @Test func energeticCanterShouldNotTriggerGallop() {
        let analyzer = GaitAnalyzer()
        let ride = Ride()

        analyzer.startAnalyzing(for: ride)

        // Session structure (60 seconds total):
        // - Walk: 10s
        // - Trot: 15s
        // - Canter: 25s (with energetic segments)
        // - Cool-down trot: 5s
        // - Walk: 5s

        var totalGallopTime: TimeInterval = 0
        var maxGallopDuration: TimeInterval = 0
        var currentGallopStart: Date?
        var gallopProbHistory: [Double] = []

        let updateRate: TimeInterval = 0.25  // 4 Hz

        // Phase 1: Walk (10 seconds = 40 updates)
        for i in 0..<40 {
            let features = createWalkFeatures(variation: Double(i) * 0.01)
            analyzer.injectSyntheticFeatures(features)

            trackGallopTime(
                analyzer: analyzer,
                currentGallopStart: &currentGallopStart,
                totalGallopTime: &totalGallopTime,
                maxGallopDuration: &maxGallopDuration,
                gallopProbHistory: &gallopProbHistory,
                updateInterval: updateRate
            )
        }

        // Phase 2: Trot (15 seconds = 60 updates)
        for i in 0..<60 {
            let features = createTrotFeatures(variation: Double(i) * 0.01)
            analyzer.injectSyntheticFeatures(features)

            trackGallopTime(
                analyzer: analyzer,
                currentGallopStart: &currentGallopStart,
                totalGallopTime: &totalGallopTime,
                maxGallopDuration: &maxGallopDuration,
                gallopProbHistory: &gallopProbHistory,
                updateInterval: updateRate
            )
        }

        // Phase 3: Canter with energetic segments (25 seconds = 100 updates)
        // Include boundary-pushing energetic segments
        for i in 0..<100 {
            let isEnergeticSegment = (i >= 20 && i < 40) || (i >= 60 && i < 80)
            let features: GaitFeatureVector

            if isEnergeticSegment {
                // Energetic canter: near the canter-gallop boundary
                features = createEnergeticCanterFeatures(
                    strideFreq: 2.8 + Double.random(in: 0...0.3),  // 2.8-3.1 Hz
                    variation: Double(i) * 0.005
                )
            } else {
                // Normal canter
                features = createCanterFeatures(variation: Double(i) * 0.01)
            }

            analyzer.injectSyntheticFeatures(features)

            trackGallopTime(
                analyzer: analyzer,
                currentGallopStart: &currentGallopStart,
                totalGallopTime: &totalGallopTime,
                maxGallopDuration: &maxGallopDuration,
                gallopProbHistory: &gallopProbHistory,
                updateInterval: updateRate
            )
        }

        // Phase 4: Cool-down trot (5 seconds = 20 updates)
        for i in 0..<20 {
            let features = createTrotFeatures(variation: Double(i) * 0.01)
            analyzer.injectSyntheticFeatures(features)

            trackGallopTime(
                analyzer: analyzer,
                currentGallopStart: &currentGallopStart,
                totalGallopTime: &totalGallopTime,
                maxGallopDuration: &maxGallopDuration,
                gallopProbHistory: &gallopProbHistory,
                updateInterval: updateRate
            )
        }

        // Phase 5: Walk (5 seconds = 20 updates)
        for i in 0..<20 {
            let features = createWalkFeatures(variation: Double(i) * 0.01)
            analyzer.injectSyntheticFeatures(features)

            trackGallopTime(
                analyzer: analyzer,
                currentGallopStart: &currentGallopStart,
                totalGallopTime: &totalGallopTime,
                maxGallopDuration: &maxGallopDuration,
                gallopProbHistory: &gallopProbHistory,
                updateInterval: updateRate
            )
        }

        // Finalize any ongoing gallop tracking
        if currentGallopStart != nil {
            let duration = Date().timeIntervalSince(currentGallopStart!)
            totalGallopTime += duration
            maxGallopDuration = max(maxGallopDuration, duration)
        }

        // Generate and print diagnostic report
        let sessionDuration: TimeInterval = 60.0
        let report = analyzer.getFalseGallopReport(sessionDuration: sessionDuration)
        print(report)

        // Print gallop probability statistics
        let maxGallopProb = gallopProbHistory.max() ?? 0
        let avgGallopProb = gallopProbHistory.isEmpty ? 0 : gallopProbHistory.reduce(0, +) / Double(gallopProbHistory.count)
        print("""
        ╔════════════════════════════════════════════════════════════════╗
        ║           GALLOP PROBABILITY STATISTICS                        ║
        ╠════════════════════════════════════════════════════════════════╣
        ║ Max Gallop Probability:        \(String(format: "%8.3f", maxGallopProb))                       ║
        ║ Avg Gallop Probability:        \(String(format: "%8.3f", avgGallopProb))                       ║
        ║ Total Gallop Time:             \(String(format: "%8.2f", totalGallopTime)) s                     ║
        ║ Max Gallop Duration:           \(String(format: "%8.2f", maxGallopDuration)) s                     ║
        ║ Gallop Percentage:             \(String(format: "%8.2f", (totalGallopTime / sessionDuration) * 100)) %%                     ║
        ╚════════════════════════════════════════════════════════════════╝
        """)

        // ASSERTIONS - These should FAIL if hypothesis is correct
        let gallopPercentage = (totalGallopTime / sessionDuration) * 100

        // Gallop time must be < 2% of session
        #expect(gallopPercentage < 2.0, "HYPOTHESIS CONFIRMED: Gallop was \(String(format: "%.1f", gallopPercentage))% of session (expected < 2%)")

        // No single gallop period > 1 second
        #expect(maxGallopDuration < 1.0, "HYPOTHESIS CONFIRMED: Max gallop duration was \(String(format: "%.2f", maxGallopDuration))s (expected < 1s)")

        analyzer.stopAnalyzing()
    }

    // MARK: - Transition Dynamics Test

    /// Test how quickly the HMM transitions from canter to gallop given favorable emissions
    @Test func transitionDynamicsCanterToGallop() {
        let hmm = GaitHMM()

        // Create gallop-favoring features (energetic canter boundary values)
        let gallopFavoringFeatures = GaitFeatureVector(
            strideFrequency: 3.2,       // In gallop range (3.0-6.0)
            h2Ratio: 0.5,               // In both ranges
            h3Ratio: 0.6,               // In gallop range (0.3-0.9), but low for canter
            spectralEntropy: 0.75,      // In gallop range (0.6-0.9)
            xyCoherence: 0.25,          // In both ranges
            zYawCoherence: 0.85,        // In both ranges
            normalizedVerticalRMS: 0.45, // In overlap zone
            yawRateRMS: 0.9,            // In gallop range
            gpsSpeed: 7.0,              // In gallop range (6.0-20.0)
            watchArmSymmetry: 0,
            watchYawEnergy: 0
        )

        let result = hmm.simulateTransitionDynamics(
            from: .canter,
            to: .gallop,
            favoringFeatures: gallopFavoringFeatures,
            maxSteps: 100,
            updateRateHz: 4.0
        )

        print("""
        ╔════════════════════════════════════════════════════════════════╗
        ║           TRANSITION DYNAMICS: CANTER → GALLOP                 ║
        ╠════════════════════════════════════════════════════════════════╣
        ║ Steps to Transition:           \(String(format: "%8d", result.stepsToTransition))                       ║
        ║ Time to Transition:            \(String(format: "%8.2f", result.timeToTransitionSeconds)) s                     ║
        ║ Final Gallop Probability:      \(String(format: "%8.3f", result.finalProbability))                       ║
        ╚════════════════════════════════════════════════════════════════╝

        Probability History (first 20 steps):
        \(result.probabilityHistory.prefix(20).enumerated().map { "  Step \($0.offset): P(gallop)=\(String(format: "%.4f", $0.element))" }.joined(separator: "\n"))
        """)

        // Record transition speed for analysis
        // A fast transition (< 2 seconds) suggests the model is too sensitive
        print("ANALYSIS: Transition takes \(String(format: "%.2f", result.timeToTransitionSeconds)) seconds")
        print("  - If < 0.5s: Model transitions TOO EASILY (emission dominates)")
        print("  - If 0.5-2s: Model has some resistance but may leak")
        print("  - If > 2s: Model has adequate inertia")
    }

    /// Test transition from gallop back to canter
    @Test func transitionDynamicsGallopToCanter() {
        let hmm = GaitHMM()

        // Create canter-favoring features
        let canterFavoringFeatures = GaitFeatureVector(
            strideFrequency: 2.4,       // In canter range (1.8-3.0)
            h2Ratio: 0.7,               // In canter range
            h3Ratio: 1.5,               // Strong H3 (canter signature)
            spectralEntropy: 0.55,      // In canter range
            xyCoherence: 0.35,          // In canter range
            zYawCoherence: 0.75,        // In canter range
            normalizedVerticalRMS: 0.35, // In canter range
            yawRateRMS: 0.6,            // In canter range
            gpsSpeed: 5.5,              // In canter range
            watchArmSymmetry: 0,
            watchYawEnergy: 0
        )

        let result = hmm.simulateTransitionDynamics(
            from: .gallop,
            to: .canter,
            favoringFeatures: canterFavoringFeatures,
            maxSteps: 100,
            updateRateHz: 4.0
        )

        print("""
        ╔════════════════════════════════════════════════════════════════╗
        ║           TRANSITION DYNAMICS: GALLOP → CANTER                 ║
        ╠════════════════════════════════════════════════════════════════╣
        ║ Steps to Transition:           \(String(format: "%8d", result.stepsToTransition))                       ║
        ║ Time to Transition:            \(String(format: "%8.2f", result.timeToTransitionSeconds)) s                     ║
        ║ Final Canter Probability:      \(String(format: "%8.3f", result.finalProbability))                       ║
        ╚════════════════════════════════════════════════════════════════╝
        """)
    }

    // MARK: - Feature Creation Helpers

    /// Create walk features with slight variation
    private func createWalkFeatures(variation: Double) -> GaitFeatureVector {
        GaitFeatureVector(
            strideFrequency: 1.6 + variation * 0.2,
            h2Ratio: 0.5 + variation * 0.1,
            h3Ratio: 0.35 + variation * 0.05,
            spectralEntropy: 0.35 + variation * 0.05,
            xyCoherence: 0.35 + variation * 0.05,
            zYawCoherence: 0.3 + variation * 0.05,
            normalizedVerticalRMS: 0.1 + variation * 0.02,
            yawRateRMS: 0.2 + variation * 0.02,
            gpsSpeed: 1.5 + variation * 0.3,
            watchArmSymmetry: 0,
            watchYawEnergy: 0
        )
    }

    /// Create trot features with slight variation
    private func createTrotFeatures(variation: Double) -> GaitFeatureVector {
        GaitFeatureVector(
            strideFrequency: 2.9 + variation * 0.3,
            h2Ratio: 1.8 + variation * 0.2,
            h3Ratio: 0.55 + variation * 0.1,
            spectralEntropy: 0.45 + variation * 0.05,
            xyCoherence: 0.85 + variation * 0.05,
            zYawCoherence: 0.25 + variation * 0.05,
            normalizedVerticalRMS: 0.25 + variation * 0.03,
            yawRateRMS: 0.35 + variation * 0.03,
            gpsSpeed: 3.5 + variation * 0.5,
            watchArmSymmetry: 0,
            watchYawEnergy: 0
        )
    }

    /// Create normal canter features with slight variation
    private func createCanterFeatures(variation: Double) -> GaitFeatureVector {
        GaitFeatureVector(
            strideFrequency: 2.4 + variation * 0.2,
            h2Ratio: 0.7 + variation * 0.1,
            h3Ratio: 1.5 + variation * 0.15,
            spectralEntropy: 0.55 + variation * 0.05,
            xyCoherence: 0.35 + variation * 0.05,
            zYawCoherence: 0.75 + variation * 0.05,
            normalizedVerticalRMS: 0.35 + variation * 0.03,
            yawRateRMS: 0.6 + variation * 0.05,
            gpsSpeed: 5.0 + variation * 0.5,
            watchArmSymmetry: 0,
            watchYawEnergy: 0
        )
    }

    /// Create energetic canter features at the canter-gallop boundary
    /// These values push into the overlap zone between canter and gallop
    private func createEnergeticCanterFeatures(strideFreq: Double, variation: Double) -> GaitFeatureVector {
        GaitFeatureVector(
            strideFrequency: strideFreq,                    // 2.8-3.1 Hz (boundary)
            h2Ratio: 0.6 + Double.random(in: 0...0.2),      // 0.6-0.8 (overlap zone)
            h3Ratio: 1.1 + Double.random(in: 0...0.3),      // 1.1-1.4 (still canter-like but lower)
            spectralEntropy: 0.6 + Double.random(in: 0...0.1), // 0.6-0.7 (overlap zone)
            xyCoherence: 0.3 + variation * 0.05,            // Low (consistent with canter)
            zYawCoherence: 0.75 + Double.random(in: 0...0.1), // 0.75-0.85 (overlap zone)
            normalizedVerticalRMS: 0.38 + Double.random(in: 0...0.07), // 0.38-0.45 (overlap zone)
            yawRateRMS: 0.7 + Double.random(in: 0...0.1),   // Elevated
            gpsSpeed: 6.0 + Double.random(in: 0...1.0),     // 6.0-7.0 m/s (overlap zone)
            watchArmSymmetry: 0,
            watchYawEnergy: 0
        )
    }

    /// Track gallop time during test
    private func trackGallopTime(
        analyzer: GaitAnalyzer,
        currentGallopStart: inout Date?,
        totalGallopTime: inout TimeInterval,
        maxGallopDuration: inout TimeInterval,
        gallopProbHistory: inout [Double],
        updateInterval: TimeInterval
    ) {
        let gallopProb = analyzer.getGallopProbability()
        gallopProbHistory.append(gallopProb)

        if analyzer.currentGait == .gallop {
            if currentGallopStart == nil {
                currentGallopStart = Date()
            }
        } else {
            if let start = currentGallopStart {
                let duration = Date().timeIntervalSince(start)
                totalGallopTime += duration
                maxGallopDuration = max(maxGallopDuration, duration)
                currentGallopStart = nil
            }
        }
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
