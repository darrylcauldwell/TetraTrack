//
//  GaitAnalyzer.swift
//  TrackRide
//
//  Enhanced gait detection using GPS speed + accelerometer motion patterns

import CoreMotion
import Observation
import SwiftData

@Observable
final class GaitAnalyzer: Resettable {
    var currentGait: GaitType = .stationary
    var isAnalyzing: Bool = false

    /// Current detected bounce frequency (Hz) - useful for debugging
    var detectedBounceFrequency: Double = 0

    /// Current vertical acceleration amplitude
    var bounceAmplitude: Double = 0

    /// Callback when gait changes (from, to)
    var onGaitChange: ((GaitType, GaitType) -> Void)?

    private var currentSegment: GaitSegment?
    private var segmentDistance: Double = 0

    // GPS speed tracking
    private var speedSamples: [Double] = []
    private let speedSampleWindow = 5

    // Motion-based gait detection
    private var verticalAccelSamples: [Double] = []
    private var sampleTimestamps: [Date] = []
    private let motionSampleWindow = 100  // ~2 seconds at 50Hz

    // Gait confirmation - require consistent detection before changing
    private var pendingGait: GaitType?
    private var pendingGaitCount: Int = 0
    private let confirmationThreshold = 3  // Require 3 consistent detections

    private var modelContext: ModelContext?
    private var currentRide: Ride?

    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func startAnalyzing(for ride: Ride) {
        guard !isAnalyzing else { return }

        currentRide = ride
        isAnalyzing = true
        currentGait = .stationary
        speedSamples = []
        verticalAccelSamples = []
        sampleTimestamps = []
        segmentDistance = 0
        pendingGait = nil
        pendingGaitCount = 0

        // Start a new segment
        startNewSegment(gait: .stationary)
    }

    func stopAnalyzing() {
        guard isAnalyzing else { return }

        // Close current segment
        finalizeCurrentSegment()

        isAnalyzing = false
        currentRide = nil
        currentSegment = nil
        speedSamples = []
        verticalAccelSamples = []
        sampleTimestamps = []
    }

    func reset() {
        stopAnalyzing()
        currentGait = .stationary
        segmentDistance = 0
        detectedBounceFrequency = 0
        bounceAmplitude = 0
    }

    // MARK: - Process Location (GPS Speed)

    /// Called with each new location update (~1Hz)
    func processLocation(speed: Double, distance: Double) {
        guard isAnalyzing else { return }

        // Add to rolling average
        speedSamples.append(speed)
        if speedSamples.count > speedSampleWindow {
            speedSamples.removeFirst()
        }

        // Accumulate distance for current segment
        segmentDistance += distance

        // Detect gait using combined approach
        detectGait()
    }

    // MARK: - Process Motion (Accelerometer)

    /// Called with each motion update (~50Hz)
    func processMotion(_ sample: MotionSample) {
        guard isAnalyzing else { return }

        // Store vertical acceleration (Z-axis represents up/down bounce)
        verticalAccelSamples.append(sample.verticalAcceleration)
        sampleTimestamps.append(sample.timestamp)

        // Keep window size manageable
        if verticalAccelSamples.count > motionSampleWindow {
            verticalAccelSamples.removeFirst()
            sampleTimestamps.removeFirst()
        }

        // Update bounce amplitude (RMS of vertical acceleration)
        if verticalAccelSamples.count >= 20 {
            let rms = sqrt(verticalAccelSamples.suffix(20).map { $0 * $0 }.reduce(0, +) / 20.0)
            bounceAmplitude = rms
        }
    }

    // MARK: - Combined Gait Detection

    private func detectGait() {
        // Calculate smoothed GPS speed
        let averageSpeed = speedSamples.isEmpty ? 0 : speedSamples.reduce(0, +) / Double(speedSamples.count)

        // Get motion-based gait estimate
        let motionGait = detectGaitFromMotion()

        // Get speed-based gait estimate
        let speedGait = GaitType.fromSpeed(averageSpeed)

        // Combine estimates - motion takes priority if we have enough data and rider is moving
        let detectedGait: GaitType
        if verticalAccelSamples.count >= 50 && averageSpeed > 0.5 {
            // Use motion-based detection with speed as sanity check
            detectedGait = combineGaitEstimates(motion: motionGait, speed: speedGait, averageSpeed: averageSpeed)
        } else {
            // Fall back to speed-only detection
            detectedGait = speedGait
        }

        // Require confirmation before changing gait (reduces flicker)
        if detectedGait != currentGait {
            if detectedGait == pendingGait {
                pendingGaitCount += 1
                if pendingGaitCount >= confirmationThreshold {
                    // Confirmed gait change
                    let previousGait = currentGait
                    finalizeCurrentSegment()
                    currentGait = detectedGait
                    startNewSegment(gait: detectedGait)
                    onGaitChange?(previousGait, detectedGait)
                    pendingGait = nil
                    pendingGaitCount = 0
                }
            } else {
                // New pending gait
                pendingGait = detectedGait
                pendingGaitCount = 1
            }
        } else {
            // Current gait confirmed, reset pending
            pendingGait = nil
            pendingGaitCount = 0
        }
    }

    /// Detect gait from accelerometer bounce pattern
    private func detectGaitFromMotion() -> GaitType {
        guard verticalAccelSamples.count >= 50 else { return .stationary }

        // Calculate bounce frequency using zero-crossing detection
        let frequency = calculateBounceFrequency()
        detectedBounceFrequency = frequency

        // Calculate bounce amplitude (intensity of vertical motion)
        let amplitude = bounceAmplitude

        // Very low amplitude = stationary or walking slowly
        if amplitude < 0.05 {
            return .stationary
        }

        // Classify based on frequency and amplitude
        // Walk: low frequency (1.4-1.8 Hz), low-medium amplitude
        // Trot: higher frequency (2.0-3.0 Hz), high amplitude (pronounced bounce)
        // Canter: medium frequency (1.5-2.2 Hz), medium-high amplitude, distinctive 3-beat
        // Gallop: high frequency (>2.5 Hz), very high amplitude

        switch (frequency, amplitude) {
        case (0..<1.3, _):
            return amplitude < 0.1 ? .stationary : .walk
        case (1.3..<1.9, ..<0.25):
            return .walk
        case (1.3..<1.9, 0.25...):
            // Higher amplitude at walk frequency suggests canter (3-beat feels slower)
            return .canter
        case (1.9..<2.8, 0.15...):
            // Trot has distinctive high-frequency bounce
            return .trot
        case (1.9..<2.8, ..<0.15):
            return .walk
        case (2.8..., 0.3...):
            return .gallop
        case (2.8..., ..<0.3):
            return .canter
        default:
            return .walk
        }
    }

    /// Calculate dominant bounce frequency using zero-crossing detection
    private func calculateBounceFrequency() -> Double {
        guard verticalAccelSamples.count >= 50,
              let firstTime = sampleTimestamps.first,
              let lastTime = sampleTimestamps.last else {
            return 0
        }

        let duration = lastTime.timeIntervalSince(firstTime)
        guard duration > 0.5 else { return 0 }

        // Count zero crossings (transitions from positive to negative or vice versa)
        var crossings = 0
        let samples = Array(verticalAccelSamples.suffix(50))

        for i in 1..<samples.count {
            if (samples[i-1] >= 0 && samples[i] < 0) || (samples[i-1] < 0 && samples[i] >= 0) {
                crossings += 1
            }
        }

        // Frequency = crossings / 2 / duration (each full cycle has 2 crossings)
        let sampleDuration = duration * Double(samples.count) / Double(verticalAccelSamples.count)
        let frequency = Double(crossings) / 2.0 / sampleDuration

        return frequency
    }

    /// Combine motion and speed estimates with sanity checks
    private func combineGaitEstimates(motion: GaitType, speed: GaitType, averageSpeed: Double) -> GaitType {
        // If both agree, use that
        if motion == speed {
            return motion
        }

        // Sanity checks - speed provides bounds
        // Can't be cantering if going slower than 2 m/s
        if motion == .canter && averageSpeed < 2.0 {
            return speed
        }

        // Can't be galloping if going slower than 4 m/s
        if motion == .gallop && averageSpeed < 4.0 {
            return motion == .gallop ? .canter : motion
        }

        // Can't be walking if going faster than 2.5 m/s
        if motion == .walk && averageSpeed > 2.5 {
            return speed
        }

        // Trust motion detection for distinguishing trot vs canter
        // (they can have similar speeds but different motion patterns)
        if (motion == .trot || motion == .canter) && (speed == .trot || speed == .canter) {
            return motion
        }

        // Default: prefer motion-based if amplitude is significant
        return bounceAmplitude > 0.1 ? motion : speed
    }

    private func startNewSegment(gait: GaitType) {
        let segment = GaitSegment(gaitType: gait, startTime: Date())
        segment.ride = currentRide
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
}
