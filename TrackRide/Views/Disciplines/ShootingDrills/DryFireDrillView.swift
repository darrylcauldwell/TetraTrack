//
//  DryFireDrillView.swift
//  TrackRide
//
//  Dry fire drill with reaction time and stance stability tracking
//

import SwiftUI

// MARK: - Dry Fire Drill View

struct DryFireDrillView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isRunning = false
    @State private var shotCount = 0
    @State private var totalShots = 10
    @State private var showFire = false
    @State private var waitingForFire = false
    @State private var reactionTimes: [TimeInterval] = []
    @State private var fireStartTime: Date?
    @State private var lastReactionTime: TimeInterval = 0

    // Watch stance stability tracking
    @State private var stanceStability: Double = 0.0
    @State private var stabilityReadings: [Double] = []
    @State private var shotStabilities: [Double] = []
    @State private var watchConnected = false
    private let watchManager = WatchConnectivityManager.shared

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                (showFire ? Color.red : Color.green.opacity(0.1))
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.1), value: showFire)

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Dry Fire Practice")
                            .font(.headline)
                            .foregroundStyle(showFire ? .white : .primary)

                        Spacer()

                        // Watch connection indicator
                        if watchManager.isReachable {
                            Image(systemName: "applewatch.radiowaves.left.and.right")
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "applewatch.slash")
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            stopMotionTracking()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.medium))
                                .foregroundStyle(showFire ? .white : .primary)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    .padding()

                    // Content area - centered in remaining space
                    if !isRunning && reactionTimes.isEmpty {
                        instructionsView
                            .frame(maxHeight: .infinity)
                    } else if isRunning {
                        activeView
                            .frame(maxHeight: .infinity)
                    } else {
                        resultsView
                            .frame(maxHeight: .infinity)
                    }
                }
            }
            .onTapGesture {
                if showFire {
                    recordShot()
                }
            }
        }
        .onAppear {
            setupMotionCallbacks()
            watchConnected = watchManager.isReachable
        }
        .onDisappear {
            stopMotionTracking()
        }
    }

    private var instructionsView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "hand.point.up.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Dry Fire Drill")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("Assume your shooting stance", systemImage: "figure.stand")
                Label("Screen turns RED = Fire!", systemImage: "circle.fill")
                Label("Tap screen as fast as you can", systemImage: "hand.tap")
                Label("Practice trigger control", systemImage: "scope")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Stepper("Shots: \(totalShots)", value: $totalShots, in: 5...20, step: 5)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()

            Button {
                startDrill()
            } label: {
                Text("Start")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
        }
        .padding(.horizontal)
    }

    private var activeView: some View {
        VStack(spacing: 32) {
            Text("Shot \(shotCount + 1) of \(totalShots)")
                .font(.headline)
                .foregroundStyle(showFire ? .white : .secondary)

            if showFire {
                VStack(spacing: 16) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(.white)
                    Text("FIRE!")
                        .font(.system(size: 48, weight: .black))
                        .foregroundStyle(.white)
                    Text("TAP NOW!")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.8))
                }
            } else if waitingForFire {
                VStack(spacing: 16) {
                    Image(systemName: "scope")
                        .font(.system(size: 80))
                        .foregroundStyle(.green)
                    Text("Ready...")
                        .font(.title)
                    Text("Aim and wait for RED")
                        .foregroundStyle(.secondary)

                    // Stance stability gauge from Watch
                    if watchManager.isReachable {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                                    .frame(width: 80, height: 80)

                                Circle()
                                    .trim(from: 0, to: stanceStability / 100.0)
                                    .stroke(
                                        stabilityColor,
                                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                    )
                                    .frame(width: 80, height: 80)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.easeInOut(duration: 0.3), value: stanceStability)

                                VStack(spacing: 0) {
                                    Text("\(Int(stanceStability))%")
                                        .font(.system(size: 18, weight: .bold))
                                    Text("Stable")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text(stabilityFeedback)
                                .font(.caption)
                                .foregroundStyle(stabilityColor)
                        }
                        .padding(.top, 8)
                    }
                }
            }

            if lastReactionTime > 0 {
                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text(String(format: "%.3fs", lastReactionTime))
                            .font(.headline)
                        Text("Reaction")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !shotStabilities.isEmpty, let lastStability = shotStabilities.last {
                        VStack(spacing: 4) {
                            Text("\(Int(lastStability))%")
                                .font(.headline)
                            Text("Stability")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .foregroundStyle(showFire ? .white.opacity(0.7) : .primary)
            }
        }
    }

    private var stabilityColor: Color {
        if stanceStability >= 80 { return .green }
        if stanceStability >= 60 { return .yellow }
        return .orange
    }

    private var stabilityFeedback: String {
        if stanceStability >= 85 { return "Excellent hold!" }
        if stanceStability >= 70 { return "Good stability" }
        if stanceStability >= 50 { return "Try to settle" }
        return "Relax and breathe"
    }

    private var resultsView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Drill Complete!")
                .font(.title.bold())

            let avgTime = reactionTimes.reduce(0, +) / Double(reactionTimes.count)
            let bestTime = reactionTimes.min() ?? 0
            let avgStability = shotStabilities.isEmpty ? 0.0 : shotStabilities.reduce(0, +) / Double(shotStabilities.count)

            VStack(spacing: 16) {
                // Reaction times
                HStack(spacing: 40) {
                    VStack {
                        Text(String(format: "%.3fs", avgTime))
                            .font(.title.bold())
                        Text("Avg Reaction")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    VStack {
                        Text(String(format: "%.3fs", bestTime))
                            .font(.title.bold())
                            .foregroundStyle(.green)
                        Text("Best")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Stability data from Watch
                if !shotStabilities.isEmpty {
                    Divider()
                        .padding(.vertical, 8)

                    HStack(spacing: 40) {
                        VStack {
                            Text("\(Int(avgStability))%")
                                .font(.title.bold())
                                .foregroundStyle(stabilityGradeColor(avgStability))
                            Text("Avg Stability")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        VStack {
                            Text("\(Int(shotStabilities.max() ?? 0))%")
                                .font(.title.bold())
                                .foregroundStyle(.green)
                            Text("Best")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(stabilityGrade(avgStability))
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(stabilityGradeColor(avgStability).opacity(0.2))
                        .foregroundStyle(stabilityGradeColor(avgStability))
                        .clipShape(Capsule())
                }

                // Grade
                Text(gradeForReaction(avgTime))
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(gradeColor(avgTime).opacity(0.2))
                    .foregroundStyle(gradeColor(avgTime))
                    .clipShape(Capsule())
            }

            Spacer()

            HStack(spacing: 16) {
                Button {
                    reactionTimes = []
                    shotStabilities = []
                    stabilityReadings = []
                    shotCount = 0
                } label: {
                    Text("Try Again")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    stopMotionTracking()
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }

    private func stabilityGradeColor(_ stability: Double) -> Color {
        if stability >= 80 { return .green }
        if stability >= 60 { return .yellow }
        return .orange
    }

    private func stabilityGrade(_ stability: Double) -> String {
        if stability >= 85 { return "Rock Steady!" }
        if stability >= 70 { return "Good Control" }
        if stability >= 50 { return "Work on Hold" }
        return "Needs Practice"
    }

    private func gradeForReaction(_ time: TimeInterval) -> String {
        if time < 0.25 { return "Lightning Fast!" }
        if time < 0.35 { return "Excellent" }
        if time < 0.45 { return "Good" }
        if time < 0.6 { return "Average" }
        return "Keep Practicing"
    }

    private func gradeColor(_ time: TimeInterval) -> Color {
        if time < 0.3 { return .green }
        if time < 0.45 { return .yellow }
        return .orange
    }

    private func startDrill() {
        isRunning = true
        shotCount = 0
        reactionTimes = []
        shotStabilities = []
        stabilityReadings = []

        // Start Watch motion tracking for shooting
        startMotionTracking()
        scheduleNextFire()
    }

    private func scheduleNextFire() {
        waitingForFire = true
        showFire = false
        stabilityReadings = []  // Reset readings for this shot

        let delay = TimeInterval.random(in: 1.5...4.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if isRunning {
                showFire = true
                fireStartTime = Date()

                // Record stability at moment of fire
                if !stabilityReadings.isEmpty {
                    let avgStability = stabilityReadings.reduce(0, +) / Double(stabilityReadings.count)
                    shotStabilities.append(avgStability)
                } else if watchManager.stanceStability > 0 {
                    shotStabilities.append(watchManager.stanceStability)
                }

                // Haptic
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
            }
        }
    }

    private func recordShot() {
        guard let start = fireStartTime else { return }

        let reactionTime = Date().timeIntervalSince(start)
        reactionTimes.append(reactionTime)
        lastReactionTime = reactionTime

        showFire = false
        waitingForFire = false
        shotCount += 1

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if shotCount >= totalShots {
            isRunning = false
            stopMotionTracking()
            let successGenerator = UINotificationFeedbackGenerator()
            successGenerator.notificationOccurred(.success)
        } else {
            scheduleNextFire()
        }
    }

    // MARK: - Watch Motion Tracking

    private func setupMotionCallbacks() {
        watchManager.onMotionUpdate = { mode, stability, _, _, _, _, _ in
            if mode == .shooting, let stability = stability {
                DispatchQueue.main.async {
                    self.stanceStability = stability
                    if self.waitingForFire {
                        self.stabilityReadings.append(stability)
                    }
                }
            }
        }
    }

    private func startMotionTracking() {
        watchManager.resetMotionMetrics()
        watchManager.startMotionTracking(mode: .shooting)
    }

    private func stopMotionTracking() {
        watchManager.stopMotionTracking()
        watchManager.onMotionUpdate = nil
    }
}
