//
//  RunningSetupSheet.swift
//  TetraTrack
//
//  Pre-session setup sheet for running — mode picker, interval/pacer config,
//  phone placement, sensor mode, and a big start button.
//

import SwiftUI
import SwiftData

struct RunningSetupSheet: View {
    let config: RunningSetupConfig
    @Binding var trackMode: Bool
    let selectedLevel: CompetitionLevel
    let onStart: (RunningSetupConfig) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingCountdown = false

    // Interval state
    @State private var intervalSettings = IntervalSettings()
    @State private var workMinutes: Int = 1
    @State private var workSeconds: Int = 0
    @State private var restMinutes: Int = 1
    @State private var restSeconds: Int = 30

    // Pacer state
    @State private var pacerSettings = PacerSettings()
    @State private var pacerMode: PacerMode = .targetPace
    @State private var paceMinutes: Int = 5
    @State private var paceSeconds: Int = 0
    @State private var targetDistanceKm: Double = 5.0
    @State private var targetTimeMinutes: Int = 25
    @State private var targetTimeSeconds: Int = 0
    @AppStorage("selectedCompetitionLevel") private var competitionLevelRaw: String = CompetitionLevel.junior.rawValue
    @AppStorage("runningPhonePlacement") private var phonePlacementRaw: String = RunningPhonePlacement.shortsThigh.rawValue

    private var isTreadmill: Bool {
        if case .standard(.treadmill) = config.runType { return true }
        return false
    }

    private var isInterval: Bool {
        if case .interval = config.runType { return true }
        return false
    }

    private var isPacer: Bool {
        if case .pacer = config.runType { return true }
        return false
    }

    private var competitionLevel: CompetitionLevel {
        CompetitionLevel(rawValue: competitionLevelRaw) ?? .junior
    }

    private var personalBests: RunningPersonalBests { RunningPersonalBests.shared }

    private var pbPace: TimeInterval? {
        let pb = personalBests.personalBest(for: competitionLevel.runDistance)
        guard pb > 0 else { return nil }
        return (pb / competitionLevel.runDistance) * 1000
    }

    private var hasPB: Bool {
        personalBests.personalBest(for: competitionLevel.runDistance) > 0
    }

    private var startDisabled: Bool {
        isPacer && pacerMode == .racePB && !hasPB
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                ScrollView {
                    VStack(spacing: 32) {
                        // Discipline icon + title
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(config.color.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                Image(systemName: config.icon)
                                    .font(.system(size: 36))
                                    .foregroundStyle(config.color)
                            }
                            Text(config.title)
                                .font(.title2.bold())
                            if case .standard(.timeTrial) = config.runType {
                                Text(selectedLevel.formattedRunDistance)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 8)

                        // Start button
                        Button {
                            showingCountdown = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(startDisabled ? Color.gray : AppColors.primary)
                                    .frame(width: 80, height: 80)
                                    .shadow(color: (startDisabled ? Color.gray : AppColors.primary).opacity(0.4), radius: 12, y: 4)
                                Image(systemName: "play.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.white)
                            }
                        }
                        .disabled(startDisabled)

                        // Watch status card — only when a watch is paired
                        if WatchConnectivityManager.shared.isPaired {
                            WatchStatusCard()
                                .padding(.horizontal, 20)
                        }

                        // Mode picker (GPS / Track) — not shown for treadmill
                        if !isTreadmill {
                            ModePickerCard(trackMode: $trackMode)
                        }

                        // Interval config — only for interval sessions
                        if isInterval {
                            IntervalConfigCard(
                                settings: $intervalSettings,
                                workMinutes: $workMinutes,
                                workSeconds: $workSeconds,
                                restMinutes: $restMinutes,
                                restSeconds: $restSeconds
                            )
                        }

                        // Pacer config — only for pacer sessions
                        if isPacer {
                            PacerConfigCard(
                                pacerMode: $pacerMode,
                                paceMinutes: $paceMinutes,
                                paceSeconds: $paceSeconds,
                                targetDistanceKm: $targetDistanceKm,
                                targetTimeMinutes: $targetTimeMinutes,
                                targetTimeSeconds: $targetTimeSeconds,
                                competitionLevel: competitionLevel,
                                personalBests: personalBests,
                                hasPB: hasPB,
                                pbPace: pbPace
                            )
                        }

                        // Phone placement picker
                        RunningPhonePlacementPicker(selectedPlacement: $phonePlacementRaw)
                            .padding(.horizontal, 20)

                        // Sensor mode (pocket mode)
                        SensorModeCard(pocketModeManager: PocketModeManager.shared)
                            .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .fullScreenCover(isPresented: $showingCountdown) {
            CountdownOverlay(
                onComplete: {
                    showingCountdown = false
                    onStart(buildFinalConfig())
                },
                onCancel: {
                    showingCountdown = false
                }
            )
            .presentationBackground(.clear)
        }
        .presentationBackground(Color.black)
    }

    // MARK: - Build Final Config

    private func buildFinalConfig() -> RunningSetupConfig {
        switch config.runType {
        case .interval:
            var settings = intervalSettings
            settings.workDuration = TimeInterval(workMinutes * 60 + workSeconds)
            settings.restDuration = TimeInterval(restMinutes * 60 + restSeconds)
            return RunningSetupConfig(
                runType: .interval(settings),
                title: config.title,
                icon: config.icon,
                color: config.color
            )

        case .pacer:
            var settings = pacerSettings
            switch pacerMode {
            case .targetTime:
                settings.targetDistance = targetDistanceKm * 1000
                settings.targetTime = TimeInterval(targetTimeMinutes * 60 + targetTimeSeconds)
                settings.targetPace = targetDistanceKm > 0
                    ? TimeInterval(targetTimeMinutes * 60 + targetTimeSeconds) / targetDistanceKm
                    : 300
                settings.useTargetTime = true
                settings.usePBPace = false
            case .racePB:
                if let pace = pbPace {
                    settings.targetPace = pace
                    settings.targetDistance = competitionLevel.runDistance
                    settings.targetTime = personalBests.personalBest(for: competitionLevel.runDistance)
                    settings.useTargetTime = true
                    settings.usePBPace = true
                }
            case .targetPace:
                settings.targetPace = TimeInterval(paceMinutes * 60 + paceSeconds)
                settings.useTargetTime = false
                settings.usePBPace = false
            }
            return RunningSetupConfig(
                runType: .pacer(settings),
                title: config.title,
                icon: config.icon,
                color: config.color
            )

        default:
            return config
        }
    }
}

// MARK: - Mode Picker Card

private struct ModePickerCard: View {
    @Binding var trackMode: Bool

    var body: some View {
        HStack {
            Text("Mode")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Picker("Mode", selection: $trackMode) {
                Label("GPS", systemImage: "location.fill").tag(false)
                Label("Track", systemImage: "circle.dashed").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
}

// MARK: - Interval Config Card

private struct IntervalConfigCard: View {
    @Binding var settings: IntervalSettings
    @Binding var workMinutes: Int
    @Binding var workSeconds: Int
    @Binding var restMinutes: Int
    @Binding var restSeconds: Int

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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Label("Interval Settings", systemImage: "timer")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)

            // Number of intervals
            HStack {
                Text("Intervals")
                    .font(.subheadline)
                Spacer()
                Stepper("\(settings.numberOfIntervals)", value: $settings.numberOfIntervals, in: 1...20)
                    .frame(width: 140)
            }

            Divider().overlay(Color.white.opacity(0.1))

            // Work duration
            HStack {
                Text("Work")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                Spacer()
                DurationWheelPicker(minutes: $workMinutes, seconds: $workSeconds)
            }

            // Rest duration
            HStack {
                Text("Rest")
                    .font(.subheadline)
                    .foregroundStyle(.green)
                Spacer()
                DurationWheelPicker(minutes: $restMinutes, seconds: $restSeconds)
            }

            Divider().overlay(Color.white.opacity(0.1))

            // Warmup / Cooldown
            Toggle("Warmup (5 min)", isOn: $settings.includeWarmup)
                .font(.subheadline)
            Toggle("Cooldown (5 min)", isOn: $settings.includeCooldown)
                .font(.subheadline)

            Divider().overlay(Color.white.opacity(0.1))

            // Summary
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        Text("Work \(workMinutes):\(String(format: "%02d", workSeconds))")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text("Rest \(restMinutes):\(String(format: "%02d", restSeconds))")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("\(settings.numberOfIntervals)x")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(formattedTotalTime)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppColors.primary)
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
}

// MARK: - Pacer Config Card

private struct PacerConfigCard: View {
    @Binding var pacerMode: PacerMode
    @Binding var paceMinutes: Int
    @Binding var paceSeconds: Int
    @Binding var targetDistanceKm: Double
    @Binding var targetTimeMinutes: Int
    @Binding var targetTimeSeconds: Int
    let competitionLevel: CompetitionLevel
    let personalBests: RunningPersonalBests
    let hasPB: Bool
    let pbPace: TimeInterval?

    private var calculatedPaceFromTarget: TimeInterval {
        let totalSeconds = TimeInterval(targetTimeMinutes * 60 + targetTimeSeconds)
        guard targetDistanceKm > 0 else { return 300 }
        return totalSeconds / targetDistanceKm
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Label("Pacer Settings", systemImage: "person.line.dotted.person.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.cyan)

            // Mode picker
            Picker("Mode", selection: $pacerMode) {
                ForEach(PacerMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // Mode-specific content
            switch pacerMode {
            case .targetPace:
                targetPaceContent

            case .targetTime:
                targetTimeContent

            case .racePB:
                racePBContent
            }

            Divider().overlay(Color.white.opacity(0.1))

            // Summary
            pacerSummary
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    // MARK: - Target Pace

    @ViewBuilder
    private var targetPaceContent: some View {
        HStack {
            Text("Target Pace")
                .font(.subheadline)
            Spacer()
            DurationWheelPicker(minutes: $paceMinutes, seconds: $paceSeconds, minuteRange: 2..<15)
        }

        // Preset paces
        VStack(alignment: .leading, spacing: 8) {
            Text("Presets")
                .font(.caption)
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 8) {
                ForEach(PacePreset.presets) { preset in
                    Button {
                        paceMinutes = Int(preset.pacePerKm) / 60
                        paceSeconds = Int(preset.pacePerKm) % 60
                    } label: {
                        Text("\(preset.name) \(preset.formattedPace)")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Target Time

    @ViewBuilder
    private var targetTimeContent: some View {
        HStack {
            Text("Distance")
                .font(.subheadline)
            Spacer()
            Picker("Distance", selection: $targetDistanceKm) {
                ForEach([1.0, 2.0, 3.0, 5.0, 10.0, 15.0, 21.1], id: \.self) { km in
                    Text(km == 21.1 ? "Half Marathon" : "\(Int(km)) km").tag(km)
                }
            }
            .pickerStyle(.menu)
            .tint(.cyan)
        }

        HStack {
            Text("Target Time")
                .font(.subheadline)
            Spacer()
            DurationWheelPicker(minutes: $targetTimeMinutes, seconds: $targetTimeSeconds, minuteRange: 0..<120)
        }

        HStack {
            Text("Required Pace")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(formatPace(calculatedPaceFromTarget))/km")
                .font(.caption.weight(.medium))
                .foregroundStyle(.cyan)
        }
    }

    // MARK: - Race PB

    @ViewBuilder
    private var racePBContent: some View {
        if hasPB, let pace = pbPace {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.yellow)
                    Text("Race Your Personal Best")
                        .font(.subheadline.weight(.medium))
                }

                HStack {
                    Text("Distance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(competitionLevel.formattedRunDistance)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.cyan)
                }

                HStack {
                    Text("Your PB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(personalBests.formattedPB(for: competitionLevel.runDistance))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.yellow)
                }

                HStack {
                    Text("PB Pace")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(formatPace(pace))/km")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                }
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title3)
                    .foregroundStyle(.orange)
                Text("No PB Set")
                    .font(.subheadline.weight(.medium))
                Text("Set your \(competitionLevel.formattedRunDistance) PB in Settings to use this feature.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Summary

    @ViewBuilder
    private var pacerSummary: some View {
        HStack {
            Image(systemName: "speaker.wave.2.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Audio coaching tells you if you're ahead or behind pace")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        switch pacerMode {
        case .targetPace:
            HStack {
                Text("Target Pace")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(paceMinutes):\(String(format: "%02d", paceSeconds))/km")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.cyan)
            }
        case .targetTime:
            HStack {
                Text("Goal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(String(format: "%.1f", targetDistanceKm)) km in \(targetTimeMinutes):\(String(format: "%02d", targetTimeSeconds))")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.cyan)
            }
        case .racePB:
            if let pace = pbPace {
                HStack {
                    Text("PB Pace")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(formatPace(pace))/km")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.yellow)
                }
            }
        }
    }

    private func formatPace(_ pace: TimeInterval) -> String {
        let mins = Int(pace) / 60
        let secs = Int(pace) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Duration Wheel Picker

private struct DurationWheelPicker: View {
    @Binding var minutes: Int
    @Binding var seconds: Int
    var minuteRange: Range<Int> = 0..<10

    var body: some View {
        HStack(spacing: 2) {
            Picker("", selection: $minutes) {
                ForEach(minuteRange, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(width: 44, height: 90)
            .clipped()

            Text(":")
                .font(.subheadline)

            Picker("", selection: $seconds) {
                ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(width: 44, height: 90)
            .clipped()
        }
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

// MARK: - Watch Status Card

/// Shows Apple Watch connection state with guidance for running sessions.
private struct WatchStatusCard: View {
    private var watchConnectivity: WatchConnectivityManager { WatchConnectivityManager.shared }

    private var isConnected: Bool {
        watchConnectivity.isPaired && watchConnectivity.isWatchAppInstalled && watchConnectivity.isReachable
    }

    private var isAppNotInstalled: Bool {
        watchConnectivity.isPaired && !watchConnectivity.isWatchAppInstalled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
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
                        AccessibleStatusIndicator(.warning, size: .small)
                    }
                }

                Spacer()

                if isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.success)
                }
            }

            // State-specific content
            if isConnected {
                connectedContent
            } else if isAppNotInstalled {
                appNotInstalledContent
            } else {
                notReachableContent
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Connected

    @ViewBuilder
    private var connectedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Enhanced metrics from your watch:")
                .font(.caption)
                .foregroundStyle(.secondary)

            WatchMetricRow(icon: "heart.fill", text: "Real-time heart rate", color: .red)
            WatchMetricRow(icon: "figure.run", text: "Cadence & stride length", color: .orange)
            WatchMetricRow(icon: "arrow.up.arrow.down", text: "Vertical oscillation", color: .cyan)
            WatchMetricRow(icon: "shoe.fill", text: "Ground contact time", color: .green)
        }
    }

    // MARK: - Not Reachable

    @ViewBuilder
    private var notReachableContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Raise your wrist or open TetraTrack on your watch to connect.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("The watch will connect automatically when you start your run.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }

        VStack(alignment: .leading, spacing: 6) {
            Text("Once connected you'll get:")
                .font(.caption)
                .foregroundStyle(.secondary)

            WatchMetricRow(icon: "heart.fill", text: "Real-time heart rate", color: .red)
            WatchMetricRow(icon: "figure.run", text: "Cadence & stride length", color: .orange)
            WatchMetricRow(icon: "arrow.up.arrow.down", text: "Vertical oscillation", color: .cyan)
            WatchMetricRow(icon: "shoe.fill", text: "Ground contact time", color: .green)
        }
    }

    // MARK: - App Not Installed

    @ViewBuilder
    private var appNotInstalledContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Install TetraTrack on your Apple Watch to unlock enhanced running metrics.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Open the Watch app on your iPhone to install.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

private struct WatchMetricRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
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

// MARK: - Running Phone Placement Picker

/// Interactive phone placement picker that configures motion analysis thresholds
struct RunningPhonePlacementPicker: View {
    @Binding var selectedPlacement: String

    private var placement: RunningPhonePlacement {
        RunningPhonePlacement(rawValue: selectedPlacement) ?? .shortsThigh
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "iphone")
                    .font(.title3)
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Phone Placement")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Adjusts cadence and impact detection")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(RunningPhonePlacement.allCases) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPlacement = option.rawValue
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: option.icon)
                            .font(.body)
                            .foregroundStyle(option == placement ? AppColors.primary : .secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(option.displayName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                if option.isRecommended {
                                    Text("Recommended")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(option.accuracyHint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if option == placement {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppColors.primary)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(AppColors.primary)
                Text("Secure the phone firmly — bouncing adds noise")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
