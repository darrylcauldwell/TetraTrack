//
//  RiderStressAnalyzer.swift
//  TetraTrack
//
//  Live rider stress analysis using frequency-domain separation of
//  tremor (>3Hz), drift (<1Hz), and stability (1-3Hz) bands from
//  100Hz MotionSample data. Tracks stability baseline, fatigue slope,
//  and tremor/drift trends over the session.
//

import Accelerate
import Foundation
import TetraTrackShared
import os

@Observable
final class RiderStressAnalyzer: Resettable {

    // MARK: - Public Outputs

    /// Stability baseline from first 30s of riding (0-1)
    private(set) var stabilityBaseline: Double = 0

    /// Current stability score (0-1)
    private(set) var currentStability: Double = 0

    /// Fatigue degradation: stability decline per minute (negative = declining)
    private(set) var fatigueDegradation: Double = 0

    /// Tremor trend: normalized high-frequency power (0-1)
    private(set) var tremorTrend: Double = 0

    /// Drift trend: normalized low-frequency power (0-1)
    private(set) var driftTrend: Double = 0

    // MARK: - FFT Configuration

    private let fftWindowSize = 256  // 2.56s at 100Hz
    private let sampleRate: Double = 100.0
    private let fftUpdateInterval: TimeInterval = 0.5
    private let emaAlpha: Double = 0.2
    private let baselineDuration: TimeInterval = 30.0

    // MARK: - Internal Buffers

    /// Combined motion signal for FFT (sqrt(pitch² + roll²))
    private var fftBuffer: [Double] = []
    private var lastFFTTime: Date = .distantPast
    private var startTime: Date?

    // Baseline collection
    private var baselineSamples: [Double] = []
    private var baselineEstablished = false

    // Stability tracking for fatigue slope
    private var stabilityHistory: [(time: TimeInterval, value: Double)] = []

    // Frequency band powers (EMA smoothed)
    private var driftPower: Double = 0
    private var stabilityBandPower: Double = 0
    private var tremorPower: Double = 0

    // MARK: - Public Interface

    /// Process a motion sample (called at ~100Hz from RidingPlugin)
    func process(motion: MotionSample) {
        if startTime == nil { startTime = motion.timestamp }

        // Combined pitch/roll signal captures postural sway
        let signal = sqrt(motion.pitch * motion.pitch + motion.roll * motion.roll)
        fftBuffer.append(signal)
        if fftBuffer.count > fftWindowSize {
            fftBuffer.removeFirst()
        }

        // Run FFT at fixed interval when buffer is full
        if motion.timestamp.timeIntervalSince(lastFFTTime) >= fftUpdateInterval
            && fftBuffer.count >= fftWindowSize {
            performFFTAnalysis()
            lastFFTTime = motion.timestamp
            updateFatigueMetrics(at: motion.timestamp)
        }
    }

    /// Reset all state
    func reset() {
        fftBuffer.removeAll()
        lastFFTTime = .distantPast
        startTime = nil
        baselineSamples.removeAll()
        baselineEstablished = false
        stabilityHistory.removeAll()
        stabilityBaseline = 0
        currentStability = 0
        fatigueDegradation = 0
        tremorTrend = 0
        driftTrend = 0
        driftPower = 0
        stabilityBandPower = 0
        tremorPower = 0
    }

    // MARK: - FFT Analysis

    private func performFFTAnalysis() {
        let signal = Array(fftBuffer.suffix(fftWindowSize))

        // Hanning window
        var windowed = [Double](repeating: 0, count: fftWindowSize)
        for i in 0..<fftWindowSize {
            let w = 0.5 * (1.0 - cos(2.0 * .pi * Double(i) / Double(fftWindowSize - 1)))
            windowed[i] = signal[i] * w
        }

        let spectrum = computePowerSpectrum(windowed)
        guard !spectrum.isEmpty else { return }

        // Frequency resolution: 100Hz / 256 = 0.3906 Hz per bin
        let freqRes = sampleRate / Double(fftWindowSize)

        // Band boundaries (bin indices)
        let driftHighBin = max(1, Int(1.0 / freqRes))       // <1Hz
        let stabilityLowBin = Int(1.0 / freqRes)            // 1Hz
        let stabilityHighBin = Int(3.0 / freqRes)           // 3Hz
        let tremorLowBin = Int(3.0 / freqRes)               // >3Hz

        let totalPower = spectrum.reduce(0, +)
        guard totalPower > 0 else { return }

        let rawDrift = spectrum.prefix(driftHighBin).reduce(0, +) / totalPower
        let rawStability = spectrum[stabilityLowBin..<min(stabilityHighBin, spectrum.count)].reduce(0, +) / totalPower
        let rawTremor = spectrum[min(tremorLowBin, spectrum.count - 1)...].reduce(0, +) / totalPower

        // EMA smooth
        driftPower = driftPower * (1.0 - emaAlpha) + rawDrift * emaAlpha
        stabilityBandPower = stabilityBandPower * (1.0 - emaAlpha) + rawStability * emaAlpha
        tremorPower = tremorPower * (1.0 - emaAlpha) + rawTremor * emaAlpha

        // Stability = stability band / total (higher = more controlled)
        currentStability = stabilityBandPower

        // Ratios
        let stablePower = max(stabilityBandPower, 0.01)
        tremorTrend = tremorPower / stablePower
        driftTrend = driftPower / stablePower
    }

    private func computePowerSpectrum(_ signal: [Double]) -> [Double] {
        let n = signal.count
        let log2n = vDSP_Length(log2(Double(n)))

        guard let fftSetup = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2)) else {
            return []
        }
        defer { vDSP_destroy_fftsetupD(fftSetup) }

        var realPart = [Double](repeating: 0, count: n / 2)
        var imagPart = [Double](repeating: 0, count: n / 2)
        var spectrum = [Double](repeating: 0, count: n / 2)

        realPart.withUnsafeMutableBufferPointer { realPtr in
            imagPart.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPDoubleSplitComplex(
                    realp: realPtr.baseAddress!,
                    imagp: imagPtr.baseAddress!
                )

                signal.withUnsafeBufferPointer { sigPtr in
                    sigPtr.baseAddress!.withMemoryRebound(to: DSPDoubleComplex.self, capacity: n / 2) { complexPtr in
                        vDSP_ctozD(complexPtr, 2, &split, 1, vDSP_Length(n / 2))
                    }
                }

                vDSP_fft_zripD(fftSetup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))

                spectrum.withUnsafeMutableBufferPointer { specPtr in
                    vDSP_zvmagsD(&split, 1, specPtr.baseAddress!, 1, vDSP_Length(n / 2))
                }
            }
        }

        var scale = 1.0 / Double(n * n)
        vDSP_vsmulD(spectrum, 1, &scale, &spectrum, 1, vDSP_Length(n / 2))

        return spectrum
    }

    // MARK: - Fatigue Metrics

    private func updateFatigueMetrics(at timestamp: Date) {
        guard let start = startTime else { return }
        let elapsed = timestamp.timeIntervalSince(start)

        // Collect baseline during first 30s
        if elapsed < baselineDuration {
            baselineSamples.append(currentStability)
        } else if !baselineEstablished && !baselineSamples.isEmpty {
            stabilityBaseline = baselineSamples.reduce(0, +) / Double(baselineSamples.count)
            baselineEstablished = true
        }

        // Track stability history for slope calculation
        stabilityHistory.append((time: elapsed, value: currentStability))

        // Keep last 120s of history
        while let first = stabilityHistory.first, elapsed - first.time > 120 {
            stabilityHistory.removeFirst()
        }

        // Compute fatigue slope (stability change per minute) via linear regression
        if stabilityHistory.count >= 30 {
            fatigueDegradation = computeFatigueSlope()
        }
    }

    private func computeFatigueSlope() -> Double {
        guard stabilityHistory.count >= 2 else { return 0 }

        let n = Double(stabilityHistory.count)
        var sumX: Double = 0
        var sumY: Double = 0
        var sumXY: Double = 0
        var sumX2: Double = 0

        for point in stabilityHistory {
            let x = point.time / 60.0  // Convert to minutes
            let y = point.value
            sumX += x
            sumY += y
            sumXY += x * y
            sumX2 += x * x
        }

        let denom = n * sumX2 - sumX * sumX
        guard abs(denom) > 1e-10 else { return 0 }

        return (n * sumXY - sumX * sumY) / denom  // Slope in stability-units per minute
    }
}
