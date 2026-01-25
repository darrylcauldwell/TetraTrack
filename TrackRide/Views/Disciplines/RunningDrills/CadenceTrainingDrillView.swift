//
//  CadenceTrainingDrillView.swift
//  TrackRide
//
//  Metronome-guided cadence training for optimal running efficiency (180 SPM target)
//

import SwiftUI
import SwiftData
import AVFoundation

struct CadenceTrainingDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var motionAnalyzer = DrillMotionAnalyzer()
    @State private var cueSystem = RealTimeCueSystem()
    @State private var isRunning = false
    @State private var countdown = 3
    @State private var elapsedTime: TimeInterval = 0
    @State private var targetDuration: TimeInterval = 60
    @State private var timer: Timer?
    @State private var metronomeTimer: Timer?
    @State private var targetSPM: Int = 180
    @State private var beatCount = 0
    @State private var isOnBeat = false
    @State private var stepCount = 0
    @State private var cadenceReadings: [Int] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppColors.running.opacity(Opacity.light).ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if !isRunning && countdown == 3 && cadenceReadings.isEmpty {
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
            Text("Cadence Training")
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

            Image(systemName: "metronome")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.running)

            Text("Cadence Training")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("Hold phone at waist or arm level", systemImage: "iphone")
                Label("March or run in place to the beat", systemImage: "figure.run")
                Label("Each beat = one foot strike", systemImage: "shoe.fill")
                Label("180 SPM is optimal for efficiency", systemImage: "speedometer")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            PhonePlacementGuidanceView(placement: .armband)
                .padding(.horizontal, 32)

            VStack(spacing: 8) {
                Text("Target: \(targetSPM) SPM")
                    .font(.headline)
                Slider(value: Binding(
                    get: { Double(targetSPM) },
                    set: { targetSPM = Int($0) }
                ), in: 150...200, step: 5)
                .tint(AppColors.running)

                HStack {
                    Text("150")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("200")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 32)

            Picker("Duration", selection: $targetDuration) {
                Text("30s").tag(TimeInterval(30))
                Text("60s").tag(TimeInterval(60))
                Text("2m").tag(TimeInterval(120))
                Text("3m").tag(TimeInterval(180))
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 32)

            Spacer()

            Button("Start") {
                startCountdown()
            }
            .buttonStyle(DrillStartButtonStyle(color: AppColors.running))
            .accessibilityLabel("Start Cadence Training")
            .accessibilityHint("Begins the metronome-guided running cadence exercise")
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
            Text("Step with each beat")
                .font(.headline)
            Spacer()
        }
    }

    private var activeDrillView: some View {
        VStack(spacing: 20) {
            // Timer
            Text(String(format: "%.1f", targetDuration - elapsedTime))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(elapsedTime > targetDuration - 10 ? .red : .primary)

            // Beat indicator
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 150, height: 150)

                Circle()
                    .fill(isOnBeat ? AppColors.running : Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isOnBeat ? 1.1 : 1.0)
                    .animation(.easeOut(duration: 0.1), value: isOnBeat)

                VStack {
                    Image(systemName: "figure.run")
                        .font(.system(size: 40))
                        .foregroundStyle(isOnBeat ? .white : .secondary)
                    Text("\(targetSPM)")
                        .font(.title2.bold())
                        .foregroundStyle(isOnBeat ? .white : .secondary)
                }
            }

            // Current cadence
            VStack(spacing: 4) {
                Text("Your Cadence")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(currentCadence) SPM")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(cadenceColor)
            }

            Text(cadenceFeedback)
                .font(.headline)
                .foregroundStyle(cadenceColor)

            // Stats
            HStack(spacing: 30) {
                VStack {
                    Text("\(beatCount)")
                        .font(.headline.monospacedDigit())
                    Text("Beats")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(stepCount)")
                        .font(.headline.monospacedDigit())
                    Text("Steps")
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

            let avgCadence = cadenceReadings.isEmpty ? 0 : cadenceReadings.reduce(0, +) / cadenceReadings.count
            let accuracy = calculateAccuracy(avgCadence: avgCadence)

            VStack {
                Text("\(avgCadence)")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(AppColors.running)
                Text("Average SPM")
                    .foregroundStyle(.secondary)
            }

            VStack {
                Text("\(Int(accuracy))%")
                    .font(.title.bold())
                    .foregroundStyle(accuracy >= 80 ? AppColors.active : AppColors.running)
                Text("Accuracy")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                HStack {
                    Text("Target SPM")
                    Spacer()
                    Text("\(targetSPM)")
                        .bold()
                }
                HStack {
                    Text("Total Steps")
                    Spacer()
                    Text("\(stepCount)")
                        .bold()
                }
            }
            .font(.subheadline)
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Text(gradeForScore(accuracy))
                .font(.title2.bold())
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.sm)
                .background(accuracy >= 80 ? AppColors.active.opacity(0.2) : AppColors.running.opacity(0.2))
                .foregroundStyle(accuracy >= 80 ? AppColors.active : AppColors.running)
                .clipShape(Capsule())

            Spacer()

            HStack(spacing: Spacing.lg) {
                Button("Try Again") {
                    reset()
                }
                .buttonStyle(DrillSecondaryButtonStyle())
                .accessibilityLabel("Try Again")
                .accessibilityHint("Restart the cadence training drill")

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

    private var currentCadence: Int {
        guard elapsedTime > 5 else { return 0 }
        return Int((Double(stepCount) / elapsedTime) * 60)
    }

    private var cadenceColor: Color {
        let diff = abs(currentCadence - targetSPM)
        if diff <= 5 { return AppColors.active }
        if diff <= 15 { return AppColors.warning }
        return AppColors.running
    }

    private var cadenceFeedback: String {
        guard currentCadence > 0 else { return "Start stepping!" }
        let diff = currentCadence - targetSPM
        if abs(diff) <= 5 { return "Perfect cadence!" }
        if diff > 15 { return "Slow down" }
        if diff < -15 { return "Speed up" }
        if diff > 0 { return "Slightly fast" }
        return "Slightly slow"
    }

    private func calculateAccuracy(avgCadence: Int) -> Double {
        guard avgCadence > 0 else { return 0 }
        let diff = abs(Double(avgCadence - targetSPM))
        return max(0, 100 - (diff / Double(targetSPM)) * 200)
    }

    private func gradeForScore(_ score: Double) -> String {
        if score >= 95 { return "Metronome Perfect!" }
        if score >= 85 { return "Excellent Cadence" }
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
        beatCount = 0
        stepCount = 0
        cadenceReadings = []
        motionAnalyzer.reset()
        motionAnalyzer.startUpdates()

        // Start metronome
        let beatInterval = 60.0 / Double(targetSPM)
        metronomeTimer = Timer.scheduledTimer(withTimeInterval: beatInterval, repeats: true) { _ in
            playBeat()
        }

        // Main timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsedTime += 0.1

            // Process real-time cues for rhythm feedback
            let targetFrequency = Double(targetSPM) / 60.0
            cueSystem.processRhythmAnalysis(motionAnalyzer, targetFrequency: targetFrequency, elapsed: elapsedTime)

            // Detect steps from vertical acceleration peaks
            if motionAnalyzer.rmsMotion > 0.3 {
                stepCount += 1
            }

            // Record cadence every 5 seconds
            if Int(elapsedTime) % 5 == 0 && elapsedTime > 0 {
                cadenceReadings.append(currentCadence)
            }

            if elapsedTime >= targetDuration {
                endDrill()
            }
        }
    }

    private func playBeat() {
        beatCount += 1
        isOnBeat = true

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isOnBeat = false
        }
    }

    private func endDrill() {
        cleanup()

        let avgCadence = cadenceReadings.isEmpty ? currentCadence : cadenceReadings.reduce(0, +) / cadenceReadings.count
        let accuracy = calculateAccuracy(avgCadence: avgCadence)

        // Save unified drill session
        let session = UnifiedDrillSession(
            drillType: .cadenceTraining,
            duration: targetDuration,
            score: accuracy,
            rhythmScore: accuracy,
            rhythmAccuracy: accuracy,
            cadence: avgCadence
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
        cadenceReadings = []
        stepCount = 0
        beatCount = 0
        countdown = 3
        motionAnalyzer.reset()
    }

    private func cleanup() {
        timer?.invalidate()
        timer = nil
        metronomeTimer?.invalidate()
        metronomeTimer = nil
        isRunning = false
        motionAnalyzer.stopUpdates()
        cueSystem.reset()
    }
}

#Preview {
    CadenceTrainingDrillView()
        .modelContainer(for: UnifiedDrillSession.self, inMemory: true)
}
