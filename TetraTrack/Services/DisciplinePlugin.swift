//
//  DisciplinePlugin.swift
//  TetraTrack
//
//  Protocol for discipline-specific session behavior.
//  SessionTracker manages common session concerns; plugins provide discipline logic.

import CoreLocation
import HealthKit
import SwiftData

// MARK: - Supporting Types

/// HealthKit enrichment data returned by a plugin when stopping a session
struct HealthKitEnrichment {
    var workoutEvents: [HKWorkoutEvent] = []
    var calorieSamples: [HKSample] = []
    var metadata: [String: Any] = [:]
}

/// Discipline-specific fields sent to Watch alongside common status
struct WatchStatusFields {
    var walkPercent: Double?
    var trotPercent: Double?
    var canterPercent: Double?
    var gallopPercent: Double?
    var leftReinPercent: Double?
    var rightReinPercent: Double?
    var leftLeadPercent: Double?
    var rightLeadPercent: Double?
    var symmetryScore: Double?
    var rhythmScore: Double?
    var optimalTime: TimeInterval?
    var timeDifference: TimeInterval?
    var elevation: Double?
    var horseName: String?
    var rideType: String?
}

// MARK: - DisciplinePlugin Protocol

@MainActor
protocol DisciplinePlugin: AnyObject {
    // MARK: - Identity

    /// Unique subscriber ID for GPS session (e.g. "ride", "run", "walk", "swim")
    var subscriberId: String { get }

    /// GPS activity type for filter configuration
    var activityType: GPSActivityType { get }

    /// Discipline for Watch session management
    var watchDiscipline: WatchSessionDiscipline { get }

    /// Activity type string for family sharing
    var sharingActivityType: String { get }

    // MARK: - Feature Flags (defaults via extension)

    /// Whether this discipline uses GPS tracking
    var usesGPS: Bool { get }

    /// Whether fall detection should be enabled
    var usesFallDetection: Bool { get }

    /// Whether vehicle speed detection should be enabled
    var usesVehicleDetection: Bool { get }

    /// Whether family sharing is supported
    var supportsFamilySharing: Bool { get }

    /// Whether auto calorie collection should be disabled (plugin provides its own)
    var disableAutoCalories: Bool { get }

    // MARK: - HealthKit

    /// Workout configuration for HealthKit session
    var workoutConfiguration: HKWorkoutConfiguration { get }

    // MARK: - Session Model

    /// Create the discipline-specific session model (e.g. Ride, RunningSession)
    func createSessionModel(in context: ModelContext) -> any PersistentModel

    /// Create a location point for GPS persistence
    func createLocationPoint(from location: CLLocation) -> (any PersistentModel)?

    // MARK: - Lifecycle Hooks

    /// Called after session starts and all infrastructure is ready
    func onSessionStarted(tracker: SessionTracker) async

    /// Called when session is paused
    func onSessionPaused(tracker: SessionTracker)

    /// Called when session resumes from pause
    func onSessionResumed(tracker: SessionTracker)

    /// Called when session is stopping — return HealthKit enrichment data
    func onSessionStopping(tracker: SessionTracker) -> HealthKitEnrichment

    /// Called after session stop is finalized (model saved, HealthKit ended)
    func onSessionCompleted(tracker: SessionTracker) async

    /// Called when session is discarded
    func onSessionDiscarded(tracker: SessionTracker)

    // MARK: - Per-Tick and Data Hooks

    /// Called after each filtered GPS location is processed
    func onLocationProcessed(_ location: CLLocation, distanceDelta: Double, tracker: SessionTracker)

    /// Called every 1s timer tick
    func onTimerTick(elapsedTime: TimeInterval, tracker: SessionTracker)

    /// Called when heart rate is updated from Watch or WorkoutLifecycle
    func onHeartRateUpdate(bpm: Int, tracker: SessionTracker)

    // MARK: - Watch

    /// Return discipline-specific Watch status fields
    func watchStatusFields(tracker: SessionTracker) -> WatchStatusFields

    /// Handle a Watch command
    func handleWatchCommand(_ command: WatchCommand, tracker: SessionTracker)

    // MARK: - Family Sharing

    /// Return current gait type for family sharing location updates
    func currentGaitType(speed: Double) -> GaitType
}

// MARK: - Default Implementations

extension DisciplinePlugin {
    var usesGPS: Bool { true }
    var usesFallDetection: Bool { false }
    var usesVehicleDetection: Bool { false }
    var supportsFamilySharing: Bool { true }
    var disableAutoCalories: Bool { false }

    func onSessionStarted(tracker: SessionTracker) async {}
    func onSessionPaused(tracker: SessionTracker) {}
    func onSessionResumed(tracker: SessionTracker) {}
    func onSessionStopping(tracker: SessionTracker) -> HealthKitEnrichment { HealthKitEnrichment() }
    func onSessionCompleted(tracker: SessionTracker) async {}
    func onSessionDiscarded(tracker: SessionTracker) {}

    func onLocationProcessed(_ location: CLLocation, distanceDelta: Double, tracker: SessionTracker) {}
    func onTimerTick(elapsedTime: TimeInterval, tracker: SessionTracker) {}
    func onHeartRateUpdate(bpm: Int, tracker: SessionTracker) {}

    func watchStatusFields(tracker: SessionTracker) -> WatchStatusFields { WatchStatusFields() }
    func handleWatchCommand(_ command: WatchCommand, tracker: SessionTracker) {}

    func currentGaitType(speed: Double) -> GaitType { .stationary }
}
