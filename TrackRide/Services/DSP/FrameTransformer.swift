//
//  FrameTransformer.swift
//  TrackRide
//
//  Transform device acceleration to horse-relative reference frame using quaternion rotation
//

import Foundation
import CoreMotion

/// Acceleration in horse-relative reference frame
struct HorseFrameAcceleration {
    /// Forward-backward acceleration (positive = forward)
    let forward: Double

    /// Left-right acceleration (positive = right)
    let lateral: Double

    /// Vertical acceleration (positive = up)
    let vertical: Double

    /// Magnitude of total acceleration
    var magnitude: Double {
        sqrt(forward * forward + lateral * lateral + vertical * vertical)
    }
}

/// Rotation rates in horse-relative reference frame
struct HorseFrameRotation {
    /// Pitch rate (nose up/down)
    let pitch: Double

    /// Roll rate (side to side)
    let roll: Double

    /// Yaw rate (turning left/right)
    let yaw: Double

    /// Magnitude of total rotation
    var magnitude: Double {
        sqrt(pitch * pitch + roll * roll + yaw * yaw)
    }
}

/// Transforms device sensor data to horse-relative reference frame
/// Using quaternion rotation to avoid gimbal lock
final class FrameTransformer {

    // MARK: - Calibration

    /// Calibration offset for phone mounting position
    /// Set at ride start to account for how phone is mounted on rider
    var calibrationQuaternion: (w: Double, x: Double, y: Double, z: Double) = (1, 0, 0, 0)

    /// Whether calibration has been performed
    var isCalibrated: Bool = false

    // MARK: - Initialization

    init() {}

    // MARK: - Calibration

    /// Calibrate the frame transformer using current device attitude
    /// Call this when rider is sitting upright on stationary horse
    /// - Parameter attitude: Current CMAttitude from device
    func calibrate(with attitude: CMAttitude) {
        let q = attitude.quaternion
        // Store inverse of calibration quaternion
        calibrationQuaternion = conjugate((q.w, q.x, q.y, q.z))
        isCalibrated = true
    }

    /// Reset calibration to identity
    func resetCalibration() {
        calibrationQuaternion = (1, 0, 0, 0)
        isCalibrated = false
    }

    // MARK: - Frame Transformation

    /// Transform device acceleration to horse-relative frame
    /// - Parameters:
    ///   - acceleration: Device userAcceleration (gravity removed)
    ///   - attitude: Device attitude for orientation
    /// - Returns: Acceleration in horse frame
    func toHorseFrame(
        acceleration: (x: Double, y: Double, z: Double),
        attitude: CMAttitude
    ) -> HorseFrameAcceleration {
        // Get quaternion
        let deviceQ = attitude.quaternion

        // Apply calibration offset if set
        let q: (w: Double, x: Double, y: Double, z: Double)
        if isCalibrated {
            q = multiplyQuaternions(calibrationQuaternion, (deviceQ.w, deviceQ.x, deviceQ.y, deviceQ.z))
        } else {
            q = (deviceQ.w, deviceQ.x, deviceQ.y, deviceQ.z)
        }

        // Rotate acceleration vector by quaternion
        // p' = q * p * q^-1 where p = (0, ax, ay, az)
        let rotated = rotateVector(acceleration, by: q)

        // Map to horse frame:
        // Device X (lateral) → Horse Y (lateral)
        // Device Y (forward) → Horse X (forward)
        // Device Z (vertical) → Horse Z (vertical)
        return HorseFrameAcceleration(
            forward: rotated.y,
            lateral: rotated.x,
            vertical: rotated.z
        )
    }

    /// Transform device rotation rates to horse-relative frame
    /// - Parameters:
    ///   - rotation: Device rotation rates (rad/s)
    ///   - attitude: Device attitude for orientation
    /// - Returns: Rotation in horse frame
    func toHorseFrame(
        rotation: (x: Double, y: Double, z: Double),
        attitude: CMAttitude
    ) -> HorseFrameRotation {
        let deviceQ = attitude.quaternion

        let q: (w: Double, x: Double, y: Double, z: Double)
        if isCalibrated {
            q = multiplyQuaternions(calibrationQuaternion, (deviceQ.w, deviceQ.x, deviceQ.y, deviceQ.z))
        } else {
            q = (deviceQ.w, deviceQ.x, deviceQ.y, deviceQ.z)
        }

        let rotated = rotateVector(rotation, by: q)

        return HorseFrameRotation(
            pitch: rotated.x,
            roll: rotated.y,
            yaw: rotated.z
        )
    }

    /// Convenience method using Euler angles instead of CMAttitude
    func toHorseFrame(
        acceleration: (x: Double, y: Double, z: Double),
        pitch: Double,
        roll: Double,
        yaw: Double
    ) -> HorseFrameAcceleration {
        let q = eulerToQuaternion(pitch: pitch, roll: roll, yaw: yaw)
        let rotated = rotateVector(acceleration, by: q)

        return HorseFrameAcceleration(
            forward: rotated.y,
            lateral: rotated.x,
            vertical: rotated.z
        )
    }

    // MARK: - Quaternion Operations

    /// Multiply two quaternions
    private func multiplyQuaternions(
        _ q1: (w: Double, x: Double, y: Double, z: Double),
        _ q2: (w: Double, x: Double, y: Double, z: Double)
    ) -> (w: Double, x: Double, y: Double, z: Double) {
        let w = q1.w * q2.w - q1.x * q2.x - q1.y * q2.y - q1.z * q2.z
        let x = q1.w * q2.x + q1.x * q2.w + q1.y * q2.z - q1.z * q2.y
        let y = q1.w * q2.y - q1.x * q2.z + q1.y * q2.w + q1.z * q2.x
        let z = q1.w * q2.z + q1.x * q2.y - q1.y * q2.x + q1.z * q2.w
        return (w, x, y, z)
    }

    /// Conjugate (inverse for unit quaternion)
    private func conjugate(
        _ q: (w: Double, x: Double, y: Double, z: Double)
    ) -> (w: Double, x: Double, y: Double, z: Double) {
        return (q.w, -q.x, -q.y, -q.z)
    }

    /// Rotate a vector by a quaternion using q * v * q^-1
    private func rotateVector(
        _ v: (x: Double, y: Double, z: Double),
        by q: (w: Double, x: Double, y: Double, z: Double)
    ) -> (x: Double, y: Double, z: Double) {
        // Convert vector to quaternion (w=0)
        let vq = (w: 0.0, x: v.x, y: v.y, z: v.z)

        // q * v * q^-1
        let qInv = conjugate(q)
        let temp = multiplyQuaternions(q, vq)
        let result = multiplyQuaternions(temp, qInv)

        return (result.x, result.y, result.z)
    }

    /// Convert Euler angles to quaternion
    private func eulerToQuaternion(
        pitch: Double,
        roll: Double,
        yaw: Double
    ) -> (w: Double, x: Double, y: Double, z: Double) {
        let cy = cos(yaw * 0.5)
        let sy = sin(yaw * 0.5)
        let cp = cos(pitch * 0.5)
        let sp = sin(pitch * 0.5)
        let cr = cos(roll * 0.5)
        let sr = sin(roll * 0.5)

        let w = cr * cp * cy + sr * sp * sy
        let x = sr * cp * cy - cr * sp * sy
        let y = cr * sp * cy + sr * cp * sy
        let z = cr * cp * sy - sr * sp * cy

        return (w, x, y, z)
    }
}

// MARK: - MotionSample Extension

extension FrameTransformer {

    /// Transform a complete MotionSample to horse frame
    /// - Parameter sample: Raw motion sample from MotionManager
    /// - Returns: Tuple of (acceleration, rotation) in horse frame
    func transform(_ sample: MotionSample) -> (accel: HorseFrameAcceleration, rotation: HorseFrameRotation) {
        let accel = toHorseFrame(
            acceleration: (sample.accelerationX, sample.accelerationY, sample.accelerationZ),
            pitch: sample.pitch,
            roll: sample.roll,
            yaw: sample.yaw
        )

        // For rotation, we don't need attitude-based transformation
        // as rotation rates are already in device frame and we just need axis mapping
        let rotation = HorseFrameRotation(
            pitch: sample.rotationX,
            roll: sample.rotationY,
            yaw: sample.rotationZ
        )

        return (accel, rotation)
    }
}
