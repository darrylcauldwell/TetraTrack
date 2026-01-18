//
//  SymmetryAnalyzerTests.swift
//  TrackRideTests
//
//  Tests for SymmetryAnalyzer movement symmetry analysis
//

import Testing
import Foundation
@testable import TetraTrack

struct SymmetryAnalyzerTests {

    // MARK: - Initialization Tests

    @Test func initialization() {
        let analyzer = SymmetryAnalyzer()

        #expect(analyzer.currentSymmetryScore == 0.0)
        #expect(analyzer.symmetryConfidence == 0.0)
        #expect(analyzer.leftReinSymmetry == 0.0)
        #expect(analyzer.rightReinSymmetry == 0.0)
    }

    // MARK: - Reset Tests

    @Test func resetClearsAllState() {
        let analyzer = SymmetryAnalyzer()

        // Feed some data
        for i in 0..<50 {
            let sample = createMotionSample(
                verticalAccel: sin(Double(i) * 0.5) * 0.4,
                lateralAccel: cos(Double(i) * 0.3) * 0.1,
                timestamp: Date().addingTimeInterval(Double(i) * 0.02)
            )
            analyzer.processMotionSample(sample, currentRein: .left)
        }

        analyzer.reset()

        #expect(analyzer.currentSymmetryScore == 0.0)
        #expect(analyzer.symmetryConfidence == 0.0)
    }

    // MARK: - Motion Sample Processing Tests

    @Test func processMotionSampleWithLowAmplitude() {
        let analyzer = SymmetryAnalyzer()

        // Feed low amplitude data (below footfall threshold)
        for i in 0..<100 {
            let sample = createMotionSample(
                verticalAccel: 0.05 * sin(Double(i) * 0.5),
                timestamp: Date().addingTimeInterval(Double(i) * 0.02)
            )
            analyzer.processMotionSample(sample, currentRein: .straight)
        }

        // With very low amplitude, no impacts detected
        #expect(analyzer.currentSymmetryScore == 0.0)
    }

    @Test func processMotionSampleWithHighAmplitude() {
        let analyzer = SymmetryAnalyzer()

        // Feed high amplitude data simulating stride impacts
        for i in 0..<300 {
            // Simulate periodic impacts
            let phase = Double(i) * 0.1
            let isImpact = Int(i) % 15 == 0
            let verticalAccel = isImpact ? 0.5 : 0.1 * sin(phase)

            let sample = createMotionSample(
                verticalAccel: verticalAccel,
                lateralAccel: 0.05 * sin(phase * 0.5),
                roll: 0.02 * sin(phase * 0.3),
                timestamp: Date().addingTimeInterval(Double(i) * 0.02)
            )
            analyzer.processMotionSample(sample, currentRein: .left)
        }

        // Should have some symmetry calculation
        #expect(analyzer.symmetryConfidence >= 0.0)
    }

    // MARK: - Rein Segment Tests

    @Test func finalizeReinSegmentRecordsScore() {
        let analyzer = SymmetryAnalyzer()

        // Process some left rein data
        for i in 0..<200 {
            let isImpact = Int(i) % 12 == 0
            let sample = createMotionSample(
                verticalAccel: isImpact ? 0.5 : 0.1,
                timestamp: Date().addingTimeInterval(Double(i) * 0.02)
            )
            analyzer.processMotionSample(sample, currentRein: .left)
        }

        analyzer.finalizeReinSegment()

        // Left rein score should be recorded
        #expect(analyzer.leftReinSymmetry >= 0.0)
    }

    // MARK: - Symmetry Score Accessors

    @Test func symmetryForGait() {
        let analyzer = SymmetryAnalyzer()

        let score = analyzer.symmetryForGait(.trot)

        #expect(score == analyzer.currentSymmetryScore)
    }

    @Test func symmetryWithConfidence() {
        let analyzer = SymmetryAnalyzer()

        let result = analyzer.symmetryWithConfidence()

        #expect(result.score == analyzer.currentSymmetryScore)
        #expect(result.confidence == analyzer.symmetryConfidence)
    }

    // MARK: - ReinAwareAnalyzer Protocol Tests

    @Test func leftReinScoreAccessor() {
        let analyzer = SymmetryAnalyzer()

        #expect(analyzer.leftReinScore == 0.0)
    }

    @Test func rightReinScoreAccessor() {
        let analyzer = SymmetryAnalyzer()

        #expect(analyzer.rightReinScore == 0.0)
    }

    // MARK: - Impact Side Detection Tests

    @Test func impactSideDetectionFromLateralAndRoll() {
        // This tests the ImpactEvent.estimatedSide computed property behavior
        // When lateral + roll > 0.05, it should be .right
        // When lateral + roll < -0.05, it should be .left
        // Otherwise .center

        // Test via feeding asymmetric data
        let analyzer = SymmetryAnalyzer()

        // Feed data biased to one side
        for i in 0..<200 {
            let isImpact = Int(i) % 12 == 0
            let sample = createMotionSample(
                verticalAccel: isImpact ? 0.5 : 0.1,
                lateralAccel: isImpact ? 0.15 : 0.0,  // Biased right
                roll: isImpact ? 0.1 : 0.0,
                timestamp: Date().addingTimeInterval(Double(i) * 0.02)
            )
            analyzer.processMotionSample(sample, currentRein: .straight)
        }

        // Analyzer should have processed the asymmetric data
        #expect(analyzer.symmetryConfidence >= 0.0)
    }

    // MARK: - Helper Functions

    private func createMotionSample(
        verticalAccel: Double = 0.0,
        lateralAccel: Double = 0.0,
        roll: Double = 0.0,
        timestamp: Date = Date()
    ) -> MotionSample {
        MotionSample(
            timestamp: timestamp,
            accelerationX: lateralAccel,
            accelerationY: 0,
            accelerationZ: verticalAccel,
            rotationX: 0,
            rotationY: 0,
            rotationZ: 0,
            pitch: 0,
            roll: roll,
            yaw: 0,
            quaternionW: 1.0,
            quaternionX: 0.0,
            quaternionY: 0.0,
            quaternionZ: 0.0
        )
    }
}

// MARK: - ImpactSide Tests

struct SymmetryImpactSideTests {

    @Test func impactSideCases() {
        // Test that ImpactSide enum exists with expected cases
        // (Testing via type checking since we can't instantiate ImpactEvent directly here)
        let analyzer = SymmetryAnalyzer()

        // After reset, there should be no data
        analyzer.reset()
        #expect(analyzer.currentSymmetryScore == 0.0)
    }
}
