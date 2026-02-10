//
//  SteadyHoldDrillView.swift
//  TetraTrack
//
//  Steady hold drill using device motion sensors for aiming stability practice
//

import SwiftUI
import CoreMotion
import SwiftData
import Combine

// MARK: - Steady Hold Drill View

struct SteadyHoldDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var motionManager = SteadyHoldMotionManager()
    @State private var cueSystem = RealTimeCueSystem()

    @State private var isRunning = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var timerStartDate: Date?
    @State private var targetDuration: TimeInterval = 10
    @State private var timer: Timer?
    @State private var wobbleHistory: [Double] = []
    @State private var bestScore: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppColors.cyan.opacity(Opacity.light).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Steady Hold")
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
                    if !isRunning && wobbleHistory.isEmpty {
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
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "scope")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.cyan)

            Text("Steady Hold Drill")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("Hold phone like you're aiming", systemImage: "iphone")
                Label("Keep crosshairs centered", systemImage: "scope")
                Label("Minimize all movement", systemImage: "hand.raised")
                Label("Practice your trigger squeeze", systemImage: "hand.point.up")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            PhonePlacementGuidanceView(placement: .twoHandedGrip)
                .padding(.horizontal, 32)

            Picker("Duration", selection: $targetDuration) {
                Text("5s").tag(TimeInterval(5))
                Text("10s").tag(TimeInterval(10))
                Text("15s").tag(TimeInterval(15))
                Text("20s").tag(TimeInterval(20))
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 32)

            Spacer()

            Button("Start") {
                startDrill()
            }
            .buttonStyle(DrillStartButtonStyle(color: AppColors.cyan))
            .accessibilityLabel("Start Steady Hold Drill")
            .accessibilityHint("Begins the aiming stability exercise")
            .padding(.horizontal, Spacing.jumbo)
            .padding(.bottom, Spacing.xl)
        }
        .padding(.horizontal)
    }

    private var activeView: some View {
        VStack(spacing: 24) {
            // Timer
            Text(String(format: "%.1f", targetDuration - elapsedTime))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()

            // Scope view with moving crosshair
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

                // Crosshairs (fixed)
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 1, height: 250)
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 250, height: 1)

                // Moving dot (represents wobble)
                Circle()
                    .fill(wobbleColor)
                    .frame(width: 20, height: 20)
                    .offset(
                        x: CGFloat(motionManager.pitch * 100),
                        y: CGFloat(motionManager.roll * 100)
                    )
                    .animation(.easeOut(duration: 0.05), value: motionManager.pitch)

                // Center target
                Circle()
                    .fill(AppColors.cyan)
                    .frame(width: 10, height: 10)
            }

            // Wobble meter
            VStack(spacing: 4) {
                Text("Wobble")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                        Rectangle()
                            .fill(wobbleColor)
                            .frame(width: geo.size.width * (1 - min(motionManager.wobble, 1)))
                    }
                }
                .frame(height: 20)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 40)

            Text(wobbleMessage)
                .font(.headline)
                .foregroundStyle(wobbleColor)
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

            let avgWobble = wobbleHistory.reduce(0, +) / Double(wobbleHistory.count)
            let steadyScore = max(0, 100 - Int(avgWobble * 200))

            VStack {
                Text("\(steadyScore)")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(AppColors.cyan)
                Text("Steadiness Score")
                    .foregroundStyle(.secondary)
            }

            Text(gradeForScore(steadyScore))
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(gradeColor(steadyScore).opacity(0.2))
                .foregroundStyle(gradeColor(steadyScore))
                .clipShape(Capsule())

            Spacer()

            HStack(spacing: Spacing.lg) {
                Button("Try Again") {
                    wobbleHistory = []
                    elapsedTime = 0
                }
                .buttonStyle(DrillSecondaryButtonStyle())
                .accessibilityLabel("Try Again")
                .accessibilityHint("Restart the steady hold drill")

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(DrillDoneButtonStyle(color: AppColors.cyan))
                .accessibilityLabel("Done")
                .accessibilityHint("Close the drill and return to training")
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding()
    }

    private var wobbleColor: Color {
        if motionManager.wobble < 0.1 { return AppColors.active }
        if motionManager.wobble < 0.3 { return AppColors.warning }
        return AppColors.error
    }

    private var wobbleMessage: String {
        if motionManager.wobble < 0.05 { return "Perfect!" }
        if motionManager.wobble < 0.1 { return "Excellent hold" }
        if motionManager.wobble < 0.2 { return "Good stability" }
        if motionManager.wobble < 0.3 { return "Some movement" }
        return "Hold steady!"
    }

    private func gradeForScore(_ score: Int) -> String {
        if score >= 90 { return "Sniper Grade" }
        if score >= 80 { return "Expert" }
        if score >= 70 { return "Proficient" }
        if score >= 50 { return "Developing" }
        return "Keep Practicing"
    }

    private func gradeColor(_ score: Int) -> Color {
        if score >= 80 { return AppColors.active }
        if score >= 60 { return AppColors.warning }
        return AppColors.running
    }

    private func startDrill() {
        isRunning = true
        elapsedTime = 0
        wobbleHistory = []
        motionManager.startUpdates()

        timerStartDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let timerStartDate else { return }
            elapsedTime = Date().timeIntervalSince(timerStartDate)
            wobbleHistory.append(motionManager.wobble)

            // Process real-time cues
            let stabilityScore = max(0, 100 - motionManager.wobble * 200)
            cueSystem.processDrillState(score: stabilityScore, stability: stabilityScore, elapsed: elapsedTime, duration: targetDuration)

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

        // Calculate score from wobble history
        let avgWobble = wobbleHistory.isEmpty ? 0.5 : wobbleHistory.reduce(0, +) / Double(wobbleHistory.count)
        let score = Double(max(0, 100 - Int(avgWobble * 200)))

        // Save drill session to history
        let session = ShootingDrillSession(
            drillType: .steadyHold,
            duration: targetDuration,
            score: score
        )
        session.stabilityScore = score
        session.averageWobble = avgWobble
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

// MARK: - Steady Hold Motion Manager

class SteadyHoldMotionManager: ObservableObject {
    private let motionManager = CMMotionManager()

    @Published var pitch: Double = 0
    @Published var roll: Double = 0
    @Published var wobble: Double = 0

    private var referencePitch: Double?
    private var referenceRoll: Double?

    func startUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }

        referencePitch = nil
        referenceRoll = nil

        motionManager.deviceMotionUpdateInterval = 1/60
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, let self = self else { return }

            // Set reference point on first reading
            if self.referencePitch == nil {
                self.referencePitch = motion.attitude.pitch
                self.referenceRoll = motion.attitude.roll
            }

            // Calculate deviation from reference
            self.pitch = motion.attitude.pitch - (self.referencePitch ?? 0)
            self.roll = motion.attitude.roll - (self.referenceRoll ?? 0)

            // Calculate total wobble
            self.wobble = sqrt(self.pitch * self.pitch + self.roll * self.roll)
        }
    }

    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}
