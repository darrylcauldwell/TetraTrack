//
//  GaitAnalyzer.swift
//  TrackRide
//
//  Physics-based gait detection using FFT spectral analysis, Hidden Markov Model,
//  and horse profile biomechanical priors

import CoreMotion
import Observation
import SwiftData

@Observable
final class GaitAnalyzer: Resettable {

    // MARK: - Public State (Backwards Compatible)

    var currentGait: GaitType = .stationary
    var isAnalyzing: Bool = false

    /// Current detected stride frequency (Hz) - primary spectral output
    var detectedBounceFrequency: Double = 0

    /// Current vertical acceleration amplitude (g)
    var bounceAmplitude: Double = 0

    /// Callback when gait changes (from, to)
    var onGaitChange: ((GaitType, GaitType) -> Void)?

    // MARK: - New Physics-Based Outputs

    /// Stride frequency from FFT (Hz) - more accurate than zero-crossing
    var strideFrequency: Double = 0

    /// Harmonic ratios for gait discrimination
    var harmonicRatios: (h2: Double, h3: Double) = (0, 0)

    /// Spectral entropy (signal complexity, 0-1)
    var spectralEntropy: Double = 0

    /// Confidence in current gait state (0-1)
    var gaitConfidence: Double = 0

    /// Left-right symmetry from coherence (0-1)
    var leftRightSymmetry: Double = 0

    /// Vertical-rotational coupling (0-1)
    var verticalYawCoherence: Double = 0

    // MARK: - DSP Components

    private let fftProcessor = FFTProcessor(windowSize: 256, sampleRate: 100)
    private let coherenceAnalyzer = CoherenceAnalyzer(segmentLength: 128, overlap: 64, sampleRate: 100)
    private let frameTransformer = FrameTransformer()
    private let hmm = GaitHMM()

    // MARK: - Sensor Buffers (256 samples = 2.56s at 100Hz)

    private var verticalBuffer: [Double] = []
    private var lateralBuffer: [Double] = []
    private var forwardBuffer: [Double] = []
    private var yawRateBuffer: [Double] = []
    private var timestampBuffer: [Date] = []
    private let bufferSize = 256

    // Buffer for FFT window processing (with overlap)
    private var lastFFTTime: Date = .distantPast
    private let fftUpdateInterval: TimeInterval = 0.25  // 4 Hz update rate

    // MARK: - GPS and Legacy Support

    private var speedSamples: [Double] = []
    private let speedSampleWindow = 5
    private var lastGPSSpeed: Double = 0

    // MARK: - Apple Watch Data

    /// Watch arm symmetry from WatchConnectivity (0-1, 0 if unavailable)
    var watchArmSymmetry: Double = 0

    /// Watch yaw energy from WatchConnectivity (rad/s RMS, 0 if unavailable)
    var watchYawEnergy: Double = 0

    // Legacy buffers for backwards compatibility
    private var verticalAccelSamples: [Double] = []
    private var sampleTimestamps: [Date] = []
    private let motionSampleWindow = 100

    // MARK: - Horse Profile

    private var horseProfile: Horse?

    // MARK: - Segment Management

    private var currentSegment: GaitSegment?
    private var segmentDistance: Double = 0
    private var modelContext: ModelContext?
    private var currentRide: Ride?

    // MARK: - Configuration

    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Configure analyzer with horse profile for breed-specific priors
    func configure(for horse: Horse?) {
        self.horseProfile = horse
        if let horse = horse {
            // Pass breed and age adjustment to HMM
            hmm.configure(for: horse.typedBreed, ageAdjustment: horse.ageAdjustmentFactor)
        }
    }

    // MARK: - Lifecycle

    func startAnalyzing(for ride: Ride) {
        guard !isAnalyzing else { return }

        currentRide = ride
        isAnalyzing = true
        currentGait = .stationary

        // Reset all buffers
        clearBuffers()

        // Reset HMM
        hmm.reset()

        // Start initial segment
        startNewSegment(gait: .stationary)

        // Configure for horse if available
        if let horse = ride.horse {
            configure(for: horse)
        }
    }

    func stopAnalyzing() {
        guard isAnalyzing else { return }

        finalizeCurrentSegment()

        isAnalyzing = false
        currentRide = nil
        currentSegment = nil

        clearBuffers()
    }

    func reset() {
        stopAnalyzing()
        currentGait = .stationary
        segmentDistance = 0
        detectedBounceFrequency = 0
        bounceAmplitude = 0
        strideFrequency = 0
        harmonicRatios = (0, 0)
        spectralEntropy = 0
        gaitConfidence = 0
        leftRightSymmetry = 0
        verticalYawCoherence = 0
        watchArmSymmetry = 0
        watchYawEnergy = 0
        hmm.reset()
    }

    private func clearBuffers() {
        speedSamples = []
        verticalBuffer = []
        lateralBuffer = []
        forwardBuffer = []
        yawRateBuffer = []
        timestampBuffer = []
        verticalAccelSamples = []
        sampleTimestamps = []
        segmentDistance = 0
        lastFFTTime = .distantPast
    }

    // MARK: - Process Location (GPS Speed)

    /// Called with each new location update (~1Hz)
    func processLocation(speed: Double, distance: Double) {
        guard isAnalyzing else { return }

        speedSamples.append(speed)
        if speedSamples.count > speedSampleWindow {
            speedSamples.removeFirst()
        }

        lastGPSSpeed = speedSamples.isEmpty ? 0 : speedSamples.reduce(0, +) / Double(speedSamples.count)
        segmentDistance += distance
    }

    // MARK: - Process Motion (Accelerometer + Gyroscope)

    /// Called with each motion update (~50-100Hz)
    func processMotion(_ sample: MotionSample) {
        guard isAnalyzing else { return }

        // Transform to horse-relative frame
        let transformed = frameTransformer.transform(sample)

        // Add to physics buffers
        verticalBuffer.append(transformed.accel.vertical)
        lateralBuffer.append(transformed.accel.lateral)
        forwardBuffer.append(transformed.accel.forward)
        yawRateBuffer.append(sample.yawRate)
        timestampBuffer.append(sample.timestamp)

        // Maintain buffer size
        if verticalBuffer.count > bufferSize {
            verticalBuffer.removeFirst()
            lateralBuffer.removeFirst()
            forwardBuffer.removeFirst()
            yawRateBuffer.removeFirst()
            timestampBuffer.removeFirst()
        }

        // Legacy buffer for backwards compatibility
        verticalAccelSamples.append(sample.verticalAcceleration)
        sampleTimestamps.append(sample.timestamp)
        if verticalAccelSamples.count > motionSampleWindow {
            verticalAccelSamples.removeFirst()
            sampleTimestamps.removeFirst()
        }

        // Update bounce amplitude (RMS)
        if verticalBuffer.count >= 20 {
            let recentSamples = Array(verticalBuffer.suffix(20))
            bounceAmplitude = sqrt(recentSamples.map { $0 * $0 }.reduce(0, +) / 20.0)
        }

        // Perform FFT analysis at fixed rate
        let now = sample.timestamp
        if now.timeIntervalSince(lastFFTTime) >= fftUpdateInterval && verticalBuffer.count >= 128 {
            performSpectralAnalysis()
            lastFFTTime = now
        }
    }

    // MARK: - Spectral Analysis

    private func performSpectralAnalysis() {
        guard verticalBuffer.count >= 128 else { return }

        // FFT on vertical channel
        let fftResult = fftProcessor.processWindow(verticalBuffer)

        strideFrequency = fftResult.dominantFrequency
        harmonicRatios = (fftResult.h2Ratio, fftResult.h3Ratio)
        spectralEntropy = fftResult.spectralEntropy

        // Legacy compatibility
        detectedBounceFrequency = strideFrequency

        // Coherence calculations (if we have enough data)
        if lateralBuffer.count >= 128 && forwardBuffer.count >= 128 && yawRateBuffer.count >= 128 {
            // X-Y coherence: forward (X) vs lateral (Y) for left-right symmetry
            leftRightSymmetry = coherenceAnalyzer.coherence(
                signal1: forwardBuffer,
                signal2: lateralBuffer,
                atFrequency: strideFrequency
            )

            // Z-yaw coherence: vertical vs yaw rate for rotational coupling
            verticalYawCoherence = coherenceAnalyzer.coherence(
                signal1: verticalBuffer,
                signal2: yawRateBuffer,
                atFrequency: strideFrequency
            )
        }

        // Build feature vector
        let normalizedRMS = horseProfile?.normalizedVerticalRMS(bounceAmplitude) ?? bounceAmplitude
        let yawRMS = sqrt(yawRateBuffer.suffix(50).map { $0 * $0 }.reduce(0, +) / 50.0)

        let features = GaitFeatureVector(
            strideFrequency: strideFrequency,
            h2Ratio: harmonicRatios.h2,
            h3Ratio: harmonicRatios.h3,
            spectralEntropy: spectralEntropy,
            xyCoherence: leftRightSymmetry,
            zYawCoherence: verticalYawCoherence,
            normalizedVerticalRMS: normalizedRMS,
            yawRateRMS: yawRMS,
            gpsSpeed: lastGPSSpeed,
            watchArmSymmetry: watchArmSymmetry,
            watchYawEnergy: watchYawEnergy
        )

        // Update HMM
        hmm.update(with: features)

        // Get new state
        let hmmState = hmm.currentState
        gaitConfidence = hmm.stateConfidence

        let newGait = gaitTypeFromHMMState(hmmState)

        // Only change gait if confidence is high enough
        if newGait != currentGait && gaitConfidence > 0.7 {
            let previousGait = currentGait
            finalizeCurrentSegment()
            currentGait = newGait
            startNewSegment(gait: newGait)
            onGaitChange?(previousGait, newGait)
        }
    }

    /// Convert HMM state to GaitType
    private func gaitTypeFromHMMState(_ state: HMMGaitState) -> GaitType {
        switch state {
        case .stationary: return .stationary
        case .walk: return .walk
        case .trot: return .trot
        case .canter: return .canter
        case .gallop: return .gallop
        }
    }

    // MARK: - Segment Management

    private func startNewSegment(gait: GaitType) {
        let segment = GaitSegment(gaitType: gait, startTime: Date())
        segment.ride = currentRide

        // Store spectral features
        segment.strideFrequency = strideFrequency
        segment.harmonicRatioH2 = harmonicRatios.h2
        segment.harmonicRatioH3 = harmonicRatios.h3
        segment.spectralEntropy = spectralEntropy

        modelContext?.insert(segment)
        currentSegment = segment
        segmentDistance = 0
    }

    private func finalizeCurrentSegment() {
        guard let segment = currentSegment else { return }

        segment.endTime = Date()
        segment.distance = segmentDistance

        if segment.duration > 0 {
            segment.averageSpeed = segmentDistance / segment.duration
        }

        // Update with final spectral features
        segment.strideFrequency = strideFrequency
        segment.harmonicRatioH2 = harmonicRatios.h2
        segment.harmonicRatioH3 = harmonicRatios.h3
        segment.spectralEntropy = spectralEntropy
        segment.verticalYawCoherence = verticalYawCoherence

        // Compute stride length if we have horse profile
        if let horse = horseProfile {
            segment.strideLength = horse.computeStrideLength(
                for: segment.gait,
                verticalRMS: bounceAmplitude
            )
        }

        try? modelContext?.save()
    }

    // MARK: - Lead & Rhythm Updates

    /// Update lead information for current gait segment
    func updateLead(_ lead: Lead, confidence: Double) {
        guard let segment = currentSegment,
              segment.isLeadApplicable else { return }

        segment.lead = lead
        segment.leadConfidence = confidence
    }

    /// Update rhythm score for current gait segment
    func updateRhythm(_ score: Double) {
        currentSegment?.rhythmScore = score
    }

    /// Update stride length for current segment
    func updateStrideLength(_ length: Double) {
        currentSegment?.strideLength = length
    }

    /// Update impulsion for current segment
    func updateImpulsion(_ value: Double) {
        currentSegment?.impulsion = value
    }

    /// Update engagement for current segment
    func updateEngagement(_ value: Double) {
        currentSegment?.engagement = value
    }

    /// Update Apple Watch motion data for gait classification
    /// - Parameters:
    ///   - armSymmetry: Left-right arm swing symmetry (0-1)
    ///   - yawEnergy: Watch yaw energy (rad/s RMS)
    func updateWatchData(armSymmetry: Double, yawEnergy: Double) {
        watchArmSymmetry = armSymmetry
        watchYawEnergy = yawEnergy
    }
}
