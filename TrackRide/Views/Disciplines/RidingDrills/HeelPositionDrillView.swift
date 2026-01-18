//
//  HeelPositionDrillView.swift
//  TrackRide
//
//  Heel position drill using device motion sensors for rider balance training
//

import SwiftUI
import CoreMotion
import SwiftData
import Combine

struct HeelPositionDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var streaks: [TrainingStreak]
    @StateObject private var motionManager = RidingMotionManager()

    @State private var isRunning = false
    @State private var countdown = 3
    @State private var elapsedTime: TimeInterval = 0
    @State private var targetDuration: TimeInterval = 30
    @State private var timer: Timer?
    @State private var results: [StabilityResult] = []

    private var streak: TrainingStreak? {
        streaks.first
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.green.opacity(0.1).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Heel Position")
                            .font(.headline)
                        Spacer()
                        Button {
                            motionManager.stopUpdates()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    .padding()

                    // Content area
                    if !isRunning && countdown == 3 && results.isEmpty {
                        instructionsView
                            .frame(maxHeight: .infinity)
                    } else if countdown > 0 && isRunning == false {
                        countdownView
                            .frame(maxHeight: .infinity)
                    } else if isRunning {
                        activeDrillView
                            .frame(maxHeight: .infinity)
                    } else {
                        resultsView
                            .frame(maxHeight: .infinity)
                    }
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
            motionManager.stopUpdates()
        }
    }

    private var instructionsView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "figure.stand")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Heel Position Drill")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("Stand on step with heels hanging off", systemImage: "stairs")
                Label("Hold phone at chest level", systemImage: "iphone")
                Label("Keep heels pushed down", systemImage: "arrow.down")
                Label("Maintain balance for the duration", systemImage: "timer")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Picker("Duration", selection: $targetDuration) {
                Text("15s").tag(TimeInterval(15))
                Text("30s").tag(TimeInterval(30))
                Text("45s").tag(TimeInterval(45))
                Text("60s").tag(TimeInterval(60))
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 32)

            Spacer()

            Button {
                startCountdown()
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

    private var countdownView: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Get Ready!")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("\(countdown)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
            Text("Heels down, weight in stirrups")
                .font(.headline)
            Spacer()
        }
    }

    private var activeDrillView: some View {
        VStack(spacing: 24) {
            // Timer
            Text(String(format: "%.1f", targetDuration - elapsedTime))
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(elapsedTime > targetDuration - 5 ? .red : .primary)

            // Stability indicator
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 20)
                    .frame(width: 200, height: 200)

                Circle()
                    .stroke(stabilityColor, lineWidth: 20)
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: motionManager.stabilityScore)

                // Wobble indicator
                Circle()
                    .fill(stabilityColor)
                    .frame(width: 30, height: 30)
                    .offset(
                        x: CGFloat(motionManager.pitch * 80),
                        y: CGFloat(motionManager.roll * 80)
                    )
                    .animation(.easeOut(duration: 0.1), value: motionManager.pitch)

                VStack {
                    Text("\(Int(motionManager.stabilityScore * 100))")
                        .font(.system(size: 48, weight: .bold))
                    Text("Stability")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(stabilityMessage)
                .font(.headline)
                .foregroundStyle(stabilityColor)

            // Real-time stats
            HStack(spacing: 30) {
                VStack {
                    Text(String(format: "%.2f", abs(motionManager.pitch * 57.3)))
                        .font(.headline.monospacedDigit())
                    Text("Pitch")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.2f", abs(motionManager.roll * 57.3)))
                        .font(.headline.monospacedDigit())
                    Text("Roll")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.3f", motionManager.totalMovement))
                        .font(.headline.monospacedDigit())
                    Text("Movement")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var resultsView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Complete!")
                .font(.title.bold())

            // Average stability
            let avgStability = results.map { $0.stability }.reduce(0, +) / Double(max(results.count, 1))
            VStack {
                Text("\(Int(avgStability * 100))%")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(.green)
                Text("Average Stability")
                    .foregroundStyle(.secondary)
            }

            // Grade
            Text(gradeForStability(avgStability))
                .font(.title2.bold())
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(gradeColor(avgStability).opacity(0.2))
                .foregroundStyle(gradeColor(avgStability))
                .clipShape(Capsule())

            Spacer()

            HStack(spacing: 16) {
                Button {
                    results = []
                    countdown = 3
                } label: {
                    Text("Try Again")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
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

    private var stabilityColor: Color {
        if motionManager.stabilityScore > 0.8 { return .green }
        if motionManager.stabilityScore > 0.5 { return .yellow }
        return .red
    }

    private var stabilityMessage: String {
        if motionManager.stabilityScore > 0.9 { return "Excellent! Rock solid!" }
        if motionManager.stabilityScore > 0.7 { return "Good stability" }
        if motionManager.stabilityScore > 0.5 { return "Some wobble detected" }
        return "Keep those heels down!"
    }

    private func gradeForStability(_ score: Double) -> String {
        if score > 0.9 { return "Competition Ready" }
        if score > 0.8 { return "Event Level" }
        if score > 0.7 { return "Building Strength" }
        if score > 0.5 { return "Developing" }
        return "Keep Practicing"
    }

    private func gradeColor(_ score: Double) -> Color {
        if score > 0.8 { return .green }
        if score > 0.6 { return .yellow }
        return .orange
    }

    private func startCountdown() {
        countdown = 3
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            countdown -= 1
            if countdown == 0 {
                t.invalidate()
                startDrill()
            }
        }
    }

    private func startDrill() {
        isRunning = true
        elapsedTime = 0
        motionManager.startUpdates()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak motionManager] _ in
            Task { @MainActor in
                guard let motionManager = motionManager else { return }
                self.elapsedTime += 0.1
                self.results.append(StabilityResult(
                    timestamp: self.elapsedTime,
                    stability: motionManager.stabilityScore
                ))

                if self.elapsedTime >= self.targetDuration {
                    self.endDrill()
                }
            }
        }
    }

    private func endDrill() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        motionManager.stopUpdates()

        // Calculate average stability score
        let avgStability = results.map { $0.stability }.reduce(0, +) / Double(max(results.count, 1))

        // Save unified drill session
        let session = UnifiedDrillSession(
            drillType: .heelPosition,
            duration: targetDuration,
            score: avgStability * 100
        )
        modelContext.insert(session)

        // Compute and save skill domain scores for profile integration
        let skillService = SkillDomainService()
        let skillScores = skillService.computeScores(from: session)
        for skillScore in skillScores {
            modelContext.insert(skillScore)
        }

        // Update streak
        if let streak = streak {
            streak.recordActivity()
        } else {
            let newStreak = TrainingStreak()
            newStreak.recordActivity()
            modelContext.insert(newStreak)
        }

        try? modelContext.save()

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - Stability Result

struct StabilityResult {
    let timestamp: TimeInterval
    let stability: Double
}

// MARK: - Riding Motion Manager

@MainActor
class RidingMotionManager: ObservableObject {
    private let motionManager = CMMotionManager()

    @Published var pitch: Double = 0
    @Published var roll: Double = 0
    @Published var yaw: Double = 0
    @Published var totalMovement: Double = 0
    @Published var stabilityScore: Double = 1.0

    private var previousPitch: Double = 0
    private var previousRoll: Double = 0

    func startUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 1/60
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, let self = self else { return }

            self.pitch = motion.attitude.pitch
            self.roll = motion.attitude.roll
            self.yaw = motion.attitude.yaw

            // Calculate movement from previous frame
            let pitchDelta = abs(self.pitch - self.previousPitch)
            let rollDelta = abs(self.roll - self.previousRoll)
            self.totalMovement = pitchDelta + rollDelta

            // Calculate stability (inverse of movement, smoothed)
            let movement = sqrt(pitchDelta * pitchDelta + rollDelta * rollDelta)
            let rawStability = max(0, 1 - (movement * 20))
            self.stabilityScore = self.stabilityScore * 0.9 + rawStability * 0.1

            self.previousPitch = self.pitch
            self.previousRoll = self.roll
        }
    }

    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}

#Preview {
    HeelPositionDrillView()
        .modelContainer(for: TrainingStreak.self, inMemory: true)
}
