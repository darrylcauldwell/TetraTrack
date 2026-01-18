//
//  FFTProcessor.swift
//  TrackRide
//
//  vDSP-based FFT for real-time spectral analysis of motion signals
//

import Foundation
import Accelerate

/// Result of FFT analysis on a signal window
struct FFTResult {
    let dominantFrequency: Double
    let powerAtF0: Double
    let h2Ratio: Double
    let h3Ratio: Double
    let spectralEntropy: Double
    let frequencyResolution: Double
}

/// vDSP-based FFT processor optimized for real-time gait analysis
final class FFTProcessor {

    // MARK: - Configuration

    let windowSize: Int
    let sampleRate: Double
    let frequencyResolution: Double

    // MARK: - vDSP Setup

    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup
    private var window: [Float]

    // Pre-allocated buffers for efficiency
    private var realBuffer: [Float]
    private var imagBuffer: [Float]
    private var magnitudes: [Float]

    // MARK: - Initialization

    /// Initialize FFT processor
    /// - Parameters:
    ///   - windowSize: Number of samples per window (must be power of 2, default 256)
    ///   - sampleRate: Sample rate in Hz (default 100)
    init(windowSize: Int = 256, sampleRate: Double = 100.0) {
        precondition(windowSize > 0 && (windowSize & (windowSize - 1)) == 0, "Window size must be power of 2")

        self.windowSize = windowSize
        self.sampleRate = sampleRate
        self.frequencyResolution = sampleRate / Double(windowSize)

        self.log2n = vDSP_Length(log2(Double(windowSize)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!

        // Create Hanning window
        self.window = [Float](repeating: 0, count: windowSize)
        vDSP_hann_window(&window, vDSP_Length(windowSize), Int32(vDSP_HANN_NORM))

        // Pre-allocate buffers
        let halfSize = windowSize / 2
        self.realBuffer = [Float](repeating: 0, count: halfSize)
        self.imagBuffer = [Float](repeating: 0, count: halfSize)
        self.magnitudes = [Float](repeating: 0, count: halfSize)
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    // MARK: - FFT Processing

    /// Process a window of samples and return spectral analysis
    /// - Parameter samples: Array of samples (must match windowSize)
    /// - Returns: FFT analysis result
    func processWindow(_ samples: [Double]) -> FFTResult {
        guard samples.count >= windowSize else {
            return FFTResult(
                dominantFrequency: 0,
                powerAtF0: 0,
                h2Ratio: 0,
                h3Ratio: 0,
                spectralEntropy: 0,
                frequencyResolution: frequencyResolution
            )
        }

        // Convert to Float and take last windowSize samples
        var floatSamples = samples.suffix(windowSize).map { Float($0) }

        // Apply Hanning window
        vDSP_vmul(floatSamples, 1, window, 1, &floatSamples, 1, vDSP_Length(windowSize))

        // Perform FFT
        let halfSize = windowSize / 2

        realBuffer = [Float](repeating: 0, count: halfSize)
        imagBuffer = [Float](repeating: 0, count: halfSize)

        realBuffer.withUnsafeMutableBufferPointer { realPtr in
            imagBuffer.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)

                floatSamples.withUnsafeBufferPointer { samplesPtr in
                    samplesPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(halfSize))
                    }
                }

                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))

                // Compute magnitudes (power spectrum)
                magnitudes = [Float](repeating: 0, count: halfSize)
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(halfSize))
            }
        }

        // Scale magnitudes
        var scale = Float(1.0 / Float(windowSize * windowSize))
        vDSP_vsmul(magnitudes, 1, &scale, &magnitudes, 1, vDSP_Length(magnitudes.count))

        // Find dominant frequency in gait range (0.5 - 6 Hz)
        let (f0, powerAtF0) = findDominantFrequency(inRange: 0.5...6.0)

        // Compute harmonic ratios
        let h2Ratio = computeHarmonicRatio(fundamental: f0, harmonic: 2)
        let h3Ratio = computeHarmonicRatio(fundamental: f0, harmonic: 3)

        // Compute spectral entropy
        let entropy = computeSpectralEntropy()

        return FFTResult(
            dominantFrequency: f0,
            powerAtF0: powerAtF0,
            h2Ratio: h2Ratio,
            h3Ratio: h3Ratio,
            spectralEntropy: entropy,
            frequencyResolution: frequencyResolution
        )
    }

    /// Find the dominant frequency within a specified range
    /// - Parameter range: Frequency range to search (Hz)
    /// - Returns: Tuple of (frequency, power)
    func findDominantFrequency(inRange range: ClosedRange<Double>) -> (frequency: Double, power: Double) {
        let minBin = max(1, Int(range.lowerBound / frequencyResolution))
        let maxBin = min(magnitudes.count - 1, Int(range.upperBound / frequencyResolution))

        guard minBin < maxBin else { return (0, 0) }

        var maxPower: Float = 0
        var maxIndex: Int = minBin

        for i in minBin...maxBin {
            if magnitudes[i] > maxPower {
                maxPower = magnitudes[i]
                maxIndex = i
            }
        }

        // Quadratic interpolation for sub-bin accuracy
        let frequency = interpolatePeak(at: maxIndex)

        return (frequency, Double(maxPower))
    }

    /// Compute harmonic ratio (power at n*f0 / power at f0)
    /// - Parameters:
    ///   - fundamental: Fundamental frequency f0
    ///   - harmonic: Harmonic number (2 for H2, 3 for H3)
    /// - Returns: Harmonic ratio
    func computeHarmonicRatio(fundamental f0: Double, harmonic n: Int) -> Double {
        guard f0 > 0 else { return 0 }

        let fundamentalBin = Int(f0 / frequencyResolution)
        let harmonicBin = Int(Double(n) * f0 / frequencyResolution)

        guard fundamentalBin > 0 && fundamentalBin < magnitudes.count &&
              harmonicBin > 0 && harmonicBin < magnitudes.count else {
            return 0
        }

        let fundamentalPower = Double(magnitudes[fundamentalBin])
        let harmonicPower = Double(magnitudes[harmonicBin])

        guard fundamentalPower > 1e-10 else { return 0 }

        return harmonicPower / fundamentalPower
    }

    /// Compute spectral entropy (measure of signal complexity)
    /// - Returns: Normalized entropy (0 = pure tone, 1 = white noise)
    func computeSpectralEntropy() -> Double {
        // Compute probability distribution from power spectrum
        var totalPower: Float = 0
        vDSP_sve(magnitudes, 1, &totalPower, vDSP_Length(magnitudes.count))

        guard totalPower > 1e-10 else { return 0 }

        // Compute entropy: -sum(p * log(p))
        var entropy: Double = 0
        for magnitude in magnitudes {
            let p = Double(magnitude) / Double(totalPower)
            if p > 1e-10 {
                entropy -= p * log2(p)
            }
        }

        // Normalize by maximum entropy (log2(N))
        let maxEntropy = log2(Double(magnitudes.count))
        return entropy / maxEntropy
    }

    /// Get power spectrum as array of (frequency, power) pairs
    func getPowerSpectrum() -> [(frequency: Double, power: Double)] {
        return magnitudes.enumerated().map { index, magnitude in
            (Double(index) * frequencyResolution, Double(magnitude))
        }
    }

    // MARK: - Private Helpers

    /// Quadratic interpolation around a peak for sub-bin frequency accuracy
    private func interpolatePeak(at index: Int) -> Double {
        guard index > 0 && index < magnitudes.count - 1 else {
            return Double(index) * frequencyResolution
        }

        let alpha = Double(magnitudes[index - 1])
        let beta = Double(magnitudes[index])
        let gamma = Double(magnitudes[index + 1])

        // Quadratic interpolation
        let denominator = alpha - 2 * beta + gamma
        guard abs(denominator) > 1e-10 else {
            return Double(index) * frequencyResolution
        }

        let delta = 0.5 * (alpha - gamma) / denominator
        return (Double(index) + delta) * frequencyResolution
    }
}

// MARK: - Windowed Analysis

extension FFTProcessor {

    /// Process a stream of samples with overlapping windows
    /// - Parameters:
    ///   - samples: Complete sample buffer
    ///   - overlap: Overlap factor (0.8 = 80% overlap)
    /// - Returns: Array of FFT results for each window
    func processWithOverlap(_ samples: [Double], overlap: Double = 0.8) -> [FFTResult] {
        let hopSize = Int(Double(windowSize) * (1.0 - overlap))
        var results: [FFTResult] = []

        var startIndex = 0
        while startIndex + windowSize <= samples.count {
            let window = Array(samples[startIndex..<(startIndex + windowSize)])
            results.append(processWindow(window))
            startIndex += hopSize
        }

        return results
    }
}
