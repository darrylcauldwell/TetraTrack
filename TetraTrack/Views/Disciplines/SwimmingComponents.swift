//
//  SwimmingComponents.swift
//  TetraTrack
//
//  Swimming subviews extracted from SwimmingView
//

import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import HealthKit
import os

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

    private let defaults = UserDefaults.standard

    // 3-minute test personal best (distance in meters)
    var pb3MinDistance: Double {
        get { defaults.double(forKey: "swim_pb_3min_distance") }
        set { defaults.set(newValue, forKey: "swim_pb_3min_distance") }
    }

    var pb3MinTime: TimeInterval {
        get { defaults.double(forKey: "swim_pb_3min_time") }
        set { defaults.set(newValue, forKey: "swim_pb_3min_time") }
    }

    // CSS (Critical Swim Speed) threshold pace
    var thresholdPace: TimeInterval {
        get { defaults.double(forKey: "swim_threshold_pace") }
        set { defaults.set(newValue, forKey: "swim_threshold_pace") }
    }

    var thresholdPaceDate: Date? {
        get { defaults.object(forKey: "swim_threshold_pace_date") as? Date }
        set { defaults.set(newValue, forKey: "swim_threshold_pace_date") }
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
}

// MARK: - Swimming Live View

struct SwimmingLiveView: View {
    @Bindable var session: SwimmingSession
    let poolLength: Double
    let isThreeMinuteTest: Bool
    let testDuration: TimeInterval  // Configurable duration for timed tests
    var freeSwimTargetDuration: TimeInterval? = nil  // Optional target for free swim
    var intervalSettings: SwimmingIntervalSettings? = nil
    let onEnd: () -> Void
    var onDiscard: (() -> Void)? = nil

    @State private var elapsedTime: TimeInterval = 0
    @State private var lengthCount: Int = 0
    @State private var timer: Timer?
    @State private var isRunning = false
    @State private var hasStarted = false
    @State private var testComplete = false
    @State private var isArmedForSubmersion = false
    @State private var sessionStartDate: Date?  // Wall-clock start for accurate timing
    @State private var additionalMeters: Int = 0  // Extra meters from partial length

    // Watch stroke tracking
    @State private var strokeCount: Int = 0
    @State private var strokeRate: Double = 0.0
    @State private var lengthStrokes: [Int] = []  // Strokes per length for SWOLF
    @State private var lengthTimes: [TimeInterval] = []  // Time per length for SWOLF
    @State private var lastLengthTime: TimeInterval = 0
    @State private var lastLengthStrokeCount: Int = 0

    // Heart rate tracking
    @State private var currentHeartRate: Int = 0
    @State private var maxHeartRateReading: Int = 0
    @State private var heartRateReadings: [Int] = []
    @State private var heartRateSamples: [HeartRateSample] = []

    // Open water GPS tracking
    @State private var locationManager: LocationManager?
    @State private var gpsDistance: Double = 0
    @State private var lastGPSLocation: CLLocation?
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var locationPoints: [SwimmingLocationPoint] = []

    // Stroke type tracking
    @State private var lengthStrokeTypes: [SwimmingStroke] = []
    @State private var showStrokePicker: Bool = false
    @State private var strokePickerTimer: Timer?

    // Auto lap detection
    @State private var lastSubmersionState: Bool = false
    @State private var showAutoLapHint: Bool = false
    @State private var autoLapDismissTimer: Timer?

    // Interval tracking
    @State private var currentIntervalIndex: Int = 0
    @State private var isResting: Bool = false
    @State private var restTimeRemaining: TimeInterval = 0
    @State private var restTimer: Timer?
    @State private var intervalStartTime: TimeInterval = 0 // elapsed time when interval started
    @State private var intervalStartLengthCount: Int = 0
    @State private var intervalData: [(distance: Double, duration: TimeInterval, strokes: Int)] = []

    // Watch status update timer
    @State private var watchUpdateTimer: Timer?

    private let watchManager = WatchConnectivityManager.shared
    private let sensorAnalyzer = WatchSensorAnalyzer.shared
    private let liveWorkoutManager = LiveWorkoutManager.shared

    private var isOpenWater: Bool {
        session.poolMode == .openWater
    }

    private var isIntervalMode: Bool {
        intervalSettings != nil
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
        return max(0, target - elapsedTime)
    }

    private var distanceInCurrentInterval: Double {
        Double(lengthCount - intervalStartLengthCount) * poolLength
    }

    private var intervalTargetReached: Bool {
        guard let settings = intervalSettings else { return false }
        return distanceInCurrentInterval >= settings.targetDistance
    }

    private var allIntervalsComplete: Bool {
        guard let settings = intervalSettings else { return false }
        return currentIntervalIndex >= settings.numberOfIntervals
    }

    // Calculate SWOLF score (strokes + time per length)
    private var averageSWOLF: Double {
        guard !lengthStrokes.isEmpty, !lengthTimes.isEmpty else { return 0 }
        // Only include lengths with actual stroke data for SWOLF
        let swolfScores = zip(lengthStrokes, lengthTimes)
            .filter { $0.0 > 0 && $0.1 > 0 }
            .map { Double($0) + $1 }
        guard !swolfScores.isEmpty else { return 0 }
        return swolfScores.reduce(0, +) / Double(swolfScores.count)
    }

    private var strokesPerLength: Double {
        guard !lengthStrokes.isEmpty else { return 0 }
        return Double(lengthStrokes.reduce(0, +)) / Double(lengthStrokes.count)
    }

    private var totalDistance: Double {
        if isOpenWater {
            return gpsDistance
        }
        return Double(lengthCount) * poolLength + Double(additionalMeters)
    }

    private var timeRemaining: TimeInterval {
        max(0, testDuration - elapsedTime)
    }

    private var currentPace: TimeInterval {
        guard totalDistance > 0, elapsedTime > 0 else { return 0 }
        return elapsedTime / (totalDistance / 100) // seconds per 100m
    }

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
        .onAppear {
            setupMotionCallbacks()
        }
        .onDisappear {
            timer?.invalidate()
            restTimer?.invalidate()
            strokePickerTimer?.invalidate()
        }
        .overlay(alignment: .top) {
            VoiceNoteRecordingOverlay()
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
                Button(action: cancelSession) {
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

            // Live heart rate (when receiving data)
            if currentHeartRate > 0 && hasStarted {
                HeartRateDisplayView(
                    heartRate: currentHeartRate,
                    zone: HeartRateZone.zone(for: currentHeartRate, maxHR: estimatedMaxHR),
                    averageHeartRate: averageHeartRate > 0 ? averageHeartRate : nil,
                    maxHeartRate: maxHeartRateReading > 0 ? maxHeartRateReading : nil
                )
                .padding()
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
            if hasStarted && (sensorAnalyzer.isSubmerged || sensorAnalyzer.oxygenSaturation > 0 || sensorAnalyzer.totalSubmergedTime > 0) {
                SwimmingSensorMetricsView(
                    isSubmerged: sensorAnalyzer.isSubmerged,
                    submergedTime: sensorAnalyzer.totalSubmergedTime,
                    submersionCount: sensorAnalyzer.submersionCount,
                    spo2: sensorAnalyzer.oxygenSaturation,
                    minSpo2: sensorAnalyzer.minSpO2,
                    recoveryQuality: sensorAnalyzer.recoveryQuality
                )
            }

            // Open water map or lap button
            if isOpenWater {
                if hasStarted {
                    SwimmingOpenWaterMapView(
                        coordinates: routeCoordinates,
                        distance: gpsDistance
                    )
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

                Text(formatTime(elapsedTime))
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
            Text(String(format: "%.0f", gpsDistance))
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
            if !hasStarted {
                // Start button
                Button(action: startSession) {
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
                Button(action: endSession) {
                    Label("Save & Finish", systemImage: "checkmark.circle.fill")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: min(geometry.size.width - 80, 300))
                        .padding(.vertical, 16)
                        .background(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            } else {
                // Stop button (for training or early end)
                Button(action: {
                    testComplete = true
                    stopTimer()
                    restTimer?.invalidate()
                    restTimer = nil
                    isResting = false
                }) {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(.red)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal)
    }

    private var averageHeartRate: Int {
        guard !heartRateReadings.isEmpty else { return 0 }
        return heartRateReadings.reduce(0, +) / heartRateReadings.count
    }

    private var heartRateZone: Int {
        guard currentHeartRate > 0 else { return 1 }
        if currentHeartRate < 100 { return 1 }
        if currentHeartRate < 120 { return 2 }
        if currentHeartRate < 150 { return 3 }
        if currentHeartRate < 170 { return 4 }
        return 5
    }

    private var estimatedMaxHR: Int { 190 }

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
        guard elapsedTime > 0, totalDistance > 0 else { return 0 }
        return (totalDistance / elapsedTime) * testDuration
    }

    private func startSession() {
        hasStarted = true
        lastLengthTime = 0
        lastLengthStrokeCount = 0
        UIApplication.shared.isIdleTimerDisabled = true

        // Start HKWorkoutSession for Watch mirroring
        // Use pool or open water swimming based on mode
        Task {
            do {
                let activityType: HKWorkoutActivityType = isOpenWater ? .swimming : .swimming
                try await liveWorkoutManager.startWorkout(activityType: activityType)
                Log.tracking.info("Started HKWorkoutSession for swimming with Watch mirroring")
            } catch {
                Log.tracking.error("Failed to start HKWorkoutSession for swimming: \(error)")
            }
        }

        // Start GPS for open water
        if isOpenWater {
            startLocationTracking()
        }

        // Start Watch motion tracking (needed for submersion detection)
        startMotionTracking()

        if isOpenWater {
            // Arm session: sensors + GPS active, timer waits for submersion
            isArmedForSubmersion = true
            // Edge case: already submerged when Start tapped
            if sensorAnalyzer.isSubmerged {
                triggerSubmersionStart()
            }
        } else {
            // Pool mode: start immediately
            isRunning = true
            startTimer()
        }
    }

    private func triggerSubmersionStart() {
        guard isArmedForSubmersion else { return }
        isArmedForSubmersion = false
        isRunning = true
        startTimer()

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Update Watch state to active tracking
        watchManager.sendCommand(.startRide)
    }

    private func cancelArmedState() {
        isArmedForSubmersion = false
        hasStarted = false
        isRunning = false
        stopMotionTracking()
        if isOpenWater {
            stopLocationTracking()
        }
    }

    private func startTimer() {
        sessionStartDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard let startDate = sessionStartDate else { return }
            let previousElapsed = elapsedTime
            elapsedTime = Date().timeIntervalSince(startDate)

            // Update stroke data from Watch
            strokeCount = watchManager.strokeCount
            strokeRate = watchManager.strokeRate

            if isThreeMinuteTest {
                // Timed test: minute marks, 10s warning, completion
                let remaining = testDuration - elapsedTime
                let previousRemaining = testDuration - previousElapsed

                // Minute milestone: detect crossing a 60-second boundary
                if Int(elapsedTime) / 60 > Int(previousElapsed) / 60 && remaining > 0 {
                    watchManager.sendCommand(.hapticMilestone)
                }
                // 10-second warning
                if previousRemaining > 10 && remaining <= 10 {
                    watchManager.sendCommand(.hapticUrgent)
                }
                if elapsedTime >= testDuration {
                    testComplete = true
                    stopTimer()
                    watchManager.sendCommand(.hapticComplete)
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } else if let target = freeSwimTargetDuration {
                // Free swim with target duration: 5-min marks, 1-min warning, completion
                let remaining = target - elapsedTime
                let previousRemaining = target - previousElapsed

                // 5-minute milestone: detect crossing a 300-second boundary
                if Int(elapsedTime) / 300 > Int(previousElapsed) / 300 && remaining > 0 {
                    watchManager.sendCommand(.hapticMilestone)
                }
                // 1-minute warning
                if previousRemaining > 60 && remaining <= 60 {
                    watchManager.sendCommand(.hapticUrgent)
                }
                if elapsedTime >= target {
                    testComplete = true
                    stopTimer()
                    watchManager.sendCommand(.hapticComplete)
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } else if !isIntervalMode {
                // Free swim without target: milestone every 10 minutes
                if Int(elapsedTime) / 600 > Int(previousElapsed) / 600 {
                    watchManager.sendCommand(.hapticMilestone)
                }
            }
        }
    }

    private func stopTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func recordLength() {
        guard !isResting else { return }

        if !hasStarted {
            startSession()
        }

        // Calculate strokes and time for this length (for SWOLF)
        // Always append to both arrays to keep indices aligned
        let lengthTime = elapsedTime - lastLengthTime
        let lengthStrokeCount = max(0, strokeCount - lastLengthStrokeCount)

        lengthTimes.append(lengthTime)
        lengthStrokes.append(lengthStrokeCount)

        // Update tracking for next length
        lastLengthTime = elapsedTime
        lastLengthStrokeCount = strokeCount

        lengthCount += 1

        // Show stroke picker briefly
        showStrokeQuickPicker()

        // Check interval target
        if isIntervalMode && intervalTargetReached {
            completeCurrentInterval()
        }
    }

    private func showStrokeQuickPicker() {
        // Default to freestyle
        lengthStrokeTypes.append(.freestyle)

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
        if !lengthStrokeTypes.isEmpty {
            lengthStrokeTypes[lengthStrokeTypes.count - 1] = stroke
        }
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

    // MARK: - Interval Management

    private func completeCurrentInterval() {
        guard let settings = intervalSettings else { return }

        // Record interval data
        let intervalDuration = elapsedTime - intervalStartTime
        let intervalStrokes = strokeCount - (intervalData.isEmpty ? 0 :
            intervalData.reduce(0) { $0 + $1.strokes })
        intervalData.append((
            distance: distanceInCurrentInterval,
            duration: intervalDuration,
            strokes: intervalStrokes
        ))

        currentIntervalIndex += 1

        // Check if all intervals complete
        if allIntervalsComplete {
            testComplete = true
            stopTimer()
            watchManager.sendCommand(.hapticComplete)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            return
        }

        // Start rest period
        isResting = true
        restTimeRemaining = settings.restDuration

        // Haptic for rest start (Watch + iPhone)
        watchManager.sendCommand(.hapticRestStart)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            restTimeRemaining -= 1

            // Watch haptic countdown at 5 and 3 seconds
            if restTimeRemaining == 5 || restTimeRemaining == 3 {
                watchManager.sendCommand(.hapticUrgent)
                let gen = UIImpactFeedbackGenerator(style: .medium)
                gen.impactOccurred()
            }

            if restTimeRemaining <= 0 {
                endRestPeriod()
            }
        }
    }

    private func endRestPeriod() {
        restTimer?.invalidate()
        restTimer = nil
        isResting = false

        // Reset interval tracking
        intervalStartTime = elapsedTime
        intervalStartLengthCount = lengthCount

        // Haptic for go (Watch + iPhone)
        watchManager.sendCommand(.hapticRestEnd)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func endSession() {
        stopTimer()
        restTimer?.invalidate()
        restTimer = nil
        strokePickerTimer?.invalidate()
        strokePickerTimer = nil
        stopMotionTracking()
        if isOpenWater {
            stopLocationTracking()
        }
        UIApplication.shared.isIdleTimerDisabled = false

        // End HKWorkoutSession - this stops Watch mirroring
        Task {
            await liveWorkoutManager.endWorkout()
            Log.tracking.info("Ended HKWorkoutSession for swimming")
        }

        session.totalDistance = totalDistance
        session.totalDuration = elapsedTime
        session.totalStrokes = strokeCount
        session.endDate = Date()

        // Create SwimmingLap objects from tracked data (pool mode)
        if !isOpenWater {
            let lapCount = min(lengthTimes.count, lengthCount)
            if lapCount > 0 {
                if session.laps == nil { session.laps = [] }
                for i in 0..<lapCount {
                    let lap = SwimmingLap(orderIndex: i, distance: poolLength)
                    lap.duration = lengthTimes[i]
                    if i < lengthStrokes.count {
                        lap.strokeCount = lengthStrokes[i]
                    }
                    if i < lengthStrokeTypes.count {
                        lap.stroke = lengthStrokeTypes[i]
                    }
                    // Calculate start/end times
                    let precedingTime = lengthTimes.prefix(i).reduce(0, +)
                    lap.startTime = session.startDate.addingTimeInterval(precedingTime)
                    lap.endTime = lap.startTime.addingTimeInterval(lengthTimes[i])
                    session.laps?.append(lap)
                }
            }
        }

        // Create SwimmingInterval objects
        if isIntervalMode, let settings = intervalSettings, !intervalData.isEmpty {
            if session.intervals == nil { session.intervals = [] }
            for (index, data) in intervalData.enumerated() {
                let interval = SwimmingInterval(
                    orderIndex: index,
                    name: "Interval \(index + 1)",
                    targetDistance: settings.targetDistance,
                    targetPace: settings.targetPace,
                    restDuration: settings.restDuration
                )
                interval.actualDistance = data.distance
                interval.actualDuration = data.duration
                interval.actualStrokes = data.strokes
                interval.isCompleted = true
                session.intervals?.append(interval)
            }
        }

        // Save location points (open water)
        if isOpenWater && !locationPoints.isEmpty {
            if session.locationPoints == nil { session.locationPoints = [] }
            for point in locationPoints {
                session.locationPoints?.append(point)
            }
        }

        // Save heart rate data
        if !heartRateReadings.isEmpty {
            session.averageHeartRate = heartRateReadings.reduce(0, +) / heartRateReadings.count
            session.maxHeartRate = maxHeartRateReading
            session.minHeartRate = heartRateReadings.min() ?? 0
            session.heartRateSamples = heartRateSamples
        }

        // Save enhanced sensor data from WatchSensorAnalyzer
        let swimmingSummary = sensorAnalyzer.getSwimmingSummary()
        if swimmingSummary.totalSubmergedTime > 0 {
            session.totalSubmergedTime = swimmingSummary.totalSubmergedTime
        }
        if swimmingSummary.submersionCount > 0 {
            session.submersionCount = swimmingSummary.submersionCount
        }
        if swimmingSummary.currentSpO2 > 0 {
            session.averageSpO2 = swimmingSummary.currentSpO2
        }
        if swimmingSummary.minSpO2 < 100 {
            session.minSpO2 = swimmingSummary.minSpO2
        }
        session.recoveryQuality = swimmingSummary.recoveryQuality
        if sensorAnalyzer.breathingRate > 0 {
            session.averageBreathingRate = sensorAnalyzer.breathingRate
        }

        onEnd()
    }

    private func cancelSession() {
        stopTimer()
        restTimer?.invalidate()
        restTimer = nil
        strokePickerTimer?.invalidate()
        strokePickerTimer = nil
        stopMotionTracking()
        if isOpenWater {
            stopLocationTracking()
        }
        UIApplication.shared.isIdleTimerDisabled = false

        // Discard HKWorkoutSession (don't save)
        Task {
            await liveWorkoutManager.discardWorkout()
            Log.tracking.info("Discarded HKWorkoutSession for swimming")
        }

        // Use onDiscard if provided to properly delete session, otherwise just close
        if let onDiscard = onDiscard {
            onDiscard()
        } else {
            onEnd()
        }
    }

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

    // MARK: - Location Tracking (Open Water)

    private func startLocationTracking() {
        let locManager = LocationManager()
        self.locationManager = locManager

        locManager.onLocationUpdate = { [self] location in
            let point = SwimmingLocationPoint(from: location)
            self.locationPoints.append(point)
            self.routeCoordinates.append(location.coordinate)

            // Calculate GPS distance
            if let lastLocation = self.lastGPSLocation {
                let delta = location.distance(from: lastLocation)
                // Filter out GPS noise (only count movements > 1m)
                if delta > 1.0 && delta < 100.0 {
                    self.gpsDistance += delta
                }
            }
            self.lastGPSLocation = location
        }

        Task {
            await locManager.startTracking()
        }
    }

    private func stopLocationTracking() {
        locationManager?.onLocationUpdate = nil
        locationManager?.stopTracking()
        locationManager = nil
    }

    // MARK: - Watch Motion Tracking

    private func setupMotionCallbacks() {
        watchManager.onMotionUpdate = { mode, _, strokes, rate, _, _, _ in
            if mode == .swimming {
                DispatchQueue.main.async {
                    if let strokes = strokes {
                        self.strokeCount = strokes
                    }
                    if let rate = rate {
                        self.strokeRate = rate
                    }
                }
            }
        }

        watchManager.onStrokeDetected = {
            // Haptic feedback on stroke detected
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }

        // Submersion detection: armed start trigger + auto-lap hints
        watchManager.onEnhancedSensorUpdate = { [self] in
            DispatchQueue.main.async {
                let currentlySubmerged = self.sensorAnalyzer.isSubmerged

                // Submersion-triggered start for open water
                if self.isArmedForSubmersion && currentlySubmerged {
                    self.triggerSubmersionStart()
                }

                // Detect surface -> resubmerge pattern (wall turn) for auto-lap
                if !self.lastSubmersionState && currentlySubmerged && self.hasStarted && self.isRunning {
                    // Only show hint if we have at least 1 length already
                    // and not already showing a hint
                    if self.lengthCount > 0 && !self.showAutoLapHint && !self.showStrokePicker {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.showAutoLapHint = true
                        }
                        // Auto-dismiss after 5 seconds
                        self.autoLapDismissTimer?.invalidate()
                        self.autoLapDismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                            self.dismissAutoLapHint()
                        }
                    }
                }
                self.lastSubmersionState = currentlySubmerged
            }
        }

        // Heart rate callback
        watchManager.onHeartRateReceived = { bpm in
            DispatchQueue.main.async {
                self.currentHeartRate = bpm
                self.heartRateReadings.append(bpm)
                if bpm > self.maxHeartRateReading {
                    self.maxHeartRateReading = bpm
                }
                // Collect samples for timeline
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
        watchManager.resetMotionMetrics()
        watchManager.startMotionTracking(mode: .swimming)
        sensorAnalyzer.startSession()
        startWatchStatusUpdates()
    }

    private func stopMotionTracking() {
        watchManager.stopMotionTracking()
        watchManager.onMotionUpdate = nil
        watchManager.onHeartRateReceived = nil
        watchManager.onStrokeDetected = nil
        watchManager.onEnhancedSensorUpdate = nil
        sensorAnalyzer.stopSession()
        autoLapDismissTimer?.invalidate()
        stopWatchStatusUpdates()

        // Send idle state to Watch
        watchManager.sendStatusUpdate(
            rideState: .idle,
            duration: 0,
            distance: 0,
            speed: 0,
            gait: "Swimming",
            heartRate: nil,
            heartRateZone: nil,
            averageHeartRate: nil,
            maxHeartRate: nil,
            horseName: nil,
            rideType: "Swimming"
        )
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
        let sessionName: String
        if isThreeMinuteTest {
            sessionName = "Timed Test"
        } else if isIntervalMode {
            sessionName = "Intervals"
        } else {
            sessionName = "Training"
        }
        watchManager.sendStatusUpdate(
            rideState: isArmedForSubmersion ? .paused : .tracking,
            duration: elapsedTime,
            distance: totalDistance,
            speed: totalDistance > 0 && elapsedTime > 0 ? totalDistance / elapsedTime : 0,
            gait: isArmedForSubmersion ? "Awaiting Entry" : "Swimming",
            heartRate: currentHeartRate > 0 ? currentHeartRate : nil,
            heartRateZone: currentHeartRate > 0 ? heartRateZone : nil,
            averageHeartRate: averageHeartRate > 0 ? averageHeartRate : nil,
            maxHeartRate: maxHeartRateReading > 0 ? maxHeartRateReading : nil,
            horseName: nil,
            rideType: sessionName
        )
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
                        SwimmingOpenWaterRouteView(session: session)
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
                        Label("Swim Insights", systemImage: "chart.bar.xaxis")
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
