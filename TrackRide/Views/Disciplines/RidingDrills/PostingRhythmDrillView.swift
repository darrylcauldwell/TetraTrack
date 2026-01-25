//
//  PostingRhythmDrillView.swift
//  TrackRide
//
//  Metronome-guided posting rhythm drill for rising trot practice
//

import SwiftUI
import SwiftData
import AVFoundation

struct PostingRhythmDrillView: View {
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
    @State private var metronomeTimer: Timer?
    @State private var bpm: Int = 70
    @State private var beatCount = 0
    @State private var lastBeatTime: Date?
    @State private var isOnBeat = false
    @State private var timingAccuracy: [Double] = []
    @State private var audioPlayer: AVAudioPlayer?

    private var streak: TrainingStreak? { streaks.first }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppColors.riding.opacity(Opacity.light).ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if !isRunning && countdown == 3 && timingAccuracy.isEmpty {
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
        .onAppear {
            configureAudio()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
            metronomeTimer?.invalidate()
            metronomeTimer = nil
            motionAnalyzer.stopUpdates()
            cueSystem.reset()
        }
    }

    private var header: some View {
        HStack {
            Text("Posting Rhythm")
                .font(.headline)
            Spacer()
            Button {
                motionAnalyzer.stopUpdates()
                metronomeTimer?.invalidate()
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
                .foregroundStyle(AppColors.riding)

            Text("Posting Rhythm Drill")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("Stand with phone at chest level", systemImage: "iphone")
                Label("Rise and sit with the metronome beat", systemImage: "arrow.up.arrow.down")
                Label("Stay smooth and consistent", systemImage: "waveform.path")
                Label("Time your up-down to each tick", systemImage: "metronome.fill")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Tempo: \(bpm) BPM")
                    .font(.headline)
                Slider(value: Binding(
                    get: { Double(bpm) },
                    set: { bpm = Int($0) }
                ), in: 50...90, step: 5)
                .tint(AppColors.riding)

                HStack {
                    Text("Slower")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Faster")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
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
            Text("Rise and sit with the beat")
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
                .foregroundStyle(elapsedTime > targetDuration - 5 ? .red : .primary)

            // Beat indicator
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 150, height: 150)

                Circle()
                    .fill(isOnBeat ? AppColors.riding : Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isOnBeat ? 1.1 : 1.0)
                    .animation(.easeOut(duration: 0.1), value: isOnBeat)

                VStack {
                    Image(systemName: "metronome.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(isOnBeat ? .white : .secondary)
                    Text("\(bpm)")
                        .font(.title2.bold())
                        .foregroundStyle(isOnBeat ? .white : .secondary)
                }
            }

            // Position indicator (shows vertical motion)
            VStack(spacing: 4) {
                Text("Your Movement")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                GeometryReader { geo in
                    ZStack {
                        // Track
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))

                        // Beat zones
                        VStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppColors.riding.opacity(0.3))
                                .frame(height: 30)
                            Spacer()
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppColors.riding.opacity(0.3))
                                .frame(height: 30)
                        }
                        .padding(4)

                        // Position indicator
                        Circle()
                            .fill(timingColor)
                            .frame(width: 20, height: 20)
                            .offset(y: CGFloat(-motionAnalyzer.pitch * 100))
                            .animation(.easeOut(duration: 0.05), value: motionAnalyzer.pitch)
                    }
                }
                .frame(width: 40, height: 120)
            }

            Text(rhythmFeedback)
                .font(.headline)
                .foregroundStyle(timingColor)

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
                    Text("\(Int(currentAccuracy))%")
                        .font(.headline.monospacedDigit())
                    Text("Accuracy")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.1f Hz", motionAnalyzer.dominantFrequency))
                        .font(.headline.monospacedDigit())
                    Text("Your Rhythm")
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

            let avgAccuracy = timingAccuracy.isEmpty ? 0 : timingAccuracy.reduce(0, +) / Double(timingAccuracy.count)

            VStack {
                Text("\(Int(avgAccuracy))%")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(AppColors.riding)
                Text("Rhythm Accuracy")
                    .foregroundStyle(.secondary)
            }

            // Additional stats
            VStack(spacing: 8) {
                HStack {
                    Text("Total Beats")
                    Spacer()
                    Text("\(beatCount)")
                        .bold()
                }
                HStack {
                    Text("Your Avg Frequency")
                    Spacer()
                    Text(String(format: "%.1f Hz", motionAnalyzer.dominantFrequency))
                        .bold()
                }
                HStack {
                    Text("Target Frequency")
                    Spacer()
                    Text(String(format: "%.1f Hz", Double(bpm) / 60.0))
                        .bold()
                }
            }
            .font(.subheadline)
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Text(gradeForScore(avgAccuracy))
                .font(.title2.bold())
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(gradeColor(avgAccuracy).opacity(0.2))
                .foregroundStyle(gradeColor(avgAccuracy))
                .clipShape(Capsule())

            Spacer()

            HStack(spacing: 16) {
                Button {
                    timingAccuracy = []
                    beatCount = 0
                    countdown = 3
                    motionAnalyzer.reset()
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

    private var currentAccuracy: Double {
        guard !timingAccuracy.isEmpty else { return 100 }
        return timingAccuracy.reduce(0, +) / Double(timingAccuracy.count)
    }

    private var timingColor: Color {
        if currentAccuracy >= 80 { return AppColors.active }
        if currentAccuracy >= 60 { return AppColors.warning }
        return AppColors.running
    }

    private var rhythmFeedback: String {
        let targetFreq = Double(bpm) / 60.0
        let currentFreq = motionAnalyzer.dominantFrequency

        if currentFreq < 0.5 {
            return "Keep moving!"
        } else if abs(currentFreq - targetFreq) < 0.1 {
            return "Perfect rhythm!"
        } else if currentFreq < targetFreq - 0.2 {
            return "Speed up a bit"
        } else if currentFreq > targetFreq + 0.2 {
            return "Slow down slightly"
        } else {
            return "Good timing"
        }
    }

    private func gradeForScore(_ score: Double) -> String {
        if score >= 90 { return "Metronome Master!" }
        if score >= 80 { return "Excellent Rhythm" }
        if score >= 70 { return "Good Timing" }
        if score >= 50 { return "Developing" }
        return "Keep Practicing"
    }

    private func gradeColor(_ score: Double) -> Color {
        if score >= 80 { return AppColors.active }
        if score >= 60 { return AppColors.warning }
        return AppColors.running
    }

    private func configureAudio() {
        // Configure audio session for metronome
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
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
        timingAccuracy = []
        motionAnalyzer.reset()
        motionAnalyzer.startUpdates()

        // Start metronome
        let beatInterval = 60.0 / Double(bpm)
        metronomeTimer = Timer.scheduledTimer(withTimeInterval: beatInterval, repeats: true) { _ in
            playBeat()
        }

        // Main timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsedTime += 0.1

            // Process real-time cues for rhythm feedback
            let targetFrequency = Double(bpm) / 60.0
            cueSystem.processRhythmAnalysis(motionAnalyzer, targetFrequency: targetFrequency, elapsed: elapsedTime)

            if elapsedTime >= targetDuration {
                endDrill()
            }
        }
    }

    private func playBeat() {
        beatCount += 1
        isOnBeat = true
        lastBeatTime = Date()

        // Haptic feedback for beat
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Calculate timing accuracy based on vertical motion phase
        // Good timing = at peak or trough of motion when beat hits
        let verticalPosition = abs(motionAnalyzer.pitch)
        let isAtExtreme = verticalPosition > 0.1  // At up or down position
        let accuracy = isAtExtreme ? min(100, 70 + verticalPosition * 200) : max(50, 70 - verticalPosition * 100)
        timingAccuracy.append(accuracy)

        // Reset beat indicator after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.isOnBeat = false
        }
    }

    private func endDrill() {
        timer?.invalidate()
        timer = nil
        metronomeTimer?.invalidate()
        metronomeTimer = nil
        isRunning = false
        motionAnalyzer.stopUpdates()
        cueSystem.reset()

        let avgAccuracy = timingAccuracy.isEmpty ? 0 : timingAccuracy.reduce(0, +) / Double(timingAccuracy.count)

        // Save unified drill session with subscores
        let session = UnifiedDrillSession(
            drillType: .postingRhythm,
            duration: targetDuration,
            score: avgAccuracy,
            stabilityScore: motionAnalyzer.scorer.stability,
            symmetryScore: motionAnalyzer.scorer.symmetry,
            enduranceScore: motionAnalyzer.scorer.endurance,
            coordinationScore: motionAnalyzer.scorer.coordination,
            averageRMS: motionAnalyzer.rmsMotion,
            rhythmAccuracy: avgAccuracy
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
    PostingRhythmDrillView()
        .modelContainer(for: TrainingStreak.self, inMemory: true)
}
