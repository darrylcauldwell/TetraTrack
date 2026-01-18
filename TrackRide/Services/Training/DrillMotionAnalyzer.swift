//
//  DrillMotionAnalyzer.swift
//  TrackRide
//
//  Unified motion analysis for all training drills with physics-based metrics
//  including frequency-domain analysis for tremor vs drift separation.
//

import Foundation
import CoreMotion
import Observation
import Accelerate

/// Unified motion analyzer for drill motion tracking
@Observable
final class DrillMotionAnalyzer {

    // MARK: - Motion Manager

    private let motionManager = CMMotionManager()
    private(set) var isRunning = false

    // MARK: - Raw Motion Values

    /// Current pitch in radians
    private(set) var pitch: Double = 0

    /// Current roll in radians
    private(set) var roll: Double = 0

    /// Current yaw in radians (relative to start)
    private(set) var yaw: Double = 0

    /// Acceleration magnitude
    private(set) var accelerationMagnitude: Double = 0

    // MARK: - Computed Metrics

    /// Root mean square of all motion axes
    private(set) var rmsMotion: Double = 0

    /// Left-right asymmetry indicator (positive = right bias, degrees)
    private(set) var leftRightAsymmetry: Double = 0

    /// Forward-back lean indicator (positive = forward, degrees)
    private(set) var anteriorPosterior: Double = 0

    /// Yaw variance (rotational stability)
    private(set) var rotationalStability: Double = 100

    /// Dominant oscillation frequency in Hz
    private(set) var dominantFrequency: Double = 0

    /// Rhythm consistency (0-100)
    private(set) var rhythmConsistency: Double = 100

    /// Overall stability score (0-100, backwards compatible)
    private(set) var stabilityScore: Double = 100

    /// Total movement magnitude
    private(set) var totalMovement: Double = 0

    // MARK: - Frequency Domain Metrics (Tremor vs Drift)

    /// High-frequency tremor power (>3Hz) - normalized 0-1
    /// Elevated tremor indicates fatigue, stress, or neuromuscular tension
    private(set) var tremorPower: Double = 0

    /// Low-frequency drift power (<1Hz) - normalized 0-1
    /// Elevated drift indicates slow postural compensation, losing balance
    private(set) var driftPower: Double = 0

    /// Stability band power (1-3Hz) - normalized 0-1
    /// This is the "controlled movement" range
    private(set) var stabilityBandPower: Double = 0

    /// Tremor-to-stability ratio
    /// High ratio = nervous system under stress
    private(set) var tremorRatio: Double = 0

    /// Drift-to-stability ratio
    /// High ratio = postural control degrading
    private(set) var driftRatio: Double = 0

    // MARK: - Fatigue Detection

    /// Initial stability baseline (set after first 3 seconds)
    private(set) var initialStabilityBaseline: Double?

    /// Current stability relative to baseline (0-100+)
    /// Below 85 indicates fatigue
    private(set) var stabilityRetention: Double = 100

    /// Fatigue slope: rate of stability decline per minute
    /// Negative = declining, positive = improving
    private(set) var fatigueSlope: Double = 0

    // MARK: - Integrated Scorer

    let scorer = DrillScorer()

    // MARK: - Internal State

    private var referenceYaw: Double?
    private var previousPitch: Double = 0
    private var previousRoll: Double = 0
    private var previousYaw: Double = 0

    private var pitchBuffer = RingBuffer<Double>(capacity: 60)
    private var rollBuffer = RingBuffer<Double>(capacity: 60)
    private var yawBuffer = RingBuffer<Double>(capacity: 60)
    private var accelerationBuffer = RingBuffer<Double>(capacity: 60)

    /// Extended buffer for FFT analysis (256 samples = ~4.27 seconds at 60Hz)
    private var fftBuffer: [Double] = []
    private let fftWindowSize = DrillPhysicsConstants.SamplingConfig.fftWindowSize

    /// For frequency detection
    private var peakTimestamps: [TimeInterval] = []
    private var lastPeakTime: TimeInterval = 0
    private var isRising = true
    private var lastAccelValue: Double = 0

    /// Fatigue tracking
    private var stabilityHistory: [(timestamp: TimeInterval, stability: Double)] = []
    private var baselineSamples: [Double] = []
    private let baselineWindowDuration: TimeInterval = 3.0  // 3 seconds for baseline

    private var startTime: Date?
    private let emaAlpha: Double = DrillPhysicsConstants.SamplingConfig.emaAlpha
    private var lastFFTTime: TimeInterval = 0
    private let fftUpdateInterval: TimeInterval = 0.5  // Update FFT every 500ms

    // MARK: - Public Interface

    /// Start motion updates at 60Hz
    func startUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        guard !isRunning else { return }

        isRunning = true
        startTime = Date()
        referenceYaw = nil
        scorer.reset()
        resetBuffers()

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, let self = self else { return }
            self.processMotion(motion)
        }
    }

    /// Stop motion updates
    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
        isRunning = false
    }

    /// Reset all state
    func reset() {
        stopUpdates()
        pitch = 0
        roll = 0
        yaw = 0
        accelerationMagnitude = 0
        rmsMotion = 0
        leftRightAsymmetry = 0
        anteriorPosterior = 0
        rotationalStability = 100
        dominantFrequency = 0
        rhythmConsistency = 100
        stabilityScore = 100
        totalMovement = 0
        referenceYaw = nil

        // Reset frequency domain metrics
        tremorPower = 0
        driftPower = 0
        stabilityBandPower = 0
        tremorRatio = 0
        driftRatio = 0

        // Reset fatigue tracking
        initialStabilityBaseline = nil
        stabilityRetention = 100
        fatigueSlope = 0
        stabilityHistory.removeAll()
        baselineSamples.removeAll()

        scorer.reset()
        resetBuffers()
    }

    // MARK: - Motion Processing

    private func processMotion(_ motion: CMDeviceMotion) {
        let timestamp = Date().timeIntervalSince(startTime ?? Date())

        // Update raw values
        pitch = motion.attitude.pitch
        roll = motion.attitude.roll

        // Set reference yaw on first reading
        if referenceYaw == nil {
            referenceYaw = motion.attitude.yaw
        }
        yaw = motion.attitude.yaw - (referenceYaw ?? 0)

        // Calculate acceleration magnitude
        let accel = motion.userAcceleration
        accelerationMagnitude = sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z)

        // Update buffers
        pitchBuffer.append(pitch)
        rollBuffer.append(roll)
        yawBuffer.append(yaw)
        accelerationBuffer.append(accelerationMagnitude)

        // Update FFT buffer (combined motion signal)
        let combinedMotion = sqrt(pitch * pitch + roll * roll)
        fftBuffer.append(combinedMotion)
        if fftBuffer.count > fftWindowSize {
            fftBuffer.removeFirst()
        }

        // Calculate deltas
        let pitchDelta = abs(pitch - previousPitch)
        let rollDelta = abs(roll - previousRoll)
        let yawDelta = abs(yaw - previousYaw)

        totalMovement = pitchDelta + rollDelta + yawDelta

        // Update computed metrics
        updateRMSMotion()
        updateAsymmetry()
        updateRotationalStability()
        updateRhythmMetrics(timestamp: timestamp)
        updateStabilityScore()

        // Update frequency domain analysis (every 500ms when we have enough data)
        if timestamp - lastFFTTime >= fftUpdateInterval && fftBuffer.count >= fftWindowSize {
            updateFrequencyDomainMetrics()
            lastFFTTime = timestamp
        }

        // Update fatigue tracking
        updateFatigueMetrics(timestamp: timestamp)

        // Feed to integrated scorer
        scorer.process(pitch: pitch, roll: roll, yaw: yaw, timestamp: timestamp)

        // Store previous values
        previousPitch = pitch
        previousRoll = roll
        previousYaw = yaw
    }

    private func updateRMSMotion() {
        let pitchValues = pitchBuffer.toArray()
        let rollValues = rollBuffer.toArray()
        let yawValues = yawBuffer.toArray()

        guard pitchValues.count > 1 else { return }

        let pitchSq = pitchValues.map { $0 * $0 }.reduce(0, +) / Double(pitchValues.count)
        let rollSq = rollValues.map { $0 * $0 }.reduce(0, +) / Double(rollValues.count)
        let yawSq = yawValues.map { $0 * $0 }.reduce(0, +) / Double(yawValues.count)

        rmsMotion = sqrt(pitchSq + rollSq + yawSq)
    }

    private func updateAsymmetry() {
        let rollValues = rollBuffer.toArray()
        guard !rollValues.isEmpty else { return }

        let avgRoll = rollValues.reduce(0, +) / Double(rollValues.count)
        leftRightAsymmetry = avgRoll * 57.3  // Convert to degrees

        let pitchValues = pitchBuffer.toArray()
        guard !pitchValues.isEmpty else { return }

        let avgPitch = pitchValues.reduce(0, +) / Double(pitchValues.count)
        anteriorPosterior = avgPitch * 57.3  // Convert to degrees
    }

    private func updateRotationalStability() {
        let yawValues = yawBuffer.toArray()
        guard yawValues.count > 1 else { return }

        let mean = yawValues.reduce(0, +) / Double(yawValues.count)
        let variance = yawValues.map { pow($0 - mean, 2) }.reduce(0, +) / Double(yawValues.count)

        // Convert variance to stability score
        let rawStability = max(0, 100 - (variance * 1000))
        rotationalStability = rotationalStability * (1 - emaAlpha) + rawStability * emaAlpha
    }

    private func updateRhythmMetrics(timestamp: TimeInterval) {
        // Simple peak detection for dominant frequency
        let currentAccel = accelerationMagnitude

        if isRising && currentAccel < lastAccelValue {
            // Found a peak
            if timestamp - lastPeakTime > 0.1 { // Minimum 100ms between peaks
                peakTimestamps.append(timestamp)
                lastPeakTime = timestamp

                // Keep only recent peaks
                while peakTimestamps.count > 20 {
                    peakTimestamps.removeFirst()
                }

                updateFrequencyFromPeaks()
            }
            isRising = false
        } else if !isRising && currentAccel > lastAccelValue {
            isRising = true
        }

        lastAccelValue = currentAccel
    }

    private func updateFrequencyFromPeaks() {
        guard peakTimestamps.count >= 3 else { return }

        // Calculate inter-peak intervals
        var intervals: [TimeInterval] = []
        for i in 1..<peakTimestamps.count {
            intervals.append(peakTimestamps[i] - peakTimestamps[i-1])
        }

        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        if avgInterval > 0.05 {
            dominantFrequency = 1.0 / avgInterval
        }

        // Calculate rhythm consistency from interval variance
        let mean = avgInterval
        let variance = intervals.map { pow($0 - mean, 2) }.reduce(0, +) / Double(intervals.count)
        let cv = sqrt(variance) / mean  // Coefficient of variation

        let rawConsistency = max(0, 100 - (cv * 100))
        rhythmConsistency = rhythmConsistency * (1 - emaAlpha) + rawConsistency * emaAlpha
    }

    private func updateStabilityScore() {
        // Backwards compatible simple stability score
        let movement = sqrt(
            pow(pitch - previousPitch, 2) +
            pow(roll - previousRoll, 2) +
            pow(yaw - previousYaw, 2)
        )
        let rawStability = max(0, 1 - (movement * 20))
        stabilityScore = stabilityScore * 0.9 + rawStability * 0.1
    }

    private func resetBuffers() {
        pitchBuffer = RingBuffer<Double>(capacity: 60)
        rollBuffer = RingBuffer<Double>(capacity: 60)
        yawBuffer = RingBuffer<Double>(capacity: 60)
        accelerationBuffer = RingBuffer<Double>(capacity: 60)
        fftBuffer.removeAll()
        peakTimestamps.removeAll()
        previousPitch = 0
        previousRoll = 0
        previousYaw = 0
        lastAccelValue = 0
        isRising = true
        lastFFTTime = 0
    }

    // MARK: - Frequency Domain Analysis (Tremor vs Drift)

    /// Perform FFT analysis to separate tremor (>3Hz) from drift (<1Hz)
    private func updateFrequencyDomainMetrics() {
        guard fftBuffer.count >= fftWindowSize else { return }

        // Use the most recent window
        let signal = Array(fftBuffer.suffix(fftWindowSize))

        // Apply Hanning window to reduce spectral leakage
        var windowedSignal = [Double](repeating: 0, count: fftWindowSize)
        for i in 0..<fftWindowSize {
            let window = 0.5 * (1 - cos(2 * Double.pi * Double(i) / Double(fftWindowSize - 1)))
            windowedSignal[i] = signal[i] * window
        }

        // Compute power spectrum using Accelerate framework
        let powerSpectrum = computePowerSpectrum(windowedSignal)

        // Frequency resolution: sampleRate / windowSize = 60Hz / 256 = 0.234 Hz per bin
        let frequencyResolution = DrillPhysicsConstants.SamplingConfig.motionUpdateRate / Double(fftWindowSize)

        // Define frequency bands
        let driftHighBin = Int(DrillPhysicsConstants.FrequencyBands.driftHighCutoff / frequencyResolution)
        let stabilityLowBin = Int(DrillPhysicsConstants.FrequencyBands.stabilityBandLow / frequencyResolution)
        let stabilityHighBin = Int(DrillPhysicsConstants.FrequencyBands.stabilityBandHigh / frequencyResolution)
        let tremorLowBin = Int(DrillPhysicsConstants.FrequencyBands.tremorLowCutoff / frequencyResolution)

        // Calculate band powers
        let totalPower = powerSpectrum.reduce(0, +)
        guard totalPower > 0 else { return }

        // Drift power: 0 to 1 Hz
        let driftSum = powerSpectrum.prefix(max(1, driftHighBin)).reduce(0, +)

        // Stability band power: 1 to 3 Hz
        let stabilitySum = powerSpectrum[min(stabilityLowBin, powerSpectrum.count - 1)..<min(stabilityHighBin, powerSpectrum.count)].reduce(0, +)

        // Tremor power: >3 Hz (up to Nyquist, 30Hz)
        let tremorSum = powerSpectrum[min(tremorLowBin, powerSpectrum.count - 1)...].reduce(0, +)

        // Normalize to 0-1 relative to total power
        let rawDrift = driftSum / totalPower
        let rawStability = stabilitySum / totalPower
        let rawTremor = tremorSum / totalPower

        // Apply EMA smoothing
        driftPower = driftPower * (1 - emaAlpha) + rawDrift * emaAlpha
        stabilityBandPower = stabilityBandPower * (1 - emaAlpha) + rawStability * emaAlpha
        tremorPower = tremorPower * (1 - emaAlpha) + rawTremor * emaAlpha

        // Calculate ratios (avoid division by zero)
        let stablePower = max(stabilityBandPower, 0.01)
        tremorRatio = tremorPower / stablePower
        driftRatio = driftPower / stablePower
    }

    /// Compute power spectrum using vDSP FFT
    private func computePowerSpectrum(_ signal: [Double]) -> [Double] {
        let n = signal.count
        let log2n = vDSP_Length(log2(Double(n)))

        guard let fftSetup = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2)) else {
            return []
        }
        defer { vDSP_destroy_fftsetupD(fftSetup) }

        // Prepare split complex arrays with proper pointer lifetime management
        var realPart = [Double](repeating: 0, count: n / 2)
        var imagPart = [Double](repeating: 0, count: n / 2)
        var powerSpectrum = [Double](repeating: 0, count: n / 2)

        realPart.withUnsafeMutableBufferPointer { realPtr in
            imagPart.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPDoubleSplitComplex(
                    realp: realPtr.baseAddress!,
                    imagp: imagPtr.baseAddress!
                )

                // Convert signal to split complex format
                signal.withUnsafeBufferPointer { signalPtr in
                    signalPtr.baseAddress!.withMemoryRebound(to: DSPDoubleComplex.self, capacity: n / 2) { complexPtr in
                        vDSP_ctozD(complexPtr, 2, &splitComplex, 1, vDSP_Length(n / 2))
                    }
                }

                // Perform FFT
                vDSP_fft_zripD(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))

                // Calculate power spectrum (magnitude squared)
                powerSpectrum.withUnsafeMutableBufferPointer { spectrumPtr in
                    vDSP_zvmagsD(&splitComplex, 1, spectrumPtr.baseAddress!, 1, vDSP_Length(n / 2))
                }
            }
        }

        // Normalize
        var scale = 1.0 / Double(n * n)
        vDSP_vsmulD(powerSpectrum, 1, &scale, &powerSpectrum, 1, vDSP_Length(n / 2))

        return powerSpectrum
    }

    // MARK: - Fatigue Detection

    private func updateFatigueMetrics(timestamp: TimeInterval) {
        // Track stability over time
        stabilityHistory.append((timestamp: timestamp, stability: stabilityScore * 100))

        // Keep only recent history (last 60 seconds)
        while let first = stabilityHistory.first, timestamp - first.timestamp > 60 {
            stabilityHistory.removeFirst()
        }

        // Establish baseline after initial period
        if timestamp < baselineWindowDuration {
            baselineSamples.append(stabilityScore * 100)
        } else if initialStabilityBaseline == nil && !baselineSamples.isEmpty {
            initialStabilityBaseline = baselineSamples.reduce(0, +) / Double(baselineSamples.count)
        }

        // Calculate stability retention (current vs baseline)
        if let baseline = initialStabilityBaseline, baseline > 0 {
            let recentStability = calculateRecentStability()
            stabilityRetention = (recentStability / baseline) * 100
        }

        // Calculate fatigue slope (stability change per minute)
        if stabilityHistory.count >= 60 {  // Need at least 1 second of data
            fatigueSlope = calculateFatigueSlope()
        }
    }

    private func calculateRecentStability() -> Double {
        let recentSamples = stabilityHistory.suffix(30)  // Last 0.5 seconds
        guard !recentSamples.isEmpty else { return 100 }
        return recentSamples.map { $0.stability }.reduce(0, +) / Double(recentSamples.count)
    }

    private func calculateFatigueSlope() -> Double {
        guard stabilityHistory.count >= 60 else { return 0 }

        // Split into first half and second half
        let midpoint = stabilityHistory.count / 2
        let firstHalf = Array(stabilityHistory.prefix(midpoint))
        let secondHalf = Array(stabilityHistory.suffix(midpoint))

        guard !firstHalf.isEmpty && !secondHalf.isEmpty else { return 0 }

        let firstAvg = firstHalf.map { $0.stability }.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.map { $0.stability }.reduce(0, +) / Double(secondHalf.count)

        // Calculate time span
        let timeSpan = (stabilityHistory.last?.timestamp ?? 0) - (stabilityHistory.first?.timestamp ?? 0)
        guard timeSpan > 0 else { return 0 }

        // Return slope in points per minute
        return ((secondAvg - firstAvg) / timeSpan) * 60
    }
}

// MARK: - Ring Buffer

/// Thread-safe fixed-size circular buffer
struct RingBuffer<T> {
    private var buffer: [T?]
    private var writeIndex = 0
    private let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }

    mutating func append(_ element: T) {
        buffer[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity
    }

    func toArray() -> [T] {
        // Return elements in order from oldest to newest
        var result: [T] = []
        for i in 0..<capacity {
            let index = (writeIndex + i) % capacity
            if let element = buffer[index] {
                result.append(element)
            }
        }
        return result
    }

    var count: Int {
        buffer.compactMap { $0 }.count
    }
}
