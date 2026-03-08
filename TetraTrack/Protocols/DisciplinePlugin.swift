//
//  DisciplinePlugin.swift
//  TetraTrack
//
//  Protocol for discipline-specific session logic.
//  Each discipline (riding, running, swimming, walking) provides a plugin
//  that the SessionTracker calls at appropriate lifecycle points.
//

import CoreLocation
import HealthKit
import SwiftData

@MainActor
protocol DisciplinePlugin: AnyObject {
    /// Which discipline this plugin handles
    var discipline: Discipline { get }

    /// Whether the session needs GPS location updates
    var needsGPS: Bool { get }

    /// Whether the session needs CoreMotion updates
    var needsMotion: Bool { get }

    /// HealthKit workout configuration for this session
    var workoutConfig: HKWorkoutConfiguration { get }

    // MARK: - Lifecycle

    /// Called once when the session starts, before GPS/timer begin.
    /// Use to create the session model, configure analyzers, etc.
    func configure(tracker: SessionTracker) async

    /// Called after all common services (GPS, timer, HealthKit) have started.
    func didStart() async

    /// Called just before the session pauses.
    func willPause()

    /// Called after the session resumes from pause.
    func didResume()

    /// Called when the session stops. Finalize analyzer data and write to the model.
    func finalize() async

    /// Reset all plugin state for a fresh session.
    func reset()

    // MARK: - Data Processing

    /// Process a filtered GPS location from GPSSessionTracker.
    func processLocation(_ location: CLLocation, distanceDelta: Double)

    /// Process a CoreMotion sample from MotionManager.
    func processMotion(_ sample: MotionSample)

    /// Process a heart rate reading from Watch.
    func processHeartRate(_ bpm: Int)

    /// Process Watch motion data (cadence, oscillation, etc.) via WatchSensorAnalyzer.
    func processWatchMotion()

    /// Called every timer tick (1Hz).
    func timerTick(elapsed: TimeInterval)

    // MARK: - Persistence

    /// Create and insert a discipline-specific location point.
    func persistLocationPoint(_ location: CLLocation, in context: ModelContext)

    // MARK: - HealthKit Integration

    /// Build discipline-specific HealthKit enrichment data for the workout.
    func buildHealthKitEnrichment() async -> (events: [HKWorkoutEvent], samples: [HKSample], metadata: [String: Any])

    // MARK: - Watch Communication

    /// Build discipline-specific data for Watch status updates.
    func watchStatusPayload() -> [String: Any]
}

// MARK: - Default implementations for optional hooks

extension DisciplinePlugin {
    func processMotion(_ sample: MotionSample) {}
    func processHeartRate(_ bpm: Int) {}
    func processWatchMotion() {}
    func willPause() {}
    func didResume() {}
}
