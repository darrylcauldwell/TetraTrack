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
    var targetDistance: Double = 0
    var shareWithFamily: Bool = false
    var fallDetectionEnabled: Bool = true
    let onEnd: () -> Void
    var onDiscard: (() -> Void)?

    @Environment(LocationManager.self) private var locationManager: LocationManager?
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<SharingRelationship> { $0.receiveFallAlerts == true && $0.phoneNumber != nil }) private var emergencyContacts: [SharingRelationship]

    @State private var isRunning = true
    @State private var elapsedTime: TimeInterval = 0
    @State private var timerSource: DispatchSourceTimer?
    @State private var sessionStartTime: Date?
    @State private var pausedAccumulated: TimeInterval = 0
    @State private var lastPauseTime: Date?
    @State private var last400mTime: TimeInterval = 0
    @State private var current400mStart: TimeInterval = 0
    @State private var showingCancelConfirmation = false

    private var personalBests: RunningPersonalBests { RunningPersonalBests.shared }

    // Watch motion tracking
    @State private var verticalOscillation: Double = 0.0  // cm
    @State private var groundContactTime: Double = 0.0    // ms
    @State private var cadence: Int = 0                   // steps per minute

    // Tracking arrays for session averages
    @State private var cadenceReadings: [Int] = []
    @State private var oscillationReadings: [Double] = []
    @State private var gctReadings: [Double] = []
    @State private var formSamples: [RunningFormSample] = []

    // Recovery tracking
    @State private var isRecoveryPhase = false
    @State private var recoveryTimer: DispatchSourceTimer?

    // Watch heart rate tracking
    @State private var currentHeartRate: Int = 0
    @State private var maxHeartRate: Int = 0
    @State private var minHeartRate: Int = Int.max
    @State private var heartRateReadings: [Int] = []
    @State private var heartRateSamples: [HeartRateSample] = []
    private var estimatedMaxHR: Int { 190 }

    // Enhanced sensor data from Watch
    private let sensorAnalyzer = WatchSensorAnalyzer.shared

    // Weather tracking
    @State private var currentWeather: WeatherConditions?

    // Watch status update timer
    @State private var watchUpdateTimer: DispatchSourceTimer?

    private let watchManager = WatchConnectivityManager.shared
    private let weatherService = WeatherService.shared
    private let liveWorkoutManager = LiveWorkoutManager.shared

    // Interval tracking
    @State private var intervalCount = 1
    @State private var isWorkPhase = true
    @State private var phaseTime: TimeInterval = 0
    @State private var workoutPhase: IntervalWorkoutPhase = .warmup

    // Tab selection for swipeable stats/map
    @State private var selectedTab: RunningTab = .stats
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var lastLocation: CLLocation?

    // Track whether services have been started (to avoid restarting on re-appear after screen lock)
    @State private var hasStartedServices = false

    // Vehicle detection
    @State private var showingVehicleAlert = false
    @State private var highSpeedStartTime: Date?
    private let vehicleSpeedThreshold: Double = 7.0  // ~25 km/h
    private let vehicleDetectionDuration: TimeInterval = 10  // 10 seconds sustained

    // iPhone motion analysis (pocket mode)
    @State private var motionManager = MotionManager()
    @State private var runningMotionAnalyzer = RunningMotionAnalyzer()
    private let pocketModeManager = PocketModeManager.shared
    @AppStorage("runningPhonePlacement") private var phonePlacementRaw: String = RunningPhonePlacement.shortsThigh.rawValue
    private var phonePlacement: RunningPhonePlacement {
        RunningPhonePlacement(rawValue: phonePlacementRaw) ?? .shortsThigh
    }

    // Family sharing
    private let sharingCoordinator = UnifiedSharingCoordinator.shared
    @State private var lastSharingUpdateTime: Date = .distantPast
    private let sharingUpdateInterval: TimeInterval = 10

    // Fall detection
    private let fallDetectionManager = FallDetectionManager.shared
    @State private var showingFallAlert = false
    @State private var fallAlertCountdown: Int = 30
    @State private var emergencyAlertSent = false

    enum IntervalWorkoutPhase {
        case warmup, work, rest, cooldown, finished
    }

    private var isOutdoorGPS: Bool {
        session.runMode == .outdoor
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header: page indicator, weather, music, voice notes, close button
                headerView
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // Main content - swipeable for GPS, static for track/indoor
                if isOutdoorGPS {
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
            setupMotionCallbacks()
            if !hasStartedServices {
                startMotionTracking()
                startLocationTracking()
                hasStartedServices = true

                // Start family sharing if enabled
                if shareWithFamily {
                    Task { await sharingCoordinator.startSharingLocation(activityType: "running") }
                }

                // Start fall detection if enabled
                if fallDetectionEnabled {
                    fallDetectionManager.configure(modelContext: modelContext)
                    fallDetectionManager.startMonitoring()
                    setupFallDetectionCallbacks()
                }
            }
            if timerSource == nil { startTimer() }
            fetchWeather()
            UIApplication.shared.isIdleTimerDisabled = true
            AudioCoachManager.shared.startRunningFormReminders()
        }
        .onDisappear {
            timerSource?.cancel()
            AudioCoachManager.shared.stopRunningFormReminders()
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
        .fullScreenCover(isPresented: $showingFallAlert) {
            if emergencyAlertSent {
                EmergencyAlertSentView(
                    emergencyContacts: emergencyContacts,
                    onDismiss: {
                        fallDetectionManager.confirmOK()
                        showingFallAlert = false
                        emergencyAlertSent = false
                    },
                    onCallContact: { contact in
                        if let url = contact.callURL {
                            UIApplication.shared.open(url)
                        }
                    }
                )
            } else {
                FallAlertView(
                    countdownSeconds: fallAlertCountdown,
                    onConfirmOK: {
                        fallDetectionManager.confirmOK()
                    },
                    onRequestEmergency: {
                        fallDetectionManager.requestEmergency()
                        emergencyAlertSent = true
                    }
                )
            }
        }
        .onChange(of: fallAlertCountdown) { _, newValue in
            if newValue <= 0 && showingFallAlert {
                emergencyAlertSent = true
            }
        }
        .overlay(alignment: .top) {
            VoiceNoteRecordingOverlay()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: 12) {
            // Page indicator on left (for GPS mode)
            if isOutdoorGPS {
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
        ZStack {
            Map {
                // User location
                UserAnnotation()

                // Route polyline
                if routeCoordinates.count > 1 {
                    MapPolyline(coordinates: routeCoordinates)
                        .stroke(AppColors.primary, lineWidth: 4)
                }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            .mapControls {
                MapCompass()
                MapScaleView()
            }

            // Back button at top left
            VStack {
                HStack {
                    Button {
                        withAnimation {
                            selectedTab = .stats
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                            Text("Stats")
                                .font(.subheadline.weight(.medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(AppColors.cardBackground)
                        .clipShape(Capsule())
                    }

                    Spacer()
                }
                .padding()

                Spacer()
            }
        }
    }

    // MARK: - Location Tracking

    private func startLocationTracking() {
        guard isOutdoorGPS, let locManager = locationManager else { return }

        locManager.onLocationUpdate = { location in
            DispatchQueue.main.async {
                // Update route for live display
                self.routeCoordinates.append(location.coordinate)

                // Store GPS point to database for trim capability
                let point = RunningLocationPoint(from: location)
                point.session = self.session
                self.modelContext.insert(point)

                // Calculate distance
                if let last = self.lastLocation {
                    let delta = location.distance(from: last)
                    self.session.totalDistance += delta
                }
                self.lastLocation = location

                // Feed GPS speed and distance to phone motion analyzer
                if location.speed >= 0 {
                    self.runningMotionAnalyzer.updateGPSSpeed(location.speed)
                }
                self.runningMotionAnalyzer.updateDistance(self.session.totalDistance)

                // Update virtual pacer with current distance
                if VirtualPacer.shared.isActive {
                    VirtualPacer.shared.update(distance: self.session.totalDistance, elapsedTime: self.elapsedTime)
                }

                // Vehicle detection
                self.checkForVehicleSpeed(location.speed)

                // Fall detection location feed
                if self.fallDetectionEnabled {
                    self.fallDetectionManager.updateLocation(location.coordinate)
                }

                // Family sharing location update (throttled every 10 seconds)
                if self.shareWithFamily {
                    let now = Date()
                    if now.timeIntervalSince(self.lastSharingUpdateTime) >= self.sharingUpdateInterval {
                        self.lastSharingUpdateTime = now
                        let gait = self.runningMotionAnalyzer.currentPhase.toGaitType
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
        }

        Task {
            await locManager.startTracking()
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
        guard let locManager = locationManager else { return }
        locManager.onLocationUpdate = nil
        locManager.stopTracking()
    }

    // MARK: - Watch Motion & Heart Rate Tracking

    private func setupMotionCallbacks() {
        watchManager.onMotionUpdate = { mode, _, _, _, oscillation, gct, cad in
            if mode == .running {
                DispatchQueue.main.async {
                    var sampleCadence: Int = 0
                    var sampleOsc: Double = 0
                    var sampleGCT: Double = 0

                    if let oscillation = oscillation {
                        self.verticalOscillation = oscillation
                        if oscillation > 0 {
                            self.oscillationReadings.append(oscillation)
                            sampleOsc = oscillation
                        }
                    }
                    if let gct = gct {
                        self.groundContactTime = gct
                        if gct > 0 {
                            self.gctReadings.append(gct)
                            sampleGCT = gct
                        }
                    }
                    if let cad = cad {
                        self.cadence = cad
                        if cad > 0 {
                            self.cadenceReadings.append(cad)
                            sampleCadence = cad
                        }
                    }

                    // Collect timestamped form sample
                    if sampleCadence > 0 || sampleOsc > 0 || sampleGCT > 0 {
                        let sample = RunningFormSample(
                            timestamp: Date(),
                            cadence: sampleCadence,
                            oscillation: sampleOsc,
                            groundContactTime: sampleGCT
                        )
                        self.formSamples.append(sample)
                    }
                }
            }
        }

        // Heart rate callback
        watchManager.onHeartRateReceived = { bpm in
            DispatchQueue.main.async {
                self.currentHeartRate = bpm
                self.heartRateReadings.append(bpm)
                if bpm > self.maxHeartRate {
                    self.maxHeartRate = bpm
                }
                if bpm < self.minHeartRate {
                    self.minHeartRate = bpm
                }
                // Collect timestamped samples for timeline
                let sample = HeartRateSample(
                    timestamp: Date(),
                    bpm: bpm,
                    maxHeartRate: self.estimatedMaxHR
                )
                self.heartRateSamples.append(sample)
            }
        }
    }

    private func startMotionTracking() {
        // Start HKWorkoutSession for Watch mirroring - this shows "Workout in Progress"
        // notification on Watch that user can tap to open the app
        Task {
            do {
                try await liveWorkoutManager.startWorkout(activityType: .running)
                Log.tracking.info("Started HKWorkoutSession for running with Watch mirroring")
            } catch {
                Log.tracking.error("Failed to start HKWorkoutSession: \(error)")
                // Continue anyway - WatchConnectivity provides backup
            }
        }

        watchManager.resetMotionMetrics()
        watchManager.startMotionTracking(mode: .running)
        sensorAnalyzer.startSession()
        startWatchStatusUpdates()

        // Start iPhone motion analysis if pocket mode is enabled
        startPhoneMotionAnalysis()
    }

    private func stopMotionTracking() {
        // End HKWorkoutSession - this stops Watch mirroring
        Task {
            await liveWorkoutManager.endWorkout()
            Log.tracking.info("Ended HKWorkoutSession for running")
        }

        watchManager.stopMotionTracking()
        watchManager.onMotionUpdate = nil
        watchManager.onHeartRateReceived = nil
        sensorAnalyzer.stopSession()
        stopWatchStatusUpdates()

        // Stop iPhone motion analysis
        stopPhoneMotionAnalysis()

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

        // Save elevation data from sensor analyzer
        if runningSummary.totalElevationGain > 0 {
            session.totalAscent = runningSummary.totalElevationGain
        }
        if runningSummary.totalElevationLoss > 0 {
            session.totalDescent = runningSummary.totalElevationLoss
        }

        // Save weather to session
        if let weather = currentWeather {
            session.startWeather = weather
        }
    }

    // MARK: - iPhone Motion Analysis

    private func startPhoneMotionAnalysis() {
        guard pocketModeManager.autoActivateEnabled else { return }

        pocketModeManager.startMonitoring()

        motionManager.onMotionUpdate = { [self] sample in
            runningMotionAnalyzer.processMotionSample(sample)
            // Feed motion data to fall detection
            if fallDetectionEnabled {
                fallDetectionManager.processMotionSample(sample)
            }
        }
        motionManager.configureForPlacement(phonePlacement)
        motionManager.startUpdates()
        runningMotionAnalyzer.startAnalyzing(placement: phonePlacement)

        // Wire up form alerts to audio coach
        runningMotionAnalyzer.onFormAlert = { alert in
            AudioCoachManager.shared.announce(alert.message)
        }

        // Wire up per-kilometre summaries
        runningMotionAnalyzer.onKilometreSummary = { km, cadence in
            AudioCoachManager.shared.announce("Kilometre \(km) complete. Cadence \(cadence).")
        }

        session.phoneMotionEnabled = true
        AudioCoachManager.shared.announce("Running form sensors enabled.")
        Log.tracking.info("Phone motion analysis started for running")
    }

    private func stopPhoneMotionAnalysis() {
        guard session.phoneMotionEnabled else { return }

        motionManager.stopUpdates()
        motionManager.onMotionUpdate = nil
        runningMotionAnalyzer.stopAnalyzing()
        pocketModeManager.stopMonitoring()

        // Save phone motion metrics to session
        let summary = runningMotionAnalyzer.getSessionSummary()
        session.phoneAverageCadence = summary.phoneAverageCadence
        session.phoneMaxCadence = summary.phoneMaxCadence
        session.averageImpactLoadValue = summary.averageImpactLoad
        session.peakImpactLoad = summary.peakImpactLoad
        session.impactLoadTrendValue = summary.impactLoadTrend
        session.totalStepCount = summary.totalStepCount
        session.runningPhaseBreakdown = summary.phaseBreakdown

        Log.tracking.info("Phone motion data saved - \(summary.totalStepCount) steps")
    }

    // MARK: - Fall Detection

    private func setupFallDetectionCallbacks() {
        fallDetectionManager.onFallDetected = {
            showingFallAlert = true
        }
        fallDetectionManager.onCountdownTick = { seconds in
            fallAlertCountdown = seconds
        }
        fallDetectionManager.onEmergencyAlert = { _ in
            emergencyAlertSent = true
        }
        fallDetectionManager.onFallDismissed = {
            showingFallAlert = false
            emergencyAlertSent = false
            fallAlertCountdown = 30
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
        // Set up temporary HR callback for recovery
        watchManager.onHeartRateReceived = { bpm in
            DispatchQueue.main.async {
                self.currentHeartRate = bpm
            }
        }
        // After 60 seconds, capture recovery HR
        let queue = DispatchQueue(label: "dev.dreamfold.tetratrack.recoveryTimer", qos: .utility)
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + 60.0, repeating: .never, leeway: .milliseconds(500))
        source.setEventHandler { [self] in
            DispatchQueue.main.async {
                if self.currentHeartRate > 0 {
                    self.session.recoveryHeartRate = self.currentHeartRate
                }
                self.watchManager.onHeartRateReceived = nil
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

            // Phone motion metrics (pocket mode)
            if session.phoneMotionEnabled && runningMotionAnalyzer.phoneCadence > 0 {
                phoneMotionMetricsCard
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

    // MARK: - Phone Motion Metrics Card

    /// Adapts display based on whether Apple Watch provides accurate metrics
    /// - With Watch: Show only cadence (real-time), impact (unique), form score
    /// - Without Watch: Show all phone estimates (best available data)
    private var phoneMotionMetricsCard: some View {
        let hasWatch = HealthKitManager.shared.hasAppleWatchRunningData

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "iphone.gen3")
                    .foregroundStyle(AppColors.primary)
                Text(hasWatch ? "Real-time Coaching" : "Phone Sensors")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if !hasWatch {
                    Text("Est.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if hasWatch {
                // Simplified view - only show metrics unique to phone or useful real-time
                // Cadence (real-time), Impact (unique), Form Score (coaching)
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("\(runningMotionAnalyzer.phoneCadence)")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(phoneCadenceColor)
                        Text("spm")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 2) {
                        Text(String(format: "%.1fg", runningMotionAnalyzer.currentImpactLoad))
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(impactLoadColor)
                        Text("impact")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                // Full view for users without Apple Watch - phone estimates are best available
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("\(runningMotionAnalyzer.phoneCadence)")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(phoneCadenceColor)
                        Text("spm")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 2) {
                        Text(String(format: "%.1fg", runningMotionAnalyzer.currentImpactLoad))
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(impactLoadColor)
                        Text("impact")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var impactLoadColor: Color {
        let impact = runningMotionAnalyzer.currentImpactLoad
        if impact < 2.0 { return .green }  // Light landing
        if impact < 3.0 { return .yellow } // Moderate
        return .orange  // Heavy
    }

    // Phone metric indicator colors
    private var phoneCadenceColor: Color {
        let c = runningMotionAnalyzer.phoneCadence
        if c >= 170 && c <= 190 { return .green }
        if c >= 160 && c <= 200 { return .yellow }
        return .orange
    }

    private var runningPhaseColor: Color {
        switch runningMotionAnalyzer.currentPhase {
        case .walking: return .blue
        case .jogging: return .green
        case .running: return .orange
        case .sprinting: return .red
        }
    }

    // MARK: - Tetrathlon Metrics

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

                // 400m split comparison
                if last400mTime > 0 {
                    HStack {
                        Text("Last 400m")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatTime(last400mTime))
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
        let pb400m = personalBests.personalBest(for: 400)
        guard pb400m > 0, last400mTime > 0 else { return .primary }
        if last400mTime < pb400m { return .green }
        if last400mTime > pb400m * 1.1 { return .red }
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

    // MARK: - Timer & Actions

    private func startTimer() {
        // Initialize interval workout phase
        if let settings = intervalSettings {
            workoutPhase = settings.includeWarmup ? .warmup : .work
        }

        sessionStartTime = Date()
        pausedAccumulated = 0

        timerSource?.cancel()
        let queue = DispatchQueue(label: "dev.dreamfold.tetratrack.runTimer", qos: .userInitiated)
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + 1.0, repeating: 1.0, leeway: .milliseconds(100))
        source.setEventHandler { [self] in
            DispatchQueue.main.async {
                guard let start = self.sessionStartTime, self.isRunning else { return }
                let newElapsed = Date().timeIntervalSince(start) - self.pausedAccumulated
                let delta = newElapsed - self.elapsedTime
                self.elapsedTime = newElapsed
                self.phaseTime += delta
                self.session.totalDuration = self.elapsedTime

                // Handle automatic phase transitions for intervals
                if self.intervalSettings != nil {
                    self.checkPhaseTransition()
                }

                // Process running form reminders
                AudioCoachManager.shared.processRunningFormReminder(elapsedTime: self.elapsedTime)
            }
        }
        source.resume()
        timerSource = source
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

        // Haptic feedback on phase change
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(workoutPhase == .work ? .warning : .success)
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
        stopMotionTracking()
        stopLocationTracking()
        VirtualPacer.shared.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        session.endDate = Date()
        session.totalDuration = elapsedTime

        // Stop fall detection
        if fallDetectionEnabled {
            fallDetectionManager.stopMonitoring()
        }

        // Stop family sharing
        if shareWithFamily {
            Task { await sharingCoordinator.stopSharingLocation() }
        }

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

        // Discard HKWorkoutSession (don't save)
        Task {
            await liveWorkoutManager.discardWorkout()
            Log.tracking.info("Discarded HKWorkoutSession for running")
        }

        // Stop tracking but skip endWorkout since we already discarded
        watchManager.stopMotionTracking()
        watchManager.onMotionUpdate = nil
        watchManager.onHeartRateReceived = nil
        sensorAnalyzer.stopSession()
        stopWatchStatusUpdates()
        stopPhoneMotionAnalysis()

        stopLocationTracking()
        VirtualPacer.shared.stop()
        UIApplication.shared.isIdleTimerDisabled = false

        // Stop fall detection
        if fallDetectionEnabled {
            fallDetectionManager.stopMonitoring()
        }

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
    let onEnd: () -> Void
    var onDiscard: (() -> Void)?
    var fallDetectionEnabled: Bool = true

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<SharingRelationship> { $0.receiveFallAlerts == true && $0.phoneNumber != nil }) private var emergencyContacts: [SharingRelationship]

    // Fall detection
    private let fallDetectionManager = FallDetectionManager.shared
    @State private var showingFallAlert = false
    @State private var fallAlertCountdown: Int = 30
    @State private var emergencyAlertSent = false

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
    private var treadmillEstimatedMaxHR: Int { 190 }

    // Watch motion tracking (running form)
    @State private var verticalOscillation: Double = 0.0
    @State private var groundContactTime: Double = 0.0
    @State private var cadence: Int = 0
    @State private var cadenceReadings: [Int] = []
    @State private var oscillationReadings: [Double] = []
    @State private var gctReadings: [Double] = []
    @State private var formSamples: [RunningFormSample] = []

    // Recovery tracking
    @State private var isRecoveryPhase = false
    @State private var recoveryTimer: DispatchSourceTimer?

    // Enhanced sensor data from Watch
    private let sensorAnalyzer = WatchSensorAnalyzer.shared

    // Watch status update timer
    @State private var watchUpdateTimer: DispatchSourceTimer?

    private let watchManager = WatchConnectivityManager.shared
    private let liveWorkoutManager = LiveWorkoutManager.shared

    // iPhone motion analysis
    @State private var treadmillMotionManager = MotionManager()
    @State private var treadmillMotionAnalyzer = RunningMotionAnalyzer()
    private let treadmillPocketMode = PocketModeManager.shared
    @AppStorage("runningPhonePlacement") private var treadmillPlacementRaw: String = RunningPhonePlacement.shortsThigh.rawValue
    private var treadmillPlacement: RunningPhonePlacement {
        RunningPhonePlacement(rawValue: treadmillPlacementRaw) ?? .shortsThigh
    }

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
            // Start HKWorkoutSession for Watch mirroring (indoor running)
            Task {
                do {
                    try await liveWorkoutManager.startWorkout(activityType: .running)
                    Log.tracking.info("Started HKWorkoutSession for treadmill with Watch mirroring")
                } catch {
                    Log.tracking.error("Failed to start HKWorkoutSession for treadmill: \(error)")
                }
            }

            setupMotionCallbacks()
            setupHeartRateCallback()
            startHeartRateTracking()
            startTimer()
            UIApplication.shared.isIdleTimerDisabled = true
            AudioCoachManager.shared.startRunningFormReminders()

            // Start phone motion analysis for treadmill step counting
            if treadmillPocketMode.autoActivateEnabled {
                treadmillPocketMode.startMonitoring()
                treadmillMotionManager.onMotionUpdate = { sample in
                    treadmillMotionAnalyzer.processMotionSample(sample)
                    // Feed motion data to fall detection
                    if fallDetectionEnabled {
                        fallDetectionManager.processMotionSample(sample)
                    }
                }
                treadmillMotionManager.configureForPlacement(treadmillPlacement)
                treadmillMotionManager.startUpdates()
                treadmillMotionAnalyzer.startAnalyzing(placement: treadmillPlacement)
                treadmillMotionAnalyzer.onFormAlert = { alert in
                    AudioCoachManager.shared.announce(alert.message)
                }
                session.phoneMotionEnabled = true
            }

            // Start fall detection for gym safety
            if fallDetectionEnabled {
                fallDetectionManager.configure(modelContext: modelContext)
                fallDetectionManager.startMonitoring()
                setupTreadmillFallDetectionCallbacks()
            }
        }
        .onDisappear {
            timerSource?.cancel()
            AudioCoachManager.shared.stopRunningFormReminders()
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
        .fullScreenCover(isPresented: $showingFallAlert) {
            if emergencyAlertSent {
                EmergencyAlertSentView(
                    emergencyContacts: emergencyContacts,
                    onDismiss: {
                        fallDetectionManager.confirmOK()
                        showingFallAlert = false
                        emergencyAlertSent = false
                    },
                    onCallContact: { contact in
                        if let url = contact.callURL {
                            UIApplication.shared.open(url)
                        }
                    }
                )
            } else {
                FallAlertView(
                    countdownSeconds: fallAlertCountdown,
                    onConfirmOK: {
                        fallDetectionManager.confirmOK()
                    },
                    onRequestEmergency: {
                        fallDetectionManager.requestEmergency()
                        emergencyAlertSent = true
                    }
                )
            }
        }
        .onChange(of: fallAlertCountdown) { _, newValue in
            if newValue <= 0 && showingFallAlert {
                emergencyAlertSent = true
            }
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

    // MARK: - Motion Tracking

    private func setupMotionCallbacks() {
        watchManager.onMotionUpdate = { mode, _, _, _, oscillation, gct, cad in
            if mode == .running {
                DispatchQueue.main.async {
                    var sampleCadence: Int = 0
                    var sampleOsc: Double = 0
                    var sampleGCT: Double = 0

                    if let oscillation = oscillation {
                        self.verticalOscillation = oscillation
                        if oscillation > 0 {
                            self.oscillationReadings.append(oscillation)
                            sampleOsc = oscillation
                        }
                    }
                    if let gct = gct {
                        self.groundContactTime = gct
                        if gct > 0 {
                            self.gctReadings.append(gct)
                            sampleGCT = gct
                        }
                    }
                    if let cad = cad {
                        self.cadence = cad
                        if cad > 0 {
                            self.cadenceReadings.append(cad)
                            sampleCadence = cad
                        }
                    }

                    // Collect timestamped form sample
                    if sampleCadence > 0 || sampleOsc > 0 || sampleGCT > 0 {
                        let sample = RunningFormSample(
                            timestamp: Date(),
                            cadence: sampleCadence,
                            oscillation: sampleOsc,
                            groundContactTime: sampleGCT
                        )
                        self.formSamples.append(sample)
                    }
                }
            }
        }
    }

    // MARK: - Heart Rate Tracking

    private func setupHeartRateCallback() {
        watchManager.onHeartRateReceived = { bpm in
            DispatchQueue.main.async {
                self.currentHeartRate = bpm
                self.heartRateReadings.append(bpm)
                if bpm > self.maxHeartRate {
                    self.maxHeartRate = bpm
                }
                if bpm < self.minHeartRate {
                    self.minHeartRate = bpm
                }
                // Collect timestamped samples for timeline
                let sample = HeartRateSample(
                    timestamp: Date(),
                    bpm: bpm,
                    maxHeartRate: self.treadmillEstimatedMaxHR
                )
                self.heartRateSamples.append(sample)
            }
        }
    }

    private func startHeartRateTracking() {
        watchManager.startMotionTracking(mode: .running)
        sensorAnalyzer.startSession()
        startWatchStatusUpdates()
    }

    private func stopHeartRateTracking() {
        watchManager.stopMotionTracking()
        watchManager.onMotionUpdate = nil
        watchManager.onHeartRateReceived = nil
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
        watchManager.onHeartRateReceived = { bpm in
            DispatchQueue.main.async {
                self.currentHeartRate = bpm
            }
        }
        // After 60 seconds, capture recovery HR
        let queue = DispatchQueue(label: "dev.dreamfold.tetratrack.recoveryTimer", qos: .utility)
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + 60.0, repeating: .never, leeway: .milliseconds(500))
        source.setEventHandler { [self] in
            DispatchQueue.main.async {
                if self.currentHeartRate > 0 {
                    self.session.recoveryHeartRate = self.currentHeartRate
                }
                self.watchManager.onHeartRateReceived = nil
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
            runningPhase: session.phoneMotionEnabled ? treadmillMotionAnalyzer.currentPhase.rawValue : nil,
            asymmetryIndex: nil  // Phone IMU can't reliably compute - use HealthKit post-session
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

    // MARK: - Timer & Actions

    private func startTimer() {
        sessionStartTime = Date()
        pausedAccumulated = 0

        timerSource?.cancel()
        let queue = DispatchQueue(label: "dev.dreamfold.tetratrack.treadmillTimer", qos: .userInitiated)
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + 1.0, repeating: 1.0, leeway: .milliseconds(100))
        source.setEventHandler { [self] in
            DispatchQueue.main.async {
                guard let start = self.sessionStartTime, self.isRunning else { return }
                self.elapsedTime = Date().timeIntervalSince(start) - self.pausedAccumulated
                self.session.totalDuration = self.elapsedTime

                // Process running form reminders
                AudioCoachManager.shared.processRunningFormReminder(elapsedTime: self.elapsedTime)
            }
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

        // End HKWorkoutSession - this stops Watch mirroring
        Task {
            await liveWorkoutManager.endWorkout()
            Log.tracking.info("Ended HKWorkoutSession for treadmill")
        }

        stopHeartRateTracking()
        stopTreadmillPhoneMotion()
        UIApplication.shared.isIdleTimerDisabled = false
        session.endDate = Date()
        session.totalDuration = elapsedTime
        session.totalDistance = manualDistanceKm * 1000 // Convert km to meters
        session.treadmillIncline = inclinePercentage > 0 ? inclinePercentage : nil
        session.manualDistance = true
        showingDistanceInput = false

        // Stop fall detection
        if fallDetectionEnabled {
            fallDetectionManager.stopMonitoring()
        }

        onEnd()
    }

    private func stopTreadmillPhoneMotion() {
        guard session.phoneMotionEnabled else { return }
        treadmillMotionManager.stopUpdates()
        treadmillMotionManager.onMotionUpdate = nil
        treadmillMotionAnalyzer.stopAnalyzing()
        treadmillPocketMode.stopMonitoring()

        let summary = treadmillMotionAnalyzer.getSessionSummary()
        session.phoneAverageCadence = summary.phoneAverageCadence
        session.phoneMaxCadence = summary.phoneMaxCadence
        session.averageImpactLoadValue = summary.averageImpactLoad
        session.peakImpactLoad = summary.peakImpactLoad
        session.impactLoadTrendValue = summary.impactLoadTrend
        session.totalStepCount = summary.totalStepCount
        session.runningPhaseBreakdown = summary.phaseBreakdown
    }

    private func discardSession() {
        timerSource?.cancel()

        // Discard HKWorkoutSession (don't save)
        Task {
            await liveWorkoutManager.discardWorkout()
            Log.tracking.info("Discarded HKWorkoutSession for treadmill")
        }

        stopHeartRateTracking()
        UIApplication.shared.isIdleTimerDisabled = false

        // Stop fall detection
        if fallDetectionEnabled {
            fallDetectionManager.stopMonitoring()
        }

        onDiscard?()
    }

    // MARK: - Fall Detection

    private func setupTreadmillFallDetectionCallbacks() {
        fallDetectionManager.onFallDetected = {
            showingFallAlert = true
        }
        fallDetectionManager.onCountdownTick = { seconds in
            fallAlertCountdown = seconds
        }
        fallDetectionManager.onEmergencyAlert = { _ in
            emergencyAlertSent = true
        }
        fallDetectionManager.onFallDismissed = {
            showingFallAlert = false
            emergencyAlertSent = false
            fallAlertCountdown = 30
        }
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
