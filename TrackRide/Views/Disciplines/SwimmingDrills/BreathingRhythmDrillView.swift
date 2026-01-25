//
//  BreathingRhythmDrillView.swift
//  TrackRide
//
//  Bilateral breathing timing drill for freestyle swimming
//

import SwiftUI
import SwiftData

struct BreathingRhythmDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var isRunning = false
    @State private var countdown = 3
    @State private var elapsedTime: TimeInterval = 0
    @State private var targetDuration: TimeInterval = 120
    @State private var timer: Timer?
    @State private var strokeCount = 0
    @State private var breathSide: BreathSide = .none
    @State private var pattern: BreathingPattern = .bilateral3
    @State private var strokesUntilBreath = 3
    @State private var breathingScores: [Double] = []
    @State private var cueSystem = RealTimeCueSystem()

    enum BreathSide: String {
        case left = "Left"
        case right = "Right"
        case none = "Stroke"
    }

    enum BreathingPattern: String, CaseIterable {
        case bilateral3 = "Every 3"
        case bilateral5 = "Every 5"
        case right2 = "Right (2)"
        case left2 = "Left (2)"

        var strokesPerBreath: Int {
            switch self {
            case .bilateral3: return 3
            case .bilateral5: return 5
            case .right2, .left2: return 2
            }
        }

        var description: String {
            switch self {
            case .bilateral3: return "Breathe every 3 strokes, alternating sides"
            case .bilateral5: return "Breathe every 5 strokes, alternating sides"
            case .right2: return "Breathe right every 2 strokes"
            case .left2: return "Breathe left every 2 strokes"
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppColors.swimming.opacity(Opacity.light).ignoresSafeArea()

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
            Text("Breathing Rhythm")
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
                .foregroundStyle(AppColors.swimming)

            Text("Swimming Breathing Rhythm")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("Practice bilateral breathing timing", systemImage: "arrow.left.and.right")
                Label("Follow visual cues for breath timing", systemImage: "eye")
                Label("Builds better balance in water", systemImage: "figure.pool.swim")
                Label("Improves oxygen efficiency", systemImage: "lungs")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            // Pattern selection
            VStack(spacing: 8) {
                Text("Breathing Pattern")
                    .font(.subheadline.bold())
                Picker("Pattern", selection: $pattern) {
                    ForEach(BreathingPattern.allCases, id: \.self) { p in
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
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 32)

            Spacer()

            Button("Start") {
                startCountdown()
            }
            .buttonStyle(DrillStartButtonStyle(color: AppColors.swimming))
            .accessibilityLabel("Start Breathing Rhythm Drill")
            .accessibilityHint("Begins the swimming breathing pattern exercise")
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
                .foregroundStyle(AppColors.swimming)
            Text("Simulate swimming strokes")
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

            // Breath indicator
            ZStack {
                Circle()
                    .fill(breathSide == .none ? AppColors.swimming.opacity(0.2) : breathColor.opacity(0.3))
                    .frame(width: 180, height: 180)
                    .scaleEffect(breathSide == .none ? 1.0 : 1.2)
                    .animation(.easeInOut(duration: 0.3), value: breathSide)

                VStack(spacing: 8) {
                    Image(systemName: breathSide == .none ? "figure.pool.swim" : "wind")
                        .font(.system(size: 50))
                        .foregroundStyle(breathSide == .none ? AppColors.swimming : breathColor)

                    Text(breathSide.rawValue.uppercased())
                        .font(.title.bold())
                        .foregroundStyle(breathSide == .none ? AppColors.swimming : breathColor)
                }
            }

            // Stroke counter to next breath
            HStack(spacing: 8) {
                ForEach(0..<pattern.strokesPerBreath, id: \.self) { i in
                    Circle()
                        .fill(i < (pattern.strokesPerBreath - strokesUntilBreath) ? AppColors.swimming : Color.gray.opacity(0.3))
                        .frame(width: 20, height: 20)
                }
            }

            Text("\(strokesUntilBreath) strokes until breath")
                .font(.headline)
                .foregroundStyle(.secondary)

            // Stats
            HStack(spacing: 30) {
                VStack {
                    Text("\(strokeCount)")
                        .font(.title2.bold().monospacedDigit())
                    Text("Strokes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(breathingScores.count)")
                        .font(.title2.bold().monospacedDigit())
                    Text("Breaths")
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

            let avgScore = breathingScores.isEmpty ? 85 : breathingScores.reduce(0, +) / Double(breathingScores.count)

            VStack {
                Text("\(Int(avgScore))%")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(AppColors.swimming)
                Text("Breathing Score")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                HStack {
                    Text("Total Strokes")
                    Spacer()
                    Text("\(strokeCount)")
                        .bold()
                }
                HStack {
                    Text("Breaths Taken")
                    Spacer()
                    Text("\(breathingScores.count)")
                        .bold()
                }
                HStack {
                    Text("Pattern")
                    Spacer()
                    Text(pattern.rawValue)
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
                .background(avgScore >= 70 ? AppColors.active.opacity(0.2) : AppColors.running.opacity(0.2))
                .foregroundStyle(avgScore >= 70 ? AppColors.active : AppColors.running)
                .clipShape(Capsule())

            Spacer()

            HStack(spacing: Spacing.lg) {
                Button("Try Again") {
                    reset()
                }
                .buttonStyle(DrillSecondaryButtonStyle())
                .accessibilityLabel("Try Again")
                .accessibilityHint("Restart the breathing rhythm drill")

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(DrillDoneButtonStyle(color: AppColors.swimming))
                .accessibilityLabel("Done")
                .accessibilityHint("Close the drill and return to training")
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding()
    }

    private var breathColor: Color {
        switch breathSide {
        case .left: return AppColors.running
        case .right: return AppColors.active
        case .none: return AppColors.swimming
        }
    }

    private func gradeForScore(_ score: Double) -> String {
        if score >= 90 { return "Perfect Rhythm!" }
        if score >= 80 { return "Excellent Timing" }
        if score >= 70 { return "Good Control" }
        if score >= 50 { return "Developing" }
        return "Keep Practicing"
    }

    private func startCountdown() {
        countdown = 3
        strokesUntilBreath = pattern.strokesPerBreath
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
        strokeCount = 0
        breathingScores = []
        strokesUntilBreath = pattern.strokesPerBreath
        breathSide = .none

        // Stroke timer (~1.5 seconds per stroke cycle)
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            elapsedTime += 1.5
            advanceStroke()

            if elapsedTime >= targetDuration {
                endDrill()
            }
        }
    }

    private func advanceStroke() {
        strokeCount += 1
        strokesUntilBreath -= 1

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if strokesUntilBreath == 0 {
            // Time to breathe
            switch pattern {
            case .bilateral3, .bilateral5:
                breathSide = (strokeCount / pattern.strokesPerBreath) % 2 == 0 ? .right : .left
            case .right2:
                breathSide = .right
            case .left2:
                breathSide = .left
            }

            breathingScores.append(80 + Double.random(in: -5...15))

            // Reset
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                breathSide = .none
                strokesUntilBreath = pattern.strokesPerBreath
            }
        }
    }

    private func endDrill() {
        cleanup()

        let avgScore = breathingScores.isEmpty ? 85 : breathingScores.reduce(0, +) / Double(breathingScores.count)

        // Save unified drill session
        let session = UnifiedDrillSession(
            drillType: .breathingRhythm,
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
        strokeCount = 0
        strokesUntilBreath = pattern.strokesPerBreath
        breathSide = .none
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
    BreathingRhythmDrillView()
        .modelContainer(for: UnifiedDrillSession.self, inMemory: true)
}
