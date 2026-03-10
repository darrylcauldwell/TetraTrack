//
//  ActivityClassificationService.swift
//  TetraTrack
//
//  Hardware activity classification from CMMotionActivityManager (M-series coprocessor).
//  Negligible battery cost — runs on dedicated low-power hardware.
//

import CoreMotion
import Observation
import os

/// Hardware-classified activity state from the M-series motion coprocessor
struct ActivityClassification: Sendable {
    let isStationary: Bool
    let isWalking: Bool
    let isRunning: Bool
    let isCycling: Bool
    let isAutomotive: Bool
    let confidence: CMMotionActivityConfidence

    /// True when the coprocessor detects automotive or cycling activity
    var isInVehicle: Bool { isAutomotive || isCycling }

    var confidenceValue: Double {
        switch confidence {
        case .low: return 0.25
        case .medium: return 0.5
        case .high: return 1.0
        @unknown default: return 0.0
        }
    }
}

@Observable
@MainActor
final class ActivityClassificationService {
    static let shared = ActivityClassificationService()

    private(set) var currentActivity: ActivityClassification?

    private let activityManager = CMMotionActivityManager()
    private var isMonitoring = false

    private init() {}

    func startMonitoring() {
        guard CMMotionActivityManager.isActivityAvailable() else {
            Log.services.info("Activity classification unavailable on this device")
            return
        }
        guard !isMonitoring else { return }
        isMonitoring = true

        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let activity else { return }
            self?.currentActivity = ActivityClassification(
                isStationary: activity.stationary,
                isWalking: activity.walking,
                isRunning: activity.running,
                isCycling: activity.cycling,
                isAutomotive: activity.automotive,
                confidence: activity.confidence
            )
        }
        Log.services.debug("Activity classification monitoring started")
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        activityManager.stopActivityUpdates()
        isMonitoring = false
        currentActivity = nil
        Log.services.debug("Activity classification monitoring stopped")
    }
}
