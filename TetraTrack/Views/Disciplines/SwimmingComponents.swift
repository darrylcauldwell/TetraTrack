//
//  SwimmingComponents.swift
//  TetraTrack
//
//  Swimming subviews extracted from SwimmingView
//

import SwiftUI
import CoreLocation
import MapKit

// MARK: - Swimming Watch Status Card

/// Shows Apple Watch connection state with guidance for swimming sessions.
struct SwimmingWatchStatusCard: View {
    private var watchConnectivity: WatchConnectivityManager { WatchConnectivityManager.shared }

    private var isConnected: Bool {
        watchConnectivity.isPaired && watchConnectivity.isWatchAppInstalled && watchConnectivity.isReachable
    }

    private var isAppNotInstalled: Bool {
        watchConnectivity.isPaired && !watchConnectivity.isWatchAppInstalled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "applewatch")
                    .font(.title3)
                    .foregroundStyle(isConnected ? AppColors.primary : .secondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Watch")
                        .font(.subheadline.weight(.semibold))
                    if isConnected {
                        AccessibleStatusIndicator(.connected, size: .small)
                    } else if isAppNotInstalled {
                        AccessibleStatusIndicator(.error, size: .small)
                    } else {
                        AccessibleStatusIndicator(.standby, size: .small)
                    }
                }

                Spacer()

                if isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.success)
                }
            }

            if isConnected {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Enhanced swimming metrics from your watch:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    swimmingMetricRow(icon: "figure.pool.swim", text: "Stroke counting & stroke rate", color: .cyan)
                    swimmingMetricRow(icon: "heart.fill", text: "Heart rate monitoring", color: .red)
                    swimmingMetricRow(icon: "arrow.turn.down.right", text: "Lap detection assistance", color: .blue)
                    swimmingMetricRow(icon: "gauge.with.dots.needle.33percent", text: "SWOLF calculation", color: .orange)
                }
            } else if isAppNotInstalled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Install TetraTrack on your Apple Watch to unlock stroke detection and SWOLF tracking.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Open the Watch app on your iPhone to install.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Watch will connect automatically when you start your session.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Once connected you'll get:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    swimmingMetricRow(icon: "figure.pool.swim", text: "Stroke counting & stroke rate", color: .cyan)
                    swimmingMetricRow(icon: "heart.fill", text: "Heart rate monitoring", color: .red)
                    swimmingMetricRow(icon: "arrow.turn.down.right", text: "Lap detection assistance", color: .blue)
                    swimmingMetricRow(icon: "gauge.with.dots.needle.33percent", text: "SWOLF calculation", color: .orange)
                }
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func swimmingMetricRow(icon: String, text: String, color: Color) -> some View {
        Label {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
                .frame(width: 16)
        }
    }
}

// MARK: - Swim Type Button

struct SwimTypeButton: View {
    let title: String
    let icon: String
    let color: Color
    var subtitle: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(color)
                    .frame(width: 70)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Swim Type Card (Grid Style)

struct SwimTypeCard: View {
    let title: String
    let icon: String
    let color: Color
    var subtitle: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(color)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Swimming Settings View

struct SwimmingSettingsView: View {
    @Binding var poolLength: Double
    @Binding var poolModeRaw: String
    @Binding var freeSwimTargetDuration: Double
    @Environment(\.dismiss) private var dismiss

    private let watchManager = WatchConnectivityManager.shared

    private var isOpenWater: Bool {
        SwimmingPoolMode(rawValue: poolModeRaw) == .openWater
    }

    private var isWatchAvailable: Bool {
        watchManager.isPaired && watchManager.isWatchAppInstalled
    }

    private var poolModeBinding: Binding<String> {
        Binding(
            get: { poolModeRaw },
            set: { newValue in
                // Only allow Open Water if Watch is available
                if newValue == SwimmingPoolMode.openWater.rawValue && !isWatchAvailable {
                    return
                }
                poolModeRaw = newValue
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Pool Type", selection: poolModeBinding) {
                        ForEach(SwimmingPoolMode.allCases, id: \.rawValue) { mode in
                            Text(mode.rawValue).tag(mode.rawValue)
                        }
                    }

                    if !isOpenWater {
                        Picker("Pool Length", selection: $poolLength) {
                            Text("20m").tag(20.0)
                            Text("25m").tag(25.0)
                            Text("33.3m").tag(33.3)
                            Text("50m").tag(50.0)
                        }
                    }
                } header: {
                    Text("Pool Settings")
                }

                Section {
                    Picker("Free Swim Duration", selection: $freeSwimTargetDuration) {
                        Text("No Limit").tag(0.0)
                        Text("15 min").tag(900.0)
                        Text("20 min").tag(1200.0)
                        Text("30 min").tag(1800.0)
                        Text("45 min").tag(2700.0)
                        Text("60 min").tag(3600.0)
                    }
                } header: {
                    Text("Free Swim")
                } footer: {
                    Text("Set a target duration for free swim sessions. Your Watch will alert you at intervals and when time is up.")
                }

                if !isWatchAvailable {
                    Section {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Apple Watch Required for Open Water")
                                    .font(.subheadline.weight(.medium))
                                Text("Open water swimming uses your Apple Watch for GPS distance tracking and stroke detection, since there are no pool walls to count lengths against.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "applewatch")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Swimming Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: poolModeRaw) {
                // Reset to pool if Watch becomes unavailable while Open Water is selected
                if isOpenWater && !isWatchAvailable {
                    poolModeRaw = SwimmingPoolMode.pool.rawValue
                }
            }
        }
    }
}

// MARK: - Swimming Personal Bests

struct SwimmingPersonalBests {
    static var shared = SwimmingPersonalBests()

    private let store = NSUbiquitousKeyValueStore.default

    // 3-minute test personal best (distance in meters)
    var pb3MinDistance: Double {
        get { store.double(forKey: "swim_pb_3min_distance") }
        set { store.set(newValue, forKey: "swim_pb_3min_distance"); store.synchronize() }
    }

    var pb3MinTime: TimeInterval {
        get { store.double(forKey: "swim_pb_3min_time") }
        set { store.set(newValue, forKey: "swim_pb_3min_time"); store.synchronize() }
    }

    // CSS (Critical Swim Speed) threshold pace
    var thresholdPace: TimeInterval {
        get { store.double(forKey: "swim_threshold_pace") }
        set { store.set(newValue, forKey: "swim_threshold_pace"); store.synchronize() }
    }

    var thresholdPaceDate: Date? {
        get { store.object(forKey: "swim_threshold_pace_date") as? Date }
        set { store.set(newValue, forKey: "swim_threshold_pace_date"); store.synchronize() }
    }

    mutating func updatePersonalBest(distance: Double, time: TimeInterval) {
        // For 3-minute test, better = more distance
        if distance > pb3MinDistance {
            pb3MinDistance = distance
            pb3MinTime = time
        }
    }

    mutating func updateThresholdPace(from distance: Double, testDuration: TimeInterval) {
        guard distance > 0, testDuration > 0 else { return }
        let pace = testDuration / (distance / 100) // seconds per 100m
        // CSS approximation: threshold is ~5% slower than test pace
        thresholdPace = pace * 1.05
        thresholdPaceDate = Date()
    }

    func formattedPBDistance() -> String {
        guard pb3MinDistance > 0 else { return "--" }
        return String(format: "%.0fm", pb3MinDistance)
    }

    func formattedPBPace() -> String {
        guard pb3MinDistance > 0, pb3MinTime > 0 else { return "--:--" }
        let pace = pb3MinTime / (pb3MinDistance / 100) // seconds per 100m
        let mins = Int(pace) / 60
        let secs = Int(pace) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    func formattedThresholdPace() -> String {
        guard thresholdPace > 0 else { return "--:--" }
        let mins = Int(thresholdPace) / 60
        let secs = Int(thresholdPace) % 60
        return String(format: "%d:%02d /100m", mins, secs)
    }

    // MARK: - Migration from UserDefaults

    static func migrateFromUserDefaults() {
        let defaults = UserDefaults.standard
        let store = NSUbiquitousKeyValueStore.default

        guard !defaults.bool(forKey: "swimming_pb_migrated_to_icloud") else { return }

        let keys = ["swim_pb_3min_distance", "swim_pb_3min_time", "swim_threshold_pace"]
        for key in keys {
            let value = defaults.double(forKey: key)
            if value > 0 && store.double(forKey: key) == 0 {
                store.set(value, forKey: key)
            }
        }
        if let date = defaults.object(forKey: "swim_threshold_pace_date") as? Date,
           store.object(forKey: "swim_threshold_pace_date") == nil {
            store.set(date, forKey: "swim_threshold_pace_date")
        }
        store.synchronize()
        defaults.set(true, forKey: "swimming_pb_migrated_to_icloud")
    }
}

// MARK: - Swimming Live View

struct SwimmingLiveView: View {
    @Environment(SessionTracker.self) private var tracker: SessionTracker?
    @Environment(GPSSessionTracker.self) private var gpsTracker: GPSSessionTracker?
    @Environment(LocationManager.self) private var locationManager: LocationManager?

    // Pure UI state
    @State private var isArmedForSubmersion = false
    @State private var additionalMeters: Int = 0  // Extra meters from partial length
    @State private var showStrokePicker: Bool = false
    @State private var strokePickerTimer: Timer?
    @State private var lastSubmersionState: Bool = false
    @State private var showAutoLapHint: Bool = false
    @State private var autoLapDismissTimer: Timer?
    @State private var showingCancelConfirmation = false

    // Watch & sensor references (for UI display only)
    private let watchManager = WatchConnectivityManager.shared
    private let sensorAnalyzer = WatchSensorAnalyzer.shared

    // MARK: - Plugin Access

    private var swimmingPlugin: SwimmingPlugin? {
        tracker?.plugin(as: SwimmingPlugin.self)
    }

    private var session: SwimmingSession {
        swimmingPlugin!.session
    }

    private var poolLength: Double {
        swimmingPlugin?.poolLength ?? 25
    }

    private var isThreeMinuteTest: Bool {
        swimmingPlugin?.isThreeMinuteTest ?? false
    }

    private var testDuration: TimeInterval {
        swimmingPlugin?.testDuration ?? 180
    }

    private var freeSwimTargetDuration: TimeInterval? {
        swimmingPlugin?.freeSwimTargetDuration
    }

    private var intervalSettings: SwimmingIntervalSettings? {
        swimmingPlugin?.intervalSettings
    }

    // MARK: - Computed Properties (UI)

    private var isOpenWater: Bool {
        session.poolMode == .openWater
    }

    private var hasStarted: Bool {
        tracker?.sessionState != .idle
    }

    private var isRunning: Bool {
        tracker?.sessionState == .tracking
    }

    private var testComplete: Bool {
        swimmingPlugin?.testComplete ?? false
    }

    private var lengthCount: Int {
        swimmingPlugin?.completedLengths ?? 0
    }

    private var strokeCount: Int {
        swimmingPlugin?.strokeCount ?? 0
    }

    private var strokeRate: Double {
        swimmingPlugin?.strokeRate ?? 0.0
    }

    private var isResting: Bool {
        swimmingPlugin?.isResting ?? false
    }

    private var restTimeRemaining: TimeInterval {
        swimmingPlugin?.restTimeRemaining ?? 0
    }

    private var currentIntervalIndex: Int {
        swimmingPlugin?.currentIntervalIndex ?? 0
    }

    private var isIntervalMode: Bool {
        swimmingPlugin?.isIntervalMode ?? (intervalSettings != nil)
    }

    private var allIntervalsComplete: Bool {
        swimmingPlugin?.allIntervalsComplete ?? false
    }

    private var distanceInCurrentInterval: Double {
        swimmingPlugin?.distanceInCurrentInterval ?? 0
    }

    private var lengthTimes: [TimeInterval] {
        swimmingPlugin?.lengthTimes ?? []
    }

    private var lengthStrokes: [Int] {
        swimmingPlugin?.lengthStrokes ?? []
    }

    private var averageSWOLF: Double {
        swimmingPlugin?.averageSWOLF ?? 0
    }

    private var hasTimedTarget: Bool {
        isThreeMinuteTest || freeSwimTargetDuration != nil
    }

    private var effectiveTargetDuration: TimeInterval {
        if isThreeMinuteTest { return testDuration }
        return freeSwimTargetDuration ?? 0
    }

    private var freeSwimTimeRemaining: TimeInterval {
        guard let target = freeSwimTargetDuration else { return 0 }
        return max(0, target - (tracker?.elapsedTime ?? 0))
    }

    private var totalDistance: Double {
        if isOpenWater {
            return tracker?.totalDistance ?? 0
        }
        return Double(lengthCount) * poolLength + Double(additionalMeters)
    }

    private var timeRemaining: TimeInterval {
        max(0, testDuration - (tracker?.elapsedTime ?? 0))
    }

    private var currentPace: TimeInterval {
        guard totalDistance > 0, (tracker?.elapsedTime ?? 0) > 0 else { return 0 }
        return (tracker?.elapsedTime ?? 0) / (totalDistance / 100) // seconds per 100m
    }

    private var currentPaceZone: SwimmingPaceZone? {
        let threshold = SwimmingPersonalBests.shared.thresholdPace
        guard threshold > 0, currentPace > 0 else { return nil }
        return SwimmingPaceZone.zone(for: currentPace, thresholdPace: threshold)
    }

    // SWOLF color indicator - lower is better
    private var swolfColor: Color {
        if averageSWOLF < 40 { return .green }
        if averageSWOLF < 55 { return .yellow }
        return .orange
    }

    // Projected distance if current pace maintained for full test duration
    private var projectedDistance: Double {
        guard (tracker?.elapsedTime ?? 0) > 0, totalDistance > 0 else { return 0 }
        return (totalDistance / (tracker?.elapsedTime ?? 1)) * testDuration
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Header
                    headerView
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // Stats content
                    statsContentView(geometry: geometry)
                        .padding(.horizontal)

                    // Bottom controls
                    controlsView(geometry: geometry)
                        .padding(.bottom, 16)
                }
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.blue.opacity(0.05),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .onDisappear {
            strokePickerTimer?.invalidate()
        }
        .onChange(of: watchManager.strokeDetectedSequence) {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        .onChange(of: watchManager.enhancedSensorSequence) {
            let currentlySubmerged = sensorAnalyzer.isSubmerged

            // Submersion-triggered start for open water
            if isArmedForSubmersion && currentlySubmerged {
                triggerSubmersionStart()
            }

            // Detect surface -> resubmerge pattern (wall turn) for auto-lap
            if !lastSubmersionState && currentlySubmerged && hasStarted && isRunning {
                if lengthCount > 0 && !showAutoLapHint && !showStrokePicker {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAutoLapHint = true
                    }
                    autoLapDismissTimer?.invalidate()
                    autoLapDismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                        dismissAutoLapHint()
                    }
                }
            }
            lastSubmersionState = currentlySubmerged
        }
        .overlay(alignment: .top) {
            VoiceNoteRecordingOverlay()
        }
        .overlay(alignment: .bottom) {
            if hasStarted && !testComplete && !isArmedForSubmersion {
                FloatingControlPanel(
                    disciplineIcon: tracker?.activePlugin?.disciplineIcon ?? "figure.pool.swim",
                    disciplineColor: tracker?.activePlugin?.disciplineColor ?? .blue,
                    onStop: { tracker?.stopSession() }
                )
            }
        }
        .overlay(alignment: .bottom) {
            if showStrokePicker {
                SwimmingStrokeQuickPicker { stroke in
                    selectStrokeForLastLength(stroke)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 120)
            }
        }
        .overlay(alignment: .top) {
            if showAutoLapHint && !isOpenWater {
                SwimmingAutoLapHintBanner(
                    onConfirm: {
                        dismissAutoLapHint()
                        recordLength()
                    },
                    onDismiss: {
                        dismissAutoLapHint()
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 60)
                .padding(.horizontal)
            }
        }
        .confirmationDialog("End Swimming Session?", isPresented: $showingCancelConfirmation, titleVisibility: .visible) {
            Button("Save Session") {
                tracker?.stopSession()
            }
            Button("Discard", role: .destructive) {
                tracker?.discardSession()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: 12) {
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

            Spacer()

            // Right side controls
            HStack(spacing: 8) {
                // Voice notes button - only show when paused
                if !isRunning {
                    VoiceNoteToolbarButton { note in
                        let service = VoiceNotesService.shared
                        session.notes = service.appendNote(note, to: session.notes)
                    }
                    .frame(width: 44, height: 44)
                }

                // Close button
                Button {
                    showingCancelConfirmation = true
                } label: {
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

    // MARK: - Stats Content View

    private func statsContentView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 20) {
            // Interval progress header
            if isIntervalMode && hasStarted, let settings = intervalSettings {
                if isResting {
                    SwimmingRestTimerView(
                        timeRemaining: restTimeRemaining,
                        totalRestDuration: settings.restDuration,
                        intervalNumber: currentIntervalIndex,
                        totalIntervals: settings.numberOfIntervals
                    )
                } else if !allIntervalsComplete {
                    SwimmingIntervalProgressView(
                        currentInterval: currentIntervalIndex + 1,
                        totalIntervals: settings.numberOfIntervals,
                        distanceInInterval: distanceInCurrentInterval,
                        targetDistance: settings.targetDistance,
                        currentPace: currentPace,
                        targetPace: settings.targetPace
                    )
                }
            }

            // Timer/Duration display
            timerDisplay
                .padding(.top, 8)

            // Lengths and Distance (pool) or GPS Distance (open water)
            if isOpenWater {
                if isArmedForSubmersion {
                    armedWaitingView
                } else if hasStarted {
                    openWaterDistanceDisplay
                } else {
                    openWaterPreStartView
                }
            } else {
                lengthsDistanceDisplay
            }

            // Watch haptic explanation (pool mode, before starting)
            if !isOpenWater && !hasStarted && watchManager.isReachable {
                hapticExplanationView
            }

            // Watch stroke tracking (when connected)
            if watchManager.isReachable && hasStarted {
                strokeTrackingDisplay
            }

            // Live heart rate with zone (always visible for parent/coach)
            if hasStarted {
                HeartRateDisplayView(
                    heartRate: tracker?.currentHeartRate ?? 0,
                    zone: tracker?.currentHeartRateZone ?? .zone1,
                    averageHeartRate: (tracker?.averageHeartRate ?? 0) > 0 ? tracker?.averageHeartRate : nil,
                    maxHeartRate: (tracker?.maxHeartRate ?? 0) > 0 ? tracker?.maxHeartRate : nil
                )
                .padding()
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Physiology panel (breathing, SpO2, fatigue from Watch)
                if sensorAnalyzer.breathingRate > 0 || sensorAnalyzer.oxygenSaturation > 0 || sensorAnalyzer.fatigueScore > 0 {
                    swimPhysiologyPanel
                }
            }

            // Live split chart (after 2+ lengths)
            if lengthTimes.count >= 2 {
                SwimmingSplitChart(
                    lengthTimes: lengthTimes,
                    poolLength: poolLength,
                    thresholdPace: SwimmingPersonalBests.shared.thresholdPace,
                    compact: true
                )
                .padding()
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Pace display
            if hasStarted && totalDistance > 0 {
                paceDisplay
            }

            // Water detection and SpO2 sensor metrics
            if hasStarted && (sensorAnalyzer.isSubmerged || sensorAnalyzer.oxygenSaturation > 0 || sensorAnalyzer.currentSubmergedTime > 0) {
                SwimmingSensorMetricsView(
                    isSubmerged: sensorAnalyzer.isSubmerged,
                    submergedTime: sensorAnalyzer.currentSubmergedTime,
                    submersionCount: sensorAnalyzer.submersionCount,
                    spo2: sensorAnalyzer.oxygenSaturation,
                    minSpo2: sensorAnalyzer.minSpO2,
                    recoveryQuality: sensorAnalyzer.recoveryQuality
                )
            }

            // Open water map or lap button
            if isOpenWater {
                if hasStarted {
                    LiveSessionMapView(
                        routeSegments: {
                            let coords = gpsTracker?.routeCoordinates ?? []
                            guard coords.count > 1 else { return [] }
                            return [RouteSegment(coordinates: coords, color: .cyan)]
                        }(),
                        followsUser: false
                    )
                    .overlay(alignment: .bottomTrailing) {
                        VStack(spacing: 2) {
                            Text(String(format: "%.0fm", tracker?.totalDistance ?? 0))
                                .font(.headline.bold())
                                .monospacedDigit()
                            Text("GPS Distance")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding()
                    }
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, -16) // bleed to edges
                }
            } else if !testComplete {
                lapButton(geometry: geometry)
                    .padding(.vertical, 8)
            }
        }
    }

    private var timerDisplay: some View {
        VStack(spacing: 8) {
            if isArmedForSubmersion {
                Text("Awaiting Water Entry")
                    .font(.subheadline)
                    .foregroundStyle(.cyan)

                Text(formatTime(effectiveTargetDuration))
                    .scaledFont(size: 64, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else if isThreeMinuteTest {
                Text(testComplete ? "Time!" : (hasStarted ? "Time Remaining" : "Timed Test"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(formatTime(hasStarted ? timeRemaining : testDuration))
                    .scaledFont(size: 64, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                    .monospacedDigit()
                    .foregroundStyle(timeRemaining < 30 && hasStarted ? .red : .primary)
            } else if let target = freeSwimTargetDuration {
                Text(testComplete ? "Target Reached!" : (hasStarted ? "Time Remaining" : "\(Int(target / 60)) min Swim"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(formatTime(hasStarted ? freeSwimTimeRemaining : target))
                    .scaledFont(size: 64, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                    .monospacedDigit()
                    .foregroundStyle(freeSwimTimeRemaining < 60 && hasStarted ? .orange : .primary)
            } else {
                Text("Duration")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(formatTime(tracker?.elapsedTime ?? 0))
                    .scaledFont(size: 64, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                    .monospacedDigit()
            }
        }
    }

    private var lengthsDistanceDisplay: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("\(lengthCount)")
                        .scaledFont(size: 44, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                        .foregroundStyle(.blue)
                    Text("Lengths")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text(String(format: "%.0f", totalDistance))
                        .scaledFont(size: 44, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                        .foregroundStyle(.blue)
                    Text("Meters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 16)

            // Additional meters input for partial length after timed test
            if testComplete && isThreeMinuteTest {
                Divider()
                    .padding(.horizontal)
                HStack {
                    Text("Extra meters")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Stepper("\(additionalMeters)m", value: $additionalMeters, in: 0...Int(poolLength - 1))
                        .font(.subheadline.monospacedDigit())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var openWaterDistanceDisplay: some View {
        VStack(spacing: 4) {
            Text(String(format: "%.0f", tracker?.totalDistance ?? 0))
                .scaledFont(size: 44, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                .foregroundStyle(.blue)
            Text("Meters")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var openWaterPreStartView: some View {
        VStack(spacing: 16) {
            Image(systemName: "applewatch.and.arrow.forward")
                .font(.system(size: 40))
                .foregroundStyle(.cyan)

            Text("Open Water Swim")
                .font(.headline)

            Text("Tap Start to begin tracking. Your Apple Watch will track GPS distance and stroke data during the swim.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if watchManager.isReachable {
                Label("Watch Connected", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
            } else {
                Label("Watch Not Reachable", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var armedWaitingView: some View {
        VStack(spacing: 16) {
            Image(systemName: "water.waves")
                .font(.system(size: 48))
                .foregroundStyle(.cyan)
                .symbolEffect(.pulse, options: .repeating)

            Text("Waiting for Water Entry...")
                .font(.headline)

            Text("Timer will start automatically when your Apple Watch detects submersion. Walk to the water at your own pace.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            hapticExplanationView

            if watchManager.isReachable {
                Label("Watch Connected - Sensors Active", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
            } else {
                Label("Watch Not Reachable", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            }

            Button {
                triggerSubmersionStart()
            } label: {
                Label("Start Now", systemImage: "play.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.cyan)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var hapticExplanationView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Watch Haptic Alerts")
                .font(.caption.weight(.semibold))

            if isThreeMinuteTest {
                hapticRow(color: .cyan, text: "Single tap every minute")
                hapticRow(color: .orange, text: "Strong buzz at 10 seconds remaining")
                hapticRow(color: .green, text: "Double tap when time is up")
            } else if freeSwimTargetDuration != nil {
                hapticRow(color: .cyan, text: "Single tap every 5 minutes")
                hapticRow(color: .orange, text: "Strong buzz at 1 minute remaining")
                hapticRow(color: .green, text: "Double tap when target reached")
            } else if isIntervalMode {
                hapticRow(color: .orange, text: "Triple tap when rest begins")
                hapticRow(color: .cyan, text: "Buzz at 5s and 3s of rest")
                hapticRow(color: .green, text: "Double tap when rest ends - go!")
            } else {
                // Open-ended free swim
                hapticRow(color: .cyan, text: "Single tap every 10 minutes")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.cyan.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func hapticRow(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.tap")
                .foregroundStyle(color)
                .frame(width: 20)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var strokeTrackingDisplay: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("\(strokeCount)")
                    .scaledFont(size: 28, weight: .bold, design: .rounded, relativeTo: .title2)
                    .foregroundStyle(.cyan)
                Text("Strokes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 4) {
                Text(String(format: "%.0f", strokeRate))
                    .scaledFont(size: 28, weight: .bold, design: .rounded, relativeTo: .title2)
                    .foregroundStyle(.cyan)
                Text("Rate/min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            if averageSWOLF > 0 {
                VStack(spacing: 4) {
                    Text(String(format: "%.0f", averageSWOLF))
                        .scaledFont(size: 28, weight: .bold, design: .rounded, relativeTo: .title2)
                        .foregroundStyle(swolfColor)
                    Text("SWOLF")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Physiology Panel

    private var swimPhysiologyPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "waveform.path.ecg")
                    .font(.caption2)
                    .foregroundStyle(.cyan)
                Text("Watch Sensors")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("(updates when swimmer surfaces)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 20) {
                // Breathing rate
                if sensorAnalyzer.breathingRate > 0 {
                    VStack(spacing: 2) {
                        Text(String(format: "%.0f", sensorAnalyzer.breathingRate))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                        Text("br/min")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // SpO2
                if sensorAnalyzer.oxygenSaturation > 0 {
                    VStack(spacing: 2) {
                        Text(String(format: "%.0f%%", sensorAnalyzer.oxygenSaturation))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(sensorAnalyzer.oxygenSaturation < 92 ? .red : .primary)
                        Text("SpO₂")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Fatigue score
                if sensorAnalyzer.fatigueScore > 0 {
                    VStack(spacing: 2) {
                        Text(String(format: "%.0f", sensorAnalyzer.fatigueScore))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(fatigueColor(sensorAnalyzer.fatigueScore))
                        Text("Fatigue")
                            .font(.caption2)
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

    private func fatigueColor(_ score: Double) -> Color {
        if score < 30 { return .green }
        if score < 60 { return .orange }
        return .red
    }

    private var paceDisplay: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(formatPace(currentPace))
                        .scaledFont(size: 24, weight: .semibold, design: .rounded, relativeTo: .title3)
                        .monospacedDigit()

                    if let zone = currentPaceZone {
                        Text(zone.name)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(paceZoneColor(zone))
                            .clipShape(Capsule())
                    }
                }
                Text("Pace /100m")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            if isThreeMinuteTest {
                VStack(spacing: 4) {
                    Text(String(format: "%.0fm", projectedDistance))
                        .scaledFont(size: 24, weight: .semibold, design: .rounded, relativeTo: .title3)
                        .monospacedDigit()
                    Text("Projected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func paceZoneColor(_ zone: SwimmingPaceZone) -> Color {
        switch zone {
        case .recovery: return .gray
        case .endurance: return .blue
        case .tempo: return .green
        case .threshold: return .yellow
        case .speed: return .red
        }
    }

    private func lapButton(geometry: GeometryProxy) -> some View {
        let buttonSize = min(geometry.size.width * 0.38, 140.0)

        return VStack(spacing: 12) {
            Button(action: recordLength) {
                Text("Tap Each Length")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: buttonSize, height: buttonSize)
                    .background(
                        Circle()
                            .fill(.blue)
                            .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                    )
            }
            .sensoryFeedback(.impact(weight: .heavy), trigger: lengthCount)
            .disabled(!isRunning && hasStarted)

            Text("\(Int(poolLength))m pool")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Controls View

    private func controlsView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 12) {
            if isOpenWater && !hasStarted && !isArmedForSubmersion {
                // Open water: Start button arms for submersion
                Button(action: armForSubmersion) {
                    Label("Start", systemImage: "play.fill")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: min(geometry.size.width - 80, 300))
                        .padding(.vertical, 16)
                        .background(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            } else if isArmedForSubmersion {
                // Armed state: cancel button
                Button(action: cancelArmedState) {
                    Label("Cancel", systemImage: "xmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(.orange)
                        .clipShape(Capsule())
                }
            } else if testComplete {
                // Finish button
                Button {
                    tracker?.stopSession()
                } label: {
                    Label("Save & Finish", systemImage: "checkmark.circle.fill")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: min(geometry.size.width - 80, 300))
                        .padding(.vertical, 16)
                        .background(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            // Active tracking stop is handled by FloatingControlPanel overlay
        }
        .padding(.horizontal)
    }

    // MARK: - Session Lifecycle

    private func armForSubmersion() {
        // Start sensor analyzer for submersion detection before session starts
        sensorAnalyzer.startSession(discipline: .swimming)
        watchManager.resetMotionMetrics()
        isArmedForSubmersion = true

        // Edge case: already submerged when Start tapped
        if sensorAnalyzer.isSubmerged {
            triggerSubmersionStart()
        }
    }

    private func triggerSubmersionStart() {
        guard isArmedForSubmersion else { return }
        isArmedForSubmersion = false

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func cancelArmedState() {
        isArmedForSubmersion = false
        // Stop sensor analyzer that was started for submersion detection
        sensorAnalyzer.stopSession()
        watchManager.stopMotionTracking()
    }

    // MARK: - Length Recording

    private func recordLength() {
        swimmingPlugin?.recordLength(stroke: swimmingPlugin?.currentStroke ?? .freestyle, elapsedTime: tracker?.elapsedTime ?? 0)

        // Show stroke picker briefly
        showStrokeQuickPicker()
    }

    private func showStrokeQuickPicker() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showStrokePicker = true
        }

        // Auto-dismiss after 3 seconds
        strokePickerTimer?.invalidate()
        strokePickerTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                showStrokePicker = false
            }
        }
    }

    private func selectStrokeForLastLength(_ stroke: SwimmingStroke) {
        swimmingPlugin?.updateLastLengthStroke(stroke)
        strokePickerTimer?.invalidate()
        withAnimation(.easeInOut(duration: 0.2)) {
            showStrokePicker = false
        }
    }

    private func dismissAutoLapHint() {
        autoLapDismissTimer?.invalidate()
        autoLapDismissTimer = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            showAutoLapHint = false
        }
    }

    // MARK: - Formatters

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatPace(_ secondsPer100m: TimeInterval) -> String {
        guard secondsPer100m > 0 else { return "--:--" }
        let mins = Int(secondsPer100m) / 60
        let secs = Int(secondsPer100m) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Session Detail View

struct SwimmingSessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: SwimmingSession

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Distance summary
                    VStack(spacing: 8) {
                        Text(session.formattedDistance)
                            .scaledFont(size: 60, weight: .bold, relativeTo: .largeTitle)
                            .foregroundStyle(AppColors.primary)

                        Text("in \(session.formattedDuration)")
                            .foregroundStyle(.secondary)
                    }
                    .padding()

                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        SwimMiniStat(title: "Pace", value: session.formattedPace)
                        SwimMiniStat(title: "SWOLF", value: String(format: "%.0f", session.averageSwolf))
                        SwimMiniStat(title: "Laps", value: "\(session.lapCount)")
                        if session.hasHeartRateData {
                            SwimMiniStat(title: "Avg HR", value: session.formattedAverageHeartRate)
                            SwimMiniStat(title: "Max HR", value: session.formattedMaxHeartRate)
                            SwimMiniStat(title: "Min HR", value: session.formattedMinHeartRate)
                        }
                    }
                    .padding(.horizontal)

                    // Open water route map
                    if session.hasRouteData {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "water.waves")
                                    .foregroundStyle(.cyan)
                                Text("Open Water Route")
                                    .font(.headline)
                            }

                            SessionRouteMapView(
                                coordinates: session.coordinates,
                                routeColors: .solid(.cyan)
                            )
                            .frame(height: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // Heart rate timeline
                    if session.heartRateSamples.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(.red)
                                Text("Heart Rate")
                                    .font(.headline)
                            }

                            HeartRateTimelineChart(samples: session.heartRateSamples)
                                .frame(height: 150)

                            if !session.heartRateSamples.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Time in Zones")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    HeartRateZoneChart(statistics: session.heartRateStatistics)
                                        .frame(height: 120)
                                }
                            }
                        }
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // Physiology section (Watch sensor data)
                    if session.totalSubmergedTime > 0 || session.submersionCount > 0 || session.averageSpO2 > 0 || session.recoveryQuality > 0 || session.averageBreathingRate > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "waveform.path.ecg")
                                    .foregroundStyle(AppColors.cyan)
                                Text("Physiology")
                                    .font(.headline)
                            }

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                if session.totalSubmergedTime > 0 {
                                    SwimMiniStat(title: "Submersion Time", value: session.totalSubmergedTime.formattedDuration)
                                }
                                if session.submersionCount > 0 {
                                    SwimMiniStat(title: "Submersions", value: "\(session.submersionCount)")
                                }
                                if session.averageSpO2 > 0 {
                                    SwimMiniStat(title: "SpO2", value: "\(Int(session.averageSpO2))%\(session.minSpO2 > 0 ? " (min: \(Int(session.minSpO2))%)" : "")")
                                }
                                if session.recoveryQuality > 0 {
                                    SwimMiniStat(title: "Recovery", value: String(format: "%.0f/100", session.recoveryQuality))
                                }
                                if session.averageBreathingRate > 0 {
                                    SwimMiniStat(title: "Breathing Rate", value: String(format: "%.0f bpm", session.averageBreathingRate))
                                }
                            }
                        }
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // Split charts
                    if session.sortedLaps.count >= 2 {
                        VStack(spacing: 16) {
                            SwimmingLapSplitChart(
                                laps: session.sortedLaps,
                                thresholdPace: SwimmingPersonalBests.shared.thresholdPace
                            )

                            SwimmingLapSWOLFChart(laps: session.sortedLaps)

                            StrokeRatePerLapChart(laps: session.sortedLaps)
                        }
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Lap breakdown
                    if !(session.laps ?? []).isEmpty {
                        // Stroke distribution
                        SwimmingStrokeDistributionBar(laps: session.sortedLaps)
                            .padding()
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Laps")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(session.sortedLaps) { lap in
                                LapRow(lap: lap)
                            }
                        }
                    }

                    // Session info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session Info")
                            .font(.headline)

                        HStack {
                            Text("Pool")
                            Spacer()
                            Text("\(session.poolMode.rawValue) - \(Int(session.poolLength))m")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Total Strokes")
                            Spacer()
                            Text("\(session.totalStrokes)")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Dominant Stroke")
                            Spacer()
                            Text(session.dominantStroke.rawValue)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Notes section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Notes")
                                .font(.headline)

                            Spacer()

                            VoiceNoteToolbarButton { note in
                                let service = VoiceNotesService.shared
                                session.notes = service.appendNote(note, to: session.notes)
                            }
                        }

                        if !session.notes.isEmpty {
                            Text(session.notes)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                session.notes = ""
                            } label: {
                                Label("Clear Notes", systemImage: "trash")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        } else {
                            Text("Tap the mic to add voice notes")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding()
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle(session.name.isEmpty ? "Session" : session.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SwimmingInsightsView(session: session)
                    } label: {
                        Label("Session Insights", systemImage: "chart.bar.xaxis")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Swim Mini Stat

struct SwimMiniStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Auto Lap Hint Banner

struct SwimmingAutoLapHintBanner: View {
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "water.waves")
                .font(.title3)
                .foregroundStyle(.cyan)

            Text("Length detected?")
                .font(.subheadline.weight(.medium))

            Spacer()

            Button(action: onConfirm) {
                Text("Confirm")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.cyan)
                    .clipShape(Capsule())
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(.gray.opacity(0.2))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

// MARK: - Stroke Quick Picker

struct SwimmingStrokeQuickPicker: View {
    let onSelect: (SwimmingStroke) -> Void

    private let strokes: [(SwimmingStroke, String)] = [
        (.freestyle, "FR"),
        (.backstroke, "BK"),
        (.breaststroke, "BR"),
        (.butterfly, "FL"),
    ]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(strokes, id: \.0) { stroke, label in
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    onSelect(stroke)
                } label: {
                    Text(label)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 44)
                        .background(.cyan)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Stroke Distribution Bar

struct SwimmingStrokeDistributionBar: View {
    let laps: [SwimmingLap]

    private var strokeCounts: [(SwimmingStroke, Int)] {
        let grouped = Dictionary(grouping: laps, by: { $0.stroke })
        return SwimmingStroke.allCases
            .compactMap { stroke in
                guard let count = grouped[stroke]?.count, count > 0 else { return nil }
                return (stroke, count)
            }
    }

    private var total: Int {
        laps.count
    }

    var body: some View {
        if strokeCounts.count > 1 {
            VStack(alignment: .leading, spacing: 8) {
                Text("Stroke Distribution")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        ForEach(strokeCounts, id: \.0) { stroke, count in
                            let width = geometry.size.width * (Double(count) / Double(total))
                            Rectangle()
                                .fill(strokeColor(for: stroke))
                                .frame(width: max(width, 4))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .frame(height: 10)

                HStack(spacing: 12) {
                    ForEach(strokeCounts, id: \.0) { stroke, count in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(strokeColor(for: stroke))
                                .frame(width: 8, height: 8)
                            Text("\(stroke.abbreviation) \(count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func strokeColor(for stroke: SwimmingStroke) -> Color {
        switch stroke {
        case .freestyle: return .blue
        case .backstroke: return .green
        case .breaststroke: return .orange
        case .butterfly: return .red
        case .individual: return .purple
        case .mixed: return .gray
        }
    }
}

// MARK: - Lap Row

struct LapRow: View {
    let lap: SwimmingLap

    var body: some View {
        HStack {
            Text("Lap \(lap.orderIndex + 1)")
                .font(.subheadline)

            Text(lap.stroke.abbreviation)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AppColors.elevatedSurface)
                .clipShape(Capsule())

            Spacer()

            Text("\(lap.strokeCount) strokes")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(lap.formattedPace)
                .font(.subheadline.bold())
                .foregroundStyle(AppColors.primary)
                .frame(width: 70, alignment: .trailing)
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }
}
