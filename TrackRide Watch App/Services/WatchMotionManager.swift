//
//  WatchMotionManager.swift
//  TrackRide Watch App
//
//  Captures accelerometer and gyroscope data for discipline-specific analysis
//

import Foundation
import CoreMotion
import Observation
import os

/// Motion data sample from Watch sensors
struct WatchMotionSample: Codable {
    let timestamp: TimeInterval
    let accelerationX: Double
    let accelerationY: Double
    let accelerationZ: Double
    let rotationX: Double
    let rotationY: Double
    let rotationZ: Double
    let pitch: Double
    let roll: Double
    let yaw: Double

    var accelerationMagnitude: Double {
        sqrt(accelerationX * accelerationX + accelerationY * accelerationY + accelerationZ * accelerationZ)
    }

    var rotationMagnitude: Double {
        sqrt(rotationX * rotationX + rotationY * rotationY + rotationZ * rotationZ)
    }
}

/// Type of motion tracking for different disciplines
enum WatchMotionMode: String, Codable {
    case shooting    // Stance stability for dry fire drills
    case swimming    // Stroke detection and counting
    case running     // Vertical oscillation and ground contact
    case idle
}

@Observable
final class WatchMotionManager {
    // MARK: - State

    private(set) var isTracking: Bool = false
    private(set) var currentMode: WatchMotionMode = .idle

    // Shooting metrics
    private(set) var stanceStability: Double = 0.0  // 0-100%
    private(set) var movementMagnitude: Double = 0.0

    // Swimming metrics
    private(set) var strokeCount: Int = 0
    private(set) var strokeRate: Double = 0.0  // strokes per minute

    // Running metrics
    private(set) var verticalOscillation: Double = 0.0  // cm
    private(set) var groundContactTime: Double = 0.0  // ms
    private(set) var cadence: Int = 0  // steps per minute

    // MARK: - Private

    private let motionManager = CMMotionManager()
    private var sampleBuffer: [WatchMotionSample] = []
    private var lastStrokeTime: Date?
    private var strokeTimes: [TimeInterval] = []
    private var runningPeaks: [TimeInterval] = []
    private var lastPeakTime: TimeInterval = 0
    private var peakDetectionThreshold: Double = 1.2  // G-force threshold

    // Callbacks
    var onMotionUpdate: ((WatchMotionSample) -> Void)?
    var onStrokeDetected: (() -> Void)?
    var onStepDetected: (() -> Void)?

    // MARK: - Singleton

    static let shared = WatchMotionManager()

    private init() {}

    // MARK: - Tracking Control

    func startTracking(mode: WatchMotionMode) {
        guard !isTracking else { return }
        guard motionManager.isDeviceMotionAvailable else {
            Log.location.warning("Device motion not available")
            return
        }

        currentMode = mode
        resetMetrics()

        // Configure update interval based on mode
        let interval: TimeInterval = switch mode {
        case .shooting: 1.0 / 50.0   // 50Hz for stability analysis
        case .swimming: 1.0 / 25.0   // 25Hz for stroke detection
        case .running: 1.0 / 50.0    // 50Hz for ground contact
        case .idle: 1.0 / 10.0
        }

        motionManager.deviceMotionUpdateInterval = interval

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else {
                if let error = error {
                    Log.location.error("Motion update error: \(error.localizedDescription)")
                }
                return
            }

            self.processMotion(motion)
        }

        isTracking = true
        Log.location.info("Started tracking - mode: \(mode.rawValue)")
    }

    func stopTracking() {
        guard isTracking else { return }

        motionManager.stopDeviceMotionUpdates()
        isTracking = false
        currentMode = .idle

        Log.location.info("Stopped tracking")
    }

    // MARK: - Private Methods

    private func resetMetrics() {
        sampleBuffer = []
        stanceStability = 100.0
        movementMagnitude = 0.0
        strokeCount = 0
        strokeRate = 0.0
        strokeTimes = []
        verticalOscillation = 0.0
        groundContactTime = 0.0
        cadence = 0
        runningPeaks = []
        lastPeakTime = 0
        lastStrokeTime = nil
    }

    private func processMotion(_ motion: CMDeviceMotion) {
        let sample = WatchMotionSample(
            timestamp: motion.timestamp,
            accelerationX: motion.userAcceleration.x,
            accelerationY: motion.userAcceleration.y,
            accelerationZ: motion.userAcceleration.z,
            rotationX: motion.rotationRate.x,
            rotationY: motion.rotationRate.y,
            rotationZ: motion.rotationRate.z,
            pitch: motion.attitude.pitch,
            roll: motion.attitude.roll,
            yaw: motion.attitude.yaw
        )

        sampleBuffer.append(sample)

        // Keep buffer size manageable (last 5 seconds at 50Hz = 250 samples)
        if sampleBuffer.count > 250 {
            sampleBuffer.removeFirst(sampleBuffer.count - 250)
        }

        // Process based on mode
        switch currentMode {
        case .shooting:
            processShootingMotion(sample)
        case .swimming:
            processSwimmingMotion(sample)
        case .running:
            processRunningMotion(sample)
        case .idle:
            break
        }

        onMotionUpdate?(sample)
    }

    // MARK: - Shooting Analysis

    private func processShootingMotion(_ sample: WatchMotionSample) {
        // Calculate stance stability from recent samples
        // Lower movement = higher stability
        let recentSamples = Array(sampleBuffer.suffix(25))  // Last 0.5 seconds
        guard recentSamples.count >= 10 else { return }

        // Calculate average movement magnitude
        let avgMagnitude = recentSamples.map { $0.accelerationMagnitude }.reduce(0, +) / Double(recentSamples.count)
        movementMagnitude = avgMagnitude

        // Calculate rotation variance
        let rotationVar = calculateVariance(recentSamples.map { $0.rotationMagnitude })

        // Stability score: lower movement and rotation = higher stability
        // Scale so typical steady hold is 70-90%, perfect stillness is 100%
        let movementPenalty = min(avgMagnitude * 100, 50)  // Max 50% penalty
        let rotationPenalty = min(rotationVar * 20, 30)     // Max 30% penalty

        stanceStability = max(0, min(100, 100 - movementPenalty - rotationPenalty))
    }

    // MARK: - Swimming Analysis

    private func processSwimmingMotion(_ sample: WatchMotionSample) {
        // Detect strokes using lateral acceleration peaks
        // Swimming strokes create distinctive acceleration patterns

        let lateralAccel = abs(sample.accelerationX)  // Lateral (arm swing) acceleration
        let threshold: Double = 0.8  // G threshold for stroke detection

        // Simple peak detection with debouncing
        let now = Date()
        let minStrokeInterval: TimeInterval = 0.5  // Minimum 0.5s between strokes (max 120 strokes/min)

        if lateralAccel > threshold {
            if let lastStroke = lastStrokeTime {
                let interval = now.timeIntervalSince(lastStroke)
                if interval >= minStrokeInterval {
                    strokeCount += 1
                    strokeTimes.append(interval)
                    lastStrokeTime = now

                    // Keep last 10 stroke times for rate calculation
                    if strokeTimes.count > 10 {
                        strokeTimes.removeFirst()
                    }

                    // Calculate stroke rate
                    if strokeTimes.count >= 2 {
                        let avgInterval = strokeTimes.reduce(0, +) / Double(strokeTimes.count)
                        strokeRate = 60.0 / avgInterval  // Strokes per minute
                    }

                    onStrokeDetected?()
                    HapticManager.shared.playClickHaptic()
                }
            } else {
                // First stroke
                strokeCount = 1
                lastStrokeTime = now
                onStrokeDetected?()
            }
        }
    }

    // MARK: - Running Analysis

    private func processRunningMotion(_ sample: WatchMotionSample) {
        // Analyze vertical oscillation and ground contact time
        // Running creates vertical acceleration peaks at foot strike and toe-off

        let verticalAccel = sample.accelerationY  // Vertical acceleration (Y on wrist)
        let timestamp = sample.timestamp

        // Detect foot strike peaks (positive vertical acceleration spike)
        let impactThreshold: Double = 1.5  // G threshold for foot strike
        let minStepInterval: TimeInterval = 0.25  // Max cadence ~240 spm

        if verticalAccel > impactThreshold && (timestamp - lastPeakTime) > minStepInterval {
            runningPeaks.append(timestamp)
            lastPeakTime = timestamp

            // Keep last 20 peaks
            if runningPeaks.count > 20 {
                runningPeaks.removeFirst()
            }

            // Calculate cadence from peak intervals
            if runningPeaks.count >= 4 {
                var intervals: [TimeInterval] = []
                for i in 1..<runningPeaks.count {
                    intervals.append(runningPeaks[i] - runningPeaks[i-1])
                }
                let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
                cadence = Int(60.0 / avgInterval)  // Steps per minute
            }

            onStepDetected?()
        }

        // Calculate vertical oscillation from recent samples
        let recentSamples = Array(sampleBuffer.suffix(50))  // Last 1 second
        guard recentSamples.count >= 20 else { return }

        let verticalAccels = recentSamples.map { $0.accelerationY }
        let maxVert = verticalAccels.max() ?? 0
        let minVert = verticalAccels.min() ?? 0

        // Convert acceleration range to estimated oscillation in cm
        // This is an approximation based on typical running biomechanics
        let oscillationRange = maxVert - minVert
        verticalOscillation = oscillationRange * 4.0  // Scale factor to cm

        // Estimate ground contact time from acceleration pattern
        // Ground contact shows sustained positive vertical acceleration
        let contactSamples = recentSamples.filter { $0.accelerationY > 0.5 }
        let contactRatio = Double(contactSamples.count) / Double(recentSamples.count)

        // Typical ground contact is 200-300ms, scale from ratio
        // At 50Hz, 250ms contact = 12.5 samples out of 50 = 25%
        groundContactTime = contactRatio * 1000 * 0.5  // Convert to ms estimate
    }

    // MARK: - Helpers

    private func calculateVariance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { ($0 - mean) * ($0 - mean) }
        return squaredDiffs.reduce(0, +) / Double(values.count - 1)
    }

    // MARK: - Public API

    /// Get current metrics for sending to iPhone
    func currentMetrics() -> WatchMotionMetrics {
        WatchMotionMetrics(
            mode: currentMode,
            stanceStability: stanceStability,
            movementMagnitude: movementMagnitude,
            strokeCount: strokeCount,
            strokeRate: strokeRate,
            verticalOscillation: verticalOscillation,
            groundContactTime: groundContactTime,
            cadence: cadence,
            timestamp: Date()
        )
    }
}

/// Aggregated metrics to send to iPhone
struct WatchMotionMetrics: Codable {
    let mode: WatchMotionMode
    let stanceStability: Double
    let movementMagnitude: Double
    let strokeCount: Int
    let strokeRate: Double
    let verticalOscillation: Double
    let groundContactTime: Double
    let cadence: Int
    let timestamp: Date
}
