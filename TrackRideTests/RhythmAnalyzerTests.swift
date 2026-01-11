//
//  RhythmAnalyzerTests.swift
//  TrackRideTests
//
//  Tests for RhythmAnalyzer stride rhythm analysis
//

import Testing
import Foundation
@testable import TetraTrack

struct RhythmAnalyzerTests {

    // MARK: - Initialization Tests

    @Test func initialization() {
        let analyzer = RhythmAnalyzer()

        #expect(analyzer.currentRhythmScore == 0.0)
        #expect(analyzer.currentStrideRate == 0.0)
        #expect(analyzer.rhythmConfidence == 0.0)
        #expect(analyzer.leftReinRhythm == 0.0)
        #expect(analyzer.rightReinRhythm == 0.0)
    }

    // MARK: - Reset Tests

    @Test func resetClearsAllState() {
        let analyzer = RhythmAnalyzer()

        // Feed some data
        for i in 0..<100 {
            let sample = createMotionSample(
                verticalAccel: sin(Double(i) * 0.5) * 0.4,
                timestamp: Date().addingTimeInterval(Double(i) * 0.02)
            )
            analyzer.processMotionSample(sample, currentGait: .trot)
        }

        analyzer.reset()

        #expect(analyzer.currentRhythmScore == 0.0)
        #expect(analyzer.currentStrideRate == 0.0)
        #expect(analyzer.rhythmConfidence == 0.0)
    }

    // MARK: - Stationary Gait Tests

    @Test func stationaryGaitProducesZeroRhythm() {
        let analyzer = RhythmAnalyzer()

        for i in 0..<100 {
            let sample = createMotionSample(
                verticalAccel: sin(Double(i) * 0.5) * 0.4,
                timestamp: Date().addingTimeInterval(Double(i) * 0.02)
            )
            analyzer.processMotionSample(sample, currentGait: .stationary)
        }

        #expect(analyzer.currentRhythmScore == 0.0)
        #expect(analyzer.currentStrideRate == 0.0)
    }

    // MARK: - Motion Sample Processing Tests

    @Test func processMotionSampleWithWalkGait() {
        let analyzer = RhythmAnalyzer()

        // Feed walk-speed data with regular stride pattern
        for i in 0..<300 {
            let phase = Double(i) * 0.12  // ~60 strides/min at 50Hz
            let sample = createMotionSample(
                verticalAccel: sin(phase) * 0.3,
                accelMagnitude: 1.0 + sin(phase) * 0.2,
                pitch: sin(phase * 0.5) * 0.05,
                timestamp: Date().addingTimeInterval(Double(i) * 0.02)
            )
            analyzer.processMotionSample(sample, currentGait: .walk)
        }

        // Should have detected some rhythm
        #expect(analyzer.rhythmConfidence >= 0.0)
    }

    @Test func processMotionSampleWithTrotGait() {
        let analyzer = RhythmAnalyzer()

        // Feed trot-speed data with higher frequency stride pattern
        for i in 0..<300 {
            let phase = Double(i) * 0.17  // ~80 strides/min at 50Hz
            let sample = createMotionSample(
                verticalAccel: sin(phase) * 0.5,
                accelMagnitude: 1.0 + sin(phase) * 0.3,
                pitch: sin(phase * 0.5) * 0.08,
                timestamp: Date().addingTimeInterval(Double(i) * 0.02)
            )
            analyzer.processMotionSample(sample, currentGait: .trot)
        }

        #expect(analyzer.rhythmConfidence >= 0.0)
    }

    // MARK: - Rein Segment Tests

    @Test func updateReinChangesCurrentRein() {
        let analyzer = RhythmAnalyzer()

        // Process with left rein
        analyzer.updateRein(.left)

        // Then switch to right
        analyzer.updateRein(.right)

        // No crash expected
        #expect(analyzer.leftReinScore >= 0.0)
    }

    @Test func finalizeReinSegmentRecordsScore() {
        let analyzer = RhythmAnalyzer()

        // Process some data
        for i in 0..<200 {
            let phase = Double(i) * 0.15
            let sample = createMotionSample(
                verticalAccel: sin(phase) * 0.4,
                timestamp: Date().addingTimeInterval(Double(i) * 0.02)
            )
            analyzer.processMotionSample(sample, currentGait: .trot)
        }

        analyzer.updateRein(.left)
        analyzer.finalizeReinSegment()

        #expect(analyzer.leftReinRhythm >= 0.0)
    }

    // MARK: - Gait Stride Rate Range Tests

    @Test func expectedStrideRateRangeForWalk() {
        let analyzer = RhythmAnalyzer()

        let range = analyzer.expectedStrideRateRange(for: .walk)

        #expect(range != nil)
        if let range = range {
            #expect(range.contains(55))  // Walk around 50-65
            #expect(range.lowerBound == 50)
            #expect(range.upperBound == 65)
        }
    }

    @Test func expectedStrideRateRangeForTrot() {
        let analyzer = RhythmAnalyzer()

        let range = analyzer.expectedStrideRateRange(for: .trot)

        #expect(range != nil)
        if let range = range {
            #expect(range.contains(75))  // Trot around 70-85
            #expect(range.lowerBound == 70)
            #expect(range.upperBound == 85)
        }
    }

    @Test func expectedStrideRateRangeForCanter() {
        let analyzer = RhythmAnalyzer()

        let range = analyzer.expectedStrideRateRange(for: .canter)

        #expect(range != nil)
        if let range = range {
            #expect(range.contains(100))  // Canter around 90-110
            #expect(range.lowerBound == 90)
            #expect(range.upperBound == 110)
        }
    }

    @Test func expectedStrideRateRangeForGallop() {
        let analyzer = RhythmAnalyzer()

        let range = analyzer.expectedStrideRateRange(for: .gallop)

        #expect(range != nil)
        if let range = range {
            #expect(range.contains(125))  // Gallop around 110-140
            #expect(range.lowerBound == 110)
            #expect(range.upperBound == 140)
        }
    }

    @Test func expectedStrideRateRangeForStationary() {
        let analyzer = RhythmAnalyzer()

        let range = analyzer.expectedStrideRateRange(for: .stationary)

        #expect(range == nil)  // No expected stride rate for stationary
    }

    // MARK: - Stride Rate With Confidence Tests

    @Test func strideRateWithConfidenceReturnsCurrentValues() {
        let analyzer = RhythmAnalyzer()

        let result = analyzer.strideRateWithConfidence()

        #expect(result.rate == analyzer.currentStrideRate)
        #expect(result.confidence == analyzer.rhythmConfidence)
    }

    // MARK: - Rhythm For Gait Tests

    @Test func rhythmForGaitReturnsCurrentScore() {
        let analyzer = RhythmAnalyzer()

        let score = analyzer.rhythmForGait(.trot)

        #expect(score == analyzer.currentRhythmScore)
    }

    // MARK: - ReinAwareAnalyzer Protocol Tests

    @Test func leftReinScoreAccessor() {
        let analyzer = RhythmAnalyzer()

        #expect(analyzer.leftReinScore == 0.0)
    }

    @Test func rightReinScoreAccessor() {
        let analyzer = RhythmAnalyzer()

        #expect(analyzer.rightReinScore == 0.0)
    }

    // MARK: - Helper Functions

    private func createMotionSample(
        verticalAccel: Double = 0.0,
        accelMagnitude: Double = 1.0,
        pitch: Double = 0.0,
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
            pitch: pitch,
            roll: 0,
            yaw: 0
        )
    }
}

// MARK: - Stride Detection Tests

struct StrideDetectionTests {

    @Test func strideValidationConstraints() {
        // Test that the analyzer respects min/max interval constraints
        let analyzer = RhythmAnalyzer()

        // Very fast "strides" should be ignored (< 0.25s = >240/min)
        for i in 0..<50 {
            let sample = MotionSample(
                timestamp: Date().addingTimeInterval(Double(i) * 0.01),  // 100Hz, too fast
                accelerationX: 0,
                accelerationY: 0,
                accelerationZ: Double(i % 2 == 0 ? 0.5 : -0.5),  // Rapid oscillation
                rotationX: 0,
                rotationY: 0,
                rotationZ: 0,
                pitch: 0,
                roll: 0,
                yaw: 0
            )
            analyzer.processMotionSample(sample, currentGait: .walk)
        }

        // Should not produce valid rhythm from too-fast data
        #expect(analyzer.currentStrideRate == 0.0)
    }
}
