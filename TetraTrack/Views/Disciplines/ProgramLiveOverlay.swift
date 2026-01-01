//
//  ProgramLiveOverlay.swift
//  TetraTrack
//
//  Overlay on RunningLiveView showing current walk/run interval phase,
//  time remaining, and upcoming intervals.
//

import SwiftUI

struct ProgramLiveOverlay: View {
    let intervals: [ProgramInterval]
    let elapsedTime: TimeInterval
    let isRunning: Bool

    /// Flattened interval sequence (expanding repeat counts)
    private var flatIntervals: [(phase: IntervalPhase, duration: Double)] {
        intervals.flatMap { interval in
            (0..<interval.repeatCount).map { _ in
                (phase: interval.phase, duration: interval.durationSeconds)
            }
        }
    }

    /// Current interval index and time within it
    private var currentState: (index: Int, timeInInterval: Double, timeRemaining: Double) {
        var accumulated: Double = 0
        for (i, interval) in flatIntervals.enumerated() {
            if elapsedTime < accumulated + interval.duration {
                let timeIn = elapsedTime - accumulated
                let remaining = interval.duration - timeIn
                return (index: i, timeInInterval: timeIn, timeRemaining: remaining)
            }
            accumulated += interval.duration
        }
        // Past all intervals
        return (index: flatIntervals.count - 1, timeInInterval: 0, timeRemaining: 0)
    }

    private var currentPhase: IntervalPhase {
        let state = currentState
        guard state.index < flatIntervals.count else { return .cooldown }
        return flatIntervals[state.index].phase
    }

    private var phaseColor: Color {
        switch currentPhase {
        case .warmup: return .gray
        case .walk: return .green
        case .run: return .orange
        case .cooldown: return .gray
        }
    }

    /// Total program duration
    private var totalDuration: Double {
        flatIntervals.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Current phase banner
            HStack(spacing: 8) {
                Image(systemName: currentPhase == .run ? "figure.run" : "figure.walk")
                    .font(.headline)
                Text(currentPhase.displayName.uppercased())
                    .font(.headline.bold())
                Spacer()
                // Time remaining in this interval
                Text(formatTime(currentState.timeRemaining))
                    .font(.system(.title3, design: .rounded))
                    .monospacedDigit()
                    .bold()
            }
            .foregroundStyle(phaseColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(phaseColor.opacity(0.15))
            )

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)

                    // Phase segments
                    HStack(spacing: 1) {
                        ForEach(Array(flatIntervals.enumerated()), id: \.offset) { index, interval in
                            let segColor: Color = {
                                switch interval.phase {
                                case .warmup, .cooldown: return .gray
                                case .walk: return .green
                                case .run: return .orange
                                }
                            }()
                            let width = geo.size.width * (interval.duration / totalDuration)
                            let opacity: Double = index < currentState.index ? 0.3 : (index == currentState.index ? 1.0 : 0.5)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(segColor.opacity(opacity))
                                .frame(width: max(2, width), height: 6)
                        }
                    }
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 16)

            // Interval progress text
            HStack {
                let state = currentState
                let intervalNum = state.index + 1
                let totalIntervals = flatIntervals.count
                Text("Interval \(intervalNum) of \(totalIntervals)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                // Upcoming phase
                if state.index + 1 < flatIntervals.count {
                    let next = flatIntervals[state.index + 1]
                    Text("Next: \(next.phase.displayName) \(formatTime(next.duration))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }

    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
