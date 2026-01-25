//
//  FallDetectionManager.swift
//  TrackRide
//
//  Multi-sensor fall detection with emergency alert flow
//

import Foundation
import CoreMotion
import CoreLocation
import Observation
import UIKit
import SwiftData
import os

@Observable
@MainActor
final class FallDetectionManager: FallDetecting {
    // MARK: - State

    private(set) var isMonitoring: Bool = false
    private(set) var fallDetected: Bool = false
    private(set) var isWaitingForResponse: Bool = false
    private(set) var countdownSeconds: Int = 30
    private(set) var lastFallTime: Date?
    private(set) var lastFallLocation: CLLocationCoordinate2D?

    // MARK: - Configuration

    /// Impact threshold in G-forces (typical fall > 3G)
    private let impactThreshold: Double = 3.0

    /// Rotation threshold in radians/sec
    private let rotationThreshold: Double = 5.0

    /// Time after impact to check for no movement (seconds)
    private let postImpactWindow: TimeInterval = 2.0

    /// Countdown duration before sending emergency alert
    private let alertCountdown: Int = 30

    // MARK: - Private Properties

    private var recentAccelerations: [Double] = []
    private var recentRotations: [Double] = []
    private var lastSignificantMovement: Date = Date()
    private var impactDetectedTime: Date?
    private var countdownTimer: Timer?
    private var currentLocation: CLLocationCoordinate2D?
    private var modelContext: ModelContext?
    private var riderName: String = "Rider"

    // HR integration
    private weak var heartRateService: HeartRateService?

    // Signal filtering
    private var accelerationFilter = Vector3DFilter(alpha: 0.2)
    private var rotationFilter = Vector3DFilter(alpha: 0.2)

    // MARK: - Callbacks

    var onFallDetected: (() -> Void)?
    var onCountdownTick: ((Int) -> Void)?
    var onEmergencyAlert: ((CLLocationCoordinate2D?) -> Void)?
    var onFallDismissed: (() -> Void)?

    // MARK: - Singleton

    static let shared = FallDetectionManager()

    private init() {}

    // MARK: - Configuration

    func configure(modelContext: ModelContext, riderName: String = "Rider", heartRateService: HeartRateService? = nil) {
        self.modelContext = modelContext
        self.riderName = riderName
        self.heartRateService = heartRateService
        setupWatchCallbacks()
    }

    private func setupWatchCallbacks() {
        let watchManager = WatchConnectivityManager.shared

        // Handle fall detected from Watch
        watchManager.onWatchFallDetected = { [weak self] confidence, impact, rotation in
            guard let self else { return }
            // Trigger fall detection on iPhone when Watch detects fall
            if !self.fallDetected {
                self.triggerFallDetection()
            }
        }

        // Handle user confirmed OK from Watch
        watchManager.onWatchFallConfirmedOK = { [weak self] in
            self?.confirmOK()
        }

        // Handle emergency request from Watch
        watchManager.onWatchFallEmergency = { [weak self] in
            self?.requestEmergency()
        }
    }

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

    func updateLocation(_ coordinate: CLLocationCoordinate2D) {
        currentLocation = coordinate
    }

    /// Process motion data from MotionManager
    func processMotionSample(_ sample: MotionSample) {
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
        if accelMagnitude > 0.3 {
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

        // Sync to Watch
        WatchConnectivityManager.shared.syncFallStateToWatch(fallDetected: false, countdown: nil)
    }

    /// User requests emergency services
    func requestEmergency() {
        stopCountdown()
        triggerEmergencyAlert()
    }

    // MARK: - Private Methods

    private func checkForFall(accelMagnitude: Double, rotationMagnitude: Double) {
        // Get HR confidence modifier (0.85 - 1.15)
        // Higher modifier = more likely to trigger (lowers effective threshold)
        let hrConfidence = heartRateService?.getHeartRateConfidenceModifier() ?? 1.0

        // Adjust thresholds based on HR confidence
        // If HR spike detected (confidence > 1.0), we become more sensitive (lower threshold)
        // If HR is stable (confidence < 1.0), we become less sensitive (higher threshold)
        let adjustedImpactThreshold = impactThreshold / hrConfidence
        let adjustedRotationThreshold = rotationThreshold / hrConfidence

        // Phase 1: Detect high-impact event
        if accelMagnitude > adjustedImpactThreshold || rotationMagnitude > adjustedRotationThreshold {
            if impactDetectedTime == nil {
                impactDetectedTime = Date()
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
        lastFallLocation = currentLocation
        countdownSeconds = alertCountdown

        // Notify UI
        onFallDetected?()

        // Start countdown
        startCountdown()

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        // Sync to Watch
        WatchConnectivityManager.shared.syncFallStateToWatch(fallDetected: true, countdown: countdownSeconds)
    }

    private func startCountdown() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }

            self.countdownSeconds -= 1
            self.onCountdownTick?(self.countdownSeconds)

            // Haptic every 5 seconds
            if self.countdownSeconds % 5 == 0 {
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
            }

            if self.countdownSeconds <= 0 {
                self.stopCountdown()
                self.triggerEmergencyAlert()
            }
        }
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func triggerEmergencyAlert() {
        isWaitingForResponse = false
        onEmergencyAlert?(lastFallLocation)

        // Strong haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)

        // Send notifications to emergency contacts
        Task {
            await sendEmergencyNotifications()
        }
    }

    private func sendEmergencyNotifications() async {
        // Fetch emergency contacts
        guard let context = modelContext else {
            Log.safety.warning("No model context available for fetching emergency contacts")
            return
        }

        let descriptor = FetchDescriptor<EmergencyContact>(
            predicate: #Predicate { $0.notifyOnFall == true }
        )

        do {
            let contacts = try context.fetch(descriptor)

            guard !contacts.isEmpty else {
                Log.safety.warning("No emergency contacts configured")
                return
            }

            // Send notifications via NotificationManager
            await NotificationManager.shared.sendFallDetectionAlert(
                location: lastFallLocation,
                contacts: contacts,
                riderName: riderName
            )

            Log.safety.info("Emergency notifications sent to \(contacts.count) contacts")

        } catch {
            Log.safety.error("Failed to fetch emergency contacts: \(error)")
        }
    }
}

// MARK: - Fall Event

struct FallEvent {
    let timestamp: Date
    let location: CLLocationCoordinate2D?
    let impactMagnitude: Double
    let responded: Bool
    let responseTime: TimeInterval?
}
