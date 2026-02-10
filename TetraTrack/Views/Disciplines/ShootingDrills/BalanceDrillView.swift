//
//  BalanceDrillView.swift
//  TetraTrack
//
//  Balance drill using device motion sensors for shooting stability training
//

import SwiftUI
import CoreMotion
import SwiftData
import Combine

// MARK: - Balance Drill View (Motion Sensors)

struct BalanceDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var motionManager = BalanceMotionManager()
    @State private var cueSystem = RealTimeCueSystem()

    @State private var isRunning = false
    @State private var countdown = 3
    @State private var elapsedTime: TimeInterval = 0
    @State private var timerStartDate: Date?
    @State private var targetDuration: TimeInterval = 30
    @State private var timer: Timer?
    @State private var results: [BalanceResult] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppColors.drillBalance.opacity(Opacity.light).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Balance Drill")
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
                                .background(AppColors.cardBackground)
                                .clipShape(Circle())
                        }
                    }
                    .padding()

                    // Content area - centered in remaining space
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
            .withRealTimeCues(cueSystem)
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
            motionManager.stopUpdates()
            cueSystem.reset()
        }
    }

    private var instructionsView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "figure.stand")
                        .font(.system(size: 60))
                        .foregroundStyle(AppColors.drillBalance)
                        .padding(.top, Spacing.xl)

                    Text("One-Leg Balance")
                        .font(.title2.bold())

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Hold phone in shooting stance", systemImage: "iphone")
                        Label("Stand on one leg", systemImage: "figure.stand")
                        Label("Stay as still as possible for \(Int(targetDuration))s", systemImage: "timer")
                        Label("Phone sensors measure your stability", systemImage: "gyroscope")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    PhonePlacementGuidanceView(placement: .chestHeld)
                        .padding(.horizontal, 32)

                    Picker("Duration", selection: $targetDuration) {
                        Text("15s").tag(TimeInterval(15))
                        Text("30s").tag(TimeInterval(30))
                        Text("45s").tag(TimeInterval(45))
                        Text("60s").tag(TimeInterval(60))
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal)
            }

            Button("Start Drill") {
                startCountdown()
            }
            .buttonStyle(DrillStartButtonStyle(color: AppColors.drillBalance))
            .accessibilityLabel("Start Balance Drill")
            .accessibilityHint("Begins the one-leg balance exercise with countdown")
            .padding(.horizontal, Spacing.jumbo)
            .padding(.bottom, Spacing.xl)
            .background(AppColors.drillBalance.opacity(Opacity.light).ignoresSafeArea(edges: .bottom))
        }
    }

    private var countdownView: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Get Ready!")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("\(countdown)")
                .scaledFont(size: 120, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                .foregroundStyle(AppColors.drillBalance)
            Text("Stand on one leg")
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

                // Wobble indicator (dot that moves with device motion)
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
                    Text(String(format: "%.2f°", abs(motionManager.pitch * 57.3)))
                        .font(.headline.monospacedDigit())
                    Text("Pitch")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.2f°", abs(motionManager.roll * 57.3)))
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
                .foregroundStyle(AppColors.active)

            Text("Complete!")
                .font(.title.bold())

            // Average stability
            let avgStability = results.map { $0.stability }.reduce(0, +) / Double(results.count)
            VStack {
                Text("\(Int(avgStability * 100))%")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(AppColors.drillBalance)
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

            HStack(spacing: Spacing.lg) {
                Button("Try Again") {
                    results = []
                    countdown = 3
                }
                .buttonStyle(DrillSecondaryButtonStyle())
                .accessibilityLabel("Try Again")
                .accessibilityHint("Restart the balance drill")

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(DrillDoneButtonStyle(color: AppColors.drillBalance))
                .accessibilityLabel("Done")
                .accessibilityHint("Close the drill and return to training")
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding()
    }

    private var stabilityColor: Color {
        StabilityColors.color(for: motionManager.stabilityScore)
    }

    private var stabilityMessage: String {
        if motionManager.stabilityScore > 0.9 { return "Excellent! Rock solid!" }
        if motionManager.stabilityScore > 0.7 { return "Good stability" }
        if motionManager.stabilityScore > 0.5 { return "Some wobble detected" }
        return "Try to stay still"
    }

    private func gradeForStability(_ score: Double) -> String {
        if score > 0.9 { return "Elite Marksman" }
        if score > 0.8 { return "Expert" }
        if score > 0.7 { return "Proficient" }
        if score > 0.5 { return "Developing" }
        return "Keep Practicing"
    }

    private func gradeColor(_ score: Double) -> Color {
        StabilityColors.gradeColor(for: score)
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

        timerStartDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let timerStartDate else { return }
            elapsedTime = Date().timeIntervalSince(timerStartDate)
            results.append(BalanceResult(
                timestamp: elapsedTime,
                stability: motionManager.stabilityScore
            ))

            // Process real-time cues
            cueSystem.processDrillState(score: motionManager.stabilityScore * 100, stability: motionManager.stabilityScore * 100, elapsed: elapsedTime, duration: targetDuration)

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
        cueSystem.reset()

        // Calculate average stability score
        let avgStability = results.isEmpty ? 0.0 : results.map { $0.stability }.reduce(0, +) / Double(results.count)

        // Save drill session to history
        let session = ShootingDrillSession(
            drillType: .balance,
            duration: targetDuration,
            score: avgStability * 100
        )
        session.stabilityScore = avgStability * 100
        modelContext.insert(session)
        try? modelContext.save()

        // Compute and save skill domain scores
        let skillService = SkillDomainService()
        let skillScores = skillService.computeScores(from: session)
        for skillScore in skillScores {
            modelContext.insert(skillScore)
        }
        try? modelContext.save()

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - Balance Result

struct BalanceResult {
    let timestamp: TimeInterval
    let stability: Double
}

// MARK: - Balance Motion Manager

class BalanceMotionManager: ObservableObject {
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
