//
//  RunningStopwatchView.swift
//  TetraTrack
//
//  Parent-focused stopwatch for timing the child's run at competition
//

import SwiftUI
import Charts
import CoreLocation

struct RunningStopwatchView: View {
    @Bindable var competition: Competition
    let onDismiss: () -> Void

    enum EntryMode { case choose, stopwatch, manual }
    @State private var entryMode: EntryMode = .choose

    // Timer state
    @State private var isRunning = false
    @State private var hasFinished = false
    @State private var startDate: Date?
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    // Manual entry
    @State private var manualMinutes: String = ""
    @State private var manualSeconds: String = ""

    // Lap splits
    @State private var lapTimes: [TimeInterval] = []
    @State private var showResetConfirmation = false

    private var runDistance: Double {
        competition.level.runDistance
    }

    private var expectedLaps: Int {
        // Typical 400m track
        max(1, Int(runDistance / 400))
    }

    /// Per-lap split times (intervals between consecutive laps)
    private var lapSplits: [TimeInterval] {
        var splits: [TimeInterval] = []
        for i in 0..<lapTimes.count {
            if i == 0 {
                splits.append(lapTimes[i])
            } else {
                splits.append(lapTimes[i] - lapTimes[i - 1])
            }
        }
        return splits
    }

    private var calculatedPoints: Double? {
        guard elapsedTime > 0, hasFinished else { return nil }
        return PonyClubScoringService.calculateRunningPoints(
            timeInSeconds: elapsedTime,
            ageCategory: competition.level.scoringCategory,
            gender: competition.level.scoringGender
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Check for existing result
                    if let time = competition.runningTime, time > 0 {
                        existingResultView(time: time)
                    } else {
                        switch entryMode {
                        case .choose:
                            chooseEntryMode
                        case .stopwatch:
                            infoHeader
                            timerDisplay
                            if !hasFinished {
                                controlButtons
                            } else {
                                resultsSection
                            }
                            if !lapTimes.isEmpty { lapSplitsSection }
                            if lapSplits.count >= 2 { paceChartSection }
                        case .manual:
                            manualEntryView
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Running")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onDismiss() }
                }
            }
            .onChange(of: isRunning) { _, newValue in
                UIApplication.shared.isIdleTimerDisabled = newValue
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
            .confirmationDialog("Reset Stopwatch?", isPresented: $showResetConfirmation) {
                Button("Reset", role: .destructive) { resetStopwatch() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will clear the current time and lap splits.")
            }
        }
    }

    // MARK: - Info Header

    private var infoHeader: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(competition.level.displayName)
                    .font(.subheadline.bold())
                Text(competition.level.formattedRunDistance)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if expectedLaps > 1 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(expectedLaps) laps")
                        .font(.subheadline.bold())
                    Text("400m track")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Timer Display

    private var timerDisplay: some View {
        VStack(spacing: 8) {
            Text(formatElapsedTime(elapsedTime))
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isRunning ? AppColors.primary : .primary)

            if isRunning && !lapTimes.isEmpty {
                let currentLapTime = elapsedTime - (lapTimes.last ?? 0)
                Text("Lap \(lapTimes.count + 1): \(formatElapsedTime(currentLapTime))")
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 16)
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: 24) {
            if isRunning {
                // Lap button
                Button {
                    recordLap()
                } label: {
                    Text("Lap")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 100, height: 100)
                        .background(Color.blue)
                        .clipShape(Circle())
                }

                // Stop button
                Button {
                    stopStopwatch()
                } label: {
                    Text("Stop")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 200, height: 200)
                        .background(Color.red)
                        .clipShape(Circle())
                }
            } else if elapsedTime > 0 {
                // Reset button
                Button {
                    showResetConfirmation = true
                } label: {
                    Text("Reset")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 100, height: 100)
                        .background(Color.gray)
                        .clipShape(Circle())
                }

                // Resume / Done
                Button {
                    hasFinished = true
                    saveResults()
                } label: {
                    Text("Done")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 200, height: 200)
                        .background(Color.green)
                        .clipShape(Circle())
                }
            } else {
                // Start button
                Button {
                    startStopwatch()
                } label: {
                    Text("Start")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 200, height: 200)
                        .background(Color.green)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Start running stopwatch")
            }
        }
        .sensoryFeedback(.impact, trigger: isRunning)
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Final Time")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(formatElapsedTime(elapsedTime))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

            if let points = calculatedPoints {
                VStack(spacing: 2) {
                    Text(String(format: "%.0f", points))
                        .font(.title.bold())
                        .foregroundStyle(AppColors.primary)
                    Text("points")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                Button {
                    showResetConfirmation = true
                } label: {
                    Label("Redo", systemImage: "arrow.counterclockwise")
                        .font(.headline)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    onDismiss()
                } label: {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Lap Splits

    private var lapSplitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lap Splits")
                .font(.headline)

            ForEach(Array(lapSplits.enumerated()), id: \.offset) { index, split in
                HStack {
                    Text("Lap \(index + 1)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(formatElapsedTime(split))
                        .font(.subheadline.monospacedDigit())

                    Text("(\(formatElapsedTime(lapTimes[index])))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Pace Chart

    private var paceChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pace per Lap")
                .font(.headline)

            Chart {
                ForEach(Array(lapSplits.enumerated()), id: \.offset) { index, split in
                    LineMark(
                        x: .value("Lap", index + 1),
                        y: .value("Time", split)
                    )
                    .foregroundStyle(AppColors.primary)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Lap", index + 1),
                        y: .value("Time", split)
                    )
                    .foregroundStyle(AppColors.primary)
                    .symbolSize(40)
                }

                // Average line
                let avg = lapSplits.reduce(0, +) / Double(lapSplits.count)
                RuleMark(y: .value("Average", avg))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Avg")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(height: 200)
            .chartXScale(domain: 0...(lapSplits.count + 1))
            .chartXAxis {
                AxisMarks(values: Array(1...lapSplits.count)) { value in
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
                            Text(formatElapsedTime(time))
                                .font(.caption2)
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Timer Actions

    private func startStopwatch() {
        let now = Date()
        startDate = now
        isRunning = true
        elapsedTime = 0
        lapTimes = []

        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            guard let start = startDate else { return }
            elapsedTime = Date().timeIntervalSince(start)
        }
    }

    private func stopStopwatch() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        if let start = startDate {
            elapsedTime = Date().timeIntervalSince(start)
        }
    }

    private func recordLap() {
        guard isRunning else { return }
        lapTimes.append(elapsedTime)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func resetStopwatch() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        hasFinished = false
        startDate = nil
        elapsedTime = 0
        lapTimes = []

        // Clear saved results
        competition.runningTime = nil
        competition.runningPoints = nil
        competition.runningStartTime = nil
        competition.runningSplitTimes = []
    }

    // MARK: - Choose Entry Mode

    private var chooseEntryMode: some View {
        VStack(spacing: 16) {
            infoHeader

            Button { entryMode = .stopwatch } label: {
                HStack(spacing: 12) {
                    Image(systemName: "stopwatch").font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use Stopwatch").font(.headline)
                        Text("Time the run live").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .foregroundStyle(.white)
                .padding()
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button { entryMode = .manual } label: {
                HStack(spacing: 12) {
                    Image(systemName: "keyboard").font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enter Time Manually").font(.headline)
                        Text("Type in the published time").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .foregroundStyle(.primary)
                .padding()
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Manual Entry

    private var manualEntryView: some View {
        VStack(spacing: 20) {
            Button { entryMode = .choose } label: {
                HStack { Image(systemName: "chevron.left"); Text("Back") }
                    .font(.subheadline).foregroundStyle(AppColors.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                Text("Running Time").font(.headline)

                HStack(spacing: 8) {
                    TextField("MM", text: $manualMinutes)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .frame(width: 80)
                        .padding()
                        .background(AppColors.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text(":").font(.system(size: 48, weight: .bold)).foregroundStyle(.secondary)

                    TextField("SS", text: $manualSeconds)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .frame(width: 80)
                        .padding()
                        .background(AppColors.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let time = manualTimeInSeconds {
                    let points = PonyClubScoringService.calculateRunningPoints(
                        timeInSeconds: time,
                        ageCategory: competition.level.scoringCategory,
                        gender: competition.level.scoringGender
                    )
                    VStack(spacing: 2) {
                        Text(String(format: "%.0f", points)).font(.title.bold()).foregroundStyle(AppColors.primary)
                        Text("points").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Button { saveManualTime() } label: {
                Label("Save Score", systemImage: "checkmark.circle.fill")
                    .font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(manualTimeInSeconds != nil ? Color.green : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(manualTimeInSeconds == nil)
        }
    }

    private var manualTimeInSeconds: TimeInterval? {
        guard let mins = Int(manualMinutes), let secs = Int(manualSeconds),
              mins >= 0, secs >= 0, secs < 60, (mins + secs) > 0 else { return nil }
        return TimeInterval(mins * 60 + secs)
    }

    private func saveManualTime() {
        guard let time = manualTimeInSeconds else { return }
        competition.runningTime = time
        let points = PonyClubScoringService.calculateRunningPoints(
            timeInSeconds: time,
            ageCategory: competition.level.scoringCategory,
            gender: competition.level.scoringGender
        )
        competition.runningPoints = points
        checkAutoCompletion()
    }

    // MARK: - Existing Result

    private func existingResultView(time: TimeInterval) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Time Recorded").font(.subheadline).foregroundStyle(.secondary)
                Text(PonyClubScoringService.formatTime(time))
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
            }
            if let points = competition.runningPoints {
                VStack(spacing: 2) {
                    Text(String(format: "%.0f", points)).font(.title.bold()).foregroundStyle(AppColors.primary)
                    Text("points").font(.caption).foregroundStyle(.secondary)
                }
            }
            Button {
                competition.runningTime = nil
                competition.runningPoints = nil
                entryMode = .choose
            } label: {
                Text("Re-enter").font(.subheadline).foregroundStyle(.orange)
            }
        }
    }

    private func saveResults() {
        competition.runningTime = elapsedTime
        competition.runningStartTime = startDate
        competition.runningSplitTimes = lapSplits

        if let points = calculatedPoints {
            competition.runningPoints = points
        }

        // Check auto-completion
        checkAutoCompletion()
    }

    private func checkAutoCompletion() {
        let isTetrathlon = competition.competitionType == .tetrathlon
        let showRiding = isTetrathlon
        let showShooting = isTetrathlon || competition.hasTriathlonDiscipline(.shooting)
        let showSwimming = isTetrathlon || competition.hasTriathlonDiscipline(.swimming)
        let showRunning = isTetrathlon || competition.hasTriathlonDiscipline(.running)

        var hasAll = true
        if showShooting && competition.shootingPoints == nil { hasAll = false }
        if showSwimming && competition.swimmingPoints == nil { hasAll = false }
        if showRunning && competition.runningPoints == nil { hasAll = false }
        if showRiding && competition.ridingPoints == nil { hasAll = false }

        if hasAll {
            let shooting: Double = competition.shootingPoints ?? 0
            let swimming: Double = competition.swimmingPoints ?? 0
            let running: Double = competition.runningPoints ?? 0
            let riding: Double = competition.ridingPoints ?? 0
            let total = shooting + swimming + running + riding
            if total > 0 {
                let wasCompleted = competition.isCompleted
                competition.isCompleted = true
                competition.storedTotalPoints = total

                if !wasCompleted && !competition.hasWeatherData {
                    fetchWeatherForCompletion()
                }
            }
        }
    }

    private func fetchWeatherForCompletion() {
        guard let lat = competition.venueLatitude,
              let lon = competition.venueLongitude else { return }
        let location = CLLocation(latitude: lat, longitude: lon)
        Task {
            if let weather = try? await WeatherService.shared.fetchWeather(for: location) {
                await MainActor.run { competition.weather = weather }
            }
        }
    }

    // MARK: - Formatting

    private func formatElapsedTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let hundredths = Int((time - Double(totalSeconds)) * 100)
        return String(format: "%d:%02d.%02d", minutes, seconds, hundredths)
    }
}

#Preview {
    RunningStopwatchView(
        competition: Competition(name: "Test", date: Date(), competitionType: .tetrathlon, level: .junior),
        onDismiss: {}
    )
}
