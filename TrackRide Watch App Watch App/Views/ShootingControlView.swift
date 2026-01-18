//
//  ShootingControlView.swift
//  TrackRide Watch App
//
//  Shooting session view with stance stability metrics
//

import SwiftUI

struct ShootingControlView: View {
    @Environment(WatchConnectivityService.self) private var connectivityService
    @Environment(WorkoutManager.self) private var workoutManager
    @State private var selectedPage: Int = 0
    @State private var voiceService = WatchVoiceNotesService.shared

    // State tracking for haptic triggers
    @State private var lastStabilityWarningTime: Date?
    private let stabilityWarningInterval: TimeInterval = 10 // seconds between warnings

    private var motionManager: WatchMotionManager { WatchMotionManager.shared }

    var body: some View {
        TabView(selection: $selectedPage) {
            // Page 1: Main shooting metrics
            mainShootingPage
                .tag(0)

            // Page 2: Stability details
            stabilityDetailsPage
                .tag(1)

            // Page 3: Heart rate
            heartRatePage
                .tag(2)
        }
        .tabViewStyle(.verticalPage)
        .onAppear {
            selectedPage = 0
            // Start shooting motion tracking
            motionManager.startTracking(mode: .shooting)
        }
        .onDisappear {
            motionManager.stopTracking()
        }
        // Stability warning haptic
        .onChange(of: motionManager.stanceStability) { _, newStability in
            guard connectivityService.isRunning else { return }
            // Throttle warnings
            if let lastWarning = lastStabilityWarningTime,
               Date().timeIntervalSince(lastWarning) < stabilityWarningInterval {
                return
            }
            // Warn if stability drops below threshold
            if newStability < 50 && newStability > 0 {
                lastStabilityWarningTime = Date()
                HapticManager.shared.playCadenceWarningHaptic()
            }
        }
    }

    // MARK: - Main Shooting Page

    private var mainShootingPage: some View {
        VStack(spacing: 8) {
            // Header
            Text(connectivityService.rideType ?? "Shooting")
                .font(.caption)
                .foregroundStyle(.red)

            // Duration
            VStack(spacing: 2) {
                Text(connectivityService.formattedDuration)
                    .font(.system(.title, design: .monospaced))
                    .fontWeight(.bold)
                Text("Duration")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Stance Stability - main metric
            VStack(spacing: 4) {
                Text("\(Int(motionManager.stanceStability))%")
                    .font(.system(.largeTitle, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(stabilityColor)
                Text("Stability")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Heart rate indicator
            if workoutManager.currentHeartRate > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text("\(workoutManager.currentHeartRate)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("bpm")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Stop and voice note buttons
            HStack(spacing: 16) {
                // Voice note button
                Button(action: toggleVoiceNote) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 40, height: 40)

                        Image(systemName: "mic.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)

                // Stop button
                Button(action: stopShooting) {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 50, height: 50)

                        Image(systemName: "stop.fill")
                            .font(.body)
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }

    // MARK: - Stability Details Page

    private var stabilityDetailsPage: some View {
        VStack(spacing: 12) {
            Text("Stance Analysis")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Main stability gauge
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: motionManager.stanceStability / 100)
                    .stroke(stabilityColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(Int(motionManager.stanceStability))")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(stabilityColor)
                    Text("%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Stability description
            Text(stabilityDescription)
                .font(.caption)
                .foregroundStyle(stabilityColor)

            Divider()

            // Tips
            VStack(spacing: 4) {
                Text("Tips")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(stabilityTip)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    // MARK: - Heart Rate Page

    private var heartRatePage: some View {
        VStack(spacing: 12) {
            Text("Heart Rate")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Current heart rate
            if workoutManager.currentHeartRate > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    Text("\(workoutManager.currentHeartRate)")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                    Text("bpm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("--")
                    .font(.system(.largeTitle, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Stats summary
            HStack {
                VStack(spacing: 2) {
                    Text(connectivityService.formattedDuration)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Time")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("\(Int(motionManager.stanceStability))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(stabilityColor)
                    Text("Stability")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private var stabilityColor: Color {
        let stability = motionManager.stanceStability
        if stability >= 80 { return .green }
        if stability >= 60 { return .yellow }
        if stability >= 40 { return .orange }
        return .red
    }

    private var stabilityDescription: String {
        let stability = motionManager.stanceStability
        if stability >= 90 { return "Excellent" }
        if stability >= 80 { return "Very Good" }
        if stability >= 70 { return "Good" }
        if stability >= 60 { return "Fair" }
        if stability >= 50 { return "Needs Work" }
        return "Unstable"
    }

    private var stabilityTip: String {
        let stability = motionManager.stanceStability
        if stability >= 80 { return "Great form! Maintain your position." }
        if stability >= 60 { return "Relax your shoulders, steady breathing." }
        if stability >= 40 { return "Focus on your stance foundation." }
        return "Reset your position and breathe."
    }

    private func stopShooting() {
        Task {
            await workoutManager.stopWorkout()
            connectivityService.sendStopRide()
        }
        motionManager.stopTracking()
        HapticManager.shared.playStopHaptic()
    }

    private func toggleVoiceNote() {
        voiceService.onTranscriptionComplete = { text in
            connectivityService.sendVoiceNote(text)
        }
        voiceService.startDictation()
    }
}

#Preview {
    ShootingControlView()
        .environment(WatchConnectivityService.shared)
        .environment(WorkoutManager())
}
