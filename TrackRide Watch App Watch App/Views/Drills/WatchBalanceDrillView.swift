//
//  WatchBalanceDrillView.swift
//  TrackRide Watch App
//
//  One-leg balance drill using Watch accelerometer
//

import SwiftUI

struct WatchBalanceDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isRunning = false
    @State private var countdown = 3
    @State private var elapsedTime: TimeInterval = 0
    @State private var targetDuration: TimeInterval = 30
    @State private var timer: Timer?
    @State private var stability: Double = 100
    @State private var stabilityHistory: [Double] = []

    private var motionManager: WatchMotionManager { WatchMotionManager.shared }

    var body: some View {
        VStack(spacing: 12) {
            if !isRunning && countdown == 3 && stabilityHistory.isEmpty {
                // Instructions
                instructionsView
            } else if countdown > 0 && !isRunning {
                // Countdown
                countdownView
            } else if isRunning {
                // Active drill
                activeDrillView
            } else {
                // Results
                resultsView
            }
        }
        .onDisappear {
            timer?.invalidate()
            motionManager.stopTracking()
        }
    }

    private var instructionsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.stand")
                .font(.largeTitle)
                .foregroundStyle(.purple)

            Text("Balance Drill")
                .font(.headline)

            Text("Stand on one leg")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Start") {
                startCountdown()
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .padding()
    }

    private var countdownView: some View {
        VStack(spacing: 8) {
            Text("Get Ready!")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(countdown)")
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .foregroundStyle(.purple)

            Text("Lift one foot")
                .font(.caption)
        }
    }

    private var activeDrillView: some View {
        VStack(spacing: 8) {
            // Timer
            Text(String(format: "%.0f", targetDuration - elapsedTime))
                .font(.system(.largeTitle, design: .rounded))
                .fontWeight(.bold)
                .monospacedDigit()

            // Stability circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: stability / 100)
                    .stroke(stabilityColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(stability))%")
                    .font(.headline)
                    .foregroundStyle(stabilityColor)
            }

            Text(stabilityMessage)
                .font(.caption)
                .foregroundStyle(stabilityColor)

            Spacer()

            Button("Stop") {
                endDrill()
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding()
    }

    private var resultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)

            Text("Complete!")
                .font(.headline)

            let avgStability = stabilityHistory.isEmpty ? 0 : stabilityHistory.reduce(0, +) / Double(stabilityHistory.count)
            Text("\(Int(avgStability))%")
                .font(.system(.title, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.purple)

            Text("Average Stability")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 12) {
                Button("Again") {
                    resetDrill()
                }
                .buttonStyle(.bordered)

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
        }
        .padding()
    }

    private var stabilityColor: Color {
        if stability >= 80 { return .green }
        if stability >= 60 { return .yellow }
        if stability >= 40 { return .orange }
        return .red
    }

    private var stabilityMessage: String {
        if stability >= 80 { return "Excellent!" }
        if stability >= 60 { return "Good" }
        if stability >= 40 { return "Steady..." }
        return "Focus!"
    }

    private func startCountdown() {
        countdown = 3
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            HapticManager.shared.playClickHaptic()
            countdown -= 1
            if countdown == 0 {
                t.invalidate()
                startDrill()
            }
        }
    }

    private func startDrill() {
        isRunning = true
        elapsedTime = 0
        stabilityHistory = []
        stability = 100
        motionManager.startTracking(mode: .shooting) // Use shooting mode for stability

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            elapsedTime += 0.5

            // Update stability from motion manager
            stability = motionManager.stanceStability
            stabilityHistory.append(stability)

            if elapsedTime >= targetDuration {
                endDrill()
            }
        }
    }

    private func endDrill() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        motionManager.stopTracking()
        HapticManager.shared.playSuccessHaptic()
    }

    private func resetDrill() {
        stabilityHistory = []
        countdown = 3
        elapsedTime = 0
    }
}

#Preview {
    WatchBalanceDrillView()
}
