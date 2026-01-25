//
//  RiderStillnessDrillView.swift
//  TrackRide
//
//  Minimal movement challenge drill - the foundation of quiet, effective aids
//

import SwiftUI
import SwiftData

struct RiderStillnessDrillView: View {
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
    @State private var stabilityHistory: [Double] = []
    @State private var peakDeviation: Double = 0

    private var streak: TrainingStreak? { streaks.first }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppColors.riding.opacity(Opacity.light).ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if !isRunning && countdown == 3 && stabilityHistory.isEmpty {
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
            Text("Rider Stillness")
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

            Image(systemName: "person.and.background.dotted")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.riding)

            Text("Rider Stillness Challenge")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("Hold phone at chest level", systemImage: "iphone")
                Label("Stand or sit in balanced position", systemImage: "figure.stand")
                Label("Minimize ALL movement", systemImage: "scope")
                Label("Breathe gently, stay relaxed", systemImage: "wind")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Text("The quieter your body, the clearer your aids")
                .font(.caption)
                .foregroundStyle(.secondary)
                .italic()
                .padding(.top, 8)

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
            .buttonStyle(DrillStartButtonStyle(color: AppColors.riding))
            .accessibilityLabel("Start Rider Stillness Drill")
            .accessibilityHint("Begins the minimal movement challenge")
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
            Text("Find your stillness")
                .font(.headline)
            Spacer()
        }
    }

    private var activeDrillView: some View {
        VStack(spacing: 20) {
            // Timer
            Text(String(format: "%.1f", targetDuration - elapsedTime))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(elapsedTime > targetDuration - 5 ? .red : .primary)

            // Stillness visualizer - concentric circles that pulse with movement
            ZStack {
                // Outer rings - expand with movement
                ForEach(0..<5, id: \.self) { ring in
                    Circle()
                        .stroke(
                            AppColors.riding.opacity(0.2 + Double(4 - ring) * 0.15),
                            lineWidth: 2
                        )
                        .frame(
                            width: CGFloat(50 + ring * 40) + CGFloat(motionAnalyzer.rmsMotion * 100),
                            height: CGFloat(50 + ring * 40) + CGFloat(motionAnalyzer.rmsMotion * 100)
                        )
                        .animation(.easeOut(duration: 0.1), value: motionAnalyzer.rmsMotion)
                }

                // Center stability indicator
                Circle()
                    .fill(stabilityColor)
                    .frame(width: 60, height: 60)

                // Stability percentage
                Text("\(Int(motionAnalyzer.stabilityScore * 100))")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .frame(width: 250, height: 250)

            Text(stillnessMessage)
                .font(.headline)
                .foregroundStyle(stabilityColor)

            // Real-time metrics
            HStack(spacing: 24) {
                metricView(value: "\(Int(motionAnalyzer.scorer.stability))", label: "Stability")
                metricView(value: String(format: "%.2f°", abs(motionAnalyzer.anteriorPosterior)), label: "Lean")
                metricView(value: String(format: "%.2f°", abs(motionAnalyzer.leftRightAsymmetry)), label: "Tilt")
            }

            // Stability trend mini chart
            VStack(spacing: 4) {
                Text("Stability Over Time")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                GeometryReader { geo in
                    Path { path in
                        guard stabilityHistory.count > 1 else { return }
                        let stepX = geo.size.width / CGFloat(max(stabilityHistory.count - 1, 1))

                        path.move(to: CGPoint(
                            x: 0,
                            y: geo.size.height * (1 - stabilityHistory[0] / 100)
                        ))

                        for (index, value) in stabilityHistory.enumerated() {
                            path.addLine(to: CGPoint(
                                x: CGFloat(index) * stepX,
                                y: geo.size.height * (1 - value / 100)
                            ))
                        }
                    }
                    .stroke(AppColors.riding, lineWidth: 2)
                }
                .frame(height: 40)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(.horizontal, 40)
        }
    }

    private func metricView(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 70)
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

            VStack {
                Text("\(Int(avgStability))%")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(AppColors.riding)
                Text("Stillness Score")
                    .foregroundStyle(.secondary)
            }

            // Detailed breakdown
            VStack(spacing: 12) {
                resultRow(label: "Avg Stability", value: "\(Int(motionAnalyzer.scorer.stability))%")
                resultRow(label: "Symmetry", value: "\(Int(motionAnalyzer.scorer.symmetry))%")
                resultRow(label: "Endurance", value: "\(Int(motionAnalyzer.scorer.endurance))%")
                resultRow(label: "Peak Deviation", value: String(format: "%.2f°", peakDeviation * 57.3))
            }
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
                    stabilityHistory = []
                    peakDeviation = 0
                    countdown = 3
                    motionAnalyzer.reset()
                }
                .buttonStyle(DrillSecondaryButtonStyle())
                .accessibilityLabel("Try Again")
                .accessibilityHint("Restart the rider stillness drill")

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

    private func resultRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
        .font(.subheadline)
    }

    private var stabilityColor: Color {
        let score = motionAnalyzer.stabilityScore
        if score > 0.85 { return AppColors.active }
        if score > 0.65 { return AppColors.warning }
        if score > 0.45 { return AppColors.running }
        return AppColors.error
    }

    private var stillnessMessage: String {
        let score = motionAnalyzer.stabilityScore
        if score > 0.95 { return "Like a statue!" }
        if score > 0.85 { return "Excellent stillness" }
        if score > 0.70 { return "Very good" }
        if score > 0.55 { return "Some movement detected" }
        if score > 0.40 { return "Try to settle" }
        return "Relax and breathe"
    }

    private func gradeForScore(_ score: Double) -> String {
        if score >= 90 { return "Zen Master" }
        if score >= 80 { return "Rock Solid" }
        if score >= 70 { return "Composed" }
        if score >= 55 { return "Developing" }
        return "Keep Practicing"
    }

    private func gradeColor(_ score: Double) -> Color {
        if score >= 80 { return AppColors.active }
        if score >= 60 { return AppColors.warning }
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
        stabilityHistory = []
        peakDeviation = 0
        motionAnalyzer.reset()
        motionAnalyzer.startUpdates()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsedTime += 0.1

            // Process real-time cues for stability feedback
            cueSystem.processMotionAnalysis(motionAnalyzer, elapsed: elapsedTime, duration: targetDuration)

            // Track stability over time
            stabilityHistory.append(motionAnalyzer.scorer.stability)

            // Track peak deviation
            let currentDeviation = sqrt(
                pow(motionAnalyzer.pitch, 2) +
                pow(motionAnalyzer.roll, 2) +
                pow(motionAnalyzer.yaw, 2)
            )
            if currentDeviation > peakDeviation {
                peakDeviation = currentDeviation
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

        let avgStability = stabilityHistory.isEmpty ? 0 : stabilityHistory.reduce(0, +) / Double(stabilityHistory.count)

        // Save unified drill session with subscores
        let session = UnifiedDrillSession(
            drillType: .riderStillness,
            duration: targetDuration,
            score: avgStability,
            stabilityScore: motionAnalyzer.scorer.stability,
            symmetryScore: motionAnalyzer.scorer.symmetry,
            enduranceScore: motionAnalyzer.scorer.endurance,
            coordinationScore: motionAnalyzer.scorer.coordination,
            averageRMS: motionAnalyzer.rmsMotion,
            peakDeviation: peakDeviation
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
    RiderStillnessDrillView()
        .modelContainer(for: TrainingStreak.self, inMemory: true)
}
