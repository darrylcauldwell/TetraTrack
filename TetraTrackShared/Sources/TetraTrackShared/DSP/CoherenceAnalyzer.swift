//
//  CoherenceAnalyzer.swift
//  TetraTrackShared
//
//  Welch coherence analysis for measuring signal coupling and symmetry
//

import Foundation
import Accelerate

/// Welch coherence analyzer for measuring coupling between two signals
/// Used for:
/// - X-Y coherence: left-right symmetry measure
/// - Z-yaw coherence: vertical-rotational coupling (canter/gallop signature)
public final class CoherenceAnalyzer {

    // MARK: - Configuration

    public let segmentLength: Int
    public let overlap: Int
    public let sampleRate: Double

    private let fftProcessor: FFTProcessor
    private let frequencyResolution: Double

    /// Cached FFT setup to avoid allocation/deallocation overhead per call
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
    public init(segmentLength: Int = 128, overlap: Int = 64, sampleRate: Double = 100.0) {
        self.segmentLength = segmentLength
        self.overlap = overlap
        self.sampleRate = sampleRate
        self.frequencyResolution = sampleRate / Double(segmentLength)

        self.fftProcessor = FFTProcessor(windowSize: segmentLength, sampleRate: sampleRate)

        self.log2n = vDSP_Length(log2(Double(segmentLength)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))

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
    public func coherence(signal1: [Double], signal2: [Double], atFrequency frequency: Double) -> Double {
        let minLength = min(signal1.count, signal2.count)
        guard minLength >= segmentLength else { return 0 }

        let (pxx, pyy, pxy) = computeWelchSpectra(signal1: Array(signal1.prefix(minLength)),
                                                   signal2: Array(signal2.prefix(minLength)))

        let bin = Int(frequency / frequencyResolution)
        guard bin > 0 && bin < pxx.count else { return 0 }

        let pxxVal = pxx[bin]
        let pyyVal = pyy[bin]
        let pxyMagSq = pxy[bin].real * pxy[bin].real + pxy[bin].imag * pxy[bin].imag

        guard pxxVal > 1e-10 && pyyVal > 1e-10 else { return 0 }

        let coherence = pxyMagSq / (pxxVal * pyyVal)
        return min(1.0, max(0.0, coherence))
    }

    /// Compute coherence spectrum across all frequencies
    public func coherenceSpectrum(signal1: [Double], signal2: [Double]) -> [(frequency: Double, coherence: Double)] {
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
    public func averageCoherence(signal1: [Double], signal2: [Double], inRange frequencyRange: ClosedRange<Double>) -> Double {
        let spectrum = coherenceSpectrum(signal1: signal1, signal2: signal2)

        let inBand = spectrum.filter { frequencyRange.contains($0.frequency) }
        guard !inBand.isEmpty else { return 0 }

        return inBand.reduce(0) { $0 + $1.coherence } / Double(inBand.count)
    }

    // MARK: - Cross-Spectral Density

    /// Compute cross-spectral density between two signals
    public func crossSpectralDensity(signal1: [Double], signal2: [Double]) -> [(real: Double, imag: Double)] {
        let (_, _, pxy) = computeWelchSpectra(signal1: signal1, signal2: signal2)
        return pxy
    }

    /// Compute power spectral density of a signal
    public func powerSpectralDensity(_ signal: [Double]) -> [Double] {
        let (pxx, _, _) = computeWelchSpectra(signal1: signal, signal2: signal)
        return pxx
    }

    // MARK: - Phase Analysis

    /// Compute cross-spectral phase at a specific frequency
    public func crossSpectralPhase(signal1: [Double], signal2: [Double], atFrequency frequency: Double) -> Double {
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

        let hopSize = segmentLength - overlap
        let numSegments = max(1, (minLength - segmentLength) / hopSize + 1)

        let halfSize = segmentLength / 2

        var pxxSum = [Double](repeating: 0, count: halfSize)
        var pyySum = [Double](repeating: 0, count: halfSize)
        var pxyRealSum = [Double](repeating: 0, count: halfSize)
        var pxyImagSum = [Double](repeating: 0, count: halfSize)

        for segIdx in 0..<numSegments {
            let startIdx = segIdx * hopSize
            let endIdx = startIdx + segmentLength

            guard endIdx <= minLength else { break }

            var seg1 = Array(signal1[startIdx..<endIdx])
            var seg2 = Array(signal2[startIdx..<endIdx])

            for i in 0..<segmentLength {
                seg1[i] *= windowDouble[i]
                seg2[i] *= windowDouble[i]
            }

            let fft1 = computeFFT(seg1)
            let fft2 = computeFFT(seg2)

            for i in 0..<halfSize {
                pxxSum[i] += fft1[i].real * fft1[i].real + fft1[i].imag * fft1[i].imag
                pyySum[i] += fft2[i].real * fft2[i].real + fft2[i].imag * fft2[i].imag
                pxyRealSum[i] += fft1[i].real * fft2[i].real + fft1[i].imag * fft2[i].imag
                pxyImagSum[i] += fft1[i].imag * fft2[i].real - fft1[i].real * fft2[i].imag
            }
        }

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

        guard let setup = fftSetup, n == segmentLength else {
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
