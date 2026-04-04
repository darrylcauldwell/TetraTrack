//
//  ShootingShotDetector.swift
//  TetraTrack Watch App
//
//  Shot cycle state machine operating on 50Hz IMU stream.
//  Detects: idle → raise → settle → hold → shot → recovery → idle
//  Computes per-shot metrics for each detected shot.
//

import Foundation
import Observation
import os
import TetraTrackShared

/// Shot cycle state machine for detecting and analyzing individual shots
@MainActor
@Observable
final class ShootingShotDetector {
    // MARK: - State

    private(set) var currentPhase: ShotPhase = .idle
    private(set) var shotCount: Int = 0
    private(set) var currentHoldSteadiness: Double = 0 // 0-100, rolling window
    private(set) var lastShotMetrics: DetectedShotMetrics?

    // MARK: - Callbacks

    var onShotDetected: ((DetectedShotMetrics) -> Void)?

    // MARK: - Private State

    private var phaseStartTime: Date?
    private var cycleStartTime: Date?
    private var raiseStartTime: Date?
    private var settleStartTime: Date?
    private var holdStartTime: Date?

    // Rolling buffers for analysis
    private var holdSamples: [WatchMotionSample] = [] // samples during hold phase
    private var raiseSamples: [WatchMotionSample] = [] // samples during raise phase
    private var holdAttitudeSamples: [(pitch: Double, yaw: Double)] = []

    // Heart rate reference
    private var currentHeartRate: Int?

    // MARK: - Thresholds

    private let raiseAccelThreshold: Double = 0.3    // G above gravity to detect arm raise
    private let settleAccelThreshold: Double = 0.08  // G below this = motion decreasing
    private let holdAccelThreshold: Double = 0.03    // G below this = fine aim only
    private let shotAccelThreshold: Double = 0.8     // G spike = recoil impulse
    private let minHoldDuration: Double = 0.5        // Minimum hold before shot detection
    private let raiseTimeout: Double = 5.0           // Max raise duration
    private let settleTimeout: Double = 10.0         // Max settle duration
    private let recoveryTimeout: Double = 2.0        // Recovery phase timeout
    private let holdWindowSize: Int = 25             // 0.5s at 50Hz for rolling steadiness

    // MARK: - Initialization

    init() {}

    // MARK: - Public API

    /// Reset the detector for a new session
    func reset() {
        currentPhase = .idle
        shotCount = 0
        currentHoldSteadiness = 0
        lastShotMetrics = nil
        phaseStartTime = nil
        cycleStartTime = nil
        raiseStartTime = nil
        settleStartTime = nil
        holdStartTime = nil
        holdSamples = []
        raiseSamples = []
        holdAttitudeSamples = []
        currentHeartRate = nil
    }

    /// Update heart rate for shot correlation
    func updateHeartRate(_ hr: Int) {
        currentHeartRate = hr
    }

    /// Process a single IMU sample from WatchMotionManager
    func processSample(_ sample: WatchMotionSample) {
        let now = Date()
        // Subtract gravity (1G) from magnitude for user acceleration
        let userAccel = abs(sample.accelerationMagnitude - 1.0)

        switch currentPhase {
        case .idle:
            processIdle(userAccel: userAccel, now: now)

        case .raise:
            processRaise(userAccel: userAccel, sample: sample, now: now)

        case .settle:
            processSettle(userAccel: userAccel, sample: sample, now: now)

        case .hold:
            processHold(userAccel: userAccel, sample: sample, now: now)

        case .shot:
            // Immediate transition to recovery
            transitionTo(.recovery, at: now)

        case .recovery:
            processRecovery(userAccel: userAccel, now: now)
        }
    }

    // MARK: - Phase Processing

    private func processIdle(userAccel: Double, now: Date) {
        if userAccel > raiseAccelThreshold {
            transitionTo(.raise, at: now)
            cycleStartTime = now
        }
    }

    private func processRaise(userAccel: Double, sample: WatchMotionSample, now: Date) {
        raiseSamples.append(sample)

        // Check timeout
        if let start = raiseStartTime, now.timeIntervalSince(start) > raiseTimeout {
            transitionTo(.idle, at: now)
            return
        }

        // Transition to settle when motion decreases
        if userAccel < settleAccelThreshold {
            transitionTo(.settle, at: now)
        }
    }

    private func processSettle(userAccel: Double, sample: WatchMotionSample, now: Date) {
        // Check timeout
        if let start = settleStartTime, now.timeIntervalSince(start) > settleTimeout {
            transitionTo(.idle, at: now)
            return
        }

        // Transition to hold when very stable
        if userAccel < holdAccelThreshold {
            transitionTo(.hold, at: now)
        }
    }

    private func processHold(userAccel: Double, sample: WatchMotionSample, now: Date) {
        holdSamples.append(sample)
        holdAttitudeSamples.append((pitch: sample.pitch, yaw: sample.yaw))

        // Update rolling steadiness from last N samples
        updateRollingHoldSteadiness()

        // Check for shot (recoil spike during hold)
        if let holdStart = holdStartTime {
            let holdDuration = now.timeIntervalSince(holdStart)
            if holdDuration >= minHoldDuration && userAccel > shotAccelThreshold {
                // Shot detected!
                computeAndEmitShotMetrics(now: now)
                transitionTo(.shot, at: now)
            }
        }
    }

    private func processRecovery(userAccel: Double, now: Date) {
        if let start = phaseStartTime, now.timeIntervalSince(start) > recoveryTimeout {
            transitionTo(.idle, at: now)
        } else if userAccel < settleAccelThreshold {
            // Motion returned to baseline
            transitionTo(.idle, at: now)
        }
    }

    // MARK: - Phase Transitions

    private func transitionTo(_ newPhase: ShotPhase, at time: Date) {
        currentPhase = newPhase
        phaseStartTime = time

        switch newPhase {
        case .idle:
            raiseSamples = []
            holdSamples = []
            holdAttitudeSamples = []
            raiseStartTime = nil
            settleStartTime = nil
            holdStartTime = nil

        case .raise:
            raiseStartTime = time
            raiseSamples = []

        case .settle:
            settleStartTime = time

        case .hold:
            holdStartTime = time
            holdSamples = []
            holdAttitudeSamples = []

        case .shot, .recovery:
            break
        }
    }

    // MARK: - Metrics Computation

    private func updateRollingHoldSteadiness() {
        let window = holdSamples.suffix(holdWindowSize)
        guard window.count >= 5 else {
            currentHoldSteadiness = 0
            return
        }

        // Steadiness = inverse of attitude variance (pitch + yaw)
        let attitudes = holdAttitudeSamples.suffix(holdWindowSize)
        let pitchValues = attitudes.map { $0.pitch }
        let yawValues = attitudes.map { $0.yaw }

        let pitchVariance = variance(of: pitchValues)
        let yawVariance = variance(of: yawValues)
        let combinedVariance = pitchVariance + yawVariance

        // Map variance to 0-100 scale (lower variance = higher steadiness)
        // Typical variance ranges: <0.0001 excellent, >0.01 poor
        let score = max(0, min(100, 100.0 * (1.0 - combinedVariance / 0.01)))
        currentHoldSteadiness = score
    }

    private func computeAndEmitShotMetrics(now: Date) {
        shotCount += 1

        // Phase timings
        let raiseDuration = (settleStartTime ?? now).timeIntervalSince(raiseStartTime ?? now)
        let settleDuration = (holdStartTime ?? now).timeIntervalSince(settleStartTime ?? now)
        let holdDuration = now.timeIntervalSince(holdStartTime ?? now)
        let totalCycleTime = now.timeIntervalSince(cycleStartTime ?? now)

        // Raise smoothness: inverse of jerk magnitude during raise
        let raiseSmoothness = computeRaiseSmoothness()

        // Hold steadiness: inverse of attitude variance during hold
        let holdSteadiness = computeHoldSteadiness()

        // Tremor: high-frequency power (>3Hz) during hold — simplified time-domain
        let tremorIntensity = computeTremorIntensity()

        // Drift: low-frequency power (<1Hz) during hold
        let driftMagnitude = computeDriftMagnitude()

        // Pitch/yaw variance for iPhone analysis
        let pitchValues = holdAttitudeSamples.map { $0.pitch }
        let yawValues = holdAttitudeSamples.map { $0.yaw }
        let holdPitchVariance = variance(of: pitchValues)
        let holdYawVariance = variance(of: yawValues)

        let metrics = DetectedShotMetrics(
            shotIndex: shotCount,
            timestamp: now,
            raiseDuration: raiseDuration,
            settleDuration: settleDuration,
            holdDuration: holdDuration,
            totalCycleTime: totalCycleTime,
            raiseSmoothness: raiseSmoothness,
            holdSteadiness: holdSteadiness,
            tremorIntensity: tremorIntensity,
            driftMagnitude: driftMagnitude,
            holdPitchVariance: holdPitchVariance,
            holdYawVariance: holdYawVariance,
            heartRateAtShot: currentHeartRate
        )

        lastShotMetrics = metrics
        onShotDetected?(metrics)
    }

    private func computeRaiseSmoothness() -> Double {
        guard raiseSamples.count >= 3 else { return 50 }

        // Calculate jerk (rate of change of acceleration) during raise
        var totalJerk: Double = 0
        for i in 1..<raiseSamples.count {
            let dt = raiseSamples[i].timestamp - raiseSamples[i-1].timestamp
            guard dt > 0 else { continue }
            let accelChange = abs(raiseSamples[i].accelerationMagnitude - raiseSamples[i-1].accelerationMagnitude)
            totalJerk += accelChange / dt
        }
        let avgJerk = totalJerk / Double(raiseSamples.count - 1)

        // Map jerk to 0-100 score (lower jerk = smoother = higher score)
        // Typical range: <5 excellent, >50 jerky
        return max(0, min(100, 100.0 * (1.0 - avgJerk / 50.0)))
    }

    private func computeHoldSteadiness() -> Double {
        guard holdSamples.count >= 5 else { return 0 }

        let pitchValues = holdAttitudeSamples.map { $0.pitch }
        let yawValues = holdAttitudeSamples.map { $0.yaw }

        let pitchVar = variance(of: pitchValues)
        let yawVar = variance(of: yawValues)
        let combinedVariance = pitchVar + yawVar

        return max(0, min(100, 100.0 * (1.0 - combinedVariance / 0.01)))
    }

    private func computeTremorIntensity() -> Double {
        // Simplified time-domain tremor: high-frequency variation in acceleration
        // At 50Hz, tremor >3Hz means changes between consecutive samples
        guard holdSamples.count >= 10 else { return 0 }

        var highFreqPower: Double = 0
        for i in 2..<holdSamples.count {
            // Second derivative (acceleration of acceleration) approximates high-freq content
            let a0 = holdSamples[i-2].accelerationMagnitude
            let a1 = holdSamples[i-1].accelerationMagnitude
            let a2 = holdSamples[i].accelerationMagnitude
            let secondDeriv = a2 - 2.0 * a1 + a0
            highFreqPower += secondDeriv * secondDeriv
        }
        let avgHighFreq = highFreqPower / Double(holdSamples.count - 2)

        // Map to 0-100 (higher = more tremor)
        // Typical range: <0.0001 minimal tremor, >0.005 significant
        return max(0, min(100, avgHighFreq / 0.005 * 100.0))
    }

    private func computeDriftMagnitude() -> Double {
        // Drift: overall trend in attitude during hold (low-frequency movement)
        guard holdAttitudeSamples.count >= 10 else { return 0 }

        let pitchValues = holdAttitudeSamples.map { $0.pitch }
        let yawValues = holdAttitudeSamples.map { $0.yaw }

        // Simple drift = range of values (max - min)
        let pitchRange = (pitchValues.max() ?? 0) - (pitchValues.min() ?? 0)
        let yawRange = (yawValues.max() ?? 0) - (yawValues.min() ?? 0)
        let totalDrift = pitchRange + yawRange

        // Map to 0-100 (higher = more drift)
        // Typical range: <0.02 rad minimal, >0.2 rad significant
        return max(0, min(100, totalDrift / 0.2 * 100.0))
    }

    // MARK: - Helpers

    private func variance(of values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let sumSquaredDiffs = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        return sumSquaredDiffs / Double(values.count - 1)
    }
}
