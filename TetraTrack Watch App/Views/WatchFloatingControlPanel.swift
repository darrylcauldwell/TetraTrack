//
//  WatchFloatingControlPanel.swift
//  TetraTrack Watch App
//
//  Apple Workout-style swipe-left control page.
//  Wraps discipline metrics as page 1, controls as page 2.
//

import SwiftUI

/// Wraps session content with swipe-left controls (Apple Workout pattern).
/// Usage: `SessionPager(icon:color:name:) { metricsContent }`
struct SessionPager<Content: View>: View {
    let disciplineIcon: String
    let disciplineColor: Color
    let disciplineName: String
    @ViewBuilder let content: () -> Content

    @Environment(WorkoutManager.self) private var workoutManager
    @State private var selectedPage: Int = 0

    var body: some View {
        TabView(selection: $selectedPage) {
            // Page 0: Session metrics
            content()
                .tag(0)

            // Page 1: Controls (swipe left to access)
            controlsPage
                .tag(1)
        }
        .tabViewStyle(.page)
    }

    private var controlsPage: some View {
        VStack(spacing: 12) {
            // Discipline header
            HStack(spacing: 6) {
                Image(systemName: disciplineIcon)
                    .foregroundStyle(disciplineColor)
                Text(disciplineName)
                    .font(.headline)
            }

            // Timer
            Text(workoutManager.formattedElapsedTime)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(workoutManager.isPaused ? .secondary : .primary)

            // Pause/Resume
            Button {
                if workoutManager.isPaused {
                    workoutManager.resumeWorkout()
                } else {
                    workoutManager.pauseWorkout()
                }
                selectedPage = 0
            } label: {
                Image(systemName: workoutManager.isPaused ? "play.fill" : "pause.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(.orange))
            }
            .buttonStyle(.plain)

            // Save + Discard buttons (direct, no confirmation dialog)
            HStack(spacing: 16) {
                Button {
                    Task { await workoutManager.stopWorkout() }
                } label: {
                    Text("Save")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    Task { await workoutManager.discardWorkout() }
                } label: {
                    Text("Discard")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(WatchAppColors.error)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
        }
    }
}
