//
//  RidePhaseControls.swift
//  TetraTrack
//
//  Phase control overlay for showjumping rides (warmup → round → rest → cooldown)
//

import SwiftUI

struct RidePhaseControls: View {
    let tracker: RideTracker

    var body: some View {
        VStack(spacing: 12) {
            // Current phase indicator
            HStack {
                Image(systemName: tracker.currentPhaseType.icon)
                    .foregroundStyle(phaseColor)
                Text(tracker.currentPhaseType.rawValue)
                    .font(.headline)
                    .fontWeight(.bold)
                if let phase = tracker.currentPhase {
                    Text(phase.formattedDuration)
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(phaseColor.opacity(0.2))
            .clipShape(Capsule())

            // Phase transition buttons
            HStack(spacing: 12) {
                ForEach(availableTransitions, id: \.self) { phaseType in
                    Button {
                        tracker.startPhase(phaseType)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: phaseType.icon)
                                .font(.title2)
                            Text(phaseType.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .frame(minWidth: 70, minHeight: 60)
                        .background(phaseButtonColor(phaseType).opacity(0.15))
                        .foregroundStyle(phaseButtonColor(phaseType))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .sensoryFeedback(.impact(weight: .medium), trigger: tracker.currentPhaseType)
                }
            }

            // Jump count and faults for current round
            if tracker.currentPhaseType == .round, let phase = tracker.currentPhase {
                HStack(spacing: 20) {
                    Label("\(tracker.jumpCount - tracker.phaseStartJumpCount) jumps", systemImage: "arrow.up.forward")
                    FaultStepper(phase: phase)
                }
                .font(.subheadline)
                .padding(.horizontal)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var phaseColor: Color {
        switch tracker.currentPhaseType {
        case .warmup: return .gray
        case .round: return .blue
        case .rest: return .yellow
        case .cooldown: return .green
        }
    }

    private func phaseButtonColor(_ type: RidePhaseType) -> Color {
        switch type {
        case .warmup: return .gray
        case .round: return .blue
        case .rest: return .yellow
        case .cooldown: return .green
        }
    }

    private var availableTransitions: [RidePhaseType] {
        RidePhaseType.allCases.filter { $0 != tracker.currentPhaseType }
    }
}

// MARK: - Fault Stepper

struct FaultStepper: View {
    let phase: RidePhase

    var body: some View {
        HStack(spacing: 8) {
            Button {
                if phase.faults > 0 { phase.faults -= 1 }
            } label: {
                Image(systemName: "minus.circle")
            }
            .disabled(phase.faults <= 0)

            Text("\(phase.faults) faults")

            Button {
                phase.faults += 1
            } label: {
                Image(systemName: "plus.circle")
            }
        }
    }
}

// MARK: - Phase Timeline Card (for ride insights)

struct PhaseTimelineCard: View {
    let phases: [RidePhase]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flag.fill")
                    .foregroundStyle(.blue)
                Text("Session Phases")
                    .font(.headline)
            }

            // Phase bar
            if !phases.isEmpty {
                GeometryReader { geo in
                    let totalDuration = phases.reduce(0) { $0 + $1.duration }
                    HStack(spacing: 1) {
                        ForEach(phases) { phase in
                            let fraction = totalDuration > 0 ? phase.duration / totalDuration : 0
                            Rectangle()
                                .fill(phaseColor(phase.phaseType))
                                .frame(width: max(2, geo.size.width * fraction))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .frame(height: 12)

                // Phase legend
                HStack(spacing: 12) {
                    ForEach(RidePhaseType.allCases) { type in
                        if phases.contains(where: { $0.phaseType == type }) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(phaseColor(type))
                                    .frame(width: 8, height: 8)
                                Text(type.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            // Per-phase summary
            ForEach(phases) { phase in
                HStack {
                    Image(systemName: phase.phaseType.icon)
                        .foregroundStyle(phaseColor(phase.phaseType))
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(phase.phaseType.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(phase.formattedDuration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        if phase.jumpCount > 0 {
                            Text("\(phase.jumpCount) jumps")
                                .font(.caption)
                        }
                        if phase.faults > 0 {
                            Text("\(phase.faults) faults")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        if phase.averageHeartRate > 0 {
                            Text("\(phase.averageHeartRate) bpm avg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func phaseColor(_ type: RidePhaseType) -> Color {
        switch type {
        case .warmup: return .gray
        case .round: return .blue
        case .rest: return .yellow
        case .cooldown: return .green
        }
    }
}
