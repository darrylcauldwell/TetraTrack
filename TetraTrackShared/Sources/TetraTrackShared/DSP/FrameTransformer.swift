//
//  FrameTransformer.swift
//  TetraTrackShared
//
//  Transform device acceleration to horse-relative reference frame using quaternion rotation.
//  Platform-agnostic: works with MotionSample (no CoreMotion dependency).
//

import Foundation

// MARK: - Mount Position

/// Device mounting position on rider, affects axis mapping and drift thresholds
public enum MountPosition: String, Codable, CaseIterable, Sendable {
    case jodhpurThigh = "Jodhpur Pocket"
    case jacketChest = "Jacket Pocket"
    case wrist = "Wrist (Watch)"

    /// Number of motion samples to wait before calibrating
    public var calibrationDelay: Int {
        switch self {
        case .jodhpurThigh: return 100  // 1s at 100Hz — thigh bounces more
        case .jacketChest: return 50    // 0.5s — torso is more stable
        case .wrist: return 150         // 1.5s at 100Hz — wrist has most movement
        }
    }

    /// EMA filter alpha for motion filtering (lower = more smoothing)
    public var filterAlpha: Double {
        switch self {
        case .jodhpurThigh: return 0.7
        case .jacketChest: return 0.8
        case .wrist: return 0.6  // More smoothing needed for wrist movement
        }
    }

    /// Calibration drift threshold in radians
    public var driftThreshold: Double {
        switch self {
        case .jodhpurThigh: return 0.40
        case .jacketChest: return 0.50
        case .wrist: return 0.60  // Wrist moves more, wider threshold
        }
    }

    /// Minimum samples between recalibrations
    public var recalibrationCooldown: Int {
        switch self {
        case .jodhpurThigh: return 3000  // ~30s at 100Hz
        case .jacketChest: return 3000
        case .wrist: return 5000         // ~50s at 100Hz (or ~100s at 50Hz Watch)
        }
    }

    /// Vertical RMS threshold below which the rider is considered stationary
    public var motionGateVerticalThreshold: Double {
        switch self {
        case .jodhpurThigh: return 0.15
        case .jacketChest: return 0.15
        case .wrist: return 0.25  // Wrist has more ambient motion
        }
    }
}

// MARK: - Horse Frame Types

/// Acceleration in horse-relative reference frame
public struct HorseFrameAcceleration: Sendable {
    /// Forward-backward acceleration (positive = forward)
    public let forward: Double

    /// Left-right acceleration (positive = right)
    public let lateral: Double

    /// Vertical acceleration (positive = up)
    public let vertical: Double

    public init(forward: Double, lateral: Double, vertical: Double) {
        self.forward = forward
        self.lateral = lateral
        self.vertical = vertical
    }

    /// Magnitude of total acceleration
    public var magnitude: Double {
        sqrt(forward * forward + lateral * lateral + vertical * vertical)
    }
}

/// Rotation rates in horse-relative reference frame
public struct HorseFrameRotation: Sendable {
    /// Pitch rate (nose up/down)
    public let pitch: Double

    /// Roll rate (side to side)
    public let roll: Double

    /// Yaw rate (turning left/right)
    public let yaw: Double

    public init(pitch: Double, roll: Double, yaw: Double) {
        self.pitch = pitch
        self.roll = roll
        self.yaw = yaw
    }

    /// Magnitude of total rotation
    public var magnitude: Double {
        sqrt(pitch * pitch + roll * roll + yaw * yaw)
    }
}

// MARK: - Frame Transformer

/// Transforms device sensor data to horse-relative reference frame
/// Using quaternion rotation to avoid gimbal lock
public final class FrameTransformer {

    // MARK: - Calibration

    /// Calibration offset for device mounting position
    /// Set at session start to account for how device is mounted on rider
    public var calibrationQuaternion: (w: Double, x: Double, y: Double, z: Double) = (1, 0, 0, 0)

    /// Whether calibration has been performed
    public var isCalibrated: Bool = false

    // MARK: - Calibration Drift Detection

    /// Running average of gravity direction in calibrated frame
    /// If this drifts significantly from (0, 0, -1), the device has moved
    private var gravityRunningAvg: (x: Double, y: Double, z: Double) = (0, 0, -1)

    /// EMA alpha for gravity tracking (slow adaptation to avoid reacting to motion)
    private let gravityAlpha: Double = 0.03

    /// Faster EMA alpha for gravity tracking before first recalibration
    private let earlyGravityAlpha: Double = 0.05

    /// Threshold for detecting significant calibration drift (radians)
    /// Configurable per mount position
    public var driftThreshold: Double = 0.40

    /// Number of samples since last drift check
    private var samplesSinceDriftCheck: Int = 0

    /// Check interval (every 100 samples = ~1 second at 100Hz)
    private let driftCheckInterval: Int = 100

    /// Whether calibration drift has been detected (reset after auto-recalibration)
    public private(set) var calibrationDriftDetected: Bool = false

    /// Number of auto-recalibrations performed during this session
    public private(set) var recalibrationCount: Int = 0

    /// Minimum samples between recalibrations
    /// Configurable per mount position via recalibrationCooldownSamples
    private var recalibrationCooldownSamples: Int = 3000

    /// Shorter cooldown for the first recalibration (~5 seconds at 100Hz)
    private let earlyRecalibrationCooldown: Int = 500

    /// Samples since last recalibration
    private var samplesSinceRecalibration: Int = 0

    /// Callback when calibration drift is detected
    public var onCalibrationDrift: (() -> Void)?

    // MARK: - Motion Gate (prevents recalibration during movement)

    /// Device mount position, affects axis mapping and thresholds
    public var mountPosition: MountPosition = .jacketChest {
        didSet {
            driftThreshold = mountPosition.driftThreshold
            recalibrationCooldownSamples = mountPosition.recalibrationCooldown
            motionGateVerticalThreshold = mountPosition.motionGateVerticalThreshold
        }
    }

    /// Rolling buffer of vertical acceleration samples for motion gate
    private var verticalSamplesForGate: [Double] = []

    /// Rolling buffer of rotation magnitude samples for motion gate
    private var rotationSamplesForGate: [Double] = []

    /// Number of samples in the motion gate window
    private let gateWindowSize = 100

    /// Vertical RMS threshold below which the rider is considered stationary
    private var motionGateVerticalThreshold = 0.15

    /// Rotation RMS threshold below which the rider is considered stationary
    private let motionGateRotationThreshold = 0.3

    /// Whether the rider is currently stationary (both vertical and rotational RMS below thresholds)
    private var isStationary: Bool {
        guard verticalSamplesForGate.count >= 20 else { return true }
        let vWindow = verticalSamplesForGate.suffix(min(gateWindowSize, verticalSamplesForGate.count))
        let vMean = vWindow.reduce(0, +) / Double(vWindow.count)
        let vAC = vWindow.map { $0 - vMean }
        let verticalRMS = sqrt(vAC.map { $0 * $0 }.reduce(0, +) / Double(vAC.count))

        let rWindow = rotationSamplesForGate.suffix(min(gateWindowSize, rotationSamplesForGate.count))
        let rotationRMS = sqrt(rWindow.map { $0 * $0 }.reduce(0, +) / max(1.0, Double(rWindow.count)))

        return verticalRMS < motionGateVerticalThreshold && rotationRMS < motionGateRotationThreshold
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Calibration

    /// Calibrate the frame transformer using a motion sample's quaternion
    /// Call this when rider is sitting upright on stationary horse
    public func calibrate(with sample: MotionSample) {
        let q = normalize((w: sample.quaternionW, x: sample.quaternionX, y: sample.quaternionY, z: sample.quaternionZ))
        // Store inverse of calibration quaternion
        calibrationQuaternion = conjugate(q)
        isCalibrated = true
    }

    /// Calibrate using raw quaternion components
    public func calibrate(quaternionW w: Double, x: Double, y: Double, z: Double) {
        let q = normalize((w: w, x: x, y: y, z: z))
        calibrationQuaternion = conjugate(q)
        isCalibrated = true
    }

    /// Reset calibration to identity
    public func resetCalibration() {
        calibrationQuaternion = (1, 0, 0, 0)
        isCalibrated = false
        calibrationDriftDetected = false
        gravityRunningAvg = (0, 0, -1)
        samplesSinceDriftCheck = 0
        recalibrationCount = 0
        samplesSinceRecalibration = 0
        verticalSamplesForGate = []
        rotationSamplesForGate = []
    }

    // MARK: - Frame Transformation

    /// Transform a complete MotionSample to horse frame using quaternion data
    public func transform(_ sample: MotionSample) -> (accel: HorseFrameAcceleration, rotation: HorseFrameRotation) {
        // Use quaternion for proper frame transformation with calibration
        let deviceQ = normalize((w: sample.quaternionW, x: sample.quaternionX, y: sample.quaternionY, z: sample.quaternionZ))

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

        let accel = mapToHorseAccel(rotatedAccel)

        // Rotate rotation rates as well for consistent frame
        let rotVec = (x: sample.rotationX, y: sample.rotationY, z: sample.rotationZ)
        let rotatedRot = rotateVector(rotVec, by: q)

        let rotation = mapToHorseRotation(rotatedRot)

        // Accumulate motion gate samples
        verticalSamplesForGate.append(accel.vertical)
        rotationSamplesForGate.append(rotation.magnitude)
        if verticalSamplesForGate.count > gateWindowSize {
            verticalSamplesForGate.removeFirst()
        }
        if rotationSamplesForGate.count > gateWindowSize {
            rotationSamplesForGate.removeFirst()
        }

        // Check for calibration drift and auto-recalibrate if needed
        if isCalibrated {
            samplesSinceRecalibration += 1
            checkCalibrationDrift(accel: accel)
        }

        return (accel, rotation)
    }

    // MARK: - Mount-Aware Axis Mapping

    /// Map rotated acceleration to horse frame based on mount position
    private func mapToHorseAccel(_ rotated: (x: Double, y: Double, z: Double)) -> HorseFrameAcceleration {
        switch mountPosition {
        case .jacketChest:
            // Phone upright in chest pocket: Y=forward, X=lateral, Z=vertical
            return HorseFrameAcceleration(forward: rotated.y, lateral: rotated.x, vertical: rotated.z)
        case .jodhpurThigh:
            // Phone in thigh pocket: Z=forward, X=lateral, Y=vertical
            return HorseFrameAcceleration(forward: rotated.z, lateral: rotated.x, vertical: rotated.y)
        case .wrist:
            // Apple Watch on left wrist, crown facing elbow:
            // Watch X → horse lateral (left/right)
            // Watch Y → horse forward (direction of travel)
            // Watch Z → horse vertical (up/down bounce)
            return HorseFrameAcceleration(forward: rotated.y, lateral: rotated.x, vertical: rotated.z)
        }
    }

    /// Map rotated rotation rates to horse frame based on mount position
    private func mapToHorseRotation(_ rotated: (x: Double, y: Double, z: Double)) -> HorseFrameRotation {
        switch mountPosition {
        case .jacketChest:
            return HorseFrameRotation(pitch: rotated.x, roll: rotated.y, yaw: rotated.z)
        case .jodhpurThigh:
            return HorseFrameRotation(pitch: rotated.x, roll: rotated.z, yaw: rotated.y)
        case .wrist:
            // Watch on left wrist, crown facing elbow:
            // Watch rotX → pitch, Watch rotY → yaw, Watch rotZ → roll
            return HorseFrameRotation(pitch: rotated.x, roll: rotated.z, yaw: rotated.y)
        }
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
        let vq = (w: 0.0, x: v.x, y: v.y, z: v.z)
        let qInv = conjugate(q)
        let temp = multiplyQuaternions(q, vq)
        let result = multiplyQuaternions(temp, qInv)
        return (result.x, result.y, result.z)
    }

    /// Normalize a quaternion to unit length
    private func normalize(
        _ q: (w: Double, x: Double, y: Double, z: Double)
    ) -> (w: Double, x: Double, y: Double, z: Double) {
        let norm = sqrt(q.w * q.w + q.x * q.x + q.y * q.y + q.z * q.z)
        guard norm > 1e-10 else { return (1, 0, 0, 0) }
        return (q.w / norm, q.x / norm, q.y / norm, q.z / norm)
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

    // MARK: - Drift Detection

    /// Check if the device has moved significantly since calibration
    private func checkCalibrationDrift(accel: HorseFrameAcceleration) {
        let alpha = recalibrationCount == 0 ? earlyGravityAlpha : gravityAlpha
        gravityRunningAvg.x = (1 - alpha) * gravityRunningAvg.x + alpha * accel.lateral
        gravityRunningAvg.y = (1 - alpha) * gravityRunningAvg.y + alpha * accel.forward
        gravityRunningAvg.z = (1 - alpha) * gravityRunningAvg.z + alpha * accel.vertical

        samplesSinceDriftCheck += 1

        guard samplesSinceDriftCheck >= driftCheckInterval else { return }
        samplesSinceDriftCheck = 0

        let activeCooldown = recalibrationCount == 0 ? earlyRecalibrationCooldown : recalibrationCooldownSamples
        guard samplesSinceRecalibration >= activeCooldown else { return }

        let gravMag = sqrt(gravityRunningAvg.x * gravityRunningAvg.x +
                          gravityRunningAvg.y * gravityRunningAvg.y +
                          gravityRunningAvg.z * gravityRunningAvg.z)

        guard gravMag > 0.5 else { return }

        let cosAngle = -gravityRunningAvg.z / gravMag
        let angle = acos(max(-1.0, min(1.0, cosAngle)))

        guard isStationary else { return }

        if angle > driftThreshold {
            recalibrate()
            onCalibrationDrift?()
        }
    }

    /// Auto-recalibrate by computing correction quaternion from observed gravity drift
    private func recalibrate() {
        let mag = sqrt(gravityRunningAvg.x * gravityRunningAvg.x +
                       gravityRunningAvg.y * gravityRunningAvg.y +
                       gravityRunningAvg.z * gravityRunningAvg.z)
        guard mag > 0.5 else { return }

        let gx = gravityRunningAvg.x / mag
        let gy = gravityRunningAvg.y / mag
        let gz = gravityRunningAvg.z / mag

        // Rodrigues' rotation from observed gravity to target (0, 0, -1)
        let cx = gy * (-1) - gz * 0     // -gy
        let cy = gz * 0 - gx * (-1)     // gx
        let cz = gx * 0 - gy * 0        // 0
        let sinAngle = sqrt(cx * cx + cy * cy + cz * cz)
        let cosAngle = gx * 0 + gy * 0 + gz * (-1)  // -gz

        guard sinAngle > 1e-6 else { return }

        let halfAngle = atan2(sinAngle, cosAngle) / 2
        let s = sin(halfAngle) / sinAngle
        let correctionQ = (w: cos(halfAngle), x: cx * s, y: cy * s, z: cz * s)

        calibrationQuaternion = normalize(multiplyQuaternions(correctionQ, calibrationQuaternion))

        gravityRunningAvg = (0, 0, -1)
        samplesSinceDriftCheck = 0
        samplesSinceRecalibration = 0
        calibrationDriftDetected = false
        recalibrationCount += 1
    }
}
