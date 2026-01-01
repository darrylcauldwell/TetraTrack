//
//  GaitAnalyzer.swift
//  TetraTrack
//
//  Physics-based gait detection using FFT spectral analysis, Hidden Markov Model,
//  and horse profile biomechanical priors

import CoreMotion
import Observation
import SwiftData
import os

@Observable
final class GaitAnalyzer: Resettable {

    // MARK: - Diagnostic State (DEBUG)

    #if DEBUG
    /// Collected diagnostic snapshots for analysis
    private(set) var diagnosticSnapshots: [GaitDiagnosticSnapshot] = []

    /// Enable/disable diagnostic logging (default: enabled in DEBUG)
    var diagnosticLoggingEnabled: Bool = true
    #endif

    // MARK: - Diagnostic Collection (for Gait Testing rides)

    /// When true, diagnostic entries are collected each HMM update
    var collectDiagnostics: Bool = false

    /// Collected diagnostic entries (populated when collectDiagnostics is true)
    private(set) var diagnosticEntries: [GaitDiagnosticEntry] = []

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
    private let fftUpdateInterval: TimeInterval = 0.167  // 6 Hz update rate

    // MARK: - GPS and Legacy Support

    private var speedSamples: [Double] = []
    private let speedSampleWindow = 5
    private var lastGPSSpeed: Double = 0
    private var lastGPSAccuracy: Double = 100.0  // Horizontal accuracy in meters

    // MARK: - Apple Watch Data

    /// Watch arm symmetry from WatchConnectivity (0-1, 0 if unavailable)
    var watchArmSymmetry: Double = 0

    /// Watch yaw energy from WatchConnectivity (rad/s RMS, 0 if unavailable)
    var watchYawEnergy: Double = 0

    // Legacy buffers for backwards compatibility
    private var verticalAccelSamples: [Double] = []
    private var sampleTimestamps: [Date] = []
    private let motionSampleWindow = 100

    // MARK: - Mount Position

    /// Phone mounting position, affects calibration timing and filtering
    var mountPosition: PhoneMountPosition = .jodhpurThigh

    /// Calibration status during ride start
    enum CalibrationStatus: String {
        case pending = "Waiting..."
        case settling = "Settling..."
        case calibrating = "Calibrating..."
        case ready = "Ready"
    }

    /// Current calibration status for UI display
    var calibrationStatus: CalibrationStatus = .pending

    /// Callback when calibration completes
    var onCalibrationComplete: (() -> Void)?

    /// Recent vertical RMS for bounce amplitude gate
    private var recentVerticalRMS: Double = 0

    /// Recent rotation rate magnitudes for settling detection during calibration
    private var recentRotationRates: [Double] = []

    /// Maximum rotation rate (rad/s) to consider the phone settled for calibration
    private let calibrationRotationThreshold: Double = 0.3

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

    /// Configure analyzer for a specific phone mount position
    func configure(mountPosition position: PhoneMountPosition) {
        mountPosition = position
        frameTransformer.driftThreshold = position.driftThreshold
    }

    /// Configure analyzer with horse profile for breed-specific priors
    func configure(for horse: Horse?) {
        self.horseProfile = horse
        if let horse = horse {
            // Pass breed, age adjustment, and custom tuning to HMM
            hmm.configure(
                for: horse.typedBreed,
                ageAdjustment: horse.ageAdjustmentFactor,
                customSpeedBounds: horse.hasCustomGaitSettings ? horse.adjustedSpeedBounds() : nil,
                transitionProbability: horse.hasCustomGaitSettings ? horse.adjustedTransitionProbability : nil,
                canterMultiplier: horse.hasCustomGaitSettings ? horse.canterDetectionMultiplier : nil,
                frequencyOffset: horse.hasCustomGaitSettings ? horse.gaitFrequencyOffset : nil
            )

            // Apply learned per-horse gait parameters (adaptive tuning from previous rides)
            if let learned = horse.learnedGaitParameters {
                hmm.applyLearnedParameters(learned)
            }
        }
    }

    // MARK: - Lifecycle

    /// Whether we need to calibrate on first motion sample
    private var needsCalibration: Bool = true

    /// Number of samples to wait before calibrating (let sensors stabilize)
    private var calibrationSampleCount: Int = 0

    func startAnalyzing(for ride: Ride) {
        guard !isAnalyzing else { return }

        currentRide = ride
        isAnalyzing = true
        currentGait = .stationary

        // Reset all buffers
        clearBuffers()

        // Reset HMM
        hmm.reset()

        // Reset frame transformer calibration for fresh calibration
        frameTransformer.resetCalibration()
        needsCalibration = true
        calibrationSampleCount = 0

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
        calibrationStatus = .pending
        recentVerticalRMS = 0
        recentRotationRates = []
        collectDiagnostics = false
        diagnosticEntries.removeAll()
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
        recentRotationRates = []
        segmentDistance = 0
        lastFFTTime = .distantPast
    }

    // MARK: - Process Location (GPS Speed)

    /// Called with each new location update (~1Hz)
    /// - Parameters:
    ///   - speed: GPS speed in m/s
    ///   - distance: Distance traveled since last update in meters
    ///   - horizontalAccuracy: GPS horizontal accuracy in meters (lower = better)
    func processLocation(speed: Double, distance: Double, horizontalAccuracy: Double = 10.0) {
        guard isAnalyzing else { return }

        speedSamples.append(speed)
        if speedSamples.count > speedSampleWindow {
            speedSamples.removeFirst()
        }

        lastGPSSpeed = speedSamples.isEmpty ? 0 : speedSamples.reduce(0, +) / Double(speedSamples.count)
        lastGPSAccuracy = horizontalAccuracy
        segmentDistance += distance
    }

    // MARK: - Process Motion (Accelerometer + Gyroscope)

    /// Called with each motion update (~50-100Hz)
    func processMotion(_ sample: MotionSample) {
        guard isAnalyzing else { return }

        // Auto-calibrate frame transformer after position-aware delay
        // This allows sensors to stabilize before capturing reference orientation
        // Jodhpur thigh needs longer settling (1s) vs jacket chest (0.5s)
        // Checks both vertical RMS and rotation rate to detect phone-in-hand handling
        if needsCalibration {
            calibrationSampleCount += 1
            let delay = mountPosition.calibrationDelay
            let forceDelay = delay * 10  // Force calibrate after 10x delay (10s thigh, 5s chest)

            if calibrationSampleCount < delay / 2 {
                calibrationStatus = .pending
            } else if calibrationSampleCount < delay {
                calibrationStatus = .settling
                // Track recent vertical acceleration for bounce gate
                recentVerticalRMS = sqrt(
                    verticalBuffer.suffix(20).map { $0 * $0 }.reduce(0, +) / max(1.0, Double(min(20, verticalBuffer.count)))
                )
                // Track rotation rate for handling detection
                recentRotationRates.append(sample.rotationMagnitude)
                if recentRotationRates.count > 30 {
                    recentRotationRates.removeFirst()
                }
            } else {
                calibrationStatus = .calibrating
                // Continue tracking rotation rate and vertical RMS during calibrating phase
                recentRotationRates.append(sample.rotationMagnitude)
                if recentRotationRates.count > 30 {
                    recentRotationRates.removeFirst()
                }
                recentVerticalRMS = sqrt(
                    verticalBuffer.suffix(20).map { $0 * $0 }.reduce(0, +) / max(1.0, Double(min(20, verticalBuffer.count)))
                )

                // Settling gate: both vertical RMS AND rotation rate must be low
                let isVerticallyStill = recentVerticalRMS < 0.2 || verticalBuffer.count < 20
                let recentRotationRMS = recentRotationRates.isEmpty ? 0.0 :
                    sqrt(recentRotationRates.map { $0 * $0 }.reduce(0, +) / Double(recentRotationRates.count))
                let isRotationallyStill = recentRotationRMS < calibrationRotationThreshold || recentRotationRates.count < 10

                // Calibrate when phone is settled, or force-calibrate at timeout
                if (isVerticallyStill && isRotationallyStill) || calibrationSampleCount >= forceDelay {
                    frameTransformer.calibrate(with: sample)
                    needsCalibration = false
                    calibrationStatus = .ready
                    Log.tracking.info("Frame transformer auto-calibrated (mount: \(self.mountPosition.rawValue), samples: \(self.calibrationSampleCount))")
                    onCalibrationComplete?()
                }
            }
        }

        // Transform to horse-relative frame
        let transformed = frameTransformer.transform(sample)

        // Add to physics buffers
        // Use transformed values for consistent frame of reference
        verticalBuffer.append(transformed.accel.vertical)
        lateralBuffer.append(transformed.accel.lateral)
        forwardBuffer.append(transformed.accel.forward)
        // Use transformed yaw rate for frame consistency (not raw sample.yawRate)
        yawRateBuffer.append(transformed.rotation.yaw)
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

        // Perform FFT analysis at fixed rate (only after calibration is complete)
        let now = sample.timestamp
        if calibrationStatus == .ready && now.timeIntervalSince(lastFFTTime) >= fftUpdateInterval && verticalBuffer.count >= 128 {
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
            gpsAccuracy: lastGPSAccuracy,
            watchArmSymmetry: watchArmSymmetry,
            watchYawEnergy: watchYawEnergy
        )

        // Update HMM
        hmm.update(with: features)

        // Get new state
        let hmmState = hmm.currentState
        gaitConfidence = hmm.stateConfidence

        let newGait = gaitTypeFromHMMState(hmmState)

        // Collect diagnostic entry for gait testing rides
        if collectDiagnostics {
            let entry = GaitDiagnosticEntry(
                timestamp: Date(),
                detectedGait: hmmState.name,
                confidence: hmm.stateConfidence,
                stateProbabilities: hmm.stateProbabilitiesDict,
                strideFrequency: features.strideFrequency,
                h2Ratio: features.h2Ratio,
                h3Ratio: features.h3Ratio,
                spectralEntropy: features.spectralEntropy,
                xyCoherence: features.xyCoherence,
                zYawCoherence: features.zYawCoherence,
                normalizedVerticalRMS: features.normalizedVerticalRMS,
                yawRateRMS: features.yawRateRMS,
                gpsSpeed: features.gpsSpeed,
                gpsAccuracy: features.gpsAccuracy
            )
            diagnosticEntries.append(entry)
        }

        #if DEBUG
        // Diagnostic logging for gallop analysis
        let gallopProb = hmm.probability(of: .gallop)
        let shouldLog = gallopProb > 0.25 || newGait == .gallop || currentGait == .gallop

        if shouldLog && diagnosticLoggingEnabled {
            let featureSnapshot = GaitFeatureSnapshot(
                strideFrequency: strideFrequency,
                h2Ratio: harmonicRatios.h2,
                h3Ratio: harmonicRatios.h3,
                h3h2Ratio: harmonicRatios.h2 > 0.01 ? harmonicRatios.h3 / harmonicRatios.h2 : 0,
                spectralEntropy: spectralEntropy,
                verticalRMSRaw: bounceAmplitude,
                verticalRMSNormalized: normalizedRMS,
                yawRMS: yawRMS,
                xyCoherence: leftRightSymmetry,
                zYawCoherence: verticalYawCoherence,
                gpsSpeed: lastGPSSpeed
            )

            let horseSnapshot = HorseProfileSnapshot(
                present: horseProfile != nil,
                breed: horseProfile?.typedBreed.rawValue,
                heightHands: horseProfile?.heightHands,
                weightKg: horseProfile?.weight
            )

            let transitionInfo = "\(currentGait.rawValue) → \(newGait.rawValue) (conf: \(String(format: "%.3f", gaitConfidence)))"

            let snapshot = GaitDiagnosticSnapshot(
                timestamp: Date(),
                currentGait: hmmStateFromGaitType(currentGait),
                proposedGait: hmmState,
                confidence: gaitConfidence,
                stateProbs: hmm.getAllStateProbabilities(),
                features: featureSnapshot,
                horseProfile: horseSnapshot,
                transitionInfo: transitionInfo
            )

            diagnosticSnapshots.append(snapshot)
            Log.gait.debug("\(snapshot.description)")

            // Log detailed emission comparison when gallop is being considered
            if gallopProb > 0.3 {
                hmm.logCanterGallopComparison(features)
            }

        }
        #endif

        // Only change gait if confidence is high enough
        if newGait != currentGait && gaitConfidence > 0.65 {
            let previousGait = currentGait
            finalizeCurrentSegment()
            currentGait = newGait
            startNewSegment(gait: newGait)
            onGaitChange?(previousGait, newGait)
        }
    }

    #if DEBUG
    /// Convert GaitType to HMMGaitState for diagnostic purposes
    private func hmmStateFromGaitType(_ gait: GaitType) -> HMMGaitState {
        switch gait {
        case .stationary: return .stationary
        case .walk: return .walk
        case .trot: return .trot
        case .canter: return .canter
        case .gallop: return .gallop
        }
    }
    #endif

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

    /// Update Apple Watch motion data for gait classification
    /// - Parameters:
    ///   - armSymmetry: Left-right arm swing symmetry (0-1)
    ///   - yawEnergy: Watch yaw energy (rad/s RMS)
    func updateWatchData(armSymmetry: Double, yawEnergy: Double) {
        watchArmSymmetry = armSymmetry
        watchYawEnergy = yawEnergy
    }

    // MARK: - Diagnostic Methods (DEBUG)

    #if DEBUG
    /// Clear diagnostic data
    func clearDiagnostics() {
        diagnosticSnapshots = []
    }

    /// Get transition dynamics for canter-gallop analysis
    func analyzeTransitionDynamics(withFeatures features: GaitFeatureVector) -> (canterToGallop: TransitionDynamicsResult, gallopToCanter: TransitionDynamicsResult) {
        let canterToGallop = hmm.simulateTransitionDynamics(
            from: .canter,
            to: .gallop,
            favoringFeatures: features,
            maxSteps: 100,
            updateRateHz: 4.0
        )

        let gallopToCanter = hmm.simulateTransitionDynamics(
            from: .gallop,
            to: .canter,
            favoringFeatures: features,
            maxSteps: 100,
            updateRateHz: 4.0
        )

        return (canterToGallop, gallopToCanter)
    }

    /// Inject synthetic features for testing (bypasses motion processing)
    func injectSyntheticFeatures(_ features: GaitFeatureVector) {
        // Update internal state as if FFT was computed
        strideFrequency = features.strideFrequency
        harmonicRatios = (features.h2Ratio, features.h3Ratio)
        spectralEntropy = features.spectralEntropy
        leftRightSymmetry = features.xyCoherence
        verticalYawCoherence = features.zYawCoherence
        bounceAmplitude = features.normalizedVerticalRMS
        lastGPSSpeed = features.gpsSpeed

        // Update HMM
        hmm.update(with: features)

        // Get new state
        let hmmState = hmm.currentState
        gaitConfidence = hmm.stateConfidence

        let newGait = gaitTypeFromHMMState(hmmState)

        // Diagnostic logging
        let gallopProb = hmm.probability(of: .gallop)
        let shouldLog = gallopProb > 0.25 || newGait == .gallop || currentGait == .gallop

        if shouldLog && diagnosticLoggingEnabled {
            let featureSnapshot = GaitFeatureSnapshot(
                strideFrequency: features.strideFrequency,
                h2Ratio: features.h2Ratio,
                h3Ratio: features.h3Ratio,
                h3h2Ratio: features.h2Ratio > 0.01 ? features.h3Ratio / features.h2Ratio : 0,
                spectralEntropy: features.spectralEntropy,
                verticalRMSRaw: features.normalizedVerticalRMS,
                verticalRMSNormalized: features.normalizedVerticalRMS,
                yawRMS: features.yawRateRMS,
                xyCoherence: features.xyCoherence,
                zYawCoherence: features.zYawCoherence,
                gpsSpeed: features.gpsSpeed
            )

            let snapshot = GaitDiagnosticSnapshot(
                timestamp: Date(),
                currentGait: hmmStateFromGaitType(currentGait),
                proposedGait: hmmState,
                confidence: gaitConfidence,
                stateProbs: hmm.getAllStateProbabilities(),
                features: featureSnapshot,
                horseProfile: HorseProfileSnapshot(present: horseProfile != nil, breed: horseProfile?.typedBreed.rawValue, heightHands: horseProfile?.heightHands, weightKg: horseProfile?.weight),
                transitionInfo: "\(currentGait.rawValue) → \(newGait.rawValue)"
            )

            diagnosticSnapshots.append(snapshot)
            Log.gait.debug("\(snapshot.description)")

        }

        // Apply gait change
        if newGait != currentGait && gaitConfidence > 0.65 {
            let previousGait = currentGait
            currentGait = newGait
            onGaitChange?(previousGait, newGait)
        }
    }

    /// Get gallop probability from HMM
    func getGallopProbability() -> Double {
        return hmm.probability(of: .gallop)
    }

    /// Get canter probability from HMM
    func getCanterProbability() -> Double {
        return hmm.probability(of: .canter)
    }
    #endif
}

