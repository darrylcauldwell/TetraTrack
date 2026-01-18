//
//  MotionManager.swift
//  TrackRide
//
//  CoreMotion wrapper for accelerometer, gyroscope, and device motion

import Foundation
import CoreMotion
import Observation

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

    // Sample rate: 100Hz for FFT analysis (requires 256 samples for 2.56s window)
    private let sampleRate: TimeInterval = 1.0 / 100.0

    private let motionManager = CMMotionManager()
    private let operationQueue: OperationQueue

    // Signal filters for noise reduction
    private var accelerationFilter = Vector3DFilter(alpha: 0.2)
    private var rotationFilter = Vector3DFilter(alpha: 0.2)

    init() {
        operationQueue = OperationQueue()
        operationQueue.name = "com.trackride.motion"
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
            let sample = MotionSample(
                timestamp: Date(),
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

            DispatchQueue.main.async {
                self.currentSample = sample
                self.onMotionUpdate?(sample)
            }
        }

        isActive = true
    }

    func stopUpdates() {
        guard isActive else { return }

        motionManager.stopDeviceMotionUpdates()
        isActive = false
        currentSample = nil

        // Reset filters for next session
        accelerationFilter.reset()
        rotationFilter.reset()
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
