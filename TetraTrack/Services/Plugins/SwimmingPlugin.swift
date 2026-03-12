//
//  SwimmingPlugin.swift
//  TetraTrack
//
//  Swimming-specific discipline plugin. Manages length counting,
//  stroke tracking, interval training, and swimming HealthKit metrics.

import CoreLocation
import HealthKit
import SwiftData
import Observation
import UIKit
import os

@Observable
@MainActor
final class SwimmingPlugin: DisciplinePlugin {
    // MARK: - Identity

    let subscriberId = "swimming"
    let activityType: GPSActivityType = .swimming
    let watchDiscipline: WatchSessionDiscipline = .swimming
    let sharingActivityType = "swimming"

    // MARK: - Feature Flags

    /// Open water uses GPS; pool does not
    var usesGPS: Bool { !isPoolMode }
    let usesFallDetection = false
    let usesVehicleDetection = false
    let supportsFamilySharing = false

    // MARK: - HealthKit

    var workoutConfiguration: HKWorkoutConfiguration {
        let config = HKWorkoutConfiguration()
        config.activityType = .swimming
        if isPoolMode {
            config.locationType = .indoor
            config.swimmingLocationType = .pool
            config.lapLength = HKQuantity(unit: .meter(), doubleValue: session.poolLength)
        } else {
            config.locationType = .outdoor
            config.swimmingLocationType = .openWater
        }
        return config
    }

    // MARK: - Observable Properties

    /// Number of completed pool lengths
    var completedLengths: Int = 0

    /// Currently selected stroke type
    var currentStroke: SwimmingStroke = .freestyle

    /// Per-length stroke counts (index-aligned with lengthTimes)
    var lengthStrokes: [Int] = []

    /// Per-length durations in seconds (index-aligned with lengthStrokes)
    var lengthTimes: [TimeInterval] = []

    /// Per-length stroke types (index-aligned with lengthStrokes)
    var lengthStrokeTypes: [SwimmingStroke] = []

    /// Current stroke count from Watch
    var strokeCount: Int = 0

    /// Current stroke rate from Watch (strokes per minute)
    var strokeRate: Double = 0.0

    /// Whether the timed test is complete
    var testComplete: Bool = false

    /// Whether currently in a rest period (interval mode)
    var isResting: Bool = false

    /// Remaining rest time in seconds
    var restTimeRemaining: TimeInterval = 0

    /// Current interval index (0-based)
    var currentIntervalIndex: Int = 0

    // MARK: - Private State

    /// Model context reference for persistence
    private var modelContext: ModelContext?

    /// The session model
    private(set) var session: SwimmingSession

    /// Interval training settings (nil = free swim or timed test)
    let intervalSettings: SwimmingIntervalSettings?

    /// Whether this is a timed test (3-minute test or similar)
    let isThreeMinuteTest: Bool

    /// Test duration for timed tests (default 180s for 3-minute test)
    let testDuration: TimeInterval

    /// Optional target duration for free swim sessions
    let freeSwimTargetDuration: TimeInterval?

    /// Elapsed time at the start of the last length (for per-length timing)
    private var lastLengthTime: TimeInterval = 0

    /// Stroke count at the start of the last length (for per-length stroke counts)
    private var lastLengthStrokeCount: Int = 0

    /// Elapsed time when the current interval started
    private var intervalStartTime: TimeInterval = 0

    /// Length count when the current interval started
    private var intervalStartLengthCount: Int = 0

    /// Recorded interval data for session finalization
    private var intervalData: [(distance: Double, duration: TimeInterval, strokes: Int)] = []

    /// Rest timer for interval mode
    private var restTimer: Timer?

    // MARK: - Computed Properties

    var isPoolMode: Bool {
        session.poolMode == .pool
    }

    /// Pool length from the session model
    var poolLength: Double {
        session.poolLength
    }

    var isIntervalMode: Bool {
        intervalSettings != nil
    }

    var distanceInCurrentInterval: Double {
        Double(completedLengths - intervalStartLengthCount) * session.poolLength
    }

    private var intervalTargetReached: Bool {
        guard let settings = intervalSettings else { return false }
        return distanceInCurrentInterval >= settings.targetDistance
    }

    var allIntervalsComplete: Bool {
        guard let settings = intervalSettings else { return false }
        return currentIntervalIndex >= settings.numberOfIntervals
    }

    /// Average SWOLF across all lengths with valid data
    var averageSWOLF: Double {
        let swolfScores = zip(lengthStrokes, lengthTimes)
            .filter { $0.0 > 0 && $0.1 > 0 }
            .map { Double($0) + $1 }
        guard !swolfScores.isEmpty else { return 0 }
        return swolfScores.reduce(0, +) / Double(swolfScores.count)
    }

    // MARK: - Services

    private let watchManager = WatchConnectivityManager.shared
    private let sensorAnalyzer = WatchSensorAnalyzer.shared

    // MARK: - Init

    init(
        session: SwimmingSession,
        intervalSettings: SwimmingIntervalSettings? = nil,
        isThreeMinuteTest: Bool = false,
        testDuration: TimeInterval = 180,
        freeSwimTargetDuration: TimeInterval? = nil
    ) {
        self.session = session
        self.intervalSettings = intervalSettings
        self.isThreeMinuteTest = isThreeMinuteTest
        self.testDuration = testDuration
        self.freeSwimTargetDuration = freeSwimTargetDuration
    }

    // MARK: - DisciplinePlugin Protocol

    func createSessionModel(in context: ModelContext) -> any SessionWritable {
        modelContext = context
        session.startDate = Date()
        return session
    }

    func createLocationPoint(from location: CLLocation) -> (any PersistentModel)? {
        // Only create location points for open water swimming
        guard !isPoolMode else { return nil }
        let point = SwimmingLocationPoint(from: location)
        point.session = session
        return point
    }

    func onSessionStarted(tracker: SessionTracker) async {
        // Reset state
        completedLengths = 0
        currentStroke = .freestyle
        lengthStrokes = []
        lengthTimes = []
        lengthStrokeTypes = []
        strokeCount = 0
        strokeRate = 0.0
        testComplete = false
        isResting = false
        restTimeRemaining = 0
        currentIntervalIndex = 0
        lastLengthTime = 0
        lastLengthStrokeCount = 0
        intervalStartTime = 0
        intervalStartLengthCount = 0
        intervalData = []

        // Start swimming sensor analysis and Watch motion tracking
        watchManager.resetMotionMetrics()
        sensorAnalyzer.startSession(discipline: .swimming)

        // Weather
        tracker.currentWeather.map { session.startWeather = $0 }

        Log.tracking.info("Swimming plugin started (pool mode: \(self.isPoolMode))")
    }

    func onLocationProcessed(_ location: CLLocation, distanceDelta: Double, tracker: SessionTracker) {
        // Open water: distance is tracked by SessionTracker via GPS
        // No per-location logic needed beyond what SessionTracker provides
    }

    func onTimerTick(elapsedTime: TimeInterval, tracker: SessionTracker) {
        // Update stroke data from Watch
        let watchStrokes = watchManager.strokeCount
        if watchStrokes > 0 {
            strokeCount = watchStrokes
        }
        let watchRate = watchManager.strokeRate
        if watchRate > 0 {
            strokeRate = watchRate
        }

        // Timed test completion
        if isThreeMinuteTest {
            let previousElapsed = elapsedTime - 1
            let remaining = testDuration - elapsedTime
            let previousRemaining = testDuration - previousElapsed

            // Minute milestone haptic
            if Int(elapsedTime) / 60 > Int(max(0, previousElapsed)) / 60 && remaining > 0 {
                watchManager.sendCommand(.hapticMilestone)
            }
            // 10-second warning
            if previousRemaining > 10 && remaining <= 10 {
                watchManager.sendCommand(.hapticUrgent)
            }
            // Test complete
            if elapsedTime >= testDuration && !testComplete {
                testComplete = true
                watchManager.sendCommand(.hapticComplete)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        } else if let target = freeSwimTargetDuration, !isIntervalMode {
            // Free swim with target: 5-min milestones, 1-min warning, completion
            let previousElapsed = elapsedTime - 1
            let remaining = target - elapsedTime
            let previousRemaining = target - previousElapsed

            // 5-minute milestone
            if Int(elapsedTime) / 300 > Int(max(0, previousElapsed)) / 300 && remaining > 0 {
                watchManager.sendCommand(.hapticMilestone)
            }
            // 1-minute warning
            if previousRemaining > 60 && remaining <= 60 {
                watchManager.sendCommand(.hapticUrgent)
            }
            // Target reached
            if elapsedTime >= target && !testComplete {
                testComplete = true
                watchManager.sendCommand(.hapticComplete)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        } else if !isIntervalMode {
            // Free swim without target: milestone every 10 minutes
            let previousElapsed = elapsedTime - 1
            if Int(elapsedTime) / 600 > Int(max(0, previousElapsed)) / 600 {
                watchManager.sendCommand(.hapticMilestone)
            }
        }
    }

    func onSessionStopping(tracker: SessionTracker) -> HealthKitEnrichment {
        // Stop sensor analysis and Watch motion tracking
        watchManager.stopMotionTracking()
        sensorAnalyzer.stopSession()

        // Invalidate rest timer
        restTimer?.invalidate()
        restTimer = nil

        // Compute total distance
        if isPoolMode {
            session.totalDistance = Double(completedLengths) * session.poolLength
        } else {
            session.totalDistance = tracker.totalDistance
        }
        session.totalDuration = tracker.elapsedTime
        session.totalStrokes = strokeCount

        // Create SwimmingLap objects from tracked data (pool mode)
        if isPoolMode {
            let lapCount = min(lengthTimes.count, completedLengths)
            if lapCount > 0 {
                if session.laps == nil { session.laps = [] }
                for i in 0..<lapCount {
                    let lap = SwimmingLap(orderIndex: i, distance: session.poolLength)
                    lap.duration = lengthTimes[i]
                    if i < lengthStrokes.count {
                        lap.strokeCount = lengthStrokes[i]
                    }
                    if i < lengthStrokeTypes.count {
                        lap.stroke = lengthStrokeTypes[i]
                    }
                    let precedingTime = lengthTimes.prefix(i).reduce(0, +)
                    lap.startTime = session.startDate.addingTimeInterval(precedingTime)
                    lap.endTime = lap.startTime.addingTimeInterval(lengthTimes[i])
                    session.laps?.append(lap)
                }
            }
        }

        // Create SwimmingInterval objects
        if isIntervalMode, let settings = intervalSettings, !intervalData.isEmpty {
            if session.intervals == nil { session.intervals = [] }
            for (index, data) in intervalData.enumerated() {
                let interval = SwimmingInterval(
                    orderIndex: index,
                    name: "Interval \(index + 1)",
                    targetDistance: settings.targetDistance,
                    targetPace: settings.targetPace,
                    restDuration: settings.restDuration
                )
                interval.actualDistance = data.distance
                interval.actualDuration = data.duration
                interval.actualStrokes = data.strokes
                interval.isCompleted = true
                session.intervals?.append(interval)
            }
        }

        // Write sensor metrics from WatchSensorAnalyzer
        let swimmingSummary = sensorAnalyzer.getSwimmingSummary()
        if swimmingSummary.totalSubmergedTime > 0 {
            session.totalSubmergedTime = swimmingSummary.totalSubmergedTime
        }
        if swimmingSummary.submersionCount > 0 {
            session.submersionCount = swimmingSummary.submersionCount
        }
        if swimmingSummary.currentSpO2 > 0 {
            session.averageSpO2 = swimmingSummary.currentSpO2
        }
        if swimmingSummary.minSpO2 < 100 {
            session.minSpO2 = swimmingSummary.minSpO2
        }
        session.recoveryQuality = swimmingSummary.recoveryQuality
        if sensorAnalyzer.breathingRate > 0 {
            session.averageBreathingRate = sensorAnalyzer.breathingRate
        }

        // Training load and fatigue (available for all disciplines)
        let trainingLoad = sensorAnalyzer.getTrainingLoadSummary()
        session.endFatigueScore = trainingLoad.fatigueScore
        session.trainingLoadScore = trainingLoad.totalLoad
        session.averageIntensity = trainingLoad.averageIntensity
        session.breathingRateTrend = trainingLoad.breathingRateTrend
        session.spo2Trend = trainingLoad.spo2Trend

        // Active time percent
        let totalActivePassive = sensorAnalyzer.activeTime + sensorAnalyzer.passiveTime
        if totalActivePassive > 0 {
            session.activeTimePercent = (sensorAnalyzer.activeTime / totalActivePassive) * 100
        }

        // Weather
        tracker.currentWeather.map { session.endWeather = $0 }

        // Build HealthKit enrichment
        var enrichment = HealthKitEnrichment()
        var hkEvents: [HKWorkoutEvent] = []
        var hkSamples: [HKSample] = []
        let sessionStart = session.startDate

        // Per-lap events and samples (pool mode)
        if isPoolMode {
            let lapCount = min(lengthTimes.count, completedLengths)
            var cumulativeTime: TimeInterval = 0
            for i in 0..<lapCount {
                let lapStart = sessionStart.addingTimeInterval(cumulativeTime)
                let lapEnd = lapStart.addingTimeInterval(lengthTimes[i])
                let interval = DateInterval(start: lapStart, end: lapEnd)

                var lapMeta: [String: Any] = ["LapIndex": i + 1]
                if i < lengthStrokes.count {
                    lapMeta["StrokeCount"] = lengthStrokes[i]
                    lapMeta["SWOLF"] = Double(lengthStrokes[i]) + lengthTimes[i]
                }
                if i < lengthStrokeTypes.count {
                    lapMeta["StrokeType"] = lengthStrokeTypes[i].rawValue
                }

                hkEvents.append(HKWorkoutEvent(type: .lap, dateInterval: interval, metadata: lapMeta))

                // Stroke count sample per lap
                if i < lengthStrokes.count, lengthStrokes[i] > 0 {
                    hkSamples.append(HKQuantitySample(
                        type: HKQuantityType(.swimmingStrokeCount),
                        quantity: HKQuantity(unit: .count(), doubleValue: Double(lengthStrokes[i])),
                        start: lapStart,
                        end: lapEnd
                    ))
                }

                // Distance sample per lap
                hkSamples.append(HKQuantitySample(
                    type: HKQuantityType(.distanceSwimming),
                    quantity: HKQuantity(unit: .meter(), doubleValue: session.poolLength),
                    start: lapStart,
                    end: lapEnd
                ))

                cumulativeTime += lengthTimes[i]
            }
        }

        // Interval segment events
        if !intervalData.isEmpty {
            var intervalStart = sessionStart
            for (index, data) in intervalData.enumerated() {
                let intervalEnd = intervalStart.addingTimeInterval(data.duration)
                let dateInterval = DateInterval(start: intervalStart, end: intervalEnd)
                hkEvents.append(HKWorkoutEvent(type: .segment, dateInterval: dateInterval, metadata: [
                    "IntervalIndex": index + 1,
                    "Distance": data.distance,
                    "Strokes": data.strokes
                ]))
                intervalStart = intervalEnd
            }
        }

        // SpO2 sample
        if sensorAnalyzer.oxygenSaturation > 0 && sensorAnalyzer.oxygenSaturation <= 100 {
            hkSamples.append(HKQuantitySample(
                type: HKQuantityType(.oxygenSaturation),
                quantity: HKQuantity(unit: .percent(), doubleValue: sensorAnalyzer.oxygenSaturation / 100.0),
                start: sessionStart,
                end: Date()
            ))
        }

        // Breathing rate sample
        if sensorAnalyzer.breathingRate > 0 {
            hkSamples.append(HKQuantitySample(
                type: HKQuantityType(.respiratoryRate),
                quantity: HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()), doubleValue: sensorAnalyzer.breathingRate),
                start: sessionStart,
                end: Date()
            ))
        }

        // Swimming metadata
        enrichment.metadata[HKMetadataKeySwimmingLocationType] = isPoolMode
            ? NSNumber(value: HKWorkoutSwimmingLocationType.pool.rawValue)
            : NSNumber(value: HKWorkoutSwimmingLocationType.openWater.rawValue)
        if isPoolMode {
            enrichment.metadata[HKMetadataKeyLapLength] = HKQuantity(unit: .meter(), doubleValue: session.poolLength)
        }
        if strokeCount > 0 {
            enrichment.metadata["TotalStrokes"] = strokeCount
        }
        if averageSWOLF > 0 {
            enrichment.metadata["AverageSWOLF"] = averageSWOLF
        }
        if !lengthStrokeTypes.isEmpty {
            let strokeCounts = Dictionary(grouping: lengthStrokeTypes, by: { $0 }).mapValues { $0.count }
            if let dominant = strokeCounts.max(by: { $0.value < $1.value }) {
                enrichment.metadata["DominantStroke"] = dominant.key.rawValue
            }
        }

        if !hkEvents.isEmpty { enrichment.workoutEvents = hkEvents }
        if !hkSamples.isEmpty { enrichment.calorieSamples = hkSamples }

        // Update swimming personal bests (timed tests)
        if isThreeMinuteTest && session.totalDistance > 0 {
            var pbs = SwimmingPersonalBests.shared
            pbs.updateThresholdPace(
                from: session.totalDistance,
                testDuration: testDuration
            )
            pbs.updatePersonalBest(
                distance: session.totalDistance,
                time: session.totalDuration
            )
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

        Log.tracking.info("Swimming plugin stopped — \(self.completedLengths) lengths, \(self.strokeCount) strokes")
        return enrichment
    }

    func onSessionCompleted(tracker: SessionTracker) async {
        await ArtifactConversionService.shared.convertAndSyncSwimmingSession(session)
    }

    func onHeartRateUpdate(bpm: Int, tracker: SessionTracker) {
        // Heart rate is managed by SessionTracker; no swimming-specific handling needed
    }

    func watchStatusFields(tracker: SessionTracker) -> WatchStatusFields {
        var fields = WatchStatusFields()
        fields.rideType = "Swimming"
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

    func onSessionDiscarded(tracker: SessionTracker) {
        // Stop sensor analysis and Watch motion tracking
        watchManager.stopMotionTracking()
        sensorAnalyzer.stopSession()

        // Invalidate rest timer
        restTimer?.invalidate()
        restTimer = nil
    }

    func currentGaitType(speed: Double) -> GaitType {
        // Swimming does not use gait classification
        .stationary
    }

    // MARK: - Public Methods (called by view)

    /// Record a completed pool length. Called when the user taps the lap button.
    func recordLength(stroke: SwimmingStroke = .freestyle, strokeCount lengthStrokeCountOverride: Int? = nil, elapsedTime: TimeInterval) {
        guard !isResting else { return }

        // Calculate per-length timing
        let lengthTime = elapsedTime - lastLengthTime
        let lengthStrokeCount = lengthStrokeCountOverride ?? max(0, strokeCount - lastLengthStrokeCount)

        lengthTimes.append(lengthTime)
        lengthStrokes.append(lengthStrokeCount)
        lengthStrokeTypes.append(stroke)

        // Update tracking for next length
        lastLengthTime = elapsedTime
        lastLengthStrokeCount = strokeCount

        completedLengths += 1

        // Haptic feedback for length recorded
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Check interval target
        if isIntervalMode && intervalTargetReached {
            completeCurrentInterval(elapsedTime: elapsedTime)
        }

        Log.tracking.debug("Length \(self.completedLengths) recorded: \(String(format: "%.1f", lengthTime))s, \(lengthStrokeCount) strokes, \(stroke.rawValue)")
    }

    /// Update the stroke type for the most recently recorded length
    func updateLastLengthStroke(_ stroke: SwimmingStroke) {
        guard !lengthStrokeTypes.isEmpty else { return }
        lengthStrokeTypes[lengthStrokeTypes.count - 1] = stroke
    }

    /// Update the currently selected stroke type
    func updateStroke(_ stroke: SwimmingStroke) {
        currentStroke = stroke
    }

    // MARK: - Interval Management

    private func completeCurrentInterval(elapsedTime: TimeInterval) {
        guard let settings = intervalSettings else { return }

        // Record interval data
        let intervalDuration = elapsedTime - intervalStartTime
        let intervalStrokes = strokeCount - (intervalData.isEmpty ? 0 :
            intervalData.reduce(0) { $0 + $1.strokes })
        intervalData.append((
            distance: distanceInCurrentInterval,
            duration: intervalDuration,
            strokes: intervalStrokes
        ))

        currentIntervalIndex += 1

        // Check if all intervals complete
        if allIntervalsComplete {
            testComplete = true
            watchManager.sendCommand(.hapticComplete)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            return
        }

        // Start rest period
        isResting = true
        restTimeRemaining = settings.restDuration

        watchManager.sendCommand(.hapticRestStart)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.restTimeRemaining -= 1

                // Countdown haptics at 5 and 3 seconds
                if self.restTimeRemaining == 5 || self.restTimeRemaining == 3 {
                    self.watchManager.sendCommand(.hapticUrgent)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }

                if self.restTimeRemaining <= 0 {
                    self.endRestPeriod(elapsedTime: elapsedTime + (settings.restDuration - self.restTimeRemaining))
                }
            }
        }
    }

    private func endRestPeriod(elapsedTime: TimeInterval) {
        restTimer?.invalidate()
        restTimer = nil
        isResting = false

        // Reset interval tracking
        intervalStartTime = elapsedTime
        intervalStartLengthCount = completedLengths

        watchManager.sendCommand(.hapticRestEnd)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
