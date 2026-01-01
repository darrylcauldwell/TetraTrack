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

    // Timer state
    @State private var isRunning = false
    @State private var hasFinished = false
    @State private var startDate: Date?
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    // Lap splits
    @State private var lapTimes: [TimeInterval] = []  // Cumulative times at each lap press
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
                    // Info header
                    infoHeader

                    // Timer display
                    timerDisplay

                    if !hasFinished {
                        // Controls
                        controlButtons
                    } else {
                        // Results
                        resultsSection
                    }

                    // Lap splits
                    if !lapTimes.isEmpty {
                        lapSplitsSection
                    }

                    // Pace chart
                    if lapSplits.count >= 2 {
                        paceChartSection
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
