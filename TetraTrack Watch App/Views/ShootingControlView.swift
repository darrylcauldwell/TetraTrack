//
//  ShootingControlView.swift
//  TetraTrack Watch App
//
//  Autonomous shooting session control for Apple Watch
//  Shows live steadiness gauge, shot count, HR, and mini-feedback
//

import SwiftUI
import WatchConnectivity
import TetraTrackShared
import os

struct ShootingControlView: View {
    @Environment(WatchConnectivityService.self) private var connectivityService
    @Environment(WorkoutManager.self) private var workoutManager
    @State private var showingStopConfirmation = false
    @State private var shotDetector = ShootingShotDetector()
    @State private var lastShotDelta: Double? // Improvement arrow value

    var body: some View {
        Group {
            if workoutManager.isWorkoutActive && workoutManager.activityType == .shooting {
                activeShootingView
            } else {
                startShootingView
            }
        }
        .onAppear {
            setupShotDetection()
        }
        .onDisappear {
            teardownShotDetection()
        }
    }

    // MARK: - Start Shooting View

    private var startShootingView: some View {
        VStack(spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 44))
                .foregroundStyle(WatchAppColors.shooting)
                .padding(.top, 8)

            if WatchSessionStore.shared.pendingCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "icloud.and.arrow.up")
                    Text("\(WatchSessionStore.shared.pendingCount) pending")
                }
                .font(.caption2)
                .foregroundStyle(.orange)
            }

            Spacer()

            Button {
                shotDetector.reset()
                Task {
                    await workoutManager.startWorkout(type: .shooting)
                }
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Shooting")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(WatchAppColors.shooting)
            .padding(.bottom, 8)
        }
        .padding(.horizontal)
    }

    // MARK: - Active Shooting View

    private var activeShootingView: some View {
        ScrollView {
            VStack(spacing: 6) {
                // Duration
                Text(workoutManager.formattedElapsedTime)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(WatchAppColors.shooting)

                // Shot count
                HStack(spacing: 4) {
                    Image(systemName: "target")
                        .font(.caption)
                    Text("\(shotDetector.shotCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("shots")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Steadiness gauge
                steadinessGauge

                Divider()
                    .padding(.vertical, 2)

                // Heart rate and last shot delta
                HStack(spacing: 12) {
                    if workoutManager.currentHeartRate > 0 {
                        VStack(spacing: 2) {
                            HStack(spacing: 2) {
                                Image(systemName: "heart.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                                Text("\(workoutManager.currentHeartRate)")
                                    .font(.callout)
                                    .fontWeight(.semibold)
                            }
                            Text("bpm")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let delta = lastShotDelta {
                        VStack(spacing: 2) {
                            HStack(spacing: 2) {
                                Image(systemName: delta >= 0 ? "arrow.up" : "arrow.down")
                                    .font(.caption2)
                                    .foregroundStyle(delta >= 0 ? .green : .orange)
                                Text(String(format: "%.0f", abs(delta)))
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(delta >= 0 ? .green : .orange)
                            }
                            Text("steadiness")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer(minLength: 8)

                // Control buttons
                HStack(spacing: 12) {
                    Button {
                        if workoutManager.isPaused {
                            workoutManager.resumeWorkout()
                        } else {
                            workoutManager.pauseWorkout()
                        }
                    } label: {
                        Image(systemName: workoutManager.isPaused ? "play.fill" : "pause.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)

                    Button {
                        showingStopConfirmation = true
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .confirmationDialog("End Shooting?", isPresented: $showingStopConfirmation) {
            Button("Save Session") {
                Task {
                    await workoutManager.stopWorkout()
                }
            }
            Button("Discard", role: .destructive) {
                workoutManager.discardWorkout()
            }
            Button("Continue", role: .cancel) {}
        }
    }

    // MARK: - Steadiness Gauge

    private var steadinessGauge: some View {
        let steadiness = shotDetector.currentHoldSteadiness
        let color = steadinessColor(steadiness)

        return ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 5)
                .frame(width: 50, height: 50)
            Circle()
                .trim(from: 0, to: steadiness / 100.0)
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 50, height: 50)
            Text(String(format: "%.0f", steadiness))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    private func steadinessColor(_ value: Double) -> Color {
        if value > 80 { return .green }
        if value > 60 { return .cyan }
        if value > 40 { return .orange }
        return .red
    }

    // MARK: - Shot Detection Setup

    private func setupShotDetection() {
        // Wire motion samples to shot detector
        WatchMotionManager.shared.onMotionUpdate = { sample in
            shotDetector.processSample(sample)
        }

        // Wire heart rate updates
        workoutManager.onHeartRateUpdate = { hr in
            shotDetector.updateHeartRate(hr)
        }

        // Handle detected shots
        shotDetector.onShotDetected = { metrics in
            // Haptic feedback
            WKInterfaceDevice.current().play(.click)

            // Calculate improvement delta
            if let previous = shotDetector.lastShotMetrics,
               metrics.shotIndex > 1 {
                // Compare against second-to-last since lastShotMetrics is already updated
                lastShotDelta = metrics.holdSteadiness - previous.holdSteadiness
            }

            // Send to iPhone
            let dict = metrics.toDictionary()
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(dict, replyHandler: nil) { error in
                    Log.tracking.error("Failed to send shot metrics: \(error.localizedDescription)")
                }
            }
        }
    }

    private func teardownShotDetection() {
        WatchMotionManager.shared.onMotionUpdate = nil
        shotDetector.onShotDetected = nil
    }
}

#Preview {
    ShootingControlView()
        .environment(WatchConnectivityService.shared)
}
