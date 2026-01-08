//
//  SwimmingComponents.swift
//  TrackRide
//
//  Swimming subviews extracted from SwimmingView
//

import SwiftUI
import SwiftData

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
            .background(Color(.secondarySystemBackground))
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
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Swimming Settings View

struct SwimmingSettingsView: View {
    @Binding var poolLength: Double
    @Binding var poolModeRaw: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Pool Type", selection: $poolModeRaw) {
                        ForEach(SwimmingPoolMode.allCases, id: \.rawValue) { mode in
                            Text(mode.rawValue).tag(mode.rawValue)
                        }
                    }

                    Picker("Pool Length", selection: $poolLength) {
                        Text("20m").tag(20.0)
                        Text("25m").tag(25.0)
                        Text("33.3m").tag(33.3)
                        Text("50m").tag(50.0)
                    }
                } header: {
                    Text("Pool Settings")
                }
            }
            .navigationTitle("Swimming Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
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

    mutating func updatePersonalBest(distance: Double, time: TimeInterval) {
        // For 3-minute test, better = more distance
        if distance > pb3MinDistance {
            pb3MinDistance = distance
            pb3MinTime = time
        }
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
}

// MARK: - Swimming Live View

struct SwimmingLiveView: View {
    @Bindable var session: SwimmingSession
    let poolLength: Double
    let isThreeMinuteTest: Bool
    let testDuration: TimeInterval  // Configurable duration for timed tests
    let onEnd: () -> Void

    @State private var elapsedTime: TimeInterval = 0
    @State private var lengthCount: Int = 0
    @State private var timer: Timer?
    @State private var isRunning = false
    @State private var hasStarted = false
    @State private var testComplete = false

    // Watch stroke tracking
    @State private var strokeCount: Int = 0
    @State private var strokeRate: Double = 0.0
    @State private var lengthStrokes: [Int] = []  // Strokes per length for SWOLF
    @State private var lengthTimes: [TimeInterval] = []  // Time per length for SWOLF
    @State private var lastLengthTime: TimeInterval = 0
    @State private var lastLengthStrokeCount: Int = 0

    // Watch status update timer
    @State private var watchUpdateTimer: Timer?

    private let watchManager = WatchConnectivityManager.shared

    private var personalBests: SwimmingPersonalBests { SwimmingPersonalBests.shared }

    // Calculate SWOLF score (strokes + time per length)
    private var averageSWOLF: Double {
        guard !lengthStrokes.isEmpty, !lengthTimes.isEmpty else { return 0 }
        let swolfScores = zip(lengthStrokes, lengthTimes).map { Double($0) + $1 }
        return swolfScores.reduce(0, +) / Double(swolfScores.count)
    }

    private var strokesPerLength: Double {
        guard !lengthStrokes.isEmpty else { return 0 }
        return Double(lengthStrokes.reduce(0, +)) / Double(lengthStrokes.count)
    }

    private var totalDistance: Double {
        Double(lengthCount) * poolLength
    }

    private var timeRemaining: TimeInterval {
        max(0, testDuration - elapsedTime)
    }

    private var currentPace: TimeInterval {
        guard totalDistance > 0, elapsedTime > 0 else { return 0 }
        return elapsedTime / (totalDistance / 100) // seconds per 100m
    }

    var body: some View {
        ZStack {
            // Background
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

            VStack(spacing: 24) {
                // Header with close button and Watch status
                HStack {
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

                    // Voice notes button - only show when paused
                    if !isRunning {
                        VoiceNoteToolbarButton { note in
                            let service = VoiceNotesService.shared
                            session.notes = service.appendNote(note, to: session.notes)
                        }
                    }

                    Button(action: cancelSession) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                Spacer()

                if isThreeMinuteTest {
                    // Timer display - countdown for 3-min test
                    VStack(spacing: 8) {
                        Text(testComplete ? "Time!" : (hasStarted ? "Time Remaining" : "3-Minute Test"))
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text(formatTime(hasStarted ? timeRemaining : testDuration))
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(timeRemaining < 30 && hasStarted ? .red : .primary)
                    }

                    // Show PB before starting
                    if !hasStarted {
                        HStack {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(.yellow)
                            Text("Personal Best:")
                                .font(.headline)
                            Text(personalBests.pb3MinDistance > 0 ? personalBests.formattedPBDistance() : "No PB yet")
                                .font(.headline.bold())
                                .foregroundStyle(personalBests.pb3MinDistance > 0 ? .orange : .secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    // Count up for training
                    VStack(spacing: 8) {
                        Text("Duration")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text(formatTime(elapsedTime))
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                }

                // Length count and distance
                VStack(spacing: 16) {
                    // Lengths and Distance
                    HStack(spacing: 40) {
                        VStack(spacing: 4) {
                            Text("Lengths")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(lengthCount)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.blue)
                        }

                        VStack(spacing: 4) {
                            Text("Distance")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.0fm", totalDistance))
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.blue)
                        }
                    }

                    // Watch stroke tracking (when connected)
                    if watchManager.isReachable && hasStarted {
                        HStack(spacing: 32) {
                            VStack(spacing: 4) {
                                Text("Strokes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(strokeCount)")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(.cyan)
                            }

                            VStack(spacing: 4) {
                                Text("Rate")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.0f/min", strokeRate))
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(.cyan)
                            }

                            if averageSWOLF > 0 {
                                VStack(spacing: 4) {
                                    Text("SWOLF")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(String(format: "%.0f", averageSWOLF))
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundStyle(swolfColor)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // PB comparison section (only for 3-minute test)
                    if isThreeMinuteTest && hasStarted {
                        VStack(spacing: 12) {
                            // Pace indicator with color
                            if totalDistance > 0 {
                                HStack(spacing: 20) {
                                    // Current pace
                                    VStack(spacing: 4) {
                                        Text("Pace")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(formatPace(currentPace))
                                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                                            .monospacedDigit()
                                    }

                                    // vs PB indicator
                                    if personalBests.pb3MinDistance > 0 {
                                        VStack(spacing: 4) {
                                            Text("vs PB")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            HStack(spacing: 4) {
                                                Image(systemName: paceStatusIcon)
                                                Text(paceStatusText)
                                            }
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundStyle(paceColor)
                                        }
                                    }

                                    // Projected distance
                                    VStack(spacing: 4) {
                                        Text("Projected")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(String(format: "%.0fm", projectedDistance))
                                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                                            .monospacedDigit()
                                            .foregroundStyle(projectedDistanceColor)
                                    }
                                }
                            }

                            // PB info bar
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .foregroundStyle(.yellow)
                                Text("PB: \(personalBests.pb3MinDistance > 0 ? personalBests.formattedPBDistance() : "--")")
                                    .font(.subheadline)
                                Spacer()
                                if personalBests.pb3MinDistance > 0 {
                                    if totalDistance > personalBests.pb3MinDistance {
                                        HStack(spacing: 4) {
                                            Image(systemName: "star.fill")
                                            Text("New PB!")
                                        }
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.yellow)
                                    } else if projectedDistance > personalBests.pb3MinDistance && elapsedTime > 30 {
                                        Text("On track for PB!")
                                            .font(.caption.bold())
                                            .foregroundStyle(.green)
                                    }
                                } else {
                                    Text("Set your first PB!")
                                        .font(.caption.bold())
                                        .foregroundStyle(.orange)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer()

                // Big lap button
                if !testComplete {
                    VStack(spacing: 12) {
                        Button(action: recordLength) {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 80))
                                Text("Tap Each Length")
                                    .font(.headline)
                            }
                            .foregroundStyle(.white)
                            .frame(width: 200, height: 200)
                            .background(
                                Circle()
                                    .fill(.blue)
                                    .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
                            )
                        }
                        .sensoryFeedback(.impact(weight: .heavy), trigger: lengthCount)
                        .disabled(!isRunning && hasStarted)

                        Text("\(Int(poolLength))m pool")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Control buttons
                if !hasStarted {
                    // Start button
                    Button(action: startSession) {
                        Label("Start", systemImage: "play.fill")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 40)
                } else if testComplete {
                    // Finish button
                    Button(action: endSession) {
                        Label("Save & Finish", systemImage: "checkmark.circle.fill")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 40)
                } else {
                    // Stop button (for training or early end)
                    Button(action: { testComplete = true; stopTimer() }) {
                        Label("Stop", systemImage: "stop.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(.red)
                            .clipShape(Capsule())
                    }
                }

                Spacer()
            }
            .padding()
        }
        .onAppear {
            setupMotionCallbacks()
        }
        .onDisappear {
            timer?.invalidate()
            stopMotionTracking()
        }
        .overlay(alignment: .top) {
            VoiceNoteRecordingOverlay()
        }
    }

    // SWOLF color indicator - lower is better
    private var swolfColor: Color {
        if averageSWOLF < 40 { return .green }
        if averageSWOLF < 55 { return .yellow }
        return .orange
    }

    // Projected distance if current pace maintained for full 3 minutes
    private var projectedDistance: Double {
        guard elapsedTime > 0, totalDistance > 0 else { return 0 }
        return (totalDistance / elapsedTime) * testDuration
    }

    private var projectedDistanceColor: Color {
        guard personalBests.pb3MinDistance > 0 else { return .primary }
        if projectedDistance > personalBests.pb3MinDistance + 10 { return .green }
        if projectedDistance < personalBests.pb3MinDistance - 10 { return .red }
        return .yellow
    }

    private var paceColor: Color {
        guard personalBests.pb3MinDistance > 0, elapsedTime > 30 else { return .primary }
        if projectedDistance > personalBests.pb3MinDistance + 10 { return .green }
        if projectedDistance < personalBests.pb3MinDistance - 10 { return .red }
        return .yellow
    }

    private var paceStatusIcon: String {
        guard personalBests.pb3MinDistance > 0, elapsedTime > 30 else { return "equal.circle.fill" }
        if projectedDistance > personalBests.pb3MinDistance + 10 { return "arrow.up.circle.fill" }
        if projectedDistance < personalBests.pb3MinDistance - 10 { return "arrow.down.circle.fill" }
        return "equal.circle.fill"
    }

    private var paceStatusText: String {
        guard personalBests.pb3MinDistance > 0, elapsedTime > 30 else { return "---" }
        let diff = projectedDistance - personalBests.pb3MinDistance
        if abs(diff) < 5 { return "On PB" }
        let sign = diff > 0 ? "+" : ""
        return "\(sign)\(Int(diff))m"
    }

    private func startSession() {
        hasStarted = true
        isRunning = true
        lastLengthTime = 0
        lastLengthStrokeCount = 0

        // Start Watch motion tracking for swimming
        startMotionTracking()
        startTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1

            // Update stroke data from Watch
            strokeCount = watchManager.strokeCount
            strokeRate = watchManager.strokeRate

            // Check for 3-minute test completion
            if isThreeMinuteTest && elapsedTime >= testDuration {
                testComplete = true
                stopTimer()
                // Haptic and sound for completion
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }

    private func stopTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func recordLength() {
        if !hasStarted {
            startSession()
        }

        // Calculate strokes and time for this length (for SWOLF)
        let lengthTime = elapsedTime - lastLengthTime
        let lengthStrokeCount = strokeCount - lastLengthStrokeCount

        if lengthTime > 0 {
            lengthTimes.append(lengthTime)
        }
        if lengthStrokeCount > 0 {
            lengthStrokes.append(lengthStrokeCount)
        }

        // Update tracking for next length
        lastLengthTime = elapsedTime
        lastLengthStrokeCount = strokeCount

        lengthCount += 1
    }

    private func endSession() {
        stopTimer()
        stopMotionTracking()

        session.totalDistance = totalDistance
        session.totalDuration = elapsedTime
        session.totalStrokes = strokeCount
        onEnd()
    }

    private func cancelSession() {
        stopTimer()
        stopMotionTracking()
        // Don't save - just close
        onEnd()
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
        return String(format: "%d:%02d /100m", mins, secs)
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
    }

    private func startMotionTracking() {
        watchManager.resetMotionMetrics()
        watchManager.startMotionTracking(mode: .swimming)
        startWatchStatusUpdates()
    }

    private func stopMotionTracking() {
        watchManager.stopMotionTracking()
        watchManager.onMotionUpdate = nil
        watchManager.onStrokeDetected = nil
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
        let sessionName = isThreeMinuteTest ? "3-Min Test" : "Training"
        watchManager.sendStatusUpdate(
            rideState: .tracking,
            duration: elapsedTime,
            distance: totalDistance,
            speed: totalDistance > 0 && elapsedTime > 0 ? totalDistance / elapsedTime : 0,
            gait: "Swimming",
            heartRate: nil,
            heartRateZone: nil,
            averageHeartRate: nil,
            maxHeartRate: nil,
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
                            .font(.system(size: 60, weight: .bold))
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
                    }
                    .padding(.horizontal)

                    // Lap breakdown
                    if !session.laps.isEmpty {
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
                    .background(Color(.secondarySystemBackground))
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
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle(session.name.isEmpty ? "Session" : session.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                .background(Color(.tertiarySystemBackground))
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
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }
}
