//
//  RunningLiveComponents.swift
//  TrackRide
//
//  Running live session views extracted from RunningView
//

import SwiftUI
import SwiftData
import CoreLocation
import MapKit
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
    let onEnd: () -> Void
    var onDiscard: (() -> Void)?

    @Environment(LocationManager.self) private var locationManager: LocationManager?
    @Environment(\.modelContext) private var modelContext

    @State private var isRunning = true
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var last400mTime: TimeInterval = 0
    @State private var current400mStart: TimeInterval = 0
    @State private var showingCancelConfirmation = false

    private var personalBests: RunningPersonalBests { RunningPersonalBests.shared }

    // Watch motion tracking
    @State private var verticalOscillation: Double = 0.0  // cm
    @State private var groundContactTime: Double = 0.0    // ms
    @State private var cadence: Int = 0                   // steps per minute

    // Watch heart rate tracking
    @State private var currentHeartRate: Int = 0
    @State private var maxHeartRate: Int = 0
    @State private var heartRateReadings: [Int] = []

    // Enhanced sensor data from Watch
    private let sensorAnalyzer = WatchSensorAnalyzer.shared

    // Weather tracking
    @State private var currentWeather: WeatherConditions?

    // Watch status update timer
    @State private var watchUpdateTimer: Timer?

    private let watchManager = WatchConnectivityManager.shared
    private let weatherService = WeatherService.shared

    // Interval tracking
    @State private var intervalCount = 1
    @State private var isWorkPhase = true
    @State private var phaseTime: TimeInterval = 0
    @State private var workoutPhase: IntervalWorkoutPhase = .warmup

    // Tab selection for swipeable stats/map
    @State private var selectedTab: RunningTab = .stats
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var lastLocation: CLLocation?

    // Vehicle detection
    @State private var showingVehicleAlert = false
    @State private var highSpeedStartTime: Date?
    private let vehicleSpeedThreshold: Double = 7.0  // ~25 km/h
    private let vehicleDetectionDuration: TimeInterval = 10  // 10 seconds sustained

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
            startMotionTracking()
            startLocationTracking()
            startTimer()
            fetchWeather()
            AudioCoachManager.shared.startRunningFormReminders()
        }
        .onDisappear {
            timer?.invalidate()
            stopMotionTracking()
            stopLocationTracking()
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
                    .font(.system(size: 56, weight: .bold, design: .rounded))
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

                // Vehicle detection
                self.checkForVehicleSpeed(location.speed)
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
                    if let oscillation = oscillation {
                        self.verticalOscillation = oscillation
                    }
                    if let gct = gct {
                        self.groundContactTime = gct
                    }
                    if let cad = cad {
                        self.cadence = cad
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
            }
        }
    }

    private func startMotionTracking() {
        watchManager.resetMotionMetrics()
        watchManager.startMotionTracking(mode: .running)
        sensorAnalyzer.startSession()
        startWatchStatusUpdates()
    }

    private func stopMotionTracking() {
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
            gait: "Running",
            heartRate: nil,
            heartRateZone: nil,
            averageHeartRate: nil,
            maxHeartRate: nil,
            horseName: nil,
            rideType: "Running"
        )

        // Save heart rate data to session
        if !heartRateReadings.isEmpty {
            session.averageHeartRate = heartRateReadings.reduce(0, +) / heartRateReadings.count
            session.maxHeartRate = maxHeartRate
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

        // Start periodic updates
        watchUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            sendStatusToWatch()
        }
    }

    private func stopWatchStatusUpdates() {
        watchUpdateTimer?.invalidate()
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
            rideType: session.sessionType.rawValue
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
                    .font(.system(size: 48, weight: .bold, design: .rounded))
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
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }

                VStack(spacing: 4) {
                    Text("Avg Pace")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(averagePace)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
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
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                        }
                        Text("bpm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if averageHeartRate > 0 {
                        VStack(spacing: 4) {
                            Text("\(averageHeartRate)")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                            Text("Avg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if maxHeartRate > 0 {
                        VStack(spacing: 4) {
                            Text("\(maxHeartRate)")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
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
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
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
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
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
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
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

    private var tetrathlonMetrics: some View {
        VStack(spacing: 20) {
            // Goal distance and progress
            VStack(spacing: 4) {
                Text(formatDistanceGoal(targetDistance))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatDistance(session.totalDistance))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
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
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(paceComparisonColor(current: currentPaceSeconds, pb: pbPace))
                }

                // Average Pace
                VStack(spacing: 4) {
                    Text("Average")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(averagePace)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(paceComparisonColor(current: averagePaceSeconds, pb: pbPace))
                }

                // PB Pace
                VStack(spacing: 4) {
                    Text("PB Pace")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(pbPace > 0 ? formatPace(pbPace) : "--:--")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
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
                            .font(.system(size: 48, weight: .bold, design: .rounded))
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
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                    }

                    VStack(spacing: 4) {
                        Text("Phase Time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatTime(phaseTime))
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
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
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                    }

                    VStack(spacing: 4) {
                        Text("Phase Time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatTime(phaseTime))
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
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
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
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

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if isRunning {
                elapsedTime += 1
                phaseTime += 1
                session.totalDuration = elapsedTime

                // Handle automatic phase transitions for intervals
                if intervalSettings != nil {
                    checkPhaseTransition()
                }

                // Process running form reminders
                AudioCoachManager.shared.processRunningFormReminder(elapsedTime: elapsedTime)
            }
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
    }

    private func resumeSession() {
        isRunning = true
    }

    private func endSession() {
        timer?.invalidate()
        VirtualPacer.shared.stop()
        session.endDate = Date()
        session.totalDuration = elapsedTime
        onEnd()
    }

    private func discardSession() {
        timer?.invalidate()
        VirtualPacer.shared.stop()
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

    @State private var isRunning = true
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
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
    @State private var heartRateReadings: [Int] = []

    // Watch status update timer
    @State private var watchUpdateTimer: Timer?

    private let watchManager = WatchConnectivityManager.shared

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
                        .font(.system(size: 56, weight: .bold, design: .rounded))
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
            setupHeartRateCallback()
            startHeartRateTracking()
            startTimer()
            AudioCoachManager.shared.startRunningFormReminders()
        }
        .onDisappear {
            timer?.invalidate()
            stopHeartRateTracking()
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
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.mint)
                } else {
                    Text("--.- km")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
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
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }

                VStack(spacing: 4) {
                    Text("Speed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(calculatedSpeed)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
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
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                        }
                        Text("bpm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if averageHeartRate > 0 {
                        VStack(spacing: 4) {
                            Text("\(averageHeartRate)")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                            Text("Avg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if maxHeartRate > 0 {
                        VStack(spacing: 4) {
                            Text("\(maxHeartRate)")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
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

    // MARK: - Heart Rate Tracking

    private func setupHeartRateCallback() {
        watchManager.onHeartRateReceived = { bpm in
            DispatchQueue.main.async {
                self.currentHeartRate = bpm
                self.heartRateReadings.append(bpm)
                if bpm > self.maxHeartRate {
                    self.maxHeartRate = bpm
                }
            }
        }
    }

    private func startHeartRateTracking() {
        watchManager.startMotionTracking(mode: .running)
        startWatchStatusUpdates()
    }

    private func stopHeartRateTracking() {
        watchManager.stopMotionTracking()
        watchManager.onHeartRateReceived = nil
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
        }
    }

    // MARK: - Watch Status Updates

    private func startWatchStatusUpdates() {
        sendStatusToWatch()
        watchUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            sendStatusToWatch()
        }
    }

    private func stopWatchStatusUpdates() {
        watchUpdateTimer?.invalidate()
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
            rideType: "Treadmill"
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
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if isRunning {
                elapsedTime += 1
                session.totalDuration = elapsedTime

                // Process running form reminders
                AudioCoachManager.shared.processRunningFormReminder(elapsedTime: elapsedTime)
            }
        }
    }

    private func pauseSession() {
        isRunning = false
    }

    private func resumeSession() {
        isRunning = true
    }

    private func endSession() {
        timer?.invalidate()
        session.endDate = Date()
        session.totalDuration = elapsedTime
        session.totalDistance = manualDistanceKm * 1000 // Convert km to meters
        session.treadmillIncline = inclinePercentage > 0 ? inclinePercentage : nil
        session.manualDistance = true
        showingDistanceInput = false
        onEnd()
    }

    private func discardSession() {
        timer?.invalidate()
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
