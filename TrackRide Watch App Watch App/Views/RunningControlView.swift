//
//  RunningControlView.swift
//  TrackRide Watch App
//
//  Running session view with cadence and form metrics
//

import SwiftUI

struct RunningControlView: View {
    @Environment(WatchConnectivityService.self) private var connectivityService
    @Environment(WorkoutManager.self) private var workoutManager
    @State private var selectedPage: Int = 0
    @State private var voiceService = WatchVoiceNotesService.shared

    // State tracking for haptic triggers
    @State private var lastDistanceMilestone: Double = 0
    @State private var lastCadenceWarningTime: Date?
    @State private var lastPaceWarningTime: Date?
    private let distanceMilestoneMeters: Double = 1000 // 1km
    private let optimalCadenceRange = 170...180
    private let cadenceWarningInterval: TimeInterval = 30 // seconds between warnings

    private var motionManager: WatchMotionManager { WatchMotionManager.shared }

    var body: some View {
        TabView(selection: $selectedPage) {
            // Page 1: Main running metrics
            mainRunningPage
                .tag(0)

            // Page 2: Form metrics
            formMetricsPage
                .tag(1)

            // Page 3: Heart rate
            heartRatePage
                .tag(2)
        }
        .tabViewStyle(.verticalPage)
        .onAppear {
            // Reset to first page when view appears (fixes issue when switching disciplines)
            selectedPage = 0
        }
        // Distance milestone haptic
        .onChange(of: connectivityService.distance) { _, newDistance in
            guard connectivityService.isRunning else { return }
            let currentMilestone = floor(newDistance / distanceMilestoneMeters)
            if currentMilestone > lastDistanceMilestone && currentMilestone > 0 {
                lastDistanceMilestone = currentMilestone
                HapticManager.shared.playMilestoneHaptic()
            }
        }
        // Cadence warning haptic
        .onChange(of: motionManager.cadence) { _, newCadence in
            guard connectivityService.isRunning, newCadence > 0 else { return }
            // Throttle warnings
            if let lastWarning = lastCadenceWarningTime,
               Date().timeIntervalSince(lastWarning) < cadenceWarningInterval {
                return
            }
            // Check if outside optimal range
            if newCadence < optimalCadenceRange.lowerBound - 5 || newCadence > optimalCadenceRange.upperBound + 10 {
                lastCadenceWarningTime = Date()
                HapticManager.shared.playCadenceWarningHaptic()
            }
        }
    }

    // MARK: - Main Running Page

    private var mainRunningPage: some View {
        VStack(spacing: 8) {
            // Header
            Text(connectivityService.rideType ?? "Running")
                .font(.caption)
                .foregroundStyle(.orange)

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

            // Distance and pace
            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text(connectivityService.formattedDistance)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                    Text("Distance")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 2) {
                    Text(formattedPace)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    Text("/km")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Cadence from Watch
            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("\(motionManager.cadence)")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(cadenceColor)
                    Text("Cadence")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Heart rate indicator
                if workoutManager.currentHeartRate > 0 {
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                            Text("\(workoutManager.currentHeartRate)")
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.bold)
                        }
                        Text("BPM")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
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
                Button(action: stopRunning) {
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

    // MARK: - Form Metrics Page

    private var formMetricsPage: some View {
        VStack(spacing: 12) {
            Text("Running Form")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Cadence
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("\(motionManager.cadence)")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(cadenceColor)
                    Text("spm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Cadence")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // Target range indicator
                Text(cadenceDescription)
                    .font(.caption2)
                    .foregroundStyle(cadenceColor)
            }

            Divider()

            // Vertical oscillation
            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", motionManager.verticalOscillation))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(oscillationColor)
                    Text("cm")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Bounce")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 2) {
                    Text(String(format: "%.0f", motionManager.groundContactTime))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(gctColor)
                    Text("ms")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Contact")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
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
                    Text(connectivityService.formattedDistance)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Distance")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text(formattedPace)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                    Text("Pace")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private var formattedPace: String {
        guard connectivityService.distance > 0, connectivityService.duration > 0 else {
            return "--:--"
        }
        let pace = connectivityService.duration / (connectivityService.distance / 1000)  // seconds per km
        let mins = Int(pace) / 60
        let secs = Int(pace) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private var cadenceColor: Color {
        let cadence = motionManager.cadence
        if cadence >= 170 && cadence <= 190 { return .green }
        if cadence >= 160 && cadence <= 200 { return .yellow }
        if cadence > 0 { return .orange }
        return .secondary
    }

    private var cadenceDescription: String {
        let cadence = motionManager.cadence
        if cadence >= 170 && cadence <= 190 { return "Optimal" }
        if cadence > 190 { return "High" }
        if cadence >= 160 { return "Good" }
        if cadence > 0 { return "Low" }
        return "--"
    }

    private var oscillationColor: Color {
        let osc = motionManager.verticalOscillation
        if osc <= 8.0 { return .green }
        if osc <= 10.0 { return .yellow }
        return .orange
    }

    private var gctColor: Color {
        let gct = motionManager.groundContactTime
        if gct <= 250 { return .green }
        if gct <= 300 { return .yellow }
        return .orange
    }

    private func stopRunning() {
        Task {
            await workoutManager.stopWorkout()
            connectivityService.sendStopRide()
        }
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
    RunningControlView()
        .environment(WatchConnectivityService.shared)
        .environment(WorkoutManager())
}
