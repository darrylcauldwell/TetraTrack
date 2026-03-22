//
//  RunningComponents.swift
//  TetraTrack
//
//  Running subviews extracted from RunningView
//

import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import Photos
import PhotosUI
import Charts
import os

// MARK: - Pacer Settings

enum PacerMode: String, CaseIterable {
    case targetPace = "pace"
    case targetTime = "time"
    case racePB = "pb"

    var label: String {
        switch self {
        case .targetPace: return "Pace"
        case .targetTime: return "Time"
        case .racePB: return "Race PB"
        }
    }
}

struct PacerSettings {
    var targetPace: TimeInterval = 300 // 5:00/km default
    var targetDistance: Double = 0     // optional target distance
    var targetTime: TimeInterval = 0   // optional target time
    var useTargetTime: Bool = false    // use time-based target instead of pace
    var usePBPace: Bool = false        // use PB pace for competition distance
    var announceInterval: TimeInterval = 60 // how often to announce status

    /// Distance checkpoints for PB race announcements (as fraction of total distance)
    /// For 1500m: 250m, 500m, 750m, 1000m, 1250m = 5 checkpoints before finish
    static let pbCheckpointFractions: [Double] = [0.17, 0.33, 0.5, 0.67, 0.83]

    /// Get distance checkpoints in meters for a given total distance
    func pbCheckpoints(for totalDistance: Double) -> [Double] {
        Self.pbCheckpointFractions.map { $0 * totalDistance }
    }
}

// MARK: - Run Type Button

struct RunTypeButton: View {
    let title: String
    let icon: String
    let color: Color
    var subtitle: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(color)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Run Type Card (Grid Style)

struct RunTypeCard: View {
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

// MARK: - Treadmill Entry View

struct TreadmillEntryView: View {
    let onSave: (TimeInterval, Double, Double, Double) -> Void  // duration, distance, speed, incline
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    // Duration inputs
    @State private var durationMinutes: Int = 30
    @State private var durationSeconds: Int = 0

    // Distance input
    @State private var distanceText: String = ""
    @State private var distanceKm: Double = 0

    // Speed input
    @State private var speedText: String = ""
    @State private var speedKmh: Double = 0

    // Incline
    @State private var inclinePercentage: Double = 0

    @FocusState private var focusedField: Field?

    enum Field {
        case distance, speed
    }

    private var duration: TimeInterval {
        TimeInterval(durationMinutes * 60 + durationSeconds)
    }

    private var calculatedPace: String {
        guard distanceKm > 0, duration > 0 else { return "--:--" }
        let paceSeconds = duration / distanceKm
        let mins = Int(paceSeconds) / 60
        let secs = Int(paceSeconds) % 60
        return String(format: "%d:%02d /km", mins, secs)
    }

    private var calculatedSpeed: String {
        guard distanceKm > 0, duration > 0 else { return "--" }
        let speed = distanceKm / (duration / 3600)
        return String(format: "%.1f km/h", speed)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Duration
                Section {
                    HStack {
                        Picker("Minutes", selection: $durationMinutes) {
                            ForEach(0..<120, id: \.self) { min in
                                Text("\(min)").tag(min)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)

                        Text("min")
                            .foregroundStyle(.secondary)

                        Picker("Seconds", selection: $durationSeconds) {
                            ForEach(0..<60, id: \.self) { sec in
                                Text(String(format: "%02d", sec)).tag(sec)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)

                        Text("sec")
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 120)
                } header: {
                    Text("Duration")
                }

                // Distance
                Section {
                    HStack {
                        Text("Distance")
                        Spacer()
                        TextField("0.00", text: $distanceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .focused($focusedField, equals: .distance)
                            .onChange(of: distanceText) { _, newValue in
                                if let value = Double(newValue.replacingOccurrences(of: ",", with: ".")) {
                                    distanceKm = value
                                }
                            }
                        Text("km")
                            .foregroundStyle(.secondary)
                    }

                    if distanceKm > 0 && duration > 0 {
                        HStack {
                            Text("Calculated Pace")
                            Spacer()
                            Text(calculatedPace)
                                .foregroundStyle(.mint)
                        }

                        HStack {
                            Text("Calculated Speed")
                            Spacer()
                            Text(calculatedSpeed)
                                .foregroundStyle(.mint)
                        }
                    }
                } header: {
                    Text("Distance")
                }

                // Speed (optional)
                Section {
                    HStack {
                        Text("Average Speed")
                        Spacer()
                        TextField("0.0", text: $speedText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .focused($focusedField, equals: .speed)
                            .onChange(of: speedText) { _, newValue in
                                if let value = Double(newValue.replacingOccurrences(of: ",", with: ".")) {
                                    speedKmh = value
                                }
                            }
                        Text("km/h")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Incline")
                        Spacer()
                        Stepper("\(Int(inclinePercentage))%", value: $inclinePercentage, in: 0...15, step: 0.5)
                    }
                } header: {
                    Text("Optional")
                } footer: {
                    Text("Enter the average speed and incline shown on your treadmill if available.")
                }
            }
            .navigationTitle("Log Treadmill Run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(duration, distanceKm, speedKmh, inclinePercentage)
                        dismiss()
                    }
                    .disabled(duration == 0 || distanceKm == 0)
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
        }
    }
}

// MARK: - Tab Button (for swipeable views)

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color(.secondarySystemBackground) : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Interval Settings

struct IntervalSettings {
    var workDuration: TimeInterval = 60      // 60 seconds default
    var restDuration: TimeInterval = 90      // 90 seconds default
    var numberOfIntervals: Int = 6
    var includeWarmup: Bool = true
    var warmupDuration: TimeInterval = 300   // 5 minutes
    var includeCooldown: Bool = true
    var cooldownDuration: TimeInterval = 300 // 5 minutes
}

// MARK: - Interval Setup View

struct IntervalSetupView: View {
    let onStart: (IntervalSettings) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var settings = IntervalSettings()

    // Picker state
    @State private var workMinutes: Int = 1
    @State private var workSeconds: Int = 0
    @State private var restMinutes: Int = 1
    @State private var restSeconds: Int = 30

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Intervals: \(settings.numberOfIntervals)", value: $settings.numberOfIntervals, in: 1...20)
                } header: {
                    Text("Number of Intervals")
                }

                Section {
                    HStack {
                        Text("Work")
                        Spacer()
                        HStack(spacing: 4) {
                            Picker("Minutes", selection: $workMinutes) {
                                ForEach(0..<10) { Text("\($0)").tag($0) }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 50, height: 100)
                            .clipped()

                            Text(":")

                            Picker("Seconds", selection: $workSeconds) {
                                ForEach(0..<60) { Text(String(format: "%02d", $0)).tag($0) }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 50, height: 100)
                            .clipped()
                        }
                    }

                    HStack {
                        Text("Rest")
                        Spacer()
                        HStack(spacing: 4) {
                            Picker("Minutes", selection: $restMinutes) {
                                ForEach(0..<10) { Text("\($0)").tag($0) }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 50, height: 100)
                            .clipped()

                            Text(":")

                            Picker("Seconds", selection: $restSeconds) {
                                ForEach(0..<60) { Text(String(format: "%02d", $0)).tag($0) }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 50, height: 100)
                            .clipped()
                        }
                    }
                } header: {
                    Text("Interval Duration")
                } footer: {
                    Text("Total workout: \(formattedTotalTime)")
                }

                Section {
                    Toggle("Include Warmup (5 min)", isOn: $settings.includeWarmup)
                    Toggle("Include Cooldown (5 min)", isOn: $settings.includeCooldown)
                } header: {
                    Text("Warmup & Cooldown")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Work")
                            Spacer()
                            Text("\(workMinutes):\(String(format: "%02d", workSeconds))")
                                .foregroundStyle(.orange)
                        }
                        HStack {
                            Text("Rest")
                            Spacer()
                            Text("\(restMinutes):\(String(format: "%02d", restSeconds))")
                                .foregroundStyle(.green)
                        }
                        HStack {
                            Text("Intervals")
                            Spacer()
                            Text("\(settings.numberOfIntervals)")
                        }
                        Divider()
                        HStack {
                            Text("Total Time")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(formattedTotalTime)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppColors.primary)
                        }
                    }
                } header: {
                    Text("Summary")
                }
            }
            .navigationTitle("Interval Running")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        settings.workDuration = TimeInterval(workMinutes * 60 + workSeconds)
                        settings.restDuration = TimeInterval(restMinutes * 60 + restSeconds)
                        onStart(settings)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var formattedTotalTime: String {
        let workTime = TimeInterval(workMinutes * 60 + workSeconds)
        let restTime = TimeInterval(restMinutes * 60 + restSeconds)
        var total = (workTime + restTime) * Double(settings.numberOfIntervals)

        if settings.includeWarmup { total += settings.warmupDuration }
        if settings.includeCooldown { total += settings.cooldownDuration }

        let minutes = Int(total) / 60
        let seconds = Int(total) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Virtual Pacer Setup View

struct VirtualPacerSetupView: View {
    let onStart: (PacerSettings) -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedCompetitionLevel") private var competitionLevelRaw: String = CompetitionLevel.junior.rawValue

    @State private var settings = PacerSettings()
    @State private var pacerMode: PacerMode = .targetPace
    @State private var paceMinutes: Int = 5
    @State private var paceSeconds: Int = 0
    @State private var targetDistanceKm: Double = 5.0
    @State private var targetTimeMinutes: Int = 25
    @State private var targetTimeSeconds: Int = 0

    private var personalBests: RunningPersonalBests { RunningPersonalBests.shared }

    private var competitionLevel: CompetitionLevel {
        CompetitionLevel(rawValue: competitionLevelRaw) ?? .junior
    }

    private var pbPace: TimeInterval? {
        let pb = personalBests.personalBest(for: competitionLevel.runDistance)
        guard pb > 0 else { return nil }
        // Calculate pace per km from PB
        return (pb / competitionLevel.runDistance) * 1000
    }

    private var hasPB: Bool {
        personalBests.personalBest(for: competitionLevel.runDistance) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                // Pace Mode Selection
                Section {
                    Picker("Mode", selection: $pacerMode) {
                        ForEach(PacerMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: pacerMode) { _, newValue in
                        settings.useTargetTime = (newValue == .targetTime)
                        settings.usePBPace = (newValue == .racePB)
                    }
                } header: {
                    Text("Pacer Mode")
                }

                switch pacerMode {
                case .targetTime:
                    // Target time mode
                    Section {
                        HStack {
                            Text("Distance")
                            Spacer()
                            Picker("Distance", selection: $targetDistanceKm) {
                                ForEach([1.0, 2.0, 3.0, 5.0, 10.0, 15.0, 21.1], id: \.self) { km in
                                    Text(km == 21.1 ? "Half Marathon" : "\(Int(km)) km").tag(km)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        HStack {
                            Text("Target Time")
                            Spacer()
                            HStack(spacing: 4) {
                                Picker("Minutes", selection: $targetTimeMinutes) {
                                    ForEach(0..<120) { Text("\($0)").tag($0) }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 50, height: 100)
                                .clipped()

                                Text(":")

                                Picker("Seconds", selection: $targetTimeSeconds) {
                                    ForEach(0..<60) { Text(String(format: "%02d", $0)).tag($0) }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 50, height: 100)
                                .clipped()
                            }
                        }
                    } header: {
                        Text("Target")
                    } footer: {
                        let pace = calculatedPaceFromTarget
                        Text("Required pace: \(formatPace(pace))/km")
                    }

                case .racePB:
                    // Race PB mode
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .foregroundStyle(.yellow)
                                Text("Race Your Personal Best")
                                    .font(.headline)
                            }

                            if hasPB, let pace = pbPace {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Competition Distance")
                                        Spacer()
                                        Text(competitionLevel.formattedRunDistance)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.cyan)
                                    }

                                    HStack {
                                        Text("Your PB")
                                        Spacer()
                                        Text(personalBests.formattedPB(for: competitionLevel.runDistance))
                                            .fontWeight(.medium)
                                            .foregroundStyle(.yellow)
                                    }

                                    HStack {
                                        Text("PB Pace")
                                        Spacer()
                                        Text(formatPace(pace) + "/km")
                                            .fontWeight(.medium)
                                            .foregroundStyle(.green)
                                    }
                                }
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.title)
                                        .foregroundStyle(.orange)
                                    Text("No PB Set")
                                        .font(.headline)
                                    Text("Set your \(competitionLevel.formattedRunDistance) PB in Settings → Rider Profile to use this feature.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            }
                        }
                    } header: {
                        Text("Personal Best")
                    } footer: {
                        if hasPB {
                            Text("Audio coaching will tell you if you're on track, ahead, or behind your PB pace.")
                        }
                    }

                case .targetPace:
                    // Target pace mode
                    Section {
                        HStack {
                            Text("Target Pace")
                            Spacer()
                            HStack(spacing: 4) {
                                Picker("Minutes", selection: $paceMinutes) {
                                    ForEach(2..<15) { Text("\($0)").tag($0) }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 50, height: 100)
                                .clipped()

                                Text(":")

                                Picker("Seconds", selection: $paceSeconds) {
                                    ForEach(0..<60) { Text(String(format: "%02d", $0)).tag($0) }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 50, height: 100)
                                .clipped()
                            }
                        }
                    } header: {
                        Text("Pace (min/km)")
                    }

                    // Preset paces
                    Section {
                        ForEach(PacePreset.presets) { preset in
                            Button {
                                paceMinutes = Int(preset.pacePerKm) / 60
                                paceSeconds = Int(preset.pacePerKm) % 60
                            } label: {
                                HStack {
                                    Text(preset.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text(preset.formattedPace)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("Presets")
                    }
                }

                // Summary
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "person.line.dotted.person.fill")
                                .foregroundStyle(.cyan)
                            Text("Virtual Pacer")
                                .font(.headline)
                        }

                        Text("The virtual pacer will run at your target pace. You'll hear audio cues telling you if you're ahead or behind.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        switch pacerMode {
                        case .targetTime:
                            HStack {
                                Text("Goal:")
                                Spacer()
                                Text("\(String(format: "%.1f", targetDistanceKm)) km in \(targetTimeMinutes):\(String(format: "%02d", targetTimeSeconds))")
                                    .fontWeight(.medium)
                                    .foregroundStyle(.cyan)
                            }
                        case .racePB:
                            if hasPB, let pace = pbPace {
                                HStack {
                                    Text("PB Pace:")
                                    Spacer()
                                    Text(formatPace(pace) + "/km")
                                        .fontWeight(.medium)
                                        .foregroundStyle(.yellow)
                                }
                            }
                        case .targetPace:
                            HStack {
                                Text("Target Pace:")
                                Spacer()
                                Text("\(paceMinutes):\(String(format: "%02d", paceSeconds))/km")
                                    .fontWeight(.medium)
                                    .foregroundStyle(.cyan)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Virtual Pacer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        switch pacerMode {
                        case .targetTime:
                            settings.targetDistance = targetDistanceKm * 1000
                            settings.targetTime = TimeInterval(targetTimeMinutes * 60 + targetTimeSeconds)
                            settings.targetPace = calculatedPaceFromTarget
                        case .racePB:
                            if let pace = pbPace {
                                settings.targetPace = pace
                                settings.targetDistance = competitionLevel.runDistance
                                settings.targetTime = personalBests.personalBest(for: competitionLevel.runDistance)
                            }
                        case .targetPace:
                            settings.targetPace = TimeInterval(paceMinutes * 60 + paceSeconds)
                        }
                        onStart(settings)
                    }
                    .fontWeight(.semibold)
                    .disabled(pacerMode == .racePB && !hasPB)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var calculatedPaceFromTarget: TimeInterval {
        let totalSeconds = TimeInterval(targetTimeMinutes * 60 + targetTimeSeconds)
        guard targetDistanceKm > 0 else { return 300 }
        return totalSeconds / targetDistanceKm
    }

    private func formatPace(_ pace: TimeInterval) -> String {
        let mins = Int(pace) / 60
        let secs = Int(pace) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Running Settings View

struct RunningSettingsView: View {
    let selectedLevel: CompetitionLevel
    let onLevelChange: (CompetitionLevel) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showingLevelPicker = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: { showingLevelPicker = true }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tetrathlon Competition Level")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Text(selectedLevel.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(selectedLevel.formattedRunDistance)
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                                Text(selectedLevel.formattedSwimDuration + " swim")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Pony Club Tetrathlon")
                } footer: {
                    Text("Sets target distances for time trials based on your age category.")
                }
            }
            .navigationTitle("Running Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingLevelPicker) {
                LevelPickerView(selectedLevel: selectedLevel, onSelect: { level in
                    onLevelChange(level)
                    showingLevelPicker = false
                })
                .sheetBackground()
            }
        }
    }
}

// MARK: - Level Picker

struct LevelPickerView: View {
    let selectedLevel: CompetitionLevel
    let onSelect: (CompetitionLevel) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(CompetitionLevel.groupedLevels, id: \.0) { group, levels in
                    Section(group) {
                        ForEach(levels, id: \.self) { level in
                            Button(action: { onSelect(level) }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(level.displayName)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(level.ageRange)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(level.formattedRunDistance)
                                            .font(.headline)
                                            .foregroundStyle(.orange)
                                        Text(level.formattedSwimDuration + " swim")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    if level == selectedLevel {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tetrathlon Level")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Running Personal Bests

struct RunningPersonalBests {
    static var shared = RunningPersonalBests()

    private let store = NSUbiquitousKeyValueStore.default

    // MARK: - Practice PBs

    var pb1000m: TimeInterval {
        get { store.double(forKey: "pb_1000m") }
        set { store.set(newValue, forKey: "pb_1000m"); store.synchronize() }
    }

    var pb1500m: TimeInterval {
        get { store.double(forKey: "pb_1500m") }
        set { store.set(newValue, forKey: "pb_1500m"); store.synchronize() }
    }

    var pb2000m: TimeInterval {
        get { store.double(forKey: "pb_2000m") }
        set { store.set(newValue, forKey: "pb_2000m"); store.synchronize() }
    }

    var pb3000m: TimeInterval {
        get { store.double(forKey: "pb_3000m") }
        set { store.set(newValue, forKey: "pb_3000m"); store.synchronize() }
    }

    var pb400m: TimeInterval {
        get { store.double(forKey: "pb_400m") }
        set { store.set(newValue, forKey: "pb_400m"); store.synchronize() }
    }

    // MARK: - Competition PBs

    var competitionPB1000m: TimeInterval {
        get { store.double(forKey: "competition_pb_1000m") }
        set { store.set(newValue, forKey: "competition_pb_1000m"); store.synchronize() }
    }

    var competitionPB1500m: TimeInterval {
        get { store.double(forKey: "competition_pb_1500m") }
        set { store.set(newValue, forKey: "competition_pb_1500m"); store.synchronize() }
    }

    var competitionPB2000m: TimeInterval {
        get { store.double(forKey: "competition_pb_2000m") }
        set { store.set(newValue, forKey: "competition_pb_2000m"); store.synchronize() }
    }

    var competitionPB3000m: TimeInterval {
        get { store.double(forKey: "competition_pb_3000m") }
        set { store.set(newValue, forKey: "competition_pb_3000m"); store.synchronize() }
    }

    // MARK: - Practice PB Methods

    func personalBest(for distance: Double) -> TimeInterval {
        switch distance {
        case 1000: return pb1000m
        case 1500: return pb1500m
        case 2000: return pb2000m
        case 3000: return pb3000m
        case 400: return pb400m
        default: return 0
        }
    }

    mutating func updatePersonalBest(for distance: Double, time: TimeInterval) {
        let current = personalBest(for: distance)
        if current == 0 || time < current {
            switch distance {
            case 1000: pb1000m = time
            case 1500: pb1500m = time
            case 2000: pb2000m = time
            case 3000: pb3000m = time
            case 400: pb400m = time
            default: break
            }
        }
    }

    func formattedPB(for distance: Double) -> String {
        let pb = personalBest(for: distance)
        guard pb > 0 else { return "--:--" }
        let mins = Int(pb) / 60
        let secs = Int(pb) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    func paceFromPB(for distance: Double) -> TimeInterval {
        let pb = personalBest(for: distance)
        guard pb > 0, distance > 0 else { return 0 }
        return (pb / distance) * 1000 // seconds per km
    }

    // MARK: - Competition PB Methods

    func competitionPersonalBest(for distance: Double) -> TimeInterval {
        switch distance {
        case 1000: return competitionPB1000m
        case 1500: return competitionPB1500m
        case 2000: return competitionPB2000m
        case 3000: return competitionPB3000m
        default: return 0
        }
    }

    func formattedCompetitionPB(for distance: Double) -> String {
        let pb = competitionPersonalBest(for: distance)
        guard pb > 0 else { return "--:--" }
        let mins = Int(pb) / 60
        let secs = Int(pb) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    mutating func updateCompetitionPersonalBest(for distance: Double, time: TimeInterval) {
        let current = competitionPersonalBest(for: distance)
        if current == 0 || time < current {
            switch distance {
            case 1000: competitionPB1000m = time
            case 1500: competitionPB1500m = time
            case 2000: competitionPB2000m = time
            case 3000: competitionPB3000m = time
            default: break
            }
        }
    }

    // MARK: - Migration from UserDefaults

    static func migrateFromUserDefaults() {
        let defaults = UserDefaults.standard
        let store = NSUbiquitousKeyValueStore.default

        guard !defaults.bool(forKey: "running_pb_migrated_to_icloud") else { return }

        let keys = ["pb_1000m", "pb_1500m", "pb_2000m", "pb_3000m", "pb_400m"]
        for key in keys {
            let value = defaults.double(forKey: key)
            if value > 0 && store.double(forKey: key) == 0 {
                store.set(value, forKey: key)
            }
        }
        store.synchronize()
        defaults.set(true, forKey: "running_pb_migrated_to_icloud")
    }
}

// MARK: - Tetrathlon Points Card

struct TetrathlonPointsCard: View {
    let session: RunningSession
    @AppStorage("selectedCompetitionLevel") private var selectedLevelRaw: String = "Junior"

    private var selectedLevel: CompetitionLevel {
        CompetitionLevel(rawValue: selectedLevelRaw) ?? .junior
    }

    var body: some View {
        let points = PonyClubScoringService.calculateRunningPoints(
            timeInSeconds: session.totalDuration,
            ageCategory: selectedLevel.scoringCategory,
            gender: selectedLevel.scoringGender
        )
        let standardTime = PonyClubScoringService.getRunStandardTime(
            for: selectedLevel.scoringCategory,
            gender: selectedLevel.scoringGender
        )
        let standardMins = Int(standardTime) / 60
        let standardSecs = Int(standardTime) % 60
        let pbTime = RunningPersonalBests.shared.personalBest(for: selectedLevel.runDistance)

        VStack(spacing: 8) {
            Text("Tetrathlon Points")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(Int(points))")
                .scaledFont(size: 48, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                .monospacedDigit()
                .foregroundStyle(points >= 1000 ? .green : points >= 800 ? .purple : .orange)

            Text("1000-pt target: \(standardMins):\(String(format: "%02d", standardSecs))")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            if pbTime > 0 {
                let pbMins = Int(pbTime) / 60
                let pbSecs = Int(pbTime) % 60
                Text("PB: \(pbMins):\(String(format: "%02d", pbSecs))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Session Detail View

struct RunningSessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: RunningSession
    @State private var showingTrimView = false
    @State private var sessionPhotos: [PHAsset] = []
    @State private var sessionVideos: [PHAsset] = []
    @State private var hasLoadedMedia = false
    @State private var showingMediaEditor = false
    @State private var selectedVideo: PHAsset?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Route Map (if session has GPS data)
                    if session.hasRouteData {
                        SessionRouteMapView(
                            coordinates: session.coordinates,
                            routeColors: .fromRunningSession(session)
                        )
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // Distance and time summary
                    VStack(spacing: 8) {
                        Text(session.formattedDistance)
                            .scaledFont(size: 50, weight: .bold, relativeTo: .largeTitle)
                            .foregroundStyle(AppColors.primary)

                        Text(session.formattedDuration)
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        Text(session.formattedPace + " /km")
                            .font(.headline)
                    }
                    .padding()

                    // Tetrathlon Points (for time trial sessions)
                    if session.sessionType == .timeTrial && session.totalDuration > 0 {
                        TetrathlonPointsCard(session: session)
                            .padding(.horizontal)
                    }

                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        RunMiniStat(title: "Avg HR", value: session.averageHeartRate > 0 ? "\(session.averageHeartRate)" : "--")
                        RunMiniStat(title: "Max HR", value: session.maxHeartRate > 0 ? "\(session.maxHeartRate)" : "--")
                        RunMiniStat(title: "Cadence", value: session.averageCadence > 0 ? "\(session.averageCadence)" : "--")
                        if session.averageVerticalOscillation > 0 {
                            RunMiniStat(title: "V. Oscillation", value: String(format: "%.1f cm", session.averageVerticalOscillation))
                        }
                        if session.averageGroundContactTime > 0 {
                            RunMiniStat(title: "GCT", value: String(format: "%.0f ms", session.averageGroundContactTime))
                        }
                    }
                    .padding(.horizontal)

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

                            if session.minHeartRate > 0 {
                                HStack(spacing: 16) {
                                    Label("\(session.minHeartRate) min", systemImage: "heart")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Label("\(session.averageHeartRate) avg", systemImage: "heart.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Label("\(session.maxHeartRate) max", systemImage: "heart.fill")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // Elevation
                    if session.totalAscent > 0 || session.totalDescent > 0 {
                        HStack(spacing: 20) {
                            HStack {
                                Image(systemName: "arrow.up.right")
                                    .foregroundStyle(.green)
                                Text("+\(Int(session.totalAscent))m")
                            }
                            HStack {
                                Image(systemName: "arrow.down.right")
                                    .foregroundStyle(.red)
                                Text("-\(Int(session.totalDescent))m")
                            }
                        }
                        .font(.subheadline)
                    }

                    // Splits
                    if !(session.splits ?? []).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Splits")
                                .font(.headline)
                                .padding(.horizontal)

                            // Track lap split chart
                            let splits = session.sortedSplits
                            if let first = splits.first, first.distance < 1000, splits.count >= 2 {
                                TrackLapSplitChart(lapTimes: splits.map(\.duration), compact: false)
                                    .padding(.horizontal)
                            }

                            // Split efficiency trend
                            if splits.count >= 2 {
                                SplitEfficiencyChart(splits: splits)
                                    .padding(.horizontal)
                            }

                            ForEach(splits) { split in
                                SplitRow(split: split, sessionAvgPace: session.averagePace, sessionAvgCadence: session.averageCadence)
                            }
                        }
                    }

                    // Coaching Insights (PB checkpoints, pacer gap, interval performance)
                    if session.hasCoachingInsights {
                        RunningCoachingInsightsSection(session: session)
                            .padding(.horizontal)
                    }

                    // Hidden PBs Found (segment analysis from longer runs)
                    if session.hasSegmentPBs {
                        SegmentPBSection(session: session)
                            .padding(.horizontal)
                    }

                    // Watch Metrics (HealthKit data from Apple Watch)
                    if session.hasWatchMetricsData {
                        watchMetricsSection
                    }

                    // Runner Insights link (when we have biomechanics data)
                    if session.averageCadence > 0 || session.averageVerticalOscillation > 0 || session.averageHeartRate > 0 || session.hasWatchMetricsData {
                        NavigationLink(destination: RunningInsightsView(session: session)) {
                            HStack {
                                Image(systemName: "figure.run")
                                    .font(.title2)
                                    .foregroundStyle(AppColors.primary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Session Insights")
                                        .font(.headline)
                                    Text("Stability · Rhythm · Symmetry · Economy")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                            .padding()
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    }

                    // Session info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session Info")
                            .font(.headline)

                        HStack {
                            Text("Type")
                            Spacer()
                            Text(session.sessionType.rawValue)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Mode")
                            Spacer()
                            Text(session.runMode.rawValue)
                                .foregroundStyle(.secondary)
                        }

                        if let power = session.averagePower {
                            HStack {
                                Text("Avg Power")
                                Spacer()
                                Text("\(Int(power))W")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Photos & Videos section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Photos & Videos")
                                .font(.headline)
                            Spacer()
                            if !sessionPhotos.isEmpty || !sessionVideos.isEmpty {
                                NavigationLink(destination: RunningMediaGalleryView(session: session)) {
                                    Text("View All (\(sessionPhotos.count + sessionVideos.count))")
                                        .font(.subheadline)
                                        .foregroundStyle(AppColors.primary)
                                }
                            }
                        }

                        if sessionPhotos.isEmpty && sessionVideos.isEmpty {
                            HStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.title2)
                                    .foregroundStyle(.tertiary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("No photos or videos")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text("Media taken within 1 hour of this run will appear here")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(sessionPhotos.prefix(4), id: \.localIdentifier) { asset in
                                        PhotoThumbnail(asset: asset)
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    ForEach(sessionVideos.prefix(2), id: \.localIdentifier) { asset in
                                        VideoThumbnail(asset: asset)
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .onTapGesture {
                                                selectedVideo = asset
                                            }
                                    }
                                    if sessionPhotos.count + sessionVideos.count > 6 {
                                        NavigationLink(destination: RunningMediaGalleryView(session: session)) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(AppColors.cardBackground)
                                                    .frame(width: 80, height: 80)
                                                VStack {
                                                    Text("+\(sessionPhotos.count + sessionVideos.count - 6)")
                                                        .font(.title3)
                                                        .fontWeight(.semibold)
                                                    Text("more")
                                                        .font(.caption2)
                                                }
                                                .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Button {
                            showingMediaEditor = true
                        } label: {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                                Text(sessionPhotos.isEmpty && sessionVideos.isEmpty ? "Add Photos & Videos" : "Add More")
                            }
                            .font(.subheadline)
                        }
                        .buttonStyle(.bordered)
                    }
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

                    // Trim Button (only show if session has GPS data)
                    if session.hasRouteData {
                        Button {
                            showingTrimView = true
                        } label: {
                            Label("Trim Run", systemImage: "scissors")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppColors.cardBackground)
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(session.name.isEmpty ? "Run" : session.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingTrimView) {
                RunningSessionTrimView(session: session)
                    .sheetBackground()
            }
            .sheet(isPresented: $showingMediaEditor) {
                RunningMediaEditorView(session: session) {
                    hasLoadedMedia = false
                    Task {
                        await loadMedia()
                    }
                }
                .sheetBackground()
            }
            .sheet(item: $selectedVideo) { video in
                VideoPlayerView(asset: video)
                    .sheetBackground()
            }
            .task {
                await loadMedia()
            }
            .sheetBackground()
        }
    }

    // MARK: - Watch Metrics Section

    private var watchMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "applewatch")
                    .foregroundStyle(AppColors.primary)
                Text("Watch Metrics")
                    .font(.headline)
            }

            // Metrics rows
            VStack(spacing: 0) {
                if let healthKitAsymmetry = session.healthKitAsymmetry, healthKitAsymmetry > 0 {
                    metricRow(icon: "arrow.left.arrow.right", label: "Asymmetry", value: String(format: "%.1f%%", healthKitAsymmetry))
                }
                if let healthKitStrideLength = session.healthKitStrideLength, healthKitStrideLength > 0 {
                    Divider()
                    metricRow(icon: "ruler", label: "Stride Length", value: String(format: "%.2f m", healthKitStrideLength))
                }
                if let healthKitPower = session.healthKitPower, healthKitPower > 0 {
                    Divider()
                    metricRow(icon: "bolt.fill", label: "Power", value: String(format: "%.0f W", healthKitPower))
                }
                if let healthKitSteps = session.healthKitStepCount, healthKitSteps > 0 {
                    Divider()
                    metricRow(icon: "shoeprints.fill", label: "Steps", value: "\(healthKitSteps)")
                }
                if let hrRecovery = session.healthKitHRRecoveryOneMinute, hrRecovery > 0 {
                    Divider()
                    metricRow(icon: "heart.circle", label: "HR Recovery (1 min)", value: String(format: "%.0f bpm", hrRecovery))
                }
            }

            // Phase breakdown (computed from GPS speed)
            let breakdown = session.effectivePhaseBreakdown
            if breakdown.totalSeconds > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Running Phase Breakdown")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        ForEach(RunningPhase.allCases) { phase in
                            let pct = breakdown.percentage(for: phase)
                            if pct > 0 {
                                VStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(phaseColor(phase))
                                        .frame(height: max(8, CGFloat(pct) * 0.6))
                                    Text(phase.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(String(format: "%.0f%%", pct))
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .frame(height: 80)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func metricRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(AppColors.primary)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .monospacedDigit()
        }
        .padding(.vertical, 6)
    }

    private func phaseColor(_ phase: RunningPhase) -> Color {
        switch phase {
        case .walking: return .blue
        case .jogging: return .green
        case .running: return .orange
        case .sprinting: return .red
        }
    }

    private func loadMedia() async {
        guard !hasLoadedMedia else { return }
        hasLoadedMedia = true

        let photoService = RidePhotoService.shared
        if !photoService.isAuthorized {
            _ = await photoService.requestAuthorization()
        }

        let (photos, videos) = await photoService.findMediaForRunningSession(session)

        await MainActor.run {
            sessionPhotos = photos
            sessionVideos = videos
        }
    }

    private func cadenceTargetColor(actual: Int, target: Int) -> Color {
        guard actual > 0, target > 0 else { return .secondary }
        let deviation = abs(actual - target)
        if deviation <= 5 { return .green }
        if deviation <= 10 { return .yellow }
        return .orange
    }
}

// MARK: - Running Media Gallery

struct RunningMediaGalleryView: View {
    let session: RunningSession

    @State private var photos: [PHAsset] = []
    @State private var videos: [PHAsset] = []
    @State private var isLoading = true
    @State private var selectedPhoto: PHAsset?
    @State private var selectedVideo: PHAsset?
    private let photoService = RidePhotoService.shared

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        VStack {
            if !photoService.isAuthorized {
                MediaPermissionView {
                    Task {
                        _ = await photoService.requestAuthorization()
                        await loadMedia()
                    }
                }
            } else if isLoading {
                ProgressView("Finding photos & videos...")
            } else if photos.isEmpty && videos.isEmpty {
                EmptyMediaView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !photos.isEmpty {
                            Text("Photos (\(photos.count))")
                                .font(.headline)
                                .padding(.horizontal)

                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(photos, id: \.localIdentifier) { asset in
                                    PhotoThumbnail(asset: asset)
                                        .aspectRatio(1, contentMode: .fill)
                                        .clipped()
                                        .onTapGesture {
                                            selectedPhoto = asset
                                        }
                                }
                            }
                        }

                        if !videos.isEmpty {
                            Text("Videos (\(videos.count))")
                                .font(.headline)
                                .padding(.horizontal)
                                .padding(.top, photos.isEmpty ? 0 : 8)

                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(videos, id: \.localIdentifier) { asset in
                                    VideoThumbnail(asset: asset)
                                        .aspectRatio(1, contentMode: .fill)
                                        .clipped()
                                        .onTapGesture {
                                            selectedVideo = asset
                                        }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Photos & Videos")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedPhoto) { asset in
            PhotoDetailView(asset: asset)
                .sheetBackground()
        }
        .sheet(item: $selectedVideo) { asset in
            VideoPlayerView(asset: asset)
                .sheetBackground()
        }
        .task {
            await loadMedia()
        }
        .sheetBackground()
    }

    private func loadMedia() async {
        isLoading = true
        let (sessionPhotos, sessionVideos) = await photoService.findMediaForRunningSession(session)
        photos = sessionPhotos
        videos = sessionVideos
        isLoading = false
    }
}

// MARK: - Running Media Editor

struct RunningMediaEditorView: View {
    let session: RunningSession
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedVideos: [PhotosPickerItem] = []
    @State private var isProcessing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("Photos and videos taken within 1 hour of your run are automatically linked.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text("Use the options below to add media from other times.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()

                Spacer()

                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 20,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Add Photos", systemImage: "photo.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                PhotosPicker(
                    selection: $selectedVideos,
                    maxSelectionCount: 10,
                    matching: .videos,
                    photoLibrary: .shared()
                ) {
                    Label("Add Videos", systemImage: "video.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer()

                if !selectedPhotos.isEmpty || !selectedVideos.isEmpty {
                    Text("Selected: \(selectedPhotos.count) photos, \(selectedVideos.count) videos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .navigationTitle("Add Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                        onDismiss()
                    }
                    .disabled(isProcessing)
                }
            }
        }
    }
}

// MARK: - Run Mini Stat

struct RunMiniStat: View {
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

// MARK: - Split Row

struct SplitRow: View {
    let split: RunningSplit
    var sessionAvgPace: TimeInterval = 0
    var sessionAvgCadence: Int = 0

    private var isTrackLap: Bool { split.distance < 1000 }

    private var paceDeviation: Double? {
        guard sessionAvgPace > 0 else { return nil }
        return (split.pace - sessionAvgPace) / sessionAvgPace * 100
    }

    private var efficiency: Double? {
        guard split.heartRate > 0, split.pace > 0 else { return nil }
        return split.pace / Double(split.heartRate)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(isTrackLap ? "Lap \(split.orderIndex + 1)" : "km \(split.orderIndex + 1)")
                    .font(.subheadline)
                    .frame(width: 50, alignment: .leading)

                if let zone = split.paceZone {
                    Text(zone.name)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(zone.color).opacity(0.2))
                        .foregroundStyle(Color(zone.color))
                        .clipShape(Capsule())
                }

                Spacer()

                if split.heartRate > 0 {
                    Label("\(split.heartRate)", systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(isTrackLap ? split.duration.formattedLapTime : split.formattedPace)
                    .font(.subheadline.bold())
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 70, alignment: .trailing)
            }

            // Efficiency metrics row
            HStack(spacing: 12) {
                if split.cadence > 0 {
                    Label("\(split.cadence) spm", systemImage: "metronome")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let dev = paceDeviation {
                    let sign = dev >= 0 ? "+" : ""
                    Text("\(sign)\(String(format: "%.1f", dev))%")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(abs(dev) < 3 ? .green : abs(dev) < 6 ? .orange : .red)
                }

                Spacer()

                if split.elevation != 0 {
                    Label(String(format: "%+.0fm", split.elevation), systemImage: split.elevation > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }
}

// MARK: - Split Efficiency Chart

struct SplitEfficiencyChart: View {
    let splits: [RunningSplit]

    private struct SplitMetric: Identifiable {
        let id: Int
        let splitLabel: String
        let pace: TimeInterval
        let heartRate: Int
        let cadence: Int
    }

    private var metrics: [SplitMetric] {
        splits.map { split in
            SplitMetric(
                id: split.orderIndex,
                splitLabel: split.distance < 1000 ? "L\(split.orderIndex + 1)" : "\(split.orderIndex + 1)",
                pace: split.pace,
                heartRate: split.heartRate,
                cadence: split.cadence
            )
        }
    }

    private var avgPace: TimeInterval {
        guard !splits.isEmpty else { return 0 }
        return splits.map(\.pace).reduce(0, +) / Double(splits.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pace & Heart Rate by Split")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Chart {
                ForEach(metrics) { m in
                    BarMark(
                        x: .value("Split", m.splitLabel),
                        y: .value("Pace", m.pace)
                    )
                    .foregroundStyle(m.pace <= avgPace ? Color.green.opacity(0.7) : Color.orange.opacity(0.7))
                }

                let hrMetrics = metrics.filter { $0.heartRate > 0 }
                if !hrMetrics.isEmpty {
                    ForEach(hrMetrics) { m in
                        LineMark(
                            x: .value("Split", m.splitLabel),
                            y: .value("HR", Double(m.heartRate))
                        )
                        .foregroundStyle(.red)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Split", m.splitLabel),
                            y: .value("HR", Double(m.heartRate))
                        )
                        .foregroundStyle(.red)
                        .symbolSize(20)
                    }
                }

                if avgPace > 0 {
                    RuleMark(y: .value("Avg", avgPace))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let sec = value.as(Double.self) {
                            Text(sec.formattedPace)
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 150)

            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(.green.opacity(0.7)).frame(width: 8, height: 8)
                    Text("Pace (faster)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(.orange.opacity(0.7)).frame(width: 8, height: 8)
                    Text("Pace (slower)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if metrics.contains(where: { $0.heartRate > 0 }) {
                    HStack(spacing: 4) {
                        Circle().fill(.red).frame(width: 8, height: 8)
                        Text("Heart Rate")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Track Lap Split Chart

struct TrackLapSplitData: Identifiable {
    let id = UUID()
    let lapNumber: Int
    let time: TimeInterval
}

struct TrackLapSplitChart: View {
    let lapTimes: [TimeInterval]
    var compact: Bool = false

    private var splitData: [TrackLapSplitData] {
        lapTimes.enumerated().map { index, time in
            TrackLapSplitData(lapNumber: index + 1, time: time)
        }
    }

    private var averageTime: TimeInterval {
        guard !lapTimes.isEmpty else { return 0 }
        return lapTimes.reduce(0, +) / Double(lapTimes.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !compact {
                Text("Lap Times")
                    .font(.headline)
            }

            Chart {
                ForEach(splitData) { split in
                    LineMark(
                        x: .value("Lap", split.lapNumber),
                        y: .value("Time", split.time)
                    )
                    .foregroundStyle(split.time <= averageTime ? .green : .orange)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Lap", split.lapNumber),
                        y: .value("Time", split.time)
                    )
                    .foregroundStyle(split.time <= averageTime ? .green : .orange)
                    .symbolSize(compact ? 20 : 40)
                }

                if averageTime > 0 {
                    RuleMark(y: .value("Average", averageTime))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .annotation(position: .top, alignment: .trailing) {
                            if !compact {
                                Text("Avg")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                }
            }
            .frame(height: compact ? 100 : 200)
            .chartXScale(domain: 0...splitData.count + 1)
            .chartXAxis {
                AxisMarks(values: Array(1...splitData.count)) { value in
                    AxisValueLabel {
                        if let num = value.as(Int.self) {
                            Text("\(num)")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let time = value.as(Double.self) {
                            Text(formatLapTime(time))
                                .font(.caption2)
                        }
                    }
                    if !compact {
                        AxisGridLine()
                    }
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatLapTime(_ time: TimeInterval) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Segment PB Section

struct SegmentPBSection: View {
    @Bindable var session: RunningSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
                Text("Hidden PBs Found")
                    .font(.headline)
                Spacer()
            }

            ForEach(session.segmentPBResults) { result in
                SegmentPBRow(result: result, session: session)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct SegmentPBRow: View {
    let result: SegmentPBResult
    @Bindable var session: RunningSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(result.distanceLabel)
                        .font(.subheadline.bold())
                    if result.isNewPB {
                        Text("NEW PB")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 12) {
                    Text(result.formattedTime)
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(result.isNewPB ? .green : .primary)

                    if result.currentPB > 0 {
                        let currentMins = Int(result.currentPB) / 60
                        let currentSecs = Int(result.currentPB) % 60
                        Text("PB: \(currentMins):\(String(format: "%02d", currentSecs))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if result.isNewPB && result.improvementSeconds > 0 {
                        Text(result.formattedImprovement)
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    }
                }
            }

            Spacer()

            if result.isNewPB {
                Button("Accept PB") {
                    var pbs = RunningPersonalBests.shared
                    pbs.updatePersonalBest(for: result.distance, time: result.time)

                    // Update the result to reflect accepted state
                    var updated = session.segmentPBResults
                    if let idx = updated.firstIndex(where: { $0.id == result.id }) {
                        updated[idx] = SegmentPBResult(
                            distance: result.distance,
                            time: result.time,
                            startIndex: result.startIndex,
                            endIndex: result.endIndex,
                            currentPB: result.time,
                            isNewPB: false
                        )
                        session.segmentPBResults = updated
                    }
                }
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Running Coaching Insights Section

struct RunningCoachingInsightsSection: View {
    let session: RunningSession

    private var summary: RunningCoachingSummary? { session.coachingSummary }

    var body: some View {
        guard let summary = summary else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: summary.coachingLevel?.icon ?? "speaker.wave.3")
                        .foregroundStyle(.blue)
                    Text("Coaching Insights")
                        .font(.headline)
                    Spacer()
                    if summary.announcementCount > 0 {
                        Text("\(summary.announcementCount) cues")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                // PB Race section (time trials)
                if !summary.pbCheckpoints.isEmpty {
                    PBCheckpointChart(checkpoints: summary.pbCheckpoints, result: summary.pbResult)
                }

                // Pacer Gap section (pacer runs)
                if !summary.pacerGapSnapshots.isEmpty {
                    PacerGapTrendChart(snapshots: summary.pacerGapSnapshots)
                }

                // Interval Performance section (intervals)
                if !summary.intervalPerformance.isEmpty {
                    IntervalPerformanceChart(records: summary.intervalPerformance.filter { $0.phaseRaw == "work" })
                }
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        )
    }
}

// MARK: - PB Checkpoint Chart

private struct PBCheckpointChart: View {
    let checkpoints: [PBCheckpointRecord]
    let result: PBResultRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
                Text("PB Race")
                    .font(.subheadline.weight(.medium))
            }

            Chart {
                ForEach(checkpoints) { cp in
                    BarMark(
                        x: .value("Distance", "\(Int(cp.distanceFraction * 100))%"),
                        y: .value("Delta", cp.delta)
                    )
                    .foregroundStyle(cp.isAhead ? Color.green : Color.red)
                }

                RuleMark(y: .value("PB Pace", 0))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .foregroundStyle(.secondary)
            }
            .chartYAxisLabel("seconds vs PB")
            .frame(height: 150)

            // Final result
            if let result = result {
                HStack {
                    if result.isNewPB {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.yellow)
                        Text("New PB!")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.yellow)
                    } else {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text("Finished")
                            .font(.subheadline)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatDuration(result.finalTime))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                        let diff = result.finalTime - result.pbTime
                        Text(diff < 0 ? "\(formatDelta(abs(diff))) faster" : "\(formatDelta(diff)) slower")
                            .font(.caption)
                            .foregroundStyle(diff < 0 ? .green : .red)
                    }
                }
                .padding(10)
                .background(result.isNewPB ? Color.yellow.opacity(0.1) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let mins = Int(t) / 60
        let secs = Int(t) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatDelta(_ t: TimeInterval) -> String {
        let secs = Int(t)
        return "\(secs)s"
    }
}

// MARK: - Pacer Gap Trend Chart

private struct PacerGapTrendChart: View {
    let snapshots: [PacerGapSnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "person.line.dotted.person.fill")
                    .foregroundStyle(.cyan)
                    .font(.caption)
                Text("Virtual Pacer")
                    .font(.subheadline.weight(.medium))
            }

            Chart {
                ForEach(snapshots) { snap in
                    let signedGap = snap.isAhead ? snap.gapSeconds : -snap.gapSeconds
                    let minutes = snap.elapsedTime / 60.0

                    LineMark(
                        x: .value("Time", minutes),
                        y: .value("Gap", signedGap)
                    )
                    .foregroundStyle(.cyan)

                    AreaMark(
                        x: .value("Time", minutes),
                        y: .value("Gap", signedGap)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [signedGap >= 0 ? .green.opacity(0.3) : .red.opacity(0.3), .clear],
                            startPoint: signedGap >= 0 ? .top : .bottom,
                            endPoint: signedGap >= 0 ? .bottom : .top
                        )
                    )
                }

                RuleMark(y: .value("Target", 0))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .foregroundStyle(.secondary)
            }
            .chartXAxisLabel("minutes")
            .chartYAxisLabel("seconds")
            .frame(height: 150)

            // Final gap stat
            if let last = snapshots.last {
                HStack {
                    Text("Final gap")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(abs(last.gapSeconds)))s \(last.isAhead ? "ahead" : "behind")")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(last.isAhead ? .green : .red)
                }
            }
        }
    }
}

// MARK: - Interval Performance Chart

private struct IntervalPerformanceChart: View {
    let records: [IntervalPerformanceRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text("Interval Performance")
                    .font(.subheadline.weight(.medium))
            }

            Chart {
                ForEach(records) { record in
                    BarMark(
                        x: .value("Interval", "Int \(record.intervalIndex)"),
                        y: .value("Duration", record.actualDuration)
                    )
                    .foregroundStyle(record.actualDuration <= record.targetDuration ? Color.green : Color.orange)
                }

                if let target = records.first?.targetDuration, target > 0 {
                    RuleMark(y: .value("Target", target))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .foregroundStyle(.secondary)
                        .annotation(position: .trailing, alignment: .leading) {
                            Text("target")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .chartYAxisLabel("seconds")
            .frame(height: 150)
        }
    }
}
