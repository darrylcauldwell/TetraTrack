//
//  RecoveryAnalyzer.swift
//  TrackRide
//
//  Post-ride heart rate recovery analysis
//

import Foundation
import HealthKit
import Observation
import os

@Observable
final class RecoveryAnalyzer: Resettable {
    // MARK: - State

    private(set) var isAnalyzing: Bool = false
    private(set) var currentSession: RecoverySession?
    private(set) var latestMetrics: RecoveryMetrics?
    private(set) var secondsSinceRideEnd: TimeInterval = 0

    // MARK: - Configuration

    private let healthStore = HKHealthStore()
    private var rideEndTime: Date?
    private var peakHeartRate: Int = 0
    private var restingHeartRate: Int?
    private var samples: [RecoverySample] = []
    private var monitoringTimer: Timer?
    private var anchoredQuery: HKAnchoredObjectQuery?
    private var queryAnchor: HKQueryAnchor?

    /// Duration to monitor recovery (2 minutes for 1-min and 2-min recovery)
    private let monitoringDuration: TimeInterval = 150  // 2.5 minutes

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Start recovery analysis after ride ends
    /// - Parameters:
    ///   - peakHeartRate: The maximum heart rate during the ride
    ///   - restingHeartRate: The rider's resting heart rate (for time-to-resting calculation)
    func startAnalysis(peakHeartRate: Int, restingHeartRate: Int?) async {
        guard HKHealthStore.isHealthDataAvailable() else {
            Log.health.warning("RecoveryAnalyzer: HealthKit not available")
            return
        }

        self.rideEndTime = Date()
        self.peakHeartRate = peakHeartRate
        self.restingHeartRate = restingHeartRate
        self.samples = []
        self.isAnalyzing = true
        self.secondsSinceRideEnd = 0

        currentSession = RecoverySession(
            rideEndTime: rideEndTime!,
            peakHeartRate: peakHeartRate,
            restingHeartRate: restingHeartRate
        )

        // Start monitoring
        startHeartRateMonitoring()
        startTimer()
    }

    /// Stop recovery analysis
    func stopAnalysis() {
        isAnalyzing = false
        stopTimer()
        stopHeartRateMonitoring()

        // Build final metrics
        if !samples.isEmpty {
            currentSession = RecoverySession(
                rideEndTime: rideEndTime ?? Date(),
                samples: samples,
                peakHeartRate: peakHeartRate,
                restingHeartRate: restingHeartRate
            )
            latestMetrics = currentSession?.buildMetrics()
        }
    }

    /// Get the final recovery metrics
    func getMetrics() -> RecoveryMetrics? {
        if isAnalyzing {
            stopAnalysis()
        }
        return latestMetrics
    }

    /// Reset the analyzer
    func reset() {
        stopAnalysis()
        rideEndTime = nil
        peakHeartRate = 0
        restingHeartRate = nil
        samples = []
        currentSession = nil
        latestMetrics = nil
        secondsSinceRideEnd = 0
    }

    // MARK: - Private Methods

    private func startTimer() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            if let rideEnd = self.rideEndTime {
                self.secondsSinceRideEnd = Date().timeIntervalSince(rideEnd)

                // Auto-stop after monitoring duration
                if self.secondsSinceRideEnd >= self.monitoringDuration {
                    self.stopAnalysis()
                }
            }
        }
    }

    private func stopTimer() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    private func startHeartRateMonitoring() {
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(
            withStart: rideEndTime,
            end: nil,
            options: .strictStartDate
        )

        anchoredQuery = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: queryAnchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, anchor, error in
            self?.handleQueryResults(samples: samples, anchor: anchor, error: error)
        }

        anchoredQuery?.updateHandler = { [weak self] _, samples, _, anchor, error in
            self?.handleQueryResults(samples: samples, anchor: anchor, error: error)
        }

        if let query = anchoredQuery {
            healthStore.execute(query)
        }
    }

    private func stopHeartRateMonitoring() {
        if let query = anchoredQuery {
            healthStore.stop(query)
            anchoredQuery = nil
        }
    }

    private func handleQueryResults(
        samples: [HKSample]?,
        anchor: HKQueryAnchor?,
        error: Error?
    ) {
        if let error = error {
            Log.health.error("RecoveryAnalyzer: Query error - \(error)")
            return
        }

        queryAnchor = anchor

        guard let heartRateSamples = samples as? [HKQuantitySample],
              let rideEnd = rideEndTime else {
            return
        }

        for sample in heartRateSamples {
            let bpm = Int(sample.quantity.doubleValue(for: .count().unitDivided(by: .minute())))
            let recoverySample = RecoverySample(
                timestamp: sample.startDate,
                bpm: bpm,
                rideEndTime: rideEnd
            )
            self.samples.append(recoverySample)
        }

        // Sort samples by time
        self.samples.sort { $0.timestamp < $1.timestamp }

        // Update current session
        DispatchQueue.main.async {
            self.currentSession = RecoverySession(
                rideEndTime: rideEnd,
                samples: self.samples,
                peakHeartRate: self.peakHeartRate,
                restingHeartRate: self.restingHeartRate
            )
        }
    }

    // MARK: - Computed Properties

    /// Current 1-minute recovery (if available)
    var oneMinuteRecovery: Int? {
        currentSession?.oneMinuteRecovery
    }

    /// Current 2-minute recovery (if available)
    var twoMinuteRecovery: Int? {
        currentSession?.twoMinuteRecovery
    }

    /// Current recovery quality
    var recoveryQuality: RecoveryQuality {
        if let recovery = oneMinuteRecovery {
            return RecoveryQuality.quality(for: recovery)
        }
        return .unknown
    }

    /// Latest heart rate sample
    var latestHeartRate: Int? {
        samples.last?.bpm
    }
}
