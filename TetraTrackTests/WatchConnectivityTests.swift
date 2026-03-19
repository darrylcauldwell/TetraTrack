//
//  WatchConnectivityTests.swift
//  TetraTrackTests
//
//  Regression tests for #268: breadcrumbs merged into applicationContext
//  must not prevent HR, motion, or status data from being processed.
//

import Testing
import Foundation
import WatchConnectivity
@testable import TetraTrack

@MainActor
struct WatchConnectivityTests {

    // MARK: - Regression: applicationContext with breadcrumbs + data

    @Test func applicationContextWithBreadcrumbsAndDataProcessesBoth() {
        let manager = WatchConnectivityManager.shared
        let previousSeq = manager.heartRateSequence

        // Simulate a payload that contains both diagnostic breadcrumbs AND
        // a heart rate update — the exact scenario that caused the regression.
        let payload: [String: Any] = [
            "command": "heartRateUpdate",
            "heartRate": 142,
            "timestamp": Date().timeIntervalSince1970,
            "diagnosticBreadcrumbs": ["boot: started", "session: mirrored"],
            "watchDiagnosticTimestamp": Date().timeIntervalSince1970
        ]

        manager.session(WCSession.default, didReceiveApplicationContext: payload)

        #expect(manager.lastReceivedHeartRate == 142)
        #expect(manager.heartRateSequence == previousSeq + 1)
    }

    @Test func applicationContextWithOnlyBreadcrumbsDoesNotProcess() {
        let manager = WatchConnectivityManager.shared
        let previousSeq = manager.heartRateSequence
        let previousCmdSeq = manager.commandSequence

        // Pure diagnostic payload — no data keys. Should not crash or update state.
        let payload: [String: Any] = [
            "diagnosticBreadcrumbs": ["boot: started"],
            "watchDiagnosticTimestamp": Date().timeIntervalSince1970
        ]

        manager.session(WCSession.default, didReceiveApplicationContext: payload)

        #expect(manager.heartRateSequence == previousSeq)
        #expect(manager.commandSequence == previousCmdSeq)
    }

    @Test func applicationContextWithMotionAndBreadcrumbsProcessesMotion() {
        let manager = WatchConnectivityManager.shared
        let previousSeq = manager.motionUpdateSequence

        // Motion update merged with breadcrumbs — cadence must still be updated.
        let payload: [String: Any] = [
            "command": "motionUpdate",
            "motionMode": "walking",
            "cadence": 118,
            "timestamp": Date().timeIntervalSince1970,
            "diagnosticBreadcrumbs": ["motion: started"]
        ]

        manager.session(WCSession.default, didReceiveApplicationContext: payload)

        #expect(manager.cadence == 118)
        #expect(manager.motionUpdateSequence > previousSeq)
    }

    // MARK: - Mirrored channel helpers

    @Test func mirroredHeartRateIncrementsSequence() {
        let manager = WatchConnectivityManager.shared
        let previousSeq = manager.heartRateSequence

        manager.updateFromMirroredHeartRate(155)

        #expect(manager.lastReceivedHeartRate == 155)
        #expect(manager.heartRateSequence == previousSeq + 1)
    }

    @Test func mirroredMotionDictUpdatesCadence() {
        let manager = WatchConnectivityManager.shared
        let previousSeq = manager.motionUpdateSequence

        let motionDict: [String: Any] = [
            "mode": "walking",
            "cadence": 124,
            "breathingRate": 18.5,
            "posturePitch": 2.1,
            "postureRoll": -0.5
        ]

        manager.updateFromMirroredMotionDict(motionDict)

        #expect(manager.cadence == 124)
        #expect(manager.breathingRate == 18.5)
        #expect(manager.motionUpdateSequence == previousSeq + 1)
    }

    @Test func motionUpdateViaApplicationContext() {
        let manager = WatchConnectivityManager.shared
        let previousSeq = manager.motionUpdateSequence

        // A motion update delivered via applicationContext (no breadcrumbs)
        // should still be processed correctly.
        let payload: [String: Any] = [
            "command": "motionUpdate",
            "motionMode": "walking",
            "cadence": 130,
            "verticalOscillation": 8.2,
            "timestamp": Date().timeIntervalSince1970
        ]

        manager.session(WCSession.default, didReceiveApplicationContext: payload)

        #expect(manager.cadence == 130)
        #expect(manager.motionUpdateSequence > previousSeq)
    }
}
