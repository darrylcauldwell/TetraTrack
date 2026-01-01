//
//  BreathingPatternsDrillView.swift
//  TetraTrack
//
//  Rhythmic breathing pattern drill coordinated with movement
//

import SwiftUI
import SwiftData

struct BreathingPatternsDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var isRunning = false
    @State private var countdown = 3
    @State private var elapsedTime: TimeInterval = 0
    @State private var timerStartDate: Date?
    @State private var targetDuration: TimeInterval = 120
    @State private var timer: Timer?
    @State private var breathPhase: BreathPhase = .inhale
    @State private var pattern: BreathPattern = .threeTwoThreeTwo
    @State private var cycleCount = 0
    @State private var currentStep = 0
    @State private var breathingScores: [Double] = []
    @State private var cueSystem = RealTimeCueSystem()

    enum BreathPhase: String {
        case inhale = "Inhale"
        case exhale = "Exhale"
    }

    enum BreathPattern: String, CaseIterable {
        case twoTwo = "2-2"
        case threeTwoThreeTwo = "3-2-3-2"
        case fourFour = "4-4"

        var inhaleSteps: Int {
            switch self {
            case .twoTwo: return 2
            case .threeTwoThreeTwo: return 3
            case .fourFour: return 4
            }
        }

        var exhaleSteps: Int {
            switch self {
            case .twoTwo: return 2
            case .threeTwoThreeTwo: return 2
            case .fourFour: return 4
            }
        }

        var description: String {
            switch self {
            case .twoTwo: return "Inhale 2 steps, exhale 2 steps"
            case .threeTwoThreeTwo: return "Inhale 3 steps, exhale 2 steps (recommended)"
            case .fourFour: return "Inhale 4 steps, exhale 4 steps"
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppColors.running.opacity(Opacity.light).ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if !isRunning && countdown == 3 && breathingScores.isEmpty {
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
            cleanup()
        }
    }

    private var header: some View {
        HStack {
            Text("Breathing Patterns")
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

            Image(systemName: "wind")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.running)

            Text("Rhythmic Breathing")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("Sync breathing with your steps", systemImage: "figure.run")
                Label("Inhale through nose, exhale through mouth", systemImage: "arrow.up.and.down")
                Label("Keep a steady running pace", systemImage: "metronome")
                Label("This pattern prevents side stitches", systemImage: "checkmark.shield")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            // Pattern selection
            VStack(spacing: 8) {
                Text("Breathing Pattern")
                    .font(.subheadline.bold())
                Picker("Pattern", selection: $pattern) {
                    ForEach(BreathPattern.allCases, id: \.self) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                Text(pattern.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)

            Picker("Duration", selection: $targetDuration) {
                Text("1m").tag(TimeInterval(60))
                Text("2m").tag(TimeInterval(120))
                Text("3m").tag(TimeInterval(180))
                Text("5m").tag(TimeInterval(300))
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 32)

            Spacer()

            Button("Start") {
                startCountdown()
            }
            .buttonStyle(DrillStartButtonStyle(color: AppColors.running))
            .accessibilityLabel("Start Breathing Patterns Drill")
            .accessibilityHint("Begins the rhythmic breathing exercise")
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
                .foregroundStyle(AppColors.running)
            Text("Start running in place")
                .font(.headline)
            Spacer()
        }
    }

    private var activeDrillView: some View {
        VStack(spacing: 24) {
            // Timer
            Text(String(format: "%.0f", targetDuration - elapsedTime))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(elapsedTime > targetDuration - 10 ? .red : .primary)

            // Breath phase indicator
            ZStack {
                Circle()
                    .fill(breathPhase == .inhale ? AppColors.swimming.opacity(Opacity.mediumHeavy) : AppColors.running.opacity(Opacity.mediumHeavy))
                    .frame(width: 180, height: 180)
                    .scaleEffect(breathPhase == .inhale ? 1.2 : 0.9)
                    .animation(.easeInOut(duration: 0.5), value: breathPhase)

                VStack(spacing: 8) {
                    Image(systemName: breathPhase == .inhale ? "arrow.down" : "arrow.up")
                        .font(.system(size: 40))
                        .foregroundStyle(breathPhase == .inhale ? AppColors.swimming : AppColors.running)

                    Text(breathPhase.rawValue.uppercased())
                        .font(.title.bold())
                        .foregroundStyle(breathPhase == .inhale ? AppColors.swimming : AppColors.running)
                }
            }

            // Step counter for current phase
            HStack(spacing: 4) {
                ForEach(0..<totalStepsForPhase, id: \.self) { step in
                    Circle()
                        .fill(step < currentStep ? phaseColor : Color.gray.opacity(0.3))
                        .frame(width: 24, height: 24)
                }
            }

            Text("Step \(currentStep) of \(totalStepsForPhase)")
                .font(.headline)
                .foregroundStyle(.secondary)

            // Stats
            HStack(spacing: 30) {
                VStack {
                    Text("\(cycleCount)")
                        .font(.title2.bold().monospacedDigit())
                    Text("Cycles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text(pattern.rawValue)
                        .font(.title2.bold())
                    Text("Pattern")
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

            let avgScore = breathingScores.isEmpty ? 80 : breathingScores.reduce(0, +) / Double(breathingScores.count)

            VStack {
                Text("\(Int(avgScore))%")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(AppColors.running)
                Text("Breathing Score")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                HStack {
                    Text("Breathing Cycles")
                    Spacer()
                    Text("\(cycleCount)")
                        .bold()
                }
                HStack {
                    Text("Pattern Used")
                    Spacer()
                    Text(pattern.rawValue)
                        .bold()
                }
                HStack {
                    Text("Duration")
                    Spacer()
                    Text("\(Int(targetDuration / 60))m")
                        .bold()
                }
            }
            .font(.subheadline)
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Text(gradeForScore(avgScore))
                .font(.title2.bold())
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.sm)
                .background(avgScore >= 70 ? AppColors.active.opacity(Opacity.medium) : AppColors.running.opacity(Opacity.medium))
                .foregroundStyle(avgScore >= 70 ? AppColors.active : AppColors.running)
                .clipShape(Capsule())

            Spacer()

            HStack(spacing: Spacing.lg) {
                Button("Try Again") {
                    reset()
                }
                .buttonStyle(DrillSecondaryButtonStyle())
                .accessibilityLabel("Try Again")
                .accessibilityHint("Restart the breathing patterns drill")

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

    private var totalStepsForPhase: Int {
        breathPhase == .inhale ? pattern.inhaleSteps : pattern.exhaleSteps
    }

    private var phaseColor: Color {
        breathPhase == .inhale ? AppColors.swimming : AppColors.running
    }

    private func gradeForScore(_ score: Double) -> String {
        if score >= 90 { return "Breathing Master!" }
        if score >= 80 { return "Excellent Control" }
        if score >= 70 { return "Good Rhythm" }
        if score >= 50 { return "Developing" }
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
        cycleCount = 0
        currentStep = 1
        breathPhase = .inhale
        breathingScores = []

        // Step timer (simulating running cadence ~180 SPM = 3 steps/second)
        let stepInterval = 1.0 / 3.0
        timerStartDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { _ in
            guard let timerStartDate else { return }
            elapsedTime = Date().timeIntervalSince(timerStartDate)
            advanceStep()

            if elapsedTime >= targetDuration {
                endDrill()
            }
        }
    }

    private func advanceStep() {
        currentStep += 1

        // Haptic on each step
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if currentStep > totalStepsForPhase {
            // Switch phase
            currentStep = 1
            if breathPhase == .inhale {
                breathPhase = .exhale
            } else {
                breathPhase = .inhale
                cycleCount += 1
                breathingScores.append(80 + Double.random(in: -10...10))  // Simulated score
            }
        }
    }

    private func endDrill() {
        cleanup()

        let avgScore = breathingScores.isEmpty ? 80 : breathingScores.reduce(0, +) / Double(breathingScores.count)

        // Save unified drill session
        let session = UnifiedDrillSession(
            drillType: .breathingPatterns,
            duration: targetDuration,
            score: avgScore,
            breathingScore: avgScore,
            rhythmScore: avgScore
        )
        modelContext.insert(session)

        // Compute and save skill domain scores for profile integration
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
        breathingScores = []
        cycleCount = 0
        currentStep = 1
        breathPhase = .inhale
        countdown = 3
    }

    private func cleanup() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        cueSystem.reset()
    }
}

#Preview {
    BreathingPatternsDrillView()
        .modelContainer(for: UnifiedDrillSession.self, inMemory: true)
}
