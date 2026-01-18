//
//  WatchReactionDrillView.swift
//  TrackRide Watch App
//
//  Tap reaction time drill
//

import SwiftUI

struct WatchReactionDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isRunning = false
    @State private var isWaiting = false
    @State private var showTarget = false
    @State private var targetAppearTime: Date?
    @State private var reactionTimes: [TimeInterval] = []
    @State private var currentRound = 0
    @State private var totalRounds = 5
    @State private var isTooEarly = false
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 12) {
            if !isRunning && reactionTimes.isEmpty {
                // Instructions
                instructionsView
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
        }
    }

    private var instructionsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Reaction Drill")
                .font(.headline)

            Text("Tap when orange appears")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(totalRounds) rounds")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Start") {
                startDrill()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding()
    }

    private var activeDrillView: some View {
        VStack(spacing: 8) {
            // Round counter
            Text("Round \(currentRound + 1)/\(totalRounds)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // Target area
            Button(action: handleTap) {
                ZStack {
                    Circle()
                        .fill(targetColor)
                        .frame(width: 120, height: 120)

                    if isTooEarly {
                        Text("Too early!")
                            .font(.caption)
                            .foregroundStyle(.white)
                    } else if showTarget {
                        Text("TAP!")
                            .font(.headline)
                            .foregroundStyle(.white)
                    } else if isWaiting {
                        Text("Wait...")
                            .font(.caption)
                            .foregroundStyle(.white)
                    } else {
                        Text("Ready")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Last reaction time
            if let lastTime = reactionTimes.last {
                Text(String(format: "%.0f ms", lastTime * 1000))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(reactionColor(lastTime))
            }

            // Stop button
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

            if !reactionTimes.isEmpty {
                let avgTime = reactionTimes.reduce(0, +) / Double(reactionTimes.count)
                let bestTime = reactionTimes.min() ?? 0

                VStack(spacing: 4) {
                    Text(String(format: "%.0f ms", avgTime * 1000))
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    Text("Average")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text(String(format: "%.0f", bestTime * 1000))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                        Text("Best")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 2) {
                        Text("\(reactionTimes.count)")
                            .font(.caption)
                            .fontWeight(.bold)
                        Text("Valid")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

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
                .tint(.orange)
            }
        }
        .padding()
    }

    private var targetColor: Color {
        if isTooEarly { return .red }
        if showTarget { return .orange }
        return .gray.opacity(0.5)
    }

    private func reactionColor(_ time: TimeInterval) -> Color {
        if time < 0.25 { return .green }
        if time < 0.35 { return .yellow }
        return .orange
    }

    private func startDrill() {
        isRunning = true
        currentRound = 0
        reactionTimes = []
        startRound()
    }

    private func startRound() {
        isTooEarly = false
        showTarget = false
        isWaiting = true

        // Random delay 1-3 seconds
        let delay = Double.random(in: 1.0...3.0)
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            showTarget = true
            targetAppearTime = Date()
            isWaiting = false
            HapticManager.shared.playClickHaptic()
        }
    }

    private func handleTap() {
        if isTooEarly {
            // Already marked too early, restart round
            startRound()
            return
        }

        if isWaiting {
            // Tapped too early
            timer?.invalidate()
            isTooEarly = true
            HapticManager.shared.playFailureHaptic()
            // Auto restart after 1 second
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                startRound()
            }
            return
        }

        if showTarget, let appearTime = targetAppearTime {
            // Valid tap
            let reactionTime = Date().timeIntervalSince(appearTime)
            reactionTimes.append(reactionTime)
            HapticManager.shared.playSuccessHaptic()

            currentRound += 1
            if currentRound >= totalRounds {
                endDrill()
            } else {
                // Next round after brief pause
                showTarget = false
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                    startRound()
                }
            }
        }
    }

    private func endDrill() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        showTarget = false
        isWaiting = false
    }

    private func resetDrill() {
        reactionTimes = []
        currentRound = 0
    }
}

#Preview {
    WatchReactionDrillView()
}
