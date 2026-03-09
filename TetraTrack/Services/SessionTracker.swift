//
//  SessionTracker.swift
//  TetraTrack
//
//  Unified session tracker for all disciplines.
//  Manages common session concerns: GPS, timer, heart rate, weather, safety,
//  family sharing, Watch communication, and checkpoint saves.
//  Discipline-specific logic is provided by a DisciplinePlugin.

import SwiftData
import CoreLocation
import HealthKit
import Observation
import UIKit
import os

@Observable
@MainActor
final class SessionTracker {
    // MARK: - Session State

    var sessionState: SessionState = .idle
    var elapsedTime: TimeInterval = 0
    var totalDistance: Double = 0
    var currentSpeed: Double = 0  // m/s

    // MARK: - Elevation

    var currentElevation: Double = 0  // meters
    var elevationGain: Double = 0
    var elevationLoss: Double = 0

    // MARK: - Heart Rate

    var currentHeartRate: Int = 0
    var averageHeartRate: Int = 0
    var maxHeartRate: Int = 0
    var minHeartRate: Int = 0
    var currentHeartRateZone: HeartRateZone = .zone1
    var heartRateSamples: [HeartRateSample] = []

    // MARK: - GPS

    var gpsSignalQuality: GPSSignalQuality = .none
    var gpsHorizontalAccuracy: Double = -1

    // MARK: - Weather

    var currentWeather: WeatherConditions?
    var weatherError: String?

    // MARK: - Safety

    var fallDetected: Bool = false
    var fallAlertCountdown: Int = 30
    var showingFallAlert: Bool = false
    var showingVehicleAlert: Bool = false

    // MARK: - Family Sharing

    var isSharingWithFamily: Bool = false

    // MARK: - Active Plugin

    private(set) var activePlugin: (any DisciplinePlugin)?

    // Fall detection callbacks
    var onFallDetected: (() -> Void)?
    var onFallCountdownTick: ((Int) -> Void)?
    var onEmergencyAlert: ((CLLocationCoordinate2D?) -> Void)?

    // MARK: - Dependencies (internal for plugin access)

    let locationManager: LocationManager
    let gpsTracker: GPSSessionTracker
    let healthCoordinator = RideHealthCoordinator()
    private let watchManager = WatchConnectivityManager.shared
    private let workoutLifecycle = WorkoutLifecycleService.shared

    // Injected services
    private let sharingCoordinator: UnifiedSharingCoordinator
    let fallDetectionManager: FallDetectionManager
    private let audioCoach: AudioCoachManager
    private let weatherService: WeatherService

    // MARK: - Private State

    private var modelContext: ModelContext?
    private var startTime: Date?
    private var timerSource: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "dev.dreamfold.tetratrack.sessionTimer", qos: .userInitiated)
    private var timerTickCount: Int = 0
    private var hasWCSessionHR: Bool = false

    // Vehicle detection
    private var highSpeedStartTime: Date?
    private let vehicleSpeedThreshold: Double = 17.0  // ~60 km/h
    private let vehicleDetectionDuration: TimeInterval = 10

    // Watch observation tasks
    private var watchCommandTask: Task<Void, Never>?
    private var watchHeartRateTask: Task<Void, Never>?
    private var watchVoiceNoteTask: Task<Void, Never>?
    private var watchUpdateTimer: Timer?

    // Task cancellation tracking
    private var activeBackgroundTasks: [Task<Void, Never>] = []
    private var familySharingTask: Task<Void, Never>?
    private var postSessionSummaryTask: Task<Void, Never>?
    private var postSessionBackgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    private var lastFamilyUpdateTime: Date?

    // MARK: - Initialization

    /// Initialize with default production services
    convenience init(locationManager: LocationManager, gpsTracker: GPSSessionTracker) {
        self.init(
            locationManager: locationManager,
            gpsTracker: gpsTracker,
            sharingCoordinator: .shared,
            fallDetection: .shared,
            audioCoach: .shared,
            weatherService: .shared
        )
    }

    /// Initialize with dependency injection (for testing)
    init(
        locationManager: LocationManager,
        gpsTracker: GPSSessionTracker,
        sharingCoordinator: UnifiedSharingCoordinator,
        fallDetection: FallDetectionManager,
        audioCoach: AudioCoachManager,
        weatherService: WeatherService
    ) {
        self.locationManager = locationManager
        self.gpsTracker = gpsTracker
        self.sharingCoordinator = sharingCoordinator
        self.fallDetectionManager = fallDetection
        self.audioCoach = audioCoach
        self.weatherService = weatherService
        startWatchObservation()
        setupHealthCoordinator()
        setupFallDetection()
    }

    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        fallDetectionManager.configure(modelContext: modelContext, heartRateService: HeartRateService())
    }

    func configure(riderProfile: RiderProfile?) {
        healthCoordinator.configure(riderProfile: riderProfile)
    }

    // MARK: - Plugin Access

    /// Downcast active plugin to a specific type
    func plugin<T: DisciplinePlugin>(as type: T.Type) -> T? {
        activePlugin as? T
    }

    // MARK: - Session Control

    func startSession(plugin: any DisciplinePlugin) async {
        Log.tracking.info("startSession() called with plugin: \(plugin.subscriberId)")
        guard sessionState == .idle else {
            Log.tracking.warning("startSession() aborted - not in idle state")
            return
        }

        // Cancel any lingering tasks from previous sessions
        if !activeBackgroundTasks.isEmpty || postSessionSummaryTask != nil {
            Log.tracking.warning("Cancelling \(self.activeBackgroundTasks.count) lingering post-session tasks")
        }
        cancelActiveTasks()

        // Request permission if needed
        if locationManager.needsPermission {
            locationManager.requestPermission()
            try? await Task.sleep(nanoseconds: 500_000_000)
        }

        guard locationManager.hasPermission else {
            Log.tracking.warning("startSession() aborted - no location permission")
            return
        }

        // Set active plugin
        activePlugin = plugin

        // Create session model
        guard let ctx = modelContext else {
            Log.tracking.error("startSession() aborted - no modelContext")
            activePlugin = nil
            return
        }
        let sessionModel = plugin.createSessionModel(in: ctx)
        ctx.insert(sessionModel)

        // Save immediately to prevent data loss on crash
        do {
            try ctx.save()
            Log.tracking.debug("Initial session save completed")
        } catch {
            Log.tracking.error("Failed to save initial session: \(error)")
        }

        // Reset tracking state
        totalDistance = 0
        elapsedTime = 0
        currentSpeed = 0
        currentElevation = 0
        elevationGain = 0
        elevationLoss = 0
        currentHeartRate = 0
        averageHeartRate = 0
        maxHeartRate = 0
        minHeartRate = 0
        currentHeartRateZone = .zone1
        heartRateSamples = []
        gpsSignalQuality = .none
        gpsHorizontalAccuracy = -1
        currentWeather = nil
        weatherError = nil
        hasWCSessionHR = false
        startTime = Date()
        timerTickCount = 0
        sessionState = .tracking

        // Clear tracked points for fresh route display
        locationManager.clearTrackedPoints()

        // Start GPS session tracker with delegate pattern
        let gpsConfig = GPSSessionConfig(
            subscriberId: plugin.subscriberId,
            activityType: plugin.activityType,
            checkpointInterval: 30,
            modelContext: ctx,
            workoutLifecycle: workoutLifecycle
        )
        await gpsTracker.start(config: gpsConfig, delegate: self)
        Log.tracking.debug("GPS session tracker started")

        // Auto-enable family sharing if plugin supports it
        if plugin.supportsFamilySharing && !isSharingWithFamily {
            if let contacts = try? sharingCoordinator.fetchRelationships(),
               contacts.contains(where: { $0.canViewLiveTracking && $0.inviteStatus == .accepted }) {
                isSharingWithFamily = true
                Log.tracking.debug("Auto-enabled family sharing")
            }
        }

        if isSharingWithFamily && plugin.supportsFamilySharing {
            await sharingCoordinator.startSharingLocation(activityType: plugin.sharingActivityType)
        }

        // Start elapsed time timer
        startTimer()

        // Prevent screen from auto-locking
        UIApplication.shared.isIdleTimerDisabled = true

        // Start heart rate monitoring
        await healthCoordinator.startMonitoring()

        // Start workout lifecycle
        do {
            try await workoutLifecycle.startWorkout(configuration: plugin.workoutConfiguration)
            if plugin.disableAutoCalories {
                workoutLifecycle.disableAutoCalories()
            }
        } catch {
            Log.tracking.error("Failed to start workout lifecycle: \(error)")
        }

        // Start Watch status updates (1Hz)
        watchUpdateTimer?.invalidate()
        watchUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.sendStatusToWatch()
        }

        // Start fall detection if plugin uses it
        if plugin.usesFallDetection {
            fallDetectionManager.startMonitoring()
        }

        // Start Watch session for this discipline
        watchManager.startSession(discipline: plugin.watchDiscipline)

        // Fetch weather for outdoor sessions
        await fetchWeatherForSession()

        // Start audio coaching session
        audioCoach.startSession()
        audioCoach.resetSafetyStatus()

        // Notify plugin that session infrastructure is ready
        await plugin.onSessionStarted(tracker: self)

        Log.tracking.info("Session started successfully - plugin: \(plugin.subscriberId)")
    }

    func pauseSession() {
        guard sessionState == .tracking else { return }

        gpsTracker.pause()
        stopTimer()
        workoutLifecycle.pause()

        activePlugin?.onSessionPaused(tracker: self)

        sessionState = .paused
    }

    func resumeSession() {
        guard sessionState == .paused else { return }

        gpsTracker.resume()
        startTimer()
        workoutLifecycle.resume()

        activePlugin?.onSessionResumed(tracker: self)

        sessionState = .tracking
    }

    func stopSession() {
        guard sessionState == .tracking || sessionState == .paused else { return }
        guard let plugin = activePlugin else {
            Log.tracking.error("stopSession() called with nil plugin")
            return
        }

        // Request background execution time for post-session tasks
        postSessionBackgroundTaskId = UIApplication.shared.beginBackgroundTask(
            withName: "PostSessionCleanup"
        ) { [weak self] in
            guard let self else { return }
            Log.tracking.warning("Post-session background task expiring")
            do {
                try self.modelContext?.save()
            } catch {
                Log.tracking.error("Emergency save on expiration failed: \(error)")
            }
            for task in self.activeBackgroundTasks { task.cancel() }
            self.activeBackgroundTasks.removeAll()
            self.postSessionSummaryTask?.cancel()
            self.postSessionSummaryTask = nil
            if self.postSessionBackgroundTaskId != .invalid {
                UIApplication.shared.endBackgroundTask(self.postSessionBackgroundTaskId)
                self.postSessionBackgroundTaskId = .invalid
            }
        }

        // Stop GPS and timer
        gpsTracker.stop()
        stopTimer()

        // Stop fall detection
        if plugin.usesFallDetection {
            fallDetectionManager.stopMonitoring()
        }

        // End audio coaching
        audioCoach.endSession(distance: totalDistance, duration: elapsedTime)

        // Stop heart rate monitoring and get final stats
        healthCoordinator.stopMonitoring()
        watchUpdateTimer?.invalidate()
        watchUpdateTimer = nil

        // Get HealthKit enrichment from plugin
        let enrichment = plugin.onSessionStopping(tracker: self)

        // End workout lifecycle with enrichment data
        let endWorkoutTask = Task {
            if !enrichment.workoutEvents.isEmpty {
                await workoutLifecycle.addWorkoutEvents(enrichment.workoutEvents)
            }
            if !enrichment.calorieSamples.isEmpty {
                await workoutLifecycle.addSamples(enrichment.calorieSamples)
            }
            let workout = await workoutLifecycle.endAndSave(metadata: enrichment.metadata)
            if let workout {
                Log.health.info("Session saved to Apple Health: \(workout.uuid.uuidString)")
            }
            workoutLifecycle.sendIdleStateToWatch()
        }
        activeBackgroundTasks.append(endWorkoutTask)

        // Capture end weather
        if let location = locationManager.currentLocation {
            let weatherTask = Task { [modelContext] in
                do {
                    let endWeather = try await self.weatherService.fetchWeather(for: location)
                    await MainActor.run {
                        // Plugin can access end weather via onSessionCompleted
                        do {
                            try modelContext?.save()
                        } catch {
                            Log.services.error("Failed to save end weather: \(error)")
                        }
                    }
                    _ = endWeather  // Plugin handles saving to model in onSessionCompleted
                } catch {
                    Log.services.error("Failed to fetch end weather: \(error)")
                }
            }
            activeBackgroundTasks.append(weatherTask)
        }

        // Save heart rate data
        let hrStats = healthCoordinator.getFinalStatistics()
        heartRateSamples = Array(hrStats.samples)

        // Start recovery analysis if we have HR data
        if hrStats.maxBPM > 0 {
            let recoveryTask = Task {
                await healthCoordinator.startRecoveryAnalysis(peakHeartRate: hrStats.maxBPM)
            }
            activeBackgroundTasks.append(recoveryTask)
        }

        // Transfer coaching notes from live tracking session
        // (Plugin handles transferring to its model in onSessionCompleted)

        // Stop family sharing
        if isSharingWithFamily {
            let stopSharingTask = Task {
                await sharingCoordinator.stopSharingLocation()
            }
            activeBackgroundTasks.append(stopSharingTask)
        }

        // Save model context
        do {
            try modelContext?.save()
        } catch {
            Log.tracking.error("Failed to save session data: \(error)")
        }

        // Notify plugin — async post-session work
        let completionTask = Task {
            await plugin.onSessionCompleted(tracker: self)
        }
        activeBackgroundTasks.append(completionTask)

        // Log integrity report
        let diag = gpsTracker.diagnostics
        Log.tracking.info("""
            Session integrity report - plugin: \(plugin.subscriberId), \
            duration: \(Int(self.elapsedTime))s, distance: \(Int(self.totalDistance))m, \
            GPS raw: \(diag.totalRawReceived), accepted: \(diag.totalFilterAccepted), \
            rejected: \(diag.totalFilterRejected), persisted: \(diag.totalPersisted), \
            checkpoints: \(diag.checkpointCount), HR samples: \(hrStats.samples.count)
            """)

        // Re-enable screen auto-lock
        UIApplication.shared.isIdleTimerDisabled = false

        // Reset common state
        sessionState = .idle
        activePlugin = nil
        currentSpeed = 0
        currentElevation = 0
        elevationGain = 0
        elevationLoss = 0
        currentHeartRate = 0
        averageHeartRate = 0
        maxHeartRate = 0
        minHeartRate = 0
        currentHeartRateZone = .zone1
        healthCoordinator.resetState()
        currentWeather = nil
        weatherError = nil

        // Await all post-session tasks with background execution protection
        Task {
            await awaitPostSessionTasks()
        }
    }

    func discardSession() {
        guard sessionState == .tracking || sessionState == .paused else { return }
        guard let plugin = activePlugin else {
            Log.tracking.error("discardSession() called with nil plugin")
            return
        }

        // Cancel any active background tasks
        cancelActiveTasks()

        // Stop all tracking services
        gpsTracker.stop()
        stopTimer()
        if plugin.usesFallDetection {
            fallDetectionManager.stopMonitoring()
        }
        audioCoach.endSession(distance: 0, duration: 0)
        healthCoordinator.stopMonitoring()
        watchUpdateTimer?.invalidate()
        watchUpdateTimer = nil

        // Discard workout lifecycle
        let discardWorkoutTask = Task {
            await workoutLifecycle.discard()
            workoutLifecycle.sendIdleStateToWatch()
        }
        activeBackgroundTasks.append(discardWorkoutTask)

        // Notify plugin
        plugin.onSessionDiscarded(tracker: self)

        // Stop family sharing
        if isSharingWithFamily {
            let stopSharingTask = Task {
                await sharingCoordinator.stopSharingLocation()
            }
            activeBackgroundTasks.append(stopSharingTask)
        }

        // Re-enable screen auto-lock
        UIApplication.shared.isIdleTimerDisabled = false

        // Reset state
        sessionState = .idle
        activePlugin = nil
        currentSpeed = 0
        currentElevation = 0
        elevationGain = 0
        elevationLoss = 0
        currentHeartRate = 0
        averageHeartRate = 0
        maxHeartRate = 0
        minHeartRate = 0
        currentHeartRateZone = .zone1
        healthCoordinator.resetState()
        currentWeather = nil
        weatherError = nil
    }

    // MARK: - Safety Actions

    func confirmFallOK() {
        fallDetectionManager.confirmOK()
    }

    func requestEmergencyHelp() {
        fallDetectionManager.requestEmergency()
    }

    func dismissVehicleAlert() {
        showingVehicleAlert = false
        highSpeedStartTime = nil
    }

    // MARK: - Checkpoint Save

    func checkpointSave() {
        guard sessionState.isActive, modelContext != nil else { return }
        do {
            try modelContext?.save()
            Log.tracking.debug("Checkpoint save completed")
        } catch {
            Log.tracking.error("Checkpoint save failed: \(error)")
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timerSource?.cancel()

        let source = DispatchSource.makeTimerSource(queue: timerQueue)
        source.schedule(deadline: .now() + 1.0, repeating: 1.0, leeway: .milliseconds(100))
        source.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                // Sync elapsed time from GPS session tracker (wall-clock based)
                self.elapsedTime = self.gpsTracker.elapsedTime

                self.timerTickCount += 1

                // Audio coaching for milestones
                self.audioCoach.processTime(self.elapsedTime)
                self.audioCoach.processDistance(self.totalDistance)

                // Periodic safety status announcement
                self.audioCoach.processSafetyStatus(
                    elapsedTime: self.elapsedTime,
                    fallDetectionActive: self.fallDetectionManager.isMonitoring
                )

                // HR fallback: use HKWorkoutBuilder HR when companion HR isn't flowing
                if !self.hasWCSessionHR {
                    let lifecycleHR = Int(self.workoutLifecycle.liveHeartRate)
                    if lifecycleHR > 0 {
                        self.handleHeartRateUpdate(lifecycleHR)
                    }
                }

                // Session health log every 30s
                if self.timerTickCount % 30 == 0 {
                    let diag = self.gpsTracker.diagnostics
                    Log.tracking.info("""
                        Session health - elapsed: \(Int(self.elapsedTime))s, \
                        distance: \(Int(self.totalDistance))m, \
                        GPS persisted: \(diag.totalPersisted), \
                        HR source: \(self.hasWCSessionHR ? "WCSession" : "WorkoutLifecycle"), \
                        HR: \(self.currentHeartRate) bpm
                        """)
                }

                // Notify plugin
                self.activePlugin?.onTimerTick(elapsedTime: self.elapsedTime, tracker: self)
            }
        }
        source.resume()
        timerSource = source
    }

    private func stopTimer() {
        timerSource?.cancel()
        timerSource = nil
    }

    // MARK: - Heart Rate

    func handleHeartRateUpdate(_ bpm: Int) {
        guard sessionState == .tracking else { return }

        healthCoordinator.processHeartRate(bpm)

        currentHeartRate = healthCoordinator.currentHeartRate
        currentHeartRateZone = healthCoordinator.currentZone
        averageHeartRate = healthCoordinator.averageHeartRate
        maxHeartRate = healthCoordinator.maxHeartRate

        activePlugin?.onHeartRateUpdate(bpm: bpm, tracker: self)
    }

    // MARK: - Watch Observation

    private func startWatchObservation() {
        watchManager.activate()

        // Observe commands
        watchCommandTask = Task { @MainActor [weak self] in
            let wm = WatchConnectivityManager.shared
            var lastSeq = wm.commandSequence
            while !Task.isCancelled {
                await withCheckedContinuation { cont in
                    withObservationTracking { _ = wm.commandSequence }
                        onChange: { cont.resume() }
                }
                guard let self, !Task.isCancelled else { break }
                guard wm.commandSequence != lastSeq else { continue }
                lastSeq = wm.commandSequence
                guard let command = wm.lastReceivedCommand else { continue }

                // Forward to plugin if active
                if let plugin = self.activePlugin {
                    plugin.handleWatchCommand(command, tracker: self)
                }

                // Handle common commands
                switch command {
                case .requestStatus:
                    self.sendStatusToWatch()
                default:
                    break
                }
            }
        }

        // Observe heart rate
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
                let hr = wm.lastReceivedHeartRate
                guard hr > 0 else { continue }
                self.hasWCSessionHR = true
                self.handleHeartRateUpdate(hr)
            }
        }

        // Observe voice notes
        watchVoiceNoteTask = Task { @MainActor [weak self] in
            let wm = WatchConnectivityManager.shared
            var lastSeq = wm.voiceNoteSequence
            while !Task.isCancelled {
                await withCheckedContinuation { cont in
                    withObservationTracking { _ = wm.voiceNoteSequence }
                        onChange: { cont.resume() }
                }
                guard let self, !Task.isCancelled else { break }
                guard wm.voiceNoteSequence != lastSeq else { continue }
                lastSeq = wm.voiceNoteSequence
                // Voice note handling is discipline-specific — plugin handles via onSessionStarted hooks
            }
        }
    }

    private func stopWatchObservation() {
        watchCommandTask?.cancel()
        watchCommandTask = nil
        watchHeartRateTask?.cancel()
        watchHeartRateTask = nil
        watchVoiceNoteTask?.cancel()
        watchVoiceNoteTask = nil
        watchUpdateTimer?.invalidate()
        watchUpdateTimer = nil
        watchManager.endSession()
    }

    // MARK: - Watch Status

    private func sendStatusToWatch() {
        guard let plugin = activePlugin else { return }
        let state: SharedRideState = sessionState == .tracking ? .tracking : .idle
        let fields = plugin.watchStatusFields(tracker: self)

        watchManager.sendStatusUpdate(
            rideState: state,
            duration: elapsedTime,
            distance: totalDistance,
            speed: currentSpeed,
            gait: plugin.currentGaitType(speed: currentSpeed).rawValue,
            heartRate: currentHeartRate > 0 ? currentHeartRate : nil,
            heartRateZone: currentHeartRateZone.rawValue,
            averageHeartRate: averageHeartRate > 0 ? averageHeartRate : nil,
            maxHeartRate: maxHeartRate > 0 ? maxHeartRate : nil,
            horseName: fields.horseName,
            rideType: fields.rideType,
            walkPercent: fields.walkPercent,
            trotPercent: fields.trotPercent,
            canterPercent: fields.canterPercent,
            gallopPercent: fields.gallopPercent,
            leftTurnCount: nil,
            rightTurnCount: nil,
            leftReinPercent: fields.leftReinPercent,
            rightReinPercent: fields.rightReinPercent,
            leftLeadPercent: fields.leftLeadPercent,
            rightLeadPercent: fields.rightLeadPercent,
            symmetryScore: fields.symmetryScore,
            rhythmScore: fields.rhythmScore,
            optimalTime: fields.optimalTime,
            timeDifference: fields.timeDifference,
            elevation: fields.elevation
        )
    }

    // MARK: - Health Coordinator Setup

    private func setupHealthCoordinator() {
        healthCoordinator.onHeartRateZoneChanged = { [weak self] newZone in
            guard let self else { return }
            self.audioCoach.processHeartRateZone(newZone)
        }
    }

    // MARK: - Fall Detection Setup

    private func setupFallDetection() {
        fallDetectionManager.onFallDetected = { [weak self] in
            guard let self else { return }
            self.fallDetected = true
            self.showingFallAlert = true
            self.onFallDetected?()
        }

        fallDetectionManager.onCountdownTick = { [weak self] seconds in
            guard let self else { return }
            self.fallAlertCountdown = seconds
            self.onFallCountdownTick?(seconds)
        }

        fallDetectionManager.onEmergencyAlert = { [weak self] location in
            guard let self else { return }
            self.onEmergencyAlert?(location)
        }

        fallDetectionManager.onFallDismissed = { [weak self] in
            guard let self else { return }
            self.fallDetected = false
            self.showingFallAlert = false
            self.fallAlertCountdown = 30
        }
    }

    // MARK: - Vehicle Detection

    func checkForVehicleSpeed(_ speed: Double) {
        guard activePlugin?.usesVehicleDetection == true else { return }

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

    // MARK: - Family Sharing

    func updateFamilySharing(location: CLLocation) async {
        guard let plugin = activePlugin, plugin.supportsFamilySharing else { return }

        // Throttle updates to every 10 seconds
        if let lastUpdate = lastFamilyUpdateTime,
           Date().timeIntervalSince(lastUpdate) < 10 {
            return
        }
        lastFamilyUpdateTime = Date()

        let gait = plugin.currentGaitType(speed: currentSpeed)
        await sharingCoordinator.updateSharedLocation(
            location: location,
            gait: gait,
            distance: totalDistance,
            duration: elapsedTime
        )
    }

    // MARK: - Weather

    private func fetchWeatherForSession() async {
        guard let location = locationManager.currentLocation else {
            weatherError = "Location not available"
            return
        }

        do {
            let weather = try await weatherService.fetchWeather(for: location)
            guard weather.temperature != 0 || weather.humidity != 0 else {
                weatherError = "Invalid weather data received"
                return
            }
            currentWeather = weather
            weatherError = nil
            Log.services.info("Weather fetched: \(weather.temperature)°C, \(weather.condition)")
        } catch {
            weatherError = error.localizedDescription
            Log.services.error("Failed to fetch weather: \(error)")
        }
    }

    // MARK: - Background Task Management

    private func cancelActiveTasks() {
        for task in activeBackgroundTasks {
            task.cancel()
        }
        activeBackgroundTasks.removeAll()
        familySharingTask?.cancel()
        familySharingTask = nil
        postSessionSummaryTask?.cancel()
        postSessionSummaryTask = nil

        if postSessionBackgroundTaskId != .invalid {
            let taskId = postSessionBackgroundTaskId
            DispatchQueue.main.async {
                UIApplication.shared.endBackgroundTask(taskId)
            }
            postSessionBackgroundTaskId = .invalid
        }
    }

    private func awaitPostSessionTasks() async {
        for task in activeBackgroundTasks {
            await task.value
        }
        activeBackgroundTasks.removeAll()

        if let summaryTask = postSessionSummaryTask {
            await summaryTask.value
            postSessionSummaryTask = nil
        }

        let taskId = postSessionBackgroundTaskId
        if taskId != .invalid {
            DispatchQueue.main.async {
                UIApplication.shared.endBackgroundTask(taskId)
            }
            postSessionBackgroundTaskId = .invalid
        }
        Log.tracking.info("All post-session tasks completed")
    }
}

// MARK: - GPSSessionDelegate

extension SessionTracker: GPSSessionDelegate {
    func createLocationPoint(from location: CLLocation) -> (any PersistentModel)? {
        guard let plugin = activePlugin else {
            Log.tracking.error("GPS delegate: createLocationPoint called with nil plugin")
            return nil
        }
        let point = plugin.createLocationPoint(from: location)
        if point == nil {
            Log.tracking.error("GPS delegate: plugin returned nil location point")
        }
        return point
    }

    func didProcessLocation(_ location: CLLocation, distanceDelta: Double, tracker: GPSSessionTracker) {
        guard sessionState == .tracking else { return }

        // Sync common GPS state from tracker
        totalDistance = tracker.totalDistance
        currentSpeed = tracker.currentSpeed
        currentElevation = tracker.currentElevation
        elevationGain = tracker.elevationGain
        elevationLoss = tracker.elevationLoss
        gpsHorizontalAccuracy = tracker.gpsHorizontalAccuracy
        gpsSignalQuality = tracker.gpsSignalQuality

        // Vehicle detection
        if activePlugin?.usesVehicleDetection == true {
            checkForVehicleSpeed(currentSpeed)
        }

        // Fall detection update
        if activePlugin?.usesFallDetection == true {
            fallDetectionManager.updateLocation(location.coordinate)
        }

        // Family sharing (throttled)
        if isSharingWithFamily {
            familySharingTask?.cancel()
            familySharingTask = Task {
                await updateFamilySharing(location: location)
            }
        }

        // Forward to plugin
        if let plugin = activePlugin {
            plugin.onLocationProcessed(location, distanceDelta: distanceDelta, tracker: self)
        } else {
            Log.tracking.warning("didProcessLocation: activePlugin is nil")
        }
    }
}
