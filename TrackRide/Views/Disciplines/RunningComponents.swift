//
//  RunningComponents.swift
//  TrackRide
//
//  Running subviews extracted from RunningView
//

import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import Photos
import PhotosUI
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
            .background(Color(.secondarySystemBackground))
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
            .background(Color(.secondarySystemBackground))
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

    private let defaults = UserDefaults.standard

    var pb1000m: TimeInterval {
        get { defaults.double(forKey: "pb_1000m") }
        set { defaults.set(newValue, forKey: "pb_1000m") }
    }

    var pb1500m: TimeInterval {
        get { defaults.double(forKey: "pb_1500m") }
        set { defaults.set(newValue, forKey: "pb_1500m") }
    }

    var pb2000m: TimeInterval {
        get { defaults.double(forKey: "pb_2000m") }
        set { defaults.set(newValue, forKey: "pb_2000m") }
    }

    var pb3000m: TimeInterval {
        get { defaults.double(forKey: "pb_3000m") }
        set { defaults.set(newValue, forKey: "pb_3000m") }
    }

    var pb400m: TimeInterval {
        get { defaults.double(forKey: "pb_400m") }
        set { defaults.set(newValue, forKey: "pb_400m") }
    }

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
}

// MARK: - Running Pause/Stop Button

struct RunningPauseStopButton: View {
    let isPaused: Bool
    let onPauseResume: () -> Void
    let onStop: () -> Void
    let onDiscard: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var showingStopOptions = false

    private let buttonSize: CGFloat = 180
    private let stopThreshold: CGFloat = -100

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background track for swipe
                Capsule()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: buttonSize + 40, height: buttonSize / 2)
                    .overlay(alignment: .leading) {
                        HStack {
                            Image(systemName: "stop.fill")
                                .font(.title2)
                                .foregroundStyle(.red.opacity(0.6))
                                .padding(.leading, 20)
                            Spacer()
                        }
                    }
                    .opacity(dragOffset < -20 ? 1 : 0)

                // Main button
                Button(action: onPauseResume) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: buttonSize, height: buttonSize)
                            .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.15), radius: 10, y: 5)

                        Circle()
                            .fill(isPaused ? AppColors.startButton.opacity(0.9) : AppColors.warning.opacity(0.9))
                            .frame(width: buttonSize - 20, height: buttonSize - 20)

                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.white)
                    }
                }
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width < 0 {
                                dragOffset = value.translation.width
                            }
                        }
                        .onEnded { _ in
                            if dragOffset < stopThreshold {
                                withAnimation(.spring()) {
                                    dragOffset = 0
                                }
                                showingStopOptions = true
                            } else {
                                withAnimation(.spring()) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
            }

            Text(isPaused ? "Tap to Resume" : "Tap to Pause")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            Text("Swipe left to End")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .confirmationDialog("End Session", isPresented: $showingStopOptions, titleVisibility: .visible) {
            Button("Save") {
                onStop()
            }
            Button("Discard", role: .destructive) {
                onDiscard()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to save or discard this session?")
        }
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
                        RunningRouteMapView(session: session)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                    }

                    // Distance and time summary
                    VStack(spacing: 8) {
                        Text(session.formattedDistance)
                            .font(.system(size: 50, weight: .bold))
                            .foregroundStyle(AppColors.primary)

                        Text(session.formattedDuration)
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        Text(session.formattedPace + " /km")
                            .font(.headline)
                    }
                    .padding()

                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        RunMiniStat(title: "Avg HR", value: session.averageHeartRate > 0 ? "\(session.averageHeartRate)" : "--")
                        RunMiniStat(title: "Max HR", value: session.maxHeartRate > 0 ? "\(session.maxHeartRate)" : "--")
                        RunMiniStat(title: "Cadence", value: session.averageCadence > 0 ? "\(session.averageCadence)" : "--")
                    }
                    .padding(.horizontal)

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
                    if !session.splits.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Splits")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(session.sortedSplits) { split in
                                SplitRow(split: split)
                            }
                        }
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
                    .background(Color(.secondarySystemBackground))
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
                    .background(Color(.secondarySystemBackground))
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
                                .background(Color(.secondarySystemBackground))
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
            }
            .sheet(isPresented: $showingMediaEditor) {
                RunningMediaEditorView(session: session) {
                    hasLoadedMedia = false
                    Task {
                        await loadMedia()
                    }
                }
            }
            .sheet(item: $selectedVideo) { video in
                VideoPlayerView(asset: video)
            }
            .task {
                await loadMedia()
            }
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
}

// MARK: - Running Media Gallery

struct RunningMediaGalleryView: View {
    let session: RunningSession

    @State private var photos: [PHAsset] = []
    @State private var videos: [PHAsset] = []
    @State private var isLoading = true
    @State private var selectedPhoto: PHAsset?
    @State private var selectedVideo: PHAsset?
    @State private var photoService = RidePhotoService.shared

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
        }
        .sheet(item: $selectedVideo) { asset in
            VideoPlayerView(asset: asset)
        }
        .task {
            await loadMedia()
        }
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
                        .background(Color(.secondarySystemBackground))
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
                        .background(Color(.secondarySystemBackground))
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
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Split Row

struct SplitRow: View {
    let split: RunningSplit

    var body: some View {
        HStack {
            Text("km \(split.orderIndex + 1)")
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

            Text(split.formattedPace)
                .font(.subheadline.bold())
                .foregroundStyle(AppColors.primary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }
}

// MARK: - Running Route Map View

struct RunningRouteMapView: View {
    let session: RunningSession

    var body: some View {
        Map {
            // Route polyline
            let coordinates = session.coordinates
            if coordinates.count > 1 {
                MapPolyline(coordinates: coordinates)
                    .stroke(.blue, lineWidth: 4)
            }

            // Start marker
            if let start = coordinates.first {
                Annotation("Start", coordinate: start) {
                    Image(systemName: "flag.fill")
                        .foregroundStyle(.green)
                        .padding(6)
                        .background(.white)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
            }

            // End marker
            if let end = coordinates.last, coordinates.count > 1 {
                Annotation("End", coordinate: end) {
                    Image(systemName: "flag.checkered")
                        .foregroundStyle(.red)
                        .padding(6)
                        .background(.white)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
    }
}
