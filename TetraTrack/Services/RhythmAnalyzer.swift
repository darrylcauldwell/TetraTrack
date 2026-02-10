//
//  RhythmAnalyzer.swift
//  TetraTrack
//
//  FFT-based rhythm analysis using spectral methods.
//  Per gait-logic.md: "Never use peak detection as these fail when the rider changes seat"
//
//  Uses frequency-domain analysis of:
//  - Vertical acceleration (primary bounce signal)
//  - Pitch rate (gyroscope rotationX, not Euler pitch angle)
//  - Yaw rate for rotational rhythm
//
//  Rhythm consistency is measured via spectral concentration at the stride frequency.

import Foundation

/// Analyzes motion data to calculate rhythm consistency score using FFT-based spectral analysis
final class RhythmAnalyzer: Resettable, ReinAwareAnalyzer {
    // MARK: - Public Properties

    /// Current rhythm score (0-100%)
    private(set) var currentRhythmScore: Double = 0.0

    /// Current stride rate (strides per minute)
    private(set) var currentStrideRate: Double = 0.0

    /// Confidence in the current rhythm measurement (0-1)
    private(set) var rhythmConfidence: Double = 0.0

    /// Average rhythm on left rein (ReinAwareAnalyzer)
    var leftReinScore: Double { reinScores.leftReinAverage }

    /// Average rhythm on right rein (ReinAwareAnalyzer)
    var rightReinScore: Double { reinScores.rightReinAverage }

    /// Legacy accessors for compatibility
    var leftReinRhythm: Double { leftReinScore }
    var rightReinRhythm: Double { rightReinScore }

    // MARK: - Configuration

    /// Window size for FFT analysis (256 samples at 100Hz = 2.56s)
    private let fftWindowSize: Int = 256

    /// Sample rate (Hz)
    private let sampleRate: Double = 100.0

    /// Expected stride frequency ranges per gait (Hz)
    /// Converted from strides/minute: divide by 60
    private let gaitFrequencyRanges: [GaitType: ClosedRange<Double>] = [
        .walk: 0.83...1.08,     // 50-65 strides/min
        .trot: 1.17...1.42,     // 70-85 strides/min
        .canter: 1.50...1.83,   // 90-110 strides/min
        .gallop: 1.83...2.33    // 110-140 strides/min
    ]

    /// Expected stride rate ranges per gait (strides/minute) for display
    private let gaitStrideRates: [GaitType: ClosedRange<Double>] = [
        .walk: 50...65,
        .trot: 70...85,
        .canter: 90...110,
        .gallop: 110...140
    ]

    // MARK: - FFT Processing

    /// FFT processor for spectral analysis
    private let fftProcessor: FFTProcessor

    /// Analysis interval (don't run FFT every sample)
    private let analysisInterval: TimeInterval = 0.25  // 4 Hz
    private var lastAnalysisTime: Date = .distantPast

    // MARK: - Sensor Buffers (use simple arrays for FFT input)

    /// Vertical acceleration buffer for FFT
    private var verticalBuffer: [Double] = []

    /// Pitch rate buffer (gyroscope rotationX, NOT Euler pitch angle)
    private var pitchRateBuffer: [Double] = []

    /// Yaw rate buffer for rotational rhythm
    private var yawRateBuffer: [Double] = []

    /// Per-rein rhythm tracking
    private var reinScores = ReinScoreTracker()

    /// Current rein and gait
    private var currentRein: ReinDirection = .straight
    private var currentGait: GaitType = .stationary

    /// Last sample timestamp for timing
    private var lastSampleTime: Date?

    init() {
        fftProcessor = FFTProcessor(windowSize: fftWindowSize, sampleRate: sampleRate)
    }

    // MARK: - Public Methods

    /// Process a motion sample for rhythm analysis using FFT-based spectral analysis
    func processMotionSample(_ sample: MotionSample, currentGait: GaitType) {
        self.currentGait = currentGait
        let timestamp = sample.timestamp

        // Skip stationary
        guard currentGait != .stationary else {
            currentRhythmScore = 0.0
            currentStrideRate = 0.0
            rhythmConfidence = 0.0
            lastSampleTime = timestamp
            return
        }

        // Store sensor data for FFT
        // Use pitch RATE (rotationX) not pitch ANGLE (Euler) - Euler angles drift and have gimbal lock
        verticalBuffer.append(sample.verticalAcceleration)
        pitchRateBuffer.append(sample.rotationX)  // Pitch rate from gyroscope
        yawRateBuffer.append(sample.yawRate)

        // Maintain buffer sizes
        if verticalBuffer.count > fftWindowSize {
            verticalBuffer.removeFirst(verticalBuffer.count - fftWindowSize)
        }
        if pitchRateBuffer.count > fftWindowSize {
            pitchRateBuffer.removeFirst(pitchRateBuffer.count - fftWindowSize)
        }
        if yawRateBuffer.count > fftWindowSize {
            yawRateBuffer.removeFirst(yawRateBuffer.count - fftWindowSize)
        }

        // Run FFT analysis at fixed rate (not every sample)
        if timestamp.timeIntervalSince(lastAnalysisTime) >= analysisInterval &&
           verticalBuffer.count >= fftWindowSize {
            calculateFFTRhythm()
            lastAnalysisTime = timestamp
        }

        lastSampleTime = timestamp
    }

    /// Update current rein for per-rein tracking
    func updateRein(_ rein: ReinDirection) {
        if currentRein != rein && currentRein != .straight {
            finalizeReinSegment()
        }
        currentRein = rein
    }

    /// Finalize rhythm scores for current rein segment (ReinAwareAnalyzer)
    func finalizeReinSegment() {
        reinScores.recordScore(currentRhythmScore, for: currentRein)
    }

    /// Reset all state
    func reset() {
        verticalBuffer.removeAll()
        pitchRateBuffer.removeAll()
        yawRateBuffer.removeAll()

        reinScores.reset()
        currentRhythmScore = 0.0
        currentStrideRate = 0.0
        rhythmConfidence = 0.0
        currentRein = .straight
        currentGait = .stationary
        lastSampleTime = nil
        lastAnalysisTime = .distantPast
    }

    // MARK: - FFT-Based Rhythm Analysis

    /// Calculate rhythm using FFT spectral analysis
    /// Rhythm consistency is measured by how concentrated the power is at the stride frequency
    private func calculateFFTRhythm() {
        // Get expected frequency range for current gait
        let frequencyRange = gaitFrequencyRanges[currentGait] ?? 0.8...2.5

        // Analyze each channel with FFT
        let verticalResult = analyzeChannelFFT(verticalBuffer, frequencyRange: frequencyRange)
        let pitchRateResult = analyzeChannelFFT(pitchRateBuffer, frequencyRange: frequencyRange)
        let yawRateResult = analyzeChannelFFT(yawRateBuffer, frequencyRange: frequencyRange)

        // Weight channels by reliability
        // Vertical acceleration is primary, gyroscope rates are secondary
        var totalWeight: Double = 0
        var weightedRhythm: Double = 0
        var weightedFrequency: Double = 0

        if verticalResult.isValid {
            let weight = 2.0  // Vertical is primary signal
            totalWeight += weight
            weightedRhythm += verticalResult.rhythmScore * weight
            weightedFrequency += verticalResult.dominantFrequency * weight
        }

        if pitchRateResult.isValid {
            let weight = 1.0  // Pitch rate secondary
            totalWeight += weight
            weightedRhythm += pitchRateResult.rhythmScore * weight
            weightedFrequency += pitchRateResult.dominantFrequency * weight
        }

        if yawRateResult.isValid {
            let weight = 0.5  // Yaw rate tertiary
            totalWeight += weight
            weightedRhythm += yawRateResult.rhythmScore * weight
            weightedFrequency += yawRateResult.dominantFrequency * weight
        }

        guard totalWeight > 0 else {
            currentRhythmScore = 0.0
            currentStrideRate = 0.0
            rhythmConfidence = 0.0
            return
        }

        // Calculate weighted averages
        let baseRhythm = weightedRhythm / totalWeight
        let dominantFreq = weightedFrequency / totalWeight

        // Convert frequency to stride rate (strides per minute)
        currentStrideRate = dominantFreq * 60.0

        // Apply gait appropriateness bonus
        let gaitBonus = calculateGaitAppropriatenessScore()

        // Combined rhythm score (80% spectral concentration, 20% gait appropriateness)
        currentRhythmScore = baseRhythm * 0.8 + gaitBonus * 0.2

        // Confidence based on channel agreement
        rhythmConfidence = calculateFFTConfidence(
            results: [verticalResult, pitchRateResult, yawRateResult]
        )
    }

    /// Analyze a single channel using FFT
    /// Returns rhythm score based on spectral concentration at dominant frequency
    private func analyzeChannelFFT(
        _ buffer: [Double],
        frequencyRange: ClosedRange<Double>
    ) -> (rhythmScore: Double, dominantFrequency: Double, isValid: Bool) {
        guard buffer.count >= fftWindowSize else {
            return (0, 0, false)
        }

        // Process FFT
        let fftResult = fftProcessor.processWindow(buffer)

        // Find dominant frequency in expected gait range
        let (dominantFreq, powerAtF0) = fftProcessor.findDominantFrequency(inRange: frequencyRange)

        guard powerAtF0 > 1e-6 && dominantFreq > 0.5 else {
            return (0, 0, false)
        }

        // Rhythm score based on spectral concentration
        // Low spectral entropy = concentrated power = consistent rhythm
        // High spectral entropy = spread power = inconsistent rhythm
        let entropy = fftResult.spectralEntropy

        // Convert entropy to rhythm score
        // Entropy 0 = perfect rhythm (100%), Entropy 1 = random (0%)
        // Use 1 - entropy, but weight toward middle values
        let rhythmScore = max(0.0, min(100.0, (1.0 - entropy) * 100.0))

        return (rhythmScore, dominantFreq, true)
    }

    /// Calculate confidence based on FFT channel agreement
    private func calculateFFTConfidence(
        results: [(rhythmScore: Double, dominantFrequency: Double, isValid: Bool)]
    ) -> Double {
        let validResults = results.filter { $0.isValid }
        guard validResults.count >= 2 else {
            return validResults.isEmpty ? 0.0 : 0.5
        }

        // Calculate frequency agreement across channels
        let frequencies = validResults.map { $0.dominantFrequency }
        let meanFreq = frequencies.reduce(0, +) / Double(frequencies.count)
        let freqVariance = frequencies.reduce(0) { $0 + ($1 - meanFreq) * ($1 - meanFreq) } / Double(frequencies.count)
        let freqStdDev = sqrt(freqVariance)

        // Lower variance = higher confidence
        // If channels agree within 0.1 Hz (6 strides/min), high confidence
        let agreement = max(0.0, 1.0 - (freqStdDev / 0.2))

        // More valid channels = higher confidence
        let channelBonus = Double(validResults.count) / 3.0

        return min(1.0, agreement * 0.7 + channelBonus * 0.3)
    }

    /// Calculate bonus based on stride rate appropriateness for current gait
    private func calculateGaitAppropriatenessScore() -> Double {
        guard let expectedRange = gaitStrideRates[currentGait] else {
            return 50.0
        }

        if expectedRange.contains(currentStrideRate) {
            return 100.0
        }

        let midpoint = (expectedRange.lowerBound + expectedRange.upperBound) / 2
        let rangeSize = expectedRange.upperBound - expectedRange.lowerBound
        let deviation = abs(currentStrideRate - midpoint)

        return max(0.0, 100.0 - (deviation / rangeSize) * 50.0)
    }

    // MARK: - Public Accessors

    /// Get rhythm score for a specific gait
    func rhythmForGait(_ gait: GaitType) -> Double {
        return currentRhythmScore
    }

    /// Get expected stride rate range for a gait
    func expectedStrideRateRange(for gait: GaitType) -> ClosedRange<Double>? {
        return gaitStrideRates[gait]
    }

    /// Get current stride rate with confidence
    func strideRateWithConfidence() -> (rate: Double, confidence: Double) {
        return (currentStrideRate, rhythmConfidence)
    }
}
