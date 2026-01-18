//
//  StreamlinePositionDrillView.swift
//  TrackRide
//
//  Perfect streamline posture hold for swimming starts and turns
//

import SwiftUI
import SwiftData

struct StreamlinePositionDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var motionAnalyzer = DrillMotionAnalyzer()
    @State private var isRunning = false
    @State private var countdown = 3
    @State private var elapsedTime: TimeInterval = 0
    @State private var targetDuration: TimeInterval = 20
    @State private var timer: Timer?
    @State private var positionReadings: [Double] = []
    @State private var bestHoldTime: TimeInterval = 0
    @State private var currentHoldStart: Date?
    @State private var cueSystem = RealTimeCueSystem()

    private let perfectThreshold = 0.08  // Very strict for streamline

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.indigo.opacity(0.1).ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if !isRunning && countdown == 3 && positionReadings.isEmpty {
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
            Text("Streamline Position")
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

            Image(systemName: "arrow.up.to.line")
                .font(.system(size: 60))
                .foregroundStyle(.indigo)

            Text("Streamline Position")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("Stand with arms overhead", systemImage: "figure.stand")
                Label("Hands stacked, arms by ears", systemImage: "arrow.up")
                Label("Squeeze ears with biceps", systemImage: "arrow.left.and.right.and.up")
                Label("Phone held between palms", systemImage: "iphone")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Text("A perfect streamline reduces drag on starts and turns")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            PhonePlacementGuidanceView(placement: .floorBeside)
                .padding(.horizontal, 32)

            Picker("Hold Duration", selection: $targetDuration) {
                Text("15s").tag(TimeInterval(15))
                Text("20s").tag(TimeInterval(20))
                Text("30s").tag(TimeInterval(30))
                Text("45s").tag(TimeInterval(45))
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
                    .background(.indigo)
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
                .foregroundStyle(.indigo)
            Text("Arms up, phone between palms")
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

            // Position visualizer - vertical streamline
            ZStack {
                // Target zone (vertical rectangle)
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.indigo.opacity(0.1))
                    .frame(width: 60, height: 200)

                // Perfect zone
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.green, lineWidth: 2)
                    .frame(width: 40, height: 180)

                // Current position indicator
                RoundedRectangle(cornerRadius: 4)
                    .fill(positionColor)
                    .frame(width: 30, height: 30)
                    .offset(
                        x: CGFloat(motionAnalyzer.roll * 100),
                        y: CGFloat(motionAnalyzer.pitch * 100)
                    )
                    .animation(.easeOut(duration: 0.1), value: motionAnalyzer.roll)
                    .animation(.easeOut(duration: 0.1), value: motionAnalyzer.pitch)

                // Side alignment markers
                VStack {
                    ForEach(0..<5) { i in
                        Rectangle()
                            .fill(Color.indigo.opacity(0.3))
                            .frame(width: 70, height: 1)
                        if i < 4 { Spacer() }
                    }
                }
                .frame(height: 180)
            }

            Text(positionFeedback)
                .font(.headline)
                .foregroundStyle(positionColor)

            // Stats
            HStack(spacing: 30) {
                VStack {
                    Text("\(Int(currentPositionScore))%")
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(positionColor)
                    Text("Alignment")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.1fs", bestHoldTime))
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(.green)
                    Text("Best Hold")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.3f", motionAnalyzer.rmsMotion))
                        .font(.title2.bold().monospacedDigit())
                    Text("Motion")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.indigo)
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
                .foregroundStyle(.green)

            Text("Complete!")
                .font(.title.bold())

            let avgPosition = positionReadings.isEmpty ? 0 : positionReadings.reduce(0, +) / Double(positionReadings.count)

            VStack {
                Text("\(Int(avgPosition))%")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(.indigo)
                Text("Streamline Score")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                HStack {
                    Text("Hold Duration")
                    Spacer()
                    Text("\(Int(targetDuration))s")
                        .bold()
                }
                HStack {
                    Text("Best Perfect Hold")
                    Spacer()
                    Text(String(format: "%.1fs", bestHoldTime))
                        .bold()
                        .foregroundStyle(.green)
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

            Text(gradeForScore(avgPosition))
                .font(.title2.bold())
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(avgPosition >= 70 ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                .foregroundStyle(avgPosition >= 70 ? .green : .orange)
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
                        .background(.indigo)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }

    private var currentPositionScore: Double {
        let deviation = sqrt(pow(motionAnalyzer.roll, 2) + pow(motionAnalyzer.pitch, 2))
        return max(0, 100 - deviation * 500)
    }

    private var positionColor: Color {
        if currentPositionScore >= 90 { return .green }
        if currentPositionScore >= 70 { return .yellow }
        return .orange
    }

    private var positionFeedback: String {
        if currentPositionScore >= 95 { return "Perfect streamline!" }
        if currentPositionScore >= 85 { return "Great position" }
        if currentPositionScore >= 70 { return "Hold steady" }
        if currentPositionScore >= 50 { return "Straighten up" }
        return "Find your line"
    }

    private func gradeForScore(_ score: Double) -> String {
        if score >= 90 { return "Torpedo Form!" }
        if score >= 80 { return "Excellent Streamline" }
        if score >= 70 { return "Good Position" }
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
        positionReadings = []
        bestHoldTime = 0
        currentHoldStart = nil
        motionAnalyzer.reset()
        motionAnalyzer.startUpdates()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsedTime += 0.1
            positionReadings.append(currentPositionScore)

            // Track best hold time in perfect zone
            let deviation = sqrt(pow(motionAnalyzer.roll, 2) + pow(motionAnalyzer.pitch, 2))
            if deviation < perfectThreshold {
                if currentHoldStart == nil {
                    currentHoldStart = Date()
                }
            } else {
                if let start = currentHoldStart {
                    let holdTime = Date().timeIntervalSince(start)
                    bestHoldTime = max(bestHoldTime, holdTime)
                }
                currentHoldStart = nil
            }

            cueSystem.processDrillState(
                score: currentPositionScore,
                stability: currentPositionScore,
                elapsed: elapsedTime,
                duration: targetDuration
            )

            if elapsedTime >= targetDuration {
                // Check final hold
                if let start = currentHoldStart {
                    let holdTime = Date().timeIntervalSince(start)
                    bestHoldTime = max(bestHoldTime, holdTime)
                }
                endDrill()
            }
        }
    }

    private func endDrill() {
        cleanup()

        let avgPosition = positionReadings.isEmpty ? 0 : positionReadings.reduce(0, +) / Double(positionReadings.count)

        let session = UnifiedDrillSession(
            drillType: .streamlinePosition,
            duration: targetDuration,
            score: avgPosition,
            stabilityScore: avgPosition,
            enduranceScore: min(100, bestHoldTime / targetDuration * 100),
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
        positionReadings = []
        bestHoldTime = 0
        currentHoldStart = nil
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
    StreamlinePositionDrillView()
        .modelContainer(for: UnifiedDrillSession.self, inMemory: true)
}
