//
//  FFTProcessorTests.swift
//  TetraTrackTests
//
//  Tests for FFTProcessor DSP component using synthetic signals
//

import Testing
import Foundation
@testable import TetraTrack

// MARK: - Helpers

/// Generate a sine wave at a given frequency
private func generateSineWave(
    frequency: Double,
    amplitude: Double = 1.0,
    sampleRate: Double = 100.0,
    sampleCount: Int = 256
) -> [Double] {
    (0..<sampleCount).map { i in
        amplitude * sin(2.0 * .pi * frequency * Double(i) / sampleRate)
    }
}

/// Generate white-ish noise using a simple LCG
private func generateNoise(sampleCount: Int = 256, seed: UInt64 = 42) -> [Double] {
    var state = seed
    return (0..<sampleCount).map { _ in
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(Int64(bitPattern: state >> 33)) / Double(Int64.max)
    }
}

// MARK: - FFTProcessorTests

struct FFTProcessorTests {

    let processor = FFTProcessor(windowSize: 256, sampleRate: 100.0)

    // MARK: - Initialization

    @Test func processorInitialization() {
        #expect(processor.windowSize == 256)
        #expect(processor.sampleRate == 100.0)
        // frequencyResolution = sampleRate / windowSize = 100/256 ≈ 0.390625
        #expect(abs(processor.frequencyResolution - 100.0 / 256.0) < 0.001)
    }

    // MARK: - Pure Sine Wave Detection

    @Test func pureSineWaveAt2Hz() {
        let signal = generateSineWave(frequency: 2.0, sampleRate: 100.0, sampleCount: 256)
        let result = processor.processWindow(signal)

        // Should detect dominant frequency near 2 Hz
        #expect(abs(result.dominantFrequency - 2.0) < 0.5)
        #expect(result.powerAtF0 > 0)
    }

    @Test func pureSineWaveAt3Hz() {
        let signal = generateSineWave(frequency: 3.0, sampleRate: 100.0, sampleCount: 256)
        let result = processor.processWindow(signal)

        #expect(abs(result.dominantFrequency - 3.0) < 0.5)
    }

    @Test func pureSineWaveAt1Hz() {
        let signal = generateSineWave(frequency: 1.0, sampleRate: 100.0, sampleCount: 256)
        let result = processor.processWindow(signal)

        #expect(abs(result.dominantFrequency - 1.0) < 0.5)
    }

    // MARK: - DC Offset Removal

    @Test func dcOffsetRemoval() {
        // Signal = DC offset + 2 Hz sine
        let signal = generateSineWave(frequency: 2.0, sampleRate: 100.0, sampleCount: 256)
            .map { $0 + 5.0 }  // Add large DC offset

        let result = processor.processWindow(signal)

        // Should still find the 2 Hz component, not the DC
        #expect(abs(result.dominantFrequency - 2.0) < 0.5)
    }

    // MARK: - Harmonic Ratios

    @Test func multiHarmonicSignal() {
        // Fundamental at 2 Hz + 2nd harmonic at 4 Hz + 3rd harmonic at 6 Hz
        let samples = (0..<256).map { i -> Double in
            let t = Double(i) / 100.0
            let fundamental = 1.0 * sin(2.0 * .pi * 2.0 * t)
            let h2 = 0.6 * sin(2.0 * .pi * 4.0 * t)
            let h3 = 0.3 * sin(2.0 * .pi * 6.0 * t)
            return fundamental + h2 + h3
        }

        let result = processor.processWindow(samples)

        // Dominant should be near 2 Hz
        #expect(abs(result.dominantFrequency - 2.0) < 0.5)
        // H2 ratio should be significant (not zero)
        #expect(result.h2Ratio > 0.1)
        // H3 ratio should be present
        #expect(result.h3Ratio > 0.01)
    }

    @Test func harmonicRatioForPureTone() {
        // Pure tone at 2 Hz should have low harmonic ratios
        let signal = generateSineWave(frequency: 2.0, sampleRate: 100.0, sampleCount: 256)
        let result = processor.processWindow(signal)

        // H2 and H3 should be low for a pure tone (no harmonics)
        #expect(result.h2Ratio < 0.5)
        #expect(result.h3Ratio < 0.5)
    }

    // MARK: - Spectral Entropy

    @Test func spectralEntropyPureTone() {
        // Pure tone = concentrated energy = low entropy
        let signal = generateSineWave(frequency: 2.0, amplitude: 1.0, sampleRate: 100.0, sampleCount: 256)
        let result = processor.processWindow(signal)

        #expect(result.spectralEntropy < 0.4)
    }

    @Test func spectralEntropyNoise() {
        // Noise = spread energy = high entropy
        let noise = generateNoise(sampleCount: 256)
        let result = processor.processWindow(noise)

        #expect(result.spectralEntropy > 0.5)
    }

    // MARK: - Band Filtering

    @Test func findDominantFrequencyInRange() {
        // Signal has 1 Hz and 4 Hz components
        let samples = (0..<256).map { i -> Double in
            let t = Double(i) / 100.0
            return 1.0 * sin(2.0 * .pi * 1.0 * t) + 0.8 * sin(2.0 * .pi * 4.0 * t)
        }

        // Process to fill magnitudes buffer
        _ = processor.processWindow(samples)

        // Search only in 3-5 Hz range should find ~4 Hz
        let (freq, power) = processor.findDominantFrequency(inRange: 3.0...5.0)
        #expect(abs(freq - 4.0) < 0.5)
        #expect(power > 0)
    }

    // MARK: - Overlap Processing

    @Test func processWithOverlapWindowCount() {
        // 512 samples with 256-sample window at 80% overlap (hop = 51)
        // Number of windows = floor((512 - 256) / 51) + 1 = floor(256/51) + 1 = 5 + 1 = 6
        let signal = generateSineWave(frequency: 2.0, sampleRate: 100.0, sampleCount: 512)
        let results = processor.processWithOverlap(signal, overlap: 0.8)

        #expect(results.count > 1)
        // Each result should have found ~2 Hz
        for result in results {
            #expect(abs(result.dominantFrequency - 2.0) < 1.0)
        }
    }

    @Test func processWithOverlapNoOverlap() {
        // 512 samples, no overlap: should get exactly 2 windows
        let signal = generateSineWave(frequency: 2.0, sampleRate: 100.0, sampleCount: 512)
        let results = processor.processWithOverlap(signal, overlap: 0.0)

        #expect(results.count == 2)
    }

    // MARK: - Edge Cases

    @Test func fewerSamplesThanWindowSize() {
        // Only 100 samples, window needs 256
        let signal = generateSineWave(frequency: 2.0, sampleRate: 100.0, sampleCount: 100)
        let result = processor.processWindow(signal)

        // Should return zero result (not crash)
        #expect(result.dominantFrequency == 0)
        #expect(result.powerAtF0 == 0)
    }

    @Test func zeroAmplitudeSignal() {
        let signal = [Double](repeating: 0.0, count: 256)
        let result = processor.processWindow(signal)

        // Should handle gracefully
        #expect(result.dominantFrequency >= 0)
        #expect(result.spectralEntropy >= 0)
    }

    @Test func powerSpectrumLength() {
        let signal = generateSineWave(frequency: 2.0, sampleRate: 100.0, sampleCount: 256)
        _ = processor.processWindow(signal)

        let spectrum = processor.getPowerSpectrum()
        // Should have windowSize/2 = 128 bins
        #expect(spectrum.count == 128)
    }
}
