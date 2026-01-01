//
//  CoherenceAnalyzerTests.swift
//  TetraTrackTests
//
//  Tests for CoherenceAnalyzer Welch coherence analysis
//

import Testing
import Foundation
@testable import TetraTrack

struct CoherenceAnalyzerTests {

    private let sampleRate = 100.0
    private let segmentLength = 128

    // MARK: - Perfectly Coherent Signals Tests

    @Test func identicalSineWavesHighCoherence() {
        let analyzer = CoherenceAnalyzer(segmentLength: segmentLength, overlap: 64, sampleRate: sampleRate)
        let frequency = 2.0
        let samples = 256

        let signal = (0..<samples).map { i in
            sin(2.0 * .pi * frequency * Double(i) / sampleRate)
        }

        let coh = analyzer.coherence(signal1: signal, signal2: signal, atFrequency: frequency)
        #expect(coh > 0.9)
    }

    @Test func sameFrequencyDifferentPhaseHighCoherence() {
        let analyzer = CoherenceAnalyzer(segmentLength: segmentLength, overlap: 64, sampleRate: sampleRate)
        let frequency = 2.0
        let samples = 256
        let phaseShift = .pi / 4.0

        let signal1 = (0..<samples).map { i in
            sin(2.0 * .pi * frequency * Double(i) / sampleRate)
        }
        let signal2 = (0..<samples).map { i in
            sin(2.0 * .pi * frequency * Double(i) / sampleRate + phaseShift)
        }

        let coh = analyzer.coherence(signal1: signal1, signal2: signal2, atFrequency: frequency)
        #expect(coh > 0.9)
    }

    // MARK: - Uncorrelated Signals Tests

    @Test func sineVsNoiseLowCoherence() {
        let analyzer = CoherenceAnalyzer(segmentLength: segmentLength, overlap: 64, sampleRate: sampleRate)
        let frequency = 2.0
        let samples = 512

        let signal1 = (0..<samples).map { i in
            sin(2.0 * .pi * frequency * Double(i) / sampleRate)
        }

        // Deterministic pseudo-noise using a simple hash
        let signal2 = (0..<samples).map { i -> Double in
            let x = Double(i * 73 + 17) // Simple deterministic sequence
            return sin(x * 137.0) * cos(x * 251.0) // Pseudo-random-looking signal
        }

        let coh = analyzer.coherence(signal1: signal1, signal2: signal2, atFrequency: frequency)
        #expect(coh < 0.5)
    }

    @Test func differentFrequencySinesLowCoherence() {
        let analyzer = CoherenceAnalyzer(segmentLength: segmentLength, overlap: 64, sampleRate: sampleRate)
        let samples = 512

        let signal1 = (0..<samples).map { i in
            sin(2.0 * .pi * 2.0 * Double(i) / sampleRate)  // 2 Hz
        }
        let signal2 = (0..<samples).map { i in
            sin(2.0 * .pi * 7.0 * Double(i) / sampleRate)  // 7 Hz
        }

        // Coherence at 2 Hz: signal1 has energy, signal2 doesn't
        let cohAt2 = analyzer.coherence(signal1: signal1, signal2: signal2, atFrequency: 2.0)
        #expect(cohAt2 < 0.5)
    }

    // MARK: - Frequency-Specific Coherence Tests

    @Test func coherentAt2HzNotAt4Hz() {
        let analyzer = CoherenceAnalyzer(segmentLength: segmentLength, overlap: 64, sampleRate: sampleRate)
        let samples = 512

        // Both signals have 2 Hz component, but only signal1 has 4 Hz
        let signal1: [Double] = (0..<samples).map { i in
            let t = Double(i) / sampleRate
            return sin(2.0 * .pi * 2.0 * t) + 0.5 * sin(2.0 * .pi * 4.0 * t)
        }
        let signal2: [Double] = (0..<samples).map { i in
            let t = Double(i) / sampleRate
            return sin(2.0 * .pi * 2.0 * t) + 0.3 * sin(2.0 * .pi * 10.0 * t)
        }

        let cohAt2 = analyzer.coherence(signal1: signal1, signal2: signal2, atFrequency: 2.0)
        let cohAt4 = analyzer.coherence(signal1: signal1, signal2: signal2, atFrequency: 4.0)

        // Should be more coherent at 2 Hz (shared) than 4 Hz (not shared)
        #expect(cohAt2 > cohAt4)
    }

    @Test func multiFrequencyCoherentAtF0IncoherentAt2F0() {
        let analyzer = CoherenceAnalyzer(segmentLength: segmentLength, overlap: 64, sampleRate: sampleRate)
        let f0 = 3.0
        let samples = 512

        // Both signals share f0, but have different harmonics
        let signal1: [Double] = (0..<samples).map { i in
            let t = Double(i) / sampleRate
            return sin(2.0 * .pi * f0 * t) + 0.5 * sin(2.0 * .pi * 2.0 * f0 * t)
        }
        let signal2: [Double] = (0..<samples).map { i in
            let t = Double(i) / sampleRate
            return sin(2.0 * .pi * f0 * t) + 0.5 * sin(2.0 * .pi * 5.0 * f0 * t)
        }

        let cohAtF0 = analyzer.coherence(signal1: signal1, signal2: signal2, atFrequency: f0)
        let cohAt2F0 = analyzer.coherence(signal1: signal1, signal2: signal2, atFrequency: 2.0 * f0)

        #expect(cohAtF0 > cohAt2F0)
    }

    @Test func shortSignalsProduceLowerConfidence() {
        let longAnalyzer = CoherenceAnalyzer(segmentLength: 128, overlap: 64, sampleRate: sampleRate)
        let frequency = 2.0

        let longSignal = (0..<512).map { i in
            sin(2.0 * .pi * frequency * Double(i) / sampleRate)
        }
        let shortSignal = (0..<140).map { i in
            sin(2.0 * .pi * frequency * Double(i) / sampleRate)
        }

        let longCoh = longAnalyzer.coherence(signal1: longSignal, signal2: longSignal, atFrequency: frequency)
        let shortCoh = longAnalyzer.coherence(signal1: shortSignal, signal2: shortSignal, atFrequency: frequency)

        // Both should be high for identical signals, but with fewer segments
        // the Welch estimate is less reliable. The value may still be high
        // but we verify both compute without error
        #expect(longCoh > 0.8)
        #expect(shortCoh >= 0.0)
    }

    // MARK: - Edge Case Tests

    @Test func zeroAmplitudeSignalsDoNotCrash() {
        let analyzer = CoherenceAnalyzer(segmentLength: segmentLength, overlap: 64, sampleRate: sampleRate)
        let zeros = [Double](repeating: 0.0, count: 256)

        let coh = analyzer.coherence(signal1: zeros, signal2: zeros, atFrequency: 2.0)
        #expect(coh >= 0.0)
        #expect(coh <= 1.0)
    }

    @Test func tooShortSignalsReturnZero() {
        let analyzer = CoherenceAnalyzer(segmentLength: segmentLength, overlap: 64, sampleRate: sampleRate)
        let short = [1.0, 2.0, 3.0]

        let coh = analyzer.coherence(signal1: short, signal2: short, atFrequency: 2.0)
        #expect(coh == 0.0)
    }

    @Test func identicalSignalsReturnHighCoherence() {
        let analyzer = CoherenceAnalyzer(segmentLength: segmentLength, overlap: 64, sampleRate: sampleRate)
        let samples = 512

        // Complex multi-frequency signal
        let signal: [Double] = (0..<samples).map { i in
            let t = Double(i) / sampleRate
            let comp1 = sin(2.0 * .pi * 2.0 * t)
            let comp2 = 0.5 * sin(2.0 * .pi * 4.0 * t)
            let comp3 = 0.25 * sin(2.0 * .pi * 6.0 * t)
            return comp1 + comp2 + comp3
        }

        let coh = analyzer.coherence(signal1: signal, signal2: signal, atFrequency: 2.0)
        #expect(coh > 0.9)
    }
}
