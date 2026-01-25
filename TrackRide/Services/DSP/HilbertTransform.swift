//
//  HilbertTransform.swift
//  TrackRide
//
//  FFT-based Hilbert transform for extracting instantaneous phase and amplitude
//

import Foundation
import Accelerate

/// Hilbert transform utilities for phase extraction and analytic signal computation
enum HilbertTransform {

    // MARK: - Analytic Signal

    /// Compute the analytic signal using FFT-based Hilbert transform
    /// The analytic signal has real part = original signal, imaginary part = Hilbert transform
    /// - Parameter signal: Input real-valued signal
    /// - Returns: Array of complex numbers representing the analytic signal
    static func analyticSignal(_ signal: [Double]) -> [(real: Double, imag: Double)] {
        let n = signal.count
        guard n > 1 else { return signal.map { ($0, 0) } }

        // Pad to power of 2 for efficient FFT
        let paddedSize = nextPowerOfTwo(n)

        // Remove DC component before Hilbert transform
        // DC offset causes phase errors in the analytic signal
        let mean = signal.reduce(0, +) / Double(n)
        let dcRemoved = signal.map { $0 - mean }
        let paddedSignal = dcRemoved + [Double](repeating: 0, count: paddedSize - n)

        // Convert to float for vDSP
        let floatSignal = paddedSignal.map { Float($0) }

        // FFT setup
        let log2n = vDSP_Length(log2(Double(paddedSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return signal.map { ($0, 0) }
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        let halfSize = paddedSize / 2

        // Prepare split complex buffer
        var realBuffer = [Float](repeating: 0, count: halfSize)
        var imagBuffer = [Float](repeating: 0, count: halfSize)

        realBuffer.withUnsafeMutableBufferPointer { realPtr in
            imagBuffer.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)

                // Convert to split complex
                floatSignal.withUnsafeBufferPointer { signalPtr in
                    signalPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(halfSize))
                    }
                }

                // Forward FFT
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

                // Apply Hilbert transform in frequency domain:
                // - DC and Nyquist components unchanged
                // - Positive frequencies multiplied by 2
                // - Negative frequencies set to 0
                // For real FFT, we only have positive frequencies, so multiply by 2 (except DC)

                // Keep DC unchanged (index 0)
                // Multiply positive frequencies by 2
                var scale: Float = 2.0
                vDSP_vsmul(realPtr.baseAddress! + 1, 1, &scale, realPtr.baseAddress! + 1, 1, vDSP_Length(halfSize - 1))
                vDSP_vsmul(imagPtr.baseAddress! + 1, 1, &scale, imagPtr.baseAddress! + 1, 1, vDSP_Length(halfSize - 1))

                // Inverse FFT
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_INVERSE))

                // Scale by 1/n
                var invScale = Float(1.0 / Float(paddedSize))
                vDSP_vsmul(realPtr.baseAddress!, 1, &invScale, realPtr.baseAddress!, 1, vDSP_Length(halfSize))
                vDSP_vsmul(imagPtr.baseAddress!, 1, &invScale, imagPtr.baseAddress!, 1, vDSP_Length(halfSize))
            }
        }

        // Convert back to interleaved and extract original length
        var result: [(real: Double, imag: Double)] = []
        result.reserveCapacity(n)

        for i in 0..<min(n, halfSize) {
            result.append((Double(realBuffer[i]), Double(imagBuffer[i])))
        }

        // Handle odd-length signals
        if n > halfSize {
            for i in halfSize..<n {
                let idx = paddedSize - i
                if idx < halfSize {
                    result.append((Double(realBuffer[idx]), -Double(imagBuffer[idx])))
                } else {
                    result.append((0, 0))
                }
            }
        }

        return result
    }

    // MARK: - Instantaneous Phase

    /// Extract instantaneous phase from a signal
    /// - Parameter signal: Input real-valued signal
    /// - Returns: Array of phase values in radians (-pi to pi)
    static func instantaneousPhase(_ signal: [Double]) -> [Double] {
        let analytic = analyticSignal(signal)
        return analytic.map { atan2($0.imag, $0.real) }
    }

    /// Extract unwrapped instantaneous phase (continuous, not wrapped to -pi..pi)
    /// - Parameter signal: Input real-valued signal
    /// - Returns: Array of unwrapped phase values in radians
    static func unwrappedPhase(_ signal: [Double]) -> [Double] {
        let phase = instantaneousPhase(signal)
        return unwrap(phase)
    }

    // MARK: - Instantaneous Amplitude

    /// Extract instantaneous amplitude (envelope) from a signal
    /// - Parameter signal: Input real-valued signal
    /// - Returns: Array of amplitude values
    static func envelope(_ signal: [Double]) -> [Double] {
        let analytic = analyticSignal(signal)
        return analytic.map { sqrt($0.real * $0.real + $0.imag * $0.imag) }
    }

    // MARK: - Phase Difference

    /// Compute phase difference between two signals at their dominant frequency
    /// Useful for lead detection: lateral vs yaw phase difference
    /// - Parameters:
    ///   - signal1: First signal (e.g., lateral acceleration)
    ///   - signal2: Second signal (e.g., yaw rate)
    /// - Returns: Array of phase differences in radians
    static func phaseDifference(signal1: [Double], signal2: [Double]) -> [Double] {
        let phase1 = instantaneousPhase(signal1)
        let phase2 = instantaneousPhase(signal2)

        let minLength = min(phase1.count, phase2.count)
        var diff = [Double](repeating: 0, count: minLength)

        for i in 0..<minLength {
            // Compute phase difference and wrap to -pi..pi
            var d = phase1[i] - phase2[i]
            while d > .pi { d -= 2 * .pi }
            while d < -.pi { d += 2 * .pi }
            diff[i] = d
        }

        return diff
    }

    /// Compute mean phase difference between two signals
    /// - Parameters:
    ///   - signal1: First signal
    ///   - signal2: Second signal
    /// - Returns: Mean phase difference in radians (-pi to pi)
    static func meanPhaseDifference(signal1: [Double], signal2: [Double]) -> Double {
        let diff = phaseDifference(signal1: signal1, signal2: signal2)
        guard !diff.isEmpty else { return 0 }

        // Use circular mean for phase values
        let sinSum = diff.reduce(0) { $0 + sin($1) }
        let cosSum = diff.reduce(0) { $0 + cos($1) }

        return atan2(sinSum, cosSum)
    }

    /// Compute mean phase difference in degrees
    static func meanPhaseDifferenceDegrees(signal1: [Double], signal2: [Double]) -> Double {
        return meanPhaseDifference(signal1: signal1, signal2: signal2) * 180.0 / .pi
    }

    // MARK: - Instantaneous Frequency

    /// Compute instantaneous frequency from phase
    /// - Parameters:
    ///   - signal: Input signal
    ///   - sampleRate: Sample rate in Hz
    /// - Returns: Array of instantaneous frequencies in Hz
    static func instantaneousFrequency(_ signal: [Double], sampleRate: Double) -> [Double] {
        let phase = unwrappedPhase(signal)
        guard phase.count > 1 else { return [] }

        var freq = [Double](repeating: 0, count: phase.count - 1)
        let dt = 1.0 / sampleRate

        for i in 0..<freq.count {
            freq[i] = (phase[i + 1] - phase[i]) / (2 * .pi * dt)
        }

        return freq
    }

    // MARK: - Private Helpers

    /// Find next power of 2 >= n
    private static func nextPowerOfTwo(_ n: Int) -> Int {
        var power = 1
        while power < n {
            power *= 2
        }
        return power
    }

    /// Unwrap phase to remove discontinuities
    private static func unwrap(_ phase: [Double]) -> [Double] {
        guard !phase.isEmpty else { return [] }

        var unwrapped = [Double](repeating: 0, count: phase.count)
        unwrapped[0] = phase[0]

        for i in 1..<phase.count {
            var diff = phase[i] - phase[i - 1]
            while diff > .pi { diff -= 2 * .pi }
            while diff < -.pi { diff += 2 * .pi }
            unwrapped[i] = unwrapped[i - 1] + diff
        }

        return unwrapped
    }
}
