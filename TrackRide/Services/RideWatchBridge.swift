//
//  RideWatchBridge.swift
//  TrackRide
//
//  Extracted from RideTracker to handle Watch communication

import Foundation
import os

/// Handles all Watch connectivity and communication during rides
final class RideWatchBridge {
    private let watchConnectivity = WatchConnectivityManager.shared
    private var watchUpdateTimer: Timer?

    // Callbacks for incoming Watch commands
    var onStartRide: (() async -> Void)?
    var onStopRide: (() -> Void)?
    var onRequestStatus: (() -> Void)?
    var onHeartRateReceived: ((Int) -> Void)?
    var onVoiceNoteReceived: ((String) -> Void)?

    init() {
        setupWatchConnectivity()
    }

    // MARK: - Setup

    private func setupWatchConnectivity() {
        watchConnectivity.activate()

        watchConnectivity.onCommandReceived = { [weak self] command in
            guard let self else { return }
            Task { @MainActor in
                switch command {
                case .startRide:
                    await self.onStartRide?()
                case .stopRide:
                    self.onStopRide?()
                case .pauseRide, .resumeRide:
                    break
                case .requestStatus:
                    self.onRequestStatus?()
                case .heartRateUpdate:
                    break // Handled by onHeartRateReceived
                case .voiceNote:
                    break // Handled by onVoiceNoteReceived
                case .startMotionTracking, .stopMotionTracking, .motionUpdate:
                    break // Handled by discipline-specific views
                case .fallDetected, .fallConfirmedOK, .fallEmergency, .syncFallState:
                    break // Handled by FallDetectionManager
                }
            }
        }

        watchConnectivity.onHeartRateReceived = { [weak self] bpm in
            self?.onHeartRateReceived?(bpm)
        }

        watchConnectivity.onVoiceNoteReceived = { [weak self] noteText in
            self?.onVoiceNoteReceived?(noteText)
        }
    }

    // MARK: - Updates

    func startUpdates(statusProvider: @escaping () -> Void) {
        watchUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            statusProvider()
        }
    }

    func stopUpdates() {
        watchUpdateTimer?.invalidate()
        watchUpdateTimer = nil
    }

    // MARK: - Status

    func sendStatus(
        rideState: SharedRideState,
        duration: TimeInterval,
        distance: Double,
        speed: Double,
        gait: String,
        heartRate: Int?,
        heartRateZone: Int?,
        averageHeartRate: Int?,
        maxHeartRate: Int?,
        horseName: String?,
        rideType: String?,
        walkPercent: Double?,
        trotPercent: Double?,
        canterPercent: Double?,
        gallopPercent: Double?,
        leftTurnCount: Int?,
        rightTurnCount: Int?,
        leftReinPercent: Double?,
        rightReinPercent: Double?,
        leftLeadPercent: Double?,
        rightLeadPercent: Double?,
        symmetryScore: Double?,
        rhythmScore: Double?,
        optimalTime: TimeInterval?,
        timeDifference: TimeInterval?,
        elevation: Double?
    ) {
        watchConnectivity.sendStatusUpdate(
            rideState: rideState,
            duration: duration,
            distance: distance,
            speed: speed,
            gait: gait,
            heartRate: heartRate,
            heartRateZone: heartRateZone,
            averageHeartRate: averageHeartRate,
            maxHeartRate: maxHeartRate,
            horseName: horseName,
            rideType: rideType,
            walkPercent: walkPercent,
            trotPercent: trotPercent,
            canterPercent: canterPercent,
            gallopPercent: gallopPercent,
            leftTurnCount: leftTurnCount,
            rightTurnCount: rightTurnCount,
            leftReinPercent: leftReinPercent,
            rightReinPercent: rightReinPercent,
            leftLeadPercent: leftLeadPercent,
            rightLeadPercent: rightLeadPercent,
            symmetryScore: symmetryScore,
            rhythmScore: rhythmScore,
            optimalTime: optimalTime,
            timeDifference: timeDifference,
            elevation: elevation
        )
    }
}
