//
//  WatchCompanionControlPanel.swift
//  TetraTrack Watch App
//
//  Glass floating control panel for companion mode (iPhone-initiated sessions).
//  Matches WatchFloatingControlPanel aesthetic but sends commands to iPhone
//  via WCSession instead of controlling a local HKWorkoutSession.
//

import SwiftUI

struct WatchCompanionControlPanel: View {
    @Environment(WatchConnectivityService.self) private var connectivityService

    @State private var showingStopConfirmation = false
    @State private var isPausePending = false

    private var isPaused: Bool {
        connectivityService.rideState == .paused
    }

    private var disciplineIcon: String {
        switch connectivityService.activeDiscipline {
        case .riding: return "figure.equestrian.sports"
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .swimming: return "figure.pool.swim"
        case .shooting: return "target"
        case .training: return "figure.mixed.cardio"
        case .idle: return "figure.stand"
        }
    }

    private var disciplineColor: Color {
        switch connectivityService.activeDiscipline {
        case .riding: return WatchAppColors.riding
        case .running: return WatchAppColors.running
        case .walking: return .teal
        case .swimming: return WatchAppColors.swimming
        case .shooting: return WatchAppColors.shooting
        case .training, .idle: return WatchAppColors.primary
        }
    }

    private var disciplineName: String {
        switch connectivityService.activeDiscipline {
        case .riding: return "Ride"
        case .running: return "Run"
        case .walking: return "Walk"
        case .swimming: return "Swim"
        case .shooting: return "Shoot"
        case .training: return "Training"
        case .idle: return "Session"
        }
    }

    /// Timer source: prefer Watch workout timer if active, fall back to iPhone relay
    private var timerText: String {
        if WorkoutManager.shared.isWorkoutActive {
            return WorkoutManager.shared.formattedElapsedTime
        }
        return connectivityService.formattedDuration
    }

    var body: some View {
        HStack(spacing: 8) {
            // Discipline icon
            Image(systemName: disciplineIcon)
                .font(.caption)
                .foregroundStyle(disciplineColor)
                .frame(width: 16)

            // Timer
            Text(timerText)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(isPaused ? .secondary : WatchAppColors.warning)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            // Pause/Resume — sends command to iPhone
            Button {
                isPausePending = true
                let command: WatchCommand = isPaused ? .resumeRide : .pauseRide
                connectivityService.sendSessionCommand(command)
                // Reset optimistic state after round-trip window
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    isPausePending = false
                }
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: WatchDesignTokens.TapTarget.minimum,
                           height: WatchDesignTokens.TapTarget.minimum)
                    .background(Circle().fill(.orange))
            }
            .buttonStyle(.plain)
            .opacity(isPausePending ? 0.5 : 1.0)
            .disabled(isPausePending)

            // Stop — sends command to iPhone
            Button {
                showingStopConfirmation = true
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: WatchDesignTokens.TapTarget.minimum,
                           height: WatchDesignTokens.TapTarget.minimum)
                    .background(Circle().fill(WatchAppColors.error))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .watchGlassPanel()
        .padding(.horizontal, 4)
        .confirmationDialog("End \(disciplineName)?", isPresented: $showingStopConfirmation) {
            Button("End \(disciplineName)") {
                connectivityService.sendSessionCommand(.stopRide)
            }
            Button("Continue", role: .cancel) {}
        }
    }
}
