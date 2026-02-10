//
//  SignalFilter.swift
//  TetraTrackShared
//
//  Exponential Moving Average filter for low-latency noise reduction
//  Used for smoothing accelerometer and gyroscope data in fall detection
//

import Foundation

/// Exponential Moving Average (EMA) filter for a single value
/// EMA provides low-latency smoothing with configurable responsiveness
public struct SignalFilter: Sendable {
    private var smoothedValue: Double?

    /// Alpha controls responsiveness: higher = more responsive, lower = smoother
    /// 0.2 provides good balance between noise reduction and responsiveness
    public let alpha: Double

    public init(alpha: Double = 0.2) {
        self.alpha = max(0.0, min(1.0, alpha))
    }

    /// Apply EMA filter to a new value
    /// Formula: smoothed = alpha * newValue + (1 - alpha) * previousSmoothed
    public mutating func filter(_ newValue: Double) -> Double {
        if let previous = smoothedValue {
            let filtered = alpha * newValue + (1 - alpha) * previous
            smoothedValue = filtered
            return filtered
        } else {
            // First sample - no filtering possible
            smoothedValue = newValue
            return newValue
        }
    }

    /// Reset the filter state
    public mutating func reset() {
        smoothedValue = nil
    }

    /// Get the current smoothed value without adding a new sample
    public var currentValue: Double? {
        smoothedValue
    }
}

/// 3D vector filter for accelerometer/gyroscope data
public struct Vector3DFilter: Sendable {
    private var xFilter: SignalFilter
    private var yFilter: SignalFilter
    private var zFilter: SignalFilter

    public init(alpha: Double = 0.2) {
        xFilter = SignalFilter(alpha: alpha)
        yFilter = SignalFilter(alpha: alpha)
        zFilter = SignalFilter(alpha: alpha)
    }

    /// Apply EMA filter to all three axes
    public mutating func filter(x: Double, y: Double, z: Double) -> (x: Double, y: Double, z: Double) {
        let filteredX = xFilter.filter(x)
        let filteredY = yFilter.filter(y)
        let filteredZ = zFilter.filter(z)
        return (x: filteredX, y: filteredY, z: filteredZ)
    }

    /// Reset all axis filters
    public mutating func reset() {
        xFilter.reset()
        yFilter.reset()
        zFilter.reset()
    }

    /// Get current filtered values
    public var currentValues: (x: Double?, y: Double?, z: Double?) {
        (x: xFilter.currentValue, y: yFilter.currentValue, z: zFilter.currentValue)
    }
}

/// Utility for calculating magnitude from filtered 3D vectors
extension Vector3DFilter {
    /// Calculate the magnitude of the most recent filtered vector
    public var currentMagnitude: Double? {
        guard let x = xFilter.currentValue,
              let y = yFilter.currentValue,
              let z = zFilter.currentValue else {
            return nil
        }
        return sqrt(x * x + y * y + z * z)
    }
}
