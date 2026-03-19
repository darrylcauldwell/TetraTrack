//
//  WalkingPlugin.swift
//  TetraTrack
//
//  Walking-specific discipline plugin. Manages cadence tracking,
//  km split announcements, symmetry feedback, and walking HealthKit metrics.

import CoreLocation
import HealthKit
import SwiftData
import Observation
import UIKit
import os

@Observable
@MainActor
final class WalkingPlugin: DisciplinePlugin {
    // MARK: - Identity

    let subscriberId = "walking"
    let activityType: GPSActivityType = .walking
    let watchDiscipline: WatchSessionDiscipline = .walking
    let sharingActivityType = "walking"

    // MARK: - Feature Flags

    let usesGPS = true
    let usesFallDetection = false
    let usesVehicleDetection = false

    // MARK: - HealthKit

    var workoutConfiguration: HKWorkoutConfiguration {
        let config = HKWorkoutConfiguration()
        config.activityType = .walking
        config.locationType = .outdoor
        return config
    }

    // MARK: - Observable Properties

    /// Current cadence from Watch (steps per minute)
    var currentCadence: Int = 0

    /// All cadence readings collected during session
    var cadenceReadings: [Int] = []

    /// Route name if walking a matched route
    var matchedRouteName: String?

    // MARK: - Private State

    /// Km split tracking
    private var lastAnnouncedKm: Int = 0
    private var lastKmSplitTime: TimeInterval = 0

    /// Cadence feedback (every 2 minutes)
    private var lastCadenceAnnouncementMark: Int = 0

    /// Symmetry check (every 5 minutes)
    private var lastSymmetryCheckMark: Int = 0

    /// HealthKit fetch task from onSessionStopping (awaited in onSessionCompleted)
    private var healthKitFetchTask: Task<Void, Never>?

    /// Model context reference for persistence
    private var modelContext: ModelContext?

    /// The session model
    private(set) var session: RunningSession

    /// Selected walking route (if any)
    let selectedRoute: WalkingRoute?

    /// Target cadence for audio feedback
    let targetCadence: Int

    // MARK: - Services

    private let audioCoach = AudioCoachManager.shared
    private let watchManager = WatchConnectivityManager.shared
    private let sensorAnalyzer = WatchSensorAnalyzer.shared

    // MARK: - Init

    init(session: RunningSession, selectedRoute: WalkingRoute?, targetCadence: Int) {
        self.session = session
        self.selectedRoute = selectedRoute
        self.targetCadence = targetCadence
    }

    // MARK: - DisciplinePlugin Protocol

    func createSessionModel(in context: ModelContext) -> any SessionWritable {
        modelContext = context
        session.startDate = Date()

        if let route = selectedRoute {
            session.matchedRouteId = route.id
            matchedRouteName = route.name
        }

        return session
    }

    func createLocationPoint(from location: CLLocation) -> (any PersistentModel)? {
        let point = RunningLocationPoint(from: location)
        point.session = session
        return point
    }

    // MARK: - Voice Notes

    func appendVoiceNote(_ note: String) {
        session.notes = VoiceNotesService.shared.appendNote(note, to: session.notes)
    }

    func onSessionStarted(tracker: SessionTracker) async {
        // Set weather on session model
        tracker.currentWeather.map { session.startWeather = $0 }

        // Reset state
        currentCadence = 0
        cadenceReadings = []
        lastAnnouncedKm = 0
        lastKmSplitTime = 0
        lastCadenceAnnouncementMark = 0
        lastSymmetryCheckMark = 0

        // Start Watch sensor session
        sensorAnalyzer.startSession(discipline: .walking)

        // Audio coach - session start
        audioCoach.announceWalkingSessionStart(routeName: selectedRoute?.name)

        Log.tracking.info("Walking plugin started")
    }

    func onLocationProcessed(_ location: CLLocation, distanceDelta: Double, tracker: SessionTracker) {
        guard tracker.sessionState == .tracking else { return }

        // Km split detection
        let currentKm = Int(tracker.totalDistance / 1000)
        if currentKm > lastAnnouncedKm && currentKm > 0 {
            let splitDuration = tracker.elapsedTime - lastKmSplitTime
            lastAnnouncedKm = currentKm
            lastKmSplitTime = tracker.elapsedTime

            // Create split model
            let split = RunningSplit(orderIndex: currentKm - 1, distance: 1000)
            split.duration = splitDuration
            if tracker.currentHeartRate > 0 { split.heartRate = tracker.currentHeartRate }
            if currentCadence > 0 { split.cadence = currentCadence }
            split.session = session
            if session.splits == nil { session.splits = [] }
            session.splits?.append(split)

            if let ctx = modelContext {
                ctx.insert(split)
            }

            audioCoach.announceWalkingMilestone(
                km: currentKm,
                splitTime: splitDuration,
                totalDistance: tracker.totalDistance,
                cadence: currentCadence
            )

            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            Log.tracking.info("Walking km split \(currentKm): \(Int(splitDuration))s")
        }
    }

    func onTimerTick(elapsedTime: TimeInterval, tracker: SessionTracker) {
        // Update cadence: prefer Watch, fallback to iPhone CMPedometer
        let watchCadence = watchManager.cadence
        let phoneCadence = tracker.pedometerCadence
        let cadence = watchCadence > 0 ? watchCadence : phoneCadence
        if cadence > 0 {
            currentCadence = cadence
            cadenceReadings.append(cadence)
        }

        // Diagnostic: log cadence sources every 10s
        let tenSecMark = Int(elapsedTime) / 10
        if tenSecMark > 0 && Int(elapsedTime) % 10 == 0 {
            let wCad = watchCadence
            let pCad = phoneCadence
            let cCad = currentCadence
            Log.tracking.error("TT: walking cadence watch=\(wCad) phone=\(pCad) current=\(cCad)")
        }

        // Cadence feedback every 2 minutes
        let twoMinMark = Int(elapsedTime) / 120
        if twoMinMark > lastCadenceAnnouncementMark && currentCadence > 0 && targetCadence > 0 {
            lastCadenceAnnouncementMark = twoMinMark
            audioCoach.announceWalkingCadenceFeedback(
                currentCadence: currentCadence,
                targetCadence: targetCadence
            )
        }

        // Symmetry check every 5 minutes
        let fiveMinMark = Int(elapsedTime) / 300
        if fiveMinMark > lastSymmetryCheckMark {
            lastSymmetryCheckMark = fiveMinMark
            let startDate = session.startDate
            Task {
                let healthKit = HealthKitManager.shared
                if let asymmetry = await healthKit.fetchRunningAsymmetry(
                    from: startDate,
                    to: Date()
                ), asymmetry > 10 {
                    await MainActor.run {
                        self.audioCoach.announceWalkingSymmetryAlert(asymmetry: asymmetry)
                    }
                }
            }
        }
    }

    func onSessionStopping(tracker: SessionTracker) -> HealthKitEnrichment {
        // Finalize cadence stats
        if !cadenceReadings.isEmpty {
            session.averageCadence = cadenceReadings.reduce(0, +) / cadenceReadings.count
            session.maxCadence = cadenceReadings.max() ?? 0
        }
        session.targetCadence = targetCadence

        // Write elevation from tracker
        session.totalAscent = tracker.elevationGain
        session.totalDescent = tracker.elevationLoss

        // Write end weather
        tracker.currentWeather.map { session.endWeather = $0 }

        // Write sensor data from WatchSensorAnalyzer
        let runningSummary = sensorAnalyzer.getRunningSummary()
        if runningSummary.averageBreathingRate > 0 {
            session.averageBreathingRate = runningSummary.averageBreathingRate
        }
        if runningSummary.currentSpO2 > 0 {
            session.averageSpO2 = runningSummary.currentSpO2
        }
        if runningSummary.minSpO2 < 100 {
            session.minSpO2 = runningSummary.minSpO2
        }
        session.endFatigueScore = runningSummary.fatigueScore
        session.postureStability = runningSummary.postureStability
        session.trainingLoadScore = runningSummary.trainingLoadScore

        // Training load summary fields
        let trainingLoad = sensorAnalyzer.getTrainingLoadSummary()
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

        sensorAnalyzer.stopSession()

        // Query HealthKit walking metrics and write to session
        let startDate = session.startDate
        let endDate = Date()
        healthKitFetchTask = Task {
            let healthKit = HealthKitManager.shared

            // Fetch walking-specific metrics
            let walkingMetrics = await healthKit.fetchWalkingMetrics(from: startDate, to: endDate)

            // Fetch running metrics (asymmetry, stride length, step count)
            let runningMetrics = await healthKit.fetchRunningMetrics(from: startDate, to: endDate)

            await MainActor.run {
                // Walking-specific HealthKit metrics
                self.session.healthKitDoubleSupportPercentage = walkingMetrics.doubleSupportPercentage
                self.session.healthKitWalkingSpeed = walkingMetrics.walkingSpeed
                self.session.healthKitWalkingStepLength = walkingMetrics.walkingStepLength
                self.session.healthKitWalkingSteadiness = walkingMetrics.walkingSteadiness
                self.session.healthKitWalkingHeartRateAvg = walkingMetrics.walkingHeartRateAverage

                // Running/walking shared metrics
                self.session.healthKitAsymmetry = runningMetrics.asymmetryPercentage
                self.session.healthKitStrideLength = runningMetrics.strideLength
                self.session.healthKitStepCount = runningMetrics.stepCount
                self.session.healthKitPower = runningMetrics.power
                self.session.healthKitSpeed = runningMetrics.speed
                self.session.healthKitHRRecoveryOneMinute = runningMetrics.heartRateRecoveryOneMinute

                // Compute walking biomechanics scores
                if let asymmetry = runningMetrics.asymmetryPercentage {
                    // Symmetry score: 100 = perfect, 0 = very asymmetric
                    self.session.walkingSymmetryScore = max(0, 100 - (asymmetry * 5))
                }

                if !self.cadenceReadings.isEmpty {
                    // Rhythm score from cadence consistency (coefficient of variation)
                    let mean = Double(self.cadenceReadings.reduce(0, +)) / Double(self.cadenceReadings.count)
                    let variance = self.cadenceReadings.reduce(0.0) { $0 + pow(Double($1) - mean, 2) } / Double(self.cadenceReadings.count)
                    let cv = mean > 0 ? sqrt(variance) / mean : 0
                    self.session.walkingCadenceConsistency = cv
                    // Lower CV = better rhythm; CV of 0.05 = score 95
                    self.session.walkingRhythmScore = max(0, min(100, 100 - (cv * 500)))
                }

                if let steadiness = walkingMetrics.walkingSteadiness {
                    self.session.walkingStabilityScore = steadiness
                }

                do {
                    try self.modelContext?.save()
                } catch {
                    Log.tracking.error("Failed to save walking HealthKit metrics: \(error)")
                }
            }
        }

        // Audio coach - session end
        audioCoach.announceWalkingSessionEnd(
            distance: tracker.totalDistance,
            duration: tracker.elapsedTime,
            averageCadence: session.averageCadence
        )

        // Build HealthKit enrichment metadata
        var enrichment = HealthKitEnrichment()
        enrichment.metadata["SessionType"] = "walking"
        enrichment.metadata[HKMetadataKeyIndoorWorkout] = false
        if tracker.elevationGain > 0 {
            enrichment.metadata[HKMetadataKeyElevationAscended] = HKQuantity(
                unit: .meter(), doubleValue: tracker.elevationGain
            )
        }

        // Compute walking analysis scores
        let walkingService = WalkingAnalysisService()
        let walkingScores = walkingService.computeScores(from: session)
        walkingService.applyScores(walkingScores, to: session)

        // Route matching
        if let ctx = modelContext {
            let routeService = RouteMatchingService()
            if let route = selectedRoute {
                if let comparison = routeService.recordAttempt(route: route, session: session, context: ctx) {
                    if let encoded = try? JSONEncoder().encode(comparison) {
                        session.routeComparisonData = encoded
                    }
                }
            } else if (session.locationPoints ?? []).count >= 5 {
                let descriptor = FetchDescriptor<WalkingRoute>()
                let existingRoutes = (try? ctx.fetch(descriptor)) ?? []
                if let matchedRoute = routeService.matchRoute(session: session, existingRoutes: existingRoutes, context: ctx) {
                    if let comparison = routeService.recordAttempt(route: matchedRoute, session: session, context: ctx) {
                        if let encoded = try? JSONEncoder().encode(comparison) {
                            session.routeComparisonData = encoded
                        }
                    }
                }
            }
        }

        // Compute skill domain scores
        if let ctx = modelContext {
            let skillService = SkillDomainService()
            let scores = skillService.computeScores(from: session, score: nil)
            for score in scores {
                ctx.insert(score)
            }
        }

        // Widget sync
        if let ctx = modelContext {
            WidgetDataSyncService.shared.syncRecentSessions(context: ctx)
        }

        Log.tracking.info("Walking plugin stopped")
        return enrichment
    }

    func onSessionCompleted(tracker: SessionTracker) async {
        // Await HealthKit fetch from onSessionStopping before proceeding
        await healthKitFetchTask?.value
        healthKitFetchTask = nil

        // Recompute walking scores after HealthKit data has been written
        await MainActor.run {
            let walkingService = WalkingAnalysisService()
            if session.healthKitAsymmetry != nil || session.healthKitDoubleSupportPercentage != nil {
                let updatedScores = walkingService.computeScores(from: session)
                walkingService.applyScores(updatedScores, to: session)
                try? modelContext?.save()
            }
        }

        // Retry HealthKit metrics that may not have synced yet (Watch-primary mode)
        let needsSteadiness = session.healthKitWalkingSteadiness == nil
        let needsAsymmetry = session.healthKitAsymmetry == nil
        let needsHRRecovery = session.healthKitHRRecoveryOneMinute == nil

        if needsSteadiness || needsAsymmetry || needsHRRecovery, let endDate = session.endDate {
            try? await Task.sleep(for: .seconds(30))
            let healthKit = HealthKitManager.shared
            let startDate = session.startDate

            let walkingMetrics = needsSteadiness
                ? await healthKit.fetchWalkingMetrics(from: startDate, to: endDate)
                : nil
            let runningMetrics = needsAsymmetry
                ? await healthKit.fetchRunningMetrics(from: startDate, to: endDate)
                : nil
            let hrRecovery = needsHRRecovery
                ? await healthKit.fetchHeartRateRecoveryOneMinute(from: startDate, to: endDate)
                : nil

            await MainActor.run {
                var updated = false

                if let walkingMetrics, let steadiness = walkingMetrics.walkingSteadiness {
                    session.healthKitWalkingSteadiness = steadiness
                    session.walkingStabilityScore = steadiness
                    updated = true
                }

                if let runningMetrics, let asymmetry = runningMetrics.asymmetryPercentage {
                    session.healthKitAsymmetry = asymmetry
                    session.walkingSymmetryScore = max(0, 100 - (asymmetry * 5))
                    updated = true
                }

                if let hrRecovery {
                    session.healthKitHRRecoveryOneMinute = hrRecovery
                    updated = true
                }

                if updated {
                    let walkingService = WalkingAnalysisService()
                    let updatedScores = walkingService.computeScores(from: session)
                    walkingService.applyScores(updatedScores, to: session)
                    try? modelContext?.save()
                    Log.tracking.info("Walking HealthKit retry: updated metrics after 30s delay")
                }
            }
        }

        await ArtifactConversionService.shared.convertAndSyncRunningSession(session)
    }

    func onHeartRateUpdate(bpm: Int, tracker: SessionTracker) {
        // Cadence is read from WatchConnectivityManager in onTimerTick;
        // nothing additional needed on HR update for walking.
    }

    func watchStatusFields(tracker: SessionTracker) -> WatchStatusFields {
        var fields = WatchStatusFields()
        fields.rideType = "Walking"
        fields.elevation = tracker.currentElevation
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
        // Walking is always .walk gait type
        speed > 0.3 ? .walk : .stationary
    }
}
