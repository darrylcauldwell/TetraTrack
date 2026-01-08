//
//  LeadAnalyzer.swift
//  TrackRide
//
//  Detects lead leg (left/right) during canter and gallop using
//  lateral acceleration asymmetry patterns from device motion.

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

    // MARK: - Configuration

    /// Minimum confidence threshold to report a lead (70%)
    private let confidenceThreshold: Double = 0.7

    /// Size of rolling window in samples (2 seconds at 50Hz)
    private let windowSize: Int = 100

    /// Minimum samples needed before analyzing
    private let minimumSamples: Int = 50

    // MARK: - Internal State

    /// Rolling buffer of lateral acceleration samples (using RollingBuffer)
    private var lateralAccelBuffer: RollingBuffer<Double>

    /// Timestamps for duration tracking
    private var lastUpdateTime: Date?
    private var leadStartTime: Date?

    /// Whether currently in a lead-detectable gait
    private var isInCanterOrGallop: Bool = false

    init() {
        lateralAccelBuffer = RollingBuffer(capacity: windowSize)
    }

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
            // Clear buffer when not in canter/gallop
            if wasInCanterOrGallop {
                finalizeCurrentLead(at: now)
            }
            lateralAccelBuffer.removeAll()
            currentLead = .unknown
            currentConfidence = 0.0
            lastUpdateTime = now
            return
        }

        // Started canter/gallop
        if !wasInCanterOrGallop {
            leadStartTime = now
        }

        // Add lateral acceleration to buffer (X-axis = left/right)
        lateralAccelBuffer.append(sample.lateralAcceleration)

        // Analyze if we have enough samples
        if lateralAccelBuffer.count >= minimumSamples {
            analyzeLead()
        }

        // Track duration
        if let lastTime = lastUpdateTime {
            let elapsed = now.timeIntervalSince(lastTime)
            updateLeadDuration(elapsed: elapsed)
        }

        lastUpdateTime = now
    }

    /// Reset all state
    func reset() {
        lateralAccelBuffer.removeAll()
        currentLead = .unknown
        currentConfidence = 0.0
        totalLeftLeadDuration = 0.0
        totalRightLeadDuration = 0.0
        lastUpdateTime = nil
        leadStartTime = nil
        isInCanterOrGallop = false
    }

    // MARK: - Lead Detection Algorithm

    private func analyzeLead() {
        // Lead detection uses lateral acceleration asymmetry:
        // - During canter, the horse's body rolls slightly toward the leading leg
        // - This creates a bias in lateral (X-axis) acceleration
        // - Left lead: more negative lateral acceleration peaks (tilting left)
        // - Right lead: more positive lateral acceleration peaks (tilting right)

        let samples = lateralAccelBuffer.items

        // Calculate statistics using RollingBuffer mean
        let mean = lateralAccelBuffer.mean

        // Detect peaks (local maxima and minima)
        let (positivePeaks, negativePeaks) = detectPeaks(samples)

        // Calculate asymmetry metrics
        let positiveAvg = positivePeaks.isEmpty ? 0 : positivePeaks.reduce(0, +) / Double(positivePeaks.count)
        let negativeAvg = negativePeaks.isEmpty ? 0 : abs(negativePeaks.reduce(0, +)) / Double(negativePeaks.count)

        // Peak count asymmetry
        let totalPeaks = positivePeaks.count + negativePeaks.count
        guard totalPeaks > 0 else {
            currentConfidence = 0.0
            return
        }

        // Calculate bias toward left or right
        // Negative mean indicates left-leaning (left lead)
        // Positive mean indicates right-leaning (right lead)
        let meanBias = mean

        // Peak magnitude asymmetry
        let peakBias = positiveAvg - negativeAvg

        // Combined score (-1 = strong left, +1 = strong right)
        let combinedScore = (meanBias * 0.4) + (peakBias * 0.6)

        // Determine lead and confidence
        let absScore = abs(combinedScore)
        let detectedLead: Lead

        if absScore < 0.05 {
            // Too ambiguous
            detectedLead = .unknown
            currentConfidence = absScore / 0.05 * 0.5  // 0-50%
        } else {
            detectedLead = combinedScore < 0 ? .left : .right
            // Scale confidence: 0.05-0.3 maps to 50%-100%
            currentConfidence = min(1.0, 0.5 + (absScore - 0.05) / 0.25 * 0.5)
        }

        // Only update if confidence meets threshold
        if currentConfidence >= confidenceThreshold {
            currentLead = detectedLead
        } else {
            currentLead = .unknown
        }
    }

    /// Detect positive and negative peaks in the acceleration data
    private func detectPeaks(_ samples: [Double]) -> (positive: [Double], negative: [Double]) {
        var positivePeaks: [Double] = []
        var negativePeaks: [Double] = []

        guard samples.count >= 3 else { return ([], []) }

        // Simple peak detection: value higher/lower than neighbors
        for i in 1..<(samples.count - 1) {
            let prev = samples[i - 1]
            let curr = samples[i]
            let next = samples[i + 1]

            // Positive peak (local maximum above threshold)
            if curr > prev && curr > next && curr > 0.1 {
                positivePeaks.append(curr)
            }
            // Negative peak (local minimum below threshold)
            else if curr < prev && curr < next && curr < -0.1 {
                negativePeaks.append(curr)
            }
        }

        return (positivePeaks, negativePeaks)
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
        // When exiting canter/gallop, finalize any remaining duration
        if let lastTime = lastUpdateTime {
            let elapsed = time.timeIntervalSince(lastTime)
            updateLeadDuration(elapsed: elapsed)
        }
        leadStartTime = nil
    }
}
