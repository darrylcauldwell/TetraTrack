//
//  StirrupPressureDrillView.swift
//  TetraTrack
//
//  Stirrup pressure drill - practice maintaining consistent weight through heels
//

import SwiftUI
import SwiftData

struct StirrupPressureDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var streaks: [TrainingStreak]

    @State private var motionAnalyzer = DrillMotionAnalyzer()
    @State private var cueSystem = RealTimeCueSystem()
    @State private var isRunning = false
    @State private var countdown = 3
    @State private var elapsedTime: TimeInterval = 0
    @State private var timerStartDate: Date?
    @State private var targetDuration: TimeInterval = 30
    @State private var timer: Timer?
    @State private var pitchHistory: [Double] = []
    @State private var optimalPitchRange: ClosedRange<Double> = -0.15...(-0.05) // Slight forward lean = heels down

    private var streak: TrainingStreak? { streaks.first }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppColors.riding.opacity(Opacity.light).ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if !isRunning && countdown == 3 && pitchHistory.isEmpty {
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
            Text("Stirrup Pressure")
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

            Image(systemName: "arrow.down.to.line")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.riding)

            Text("Stirrup Pressure Drill")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("Hold phone at chest level", systemImage: "iphone")
                Label("Push weight down through heels", systemImage: "arrow.down")
                Label("Maintain slight forward lean", systemImage: "figure.stand")
                Label("Keep consistent pressure", systemImage: "gauge.with.needle")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Text("Heels down = security in the saddle")
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
            .accessibilityLabel("Start Stirrup Pressure Drill")
            .accessibilityHint("Begins the heel-down pressure drill")
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
                .scaledFont(size: 120, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                .foregroundStyle(AppColors.riding)
            Text("Heels down, weight through stirrups")
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

            // Pressure gauge visualization
            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0.25, to: 0.75)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(180))

                // Optimal zone
                Circle()
                    .trim(from: 0.4, to: 0.6) // Optimal range
                    .stroke(AppColors.riding.opacity(0.3), lineWidth: 22)
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(180))

                // Current pressure indicator
                Circle()
                    .trim(from: 0.25, to: 0.25 + pitchToGaugeValue * 0.5)
                    .stroke(pressureColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(180))
                    .animation(.easeOut(duration: 0.1), value: motionAnalyzer.pitch)

                // Needle
                Rectangle()
                    .fill(pressureColor)
                    .frame(width: 4, height: 70)
                    .offset(y: -35)
                    .rotationEffect(.degrees(needleAngle))
                    .animation(.easeOut(duration: 0.1), value: motionAnalyzer.pitch)

                // Center
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: 30, height: 30)
                Circle()
                    .fill(pressureColor)
                    .frame(width: 20, height: 20)

                // Labels
                VStack {
                    Spacer()
                    Text(pressureLabel)
                        .font(.headline)
                        .foregroundStyle(pressureColor)
                        .offset(y: -20)
                }
                .frame(height: 200)

                // Side labels
                HStack {
                    Text("Toes")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Heels")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 220)
                .offset(y: 30)
            }
            .frame(width: 250, height: 180)

            Text(feedbackMessage)
                .font(.headline)
                .foregroundStyle(pressureColor)
                .multilineTextAlignment(.center)

            // Real-time stats
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(Int(motionAnalyzer.scorer.stability))")
                        .font(.headline.monospacedDigit())
                    Text("Stability")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    Text("\(Int(timeInZone))%")
                        .font(.headline.monospacedDigit())
                    Text("In Zone")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    Text(String(format: "%.1f°", motionAnalyzer.pitch * 57.3))
                        .font(.headline.monospacedDigit())
                    Text("Angle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Stability bar
            VStack(spacing: 4) {
                Text("Pressure Consistency")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                        Rectangle()
                            .fill(pressureColor)
                            .frame(width: geo.size.width * (motionAnalyzer.scorer.stability / 100))
                    }
                }
                .frame(height: 12)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 40)
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
                Text("\(Int(timeInZone))%")
                    .scaledFont(size: 60, weight: .bold, relativeTo: .largeTitle)
                    .foregroundStyle(AppColors.riding)
                Text("Time in Optimal Zone")
                    .foregroundStyle(.secondary)
            }

            // Stats breakdown
            VStack(spacing: 12) {
                resultRow(label: "Stability", value: "\(Int(motionAnalyzer.scorer.stability))%")
                resultRow(label: "Consistency", value: "\(Int(motionAnalyzer.scorer.endurance))%")
                resultRow(label: "Avg Angle", value: String(format: "%.1f°", averagePitch * 57.3))
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Text(gradeForScore(timeInZone))
                .font(.title2.bold())
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(gradeColor(timeInZone).opacity(0.2))
                .foregroundStyle(gradeColor(timeInZone))
                .clipShape(Capsule())

            Spacer()

            HStack(spacing: Spacing.lg) {
                Button("Try Again") {
                    pitchHistory = []
                    countdown = 3
                    motionAnalyzer.reset()
                }
                .buttonStyle(DrillSecondaryButtonStyle())
                .accessibilityLabel("Try Again")
                .accessibilityHint("Restart the stirrup pressure drill")

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

    // MARK: - Computed Properties

    private var pitchToGaugeValue: Double {
        // Map pitch to 0-1 gauge value
        // Negative pitch = forward lean = heels down
        let normalized = (-motionAnalyzer.pitch + 0.3) / 0.6  // Map -0.3 to 0.3 to 0-1
        return max(0, min(1, normalized))
    }

    private var needleAngle: Double {
        // Map pitch to needle angle (-90 to 90 degrees)
        let normalized = pitchToGaugeValue
        return (normalized - 0.5) * 180
    }

    private var pressureColor: Color {
        if optimalPitchRange.contains(motionAnalyzer.pitch) {
            return AppColors.active
        } else if motionAnalyzer.pitch < optimalPitchRange.lowerBound - 0.1 {
            return AppColors.running // Too much forward lean
        } else if motionAnalyzer.pitch > optimalPitchRange.upperBound + 0.1 {
            return AppColors.error // Leaning back, toes down
        }
        return AppColors.warning
    }

    private var pressureLabel: String {
        if optimalPitchRange.contains(motionAnalyzer.pitch) {
            return "Perfect"
        } else if motionAnalyzer.pitch < optimalPitchRange.lowerBound {
            return "Forward"
        } else {
            return "Back"
        }
    }

    private var feedbackMessage: String {
        if optimalPitchRange.contains(motionAnalyzer.pitch) {
            return "Excellent heel position!"
        } else if motionAnalyzer.pitch < optimalPitchRange.lowerBound - 0.1 {
            return "Too much forward lean"
        } else if motionAnalyzer.pitch < optimalPitchRange.lowerBound {
            return "Slightly more upright"
        } else if motionAnalyzer.pitch > optimalPitchRange.upperBound + 0.1 {
            return "Push weight into heels!"
        } else {
            return "A bit more heel"
        }
    }

    private var timeInZone: Double {
        guard !pitchHistory.isEmpty else { return 0 }
        let inZone = pitchHistory.filter { optimalPitchRange.contains($0) }.count
        return Double(inZone) / Double(pitchHistory.count) * 100
    }

    private var averagePitch: Double {
        guard !pitchHistory.isEmpty else { return 0 }
        return pitchHistory.reduce(0, +) / Double(pitchHistory.count)
    }

    private func gradeForScore(_ score: Double) -> String {
        if score >= 85 { return "Heels Down Master!" }
        if score >= 70 { return "Solid Position" }
        if score >= 55 { return "Good Progress" }
        if score >= 40 { return "Developing" }
        return "Keep Practicing"
    }

    private func gradeColor(_ score: Double) -> Color {
        if score >= 70 { return AppColors.active }
        if score >= 50 { return AppColors.warning }
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
        pitchHistory = []
        motionAnalyzer.reset()
        motionAnalyzer.startUpdates()

        timerStartDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let timerStartDate else { return }
            elapsedTime = Date().timeIntervalSince(timerStartDate)

            // Process real-time cues for position feedback
            cueSystem.processMotionAnalysis(motionAnalyzer, elapsed: elapsedTime, duration: targetDuration)

            pitchHistory.append(motionAnalyzer.pitch)

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

        // Calculate final score based on time in optimal zone
        let score = timeInZone

        // Save unified drill session with subscores
        let session = UnifiedDrillSession(
            drillType: .stirrupPressure,
            duration: targetDuration,
            score: score,
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
    StirrupPressureDrillView()
        .modelContainer(for: TrainingStreak.self, inMemory: true)
}
