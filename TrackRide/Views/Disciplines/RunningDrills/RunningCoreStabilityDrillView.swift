//
//  RunningCoreStabilityDrillView.swift
//  TrackRide
//
//  Plank hold drill with motion tracking for running core stability
//

import SwiftUI
import SwiftData

struct RunningCoreStabilityDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var motionAnalyzer = DrillMotionAnalyzer()
    @State private var isRunning = false
    @State private var countdown = 3
    @State private var elapsedTime: TimeInterval = 0
    @State private var targetDuration: TimeInterval = 30
    @State private var timer: Timer?
    @State private var stabilityReadings: [Double] = []
    @State private var cueSystem = RealTimeCueSystem()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.green.opacity(0.1).ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if !isRunning && countdown == 3 && stabilityReadings.isEmpty {
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
            Text("Running Core Stability")
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
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding()
    }

    private var instructionsView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "figure.core.training")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Core Stability for Runners")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("Place phone flat on your back", systemImage: "iphone")
                Label("Get into plank position", systemImage: "figure.core.training")
                Label("Keep your body straight and still", systemImage: "arrow.left.and.right")
                Label("Engage your core throughout", systemImage: "bolt.fill")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Text("A strong core means better running posture and efficiency")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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
                    .background(.green)
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
            Text("Get in Position!")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("\(countdown)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
            Text("Plank position, phone on back")
                .font(.headline)
            Spacer()
        }
    }

    private var activeDrillView: some View {
        VStack(spacing: 24) {
            // Timer
            Text(String(format: "%.1f", targetDuration - elapsedTime))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(elapsedTime > targetDuration - 5 ? .red : .primary)

            // Stability indicator
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 180, height: 180)

                Circle()
                    .fill(stabilityColor.opacity(0.3))
                    .frame(width: 150, height: 150)

                // Level indicator
                Circle()
                    .fill(stabilityColor)
                    .frame(width: 30, height: 30)
                    .offset(
                        x: CGFloat(motionAnalyzer.roll * 50),
                        y: CGFloat(motionAnalyzer.pitch * 50)
                    )
                    .animation(.easeOut(duration: 0.1), value: motionAnalyzer.roll)
                    .animation(.easeOut(duration: 0.1), value: motionAnalyzer.pitch)

                // Target zone
                Circle()
                    .strokeBorder(Color.green, lineWidth: 2)
                    .frame(width: 60, height: 60)
            }

            Text(currentStability >= 80 ? "Excellent stability!" : "Keep still!")
                .font(.headline)
                .foregroundStyle(stabilityColor)

            // Stats
            HStack(spacing: 30) {
                VStack {
                    Text("\(Int(currentStability))%")
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(stabilityColor)
                    Text("Stability")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.2f", motionAnalyzer.rmsMotion))
                        .font(.title2.bold().monospacedDigit())
                    Text("Motion")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress bar
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green)
                            .frame(width: geo.size.width * (elapsedTime / targetDuration))
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("0s")
                    Spacer()
                    Text("\(Int(targetDuration))s")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 40)
        }
    }

    private var resultsView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Complete!")
                .font(.title.bold())

            let avgStability = stabilityReadings.isEmpty ? 0 : stabilityReadings.reduce(0, +) / Double(stabilityReadings.count)

            VStack {
                Text("\(Int(avgStability))%")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(.green)
                Text("Core Stability Score")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                HStack {
                    Text("Hold Time")
                    Spacer()
                    Text("\(Int(targetDuration))s")
                        .bold()
                }
                HStack {
                    Text("Average Motion")
                    Spacer()
                    Text(String(format: "%.3f", motionAnalyzer.rmsMotion))
                        .bold()
                }
            }
            .font(.subheadline)
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Text(gradeForScore(avgStability))
                .font(.title2.bold())
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(avgStability >= 70 ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
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
                        .background(Color(.secondarySystemBackground))
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
                        .background(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }

    private var currentStability: Double {
        motionAnalyzer.scorer.stability
    }

    private var stabilityColor: Color {
        if currentStability >= 80 { return .green }
        if currentStability >= 60 { return .yellow }
        return .orange
    }

    private func gradeForScore(_ score: Double) -> String {
        if score >= 90 { return "Rock Solid!" }
        if score >= 80 { return "Excellent Core" }
        if score >= 70 { return "Good Stability" }
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
        stabilityReadings = []
        motionAnalyzer.reset()
        motionAnalyzer.startUpdates()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsedTime += 0.1

            // Record stability
            stabilityReadings.append(currentStability)

            // Real-time cues
            cueSystem.processDrillState(
                score: currentStability,
                stability: currentStability,
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

        let avgStability = stabilityReadings.isEmpty ? 0 : stabilityReadings.reduce(0, +) / Double(stabilityReadings.count)

        // Save unified drill session
        let session = UnifiedDrillSession(
            drillType: .runningCoreStability,
            duration: targetDuration,
            score: avgStability,
            stabilityScore: avgStability,
            enduranceScore: motionAnalyzer.scorer.endurance,
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
        stabilityReadings = []
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
    RunningCoreStabilityDrillView()
        .modelContainer(for: UnifiedDrillSession.self, inMemory: true)
}
