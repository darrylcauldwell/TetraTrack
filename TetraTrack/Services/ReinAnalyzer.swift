//
//  ReinAnalyzer.swift
//  TetraTrack
//
//  Detects rein direction (left/right/straight) using sensor fusion
//  combining GPS bearing changes, accelerometer, and gyroscope data.

import Foundation
import CoreLocation

/// Analyzes combined sensor data to detect which rein the horse is on
final class ReinAnalyzer: Resettable {
    // MARK: - Public Properties

    /// Currently detected rein direction
    private(set) var currentRein: ReinDirection = .straight

    /// Total duration on left rein
    private(set) var totalLeftReinDuration: TimeInterval = 0.0

    /// Total duration on right rein
    private(set) var totalRightReinDuration: TimeInterval = 0.0

    /// Callback when rein changes
    var onReinChange: ((ReinDirection, ReinDirection) -> Void)?

    // MARK: - Rein Segments

    /// Current rein segment being tracked
    private(set) var currentSegment: ReinSegmentData?

    /// Completed rein segments
    private(set) var completedSegments: [ReinSegmentData] = []

    struct ReinSegmentData {
        var direction: ReinDirection
        var startTime: Date
        var endTime: Date?
        var distance: Double = 0.0
    }

    // MARK: - Configuration

    /// Sensor weights for fusion
    private let gpsWeight: Double = 0.4
    private let accelWeight: Double = 0.3
    private let gyroWeight: Double = 0.3

    /// Threshold for detecting circular motion (degrees)
    private let circularThreshold: Double = 60.0

    /// Detection threshold for rein assignment
    private let reinThreshold: Double = 0.3

    /// History sizes
    private let bearingHistorySize: Int = 20
    private let motionHistorySize: Int = 50  // 1 second at 50Hz

    /// Minimum duration before rein change (debounce)
    private let minimumReinDuration: TimeInterval = 2.0

    // MARK: - Internal State

    /// GPS bearing history (using RollingBuffer)
    private var bearingBuffer: RollingBuffer<Double>
    private var lastBearing: Double?

    /// Accelerometer lateral acceleration history (using RollingBuffer)
    private var lateralAccelBuffer: RollingBuffer<Double>

    /// Gyroscope yaw rate history (using RollingBuffer)
    private var yawRateBuffer: RollingBuffer<Double>

    /// Timestamps for duration tracking
    private var lastUpdateTime: Date?
    private var lastReinChangeTime: Date?

    /// Distance tracking
    private var lastLocation: CLLocationCoordinate2D?

    init() {
        bearingBuffer = RollingBuffer(capacity: bearingHistorySize)
        lateralAccelBuffer = RollingBuffer(capacity: motionHistorySize)
        yawRateBuffer = RollingBuffer(capacity: motionHistorySize)
    }

    // MARK: - Public Methods

    /// Process a new GPS location for bearing-based rein detection
    /// - Parameters:
    ///   - from: Previous coordinate
    ///   - to: Current coordinate
    func processLocation(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) {
        let bearing = LocationMath.bearing(from: from, to: to)

        // Track bearing changes using RollingBuffer
        if let lastBearing = lastBearing {
            let bearingChange = LocationMath.bearingChange(from: lastBearing, to: bearing)
            bearingBuffer.append(bearingChange)
        }

        lastBearing = bearing

        // Track distance for current segment
        if currentSegment != nil {
            let distance = LocationMath.distance(from: from, to: to)
            currentSegment?.distance += distance
        }

        lastLocation = to
    }

    /// Process motion sample for accelerometer and gyroscope-based detection
    /// - Parameter sample: Motion sample from MotionManager
    func processMotion(_ sample: MotionSample) {
        let now = sample.timestamp

        // Add lateral acceleration (X-axis for left/right)
        lateralAccelBuffer.append(sample.lateralAcceleration)

        // Add yaw rate (rotation around vertical axis)
        // Positive yaw rate = turning right, negative = turning left
        yawRateBuffer.append(sample.yawRate)

        // Analyze combined sensor data
        analyzeRein()

        // Track duration
        if let lastTime = lastUpdateTime {
            let elapsed = now.timeIntervalSince(lastTime)
            updateReinDuration(elapsed: elapsed)
        }

        lastUpdateTime = now
    }

    /// Reset all state
    func reset() {
        bearingBuffer.removeAll()
        lateralAccelBuffer.removeAll()
        yawRateBuffer.removeAll()
        lastBearing = nil
        lastUpdateTime = nil
        lastReinChangeTime = nil
        lastLocation = nil
        currentRein = .straight
        totalLeftReinDuration = 0.0
        totalRightReinDuration = 0.0
        currentSegment = nil
        completedSegments.removeAll()
    }

    // MARK: - Sensor Fusion Algorithm

    private func analyzeRein() {
        // Get votes from each sensor
        let gpsVote = analyzeGPSPattern()
        let accelVote = analyzeLateralAccel()
        let gyroVote = analyzeYawRate()

        // Weighted sensor fusion
        let combinedScore = gpsVote * gpsWeight + accelVote * accelWeight + gyroVote * gyroWeight

        // Determine rein direction
        let newRein: ReinDirection
        if combinedScore < -reinThreshold {
            newRein = .left
        } else if combinedScore > reinThreshold {
            newRein = .right
        } else {
            newRein = .straight
        }

        // Update rein with debounce
        updateRein(newRein)
    }

    /// Analyze GPS bearing pattern
    /// Returns: -1 (left circle), 0 (straight), +1 (right circle)
    private func analyzeGPSPattern() -> Double {
        guard bearingBuffer.count >= 5 else { return 0.0 }

        // Sum of bearing changes using RollingBuffer
        let totalBearingChange = bearingBuffer.sum

        // If cumulative change exceeds threshold, we're circling
        if abs(totalBearingChange) > circularThreshold {
            // Normalize to -1 to +1 range
            // Max expected change is about 180 degrees for a full circle segment
            return min(1.0, max(-1.0, totalBearingChange / 180.0))
        }

        return 0.0
    }

    /// Analyze lateral acceleration (centripetal force)
    /// Returns: -1 (left turn), 0 (straight), +1 (right turn)
    private func analyzeLateralAccel() -> Double {
        guard lateralAccelBuffer.count >= 20 else { return 0.0 }

        // Average lateral acceleration using RollingBuffer
        let avgLateralAccel = lateralAccelBuffer.mean

        // During circular motion, centripetal acceleration points toward center
        // With phone in rider's pocket/arm: left turn creates rightward acceleration (positive)
        // Right turn creates leftward acceleration (negative)
        // So we negate to get: positive accel -> left rein (-1), negative accel -> right rein (+1)

        // Threshold for significant lateral acceleration (g-force)
        let threshold: Double = 0.05

        if abs(avgLateralAccel) > threshold {
            // Scale to -1 to +1 range, negate because centripetal points outward
            // 0.3 g is considered a strong turn
            return max(-1.0, min(1.0, -avgLateralAccel / 0.3))
        }

        return 0.0
    }

    /// Analyze yaw rate (rotation around vertical)
    /// Returns: -1 (left turn), 0 (straight), +1 (right turn)
    private func analyzeYawRate() -> Double {
        guard yawRateBuffer.count >= 20 else { return 0.0 }

        // Average yaw rate using RollingBuffer
        let avgYawRate = yawRateBuffer.mean

        // Yaw rate: positive = turning right, negative = turning left
        // Threshold for significant rotation (rad/s)
        let threshold: Double = 0.1

        if abs(avgYawRate) > threshold {
            // Scale to -1 to +1 (0.5 rad/s is strong turn)
            return min(1.0, max(-1.0, avgYawRate / 0.5))
        }

        return 0.0
    }

    // MARK: - Rein Update & Duration Tracking

    private func updateRein(_ newRein: ReinDirection) {
        let now = Date()

        // Debounce: require minimum duration before changing
        if let lastChange = lastReinChangeTime,
           now.timeIntervalSince(lastChange) < minimumReinDuration {
            return
        }

        // Only update if different
        guard newRein != currentRein else { return }

        let oldRein = currentRein

        // Finalize current segment
        if var segment = currentSegment {
            segment.endTime = now
            completedSegments.append(segment)
        }

        // Start new segment
        currentSegment = ReinSegmentData(
            direction: newRein,
            startTime: now
        )

        currentRein = newRein
        lastReinChangeTime = now

        // Notify callback
        onReinChange?(oldRein, newRein)
    }

    private func updateReinDuration(elapsed: TimeInterval) {
        switch currentRein {
        case .left:
            totalLeftReinDuration += elapsed
        case .right:
            totalRightReinDuration += elapsed
        case .straight:
            break
        }
    }

    // MARK: - Segment Export

    /// Get completed segments for persistence
    func getSegmentData() -> [(direction: ReinDirection, startTime: Date, endTime: Date?, distance: Double)] {
        var segments = completedSegments.map {
            ($0.direction, $0.startTime, $0.endTime, $0.distance)
        }

        // Include current segment if active
        if let current = currentSegment {
            segments.append((current.direction, current.startTime, current.endTime, current.distance))
        }

        return segments
    }
}
