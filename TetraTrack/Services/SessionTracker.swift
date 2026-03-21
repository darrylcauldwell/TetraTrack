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

    // MARK: - Pedometer

    var pedometerCadence: Int = 0
    var pedometerFloorsAscended: Int = 0
    var pedometerFloorsDescended: Int = 0

    // MARK: - Activity Classification

    var currentActivityClassification: ActivityClassification?

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

    // MARK: - Post-Session

    /// Info captured at session end for post-session insights navigation
    struct CompletedSessionInfo {
        let disciplineType: String  // Plugin subscriberId for dispatch
        let modelID: PersistentIdentifier
    }

    var completedSessionInfo: CompletedSessionInfo?

    // MARK: - Active Plugin

    private(set) var activePlugin: (any DisciplinePlugin)?
    private(set) var currentSessionModel: (any SessionWritable)?

    // Fall detection callbacks
    var onFallDetected: (() -> Void)?
    var onFallCountdownTick: ((Int) -> Void)?
    var onEmergencyAlert: ((CLLocationCoordinate2D?) -> Void)?

    // MARK: - Dependencies (internal for plugin access)

    let locationManager: LocationManager
    let gpsTracker: GPSSessionTracker
    let healthCoordinator = HealthCoordinator()
    private let watchManager = WatchConnectivityManager.shared
    private let workoutLifecycle = WorkoutLifecycleService.shared
    private let activityClassifier = ActivityClassificationService.shared

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

    // Wall-clock timer state for non-GPS disciplines
    private var pausedAccumulated: TimeInterval = 0
    private var lastPauseDate: Date?

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
        setupMirroredSessionCallback()
    }

    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        fallDetectionManager.configure(modelContext: modelContext, heartRateService: HeartRateService())
    }

    func configure(riderProfile: RiderProfile?) {
        if let profile = riderProfile {
            healthCoordinator.configure(maxHeartRate: profile.maxHeartRate, restingHeartRate: profile.restingHeartRate)
        }
    }

    // MARK: - Mirrored Session Support

    /// Wire the callback so autonomous Watch workouts create a plugin on iPhone.
    private func setupMirroredSessionCallback() {
        workoutLifecycle.onAutonomousMirroredSession = { [weak self] activityType, watchStartDate in
            guard let self else { return }
            Task { @MainActor in
                await self.startSessionFromMirroredWorkout(activityType: activityType, startDate: watchStartDate)
            }
        }
    }

    /// Create a default plugin for a Watch-initiated mirrored workout.
    private func createDefaultPlugin(for activityType: HKWorkoutActivityType) -> (any DisciplinePlugin)? {
        switch activityType {
        case .equestrianSports: RidingPlugin()
        case .running: RunningPlugin(session: RunningSession())
        case .walking: WalkingPlugin(session: RunningSession(), selectedRoute: nil, targetCadence: 0)
        case .swimming: SwimmingPlugin(session: SwimmingSession())
        case .archery: ShootingPlugin(sessionContext: .freePractice)
        default: nil
        }
    }

    /// Start a full session in response to an autonomous mirrored workout from Watch.
    /// Reuses startSession() logic but skips requestWatchWorkout() since Watch already
    /// owns the workout session.
    /// - Parameter startDate: The Watch's workout start time for elapsed time sync.
    func startSessionFromMirroredWorkout(activityType: HKWorkoutActivityType, startDate: Date) async {
        guard sessionState == .idle else {
            Log.tracking.warning("startSessionFromMirroredWorkout: not idle, ignoring")
            return
        }

        guard let plugin = createDefaultPlugin(for: activityType) else {
            Log.tracking.error("startSessionFromMirroredWorkout: no plugin for activityType \(activityType.rawValue)")
            return
        }

        Log.tracking.info("startSessionFromMirroredWorkout: starting with \(plugin.subscriberId)")

        // Cancel any lingering tasks
        cancelActiveTasks()

        // Request location permission for GPS disciplines
        if plugin.usesGPS {
            if locationManager.needsPermission {
                locationManager.requestPermission()
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            guard locationManager.hasPermission else {
                Log.tracking.warning("startSessionFromMirroredWorkout: no location permission")
                return
            }
        }

        // Set active plugin
        activePlugin = plugin

        // Create session model
        guard let ctx = modelContext else {
            Log.tracking.error("startSessionFromMirroredWorkout: no modelContext")
            activePlugin = nil
            return
        }
        let sessionModel = plugin.createSessionModel(in: ctx)
        currentSessionModel = sessionModel
        ctx.insert(sessionModel)

        do {
            try ctx.save()
        } catch {
            Log.tracking.error("startSessionFromMirroredWorkout: failed to save initial session: \(error)")
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
        startTime = startDate
        timerTickCount = 0
        pausedAccumulated = 0
        lastPauseDate = nil
        sessionState = .tracking

        // Start GPS if discipline uses it
        if plugin.usesGPS {
            locationManager.clearTrackedPoints()
            let gpsConfig = GPSSessionConfig(
                subscriberId: plugin.subscriberId,
                activityType: plugin.activityType,
                checkpointInterval: 30,
                modelContext: ctx,
                workoutLifecycle: workoutLifecycle
            )
            await gpsTracker.start(config: gpsConfig, delegate: self)
            gpsTracker.setStartTime(startDate)
        }

        // Family sharing
        if plugin.supportsFamilySharing && !isSharingWithFamily {
            if let contacts = try? sharingCoordinator.fetchRelationships(),
               contacts.contains(where: { $0.canViewLiveTracking && $0.inviteStatus == .accepted }) {
                isSharingWithFamily = true
            }
        }
        if isSharingWithFamily && plugin.supportsFamilySharing {
            await sharingCoordinator.startSharingLocation(activityType: plugin.sharingActivityType)
        }

        // Start timer, prevent screen lock
        startTimer()
        UIApplication.shared.isIdleTimerDisabled = true

        // NOTE: Skip requestWatchWorkout() — Watch already owns the workout session.
        // WorkoutLifecycleService state is already configured by setupMirroringHandler().

        // Watch status updates (1Hz)
        watchUpdateTimer?.invalidate()
        watchUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.sendStatusToWatch()
        }

        // Fall detection
        if plugin.usesFallDetection {
            fallDetectionManager.startMonitoring()
        }

        // Activity classification
        activityClassifier.startMonitoring()

        // Watch session
        watchManager.startSession(discipline: plugin.watchDiscipline)

        // Weather
        if plugin.usesGPS {
            await fetchWeatherForSession()
        }

        // Audio coaching
        audioCoach.startSession()
        audioCoach.resetSafetyStatus()

        // Notify plugin
        await plugin.onSessionStarted(tracker: self)

        Log.tracking.info("startSessionFromMirroredWorkout: session started — \(plugin.subscriberId)")
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

        // Request location permission only for GPS disciplines
        if plugin.usesGPS {
            if locationManager.needsPermission {
                locationManager.requestPermission()
                try? await Task.sleep(nanoseconds: 500_000_000)
            }

            guard locationManager.hasPermission else {
                Log.tracking.warning("startSession() aborted - no location permission")
                return
            }
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
        currentSessionModel = sessionModel
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
        startTime = Date()
        timerTickCount = 0
        pausedAccumulated = 0
        lastPauseDate = nil
        sessionState = .tracking

        // Start GPS if discipline uses it
        if plugin.usesGPS {
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
        }

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

        // Start workout lifecycle — prefer Watch-primary, fall back to iPhone only
        // when Watch is genuinely unavailable (not on transient failures).
        do {
            try await workoutLifecycle.requestWatchWorkout(configuration: plugin.workoutConfiguration)
            // disableAutoCalories not needed — builder runs on Watch.
            // Start-time correction is no longer needed — Watch sends authoritative
            // elapsed time at 1Hz via mirrored session (watchElapsedTime).
        } catch {
            Log.tracking.error("TT: Watch unavailable, falling back to iPhone-primary workout: \(error)")
            do {
                try await workoutLifecycle.startWorkoutFallback(configuration: plugin.workoutConfiguration)
                if plugin.disableAutoCalories {
                    workoutLifecycle.disableAutoCalories()
                }
            } catch {
                Log.tracking.error("Failed to start workout lifecycle: \(error)")
            }
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

        // Start activity classification (negligible battery cost)
        activityClassifier.startMonitoring()

        // Start Watch session for this discipline
        watchManager.startSession(discipline: plugin.watchDiscipline)

        // Fetch weather for outdoor sessions (only if GPS/outdoor)
        if plugin.usesGPS {
            await fetchWeatherForSession()
        }

        // Start audio coaching session
        audioCoach.startSession()
        audioCoach.resetSafetyStatus()

        // Notify plugin that session infrastructure is ready
        await plugin.onSessionStarted(tracker: self)

        Log.tracking.info("Session started successfully - plugin: \(plugin.subscriberId)")
    }

    func pauseSession() {
        guard sessionState == .tracking else { return }

        if activePlugin?.usesGPS == true {
            gpsTracker.pause()
        } else {
            lastPauseDate = Date()
        }
        stopTimer()
        workoutLifecycle.pause()

        activePlugin?.onSessionPaused(tracker: self)

        sessionState = .paused
    }

    func resumeSession() {
        guard sessionState == .paused else { return }

        if activePlugin?.usesGPS == true {
            gpsTracker.resume()
        } else if let pauseDate = lastPauseDate {
            pausedAccumulated += Date().timeIntervalSince(pauseDate)
            lastPauseDate = nil
        }
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

        // Stop GPS (if used) and timer
        if plugin.usesGPS {
            gpsTracker.stop()
        }
        stopTimer()

        // Stop fall detection
        if plugin.usesFallDetection {
            fallDetectionManager.stopMonitoring()
        }

        // Stop activity classification
        activityClassifier.stopMonitoring()

        // End audio coaching
        audioCoach.endSession(distance: totalDistance, duration: elapsedTime)

        // Stop watch status updates
        watchUpdateTimer?.invalidate()
        watchUpdateTimer = nil

        // Write common fields to session model before plugin gets a chance to override
        let hrStats = healthCoordinator.getFinalStatistics()
        if let model = currentSessionModel {
            model.endDate = Date()
            model.totalDistance = totalDistance
            model.totalDuration = elapsedTime
            model.averageHeartRate = hrStats.averageBPM
            model.maxHeartRate = hrStats.maxBPM
            model.minHeartRate = hrStats.minBPM
            model.heartRateSamplesData = try? JSONEncoder().encode(Array(hrStats.samples))
        }

        // Get HealthKit enrichment from plugin (can override common fields)
        let enrichment = plugin.onSessionStopping(tracker: self)

        // End workout lifecycle with enrichment data
        let endWorkoutTask = Task { [weak self] in
            guard let self else { return }
            if !enrichment.workoutEvents.isEmpty {
                await self.workoutLifecycle.addWorkoutEvents(enrichment.workoutEvents)
            }
            if !enrichment.calorieSamples.isEmpty {
                await self.workoutLifecycle.addSamples(enrichment.calorieSamples)
            }
            let workout = await self.workoutLifecycle.endAndSave(metadata: enrichment.metadata)
            if let workout {
                self.currentSessionModel?.healthKitWorkoutUUID = workout.uuid.uuidString
                Log.health.info("Session saved to Apple Health: \(workout.uuid.uuidString)")
            }
            self.workoutLifecycle.sendIdleStateToWatch()
        }
        activeBackgroundTasks.append(endWorkoutTask)

        // Capture end weather
        if let location = locationManager.currentLocation {
            let weatherTask = Task { [weak self] in
                guard let self else { return }
                do {
                    let endWeather = try await self.weatherService.fetchWeather(for: location)
                    await MainActor.run {
                        // save() removed — stopSession() owns the final save
                    }
                    _ = endWeather  // Plugin handles saving to model in onSessionCompleted
                } catch {
                    Log.services.error("Failed to fetch end weather: \(error)")
                }
            }
            activeBackgroundTasks.append(weatherTask)
        }

        // Save heart rate samples for local display
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

        // Capture completed session info before clearing plugin/model
        if let model = currentSessionModel {
            completedSessionInfo = CompletedSessionInfo(
                disciplineType: plugin.subscriberId,
                modelID: model.persistentModelID
            )
        }

        // Reset common state — transition to .completed so ContentView shows insights
        sessionState = .completed
        activePlugin = nil
        currentSessionModel = nil
        currentSpeed = 0
        currentElevation = 0
        elevationGain = 0
        elevationLoss = 0
        pedometerCadence = 0
        pedometerFloorsAscended = 0
        pedometerFloorsDescended = 0
        currentActivityClassification = nil
        currentHeartRate = 0
        averageHeartRate = 0
        maxHeartRate = 0
        minHeartRate = 0
        currentHeartRateZone = .zone1
        healthCoordinator.resetState()
        currentWeather = nil
        weatherError = nil
        pausedAccumulated = 0
        lastPauseDate = nil

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
        if plugin.usesGPS {
            gpsTracker.stop()
        }
        stopTimer()
        if plugin.usesFallDetection {
            fallDetectionManager.stopMonitoring()
        }
        activityClassifier.stopMonitoring()
        audioCoach.endSession(distance: 0, duration: 0)
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

        // Delete session model if present
        if let model = currentSessionModel {
            modelContext?.delete(model)
            do {
                try modelContext?.save()
            } catch {
                Log.tracking.error("Failed to delete discarded session model: \(error)")
            }
        }

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
        currentSessionModel = nil
        currentSpeed = 0
        currentElevation = 0
        elevationGain = 0
        elevationLoss = 0
        pedometerCadence = 0
        pedometerFloorsAscended = 0
        pedometerFloorsDescended = 0
        currentActivityClassification = nil
        currentHeartRate = 0
        averageHeartRate = 0
        maxHeartRate = 0
        minHeartRate = 0
        currentHeartRateZone = .zone1
        healthCoordinator.resetState()
        currentWeather = nil
        weatherError = nil
        pausedAccumulated = 0
        lastPauseDate = nil
    }

    // MARK: - Post-Session Dismiss

    func dismissPostSession() {
        completedSessionInfo = nil
        sessionState = .idle
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

                // Elapsed time: Watch-authoritative, GPS-based, or wall-clock based
                if self.workoutLifecycle.isWatchPrimary && self.workoutLifecycle.watchElapsedTime > 0 {
                    // Watch sends authoritative elapsed time at 1Hz via mirrored session
                    self.elapsedTime = self.workoutLifecycle.watchElapsedTime
                } else if self.activePlugin?.usesGPS == true {
                    self.elapsedTime = self.gpsTracker.elapsedTime
                } else {
                    guard let start = self.startTime else { return }
                    self.elapsedTime = Date().timeIntervalSince(start) - self.pausedAccumulated
                }

                self.timerTickCount += 1

                // Sync pedometer metrics from GPS tracker
                if self.activePlugin?.usesGPS == true {
                    self.pedometerCadence = self.gpsTracker.pedometerCadence
                    self.pedometerFloorsAscended = self.gpsTracker.pedometerFloorsAscended
                    self.pedometerFloorsDescended = self.gpsTracker.pedometerFloorsDescended
                }

                // Sync activity classification
                self.currentActivityClassification = self.activityClassifier.currentActivity

                // Audio coaching for milestones
                self.audioCoach.processTime(self.elapsedTime)
                self.audioCoach.processDistance(self.totalDistance)

                // Periodic safety status announcement
                self.audioCoach.processSafetyStatus(
                    elapsedTime: self.elapsedTime,
                    fallDetectionActive: self.fallDetectionManager.isMonitoring
                )

                // Session health log every 30s
                if self.timerTickCount % 30 == 0 {
                    let hr = self.currentHeartRate
                    if self.activePlugin?.usesGPS == true {
                        let diag = self.gpsTracker.diagnostics
                        Log.tracking.info("""
                            Session health - elapsed: \(Int(self.elapsedTime))s, \
                            distance: \(Int(self.totalDistance))m, \
                            GPS persisted: \(diag.totalPersisted), \
                            HR: \(hr) bpm
                            """)
                    } else {
                        Log.tracking.info("""
                            Session health - elapsed: \(Int(self.elapsedTime))s, \
                            HR: \(hr) bpm
                            """)
                    }
                }

                // Heart rate arrives via Watch relay:
                // Watch-primary: mirrored session → updateFromMirroredHeartRate() → heartRateSequence
                // Fallback: WCSession → heartRateUpdate → heartRateSequence
                // Both paths increment heartRateSequence → startWatchHeartRateObservation()
                //   fires → handleHeartRateUpdate()
                // The builder's liveHeartRate is also checked as a fallback for iPhone-only mode
                // (e.g., BLE chest strap without Watch)
                if !self.workoutLifecycle.isWatchPrimary {
                    let builderHR = self.workoutLifecycle.liveHeartRate
                    if builderHR > 0 {
                        self.handleHeartRateUpdate(builderHR)
                    }
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
        guard sessionState == .tracking else {
            Log.tracking.info("handleHeartRateUpdate: dropped HR \(bpm) bpm — sessionState is \(String(describing: self.sessionState))")
            return
        }
        Log.tracking.info("handleHeartRateUpdate: processing HR \(bpm) bpm")

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
        startWatchHeartRateObservation()

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

    /// Start (or restart) the Watch heart rate observation task.
    /// Called by `startWatchObservation()` to begin heart rate monitoring.
    private func startWatchHeartRateObservation() {
        watchHeartRateTask?.cancel()
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
                Log.tracking.info("startWatchHeartRateObservation: seq=\(lastSeq), hr=\(hr)")
                guard hr > 0 else { continue }
                self.handleHeartRateUpdate(hr)
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

        // Fast path: activity classifier detects vehicle before speed threshold
        if let activity = currentActivityClassification, activity.isInVehicle {
            if !showingVehicleAlert {
                showingVehicleAlert = true
                audioCoach.announce("It looks like you may be in a vehicle. Would you like to stop tracking?")
            }
            return
        }

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
            UIApplication.shared.endBackgroundTask(postSessionBackgroundTaskId)
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

        if postSessionBackgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(postSessionBackgroundTaskId)
            postSessionBackgroundTaskId = .invalid
        }
        Log.tracking.info("All post-session tasks completed")
    }
}

// MARK: - GPSSessionDelegate

extension SessionTracker: GPSSessionDelegate {
    func createLocationPoint(from location: CLLocation) -> GPSPoint? {
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
