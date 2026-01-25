//
//  LeadAnalyzer.swift
//  TrackRide
//
//  Physics-based lead detection using Hilbert transform phase analysis.
//  Detects lead leg (left/right) during canter and gallop by analyzing
//  the phase relationship between lateral acceleration and yaw rate.

import Foundation

/// Analyzes motion data to detect which lead leg the horse is using during canter/gallop
final class LeadAnalyzer: Resettable {

    // MARK: - Public Properties

    /// Currently detected lead
    private(set) var currentLead: Lead = .unknown

    /// Confidence in current lead detection (0-1)
    private(set) var currentConfidence: Double = 0.0

    /// Total duration on left lead
    private(set) var totalLeftLeadDuration: TimeInterval = 0.0

    /// Total duration on right lead
    private(set) var totalRightLeadDuration: TimeInterval = 0.0

    // MARK: - New Physics-Based Outputs

    /// Phase angle between lateral acceleration and yaw rate (degrees)
    /// +90° indicates left lead, -90° indicates right lead
    var phaseAngle: Double = 0

    /// Lead quality metric (coherence × |sin(phase)|)
    /// Higher values indicate clearer lead detection
    var leadQuality: Double = 0

    /// Current stride frequency for lead analysis
    var strideFrequency: Double = 0

    // MARK: - Configuration

    /// Minimum confidence threshold to report a lead (70%)
    private let confidenceThreshold: Double = 0.7

    /// Size of rolling window in samples (128 samples ≈ 1.3s at 100Hz)
    private let windowSize: Int = 128

    /// Minimum samples needed before analyzing
    private let minimumSamples: Int = 64

    // MARK: - Buffers

    /// Rolling buffer of lateral acceleration samples
    private var lateralBuffer: [Double] = []

    /// Rolling buffer of yaw rate samples
    private var yawBuffer: [Double] = []

    /// Coherence analyzer for phase confidence
    private let coherenceAnalyzer = CoherenceAnalyzer(segmentLength: 64, overlap: 32, sampleRate: 100)

    // MARK: - Internal State

    /// Timestamps for duration tracking
    private var lastUpdateTime: Date?
    private var leadStartTime: Date?

    /// Whether currently in a lead-detectable gait
    private var isInCanterOrGallop: Bool = false

    /// Last FFT analysis time
    private var lastAnalysisTime: Date = .distantPast
    private let analysisInterval: TimeInterval = 0.25  // 4 Hz

    init() {}

    // MARK: - Public Methods

    /// Process a motion sample during canter or gallop
    /// - Parameters:
    ///   - sample: The motion sample from MotionManager
    ///   - currentGait: The current detected gait type
    func processMotionSample(_ sample: MotionSample, currentGait: GaitType) {
        let now = sample.timestamp

        // Only analyze during canter or gallop
        let wasInCanterOrGallop = isInCanterOrGallop
        isInCanterOrGallop = (currentGait == .canter || currentGait == .gallop)

        if !isInCanterOrGallop {
            // Clear buffers when not in canter/gallop
            if wasInCanterOrGallop {
                finalizeCurrentLead(at: now)
            }
            clearBuffers()
            currentLead = .unknown
            currentConfidence = 0.0
            phaseAngle = 0
            leadQuality = 0
            lastUpdateTime = now
            return
        }

        // Started canter/gallop
        if !wasInCanterOrGallop {
            leadStartTime = now
        }

        // Add to buffers
        lateralBuffer.append(sample.lateralAcceleration)
        yawBuffer.append(sample.yawRate)

        // Maintain buffer size
        if lateralBuffer.count > windowSize {
            lateralBuffer.removeFirst()
            yawBuffer.removeFirst()
        }

        // Analyze at fixed rate
        if now.timeIntervalSince(lastAnalysisTime) >= analysisInterval &&
           lateralBuffer.count >= minimumSamples {
            analyzeLeadWithPhase()
            lastAnalysisTime = now
        }

        // Track duration
        if let lastTime = lastUpdateTime {
            let elapsed = now.timeIntervalSince(lastTime)
            updateLeadDuration(elapsed: elapsed)
        }

        lastUpdateTime = now
    }

    /// Configure with current stride frequency from gait analyzer
    func configure(strideFrequency: Double) {
        self.strideFrequency = strideFrequency
    }

    /// Reset all state
    func reset() {
        clearBuffers()
        currentLead = .unknown
        currentConfidence = 0.0
        totalLeftLeadDuration = 0.0
        totalRightLeadDuration = 0.0
        lastUpdateTime = nil
        leadStartTime = nil
        isInCanterOrGallop = false
        phaseAngle = 0
        leadQuality = 0
        strideFrequency = 0
        lastAnalysisTime = .distantPast
    }

    private func clearBuffers() {
        lateralBuffer = []
        yawBuffer = []
    }

    // MARK: - Physics-Based Lead Detection

    /// Detect lead using Hilbert transform phase analysis
    /// Left lead: lateral phase leads yaw by ~+90°
    /// Right lead: yaw phase leads lateral by ~-90°
    private func analyzeLeadWithPhase() {
        guard lateralBuffer.count >= minimumSamples && yawBuffer.count >= minimumSamples else {
            return
        }

        // Compute instantaneous phase of both signals using Hilbert transform
        let lateralPhase = HilbertTransform.instantaneousPhase(lateralBuffer)
        let yawPhase = HilbertTransform.instantaneousPhase(yawBuffer)

        // Compute phase difference
        let minLength = min(lateralPhase.count, yawPhase.count)
        guard minLength > 0 else { return }

        var phaseDiff: [Double] = []
        phaseDiff.reserveCapacity(minLength)

        for i in 0..<minLength {
            var diff = lateralPhase[i] - yawPhase[i]
            // Wrap to -π to π
            while diff > .pi { diff -= 2 * .pi }
            while diff < -.pi { diff += 2 * .pi }
            phaseDiff.append(diff)
        }

        // Compute mean phase using circular statistics
        let sinSum = phaseDiff.reduce(0) { $0 + sin($1) }
        let cosSum = phaseDiff.reduce(0) { $0 + cos($1) }
        let meanPhase = atan2(sinSum, cosSum)

        // Convert to degrees
        let phaseDegrees = meanPhase * 180.0 / .pi
        phaseAngle = phaseDegrees

        // Compute coherence at stride frequency for confidence
        let targetFreq = strideFrequency > 0 ? strideFrequency : 2.0  // Default canter frequency
        let coherence = coherenceAnalyzer.coherence(
            signal1: lateralBuffer,
            signal2: yawBuffer,
            atFrequency: targetFreq
        )

        // Lead quality combines coherence with phase clarity
        leadQuality = coherence * abs(sin(meanPhase))

        // Determine lead from phase angle
        // Left lead: +45° to +135° (lateral leads yaw)
        // Right lead: -45° to -135° (yaw leads lateral)
        let detectedLead: Lead
        let phaseConfidence: Double

        if phaseDegrees > 45 && phaseDegrees < 135 {
            // Left lead
            detectedLead = .left
            // Confidence peaks at 90°, decreases toward 45° and 135°
            phaseConfidence = coherence * (1.0 - abs(phaseDegrees - 90) / 45.0)
        } else if phaseDegrees < -45 && phaseDegrees > -135 {
            // Right lead
            detectedLead = .right
            phaseConfidence = coherence * (1.0 - abs(phaseDegrees + 90) / 45.0)
        } else {
            // Ambiguous - phase near 0° or ±180°
            detectedLead = .unknown
            phaseConfidence = 0.0
        }

        // Combine with legacy asymmetry detection for robustness
        let legacyResult = analyzeLegacyAsymmetry()

        // Weighted combination: 70% phase, 30% legacy
        var finalConfidence: Double
        var finalLead: Lead

        if phaseConfidence > 0.5 {
            // Trust phase-based detection
            finalConfidence = phaseConfidence * 0.7 + legacyResult.confidence * 0.3
            finalLead = detectedLead
        } else if legacyResult.confidence > confidenceThreshold {
            // Fall back to legacy
            finalConfidence = legacyResult.confidence * 0.7
            finalLead = legacyResult.lead
        } else {
            finalConfidence = max(phaseConfidence, legacyResult.confidence) * 0.5
            finalLead = .unknown
        }

        // Update state
        currentConfidence = finalConfidence
        if finalConfidence >= confidenceThreshold {
            currentLead = finalLead
        } else {
            currentLead = .unknown
        }
    }

    // MARK: - RMS Asymmetry Detection (Frequency-Domain Fallback)

    /// Fallback lead detection using RMS asymmetry (avoids peak detection)
    /// Per gait-logic.md: "Never use ... peak detection ... as these fail when the rider changes seat"
    private func analyzeLegacyAsymmetry() -> (lead: Lead, confidence: Double) {
        guard lateralBuffer.count >= minimumSamples else {
            return (.unknown, 0)
        }

        // Calculate lateral RMS for positive and negative samples
        // This is a frequency-domain-inspired approach without explicit peak detection
        let positiveSamples = lateralBuffer.filter { $0 > 0 }
        let negativeSamples = lateralBuffer.filter { $0 < 0 }

        // Compute RMS for each side
        let positiveRMS: Double
        if positiveSamples.isEmpty {
            positiveRMS = 0
        } else {
            positiveRMS = sqrt(positiveSamples.map { $0 * $0 }.reduce(0, +) / Double(positiveSamples.count))
        }

        let negativeRMS: Double
        if negativeSamples.isEmpty {
            negativeRMS = 0
        } else {
            negativeRMS = sqrt(negativeSamples.map { $0 * $0 }.reduce(0, +) / Double(negativeSamples.count))
        }

        let total = positiveRMS + negativeRMS
        guard total > 0.02 else { return (.unknown, 0) }

        // Compute asymmetry ratio
        let asymmetry = (negativeRMS - positiveRMS) / total  // Negative = left bias

        // Also compute mean bias (DC component)
        let mean = lateralBuffer.reduce(0, +) / Double(lateralBuffer.count)

        // Combine RMS asymmetry with DC bias
        let combinedScore = asymmetry * 0.7 + (mean * -5.0).clamped(to: -1...1) * 0.3

        let absScore = abs(combinedScore)
        let detectedLead: Lead
        let confidence: Double

        if absScore < 0.1 {
            detectedLead = .unknown
            confidence = absScore / 0.1 * 0.4
        } else {
            // Positive asymmetry (negativeRMS > positiveRMS) indicates left lead
            detectedLead = combinedScore > 0 ? .left : .right
            confidence = min(1.0, 0.4 + (absScore - 0.1) / 0.4 * 0.5)
        }

        return (detectedLead, confidence)
    }

    // MARK: - Duration Tracking

    private func updateLeadDuration(elapsed: TimeInterval) {
        guard currentConfidence >= confidenceThreshold else { return }

        switch currentLead {
        case .left:
            totalLeftLeadDuration += elapsed
        case .right:
            totalRightLeadDuration += elapsed
        case .unknown:
            break
        }
    }

    private func finalizeCurrentLead(at time: Date) {
        if let lastTime = lastUpdateTime {
            let elapsed = time.timeIntervalSince(lastTime)
            updateLeadDuration(elapsed: elapsed)
        }
        leadStartTime = nil
    }
}
