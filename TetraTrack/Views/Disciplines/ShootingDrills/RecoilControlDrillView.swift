//
//  RecoilControlDrillView.swift
//  TetraTrack
//
//  Simulated recoil recovery drill - practice returning to target quickly
//

import SwiftUI
import SwiftData
import CoreMotion
import Combine

struct RecoilControlDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var motionManager = RecoilMotionManager()
    @State private var cueSystem = RealTimeCueSystem()
    @State private var isRunning = false
    @State private var currentRound = 0
    @State private var totalRounds = 10
    @State private var recoveryTimes: [TimeInterval] = []
    @State private var showRecoil = false
    @State private var recoilStartTime: Date?
    @State private var isRecovered = false
    @State private var waitingForStable = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppColors.shooting.opacity(Opacity.light).ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if !isRunning && recoveryTimes.isEmpty {
                        instructionsView
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
            motionManager.stopUpdates()
            cueSystem.reset()
        }
    }

    private var header: some View {
        HStack {
            Text("Recoil Control")
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
    }

    private var instructionsView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.shooting)

            Text("Recoil Control Drill")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("Hold phone like aiming", systemImage: "scope")
                Label("Keep crosshairs on target", systemImage: "target")
                Label("\"Shot\" will bump your aim", systemImage: "waveform.path.badge.minus")
                Label("Return to center as fast as possible", systemImage: "arrow.uturn.backward")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Stepper("Rounds: \(totalRounds)", value: $totalRounds, in: 5...20, step: 5)
                .padding()
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 32)

            Spacer()

            Button("Start") {
                startDrill()
            }
            .buttonStyle(DrillStartButtonStyle(color: AppColors.shooting))
            .accessibilityLabel("Start Recoil Control Drill")
            .accessibilityHint("Begins the recoil recovery practice")
            .padding(.horizontal, Spacing.jumbo)
            .padding(.bottom, Spacing.xl)
        }
        .padding(.horizontal)
    }

    private var activeDrillView: some View {
        VStack(spacing: 20) {
            // Progress
            Text("Round \(currentRound)/\(totalRounds)")
                .font(.headline)
                .foregroundStyle(.secondary)

            // Target scope view
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: 250, height: 250)

                // Score rings
                ForEach([0.2, 0.4, 0.6, 0.8, 1.0], id: \.self) { scale in
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        .frame(width: 250 * scale, height: 250 * scale)
                }

                // Crosshairs
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 1, height: 250)
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 250, height: 1)

                // Aim point indicator
                Circle()
                    .fill(aimColor)
                    .frame(width: 20, height: 20)
                    .offset(
                        x: CGFloat(motionManager.pitch * 100),
                        y: CGFloat(motionManager.roll * 100)
                    )
                    .animation(.easeOut(duration: 0.05), value: motionManager.pitch)

                // Center target
                Circle()
                    .fill(isRecovered ? .green : .red)
                    .frame(width: 12, height: 12)
            }

            // Status message
            Text(statusMessage)
                .font(.title3.bold())
                .foregroundStyle(statusColor)

            // Last recovery time
            if let lastTime = recoveryTimes.last {
                VStack(spacing: 4) {
                    Text(String(format: "%.3fs", lastTime))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(timeColor(lastTime))
                    Text("Last Recovery")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Stats
            HStack(spacing: 32) {
                VStack {
                    Text("\(recoveryTimes.count)")
                        .font(.headline)
                    Text("Recovered")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !recoveryTimes.isEmpty {
                    VStack {
                        let avg = recoveryTimes.reduce(0, +) / Double(recoveryTimes.count)
                        Text(String(format: "%.3fs", avg))
                            .font(.headline)
                        Text("Average")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var resultsView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.active)

            Text("Complete!")
                .font(.title.bold())

            let avgRecovery = recoveryTimes.isEmpty ? 0 : recoveryTimes.reduce(0, +) / Double(recoveryTimes.count)
            let bestRecovery = recoveryTimes.min() ?? 0

            VStack(spacing: 8) {
                Text(String(format: "%.3fs", avgRecovery))
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(AppColors.shooting)
                Text("Average Recovery")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 32) {
                VStack {
                    Text(String(format: "%.3fs", bestRecovery))
                        .font(.title2.bold())
                        .foregroundStyle(AppColors.active)
                    Text("Best")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    let worstRecovery = recoveryTimes.max() ?? 0
                    Text(String(format: "%.3fs", worstRecovery))
                        .font(.title2.bold())
                        .foregroundStyle(AppColors.running)
                    Text("Slowest")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Score based on average recovery time
            let score = max(0, min(100, (1.0 - avgRecovery) * 100))
            Text(gradeForScore(score))
                .font(.title2.bold())
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(gradeColor(score).opacity(0.2))
                .foregroundStyle(gradeColor(score))
                .clipShape(Capsule())

            Spacer()

            HStack(spacing: Spacing.lg) {
                Button("Try Again") {
                    recoveryTimes = []
                    currentRound = 0
                }
                .buttonStyle(DrillSecondaryButtonStyle())
                .accessibilityLabel("Try Again")
                .accessibilityHint("Restart the recoil control drill")

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

    private var aimColor: Color {
        let distance = sqrt(pow(motionManager.pitch, 2) + pow(motionManager.roll, 2))
        if distance < 0.05 { return AppColors.active }
        if distance < 0.1 { return AppColors.warning }
        return AppColors.error
    }

    private var statusMessage: String {
        if waitingForStable {
            return "Steady... Get on target"
        } else if showRecoil {
            return "RECOVER!"
        } else if isRecovered {
            return "Good! Next shot coming..."
        } else {
            return "Hold steady"
        }
    }

    private var statusColor: Color {
        if showRecoil { return AppColors.error }
        if isRecovered { return AppColors.active }
        return .primary
    }

    private func timeColor(_ time: TimeInterval) -> Color {
        if time < 0.3 { return AppColors.active }
        if time < 0.5 { return AppColors.warning }
        return AppColors.running
    }

    private func gradeForScore(_ score: Double) -> String {
        if score >= 80 { return "Quick Draw!" }
        if score >= 60 { return "Fast Recovery" }
        if score >= 40 { return "Good Control" }
        return "Keep Practicing"
    }

    private func gradeColor(_ score: Double) -> Color {
        if score >= 70 { return AppColors.active }
        if score >= 50 { return AppColors.warning }
        return AppColors.running
    }

    private func startDrill() {
        isRunning = true
        currentRound = 0
        recoveryTimes = []
        motionManager.startUpdates()
        waitingForStable = true
        checkStableAndShoot()
    }

    private func checkStableAndShoot() {
        // Wait until stable, then trigger recoil
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak motionManager] timer in
            Task { @MainActor in
                guard let motionManager = motionManager else {
                    timer.invalidate()
                    return
                }
                let isStable = sqrt(pow(motionManager.pitch, 2) + pow(motionManager.roll, 2)) < 0.08

                if isStable && self.waitingForStable {
                    self.waitingForStable = false
                    timer.invalidate()

                    // Random delay before "shot"
                    try? await Task.sleep(for: .milliseconds(Int.random(in: 500...2000)))
                    self.triggerRecoil()
                }
            }
        }
    }

    private func triggerRecoil() {
        currentRound += 1

        if currentRound > totalRounds {
            endDrill()
            return
        }

        showRecoil = true
        isRecovered = false
        recoilStartTime = Date()

        // Heavy haptic for "shot"
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        // Monitor for recovery
        checkRecovery()
    }

    private func checkRecovery() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak motionManager] timer in
            Task { @MainActor in
                guard let motionManager = motionManager else {
                    timer.invalidate()
                    return
                }

                let distance = sqrt(pow(motionManager.pitch, 2) + pow(motionManager.roll, 2))

                if distance < 0.08 && self.showRecoil {
                    // Recovered!
                    if let startTime = self.recoilStartTime {
                        let recoveryTime = Date().timeIntervalSince(startTime)
                        self.recoveryTimes.append(recoveryTime)
                    }

                    self.showRecoil = false
                    self.isRecovered = true
                    timer.invalidate()

                    let successGenerator = UINotificationFeedbackGenerator()
                    successGenerator.notificationOccurred(.success)

                    // Setup next round
                    try? await Task.sleep(for: .milliseconds(500))
                    self.waitingForStable = true
                    self.isRecovered = false
                    self.checkStableAndShoot()
                }

                // Auto-fail after 2 seconds
                if let startTime = self.recoilStartTime,
                   Date().timeIntervalSince(startTime) > 2.0 && self.showRecoil {
                    self.recoveryTimes.append(2.0)
                    self.showRecoil = false
                    timer.invalidate()

                    try? await Task.sleep(for: .milliseconds(300))
                    self.waitingForStable = true
                    self.checkStableAndShoot()
                }
            }
        }
    }

    private func endDrill() {
        isRunning = false
        motionManager.stopUpdates()
        cueSystem.reset()

        let avgRecovery = recoveryTimes.isEmpty ? 1.0 : recoveryTimes.reduce(0, +) / Double(recoveryTimes.count)
        let score = max(0, min(100, (1.0 - avgRecovery) * 100))

        // Save session
        let session = ShootingDrillSession(
            drillType: .recoilControl,
            duration: TimeInterval(totalRounds * 3),
            score: score,
            stabilityScore: 0,
            recoveryScore: score,
            bestReactionTime: recoveryTimes.min() ?? 0
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

// MARK: - Recoil Motion Manager

@MainActor
class RecoilMotionManager: ObservableObject {
    private let motionManager = CMMotionManager()

    @Published var pitch: Double = 0
    @Published var roll: Double = 0

    private var referencePitch: Double?
    private var referenceRoll: Double?

    func startUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }

        referencePitch = nil
        referenceRoll = nil

        motionManager.deviceMotionUpdateInterval = 1/60
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, let self = self else { return }

            if self.referencePitch == nil {
                self.referencePitch = motion.attitude.pitch
                self.referenceRoll = motion.attitude.roll
            }

            self.pitch = motion.attitude.pitch - (self.referencePitch ?? 0)
            self.roll = motion.attitude.roll - (self.referenceRoll ?? 0)
        }
    }

    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}

#Preview {
    RecoilControlDrillView()
}
