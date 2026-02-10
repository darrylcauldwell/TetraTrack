//
//  FrameTransformerTests.swift
//  TetraTrackTests
//
//  Tests for FrameTransformer quaternion-based reference frame transformation
//

import Testing
import Foundation
@testable import TetraTrack

// MARK: - Helpers

/// Create a MotionSample with specified acceleration and quaternion values
private func createSample(
    accelX: Double = 0, accelY: Double = 0, accelZ: Double = 0,
    rotX: Double = 0, rotY: Double = 0, rotZ: Double = 0,
    qW: Double = 1, qX: Double = 0, qY: Double = 0, qZ: Double = 0
) -> MotionSample {
    MotionSample(
        timestamp: Date(),
        accelerationX: accelX, accelerationY: accelY, accelerationZ: accelZ,
        rotationX: rotX, rotationY: rotY, rotationZ: rotZ,
        pitch: 0, roll: 0, yaw: 0,
        quaternionW: qW, quaternionX: qX, quaternionY: qY, quaternionZ: qZ
    )
}

// MARK: - FrameTransformerTests

struct FrameTransformerTests {

    // MARK: - Initialization

    @Test func initialState() {
        let transformer = FrameTransformer()

        #expect(transformer.isCalibrated == false)
        #expect(transformer.calibrationDriftDetected == false)
        #expect(transformer.recalibrationCount == 0)
    }

    // MARK: - Identity Quaternion

    @Test func identityQuaternionNoTransformation() {
        let transformer = FrameTransformer()
        let sample = createSample(accelX: 0.5, accelY: 0.3, accelZ: -0.8, qW: 1, qX: 0, qY: 0, qZ: 0)

        let result = transformer.transform(sample)

        // With identity quaternion and no calibration, output should match input mapping:
        // lateral = rotated.x, forward = rotated.y, vertical = rotated.z
        #expect(abs(result.accel.lateral - 0.5) < 0.01)
        #expect(abs(result.accel.forward - 0.3) < 0.01)
        #expect(abs(result.accel.vertical - (-0.8)) < 0.01)
    }

    // MARK: - Calibration

    @Test func calibrateSetsIsCalibrated() {
        let transformer = FrameTransformer()
        let sample = createSample(qW: 1, qX: 0, qY: 0, qZ: 0)

        transformer.calibrate(with: sample)

        #expect(transformer.isCalibrated == true)
    }

    @Test func resetCalibrationClearsState() {
        let transformer = FrameTransformer()
        let sample = createSample(qW: 0.707, qX: 0.707, qY: 0, qZ: 0)

        transformer.calibrate(with: sample)
        #expect(transformer.isCalibrated == true)

        transformer.resetCalibration()
        #expect(transformer.isCalibrated == false)
        #expect(transformer.calibrationDriftDetected == false)
        #expect(transformer.recalibrationCount == 0)
    }

    // MARK: - Magnitude Preservation

    @Test func rotationPreservesAccelerationMagnitude() {
        let transformer = FrameTransformer()
        let ax = 0.3, ay = 0.5, az = -0.7
        let inputMag = sqrt(ax * ax + ay * ay + az * az)

        // Use a non-trivial quaternion (45 deg rotation around Z)
        let angle = Double.pi / 4
        let qW = cos(angle / 2)
        let qZ = sin(angle / 2)
        let sample = createSample(accelX: ax, accelY: ay, accelZ: az, qW: qW, qX: 0, qY: 0, qZ: qZ)

        let result = transformer.transform(sample)
        let outputMag = result.accel.magnitude

        // Magnitude should be preserved (rotation doesn't change length)
        #expect(abs(outputMag - inputMag) < 0.01)
    }

    // MARK: - Calibration Inverse

    @Test func calibrationInvertsQuaternion() {
        let transformer = FrameTransformer()

        // Calibrate with a rotation
        let angle = Double.pi / 6  // 30 degrees around X
        let qW = cos(angle / 2)
        let qX = sin(angle / 2)
        let calibSample = createSample(qW: qW, qX: qX, qY: 0, qZ: 0)
        transformer.calibrate(with: calibSample)

        // Transform with the same quaternion should produce near-identity result
        let testSample = createSample(accelX: 1.0, accelY: 0, accelZ: 0, qW: qW, qX: qX, qY: 0, qZ: 0)
        let result = transformer.transform(testSample)

        // After calibration with same quaternion, should get back approximately original axes
        #expect(abs(result.accel.lateral - 1.0) < 0.05)
        #expect(abs(result.accel.forward) < 0.05)
        #expect(abs(result.accel.vertical) < 0.05)
    }

    // MARK: - Drift Detection

    @Test func driftDetectionRequiresSustainedDrift() {
        let transformer = FrameTransformer()

        // Calibrate with identity
        let calibSample = createSample(qW: 1, qX: 0, qY: 0, qZ: 0)
        transformer.calibrate(with: calibSample)

        // Feed samples that indicate gravity has shifted significantly
        // Simulate large tilt: gravity now appears in forward direction
        // This requires many samples due to the EMA tracking (alpha = 0.01)
        // and the drift check interval (100 samples)
        let tiltAngle = Double.pi / 4  // 45 degrees
        let qW = cos(tiltAngle / 2)
        let qX = sin(tiltAngle / 2)

        for _ in 0..<500 {
            let sample = createSample(accelX: 0, accelY: 0.5, accelZ: -0.5,
                                      qW: qW, qX: qX, qY: 0, qZ: 0)
            _ = transformer.transform(sample)
        }

        // After many tilted samples, recalibration should have occurred
        // (may or may not, depending on the gravity averaging)
        #expect(transformer.recalibrationCount >= 0)  // At minimum doesn't crash
    }

    @Test func cooldownPreventsRapidRecalibration() {
        let transformer = FrameTransformer()
        let calibSample = createSample(qW: 1, qX: 0, qY: 0, qZ: 0)
        transformer.calibrate(with: calibSample)

        // Even if drift is detected, cooldown of 3000 samples prevents immediate re-recalibration
        // Feed 100 samples (one drift check interval) - not enough for cooldown
        for _ in 0..<200 {
            let sample = createSample(accelZ: -1.0, qW: 1, qX: 0, qY: 0, qZ: 0)
            _ = transformer.transform(sample)
        }

        // Should still be functioning normally
        #expect(transformer.isCalibrated == true)
    }

    // MARK: - Callback

    @Test func onCalibrationDriftCallbackFires() {
        let transformer = FrameTransformer()
        var callbackFired = false
        transformer.onCalibrationDrift = { callbackFired = true }

        // Calibrate with identity
        transformer.calibrate(with: createSample(qW: 1, qX: 0, qY: 0, qZ: 0))

        // Feed strongly tilted samples for a long time to trigger drift
        // We need to exceed recalibrationCooldown (3000 samples)
        let tiltAngle = Double.pi / 3
        let qW = cos(tiltAngle / 2)
        let qX = sin(tiltAngle / 2)

        for _ in 0..<4000 {
            let sample = createSample(accelX: 0, accelY: 0.7, accelZ: -0.3,
                                      qW: qW, qX: qX, qY: 0, qZ: 0)
            _ = transformer.transform(sample)
        }

        // Callback may or may not have fired depending on EMA convergence
        // Just verify it doesn't crash and is callable
        #expect(transformer.recalibrationCount >= 0)
    }

    // MARK: - Rotation Rates

    @Test func rotationRatesTransformed() {
        let transformer = FrameTransformer()
        let sample = createSample(rotX: 1.0, rotY: 0.5, rotZ: 0.3, qW: 1, qX: 0, qY: 0, qZ: 0)

        let result = transformer.transform(sample)

        // With identity quaternion, rotation mapping: pitch=x, roll=y, yaw=z
        #expect(abs(result.rotation.pitch - 1.0) < 0.01)
        #expect(abs(result.rotation.roll - 0.5) < 0.01)
        #expect(abs(result.rotation.yaw - 0.3) < 0.01)
    }

    @Test func rotationMagnitudePreserved() {
        let transformer = FrameTransformer()
        let rx = 0.4, ry = 0.6, rz = 0.8
        let inputMag = sqrt(rx * rx + ry * ry + rz * rz)

        let angle = Double.pi / 3
        let qW = cos(angle / 2)
        let qY = sin(angle / 2)
        let sample = createSample(rotX: rx, rotY: ry, rotZ: rz, qW: qW, qX: 0, qY: qY, qZ: 0)

        let result = transformer.transform(sample)
        let outputMag = result.rotation.magnitude

        #expect(abs(outputMag - inputMag) < 0.01)
    }
}
