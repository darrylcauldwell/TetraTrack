//
//  MotionManager.swift
//  TetraTrack
//
//  CoreMotion wrapper for accelerometer, gyroscope, and device motion

import Foundation
import CoreMotion
import Observation
import os

// MARK: - Motion Sample

/// A sample of device motion data
struct MotionSample {
    let timestamp: Date

    // Accelerometer data (g-force)
    let accelerationX: Double
    let accelerationY: Double
    let accelerationZ: Double

    // Gyroscope data (rad/s)
    let rotationX: Double
    let rotationY: Double
    let rotationZ: Double

    // Attitude (radians)
    let pitch: Double
    let roll: Double
    let yaw: Double

    // Quaternion for frame transformation (more accurate than Euler angles)
    let quaternionW: Double
    let quaternionX: Double
    let quaternionY: Double
    let quaternionZ: Double

    /// Acceleration magnitude (total g-force)
    var accelerationMagnitude: Double {
        sqrt(accelerationX * accelerationX +
             accelerationY * accelerationY +
             accelerationZ * accelerationZ)
    }

    /// Rotation magnitude (total rotation rate)
    var rotationMagnitude: Double {
        sqrt(rotationX * rotationX +
             rotationY * rotationY +
             rotationZ * rotationZ)
    }

    /// Lateral acceleration (X-axis, left/right)
    var lateralAcceleration: Double {
        accelerationX
    }

    /// Vertical acceleration (Z-axis, up/down)
    var verticalAcceleration: Double {
        accelerationZ
    }

    /// Forward acceleration (Y-axis, forward/back)
    var forwardAcceleration: Double {
        accelerationY
    }

    /// Yaw rate (rotation around vertical axis)
    var yawRate: Double {
        rotationZ
    }
}

// MARK: - Motion Manager

@Observable
final class MotionManager {
    var isActive: Bool = false
    var isAvailable: Bool = false
    var currentSample: MotionSample?

    // Callback for motion updates
    var onMotionUpdate: ((MotionSample) -> Void)?

    // Callback when motion delivery resumes after a gap
    var onMotionResumed: (() -> Void)?

    // Delivery gap monitoring
    private(set) var isInDeliveryGap: Bool = false
    private var lastDeliveryTime: Date?
    private var gapMonitorSource: DispatchSourceTimer?
    private let gapMonitorQueue = DispatchQueue(label: "dev.dreamfold.tetratrack.motionGapMonitor", qos: .utility)
    private let maxDeliveryGap: TimeInterval = 2.0

    // Sample rate: 100Hz for FFT analysis (requires 256 samples for 2.56s window)
    private let sampleRate: TimeInterval = 1.0 / 100.0

    private let motionManager = CMMotionManager()
    private let operationQueue: OperationQueue

    // Signal filters for noise reduction
    // Alpha 0.6 provides mild smoothing without excessive lag
    // Higher alpha = less smoothing, more responsive (better for gait detection)
    // Lower alpha = more smoothing, more lag (can blur gait transitions)
    private var accelerationFilter = Vector3DFilter(alpha: 0.6)
    private var rotationFilter = Vector3DFilter(alpha: 0.6)

    /// Boot time reference for accurate timestamp conversion
    /// CoreMotion timestamps are seconds since device boot - we need this reference
    /// to convert to Date accurately. Calculated once on init to avoid drift.
    private let bootTimeReference: Date

    init() {
        // Calculate boot time ONCE at init to avoid drift during processing
        // This is more accurate than calculating per-sample
        let uptime = ProcessInfo.processInfo.systemUptime
        bootTimeReference = Date(timeIntervalSinceNow: -uptime)

        operationQueue = OperationQueue()
        operationQueue.name = "dev.dreamfold.tetratrack.motion"
        operationQueue.maxConcurrentOperationCount = 1

        isAvailable = motionManager.isDeviceMotionAvailable
    }

    // MARK: - Start/Stop Updates

    func startUpdates() {
        guard isAvailable, !isActive else { return }

        motionManager.deviceMotionUpdateInterval = sampleRate

        // Use xArbitraryZVertical reference frame for consistent orientation
        motionManager.startDeviceMotionUpdates(
            using: .xArbitraryZVertical,
            to: operationQueue
        ) { [weak self] motion, error in
            guard let self = self, let motion = motion, error == nil else {
                return
            }

            // Apply EMA filtering to reduce noise
            let filteredAccel = self.accelerationFilter.filter(
                x: motion.userAcceleration.x,
                y: motion.userAcceleration.y,
                z: motion.userAcceleration.z
            )
            let filteredRotation = self.rotationFilter.filter(
                x: motion.rotationRate.x,
                y: motion.rotationRate.y,
                z: motion.rotationRate.z
            )

            let quaternion = motion.attitude.quaternion
            // Use CoreMotion's timestamp for better precision
            // Convert from system uptime (seconds since boot) to Date
            // Uses pre-calculated bootTimeReference to avoid per-sample drift
            let motionDate = self.bootTimeReference.addingTimeInterval(motion.timestamp)
            let sample = MotionSample(
                timestamp: motionDate,
                accelerationX: filteredAccel.x,
                accelerationY: filteredAccel.y,
                accelerationZ: filteredAccel.z,
                rotationX: filteredRotation.x,
                rotationY: filteredRotation.y,
                rotationZ: filteredRotation.z,
                pitch: motion.attitude.pitch,
                roll: motion.attitude.roll,
                yaw: motion.attitude.yaw,
                quaternionW: quaternion.w,
                quaternionX: quaternion.x,
                quaternionY: quaternion.y,
                quaternionZ: quaternion.z
            )

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.lastDeliveryTime = Date()
                if self.isInDeliveryGap {
                    self.isInDeliveryGap = false
                    self.onMotionResumed?()
                }
                self.currentSample = sample
                self.onMotionUpdate?(sample)
            }
        }

        isActive = true
        startGapMonitoring()
    }

    func stopUpdates() {
        guard isActive else { return }

        stopGapMonitoring()
        motionManager.stopDeviceMotionUpdates()
        isActive = false
        currentSample = nil
        lastDeliveryTime = nil
        isInDeliveryGap = false

        // Reset filters for next session
        accelerationFilter.reset()
        rotationFilter.reset()
    }

    // MARK: - Delivery Gap Monitoring

    private func startGapMonitoring() {
        gapMonitorSource?.cancel()

        let source = DispatchSource.makeTimerSource(queue: gapMonitorQueue)
        source.schedule(deadline: .now() + maxDeliveryGap, repeating: maxDeliveryGap, leeway: .milliseconds(200))
        source.setEventHandler { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                guard let lastTime = self.lastDeliveryTime else { return }
                let gap = Date().timeIntervalSince(lastTime)
                if gap > self.maxDeliveryGap && !self.isInDeliveryGap {
                    self.isInDeliveryGap = true
                    Log.tracking.warning("CoreMotion delivery gap detected: \(String(format: "%.1f", gap))s since last sample")
                    self.restartMotionUpdates()
                }
            }
        }
        source.resume()
        gapMonitorSource = source
    }

    private func stopGapMonitoring() {
        gapMonitorSource?.cancel()
        gapMonitorSource = nil
    }

    private func restartMotionUpdates() {
        Log.tracking.info("Restarting CoreMotion device motion updates")
        motionManager.stopDeviceMotionUpdates()

        // Brief delay before restart to allow system to reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self, self.isActive else { return }
            self.motionManager.startDeviceMotionUpdates(
                using: .xArbitraryZVertical,
                to: self.operationQueue
            ) { [weak self] motion, error in
                guard let self = self, let motion = motion, error == nil else { return }

                let filteredAccel = self.accelerationFilter.filter(
                    x: motion.userAcceleration.x,
                    y: motion.userAcceleration.y,
                    z: motion.userAcceleration.z
                )
                let filteredRotation = self.rotationFilter.filter(
                    x: motion.rotationRate.x,
                    y: motion.rotationRate.y,
                    z: motion.rotationRate.z
                )

                let quaternion = motion.attitude.quaternion
                let motionDate = self.bootTimeReference.addingTimeInterval(motion.timestamp)
                let sample = MotionSample(
                    timestamp: motionDate,
                    accelerationX: filteredAccel.x,
                    accelerationY: filteredAccel.y,
                    accelerationZ: filteredAccel.z,
                    rotationX: filteredRotation.x,
                    rotationY: filteredRotation.y,
                    rotationZ: filteredRotation.z,
                    pitch: motion.attitude.pitch,
                    roll: motion.attitude.roll,
                    yaw: motion.attitude.yaw,
                    quaternionW: quaternion.w,
                    quaternionX: quaternion.x,
                    quaternionY: quaternion.y,
                    quaternionZ: quaternion.z
                )

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.lastDeliveryTime = Date()
                    if self.isInDeliveryGap {
                        self.isInDeliveryGap = false
                        self.onMotionResumed?()
                    }
                    self.currentSample = sample
                    self.onMotionUpdate?(sample)
                }
            }
        }
    }

    // MARK: - Mount Position Configuration

    /// Configure filter parameters for phone placement.
    /// Accepts any PhonePlacementConfigurable (riding's PhoneMountPosition or running's RunningPhonePlacement).
    func configureForPlacement(_ placement: any PhonePlacementConfigurable) {
        accelerationFilter = Vector3DFilter(alpha: placement.filterAlpha)
        rotationFilter = Vector3DFilter(alpha: placement.filterAlpha)
    }

    // MARK: - Utility Methods

    /// Check if device motion is available
    static var deviceMotionAvailable: Bool {
        CMMotionManager().isDeviceMotionAvailable
    }

    /// Check if accelerometer is available
    static var accelerometerAvailable: Bool {
        CMMotionManager().isAccelerometerAvailable
    }

    /// Check if gyroscope is available
    static var gyroscopeAvailable: Bool {
        CMMotionManager().isGyroAvailable
    }
}
