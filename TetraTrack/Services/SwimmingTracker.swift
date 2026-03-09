//
//  SwimmingTracker.swift
//  TetraTrack
//
//  Long-lived @Observable service for swimming sessions (pool and open water).
//  Follows the RideTracker pattern: created once in TetraTrackApp, injected
//  via .environment(), and directly conforms to GPSSessionDelegate so the
//  weak delegate reference never goes nil during a session.
//

import SwiftData
import CoreLocation
import HealthKit
import Observation
import UIKit
import os

@Observable
@MainActor
final class SwimmingTracker {

    // MARK: - Session State

    enum SessionState: Equatable {
        case idle, armed, tracking, paused, complete
        var isActive: Bool { self != .idle }
    }

    private(set) var sessionState: SessionState = .idle
    private(set) var currentSession: SwimmingSession?

    // MARK: - Observable Properties

    // Core
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var totalDistance: Double = 0
    private(set) var isOpenWater: Bool = false
    private(set) var poolLength: Double = 25.0

    // Lengths (pool mode)
    private(set) var lengthCount: Int = 0

    // Strokes
    private(set) var strokeCount: Int = 0
    private(set) var strokeRate: Double = 0.0

    // Heart rate
    private(set) var currentHeartRate: Int = 0
    private(set) var maxHeartRate: Int = 0
    private(set) var averageHeartRate: Int = 0

    // Test mode
    private(set) var testComplete: Bool = false
    var isThreeMinuteTest: Bool = false
    var testDuration: TimeInterval = 180
    var freeSwimTargetDuration: TimeInterval? = nil

    // MARK: - Private State

    private var sessionStartDate: Date?
    private var timer: Timer?

    // Heart rate tracking
    private var heartRateReadings: [Int] = []
    private var heartRateSamples: [HeartRateSample] = []
    private var hasWCSessionHR: Bool = false
    private var estimatedMaxHR: Int { 190 }

    // Stroke tracking (exposed for UI display)
    private(set) var lengthStrokes: [Int] = []
    private(set) var lengthTimes: [TimeInterval] = []
    private var lastLengthTime: TimeInterval = 0
    private var lastLengthStrokeCount: Int = 0
    private(set) var lengthStrokeTypes: [SwimmingStroke] = []

    // Interval tracking
    private var intervalSettings: SwimmingIntervalSettings?
    private(set) var currentIntervalIndex: Int = 0
    private(set) var isResting: Bool = false
    private(set) var restTimeRemaining: TimeInterval = 0
    private var restTimer: Timer?
    private var intervalStartTime: TimeInterval = 0
    private var intervalStartLengthCount: Int = 0
    private var intervalData: [(distance: Double, duration: TimeInterval, strokes: Int)] = []

    // Interval computed properties
    var isIntervalMode: Bool { intervalSettings != nil }
    var numberOfIntervals: Int { intervalSettings?.numberOfIntervals ?? 0 }
    var intervalTargetDistance: Double { intervalSettings?.targetDistance ?? 0 }
    var intervalTargetPace: TimeInterval { intervalSettings?.targetPace ?? 0 }
    var intervalRestDuration: TimeInterval { intervalSettings?.restDuration ?? 0 }
    var distanceInCurrentInterval: Double {
        Double(lengthCount - intervalStartLengthCount) * poolLength
    }
    var allIntervalsComplete: Bool {
        guard let settings = intervalSettings else { return false }
        return currentIntervalIndex >= settings.numberOfIntervals
    }
    var averageSWOLF: Double {
        guard !lengthStrokes.isEmpty, !lengthTimes.isEmpty else { return 0 }
        let swolfScores = zip(lengthStrokes, lengthTimes)
            .filter { $0.0 > 0 && $0.1 > 0 }
            .map { Double($0) + $1 }
        guard !swolfScores.isEmpty else { return 0 }
        return swolfScores.reduce(0, +) / Double(swolfScores.count)
    }

    // Watch status updates
    private var watchUpdateTimer: Timer?

    // Watch observation
    private var watchHeartRateTask: Task<Void, Never>?
    private var watchMotionTask: Task<Void, Never>?
    private var watchSensorTask: Task<Void, Never>?

    // MARK: - Dependencies

    private let locationManager: LocationManager
    private let gpsTracker: GPSSessionTracker
    private let watchManager = WatchConnectivityManager.shared
    private let workoutLifecycle = WorkoutLifecycleService.shared
    private let sensorAnalyzer = WatchSensorAnalyzer.shared

    private var modelContext: ModelContext?

    // MARK: - Init

    init(locationManager: LocationManager, gpsTracker: GPSSessionTracker) {
        self.locationManager = locationManager
        self.gpsTracker = gpsTracker
        startWatchObservation()
    }

    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Session Lifecycle

    func startSession(
        _ session: SwimmingSession,
        poolLength: Double,
        isOpenWater: Bool,
        isThreeMinuteTest: Bool = false,
        testDuration: TimeInterval = 180,
        freeSwimTargetDuration: TimeInterval? = nil,
        intervalSettings: SwimmingIntervalSettings? = nil
    ) async {
        guard sessionState == .idle else {
            Log.tracking.warning("SwimmingTracker.startSession() aborted - not idle")
            return
        }

        currentSession = session
        self.poolLength = poolLength
        self.isOpenWater = isOpenWater
        self.isThreeMinuteTest = isThreeMinuteTest
        self.testDuration = testDuration
        self.freeSwimTargetDuration = freeSwimTargetDuration
        self.intervalSettings = intervalSettings

        session.startDate = Date()
        modelContext?.insert(session)

        // Reset state
        resetTrackingState()

        // Start HealthKit workout
        do {
            let config = HKWorkoutConfiguration()
            config.activityType = .swimming
            if isOpenWater {
                config.locationType = .outdoor
                config.swimmingLocationType = .openWater
            } else {
                config.locationType = .indoor
                config.swimmingLocationType = .pool
                config.lapLength = HKQuantity(unit: .meter(), doubleValue: poolLength)
            }
            try await workoutLifecycle.startWorkout(configuration: config)
            Log.tracking.info("SwimmingTracker: workout lifecycle started")
        } catch {
            Log.tracking.error("Failed to start swimming workout lifecycle: \(error)")
        }

        // Start GPS for open water
        if isOpenWater {
            await startLocationTracking()
        }

        // Start Watch motion/sensor tracking
        watchManager.resetMotionMetrics()
        sensorAnalyzer.startSession(discipline: .swimming)
        startWatchStatusUpdates()

        if isOpenWater {
            // Arm for submersion-triggered start
            sessionState = .armed
            if sensorAnalyzer.isSubmerged {
                triggerSubmersionStart()
            }
        } else {
            sessionState = .tracking
            startTimer()
        }

        UIApplication.shared.isIdleTimerDisabled = true
        Log.tracking.info("SwimmingTracker: session started (openWater=\(isOpenWater))")
    }

    func triggerSubmersionStart() {
        guard sessionState == .armed else { return }
        sessionState = .tracking
        startTimer()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func pause() {
        guard sessionState == .tracking else { return }
        stopTimer()
        sessionState = .paused
    }

    func resume() {
        guard sessionState == .paused else { return }
        startTimer()
        sessionState = .tracking
    }

    func stop() {
        guard sessionState.isActive else { return }

        stopTimer()
        restTimer?.invalidate()
        restTimer = nil
        stopWatchStatusUpdates()

        // Stop GPS for open water
        if isOpenWater {
            gpsTracker.stop()
        }

        // Stop motion tracking
        watchManager.stopMotionTracking()
        sensorAnalyzer.stopSession()

        // Finalize session
        if let session = currentSession {
            session.endDate = Date()
            session.totalDuration = elapsedTime
            session.totalDistance = totalDistance
            session.totalStrokes = strokeCount

            // Heart rate
            if !heartRateReadings.isEmpty {
                session.averageHeartRate = heartRateReadings.reduce(0, +) / heartRateReadings.count
                session.maxHeartRate = maxHeartRate
                session.minHeartRate = heartRateReadings.min() ?? 0
                session.heartRateSamples = heartRateSamples
            }

            // Create SwimmingLap objects (pool mode)
            if !isOpenWater {
                let lapCount = min(lengthTimes.count, lengthCount)
                if lapCount > 0 {
                    if session.laps == nil { session.laps = [] }
                    for i in 0..<lapCount {
                        let lap = SwimmingLap(orderIndex: i, distance: poolLength)
                        lap.duration = lengthTimes[i]
                        if i < lengthStrokes.count { lap.strokeCount = lengthStrokes[i] }
                        if i < lengthStrokeTypes.count { lap.stroke = lengthStrokeTypes[i] }
                        let precedingTime = lengthTimes.prefix(i).reduce(0, +)
                        lap.startTime = session.startDate.addingTimeInterval(precedingTime)
                        lap.endTime = lap.startTime.addingTimeInterval(lengthTimes[i])
                        session.laps?.append(lap)
                    }
                }
            }

            // Create SwimmingInterval objects
            if let settings = intervalSettings, !intervalData.isEmpty {
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

            // Sensor data
            let summary = sensorAnalyzer.getSwimmingSummary()
            if summary.totalSubmergedTime > 0 { session.totalSubmergedTime = summary.totalSubmergedTime }
            if summary.submersionCount > 0 { session.submersionCount = summary.submersionCount }
            if summary.currentSpO2 > 0 { session.averageSpO2 = summary.currentSpO2 }
            if summary.minSpO2 < 100 { session.minSpO2 = summary.minSpO2 }
            session.recoveryQuality = summary.recoveryQuality
            if sensorAnalyzer.breathingRate > 0 { session.averageBreathingRate = sensorAnalyzer.breathingRate }

            do { try modelContext?.save() } catch {
                Log.tracking.error("Failed to save swimming session: \(error)")
            }
        }

        // Build HealthKit enrichment
        var hkEvents: [HKWorkoutEvent] = []
        var hkSamples: [HKSample] = []
        let sessionStart = currentSession?.startDate ?? Date()

        // Per-lap events (pool mode)
        if !isOpenWater {
            let lapCount = min(lengthTimes.count, lengthCount)
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

                if i < lengthStrokes.count, lengthStrokes[i] > 0 {
                    hkSamples.append(HKQuantitySample(
                        type: HKQuantityType(.swimmingStrokeCount),
                        quantity: HKQuantity(unit: .count(), doubleValue: Double(lengthStrokes[i])),
                        start: lapStart,
                        end: lapEnd
                    ))
                }

                hkSamples.append(HKQuantitySample(
                    type: HKQuantityType(.distanceSwimming),
                    quantity: HKQuantity(unit: .meter(), doubleValue: poolLength),
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
                let interval = DateInterval(start: intervalStart, end: intervalEnd)
                hkEvents.append(HKWorkoutEvent(type: .segment, dateInterval: interval, metadata: [
                    "IntervalIndex": index + 1,
                    "Distance": data.distance,
                    "Strokes": data.strokes
                ]))
                intervalStart = intervalEnd
            }
        }

        // SpO2 sample (if available from Watch)
        if sensorAnalyzer.oxygenSaturation > 0 && sensorAnalyzer.oxygenSaturation <= 100 {
            hkSamples.append(HKQuantitySample(
                type: HKQuantityType(.oxygenSaturation),
                quantity: HKQuantity(unit: .percent(), doubleValue: sensorAnalyzer.oxygenSaturation / 100.0),
                start: sessionStart,
                end: Date()
            ))
        }

        // Breathing rate sample (if available from Watch)
        if sensorAnalyzer.breathingRate > 0 {
            hkSamples.append(HKQuantitySample(
                type: HKQuantityType(.respiratoryRate),
                quantity: HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()), doubleValue: sensorAnalyzer.breathingRate),
                start: sessionStart,
                end: Date()
            ))
        }

        // Build metadata
        var swimMetadata: [String: Any] = [
            HKMetadataKeySwimmingLocationType: isOpenWater
                ? NSNumber(value: HKWorkoutSwimmingLocationType.openWater.rawValue)
                : NSNumber(value: HKWorkoutSwimmingLocationType.pool.rawValue)
        ]
        if !isOpenWater {
            swimMetadata[HKMetadataKeyLapLength] = HKQuantity(unit: .meter(), doubleValue: poolLength)
        }
        if strokeCount > 0 { swimMetadata["TotalStrokes"] = strokeCount }
        if averageSWOLF > 0 { swimMetadata["AverageSWOLF"] = averageSWOLF }
        if !lengthStrokeTypes.isEmpty {
            let strokeCounts = Dictionary(grouping: lengthStrokeTypes, by: { $0 }).mapValues { $0.count }
            if let dominant = strokeCounts.max(by: { $0.value < $1.value }) {
                swimMetadata["DominantStroke"] = dominant.key.rawValue
            }
        }

        // End HealthKit workout
        Task {
            if !hkEvents.isEmpty { await workoutLifecycle.addWorkoutEvents(hkEvents) }
            if !hkSamples.isEmpty { await workoutLifecycle.addSamples(hkSamples) }
            let workout = await workoutLifecycle.endAndSave(metadata: swimMetadata)
            if let workout, let session = currentSession {
                session.healthKitWorkoutUUID = workout.uuid.uuidString
                Log.tracking.info("Swimming workout saved: \(workout.uuid.uuidString)")
            }
            workoutLifecycle.sendIdleStateToWatch()
        }

        UIApplication.shared.isIdleTimerDisabled = false
        sessionState = .idle
        currentSession = nil
    }

    func discard() {
        guard sessionState.isActive else { return }

        stopTimer()
        restTimer?.invalidate()
        restTimer = nil
        stopWatchStatusUpdates()
        watchManager.stopMotionTracking()
        sensorAnalyzer.stopSession()

        if isOpenWater { gpsTracker.stop() }

        Task {
            await workoutLifecycle.discard()
            workoutLifecycle.sendIdleStateToWatch()
        }

        if let session = currentSession {
            modelContext?.delete(session)
            do { try modelContext?.save() } catch {
                Log.tracking.error("Failed to save after discard: \(error)")
            }
        }

        UIApplication.shared.isIdleTimerDisabled = false
        sessionState = .idle
        currentSession = nil
    }

    // MARK: - Pool Mode Actions

    func recordLength() {
        guard sessionState == .tracking, !isOpenWater, !isResting else { return }

        lengthCount += 1

        // Track time for this length
        let lengthTime = elapsedTime - lastLengthTime
        lengthTimes.append(lengthTime)
        lastLengthTime = elapsedTime

        // Track strokes for this length
        let currentStrokes = strokeCount - lastLengthStrokeCount
        lengthStrokes.append(max(0, currentStrokes))
        lastLengthStrokeCount = strokeCount

        // Update distance
        totalDistance = Double(lengthCount) * poolLength

        // Haptic
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        watchManager.sendCommand(.hapticMilestone)

        // Check interval target
        if isIntervalMode, let settings = intervalSettings,
           distanceInCurrentInterval >= settings.targetDistance {
            completeCurrentInterval()
        }
    }

    func setStrokeType(_ stroke: SwimmingStroke, forLength index: Int) {
        if index < lengthStrokeTypes.count {
            lengthStrokeTypes[index] = stroke
        } else {
            // Pad with freestyle up to the target index
            while lengthStrokeTypes.count < index {
                lengthStrokeTypes.append(.freestyle)
            }
            lengthStrokeTypes.append(stroke)
        }
    }

    // MARK: - Interval Management

    func markComplete() {
        guard sessionState == .tracking || sessionState == .armed else { return }
        testComplete = true
        stopTimer()
        restTimer?.invalidate()
        restTimer = nil
        isResting = false
        sessionState = .complete
    }

    func completeCurrentInterval() {
        guard let settings = intervalSettings else { return }

        let intervalDuration = elapsedTime - intervalStartTime
        let intervalStrokes = strokeCount - intervalData.reduce(0) { $0 + $1.strokes }
        intervalData.append((
            distance: distanceInCurrentInterval,
            duration: intervalDuration,
            strokes: intervalStrokes
        ))

        currentIntervalIndex += 1

        if allIntervalsComplete {
            testComplete = true
            stopTimer()
            watchManager.sendCommand(.hapticComplete)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            sessionState = .complete
            return
        }

        isResting = true
        restTimeRemaining = settings.restDuration

        watchManager.sendCommand(.hapticRestStart)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)

        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.restTimeRemaining -= 1
                if self.restTimeRemaining == 5 || self.restTimeRemaining == 3 {
                    self.watchManager.sendCommand(.hapticUrgent)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                if self.restTimeRemaining <= 0 {
                    self.endRestPeriod()
                }
            }
        }
    }

    func endRestPeriod() {
        restTimer?.invalidate()
        restTimer = nil
        isResting = false
        intervalStartTime = elapsedTime
        intervalStartLengthCount = lengthCount
        watchManager.sendCommand(.hapticRestEnd)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Timer

    private func startTimer() {
        sessionStartDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.timerTick()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func timerTick() {
        guard let startDate = sessionStartDate else { return }
        let previousElapsed = elapsedTime
        elapsedTime = Date().timeIntervalSince(startDate)

        // Update stroke data
        strokeCount = watchManager.strokeCount
        strokeRate = watchManager.strokeRate

        // HR fallback from workout builder
        if !hasWCSessionHR {
            let lifecycleHR = Int(workoutLifecycle.liveHeartRate)
            if lifecycleHR > 0 {
                handleHeartRateUpdate(lifecycleHR)
            }
        }

        // Timed test completion
        if isThreeMinuteTest {
            let remaining = testDuration - elapsedTime
            let previousRemaining = testDuration - previousElapsed
            if Int(elapsedTime) / 60 > Int(previousElapsed) / 60 && remaining > 0 {
                watchManager.sendCommand(.hapticMilestone)
            }
            if previousRemaining > 10 && remaining <= 10 {
                watchManager.sendCommand(.hapticUrgent)
            }
            if elapsedTime >= testDuration {
                testComplete = true
                stopTimer()
                watchManager.sendCommand(.hapticComplete)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                sessionState = .complete
            }
        } else if let target = freeSwimTargetDuration {
            let remaining = target - elapsedTime
            let previousRemaining = target - previousElapsed
            if Int(elapsedTime) / 300 > Int(previousElapsed) / 300 && remaining > 0 {
                watchManager.sendCommand(.hapticMilestone)
            }
            if previousRemaining > 60 && remaining <= 60 {
                watchManager.sendCommand(.hapticUrgent)
            }
            if elapsedTime >= target {
                testComplete = true
                stopTimer()
                watchManager.sendCommand(.hapticComplete)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                sessionState = .complete
            }
        }

        // Open water distance from GPS
        if isOpenWater {
            totalDistance = gpsTracker.totalDistance
        }
    }

    // MARK: - Checkpoint Save

    func checkpointSave() {
        guard sessionState.isActive else { return }
        do {
            try modelContext?.save()
            Log.tracking.debug("SwimmingTracker checkpoint save completed")
        } catch {
            Log.tracking.error("SwimmingTracker checkpoint save failed: \(error)")
        }
    }

    // MARK: - GPS (Open Water)

    private func startLocationTracking() async {
        guard let ctx = modelContext else { return }

        let config = GPSSessionConfig(
            subscriberId: "swimming",
            activityType: .swimming,
            checkpointInterval: 30,
            modelContext: ctx,
            workoutLifecycle: workoutLifecycle
        )
        await gpsTracker.start(config: config, delegate: self)
        Log.tracking.info("SwimmingTracker: GPS started for open water")
    }

    // MARK: - Watch Observation

    private func startWatchObservation() {
        // Heart rate
        watchHeartRateTask = Task { @MainActor [weak self] in
            let wm = WatchConnectivityManager.shared
            var lastSeq = wm.heartRateSequence
            while !Task.isCancelled {
                await withCheckedContinuation { cont in
                    withObservationTracking { _ = wm.heartRateSequence }
                        onChange: { cont.resume() }
                }
                guard let self, !Task.isCancelled else { break }
                guard wm.heartRateSequence != lastSeq else { continue }
                lastSeq = wm.heartRateSequence
                let bpm = wm.lastReceivedHeartRate
                guard bpm > 0, self.sessionState == .tracking else { continue }
                self.handleHeartRateUpdate(bpm)
            }
        }

        // Motion (strokes)
        watchMotionTask = Task { @MainActor [weak self] in
            let wm = WatchConnectivityManager.shared
            var lastSeq = wm.motionUpdateSequence
            while !Task.isCancelled {
                await withCheckedContinuation { cont in
                    withObservationTracking { _ = wm.motionUpdateSequence }
                        onChange: { cont.resume() }
                }
                guard let self, !Task.isCancelled else { break }
                guard wm.motionUpdateSequence != lastSeq else { continue }
                lastSeq = wm.motionUpdateSequence
                guard self.sessionState == .tracking || self.sessionState == .armed else { continue }
                guard wm.currentMotionMode == .swimming else { continue }
                let strokes = wm.strokeCount
                if strokes > 0 { self.strokeCount = strokes }
                let rate = wm.strokeRate
                if rate > 0 { self.strokeRate = rate }
            }
        }

        // Sensor (submersion detection)
        watchSensorTask = Task { @MainActor [weak self] in
            let wm = WatchConnectivityManager.shared
            var lastSeq = wm.enhancedSensorSequence
            while !Task.isCancelled {
                await withCheckedContinuation { cont in
                    withObservationTracking { _ = wm.enhancedSensorSequence }
                        onChange: { cont.resume() }
                }
                guard let self, !Task.isCancelled else { break }
                guard wm.enhancedSensorSequence != lastSeq else { continue }
                lastSeq = wm.enhancedSensorSequence

                // Submersion-triggered start for open water
                if self.sessionState == .armed && self.sensorAnalyzer.isSubmerged {
                    self.triggerSubmersionStart()
                }
            }
        }
    }

    private func handleHeartRateUpdate(_ bpm: Int) {
        hasWCSessionHR = true
        currentHeartRate = bpm
        heartRateReadings.append(bpm)
        if bpm > maxHeartRate { maxHeartRate = bpm }
        heartRateSamples.append(HeartRateSample(
            timestamp: Date(),
            bpm: bpm,
            maxHeartRate: estimatedMaxHR
        ))
        if !heartRateReadings.isEmpty {
            averageHeartRate = heartRateReadings.reduce(0, +) / heartRateReadings.count
        }
    }

    // MARK: - Watch Status

    private func startWatchStatusUpdates() {
        sendStatusToWatch()
        watchUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.sendStatusToWatch()
            }
        }
    }

    private func stopWatchStatusUpdates() {
        watchUpdateTimer?.invalidate()
        watchUpdateTimer = nil
    }

    private func sendStatusToWatch() {
        let sessionName = isThreeMinuteTest ? "Timed Test" : (intervalSettings != nil ? "Intervals" : "Training")
        watchManager.sendStatusUpdate(
            rideState: sessionState == .armed ? .paused : .tracking,
            duration: elapsedTime,
            distance: totalDistance,
            speed: totalDistance > 0 && elapsedTime > 0 ? totalDistance / elapsedTime : 0,
            gait: sessionState == .armed ? "Awaiting Entry" : "Swimming",
            heartRate: currentHeartRate > 0 ? currentHeartRate : nil,
            heartRateZone: nil,
            averageHeartRate: averageHeartRate > 0 ? averageHeartRate : nil,
            maxHeartRate: maxHeartRate > 0 ? maxHeartRate : nil,
            horseName: nil,
            rideType: sessionName
        )
    }

    // MARK: - Private Helpers

    private func resetTrackingState() {
        elapsedTime = 0
        totalDistance = 0
        lengthCount = 0
        strokeCount = 0
        strokeRate = 0
        currentHeartRate = 0
        maxHeartRate = 0
        averageHeartRate = 0
        testComplete = false
        sessionStartDate = nil
        heartRateReadings = []
        heartRateSamples = []
        hasWCSessionHR = false
        lengthStrokes = []
        lengthTimes = []
        lastLengthTime = 0
        lastLengthStrokeCount = 0
        lengthStrokeTypes = []
        currentIntervalIndex = 0
        isResting = false
        restTimeRemaining = 0
        intervalStartTime = 0
        intervalStartLengthCount = 0
        intervalData = []
    }
}

// MARK: - GPSSessionDelegate

extension SwimmingTracker: GPSSessionDelegate {
    nonisolated func createLocationPoint(from location: CLLocation) -> (any PersistentModel)? {
        MainActor.assumeIsolated {
            guard let session = currentSession else { return nil }
            let point = SwimmingLocationPoint(from: location)
            point.session = session
            return point
        }
    }

    nonisolated func didProcessLocation(_ location: CLLocation, distanceDelta: Double, tracker: GPSSessionTracker) {
        MainActor.assumeIsolated {
            // Open water: sync distance from GPS
            totalDistance = tracker.totalDistance
        }
    }
}
