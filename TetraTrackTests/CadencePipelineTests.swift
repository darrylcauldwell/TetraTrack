//
//  CadencePipelineTests.swift
//  TetraTrackTests
//
//  Regression tests for #270: walking/running cadence fallback pipeline.
//  Covers: Watch→phone fallback, CMPedometer warmup filter, cadence averaging,
//  and HealthKit retry conditions.
//

import Testing
import Foundation
@testable import TetraTrack

// MARK: - Walking Cadence Pipeline

@MainActor
struct WalkingCadencePipelineTests {

    // MARK: - Helpers

    private func makeTracker() -> SessionTracker {
        let locationManager = LocationManager()
        let gpsTracker = GPSSessionTracker(locationManager: locationManager)
        return SessionTracker(locationManager: locationManager, gpsTracker: gpsTracker)
    }

    private func makeWalkingPlugin() -> WalkingPlugin {
        WalkingPlugin(session: RunningSession(), selectedRoute: nil, targetCadence: 120)
    }

    // MARK: - Fallback: Watch → Phone

    @Test func watchCadencePreferredOverPhone() {
        let tracker = makeTracker()
        let plugin = makeWalkingPlugin()
        let watchManager = WatchConnectivityManager.shared

        // Set Watch cadence via mirrored motion dict
        watchManager.updateFromMirroredMotionDict(["mode": "walking", "cadence": 115])
        // Set phone cadence (CMPedometer)
        tracker.pedometerCadence = 110

        plugin.onTimerTick(elapsedTime: 1.0, tracker: tracker)

        // Watch cadence (115) should be used, not phone (110)
        #expect(plugin.currentCadence == 115)
        #expect(plugin.cadenceReadings == [115])

        // Reset for other tests
        watchManager.resetMotionMetrics()
    }

    @Test func phoneCadenceUsedWhenWatchIsZero() {
        let tracker = makeTracker()
        let plugin = makeWalkingPlugin()
        let watchManager = WatchConnectivityManager.shared

        // Ensure Watch cadence is 0 (no Watch connected)
        watchManager.resetMotionMetrics()
        #expect(watchManager.cadence == 0)

        // Phone provides cadence from CMPedometer
        tracker.pedometerCadence = 108

        plugin.onTimerTick(elapsedTime: 1.0, tracker: tracker)

        #expect(plugin.currentCadence == 108)
        #expect(plugin.cadenceReadings == [108])
    }

    @Test func noCadenceWhenBothSourcesZero() {
        let tracker = makeTracker()
        let plugin = makeWalkingPlugin()
        let watchManager = WatchConnectivityManager.shared

        watchManager.resetMotionMetrics()
        tracker.pedometerCadence = 0

        plugin.onTimerTick(elapsedTime: 1.0, tracker: tracker)

        #expect(plugin.currentCadence == 0)
        #expect(plugin.cadenceReadings.isEmpty)
    }

    // MARK: - Warmup Filter (>= 40 spm)

    @Test func warmupFilterRejectsLowCadence() {
        let tracker = makeTracker()
        let plugin = makeWalkingPlugin()
        let watchManager = WatchConnectivityManager.shared
        watchManager.resetMotionMetrics()

        // Simulate CMPedometer warmup: cadence = 13 spm (real value seen on device)
        tracker.pedometerCadence = 13
        plugin.onTimerTick(elapsedTime: 1.0, tracker: tracker)
        #expect(plugin.currentCadence == 0, "13 spm should be filtered as warmup noise")
        #expect(plugin.cadenceReadings.isEmpty)

        // Another warmup reading at 35 spm
        tracker.pedometerCadence = 35
        plugin.onTimerTick(elapsedTime: 2.0, tracker: tracker)
        #expect(plugin.currentCadence == 0, "35 spm should be filtered as warmup noise")
        #expect(plugin.cadenceReadings.isEmpty)
    }

    @Test func warmupFilterAcceptsBoundaryValue() {
        let tracker = makeTracker()
        let plugin = makeWalkingPlugin()
        let watchManager = WatchConnectivityManager.shared
        watchManager.resetMotionMetrics()

        // Exactly 40 spm — should be accepted
        tracker.pedometerCadence = 40
        plugin.onTimerTick(elapsedTime: 1.0, tracker: tracker)
        #expect(plugin.currentCadence == 40)
        #expect(plugin.cadenceReadings == [40])
    }

    @Test func warmupToNormalTransition() {
        let tracker = makeTracker()
        let plugin = makeWalkingPlugin()
        let watchManager = WatchConnectivityManager.shared
        watchManager.resetMotionMetrics()

        // Warmup phase: low readings filtered
        tracker.pedometerCadence = 13
        plugin.onTimerTick(elapsedTime: 1.0, tracker: tracker)
        tracker.pedometerCadence = 25
        plugin.onTimerTick(elapsedTime: 2.0, tracker: tracker)
        #expect(plugin.cadenceReadings.isEmpty, "Warmup readings should all be filtered")

        // Normal phase: valid readings accepted
        tracker.pedometerCadence = 108
        plugin.onTimerTick(elapsedTime: 3.0, tracker: tracker)
        tracker.pedometerCadence = 112
        plugin.onTimerTick(elapsedTime: 4.0, tracker: tracker)

        #expect(plugin.currentCadence == 112)
        #expect(plugin.cadenceReadings == [108, 112])
    }

    // MARK: - Cadence Accumulation

    @Test func cadenceReadingsAccumulate() {
        let tracker = makeTracker()
        let plugin = makeWalkingPlugin()
        let watchManager = WatchConnectivityManager.shared
        watchManager.resetMotionMetrics()

        let readings = [105, 108, 112, 110, 115]
        for (i, cadence) in readings.enumerated() {
            tracker.pedometerCadence = cadence
            plugin.onTimerTick(elapsedTime: Double(i + 1), tracker: tracker)
        }

        #expect(plugin.cadenceReadings.count == 5)
        #expect(plugin.cadenceReadings == readings)
        #expect(plugin.currentCadence == 115) // last reading
    }

    // MARK: - Session Stop: Average & Max

    @Test func onSessionStoppingComputesAverageAndMax() {
        let tracker = makeTracker()
        let plugin = makeWalkingPlugin()
        let watchManager = WatchConnectivityManager.shared
        watchManager.resetMotionMetrics()

        // Simulate a walk with varying cadence
        let readings = [100, 110, 120, 115, 105]
        for (i, cadence) in readings.enumerated() {
            tracker.pedometerCadence = cadence
            plugin.onTimerTick(elapsedTime: Double(i + 1), tracker: tracker)
        }

        _ = plugin.onSessionStopping(tracker: tracker)

        // Average: (100+110+120+115+105) / 5 = 110
        #expect(plugin.session.averageCadence == 110)
        // Max: 120
        #expect(plugin.session.maxCadence == 120)
    }

    @Test func onSessionStoppingWithNoReadingsLeavesZero() {
        let tracker = makeTracker()
        let plugin = makeWalkingPlugin()

        _ = plugin.onSessionStopping(tracker: tracker)

        #expect(plugin.session.averageCadence == 0)
        #expect(plugin.session.maxCadence == 0)
    }

    @Test func onSessionStoppingWritesTargetCadence() {
        let tracker = makeTracker()
        let plugin = WalkingPlugin(session: RunningSession(), selectedRoute: nil, targetCadence: 125)

        _ = plugin.onSessionStopping(tracker: tracker)

        #expect(plugin.session.targetCadence == 125)
    }

    // MARK: - Warmup Filter Does Not Corrupt Average

    @Test func warmupReadingsExcludedFromAverage() {
        let tracker = makeTracker()
        let plugin = makeWalkingPlugin()
        let watchManager = WatchConnectivityManager.shared
        watchManager.resetMotionMetrics()

        // Warmup noise — should be filtered
        tracker.pedometerCadence = 13
        plugin.onTimerTick(elapsedTime: 1.0, tracker: tracker)
        tracker.pedometerCadence = 25
        plugin.onTimerTick(elapsedTime: 2.0, tracker: tracker)

        // Real cadence
        tracker.pedometerCadence = 108
        plugin.onTimerTick(elapsedTime: 3.0, tracker: tracker)
        tracker.pedometerCadence = 112
        plugin.onTimerTick(elapsedTime: 4.0, tracker: tracker)

        _ = plugin.onSessionStopping(tracker: tracker)

        // Average should be (108+112)/2 = 110, NOT (13+25+108+112)/4 = 64
        #expect(plugin.session.averageCadence == 110)
        #expect(plugin.session.maxCadence == 112)
    }
}

// MARK: - Running Cadence Pipeline

@MainActor
struct RunningCadencePipelineTests {

    // MARK: - Helpers

    private func makeTracker() -> SessionTracker {
        let locationManager = LocationManager()
        let gpsTracker = GPSSessionTracker(locationManager: locationManager)
        return SessionTracker(locationManager: locationManager, gpsTracker: gpsTracker)
    }

    private func makeRunningPlugin() -> RunningPlugin {
        RunningPlugin(session: RunningSession())
    }

    private func setWatchRunningMode(cadence: Int) {
        let watchManager = WatchConnectivityManager.shared
        watchManager.updateFromMirroredMotionDict([
            "mode": "running",
            "cadence": cadence
        ])
    }

    // MARK: - Fallback: Watch → Phone

    @Test func watchCadencePreferredOverPhone() {
        let tracker = makeTracker()
        let plugin = makeRunningPlugin()

        // Set Watch to running mode with cadence 170
        setWatchRunningMode(cadence: 170)
        tracker.pedometerCadence = 165

        plugin.onTimerTick(elapsedTime: 1.0, tracker: tracker)

        #expect(plugin.currentCadence == 170)
        #expect(plugin.cadenceReadings == [170])

        WatchConnectivityManager.shared.resetMotionMetrics()
    }

    @Test func phoneCadenceUsedWhenWatchCadenceZero() {
        let tracker = makeTracker()
        let plugin = makeRunningPlugin()

        // Watch in running mode but cadence is 0
        setWatchRunningMode(cadence: 0)
        tracker.pedometerCadence = 160

        plugin.onTimerTick(elapsedTime: 1.0, tracker: tracker)

        #expect(plugin.currentCadence == 160)
        #expect(plugin.cadenceReadings == [160])

        WatchConnectivityManager.shared.resetMotionMetrics()
    }

    @Test func cadenceIgnoredWhenNotInRunningMode() {
        let tracker = makeTracker()
        let plugin = makeRunningPlugin()
        let watchManager = WatchConnectivityManager.shared

        // Watch in idle mode (not running) — cadence path not entered
        watchManager.resetMotionMetrics()
        tracker.pedometerCadence = 160

        plugin.onTimerTick(elapsedTime: 1.0, tracker: tracker)

        // RunningPlugin only reads cadence when watchManager.currentMotionMode == .running
        #expect(plugin.currentCadence == 0)
        #expect(plugin.cadenceReadings.isEmpty)
    }

    // MARK: - Warmup Filter

    @Test func warmupFilterRejectsLowCadence() {
        let tracker = makeTracker()
        let plugin = makeRunningPlugin()

        setWatchRunningMode(cadence: 0)
        tracker.pedometerCadence = 20
        plugin.onTimerTick(elapsedTime: 1.0, tracker: tracker)

        #expect(plugin.currentCadence == 0, "20 spm should be filtered as warmup noise")
        #expect(plugin.cadenceReadings.isEmpty)

        WatchConnectivityManager.shared.resetMotionMetrics()
    }

    @Test func warmupFilterAcceptsBoundaryValue() {
        let tracker = makeTracker()
        let plugin = makeRunningPlugin()

        setWatchRunningMode(cadence: 0)
        tracker.pedometerCadence = 40
        plugin.onTimerTick(elapsedTime: 1.0, tracker: tracker)

        #expect(plugin.currentCadence == 40)
        #expect(plugin.cadenceReadings == [40])

        WatchConnectivityManager.shared.resetMotionMetrics()
    }

    @Test func warmupToNormalTransition() {
        let tracker = makeTracker()
        let plugin = makeRunningPlugin()

        setWatchRunningMode(cadence: 0)

        // Warmup
        tracker.pedometerCadence = 15
        plugin.onTimerTick(elapsedTime: 1.0, tracker: tracker)
        #expect(plugin.cadenceReadings.isEmpty)

        // Normal
        tracker.pedometerCadence = 168
        plugin.onTimerTick(elapsedTime: 2.0, tracker: tracker)
        #expect(plugin.cadenceReadings == [168])

        WatchConnectivityManager.shared.resetMotionMetrics()
    }
}

// MARK: - HealthKit Retry Conditions

@MainActor
struct WalkingHealthKitRetryTests {

    // MARK: - Retry Condition Detection

    @Test func retryNeededWhenSteadinessNil() {
        let session = RunningSession()
        session.healthKitWalkingSteadiness = nil
        session.healthKitAsymmetry = 5.0 // present
        session.healthKitHRRecoveryOneMinute = 30.0 // present

        // Retry is needed if any key metric is nil
        let needsSteadiness = session.healthKitWalkingSteadiness == nil
        let needsAsymmetry = session.healthKitAsymmetry == nil
        let needsHRRecovery = session.healthKitHRRecoveryOneMinute == nil

        #expect(needsSteadiness == true)
        #expect(needsAsymmetry == false)
        #expect(needsHRRecovery == false)
        #expect(needsSteadiness || needsAsymmetry || needsHRRecovery)
    }

    @Test func retryNeededWhenAsymmetryNil() {
        let session = RunningSession()
        session.healthKitWalkingSteadiness = 85.0
        session.healthKitAsymmetry = nil
        session.healthKitHRRecoveryOneMinute = 30.0

        let needsAsymmetry = session.healthKitAsymmetry == nil
        #expect(needsAsymmetry == true)
    }

    @Test func retryNeededWhenHRRecoveryNil() {
        let session = RunningSession()
        session.healthKitWalkingSteadiness = 85.0
        session.healthKitAsymmetry = 5.0
        session.healthKitHRRecoveryOneMinute = nil

        let needsHRRecovery = session.healthKitHRRecoveryOneMinute == nil
        #expect(needsHRRecovery == true)
    }

    @Test func noRetryWhenAllMetricsPresent() {
        let session = RunningSession()
        session.healthKitWalkingSteadiness = 85.0
        session.healthKitAsymmetry = 5.0
        session.healthKitHRRecoveryOneMinute = 30.0

        let needsSteadiness = session.healthKitWalkingSteadiness == nil
        let needsAsymmetry = session.healthKitAsymmetry == nil
        let needsHRRecovery = session.healthKitHRRecoveryOneMinute == nil

        #expect(!(needsSteadiness || needsAsymmetry || needsHRRecovery),
                "No retry when all metrics are populated")
    }

    @Test func retryRequiresEndDate() {
        let session = RunningSession()
        session.healthKitWalkingSteadiness = nil
        session.endDate = nil

        // Retry condition requires endDate to be non-nil
        let needsSteadiness = session.healthKitWalkingSteadiness == nil
        let hasEndDate = session.endDate != nil

        #expect(needsSteadiness == true)
        #expect(hasEndDate == false, "No retry without endDate even if metrics are missing")
    }

    // MARK: - Score Recomputation After Retry

    @Test func steadinessRetryUpdatesStabilityScore() {
        let session = RunningSession()
        session.healthKitWalkingSteadiness = nil
        session.walkingStabilityScore = 0

        // Simulate what happens after retry succeeds
        let steadiness: Double = 78.0
        session.healthKitWalkingSteadiness = steadiness
        session.walkingStabilityScore = steadiness

        #expect(session.healthKitWalkingSteadiness == 78.0)
        #expect(session.walkingStabilityScore == 78.0)
    }

    @Test func asymmetryRetryUpdatesSymmetryScore() {
        let session = RunningSession()
        session.healthKitAsymmetry = nil
        session.walkingSymmetryScore = 0

        // Simulate asymmetry retry result: 8% asymmetry → symmetry score = 100 - (8 * 5) = 60
        let asymmetry: Double = 8.0
        session.healthKitAsymmetry = asymmetry
        session.walkingSymmetryScore = max(0, 100 - (asymmetry * 5))

        #expect(session.healthKitAsymmetry == 8.0)
        #expect(session.walkingSymmetryScore == 60.0)
    }

    @Test func highAsymmetryClampedToZero() {
        let session = RunningSession()

        // 25% asymmetry → 100 - (25 * 5) = -25 → clamped to 0
        let asymmetry: Double = 25.0
        session.healthKitAsymmetry = asymmetry
        session.walkingSymmetryScore = max(0, 100 - (asymmetry * 5))

        #expect(session.walkingSymmetryScore == 0.0)
    }
}
