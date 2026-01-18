//
//  PosturalDriftDrillView.swift
//  TrackRide
//
//  Extended hold drill measuring stability degradation over time
//

import SwiftUI
import SwiftData
import CoreMotion
import Combine

struct PosturalDriftDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var motionManager = PosturalDriftMotionManager()
    @State private var cueSystem = RealTimeCueSystem()
    @State private var isRunning = false
    @State private var countdown = 3
    @State private var elapsedTime: TimeInterval = 0
    @State private var targetDuration: TimeInterval = 60
    @State private var timer: Timer?
    @State private var stabilityHistory: [(time: TimeInterval, stability: Double)] = []
    @State private var currentStability: Double = 100

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.indigo.opacity(0.1).ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if !isRunning && countdown == 3 && stabilityHistory.isEmpty {
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
            timer?.invalidate()
            timer = nil
            motionManager.stopUpdates()
            cueSystem.reset()
        }
    }

    private var header: some View {
        HStack {
            Text("Postural Drift")
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
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding()
    }

    private var instructionsView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "figure.walk.motion")
                .font(.system(size: 60))
                .foregroundStyle(.indigo)

            Text("Postural Drift Drill")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("Extended stability hold", systemImage: "clock")
                Label("Maintain aim as long as possible", systemImage: "scope")
                Label("Track how stability degrades", systemImage: "chart.line.downtrend.xyaxis")
                Label("Build shooting endurance", systemImage: "figure.strengthtraining.traditional")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Text("Competition shooting requires sustained focus")
                .font(.caption)
                .foregroundStyle(.secondary)
                .italic()
                .padding(.top, 8)

            Picker("Duration", selection: $targetDuration) {
                Text("60s").tag(TimeInterval(60))
                Text("90s").tag(TimeInterval(90))
                Text("120s").tag(TimeInterval(120))
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
            Text("Get Ready!")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("\(countdown)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundStyle(.indigo)
            Text("Find your stable hold")
                .font(.headline)
            Spacer()
        }
    }

    private var activeDrillView: some View {
        VStack(spacing: 16) {
            // Timer
            HStack {
                Text(String(format: "%.0f", elapsedTime))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("/")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("\(Int(targetDuration))s")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    Rectangle()
                        .fill(progressColor)
                        .frame(width: geo.size.width * (elapsedTime / targetDuration))
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())
            .padding(.horizontal, 40)

            // Stability visualizer
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 180, height: 180)

                // Stability arc
                Circle()
                    .trim(from: 0, to: currentStability / 100)
                    .stroke(
                        stabilityColor,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))

                // Center info
                VStack(spacing: 4) {
                    Text("\(Int(currentStability))%")
                        .font(.system(size: 36, weight: .bold))
                    Text("Stability")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Wobble indicator
                Circle()
                    .fill(stabilityColor)
                    .frame(width: 16, height: 16)
                    .offset(
                        x: CGFloat(motionManager.pitch * 50),
                        y: CGFloat(motionManager.roll * 50)
                    )
                    .animation(.easeOut(duration: 0.05), value: motionManager.wobble)
            }

            Text(feedbackMessage)
                .font(.headline)
                .foregroundStyle(stabilityColor)

            // Stability trend chart
            VStack(spacing: 4) {
                Text("Stability Over Time")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                GeometryReader { geo in
                    Path { path in
                        guard stabilityHistory.count > 1 else { return }
                        let stepX = geo.size.width / CGFloat(targetDuration)

                        path.move(to: CGPoint(
                            x: 0,
                            y: geo.size.height * (1 - stabilityHistory[0].stability / 100)
                        ))

                        for point in stabilityHistory {
                            path.addLine(to: CGPoint(
                                x: CGFloat(point.time) * stepX,
                                y: geo.size.height * (1 - point.stability / 100)
                            ))
                        }
                    }
                    .stroke(Color.indigo, lineWidth: 2)

                    // Threshold line
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: geo.size.height * 0.3))
                        path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height * 0.3))
                    }
                    .stroke(Color.green.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5]))
                }
                .frame(height: 60)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 40)

            // Stats
            HStack(spacing: 30) {
                VStack {
                    Text(String(format: "%.1f°", motionManager.wobble * 57.3))
                        .font(.headline.monospacedDigit())
                    Text("Wobble")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    if let initialStability = stabilityHistory.first?.stability {
                        let drift = initialStability - currentStability
                        Text(String(format: "%.0f%%", drift))
                            .font(.headline)
                            .foregroundStyle(drift > 20 ? .orange : .primary)
                    } else {
                        Text("--")
                            .font(.headline)
                    }
                    Text("Drift")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    let avgStability = stabilityHistory.isEmpty ? 100 : stabilityHistory.map(\.stability).reduce(0, +) / Double(stabilityHistory.count)
                    Text("\(Int(avgStability))%")
                        .font(.headline)
                    Text("Average")
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
                .foregroundStyle(.green)

            Text("Complete!")
                .font(.title.bold())

            let avgStability = stabilityHistory.isEmpty ? 0 : stabilityHistory.map(\.stability).reduce(0, +) / Double(stabilityHistory.count)
            let initialStability = stabilityHistory.first?.stability ?? 100
            let finalStability = stabilityHistory.last?.stability ?? 0
            let totalDrift = initialStability - finalStability

            VStack(spacing: 8) {
                Text("\(Int(avgStability))%")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.indigo)
                Text("Average Stability")
                    .foregroundStyle(.secondary)
            }

            // Breakdown
            VStack(spacing: 12) {
                resultRow(label: "Initial Stability", value: "\(Int(initialStability))%")
                resultRow(label: "Final Stability", value: "\(Int(finalStability))%")
                resultRow(label: "Total Drift", value: "\(Int(totalDrift))%", color: totalDrift > 30 ? .orange : .primary)
                resultRow(label: "Duration", value: String(format: "%.0fs", elapsedTime))
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            // Calculate endurance score - reward maintaining stability
            let enduranceScore = max(0, avgStability - (totalDrift * 0.5))
            Text(gradeForScore(enduranceScore))
                .font(.title2.bold())
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(gradeColor(enduranceScore).opacity(0.2))
                .foregroundStyle(gradeColor(enduranceScore))
                .clipShape(Capsule())

            Spacer()

            HStack(spacing: 16) {
                Button {
                    stabilityHistory = []
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
                        .background(.indigo)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }

    private func resultRow(label: String, value: String, color: Color = .primary) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .bold()
                .foregroundStyle(color)
        }
        .font(.subheadline)
    }

    private var progressColor: Color {
        let progress = elapsedTime / targetDuration
        if progress > 0.8 { return .green }
        if progress > 0.5 { return .yellow }
        return .indigo
    }

    private var stabilityColor: Color {
        if currentStability >= 70 { return .green }
        if currentStability >= 50 { return .yellow }
        if currentStability >= 30 { return .orange }
        return .red
    }

    private var feedbackMessage: String {
        if currentStability >= 85 { return "Excellent hold!" }
        if currentStability >= 70 { return "Good stability" }
        if currentStability >= 50 { return "Some fatigue showing" }
        if currentStability >= 30 { return "Focus! Stay with it" }
        return "Drift detected - reset position"
    }

    private func gradeForScore(_ score: Double) -> String {
        if score >= 80 { return "Iron Will!" }
        if score >= 65 { return "Strong Endurance" }
        if score >= 50 { return "Solid Hold" }
        if score >= 35 { return "Building Stamina" }
        return "Keep Practicing"
    }

    private func gradeColor(_ score: Double) -> Color {
        if score >= 70 { return .green }
        if score >= 50 { return .yellow }
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
        stabilityHistory = []
        currentStability = 100
        motionManager.startUpdates()

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            elapsedTime += 0.5

            // Calculate current stability from wobble
            let wobbleStability = max(0, 100 - (motionManager.wobble * 200))
            currentStability = currentStability * 0.8 + wobbleStability * 0.2

            // Record stability point
            stabilityHistory.append((time: elapsedTime, stability: currentStability))

            // Process real-time cues
            cueSystem.processDrillState(score: currentStability, stability: currentStability, elapsed: elapsedTime, duration: targetDuration)

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
        cueSystem.reset()

        let avgStability = stabilityHistory.isEmpty ? 0 : stabilityHistory.map(\.stability).reduce(0, +) / Double(stabilityHistory.count)
        let totalDrift = (stabilityHistory.first?.stability ?? 100) - (stabilityHistory.last?.stability ?? 0)
        let enduranceScore = max(0, avgStability - (totalDrift * 0.5))

        // Save session
        let session = ShootingDrillSession(
            drillType: .posturalDrift,
            duration: targetDuration,
            score: enduranceScore,
            stabilityScore: avgStability,
            enduranceScore: enduranceScore,
            averageWobble: motionManager.averageWobble
        )
        modelContext.insert(session)
        try? modelContext.save()

        // Compute and save skill domain scores
        let skillService = SkillDomainService()
        let skillScores = skillService.computeScores(from: session)
        for skillScore in skillScores {
            modelContext.insert(skillScore)
        }
        try? modelContext.save()

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - Postural Drift Motion Manager

@MainActor
class PosturalDriftMotionManager: ObservableObject {
    private let motionManager = CMMotionManager()

    @Published var pitch: Double = 0
    @Published var roll: Double = 0
    @Published var wobble: Double = 0
    @Published var averageWobble: Double = 0

    private var referencePitch: Double?
    private var referenceRoll: Double?
    private var wobbleSum: Double = 0
    private var sampleCount: Int = 0

    func startUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }

        referencePitch = nil
        referenceRoll = nil
        wobbleSum = 0
        sampleCount = 0

        motionManager.deviceMotionUpdateInterval = 1/60
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, let self = self else { return }

            if self.referencePitch == nil {
                self.referencePitch = motion.attitude.pitch
                self.referenceRoll = motion.attitude.roll
            }

            self.pitch = motion.attitude.pitch - (self.referencePitch ?? 0)
            self.roll = motion.attitude.roll - (self.referenceRoll ?? 0)
            self.wobble = sqrt(self.pitch * self.pitch + self.roll * self.roll)

            self.wobbleSum += self.wobble
            self.sampleCount += 1
            self.averageWobble = self.wobbleSum / Double(self.sampleCount)
        }
    }

    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}

#Preview {
    PosturalDriftDrillView()
}
