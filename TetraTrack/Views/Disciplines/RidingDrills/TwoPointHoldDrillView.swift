//
//  TwoPointHoldDrillView.swift
//  TetraTrack
//
//  Two-point (half-seat) hold drill for building leg strength and balance
//

import SwiftUI
import CoreMotion
import SwiftData
import Combine

struct TwoPointHoldDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var streaks: [TrainingStreak]
    @StateObject private var motionManager = TwoPointMotionManager()

    @State private var isRunning = false
    @State private var countdown = 3
    @State private var elapsedTime: TimeInterval = 0
    @State private var timerStartDate: Date?
    @State private var targetDuration: TimeInterval = 30
    @State private var timer: Timer?
    @State private var results: [StabilityResult] = []

    private var streak: TrainingStreak? {
        streaks.first
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppColors.running.opacity(Opacity.light).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Two-Point Hold")
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

                    // Content area
                    if !isRunning && countdown == 3 && results.isEmpty {
                        instructionsView
                            .frame(maxHeight: .infinity)
                    } else if countdown > 0 && isRunning == false {
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
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
            motionManager.stopUpdates()
        }
    }

    private var instructionsView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "figure.gymnastics")
                        .font(.system(size: 60))
                        .foregroundStyle(AppColors.running)
                        .padding(.top, Spacing.xl)

                    Text("Two-Point Hold Drill")
                        .font(.title2.bold())

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Stand in half-seat position", systemImage: "figure.gymnastics")
                        Label("Knees bent, weight in heels", systemImage: "arrow.down")
                        Label("Hold phone at chest level", systemImage: "iphone")
                        Label("Maintain position for duration", systemImage: "timer")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Picker("Duration", selection: $targetDuration) {
                        Text("15s").tag(TimeInterval(15))
                        Text("30s").tag(TimeInterval(30))
                        Text("45s").tag(TimeInterval(45))
                        Text("60s").tag(TimeInterval(60))
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal)
            }

            Button("Start Drill") {
                startCountdown()
            }
            .buttonStyle(DrillStartButtonStyle(color: AppColors.running))
            .accessibilityLabel("Start Two-Point Drill")
            .accessibilityHint("Begins the two-point hold exercise with countdown")
            .padding(.horizontal, Spacing.jumbo)
            .padding(.bottom, Spacing.xl)
            .background(AppColors.running.opacity(Opacity.light).ignoresSafeArea(edges: .bottom))
        }
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
            Text("Into two-point position")
                .font(.headline)
            Spacer()
        }
    }

    private var activeDrillView: some View {
        VStack(spacing: 24) {
            // Timer with progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 180, height: 180)

                Circle()
                    .trim(from: 0, to: elapsedTime / targetDuration)
                    .stroke(stabilityColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.1), value: elapsedTime)

                VStack(spacing: 4) {
                    Text(String(format: "%.0f", targetDuration - elapsedTime))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(elapsedTime > targetDuration - 5 ? .red : .primary)
                    Text("seconds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Stability indicator
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 100)

                // Stability bar
                GeometryReader { geo in
                    HStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(stabilityColor)
                            .frame(width: geo.size.width * motionManager.stabilityScore)
                        Spacer(minLength: 0)
                    }
                }
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(4)

                HStack {
                    VStack(alignment: .leading) {
                        Text("\(Int(motionManager.stabilityScore * 100))%")
                            .font(.title.bold())
                            .foregroundStyle(.white)
                        Text("Stability")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer()
                    Image(systemName: stabilityIcon)
                        .font(.title)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, 20)

            Text(stabilityMessage)
                .font(.headline)
                .foregroundStyle(stabilityColor)

            // Movement stats
            HStack(spacing: 40) {
                VStack {
                    Text(String(format: "%.1f", abs(motionManager.pitch * 57.3)))
                        .font(.title3.bold().monospacedDigit())
                    Text("Forward")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.1f", abs(motionManager.roll * 57.3)))
                        .font(.title3.bold().monospacedDigit())
                    Text("Lateral")
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

            let avgStability = results.map { $0.stability }.reduce(0, +) / Double(max(results.count, 1))
            VStack {
                Text("\(Int(avgStability * 100))%")
                    .scaledFont(size: 60, weight: .bold, relativeTo: .largeTitle)
                    .foregroundStyle(AppColors.running)
                Text("Two-Point Stability")
                    .foregroundStyle(.secondary)
            }

            // Duration completed
            Text("\(Int(targetDuration))s held")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(gradeForStability(avgStability))
                .font(.title2.bold())
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(gradeColor(avgStability).opacity(0.2))
                .foregroundStyle(gradeColor(avgStability))
                .clipShape(Capsule())

            Spacer()

            HStack(spacing: Spacing.lg) {
                Button("Try Again") {
                    results = []
                    countdown = 3
                }
                .buttonStyle(DrillSecondaryButtonStyle())
                .accessibilityLabel("Try Again")
                .accessibilityHint("Restart the two-point hold drill")

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
        StabilityColors.color(for: motionManager.stabilityScore)
    }

    private var stabilityIcon: String {
        if motionManager.stabilityScore > 0.8 { return "checkmark.circle.fill" }
        if motionManager.stabilityScore > 0.5 { return "exclamationmark.circle.fill" }
        return "xmark.circle.fill"
    }

    private var stabilityMessage: String {
        if motionManager.stabilityScore > 0.9 { return "Perfect form!" }
        if motionManager.stabilityScore > 0.7 { return "Strong position" }
        if motionManager.stabilityScore > 0.5 { return "Hold steady" }
        return "Keep your balance!"
    }

    private func gradeForStability(_ score: Double) -> String {
        if score > 0.9 { return "Competition Ready" }
        if score > 0.8 { return "Event Level" }
        if score > 0.7 { return "Building Strength" }
        if score > 0.5 { return "Developing" }
        return "Keep Practicing"
    }

    private func gradeColor(_ score: Double) -> Color {
        StabilityColors.gradeColor(for: score)
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
        motionManager.startUpdates()

        timerStartDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let timerStartDate else { return }
            elapsedTime = Date().timeIntervalSince(timerStartDate)
            results.append(StabilityResult(
                timestamp: elapsedTime,
                stability: motionManager.stabilityScore
            ))

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

        // Calculate average stability score
        let avgStability = results.map { $0.stability }.reduce(0, +) / Double(max(results.count, 1))

        // Save unified drill session
        let session = UnifiedDrillSession(
            drillType: .twoPoint,
            duration: targetDuration,
            score: avgStability * 100
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

// MARK: - Two-Point Motion Manager

@MainActor
class TwoPointMotionManager: ObservableObject {
    private let motionManager = CMMotionManager()

    @Published var pitch: Double = 0
    @Published var roll: Double = 0
    @Published var totalMovement: Double = 0
    @Published var stabilityScore: Double = 1.0

    private var previousPitch: Double = 0
    private var previousRoll: Double = 0

    func startUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 1/60
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, let self = self else { return }

            self.pitch = motion.attitude.pitch
            self.roll = motion.attitude.roll

            // Calculate movement from previous frame
            let pitchDelta = abs(self.pitch - self.previousPitch)
            let rollDelta = abs(self.roll - self.previousRoll)
            self.totalMovement = pitchDelta + rollDelta

            // Calculate stability (inverse of movement, smoothed)
            let movement = sqrt(pitchDelta * pitchDelta + rollDelta * rollDelta)
            let rawStability = max(0, 1 - (movement * 20))
            self.stabilityScore = self.stabilityScore * 0.9 + rawStability * 0.1

            self.previousPitch = self.pitch
            self.previousRoll = self.roll
        }
    }

    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}

#Preview {
    TwoPointHoldDrillView()
        .modelContainer(for: TrainingStreak.self, inMemory: true)
}
