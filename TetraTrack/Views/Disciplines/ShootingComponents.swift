//
//  ShootingComponents.swift
//  TetraTrack
//
//  Shooting discipline subviews extracted from ShootingView
//

import SwiftUI
import SwiftData
import WidgetKit

// MARK: - Shooting Watch Status Card

/// Shows Apple Watch connection state with guidance for shooting sessions.
struct ShootingWatchStatusCard: View {
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
                    Text("Enhanced shooting metrics from your watch:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    shootingMetricRow(icon: "scope", text: "Hold steadiness & drift analysis", color: .cyan)
                    shootingMetricRow(icon: "waveform.path", text: "Shot detection & cycle timing", color: .orange)
                    shootingMetricRow(icon: "hand.raised.fingers.spread", text: "Tremor intensity tracking", color: .purple)
                    shootingMetricRow(icon: "heart.fill", text: "Heart rate & composure", color: .red)
                }
            } else if isAppNotInstalled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Install TetraTrack on your Apple Watch to unlock shot detection and Session Insights.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Open the Watch app on your iPhone to install.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Open TetraTrack on your Apple Watch before starting for heart rate and shot detection.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Once connected you'll get:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    shootingMetricRow(icon: "scope", text: "Hold steadiness & drift analysis", color: .cyan)
                    shootingMetricRow(icon: "waveform.path", text: "Shot detection & cycle timing", color: .orange)
                    shootingMetricRow(icon: "hand.raised.fingers.spread", text: "Tremor intensity tracking", color: .purple)
                    shootingMetricRow(icon: "heart.fill", text: "Heart rate & composure", color: .red)
                }
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func shootingMetricRow(icon: String, text: String, color: Color) -> some View {
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

// MARK: - Shoot Type Button

struct ShootTypeButton: View {
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

// MARK: - Shoot Type Card (Grid Style)

struct ShootTypeCard: View {
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

// MARK: - Shooting Personal Bests

struct ShootingPersonalBests {
    static var shared = ShootingPersonalBests()

    private let store = NSUbiquitousKeyValueStore.default

    // Competition PB - tetrathlon points (max 1000)
    // Raw score (2,4,6,8,10 per shot) x 10 = tetrathlon points
    var pbRawScore: Int {
        get { Int(store.longLong(forKey: "shooting_pb_raw")) }
        set { store.set(Int64(newValue), forKey: "shooting_pb_raw"); store.synchronize() }
    }

    var pbTetrathlonPoints: Int {
        pbRawScore * 10
    }

    var formattedPB: String {
        guard pbRawScore > 0 else { return "No PB yet" }
        return "\(pbRawScore)/100 (\(pbTetrathlonPoints) pts)"
    }

    mutating func updatePersonalBest(rawScore: Int) {
        if rawScore > pbRawScore {
            pbRawScore = rawScore
        }
    }

    // MARK: - Migration from UserDefaults

    static func migrateFromUserDefaults() {
        let defaults = UserDefaults.standard
        let store = NSUbiquitousKeyValueStore.default

        guard !defaults.bool(forKey: "shooting_pb_migrated_to_icloud") else { return }

        let value = defaults.integer(forKey: "shooting_pb_raw")
        if value > 0 && store.longLong(forKey: "shooting_pb_raw") == 0 {
            store.set(Int64(value), forKey: "shooting_pb_raw")
        }
        store.synchronize()
        defaults.set(true, forKey: "shooting_pb_migrated_to_icloud")
    }
}

// MARK: - Settings View

struct ShootingSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Competition") {
                    Text("Default: 2x 5-shot cards (10 shots total)")
                        .foregroundStyle(.secondary)
                }

                Section("Personal Best") {
                    HStack {
                        Text("Current PB")
                        Spacer()
                        Text(ShootingPersonalBests.shared.formattedPB)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Shooting Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Session Setup View

struct ShootingSessionSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var sessionName = ""
    @State private var targetType: ShootingTargetType = .olympic
    @State private var distance: Double = 10.0
    @State private var numberOfEnds = 6
    @State private var arrowsPerEnd = 6
    @State private var sessionMode: SessionMode = .practice

    enum SessionMode: String, CaseIterable {
        case practice = "Practice"
        case competition = "Competition"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Session Type") {
                    Picker("Mode", selection: $sessionMode) {
                        ForEach(SessionMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("Session Name (optional)", text: $sessionName)
                }

                Section("Target") {
                    Picker("Target Type", selection: $targetType) {
                        ForEach(ShootingTargetType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    HStack {
                        Text("Distance")
                        Spacer()
                        Text(String(format: "%.0fm", distance))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $distance, in: 5...25, step: 1)
                }

                Section("Rounds") {
                    Stepper("Ends: \(numberOfEnds)", value: $numberOfEnds, in: 1...12)
                    Stepper("Shots per End: \(arrowsPerEnd)", value: $arrowsPerEnd, in: 3...10)
                }

                Section {
                    Text("Total shots: \(numberOfEnds * arrowsPerEnd)")
                        .foregroundStyle(.secondary)
                    Text("Max possible score: \(numberOfEnds * arrowsPerEnd * targetType.maxScore)")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") { startSession() }
                }
            }
        }
    }

    private func startSession() {
        let session = ShootingSession(
            name: sessionName.isEmpty ? "\(sessionMode.rawValue) Session" : sessionName,
            targetType: targetType,
            distance: distance,
            numberOfEnds: numberOfEnds,
            arrowsPerEnd: arrowsPerEnd
        )
        // Wire Watch stance/tremor sensor data
        let watchManager = WatchConnectivityManager.shared
        if watchManager.stanceStability > 0 {
            session.averageStanceStability = watchManager.stanceStability
        }
        if watchManager.tremorLevel > 0 {
            session.averageTremorLevel = watchManager.tremorLevel
        }

        modelContext.insert(session)
        // Sync sessions to widgets
        WidgetDataSyncService.shared.syncRecentSessions(context: modelContext)
        dismiss()
    }
}

// MARK: - Session Detail View

struct ShootingSessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: ShootingSession

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Score summary
                    VStack(spacing: 8) {
                        Text("\(session.totalScore)")
                            .scaledFont(size: 60, weight: .bold, relativeTo: .largeTitle)
                            .foregroundStyle(AppColors.primary)

                        Text("out of \(session.maxPossibleScore)")
                            .foregroundStyle(.secondary)

                        Text(String(format: "%.1f%%", session.scorePercentage))
                            .font(.title3)
                    }
                    .padding()

                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        MiniStatCard(title: "X's", value: "\(session.xCount)")
                        MiniStatCard(title: "10's", value: "\(session.tensCount)")
                        MiniStatCard(title: "Avg/Arrow", value: String(format: "%.1f", session.averageScorePerArrow))
                    }
                    .padding(.horizontal)

                    // Stance & Tremor data (from Watch)
                    if session.averageStanceStability > 0 || session.averageTremorLevel > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "figure.stand")
                                    .foregroundStyle(.cyan)
                                Text("Stance Analysis")
                                    .font(.headline)
                            }
                            .padding(.horizontal)

                            HStack(spacing: 24) {
                                CircularGaugeView(
                                    value: session.averageStanceStability,
                                    maxValue: 100,
                                    title: "Stability",
                                    subtitle: stanceStabilityLabel,
                                    color: stanceStabilityColor
                                )

                                CircularGaugeView(
                                    value: session.averageTremorLevel,
                                    maxValue: 100,
                                    title: "Tremor",
                                    subtitle: tremorLevelLabel,
                                    color: tremorLevelColor
                                )
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)

                            // Coach insight
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.caption)
                                Text(stanceCoachInsight)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                        }
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Session Insights link
                    if session.overallBiomechanicalScore > 0 {
                        NavigationLink(destination: ShootingGRACEInsightsView(session: session)) {
                            HStack {
                                Image(systemName: "chart.bar.xaxis.ascending")
                                    .font(.title3)
                                    .foregroundStyle(.purple)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Session Insights")
                                        .font(.headline)
                                    Text("Stability · Rhythm · Symmetry · Economy")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(String(format: "%.0f", session.overallBiomechanicalScore))
                                    .font(.title2.bold())
                                    .foregroundStyle(graceScoreColor(session.overallBiomechanicalScore))

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding()
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    } else {
                        // Prompt to use Watch for Session Insights
                        HStack(spacing: 12) {
                            Image(systemName: "applewatch.radiowaves.left.and.right")
                                .font(.title3)
                                .foregroundStyle(.purple.opacity(0.6))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Session Insights")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text("Start your next session from the Apple Watch to unlock shot-by-shot sensor analysis")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(AppColors.cardBackground.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Heart Rate (from HealthKit post-session)
                    if session.averageHeartRate > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(.red)
                                Text("Heart Rate")
                                    .font(.headline)
                            }
                            .padding(.horizontal)

                            HStack(spacing: 24) {
                                VStack(spacing: 4) {
                                    Text("\(session.averageHeartRate)")
                                        .font(.title2.bold())
                                    Text("Avg bpm")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)

                                if session.maxHeartRate > 0 {
                                    VStack(spacing: 4) {
                                        Text("\(session.maxHeartRate)")
                                            .font(.title2.bold())
                                        Text("Max bpm")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                }

                                if session.minHeartRate > 0 {
                                    VStack(spacing: 4) {
                                        Text("\(session.minHeartRate)")
                                            .font(.title2.bold())
                                        Text("Min bpm")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Weather
                    if session.hasWeatherData {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "cloud.sun")
                                Text("Weather")
                                    .font(.headline)
                            }

                            if let startWeather = session.startWeather {
                                WeatherDetailView(weather: startWeather, title: "Start Conditions")
                            }

                            if let endWeather = session.endWeather, session.startWeather?.condition != endWeather.condition {
                                WeatherChangeSummaryView(stats: session.weatherStats)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Ends breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ends")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(session.sortedEnds) { end in
                            EndRow(end: end)
                        }
                    }

                    // Session configuration
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "gearshape")
                                .foregroundStyle(.blue)
                            Text("Session Configuration")
                                .font(.headline)
                        }

                        HStack {
                            Text("Target")
                            Spacer()
                            Text(session.targetType.rawValue)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Distance")
                            Spacer()
                            Text(session.formattedDistance)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Ends")
                            Spacer()
                            Text("\(session.numberOfEnds)")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Shots per End")
                            Spacer()
                            Text("\(session.arrowsPerEnd)")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Duration")
                            Spacer()
                            Text(session.formattedDuration)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Environmental data (manual fields)
                    if session.temperature != nil || session.humidity != nil || session.windSpeed != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "thermometer.medium")
                                    .foregroundStyle(.orange)
                                Text("Environmental Conditions")
                                    .font(.headline)
                            }

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                if let temp = session.temperature {
                                    MiniStatCard(title: "Temperature", value: String(format: "%.0f\u{00B0}C", temp))
                                }
                                if let humidity = session.humidity {
                                    MiniStatCard(title: "Humidity", value: String(format: "%.0f%%", humidity))
                                }
                                if let wind = session.windSpeed {
                                    MiniStatCard(title: "Wind Speed", value: String(format: "%.1f m/s", wind))
                                }
                                if let direction = session.windDirection {
                                    MiniStatCard(title: "Wind Direction", value: direction.rawValue)
                                }
                            }
                        }
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Fatigue trend
                    if session.firstHalfSteadiness > 0 && session.secondHalfSteadiness > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "chart.line.downtrend.xyaxis")
                                    .foregroundStyle(.purple)
                                Text("Fatigue Trend")
                                    .font(.headline)
                            }

                            HStack(spacing: 16) {
                                VStack(spacing: 4) {
                                    Text(String(format: "%.0f%%", session.firstHalfSteadiness))
                                        .font(.title2.bold())
                                        .foregroundStyle(.green)
                                    Text("1st Half")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("Steadiness")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .frame(maxWidth: .infinity)

                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.secondary)

                                VStack(spacing: 4) {
                                    Text(String(format: "%.0f%%", session.secondHalfSteadiness))
                                        .font(.title2.bold())
                                        .foregroundStyle(session.secondHalfSteadiness >= session.firstHalfSteadiness ? .green : .orange)
                                    Text("2nd Half")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("Steadiness")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.vertical, 4)

                            if session.steadinessDegradation != 0 {
                                let degradation = session.steadinessDegradation
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: degradation > 5 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                        .foregroundStyle(degradation > 5 ? .orange : .green)
                                        .font(.caption)
                                    Text(fatigueTrendInsight)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Shot Timing Consistency
                    if session.averageHoldDuration > 0 || session.shotTimingConsistencyCV > 0 || session.averageHoldSteadiness > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "timer")
                                    .foregroundStyle(.cyan)
                                Text("Shot Timing")
                                    .font(.headline)
                            }

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                if session.averageHoldDuration > 0 {
                                    MiniStatCard(title: "Avg Hold", value: String(format: "%.1fs", session.averageHoldDuration))
                                }
                                if session.shotTimingConsistencyCV > 0 {
                                    MiniStatCard(title: "Consistency CV", value: String(format: "%.2f", session.shotTimingConsistencyCV))
                                }
                                if session.averageHoldSteadiness > 0 {
                                    MiniStatCard(title: "Avg Steadiness", value: String(format: "%.0f%%", session.averageHoldSteadiness))
                                }
                            }
                        }
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Physiology
                    if hasPhysiologyData {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "waveform.path.ecg")
                                    .foregroundStyle(.pink)
                                Text("Physiology")
                                    .font(.headline)
                            }

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                if session.averageBreathingRate > 0 {
                                    MiniStatCard(title: "Breathing", value: String(format: "%.0f /min", session.averageBreathingRate))
                                }
                                if session.averageSpO2 > 0 {
                                    MiniStatCard(title: "SpO2", value: String(format: "%.0f%%", session.averageSpO2))
                                }
                                if session.minSpO2 > 0 {
                                    MiniStatCard(title: "Min SpO2", value: String(format: "%.0f%%", session.minSpO2))
                                }
                                if session.postureStability > 0 {
                                    MiniStatCard(title: "Posture", value: String(format: "%.0f%%", session.postureStability))
                                }
                                if session.recoveryQuality > 0 {
                                    MiniStatCard(title: "Recovery", value: String(format: "%.0f%%", session.recoveryQuality))
                                }
                                if session.trainingLoadScore > 0 {
                                    MiniStatCard(title: "Training Load", value: String(format: "%.0f", session.trainingLoadScore))
                                }
                                if session.goodPosturePercent > 0 {
                                    MiniStatCard(title: "Good Posture", value: String(format: "%.0f%%", session.goodPosturePercent))
                                }
                                if session.activeTimePercent > 0 {
                                    MiniStatCard(title: "Active Time", value: String(format: "%.0f%%", session.activeTimePercent))
                                }
                                if session.endFatigueScore > 0 {
                                    MiniStatCard(title: "Fatigue", value: String(format: "%.0f", session.endFatigueScore))
                                }
                            }
                        }
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onDisappear {
                applySensorAnalysisIfNeeded()
            }
        }
    }

    private var hasPhysiologyData: Bool {
        session.averageBreathingRate > 0 ||
        session.averageSpO2 > 0 ||
        session.minSpO2 > 0 ||
        session.postureStability > 0 ||
        session.recoveryQuality > 0 ||
        session.trainingLoadScore > 0 ||
        session.goodPosturePercent > 0 ||
        session.activeTimePercent > 0 ||
        session.endFatigueScore > 0
    }

    private func applySensorAnalysisIfNeeded() {
        let watchManager = WatchConnectivityManager.shared
        let shotMetrics = watchManager.receivedShotMetrics
        guard !shotMetrics.isEmpty, session.overallBiomechanicalScore == 0 else { return }

        let allShots = (session.ends ?? []).flatMap { $0.shots ?? [] }
        ShootingSensorAnalyzer.applyShotSensorData(shotMetrics, to: allShots)

        // Update stance/tremor averages if not already set
        if session.averageStanceStability == 0 && watchManager.stanceStability > 0 {
            session.averageStanceStability = watchManager.stanceStability
        }
        if session.averageTremorLevel == 0 && watchManager.tremorLevel > 0 {
            session.averageTremorLevel = watchManager.tremorLevel
        }

        let analysis = ShootingSensorAnalyzer.analyzeSession(
            shotMetrics: shotMetrics,
            sessionStanceStability: session.averageStanceStability,
            averageHeartRate: session.averageHeartRate
        )
        ShootingSensorAnalyzer.applyAnalysis(analysis, to: session)
        watchManager.clearShotMetrics()
    }

    // MARK: - Stance & Tremor Helpers

    private var stanceStabilityLabel: String {
        switch session.averageStanceStability {
        case 80...100: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Fair"
        default: return "Needs Work"
        }
    }

    private var stanceStabilityColor: Color {
        switch session.averageStanceStability {
        case 80...100: return .green
        case 60..<80: return .cyan
        case 40..<60: return .orange
        default: return .red
        }
    }

    private var tremorLevelLabel: String {
        switch session.averageTremorLevel {
        case 0..<20: return "Very Low"
        case 20..<40: return "Low"
        case 40..<60: return "Moderate"
        case 60..<80: return "High"
        default: return "Very High"
        }
    }

    private var tremorLevelColor: Color {
        // Lower tremor is better, so invert the color scale
        switch session.averageTremorLevel {
        case 0..<20: return .green
        case 20..<40: return .cyan
        case 40..<60: return .orange
        case 60..<80: return .red
        default: return .red
        }
    }

    private func graceScoreColor(_ score: Double) -> Color {
        switch score {
        case 80...: return .green
        case 60..<80: return .blue
        case 40..<60: return .yellow
        default: return .orange
        }
    }

    private var fatigueTrendInsight: String {
        let degradation = session.steadinessDegradation
        if degradation > 15 {
            return "Steadiness dropped \(String(format: "%.0f%%", degradation)) from first to second half. Consider shorter sessions or adding rest between ends to manage fatigue."
        } else if degradation > 5 {
            return "Mild fatigue detected (\(String(format: "%.0f%%", degradation)) drop). Focus on breathing and stance reset between ends."
        } else if degradation > 0 {
            return "Minimal fatigue — steadiness held well throughout the session."
        } else {
            return "Steadiness improved in the second half — strong finish."
        }
    }

    private var stanceCoachInsight: String {
        let stability = Int(session.averageStanceStability)
        let tremor = Int(session.averageTremorLevel)

        if stability >= 80 && tremor < 20 {
            return "Stance stability of \(stability)% with tremor level \(tremor)/100 — excellent control. Your steady platform is contributing to consistent shot placement."
        } else if stability >= 60 && tremor < 40 {
            return "Stance stability of \(stability)% with tremor level \(tremor)/100 — good foundation. Focus on breathing control to further reduce tremor."
        } else if tremor >= 60 {
            return "Stance stability of \(stability)% — tremor level \(tremor)/100. High tremor detected. Try box breathing (4-4-4-4) and ensure your stance width matches shoulder width."
        } else {
            return "Stance stability of \(stability)% — tremor level \(tremor)/100. Work on balance drills and core strength to build a more stable shooting platform."
        }
    }
}

// MARK: - Mini Stat Card

struct MiniStatCard: View {
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

// MARK: - End Row

struct EndRow: View {
    let end: ShootingEnd

    private var hasSensorData: Bool {
        (end.shots ?? []).contains { $0.hasSensorData }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("End \(end.orderIndex + 1)")
                    .font(.subheadline)

                Spacer()

                Text(end.formattedScores)
                    .font(.system(.subheadline, design: .monospaced))

                Text("= \(end.totalScore)")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 50, alignment: .trailing)
            }

            // Per-shot sensor mini-metrics
            if hasSensorData {
                HStack(spacing: 4) {
                    ForEach(end.sortedShots) { shot in
                        if shot.hasSensorData {
                            VStack(spacing: 2) {
                                Text(shot.displayValue)
                                    .font(.caption2.bold())
                                shotSteadinessBar(shot.holdSteadiness)
                                Text(String(format: "%.1fs", shot.holdDuration))
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                                shotSensorMetrics(shot)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            VStack(spacing: 2) {
                                Text(shot.displayValue)
                                    .font(.caption2.bold())
                                Rectangle()
                                    .fill(.quaternary)
                                    .frame(height: 4)
                                    .clipShape(Capsule())
                                Text("--")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func shotSensorMetrics(_ shot: Shot) -> some View {
        let metrics: [(String, String)] = {
            var items: [(String, String)] = []
            if shot.raiseSmoothness > 0 {
                items.append(("Raise", String(format: "%.0f", shot.raiseSmoothness)))
            }
            if shot.settleDuration > 0 {
                items.append(("Settle", String(format: "%.1fs", shot.settleDuration)))
            }
            if shot.tremorIntensity > 0 {
                items.append(("Tremor", String(format: "%.0f", shot.tremorIntensity)))
            }
            if shot.driftMagnitude > 0 {
                items.append(("Drift", String(format: "%.0f", shot.driftMagnitude)))
            }
            if shot.totalCycleTime > 0 {
                items.append(("Cycle", String(format: "%.1fs", shot.totalCycleTime)))
            }
            if shot.heartRateAtShot > 0 {
                items.append(("HR", "\(shot.heartRateAtShot)"))
            }
            return items
        }()

        if !metrics.isEmpty {
            VStack(spacing: 1) {
                ForEach(metrics, id: \.0) { label, value in
                    HStack(spacing: 1) {
                        Text(label)
                            .font(.system(size: 7))
                            .foregroundStyle(.tertiary)
                        Text(value)
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func shotSteadinessBar(_ value: Double) -> some View {
        let color: Color = value > 80 ? .green : value > 60 ? .cyan : value > 40 ? .orange : .red
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.2))
                Capsule().fill(color)
                    .frame(width: geo.size.width * min(1, value / 100))
            }
        }
        .frame(height: 4)
    }
}
