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
    @Environment(SessionTracker.self) private var tracker: SessionTracker

    @State private var showingCancelConfirmation = false
    @State private var selectedTab: RunningTab = .stats

    // Display-only shared singletons
    private var lapDetector: LapDetector { LapDetector.shared }
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

    // Enhanced sensor data from Watch (display-only)
    private let sensorAnalyzer = WatchSensorAnalyzer.shared

    private var usesGPS: Bool {
        session.runMode == .outdoor || session.runMode == .track
    }

    private var isTrackMode: Bool {
        session.runMode == .track
    }

    // MARK: - Plugin Access

    private var runningPlugin: RunningPlugin? {
        tracker.plugin(as: RunningPlugin.self)
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
            if tracker.sessionState == .idle {
                tracker.isSharingWithFamily = shareWithFamily
                let plugin = RunningPlugin(
                    session: session,
                    intervalSettings: intervalSettings,
                    programIntervals: programIntervals,
                    targetDistance: targetDistance,
                    targetCadence: targetCadence
                )
                Task {
                    await tracker.startSession(plugin: plugin)
                }
            }
        }
        .confirmationDialog("End Session", isPresented: $showingCancelConfirmation, titleVisibility: .visible) {
            Button("Save") {
                tracker.stopSession()
                onEnd()
            }
            Button("Discard", role: .destructive) {
                tracker.discardSession()
                onDiscard?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to save or discard this session?")
        }
        .alert("Vehicle Detected", isPresented: Binding(
            get: { tracker.showingVehicleAlert },
            set: { tracker.showingVehicleAlert = $0 }
        )) {
            Button("Stop & Save") {
                tracker.stopSession()
                onEnd()
            }
            Button("Keep Tracking", role: .cancel) {}
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
            if session.isOutdoor, let weather = tracker.currentWeather {
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
                if tracker.sessionState == .paused {
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
        let isTracking = tracker.sessionState == .tracking
        return VStack(spacing: 0) {
            // Tap hint at top
            Text(!isTracking ? "Tap to Resume" : "Tap to Pause")
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
                isPaused: !isTracking,
                onTap: {
                    if isTracking {
                        tracker.pauseSession()
                    } else {
                        tracker.resumeSession()
                    }
                },
                onStop: {
                    tracker.stopSession()
                    onEnd()
                },
                onDiscard: {
                    tracker.discardSession()
                    onDiscard?()
                }
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
                    elapsedTime: tracker.elapsedTime,
                    isRunning: tracker.sessionState == .tracking
                )
            }

            // Duration
            VStack(spacing: 4) {
                Text("Duration")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(formatTime(tracker.elapsedTime))
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

    private var pacerGapColor: Color {
        switch VirtualPacer.shared.gapStatus {
        case .wellAhead: return .blue
        case .slightlyAhead, .onPace: return .green
        case .slightlyBehind: return .yellow
        case .wellBehind: return .red
        }
    }

    // MARK: - Run Metrics (General Running)

    private var runMetrics: some View {
        VStack(spacing: 24) {
            // Distance - prominent
            VStack(spacing: 4) {
                Text(formatDistance(tracker.totalDistance))
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
            if tracker.currentHeartRate > 0 {
                HStack(spacing: 24) {
                    // Current heart rate with pulsing icon
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                                .symbolEffect(.pulse, options: .repeating)
                            Text("\(tracker.currentHeartRate)")
                                .scaledFont(size: 32, weight: .bold, design: .rounded, relativeTo: .title)
                        }
                        Text("bpm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if tracker.averageHeartRate > 0 {
                        VStack(spacing: 4) {
                            Text("\(tracker.averageHeartRate)")
                                .scaledFont(size: 22, weight: .semibold, design: .rounded, relativeTo: .title3)
                            Text("Avg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if tracker.maxHeartRate > 0 {
                        VStack(spacing: 4) {
                            Text("\(tracker.maxHeartRate)")
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
            if let plugin = runningPlugin, (plugin.currentCadence > 0 || plugin.verticalOscillation > 0) {
                HStack(spacing: 24) {
                    // Cadence
                    VStack(spacing: 4) {
                        Text("Cadence")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 2) {
                            Text("\(plugin.currentCadence)")
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
                            Text(String(format: "%.1f", plugin.verticalOscillation))
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
                            Text(String(format: "%.0f", plugin.groundContactTime))
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
        let cadence = runningPlugin?.currentCadence ?? 0
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
        let verticalOscillation = runningPlugin?.verticalOscillation ?? 0
        if verticalOscillation <= 8.0 { return .green }  // Efficient
        if verticalOscillation <= 10.0 { return .yellow }
        return .orange  // Too bouncy
    }

    private var gctColor: Color {
        let groundContactTime = runningPlugin?.groundContactTime ?? 0
        if groundContactTime <= 250 { return .green }  // Good
        if groundContactTime <= 300 { return .yellow }
        return .orange  // Too long
    }

    // MARK: - Tetrathlon Metrics

    // MARK: - Projected Points

    private var projectedPoints: Double {
        guard targetDistance > 0, tracker.totalDistance > 50, tracker.elapsedTime > 0 else { return 0 }
        let percentComplete = tracker.totalDistance / targetDistance
        guard percentComplete > 0.05 else { return 0 }
        let projectedTime = tracker.elapsedTime / percentComplete
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

                Text(formatDistance(tracker.totalDistance))
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
                                .frame(width: min(geo.size.width, geo.size.width * (tracker.totalDistance / targetDistance)), height: 8)
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
        let currentWorkoutPhase = runningPlugin?.workoutPhase ?? .warmup
        let currentIntervalCount = runningPlugin?.intervalCount ?? 1
        let currentPhaseTime = runningPlugin?.phaseTime ?? 0
        let currentIsWorkPhase = runningPlugin?.isWorkPhase ?? true

        return VStack(spacing: 20) {
            // Phase indicator with countdown
            if let settings = intervalSettings {
                VStack(spacing: 8) {
                    Text(phaseDisplayName(currentWorkoutPhase))
                        .font(.title2.bold())
                        .foregroundStyle(phaseColor(currentWorkoutPhase))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(phaseColor(currentWorkoutPhase).opacity(0.2))
                        .clipShape(Capsule())

                    // Phase countdown
                    if currentWorkoutPhase != .finished {
                        Text(formatTime(phaseTimeRemaining(currentWorkoutPhase, phaseTime: currentPhaseTime)))
                            .scaledFont(size: 48, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                            .monospacedDigit()
                            .foregroundStyle(phaseColor(currentWorkoutPhase))
                    }
                }

                // Progress info
                HStack(spacing: 32) {
                    VStack(spacing: 4) {
                        Text("Interval")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(currentIntervalCount) / \(settings.numberOfIntervals)")
                            .scaledFont(size: 24, weight: .bold, design: .rounded, relativeTo: .title3)
                    }

                    VStack(spacing: 4) {
                        Text("Phase Time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatTime(currentPhaseTime))
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
                    Text(currentIsWorkPhase ? "WORK" : "REST")
                        .font(.title2.bold())
                        .foregroundStyle(currentIsWorkPhase ? .orange : .green)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background((currentIsWorkPhase ? Color.orange : Color.green).opacity(0.2))
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
                        Text("#\(currentIntervalCount)")
                            .scaledFont(size: 32, weight: .bold, design: .rounded, relativeTo: .title)
                    }

                    VStack(spacing: 4) {
                        Text("Phase Time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatTime(currentPhaseTime))
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
                Text(formatDistance(tracker.totalDistance))
                    .scaledFont(size: 20, weight: .semibold, design: .rounded, relativeTo: .title3)
                    .monospacedDigit()
            }
        }
    }

    private func phaseDisplayName(_ phase: RunningPlugin.IntervalWorkoutPhase) -> String {
        switch phase {
        case .warmup: return "WARMUP"
        case .work: return "WORK"
        case .rest: return "REST"
        case .cooldown: return "COOLDOWN"
        case .finished: return "FINISHED"
        }
    }

    private func phaseColor(_ phase: RunningPlugin.IntervalWorkoutPhase) -> Color {
        switch phase {
        case .warmup: return .blue
        case .work: return .orange
        case .rest: return .green
        case .cooldown: return .blue
        case .finished: return .purple
        }
    }

    private func phaseTimeRemaining(_ phase: RunningPlugin.IntervalWorkoutPhase, phaseTime: TimeInterval) -> TimeInterval {
        guard let settings = intervalSettings else { return 0 }
        let phaseDuration: TimeInterval
        switch phase {
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
        guard tracker.totalDistance > 0 else { return 0 }
        return (tracker.elapsedTime / tracker.totalDistance) * 1000
    }

    private var averagePace: String {
        guard tracker.totalDistance > 100 else { return "--:--" }
        return formatPace(averagePaceSeconds)
    }

    private var currentPaceSeconds: TimeInterval {
        guard tracker.totalDistance > 0 else { return 0 }
        return (tracker.elapsedTime / tracker.totalDistance) * 1000
    }

    private var currentPace: String {
        guard tracker.totalDistance > 100 else { return "--:--" }
        return formatPace(currentPaceSeconds)
    }

    private func formatPace(_ secondsPerKm: TimeInterval) -> String {
        let mins = Int(secondsPerKm) / 60
        let secs = Int(secondsPerKm) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Manual Phase Toggle (for interval sessions without settings)

    private func togglePhase() {
        guard let plugin = runningPlugin else { return }
        if plugin.isWorkPhase {
            plugin.intervalCount += 1
        }
        plugin.isWorkPhase.toggle()
        plugin.phaseTime = 0
    }

    // MARK: - Formatters

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

    @Environment(SessionTracker.self) private var tracker: SessionTracker

    @State private var showingCancelConfirmation = false
    @State private var showingDistanceInput = false

    // Manual input fields
    @State private var manualDistanceKm: Double = 0.0
    @State private var manualDistanceText: String = ""
    @State private var manualSpeedKmh: Double = 0.0
    @State private var manualSpeedText: String = ""
    @State private var inclinePercentage: Double = 0.0

    // MARK: - Plugin Accessor

    private var runningPlugin: RunningPlugin? {
        tracker.plugin(as: RunningPlugin.self)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 24) {
                // Header with audio controls, treadmill icon, and close button
                HStack {
                    CompactAudioControls()

                    Spacer()

                    // Watch connection indicator
                    if WatchConnectivityManager.shared.isReachable {
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
                    Text(formatTime(tracker.elapsedTime))
                        .scaledFont(size: 56, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                        .monospacedDigit()
                }

                // Treadmill metrics
                treadmillMetrics

                Spacer()

                // Pause/Resume button with stop option
                PauseResumeButton(
                    isPaused: tracker.sessionState != .tracking,
                    onTap: {
                        if tracker.sessionState == .tracking {
                            tracker.pauseSession()
                        } else {
                            tracker.resumeSession()
                        }
                    },
                    onStop: {
                        showingDistanceInput = true
                    },
                    onDiscard: {
                        tracker.discardSession()
                        onDiscard?()
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
            if tracker.sessionState == .idle {
                let plugin = RunningPlugin(
                    session: session,
                    intervalSettings: nil,
                    programIntervals: nil,
                    targetDistance: 0,
                    targetCadence: targetCadence
                )
                Task { await tracker.startSession(plugin: plugin) }
            }
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            // Audio form reminders are stopped by RunningPlugin.onSessionStopping
        }
        .confirmationDialog("End Session", isPresented: $showingCancelConfirmation, titleVisibility: .visible) {
            Button("Save") {
                endSession()
            }
            Button("Discard", role: .destructive) {
                tracker.discardSession()
                onDiscard?()
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
                duration: tracker.elapsedTime,
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
            if tracker.currentHeartRate > 0 {
                HStack(spacing: 24) {
                    // Current heart rate with pulsing icon
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                                .symbolEffect(.pulse, options: .repeating)
                            Text("\(tracker.currentHeartRate)")
                                .scaledFont(size: 32, weight: .bold, design: .rounded, relativeTo: .title)
                        }
                        Text("bpm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if tracker.averageHeartRate > 0 {
                        VStack(spacing: 4) {
                            Text("\(tracker.averageHeartRate)")
                                .scaledFont(size: 22, weight: .semibold, design: .rounded, relativeTo: .title3)
                            Text("Avg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if tracker.maxHeartRate > 0 {
                        VStack(spacing: 4) {
                            Text("\(tracker.maxHeartRate)")
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

            // Cadence display (from Watch via RunningPlugin)
            if let plugin = runningPlugin, plugin.currentCadence > 0 {
                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("Cadence")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 2) {
                            Text("\(plugin.currentCadence)")
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

                    if plugin.verticalOscillation > 0 {
                        VStack(spacing: 4) {
                            Text("Oscillation")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 2) {
                                Text(String(format: "%.1f", plugin.verticalOscillation))
                                    .scaledFont(size: 22, weight: .semibold, design: .rounded, relativeTo: .title3)
                                Text("cm")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if plugin.groundContactTime > 0 {
                        VStack(spacing: 4) {
                            Text("Contact")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 2) {
                                Text(String(format: "%.0f", plugin.groundContactTime))
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
        let cadence = runningPlugin?.currentCadence ?? 0
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
        let elapsed = tracker.elapsedTime
        guard manualDistanceKm > 0, elapsed > 0 else { return "--:--" }
        let paceSecondsPerKm = elapsed / manualDistanceKm
        let mins = Int(paceSecondsPerKm) / 60
        let secs = Int(paceSecondsPerKm) % 60
        return String(format: "%d:%02d /km", mins, secs)
    }

    private var calculatedSpeed: String {
        let elapsed = tracker.elapsedTime
        guard manualDistanceKm > 0, elapsed > 0 else { return "--.- km/h" }
        let speedKmh = manualDistanceKm / (elapsed / 3600)
        return String(format: "%.1f km/h", speedKmh)
    }

    // MARK: - Actions

    private func endSession() {
        // Write treadmill-specific values to session before stopping
        session.totalDistance = manualDistanceKm * 1000
        session.treadmillIncline = inclinePercentage > 0 ? inclinePercentage : nil
        session.manualDistance = true
        showingDistanceInput = false
        UIApplication.shared.isIdleTimerDisabled = false
        tracker.stopSession()
        onEnd()
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
