//
//  WatchBreathingDrillView.swift
//  TrackRide Watch App
//
//  Box breathing drill with haptic cues
//

import SwiftUI

struct WatchBreathingDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isRunning = false
    @State private var currentPhase: BreathPhase = .ready
    @State private var phaseProgress: Double = 0
    @State private var cycleCount = 0
    @State private var targetCycles = 4
    @State private var timer: Timer?

    enum BreathPhase: String {
        case ready = "Ready"
        case inhale = "Inhale"
        case holdIn = "Hold In"
        case exhale = "Exhale"
        case holdOut = "Hold Out"

        var duration: TimeInterval { 4.0 } // 4 seconds each phase

        var color: Color {
            switch self {
            case .ready: return .gray
            case .inhale: return .blue
            case .holdIn: return .cyan
            case .exhale: return .purple
            case .holdOut: return .indigo
            }
        }

        var icon: String {
            switch self {
            case .ready: return "lungs"
            case .inhale: return "arrow.down.circle"
            case .holdIn: return "pause.circle"
            case .exhale: return "arrow.up.circle"
            case .holdOut: return "pause.circle"
            }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            if !isRunning && currentPhase == .ready {
                // Instructions
                instructionsView
            } else if isRunning {
                // Active breathing
                activeBreathingView
            } else {
                // Complete
                resultsView
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private var instructionsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "wind")
                .font(.largeTitle)
                .foregroundStyle(.blue)

            Text("Box Breathing")
                .font(.headline)

            Text("4-4-4-4 pattern")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(targetCycles) cycles")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Start") {
                startBreathing()
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding()
    }

    private var activeBreathingView: some View {
        VStack(spacing: 8) {
            // Cycle counter
            Text("Cycle \(cycleCount + 1)/\(targetCycles)")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Phase indicator
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 12)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: phaseProgress)
                    .stroke(currentPhase.color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: phaseProgress)

                VStack(spacing: 4) {
                    Image(systemName: currentPhase.icon)
                        .font(.title2)
                        .foregroundStyle(currentPhase.color)
                    Text(currentPhase.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }

            // Timer
            Text(String(format: "%.0f", (1 - phaseProgress) * currentPhase.duration))
                .font(.title3)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Spacer()

            Button("Stop") {
                stopBreathing()
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

            Text("\(targetCycles) cycles")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.blue)

            Text("Well done!")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 12) {
                Button("Again") {
                    resetBreathing()
                }
                .buttonStyle(.bordered)

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
        }
        .padding()
    }

    private func startBreathing() {
        isRunning = true
        cycleCount = 0
        currentPhase = .inhale
        phaseProgress = 0
        HapticManager.shared.playStartHaptic()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            phaseProgress += 0.1 / currentPhase.duration

            if phaseProgress >= 1.0 {
                advancePhase()
            }
        }
    }

    private func advancePhase() {
        phaseProgress = 0

        // Haptic at phase transition
        HapticManager.shared.playClickHaptic()

        switch currentPhase {
        case .ready:
            currentPhase = .inhale
        case .inhale:
            currentPhase = .holdIn
        case .holdIn:
            currentPhase = .exhale
        case .exhale:
            currentPhase = .holdOut
        case .holdOut:
            // Complete one cycle
            cycleCount += 1
            if cycleCount >= targetCycles {
                stopBreathing()
            } else {
                currentPhase = .inhale
            }
        }
    }

    private func stopBreathing() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        HapticManager.shared.playSuccessHaptic()
    }

    private func resetBreathing() {
        currentPhase = .ready
        cycleCount = 0
        phaseProgress = 0
    }
}

#Preview {
    WatchBreathingDrillView()
}
