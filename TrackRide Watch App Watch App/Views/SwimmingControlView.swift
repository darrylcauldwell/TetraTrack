//
//  SwimmingControlView.swift
//  TrackRide Watch App
//
//  Swimming session view with stroke tracking
//

import SwiftUI

struct SwimmingControlView: View {
    @Environment(WatchConnectivityService.self) private var connectivityService
    @Environment(WorkoutManager.self) private var workoutManager
    @State private var selectedPage: Int = 0
    @State private var voiceService = WatchVoiceNotesService.shared

    // State tracking for haptic triggers
    @State private var lastLengthStrokeCount: Int = 0
    @State private var wasSwimming: Bool = false
    private let strokesPerLength: Int = 18 // Typical strokes per 25m length

    private var motionManager: WatchMotionManager { WatchMotionManager.shared }

    var body: some View {
        TabView(selection: $selectedPage) {
            // Page 1: Main swimming metrics
            mainSwimmingPage
                .tag(0)

            // Page 2: Heart rate
            heartRatePage
                .tag(1)
        }
        .tabViewStyle(.verticalPage)
        .onAppear {
            // Reset to first page when view appears (fixes issue when switching disciplines)
            selectedPage = 0
        }
        // Length completion haptic (every ~18 strokes)
        .onChange(of: motionManager.strokeCount) { _, newCount in
            guard connectivityService.isSwimming else { return }
            let lengthsCompleted = newCount / strokesPerLength
            let previousLengths = lastLengthStrokeCount / strokesPerLength
            if lengthsCompleted > previousLengths && lengthsCompleted > 0 {
                HapticManager.shared.playLengthCompleteHaptic()
            }
            lastLengthStrokeCount = newCount
        }
        // Rest interval detection (stroke rate drops to 0)
        .onChange(of: motionManager.strokeRate) { oldRate, newRate in
            guard connectivityService.isSwimming else { return }
            // Entering rest (was swimming, now stopped)
            if oldRate > 10 && newRate < 5 && wasSwimming {
                HapticManager.shared.playRestIntervalStartHaptic()
                wasSwimming = false
            }
            // Ending rest (was resting, now swimming)
            if oldRate < 5 && newRate > 10 && !wasSwimming {
                HapticManager.shared.playRestIntervalEndHaptic()
                wasSwimming = true
            }
            // Track swimming state
            if newRate > 10 {
                wasSwimming = true
            }
        }
    }

    // MARK: - Main Swimming Page

    private var mainSwimmingPage: some View {
        VStack(spacing: 8) {
            // Header
            Text(connectivityService.rideType ?? "Swimming")
                .font(.caption)
                .foregroundStyle(.cyan)

            // Duration - large and prominent
            VStack(spacing: 2) {
                Text(connectivityService.formattedDuration)
                    .font(.system(.title, design: .monospaced))
                    .fontWeight(.bold)
                Text("Duration")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Stroke metrics from Watch sensors
            HStack(spacing: 16) {
                // Stroke count
                VStack(spacing: 2) {
                    Text("\(motionManager.strokeCount)")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.cyan)
                    Text("Strokes")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Stroke rate
                VStack(spacing: 2) {
                    Text(String(format: "%.0f", motionManager.strokeRate))
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.cyan)
                    Text("SPM")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Distance from iPhone
            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text(connectivityService.formattedDistance)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Distance")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Pace (if distance > 0)
                if connectivityService.distance > 0 && connectivityService.duration > 0 {
                    VStack(spacing: 2) {
                        Text(formattedPace)
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("/100m")
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
                Button(action: stopSwimming) {
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

            // Session stats
            HStack {
                VStack(spacing: 2) {
                    Text("\(motionManager.strokeCount)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.cyan)
                    Text("Strokes")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text(connectivityService.formattedDuration)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Time")
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
        let pace = connectivityService.duration / (connectivityService.distance / 100)  // seconds per 100m
        let mins = Int(pace) / 60
        let secs = Int(pace) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func stopSwimming() {
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
    SwimmingControlView()
        .environment(WatchConnectivityService.shared)
        .environment(WorkoutManager())
}
