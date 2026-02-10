//
//  PocketModeManager.swift
//  TetraTrack
//
//  Manages proximity-based pocket mode for full-sensor riding.
//  When enabled, the proximity sensor blacks out the screen while
//  keeping the app in foreground so CoreMotion continues at full rate.
//

import Foundation
import UIKit
import Observation
import os

@Observable
@MainActor
final class PocketModeManager {

    static let shared = PocketModeManager()

    // MARK: - State

    private(set) var isPocketModeActive: Bool = false
    private(set) var isMonitoring: Bool = false

    // MARK: - Settings

    /// User preference: auto-activate pocket mode via proximity sensor
    var autoActivateEnabled: Bool = true {
        didSet { UserDefaults.standard.set(autoActivateEnabled, forKey: Keys.autoActivateEnabled) }
    }

    /// Manual toggle (for users who want to activate before pocketing)
    var isManuallyEnabled: Bool = false

    // MARK: - Private

    private let audioCoach: AudioCoachManager
    private var lastProximityChange: Date?
    private let debounceInterval: TimeInterval = 1.5
    private var proximityObserver: NSObjectProtocol?

    private enum Keys {
        static let autoActivateEnabled = "pocketMode.autoActivateEnabled"
    }

    // MARK: - Init

    init(audioCoach: AudioCoachManager = .shared) {
        self.audioCoach = audioCoach
        if UserDefaults.standard.object(forKey: Keys.autoActivateEnabled) != nil {
            autoActivateEnabled = UserDefaults.standard.bool(forKey: Keys.autoActivateEnabled)
        }
    }

    // MARK: - Sensor Availability

    /// Check if proximity sensor exists on this device
    var isSensorAvailable: Bool {
        let device = UIDevice.current
        let wasEnabled = device.isProximityMonitoringEnabled
        device.isProximityMonitoringEnabled = true
        let available = device.isProximityMonitoringEnabled
        device.isProximityMonitoringEnabled = wasEnabled
        return available
    }

    // MARK: - Lifecycle

    func startMonitoring() {
        guard autoActivateEnabled || isManuallyEnabled else { return }
        guard isSensorAvailable else {
            Log.tracking.info("Proximity sensor not available - pocket mode disabled")
            return
        }

        UIDevice.current.isProximityMonitoringEnabled = true
        isMonitoring = true

        proximityObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.proximityStateDidChangeNotification,
            object: UIDevice.current,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleProximityChange()
            }
        }

        Log.tracking.info("Pocket mode monitoring started")
    }

    func stopMonitoring() {
        UIDevice.current.isProximityMonitoringEnabled = false
        isMonitoring = false
        isPocketModeActive = false
        isManuallyEnabled = false

        if let observer = proximityObserver {
            NotificationCenter.default.removeObserver(observer)
            proximityObserver = nil
        }

        Log.tracking.info("Pocket mode monitoring stopped")
    }

    /// Manual toggle from UI button
    func toggleManual() {
        isManuallyEnabled.toggle()
        if isManuallyEnabled {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }

    // MARK: - Private

    private func handleProximityChange() {
        let now = Date()
        if let last = lastProximityChange, now.timeIntervalSince(last) < debounceInterval {
            return
        }
        lastProximityChange = now

        let isProximityActive = UIDevice.current.proximityState

        if isProximityActive && !isPocketModeActive {
            isPocketModeActive = true
            audioCoach.announce("Pocket mode active. Full sensor tracking.")
            Log.tracking.info("Pocket mode activated - proximity detected")
        } else if !isProximityActive && isPocketModeActive {
            isPocketModeActive = false
            audioCoach.announce("Pocket mode off.")
            Log.tracking.info("Pocket mode deactivated - phone removed from pocket")
        }
    }
}
