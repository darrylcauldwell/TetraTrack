//
//  GaitAnalyzer.swift
//  TetraTrack
//
//  Physics-based gait detection using FFT spectral analysis, Hidden Markov Model,
//  and horse profile biomechanical priors

import CoreMotion
import Observation
import SwiftData
import TetraTrackShared
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

    // MARK: - Watch Motion Data

    private var lastWatchVerticalOscillation: Double = 0
    private var lastWatchMovementIntensity: Double = 0
    private var lastWatchRhythmScore: Double = 0
    private var lastWatchPostureStability: Double = 0
    private var lastWatchUpdateTime: Date = .distantPast

    /// Update Watch motion data for gait feature vector enrichment
    func updateWatchData(
        verticalOscillation: Double,
        movementIntensity: Double,
        rhythmScore: Double = 0,
        postureStability: Double = 0
    ) {
        lastWatchVerticalOscillation = verticalOscillation
        lastWatchMovementIntensity = movementIntensity
        lastWatchRhythmScore = rhythmScore
        lastWatchPostureStability = postureStability
        lastWatchUpdateTime = Date()
    }

    // MARK: - Cadence Regularity Buffer

    /// Circular buffer of recent stride frequencies for CV computation
    private var recentStrideFrequencies: [Double] = []
    private let cadenceBufferSize = 10

    // MARK: - GPS and Legacy Support

    private var speedSamples: [Double] = []
    private let speedSampleWindow = 5
    private var lastGPSSpeed: Double = 0
    private var lastGPSAccuracy: Double = 100.0  // Horizontal accuracy in meters

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

    // MARK: - Dwell Time (anti-oscillation)

    /// Minimum consecutive frames the HMM must favor a new gait before we accept the transition.
    /// At 6 Hz update rate, 18 frames = 3 seconds of sustained evidence.
    private let minimumDwellFrames = 18

    /// The gait currently being "proposed" but not yet accepted
    private var pendingGait: GaitType?

    /// How many consecutive frames the pending gait has been the top candidate
    private var pendingGaitFrameCount: Int = 0

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
        frameTransformer.mountPosition = position.mountPosition
    }

    /// Configure analyzer with horse profile for breed-specific priors
    func configure(for horse: Horse?) {
        self.horseProfile = horse
        if let horse = horse {
            // Pass breed, age adjustment, and custom tuning to HMM
            hmm.configure(
                with: horse.typedBreed.biomechanicalPriors,
                ageAdjustment: horse.ageAdjustmentFactor,
                customSpeedBounds: horse.hasCustomGaitSettings ? horse.adjustedSpeedBounds() : nil,
                transitionProbability: horse.hasCustomGaitSettings ? horse.adjustedTransitionProbability : nil,
                canterMultiplier: horse.hasCustomGaitSettings ? horse.canterDetectionMultiplier : nil,
                frequencyOffset: horse.hasCustomGaitSettings ? horse.gaitFrequencyOffset : nil
            )

            // Apply learned per-horse gait parameters (adaptive tuning from previous rides)
            // Skip if weight has changed >10% since parameters were learned
            if let learned = horse.learnedGaitParameters, !horse.hasStaleLearnedParameters {
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
        calibrationStatus = .pending
        recentVerticalRMS = 0
        recentRotationRates = []
        pendingGait = nil
        pendingGaitFrameCount = 0
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
        recentStrideFrequencies = []
        segmentDistance = 0
        lastFFTTime = .distantPast
        lastWatchVerticalOscillation = 0
        lastWatchMovementIntensity = 0
        lastWatchRhythmScore = 0
        lastWatchPostureStability = 0
        lastWatchUpdateTime = .distantPast
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
                // Track recent vertical acceleration for bounce gate (DC-removed RMS)
                let settleWindow = Array(verticalBuffer.suffix(min(20, verticalBuffer.count)))
                let settleMean = settleWindow.isEmpty ? 0.0 : settleWindow.reduce(0, +) / Double(settleWindow.count)
                let settleAC = settleWindow.map { $0 - settleMean }
                recentVerticalRMS = sqrt(
                    settleAC.map { $0 * $0 }.reduce(0, +) / max(1.0, Double(settleAC.count))
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
                let calWindow = Array(verticalBuffer.suffix(min(20, verticalBuffer.count)))
                let calMean = calWindow.isEmpty ? 0.0 : calWindow.reduce(0, +) / Double(calWindow.count)
                let calAC = calWindow.map { $0 - calMean }
                recentVerticalRMS = sqrt(
                    calAC.map { $0 * $0 }.reduce(0, +) / max(1.0, Double(calAC.count))
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

        // Update bounce amplitude (AC-coupled RMS over up to 100 samples)
        // DC removal prevents a constant offset from inflating the RMS
        if verticalBuffer.count >= 20 {
            let window = Array(verticalBuffer.suffix(min(100, verticalBuffer.count)))
            let mean = window.reduce(0, +) / Double(window.count)
            let ac = window.map { $0 - mean }
            bounceAmplitude = sqrt(ac.map { $0 * $0 }.reduce(0, +) / Double(ac.count))
        }

        // Perform FFT analysis at fixed rate (only after calibration is complete)
        let now = sample.timestamp
        if calibrationStatus == .ready && now.timeIntervalSince(lastFFTTime) >= fftUpdateInterval && verticalBuffer.count >= 128 {
            performSpectralAnalysis()
            lastFFTTime = now
        }
    }

    // MARK: - Spectral Analysis

    // Temporal window sizes and rationale:
    // - FFT window: 256 samples (2.56s at 100Hz) — captures ~2 full stride cycles at walk
    // - Bounce amplitude RMS: up to 100 samples (1s) — responsive to gait changes
    // - Yaw RMS: up to 100 samples (1s) — matches bounce amplitude window
    // - Coherence segments: 128 samples with 64-sample overlap — Welch's method
    // - FFT update rate: 6 Hz (every 0.167s) — responsive without excessive computation
    // - Calibration settling: 20 samples (0.2s) — quick settling check

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

        // Yaw RMS with DC removal over up to 100 samples
        let yawWindow = Array(yawRateBuffer.suffix(min(100, yawRateBuffer.count)))
        let yawMean = yawWindow.reduce(0, +) / max(1.0, Double(yawWindow.count))
        let yawAC = yawWindow.map { $0 - yawMean }
        let rawYawRMS = sqrt(yawAC.map { $0 * $0 }.reduce(0, +) / max(1.0, Double(yawAC.count)))

        // Scale yaw RMS for thigh mount (thigh amplifies yaw due to leg rotation)
        let yawRateScaleFactor: Double = mountPosition == .jodhpurThigh ? 0.5 : 1.0
        let yawRMS = rawYawRMS * yawRateScaleFactor

        let watchDataAge = Date().timeIntervalSince(lastWatchUpdateTime)

        // Stride length: GPS speed / stride frequency (when GPS is accurate and freq is plausible)
        let computedStrideLength: Double
        if lastGPSAccuracy < 20.0 && strideFrequency > 0.5 && lastGPSSpeed > 0.5 {
            computedStrideLength = lastGPSSpeed / strideFrequency
        } else {
            computedStrideLength = 0  // Unavailable — HMM will use uninformative variance
        }

        // Cadence regularity: coefficient of variation of recent stride frequencies
        if strideFrequency > 0.5 {
            recentStrideFrequencies.append(strideFrequency)
            if recentStrideFrequencies.count > cadenceBufferSize {
                recentStrideFrequencies.removeFirst()
            }
        }
        let computedCadenceRegularity: Double
        if recentStrideFrequencies.count >= 3 {
            let mean = recentStrideFrequencies.reduce(0, +) / Double(recentStrideFrequencies.count)
            let variance = recentStrideFrequencies.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(recentStrideFrequencies.count)
            computedCadenceRegularity = mean > 0 ? sqrt(variance) / mean : 0
        } else {
            computedCadenceRegularity = 0  // Insufficient data — HMM will use uninformative variance
        }

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
            watchVerticalOscillation: lastWatchVerticalOscillation,
            watchMovementIntensity: lastWatchMovementIntensity,
            watchRhythmScore: lastWatchRhythmScore,
            watchPostureStability: lastWatchPostureStability,
            watchDataAge: watchDataAge,
            strideLength: computedStrideLength,
            cadenceRegularity: computedCadenceRegularity
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
                gpsAccuracy: features.gpsAccuracy,
                watchVerticalOscillation: features.watchVerticalOscillation,
                watchMovementIntensity: features.watchMovementIntensity,
                watchRhythmScore: features.watchRhythmScore,
                watchPostureStability: features.watchPostureStability,
                watchDataAge: features.watchDataAge
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
                gpsSpeed: lastGPSSpeed,
                watchVerticalOscillation: lastWatchVerticalOscillation,
                watchMovementIntensity: lastWatchMovementIntensity,
                watchRhythmScore: lastWatchRhythmScore,
                watchPostureStability: lastWatchPostureStability,
                watchDataAge: watchDataAge
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

        // Only change gait if confidence is high enough AND sustained for minimum dwell time
        if newGait != currentGait && gaitConfidence > 0.65 {
            if newGait == pendingGait {
                pendingGaitFrameCount += 1
            } else {
                pendingGait = newGait
                pendingGaitFrameCount = 1
            }

            if pendingGaitFrameCount >= minimumDwellFrames {
                let previousGait = currentGait
                finalizeCurrentSegment()
                currentGait = newGait
                startNewSegment(gait: newGait)
                onGaitChange?(previousGait, newGait)
                pendingGait = nil
                pendingGaitFrameCount = 0
            }
        } else if newGait == currentGait {
            pendingGait = nil
            pendingGaitFrameCount = 0
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

    /// Set gait state from Watch classification (Watch-primary mode)
    /// Bypasses iPhone HMM and applies Watch result directly
    func setGaitFromWatch(_ gait: GaitType, confidence: Double) {
        let previousGait = currentGait
        if gait != previousGait {
            finalizeCurrentSegment()
            currentGait = gait
            gaitConfidence = confidence
            startNewSegment(gait: gait)
            onGaitChange?(previousGait, gait)
        } else {
            gaitConfidence = confidence
        }
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
                gpsSpeed: features.gpsSpeed,
                watchVerticalOscillation: features.watchVerticalOscillation,
                watchMovementIntensity: features.watchMovementIntensity,
                watchRhythmScore: features.watchRhythmScore,
                watchPostureStability: features.watchPostureStability,
                watchDataAge: features.watchDataAge
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

        // Apply gait change with dwell time
        if newGait != currentGait && gaitConfidence > 0.65 {
            if newGait == pendingGait {
                pendingGaitFrameCount += 1
            } else {
                pendingGait = newGait
                pendingGaitFrameCount = 1
            }

            if pendingGaitFrameCount >= minimumDwellFrames {
                let previousGait = currentGait
                currentGait = newGait
                onGaitChange?(previousGait, newGait)
                pendingGait = nil
                pendingGaitFrameCount = 0
            }
        } else if newGait == currentGait {
            pendingGait = nil
            pendingGaitFrameCount = 0
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

