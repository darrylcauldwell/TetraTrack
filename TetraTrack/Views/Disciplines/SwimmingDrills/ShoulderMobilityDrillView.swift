//
//  ShoulderMobilityDrillView.swift
//  TetraTrack
//
//  Stroke-prep shoulder circles for swimming warm-up
//

import SwiftUI
import SwiftData

struct ShoulderMobilityDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var motionAnalyzer = DrillMotionAnalyzer()
    @State private var isRunning = false
    @State private var countdown = 3
    @State private var elapsedTime: TimeInterval = 0
    @State private var timerStartDate: Date?
    @State private var targetDuration: TimeInterval = 60
    @State private var timer: Timer?
    @State private var circleDirection: CircleDirection = .forward
    @State private var circleCount = 0
    @State private var mobilityReadings: [Double] = []
    @State private var cueSystem = RealTimeCueSystem()

    enum CircleDirection: String, CaseIterable {
        case forward = "Forward"
        case backward = "Backward"
        case alternating = "Alternating"

        var description: String {
            switch self {
            case .forward: return "Circle arms forward"
            case .backward: return "Circle arms backward"
            case .alternating: return "Alternate forward and backward"
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppColors.swimming.opacity(Opacity.light).ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if !isRunning && countdown == 3 && mobilityReadings.isEmpty {
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
            Text("Shoulder Mobility")
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

            Image(systemName: "figure.arms.open")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.swimming)

            Text("Shoulder Circles")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("Hold phone at chest level", systemImage: "iphone")
                Label("Arms extended to sides", systemImage: "arrow.left.and.right")
                Label("Make large circular motions", systemImage: "arrow.circlepath")
                Label("Essential for stroke preparation", systemImage: "figure.pool.swim")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Text("Shoulder mobility prevents injury and improves stroke power")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Direction selection
            VStack(spacing: 8) {
                Text("Circle Direction")
                    .font(.subheadline.bold())
                Picker("Direction", selection: $circleDirection) {
                    ForEach(CircleDirection.allCases, id: \.self) { dir in
                        Text(dir.rawValue).tag(dir)
                    }
                }
                .pickerStyle(.segmented)
                Text(circleDirection.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)

            Picker("Duration", selection: $targetDuration) {
                Text("30s").tag(TimeInterval(30))
                Text("60s").tag(TimeInterval(60))
                Text("90s").tag(TimeInterval(90))
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 32)

            Spacer()

            Button("Start") {
                startCountdown()
            }
            .buttonStyle(DrillStartButtonStyle(color: AppColors.swimming))
            .accessibilityLabel("Start Shoulder Mobility Drill")
            .accessibilityHint("Begins the shoulder circles warm-up exercise")
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
                .foregroundStyle(AppColors.swimming)
            Text("Arms out to sides")
                .font(.headline)
            Spacer()
        }
    }

    private var activeDrillView: some View {
        VStack(spacing: 24) {
            // Timer
            Text(String(format: "%.1f", targetDuration - elapsedTime))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(elapsedTime > targetDuration - 5 ? .red : .primary)

            // Direction indicator
            Text(currentDirectionText)
                .font(.title3.bold())
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(AppColors.swimming.opacity(0.2))
                .clipShape(Capsule())

            // Motion visualization
            ZStack {
                // Outer track
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 160, height: 160)

                // Motion arc
                Circle()
                    .trim(from: 0, to: CGFloat(min(1, motionAnalyzer.dominantFrequency)))
                    .stroke(AppColors.swimming, lineWidth: 8)
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.2), value: motionAnalyzer.dominantFrequency)

                // Center indicator
                Circle()
                    .fill(mobilityColor)
                    .frame(width: 24, height: 24)
                    .offset(
                        x: CGFloat(motionAnalyzer.roll * 60),
                        y: CGFloat(motionAnalyzer.pitch * 60)
                    )
                    .animation(.easeOut(duration: 0.1), value: motionAnalyzer.roll)

                // Direction arrow
                Image(systemName: isForwardPhase ? "arrow.clockwise" : "arrow.counterclockwise")
                    .font(.system(size: 30))
                    .foregroundStyle(.teal.opacity(0.5))
            }

            Text(mobilityFeedback)
                .font(.headline)
                .foregroundStyle(mobilityColor)

            // Stats
            HStack(spacing: 30) {
                VStack {
                    Text("\(circleCount)")
                        .font(.title2.bold().monospacedDigit())
                    Text("Circles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.1f Hz", motionAnalyzer.dominantFrequency))
                        .font(.title2.bold().monospacedDigit())
                    Text("Rhythm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.swimming)
                        .frame(width: geo.size.width * (elapsedTime / targetDuration))
                }
            }
            .frame(height: 8)
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

            let avgMobility = mobilityReadings.isEmpty ? 0 : mobilityReadings.reduce(0, +) / Double(mobilityReadings.count)
            let score = min(100, avgMobility + Double(circleCount) * 1.5)

            VStack {
                Text("\(Int(score))%")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(AppColors.swimming)
                Text("Mobility Score")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                HStack {
                    Text("Circles Completed")
                    Spacer()
                    Text("\(circleCount)")
                        .bold()
                }
                HStack {
                    Text("Average Rhythm")
                    Spacer()
                    Text(String(format: "%.2f Hz", avgMobility / 20))
                        .bold()
                }
                HStack {
                    Text("Direction")
                    Spacer()
                    Text(circleDirection.rawValue)
                        .bold()
                }
            }
            .font(.subheadline)
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Text(gradeForScore(score))
                .font(.title2.bold())
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.sm)
                .background(score >= 70 ? AppColors.active.opacity(Opacity.medium) : AppColors.running.opacity(Opacity.medium))
                .foregroundStyle(score >= 70 ? AppColors.active : AppColors.running)
                .clipShape(Capsule())

            Spacer()

            HStack(spacing: Spacing.lg) {
                Button("Try Again") {
                    reset()
                }
                .buttonStyle(DrillSecondaryButtonStyle())
                .accessibilityLabel("Try Again")
                .accessibilityHint("Restart the shoulder mobility drill")

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

    private var isForwardPhase: Bool {
        switch circleDirection {
        case .forward: return true
        case .backward: return false
        case .alternating: return Int(elapsedTime / 10) % 2 == 0
        }
    }

    private var currentDirectionText: String {
        switch circleDirection {
        case .forward: return "Forward Circles"
        case .backward: return "Backward Circles"
        case .alternating: return isForwardPhase ? "Forward" : "Backward"
        }
    }

    private var mobilityColor: Color {
        if motionAnalyzer.dominantFrequency > 0.5 { return AppColors.active }
        if motionAnalyzer.dominantFrequency > 0.25 { return AppColors.warning }
        return AppColors.running
    }

    private var mobilityFeedback: String {
        if motionAnalyzer.dominantFrequency > 0.6 { return "Excellent range!" }
        if motionAnalyzer.dominantFrequency > 0.4 { return "Good circles" }
        if motionAnalyzer.dominantFrequency > 0.2 { return "Bigger circles" }
        return "Start circling"
    }

    private func gradeForScore(_ score: Double) -> String {
        if score >= 90 { return "Swimmer's Shoulders!" }
        if score >= 80 { return "Great Mobility" }
        if score >= 70 { return "Good Range" }
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
        circleCount = 0
        mobilityReadings = []
        motionAnalyzer.reset()
        motionAnalyzer.startUpdates()

        timerStartDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let timerStartDate else { return }
            elapsedTime = Date().timeIntervalSince(timerStartDate)

            // Count circles based on frequency
            if motionAnalyzer.dominantFrequency > 0.2 {
                circleCount = Int(elapsedTime * motionAnalyzer.dominantFrequency)
            }

            // Record mobility score
            let range = sqrt(pow(motionAnalyzer.roll, 2) + pow(motionAnalyzer.pitch, 2))
            mobilityReadings.append(min(100, range * 150 + motionAnalyzer.dominantFrequency * 30))

            cueSystem.processDrillState(
                score: mobilityReadings.last ?? 0,
                stability: motionAnalyzer.dominantFrequency * 100,
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

        let avgMobility = mobilityReadings.isEmpty ? 0 : mobilityReadings.reduce(0, +) / Double(mobilityReadings.count)
        let score = min(100, avgMobility + Double(circleCount) * 1.5)

        let session = UnifiedDrillSession(
            drillType: .shoulderMobility,
            duration: targetDuration,
            score: score,
            coordinationScore: avgMobility,
            averageRMS: motionAnalyzer.rmsMotion
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
        mobilityReadings = []
        circleCount = 0
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
    ShoulderMobilityDrillView()
        .modelContainer(for: UnifiedDrillSession.self, inMemory: true)
}
