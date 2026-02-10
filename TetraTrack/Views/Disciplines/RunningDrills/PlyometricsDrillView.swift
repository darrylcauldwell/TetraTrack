//
//  PlyometricsDrillView.swift
//  TetraTrack
//
//  Jump power measurement and plyometric training for explosive running
//

import SwiftUI
import SwiftData

struct PlyometricsDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var motionAnalyzer = DrillMotionAnalyzer()
    @State private var isRunning = false
    @State private var countdown = 3
    @State private var elapsedTime: TimeInterval = 0
    @State private var timerStartDate: Date?
    @State private var targetReps: Int = 10
    @State private var timer: Timer?
    @State private var jumpCount = 0
    @State private var jumpHeights: [Double] = []
    @State private var isInAir = false
    @State private var currentJumpPeak = 0.0
    @State private var cueSystem = RealTimeCueSystem()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppColors.error.opacity(Opacity.light).ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if !isRunning && countdown == 3 && jumpHeights.isEmpty {
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
            Text("Plyometrics")
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

            Image(systemName: "figure.jumprope")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.error)

            Text("Plyometric Jumps")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("Hold phone securely at chest", systemImage: "iphone")
                Label("Perform vertical squat jumps", systemImage: "arrow.up")
                Label("Land softly, absorb with legs", systemImage: "arrow.down")
                Label("Jump with maximum effort", systemImage: "bolt.fill")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Text("Plyometrics build explosive power for faster running")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            PhonePlacementGuidanceView(placement: .armband)
                .padding(.horizontal, 32)

            VStack(spacing: 8) {
                Text("Target Jumps")
                    .font(.subheadline)
                Picker("Reps", selection: $targetReps) {
                    Text("5").tag(5)
                    Text("10").tag(10)
                    Text("15").tag(15)
                    Text("20").tag(20)
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 32)

            Spacer()

            Button("Start") {
                startCountdown()
            }
            .buttonStyle(DrillStartButtonStyle(color: AppColors.running))
            .accessibilityLabel("Start Plyometrics Drill")
            .accessibilityHint("Begins the jump power training exercise")
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
                .foregroundStyle(AppColors.error)
            Text("Prepare to jump!")
                .font(.headline)
            Spacer()
        }
    }

    private var activeDrillView: some View {
        VStack(spacing: 24) {
            // Jump counter
            HStack {
                Text("Jump")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("\(jumpCount)")
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.error)
                Text("/ \(targetReps)")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            // Jump height indicator
            ZStack {
                // Background track
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 200)

                // Current height
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isInAir ? Color.red : Color.orange)
                        .frame(width: 50, height: CGFloat(min(180, currentJumpPeak * 1000)))
                        .animation(.spring(response: 0.2), value: currentJumpPeak)
                }
                .frame(width: 60, height: 200)

                // Height markers
                VStack {
                    ForEach([180, 135, 90, 45], id: \.self) { height in
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 70, height: 2)
                        Spacer()
                    }
                }
                .frame(height: 180)
            }

            Text(isInAir ? "In Air!" : "Land & Jump!")
                .font(.title2.bold())
                .foregroundStyle(isInAir ? .red : .orange)

            // Stats
            VStack(spacing: 8) {
                if let lastHeight = jumpHeights.last {
                    HStack {
                        Text("Last Jump")
                        Spacer()
                        Text(String(format: "%.0f", lastHeight * 100) + " pts")
                            .bold()
                    }
                }
                if !jumpHeights.isEmpty {
                    HStack {
                        Text("Best Jump")
                        Spacer()
                        Text(String(format: "%.0f", (jumpHeights.max() ?? 0) * 100) + " pts")
                            .bold()
                            .foregroundStyle(AppColors.active)
                    }
                }
            }
            .font(.subheadline)
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
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

            let avgPower = jumpHeights.isEmpty ? 0 : jumpHeights.reduce(0, +) / Double(jumpHeights.count)
            let score = min(100, avgPower * 100)

            VStack {
                Text("\(Int(score))%")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(AppColors.error)
                Text("Power Score")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                HStack {
                    Text("Jumps Completed")
                    Spacer()
                    Text("\(jumpCount)")
                        .bold()
                }
                HStack {
                    Text("Best Jump")
                    Spacer()
                    Text(String(format: "%.0f pts", (jumpHeights.max() ?? 0) * 100))
                        .bold()
                        .foregroundStyle(AppColors.active)
                }
                HStack {
                    Text("Average Power")
                    Spacer()
                    Text(String(format: "%.0f pts", avgPower * 100))
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
                .accessibilityHint("Restart the plyometrics drill")

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

    private func gradeForScore(_ score: Double) -> String {
        if score >= 90 { return "Explosive Power!" }
        if score >= 80 { return "Great Jumps" }
        if score >= 70 { return "Good Power" }
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
        jumpCount = 0
        jumpHeights = []
        currentJumpPeak = 0
        motionAnalyzer.reset()
        motionAnalyzer.startUpdates()

        timerStartDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            guard let timerStartDate else { return }
            elapsedTime = Date().timeIntervalSince(timerStartDate)

            // Detect jump from vertical acceleration
            let verticalAccel = abs(motionAnalyzer.pitch)  // Using pitch as proxy for vertical

            if verticalAccel > 0.3 && !isInAir {
                // Takeoff detected
                isInAir = true
                currentJumpPeak = 0
            }

            if isInAir {
                currentJumpPeak = max(currentJumpPeak, verticalAccel)
            }

            if isInAir && verticalAccel < 0.1 {
                // Landing detected
                isInAir = false
                jumpCount += 1
                jumpHeights.append(currentJumpPeak)

                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()

                currentJumpPeak = 0

                if jumpCount >= targetReps {
                    endDrill()
                }
            }
        }
    }

    private func endDrill() {
        cleanup()

        let avgPower = jumpHeights.isEmpty ? 0 : jumpHeights.reduce(0, +) / Double(jumpHeights.count)
        let score = min(100, avgPower * 100)

        // Save unified drill session
        let session = UnifiedDrillSession(
            drillType: .plyometrics,
            duration: elapsedTime,
            score: score,
            coordinationScore: score,
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
        jumpHeights = []
        jumpCount = 0
        currentJumpPeak = 0
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
    PlyometricsDrillView()
        .modelContainer(for: UnifiedDrillSession.self, inMemory: true)
}
