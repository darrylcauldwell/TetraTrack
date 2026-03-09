//
//  RunningTracker.swift
//  TetraTrack
//
//  Long-lived @Observable service for walking and running sessions.
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
final class RunningTracker {

    // MARK: - Session State

    enum SessionState: Equatable {
        case idle, tracking, paused
        var isActive: Bool { self != .idle }
    }

    enum ActivityMode: Equatable {
        case outdoor, track, walking
    }

    private(set) var sessionState: SessionState = .idle
    private(set) var currentSession: RunningSession?
    private(set) var activityMode: ActivityMode = .outdoor

    // MARK: - Observable Properties (views bind to these)

    // Core
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var totalDistance: Double = 0
    private(set) var currentSpeed: Double = 0

    // Elevation
    private(set) var currentElevation: Double = 0
    private(set) var elevationGain: Double = 0
    private(set) var elevationLoss: Double = 0

    // Heart rate
    private(set) var currentHeartRate: Int = 0
    private(set) var averageHeartRate: Int = 0
    private(set) var maxHeartRate: Int = 0
    private(set) var minHeartRate: Int = Int.max

    // Cadence & form
    private(set) var currentCadence: Int = 0
    private(set) var verticalOscillation: Double = 0
    private(set) var groundContactTime: Double = 0

    // GPS
    private(set) var gpsSignalQuality: GPSSignalQuality = .none

    // Track mode
    private(set) var lapCount: Int = 0
    private(set) var lastLapTime: TimeInterval = 0

    // Vehicle detection
    var showingVehicleAlert: Bool = false

    // MARK: - Private tracking arrays

    private var heartRateReadings: [Int] = []
    private var heartRateSamples: [HeartRateSample] = []
    private var cadenceReadings: [Int] = []
    private var oscillationReadings: [Double] = []
    private var gctReadings: [Double] = []
    private var formSamples: [RunningFormSample] = []
    private var hasWCSessionHR: Bool = false
    private var estimatedMaxHR: Int { 190 }

    // Km split tracking
    private var lastAnnouncedKm: Int = 0
    private var lastKmSplitTime: TimeInterval = 0

    // Vehicle detection
    private var highSpeedStartTime: Date?
    private let vehicleSpeedThreshold: Double = 7.0
    private let vehicleDetectionDuration: TimeInterval = 10

    // Family sharing
    private var shareWithFamily: Bool = false
    private var lastSharingUpdateTime: Date = .distantPast
    private let sharingUpdateInterval: TimeInterval = 10

    // Watch observation tasks
    private var watchHeartRateTask: Task<Void, Never>?
    private var watchMotionTask: Task<Void, Never>?
    private var watchUpdateTimer: Timer?

    // Post-session background task
    private var postSessionBackgroundTaskId: UIBackgroundTaskIdentifier = .invalid

    // MARK: - Dependencies

    private let locationManager: LocationManager
    private let gpsTracker: GPSSessionTracker
    private let watchManager = WatchConnectivityManager.shared
    private let workoutLifecycle = WorkoutLifecycleService.shared
    private let sharingCoordinator = UnifiedSharingCoordinator.shared
    private let sensorAnalyzer = WatchSensorAnalyzer.shared
    private let audioCoach = AudioCoachManager.shared
    private let weatherService = WeatherService.shared
    private var lapDetector: LapDetector { LapDetector.shared }

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
        _ session: RunningSession,
        mode: ActivityMode,
        shareWithFamily: Bool = false,
        targetCadence: Int = 0
    ) async {
        guard sessionState == .idle else {
            Log.tracking.warning("RunningTracker.startSession() aborted - not idle")
            return
        }

        // Request permission if needed
        if locationManager.needsPermission {
            locationManager.requestPermission()
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        guard mode == .walking || locationManager.hasPermission else {
            Log.tracking.warning("RunningTracker.startSession() aborted - no location permission")
            return
        }

        currentSession = session
        activityMode = mode
        self.shareWithFamily = shareWithFamily

        session.startDate = Date()
        modelContext?.insert(session)
        do {
            try modelContext?.save()
            Log.tracking.debug("Initial session save completed")
        } catch {
            Log.tracking.error("Failed to save initial session: \(error)")
        }

        // Reset state
        resetTrackingState()

        // Start GPS for outdoor/track/walking
        let usesGPS = mode == .outdoor || mode == .track || mode == .walking
        if usesGPS {
            guard let ctx = modelContext else {
                Log.tracking.error("RunningTracker: no modelContext")
                return
            }
            let activityType: GPSActivityType = mode == .walking ? .walking : .running
            let gpsConfig = GPSSessionConfig(
                subscriberId: mode == .walking ? "walking" : "running",
                activityType: activityType,
                checkpointInterval: 30,
                modelContext: ctx,
                workoutLifecycle: workoutLifecycle
            )
            await gpsTracker.start(config: gpsConfig, delegate: self)
            Log.tracking.info("RunningTracker: GPS started for \(String(describing: mode))")
        }

        // Start HealthKit workout
        do {
            let config = HKWorkoutConfiguration()
            config.activityType = mode == .walking ? .walking : .running
            config.locationType = usesGPS ? .outdoor : .indoor
            try await workoutLifecycle.startWorkout(configuration: config)
            Log.tracking.info("RunningTracker: workout lifecycle started")
        } catch {
            Log.tracking.error("Failed to start workout lifecycle: \(error)")
        }

        // Start Watch motion tracking
        watchManager.resetMotionMetrics()
        sensorAnalyzer.startSession(discipline: mode == .walking ? .walking : .running)

        // Family sharing
        if shareWithFamily {
            await sharingCoordinator.startSharingLocation(
                activityType: mode == .walking ? "walking" : "running"
            )
        }

        // Track mode setup
        if mode == .track {
            lapDetector.configure(trackLength: session.trackLength)
            lapDetector.onLapCompleted = { [weak self] lapNumber, lapTime in
                guard let self else { return }
                self.handleLapCompleted(lapNumber: lapNumber, lapTime: lapTime)
            }
        }

        // Start Watch status updates
        startWatchStatusUpdates()

        // Audio coaching
        if mode == .walking {
            audioCoach.announceWalkingSessionStart(routeName: nil)
        }
        audioCoach.startRunningFormReminders()

        // Prevent screen auto-lock
        UIApplication.shared.isIdleTimerDisabled = true

        sessionState = .tracking
        Log.tracking.info("RunningTracker: session started (\(String(describing: mode)))")
    }

    func pause() {
        guard sessionState == .tracking else { return }
        gpsTracker.pause()
        workoutLifecycle.pause()
        sessionState = .paused
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func resume() {
        guard sessionState == .paused else { return }
        gpsTracker.resume()
        workoutLifecycle.resume()
        sessionState = .tracking
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func stop() {
        guard sessionState.isActive else { return }

        // Request background time for post-session saves
        postSessionBackgroundTaskId = UIApplication.shared.beginBackgroundTask(
            withName: "RunningPostSession"
        ) { [weak self] in
            guard let self else { return }
            Log.tracking.warning("Running post-session background task expiring")
            do { try self.modelContext?.save() } catch {
                Log.tracking.error("Emergency save on expiration: \(error)")
            }
            if self.postSessionBackgroundTaskId != .invalid {
                UIApplication.shared.endBackgroundTask(self.postSessionBackgroundTaskId)
                self.postSessionBackgroundTaskId = .invalid
            }
        }

        // Stop GPS and workout
        gpsTracker.stop()
        stopWatchStatusUpdates()
        audioCoach.stopRunningFormReminders()

        // Finalize session data
        if let session = currentSession {
            session.endDate = Date()
            session.totalDuration = elapsedTime
            session.totalDistance = totalDistance
            session.totalAscent = elevationGain
            session.totalDescent = elevationLoss

            // Heart rate
            if !heartRateReadings.isEmpty {
                session.averageHeartRate = heartRateReadings.reduce(0, +) / heartRateReadings.count
                session.maxHeartRate = maxHeartRate
                session.minHeartRate = minHeartRate == Int.max ? 0 : minHeartRate
                session.heartRateSamples = heartRateSamples
            }

            // Cadence
            if !cadenceReadings.isEmpty {
                session.averageCadence = cadenceReadings.reduce(0, +) / cadenceReadings.count
                session.maxCadence = cadenceReadings.max() ?? 0
            }

            // Running form
            if !oscillationReadings.isEmpty {
                session.averageVerticalOscillation = oscillationReadings.reduce(0, +) / Double(oscillationReadings.count)
            }
            if !gctReadings.isEmpty {
                session.averageGroundContactTime = gctReadings.reduce(0, +) / Double(gctReadings.count)
            }
            if !formSamples.isEmpty {
                session.runningFormSamples = formSamples
            }

            session.peakHeartRateAtEnd = currentHeartRate > 0 ? currentHeartRate : maxHeartRate

            // Sensor data
            let summary = sensorAnalyzer.getRunningSummary()
            if summary.averageBreathingRate > 0 { session.averageBreathingRate = summary.averageBreathingRate }
            if summary.currentSpO2 > 0 { session.averageSpO2 = summary.currentSpO2 }
            if summary.minSpO2 < 100 { session.minSpO2 = summary.minSpO2 }
            session.endFatigueScore = summary.fatigueScore
            session.postureStability = summary.postureStability
            session.trainingLoadScore = summary.trainingLoadScore

            // Fallback elevation from sensor if GPS didn't provide it
            if session.totalAscent == 0 && summary.totalElevationGain > 0 {
                session.totalAscent = summary.totalElevationGain
            }
            if session.totalDescent == 0 && summary.totalElevationLoss > 0 {
                session.totalDescent = summary.totalElevationLoss
            }

            do {
                try modelContext?.save()
            } catch {
                Log.tracking.error("Failed to save session data: \(error)")
            }
        }

        // Build HealthKit metadata
        var metadata: [String: Any] = [
            HKMetadataKeyIndoorWorkout: activityMode != .outdoor && activityMode != .track && activityMode != .walking,
            "SessionType": currentSession?.sessionType.rawValue ?? "easy"
        ]
        if activityMode == .walking {
            metadata["SessionType"] = "walking"
        }

        // Build HealthKit events for track laps
        var hkEvents: [HKWorkoutEvent] = []
        if activityMode == .track, let session = currentSession, !lapDetector.lapTimes.isEmpty {
            var lapStartDate = session.startDate
            for (index, duration) in lapDetector.lapTimes.enumerated() {
                let lapEndDate = lapStartDate.addingTimeInterval(duration)
                let interval = DateInterval(start: lapStartDate, end: lapEndDate)
                hkEvents.append(HKWorkoutEvent(type: .lap, dateInterval: interval, metadata: [
                    "LapIndex": index + 1,
                    "LapDistance": session.trackLength
                ]))
                lapStartDate = lapEndDate
            }
        }

        // End HealthKit workout
        Task {
            if !hkEvents.isEmpty {
                await workoutLifecycle.addWorkoutEvents(hkEvents)
            }
            let workout = await workoutLifecycle.endAndSave(metadata: metadata)
            if let workout, let session = currentSession {
                session.healthKitWorkoutUUID = workout.uuid.uuidString
                Log.tracking.info("Running workout saved: \(workout.uuid.uuidString)")
            }
            workoutLifecycle.sendIdleStateToWatch()
        }

        // Stop motion & sensor tracking
        watchManager.stopMotionTracking()
        sensorAnalyzer.stopSession()

        // Stop family sharing
        if shareWithFamily {
            Task { await sharingCoordinator.stopSharingLocation() }
        }

        // Audio coaching end
        if activityMode == .walking, let session = currentSession {
            audioCoach.announceWalkingSessionEnd(
                distance: session.totalDistance,
                duration: elapsedTime,
                averageCadence: session.averageCadence
            )
        }

        // Re-enable screen auto-lock
        UIApplication.shared.isIdleTimerDisabled = false

        // End background task
        Task {
            let taskId = postSessionBackgroundTaskId
            if taskId != .invalid {
                UIApplication.shared.endBackgroundTask(taskId)
            }
            postSessionBackgroundTaskId = .invalid
            Log.tracking.info("Running post-session tasks completed")
        }

        // Reset state
        sessionState = .idle
        currentSession = nil
    }

    func discard() {
        guard sessionState.isActive else { return }

        gpsTracker.stop()
        stopWatchStatusUpdates()
        audioCoach.stopRunningFormReminders()
        watchManager.stopMotionTracking()
        sensorAnalyzer.stopSession()

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

        if shareWithFamily {
            Task { await sharingCoordinator.stopSharingLocation() }
        }

        UIApplication.shared.isIdleTimerDisabled = false
        sessionState = .idle
        currentSession = nil
    }

    // MARK: - Track Mode

    func configureLapDetector(trackLength: Double) {
        lapDetector.configure(trackLength: trackLength)
    }

    // MARK: - Checkpoint Save

    func checkpointSave() {
        guard sessionState.isActive else { return }
        do {
            try modelContext?.save()
            Log.tracking.debug("RunningTracker checkpoint save completed")
        } catch {
            Log.tracking.error("RunningTracker checkpoint save failed: \(error)")
        }
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

        // Motion (cadence, oscillation, GCT)
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
                guard self.sessionState == .tracking else { continue }
                self.handleMotionUpdate()
            }
        }
    }

    private func handleHeartRateUpdate(_ bpm: Int) {
        hasWCSessionHR = true
        currentHeartRate = bpm
        heartRateReadings.append(bpm)
        if bpm > maxHeartRate { maxHeartRate = bpm }
        if bpm < minHeartRate { minHeartRate = bpm }
        heartRateSamples.append(HeartRateSample(
            timestamp: Date(),
            bpm: bpm,
            maxHeartRate: estimatedMaxHR
        ))
    }

    private func handleMotionUpdate() {
        let mode = watchManager.currentMotionMode
        let isRunningMode = mode == .running
        let isWalkingMode = activityMode == .walking

        // Cadence applies to both running and walking
        let cadVal = watchManager.cadence
        if cadVal > 0 {
            currentCadence = cadVal
            cadenceReadings.append(cadVal)
        }

        // Oscillation and GCT only for running mode
        if isRunningMode {
            let osc = watchManager.verticalOscillation
            if osc > 0 {
                verticalOscillation = osc
                oscillationReadings.append(osc)
            }
            let gctVal = watchManager.groundContactTime
            if gctVal > 0 {
                groundContactTime = gctVal
                gctReadings.append(gctVal)
            }

            if cadVal > 0 || osc > 0 || gctVal > 0 {
                formSamples.append(RunningFormSample(
                    timestamp: Date(),
                    cadence: cadVal > 0 ? cadVal : 0,
                    oscillation: osc > 0 ? osc : 0,
                    groundContactTime: gctVal > 0 ? gctVal : 0
                ))
            }
        }

        // Audio coaching for cadence (walking has its own cadence check in the timer)
        if isRunningMode && cadVal > 0 && audioCoach.announceCadenceFeedback {
            // Running cadence coaching with target (if set)
            let target = currentSession?.targetCadence ?? 0
            if target > 0 {
                audioCoach.processCadence(cadVal, target: target)
            }
        }
    }

    // MARK: - Watch Status Updates

    private func startWatchStatusUpdates() {
        sendStatusToWatch()
        watchUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.sendStatusToWatch()
        }
    }

    private func stopWatchStatusUpdates() {
        watchUpdateTimer?.invalidate()
        watchUpdateTimer = nil
    }

    private func sendStatusToWatch() {
        let gaitLabel = activityMode == .walking ? "Walking" : "Running"
        watchManager.sendStatusUpdate(
            rideState: .tracking,
            duration: elapsedTime,
            distance: totalDistance,
            speed: totalDistance > 0 && elapsedTime > 0 ? totalDistance / elapsedTime : 0,
            gait: gaitLabel,
            heartRate: currentHeartRate > 0 ? currentHeartRate : nil,
            heartRateZone: currentHeartRate > 0 ? heartRateZone : nil,
            averageHeartRate: averageHeartRate > 0 ? averageHeartRate : nil,
            maxHeartRate: maxHeartRate > 0 ? maxHeartRate : nil,
            horseName: nil,
            rideType: activityMode == .walking ? "Walking" : currentSession?.sessionType.rawValue ?? "easy"
        )
    }

    private var heartRateZone: Int {
        guard currentHeartRate > 0 else { return 1 }
        if currentHeartRate < 100 { return 1 }
        if currentHeartRate < 120 { return 2 }
        if currentHeartRate < 150 { return 3 }
        if currentHeartRate < 170 { return 4 }
        return 5
    }

    // MARK: - Private Helpers

    private func resetTrackingState() {
        elapsedTime = 0
        totalDistance = 0
        currentSpeed = 0
        currentElevation = 0
        elevationGain = 0
        elevationLoss = 0
        currentHeartRate = 0
        averageHeartRate = 0
        maxHeartRate = 0
        minHeartRate = Int.max
        currentCadence = 0
        verticalOscillation = 0
        groundContactTime = 0
        gpsSignalQuality = .none
        lapCount = 0
        lastLapTime = 0
        showingVehicleAlert = false
        highSpeedStartTime = nil
        lastAnnouncedKm = 0
        lastKmSplitTime = 0
        lastSharingUpdateTime = .distantPast
        heartRateReadings = []
        heartRateSamples = []
        cadenceReadings = []
        oscillationReadings = []
        gctReadings = []
        formSamples = []
        hasWCSessionHR = false
    }

    private func handleLapCompleted(lapNumber: Int, lapTime: TimeInterval) {
        guard let session = currentSession else { return }

        lapCount = lapNumber
        lastLapTime = lapTime

        // Persist as RunningSplit
        let split = RunningSplit(orderIndex: lapNumber - 1, distance: session.trackLength)
        split.duration = lapTime
        if currentHeartRate > 0 { split.heartRate = currentHeartRate }
        if currentCadence > 0 { split.cadence = currentCadence }
        split.session = session
        if session.splits == nil { session.splits = [] }
        session.splits?.append(split)
        modelContext?.insert(split)

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        watchManager.sendCommand(.hapticMilestone)

        if audioCoach.announceRunningLaps {
            let previousLapTime: TimeInterval? = lapDetector.lapTimes.count >= 2
                ? lapDetector.lapTimes[lapDetector.lapTimes.count - 2] : nil
            let isFastest = lapDetector.lapTimes.count > 1 && lapTime == lapDetector.fastestLap
            audioCoach.announceLapWithComparison(
                lapNumber, lapTime: lapTime,
                previousLapTime: previousLapTime, isFastest: isFastest
            )
        }
    }

    private func checkForVehicleSpeed(_ speed: Double) {
        if speed > vehicleSpeedThreshold {
            if highSpeedStartTime == nil {
                highSpeedStartTime = Date()
            } else if let start = highSpeedStartTime,
                      Date().timeIntervalSince(start) > vehicleDetectionDuration {
                if !showingVehicleAlert {
                    showingVehicleAlert = true
                    audioCoach.announce("It looks like you may be in a vehicle. Would you like to stop tracking?")
                }
            }
        } else {
            highSpeedStartTime = nil
        }
    }

    func dismissVehicleAlert() {
        showingVehicleAlert = false
        highSpeedStartTime = nil
    }
}

// MARK: - GPSSessionDelegate

extension RunningTracker: GPSSessionDelegate {
    nonisolated func createLocationPoint(from location: CLLocation) -> (any PersistentModel)? {
        MainActor.assumeIsolated {
            guard let session = currentSession else { return nil }
            let point = RunningLocationPoint(from: location)
            point.session = session
            return point
        }
    }

    nonisolated func didProcessLocation(_ location: CLLocation, distanceDelta: Double, tracker: GPSSessionTracker) {
        MainActor.assumeIsolated {
            handleLocationUpdate(location, distanceDelta: distanceDelta)
        }
    }

    private func handleLocationUpdate(_ location: CLLocation, distanceDelta: Double) {
        guard sessionState == .tracking, let session = currentSession else { return }

        // Sync from GPS tracker
        totalDistance = gpsTracker.totalDistance
        currentSpeed = gpsTracker.currentSpeed
        currentElevation = gpsTracker.currentElevation
        elevationGain = gpsTracker.elevationGain
        elevationLoss = gpsTracker.elevationLoss
        gpsSignalQuality = gpsTracker.gpsSignalQuality
        elapsedTime = gpsTracker.elapsedTime

        // Sync to session model
        session.totalDistance = totalDistance
        session.totalAscent = elevationGain
        session.totalDescent = elevationLoss

        // Km split detection (outdoor and walking, not track)
        if activityMode != .track {
            let currentKm = Int(totalDistance / 1000)
            if currentKm > lastAnnouncedKm && currentKm > 0 {
                let splitDuration = elapsedTime - lastKmSplitTime
                lastAnnouncedKm = currentKm
                lastKmSplitTime = elapsedTime

                let split = RunningSplit(orderIndex: currentKm - 1, distance: 1000)
                split.duration = splitDuration
                if currentHeartRate > 0 { split.heartRate = currentHeartRate }
                if currentCadence > 0 { split.cadence = currentCadence }
                split.session = session
                if session.splits == nil { session.splits = [] }
                session.splits?.append(split)
                modelContext?.insert(split)

                if activityMode == .walking {
                    audioCoach.announceWalkingMilestone(
                        km: currentKm,
                        splitTime: splitDuration,
                        totalDistance: totalDistance,
                        cadence: session.averageCadence
                    )
                } else if audioCoach.announceRunningPace {
                    audioCoach.announceKmSplit(
                        km: currentKm,
                        averagePace: splitDuration,
                        gapMeters: nil,
                        remaining: nil
                    )
                }

                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }

        // Virtual pacer update
        if VirtualPacer.shared.isActive {
            VirtualPacer.shared.update(distance: totalDistance, elapsedTime: elapsedTime)
        }

        // Vehicle detection
        checkForVehicleSpeed(location.speed)

        // Track mode: lap detection
        if activityMode == .track {
            lapDetector.processLocation(location, elapsedTime: elapsedTime)
        }

        // Family sharing (throttled)
        if shareWithFamily {
            let now = Date()
            if now.timeIntervalSince(lastSharingUpdateTime) >= sharingUpdateInterval {
                lastSharingUpdateTime = now
                let gait = RunningPhase.fromGPSSpeed(max(0, location.speed)).toGaitType
                Task {
                    await sharingCoordinator.updateSharedLocation(
                        location: location,
                        gait: gait,
                        distance: totalDistance,
                        duration: elapsedTime
                    )
                }
            }
        }
    }
}
