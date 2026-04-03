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
    @State private var showingStopConfirmation = false
    @State private var pendingAction: SessionAction?

    enum SessionAction {
        case save, discard
    }

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
        .confirmationDialog("End \(disciplineName)?", isPresented: $showingStopConfirmation) {
            Button("Save \(disciplineName)") {
                pendingAction = .save
            }
            Button("Discard", role: .destructive) {
                pendingAction = .discard
            }
            Button("Continue", role: .cancel) {}
        }
        .onChange(of: pendingAction) { _, action in
            guard let action else { return }
            pendingAction = nil
            Task {
                switch action {
                case .save:
                    await workoutManager.stopWorkout()
                case .discard:
                    await workoutManager.discardWorkout()
                }
            }
        }
    }

    private var controlsPage: some View {
        VStack(spacing: 16) {
            // Discipline header
            HStack(spacing: 6) {
                Image(systemName: disciplineIcon)
                    .foregroundStyle(disciplineColor)
                Text(disciplineName)
                    .font(.headline)
            }

            // Timer
            Text(workoutManager.formattedElapsedTime)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(workoutManager.isPaused ? .secondary : .primary)

            // Pause/Resume + Stop buttons
            HStack(spacing: 20) {
                Button {
                    if workoutManager.isPaused {
                        workoutManager.resumeWorkout()
                    } else {
                        workoutManager.pauseWorkout()
                    }
                    selectedPage = 0
                } label: {
                    Image(systemName: workoutManager.isPaused ? "play.fill" : "pause.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(.orange))
                }
                .buttonStyle(.plain)

                Button {
                    showingStopConfirmation = true
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(WatchAppColors.error))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
