//
//  SingleLegBalanceDrillView.swift
//  TrackRide
//
//  Single-leg balance hold for runners and swimmers - builds stability
//  essential for running gait and swimming push-off power.
//

import SwiftUI
import SwiftData

struct SingleLegBalanceDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var motionAnalyzer = DrillMotionAnalyzer()
    @State private var cueSystem = RealTimeCueSystem()
    @State private var isRunning = false
    @State private var countdown = 3
    @State private var elapsedTime: TimeInterval = 0
    @State private var targetDuration: TimeInterval = 30
    @State private var timer: Timer?
    @State private var currentLeg: BalanceLeg = .left
    @State private var leftLegScore: Double = 0
    @State private var rightLegScore: Double = 0
    @State private var leftStabilityHistory: [Double] = []
    @State private var rightStabilityHistory: [Double] = []
    @State private var phase: DrillPhase = .instructions

    enum BalanceLeg: String {
        case left = "Left"
        case right = "Right"
    }

    enum DrillPhase {
        case instructions
        case countdown
        case leftLeg
        case switchLeg
        case rightLeg
        case results
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppColors.running.opacity(Opacity.light).ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    switch phase {
                    case .instructions:
                        instructionsView.frame(maxHeight: .infinity)
                    case .countdown:
                        countdownView.frame(maxHeight: .infinity)
                    case .leftLeg, .rightLeg:
                        activeDrillView.frame(maxHeight: .infinity)
                    case .switchLeg:
                        switchLegView.frame(maxHeight: .infinity)
                    case .results:
                        resultsView.frame(maxHeight: .infinity)
                    }
                }
            }
            .withRealTimeCues(cueSystem)
        }
        .onDisappear {
            cleanup()
        }
    }

    private var header: some View {
        HStack {
            Text("Single-Leg Balance")
                .font(.headline)
            Spacer()
            Button {
                cleanup()
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

            Image(systemName: "figure.stand.line.dotted.figure.stand")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.running)

            Text("Single-Leg Balance")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("Stand on one leg, phone at chest", systemImage: "iphone")
                Label("Keep standing leg slightly bent", systemImage: "figure.stand")
                Label("Focus on a fixed point ahead", systemImage: "eye")
                Label("You'll balance on each leg", systemImage: "arrow.left.arrow.right")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Text("Essential for running gait stability and swimming push-off power")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            PhonePlacementGuidanceView(placement: .chestHeld)
                .padding(.horizontal, 32)

            Picker("Duration per leg", selection: $targetDuration) {
                Text("15s").tag(TimeInterval(15))
                Text("30s").tag(TimeInterval(30))
                Text("45s").tag(TimeInterval(45))
                Text("60s").tag(TimeInterval(60))
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 32)

            Spacer()

            Button("Start") {
                startCountdown(for: .left)
            }
            .buttonStyle(DrillStartButtonStyle(color: AppColors.running))
            .accessibilityLabel("Start Single-Leg Balance Drill")
            .accessibilityHint("Begins the balance exercise on each leg")
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
                .foregroundStyle(AppColors.running)
            Text("Stand on \(currentLeg.rawValue) leg")
                .font(.headline)
            Spacer()
        }
    }

    private var activeDrillView: some View {
        VStack(spacing: 24) {
            // Current leg indicator
            Text("\(currentLeg.rawValue) Leg")
                .font(.title3.bold())
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(currentLeg == .left ? AppColors.riding.opacity(Opacity.medium) : AppColors.active.opacity(Opacity.medium))
                .clipShape(Capsule())

            // Timer
            Text(String(format: "%.1f", targetDuration - elapsedTime))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(elapsedTime > targetDuration - 5 ? .red : .primary)

            // Balance visualizer
            ZStack {
                // Concentric rings
                ForEach([0.3, 0.6, 1.0], id: \.self) { scale in
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                        .frame(width: 180 * scale, height: 180 * scale)
                }

                // Target zone
                Circle()
                    .fill(AppColors.active.opacity(Opacity.medium))
                    .frame(width: 60, height: 60)

                // Balance indicator
                Circle()
                    .fill(stabilityColor)
                    .frame(width: 24, height: 24)
                    .offset(
                        x: CGFloat(motionAnalyzer.roll * 80),
                        y: CGFloat(motionAnalyzer.pitch * 80)
                    )
                    .animation(.easeOut(duration: 0.1), value: motionAnalyzer.roll)

                // Center point
                Circle()
                    .fill(AppColors.running)
                    .frame(width: 8, height: 8)
            }
            .frame(width: 200, height: 200)

            Text(feedbackMessage)
                .font(.headline)
                .foregroundStyle(stabilityColor)

            // Stats
            HStack(spacing: 30) {
                VStack {
                    Text("\(Int(motionAnalyzer.scorer.stability))%")
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(stabilityColor)
                    Text("Stability")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.1f°", abs(motionAnalyzer.leftRightAsymmetry)))
                        .font(.title2.bold().monospacedDigit())
                    Text("Sway")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.running)
                        .frame(width: geo.size.width * (elapsedTime / targetDuration))
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 40)
        }
    }

    private var switchLegView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.running)

            Text("Switch Legs!")
                .font(.title.bold())

            Text("Left leg score: \(Int(leftLegScore))%")
                .font(.headline)
                .foregroundStyle(AppColors.riding)

            Text("Now balance on your Right leg")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Continue") {
                startCountdown(for: .right)
            }
            .buttonStyle(DrillStartButtonStyle(color: AppColors.running))
            .accessibilityLabel("Continue to Right Leg")
            .accessibilityHint("Begins the balance exercise on your right leg")
            .padding(.horizontal, Spacing.jumbo)
            .padding(.bottom, Spacing.xl)
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

            let overallScore = (leftLegScore + rightLegScore) / 2
            let symmetryScore = 100 - abs(leftLegScore - rightLegScore)

            VStack {
                Text("\(Int(overallScore))%")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(AppColors.running)
                Text("Balance Score")
                    .foregroundStyle(.secondary)
            }

            // Leg comparison
            HStack(spacing: 40) {
                VStack {
                    Text("\(Int(leftLegScore))%")
                        .font(.title2.bold())
                        .foregroundStyle(AppColors.riding)
                    Text("Left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(Int(rightLegScore))%")
                        .font(.title2.bold())
                        .foregroundStyle(AppColors.active)
                    Text("Right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(Int(symmetryScore))%")
                        .font(.title2.bold())
                        .foregroundStyle(AppColors.purple)
                    Text("Symmetry")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))

            Text(gradeForScore(overallScore))
                .font(.title2.bold())
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.sm)
                .background(overallScore >= 70 ? AppColors.active.opacity(Opacity.medium) : AppColors.running.opacity(Opacity.medium))
                .foregroundStyle(overallScore >= 70 ? AppColors.active : AppColors.running)
                .clipShape(Capsule())

            Spacer()

            HStack(spacing: Spacing.lg) {
                Button("Try Again") {
                    reset()
                }
                .buttonStyle(DrillSecondaryButtonStyle())
                .accessibilityLabel("Try Again")
                .accessibilityHint("Restart the single-leg balance drill")

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(DrillDoneButtonStyle(color: AppColors.running))
                .accessibilityLabel("Done")
                .accessibilityHint("Close the drill and return to training")
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding()
    }

    private var stabilityColor: Color {
        let score = motionAnalyzer.scorer.stability
        if score >= 80 { return AppColors.active }
        if score >= 60 { return AppColors.warning }
        return AppColors.running
    }

    private var feedbackMessage: String {
        let score = motionAnalyzer.scorer.stability
        if score >= 90 { return "Rock solid!" }
        if score >= 75 { return "Great balance" }
        if score >= 60 { return "Stay centered" }
        return "Focus on a fixed point"
    }

    private func gradeForScore(_ score: Double) -> String {
        if score >= 90 { return "Elite Balance!" }
        if score >= 80 { return "Strong Stability" }
        if score >= 70 { return "Good Balance" }
        if score >= 50 { return "Developing" }
        return "Keep Practicing"
    }

    private func startCountdown(for leg: BalanceLeg) {
        currentLeg = leg
        countdown = 3
        phase = .countdown

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            countdown -= 1
            if countdown == 0 {
                t.invalidate()
                startDrill()
            }
        }
    }

    private func startDrill() {
        phase = currentLeg == .left ? .leftLeg : .rightLeg
        isRunning = true
        elapsedTime = 0
        motionAnalyzer.reset()
        motionAnalyzer.startUpdates()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsedTime += 0.1

            // Record stability
            if currentLeg == .left {
                leftStabilityHistory.append(motionAnalyzer.scorer.stability)
            } else {
                rightStabilityHistory.append(motionAnalyzer.scorer.stability)
            }

            cueSystem.processDrillState(
                score: motionAnalyzer.scorer.stability,
                stability: motionAnalyzer.scorer.stability,
                elapsed: elapsedTime,
                duration: targetDuration
            )

            if elapsedTime >= targetDuration {
                endLegPhase()
            }
        }
    }

    private func endLegPhase() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        motionAnalyzer.stopUpdates()

        if currentLeg == .left {
            leftLegScore = leftStabilityHistory.isEmpty ? 0 : leftStabilityHistory.reduce(0, +) / Double(leftStabilityHistory.count)
            phase = .switchLeg
        } else {
            rightLegScore = rightStabilityHistory.isEmpty ? 0 : rightStabilityHistory.reduce(0, +) / Double(rightStabilityHistory.count)
            saveDrill()
            phase = .results
        }
    }

    private func saveDrill() {
        let overallScore = (leftLegScore + rightLegScore) / 2
        let symmetryScore = 100 - abs(leftLegScore - rightLegScore)

        let session = UnifiedDrillSession(
            drillType: .singleLegBalance,
            duration: targetDuration * 2, // Both legs
            score: overallScore,
            stabilityScore: overallScore,
            symmetryScore: symmetryScore,
            enduranceScore: motionAnalyzer.scorer.endurance,
            averageRMS: motionAnalyzer.rmsMotion
        )
        modelContext.insert(session)

        let skillService = SkillDomainService()
        let skillScores = skillService.computeScores(from: session)
        for skillScore in skillScores {
            modelContext.insert(skillScore)
        }

        try? modelContext.save()

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func reset() {
        leftLegScore = 0
        rightLegScore = 0
        leftStabilityHistory = []
        rightStabilityHistory = []
        countdown = 3
        phase = .instructions
        motionAnalyzer.reset()
    }

    private func cleanup() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        motionAnalyzer.stopUpdates()
        cueSystem.reset()
    }
}

#Preview {
    SingleLegBalanceDrillView()
        .modelContainer(for: UnifiedDrillSession.self, inMemory: true)
}
