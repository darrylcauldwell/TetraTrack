//
//  RideHealthCoordinator.swift
//  TrackRide
//
//  Extracted from RideTracker to handle heart rate and recovery services

import Foundation
import os

/// Coordinates heart rate monitoring and recovery analysis during rides
final class RideHealthCoordinator {
    private let heartRateService = HeartRateService()
    private let recoveryAnalyzer = RecoveryAnalyzer()

    // Configuration
    private var riderMaxHeartRate: Int = 180
    private var riderRestingHeartRate: Int = 60

    // Current state
    private(set) var currentHeartRate: Int = 0
    private(set) var averageHeartRate: Int = 0
    private(set) var maxHeartRate: Int = 0
    private(set) var currentZone: HeartRateZone = .zone1

    // Callbacks
    var onHeartRateZoneChanged: ((HeartRateZone) -> Void)?

    // MARK: - Configuration

    func configure(riderProfile: RiderProfile?) {
        if let profile = riderProfile {
            riderMaxHeartRate = profile.maxHeartRate
            riderRestingHeartRate = profile.restingHeartRate
            heartRateService.configure(maxHeartRate: riderMaxHeartRate)
        }
    }

    // MARK: - Monitoring

    func startMonitoring() async {
        await heartRateService.startMonitoring()
    }

    func stopMonitoring() {
        heartRateService.stopMonitoring()
    }

    func resetState() {
        currentHeartRate = 0
        averageHeartRate = 0
        maxHeartRate = 0
        currentZone = .zone1
        heartRateService.resetState()
    }

    // MARK: - Heart Rate Processing

    func processHeartRate(_ bpm: Int) {
        heartRateService.processHeartRate(bpm)

        currentHeartRate = bpm
        let newZone = HeartRateZone.zone(for: bpm, maxHR: riderMaxHeartRate)

        if newZone != currentZone {
            onHeartRateZoneChanged?(newZone)
        }

        currentZone = newZone
        averageHeartRate = heartRateService.averageHeartRate
        maxHeartRate = heartRateService.maxHeartRate
    }

    // MARK: - Statistics

    func getFinalStatistics() -> HeartRateStatistics {
        heartRateService.getFinalStatistics()
    }

    // MARK: - Recovery Analysis

    func startRecoveryAnalysis(peakHeartRate: Int) async {
        guard peakHeartRate > 0 else { return }
        await recoveryAnalyzer.startAnalysis(
            peakHeartRate: peakHeartRate,
            restingHeartRate: riderRestingHeartRate
        )
    }
}
