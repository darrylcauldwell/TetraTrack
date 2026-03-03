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
    let selectedLevel: CompetitionLevel
    let onStart: (RunningSetupConfig) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingCountdown = false
    @State private var showingAudioCoachingSettings = false
    @State private var fitnessMetrics: HealthKitFitnessMetrics?
    @State private var isLoadingReadiness = true
    @AppStorage("targetRunCadence") private var targetRunCadence: Int = 170
    @AppStorage("trackLapLength") private var savedTrackLength: Int = 400

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

    private var isTreadmill: Bool {
        if case .standard(.treadmill) = config.runType { return true }
        return false
    }

    private var isTrackMode: Bool {
        config.runMode == .track
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

                        // Race plan card — only for time trial mode
                        if case .standard(.timeTrial) = config.runType {
                            TetrathlonRacePlanCard(
                                competitionLevel: competitionLevel,
                                personalBests: personalBests
                            )
                        }

                        // Run readiness card
                        if HealthKitManager.shared.hasConnectedToHealthKit {
                            RunReadinessCard(fitnessMetrics: fitnessMetrics, isLoading: isLoadingReadiness)
                        }

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

                        // Mode info card — contextual description based on run mode
                        if !isTreadmill {
                            ModeInfoCard(runMode: config.runMode)
                        }

                        // Track lap length — only for track mode
                        if isTrackMode {
                            TrackLengthCard(savedTrackLength: $savedTrackLength)
                        }

                        // Target cadence — for outdoor, track, and treadmill runs
                        if !isPacer {
                            RunningCadenceCard(targetCadence: $targetRunCadence)
                        }

                        // Coaching level picker
                        CoachingLevelCard(showingSettings: $showingAudioCoachingSettings)

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
        .sheet(isPresented: $showingAudioCoachingSettings) {
            NavigationStack {
                AudioCoachingView()
            }
            .presentationBackground(Color.black)
        }
        .presentationBackground(Color.black)
        .task {
            guard HealthKitManager.shared.hasConnectedToHealthKit else { return }
            fitnessMetrics = await HealthKitManager.shared.fetchFitnessMetrics()
            isLoadingReadiness = false
        }
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
                color: config.color,
                targetCadence: targetRunCadence
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
                color: config.color,
                targetCadence: targetRunCadence
            )

        default:
            var result = config
            result.targetCadence = targetRunCadence
            result.trackLength = Double(savedTrackLength)
            return result
        }
    }
}

// MARK: - Race Plan Segment

private struct RacePlanSegment {
    let label: String
    let distanceMeters: Double
    let time: TimeInterval
    let pacePerKm: TimeInterval
    let isFinalPickup: Bool
}

// MARK: - Tetrathlon Race Plan Card

private struct TetrathlonRacePlanCard: View {
    let competitionLevel: CompetitionLevel
    let personalBests: RunningPersonalBests

    private var distance: Double { competitionLevel.runDistance }

    private var pbTime: TimeInterval {
        personalBests.personalBest(for: distance)
    }

    private var hasPB: Bool { pbTime > 0 }

    private var targetTime: TimeInterval {
        if hasPB {
            return pbTime
        }
        return PonyClubScoringService.getRunStandardTime(
            for: competitionLevel.scoringCategory,
            gender: competitionLevel.scoringGender
        )
    }

    private var standardTime: TimeInterval {
        PonyClubScoringService.getRunStandardTime(
            for: competitionLevel.scoringCategory,
            gender: competitionLevel.scoringGender
        )
    }

    private var pbPoints: Double {
        PonyClubScoringService.calculateRunningPoints(
            timeInSeconds: pbTime,
            ageCategory: competitionLevel.scoringCategory,
            gender: competitionLevel.scoringGender
        )
    }

    private var segments: [RacePlanSegment] {
        buildSegments()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: hasPB ? "trophy.fill" : "target")
                    .foregroundStyle(hasPB ? .yellow : .orange)
                Text("Race Plan")
                    .font(.headline)
            }

            // PB / Target stats
            HStack(spacing: 0) {
                // Left: time and pace
                VStack(alignment: .leading, spacing: 4) {
                    Text(hasPB ? "PB" : "Target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatTime(targetTime))
                        .font(.title3.weight(.bold).monospacedDigit())
                    Text("\(formatPace(targetTime / distance * 1000))/km")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right: points info
                VStack(alignment: .trailing, spacing: 4) {
                    if hasPB {
                        Text("\(Int(pbPoints)) pts")
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(.cyan)
                    }
                    Text("1000pts = \(formatTime(standardTime))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Strategy header
            VStack(spacing: 4) {
                Text("Negative Split Strategy")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Start controlled, finish fast")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)

            // Segment rows
            VStack(spacing: 6) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    HStack {
                        Text(segment.label)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(formatTime(segment.time))
                            .font(.subheadline.monospacedDigit())
                            .frame(width: 50, alignment: .trailing)
                        Text("\(formatPace(segment.pacePerKm))/km")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .trailing)
                        if segment.isFinalPickup {
                            Text("kick")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Cadence tip
            let finalDistance = segments.last?.distanceMeters ?? 0
            HStack(spacing: 6) {
                Image(systemName: "hare.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("Pick up cadence for the final \(Int(finalDistance))m")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    // MARK: - Segment Calculation

    private func buildSegments() -> [RacePlanSegment] {
        let evenPacePerMeter = targetTime / distance
        let lapDistance: Double = 400

        // Determine full conservative laps and final segment
        let fullLaps: Int
        let finalSegmentDistance: Double

        switch Int(distance) {
        case 1000:
            fullLaps = 2
            finalSegmentDistance = 200
        case 1500:
            fullLaps = 3
            finalSegmentDistance = 300
        case 2000:
            // 5 laps total, first 4 conservative, last lap is pickup
            fullLaps = 4
            finalSegmentDistance = 400
        case 3000:
            fullLaps = 7
            finalSegmentDistance = 200
        default:
            fullLaps = max(1, Int(distance / lapDistance) - 1)
            finalSegmentDistance = distance - Double(fullLaps) * lapDistance
        }

        // Conservative laps at 1.5% slower than even pace
        let conservativeLapTime = evenPacePerMeter * lapDistance * 1.015
        let conservativePacePerKm = conservativeLapTime / lapDistance * 1000

        // Final segment gets remaining time
        let totalConservativeTime = Double(fullLaps) * conservativeLapTime
        let finalTime = targetTime - totalConservativeTime
        let finalPacePerKm = finalTime / finalSegmentDistance * 1000

        var result: [RacePlanSegment] = []

        for i in 1...fullLaps {
            result.append(RacePlanSegment(
                label: "Lap \(i) (400m)",
                distanceMeters: lapDistance,
                time: conservativeLapTime,
                pacePerKm: conservativePacePerKm,
                isFinalPickup: false
            ))
        }

        let finalLabel: String
        if Int(distance) == 2000 {
            finalLabel = "Lap 5 (400m)"
        } else {
            finalLabel = "Final (\(Int(finalSegmentDistance))m)"
        }

        result.append(RacePlanSegment(
            label: finalLabel,
            distanceMeters: finalSegmentDistance,
            time: finalTime,
            pacePerKm: finalPacePerKm,
            isFinalPickup: true
        ))

        return result
    }

    // MARK: - Formatting

    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatPace(_ pace: TimeInterval) -> String {
        let mins = Int(pace) / 60
        let secs = Int(pace) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Mode Info Card

private struct ModeInfoCard: View {
    let runMode: RunningMode

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: runMode == .track ? "circle.dashed" : "location.fill")
                    .foregroundStyle(runMode == .track ? .cyan : .blue)
                    .frame(width: 20)
                Text(runMode == .track ? "Track Mode" : "GPS Mode")
                    .font(.subheadline.weight(.medium))
            }

            if runMode == .track {
                VStack(alignment: .leading, spacing: 6) {
                    featureRow(icon: "mappin.circle", text: "Start position recorded from first GPS fix")
                    featureRow(icon: "arrow.circlepath", text: "Laps detected automatically when you pass the start line")
                    featureRow(icon: "speaker.wave.2", text: "Audio announces each lap time with comparison")
                    featureRow(icon: "chart.line.uptrend.xyaxis", text: "Live lap split chart after 2 laps")
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    featureRow(icon: "map", text: "Live route displayed on map")
                    featureRow(icon: "location.fill", text: "Real-time distance, pace, and speed")
                    featureRow(icon: "point.bottomleft.forward.to.point.topright.scurvepath", text: "Speed-coloured route segments")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    private func featureRow(icon: String, text: String) -> some View {
        Label {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(width: 16)
        }
    }
}

// MARK: - Track Length Card

private struct TrackLengthCard: View {
    @Binding var savedTrackLength: Int

    private enum TrackLengthMode {
        case preset200, preset400, custom
    }

    private var mode: TrackLengthMode {
        switch savedTrackLength {
        case 200: return .preset200
        case 400: return .preset400
        default: return .custom
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "ruler")
                    .foregroundStyle(.cyan)
                Text("Lap Length")
                    .font(.headline)
            }

            // Preset buttons
            HStack(spacing: 10) {
                presetButton("200m", value: 200, selected: mode == .preset200)
                presetButton("400m", value: 400, selected: mode == .preset400)
                presetButton("Custom", value: nil, selected: mode == .custom)
            }

            // Custom stepper — shown when not a preset
            if mode == .custom {
                HStack {
                    Text("\(savedTrackLength)m")
                        .font(.system(.title3, design: .rounded))
                        .monospacedDigit()
                        .bold()

                    Spacer()

                    Stepper("", value: $savedTrackLength, in: 100...2000, step: 50)
                        .labelsHidden()
                }
            }

            Text("Laps auto-detected when you pass the start line")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    private func presetButton(_ label: String, value: Int?, selected: Bool) -> some View {
        Button {
            if let value {
                savedTrackLength = value
            } else {
                // Switch to custom — keep current value if already custom, else default to 500
                if savedTrackLength == 200 || savedTrackLength == 400 {
                    savedTrackLength = 500
                }
            }
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? Color.cyan.opacity(0.2) : Color.white.opacity(0.08))
                .foregroundStyle(selected ? .cyan : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(selected ? Color.cyan.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Running Cadence Card

private struct RunningCadenceCard: View {
    @Binding var targetCadence: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "metronome")
                    .foregroundStyle(.blue)
                Text("Target Cadence")
                    .font(.headline)
                Text("Optional")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("\(targetCadence) SPM")
                    .font(.system(.title3, design: .rounded))
                    .monospacedDigit()
                    .bold()

                Spacer()

                Stepper("", value: $targetCadence, in: 140...210, step: 5)
                    .labelsHidden()
            }

            Text("Most runners benefit from 170–180 SPM. Higher cadence reduces impact.")
                .font(.caption)
                .foregroundStyle(.secondary)
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

// MARK: - Coaching Level Card

struct CoachingLevelCard: View {
    @Binding var showingSettings: Bool
    private var audioCoach: AudioCoachManager { AudioCoachManager.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: audioCoach.runningCoachingLevel.icon)
                    .foregroundStyle(.blue)
                    .frame(width: 20)
                Text("Voice Coaching")
                    .font(.subheadline.weight(.medium))
            }

            Picker("Level", selection: Binding(
                get: { audioCoach.runningCoachingLevel },
                set: { audioCoach.applyRunningCoachingLevel($0) }
            )) {
                ForEach(RunningCoachingLevel.allCases) { level in
                    Text(level.displayName).tag(level)
                }
            }
            .pickerStyle(.segmented)

            Text(audioCoach.runningCoachingLevel.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                showingSettings = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption2)
                    Text("Customise in Settings")
                        .font(.caption)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
}

// MARK: - Watch Status Card

/// Shows Apple Watch connection state with guidance for running sessions.
struct WatchStatusCard: View {
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
                        AccessibleStatusIndicator(.standby, size: .small)
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
            Text("Watch will connect automatically when you start your session.")
                .font(.caption)
                .foregroundStyle(.secondary)
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

// MARK: - Run Readiness Card

private enum InsightSeverity: Int, Comparable {
    case positive = 0
    case neutral = 1
    case caution = 2
    case warning = 3

    static func < (lhs: InsightSeverity, rhs: InsightSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

private struct RunReadinessInsight {
    let icon: String
    let text: String
    let severity: InsightSeverity
}

private struct RunReadinessCard: View {
    let fitnessMetrics: HealthKitFitnessMetrics?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.secondary)
                    Text("Checking readiness...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else if let metrics = fitnessMetrics, metrics.hasRecoveryData {
                // Header
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "gauge.with.dots.needle.33percent")
                            .foregroundStyle(.cyan)
                        Text("Run Readiness")
                            .font(.headline)
                    }
                    Spacer()
                    if let score = metrics.trainingReadinessScore {
                        Text("\(score)")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(readinessColor(score))
                    }
                }

                // Metric pills
                metricPills(metrics)

                // Insights
                let insights = generateRunningInsights(metrics)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(insights.enumerated()), id: \.offset) { _, insight in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: insight.icon)
                                .font(.caption)
                                .foregroundStyle(severityColor(insight.severity))
                                .frame(width: 16, alignment: .center)
                            Text(insight.text)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else {
                // No data state
                HStack(spacing: 8) {
                    Image(systemName: "gauge.with.dots.needle.33percent")
                        .foregroundStyle(.secondary)
                    Text("Run Readiness")
                        .font(.headline)
                }
                Text("Wear Apple Watch overnight for recovery insights")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    // MARK: - Metric Pills

    @ViewBuilder
    private func metricPills(_ metrics: HealthKitFitnessMetrics) -> some View {
        HStack(spacing: 0) {
            if let rhr = metrics.restingHeartRate {
                metricPill(icon: "heart.fill", value: "\(rhr)", unit: "bpm", color: rhrColor(rhr))
            }
            if let hrv = metrics.heartRateVariability {
                metricPill(icon: "waveform.path.ecg", value: "\(Int(hrv))", unit: "ms", color: hrvColor(hrv))
            }
            if let sleep = metrics.lastNightSleep {
                metricPill(icon: "moon.fill", value: String(format: "%.1f", sleep.totalSleepHours), unit: "h", color: .purple)
            }
        }
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func metricPill(icon: String, value: String, unit: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Insight Generation

    private func generateRunningInsights(_ metrics: HealthKitFitnessMetrics) -> [RunReadinessInsight] {
        var insights: [RunReadinessInsight] = []
        var sleepConsumed = false
        var hrvConsumed = false
        var rhrTrendConsumed = false

        let hrv = metrics.heartRateVariability
        let sleep = metrics.lastNightSleep
        let rhrTrend = metrics.restingHeartRateTrend

        // Compound rules
        if let hrv, let sleep, hrv < 20 && sleep.totalSleepHours < 5.5 {
            insights.append(RunReadinessInsight(
                icon: "exclamationmark.triangle.fill",
                text: "HRV and sleep both poor — strongly consider rest or very easy shakeout",
                severity: .warning
            ))
            sleepConsumed = true
            hrvConsumed = true
        }

        if !hrvConsumed || !rhrTrendConsumed {
            let trendDelta = rhrTrendDelta(rhrTrend)
            if let delta = trendDelta, let hrv, delta > 5 && hrv < 35 && !hrvConsumed {
                insights.append(RunReadinessInsight(
                    icon: "exclamationmark.triangle.fill",
                    text: "Accumulated fatigue — HR trending up while recovery suppressed, easy pace only",
                    severity: .warning
                ))
                hrvConsumed = true
                rhrTrendConsumed = true
            }
        }

        if !sleepConsumed && !hrvConsumed {
            if let sleep, let hrv, sleep.totalSleepHours >= 7.5 && sleep.deepHours >= 1.0 && hrv >= 50 {
                insights.append(RunReadinessInsight(
                    icon: "checkmark.seal.fill",
                    text: "Recovery signals all green — primed for a quality session",
                    severity: .positive
                ))
                sleepConsumed = true
                hrvConsumed = true
            }
        }

        // Sleep rules (at most one, priority order)
        if !sleepConsumed, let sleep {
            if sleep.totalSleepHours < 5.5 {
                insights.append(RunReadinessInsight(
                    icon: "moon.zzz.fill",
                    text: "Poor sleep — consider easy effort only, injury risk elevated",
                    severity: .warning
                ))
            } else if sleep.deepHours < 0.5 {
                insights.append(RunReadinessInsight(
                    icon: "bed.double.fill",
                    text: "Minimal deep sleep — high asymmetry risk, shorten intensity blocks",
                    severity: .warning
                ))
            } else if sleep.totalSleepHours < 6.5 {
                insights.append(RunReadinessInsight(
                    icon: "moon.zzz.fill",
                    text: "Short sleep — warm up longer, RPE will feel 1-2 points higher",
                    severity: .caution
                ))
            } else if sleep.deepHours < 1.0 {
                insights.append(RunReadinessInsight(
                    icon: "bed.double.fill",
                    text: "Low deep sleep — cadence may drift, focus on form cues",
                    severity: .caution
                ))
            } else if sleep.deepHours >= 1.5 {
                insights.append(RunReadinessInsight(
                    icon: "bed.double.fill",
                    text: "Strong deep sleep — expect good cadence consistency and form stability",
                    severity: .positive
                ))
            } else if sleep.totalSleepHours >= 8.0 {
                insights.append(RunReadinessInsight(
                    icon: "moon.zzz.fill",
                    text: "Well rested — full intensity is on the table",
                    severity: .positive
                ))
            } else if sleep.remHours < 0.5 {
                insights.append(RunReadinessInsight(
                    icon: "brain.head.profile",
                    text: "Low REM sleep — reaction time slower, watch footing on trails",
                    severity: .caution
                ))
            }
        }

        // HRV rules (at most one)
        if !hrvConsumed, let hrv {
            if hrv >= 50 {
                insights.append(RunReadinessInsight(
                    icon: "waveform.path.ecg",
                    text: "HRV in excellent range — body well recovered for quality training",
                    severity: .positive
                ))
            } else if hrv < 20 {
                insights.append(RunReadinessInsight(
                    icon: "waveform.path.ecg",
                    text: "HRV very low — keep effort conversational",
                    severity: .warning
                ))
            } else if hrv < 35 {
                insights.append(RunReadinessInsight(
                    icon: "waveform.path.ecg",
                    text: "HRV below typical — expect faster fatigue in the second half",
                    severity: .caution
                ))
            }
            // 35-49 = normal, no insight
        }

        // RHR trend rules (at most one, requires ≥ 3 data points)
        if !rhrTrendConsumed {
            if let delta = rhrTrendDelta(rhrTrend) {
                if delta < -3 {
                    insights.append(RunReadinessInsight(
                        icon: "heart.text.square",
                        text: "Resting HR trending down — good day for progression",
                        severity: .positive
                    ))
                } else if delta > 5 {
                    insights.append(RunReadinessInsight(
                        icon: "heart.text.square",
                        text: "Resting HR significantly elevated — reduce volume, monitor for illness",
                        severity: .warning
                    ))
                } else if delta >= 3 {
                    insights.append(RunReadinessInsight(
                        icon: "heart.text.square",
                        text: "Resting HR creeping up — add extra warm-up time",
                        severity: .caution
                    ))
                }
                // -3 to +3 = stable, no insight
            }
        }

        // Sort by severity descending (warning first)
        insights.sort { $0.severity > $1.severity }

        // Limit to 3
        if insights.count > 3 {
            insights = Array(insights.prefix(3))
        }

        // Fallback if no insights generated
        if insights.isEmpty {
            insights.append(RunReadinessInsight(
                icon: "checkmark.circle",
                text: "Recovery metrics in normal range — train as planned",
                severity: .neutral
            ))
        }

        return insights
    }

    // MARK: - RHR Trend Delta

    private func rhrTrendDelta(_ trend: [Date: Int]) -> Double? {
        guard trend.count >= 3 else { return nil }
        let sorted = trend.sorted { $0.key < $1.key }
        let recentCount = min(3, sorted.count)
        let oldestCount = min(3, sorted.count)
        let recentAvg = Double(sorted.suffix(recentCount).map(\.value).reduce(0, +)) / Double(recentCount)
        let oldestAvg = Double(sorted.prefix(oldestCount).map(\.value).reduce(0, +)) / Double(oldestCount)
        return recentAvg - oldestAvg
    }

    // MARK: - Color Helpers

    private func readinessColor(_ score: Int) -> Color {
        switch score {
        case 85...100: return .green
        case 70..<85: return .blue
        case 55..<70: return .yellow
        case 40..<55: return .orange
        default: return .red
        }
    }

    private func hrvColor(_ hrv: Double) -> Color {
        switch hrv {
        case 50...: return .green
        case 35..<50: return .blue
        case 20..<35: return .yellow
        default: return .red
        }
    }

    private func rhrColor(_ rhr: Int) -> Color {
        switch rhr {
        case ..<60: return .green
        case 60..<70: return .blue
        case 70..<80: return .yellow
        default: return .orange
        }
    }

    private func severityColor(_ severity: InsightSeverity) -> Color {
        switch severity {
        case .positive: return .green
        case .neutral: return .blue
        case .caution: return .orange
        case .warning: return .red
        }
    }
}

