//
//  StressInoculationDrillView.swift
//  TrackRide
//
//  Elevated heart rate shooting simulation for competition stress training
//

import SwiftUI
import SwiftData
import CoreMotion
import Combine

struct StressInoculationDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var motionManager = StressMotionManager()
    @State private var cueSystem = RealTimeCueSystem()
    @State private var phase: DrillPhase = .instructions
    @State private var warmupCountdown = 30
    @State private var shootingTime: TimeInterval = 0
    @State private var targetDuration: TimeInterval = 20
    @State private var timer: Timer?
    @State private var stabilityHistory: [Double] = []
    @State private var currentStability: Double = 0

    enum DrillPhase {
        case instructions
        case warmup
        case shooting
        case results
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                phaseBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    switch phase {
                    case .instructions:
                        instructionsView
                            .frame(maxHeight: .infinity)
                    case .warmup:
                        warmupView
                            .frame(maxHeight: .infinity)
                    case .shooting:
                        shootingView
                            .frame(maxHeight: .infinity)
                    case .results:
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

    private var phaseBackground: Color {
        switch phase {
        case .instructions: return AppColors.shooting.opacity(Opacity.light)
        case .warmup: return AppColors.running.opacity(Opacity.medium)
        case .shooting: return AppColors.error.opacity(Opacity.light)
        case .results: return AppColors.active.opacity(Opacity.light)
        }
    }

    private var header: some View {
        HStack {
            Text("Stress Inoculation")
                .font(.headline)
            Spacer()
            Button {
                motionManager.stopUpdates()
                timer?.invalidate()
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
    }

    private var instructionsView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "heart.text.square")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.shooting)

            Text("Stress Inoculation Drill")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("30 seconds of jumping jacks", systemImage: "figure.jumprope")
                Label("Immediately begin shooting drill", systemImage: "scope")
                Label("Test stability under stress", systemImage: "waveform.path.ecg")
                Label("Simulate competition conditions", systemImage: "flag.checkered")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Text("Competition stress affects your shooting.\nLearn to manage it.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .italic()
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Picker("Shooting Duration", selection: $targetDuration) {
                Text("15s").tag(TimeInterval(15))
                Text("20s").tag(TimeInterval(20))
                Text("30s").tag(TimeInterval(30))
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 32)

            Spacer()

            Button {
                startWarmup()
            } label: {
                HStack {
                    Image(systemName: "figure.jumprope")
                    Text("Start Warm-up")
                }
                .font(.title3.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppColors.shooting)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
            }
            .accessibilityLabel("Start Warm-up")
            .accessibilityHint("Begins 30 seconds of jumping jacks before shooting")
            .padding(.horizontal, Spacing.jumbo)
            .padding(.bottom, Spacing.xl)
        }
        .padding(.horizontal)
    }

    private var warmupView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Animated jumping figure
            Image(systemName: "figure.jumprope")
                .font(.system(size: 100))
                .foregroundStyle(AppColors.running)
                .symbolEffect(.bounce, options: .repeating)

            Text("JUMPING JACKS!")
                .font(.system(size: 32, weight: .black))
                .foregroundStyle(AppColors.running)

            Text("\(warmupCountdown)")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text("Keep moving! Get your heart rate up!")
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Progress indicator
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    Rectangle()
                        .fill(AppColors.running)
                        .frame(width: geo.size.width * (1 - Double(warmupCountdown) / 30))
                }
            }
            .frame(height: 12)
            .clipShape(Capsule())
            .padding(.horizontal, 40)

            Spacer()

            Text("Prepare to shoot when timer ends!")
                .font(.headline)
                .foregroundStyle(AppColors.running)
                .padding(.bottom, 20)
        }
    }

    private var shootingView: some View {
        VStack(spacing: 20) {
            // Timer
            Text(String(format: "%.1f", targetDuration - shootingTime))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(shootingTime > targetDuration - 5 ? .red : .primary)

            // Target scope
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: 220, height: 220)

                // Score rings
                ForEach([0.2, 0.4, 0.6, 0.8, 1.0], id: \.self) { scale in
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        .frame(width: 220 * scale, height: 220 * scale)
                }

                // Crosshairs
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 1, height: 220)
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 220, height: 1)

                // Aim point
                Circle()
                    .fill(stabilityColor)
                    .frame(width: 20, height: 20)
                    .offset(
                        x: CGFloat(motionManager.pitch * 100),
                        y: CGFloat(motionManager.roll * 100)
                    )
                    .animation(.easeOut(duration: 0.05), value: motionManager.wobble)

                // Center target
                Circle()
                    .fill(.red)
                    .frame(width: 10, height: 10)

                // Stability score
                VStack {
                    Spacer()
                    Text("\(Int(currentStability))%")
                        .font(.title2.bold())
                        .foregroundStyle(stabilityColor)
                    Text("Stability")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 220)
                .offset(y: 40)
            }

            Text(stressMessage)
                .font(.headline)
                .foregroundStyle(stabilityColor)

            // Wobble meter
            VStack(spacing: 4) {
                Text("Aim Wobble")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                        Rectangle()
                            .fill(stabilityColor)
                            .frame(width: geo.size.width * min(1, (1 - motionManager.wobble * 5)))
                    }
                }
                .frame(height: 16)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 40)

            // Stats
            HStack(spacing: 30) {
                VStack {
                    let avgStability = stabilityHistory.isEmpty ? 0 : stabilityHistory.reduce(0, +) / Double(stabilityHistory.count)
                    Text("\(Int(avgStability))%")
                        .font(.headline)
                    Text("Average")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.2f°", motionManager.wobble * 57.3))
                        .font(.headline.monospacedDigit())
                    Text("Wobble")
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

            let avgStability = stabilityHistory.isEmpty ? 0 : stabilityHistory.reduce(0, +) / Double(stabilityHistory.count)

            VStack(spacing: 8) {
                Text("\(Int(avgStability))%")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(AppColors.shooting)
                Text("Stability Under Stress")
                    .foregroundStyle(.secondary)
            }

            // Performance comparison text
            VStack(spacing: 8) {
                Text("Post-Exercise Performance")
                    .font(.headline)

                if avgStability >= 70 {
                    Text("Excellent stress management! You maintain composure under pressure.")
                        .foregroundStyle(.green)
                } else if avgStability >= 50 {
                    Text("Good progress! With practice, you'll improve your stress resilience.")
                        .foregroundStyle(.yellow)
                } else {
                    Text("Competition stress is affecting your aim. Regular stress training will help!")
                        .foregroundStyle(AppColors.running)
                }
            }
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Text(gradeForScore(avgStability))
                .font(.title2.bold())
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(gradeColor(avgStability).opacity(0.2))
                .foregroundStyle(gradeColor(avgStability))
                .clipShape(Capsule())

            Spacer()

            HStack(spacing: Spacing.lg) {
                Button("Try Again") {
                    phase = .instructions
                    stabilityHistory = []
                    shootingTime = 0
                    warmupCountdown = 30
                }
                .buttonStyle(DrillSecondaryButtonStyle())
                .accessibilityLabel("Try Again")
                .accessibilityHint("Restart the stress inoculation drill")

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(DrillDoneButtonStyle(color: AppColors.shooting))
                .accessibilityLabel("Done")
                .accessibilityHint("Close the drill and return to training")
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding()
    }

    private var stabilityColor: Color {
        if currentStability >= 70 { return AppColors.active }
        if currentStability >= 50 { return AppColors.warning }
        if currentStability >= 30 { return AppColors.running }
        return AppColors.error
    }

    private var stressMessage: String {
        if currentStability >= 80 { return "Cool under pressure!" }
        if currentStability >= 60 { return "Managing the stress" }
        if currentStability >= 40 { return "Heart rate affecting aim" }
        return "Focus! Control your breathing"
    }

    private func gradeForScore(_ score: Double) -> String {
        if score >= 80 { return "Ice Cold!" }
        if score >= 65 { return "Stress Resistant" }
        if score >= 50 { return "Managing Pressure" }
        if score >= 35 { return "Building Resilience" }
        return "Keep Training"
    }

    private func gradeColor(_ score: Double) -> Color {
        if score >= 70 { return AppColors.active }
        if score >= 50 { return AppColors.warning }
        return AppColors.running
    }

    private func startWarmup() {
        phase = .warmup
        warmupCountdown = 30

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            warmupCountdown -= 1

            // Haptic every 5 seconds
            if warmupCountdown % 5 == 0 {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }

            if warmupCountdown <= 0 {
                timer?.invalidate()
                startShooting()
            }
        }
    }

    private func startShooting() {
        phase = .shooting
        shootingTime = 0
        stabilityHistory = []
        currentStability = 0
        motionManager.startUpdates()

        // Strong haptic to signal start
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            shootingTime += 0.1

            // Calculate current stability from wobble
            let wobbleStability = max(0, 100 - (motionManager.wobble * 200))
            currentStability = currentStability * 0.8 + wobbleStability * 0.2
            stabilityHistory.append(currentStability)

            // Process real-time cues
            cueSystem.processDrillState(score: currentStability, stability: currentStability, elapsed: shootingTime, duration: targetDuration)

            if shootingTime >= targetDuration {
                endDrill()
            }
        }
    }

    private func endDrill() {
        timer?.invalidate()
        timer = nil
        motionManager.stopUpdates()
        cueSystem.reset()
        phase = .results

        let avgStability = stabilityHistory.isEmpty ? 0 : stabilityHistory.reduce(0, +) / Double(stabilityHistory.count)

        // Save session
        let session = ShootingDrillSession(
            drillType: .stressInoculation,
            duration: targetDuration + 30, // Include warmup
            score: avgStability,
            stabilityScore: avgStability,
            averageWobble: motionManager.averageWobble
        )
        modelContext.insert(session)
        try? modelContext.save()

        // Compute and save skill domain scores
        let skillService = SkillDomainService()
        let skillScores = skillService.computeScores(from: session)
        for skillScore in skillScores {
            modelContext.insert(skillScore)
        }
        try? modelContext.save()

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - Stress Motion Manager

@MainActor
class StressMotionManager: ObservableObject {
    private let motionManager = CMMotionManager()

    @Published var pitch: Double = 0
    @Published var roll: Double = 0
    @Published var wobble: Double = 0
    @Published var averageWobble: Double = 0

    private var referencePitch: Double?
    private var referenceRoll: Double?
    private var wobbleSum: Double = 0
    private var sampleCount: Int = 0

    func startUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }

        referencePitch = nil
        referenceRoll = nil
        wobbleSum = 0
        sampleCount = 0

        motionManager.deviceMotionUpdateInterval = 1/60
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, let self = self else { return }

            if self.referencePitch == nil {
                self.referencePitch = motion.attitude.pitch
                self.referenceRoll = motion.attitude.roll
            }

            self.pitch = motion.attitude.pitch - (self.referencePitch ?? 0)
            self.roll = motion.attitude.roll - (self.referenceRoll ?? 0)
            self.wobble = sqrt(self.pitch * self.pitch + self.roll * self.roll)

            self.wobbleSum += self.wobble
            self.sampleCount += 1
            self.averageWobble = self.wobbleSum / Double(self.sampleCount)
        }
    }

    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}

#Preview {
    StressInoculationDrillView()
}
