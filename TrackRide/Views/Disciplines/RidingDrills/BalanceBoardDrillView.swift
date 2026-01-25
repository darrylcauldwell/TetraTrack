//
//  BalanceBoardDrillView.swift
//  TrackRide
//
//  Balance board drill to simulate absorbing horse movement
//

import SwiftUI
import CoreMotion
import SwiftData
import Combine

struct BalanceBoardDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var streaks: [TrainingStreak]
    @StateObject private var motionManager = BalanceBoardMotionManager()

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
                AppColors.riding.opacity(Opacity.light).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Balance Board")
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

            Image(systemName: "figure.surfing")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.riding)

            Text("Balance Board Drill")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("Stand on wobble board or cushion", systemImage: "circle.dotted")
                Label("Hold phone at chest level", systemImage: "iphone")
                Label("Absorb movement smoothly", systemImage: "waveform.path")
                Label("Simulate horse's motion", systemImage: "figure.equestrian.sports")
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

            Spacer()

            Button("Start") {
                startCountdown()
            }
            .buttonStyle(DrillStartButtonStyle(color: AppColors.riding))
            .accessibilityLabel("Start Balance Board Drill")
            .accessibilityHint("Begins the movement absorption practice")
            .padding(.horizontal, Spacing.jumbo)
            .padding(.bottom, Spacing.xl)
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
                .foregroundStyle(AppColors.riding)
            Text("Step onto your balance board")
                .font(.headline)
            Spacer()
        }
    }

    private var activeDrillView: some View {
        VStack(spacing: 24) {
            // Timer
            Text(String(format: "%.1f", targetDuration - elapsedTime))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(elapsedTime > targetDuration - 5 ? .red : .primary)

            // Balance visualization - simulated horse movement
            ZStack {
                // Ground reference
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 250, height: 20)
                    .offset(y: 80)

                // Board representation
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.brown)
                    .frame(width: 200, height: 10)
                    .rotationEffect(.degrees(motionManager.roll * 30))
                    .offset(y: 70)
                    .animation(.easeOut(duration: 0.1), value: motionManager.roll)

                // Balance indicator circle
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                        .frame(width: 200, height: 200)

                    // Target zones
                    ForEach([0.3, 0.6, 0.9], id: \.self) { scale in
                        Circle()
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                            .frame(width: 200 * scale, height: 200 * scale)
                    }

                    // Crosshairs
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1, height: 200)
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 200, height: 1)

                    // Moving balance point
                    Circle()
                        .fill(stabilityColor)
                        .frame(width: 25, height: 25)
                        .shadow(color: stabilityColor.opacity(0.5), radius: 8)
                        .offset(
                            x: CGFloat(motionManager.roll * 80),
                            y: CGFloat(motionManager.pitch * 80)
                        )
                        .animation(.easeOut(duration: 0.05), value: motionManager.roll)

                    // Center target
                    Circle()
                        .fill(AppColors.riding)
                        .frame(width: 8, height: 8)
                }

                // Stability score overlay
                VStack {
                    Spacer()
                    HStack {
                        Text("\(Int(motionManager.absorptionScore * 100))")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(stabilityColor)
                        Text("absorption")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 250)
            }

            Text(stabilityMessage)
                .font(.headline)
                .foregroundStyle(stabilityColor)

            // Movement metrics
            HStack(spacing: 24) {
                VStack {
                    Text(String(format: "%.1f", abs(motionManager.pitch * 57.3)))
                        .font(.headline.monospacedDigit())
                    Text("Forward")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.1f", abs(motionManager.roll * 57.3)))
                        .font(.headline.monospacedDigit())
                    Text("Lateral")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.2f", motionManager.smoothness))
                        .font(.headline.monospacedDigit())
                    Text("Smooth")
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

            let avgAbsorption = results.map { $0.stability }.reduce(0, +) / Double(max(results.count, 1))
            VStack {
                Text("\(Int(avgAbsorption * 100))%")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(AppColors.riding)
                Text("Movement Absorption")
                    .foregroundStyle(.secondary)
            }

            Text(gradeForAbsorption(avgAbsorption))
                .font(.title2.bold())
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(gradeColor(avgAbsorption).opacity(0.2))
                .foregroundStyle(gradeColor(avgAbsorption))
                .clipShape(Capsule())

            Spacer()

            HStack(spacing: Spacing.lg) {
                Button("Try Again") {
                    results = []
                    countdown = 3
                }
                .buttonStyle(DrillSecondaryButtonStyle())
                .accessibilityLabel("Try Again")
                .accessibilityHint("Restart the balance board drill")

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(DrillDoneButtonStyle(color: AppColors.riding))
                .accessibilityLabel("Done")
                .accessibilityHint("Close the drill and return to training")
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding()
    }

    private var stabilityColor: Color {
        if motionManager.absorptionScore > 0.8 { return AppColors.active }
        if motionManager.absorptionScore > 0.5 { return AppColors.warning }
        return AppColors.error
    }

    private var stabilityMessage: String {
        if motionManager.absorptionScore > 0.9 { return "Excellent absorption!" }
        if motionManager.absorptionScore > 0.7 { return "Smooth movement" }
        if motionManager.absorptionScore > 0.5 { return "Keep it fluid" }
        return "Absorb the movement!"
    }

    private func gradeForAbsorption(_ score: Double) -> String {
        if score > 0.9 { return "Competition Ready" }
        if score > 0.8 { return "Event Level" }
        if score > 0.7 { return "Building Skill" }
        if score > 0.5 { return "Developing" }
        return "Keep Practicing"
    }

    private func gradeColor(_ score: Double) -> Color {
        if score > 0.8 { return AppColors.active }
        if score > 0.6 { return AppColors.warning }
        return AppColors.running
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
                stability: motionManager.absorptionScore
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

        // Calculate average absorption score
        let avgAbsorption = results.map { $0.stability }.reduce(0, +) / Double(max(results.count, 1))

        // Save unified drill session
        let session = UnifiedDrillSession(
            drillType: .balanceBoard,
            duration: targetDuration,
            score: avgAbsorption * 100
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

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - Balance Board Motion Manager

@MainActor
class BalanceBoardMotionManager: ObservableObject {
    private let motionManager = CMMotionManager()

    @Published var pitch: Double = 0
    @Published var roll: Double = 0
    @Published var absorptionScore: Double = 1.0
    @Published var smoothness: Double = 1.0

    private var previousPitch: Double = 0
    private var previousRoll: Double = 0
    private var velocityHistory: [Double] = []

    func startUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }

        velocityHistory = []

        motionManager.deviceMotionUpdateInterval = 1/60
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, let self = self else { return }

            self.pitch = motion.attitude.pitch
            self.roll = motion.attitude.roll

            // Calculate movement velocity
            let pitchDelta = abs(self.pitch - self.previousPitch)
            let rollDelta = abs(self.roll - self.previousRoll)
            let velocity = sqrt(pitchDelta * pitchDelta + rollDelta * rollDelta)

            // Track velocity history for smoothness calculation
            self.velocityHistory.append(velocity)
            if self.velocityHistory.count > 30 { // Keep ~0.5 seconds of history
                self.velocityHistory.removeFirst()
            }

            // Calculate smoothness (lower variance = smoother)
            let avgVelocity = self.velocityHistory.reduce(0, +) / Double(self.velocityHistory.count)
            let variance = self.velocityHistory.map { pow($0 - avgVelocity, 2) }.reduce(0, +) / Double(self.velocityHistory.count)
            self.smoothness = max(0, 1 - sqrt(variance) * 50)

            // Absorption score considers both staying centered and smooth movement
            let centeredness = max(0, 1 - sqrt(self.pitch * self.pitch + self.roll * self.roll) * 3)
            self.absorptionScore = self.absorptionScore * 0.9 + (centeredness * 0.7 + self.smoothness * 0.3) * 0.1

            self.previousPitch = self.pitch
            self.previousRoll = self.roll
        }
    }

    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}

#Preview {
    BalanceBoardDrillView()
        .modelContainer(for: TrainingStreak.self, inMemory: true)
}
