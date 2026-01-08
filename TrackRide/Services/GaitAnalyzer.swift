//
//  GaitAnalyzer.swift
//  TrackRide
//

import CoreMotion
import Observation
import SwiftData

@Observable
final class GaitAnalyzer: Resettable {
    var currentGait: GaitType = .stationary
    var isAnalyzing: Bool = false

    /// Callback when gait changes (from, to)
    var onGaitChange: ((GaitType, GaitType) -> Void)?

    private let motionManager = CMMotionManager()
    private var currentSegment: GaitSegment?
    private var segmentDistance: Double = 0
    private var speedSamples: [Double] = []
    private let sampleWindow = 5  // Average over 5 samples for smoother detection

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
        segmentDistance = 0

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
    }

    func reset() {
        stopAnalyzing()
        currentGait = .stationary
        segmentDistance = 0
    }

    // Called with each new location update
    func processLocation(speed: Double, distance: Double) {
        guard isAnalyzing else { return }

        // Add to rolling average
        speedSamples.append(speed)
        if speedSamples.count > sampleWindow {
            speedSamples.removeFirst()
        }

        // Calculate smoothed speed
        let averageSpeed = speedSamples.reduce(0, +) / Double(speedSamples.count)

        // Determine gait from speed
        let detectedGait = GaitType.fromSpeed(averageSpeed)

        // Accumulate distance for current segment
        segmentDistance += distance

        // Check if gait changed
        if detectedGait != currentGait {
            let previousGait = currentGait

            // Finalize current segment
            finalizeCurrentSegment()

            // Start new segment
            currentGait = detectedGait
            startNewSegment(gait: detectedGait)

            // Notify callback
            onGaitChange?(previousGait, detectedGait)
        }
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
