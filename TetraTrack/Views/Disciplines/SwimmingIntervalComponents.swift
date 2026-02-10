//
//  SwimmingIntervalComponents.swift
//  TetraTrack
//
//  Interval training setup and execution components for swimming
//

import SwiftUI

// MARK: - Interval Settings

struct SwimmingIntervalSettings {
    var targetDistance: Double = 100 // meters per interval
    var targetPace: TimeInterval = 120 // seconds per 100m
    var restDuration: TimeInterval = 30 // seconds
    var numberOfIntervals: Int = 4

    var totalWorkoutDistance: Double {
        targetDistance * Double(numberOfIntervals)
    }

    var estimatedWorkoutDuration: TimeInterval {
        let swimTime = (targetPace / 100) * targetDistance * Double(numberOfIntervals)
        let restTime = restDuration * Double(max(0, numberOfIntervals - 1))
        return swimTime + restTime
    }

    var formattedTargetPace: String {
        let mins = Int(targetPace) / 60
        let secs = Int(targetPace) % 60
        return String(format: "%d:%02d /100m", mins, secs)
    }

    var formattedRestDuration: String {
        let mins = Int(restDuration) / 60
        let secs = Int(restDuration) % 60
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        }
        return "\(Int(restDuration))s"
    }

    var formattedEstimatedDuration: String {
        let mins = Int(estimatedWorkoutDuration) / 60
        let secs = Int(estimatedWorkoutDuration) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Interval Setup View

struct SwimmingIntervalSetupView: View {
    @Binding var settings: SwimmingIntervalSettings
    let poolLength: Double
    let onStart: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let distanceOptions: [Double] = [25, 50, 100, 200, 400]

    private let paceOptions: [TimeInterval] = stride(from: 60, through: 240, by: 5).map { $0 }

    private let restOptions: [TimeInterval] = [10, 15, 20, 30, 45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Distance", selection: $settings.targetDistance) {
                        ForEach(distanceOptions, id: \.self) { dist in
                            Text("\(Int(dist))m").tag(dist)
                        }
                    }

                    Picker("Target Pace", selection: $settings.targetPace) {
                        ForEach(paceOptions, id: \.self) { pace in
                            Text(formatPace(pace)).tag(pace)
                        }
                    }

                    Picker("Rest", selection: $settings.restDuration) {
                        ForEach(restOptions, id: \.self) { rest in
                            Text(formatRest(rest)).tag(rest)
                        }
                    }

                    Stepper("Intervals: \(settings.numberOfIntervals)",
                            value: $settings.numberOfIntervals,
                            in: 1...20)
                } header: {
                    Text("Interval Configuration")
                }

                Section {
                    HStack {
                        Text("Total Distance")
                        Spacer()
                        Text("\(Int(settings.totalWorkoutDistance))m")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Estimated Duration")
                        Spacer()
                        Text(settings.formattedEstimatedDuration)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Lengths per Interval")
                        Spacer()
                        Text("\(Int(settings.targetDistance / poolLength))")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Workout Summary")
                }

                // CSS reference
                if SwimmingPersonalBests.shared.thresholdPace > 0 {
                    Section {
                        HStack {
                            Text("Your CSS Pace")
                            Spacer()
                            Text(SwimmingPersonalBests.shared.formattedThresholdPace())
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Reference")
                    }
                }
            }
            .navigationTitle("Interval Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        dismiss()
                        onStart()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func formatPace(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d /100m", mins, secs)
    }

    private func formatRest(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        }
        return "\(Int(seconds))s"
    }
}

// MARK: - Rest Timer View

struct SwimmingRestTimerView: View {
    let timeRemaining: TimeInterval
    let totalRestDuration: TimeInterval
    let intervalNumber: Int
    let totalIntervals: Int

    private var progress: Double {
        guard totalRestDuration > 0 else { return 0 }
        return 1.0 - (timeRemaining / totalRestDuration)
    }

    private var isAlmostDone: Bool {
        timeRemaining <= 5
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("REST")
                .font(.headline)
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .stroke(.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        isAlmostDone ? .green : .cyan,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                VStack(spacing: 4) {
                    Text(formatCountdown(timeRemaining))
                        .scaledFont(size: 48, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                        .monospacedDigit()
                        .foregroundStyle(isAlmostDone ? .green : .primary)

                    Text("Next: Interval \(intervalNumber + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Interval \(intervalNumber) of \(totalIntervals)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func formatCountdown(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval))
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        }
        return "\(secs)"
    }
}

// MARK: - Interval Progress View

struct SwimmingIntervalProgressView: View {
    let currentInterval: Int
    let totalIntervals: Int
    let distanceInInterval: Double
    let targetDistance: Double
    let currentPace: TimeInterval
    let targetPace: TimeInterval

    private var intervalProgress: Double {
        guard targetDistance > 0 else { return 0 }
        return min(distanceInInterval / targetDistance, 1.0)
    }

    private var paceDifference: TimeInterval {
        guard currentPace > 0, targetPace > 0 else { return 0 }
        return currentPace - targetPace
    }

    private var paceStatus: String {
        if abs(paceDifference) < 3 { return "On Pace" }
        return paceDifference > 0 ? "Behind" : "Ahead"
    }

    private var paceColor: Color {
        if abs(paceDifference) < 3 { return .green }
        return paceDifference > 0 ? .red : .blue
    }

    var body: some View {
        VStack(spacing: 12) {
            // Interval header
            HStack {
                Text("Interval \(currentInterval) of \(totalIntervals)")
                    .font(.headline)
                Spacer()
                Text(paceStatus)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(paceColor)
                    .clipShape(Capsule())
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(.cyan)
                        .frame(width: geometry.size.width * intervalProgress)
                        .animation(.linear(duration: 0.3), value: intervalProgress)
                }
            }
            .frame(height: 12)

            // Distance in interval
            HStack {
                Text("\(Int(distanceInInterval))m / \(Int(targetDistance))m")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if targetPace > 0 && currentPace > 0 {
                    let diff = paceDifference
                    Text(String(format: "%+.0fs", diff))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(paceColor)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Previews

#Preview("Interval Setup") {
    SwimmingIntervalSetupView(
        settings: .constant(SwimmingIntervalSettings()),
        poolLength: 25,
        onStart: {}
    )
}

#Preview("Rest Timer") {
    SwimmingRestTimerView(
        timeRemaining: 15,
        totalRestDuration: 30,
        intervalNumber: 3,
        totalIntervals: 8
    )
    .padding()
}

#Preview("Interval Progress") {
    SwimmingIntervalProgressView(
        currentInterval: 3,
        totalIntervals: 8,
        distanceInInterval: 75,
        targetDistance: 100,
        currentPace: 125,
        targetPace: 120
    )
    .padding()
}
