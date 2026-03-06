//
//  WalkingLiveView.swift
//  TetraTrack
//
//  Live walking session view with cadence display, symmetry indicator,
//  and route-colored map.
//

import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import HealthKit
import os

struct WalkingLiveView: View {
    @Bindable var session: RunningSession
    var selectedRoute: WalkingRoute?
    var shareWithFamily: Bool = false
    var targetCadence: Int = 120
    let onEnd: () -> Void
    var onDiscard: (() -> Void)?

    @Environment(LocationManager.self) private var locationManager: LocationManager?
    @Environment(GPSSessionTracker.self) private var gpsTracker: GPSSessionTracker?
    @Environment(\.modelContext) private var modelContext

    @State private var isRunning = true
    @State private var elapsedTime: TimeInterval = 0
    @State private var timerSource: DispatchSourceTimer?
    @State private var showingCancelConfirmation = false

    // Wall-clock timer state (independent of GPS tracker)
    @State private var timerStartDate: Date?
    @State private var pausedAccumulated: TimeInterval = 0
    @State private var lastPauseDate: Date?

    // Cadence tracking
    @State private var currentCadence: Int = 0
    @State private var cadenceReadings: [Int] = []

    // Heart rate
    @State private var currentHeartRate: Int = 0
    @State private var maxHeartRate: Int = 0
    @State private var minHeartRate: Int = Int.max
    @State private var heartRateReadings: [Int] = []
    @State private var heartRateSamples: [HeartRateSample] = []
    @State private var hasWCSessionHR: Bool = false  // tracks whether WCSession is providing HR

    // Map
    @State private var selectedTab: RunningTab = .stats

    // Km split tracking
    @State private var lastAnnouncedKm: Int = 0
    @State private var lastKmSplitTime: TimeInterval = 0

    // Last cadence announcement time
    @State private var lastCadenceAnnouncementMark: Int = 0

    // Symmetry check tracking (every 5 minutes)
    @State private var lastSymmetryCheckMark: Int = 0

    // Watch
    private let watchManager = WatchConnectivityManager.shared
    private let workoutLifecycle = WorkoutLifecycleService.shared

    // Watch status updates
    @State private var watchUpdateTimer: DispatchSourceTimer?

    // Service startup guard
    @State private var hasStartedServices = false

    // Route matching state
    @State private var matchedRouteName: String?

    // Family sharing
    private let sharingCoordinator = UnifiedSharingCoordinator.shared
    @State private var lastSharingUpdateTime: Date = .distantPast
    private let sharingUpdateInterval: TimeInterval = 10

    private var estimatedMaxHR: Int { 190 }

    var body: some View {
        GeometryReader { _ in
            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // Main content - swipeable stats/map
                TabView(selection: $selectedTab) {
                    walkingStatsView
                        .tag(RunningTab.stats)

                    walkingMapView
                        .tag(RunningTab.map)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .onAppear {
            if !hasStartedServices {
                startSession()
            }
            if timerSource == nil {
                startTimer()
            }
        }
        .onDisappear { cleanup() }
        .confirmationDialog("End Walking Session?", isPresented: $showingCancelConfirmation, titleVisibility: .visible) {
            Button("Save Session") {
                endSession()
            }
            Button("Discard", role: .destructive) {
                onDiscard?()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            // Page indicators
            HStack(spacing: 6) {
                Circle()
                    .fill(selectedTab == .stats ? Color.teal : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(selectedTab == .map ? Color.teal : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }

            Spacer()

            // Route match banner
            if let routeName = matchedRouteName {
                HStack(spacing: 4) {
                    Image(systemName: "repeat")
                        .font(.caption2)
                    Text(routeName)
                        .font(.caption2.bold())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.teal.opacity(0.3)))
                .foregroundStyle(.teal)
            }

            Spacer()

            // Close button
            Button {
                showingCancelConfirmation = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Walking Stats View

    private var walkingStatsView: some View {
        VStack(spacing: 16) {
            Spacer()

            // Elapsed time
            VStack(spacing: 4) {
                Text("WALKING")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(formatTime(elapsedTime))
                    .scaledFont(size: 56, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                    .monospacedDigit()
            }

            // Distance
            VStack(spacing: 4) {
                Text(formatDistance(session.totalDistance))
                    .scaledFont(size: 48, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                    .monospacedDigit()
                    .foregroundStyle(.teal)
                Text("distance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Cadence with target indicator
            cadenceDisplay

            // Secondary metrics row
            HStack(spacing: 24) {
                metricColumn(
                    value: session.totalDistance > 50 ? formatPace(session.averagePace) : "--",
                    label: "Pace"
                )
                metricColumn(
                    value: currentHeartRate > 0 ? "\(currentHeartRate)" : "--",
                    label: "Heart Rate"
                )
                metricColumn(
                    value: session.totalAscent > 0 ? String(format: "%.0f m", session.totalAscent) : "--",
                    label: "Ascent"
                )
            }

            Spacer()

            // Pause/Stop controls
            controlButtons
                .padding(.bottom, 32)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Cadence Display

    private var cadenceDisplay: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(currentCadence > 0 ? "\(currentCadence)" : "--")
                    .scaledFont(size: 36, weight: .bold, design: .rounded, relativeTo: .title)
                    .monospacedDigit()
                Text("SPM")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Cadence target zone bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)

                    // Target zone highlight (±10 SPM from target)
                    let zoneStart = max(0, CGFloat(targetCadence - 10 - 80) / 80.0)
                    let zoneEnd = min(1, CGFloat(targetCadence + 10 - 80) / 80.0)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.teal.opacity(0.3))
                        .frame(width: geo.size.width * (zoneEnd - zoneStart), height: 8)
                        .offset(x: geo.size.width * zoneStart)

                    // Current cadence marker
                    if currentCadence > 0 {
                        let position = min(1, max(0, CGFloat(currentCadence - 80) / 80.0))
                        Circle()
                            .fill(cadenceColor)
                            .frame(width: 12, height: 12)
                            .offset(x: geo.size.width * position - 6)
                    }
                }
            }
            .frame(height: 12)
            .padding(.horizontal, 20)

            Text("Target: \(targetCadence) SPM")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var cadenceColor: Color {
        guard currentCadence > 0 else { return .gray }
        let deviation = abs(currentCadence - targetCadence)
        if deviation <= 5 { return .green }
        if deviation <= 10 { return .teal }
        if deviation <= 20 { return .yellow }
        return .orange
    }

    // MARK: - Walking Map View

    private var walkingMapView: some View {
        ZStack {
            Map {
                UserAnnotation()

                if let coords = gpsTracker?.routeCoordinates, coords.count > 1 {
                    MapPolyline(coordinates: coords)
                        .stroke(.teal, lineWidth: 4)
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .mapControls {
                MapUserLocationButton()
            }
        }
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: 40) {
            // Pause/Resume
            Button {
                togglePause()
            } label: {
                ZStack {
                    Circle()
                        .fill(isRunning ? Color.yellow : Color.teal)
                        .frame(width: 70, height: 70)
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.black)
                }
            }

            // Stop
            Button {
                showingCancelConfirmation = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 70, height: 70)
                    Image(systemName: "stop.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Helpers

    private func metricColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded))
                .monospacedDigit()
                .bold()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Session Lifecycle

    private func startSession() {
        guard !hasStartedServices else {
            Log.location.warning("Walking: startSession() skipped — services already started")
            return
        }
        hasStartedServices = true
        Log.location.info("Walking: startSession() beginning")

        session.startDate = Date()

        // Set selected route if any
        if let route = selectedRoute {
            session.matchedRouteId = route.id
            matchedRouteName = route.name
        }

        // Start location tracking (callback-based, matching RunningLiveView pattern)
        startLocationTracking()

        // Setup Watch heart rate, cadence callbacks, and status updates
        setupWatchCallbacks()
        startWatchStatusUpdates()

        // Start HealthKit workout
        let config = HKWorkoutConfiguration()
        config.activityType = .walking
        config.locationType = .outdoor
        Task {
            try? await workoutLifecycle.startWorkout(configuration: config)
        }

        // Audio coach - session start
        AudioCoachManager.shared.announceWalkingSessionStart(routeName: selectedRoute?.name)

        // Note: startTimer() is called from onAppear, not here,
        // so it can recover if SwiftUI triggers onDisappear/onAppear cycles
    }

    private func endSession() {
        stopTimer()
        stopLocationTracking()

        session.endDate = Date()
        session.totalDuration = elapsedTime

        // Finalize cadence
        if !cadenceReadings.isEmpty {
            session.averageCadence = cadenceReadings.reduce(0, +) / cadenceReadings.count
            session.maxCadence = cadenceReadings.max() ?? 0
        }

        // Finalize heart rate
        if !heartRateReadings.isEmpty {
            session.averageHeartRate = heartRateReadings.reduce(0, +) / heartRateReadings.count
            session.maxHeartRate = maxHeartRate
            session.minHeartRate = heartRateReadings.filter { $0 > 0 }.min() ?? 0
        }
        session.heartRateSamples = heartRateSamples

        // Clean up Watch callbacks and status updates
        stopWatchStatusUpdates()
        watchManager.onMotionUpdate = nil
        watchManager.onHeartRateReceived = nil

        // Stop family sharing
        if shareWithFamily {
            Task { await sharingCoordinator.stopSharingLocation() }
        }

        // End HealthKit workout with metadata
        let walkingMetadata: [String: Any] = [
            "SessionType": "walking",
            HKMetadataKeyIndoorWorkout: false
        ]
        Task {
            _ = await workoutLifecycle.endAndSave(metadata: walkingMetadata)
            workoutLifecycle.sendIdleStateToWatch()
        }

        // Audio coach - session end
        AudioCoachManager.shared.announceWalkingSessionEnd(
            distance: session.totalDistance,
            duration: elapsedTime,
            averageCadence: session.averageCadence
        )

        try? modelContext.save()
        onEnd()
    }

    private func cleanup() {
        // Only stop the timer — location tracking continues in background.
        // The timer is restarted in onAppear if SwiftUI triggers a
        // disappear/appear cycle (e.g. from the paged TabView).
        stopTimer()
    }

    // MARK: - Location Tracking

    private func startLocationTracking() {
        guard let tracker = gpsTracker else {
            Log.location.error("Walking: gpsTracker is nil — cannot start tracking")
            return
        }

        Log.location.info("Walking: setting up GPS session tracker")

        // Persist filtered locations as RunningLocationPoints
        tracker.insertLocationPoint = { [self] location, ctx in
            let point = RunningLocationPoint(from: location)
            point.session = self.session
            ctx.insert(point)
        }

        // Walking-specific logic after each filtered GPS point
        tracker.onLocationProcessed = { [self] location, distanceDelta in
            guard self.isRunning else { return }

            // Sync distance and elevation from tracker (Kalman-filtered)
            self.session.totalDistance = tracker.totalDistance
            self.session.totalAscent = tracker.elevationGain
            self.session.totalDescent = tracker.elevationLoss

            // Km split detection
            let currentKm = Int(self.session.totalDistance / 1000)
            if currentKm > self.lastAnnouncedKm && currentKm > 0 {
                let splitDuration = self.elapsedTime - self.lastKmSplitTime
                self.lastAnnouncedKm = currentKm
                self.lastKmSplitTime = self.elapsedTime

                let split = RunningSplit(orderIndex: currentKm - 1, distance: 1000)
                split.duration = splitDuration
                if self.currentHeartRate > 0 { split.heartRate = self.currentHeartRate }
                if self.currentCadence > 0 { split.cadence = self.currentCadence }
                split.session = self.session
                if self.session.splits == nil { self.session.splits = [] }
                self.session.splits?.append(split)
                self.modelContext.insert(split)

                AudioCoachManager.shared.announceWalkingMilestone(
                    km: currentKm,
                    splitTime: splitDuration,
                    totalDistance: self.session.totalDistance,
                    cadence: self.session.averageCadence
                )

                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }

            // Family sharing (throttled)
            if self.shareWithFamily {
                let now = Date()
                if now.timeIntervalSince(self.lastSharingUpdateTime) >= self.sharingUpdateInterval {
                    self.lastSharingUpdateTime = now
                    let gait = RunningPhase.fromGPSSpeed(max(0, location.speed)).toGaitType
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

        Log.location.info("Walking: starting GPS session tracker")
        Task {
            await tracker.start(
                subscriberId: "walking",
                activityType: .walking,
                modelContext: modelContext,
                workoutLifecycle: workoutLifecycle
            )
            Log.location.info("Walking: GPS session tracker started")
        }
    }

    private func stopLocationTracking() {
        gpsTracker?.stop()
    }

    // MARK: - Watch Callbacks

    private func setupWatchCallbacks() {
        // Heart rate callback (companion HR via WCSession)
        watchManager.onHeartRateReceived = { bpm in
            DispatchQueue.main.async {
                self.hasWCSessionHR = true
                self.currentHeartRate = bpm
                self.heartRateReadings.append(bpm)
                if bpm > self.maxHeartRate { self.maxHeartRate = bpm }
                if bpm < self.minHeartRate { self.minHeartRate = bpm }
                self.heartRateSamples.append(HeartRateSample(
                    timestamp: Date(),
                    bpm: bpm,
                    maxHeartRate: self.estimatedMaxHR
                ))
            }
        }

        // Motion callback for cadence
        watchManager.onMotionUpdate = { mode, _, _, _, _, _, cad in
            DispatchQueue.main.async {
                if let cad = cad, cad > 0 {
                    self.currentCadence = cad
                    self.cadenceReadings.append(cad)
                }
            }
        }
    }

    // MARK: - Watch Status Updates

    private func startWatchStatusUpdates() {
        sendStatusToWatch()

        let queue = DispatchQueue(label: "dev.dreamfold.tetratrack.walkingWatchUpdate", qos: .utility)
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
            gait: "Walking",
            heartRate: currentHeartRate > 0 ? currentHeartRate : nil,
            heartRateZone: nil,
            averageHeartRate: nil,
            maxHeartRate: maxHeartRate > 0 ? maxHeartRate : nil,
            horseName: nil,
            rideType: "Walking"
        )
    }

    // MARK: - Timer

    private func startTimer() {
        timerSource?.cancel()
        let start = Date()
        timerStartDate = start
        pausedAccumulated = 0

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .seconds(1))
        timer.setEventHandler { [self] in
            guard isRunning else { return }
            elapsedTime = Date().timeIntervalSince(start) - pausedAccumulated
            session.totalDuration = elapsedTime

            // Sync distance and elevation from GPS tracker
            if let tracker = gpsTracker {
                session.totalDistance = tracker.totalDistance
                session.totalAscent = tracker.elevationGain
                session.totalDescent = tracker.elevationLoss
            }

            // HR fallback: use HKWorkoutBuilder HR when companion HR isn't flowing.
            // When mirroring is active, Watch skips companion HR (no WCSession messages),
            // but HKLiveWorkoutDataSource still collects HR on iPhone.
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

            checkCadenceFeedback()
            checkSymmetryFeedback()
        }
        timer.resume()
        timerSource = timer
    }

    private func stopTimer() {
        timerSource?.cancel()
        timerSource = nil
    }

    private func togglePause() {
        if isRunning {
            gpsTracker?.pause()
            workoutLifecycle.pause()
            lastPauseDate = Date()
            isRunning = false
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else {
            if let pauseDate = lastPauseDate {
                pausedAccumulated += Date().timeIntervalSince(pauseDate)
            }
            lastPauseDate = nil
            gpsTracker?.resume()
            workoutLifecycle.resume()
            isRunning = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    // MARK: - Cadence Feedback

    private func checkCadenceFeedback() {
        // Cadence feedback every 2 minutes
        let twoMinMark = Int(elapsedTime) / 120
        if twoMinMark > lastCadenceAnnouncementMark && currentCadence > 0 {
            lastCadenceAnnouncementMark = twoMinMark
            AudioCoachManager.shared.announceWalkingCadenceFeedback(
                currentCadence: currentCadence,
                targetCadence: targetCadence
            )
        }
    }

    // MARK: - Symmetry Feedback

    private func checkSymmetryFeedback() {
        // Symmetry check every 5 minutes
        let fiveMinMark = Int(elapsedTime) / 300
        guard fiveMinMark > lastSymmetryCheckMark else { return }
        lastSymmetryCheckMark = fiveMinMark

        Task {
            let healthKit = HealthKitManager.shared
            if let asymmetry = await healthKit.fetchRunningAsymmetry(
                from: session.startDate,
                to: Date()
            ), asymmetry > 10 {
                await MainActor.run {
                    AudioCoachManager.shared.announceWalkingSymmetryAlert(asymmetry: asymmetry)
                }
            }
        }
    }

    // MARK: - Formatters

    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }

    private func formatPace(_ paceSecondsPerKm: TimeInterval) -> String {
        let minutes = Int(paceSecondsPerKm) / 60
        let seconds = Int(paceSecondsPerKm) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
