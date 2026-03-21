//
//  WatchFloatingControlPanel.swift
//  TetraTrack Watch App
//
//  Apple Workout-style floating glass control panel.
//  Shared by all active session views — timer + pause/stop controls.
//

import SwiftUI

struct WatchFloatingControlPanel: View {
    let disciplineIcon: String
    let disciplineColor: Color
    let disciplineName: String

    @Environment(WorkoutManager.self) private var workoutManager
    @State private var showingStopConfirmation = false

    var body: some View {
        HStack(spacing: 8) {
            // Discipline icon
            Image(systemName: disciplineIcon)
                .font(.caption)
                .foregroundStyle(disciplineColor)
                .frame(width: 16)

            // Timer — CRITICAL: always from WorkoutManager, never connectivityService
            Text(workoutManager.formattedElapsedTime)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(workoutManager.isPaused ? .secondary : WatchAppColors.warning)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            // Pause/Resume
            Button {
                if workoutManager.isPaused {
                    workoutManager.resumeWorkout()
                } else {
                    workoutManager.pauseWorkout()
                }
            } label: {
                Image(systemName: workoutManager.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: WatchDesignTokens.TapTarget.minimum,
                           height: WatchDesignTokens.TapTarget.minimum)
                    .background(Circle().fill(.orange))
            }
            .buttonStyle(.plain)

            // Stop
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
            Button("Save \(disciplineName)") {
                Task {
                    await workoutManager.stopWorkout()
                }
            }
            Button("Discard", role: .destructive) {
                Task { await workoutManager.discardWorkout() }
            }
            Button("Continue", role: .cancel) {}
        }
    }
}
