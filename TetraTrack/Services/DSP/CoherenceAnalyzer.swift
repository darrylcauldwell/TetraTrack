//
//  CoherenceAnalyzer.swift
//  TetraTrack
//
//  Welch coherence analysis for measuring signal coupling and symmetry
//

import Foundation
import Accelerate

/// Welch coherence analyzer for measuring coupling between two signals
/// Used for:
/// - X-Y coherence: left-right symmetry measure
/// - Z-yaw coherence: vertical-rotational coupling (canter/gallop signature)
final class CoherenceAnalyzer {

    // MARK: - Configuration

    let segmentLength: Int
    let overlap: Int
    let sampleRate: Double

    private let fftProcessor: FFTProcessor
    private let frequencyResolution: Double

    /// Cached FFT setup to avoid allocation/deallocation overhead per call
    /// Creating/destroying FFT setup on every call is expensive and can affect real-time performance
    private let fftSetup: OpaquePointer?
    private let log2n: vDSP_Length

    /// Pre-allocated Hanning window
    private let windowDouble: [Double]

    // MARK: - Initialization

    /// Initialize coherence analyzer
    /// - Parameters:
    ///   - segmentLength: Length of each Welch segment (default 128)
    ///   - overlap: Number of overlapping samples (default 64 = 50%)
    ///   - sampleRate: Sample rate in Hz (default 100)
    init(segmentLength: Int = 128, overlap: Int = 64, sampleRate: Double = 100.0) {
        self.segmentLength = segmentLength
        self.overlap = overlap
        self.sampleRate = sampleRate
        self.frequencyResolution = sampleRate / Double(segmentLength)

        // Use FFT processor with segment length
        self.fftProcessor = FFTProcessor(windowSize: segmentLength, sampleRate: sampleRate)

        // Pre-compute and cache FFT setup (expensive operation)
        self.log2n = vDSP_Length(log2(Double(segmentLength)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))

        // Pre-compute Hanning window
        var window = [Float](repeating: 0, count: segmentLength)
        vDSP_hann_window(&window, vDSP_Length(segmentLength), Int32(vDSP_HANN_NORM))
        self.windowDouble = window.map { Double($0) }
    }

    deinit {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }

    // MARK: - Coherence Computation

    /// Compute magnitude-squared coherence at a specific frequency
    /// Coherence ranges from 0 (no correlation) to 1 (perfect correlation)
    /// - Parameters:
    ///   - signal1: First signal
    ///   - signal2: Second signal
    ///   - frequency: Target frequency in Hz
    /// - Returns: Coherence value (0-1)
    func coherence(signal1: [Double], signal2: [Double], atFrequency frequency: Double) -> Double {
        let minLength = min(signal1.count, signal2.count)
        guard minLength >= segmentLength else { return 0 }

        // Compute Welch spectra
        let (pxx, pyy, pxy) = computeWelchSpectra(signal1: Array(signal1.prefix(minLength)),
                                                   signal2: Array(signal2.prefix(minLength)))

        // Find frequency bin
        let bin = Int(frequency / frequencyResolution)
        guard bin > 0 && bin < pxx.count else { return 0 }

        // Coherence = |Pxy|^2 / (Pxx * Pyy)
        let pxxVal = pxx[bin]
        let pyyVal = pyy[bin]
        let pxyMagSq = pxy[bin].real * pxy[bin].real + pxy[bin].imag * pxy[bin].imag

        guard pxxVal > 1e-10 && pyyVal > 1e-10 else { return 0 }

        let coherence = pxyMagSq / (pxxVal * pyyVal)
        return min(1.0, max(0.0, coherence))
    }

    /// Compute coherence spectrum across all frequencies
    /// - Parameters:
    ///   - signal1: First signal
    ///   - signal2: Second signal
    /// - Returns: Array of (frequency, coherence) pairs
    func coherenceSpectrum(signal1: [Double], signal2: [Double]) -> [(frequency: Double, coherence: Double)] {
        let minLength = min(signal1.count, signal2.count)
        guard minLength >= segmentLength else { return [] }

        let (pxx, pyy, pxy) = computeWelchSpectra(signal1: Array(signal1.prefix(minLength)),
                                                   signal2: Array(signal2.prefix(minLength)))

        var spectrum: [(Double, Double)] = []
        spectrum.reserveCapacity(pxx.count)

        for i in 0..<pxx.count {
            let freq = Double(i) * frequencyResolution
            let pxxVal = pxx[i]
            let pyyVal = pyy[i]
            let pxyMagSq = pxy[i].real * pxy[i].real + pxy[i].imag * pxy[i].imag

            var coh = 0.0
            if pxxVal > 1e-10 && pyyVal > 1e-10 {
                coh = min(1.0, max(0.0, pxyMagSq / (pxxVal * pyyVal)))
            }

            spectrum.append((freq, coh))
        }

        return spectrum
    }

    /// Compute average coherence in a frequency band
    /// - Parameters:
    ///   - signal1: First signal
    ///   - signal2: Second signal
    ///   - frequencyRange: Frequency range to average over
    /// - Returns: Average coherence in the band
    func averageCoherence(signal1: [Double], signal2: [Double], inRange frequencyRange: ClosedRange<Double>) -> Double {
        let spectrum = coherenceSpectrum(signal1: signal1, signal2: signal2)

        let inBand = spectrum.filter { frequencyRange.contains($0.frequency) }
        guard !inBand.isEmpty else { return 0 }

        return inBand.reduce(0) { $0 + $1.coherence } / Double(inBand.count)
    }

    // MARK: - Cross-Spectral Density

    /// Compute cross-spectral density between two signals
    /// - Parameters:
    ///   - signal1: First signal
    ///   - signal2: Second signal
    /// - Returns: Complex cross-spectral density
    func crossSpectralDensity(signal1: [Double], signal2: [Double]) -> [(real: Double, imag: Double)] {
        let (_, _, pxy) = computeWelchSpectra(signal1: signal1, signal2: signal2)
        return pxy
    }

    /// Compute power spectral density of a signal
    /// - Parameter signal: Input signal
    /// - Returns: Power spectral density array
    func powerSpectralDensity(_ signal: [Double]) -> [Double] {
        let (pxx, _, _) = computeWelchSpectra(signal1: signal, signal2: signal)
        return pxx
    }

    // MARK: - Phase Analysis

    /// Compute cross-spectral phase at a specific frequency
    /// - Parameters:
    ///   - signal1: First signal
    ///   - signal2: Second signal
    ///   - frequency: Target frequency in Hz
    /// - Returns: Phase difference in radians
    func crossSpectralPhase(signal1: [Double], signal2: [Double], atFrequency frequency: Double) -> Double {
        let pxy = crossSpectralDensity(signal1: signal1, signal2: signal2)

        let bin = Int(frequency / frequencyResolution)
        guard bin > 0 && bin < pxy.count else { return 0 }

        return atan2(pxy[bin].imag, pxy[bin].real)
    }

    // MARK: - Private Implementation

    /// Compute Welch spectra for two signals
    private func computeWelchSpectra(signal1: [Double], signal2: [Double]) -> (pxx: [Double], pyy: [Double], pxy: [(real: Double, imag: Double)]) {
        let minLength = min(signal1.count, signal2.count)
        guard minLength >= segmentLength else {
            return ([], [], [])
        }

        // Calculate number of segments
        let hopSize = segmentLength - overlap
        let numSegments = max(1, (minLength - segmentLength) / hopSize + 1)

        let halfSize = segmentLength / 2

        // Accumulate spectra
        var pxxSum = [Double](repeating: 0, count: halfSize)
        var pyySum = [Double](repeating: 0, count: halfSize)
        var pxyRealSum = [Double](repeating: 0, count: halfSize)
        var pxyImagSum = [Double](repeating: 0, count: halfSize)

        // Use pre-computed Hanning window (cached in init)

        // Process each segment
        for segIdx in 0..<numSegments {
            let startIdx = segIdx * hopSize
            let endIdx = startIdx + segmentLength

            guard endIdx <= minLength else { break }

            // Extract and window segments
            var seg1 = Array(signal1[startIdx..<endIdx])
            var seg2 = Array(signal2[startIdx..<endIdx])

            for i in 0..<segmentLength {
                seg1[i] *= windowDouble[i]
                seg2[i] *= windowDouble[i]
            }

            // Compute FFTs using cached setup
            let fft1 = computeFFT(seg1)
            let fft2 = computeFFT(seg2)

            // Accumulate power and cross-spectra
            for i in 0..<halfSize {
                // Pxx = |X|^2
                pxxSum[i] += fft1[i].real * fft1[i].real + fft1[i].imag * fft1[i].imag

                // Pyy = |Y|^2
                pyySum[i] += fft2[i].real * fft2[i].real + fft2[i].imag * fft2[i].imag

                // Pxy = X * conj(Y)
                pxyRealSum[i] += fft1[i].real * fft2[i].real + fft1[i].imag * fft2[i].imag
                pxyImagSum[i] += fft1[i].imag * fft2[i].real - fft1[i].real * fft2[i].imag
            }
        }

        // Average over segments
        let scale = 1.0 / Double(numSegments)
        let pxx = pxxSum.map { $0 * scale }
        let pyy = pyySum.map { $0 * scale }
        let pxy = zip(pxyRealSum, pxyImagSum).map { (real: $0 * scale, imag: $1 * scale) }

        return (pxx, pyy, pxy)
    }

    /// Compute FFT of a windowed segment using cached setup
    private func computeFFT(_ segment: [Double]) -> [(real: Double, imag: Double)] {
        let n = segment.count
        guard n > 1 else { return segment.map { ($0, 0) } }

        // Use cached FFT setup - don't create/destroy per call
        guard let setup = fftSetup, n == segmentLength else {
            // Fallback for mismatched sizes (shouldn't happen in normal use)
            return computeFFTFallback(segment)
        }

        let floatSegment = segment.map { Float($0) }
        let halfSize = n / 2

        var realBuffer = [Float](repeating: 0, count: halfSize)
        var imagBuffer = [Float](repeating: 0, count: halfSize)

        realBuffer.withUnsafeMutableBufferPointer { realPtr in
            imagBuffer.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)

                floatSegment.withUnsafeBufferPointer { segPtr in
                    segPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(halfSize))
                    }
                }

                vDSP_fft_zrip(setup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
            }
        }

        // Scale and convert to complex pairs
        let scale = 1.0 / Float(n)
        return (0..<halfSize).map { i in
            (Double(realBuffer[i] * scale), Double(imagBuffer[i] * scale))
        }
    }

    /// Fallback FFT for segments that don't match cached size
    private func computeFFTFallback(_ segment: [Double]) -> [(real: Double, imag: Double)] {
        let n = segment.count
        guard n > 1 else { return segment.map { ($0, 0) } }

        let fallbackLog2n = vDSP_Length(log2(Double(n)))
        guard let fallbackSetup = vDSP_create_fftsetup(fallbackLog2n, FFTRadix(kFFTRadix2)) else {
            return segment.map { ($0, 0) }
        }
        defer { vDSP_destroy_fftsetup(fallbackSetup) }

        let floatSegment = segment.map { Float($0) }
        let halfSize = n / 2

        var realBuffer = [Float](repeating: 0, count: halfSize)
        var imagBuffer = [Float](repeating: 0, count: halfSize)

        realBuffer.withUnsafeMutableBufferPointer { realPtr in
            imagBuffer.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)

                floatSegment.withUnsafeBufferPointer { segPtr in
                    segPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(halfSize))
                    }
                }

                vDSP_fft_zrip(fallbackSetup, &splitComplex, 1, fallbackLog2n, FFTDirection(FFT_FORWARD))
            }
        }

        let scale = 1.0 / Float(n)
        return (0..<halfSize).map { i in
            (Double(realBuffer[i] * scale), Double(imagBuffer[i] * scale))
        }
    }
}
