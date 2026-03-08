//
//  RunningLiveComponents.swift
//  TetraTrack
//
//  Running live session views extracted from RunningView
//

import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import HealthKit
import Charts
import os

// MARK: - Running Tab

enum RunningTab {
    case stats
    case map
}

// MARK: - Running Live View

struct RunningLiveView: View {
    @Bindable var session: RunningSession
    var intervalSettings: IntervalSettings?
    var programIntervals: [ProgramInterval]?
    var targetDistance: Double = 0
    var shareWithFamily: Bool = false
    var targetCadence: Int = 0
    let onEnd: () -> Void
    var onDiscard: (() -> Void)?

    @Environment(LocationManager.self) private var locationManager: LocationManager?
    @Environment(GPSSessionTracker.self) private var gpsTracker: GPSSessionTracker?
    @Environment(\.modelContext) private var modelContext

    @State private var isRunning = true
    @State private var elapsedTime: TimeInterval = 0
    @State private var timerSource: DispatchSourceTimer?
    @State private var showingCancelConfirmation = false

    // Track mode lap detection via LapDetector
    private var lapDetector: LapDetector { LapDetector.shared }

    // Km split tracking (outdoor runs)
    @State private var lastAnnouncedKm: Int = 0
    @State private var lastKmSplitTime: TimeInterval = 0

    // PB race coaching (time trials)
    @State private var lastAnnouncedCheckpointIndex: Int = -1
    @State private var lastPBEncouragementPercent: Int = 0

    // Virtual pacer audio tracking
    @State private var lastPacerAnnouncementTime: TimeInterval = 0

    // Interval countdown tracking
    @State private var lastAnnouncedCountdown: Int = Int.max

    private var personalBests: RunningPersonalBests { RunningPersonalBests.shared }

    // Tetrathlon scoring context
    @AppStorage("selectedCompetitionLevel") private var selectedLevelRaw: String = "Junior"

    private var selectedLevel: CompetitionLevel {
        CompetitionLevel(rawValue: selectedLevelRaw) ?? .junior
    }

    private var standardTime: TimeInterval {
        PonyClubScoringService.getRunStandardTime(
            for: selectedLevel.scoringCategory,
            gender: selectedLevel.scoringGender
        )
    }

    // Watch motion tracking
    @State private var verticalOscillation: Double = 0.0  // cm
    @State private var groundContactTime: Double = 0.0    // ms
    @State private var cadence: Int = 0                   // steps per minute

    // Tracking arrays for session averages
    @State private var cadenceReadings: [Int] = []
    @State private var oscillationReadings: [Double] = []
    @State private var gctReadings: [Double] = []
    @State private var formSamples: [RunningFormSample] = []

    // Form degradation detection
    @State private var lastDegradationCheckCount: Int = 0
    @State private var lastDegradationAlertTime: Date = .distantPast

    // Recovery tracking
    @State private var isRecoveryPhase = false
    @State private var recoveryTimer: DispatchSourceTimer?

    // Watch heart rate tracking
    @State private var currentHeartRate: Int = 0
    @State private var maxHeartRate: Int = 0
    @State private var minHeartRate: Int = Int.max
    @State private var heartRateReadings: [Int] = []
    @State private var heartRateSamples: [HeartRateSample] = []
    @State private var hasWCSessionHR: Bool = false  // tracks whether WCSession is providing HR
    private var estimatedMaxHR: Int { 190 }

    // Enhanced sensor data from Watch
    private let sensorAnalyzer = WatchSensorAnalyzer.shared

    // Coaching data collection
    @State private var coachingData = RunningCoachingSummary()

    // Weather tracking
    @State private var currentWeather: WeatherConditions?

    // Watch status update timer
    @State private var watchUpdateTimer: DispatchSourceTimer?

    private let watchManager = WatchConnectivityManager.shared
    private let weatherService = WeatherService.shared
    private let workoutLifecycle = WorkoutLifecycleService.shared

    // Interval tracking
    @State private var intervalCount = 1
    @State private var isWorkPhase = true
    @State private var phaseTime: TimeInterval = 0
    @State private var workoutPhase: IntervalWorkoutPhase = .warmup
    @State private var phaseTransitions: [(phase: IntervalWorkoutPhase, start: Date)] = []

    // Program interval tracking
    @State private var programAudioCoach = ProgramAudioCoach()
    @State private var lastProgramPhaseIndex: Int = -1
    @State private var lastProgramCountdown: Int = Int.max

    // Tab selection for swipeable stats/map
    @State private var selectedTab: RunningTab = .stats

    // Track whether services have been started (to avoid restarting on re-appear after screen lock)
    @State private var hasStartedServices = false

    // Vehicle detection
    @State private var showingVehicleAlert = false
    @State private var highSpeedStartTime: Date?
    private let vehicleSpeedThreshold: Double = 7.0  // ~25 km/h
    private let vehicleDetectionDuration: TimeInterval = 10  // 10 seconds sustained

    // Family sharing
    private let sharingCoordinator = UnifiedSharingCoordinator.shared
    @State private var lastSharingUpdateTime: Date = .distantPast
    private let sharingUpdateInterval: TimeInterval = 10

    enum IntervalWorkoutPhase {
        case warmup, work, rest, cooldown, finished
    }

    private var usesGPS: Bool {
        session.runMode == .outdoor || session.runMode == .track
    }

    private var isTrackMode: Bool {
        session.runMode == .track
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header: page indicator, weather, music, voice notes, close button
                headerView
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // Main content - swipeable for GPS, static for track/indoor
                if usesGPS {
                    TabView(selection: $selectedTab) {
                        // Stats with integrated pause/stop
                        runningStatsFullView
                            .tag(RunningTab.stats)

                        // Map with back button
                        runningMapView
                            .tag(RunningTab.map)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                } else {
                    // Indoor/Track - stats only with integrated pause/stop
                    runningStatsFullView
                }
            }
            .padding(.top, geometry.safeAreaInsets.top)
            .padding(.bottom, geometry.safeAreaInsets.bottom)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    sessionColor.opacity(0.05),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .onAppear {
            Log.location.info("Running: onAppear fired, hasStartedServices=\(hasStartedServices), timerSource=\(timerSource == nil ? "nil" : "set")")
            if !hasStartedServices {
                Log.location.info("Running: starting services (location, motion)")
                startMotionTracking()
                startLocationTracking()
                hasStartedServices = true

                // Start family sharing if enabled
                if shareWithFamily {
                    Task { await sharingCoordinator.startSharingLocation(activityType: "running") }
                }
            }
            if timerSource == nil {
                Log.location.info("Running: starting timer")
                startTimer()
            }
            if isTrackMode {
                lapDetector.configure(trackLength: session.trackLength)
                lapDetector.onLapCompleted = { lapNumber, lapTime in
                    // Persist lap as RunningSplit
                    let split = RunningSplit(orderIndex: lapNumber - 1, distance: session.trackLength)
                    split.duration = lapTime
                    if currentHeartRate > 0 { split.heartRate = currentHeartRate }
                    if cadence > 0 { split.cadence = cadence }
                    split.session = session
                    if session.splits == nil { session.splits = [] }
                    session.splits?.append(split)
                    modelContext.insert(split)

                    // Haptic feedback
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    watchManager.sendCommand(.hapticMilestone)

                    // Audio coaching
                    if AudioCoachManager.shared.announceRunningLaps {
                        let previousLapTime: TimeInterval? = lapDetector.lapTimes.count >= 2
                            ? lapDetector.lapTimes[lapDetector.lapTimes.count - 2] : nil
                        let isFastest = lapDetector.lapTimes.count > 1 && lapTime == lapDetector.fastestLap
                        AudioCoachManager.shared.announceLapWithComparison(
                            lapNumber, lapTime: lapTime,
                            previousLapTime: previousLapTime, isFastest: isFastest
                        )
                    }
                }
                AudioCoachManager.shared.announceTrackModeStart()
            }

            // Tetrathlon practice coaching: announce race start for time trials
            if session.sessionType == .timeTrial && targetDistance > 0 && AudioCoachManager.shared.announcePBRaceCoaching {
                let pbTime = personalBests.personalBest(for: targetDistance)
                AudioCoachManager.shared.announceTetrathlonPracticeStart(
                    pbTime: pbTime,
                    standardTime: standardTime,
                    distance: targetDistance,
                    category: selectedLevel.displayName
                )
            }

            // Virtual pacer: announce pacer start
            if VirtualPacer.shared.isActive && AudioCoachManager.shared.announceVirtualPacer {
                AudioCoachManager.shared.announceVirtualPacerStart(targetPace: VirtualPacer.shared.targetPace)
            }

            // Initialize coaching data collection
            coachingData.coachingLevelRaw = AudioCoachManager.shared.runningCoachingLevel.rawValue
            AudioCoachManager.shared.resetSessionAnnouncementCount()

            fetchWeather()
            UIApplication.shared.isIdleTimerDisabled = true
            AudioCoachManager.shared.startRunningFormReminders()
        }
        .onDisappear {
            timerSource?.cancel()
            AudioCoachManager.shared.stopRunningFormReminders()
        }
        .onChange(of: watchManager.motionUpdateSequence) {
            guard watchManager.currentMotionMode == .running else { return }
            var sampleCadence: Int = 0
            var sampleOsc: Double = 0
            var sampleGCT: Double = 0

            let osc = watchManager.verticalOscillation
            if osc > 0 {
                verticalOscillation = osc
                oscillationReadings.append(osc)
                sampleOsc = osc
            }
            let gctVal = watchManager.groundContactTime
            if gctVal > 0 {
                groundContactTime = gctVal
                gctReadings.append(gctVal)
                sampleGCT = gctVal
            }
            let cadVal = watchManager.cadence
            if cadVal > 0 {
                cadence = cadVal
                cadenceReadings.append(cadVal)
                sampleCadence = cadVal
            }

            if sampleCadence > 0 || sampleOsc > 0 || sampleGCT > 0 {
                formSamples.append(RunningFormSample(
                    timestamp: Date(),
                    cadence: sampleCadence,
                    oscillation: sampleOsc,
                    groundContactTime: sampleGCT
                ))
            }

            if sampleCadence > 0 && AudioCoachManager.shared.announceCadenceFeedback {
                AudioCoachManager.shared.processCadence(sampleCadence, target: targetCadence)
            }
            if sampleGCT > 0 && AudioCoachManager.shared.announceRunningBiomechanics {
                AudioCoachManager.shared.processGroundContactTime(sampleGCT)
            }
            if sampleOsc > 0 && AudioCoachManager.shared.announceRunningBiomechanics {
                AudioCoachManager.shared.processVerticalOscillation(sampleOsc)
            }
            let stability = sensorAnalyzer.postureStability
            if stability > 0 {
                AudioCoachManager.shared.processRunningStability(stability)
            }
            checkFormDegradation()
        }
        .onChange(of: watchManager.heartRateSequence) {
            let bpm = watchManager.lastReceivedHeartRate
            guard bpm > 0 else { return }
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
        .confirmationDialog("End Session", isPresented: $showingCancelConfirmation, titleVisibility: .visible) {
            Button("Save") {
                endSession()
            }
            Button("Discard", role: .destructive) {
                discardSession()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to save or discard this session?")
        }
        .alert("Vehicle Detected", isPresented: $showingVehicleAlert) {
            Button("Stop & Save") {
                endSession()
            }
            Button("Keep Tracking", role: .cancel) {
                // Reset detection so it doesn't immediately trigger again
                highSpeedStartTime = nil
            }
        } message: {
            Text("It looks like you're traveling at vehicle speed. Would you like to stop tracking?")
        }
        .overlay(alignment: .top) {
            VoiceNoteRecordingOverlay()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: 12) {
            // Page indicator on left (for GPS mode)
            if usesGPS {
                HStack(spacing: 8) {
                    Capsule()
                        .fill(selectedTab == .stats ? AppColors.primary : Color.gray.opacity(0.3))
                        .frame(width: selectedTab == .stats ? 24 : 8, height: 8)
                    Capsule()
                        .fill(selectedTab == .map ? AppColors.primary : Color.gray.opacity(0.3))
                        .frame(width: selectedTab == .map ? 24 : 8, height: 8)
                }
                .animation(.spring(response: 0.3), value: selectedTab)

                // GPS signal indicator (for outdoor GPS runs)
                if let locManager = locationManager {
                    GPSSignalIndicator(quality: locManager.gpsSignalQuality, showLabel: false)
                        .help(locManager.gpsSignalQuality.impactDescription)
                }
            }

            Spacer()

            // Weather badge (for outdoor runs)
            if session.isOutdoor, let weather = currentWeather {
                WeatherBadgeView(weather: weather)
            }

            // Right side controls
            HStack(spacing: 8) {
                // Music control
                CompactMusicButton()

                // Mute coaching button
                Button {
                    AudioCoachManager.shared.isMuted.toggle()
                    if AudioCoachManager.shared.isMuted {
                        AudioCoachManager.shared.stopSpeaking()
                    }
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                } label: {
                    Image(systemName: AudioCoachManager.shared.isMuted ? "speaker.slash" : "speaker.wave.2")
                        .font(.body.weight(.medium))
                        .foregroundStyle(AudioCoachManager.shared.isMuted ? .red : .primary)
                        .frame(width: 44, height: 44)
                        .background(AppColors.cardBackground)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(AudioCoachManager.shared.isMuted ? Color.clear : AppColors.primary.opacity(0.3), lineWidth: 1)
                        )
                }

                // Voice notes button - only show when paused
                if !isRunning {
                    VoiceNoteToolbarButton { note in
                        let service = VoiceNotesService.shared
                        session.notes = service.appendNote(note, to: session.notes)
                    }
                    .frame(width: 44, height: 44)
                }

                // Close button
                Button(action: { showingCancelConfirmation = true }) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(AppColors.cardBackground)
                        .clipShape(Circle())
                }
            }
        }
    }

    // MARK: - Full Stats View with integrated pause/stop

    private var runningStatsFullView: some View {
        VStack(spacing: 0) {
            // Tap hint at top
            Text(!isRunning ? "Tap to Resume" : "Tap to Pause")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            // Stats - scrollable
            ScrollView(showsIndicators: false) {
                statsContentView
                    .padding(.horizontal)
            }

            Spacer(minLength: 20)

            // Pause/Resume button with stop option
            PauseResumeButton(
                isPaused: !isRunning,
                onTap: {
                    if isRunning {
                        pauseSession()
                    } else {
                        resumeSession()
                    }
                },
                onStop: { endSession() },
                onDiscard: { discardSession() }
            )
            .padding(.bottom, 20)
        }
    }

    // MARK: - Stats Content View

    private var statsContentView: some View {
        VStack(spacing: 16) {
            Spacer()

            // Program interval overlay (walk/run phases)
            if let intervals = programIntervals, !intervals.isEmpty {
                ProgramLiveOverlay(
                    intervals: intervals,
                    elapsedTime: elapsedTime,
                    isRunning: isRunning
                )
            }

            // Duration
            VStack(spacing: 4) {
                Text("Duration")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(formatTime(elapsedTime))
                    .scaledFont(size: 56, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                    .monospacedDigit()
            }

            // Session-specific metrics
            switch session.sessionType {
            case .intervals:
                intervalMetrics
            case .timeTrial:
                tetrathlonMetrics
            default:
                runMetrics
            }

            Spacer()
        }
    }

    // MARK: - Running Map View

    @ViewBuilder
    private var runningMapView: some View {
        LiveSessionMapView(
            routeSegments: {
                let coords = gpsTracker?.routeCoordinates ?? []
                guard coords.count > 1 else { return [] }
                return [RouteSegment(coordinates: coords, color: AppColors.primary)]
            }(),
            followsUser: false,
            onBack: {
                withAnimation {
                    selectedTab = .stats
                }
            }
        )
    }

    // MARK: - Location Tracking

    private func startLocationTracking() {
        guard usesGPS, let tracker = gpsTracker else {
            Log.location.error("Running: startLocationTracking skipped — usesGPS=\(usesGPS), gpsTracker=\(gpsTracker == nil ? "nil" : "set")")
            return
        }

        Log.location.info("Running: setting up GPS session tracker")

        // Persist filtered locations as RunningLocationPoints
        tracker.insertLocationPoint = { [self] location, ctx in
            let point = RunningLocationPoint(from: location)
            point.session = self.session
            ctx.insert(point)
        }

        // Running-specific logic after each filtered GPS point
        tracker.onLocationProcessed = { [self] location, distanceDelta in
            // Sync distance and elevation from tracker (Kalman-filtered)
            self.session.totalDistance = tracker.totalDistance
            self.session.totalAscent = tracker.elevationGain
            self.session.totalDescent = tracker.elevationLoss

            // Outdoor run: detect km boundary crossing for split announcements
            if !self.isTrackMode {
                let currentKm = Int(self.session.totalDistance / 1000)
                if currentKm > self.lastAnnouncedKm && currentKm > 0 {
                    let splitDuration = self.elapsedTime - self.lastKmSplitTime
                    self.lastAnnouncedKm = currentKm
                    self.lastKmSplitTime = self.elapsedTime

                    let split = RunningSplit(orderIndex: currentKm - 1, distance: 1000)
                    split.duration = splitDuration
                    if self.currentHeartRate > 0 { split.heartRate = self.currentHeartRate }
                    if self.cadence > 0 { split.cadence = self.cadence }
                    split.session = self.session
                    if self.session.splits == nil { self.session.splits = [] }
                    self.session.splits?.append(split)
                    self.modelContext.insert(split)

                    if AudioCoachManager.shared.announceRunningPace {
                        let splitPace = splitDuration
                        let remaining = self.targetDistance > 0
                            ? self.targetDistance - self.session.totalDistance : nil
                        AudioCoachManager.shared.announceKmSplit(
                            km: currentKm,
                            averagePace: splitPace,
                            gapMeters: nil,
                            remaining: remaining
                        )
                    }

                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
            }

            // Update virtual pacer with current distance
            if VirtualPacer.shared.isActive {
                VirtualPacer.shared.update(distance: self.session.totalDistance, elapsedTime: self.elapsedTime)
            }

            // Vehicle detection
            self.checkForVehicleSpeed(location.speed)

            // Track mode: auto-detect laps via LapDetector
            if self.isTrackMode {
                self.lapDetector.processLocation(location, elapsedTime: self.elapsedTime)
            }

            // Family sharing location update (throttled every 10 seconds)
            if self.shareWithFamily {
                let now = Date()
                if now.timeIntervalSince(self.lastSharingUpdateTime) >= self.sharingUpdateInterval {
                    self.lastSharingUpdateTime = now
                    let currentSpeed = location.speed >= 0 ? location.speed : 0
                    let gait = RunningPhase.fromGPSSpeed(currentSpeed).toGaitType
                    Task {
                        await self.sharingCoordinator.updateSharedLocation(
                            location: location,
                            gait: gait,
                            distance: self.session.totalDistance,
                            duration: self.elapsedTime
                        )
                    }
                }
            }
        }

        Log.location.info("Running: starting GPS session tracker")
        Task {
            await tracker.start(
                subscriberId: "running",
                activityType: .running,
                modelContext: modelContext,
                workoutLifecycle: workoutLifecycle
            )
            Log.location.info("Running: GPS session tracker started")
        }
    }

    private func checkForVehicleSpeed(_ speed: Double) {
        if speed > vehicleSpeedThreshold {
            if highSpeedStartTime == nil {
                highSpeedStartTime = Date()
            } else if let start = highSpeedStartTime,
                      Date().timeIntervalSince(start) > vehicleDetectionDuration {
                // Sustained high speed detected - show alert
                if !showingVehicleAlert {
                    showingVehicleAlert = true
                    AudioCoachManager.shared.announce("It looks like you may be in a vehicle. Would you like to stop tracking?")
                }
            }
        } else {
            // Speed dropped below threshold - reset detection
            highSpeedStartTime = nil
        }
    }

    private func stopLocationTracking() {
        gpsTracker?.stop()
    }

    // Watch motion & HR callbacks removed — using .onChange(of:) modifiers

    private func startMotionTracking() {
        // Start workout lifecycle for Watch mirroring + HealthKit tracking
        Task {
            do {
                let config = HKWorkoutConfiguration()
                config.activityType = .running
                config.locationType = usesGPS ? .outdoor : .indoor
                try await workoutLifecycle.startWorkout(configuration: config)
                Log.tracking.info("Started workout lifecycle for running with Watch mirroring")
            } catch {
                Log.tracking.error("Failed to start workout lifecycle: \(error)")
            }
        }

        watchManager.resetMotionMetrics()
        // Motion tracking is started by WorkoutLifecycleService — no duplicate send here
        sensorAnalyzer.startSession(discipline: .running)
        startWatchStatusUpdates()
    }

    private func stopMotionTracking() {
        var runMetadata: [String: Any] = [
            HKMetadataKeyIndoorWorkout: !usesGPS,
            "SessionType": session.sessionType.rawValue
        ]
        if let weather = currentWeather {
            runMetadata["Temperature"] = weather.temperature
            runMetadata["Humidity"] = weather.humidity
        }

        // Build interval segment events for HealthKit
        var hkEvents: [HKWorkoutEvent] = []
        if intervalSettings != nil && phaseTransitions.count > 1 {
            for i in 0..<(phaseTransitions.count - 1) {
                let transition = phaseTransitions[i]
                let nextStart = phaseTransitions[i + 1].start
                let interval = DateInterval(start: transition.start, end: nextStart)
                let event = HKWorkoutEvent(type: .segment, dateInterval: interval, metadata: [
                    "Phase": "\(transition.phase)",
                    "IntervalIndex": i + 1
                ])
                hkEvents.append(event)
            }
            // Last phase segment up to now
            if let last = phaseTransitions.last {
                let interval = DateInterval(start: last.start, end: Date())
                hkEvents.append(HKWorkoutEvent(type: .segment, dateInterval: interval, metadata: [
                    "Phase": "\(last.phase)",
                    "IntervalIndex": phaseTransitions.count
                ]))
            }
        }

        // Track mode: add lap events to HealthKit
        if isTrackMode && !lapDetector.lapTimes.isEmpty {
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

        // Begin non-blocking workout save (awaited in parent view's onEnd)
        workoutLifecycle.beginEndAndSave(
            metadata: runMetadata,
            events: hkEvents.isEmpty ? nil : hkEvents
        )

        watchManager.stopMotionTracking()
        sensorAnalyzer.stopSession()
        stopWatchStatusUpdates()

        // Save heart rate data to session
        if !heartRateReadings.isEmpty {
            session.averageHeartRate = heartRateReadings.reduce(0, +) / heartRateReadings.count
            session.maxHeartRate = maxHeartRate
            session.minHeartRate = minHeartRate == Int.max ? 0 : minHeartRate
        }

        // Save timestamped heart rate samples
        if !heartRateSamples.isEmpty {
            session.heartRateSamples = heartRateSamples
        }

        // Save cadence data to session
        if !cadenceReadings.isEmpty {
            session.averageCadence = cadenceReadings.reduce(0, +) / cadenceReadings.count
            session.maxCadence = cadenceReadings.max() ?? 0
        }

        // Save running form metrics to session
        if !oscillationReadings.isEmpty {
            session.averageVerticalOscillation = oscillationReadings.reduce(0, +) / Double(oscillationReadings.count)
        }
        if !gctReadings.isEmpty {
            session.averageGroundContactTime = gctReadings.reduce(0, +) / Double(gctReadings.count)
        }

        // Save timestamped form samples
        if !formSamples.isEmpty {
            session.runningFormSamples = formSamples
        }

        // Capture peak HR at end for recovery calculation
        session.peakHeartRateAtEnd = currentHeartRate > 0 ? currentHeartRate : maxHeartRate

        // Start recovery HR tracking (keep listening for 60s)
        startRecoveryTracking()

        // Save enhanced sensor data from WatchSensorAnalyzer
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

        // Save elevation data from sensor analyzer only as fallback
        // GPSSessionTracker barometric elevation (~0.3m accuracy) is preferred
        if session.totalAscent == 0 && runningSummary.totalElevationGain > 0 {
            session.totalAscent = runningSummary.totalElevationGain
        }
        if session.totalDescent == 0 && runningSummary.totalElevationLoss > 0 {
            session.totalDescent = runningSummary.totalElevationLoss
        }

        // Save weather to session
        if let weather = currentWeather {
            session.startWeather = weather
        }
    }

    // MARK: - Watch Status Updates

    private func startWatchStatusUpdates() {
        // Send initial status
        sendStatusToWatch()

        // Start periodic updates on background queue
        let queue = DispatchQueue(label: "dev.dreamfold.tetratrack.watchUpdate", qos: .utility)
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + 1.0, repeating: 1.0, leeway: .milliseconds(100))
        source.setEventHandler { [self] in
            DispatchQueue.main.async {
                self.sendStatusToWatch()
            }
        }
        source.resume()
        watchUpdateTimer = source
    }

    private func stopWatchStatusUpdates() {
        watchUpdateTimer?.cancel()
        watchUpdateTimer = nil
    }

    private func sendStatusToWatch() {
        watchManager.sendStatusUpdate(
            rideState: .tracking,
            duration: elapsedTime,
            distance: session.totalDistance,
            speed: session.totalDistance > 0 && elapsedTime > 0 ? session.totalDistance / elapsedTime : 0,
            gait: "Running",
            heartRate: currentHeartRate > 0 ? currentHeartRate : nil,
            heartRateZone: heartRateZone,
            averageHeartRate: averageHeartRate > 0 ? averageHeartRate : nil,
            maxHeartRate: maxHeartRate > 0 ? maxHeartRate : nil,
            horseName: nil,
            rideType: session.sessionType.rawValue,
            runningPhase: nil,
            asymmetryIndex: nil  // Phone IMU can't reliably compute - use HealthKit post-session
        )
    }

    private var heartRateZone: Int {
        // Simple zone calculation based on heart rate
        guard currentHeartRate > 0 else { return 1 }
        if currentHeartRate < 100 { return 1 }
        if currentHeartRate < 120 { return 2 }
        if currentHeartRate < 150 { return 3 }
        if currentHeartRate < 170 { return 4 }
        return 5
    }

    private var pacerGapColor: Color {
        switch VirtualPacer.shared.gapStatus {
        case .wellAhead: return .blue
        case .slightlyAhead, .onPace: return .green
        case .slightlyBehind: return .yellow
        case .wellBehind: return .red
        }
    }

    // MARK: - Recovery HR Tracking

    private func startRecoveryTracking() {
        isRecoveryPhase = true
        // HR updates flow via .onChange(of: watchManager.heartRateSequence) —
        // the modifier keeps currentHeartRate updated during recovery.
        // After 60 seconds, capture recovery HR.
        let queue = DispatchQueue(label: "dev.dreamfold.tetratrack.recoveryTimer", qos: .utility)
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + 60.0, repeating: .never, leeway: .milliseconds(500))
        source.setEventHandler { [self] in
            DispatchQueue.main.async {
                if self.currentHeartRate > 0 {
                    self.session.recoveryHeartRate = self.currentHeartRate
                }
                self.isRecoveryPhase = false
                self.recoveryTimer = nil
            }
        }
        source.resume()
        recoveryTimer = source
    }

    // MARK: - Weather

    private func fetchWeather() {
        guard session.isOutdoor else { return }

        Task {
            do {
                // Use location from LocationManager or default
                let location = CLLocation(latitude: 51.5074, longitude: -0.1278)  // Default to London
                let weather = try await weatherService.fetchWeather(for: location)
                await MainActor.run {
                    currentWeather = weather
                    session.startWeather = weather
                }
            } catch {
                Log.services.error("RunningLiveView: Failed to fetch weather - \(error)")
            }
        }
    }

    private var averageHeartRate: Int {
        guard !heartRateReadings.isEmpty else { return 0 }
        return heartRateReadings.reduce(0, +) / heartRateReadings.count
    }

    // MARK: - Session Color

    private var sessionColor: Color {
        switch session.sessionType {
        case .easy: return .green
        case .tempo: return .yellow
        case .intervals: return .orange
        case .longRun: return .blue
        case .recovery: return .mint
        case .race: return .red
        case .timeTrial: return .purple
        case .fartlek: return .pink
        case .treadmill: return .mint
        case .walking: return .teal
        }
    }

    // MARK: - Run Metrics (General Running)

    private var runMetrics: some View {
        VStack(spacing: 24) {
            // Distance - prominent
            VStack(spacing: 4) {
                Text(formatDistance(session.totalDistance))
                    .scaledFont(size: 48, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                    .monospacedDigit()
                    .foregroundStyle(AppColors.primary)
            }

            // Track mode: Lap counter
            if isTrackMode && lapDetector.lapCount > 0 {
                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("\(lapDetector.lapCount)")
                            .scaledFont(size: 36, weight: .bold, design: .rounded, relativeTo: .title)
                            .foregroundStyle(.cyan)
                        Text("Laps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let lastLap = lapDetector.lapTimes.last {
                        VStack(spacing: 4) {
                            Text(formatTime(lastLap))
                                .scaledFont(size: 28, weight: .semibold, design: .rounded, relativeTo: .title2)
                                .monospacedDigit()
                                .foregroundStyle(splitComparisonColor)
                            Text("Last Lap")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if lapDetector.lapTimes.count >= 2 {
                        VStack(spacing: 4) {
                            Text(formatTime(lapDetector.averageLapTime))
                                .scaledFont(size: 28, weight: .semibold, design: .rounded, relativeTo: .title2)
                                .monospacedDigit()
                            Text("Avg Lap")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Track mode: Live lap split chart
            if isTrackMode && lapDetector.lapTimes.count >= 2 {
                TrackLapSplitChart(lapTimes: lapDetector.lapTimes, compact: true)
                    .frame(height: 120)
                    .padding(.horizontal)
            }

            // Pace
            HStack(spacing: 40) {
                VStack(spacing: 4) {
                    Text("Current Pace")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(currentPace)
                        .scaledFont(size: 28, weight: .semibold, design: .rounded, relativeTo: .title2)
                        .monospacedDigit()
                }

                VStack(spacing: 4) {
                    Text("Avg Pace")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(averagePace)
                        .scaledFont(size: 28, weight: .semibold, design: .rounded, relativeTo: .title2)
                        .monospacedDigit()
                }
            }

            // Virtual Pacer (when active)
            if VirtualPacer.shared.isActive {
                VStack(spacing: 8) {
                    // Gap indicator
                    HStack(spacing: 8) {
                        Image(systemName: VirtualPacer.shared.gapStatus.icon)
                            .foregroundStyle(pacerGapColor)
                        Text(VirtualPacer.shared.formattedGap)
                            .scaledFont(size: 32, weight: .bold, design: .rounded, relativeTo: .title)
                            .foregroundStyle(pacerGapColor)
                    }

                    HStack(spacing: 24) {
                        VStack(spacing: 2) {
                            Text(VirtualPacer.shared.formattedCurrentPace)
                                .font(.headline.monospacedDigit())
                            Text("Current")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        VStack(spacing: 2) {
                            Text(VirtualPacer.shared.formattedTargetPace)
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(.cyan)
                            Text("Target")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(VirtualPacer.shared.gapStatus.description)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(pacerGapColor)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Heart rate (when Watch connected and receiving)
            if currentHeartRate > 0 {
                HStack(spacing: 24) {
                    // Current heart rate with pulsing icon
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                                .symbolEffect(.pulse, options: .repeating)
                            Text("\(currentHeartRate)")
                                .scaledFont(size: 32, weight: .bold, design: .rounded, relativeTo: .title)
                        }
                        Text("bpm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if averageHeartRate > 0 {
                        VStack(spacing: 4) {
                            Text("\(averageHeartRate)")
                                .scaledFont(size: 22, weight: .semibold, design: .rounded, relativeTo: .title3)
                            Text("Avg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if maxHeartRate > 0 {
                        VStack(spacing: 4) {
                            Text("\(maxHeartRate)")
                                .scaledFont(size: 22, weight: .semibold, design: .rounded, relativeTo: .title3)
                                .foregroundStyle(.red)
                            Text("Max")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Watch running metrics (when connected)
            if watchManager.isReachable && (cadence > 0 || verticalOscillation > 0) {
                HStack(spacing: 24) {
                    // Cadence
                    VStack(spacing: 4) {
                        Text("Cadence")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 2) {
                            Text("\(cadence)")
                                .scaledFont(size: 22, weight: .semibold, design: .rounded, relativeTo: .title3)
                            Text("spm")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(cadenceColor)
                        if targetCadence > 0 {
                            Text("Target: \(targetCadence)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Vertical Oscillation
                    VStack(spacing: 4) {
                        Text("Oscillation")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 2) {
                            Text(String(format: "%.1f", verticalOscillation))
                                .scaledFont(size: 22, weight: .semibold, design: .rounded, relativeTo: .title3)
                            Text("cm")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(oscillationColor)
                    }

                    // Ground Contact Time
                    VStack(spacing: 4) {
                        Text("Contact")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 2) {
                            Text(String(format: "%.0f", groundContactTime))
                                .scaledFont(size: 22, weight: .semibold, design: .rounded, relativeTo: .title3)
                            Text("ms")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(gctColor)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Enhanced sensor metrics (SpO2, breathing, fatigue)
            if sensorAnalyzer.oxygenSaturation > 0 || sensorAnalyzer.breathingRate > 0 || sensorAnalyzer.fatigueScore > 0 {
                Divider()
                    .padding(.vertical, 8)

                RunningSensorMetricsView(
                    elevationGain: sensorAnalyzer.totalElevationGain,
                    elevationLoss: sensorAnalyzer.totalElevationLoss,
                    breathingRate: sensorAnalyzer.breathingRate,
                    breathingTrend: sensorAnalyzer.breathingRateTrend,
                    spo2: sensorAnalyzer.oxygenSaturation,
                    minSpo2: sensorAnalyzer.minSpO2,
                    postureStability: sensorAnalyzer.postureStability,
                    fatigueScore: sensorAnalyzer.fatigueScore
                )
            }
        }
    }

    // Running form indicator colors
    private var cadenceColor: Color {
        if targetCadence > 0 {
            let deviation = abs(cadence - targetCadence)
            if deviation <= 5 { return .green }
            if deviation <= 15 { return .yellow }
            return .orange
        }
        if cadence >= 170 && cadence <= 190 { return .green }  // Ideal range
        if cadence >= 160 && cadence <= 200 { return .yellow } // Acceptable
        return .orange
    }

    private var oscillationColor: Color {
        if verticalOscillation <= 8.0 { return .green }  // Efficient
        if verticalOscillation <= 10.0 { return .yellow }
        return .orange  // Too bouncy
    }

    private var gctColor: Color {
        if groundContactTime <= 250 { return .green }  // Good
        if groundContactTime <= 300 { return .yellow }
        return .orange  // Too long
    }

    // MARK: - Tetrathlon Metrics

    // MARK: - Projected Points

    private var projectedPoints: Double {
        guard targetDistance > 0, session.totalDistance > 50, elapsedTime > 0 else { return 0 }
        let percentComplete = session.totalDistance / targetDistance
        guard percentComplete > 0.05 else { return 0 }
        let projectedTime = elapsedTime / percentComplete
        return max(0, 1000.0 - ((projectedTime - standardTime) * 3.0))
    }

    private var projectedPointsColor: Color {
        let pts = projectedPoints
        if pts >= 1000 { return .green }
        if pts >= 800 { return .purple }
        return .orange
    }

    private var tetrathlonMetrics: some View {
        VStack(spacing: 20) {
            // Goal distance and progress
            VStack(spacing: 4) {
                Text(formatDistanceGoal(targetDistance))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatDistance(session.totalDistance))
                    .scaledFont(size: 48, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                    .monospacedDigit()
                    .foregroundStyle(.purple)

                // Progress bar
                if targetDistance > 0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(.systemGray5))
                                .frame(height: 8)
                            Capsule()
                                .fill(Color.purple)
                                .frame(width: min(geo.size.width, geo.size.width * (session.totalDistance / targetDistance)), height: 8)
                        }
                    }
                    .frame(height: 8)
                    .padding(.horizontal, 40)
                }
            }

            // Projected Tetrathlon Points
            if projectedPoints > 0 {
                VStack(spacing: 4) {
                    Text("Projected Points")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(projectedPoints))")
                        .scaledFont(size: 44, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                        .monospacedDigit()
                        .foregroundStyle(projectedPointsColor)

                    let standardMins = Int(standardTime) / 60
                    let standardSecs = Int(standardTime) % 60
                    Text("1000-pt target: \(standardMins):\(String(format: "%02d", standardSecs))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Pace comparison with PB
            let pbPace = personalBests.paceFromPB(for: targetDistance)

            HStack(spacing: 24) {
                // Current Pace
                VStack(spacing: 4) {
                    Text("Current")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(currentPace)
                        .scaledFont(size: 24, weight: .semibold, design: .rounded, relativeTo: .title3)
                        .monospacedDigit()
                        .foregroundStyle(paceComparisonColor(current: currentPaceSeconds, pb: pbPace))
                }

                // Average Pace
                VStack(spacing: 4) {
                    Text("Average")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(averagePace)
                        .scaledFont(size: 24, weight: .semibold, design: .rounded, relativeTo: .title3)
                        .monospacedDigit()
                        .foregroundStyle(paceComparisonColor(current: averagePaceSeconds, pb: pbPace))
                }

                // PB Pace
                VStack(spacing: 4) {
                    Text("PB Pace")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(pbPace > 0 ? formatPace(pbPace) : "--:--")
                        .scaledFont(size: 24, weight: .semibold, design: .rounded, relativeTo: .title3)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            // PB info
            VStack(spacing: 8) {
                HStack {
                    Text("Personal Best")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(personalBests.formattedPB(for: targetDistance))
                        .font(.subheadline.bold())
                        .foregroundStyle(.purple)
                }

                // Track lap split comparison
                if lapDetector.lastLapTime > 0 {
                    HStack {
                        Text("Last \(Int(session.trackLength))m")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatTime(lapDetector.lastLapTime))
                            .font(.subheadline.bold())
                            .foregroundStyle(splitComparisonColor)
                    }
                }
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    private func paceComparisonColor(current: TimeInterval, pb: TimeInterval) -> Color {
        guard pb > 0, current > 0 else { return .primary }
        let diff = current - pb
        if diff < -5 { return .green }      // Faster than PB
        if diff > 10 { return .red }        // Slower than PB
        return .yellow                       // Close to PB
    }

    private var splitComparisonColor: Color {
        let pbLap = personalBests.personalBest(for: session.trackLength)
        guard pbLap > 0, lapDetector.lastLapTime > 0 else { return .primary }
        if lapDetector.lastLapTime < pbLap { return .green }
        if lapDetector.lastLapTime > pbLap * 1.1 { return .red }
        return .yellow
    }

    private func formatDistanceGoal(_ distance: Double) -> String {
        if distance >= 1000 {
            return String(format: "Goal: %.0fm", distance)
        }
        return String(format: "Goal: %.0fm", distance)
    }

    // MARK: - Interval Metrics

    private var intervalMetrics: some View {
        VStack(spacing: 20) {
            // Phase indicator with countdown
            if let settings = intervalSettings {
                VStack(spacing: 8) {
                    Text(phaseDisplayName)
                        .font(.title2.bold())
                        .foregroundStyle(phaseColor)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(phaseColor.opacity(0.2))
                        .clipShape(Capsule())

                    // Phase countdown
                    if workoutPhase != .finished {
                        Text(formatTime(phaseTimeRemaining))
                            .scaledFont(size: 48, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                            .monospacedDigit()
                            .foregroundStyle(phaseColor)
                    }
                }

                // Progress info
                HStack(spacing: 32) {
                    VStack(spacing: 4) {
                        Text("Interval")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(intervalCount) / \(settings.numberOfIntervals)")
                            .scaledFont(size: 24, weight: .bold, design: .rounded, relativeTo: .title3)
                    }

                    VStack(spacing: 4) {
                        Text("Phase Time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatTime(phaseTime))
                            .scaledFont(size: 24, weight: .semibold, design: .rounded, relativeTo: .title3)
                            .monospacedDigit()
                    }
                }

                // Work/Rest durations
                HStack(spacing: 20) {
                    Label("\(Int(settings.workDuration))s work", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Label("\(Int(settings.restDuration))s rest", systemImage: "pause.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                .padding(.top, 8)
            } else {
                // Fallback for manual interval tracking
                HStack(spacing: 16) {
                    Text(isWorkPhase ? "WORK" : "REST")
                        .font(.title2.bold())
                        .foregroundStyle(isWorkPhase ? .orange : .green)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background((isWorkPhase ? Color.orange : Color.green).opacity(0.2))
                        .clipShape(Capsule())

                    Button(action: togglePhase) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 32) {
                    VStack(spacing: 4) {
                        Text("Interval")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("#\(intervalCount)")
                            .scaledFont(size: 32, weight: .bold, design: .rounded, relativeTo: .title)
                    }

                    VStack(spacing: 4) {
                        Text("Phase Time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatTime(phaseTime))
                            .scaledFont(size: 32, weight: .semibold, design: .rounded, relativeTo: .title)
                            .monospacedDigit()
                    }
                }
            }

            // Distance
            VStack(spacing: 4) {
                Text("Total Distance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatDistance(session.totalDistance))
                    .scaledFont(size: 20, weight: .semibold, design: .rounded, relativeTo: .title3)
                    .monospacedDigit()
            }
        }
    }

    private var phaseDisplayName: String {
        switch workoutPhase {
        case .warmup: return "WARMUP"
        case .work: return "WORK"
        case .rest: return "REST"
        case .cooldown: return "COOLDOWN"
        case .finished: return "FINISHED"
        }
    }

    private var phaseColor: Color {
        switch workoutPhase {
        case .warmup: return .blue
        case .work: return .orange
        case .rest: return .green
        case .cooldown: return .blue
        case .finished: return .purple
        }
    }

    private var phaseTimeRemaining: TimeInterval {
        guard let settings = intervalSettings else { return 0 }
        let phaseDuration: TimeInterval
        switch workoutPhase {
        case .warmup: phaseDuration = settings.warmupDuration
        case .work: phaseDuration = settings.workDuration
        case .rest: phaseDuration = settings.restDuration
        case .cooldown: phaseDuration = settings.cooldownDuration
        case .finished: return 0
        }
        return max(0, phaseDuration - phaseTime)
    }

    // MARK: - Pace Calculations

    private var averagePaceSeconds: TimeInterval {
        guard session.totalDistance > 0 else { return 0 }
        return (elapsedTime / session.totalDistance) * 1000
    }

    private var averagePace: String {
        guard session.totalDistance > 100 else { return "--:--" }
        return formatPace(averagePaceSeconds)
    }

    private var currentPaceSeconds: TimeInterval {
        guard session.totalDistance > 0 else { return 0 }
        return (elapsedTime / session.totalDistance) * 1000
    }

    private var currentPace: String {
        guard session.totalDistance > 100 else { return "--:--" }
        return formatPace(currentPaceSeconds)
    }

    private func formatPace(_ secondsPerKm: TimeInterval) -> String {
        let mins = Int(secondsPerKm) / 60
        let secs = Int(secondsPerKm) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Form Degradation Detection

    private func checkFormDegradation() {
        // Need at least 20 samples and check every 10 new samples (~30s at 3s intervals)
        guard formSamples.count >= 20,
              formSamples.count - lastDegradationCheckCount >= 10 else { return }
        lastDegradationCheckCount = formSamples.count

        // Throttle alerts to at most once per 90 seconds
        guard Date().timeIntervalSince(lastDegradationAlertTime) > 90 else { return }

        let bio = RunnerBiomechanics()
        let analysis = bio.formDegradation(
            oscillationSamples: formSamples.map(\.oscillation),
            gctSamples: formSamples.map(\.groundContactTime),
            cadenceSamples: formSamples.map { Double($0.cadence) }
        )

        guard analysis.hasDegradation else { return }
        lastDegradationAlertTime = Date()

        if analysis.cadenceDegraded {
            AudioCoachManager.shared.announce("Cadence dropping — focus on quick, light steps")
        } else if analysis.gctDegraded {
            AudioCoachManager.shared.announce("Ground contact rising — think hot coals, quick feet")
        } else if analysis.oscillationDegraded {
            AudioCoachManager.shared.announce("Bouncing more — run tall, engage your core")
        }
    }

    // MARK: - Timer & Actions

    private func startTimer() {
        // Initialize interval workout phase
        if let settings = intervalSettings {
            let initialPhase: IntervalWorkoutPhase = settings.includeWarmup ? .warmup : .work
            workoutPhase = initialPhase
            phaseTransitions = [(phase: initialPhase, start: Date())]
        }

        Log.location.info("Running: startTimer() called")

        timerSource?.cancel()
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now(), repeating: .seconds(1))
        source.setEventHandler { [self] in
            guard isRunning else { return }
            let newElapsed = gpsTracker?.elapsedTime ?? 0
            let delta = newElapsed - elapsedTime
            elapsedTime = newElapsed
            phaseTime += delta
            session.totalDuration = elapsedTime

            // Sync distance during pedometer fallback (GPS gaps)
            if let tracker = gpsTracker, tracker.isUsingPedometerFallback {
                session.totalDistance = tracker.totalDistance
            }

            // HR fallback: use HKWorkoutBuilder HR when companion HR isn't flowing
            if !hasWCSessionHR {
                let lifecycleHR = Int(workoutLifecycle.liveHeartRate)
                if lifecycleHR > 0 {
                    currentHeartRate = lifecycleHR
                    heartRateReadings.append(lifecycleHR)
                    if lifecycleHR > maxHeartRate { maxHeartRate = lifecycleHR }
                    if lifecycleHR < minHeartRate { minHeartRate = lifecycleHR }
                    heartRateSamples.append(HeartRateSample(
                        timestamp: Date(),
                        bpm: lifecycleHR,
                        maxHeartRate: estimatedMaxHR
                    ))
                }
            }

            // Handle automatic phase transitions for intervals
            if intervalSettings != nil {
                checkPhaseTransition()
            }

            // Tetrathlon practice coaching: checkpoint announcements (time trials)
            if session.sessionType == .timeTrial && targetDistance > 0 && AudioCoachManager.shared.announcePBRaceCoaching {
                let pbTime = personalBests.personalBest(for: targetDistance)
                if session.totalDistance > 0 {
                    let checkpoints = PacerSettings.pbCheckpointFractions
                    let percentComplete = session.totalDistance / targetDistance

                    // Distance-based checkpoint announcements with tetrathlon points
                    for (index, fraction) in checkpoints.enumerated() {
                        if percentComplete >= fraction && index > lastAnnouncedCheckpointIndex {
                            lastAnnouncedCheckpointIndex = index
                            let expectedPBTime = pbTime > 0 ? pbTime * fraction : 0
                            AudioCoachManager.shared.announceTetrathlonCheckpoint(
                                distanceCovered: session.totalDistance,
                                totalDistance: targetDistance,
                                currentTime: elapsedTime,
                                expectedPBTime: expectedPBTime,
                                standardTime: standardTime
                            )

                            // Capture PB checkpoint for post-session insights
                            coachingData.pbCheckpoints.append(PBCheckpointRecord(
                                distanceFraction: fraction,
                                distanceMeters: session.totalDistance,
                                currentTime: elapsedTime,
                                expectedTime: expectedPBTime
                            ))
                        }
                    }

                    // Encouragement at 25%, 50%, 75%, 90%
                    let percentInt = Int(percentComplete * 100)
                    let encouragementThresholds = [25, 50, 75, 90]
                    for threshold in encouragementThresholds {
                        if percentInt >= threshold && lastPBEncouragementPercent < threshold {
                            lastPBEncouragementPercent = threshold
                            let expectedTime = pbTime > 0 ? pbTime * percentComplete : 0
                            let isAhead = pbTime > 0 ? elapsedTime < expectedTime : true
                            AudioCoachManager.shared.announcePBEncouragement(
                                percentComplete: percentComplete,
                                isAhead: isAhead
                            )
                        }
                    }
                }
            }

            // Virtual pacer: periodic gap announcements (~every 60s)
            if VirtualPacer.shared.isActive && AudioCoachManager.shared.announceVirtualPacer {
                let timeSinceLastAnnouncement = elapsedTime - lastPacerAnnouncementTime
                if timeSinceLastAnnouncement >= 60 && session.totalDistance > 100 {
                    lastPacerAnnouncementTime = elapsedTime
                    AudioCoachManager.shared.announceGapStatus(
                        gapSeconds: VirtualPacer.shared.gapTime,
                        gapMeters: VirtualPacer.shared.gapDistance,
                        isAhead: VirtualPacer.shared.isAhead
                    )

                    // Capture pacer gap for post-session insights
                    coachingData.pacerGapSnapshots.append(PacerGapSnapshot(
                        elapsedTime: elapsedTime,
                        gapSeconds: VirtualPacer.shared.gapTime,
                        gapMeters: VirtualPacer.shared.gapDistance,
                        isAhead: VirtualPacer.shared.isAhead
                    ))

                    // Pace alert when significantly off target (>15s/km difference)
                    let paceNow = averagePaceSeconds
                    let pacerTarget = VirtualPacer.shared.targetPace
                    if paceNow > 0 && pacerTarget > 0 && abs(paceNow - pacerTarget) > 15 {
                        AudioCoachManager.shared.announcePaceAlert(
                            currentPace: paceNow,
                            targetPace: pacerTarget
                        )
                    }
                }
            }

            // Interval coaching: countdown when <=10 seconds remain in current phase
            if intervalSettings != nil && workoutPhase != .finished {
                let remaining = Int(phaseTimeRemaining)
                if remaining <= 10 && remaining > 0 && remaining < lastAnnouncedCountdown {
                    lastAnnouncedCountdown = remaining
                    AudioCoachManager.shared.runningCountdown(remaining)
                } else if remaining > 10 {
                    lastAnnouncedCountdown = Int.max
                }
            }

            // Program interval coaching: phase transitions and countdowns
            if let intervals = programIntervals, !intervals.isEmpty {
                processProgramIntervalCoaching(intervals: intervals)
            }

            // Process running form reminders
            AudioCoachManager.shared.processRunningFormReminder(elapsedTime: elapsedTime)
        }
        source.resume()
        timerSource = source
    }

    // MARK: - Program Interval Coaching

    private func processProgramIntervalCoaching(intervals: [ProgramInterval]) {
        // Flatten intervals (expanding repeat counts)
        let flat = intervals.flatMap { interval in
            (0..<interval.repeatCount).map { _ in
                (phase: interval.phase, duration: interval.durationSeconds)
            }
        }
        guard !flat.isEmpty else { return }

        // Find current interval index
        var accumulated: Double = 0
        var currentIndex = flat.count - 1
        var timeRemaining: Double = 0
        for (i, interval) in flat.enumerated() {
            if elapsedTime < accumulated + interval.duration {
                currentIndex = i
                timeRemaining = accumulated + interval.duration - elapsedTime
                break
            }
            accumulated += interval.duration
        }

        // Detect phase transition
        if currentIndex != lastProgramPhaseIndex {
            let phase = flat[currentIndex].phase
            let duration = flat[currentIndex].duration

            // Announce phase transition
            programAudioCoach.announcePhaseTransition(
                phase: phase,
                duration: duration,
                intervalIndex: currentIndex,
                totalIntervals: flat.count
            )

            // Announce interval progress when completing an interval
            if lastProgramPhaseIndex >= 0 {
                programAudioCoach.announceIntervalProgress(
                    completedIndex: lastProgramPhaseIndex,
                    totalIntervals: flat.count
                )
            }

            lastProgramPhaseIndex = currentIndex
            lastProgramCountdown = Int.max
        }

        // Countdown announcements (10 seconds and 3 seconds before phase change)
        let secondsRemaining = Int(timeRemaining)
        if secondsRemaining <= 10 && secondsRemaining > 0 && secondsRemaining < lastProgramCountdown {
            let nextPhase: IntervalPhase? = (currentIndex + 1 < flat.count) ? flat[currentIndex + 1].phase : nil
            programAudioCoach.announcePhaseCountdown(
                secondsRemaining: secondsRemaining,
                nextPhase: nextPhase
            )
            lastProgramCountdown = secondsRemaining
        } else if secondsRemaining > 10 {
            lastProgramCountdown = Int.max
        }
    }

    private func checkPhaseTransition() {
        guard let settings = intervalSettings else { return }

        let phaseDuration: TimeInterval
        switch workoutPhase {
        case .warmup: phaseDuration = settings.warmupDuration
        case .work: phaseDuration = settings.workDuration
        case .rest: phaseDuration = settings.restDuration
        case .cooldown: phaseDuration = settings.cooldownDuration
        case .finished: return
        }

        if phaseTime >= phaseDuration {
            advancePhase()
        }
    }

    private func advancePhase() {
        guard let settings = intervalSettings else { return }

        // Record completed phase performance for coaching insights
        let completedDuration = phaseTime
        let completedPhase = workoutPhase
        let targetDuration: TimeInterval
        switch completedPhase {
        case .warmup: targetDuration = settings.warmupDuration
        case .work: targetDuration = settings.workDuration
        case .rest: targetDuration = settings.restDuration
        case .cooldown: targetDuration = settings.cooldownDuration
        case .finished: targetDuration = 0
        }
        if completedPhase != .finished {
            let phaseLabel: String
            switch completedPhase {
            case .warmup: phaseLabel = "warmup"
            case .work: phaseLabel = "work"
            case .rest: phaseLabel = "rest"
            case .cooldown: phaseLabel = "cooldown"
            case .finished: phaseLabel = "finished"
            }
            coachingData.intervalPerformance.append(IntervalPerformanceRecord(
                intervalIndex: intervalCount,
                phaseRaw: phaseLabel,
                targetDuration: targetDuration,
                actualDuration: completedDuration
            ))
        }

        phaseTime = 0

        switch workoutPhase {
        case .warmup:
            workoutPhase = .work
        case .work:
            if intervalCount < settings.numberOfIntervals {
                workoutPhase = .rest
            } else if settings.includeCooldown {
                workoutPhase = .cooldown
            } else {
                workoutPhase = .finished
            }
        case .rest:
            intervalCount += 1
            workoutPhase = .work
        case .cooldown:
            workoutPhase = .finished
        case .finished:
            break
        }

        // Record phase transition timestamp for HealthKit segment events
        phaseTransitions.append((phase: workoutPhase, start: Date()))

        // Reset countdown tracker for new phase
        lastAnnouncedCountdown = Int.max

        // Audio coaching: interval phase announcements (gated by sessionStartEnd for Silent/Essential)
        if let settings = intervalSettings, AudioCoachManager.shared.announceSessionStartEnd {
            switch workoutPhase {
            case .work:
                AudioCoachManager.shared.announceRunningIntervalStart(
                    name: "Interval \(intervalCount)",
                    targetPace: nil
                )
            case .rest:
                AudioCoachManager.shared.announceIntervalRest(duration: settings.restDuration)
            case .finished:
                AudioCoachManager.shared.announce("Interval workout complete. \(settings.numberOfIntervals) intervals finished.")
            default:
                break
            }
        }

        // Haptic feedback on phase change
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(workoutPhase == .work ? .warning : .success)
    }

    private func pauseSession() {
        isRunning = false
        gpsTracker?.pause()
        workoutLifecycle.pause()
    }

    private func resumeSession() {
        gpsTracker?.resume()
        workoutLifecycle.resume()
        isRunning = true
    }

    private func endSession() {
        timerSource?.cancel()
        stopMotionTracking()
        stopLocationTracking()
        VirtualPacer.shared.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        session.endDate = Date()
        session.totalDuration = elapsedTime

        // Stop family sharing
        if shareWithFamily {
            Task { await sharingCoordinator.stopSharingLocation() }
        }

        // Stop LapDetector and announce track session complete
        if isTrackMode && lapDetector.lapCount > 0 {
            AudioCoachManager.shared.announceTrackSessionComplete(lapCount: lapDetector.lapCount)
            lapDetector.stop()
        }

        // Audio coaching: tetrathlon race complete for time trials
        if session.sessionType == .timeTrial && targetDistance > 0 && AudioCoachManager.shared.announcePBRaceCoaching {
            let pbTime = personalBests.personalBest(for: targetDistance)
            let isNewPB = pbTime > 0 ? elapsedTime < pbTime : true
            AudioCoachManager.shared.announceTetrathlonComplete(
                finalTime: elapsedTime,
                pbTime: pbTime,
                standardTime: standardTime,
                isNewPB: isNewPB
            )
        }

        // Audio coaching: announce run complete summary
        if AudioCoachManager.shared.announceSessionStartEnd && session.totalDistance > 100 {
            AudioCoachManager.shared.announceRunComplete(
                distance: session.totalDistance,
                duration: elapsedTime,
                averagePace: averagePaceSeconds,
                targetPace: nil
            )
        }

        // Auto-update practice PB for time trials
        if session.sessionType == .timeTrial && targetDistance > 0 {
            var pbs = RunningPersonalBests.shared
            pbs.updatePersonalBest(for: targetDistance, time: elapsedTime)
        }

        // Save coaching insights
        if session.sessionType == .timeTrial && targetDistance > 0 {
            let pbTime = personalBests.personalBest(for: targetDistance)
            if pbTime > 0 {
                coachingData.pbResult = PBResultRecord(
                    finalTime: elapsedTime, pbTime: pbTime, isNewPB: elapsedTime < pbTime
                )
            }
        }
        coachingData.announcementCount = AudioCoachManager.shared.sessionAnnouncementCount
        session.coachingSummary = coachingData

        // Fetch end weather for outdoor sessions
        if session.isOutdoor {
            Task {
                do {
                    let location = locationManager?.currentLocation ?? CLLocation(latitude: 51.5074, longitude: -0.1278)
                    let weather = try await weatherService.fetchWeather(for: location)
                    await MainActor.run {
                        session.endWeather = weather
                    }
                } catch {
                    Log.services.error("RunningLiveView: Failed to fetch end weather - \(error)")
                }
            }
        }

        onEnd()
    }

    private func discardSession() {
        timerSource?.cancel()

        // Discard workout lifecycle (don't save)
        Task {
            await workoutLifecycle.discard()
            workoutLifecycle.sendIdleStateToWatch()
            Log.tracking.info("Discarded workout lifecycle for running")
        }

        // Stop tracking
        watchManager.stopMotionTracking()
        sensorAnalyzer.stopSession()
        stopWatchStatusUpdates()

        stopLocationTracking()
        VirtualPacer.shared.stop()
        UIApplication.shared.isIdleTimerDisabled = false

        // Stop family sharing
        if shareWithFamily {
            Task { await sharingCoordinator.stopSharingLocation() }
        }

        onDiscard?()
    }

    private func togglePhase() {
        if isWorkPhase {
            intervalCount += 1
        }
        isWorkPhase.toggle()
        phaseTime = 0
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }
}

// MARK: - Treadmill Live View

struct TreadmillLiveView: View {
    @Bindable var session: RunningSession
    var targetCadence: Int = 0
    let onEnd: () -> Void
    var onDiscard: (() -> Void)?

    @Environment(\.modelContext) private var modelContext

    @State private var isRunning = true
    @State private var elapsedTime: TimeInterval = 0
    @State private var timerSource: DispatchSourceTimer?
    @State private var sessionStartTime: Date?
    @State private var pausedAccumulated: TimeInterval = 0
    @State private var lastPauseTime: Date?
    @State private var showingCancelConfirmation = false
    @State private var showingDistanceInput = false

    // Manual input fields
    @State private var manualDistanceKm: Double = 0.0
    @State private var manualDistanceText: String = ""
    @State private var manualSpeedKmh: Double = 0.0
    @State private var manualSpeedText: String = ""
    @State private var inclinePercentage: Double = 0.0

    // Watch heart rate tracking
    @State private var currentHeartRate: Int = 0
    @State private var maxHeartRate: Int = 0
    @State private var minHeartRate: Int = Int.max
    @State private var heartRateReadings: [Int] = []
    @State private var heartRateSamples: [HeartRateSample] = []
    @State private var hasWCSessionHR: Bool = false  // tracks whether WCSession is providing HR
    private var treadmillEstimatedMaxHR: Int { 190 }

    // Watch motion tracking (running form)
    @State private var verticalOscillation: Double = 0.0
    @State private var groundContactTime: Double = 0.0
    @State private var cadence: Int = 0
    @State private var cadenceReadings: [Int] = []
    @State private var oscillationReadings: [Double] = []
    @State private var gctReadings: [Double] = []
    @State private var formSamples: [RunningFormSample] = []

    // Form degradation detection
    @State private var lastDegradationCheckCount: Int = 0
    @State private var lastDegradationAlertTime: Date = .distantPast

    // Recovery tracking
    @State private var isRecoveryPhase = false
    @State private var recoveryTimer: DispatchSourceTimer?

    // Enhanced sensor data from Watch
    private let sensorAnalyzer = WatchSensorAnalyzer.shared

    // Watch status update timer
    @State private var watchUpdateTimer: DispatchSourceTimer?

    private let watchManager = WatchConnectivityManager.shared
    private let workoutLifecycle = WorkoutLifecycleService.shared

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 24) {
                // Header with audio controls, treadmill icon, and close button
                HStack {
                    CompactAudioControls()

                    Spacer()

                    // Watch connection indicator
                    if watchManager.isReachable {
                        HStack(spacing: 4) {
                            Image(systemName: "applewatch.radiowaves.left.and.right")
                            Text("Watch")
                        }
                        .font(.caption)
                        .foregroundStyle(.green)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "applewatch.slash")
                            Text("No Watch")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    // Close button
                    Button(action: { showingCancelConfirmation = true }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Duration - large display
                VStack(spacing: 4) {
                    Text("Duration")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(formatTime(elapsedTime))
                        .scaledFont(size: 56, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                        .monospacedDigit()
                }

                // Treadmill metrics
                treadmillMetrics

                Spacer()

                // Pause/Resume button with stop option
                PauseResumeButton(
                    isPaused: !isRunning,
                    onTap: {
                        if isRunning {
                            pauseSession()
                        } else {
                            resumeSession()
                        }
                    },
                    onStop: {
                        showingDistanceInput = true
                    },
                    onDiscard: {
                        discardSession()
                    }
                )
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, geometry.safeAreaInsets.top + 8)
            .padding(.bottom, geometry.safeAreaInsets.bottom + 8)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.mint.opacity(0.05),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .onAppear {
            // Start workout lifecycle for Watch mirroring (indoor running)
            Task {
                do {
                    let config = HKWorkoutConfiguration()
                    config.activityType = .running
                    config.locationType = .indoor
                    try await workoutLifecycle.startWorkout(configuration: config)
                    Log.tracking.info("Started workout lifecycle for treadmill with Watch mirroring")
                } catch {
                    Log.tracking.error("Failed to start workout lifecycle for treadmill: \(error)")
                }
            }

            startHeartRateTracking()
            startTimer()
            UIApplication.shared.isIdleTimerDisabled = true
            AudioCoachManager.shared.startRunningFormReminders()
        }
        .onDisappear {
            timerSource?.cancel()
            AudioCoachManager.shared.stopRunningFormReminders()
        }
        .onChange(of: watchManager.motionUpdateSequence) {
            guard watchManager.currentMotionMode == .running else { return }
            var sampleCadence: Int = 0
            var sampleOsc: Double = 0
            var sampleGCT: Double = 0

            let osc = watchManager.verticalOscillation
            if osc > 0 {
                verticalOscillation = osc
                oscillationReadings.append(osc)
                sampleOsc = osc
            }
            let gctVal = watchManager.groundContactTime
            if gctVal > 0 {
                groundContactTime = gctVal
                gctReadings.append(gctVal)
                sampleGCT = gctVal
            }
            let cadVal = watchManager.cadence
            if cadVal > 0 {
                cadence = cadVal
                cadenceReadings.append(cadVal)
                sampleCadence = cadVal
            }

            if sampleCadence > 0 || sampleOsc > 0 || sampleGCT > 0 {
                formSamples.append(RunningFormSample(
                    timestamp: Date(),
                    cadence: sampleCadence,
                    oscillation: sampleOsc,
                    groundContactTime: sampleGCT
                ))
            }

            if sampleCadence > 0 && AudioCoachManager.shared.announceCadenceFeedback {
                AudioCoachManager.shared.processCadence(sampleCadence, target: targetCadence)
            }
            if sampleGCT > 0 && AudioCoachManager.shared.announceRunningBiomechanics {
                AudioCoachManager.shared.processGroundContactTime(sampleGCT)
            }
            if sampleOsc > 0 && AudioCoachManager.shared.announceRunningBiomechanics {
                AudioCoachManager.shared.processVerticalOscillation(sampleOsc)
            }
            let stability = sensorAnalyzer.postureStability
            if stability > 0 {
                AudioCoachManager.shared.processRunningStability(stability)
            }
            checkFormDegradation()
        }
        .onChange(of: watchManager.heartRateSequence) {
            let bpm = watchManager.lastReceivedHeartRate
            guard bpm > 0 else { return }
            hasWCSessionHR = true
            currentHeartRate = bpm
            heartRateReadings.append(bpm)
            if bpm > maxHeartRate { maxHeartRate = bpm }
            if bpm < minHeartRate { minHeartRate = bpm }
            heartRateSamples.append(HeartRateSample(
                timestamp: Date(),
                bpm: bpm,
                maxHeartRate: treadmillEstimatedMaxHR
            ))
        }
        .confirmationDialog("End Session", isPresented: $showingCancelConfirmation, titleVisibility: .visible) {
            Button("Save") {
                endSession()
            }
            Button("Discard", role: .destructive) {
                discardSession()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to save or discard this session?")
        }
        .sheet(isPresented: $showingDistanceInput) {
            TreadmillDistanceInputView(
                distanceKm: $manualDistanceKm,
                distanceText: $manualDistanceText,
                speedKmh: $manualSpeedKmh,
                speedText: $manualSpeedText,
                incline: $inclinePercentage,
                duration: elapsedTime,
                onSave: {
                    endSession()
                },
                onCancel: {
                    showingDistanceInput = false
                }
            )
        }
        .presentationBackground(Color.black)
    }

    // MARK: - Treadmill Metrics View

    private var treadmillMetrics: some View {
        VStack(spacing: 24) {
            // Distance display (will be entered at end)
            VStack(spacing: 4) {
                Text("Distance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if manualDistanceKm > 0 {
                    Text(String(format: "%.2f km", manualDistanceKm))
                        .scaledFont(size: 48, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                        .foregroundStyle(.mint)
                } else {
                    Text("--.- km")
                        .scaledFont(size: 48, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                        .foregroundStyle(.secondary)
                }
                Text("Enter at end of workout")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Calculated pace (if distance and time available)
            HStack(spacing: 40) {
                VStack(spacing: 4) {
                    Text("Pace")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(calculatedPace)
                        .scaledFont(size: 28, weight: .semibold, design: .rounded, relativeTo: .title2)
                        .monospacedDigit()
                }

                VStack(spacing: 4) {
                    Text("Speed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(calculatedSpeed)
                        .scaledFont(size: 28, weight: .semibold, design: .rounded, relativeTo: .title2)
                        .monospacedDigit()
                }
            }

            // Heart rate (when Watch connected and receiving)
            if currentHeartRate > 0 {
                HStack(spacing: 24) {
                    // Current heart rate with pulsing icon
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                                .symbolEffect(.pulse, options: .repeating)
                            Text("\(currentHeartRate)")
                                .scaledFont(size: 32, weight: .bold, design: .rounded, relativeTo: .title)
                        }
                        Text("bpm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if averageHeartRate > 0 {
                        VStack(spacing: 4) {
                            Text("\(averageHeartRate)")
                                .scaledFont(size: 22, weight: .semibold, design: .rounded, relativeTo: .title3)
                            Text("Avg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if maxHeartRate > 0 {
                        VStack(spacing: 4) {
                            Text("\(maxHeartRate)")
                                .scaledFont(size: 22, weight: .semibold, design: .rounded, relativeTo: .title3)
                                .foregroundStyle(.red)
                            Text("Max")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Cadence display (from Watch)
            if cadence > 0 {
                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("Cadence")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 2) {
                            Text("\(cadence)")
                                .scaledFont(size: 22, weight: .semibold, design: .rounded, relativeTo: .title3)
                            Text("spm")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(treadmillCadenceColor)
                        if targetCadence > 0 {
                            Text("Target: \(targetCadence)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if verticalOscillation > 0 {
                        VStack(spacing: 4) {
                            Text("Oscillation")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 2) {
                                Text(String(format: "%.1f", verticalOscillation))
                                    .scaledFont(size: 22, weight: .semibold, design: .rounded, relativeTo: .title3)
                                Text("cm")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if groundContactTime > 0 {
                        VStack(spacing: 4) {
                            Text("Contact")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 2) {
                                Text(String(format: "%.0f", groundContactTime))
                                    .scaledFont(size: 22, weight: .semibold, design: .rounded, relativeTo: .title3)
                                Text("ms")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Incline indicator (if set)
            if inclinePercentage > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(.orange)
                    Text(String(format: "%.1f%% incline", inclinePercentage))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var treadmillCadenceColor: Color {
        if targetCadence > 0 {
            let deviation = abs(cadence - targetCadence)
            if deviation <= 5 { return .green }
            if deviation <= 15 { return .yellow }
            return .orange
        }
        if cadence >= 170 && cadence <= 190 { return .green }
        if cadence >= 160 && cadence <= 200 { return .yellow }
        return .orange
    }

    // MARK: - Calculated Values

    private var calculatedPace: String {
        guard manualDistanceKm > 0, elapsedTime > 0 else { return "--:--" }
        let paceSecondsPerKm = elapsedTime / manualDistanceKm
        let mins = Int(paceSecondsPerKm) / 60
        let secs = Int(paceSecondsPerKm) % 60
        return String(format: "%d:%02d /km", mins, secs)
    }

    private var calculatedSpeed: String {
        guard manualDistanceKm > 0, elapsedTime > 0 else { return "--.- km/h" }
        let speedKmh = manualDistanceKm / (elapsedTime / 3600)
        return String(format: "%.1f km/h", speedKmh)
    }

    private var averageHeartRate: Int {
        guard !heartRateReadings.isEmpty else { return 0 }
        return heartRateReadings.reduce(0, +) / heartRateReadings.count
    }

    // Treadmill watch motion & HR callbacks removed — using .onChange(of:) modifiers

    private func startHeartRateTracking() {
        // Motion tracking is started by WorkoutLifecycleService — no duplicate send here
        sensorAnalyzer.startSession(discipline: .treadmill)
        startWatchStatusUpdates()
    }

    private func stopHeartRateTracking() {
        watchManager.stopMotionTracking()
        sensorAnalyzer.stopSession()
        stopWatchStatusUpdates()

        // Send idle state to Watch
        watchManager.sendStatusUpdate(
            rideState: .idle,
            duration: 0,
            distance: 0,
            speed: 0,
            gait: "Treadmill",
            heartRate: nil,
            heartRateZone: nil,
            averageHeartRate: nil,
            maxHeartRate: nil,
            horseName: nil,
            rideType: "Treadmill"
        )

        // Save heart rate data to session
        if !heartRateReadings.isEmpty {
            session.averageHeartRate = heartRateReadings.reduce(0, +) / heartRateReadings.count
            session.maxHeartRate = maxHeartRate
            session.minHeartRate = minHeartRate == Int.max ? 0 : minHeartRate
        }

        // Save timestamped heart rate samples
        if !heartRateSamples.isEmpty {
            session.heartRateSamples = heartRateSamples
        }

        // Save cadence data to session
        if !cadenceReadings.isEmpty {
            session.averageCadence = cadenceReadings.reduce(0, +) / cadenceReadings.count
            session.maxCadence = cadenceReadings.max() ?? 0
        }

        // Save running form metrics
        if !oscillationReadings.isEmpty {
            session.averageVerticalOscillation = oscillationReadings.reduce(0, +) / Double(oscillationReadings.count)
        }
        if !gctReadings.isEmpty {
            session.averageGroundContactTime = gctReadings.reduce(0, +) / Double(gctReadings.count)
        }

        // Save timestamped form samples
        if !formSamples.isEmpty {
            session.runningFormSamples = formSamples
        }

        // Capture peak HR at end for recovery calculation
        session.peakHeartRateAtEnd = currentHeartRate > 0 ? currentHeartRate : maxHeartRate

        // Start recovery HR tracking (keep listening for 60s)
        startRecoveryTracking()

        // Save enhanced sensor data
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
    }

    // MARK: - Recovery HR Tracking

    private func startRecoveryTracking() {
        isRecoveryPhase = true
        // HR updates flow via .onChange(of: watchManager.heartRateSequence) modifier
        // After 60 seconds, capture recovery HR
        let queue = DispatchQueue(label: "dev.dreamfold.tetratrack.recoveryTimer", qos: .utility)
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + 60.0, repeating: .never, leeway: .milliseconds(500))
        source.setEventHandler { [self] in
            DispatchQueue.main.async {
                if self.currentHeartRate > 0 {
                    self.session.recoveryHeartRate = self.currentHeartRate
                }
                self.isRecoveryPhase = false
                self.recoveryTimer = nil
            }
        }
        source.resume()
        recoveryTimer = source
    }

    // MARK: - Watch Status Updates

    private func startWatchStatusUpdates() {
        sendStatusToWatch()

        let queue = DispatchQueue(label: "dev.dreamfold.tetratrack.watchUpdate", qos: .utility)
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + 1.0, repeating: 1.0, leeway: .milliseconds(100))
        source.setEventHandler { [self] in
            DispatchQueue.main.async {
                self.sendStatusToWatch()
            }
        }
        source.resume()
        watchUpdateTimer = source
    }

    private func stopWatchStatusUpdates() {
        watchUpdateTimer?.cancel()
        watchUpdateTimer = nil
    }

    private func sendStatusToWatch() {
        watchManager.sendStatusUpdate(
            rideState: .tracking,
            duration: elapsedTime,
            distance: manualDistanceKm * 1000,
            speed: manualDistanceKm > 0 && elapsedTime > 0 ? (manualDistanceKm * 1000) / elapsedTime : 0,
            gait: "Treadmill",
            heartRate: currentHeartRate > 0 ? currentHeartRate : nil,
            heartRateZone: heartRateZone,
            averageHeartRate: averageHeartRate > 0 ? averageHeartRate : nil,
            maxHeartRate: maxHeartRate > 0 ? maxHeartRate : nil,
            horseName: nil,
            rideType: "Treadmill",
            runningPhase: nil,
            asymmetryIndex: nil
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

    // MARK: - Form Degradation Detection

    private func checkFormDegradation() {
        guard formSamples.count >= 20,
              formSamples.count - lastDegradationCheckCount >= 10 else { return }
        lastDegradationCheckCount = formSamples.count

        guard Date().timeIntervalSince(lastDegradationAlertTime) > 90 else { return }

        let bio = RunnerBiomechanics()
        let analysis = bio.formDegradation(
            oscillationSamples: formSamples.map(\.oscillation),
            gctSamples: formSamples.map(\.groundContactTime),
            cadenceSamples: formSamples.map { Double($0.cadence) }
        )

        guard analysis.hasDegradation else { return }
        lastDegradationAlertTime = Date()

        if analysis.cadenceDegraded {
            AudioCoachManager.shared.announce("Cadence dropping — focus on quick, light steps")
        } else if analysis.gctDegraded {
            AudioCoachManager.shared.announce("Ground contact rising — think hot coals, quick feet")
        } else if analysis.oscillationDegraded {
            AudioCoachManager.shared.announce("Bouncing more — run tall, engage your core")
        }
    }

    // MARK: - Timer & Actions

    private func startTimer() {
        sessionStartTime = Date()
        pausedAccumulated = 0

        timerSource?.cancel()
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now(), repeating: .seconds(1))
        source.setEventHandler { [self] in
            guard let start = sessionStartTime, isRunning else { return }
            elapsedTime = Date().timeIntervalSince(start) - pausedAccumulated
            session.totalDuration = elapsedTime

            // HR fallback: use HKWorkoutBuilder HR when companion HR isn't flowing
            if !hasWCSessionHR {
                let lifecycleHR = Int(workoutLifecycle.liveHeartRate)
                if lifecycleHR > 0 {
                    currentHeartRate = lifecycleHR
                    heartRateReadings.append(lifecycleHR)
                    if lifecycleHR > maxHeartRate { maxHeartRate = lifecycleHR }
                    if lifecycleHR < minHeartRate { minHeartRate = lifecycleHR }
                    heartRateSamples.append(HeartRateSample(
                        timestamp: Date(),
                        bpm: lifecycleHR,
                        maxHeartRate: treadmillEstimatedMaxHR
                    ))
                }
            }

            // Process running form reminders
            AudioCoachManager.shared.processRunningFormReminder(elapsedTime: elapsedTime)
        }
        source.resume()
        timerSource = source
    }

    private func pauseSession() {
        isRunning = false
        lastPauseTime = Date()
    }

    private func resumeSession() {
        if let pauseStart = lastPauseTime {
            pausedAccumulated += Date().timeIntervalSince(pauseStart)
            lastPauseTime = nil
        }
        isRunning = true
    }

    private func endSession() {
        timerSource?.cancel()

        var treadmillMetadata: [String: Any] = [
            HKMetadataKeyIndoorWorkout: true,
            "SessionType": session.sessionType.rawValue
        ]
        if inclinePercentage > 0 {
            treadmillMetadata["TreadmillIncline"] = inclinePercentage
        }

        // Begin non-blocking workout save (awaited in parent view's onEnd)
        workoutLifecycle.beginEndAndSave(metadata: treadmillMetadata)

        stopHeartRateTracking()
        UIApplication.shared.isIdleTimerDisabled = false
        session.endDate = Date()
        session.totalDuration = elapsedTime
        session.totalDistance = manualDistanceKm * 1000 // Convert km to meters
        session.treadmillIncline = inclinePercentage > 0 ? inclinePercentage : nil
        session.manualDistance = true
        showingDistanceInput = false

        // Audio coaching: announce run complete summary
        if AudioCoachManager.shared.announceSessionStartEnd && manualDistanceKm > 0 {
            let distanceMeters = manualDistanceKm * 1000
            let avgPace = elapsedTime / manualDistanceKm // seconds per km
            AudioCoachManager.shared.announceRunComplete(
                distance: distanceMeters,
                duration: elapsedTime,
                averagePace: avgPace,
                targetPace: nil
            )
        }

        onEnd()
    }

    private func discardSession() {
        timerSource?.cancel()

        // Discard workout lifecycle (don't save)
        Task {
            await workoutLifecycle.discard()
            workoutLifecycle.sendIdleStateToWatch()
            Log.tracking.info("Discarded workout lifecycle for treadmill")
        }

        stopHeartRateTracking()
        UIApplication.shared.isIdleTimerDisabled = false

        onDiscard?()
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Treadmill Distance Input View

struct TreadmillDistanceInputView: View {
    @Binding var distanceKm: Double
    @Binding var distanceText: String
    @Binding var speedKmh: Double
    @Binding var speedText: String
    @Binding var incline: Double
    let duration: TimeInterval
    let onSave: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isDistanceFocused: Bool
    @FocusState private var isSpeedFocused: Bool

    @State private var inputMode: TreadmillInputMode = .distance

    enum TreadmillInputMode {
        case distance
        case speed
    }

    var body: some View {
        NavigationStack {
            Form {
                // Duration display (read-only)
                Section {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(formatDuration(duration))
                            .foregroundStyle(.secondary)
                            .font(.headline)
                    }
                } header: {
                    Text("Workout Time")
                }

                // Input mode selection
                Section {
                    Picker("Input Method", selection: $inputMode) {
                        Text("Enter Distance").tag(TreadmillInputMode.distance)
                        Text("Enter Speed").tag(TreadmillInputMode.speed)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("How would you like to enter your data?")
                }

                // Distance input
                Section {
                    if inputMode == .distance {
                        HStack {
                            Text("Distance")
                            Spacer()
                            TextField("0.00", text: $distanceText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                .focused($isDistanceFocused)
                                .onChange(of: distanceText) { _, newValue in
                                    if let value = Double(newValue.replacingOccurrences(of: ",", with: ".")) {
                                        distanceKm = value
                                    }
                                }
                            Text("km")
                                .foregroundStyle(.secondary)
                        }

                        // Calculated pace from distance
                        if distanceKm > 0 {
                            HStack {
                                Text("Calculated Pace")
                                Spacer()
                                Text(calculatedPaceFromDistance)
                                    .foregroundStyle(.mint)
                                    .font(.headline)
                            }

                            HStack {
                                Text("Calculated Speed")
                                Spacer()
                                Text(calculatedSpeedFromDistance)
                                    .foregroundStyle(.mint)
                            }
                        }
                    } else {
                        // Speed input mode
                        HStack {
                            Text("Average Speed")
                            Spacer()
                            TextField("0.0", text: $speedText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                .focused($isSpeedFocused)
                                .onChange(of: speedText) { _, newValue in
                                    if let value = Double(newValue.replacingOccurrences(of: ",", with: ".")) {
                                        speedKmh = value
                                        // Calculate distance from speed
                                        distanceKm = (speedKmh * duration) / 3600
                                        distanceText = String(format: "%.2f", distanceKm)
                                    }
                                }
                            Text("km/h")
                                .foregroundStyle(.secondary)
                        }

                        // Calculated distance from speed
                        if speedKmh > 0 {
                            HStack {
                                Text("Calculated Distance")
                                Spacer()
                                Text(String(format: "%.2f km", distanceKm))
                                    .foregroundStyle(.mint)
                                    .font(.headline)
                            }

                            HStack {
                                Text("Calculated Pace")
                                Spacer()
                                Text(calculatedPaceFromSpeed)
                                    .foregroundStyle(.mint)
                            }
                        }
                    }
                } header: {
                    Text(inputMode == .distance ? "Distance from Treadmill Display" : "Speed from Treadmill Display")
                } footer: {
                    Text(inputMode == .distance
                         ? "Enter the distance shown on your treadmill at the end of your workout"
                         : "Enter your average speed from the treadmill display")
                }

                // Incline (optional)
                Section {
                    HStack {
                        Text("Incline")
                        Spacer()
                        Slider(value: $incline, in: 0...15, step: 0.5)
                            .frame(width: 150)
                        Text(String(format: "%.1f%%", incline))
                            .frame(width: 50, alignment: .trailing)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Incline (Optional)")
                } footer: {
                    Text("Set the average incline if you used one during your run")
                }

                // Summary
                if distanceKm > 0 {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "figure.run.treadmill")
                                    .foregroundStyle(.mint)
                                Text("Treadmill Run Summary")
                                    .font(.headline)
                            }

                            Divider()

                            HStack {
                                Text("Duration")
                                Spacer()
                                Text(formatDuration(duration))
                                    .fontWeight(.medium)
                            }

                            HStack {
                                Text("Distance")
                                Spacer()
                                Text(String(format: "%.2f km", distanceKm))
                                    .fontWeight(.medium)
                                    .foregroundStyle(.mint)
                            }

                            HStack {
                                Text("Pace")
                                Spacer()
                                Text(calculatedPaceFromDistance)
                                    .fontWeight(.medium)
                            }

                            if incline > 0 {
                                HStack {
                                    Text("Incline")
                                    Spacer()
                                    Text(String(format: "%.1f%%", incline))
                                        .fontWeight(.medium)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Summary")
                    }
                }
            }
            .navigationTitle("Enter Treadmill Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                    .fontWeight(.semibold)
                    .disabled(distanceKm <= 0)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isDistanceFocused = false
                        isSpeedFocused = false
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if inputMode == .distance {
                        isDistanceFocused = true
                    } else {
                        isSpeedFocused = true
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Calculated Values

    private var calculatedPaceFromDistance: String {
        guard distanceKm > 0, duration > 0 else { return "--:--" }
        let paceSecondsPerKm = duration / distanceKm
        let mins = Int(paceSecondsPerKm) / 60
        let secs = Int(paceSecondsPerKm) % 60
        return String(format: "%d:%02d /km", mins, secs)
    }

    private var calculatedSpeedFromDistance: String {
        guard distanceKm > 0, duration > 0 else { return "--.- km/h" }
        let speedKmh = distanceKm / (duration / 3600)
        return String(format: "%.1f km/h", speedKmh)
    }

    private var calculatedPaceFromSpeed: String {
        guard speedKmh > 0 else { return "--:--" }
        let paceSecondsPerKm = 3600 / speedKmh
        let mins = Int(paceSecondsPerKm) / 60
        let secs = Int(paceSecondsPerKm) % 60
        return String(format: "%d:%02d /km", mins, secs)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
