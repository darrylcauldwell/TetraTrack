//
//  WorkoutManager.swift
//  TetraTrack Watch App
//
//  Manages autonomous workout sessions on Apple Watch
//  Supports riding, running, and swimming with GPS and heart rate
//

import Foundation
import HealthKit
import Observation
import os
import TetraTrackShared

/// Activity type for Watch workouts
enum WatchActivityType: String {
    case riding
    case running
    case walking
    case swimming
    case shooting

    var healthKitType: HKWorkoutActivityType {
        switch self {
        case .riding: return .equestrianSports
        case .running: return .running
        case .walking: return .walking
        case .swimming: return .swimming
        case .shooting: return .archery
        }
    }

    var sessionDiscipline: WatchSessionDiscipline {
        switch self {
        case .riding: return .riding
        case .running: return .running
        case .walking: return .walking
        case .swimming: return .swimming
        case .shooting: return .shooting
        }
    }
}

/// Manages autonomous workout sessions on Apple Watch
@Observable
final class WorkoutManager: NSObject {
    static let shared = WorkoutManager()

    // MARK: - State

    private(set) var isWorkoutActive: Bool = false
    private(set) var isPaused: Bool = false
    private(set) var isCompanionMode: Bool = false
    private(set) var activityType: WatchActivityType?

    // MARK: - Metrics

    private(set) var currentHeartRate: Int = 0
    private(set) var averageHeartRate: Int = 0
    private(set) var maxHeartRate: Int = 0
    private(set) var minHeartRate: Int = 0
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var activeCalories: Double = 0

    // MARK: - Swimming Metrics

    private(set) var strokeCount: Int = 0
    private(set) var lapCount: Int = 0
    private(set) var swimmingDistance: Double = 0  // meters
    private(set) var currentStrokeType: HKSwimmingStrokeStyle = .unknown
    private(set) var poolLength: Double = 25.0  // meters (default 25m pool)

    // MARK: - Callbacks

    var onHeartRateUpdate: ((Int) -> Void)?
    var onWorkoutStateChanged: ((Bool) -> Void)?

    /// Called when motion data should be sent via WatchConnectivity fallback (non-mirrored sessions)
    var onMotionDataSend: (() -> Void)?

    // MARK: - Private

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var heartRateSamples: [Int] = []
    private var startTime: Date?
    private var elapsedTimer: DispatchSourceTimer?
    private var motionSendTimer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "dev.dreamfold.tetratrack.watchTimers", qos: .userInitiated)
    private(set) var motionSendTickCount: Int = 0

    // Dependencies
    private let locationManager = WatchLocationManager.shared
    private let sessionStore = WatchSessionStore.shared

    /// Whether this workout was started via iPhone's startWatchApp or mirroring
    private(set) var isMirroredFromiPhone: Bool = false

    /// Whether data is being mirrored to iPhone (true for both iPhone-triggered and autonomous workouts)
    private(set) var isMirroringToiPhone: Bool = false

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Reset

    /// Clean teardown before starting a new workout (matches Apple's resetWorkout() pattern).
    func resetWorkout() async {
        if isWorkoutActive {
            await discardWorkout()
        }
        workoutSession = nil
        workoutBuilder = nil
        isWorkoutActive = false
        isCompanionMode = false
        isMirroredFromiPhone = false
        isMirroringToiPhone = false
        isPaused = false
    }

    // MARK: - iPhone-Triggered Primary Workout

    /// Start a primary workout on Watch, triggered by iPhone via startWatchApp.
    /// Watch creates the session, builder, and data source, then mirrors to iPhone.
    /// Aligned to Apple's MirroringWorkoutsSample (WWDC23) exact order:
    /// session → builder → delegates → dataSource → mirror → startActivity → beginCollection
    func startWorkoutFromiPhone(configuration: HKWorkoutConfiguration) async throws {
        let activityRaw = configuration.activityType.rawValue
        let locationRaw = configuration.locationType.rawValue
        Log.tracking.error("TT: startWorkoutFromiPhone() — activity=\(activityRaw, privacy: .public), location=\(locationRaw, privacy: .public)")
        WatchConnectivityService.sendDiagnostic("startWorkoutFromiPhone: entry")

        // --- Apple-reference-aligned core (EXACT order from MirroringWorkoutsSample) ---
        let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()
        session.delegate = self
        builder.delegate = self
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )

        session.prepare()
        WatchConnectivityService.sendDiagnostic("startWorkoutFromiPhone: session prepared, about to mirror")
        try await session.startMirroringToCompanionDevice()
        Log.tracking.error("TT: startWorkoutFromiPhone — mirroring SUCCEEDED")
        WatchConnectivityService.sendDiagnostic("startWorkoutFromiPhone: mirroring SUCCEEDED")

        let startDate = Date()
        session.startActivity(with: startDate)
        try await builder.beginCollection(at: startDate)

        // Notify iPhone AFTER session is fully live (startActivity + beginCollection complete).
        // Uses transferUserInfo so status updates can't overwrite it via applicationContext.
        let mirroringMsg = WatchMessage.mirroringStarted(discipline: mapActivityType(configuration.activityType).rawValue)
        WatchConnectivityService.shared.sendReliableMessage(mirroringMsg.toDictionary())
        Log.tracking.error("TT: sent mirroringStarted to iPhone (fromIPhone path, after beginCollection)")

        // --- TetraTrack-specific (AFTER core setup) ---
        workoutSession = session
        workoutBuilder = builder
        activityType = mapActivityType(configuration.activityType)
        isWorkoutActive = true
        isCompanionMode = false
        isMirroredFromiPhone = true
        isMirroringToiPhone = true
        isPaused = false
        startTime = startDate
        resetMetrics()

        // Location tracking (outdoor activities)
        if let type = activityType, type != .swimming && type != .shooting {
            locationManager.startTracking()
        }

        // Motion tracking (discipline-aware)
        if let type = activityType {
            let motionMode: WatchMotionMode = switch type {
            case .riding: .riding
            case .running: .running
            case .walking: .walking
            case .swimming: .swimming
            case .shooting: .shooting
            }
            WatchMotionManager.shared.startTracking(mode: motionMode)
        }

        startMotionDataSending()
        startElapsedTimer()
        persistRecoveryContext()
        onWorkoutStateChanged?(true)

        let typeName = activityType?.rawValue ?? "unknown"
        Log.tracking.error("TT: iPhone-triggered primary workout started: \(typeName, privacy: .public)")
    }

    /// Send heart rate to iPhone via mirrored workout session channel.
    func sendHeartRateViaMirroredSession(_ bpm: Int) {
        guard let session = workoutSession else { return }

        let envelope: [String: Any] = [
            "type": "heartRate",
            "bpm": bpm,
            "timestamp": Date().timeIntervalSince1970
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: envelope) else { return }

        Task {
            do {
                try await session.sendToRemoteWorkoutSession(data: data)
            } catch {
                Log.tracking.error("Failed to send HR via mirrored session: \(error)")
            }
        }
    }

    // MARK: - Activity Type Mapping

    private func mapActivityType(_ hkType: HKWorkoutActivityType) -> WatchActivityType {
        switch hkType {
        case .equestrianSports: return .riding
        case .running: return .running
        case .swimming: return .swimming
        case .walking: return .walking
        case .archery: return .shooting
        case .other: return .shooting  // backward compat: iPhone ShootingPlugin used .other before alignment
        default: return .running
        }
    }

    private func resetMetrics() {
        heartRateSamples = []
        currentHeartRate = 0
        averageHeartRate = 0
        maxHeartRate = 0
        minHeartRate = 0
        elapsedTime = 0
        activeCalories = 0
        strokeCount = 0
        lapCount = 0
        swimmingDistance = 0
        currentStrokeType = .unknown
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            return false
        }

        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceSwimming)
        ]

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned)
        ]

        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            return true
        } catch {
            Log.health.error("Authorization failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Workout Control

    /// Start an autonomous workout session.
    /// Aligned to Apple's MirroringWorkoutsSample exact order:
    /// session → builder → delegates → dataSource → mirror → startActivity → beginCollection
    func startWorkout(type: WatchActivityType) async {
        guard !isWorkoutActive else {
            Log.tracking.error("TT: startWorkout skipped — workout already active")
            WatchConnectivityService.sendDiagnostic("startWorkout skipped: already active")
            return
        }

        // Ensure HealthKit authorization before creating session
        let authorized = await requestAuthorization()
        if !authorized {
            Log.tracking.error("TT: startWorkout — HealthKit authorization denied")
            WatchConnectivityService.sendDiagnostic("startWorkout: HealthKit auth DENIED")
            return
        }
        WatchConnectivityService.sendDiagnostic("startWorkout: HealthKit auth OK")

        // Clear any stale session state
        await resetWorkout()

        // Create workout configuration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = type.healthKitType
        configuration.locationType = (type == .swimming || type == .shooting) ? .indoor : .outdoor

        // Configure swimming-specific settings
        if type == .swimming {
            configuration.swimmingLocationType = .pool
            configuration.lapLength = HKQuantity(unit: .meter(), doubleValue: poolLength)
        }

        do {
            // Apple-reference-aligned core (same order as startWorkoutFromiPhone)
            WatchConnectivityService.sendDiagnostic("startWorkout: creating HKWorkoutSession for \(type.rawValue)")
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            session.delegate = self
            builder.delegate = self
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            // Prepare session before mirroring (required per Apple docs + nonstrict.eu findings)
            session.prepare()
            WatchConnectivityService.sendDiagnostic("startWorkout: session prepared, calling startMirroringToCompanionDevice()")

            var mirroringSucceeded = false
            do {
                try await session.startMirroringToCompanionDevice()
                mirroringSucceeded = true
                WatchConnectivityService.sendDiagnostic("startWorkout: mirroring SUCCEEDED")
            } catch {
                let errMsg = error.localizedDescription
                Log.tracking.error("TT: startMirroringToCompanionDevice FAILED: \(errMsg, privacy: .public) — continuing with local Watch workout")
                WatchConnectivityService.sendDiagnostic("startWorkout: mirroring FAILED: \(errMsg) — continuing locally")
            }

            let startDate = Date()
            session.startActivity(with: startDate)
            try await builder.beginCollection(at: startDate)
            WatchConnectivityService.sendDiagnostic("startWorkout: activity started + collection began")

            // Notify iPhone AFTER session is fully live (startActivity + beginCollection complete).
            // Uses transferUserInfo so status updates can't overwrite it via applicationContext.
            if mirroringSucceeded {
                let mirroringMsg = WatchMessage.mirroringStarted(discipline: type.rawValue)
                WatchConnectivityService.shared.sendReliableMessage(mirroringMsg.toDictionary())
                Log.tracking.error("TT: sent mirroringStarted to iPhone (after beginCollection)")
            }

            // TetraTrack-specific state
            workoutSession = session
            workoutBuilder = builder
            activityType = type
            isWorkoutActive = true
            isCompanionMode = false
            isMirroringToiPhone = mirroringSucceeded
            isPaused = false
            startTime = startDate
            resetMetrics()

            // Start location tracking (except swimming and shooting)
            if type != .swimming && type != .shooting {
                locationManager.startTracking()
            }

            // Motion tracking (discipline-aware)
            let motionMode: WatchMotionMode = switch type {
            case .riding: .riding
            case .running: .running
            case .walking: .walking
            case .swimming: .swimming
            case .shooting: .shooting
            }
            WatchMotionManager.shared.startTracking(mode: motionMode)

            // Start 1Hz mirrored data sending (HR + motion to iPhone)
            startMotionDataSending()

            // Start elapsed time timer
            startElapsedTimer()

            // Create session in store
            _ = sessionStore.startSession(discipline: type.sessionDiscipline)

            persistRecoveryContext()
            onWorkoutStateChanged?(true)
            Log.tracking.info("Started \(type.rawValue) workout (mirroring to iPhone)")

        } catch {
            let errMsg = error.localizedDescription
            Log.tracking.error("TT: startWorkout FAILED: \(errMsg, privacy: .public)")
            WatchConnectivityService.sendDiagnostic("startWorkout FAILED: \(errMsg)")
        }
    }

    /// Pause the current workout
    func pauseWorkout() {
        guard isWorkoutActive, !isPaused else { return }

        workoutSession?.pause()
        isPaused = true
        stopElapsedTimer()
        Log.tracking.info("Paused workout")
    }

    /// Resume a paused workout
    func resumeWorkout() {
        guard isWorkoutActive, isPaused else { return }

        workoutSession?.resume()
        isPaused = false
        startElapsedTimer()
        Log.tracking.info("Resumed workout")
    }

    /// Stop and save the workout
    func stopWorkout() async {
        guard isWorkoutActive else { return }

        // Stop all tracking
        locationManager.stopTracking()
        stopElapsedTimer()
        stopMotionDataSending()
        onMotionDataSend = nil
        WatchMotionManager.shared.stopTracking()

        // End data collection and save (session.end() must come AFTER finishWorkout per Apple docs)
        let endDate = Date()
        var healthKitSaveSucceeded = false

        do {
            try await workoutBuilder?.endCollection(at: endDate)

            // Save workout to HealthKit
            if let builder = workoutBuilder {
                try await builder.finishWorkout()
                healthKitSaveSucceeded = true
                Log.health.info("Workout saved to HealthKit")
            }
        } catch {
            Log.tracking.error("Failed to end workout: \(error.localizedDescription)")
        }

        // End session AFTER builder operations complete (Apple docs requirement)
        workoutSession?.end()

        // Update session store with final metrics (only for non-iPhone-triggered workouts)
        if !isMirroredFromiPhone {
            sessionStore.updateActiveSession(
                duration: elapsedTime,
                distance: locationManager.totalDistance,
                elevationGain: locationManager.elevationGain,
                elevationLoss: locationManager.elevationLoss,
                averageSpeed: locationManager.averageSpeed,
                maxSpeed: locationManager.maxSpeed,
                averageHeartRate: averageHeartRate > 0 ? averageHeartRate : nil,
                maxHeartRate: maxHeartRate > 0 ? maxHeartRate : nil,
                minHeartRate: minHeartRate > 0 ? minHeartRate : nil
            )
            sessionStore.completeSession(locationPointsData: locationManager.getEncodedPoints())
        }

        // Clean up
        clearRecoveryContext()
        workoutSession = nil
        workoutBuilder = nil
        isWorkoutActive = false
        isCompanionMode = false
        isMirroredFromiPhone = false
        isMirroringToiPhone = false
        isPaused = false
        activityType = nil

        onWorkoutStateChanged?(false)

        if healthKitSaveSucceeded {
            Log.tracking.info("Workout stopped and saved to HealthKit")
        } else {
            Log.tracking.info("Workout stopped - data saved locally, will sync to iPhone for HealthKit save")
        }
    }

    /// Discard the current workout without saving
    func discardWorkout() async {
        guard isWorkoutActive else { return }

        locationManager.stopTracking()
        stopElapsedTimer()
        stopMotionDataSending()
        onMotionDataSend = nil
        WatchMotionManager.shared.stopTracking()

        try? await workoutBuilder?.endCollection(at: Date())
        workoutBuilder?.discardWorkout()
        workoutSession?.end()

        sessionStore.discardSession()
        clearRecoveryContext()

        workoutSession = nil
        workoutBuilder = nil
        isWorkoutActive = false
        isCompanionMode = false
        isMirroredFromiPhone = false
        isMirroringToiPhone = false
        isPaused = false
        activityType = nil

        onWorkoutStateChanged?(false)
        Log.tracking.info("Workout discarded")
    }

    // MARK: - Crash Recovery

    /// Persist minimal session context to UserDefaults for crash recovery.
    private func persistRecoveryContext() {
        guard let type = activityType, let start = startTime else { return }
        UserDefaults.standard.set(type.rawValue, forKey: "activeWorkoutDiscipline")
        UserDefaults.standard.set(start.timeIntervalSince1970, forKey: "activeWorkoutStartDate")
        UserDefaults.standard.set(isMirroredFromiPhone, forKey: "activeWorkoutFromiPhone")
    }

    /// Clear persisted recovery context after normal workout completion.
    private func clearRecoveryContext() {
        UserDefaults.standard.removeObject(forKey: "activeWorkoutDiscipline")
        UserDefaults.standard.removeObject(forKey: "activeWorkoutStartDate")
        UserDefaults.standard.removeObject(forKey: "activeWorkoutFromiPhone")
    }

    /// Recover an active workout session after a Watch app crash or relaunch.
    /// Called from WKApplicationDelegate.handleActiveWorkoutRecovery().
    func recoverActiveWorkout() async {
        do {
            guard let session = try await healthStore.recoverActiveWorkoutSession() else {
                Log.tracking.info("No active workout to recover")
                clearRecoveryContext()
                return
            }

            // Re-attach delegates
            session.delegate = self
            workoutSession = session

            let builder = session.associatedWorkoutBuilder()
            builder.delegate = self
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: session.workoutConfiguration
            )
            workoutBuilder = builder

            // Restore state from persisted context or derive from session
            let config = session.workoutConfiguration
            if let disciplineRaw = UserDefaults.standard.string(forKey: "activeWorkoutDiscipline"),
               let savedType = WatchActivityType(rawValue: disciplineRaw) {
                activityType = savedType
            } else {
                activityType = mapActivityType(config.activityType)
            }

            let savedStartTimestamp = UserDefaults.standard.double(forKey: "activeWorkoutStartDate")
            startTime = savedStartTimestamp > 0
                ? Date(timeIntervalSince1970: savedStartTimestamp)
                : (session.startDate ?? Date())

            isMirroredFromiPhone = UserDefaults.standard.bool(forKey: "activeWorkoutFromiPhone")
            isWorkoutActive = true
            isPaused = session.state == .paused
            isMirroringToiPhone = true

            // Restart elapsed timer
            if !isPaused {
                startElapsedTimer()
            }

            // Restart motion data sending
            startMotionDataSending()

            // Restart motion tracking if applicable
            if let type = activityType {
                let motionMode: WatchMotionMode = switch type {
                case .riding: .riding
                case .running: .running
                case .walking: .walking
                case .swimming: .swimming
                case .shooting: .shooting
                }
                WatchMotionManager.shared.startTracking(mode: motionMode)
            }

            onWorkoutStateChanged?(true)
            Log.tracking.info("Recovered active workout: \(self.activityType?.rawValue ?? "unknown")")

        } catch {
            Log.tracking.error("Failed to recover active workout: \(error.localizedDescription)")
            clearRecoveryContext()
        }
    }

    // MARK: - Heart Rate Monitoring (Companion Mode)
    // NOTE: This companion mode serves as fallback when HKWorkoutSession mirroring
    // is unavailable. When mirroring is active, the Watch receives the mirrored session
    // via setupMirroringHandler() and HR is auto-collected — this mode is not needed.

    /// Start heart rate monitoring as a companion to iPhone session.
    /// Creates an HKWorkoutSession for live HR delivery without Watch-side
    /// location tracking, timers, or session store.
    /// The workout is discarded (not saved to HealthKit) when stopped,
    /// since the iPhone handles HealthKit saving.
    func startHeartRateMonitoring(type: WatchActivityType = .riding) async {
        guard !isWorkoutActive else { return }

        let authorized = await requestAuthorization()
        guard authorized else {
            Log.health.warning("Not authorized for companion HR monitoring")
            return
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = type.healthKitType
        configuration.locationType = type == .swimming ? .indoor : .outdoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutSession?.delegate = self

            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            workoutBuilder?.delegate = self
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            workoutSession?.prepare()
            let startDate = Date()
            workoutSession?.startActivity(with: startDate)
            try await workoutBuilder?.beginCollection(at: startDate)

            isWorkoutActive = true
            isCompanionMode = true
            heartRateSamples = []
            currentHeartRate = 0
            averageHeartRate = 0
            maxHeartRate = 0
            minHeartRate = 0

            Log.health.info("Heart rate monitoring started (companion mode) - \(type.rawValue)")
        } catch {
            Log.health.error("Failed to start companion HR monitoring: \(error.localizedDescription)")
        }
    }

    /// Stop companion heart rate monitoring and discard the workout
    func stopHeartRateMonitoring() async {
        guard isWorkoutActive, isCompanionMode else { return }

        try? await workoutBuilder?.endCollection(at: Date())
        workoutBuilder?.discardWorkout()
        workoutSession?.end()

        workoutSession = nil
        workoutBuilder = nil
        isWorkoutActive = false
        isCompanionMode = false

        Log.health.info("Heart rate monitoring stopped (companion mode)")
    }

    // MARK: - Motion Data Sending

    /// Start sending motion + HR data at 1Hz via mirrored session or WC fallback.
    func startMotionDataSending() {
        stopMotionDataSending()
        motionSendTickCount = 0

        let source = DispatchSource.makeTimerSource(queue: timerQueue)
        source.schedule(deadline: .now() + 1.0, repeating: 1.0, leeway: .milliseconds(100))
        source.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.motionSendTickCount += 1
                if self.motionSendTickCount == 1 || self.motionSendTickCount % 10 == 0 {
                    Log.tracking.info("motionSend tick \(self.motionSendTickCount), HR=\(self.currentHeartRate), mirroring=\(self.isMirroringToiPhone)")
                }
                self.sendMirroredDataTick()
            }
        }
        source.resume()
        motionSendTimer = source
        Log.tracking.info("Motion data sending started (1Hz, DispatchSourceTimer)")
        WatchConnectivityService.sendDiagnostic("motionSend timer started (1Hz)")
    }

    /// Stop motion data sending.
    func stopMotionDataSending() {
        motionSendTimer?.cancel()
        motionSendTimer = nil
    }

    private func sendMirroredDataTick() {
        let metrics = WatchMotionManager.shared.currentMetrics()

        if isMirroringToiPhone {
            sendMotionViaMirroredSession(metrics)
            sendBuilderStatsViaMirroredSession()
            // Send gait classification result if available (riding only — avoids heavy DSP init on Watch for other disciplines)
            if activityType == .riding,
               let gaitResult = WatchGaitAnalyzer.shared.currentGaitResult {
                sendGaitResultViaMirroredSession(gaitResult)
            }
            // Also send HR via mirrored session
            if currentHeartRate > 0 {
                sendHeartRateViaMirroredSession(currentHeartRate)
            } else if motionSendTickCount % 30 == 0 {
                Log.tracking.info("motionSend: HR is 0 at tick \(self.motionSendTickCount) — no HR sample from HKLiveWorkoutBuilder yet")
            }
        } else {
            onMotionDataSend?()
        }
    }

    private func sendBuilderStatsViaMirroredSession() {
        guard let session = workoutSession, let builder = workoutBuilder else { return }

        var stats: [String: Any] = ["type": "builderStats"]
        var hasStats = false

        // Cumulative types — use sumQuantity()
        if let cal = builder.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity() {
            stats["activeCalories"] = cal.doubleValue(for: .kilocalorie())
            hasStats = true
        }
        if let dist = builder.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity() {
            stats["distance"] = dist.doubleValue(for: .meter())
            hasStats = true
        }
        if let swimDist = builder.statistics(for: HKQuantityType(.distanceSwimming))?.sumQuantity() {
            stats["distance"] = swimDist.doubleValue(for: .meter())
            hasStats = true
        }
        if let steps = builder.statistics(for: HKQuantityType(.stepCount))?.sumQuantity() {
            stats["stepCount"] = Int(steps.doubleValue(for: .count()))
            hasStats = true
        }
        if let strokes = builder.statistics(for: HKQuantityType(.swimmingStrokeCount))?.sumQuantity() {
            stats["swimmingStrokeCount"] = Int(strokes.doubleValue(for: .count()))
            hasStats = true
        }

        // Instantaneous types — use mostRecentQuantity() or averageQuantity()
        if let speed = builder.statistics(for: HKQuantityType(.runningSpeed))?.averageQuantity() {
            stats["runningSpeed"] = speed.doubleValue(for: HKUnit.meter().unitDivided(by: .second()))
            hasStats = true
        }
        if let power = builder.statistics(for: HKQuantityType(.runningPower))?.averageQuantity() {
            stats["runningPower"] = power.doubleValue(for: .watt())
            hasStats = true
        }
        if let stride = builder.statistics(for: HKQuantityType(.runningStrideLength))?.averageQuantity() {
            stats["runningStrideLength"] = stride.doubleValue(for: .meter())
            hasStats = true
        }
        if let gct = builder.statistics(for: HKQuantityType(.runningGroundContactTime))?.averageQuantity() {
            stats["groundContactTime"] = gct.doubleValue(for: .secondUnit(with: .milli))
            hasStats = true
        }
        if let osc = builder.statistics(for: HKQuantityType(.runningVerticalOscillation))?.averageQuantity() {
            stats["verticalOscillation"] = osc.doubleValue(for: HKUnit.meterUnit(with: .centi))
            hasStats = true
        }

        guard hasStats else { return }

        guard let data = try? JSONSerialization.data(withJSONObject: stats) else { return }
        Task {
            do {
                try await session.sendToRemoteWorkoutSession(data: data)
            } catch {
                Log.tracking.error("Failed to send builder stats via mirrored session: \(error)")
            }
        }
    }

    private func sendGaitResultViaMirroredSession(_ result: WatchGaitResult) {
        guard let session = workoutSession else { return }

        guard let resultJSON = try? JSONEncoder().encode(result),
              let resultString = String(data: resultJSON, encoding: .utf8) else { return }

        let envelope: [String: Any] = [
            "type": "gaitResult",
            "resultJSON": resultString
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: envelope) else { return }

        Task {
            do {
                try await session.sendToRemoteWorkoutSession(data: data)
            } catch {
                Log.tracking.error("Failed to send gait result via mirrored session: \(error)")
            }
        }
    }

    private func sendMotionViaMirroredSession(_ metrics: WatchMotionMetrics) {
        guard let session = workoutSession else { return }

        guard let metricsJSON = try? JSONEncoder().encode(metrics),
              let metricsString = String(data: metricsJSON, encoding: .utf8) else { return }

        let envelope: [String: Any] = [
            "type": "motionData",
            "metricsJSON": metricsString
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: envelope) else { return }

        Task {
            do {
                try await session.sendToRemoteWorkoutSession(data: data)
            } catch {
                Log.tracking.error("Failed to send motion via mirrored session: \(error)")
            }
        }
    }

    // MARK: - Elapsed Timer

    private func startElapsedTimer() {
        stopElapsedTimer()

        let source = DispatchSource.makeTimerSource(queue: timerQueue)
        source.schedule(deadline: .now() + 1.0, repeating: 1.0, leeway: .milliseconds(100))
        source.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                guard let self, let start = self.startTime, !self.isPaused else { return }
                self.elapsedTime = Date().timeIntervalSince(start)
            }
        }
        source.resume()
        elapsedTimer = source
    }

    private func stopElapsedTimer() {
        elapsedTimer?.cancel()
        elapsedTimer = nil
    }

    // MARK: - Computed Properties

    /// Current distance from location manager
    var distance: Double {
        locationManager.totalDistance
    }

    /// Current speed from location manager
    var currentSpeed: Double {
        locationManager.currentSpeed
    }

    /// Current elevation from location manager
    var currentElevation: Double {
        locationManager.currentAltitude
    }

    /// Elevation gain from location manager
    var elevationGain: Double {
        locationManager.elevationGain
    }

    /// Formatted elapsed time string
    var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Formatted distance string
    var formattedDistance: String {
        let km = distance / 1000.0
        if km < 1 {
            return String(format: "%.0f m", distance)
        }
        return String(format: "%.2f km", km)
    }

    /// Formatted pace (for running)
    var formattedPace: String {
        guard currentSpeed > 0 else { return "--:--" }
        let paceSecondsPerKm = 1000.0 / currentSpeed
        let minutes = Int(paceSecondsPerKm) / 60
        let seconds = Int(paceSecondsPerKm) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    // MARK: - Swimming Computed Properties

    /// SWOLF score (strokes + seconds per lap) - lower is better
    var swolfScore: Int {
        guard lapCount > 0 else { return 0 }
        let avgStrokesPerLap = Double(strokeCount) / Double(lapCount)
        let avgSecondsPerLap = elapsedTime / Double(lapCount)
        return Int(avgStrokesPerLap + avgSecondsPerLap)
    }

    /// Average strokes per lap
    var strokesPerLap: Double {
        guard lapCount > 0 else { return 0 }
        return Double(strokeCount) / Double(lapCount)
    }

    /// Formatted swimming distance
    var formattedSwimmingDistance: String {
        if swimmingDistance >= 1000 {
            return String(format: "%.2f km", swimmingDistance / 1000)
        }
        return String(format: "%.0f m", swimmingDistance)
    }

    /// Stroke type display name
    var strokeTypeName: String {
        switch currentStrokeType {
        case .freestyle: return "Freestyle"
        case .backstroke: return "Backstroke"
        case .breaststroke: return "Breaststroke"
        case .butterfly: return "Butterfly"
        case .mixed: return "Mixed"
        case .kickboard: return "Kickboard"
        case .unknown: return "---"
        @unknown default: return "---"
        }
    }

    /// Pace per 100m for swimming
    var swimPacePer100m: String {
        guard swimmingDistance > 0, elapsedTime > 0 else { return "--:--" }
        let secondsPer100m = (elapsedTime / swimmingDistance) * 100
        let minutes = Int(secondsPer100m) / 60
        let seconds = Int(secondsPer100m) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            switch toState {
            case .running:
                self.isPaused = false
            case .paused:
                self.isPaused = true
            case .ended:
                self.isWorkoutActive = false
                self.isMirroringToiPhone = false
                // Clean up mirrored session state
                if self.isMirroredFromiPhone {
                    self.isMirroredFromiPhone = false
                    self.stopMotionDataSending()
                    self.onMotionDataSend = nil
                    WatchMotionManager.shared.stopTracking()
                    self.workoutSession = nil
                    self.workoutBuilder = nil
                    self.activityType = nil
                    self.stopElapsedTimer()
                    self.onWorkoutStateChanged?(false)
                    Log.tracking.info("Mirrored session ended by iPhone")
                }
            default:
                break
            }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Log.tracking.error("Workout session failed: \(error.localizedDescription)")
    }

    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didReceiveDataFromRemoteWorkoutSession data: [Data]
    ) {
        // Handle data sent from iPhone via sendToRemoteWorkoutSession
        for item in data {
            guard let payload = try? JSONSerialization.jsonObject(with: item) as? [String: Any],
                  let type = payload["type"] as? String else { continue }

            Task { @MainActor in
                switch type {
                case "statusUpdate":
                    // iPhone sent live stats update
                    if let duration = payload["duration"] as? TimeInterval {
                        self.elapsedTime = duration
                    }
                case "haptic":
                    if let hapticType = payload["hapticType"] as? String {
                        switch hapticType {
                        case "milestone": HapticManager.shared.playMilestoneHaptic()
                        case "gaitChange": HapticManager.shared.playGaitChangeHaptic()
                        case "zoneChange": HapticManager.shared.playZoneChangeHaptic(zone: 0)
                        case "lap": HapticManager.shared.playLapCompleteHaptic()
                        case "notification": HapticManager.shared.playNotificationHaptic()
                        default: HapticManager.shared.playClickHaptic()
                        }
                    }
                case "control":
                    // iPhone sent control command via mirrored session
                    if let action = payload["action"] as? String {
                        switch action {
                        case "pause":
                            self.pauseWorkout()
                            Log.tracking.info("Pause command from iPhone via mirrored session")
                        case "resume":
                            self.resumeWorkout()
                            Log.tracking.info("Resume command from iPhone via mirrored session")
                        case "stop":
                            await self.stopWorkout()
                            Log.tracking.info("Stop command from iPhone via mirrored session")
                        default:
                            break
                        }
                    }
                default:
                    break
                }
            }
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }

            if quantityType == HKQuantityType(.heartRate) {
                let statistics = workoutBuilder.statistics(for: quantityType)
                processHeartRateStatistics(statistics)
            }

            if quantityType == HKQuantityType(.activeEnergyBurned) {
                let statistics = workoutBuilder.statistics(for: quantityType)
                if let sum = statistics?.sumQuantity() {
                    Task { @MainActor in
                        self.activeCalories = sum.doubleValue(for: .kilocalorie())
                    }
                }
            }

            // Swimming metrics
            if quantityType == HKQuantityType(.swimmingStrokeCount) {
                let statistics = workoutBuilder.statistics(for: quantityType)
                if let sum = statistics?.sumQuantity() {
                    Task { @MainActor in
                        self.strokeCount = Int(sum.doubleValue(for: .count()))
                    }
                }
            }

            if quantityType == HKQuantityType(.distanceSwimming) {
                let statistics = workoutBuilder.statistics(for: quantityType)
                if let sum = statistics?.sumQuantity() {
                    Task { @MainActor in
                        self.swimmingDistance = sum.doubleValue(for: .meter())
                        // Calculate lap count from distance and pool length
                        self.lapCount = Int(self.swimmingDistance / self.poolLength)
                    }
                }
            }
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events - particularly swimming events
        let events = workoutBuilder.workoutEvents
        guard !events.isEmpty else { return }

        for event in events {
            // Check for swimming stroke style in event metadata
            if let metadata = event.metadata,
               let strokeStyleValue = metadata[HKMetadataKeySwimmingStrokeStyle] as? Int,
               let strokeStyle = HKSwimmingStrokeStyle(rawValue: strokeStyleValue) {
                Task { @MainActor in
                    self.currentStrokeType = strokeStyle
                }
            }
        }
    }

    private func processHeartRateStatistics(_ statistics: HKStatistics?) {
        guard let statistics = statistics else { return }

        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())

        Task { @MainActor in
            if let mostRecent = statistics.mostRecentQuantity() {
                let bpm = Int(mostRecent.doubleValue(for: heartRateUnit))
                self.currentHeartRate = bpm
                self.heartRateSamples.append(bpm)
                self.onHeartRateUpdate?(bpm)
            }

            if let average = statistics.averageQuantity() {
                self.averageHeartRate = Int(average.doubleValue(for: heartRateUnit))
            }

            if let max = statistics.maximumQuantity() {
                self.maxHeartRate = Int(max.doubleValue(for: heartRateUnit))
            }

            if let min = statistics.minimumQuantity() {
                self.minHeartRate = Int(min.doubleValue(for: heartRateUnit))
            }
        }
    }
}
