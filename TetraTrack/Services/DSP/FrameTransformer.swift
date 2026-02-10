//
//  FrameTransformer.swift
//  TetraTrack
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

    // MARK: - Calibration Drift Detection

    /// Running average of gravity direction in calibrated frame
    /// If this drifts significantly from (0, 0, -1), the phone has moved
    private var gravityRunningAvg: (x: Double, y: Double, z: Double) = (0, 0, -1)

    /// EMA alpha for gravity tracking (slow adaptation to avoid reacting to motion)
    private let gravityAlpha: Double = 0.01

    /// Faster EMA alpha for gravity tracking before first recalibration
    /// Converges 5x faster to detect misalignment from in-hand calibration
    private let earlyGravityAlpha: Double = 0.05

    /// Threshold for detecting significant calibration drift (radians)
    /// About 20 degrees of tilt indicates phone has moved
    /// Configurable per mount position (thigh needs wider threshold)
    var driftThreshold: Double = 0.35

    /// Number of samples since last drift check
    private var samplesSinceDriftCheck: Int = 0

    /// Check interval (every 100 samples = ~1 second at 100Hz)
    private let driftCheckInterval: Int = 100

    /// Whether calibration drift has been detected (reset after auto-recalibration)
    private(set) var calibrationDriftDetected: Bool = false

    /// Number of auto-recalibrations performed during this session
    private(set) var recalibrationCount: Int = 0

    /// Minimum samples between recalibrations (~30 seconds at 100Hz)
    /// Avoids constant corrections during vigorous movement
    private let recalibrationCooldown: Int = 3000

    /// Shorter cooldown for the first recalibration (~5 seconds at 100Hz)
    /// Allows quick correction if initial calibration caught the phone in-hand
    private let earlyRecalibrationCooldown: Int = 500

    /// Samples since last recalibration
    private var samplesSinceRecalibration: Int = 0

    /// Callback when calibration drift is detected
    var onCalibrationDrift: (() -> Void)?

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
        calibrationDriftDetected = false
        gravityRunningAvg = (0, 0, -1)
        samplesSinceDriftCheck = 0
        recalibrationCount = 0
        samplesSinceRecalibration = 0
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

    /// Transform a complete MotionSample to horse frame using quaternion data
    /// - Parameter sample: Raw motion sample from MotionManager
    /// - Returns: Tuple of (acceleration, rotation) in horse frame
    func transform(_ sample: MotionSample) -> (accel: HorseFrameAcceleration, rotation: HorseFrameRotation) {
        // Use quaternion for proper frame transformation with calibration
        let deviceQ = (w: sample.quaternionW, x: sample.quaternionX, y: sample.quaternionY, z: sample.quaternionZ)

        // Apply calibration offset if set
        let q: (w: Double, x: Double, y: Double, z: Double)
        if isCalibrated {
            q = multiplyQuaternions(calibrationQuaternion, deviceQ)
        } else {
            q = deviceQ
        }

        // Rotate acceleration vector by quaternion
        let accelVec = (x: sample.accelerationX, y: sample.accelerationY, z: sample.accelerationZ)
        let rotatedAccel = rotateVector(accelVec, by: q)

        let accel = HorseFrameAcceleration(
            forward: rotatedAccel.y,
            lateral: rotatedAccel.x,
            vertical: rotatedAccel.z
        )

        // Rotate rotation rates as well for consistent frame
        let rotVec = (x: sample.rotationX, y: sample.rotationY, z: sample.rotationZ)
        let rotatedRot = rotateVector(rotVec, by: q)

        let rotation = HorseFrameRotation(
            pitch: rotatedRot.x,
            roll: rotatedRot.y,
            yaw: rotatedRot.z
        )

        // Check for calibration drift and auto-recalibrate if needed
        if isCalibrated {
            samplesSinceRecalibration += 1
            checkCalibrationDrift(accel: accel)
        }

        return (accel, rotation)
    }

    // MARK: - Drift Detection

    /// Check if the phone has moved significantly since calibration
    /// Uses gravity direction: in a well-calibrated system at rest, vertical should be ~-1g
    /// When drift is detected, auto-recalibrates and resets drift tracking
    private func checkCalibrationDrift(accel: HorseFrameAcceleration) {
        // Update running average of gravity direction
        // During motion, instantaneous values vary, but the average should stay near (0, 0, -1)
        // Use faster convergence before first recalibration to detect in-hand misalignment sooner
        let alpha = recalibrationCount == 0 ? earlyGravityAlpha : gravityAlpha
        gravityRunningAvg.x = (1 - alpha) * gravityRunningAvg.x + alpha * accel.lateral
        gravityRunningAvg.y = (1 - alpha) * gravityRunningAvg.y + alpha * accel.forward
        gravityRunningAvg.z = (1 - alpha) * gravityRunningAvg.z + alpha * accel.vertical

        samplesSinceDriftCheck += 1

        // Only check periodically to avoid excessive computation
        guard samplesSinceDriftCheck >= driftCheckInterval else { return }
        samplesSinceDriftCheck = 0

        // Enforce cooldown between recalibrations
        // Use shorter cooldown before first recalibration for quick correction of in-hand calibration
        let activeCooldown = recalibrationCount == 0 ? earlyRecalibrationCooldown : recalibrationCooldown
        guard samplesSinceRecalibration >= activeCooldown else { return }

        // Calculate angle between current gravity direction and expected (0, 0, -1)
        // Using dot product: cos(angle) = a·b / (|a||b|)
        // Expected gravity in calibrated frame: (0, 0, -1)
        let gravMag = sqrt(gravityRunningAvg.x * gravityRunningAvg.x +
                          gravityRunningAvg.y * gravityRunningAvg.y +
                          gravityRunningAvg.z * gravityRunningAvg.z)

        guard gravMag > 0.5 else { return }  // Need reasonable gravity to measure

        // Dot product with (0, 0, -1) is just -z
        let cosAngle = -gravityRunningAvg.z / gravMag
        let angle = acos(max(-1.0, min(1.0, cosAngle)))

        // If angle exceeds threshold, phone has moved significantly — auto-recalibrate
        if angle > driftThreshold {
            recalibrate()
            onCalibrationDrift?()
        }
    }

    /// Compute a correction quaternion that rotates the observed gravity direction
    /// back to the expected (0, 0, -1), apply it to the calibration quaternion,
    /// then reset drift tracking so future drift can be detected and corrected.
    private func recalibrate() {
        // Normalize the observed gravity direction
        let mag = sqrt(gravityRunningAvg.x * gravityRunningAvg.x +
                       gravityRunningAvg.y * gravityRunningAvg.y +
                       gravityRunningAvg.z * gravityRunningAvg.z)
        guard mag > 0.5 else { return }

        let gx = gravityRunningAvg.x / mag
        let gy = gravityRunningAvg.y / mag
        let gz = gravityRunningAvg.z / mag

        // Target gravity direction in horse frame: (0, 0, -1)
        // Compute rotation from observed gravity to target using Rodrigues' formula
        // cross product: observed × target = (gx, gy, gz) × (0, 0, -1)
        let cx = gy * (-1) - gz * 0     // -gy
        let cy = gz * 0 - gx * (-1)     // gx
        let cz = gx * 0 - gy * 0        // 0
        let sinAngle = sqrt(cx * cx + cy * cy + cz * cz)
        let cosAngle = gx * 0 + gy * 0 + gz * (-1)  // -gz

        guard sinAngle > 1e-6 else { return }  // Vectors are nearly parallel, no correction needed

        // Axis-angle to quaternion
        let halfAngle = atan2(sinAngle, cosAngle) / 2
        let s = sin(halfAngle) / sinAngle
        let correctionQ = (w: cos(halfAngle), x: cx * s, y: cy * s, z: cz * s)

        // Apply correction: new calibration = correction * old calibration
        calibrationQuaternion = multiplyQuaternions(correctionQ, calibrationQuaternion)

        // Reset drift tracking for continued monitoring
        gravityRunningAvg = (0, 0, -1)
        samplesSinceDriftCheck = 0
        samplesSinceRecalibration = 0
        calibrationDriftDetected = false
        recalibrationCount += 1
    }

    /// Auto-calibrate using a motion sample
    /// Call this when rider is sitting upright on stationary horse
    func calibrate(with sample: MotionSample) {
        let q = (w: sample.quaternionW, x: sample.quaternionX, y: sample.quaternionY, z: sample.quaternionZ)
        // Store inverse of calibration quaternion
        calibrationQuaternion = conjugate(q)
        isCalibrated = true
    }
}
