//
//  KickEfficiencyDrillView.swift
//  TrackRide
//
//  Flutter kick rhythm analysis for efficient swimming propulsion
//

import SwiftUI
import SwiftData

struct KickEfficiencyDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var motionAnalyzer = DrillMotionAnalyzer()
    @State private var isRunning = false
    @State private var countdown = 3
    @State private var elapsedTime: TimeInterval = 0
    @State private var targetDuration: TimeInterval = 60
    @State private var timer: Timer?
    @State private var kickCount = 0
    @State private var lastKickTime: Date?
    @State private var kickIntervals: [TimeInterval] = []
    @State private var efficiencyReadings: [Double] = []
    @State private var kickStyle: KickStyle = .flutter
    @State private var cueSystem = RealTimeCueSystem()

    enum KickStyle: String, CaseIterable {
        case flutter = "Flutter"
        case dolphin = "Dolphin"
        case breaststroke = "Breaststroke"

        var description: String {
            switch self {
            case .flutter: return "Alternating legs, small quick kicks"
            case .dolphin: return "Legs together, wave motion"
            case .breaststroke: return "Whip kick, legs together then apart"
            }
        }

        var targetFrequency: Double {
            switch self {
            case .flutter: return 3.0  // ~6 kicks per second (each leg)
            case .dolphin: return 1.5  // ~1.5 kicks per second
            case .breaststroke: return 0.8  // ~1 kick per second
            }
        }

        var icon: String {
            switch self {
            case .flutter: return "waveform.path"
            case .dolphin: return "water.waves"
            case .breaststroke: return "arrow.left.and.right"
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.cyan.opacity(0.1).ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if !isRunning && countdown == 3 && efficiencyReadings.isEmpty {
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
            Text("Kick Efficiency")
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

            Image(systemName: "figure.pool.swim")
                .font(.system(size: 60))
                .foregroundStyle(.cyan)

            Text("Kick Rhythm Training")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("Lie face down on a bench or floor", systemImage: "bed.double")
                Label("Phone secured on lower leg/ankle", systemImage: "iphone")
                Label("Perform your kick pattern", systemImage: kickStyle.icon)
                Label("Focus on consistent rhythm", systemImage: "metronome")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Text("Efficient kicks provide propulsion without wasting energy")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Kick style selection
            VStack(spacing: 8) {
                Text("Kick Style")
                    .font(.subheadline.bold())
                Picker("Style", selection: $kickStyle) {
                    ForEach(KickStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                Text(kickStyle.description)
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

            Button {
                startCountdown()
            } label: {
                Text("Start")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.cyan)
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
                .foregroundStyle(.cyan)
            Text("Phone on ankle, prepare to kick")
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

            // Kick style indicator
            HStack {
                Image(systemName: kickStyle.icon)
                    .font(.title2)
                Text(kickStyle.rawValue)
                    .font(.title3.bold())
            }
            .foregroundStyle(.cyan)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(Color.cyan.opacity(0.2))
            .clipShape(Capsule())

            // Rhythm visualizer
            ZStack {
                // Background wave
                WaveShape(frequency: kickStyle.targetFrequency, amplitude: 0.3, phase: elapsedTime * 2)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(height: 100)

                // Current rhythm wave
                WaveShape(frequency: currentFrequency, amplitude: 0.4, phase: elapsedTime * 2)
                    .stroke(rhythmColor, lineWidth: 4)
                    .frame(height: 100)
                    .animation(.easeOut(duration: 0.2), value: currentFrequency)
            }
            .frame(height: 120)
            .padding(.horizontal, 20)

            Text(rhythmFeedback)
                .font(.headline)
                .foregroundStyle(rhythmColor)

            // Stats
            HStack(spacing: 24) {
                VStack {
                    Text("\(kickCount)")
                        .font(.title2.bold().monospacedDigit())
                    Text("Kicks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.1f Hz", currentFrequency))
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(rhythmColor)
                    Text("Frequency")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(Int(currentEfficiency))%")
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(rhythmColor)
                    Text("Efficiency")
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
                        .fill(Color.cyan)
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

            let avgEfficiency = efficiencyReadings.isEmpty ? 0 : efficiencyReadings.reduce(0, +) / Double(efficiencyReadings.count)
            let avgFreq = kickIntervals.isEmpty ? 0 : 1.0 / (kickIntervals.reduce(0, +) / Double(kickIntervals.count))

            VStack {
                Text("\(Int(avgEfficiency))%")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(.cyan)
                Text("Kick Efficiency")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                HStack {
                    Text("Total Kicks")
                    Spacer()
                    Text("\(kickCount)")
                        .bold()
                }
                HStack {
                    Text("Average Frequency")
                    Spacer()
                    Text(String(format: "%.1f Hz", avgFreq))
                        .bold()
                }
                HStack {
                    Text("Target Frequency")
                    Spacer()
                    Text(String(format: "%.1f Hz", kickStyle.targetFrequency))
                        .bold()
                        .foregroundStyle(.cyan)
                }
                HStack {
                    Text("Rhythm Consistency")
                    Spacer()
                    Text(String(format: "%.0f%%", rhythmConsistency))
                        .bold()
                }
            }
            .font(.subheadline)
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Text(gradeForScore(avgEfficiency))
                .font(.title2.bold())
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(avgEfficiency >= 70 ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                .foregroundStyle(avgEfficiency >= 70 ? .green : .orange)
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
                        .background(.cyan)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }

    private var currentFrequency: Double {
        motionAnalyzer.dominantFrequency
    }

    private var currentEfficiency: Double {
        let freqDiff = abs(currentFrequency - kickStyle.targetFrequency)
        let freqScore = max(0, 100 - freqDiff * 40)
        let consistencyScore = rhythmConsistency
        return (freqScore + consistencyScore) / 2
    }

    private var rhythmConsistency: Double {
        guard kickIntervals.count >= 2 else { return 100 }
        let mean = kickIntervals.reduce(0, +) / Double(kickIntervals.count)
        let variance = kickIntervals.map { pow($0 - mean, 2) }.reduce(0, +) / Double(kickIntervals.count)
        let stdDev = sqrt(variance)
        let cv = mean > 0 ? stdDev / mean : 1
        return max(0, 100 - cv * 200)
    }

    private var rhythmColor: Color {
        if currentEfficiency >= 80 { return .green }
        if currentEfficiency >= 60 { return .yellow }
        return .orange
    }

    private var rhythmFeedback: String {
        let freqDiff = currentFrequency - kickStyle.targetFrequency
        if abs(freqDiff) < 0.3 { return "Perfect rhythm!" }
        if freqDiff > 0.3 { return "Slow down slightly" }
        if freqDiff < -0.3 { return "Speed up kicks" }
        return "Keep kicking"
    }

    private func gradeForScore(_ score: Double) -> String {
        if score >= 90 { return "Propulsion Master!" }
        if score >= 80 { return "Efficient Kicker" }
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
        kickCount = 0
        kickIntervals = []
        efficiencyReadings = []
        lastKickTime = nil
        motionAnalyzer.reset()
        motionAnalyzer.startUpdates()

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            elapsedTime += 0.05

            // Detect kicks from accelerometer peaks
            let acceleration = abs(motionAnalyzer.pitch)
            if acceleration > 0.25 {
                let now = Date()
                if let lastTime = lastKickTime {
                    let interval = now.timeIntervalSince(lastTime)
                    if interval > 0.15 {  // Minimum time between kicks
                        kickCount += 1
                        kickIntervals.append(interval)
                        lastKickTime = now

                        // Haptic on kick detection
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                } else {
                    kickCount += 1
                    lastKickTime = now
                }
            }

            efficiencyReadings.append(currentEfficiency)

            cueSystem.processDrillState(
                score: currentEfficiency,
                stability: rhythmConsistency,
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

        let avgEfficiency = efficiencyReadings.isEmpty ? 0 : efficiencyReadings.reduce(0, +) / Double(efficiencyReadings.count)

        let session = UnifiedDrillSession(
            drillType: .kickEfficiency,
            duration: targetDuration,
            score: avgEfficiency,
            coordinationScore: avgEfficiency,
            rhythmScore: rhythmConsistency,
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
        kickCount = 0
        kickIntervals = []
        efficiencyReadings = []
        lastKickTime = nil
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

// MARK: - Wave Shape

struct WaveShape: Shape {
    var frequency: Double
    var amplitude: Double
    var phase: Double

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.height / 2
        let wavelength = rect.width / CGFloat(frequency)

        path.move(to: CGPoint(x: 0, y: midY))

        for x in stride(from: 0, through: rect.width, by: 2) {
            let relativeX = x / wavelength
            let y = midY + CGFloat(sin(Double(relativeX) * .pi * 2 + phase)) * rect.height * CGFloat(amplitude)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        return path
    }
}

#Preview {
    KickEfficiencyDrillView()
        .modelContainer(for: UnifiedDrillSession.self, inMemory: true)
}
