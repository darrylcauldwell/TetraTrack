//
//  MotionSample.swift
//  TetraTrackShared
//
//  Platform-agnostic motion sample containing accelerometer, gyroscope, and attitude data.
//  Produced by iPhone's MotionManager and Watch's WatchMotionManager.
//

import Foundation

// MARK: - Motion Sample

/// A sample of device motion data (platform-agnostic)
public struct MotionSample: Sendable {
    public let timestamp: Date

    // Accelerometer data (g-force)
    public let accelerationX: Double
    public let accelerationY: Double
    public let accelerationZ: Double

    // Gyroscope data (rad/s)
    public let rotationX: Double
    public let rotationY: Double
    public let rotationZ: Double

    // Attitude (radians)
    public let pitch: Double
    public let roll: Double
    public let yaw: Double

    // Quaternion for frame transformation (more accurate than Euler angles)
    public let quaternionW: Double
    public let quaternionX: Double
    public let quaternionY: Double
    public let quaternionZ: Double

    public init(
        timestamp: Date,
        accelerationX: Double, accelerationY: Double, accelerationZ: Double,
        rotationX: Double, rotationY: Double, rotationZ: Double,
        pitch: Double, roll: Double, yaw: Double,
        quaternionW: Double, quaternionX: Double, quaternionY: Double, quaternionZ: Double
    ) {
        self.timestamp = timestamp
        self.accelerationX = accelerationX
        self.accelerationY = accelerationY
        self.accelerationZ = accelerationZ
        self.rotationX = rotationX
        self.rotationY = rotationY
        self.rotationZ = rotationZ
        self.pitch = pitch
        self.roll = roll
        self.yaw = yaw
        self.quaternionW = quaternionW
        self.quaternionX = quaternionX
        self.quaternionY = quaternionY
        self.quaternionZ = quaternionZ
    }

    /// Acceleration magnitude (total g-force)
    public var accelerationMagnitude: Double {
        sqrt(accelerationX * accelerationX +
             accelerationY * accelerationY +
             accelerationZ * accelerationZ)
    }

    /// Rotation magnitude (total rotation rate)
    public var rotationMagnitude: Double {
        sqrt(rotationX * rotationX +
             rotationY * rotationY +
             rotationZ * rotationZ)
    }

    /// Lateral acceleration (X-axis, left/right)
    public var lateralAcceleration: Double {
        accelerationX
    }

    /// Vertical acceleration (Z-axis, up/down)
    public var verticalAcceleration: Double {
        accelerationZ
    }

    /// Forward acceleration (Y-axis, forward/back)
    public var forwardAcceleration: Double {
        accelerationY
    }

    /// Yaw rate (rotation around vertical axis)
    public var yawRate: Double {
        rotationZ
    }
}
