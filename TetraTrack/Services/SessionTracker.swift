//
//  SessionTracker.swift
//  TetraTrack
//
//  Unified session lifecycle manager for all disciplines.
//  Common concerns (timer, HR, Watch, GPS sync, family sharing,
//  HealthKit, background tasks, checkpoint saves) live here.
//  Discipline-specific logic lives in DisciplinePlugin implementations.
//

import SwiftData
import CoreLocation
import HealthKit
import Observation
import UIKit
import os

@Observable
final class SessionTracker {
    // MARK: - Common State

    var sessionState: SessionState = .idle
    var activeDiscipline: Discipline?
    var elapsedTime: TimeInterval = 0
    var totalDistance: Double = 0
    var currentSpeed: Double = 0
    var currentElevation: Double = 0
    var elevationGain: Double = 0
    var elevationLoss: Double = 0
    var gpsSignalQuality: GPSSignalQuality = .none
    var gpsHorizontalAccuracy: Double = -1

    // Heart rate (centralised)
    var currentHeartRate: Int = 0
    var averageHeartRate: Int = 0
    var maxHeartRate: Int = 0
    var minHeartRate: Int = Int.max
    var currentHeartRateZone: HeartRateZone = .zone1

    // Family sharing
    var isSharingWithFamily: Bool = false

    // Weather
    var currentWeather: WeatherConditions?
    var weatherError: String?

    // MARK: - Typed Plugin Access (for view observation)

    private(set) var ridingState: RidingPlugin?
    // Future: runningState, swimmingState, walkingState

    // MARK: - Dependencies

    let locationManager: LocationManager
    let gpsTracker: GPSSessionTracker
    let workoutLifecycle = WorkoutLifecycleService.shared
    let watchManager = WatchConnectivityManager.shared
    let audioCoach = AudioCoachManager.shared
    let sharingCoordinator = UnifiedSharingCoordinator.shared

    // MARK: - Internal

    private(set) var _plugin: (any DisciplinePlugin)?
    private var healthCoordinator = RideHealthCoordinator()
    private var timerSource: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "dev.dreamfold.tetratrack.sessionTimer", qos: .userInitiated)
    private var timerTickCount: Int = 0
    private var watchHRTask: Task<Void, Never>?
    private var watchCommandTask: Task<Void, Never>?
    private var watchVoiceNoteTask: Task<Void, Never>?
    private var watchUpdateTimer: Timer?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private(set) var modelContext: ModelContext?
    private var familySharingTask: Task<Void, Never>?
    private var lastFamilyUpdateTime: Date?
    private var activeBackgroundTasks: [Task<Void, Never>] = []
    private var postSessionSummaryTask: Task<Void, Never>?
    private var postSessionBackgroundTaskId: UIBackgroundTaskIdentifier = .invalid

    // MARK: - Init

    convenience init(locationManager: LocationManager, gpsTracker: GPSSessionTracker) {
        self.init(
            locationManager: locationManager,
            gpsTracker: gpsTracker,
            healthCoordinator: RideHealthCoordinator()
        )
    }

    init(
        locationManager: LocationManager,
        gpsTracker: GPSSessionTracker,
        healthCoordinator: RideHealthCoordinator
    ) {
        self.locationManager = locationManager
        self.gpsTracker = gpsTracker
        self.healthCoordinator = healthCoordinator
        startWatchObservation()
        setupHealthCoordinator()
    }

    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func configure(riderProfile: RiderProfile?) {
        healthCoordinator.configure(riderProfile: riderProfile)
    }

    // MARK: - Session Control

    func start(plugin: any DisciplinePlugin) async {
        guard sessionState == .idle else {
            Log.tracking.warning("start() aborted - not in idle state")
            return
        }

        // Cancel any lingering tasks from previous sessions
        cancelActiveTasks()

        // Request location permission if needed
        if locationManager.needsPermission {
            locationManager.requestPermission()
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        guard locationManager.hasPermission else {
            Log.tracking.warning("start() aborted - no location permission")
            return
        }

        // Store plugin
        _plugin = plugin
        activeDiscipline = plugin.discipline

        // Set typed state for view observation
        if let riding = plugin as? RidingPlugin {
            ridingState = riding
        }

        // Configure plugin (creates session model, sets up analyzers)
        await plugin.configure(tracker: self)

        // Setup GPS callbacks
        setupLocationCallback()

        // Clear tracked points for fresh route display
        locationManager.clearTrackedPoints()

        // Reset common state
        totalDistance = 0
        elapsedTime = 0
        currentSpeed = 0
        currentElevation = 0
        elevationGain = 0
        elevationLoss = 0
        currentHeartRate = 0
        averageHeartRate = 0
        maxHeartRate = 0
        minHeartRate = Int.max
        currentHeartRateZone = .zone1
        timerTickCount = 0
        sessionState = .tracking

        // Determine GPS activity type from discipline
        let activityType: GPSActivityType
        switch plugin.discipline {
        case .riding: activityType = .riding
        case .running: activityType = .running
        case .swimming: activityType = .swimming
        default: activityType = .walking
        }

        // Start GPS session tracker
        if plugin.needsGPS {
            await gpsTracker.start(
                subscriberId: plugin.discipline.rawValue.lowercased(),
                activityType: activityType,
                modelContext: modelContext,
                workoutLifecycle: workoutLifecycle
            )
        }

        // Auto-enable family sharing if contacts have live tracking permission
        if !isSharingWithFamily {
            if let contacts = try? sharingCoordinator.fetchRelationships(),
               contacts.contains(where: { $0.canViewLiveTracking && $0.inviteStatus == .accepted }) {
                isSharingWithFamily = true
            }
        }

        // Start family sharing
        if isSharingWithFamily {
            await sharingCoordinator.startSharingLocation(activityType: plugin.discipline.rawValue.lowercased())
        }

        // Start timer
        startTimer()

        // Prevent screen auto-lock
        await MainActor.run { UIApplication.shared.isIdleTimerDisabled = true }

        // Start health monitoring
        await healthCoordinator.startMonitoring()

        // Start workout lifecycle
        do {
            try await workoutLifecycle.startWorkout(configuration: plugin.workoutConfig)
        } catch {
            Log.tracking.error("Failed to start workout lifecycle: \(error)")
        }

        // Start Watch status updates (1Hz)
        watchUpdateTimer?.invalidate()
        watchUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.sendStatusToWatch()
        }

        // Start audio coaching session
        audioCoach.startSession()

        // Notify plugin that everything is started
        await plugin.didStart()

        Log.tracking.info("\(plugin.discipline.rawValue) session started")
    }

    func pause() {
        guard sessionState == .tracking else { return }

        gpsTracker.pause()
        stopTimer()
        workoutLifecycle.pause()
        _plugin?.willPause()

        sessionState = .paused
    }

    func resume() {
        guard sessionState == .paused else { return }

        gpsTracker.resume()
        startTimer()
        workoutLifecycle.resume()
        _plugin?.didResume()

        sessionState = .tracking
    }

    func stop() {
        guard sessionState == .tracking || sessionState == .paused else { return }

        // Request background execution time
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

        // Stop common services
        gpsTracker.stop()
        stopTimer()
        healthCoordinator.stopMonitoring()
        watchUpdateTimer?.invalidate()
        watchUpdateTimer = nil
        audioCoach.endSession(distance: totalDistance, duration: elapsedTime)

        // Finalize plugin
        if let plugin = _plugin {
            let finalizeTask = Task {
                await plugin.finalize()
            }
            activeBackgroundTasks.append(finalizeTask)

            // Build HealthKit enrichment from plugin
            let endWorkoutTask = Task {
                let enrichment = await plugin.buildHealthKitEnrichment()
                if !enrichment.events.isEmpty {
                    await workoutLifecycle.addWorkoutEvents(enrichment.events)
                }
                if !enrichment.samples.isEmpty {
                    await workoutLifecycle.addSamples(enrichment.samples)
                }
                let workout = await workoutLifecycle.endAndSave(metadata: enrichment.metadata)
                if let workout {
                    Log.health.info("Session saved to Apple Health: \(workout.uuid.uuidString)")
                }
                workoutLifecycle.sendIdleStateToWatch()
            }
            activeBackgroundTasks.append(endWorkoutTask)
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
        activeDiscipline = nil
        ridingState = nil
        _plugin = nil
        currentSpeed = 0
        currentElevation = 0
        elevationGain = 0
        elevationLoss = 0
        currentHeartRate = 0
        averageHeartRate = 0
        maxHeartRate = 0
        minHeartRate = Int.max
        currentHeartRateZone = .zone1
        currentWeather = nil
        weatherError = nil
        healthCoordinator.resetState()

        // Await post-session tasks in background
        Task {
            await awaitPostSessionTasks()
        }
    }

    func discard() {
        guard sessionState == .tracking || sessionState == .paused else { return }

        cancelActiveTasks()

        gpsTracker.stop()
        stopTimer()
        healthCoordinator.stopMonitoring()
        audioCoach.endSession(distance: 0, duration: 0)
        watchUpdateTimer?.invalidate()
        watchUpdateTimer = nil

        // Discard workout lifecycle
        let discardWorkoutTask = Task {
            await workoutLifecycle.discard()
            workoutLifecycle.sendIdleStateToWatch()
        }
        activeBackgroundTasks.append(discardWorkoutTask)

        // Plugin-specific cleanup is handled by reset
        _plugin?.reset()

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
        activeDiscipline = nil
        ridingState = nil
        _plugin = nil
        currentSpeed = 0
        currentElevation = 0
        elevationGain = 0
        elevationLoss = 0
        currentHeartRate = 0
        averageHeartRate = 0
        maxHeartRate = 0
        minHeartRate = Int.max
        currentHeartRateZone = .zone1
        currentWeather = nil
        weatherError = nil
        healthCoordinator.resetState()
    }

    // MARK: - GPS Location Callback

    private func setupLocationCallback() {
        gpsTracker.insertLocationPoint = { [weak self] location, ctx in
            self?._plugin?.persistLocationPoint(location, in: ctx)
        }

        gpsTracker.onLocationProcessed = { [weak self] location, distanceDelta in
            self?.handleLocation(location, distanceDelta: distanceDelta)
        }
    }

    private func handleLocation(_ location: CLLocation, distanceDelta: Double) {
        guard sessionState == .tracking else { return }

        // Sync common GPS state from tracker
        totalDistance = gpsTracker.totalDistance
        currentSpeed = gpsTracker.currentSpeed
        currentElevation = gpsTracker.currentElevation
        elevationGain = gpsTracker.elevationGain
        elevationLoss = gpsTracker.elevationLoss
        gpsHorizontalAccuracy = gpsTracker.gpsHorizontalAccuracy
        gpsSignalQuality = gpsTracker.gpsSignalQuality

        // Forward to plugin
        _plugin?.processLocation(location, distanceDelta: distanceDelta)

        // Update family sharing (throttled to every 10 seconds)
        if isSharingWithFamily {
            familySharingTask?.cancel()
            familySharingTask = Task {
                await updateFamilySharing(location: location)
            }
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

                // Plugin tick
                self._plugin?.timerTick(elapsed: self.elapsedTime)

                // Audio coaching
                self.audioCoach.processTime(self.elapsedTime)
                self.audioCoach.processDistance(self.totalDistance)

                // Periodic checkpoint save every 30 seconds
                self.timerTickCount += 1
                if self.timerTickCount % 30 == 0 {
                    self.checkpointSave()
                }
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

    private func handleHeartRateUpdate(_ bpm: Int) {
        guard sessionState == .tracking else { return }

        healthCoordinator.processHeartRate(bpm)

        // Sync state from coordinator
        currentHeartRate = healthCoordinator.currentHeartRate
        currentHeartRateZone = healthCoordinator.currentZone
        averageHeartRate = healthCoordinator.averageHeartRate
        maxHeartRate = healthCoordinator.maxHeartRate

        // Forward to plugin
        _plugin?.processHeartRate(bpm)
    }

    private func setupHealthCoordinator() {
        healthCoordinator.onHeartRateZoneChanged = { [weak self] newZone in
            guard let self else { return }
            self.audioCoach.processHeartRateZone(newZone)
        }
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
                switch command {
                case .startRide:
                    // Watch-initiated start defaults to hack ride
                    let plugin = RidingPlugin()
                    await self.start(plugin: plugin)
                case .stopRide:
                    self.stop()
                case .requestStatus:
                    self.sendStatusToWatch()
                default:
                    break
                }
            }
        }

        // Observe heart rate
        watchHRTask = Task { @MainActor [weak self] in
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
                guard let noteText = wm.lastVoiceNoteText else { continue }

                // Forward to riding plugin if riding (it owns the Ride model)
                if let riding = self.ridingState, let ride = riding.currentRide {
                    let service = VoiceNotesService.shared
                    ride.notes = service.appendNote(noteText, to: ride.notes)
                    var currentNotes = ride.voiceNotes
                    currentNotes.append(noteText)
                    ride.voiceNotes = currentNotes
                }
            }
        }
    }

    private func sendStatusToWatch() {
        let state: SharedRideState = sessionState == .tracking ? .tracking : .idle
        var payload = _plugin?.watchStatusPayload() ?? [:]

        watchManager.sendStatusUpdate(
            rideState: state,
            duration: elapsedTime,
            distance: totalDistance,
            speed: currentSpeed,
            gait: (payload["gait"] as? String) ?? GaitType.stationary.rawValue,
            heartRate: currentHeartRate > 0 ? currentHeartRate : nil,
            heartRateZone: currentHeartRateZone.rawValue,
            averageHeartRate: averageHeartRate > 0 ? averageHeartRate : nil,
            maxHeartRate: maxHeartRate > 0 ? maxHeartRate : nil,
            horseName: payload["horseName"] as? String,
            rideType: payload["rideType"] as? String,
            walkPercent: payload["walkPercent"] as? Double,
            trotPercent: payload["trotPercent"] as? Double,
            canterPercent: payload["canterPercent"] as? Double,
            gallopPercent: payload["gallopPercent"] as? Double,
            leftTurnCount: nil,
            rightTurnCount: nil,
            leftReinPercent: payload["leftReinPercent"] as? Double,
            rightReinPercent: payload["rightReinPercent"] as? Double,
            leftLeadPercent: payload["leftLeadPercent"] as? Double,
            rightLeadPercent: payload["rightLeadPercent"] as? Double,
            symmetryScore: payload["symmetryScore"] as? Double,
            rhythmScore: payload["rhythmScore"] as? Double,
            optimalTime: payload["optimalTime"] as? TimeInterval,
            timeDifference: payload["timeDifference"] as? TimeInterval,
            elevation: payload["elevation"] as? Double
        )
    }

    // MARK: - Family Sharing

    private func updateFamilySharing(location: CLLocation) async {
        if let lastUpdate = lastFamilyUpdateTime,
           Date().timeIntervalSince(lastUpdate) < 10 {
            return
        }
        lastFamilyUpdateTime = Date()

        let gaitRaw = (_plugin?.watchStatusPayload()["gait"] as? String) ?? GaitType.stationary.rawValue
        let gait = GaitType(rawValue: gaitRaw) ?? .stationary

        await sharingCoordinator.updateSharedLocation(
            location: location,
            gait: gait,
            distance: totalDistance,
            duration: elapsedTime
        )
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
