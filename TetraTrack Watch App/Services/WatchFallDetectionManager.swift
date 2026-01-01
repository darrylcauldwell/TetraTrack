//
//  WatchFallDetectionManager.swift
//  TetraTrack Watch App
//
//  Watch-side fall detection with local alert and iPhone sync
//

import Foundation
import WatchKit
import Observation

/// Watch motion sample for fall detection
struct WatchFallMotionSample {
    let timestamp: Date
    let accelerationX: Double
    let accelerationY: Double
    let accelerationZ: Double
    let rotationX: Double
    let rotationY: Double
    let rotationZ: Double

    var accelerationMagnitude: Double {
        sqrt(accelerationX * accelerationX +
             accelerationY * accelerationY +
             accelerationZ * accelerationZ)
    }

    var rotationMagnitude: Double {
        sqrt(rotationX * rotationX +
             rotationY * rotationY +
             rotationZ * rotationZ)
    }
}

@Observable
final class WatchFallDetectionManager {
    // MARK: - State

    private(set) var isMonitoring: Bool = false
    private(set) var fallDetected: Bool = false
    private(set) var isWaitingForResponse: Bool = false
    private(set) var countdownSeconds: Int = 30
    private(set) var lastFallTime: Date?

    // MARK: - Configuration

    /// Impact threshold in G-forces (typical fall > 3G)
    private let impactThreshold: Double = 3.0

    /// Rotation threshold in radians/sec
    private let rotationThreshold: Double = 5.0

    /// Time after impact to check for no movement (seconds)
    private let postImpactWindow: TimeInterval = 2.0

    /// Countdown duration before sending emergency alert
    private let alertCountdown: Int = 30

    /// Threshold for significant movement
    private let movementThreshold: Double = 0.3

    // MARK: - Private Properties

    private var recentAccelerations: [Double] = []
    private var recentRotations: [Double] = []
    private var lastSignificantMovement: Date = Date()
    private var impactDetectedTime: Date?
    private var countdownTimer: Timer?

    // Signal filtering
    private var accelerationFilter = Vector3DFilter(alpha: 0.2)
    private var rotationFilter = Vector3DFilter(alpha: 0.2)

    // Last detected magnitudes (for reporting to iPhone)
    private var lastImpactMagnitude: Double = 0
    private var lastRotationMagnitude: Double = 0

    // MARK: - Callbacks

    var onFallDetected: (() -> Void)?
    var onCountdownTick: ((Int) -> Void)?
    var onEmergencyAlert: (() -> Void)?
    var onFallDismissed: (() -> Void)?

    // Sync with iPhone
    var onSendFallToiPhone: ((Double, Double, Double) -> Void)?  // confidence, impact, rotation

    // MARK: - Singleton

    static let shared = WatchFallDetectionManager()

    private init() {}

    // MARK: - Public Methods

    func startMonitoring() {
        isMonitoring = true
        fallDetected = false
        isWaitingForResponse = false
        recentAccelerations = []
        recentRotations = []
        lastSignificantMovement = Date()
        impactDetectedTime = nil
        accelerationFilter.reset()
        rotationFilter.reset()
    }

    func stopMonitoring() {
        isMonitoring = false
        stopCountdown()
        fallDetected = false
        isWaitingForResponse = false
    }

    /// Process motion data from WatchMotionManager
    func processMotionSample(_ sample: WatchFallMotionSample) {
        guard isMonitoring, !isWaitingForResponse else { return }

        // Apply EMA filtering to reduce noise
        let filteredAccel = accelerationFilter.filter(
            x: sample.accelerationX,
            y: sample.accelerationY,
            z: sample.accelerationZ
        )
        let filteredRotation = rotationFilter.filter(
            x: sample.rotationX,
            y: sample.rotationY,
            z: sample.rotationZ
        )

        // Calculate filtered magnitudes
        let accelMagnitude = sqrt(
            filteredAccel.x * filteredAccel.x +
            filteredAccel.y * filteredAccel.y +
            filteredAccel.z * filteredAccel.z
        )
        let rotationMagnitude = sqrt(
            filteredRotation.x * filteredRotation.x +
            filteredRotation.y * filteredRotation.y +
            filteredRotation.z * filteredRotation.z
        )

        // Keep sliding window of recent values
        recentAccelerations.append(accelMagnitude)
        recentRotations.append(rotationMagnitude)

        // Keep last 2 seconds of data (assuming ~50Hz updates)
        if recentAccelerations.count > 100 {
            recentAccelerations.removeFirst()
        }
        if recentRotations.count > 100 {
            recentRotations.removeFirst()
        }

        // Track significant movement
        if accelMagnitude > movementThreshold {
            lastSignificantMovement = Date()
        }

        // Check for fall pattern
        checkForFall(accelMagnitude: accelMagnitude, rotationMagnitude: rotationMagnitude)
    }

    /// User confirms they are OK
    func confirmOK() {
        stopCountdown()
        fallDetected = false
        isWaitingForResponse = false
        impactDetectedTime = nil
        onFallDismissed?()
    }

    /// User requests emergency services
    func requestEmergency() {
        stopCountdown()
        triggerEmergencyAlert()
    }

    /// Handle synced fall state from iPhone
    func handleSyncedFallState(detected: Bool, countdown: Int?) {
        if detected && !fallDetected {
            // iPhone detected fall - show alert on Watch
            fallDetected = true
            isWaitingForResponse = true
            lastFallTime = Date()

            if let countdown = countdown {
                countdownSeconds = countdown
            } else {
                countdownSeconds = alertCountdown
            }

            onFallDetected?()

            // If countdown not already running, sync the countdown display
            if countdownTimer == nil {
                startLocalCountdownDisplay()
            }

        } else if !detected && fallDetected {
            // iPhone cleared the fall state
            confirmOK()
        }
    }

    // MARK: - Private Methods

    private func checkForFall(accelMagnitude: Double, rotationMagnitude: Double) {
        // Phase 1: Detect high-impact event
        if accelMagnitude > impactThreshold || rotationMagnitude > rotationThreshold {
            if impactDetectedTime == nil {
                impactDetectedTime = Date()
                lastImpactMagnitude = accelMagnitude
                lastRotationMagnitude = rotationMagnitude
            }
        }

        // Phase 2: Check for immobility after impact
        guard let impactTime = impactDetectedTime else { return }

        let timeSinceImpact = Date().timeIntervalSince(impactTime)

        if timeSinceImpact >= postImpactWindow {
            // Check if there's been minimal movement since impact
            let timeSinceMovement = Date().timeIntervalSince(lastSignificantMovement)

            if timeSinceMovement >= postImpactWindow {
                // Fall pattern detected: impact followed by immobility
                triggerFallDetection()
            } else {
                // Movement detected after impact - likely not a fall
                impactDetectedTime = nil
            }
        }
    }

    private func triggerFallDetection() {
        guard !fallDetected else { return }

        fallDetected = true
        isWaitingForResponse = true
        lastFallTime = Date()
        countdownSeconds = alertCountdown

        // Notify iPhone
        let confidence = calculateConfidence()
        onSendFallToiPhone?(confidence, lastImpactMagnitude, lastRotationMagnitude)

        // Notify UI
        onFallDetected?()

        // Start countdown
        startCountdown()

        // Play fall detection haptic
        HapticManager.shared.playFallDetectionHaptic()
    }

    private func calculateConfidence() -> Double {
        // Calculate confidence based on how much the thresholds were exceeded
        let accelConfidence = min(lastImpactMagnitude / impactThreshold, 2.0) / 2.0
        let rotationConfidence = min(lastRotationMagnitude / rotationThreshold, 2.0) / 2.0
        return max(accelConfidence, rotationConfidence)
    }

    private func startCountdown() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }

            self.countdownSeconds -= 1
            self.onCountdownTick?(self.countdownSeconds)

            // Haptic feedback
            if self.countdownSeconds <= 10 {
                HapticManager.shared.playCountdownUrgentHaptic()
            } else {
                HapticManager.shared.playCountdownTickHaptic()
            }

            if self.countdownSeconds <= 0 {
                self.stopCountdown()
                self.triggerEmergencyAlert()
            }
        }
    }

    /// Display-only countdown for synced state from iPhone
    private func startLocalCountdownDisplay() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }

            self.countdownSeconds -= 1
            self.onCountdownTick?(self.countdownSeconds)

            // Haptic feedback
            if self.countdownSeconds <= 10 {
                HapticManager.shared.playCountdownUrgentHaptic()
            } else {
                HapticManager.shared.playCountdownTickHaptic()
            }

            // Don't trigger emergency here - iPhone handles it
            if self.countdownSeconds <= 0 {
                self.stopCountdown()
            }
        }
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func triggerEmergencyAlert() {
        isWaitingForResponse = false
        onEmergencyAlert?()

        // Strong haptic
        WKInterfaceDevice.current().play(.failure)
    }
}
