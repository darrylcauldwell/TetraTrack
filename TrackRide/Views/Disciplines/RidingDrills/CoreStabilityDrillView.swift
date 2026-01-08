//
//  CoreStabilityDrillView.swift
//  TrackRide
//
//  Core stability drill for developing independent seat
//

import SwiftUI
import CoreMotion
import SwiftData
import Combine

struct CoreStabilityDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var streaks: [TrainingStreak]
    @StateObject private var motionManager = CoreMotionManager()

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
                Color.blue.opacity(0.1).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Core Stability")
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

            Image(systemName: "figure.core.training")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Core Stability Drill")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("Sit on exercise ball or unstable surface", systemImage: "circle.fill")
                Label("Hold phone at chest/core level", systemImage: "iphone")
                Label("Keep core engaged and steady", systemImage: "figure.core.training")
                Label("Minimize all rotation", systemImage: "arrow.triangle.2.circlepath")
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
                    .background(.blue)
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
                .foregroundStyle(.blue)
            Text("Engage your core")
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

            // Core stability visualizer - shows rotational movement
            ZStack {
                // Outer rings
                ForEach([0.2, 0.4, 0.6, 0.8, 1.0], id: \.self) { scale in
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        .frame(width: 200 * scale, height: 200 * scale)
                }

                // Crosshairs
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: 200)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 200, height: 1)

                // Movement indicator - combines roll and yaw
                Circle()
                    .fill(stabilityColor)
                    .frame(width: 30, height: 30)
                    .offset(
                        x: CGFloat(motionManager.roll * 80),
                        y: CGFloat(motionManager.yaw * 80)
                    )
                    .animation(.easeOut(duration: 0.1), value: motionManager.roll)

                // Center target
                Circle()
                    .fill(.blue)
                    .frame(width: 10, height: 10)

                // Stability score
                VStack {
                    Text("\(Int(motionManager.stabilityScore * 100))")
                        .font(.system(size: 24, weight: .bold))
                    Text("Core")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .offset(y: 100)
            }

            Text(stabilityMessage)
                .font(.headline)
                .foregroundStyle(stabilityColor)

            // Real-time stats
            HStack(spacing: 30) {
                VStack {
                    Text(String(format: "%.2f", abs(motionManager.roll * 57.3)))
                        .font(.headline.monospacedDigit())
                    Text("Roll")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.2f", abs(motionManager.yaw * 57.3)))
                        .font(.headline.monospacedDigit())
                    Text("Rotation")
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

            let avgStability = results.map { $0.stability }.reduce(0, +) / Double(max(results.count, 1))
            VStack {
                Text("\(Int(avgStability * 100))%")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(.blue)
                Text("Core Stability Score")
                    .foregroundStyle(.secondary)
            }

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
                        .background(.blue)
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
        if motionManager.stabilityScore > 0.9 { return "Excellent core control!" }
        if motionManager.stabilityScore > 0.7 { return "Good stability" }
        if motionManager.stabilityScore > 0.5 { return "Some movement detected" }
        return "Engage your core!"
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

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsedTime += 0.1
            results.append(StabilityResult(
                timestamp: elapsedTime,
                stability: motionManager.stabilityScore
            ))

            if elapsedTime >= targetDuration {
                endDrill()
            }
        }
    }

    private func endDrill() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        motionManager.stopUpdates()

        // Update streak
        if let streak = streak {
            streak.recordActivity()
            try? modelContext.save()
        } else {
            let newStreak = TrainingStreak()
            newStreak.recordActivity()
            modelContext.insert(newStreak)
            try? modelContext.save()
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - Core Motion Manager

@MainActor
class CoreMotionManager: ObservableObject {
    private let motionManager = CMMotionManager()

    @Published var pitch: Double = 0
    @Published var roll: Double = 0
    @Published var yaw: Double = 0
    @Published var totalMovement: Double = 0
    @Published var stabilityScore: Double = 1.0

    private var previousRoll: Double = 0
    private var previousYaw: Double = 0
    private var referenceYaw: Double?

    func startUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }

        referenceYaw = nil

        motionManager.deviceMotionUpdateInterval = 1/60
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, let self = self else { return }

            self.pitch = motion.attitude.pitch
            self.roll = motion.attitude.roll

            // Set reference yaw on first reading
            if self.referenceYaw == nil {
                self.referenceYaw = motion.attitude.yaw
            }
            self.yaw = motion.attitude.yaw - (self.referenceYaw ?? 0)

            // Calculate movement from roll and yaw
            let rollDelta = abs(self.roll - self.previousRoll)
            let yawDelta = abs(self.yaw - self.previousYaw)
            self.totalMovement = rollDelta + yawDelta

            // Calculate stability
            let movement = sqrt(rollDelta * rollDelta + yawDelta * yawDelta)
            let rawStability = max(0, 1 - (movement * 20))
            self.stabilityScore = self.stabilityScore * 0.9 + rawStability * 0.1

            self.previousRoll = self.roll
            self.previousYaw = self.yaw
        }
    }

    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}

#Preview {
    CoreStabilityDrillView()
        .modelContainer(for: TrainingStreak.self, inMemory: true)
}
