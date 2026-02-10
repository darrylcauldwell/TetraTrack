//
//  SwimmingCompetitionTrackerView.swift
//  TetraTrack
//
//  Parent-focused lap counter and countdown timer for timed swim at competition
//

import SwiftUI
import Charts
import CoreLocation

struct SwimmingCompetitionTrackerView: View {
    @Bindable var competition: Competition
    let onDismiss: () -> Void

    // Timer state
    @State private var isRunning = false
    @State private var hasFinished = false
    @State private var startDate: Date?
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    // Swimming state
    @State private var lengthCount: Int = 0
    @State private var splitTimes: [TimeInterval] = []  // Per-length split times
    @State private var extraMeters: Int = 0
    @State private var poolLength: Double = 25
    @State private var showResetConfirmation = false

    private var swimDuration: TimeInterval {
        competition.level.swimDuration
    }

    private var remainingTime: TimeInterval {
        max(0, swimDuration - elapsedTime)
    }

    private var totalDistance: Double {
        Double(lengthCount) * poolLength + Double(extraMeters)
    }

    private var calculatedPoints: Double? {
        guard totalDistance > 0 else { return nil }
        return PonyClubScoringService.calculateSwimmingPoints(
            distanceMeters: totalDistance,
            ageCategory: competition.level.scoringCategory,
            gender: competition.level.scoringGender
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    infoHeader

                    if !hasFinished {
                        countdownDisplay
                        lengthCounter
                        controlButtons
                    } else {
                        resultsSection
                    }

                    if splitTimes.count >= 2 {
                        splitChartSection
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Swimming")
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
            .confirmationDialog("Reset Timer?", isPresented: $showResetConfirmation) {
                Button("Reset", role: .destructive) { resetTimer() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will clear the current timer and lap count.")
            }
        }
    }

    // MARK: - Info Header

    private var infoHeader: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(competition.level.displayName)
                    .font(.subheadline.bold())
                Text(competition.level.formattedSwimDuration + " swim")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Pool length picker
            Menu {
                ForEach([20.0, 25.0, 33.0, 50.0], id: \.self) { length in
                    Button("\(Int(length))m pool") {
                        poolLength = length
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("\(Int(poolLength))m pool")
                        .font(.subheadline)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(AppColors.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Countdown Display

    private var countdownDisplay: some View {
        VStack(spacing: 8) {
            if isRunning {
                // Show remaining time as countdown
                Text(formatTime(remainingTime))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(remainingTime < 30 ? .red : (remainingTime < 60 ? .orange : AppColors.primary))

                Text("remaining")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Distance so far
                if totalDistance > 0 {
                    Text("\(Int(totalDistance))m")
                        .font(.title2.monospacedDigit().bold())
                        .foregroundStyle(AppColors.primary)
                }
            } else if elapsedTime > 0 && !hasFinished {
                Text("Timer Expired")
                    .font(.title.bold())
                    .foregroundStyle(.orange)

                Text("\(Int(totalDistance))m swum")
                    .font(.title2.monospacedDigit())
            } else {
                Text(formatTime(swimDuration))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Text("ready")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 16)
    }

    // MARK: - Length Counter

    private var lengthCounter: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Lengths")
                    .font(.headline)
                Spacer()
                Text("\(lengthCount)")
                    .font(.title.bold().monospacedDigit())
                    .foregroundStyle(AppColors.primary)
            }

            if isRunning {
                // Large tap target for counting lengths
                Button {
                    recordLength()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 36))
                        Text("Tap for Length")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .sensoryFeedback(.impact(weight: .heavy), trigger: lengthCount)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: 24) {
            if isRunning {
                // Timer is running - no stop button, countdown auto-expires
                // But provide emergency stop
                Button {
                    stopTimer()
                } label: {
                    Text("End Early")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else if elapsedTime > 0 && !hasFinished {
                // Timer expired, need to enter extra meters and finish
                extraMetersEntry

                Button {
                    finishSwim()
                } label: {
                    Label("Save Result", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                // Not started yet
                Button {
                    startTimer()
                } label: {
                    Text("Start")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 200, height: 200)
                        .background(Color.green)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Start swimming countdown")
            }
        }
    }

    // MARK: - Extra Meters Entry

    private var extraMetersEntry: some View {
        VStack(spacing: 8) {
            Text("Extra Meters")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Stepper("\(extraMeters)m", value: $extraMeters, in: 0...Int(poolLength - 1))
                .font(.headline.monospacedDigit())
                .padding(.horizontal)
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Distance Swum")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(Int(totalDistance))m")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

            HStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text("\(lengthCount)")
                        .font(.title2.bold().monospacedDigit())
                    Text("lengths")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if extraMeters > 0 {
                    VStack(spacing: 2) {
                        Text("+\(extraMeters)m")
                            .font(.title2.bold().monospacedDigit())
                        Text("extra")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 2) {
                    Text(competition.level.formattedSwimDuration)
                        .font(.title2.bold())
                    Text("duration")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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

    // MARK: - Split Chart

    private var splitChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Length Splits")
                .font(.headline)

            // Show split times table
            ForEach(Array(splitTimes.enumerated()), id: \.offset) { index, split in
                HStack {
                    Text("Length \(index + 1)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatSplitTime(split))
                        .font(.subheadline.monospacedDigit())
                }
                .padding(.vertical, 2)
            }

            // Chart
            if splitTimes.count >= 2 {
                Chart {
                    ForEach(Array(splitTimes.enumerated()), id: \.offset) { index, split in
                        LineMark(
                            x: .value("Length", index + 1),
                            y: .value("Time", split)
                        )
                        .foregroundStyle(AppColors.primary)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Length", index + 1),
                            y: .value("Time", split)
                        )
                        .foregroundStyle(AppColors.primary)
                        .symbolSize(40)
                    }

                    let avg = splitTimes.reduce(0, +) / Double(splitTimes.count)
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
                .chartXScale(domain: 0...(splitTimes.count + 1))
                .chartXAxis {
                    AxisMarks(values: Array(1...splitTimes.count)) { value in
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
                                Text(formatSplitTime(time))
                                    .font(.caption2)
                            }
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

    private func startTimer() {
        let now = Date()
        startDate = now
        isRunning = true
        elapsedTime = 0
        lengthCount = 0
        splitTimes = []
        extraMeters = 0

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let start = startDate else { return }
            let previousElapsed = elapsedTime
            elapsedTime = Date().timeIntervalSince(start)

            // Check for timer expiry
            if elapsedTime >= swimDuration && previousElapsed < swimDuration {
                timerExpired()
            }

            // Milestone warnings
            let prevRemaining = swimDuration - previousElapsed
            let curRemaining = swimDuration - elapsedTime

            // 60 second warning
            if prevRemaining > 60 && curRemaining <= 60 {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }

            // 30 second warning
            if prevRemaining > 30 && curRemaining <= 30 {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }

            // 10 second warning
            if prevRemaining > 10 && curRemaining <= 10 {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
    }

    private func timerExpired() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    private func stopTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        if let start = startDate {
            elapsedTime = Date().timeIntervalSince(start)
        }
    }

    private func recordLength() {
        guard isRunning else { return }
        lengthCount += 1

        // Record split time for this length
        let previousTotal = splitTimes.reduce(0, +)
        let lengthTime = elapsedTime - previousTotal
        splitTimes.append(max(0.1, lengthTime))
    }

    private func finishSwim() {
        hasFinished = true
        saveResults()
    }

    private func resetTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        hasFinished = false
        startDate = nil
        elapsedTime = 0
        lengthCount = 0
        splitTimes = []
        extraMeters = 0

        // Clear saved results
        competition.swimmingDistance = nil
        competition.swimmingTime = nil
        competition.swimStartTime = nil
        competition.swimmingPoints = nil
        competition.swimmingSplitTimes = []
    }

    private func saveResults() {
        competition.swimmingDistance = totalDistance
        competition.swimmingTime = swimDuration
        competition.swimStartTime = startDate
        competition.swimmingSplitTimes = splitTimes

        if let points = calculatedPoints {
            competition.swimmingPoints = points
        }

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

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let tenths = Int((time - Double(totalSeconds)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }

    private func formatSplitTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let hundredths = Int((time - Double(totalSeconds)) * 100)
        if minutes > 0 {
            return String(format: "%d:%02d.%02d", minutes, seconds, hundredths)
        }
        return String(format: "%d.%02d", seconds, hundredths)
    }
}

#Preview {
    SwimmingCompetitionTrackerView(
        competition: Competition(name: "Test", date: Date(), competitionType: .tetrathlon, level: .junior),
        onDismiss: {}
    )
}
