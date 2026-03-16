//
//  WatchGaitAnalyzer.swift
//  TetraTrack Watch App
//
//  Full DSP gait classification pipeline running locally on Watch at 50Hz.
//  Uses shared FFT/HMM/Coherence/Hilbert components from TetraTrackShared.
//
//  Pipeline: WatchMotionManager (50Hz) → FrameTransformer (wrist mount)
//    → Buffers → FFT → CoherenceAnalyzer → GaitFeatureVector → GaitHMM
//    → Dwell time hysteresis → WatchGaitResult (1Hz to iPhone)
//

import Foundation
import Observation
import os
import TetraTrackShared

private let logger = Logger(subsystem: "dev.dreamfold.TetraTrack.watchkit", category: "WatchGaitAnalyzer")

/// Runs the full gait DSP pipeline on Watch, producing classified gait results
@Observable
final class WatchGaitAnalyzer {

    // MARK: - Public State

    /// Most recent gait classification result
    private(set) var currentGaitResult: WatchGaitResult?

    /// Whether analysis is active
    private(set) var isAnalyzing: Bool = false

    // MARK: - DSP Components

    private let frameTransformer = FrameTransformer()
    private let fftProcessor = FFTProcessor(windowSize: 256, sampleRate: 50.0)
    private let coherenceAnalyzer = CoherenceAnalyzer(segmentLength: 128, overlap: 64, sampleRate: 50)
    private let hmm = GaitHMM(sensorMount: .wrist)

    // MARK: - Buffers (256 samples = 5.12s at 50Hz)

    private let bufferSize = 256
    private var verticalBuffer: [Double] = []
    private var lateralBuffer: [Double] = []
    private var forwardBuffer: [Double] = []
    private var yawRateBuffer: [Double] = []

    // MARK: - FFT Timing

    /// FFT update rate: 6Hz (every ~0.167s)
    private let fftUpdateInterval: TimeInterval = 1.0 / 6.0
    private var lastFFTTime: Date = .distantPast

    // MARK: - Spectral Features

    private var strideFrequency: Double = 0
    private var bounceAmplitude: Double = 0
    private var lateralSymmetry: Double = 0
    private var verticalYawCoherence: Double = 0
    private var harmonicRatios: (h2: Double, h3: Double) = (0, 0)
    private var spectralEntropy: Double = 0

    // MARK: - Canter Lead Detection

    private var canterLead: String? = nil
    private var canterLeadConfidence: Double = 0

    // MARK: - Anti-Oscillation: Dwell Time Hysteresis

    /// Minimum consecutive FFT frames the HMM must favor a new gait before accepting.
    /// At 6Hz update rate, 18 frames = 3 seconds of sustained evidence.
    private let minimumDwellFrames = 18

    /// The gait currently being proposed but not yet accepted
    private var pendingState: HMMGaitState?

    /// How many consecutive frames the pending state has been the top candidate
    private var pendingStateCount: Int = 0

    /// Currently accepted gait state
    private var acceptedState: HMMGaitState = .stationary

    /// Confidence in accepted state
    private var acceptedConfidence: Double = 0

    // MARK: - Anti-Oscillation: EMA Smoothing on State Probabilities

    /// EMA alpha for state probability smoothing (lower = more smoothing)
    private let probabilitySmoothingAlpha: Double = 0.3

    /// Smoothed state probabilities (EMA-filtered)
    private var smoothedProbs: [Double] = [1.0, 0, 0, 0, 0]

    // MARK: - Calibration

    private var needsCalibration = true
    private var calibrationSampleCount = 0
    private let calibrationDelay: Int

    // MARK: - Boot Time Reference

    /// Boot time reference for converting CMDeviceMotion timestamps to Date
    private let bootTimeReference: Date

    // MARK: - Singleton

    static let shared = WatchGaitAnalyzer()

    init() {
        frameTransformer.mountPosition = .wrist
        calibrationDelay = MountPosition.wrist.calibrationDelay
        let uptime = ProcessInfo.processInfo.systemUptime
        bootTimeReference = Date(timeIntervalSinceNow: -uptime)
    }

    // MARK: - Lifecycle

    /// Start gait analysis — subscribe to motion samples
    func startAnalyzing() {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        needsCalibration = true
        calibrationSampleCount = 0
        reset()

        WatchMotionManager.shared.onMotionUpdate = { [weak self] sample in
            self?.processWatchSample(sample)
        }

        logger.info("Watch gait analysis started")
    }

    /// Stop gait analysis
    func stopAnalyzing() {
        guard isAnalyzing else { return }
        isAnalyzing = false
        WatchMotionManager.shared.onMotionUpdate = nil
        logger.info("Watch gait analysis stopped")
    }

    /// Reset all state
    func reset() {
        verticalBuffer.removeAll()
        lateralBuffer.removeAll()
        forwardBuffer.removeAll()
        yawRateBuffer.removeAll()

        strideFrequency = 0
        bounceAmplitude = 0
        lateralSymmetry = 0
        verticalYawCoherence = 0
        harmonicRatios = (0, 0)
        spectralEntropy = 0
        canterLead = nil
        canterLeadConfidence = 0

        acceptedState = .stationary
        acceptedConfidence = 0
        pendingState = nil
        pendingStateCount = 0
        smoothedProbs = [1.0, 0, 0, 0, 0]
        lastFFTTime = .distantPast
        currentGaitResult = nil
    }

    // MARK: - Sample Processing

    private func processWatchSample(_ watchSample: WatchMotionSample) {
        // Convert WatchMotionSample → shared MotionSample
        let sampleDate = bootTimeReference.addingTimeInterval(watchSample.timestamp)
        let sample = MotionSample(
            timestamp: sampleDate,
            accelerationX: watchSample.accelerationX,
            accelerationY: watchSample.accelerationY,
            accelerationZ: watchSample.accelerationZ,
            rotationX: watchSample.rotationX,
            rotationY: watchSample.rotationY,
            rotationZ: watchSample.rotationZ,
            pitch: watchSample.pitch,
            roll: watchSample.roll,
            yaw: watchSample.yaw,
            quaternionW: watchSample.quaternionW,
            quaternionX: watchSample.quaternionX,
            quaternionY: watchSample.quaternionY,
            quaternionZ: watchSample.quaternionZ
        )

        // Auto-calibration at session start
        if needsCalibration {
            calibrationSampleCount += 1
            if calibrationSampleCount >= calibrationDelay {
                frameTransformer.calibrate(with: sample)
                needsCalibration = false
                logger.info("Watch frame transformer calibrated after \(self.calibrationSampleCount) samples")
            }
        }

        // Transform to horse-relative frame
        let transformed = frameTransformer.transform(sample)

        // Buffer transformed data
        verticalBuffer.append(transformed.accel.vertical)
        lateralBuffer.append(transformed.accel.lateral)
        forwardBuffer.append(transformed.accel.forward)
        yawRateBuffer.append(transformed.rotation.yaw)

        // Maintain buffer size
        if verticalBuffer.count > bufferSize {
            verticalBuffer.removeFirst()
            lateralBuffer.removeFirst()
            forwardBuffer.removeFirst()
            yawRateBuffer.removeFirst()
        }

        // Update bounce amplitude (AC-coupled RMS)
        if verticalBuffer.count >= 20 {
            let window = Array(verticalBuffer.suffix(min(100, verticalBuffer.count)))
            let mean = window.reduce(0, +) / Double(window.count)
            let ac = window.map { $0 - mean }
            bounceAmplitude = sqrt(ac.map { $0 * $0 }.reduce(0, +) / Double(ac.count))
        }

        // Run FFT at 6Hz update rate
        let now = sampleDate
        if !needsCalibration && now.timeIntervalSince(lastFFTTime) >= fftUpdateInterval && verticalBuffer.count >= 128 {
            performSpectralAnalysis()
            lastFFTTime = now

            // Build result after each spectral update
            currentGaitResult = buildResult(timestamp: now)
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

        // Coherence calculations
        if lateralBuffer.count >= 128 && forwardBuffer.count >= 128 && yawRateBuffer.count >= 128 {
            lateralSymmetry = coherenceAnalyzer.coherence(
                signal1: forwardBuffer,
                signal2: lateralBuffer,
                atFrequency: strideFrequency
            )

            verticalYawCoherence = coherenceAnalyzer.coherence(
                signal1: verticalBuffer,
                signal2: yawRateBuffer,
                atFrequency: strideFrequency
            )
        }

        // Build feature vector (no GPS on Watch — use 0)
        let yawWindow = Array(yawRateBuffer.suffix(min(100, yawRateBuffer.count)))
        let yawMean = yawWindow.reduce(0, +) / max(1.0, Double(yawWindow.count))
        let yawAC = yawWindow.map { $0 - yawMean }
        let rawYawRMS = sqrt(yawAC.map { $0 * $0 }.reduce(0, +) / max(1.0, Double(yawAC.count)))
        let yawRMS = rawYawRMS * 0.7  // Wrist yaw rate scale factor

        let features = GaitFeatureVector(
            strideFrequency: strideFrequency,
            h2Ratio: harmonicRatios.h2,
            h3Ratio: harmonicRatios.h3,
            spectralEntropy: spectralEntropy,
            xyCoherence: lateralSymmetry,
            zYawCoherence: verticalYawCoherence,
            normalizedVerticalRMS: bounceAmplitude,
            yawRateRMS: yawRMS,
            gpsSpeed: 0,        // No GPS on Watch
            gpsAccuracy: 100    // Low accuracy flag — disables GPS speed constraints in HMM
        )

        // Update HMM
        hmm.update(with: features)

        // Apply EMA smoothing on state probabilities
        let rawProbs = HMMGaitState.allCases.map { hmm.probability(of: $0) }
        for i in 0..<smoothedProbs.count {
            smoothedProbs[i] = probabilitySmoothingAlpha * rawProbs[i] + (1 - probabilitySmoothingAlpha) * smoothedProbs[i]
        }

        // Find best state from smoothed probabilities
        let bestIdx = smoothedProbs.enumerated().max { $0.element < $1.element }?.offset ?? 0
        let newState = HMMGaitState(rawValue: bestIdx) ?? .stationary
        let newConfidence = smoothedProbs[bestIdx]

        // Apply dwell time hysteresis
        applyDwellTime(newState: newState, confidence: newConfidence)

        // Detect canter lead when in canter or gallop
        detectCanterLead()
    }

    // MARK: - Dwell Time Hysteresis

    private func applyDwellTime(newState: HMMGaitState, confidence: Double) {
        if newState != acceptedState && confidence > 0.65 {
            // Confidence margin: new state must exceed current state's probability by 2x
            let currentProb = smoothedProbs[acceptedState.rawValue]
            let newProb = smoothedProbs[newState.rawValue]
            guard newProb > currentProb * 2.0 || currentProb < 0.1 else {
                // Not enough margin — don't start pending transition
                return
            }

            if newState == pendingState {
                pendingStateCount += 1
            } else {
                pendingState = newState
                pendingStateCount = 1
            }

            if pendingStateCount >= minimumDwellFrames {
                acceptedState = newState
                acceptedConfidence = confidence
                pendingState = nil
                pendingStateCount = 0
                logger.error("TT: Gait transition: \(newState.name) (conf: \(String(format: "%.2f", confidence)))")
            }
        } else if newState == acceptedState {
            // Current state confirmed — reset pending
            acceptedConfidence = confidence
            pendingState = nil
            pendingStateCount = 0
        }
    }

    // MARK: - Canter Lead Detection

    private func detectCanterLead() {
        guard acceptedState == .canter || acceptedState == .gallop else {
            canterLead = nil
            canterLeadConfidence = 0
            return
        }

        guard lateralBuffer.count >= 128, yawRateBuffer.count >= 128 else { return }

        // Hilbert transform phase analysis
        let lateralPhase = HilbertTransform.instantaneousPhase(lateralBuffer)
        let yawPhase = HilbertTransform.instantaneousPhase(yawRateBuffer)

        let minLength = min(lateralPhase.count, yawPhase.count)
        guard minLength > 0 else { return }

        var phaseDiff: [Double] = []
        phaseDiff.reserveCapacity(minLength)

        for i in 0..<minLength {
            var diff = lateralPhase[i] - yawPhase[i]
            while diff > .pi { diff -= 2 * .pi }
            while diff < -.pi { diff += 2 * .pi }
            phaseDiff.append(diff)
        }

        // Circular mean of phase difference
        let sinSum = phaseDiff.reduce(0) { $0 + sin($1) }
        let cosSum = phaseDiff.reduce(0) { $0 + cos($1) }
        let meanPhase = atan2(sinSum, cosSum)
        let phaseDegrees = meanPhase * 180.0 / .pi

        // Coherence at stride frequency
        let targetFreq = strideFrequency > 0 ? strideFrequency : 2.0
        let coherence = coherenceAnalyzer.coherence(
            signal1: lateralBuffer,
            signal2: yawRateBuffer,
            atFrequency: targetFreq
        )

        // Left lead: +45° to +135°, Right lead: -45° to -135°
        if phaseDegrees > 45 && phaseDegrees < 135 {
            canterLead = "left"
            canterLeadConfidence = coherence * (1.0 - abs(phaseDegrees - 90) / 45.0)
        } else if phaseDegrees < -45 && phaseDegrees > -135 {
            canterLead = "right"
            canterLeadConfidence = coherence * (1.0 - abs(phaseDegrees + 90) / 45.0)
        } else {
            canterLead = nil
            canterLeadConfidence = 0
        }
    }

    // MARK: - Result Building

    private func buildResult(timestamp: Date) -> WatchGaitResult {
        WatchGaitResult(
            gaitState: acceptedState.name,
            confidence: acceptedConfidence,
            strideFrequency: strideFrequency,
            bounceAmplitude: bounceAmplitude,
            lateralSymmetry: lateralSymmetry,
            canterLead: canterLead,
            canterLeadConfidence: canterLeadConfidence,
            timestamp: timestamp
        )
    }
}
