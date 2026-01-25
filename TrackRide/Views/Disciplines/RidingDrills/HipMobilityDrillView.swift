//
//  HipMobilityDrillView.swift
//  TrackRide
//
//  Hip mobility drill - circular hip motion while maintaining upper body stillness
//

import SwiftUI
import SwiftData

struct HipMobilityDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var streaks: [TrainingStreak]

    @State private var motionAnalyzer = DrillMotionAnalyzer()
    @State private var cueSystem = RealTimeCueSystem()
    @State private var isRunning = false
    @State private var countdown = 3
    @State private var elapsedTime: TimeInterval = 0
    @State private var targetDuration: TimeInterval = 30
    @State private var timer: Timer?
    @State private var hipPath: [CGPoint] = []
    @State private var circleDirection: CircleDirection = .clockwise

    private var streak: TrainingStreak? { streaks.first }

    enum CircleDirection: String, CaseIterable {
        case clockwise = "Clockwise"
        case counterClockwise = "Counter-Clockwise"
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppColors.pink.opacity(Opacity.light).ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if !isRunning && countdown == 3 && hipPath.isEmpty {
                        instructionsView
                            .frame(maxHeight: .infinity)
                    } else if countdown > 0 && !isRunning {
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
            motionAnalyzer.stopUpdates()
            cueSystem.reset()
        }
    }

    private var header: some View {
        HStack {
            Text("Hip Mobility")
                .font(.headline)
            Spacer()
            Button {
                motionAnalyzer.stopUpdates()
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

            Image(systemName: "figure.flexibility")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.pink)

            Text("Hip Mobility Drill")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("Hold phone at chest/hip level", systemImage: "iphone")
                Label("Make smooth circular hip motions", systemImage: "circle.dashed")
                Label("Keep upper body as still as possible", systemImage: "figure.stand")
                Label("Trace the target circle with your hips", systemImage: "scope")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Picker("Direction", selection: $circleDirection) {
                ForEach(CircleDirection.allCases, id: \.self) { direction in
                    Text(direction.rawValue).tag(direction)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 32)

            Picker("Duration", selection: $targetDuration) {
                Text("20s").tag(TimeInterval(20))
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
            .buttonStyle(DrillStartButtonStyle(color: AppColors.pink))
            .accessibilityLabel("Start Hip Mobility Drill")
            .accessibilityHint("Begins the hip mobility exercise with countdown")
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
                .foregroundStyle(AppColors.pink)
            Text("Begin \(circleDirection.rawValue.lowercased()) hip circles")
                .font(.headline)
            Spacer()
        }
    }

    private var activeDrillView: some View {
        VStack(spacing: 16) {
            // Timer
            Text(String(format: "%.1f", targetDuration - elapsedTime))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(elapsedTime > targetDuration - 5 ? .red : .primary)

            // Hip circle visualizer
            ZStack {
                // Target circle
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    .frame(width: 200, height: 200)

                // Inner rings for guidance
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    .frame(width: 150, height: 150)
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    .frame(width: 100, height: 100)

                // Hip path trail
                Path { path in
                    guard hipPath.count > 1 else { return }
                    path.move(to: hipPath[0])
                    for point in hipPath.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(AppColors.pink.opacity(0.5), lineWidth: 3)

                // Current position indicator
                Circle()
                    .fill(hipPositionColor)
                    .frame(width: 24, height: 24)
                    .offset(
                        x: CGFloat(motionAnalyzer.roll * 80),
                        y: CGFloat(motionAnalyzer.pitch * 80)
                    )

                // Center point
                Circle()
                    .fill(AppColors.pink)
                    .frame(width: 8, height: 8)

                // Direction indicator
                Image(systemName: circleDirection == .clockwise ? "arrow.clockwise" : "arrow.counterclockwise")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .offset(y: 120)
            }
            .frame(width: 250, height: 250)

            Text(feedbackMessage)
                .font(.headline)
                .foregroundStyle(hipPositionColor)

            // Real-time stats
            HStack(spacing: 30) {
                VStack {
                    Text("\(Int(motionAnalyzer.scorer.stability))")
                        .font(.headline.monospacedDigit())
                    Text("Stability")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(Int(motionAnalyzer.scorer.symmetry))")
                        .font(.headline.monospacedDigit())
                    Text("Symmetry")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(Int(motionAnalyzer.rhythmConsistency))")
                        .font(.headline.monospacedDigit())
                    Text("Rhythm")
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

            VStack {
                Text("\(Int(motionAnalyzer.scorer.overallScore))%")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(AppColors.pink)
                Text("Hip Mobility Score")
                    .foregroundStyle(.secondary)
            }

            // Subscores
            HStack(spacing: 24) {
                subscoreCard(title: "Stability", score: motionAnalyzer.scorer.stability)
                subscoreCard(title: "Symmetry", score: motionAnalyzer.scorer.symmetry)
                subscoreCard(title: "Endurance", score: motionAnalyzer.scorer.endurance)
            }

            Text(gradeForScore(motionAnalyzer.scorer.overallScore))
                .font(.title2.bold())
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(gradeColor(motionAnalyzer.scorer.overallScore).opacity(0.2))
                .foregroundStyle(gradeColor(motionAnalyzer.scorer.overallScore))
                .clipShape(Capsule())

            Spacer()

            HStack(spacing: Spacing.lg) {
                Button("Try Again") {
                    hipPath = []
                    countdown = 3
                    motionAnalyzer.reset()
                }
                .buttonStyle(DrillSecondaryButtonStyle())
                .accessibilityLabel("Try Again")
                .accessibilityHint("Restart the hip mobility drill")

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(DrillDoneButtonStyle(color: AppColors.pink))
                .accessibilityLabel("Done")
                .accessibilityHint("Close the drill and return to training")
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding()
    }

    private func subscoreCard(title: String, score: Double) -> some View {
        VStack(spacing: 4) {
            Text("\(Int(score))")
                .font(.title3.bold())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 70)
        .padding(.vertical, 8)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var hipPositionColor: Color {
        let distance = sqrt(pow(motionAnalyzer.roll, 2) + pow(motionAnalyzer.pitch, 2))
        let targetDistance = 0.15 // Radians for target circle
        let deviation = abs(distance - targetDistance)

        if deviation < 0.05 { return AppColors.active }
        if deviation < 0.1 { return AppColors.warning }
        return AppColors.running
    }

    private var feedbackMessage: String {
        let distance = sqrt(pow(motionAnalyzer.roll, 2) + pow(motionAnalyzer.pitch, 2))
        let targetDistance = 0.15

        if distance < 0.05 {
            return "Make bigger circles"
        } else if distance > 0.25 {
            return "Smaller, controlled circles"
        } else if abs(distance - targetDistance) < 0.05 {
            return "Perfect! Keep it smooth"
        } else {
            return "Follow the target circle"
        }
    }

    private func gradeForScore(_ score: Double) -> String {
        if score >= 90 { return "Supple & Fluid" }
        if score >= 80 { return "Good Mobility" }
        if score >= 70 { return "Developing" }
        if score >= 50 { return "Keep Practicing" }
        return "Needs Work"
    }

    private func gradeColor(_ score: Double) -> Color {
        StabilityColors.gradeColor(for: score / 100.0)
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
        hipPath = []
        motionAnalyzer.reset()
        motionAnalyzer.startUpdates()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsedTime += 0.1

            // Process real-time cues for mobility feedback
            cueSystem.processMotionAnalysis(motionAnalyzer, elapsed: elapsedTime, duration: targetDuration)

            // Record hip path for visualization
            let point = CGPoint(
                x: 125 + CGFloat(motionAnalyzer.roll * 80),
                y: 125 + CGFloat(motionAnalyzer.pitch * 80)
            )
            hipPath.append(point)

            // Keep path limited
            if hipPath.count > 100 {
                hipPath.removeFirst()
            }

            if elapsedTime >= targetDuration {
                endDrill()
            }
        }
    }

    private func endDrill() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        motionAnalyzer.stopUpdates()
        cueSystem.reset()

        // Save unified drill session with subscores
        let session = UnifiedDrillSession(
            drillType: .hipMobility,
            duration: targetDuration,
            score: motionAnalyzer.scorer.overallScore,
            stabilityScore: motionAnalyzer.scorer.stability,
            symmetryScore: motionAnalyzer.scorer.symmetry,
            enduranceScore: motionAnalyzer.scorer.endurance,
            coordinationScore: motionAnalyzer.scorer.coordination,
            averageRMS: motionAnalyzer.rmsMotion
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

#Preview {
    HipMobilityDrillView()
        .modelContainer(for: TrainingStreak.self, inMemory: true)
}
