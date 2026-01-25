//
//  ExtendedSeatHoldDrillView.swift
//  TrackRide
//
//  Extended seat hold drill for building rider endurance
//  Tracks form degradation over 3-5 minutes to measure stamina.
//

import SwiftUI
import SwiftData

struct ExtendedSeatHoldDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var streaks: [TrainingStreak]

    @State private var motionAnalyzer = DrillMotionAnalyzer()
    @State private var cueSystem = RealTimeCueSystem()
    @State private var isRunning = false
    @State private var countdown = 3
    @State private var elapsedTime: TimeInterval = 0
    @State private var targetDuration: TimeInterval = 180 // 3 minutes default
    @State private var timer: Timer?
    @State private var stabilityHistory: [Double] = []
    @State private var checkpoints: [(time: TimeInterval, score: Double)] = []

    private var streak: TrainingStreak? { streaks.first }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppColors.riding.opacity(Opacity.light).ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if !isRunning && countdown == 3 && stabilityHistory.isEmpty {
                        instructionsView.frame(maxHeight: .infinity)
                    } else if countdown > 0 && !isRunning {
                        countdownView.frame(maxHeight: .infinity)
                    } else if isRunning {
                        activeDrillView.frame(maxHeight: .infinity)
                    } else {
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
            Text("Extended Seat Hold")
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

            Image(systemName: "timer.circle")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.riding)

            Text("Extended Seat Hold")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("Sit on exercise ball or balance cushion", systemImage: "circle.fill")
                Label("Hold phone at chest/core level", systemImage: "iphone")
                Label("Maintain balanced seat for full duration", systemImage: "figure.equestrian.sports")
                Label("Form degradation will be tracked", systemImage: "chart.line.downtrend.xyaxis")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Text("Builds the endurance to maintain an effective seat through long flatwork sessions")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            PhonePlacementGuidanceView(placement: .chestHeld)
                .padding(.horizontal, 32)

            Picker("Duration", selection: $targetDuration) {
                Text("2 min").tag(TimeInterval(120))
                Text("3 min").tag(TimeInterval(180))
                Text("4 min").tag(TimeInterval(240))
                Text("5 min").tag(TimeInterval(300))
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
                    .background(AppColors.riding)
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
                .foregroundStyle(AppColors.riding)
            Text("Find your balanced seat")
                .font(.headline)
            Spacer()
        }
    }

    private var activeDrillView: some View {
        VStack(spacing: 20) {
            // Timer
            Text(formatTime(targetDuration - elapsedTime))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(elapsedTime > targetDuration - 30 ? .red : .primary)

            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: elapsedTime / targetDuration)
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.3), value: elapsedTime)

                VStack(spacing: 4) {
                    Text("\(Int(motionAnalyzer.scorer.stability))%")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(stabilityColor)
                    Text("Current")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Endurance indicator
            VStack(spacing: 8) {
                HStack {
                    Text("Endurance")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(motionAnalyzer.stabilityRetention))%")
                        .font(.subheadline.bold())
                        .foregroundStyle(enduranceColor)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(enduranceColor)
                            .frame(width: geo.size.width * (motionAnalyzer.stabilityRetention / 100))
                    }
                }
                .frame(height: 8)
            }
            .padding(.horizontal, 40)

            Text(enduranceMessage)
                .font(.headline)
                .foregroundStyle(enduranceColor)

            // Checkpoints
            if !checkpoints.isEmpty {
                HStack(spacing: 16) {
                    ForEach(checkpoints.indices, id: \.self) { index in
                        VStack {
                            Text("\(Int(checkpoints[index].score))%")
                                .font(.caption.bold())
                                .foregroundStyle(checkpoints[index].score >= 70 ? .green : .orange)
                            Text("\(Int(checkpoints[index].time / 60))m")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            // Stats
            HStack(spacing: 30) {
                VStack {
                    Text(String(format: "%.1f°", abs(motionAnalyzer.leftRightAsymmetry)))
                        .font(.headline.monospacedDigit())
                    Text("L/R Lean")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.1f°", abs(motionAnalyzer.anteriorPosterior)))
                        .font(.headline.monospacedDigit())
                    Text("F/B Lean")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.2f", motionAnalyzer.fatigueSlope))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(motionAnalyzer.fatigueSlope < -5 ? .red : .primary)
                    Text("Fatigue")
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
            let enduranceScore = calculateEnduranceScore()

            VStack {
                Text("\(Int(avgStability))%")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(AppColors.riding)
                Text("Average Stability")
                    .foregroundStyle(.secondary)
            }

            // Checkpoint breakdown
            VStack(spacing: 8) {
                HStack {
                    Text("Endurance Score")
                    Spacer()
                    Text("\(Int(enduranceScore))%")
                        .bold()
                        .foregroundStyle(enduranceScore >= 70 ? .green : .orange)
                }
                HStack {
                    Text("Hold Duration")
                    Spacer()
                    Text(formatTime(targetDuration))
                        .bold()
                }
                HStack {
                    Text("Fatigue Rate")
                    Spacer()
                    Text(String(format: "%.1f pts/min", abs(motionAnalyzer.fatigueSlope)))
                        .bold()
                        .foregroundStyle(abs(motionAnalyzer.fatigueSlope) < 5 ? .green : .orange)
                }
            }
            .font(.subheadline)
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            // Checkpoint timeline
            if !checkpoints.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Performance Timeline")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    HStack(spacing: 0) {
                        ForEach(checkpoints.indices, id: \.self) { index in
                            Rectangle()
                                .fill(checkpoints[index].score >= 70 ? AppColors.active : AppColors.running)
                                .frame(height: 8)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .padding(.horizontal)
            }

            Text(gradeForScore(avgStability, endurance: enduranceScore))
                .font(.title2.bold())
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(avgStability >= 70 ? AppColors.active.opacity(0.2) : AppColors.running.opacity(0.2))
                .foregroundStyle(avgStability >= 70 ? .green : .orange)
                .clipShape(Capsule())

            Spacer()

            HStack(spacing: 16) {
                Button {
                    reset()
                } label: {
                    Text("Try Again")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.cardBackground)
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
                        .background(AppColors.riding)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }

    private var stabilityColor: Color {
        let score = motionAnalyzer.scorer.stability
        if score >= 80 { return AppColors.active }
        if score >= 60 { return AppColors.warning }
        return AppColors.running
    }

    private var enduranceColor: Color {
        let retention = motionAnalyzer.stabilityRetention
        if retention >= 85 { return AppColors.active }
        if retention >= 70 { return AppColors.warning }
        return AppColors.running
    }

    private var progressColor: Color {
        let progress = elapsedTime / targetDuration
        if progress < 0.5 { return AppColors.riding }
        if progress < 0.8 { return AppColors.swimming }
        return AppColors.active
    }

    private var enduranceMessage: String {
        let retention = motionAnalyzer.stabilityRetention
        if retention >= 95 { return "Excellent stamina!" }
        if retention >= 85 { return "Strong endurance" }
        if retention >= 70 { return "Holding steady" }
        if retention >= 50 { return "Form starting to fade" }
        return "Focus on core engagement"
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func calculateEnduranceScore() -> Double {
        guard checkpoints.count >= 2 else { return 100 }

        let firstHalf = checkpoints.prefix(checkpoints.count / 2)
        let secondHalf = checkpoints.suffix(checkpoints.count / 2)

        let firstAvg = firstHalf.map { $0.score }.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.map { $0.score }.reduce(0, +) / Double(secondHalf.count)

        // Score based on how well form is maintained
        let retention = secondAvg / max(firstAvg, 1) * 100
        return min(100, retention)
    }

    private func gradeForScore(_ stability: Double, endurance: Double) -> String {
        let combined = (stability + endurance) / 2
        if combined >= 90 { return "Marathon Ready!" }
        if combined >= 80 { return "Excellent Endurance" }
        if combined >= 70 { return "Building Stamina" }
        if combined >= 50 { return "Developing" }
        return "Keep Practicing"
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
        checkpoints = []
        motionAnalyzer.reset()
        motionAnalyzer.startUpdates()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsedTime += 0.1
            stabilityHistory.append(motionAnalyzer.scorer.stability)

            // Record checkpoint every 30 seconds
            if Int(elapsedTime) % 30 == 0 && Int(elapsedTime * 10) % 300 == 0 {
                let recentAvg = stabilityHistory.suffix(300).reduce(0, +) / min(Double(stabilityHistory.count), 300)
                checkpoints.append((time: elapsedTime, score: recentAvg))
            }

            cueSystem.processMotionAnalysis(
                motionAnalyzer,
                elapsed: elapsedTime,
                duration: targetDuration
            )

            if elapsedTime >= targetDuration {
                endDrill()
            }
        }
    }

    private func endDrill() {
        cleanup()

        let avgStability = stabilityHistory.isEmpty ? 0 : stabilityHistory.reduce(0, +) / Double(stabilityHistory.count)
        let enduranceScore = calculateEnduranceScore()

        let session = UnifiedDrillSession(
            drillType: .extendedSeatHold,
            duration: targetDuration,
            score: avgStability,
            stabilityScore: avgStability,
            symmetryScore: motionAnalyzer.scorer.symmetry,
            enduranceScore: enduranceScore,
            coordinationScore: motionAnalyzer.scorer.coordination,
            averageRMS: motionAnalyzer.rmsMotion
        )
        modelContext.insert(session)

        let skillService = SkillDomainService()
        let skillScores = skillService.computeScores(from: session)
        for skillScore in skillScores {
            modelContext.insert(skillScore)
        }

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

    private func reset() {
        stabilityHistory = []
        checkpoints = []
        countdown = 3
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
    ExtendedSeatHoldDrillView()
        .modelContainer(for: [TrainingStreak.self, UnifiedDrillSession.self], inMemory: true)
}
