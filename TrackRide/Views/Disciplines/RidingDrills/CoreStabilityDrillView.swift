//
//  CoreStabilityDrillView.swift
//  TrackRide
//
//  Core stability drill for developing independent seat
//  Uses unified DrillMotionAnalyzer for physics-based metrics
//  and RealTimeCueSystem for directional coaching feedback.
//

import SwiftUI
import CoreMotion
import SwiftData
import Combine

struct CoreStabilityDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var streaks: [TrainingStreak]

    // Use unified motion analyzer for physics-based metrics
    @State private var motionAnalyzer = DrillMotionAnalyzer()

    // Real-time cue system for coaching feedback
    @State private var cueSystem = RealTimeCueSystem()

    @State private var isRunning = false
    @State private var countdown = 3
    @State private var elapsedTime: TimeInterval = 0
    @State private var targetDuration: TimeInterval = 30
    @State private var timer: Timer?
    @State private var results: [StabilityResult] = []

    private var streak: TrainingStreak? {
        streaks.first
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.blue.opacity(0.1).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Core Stability")
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
                                .background(.ultraThinMaterial)
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
            // Apply real-time coaching cue overlay
            .withRealTimeCues(cueSystem)
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
            motionAnalyzer.stopUpdates()
            cueSystem.reset()
        }
    }

    private var instructionsView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "figure.core.training")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Core Stability Drill")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("Sit on exercise ball or unstable surface", systemImage: "circle.fill")
                Label("Hold phone at chest/core level", systemImage: "iphone")
                Label("Keep core engaged and steady", systemImage: "figure.core.training")
                Label("Minimize all rotation", systemImage: "arrow.triangle.2.circlepath")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            PhonePlacementGuidanceView(placement: .chestHeld)
                .padding(.horizontal, 32)

            Picker("Duration", selection: $targetDuration) {
                Text("15s").tag(TimeInterval(15))
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
                    .background(.blue)
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
                .foregroundStyle(.blue)
            Text("Engage your core")
                .font(.headline)
            Spacer()
        }
    }

    private var activeDrillView: some View {
        VStack(spacing: 24) {
            // Timer
            Text(String(format: "%.1f", targetDuration - elapsedTime))
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(elapsedTime > targetDuration - 5 ? .red : .primary)

            // Core stability visualizer - shows rotational movement
            ZStack {
                // Outer rings
                ForEach([0.2, 0.4, 0.6, 0.8, 1.0], id: \.self) { scale in
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        .frame(width: 200 * scale, height: 200 * scale)
                }

                // Crosshairs
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: 200)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 200, height: 1)

                // Movement indicator - combines roll and yaw
                Circle()
                    .fill(stabilityColor)
                    .frame(width: 30, height: 30)
                    .offset(
                        x: CGFloat(motionAnalyzer.roll * 80),
                        y: CGFloat(motionAnalyzer.yaw * 80)
                    )
                    .animation(.easeOut(duration: 0.1), value: motionAnalyzer.roll)

                // Center target
                Circle()
                    .fill(.blue)
                    .frame(width: 10, height: 10)

                // Stability score
                VStack {
                    Text("\(Int(motionAnalyzer.stabilityScore * 100))")
                        .font(.system(size: 24, weight: .bold))
                    Text("Core")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .offset(y: 100)
            }

            Text(stabilityMessage)
                .font(.headline)
                .foregroundStyle(stabilityColor)

            // Real-time stats with physics metrics
            HStack(spacing: 20) {
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
                    Text(String(format: "%.0f%%", motionAnalyzer.stabilityRetention))
                        .font(.headline.monospacedDigit())
                    Text("Endurance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Frequency domain indicators (tremor vs drift)
            if elapsedTime > 4 {
                HStack(spacing: 20) {
                    FrequencyIndicator(label: "Tremor", value: motionAnalyzer.tremorPower, threshold: DrillPhysicsConstants.CueThresholds.tremorCueThreshold)
                    FrequencyIndicator(label: "Drift", value: motionAnalyzer.driftPower, threshold: DrillPhysicsConstants.CueThresholds.driftCueThreshold)
                }
                .padding(.top, 8)
            }
        }
    }

    /// Compact indicator for frequency domain metrics
    private struct FrequencyIndicator: View {
        let label: String
        let value: Double
        let threshold: Double

        var body: some View {
            VStack(spacing: 4) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(value > threshold ? Color.orange : Color.green)
                            .frame(width: geo.size.width * min(value, 1))
                    }
                }
                .frame(width: 60, height: 6)
            }
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

            let avgStability = results.map { $0.stability }.reduce(0, +) / Double(max(results.count, 1))
            VStack {
                Text("\(Int(avgStability * 100))%")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(.blue)
                Text("Core Stability Score")
                    .foregroundStyle(.secondary)
            }

            Text(gradeForStability(avgStability))
                .font(.title2.bold())
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(gradeColor(avgStability).opacity(0.2))
                .foregroundStyle(gradeColor(avgStability))
                .clipShape(Capsule())

            Spacer()

            HStack(spacing: 16) {
                Button {
                    results = []
                    countdown = 3
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
                        .background(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }

    private var stabilityColor: Color {
        let score = motionAnalyzer.stabilityScore
        if score > 0.8 { return .green }
        if score > 0.5 { return .yellow }
        return .red
    }

    private var stabilityMessage: String {
        let score = motionAnalyzer.stabilityScore
        if score > 0.9 { return "Excellent core control!" }
        if score > 0.7 { return "Good stability" }
        if score > 0.5 { return "Some movement detected" }
        return "Engage your core!"
    }

    private func gradeForStability(_ score: Double) -> String {
        if score > 0.9 { return "Competition Ready" }
        if score > 0.8 { return "Event Level" }
        if score > 0.7 { return "Building Strength" }
        if score > 0.5 { return "Developing" }
        return "Keep Practicing"
    }

    private func gradeColor(_ score: Double) -> Color {
        if score > 0.8 { return .green }
        if score > 0.6 { return .yellow }
        return .orange
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
        cueSystem.reset()
        motionAnalyzer.reset()
        motionAnalyzer.startUpdates()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsedTime += 0.1

            // Record stability for scoring
            results.append(StabilityResult(
                timestamp: elapsedTime,
                stability: motionAnalyzer.stabilityScore
            ))

            // Process motion analysis for physics-based coaching cues
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
        timer?.invalidate()
        timer = nil
        isRunning = false
        motionAnalyzer.stopUpdates()
        cueSystem.reset()

        // Calculate average stability score using unified scorer
        let avgStability = results.map { $0.stability }.reduce(0, +) / Double(max(results.count, 1))

        // Get subscores from motion analyzer's integrated scorer
        let scorer = motionAnalyzer.scorer

        // Save unified drill session with all subscores
        let session = UnifiedDrillSession(
            drillType: .coreStability,
            duration: targetDuration,
            score: avgStability * 100
        )
        session.stabilityScore = scorer.stability
        session.symmetryScore = scorer.symmetry
        session.enduranceScore = scorer.endurance
        session.coordinationScore = scorer.coordination
        session.averageRMS = motionAnalyzer.rmsMotion
        session.peakDeviation = abs(motionAnalyzer.leftRightAsymmetry)

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

// MARK: - Preview

#Preview {
    CoreStabilityDrillView()
        .modelContainer(for: [TrainingStreak.self, UnifiedDrillSession.self], inMemory: true)
}
