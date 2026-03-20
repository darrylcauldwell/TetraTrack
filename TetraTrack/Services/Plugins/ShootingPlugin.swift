//
//  ShootingPlugin.swift
//  TetraTrack
//
//  Shooting-specific discipline plugin. Manages score entry, Watch sensor data,
//  GRACE analysis, and HealthKit enrichment for shooting sessions.

import CoreLocation
import HealthKit
import SwiftData
import Observation
import UIKit
import TetraTrackShared
import os

@Observable
@MainActor
final class ShootingPlugin: DisciplinePlugin {
    // MARK: - Identity

    let subscriberId = "shooting"
    let activityType: GPSActivityType = .riding // Shooting has no GPS; use a placeholder
    let watchDiscipline: WatchSessionDiscipline = .shooting
    let sharingActivityType = "shooting"

    // MARK: - Feature Flags

    let usesGPS = false
    let usesFallDetection = false
    let usesVehicleDetection = false
    let supportsFamilySharing = false
    let disableAutoCalories = false
    let supportsPause = false
    let supportsAudioCoaching = false
    let supportsVoiceNotes = false

    // MARK: - HealthKit

    var workoutConfiguration: HKWorkoutConfiguration {
        let config = HKWorkoutConfiguration()
        config.activityType = .archery
        config.locationType = .indoor
        return config
    }

    // MARK: - State

    /// The current shooting session model, set after createSessionModel
    private(set) var currentSession: ShootingSession?

    // MARK: - Private State

    /// Model context reference for persistence
    private var modelContext: ModelContext?

    /// Session context (competition, practice, etc.)
    let sessionContext: ShootingSessionContext

    // MARK: - Breathing Monitoring

    /// Current breathing rate from Watch sensor
    private(set) var currentBreathingRate: Double = 0

    /// Timestamp of last breath coaching announcement (throttle)
    private var lastBreathCoachTime: Date?

    // MARK: - Services

    private let watchManager = WatchConnectivityManager.shared
    private let sensorAnalyzer = WatchSensorAnalyzer.shared
    private let audioCoach = AudioCoachManager.shared

    // MARK: - Init

    init(sessionContext: ShootingSessionContext) {
        self.sessionContext = sessionContext
    }

    // MARK: - DisciplinePlugin Protocol

    func createSessionModel(in context: ModelContext) -> any SessionWritable {
        modelContext = context

        let name = sessionContext == .competition ? "Competition" : "Tetrathlon Practice"
        let session = ShootingSession(
            name: name,
            targetType: .olympic,
            distance: 10.0,
            numberOfEnds: 2,
            arrowsPerEnd: 5,
            sessionContext: sessionContext
        )
        session.startDate = Date()

        currentSession = session
        return session
    }

    func createLocationPoint(from location: CLLocation) -> GPSPoint? {
        // Shooting does not track GPS location points
        nil
    }

    func onSessionStarted(tracker: SessionTracker) async {
        sensorAnalyzer.startSession(discipline: .shooting)

        // Weather
        tracker.currentWeather.map { currentSession?.startWeather = $0 }

        Log.tracking.info("Shooting plugin started (context: \(self.sessionContext.rawValue))")
    }

    // MARK: - Timer Tick (Breathing Monitoring)

    func onTimerTick(elapsedTime: TimeInterval, tracker: SessionTracker) {
        let rate = sensorAnalyzer.breathingRate
        guard rate > 0 else { return }
        currentBreathingRate = rate

        // Throttle announcements to every 30 seconds
        if let lastTime = lastBreathCoachTime, Date().timeIntervalSince(lastTime) < 30 { return }

        if rate < 10 {
            // Respiratory pause detected — ideal moment to fire
            audioCoach.announceShootingBreathHoldReady()
            lastBreathCoachTime = Date()
        } else if rate > 16 {
            // Elevated breathing — coach to slow down
            audioCoach.announceShootingBreathingControl()
            lastBreathCoachTime = Date()
        }
    }

    // MARK: - Save Scores

    /// Called by the view when scores are submitted. Creates ends and shots,
    /// wires Watch sensor data, runs GRACE analysis, and persists.
    func saveScores(
        card1Scores: [Int],
        card2Scores: [Int],
        card1ScanID: UUID?,
        card2ScanID: UUID?
    ) {
        guard let session = currentSession else {
            Log.shooting.error("saveScores called with no current session")
            return
        }

        // Create End 1 with shots
        let end1 = ShootingEnd(orderIndex: 0)
        end1.targetScanAnalysisID = card1ScanID
        end1.shots = []
        for (index, score) in card1Scores.enumerated() {
            let shot = Shot(orderIndex: index, score: score, isX: score == 10)
            end1.shots?.append(shot)
        }
        if session.ends == nil { session.ends = [] }
        session.ends?.append(end1)

        // Create End 2 with shots
        let end2 = ShootingEnd(orderIndex: 1)
        end2.targetScanAnalysisID = card2ScanID
        end2.shots = []
        for (index, score) in card2Scores.enumerated() {
            let shot = Shot(orderIndex: index, score: score, isX: score == 10)
            end2.shots?.append(shot)
        }
        session.ends?.append(end2)

        // Wire Watch stance/tremor sensor data
        if watchManager.stanceStability > 0 {
            session.averageStanceStability = watchManager.stanceStability
        }
        if watchManager.tremorLevel > 0 {
            session.averageTremorLevel = watchManager.tremorLevel
        }

        // Apply per-shot sensor data and compute GRACE scores
        let shotMetrics = watchManager.receivedShotMetrics
        if !shotMetrics.isEmpty {
            let allShots = (session.ends ?? []).flatMap { $0.shots ?? [] }
            ShootingSensorAnalyzer.applyShotSensorData(shotMetrics, to: allShots)

            let analysis = ShootingSensorAnalyzer.analyzeSession(
                shotMetrics: shotMetrics,
                sessionStanceStability: session.averageStanceStability,
                averageHeartRate: session.averageHeartRate,
                averageBreathingRate: sensorAnalyzer.breathingRate
            )
            ShootingSensorAnalyzer.applyAnalysis(analysis, to: session)
            watchManager.clearShotMetrics()
        }

        // Persist
        do {
            try modelContext?.save()
        } catch {
            Log.shooting.error("Failed to save shooting scores: \(error)")
        }

        Log.shooting.info("Shooting scores saved: \(session.totalScore)/\(session.maxPossibleScore)")
    }

    // MARK: - Session Stopping

    func onSessionStopping(tracker: SessionTracker) -> HealthKitEnrichment {
        guard let session = currentSession else {
            return HealthKitEnrichment()
        }

        // Read shooting sensor summary
        let shootingSummary = sensorAnalyzer.getShootingSummary()
        session.postureStability = shootingSummary.postureStability

        // Read breathing/SpO2/fatigue (available for all disciplines)
        let trainingLoad = sensorAnalyzer.getTrainingLoadSummary()
        session.averageBreathingRate = sensorAnalyzer.breathingRate
        if sensorAnalyzer.oxygenSaturation > 0 {
            session.averageSpO2 = sensorAnalyzer.oxygenSaturation
        }
        if sensorAnalyzer.minSpO2 < 100 {
            session.minSpO2 = sensorAnalyzer.minSpO2
        }
        session.endFatigueScore = trainingLoad.fatigueScore
        session.trainingLoadScore = trainingLoad.totalLoad
        session.recoveryQuality = trainingLoad.recoveryQuality
        session.averageIntensity = trainingLoad.averageIntensity
        session.breathingRateTrend = trainingLoad.breathingRateTrend
        session.spo2Trend = trainingLoad.spo2Trend

        // Posture and active time from WatchSensorAnalyzer
        let totalPostureTime = sensorAnalyzer.goodPostureTime + sensorAnalyzer.poorPostureTime
        if totalPostureTime > 0 {
            session.goodPosturePercent = (sensorAnalyzer.goodPostureTime / totalPostureTime) * 100
        }
        let totalActivePassive = sensorAnalyzer.activeTime + sensorAnalyzer.passiveTime
        if totalActivePassive > 0 {
            session.activeTimePercent = (sensorAnalyzer.activeTime / totalActivePassive) * 100
        }

        // Weather
        tracker.currentWeather.map { session.endWeather = $0 }

        sensorAnalyzer.stopSession()

        var enrichment = HealthKitEnrichment()

        // Build segment events for each shooting end (split session duration in half)
        let endDate = Date()
        let sessionDuration = endDate.timeIntervalSince(session.startDate)
        let halfDuration = sessionDuration / 2

        // End 1 segment
        let end1Start = session.startDate
        let end1End = session.startDate.addingTimeInterval(halfDuration)
        let card1Scores = session.sortedEnds.first.map { end in
            (end.shots ?? []).sorted { $0.orderIndex < $1.orderIndex }
        } ?? []
        let card1Total = card1Scores.reduce(0) { $0 + $1.score }
        let card1XCount = card1Scores.filter { $0.isX }.count

        enrichment.workoutEvents.append(
            HKWorkoutEvent(
                type: .segment,
                dateInterval: DateInterval(start: end1Start, end: end1End),
                metadata: [
                    "EndIndex": 1,
                    "EndScore": card1Total,
                    "XCount": card1XCount
                ]
            )
        )

        // End 2 segment
        let end2Start = end1End
        let end2End = endDate
        let card2Scores = session.sortedEnds.dropFirst().first.map { end in
            (end.shots ?? []).sorted { $0.orderIndex < $1.orderIndex }
        } ?? []
        let card2Total = card2Scores.reduce(0) { $0 + $1.score }
        let card2XCount = card2Scores.filter { $0.isX }.count

        enrichment.workoutEvents.append(
            HKWorkoutEvent(
                type: .segment,
                dateInterval: DateInterval(start: end2Start, end: end2End),
                metadata: [
                    "EndIndex": 2,
                    "EndScore": card2Total,
                    "XCount": card2XCount
                ]
            )
        )

        // Build metadata
        let totalScore = session.totalScore
        let maxPossible = session.maxPossibleScore
        let scorePercentage = maxPossible > 0 ? Double(totalScore) / Double(maxPossible) : 0
        let tetrathlonPoints = totalScore * 10

        enrichment.metadata["TotalScore"] = totalScore
        enrichment.metadata["MaxPossibleScore"] = maxPossible
        enrichment.metadata["ScorePercentage"] = scorePercentage
        enrichment.metadata["TetrathlonPoints"] = tetrathlonPoints
        enrichment.metadata["SessionContext"] = sessionContext.rawValue
        enrichment.metadata["XCount"] = session.xCount

        if session.averageStanceStability > 0 {
            enrichment.metadata["StanceStability"] = session.averageStanceStability
        }
        if session.averageTremorLevel > 0 {
            enrichment.metadata["TremorLevel"] = session.averageTremorLevel
        }
        if session.averageBreathingRate > 0 {
            enrichment.metadata["BreathingRate"] = session.averageBreathingRate
        }
        if session.averageSpO2 > 0 {
            enrichment.metadata["SpO2"] = session.averageSpO2
        }
        if session.recoveryQuality > 0 {
            enrichment.metadata["RecoveryQuality"] = session.recoveryQuality
        }
        if session.averageIntensity > 0 {
            enrichment.metadata["AverageIntensity"] = session.averageIntensity
        }

        // Compute skill domain scores
        if let ctx = modelContext {
            let skillService = SkillDomainService()
            let scores = skillService.computeScores(from: session)
            for score in scores {
                ctx.insert(score)
            }
            // save() removed — SessionTracker.stopSession() owns the final save
        }

        Log.tracking.info("Shooting plugin stopped")
        return enrichment
    }

    // MARK: - Session Completed

    func onSessionCompleted(tracker: SessionTracker) async {
        guard let session = currentSession else { return }

        // Sync to widgets
        if let ctx = modelContext {
            WidgetDataSyncService.shared.syncRecentSessions(context: ctx)
        }

        // Convert to training artifact
        await ArtifactConversionService.shared.convertAndSyncShootingSession(session)

        // Update personal best
        ShootingPersonalBests.shared.updatePersonalBest(rawScore: session.totalScore)

        Log.tracking.info("Shooting session completed: \(session.totalScore) points")
    }

    // MARK: - Watch

    func watchStatusFields(tracker: SessionTracker) -> WatchStatusFields {
        var fields = WatchStatusFields()
        fields.rideType = "Shooting"
        return fields
    }

    func handleWatchCommand(_ command: WatchCommand, tracker: SessionTracker) {
        switch command {
        case .startRide:
            Task {
                await tracker.startSession(plugin: self)
            }
        case .stopRide:
            tracker.stopSession()
        case .pauseRide:
            tracker.pauseSession()
        case .resumeRide:
            tracker.resumeSession()
        default:
            break
        }
    }

    func currentGaitType(speed: Double) -> GaitType {
        // Shooting is stationary
        .stationary
    }
}
