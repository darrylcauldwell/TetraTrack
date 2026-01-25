//
//  WatchStartSessionView.swift
//  TrackRide Watch App
//
//  Discipline selector for starting autonomous Watch sessions
//

import SwiftUI

struct WatchStartSessionView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @State private var showRideControl = false
    @State private var showRunControl = false
    @State private var showSwimControl = false

    var body: some View {
        NavigationStack {
            Group {
                if workoutManager.isWorkoutActive {
                    // Show active session - tap to return to controls
                    activeSessionView
                } else {
                    // Show discipline selector
                    disciplineSelectorView
                }
            }
            .navigationDestination(isPresented: $showRideControl) {
                RideControlView()
            }
            .navigationDestination(isPresented: $showRunControl) {
                RunningControlView()
            }
            .navigationDestination(isPresented: $showSwimControl) {
                SwimControlView()
            }
        }
    }

    // MARK: - Active Session View

    private var activeSessionView: some View {
        VStack(spacing: 12) {
            // Icon
            Image(systemName: activityIcon)
                .font(.system(size: 36))
                .foregroundStyle(activityColor)

            // Duration
            Text(workoutManager.formattedElapsedTime)
                .font(.system(size: 32, weight: .bold, design: .monospaced))

            // Distance (not shown for swimming)
            if workoutManager.activityType != .swimming {
                Text(workoutManager.formattedDistance)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Return to session button
            Button {
                switch workoutManager.activityType {
                case .riding:
                    showRideControl = true
                case .running:
                    showRunControl = true
                case .swimming:
                    showSwimControl = true
                case .none:
                    break
                }
            } label: {
                Text("Return to Session")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(activityColor)
            .padding(.bottom, 8)
        }
        .padding(.horizontal)
    }

    private var activityIcon: String {
        switch workoutManager.activityType {
        case .riding: return "figure.equestrian.sports"
        case .running: return "figure.run"
        case .swimming: return "figure.pool.swim"
        case .none: return "figure.stand"
        }
    }

    private var activityColor: Color {
        switch workoutManager.activityType {
        case .riding: return WatchAppColors.riding
        case .running: return WatchAppColors.running
        case .swimming: return WatchAppColors.swimming
        case .none: return WatchAppColors.primary
        }
    }

    // MARK: - Discipline Selector

    private var disciplineSelectorView: some View {
        VStack(spacing: 6) {
            // Riding button
            Button {
                showRideControl = true
            } label: {
                HStack {
                    Image(systemName: "figure.equestrian.sports")
                        .font(.title3)
                        .foregroundStyle(WatchAppColors.riding)
                    Text("GPS + Heart Rate")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(WatchAppColors.riding.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            // Running button
            Button {
                showRunControl = true
            } label: {
                HStack {
                    Image(systemName: "figure.run")
                        .font(.title3)
                        .foregroundStyle(WatchAppColors.running)
                    Text("GPS + Heart Rate")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(WatchAppColors.running.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            // Swimming button
            Button {
                showSwimControl = true
            } label: {
                HStack {
                    Image(systemName: "figure.pool.swim")
                        .font(.title3)
                        .foregroundStyle(WatchAppColors.swimming)
                    Text("Strokes + HR")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(WatchAppColors.swimming.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
    }
}

#Preview {
    WatchStartSessionView()
}
