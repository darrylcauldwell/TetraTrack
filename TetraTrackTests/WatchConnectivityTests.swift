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

    // MARK: - Reliable command transport (#268)

    @Test func sendReliableCommandMethodExists() {
        // sendReliableCommand with nil session should early-return without crash
        let manager = WatchConnectivityManager.shared
        manager.sendReliableCommand(.stopRide)
        // No crash = pass. Session is nil so it skips the send.
    }

    @Test func stopRideViaUserInfoUpdatesCommandSequence() {
        let manager = WatchConnectivityManager.shared
        let previousSeq = manager.commandSequence

        // Simulate stopRide arriving via transferUserInfo (the reliable path)
        let payload: [String: Any] = [
            "command": "stopRide",
            "timestamp": Date().timeIntervalSince1970
        ]

        manager.session(WCSession.default, didReceiveUserInfo: payload)

        #expect(manager.lastReceivedCommand == .stopRide)
        #expect(manager.commandSequence == previousSeq + 1)
    }

    @Test func pauseRideViaUserInfoUpdatesCommandSequence() {
        let manager = WatchConnectivityManager.shared
        let previousSeq = manager.commandSequence

        let payload: [String: Any] = [
            "command": "pauseRide",
            "timestamp": Date().timeIntervalSince1970
        ]

        manager.session(WCSession.default, didReceiveUserInfo: payload)

        #expect(manager.lastReceivedCommand == .pauseRide)
        #expect(manager.commandSequence == previousSeq + 1)
    }

    @Test func resumeRideViaUserInfoUpdatesCommandSequence() {
        let manager = WatchConnectivityManager.shared
        let previousSeq = manager.commandSequence

        let payload: [String: Any] = [
            "command": "resumeRide",
            "timestamp": Date().timeIntervalSince1970
        ]

        manager.session(WCSession.default, didReceiveUserInfo: payload)

        #expect(manager.lastReceivedCommand == .resumeRide)
        #expect(manager.commandSequence == previousSeq + 1)
    }

    @Test func mirroredMotionDictWithWalkingMode() {
        let manager = WatchConnectivityManager.shared

        let motionDict: [String: Any] = [
            "mode": "walking",
            "cadence": 112,
            "breathingRate": 20.0,
            "groundContactTime": 245.0
        ]

        manager.updateFromMirroredMotionDict(motionDict)

        #expect(manager.cadence == 112)
        #expect(manager.breathingRate == 20.0)
        #expect(manager.groundContactTime == 245.0)
    }

    @Test func mirroredHeartRateWithWalkingValues() {
        let manager = WatchConnectivityManager.shared
        let previousSeq = manager.heartRateSequence

        // Walking HR range (typically 90-140 bpm)
        manager.updateFromMirroredHeartRate(118)

        #expect(manager.lastReceivedHeartRate == 118)
        #expect(manager.heartRateSequence == previousSeq + 1)
    }

    @Test func stopRideViaApplicationContextNotClobberedByStatusUpdate() {
        let manager = WatchConnectivityManager.shared

        // First: deliver stopRide via userInfo (transferUserInfo path)
        let stopPayload: [String: Any] = [
            "command": "stopRide",
            "timestamp": Date().timeIntervalSince1970
        ]
        manager.session(WCSession.default, didReceiveUserInfo: stopPayload)
        #expect(manager.lastReceivedCommand == .stopRide)
        let seqAfterStop = manager.commandSequence

        // Second: a status update arrives via applicationContext (1Hz timer).
        // This must NOT change lastReceivedCommand back from .stopRide.
        let statusPayload: [String: Any] = [
            "rideState": "tracking",
            "duration": 120.0,
            "distance": 500.0,
            "speed": 4.2,
            "gait": "Walk",
            "timestamp": Date().timeIntervalSince1970
        ]
        manager.session(WCSession.default, didReceiveApplicationContext: statusPayload)

        // Command sequence should not have changed (status updates have no command key)
        #expect(manager.commandSequence == seqAfterStop)
        #expect(manager.lastReceivedCommand == .stopRide)
    }
}
