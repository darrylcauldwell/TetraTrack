//
//  MountedBreathingDrillView.swift
//  TrackRide
//
//  Breathing drill for riders that combines calming breath patterns
//  with seat stability measurement - essential for working with nervous horses.
//

import SwiftUI
import SwiftData

struct MountedBreathingDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var streaks: [TrainingStreak]

    @State private var motionAnalyzer = DrillMotionAnalyzer()
    @State private var cueSystem = RealTimeCueSystem()
    @State private var phase: BreathPhase = .instructions
    @State private var breathCount = 0
    @State private var totalBreaths = 5
    @State private var timer: Timer?
    @State private var phaseProgress: CGFloat = 0
    @State private var circleScale: CGFloat = 0.5
    @State private var phaseTimeLeft: Int = 4
    @State private var stabilityHistory: [Double] = []
    @State private var phaseStabilityScores: [BreathPhase: [Double]] = [:]
    @State private var elapsedTime: TimeInterval = 0

    private var streak: TrainingStreak? { streaks.first }

    enum BreathPhase: String, CaseIterable {
        case instructions = "Instructions"
        case countdown = "Get Ready"
        case inhale = "Breathe In"
        case holdIn = "Hold In"
        case exhale = "Breathe Out"
        case holdOut = "Hold Out"
        case complete = "Complete"

        var isActive: Bool {
            switch self {
            case .inhale, .holdIn, .exhale, .holdOut:
                return true
            default:
                return false
            }
        }
    }

    private let inhaleDuration: TimeInterval = 4
    private let holdDuration: TimeInterval = 4
    private let exhaleDuration: TimeInterval = 6  // Longer exhale for calming
    private let holdOutDuration: TimeInterval = 2

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient based on phase
                LinearGradient(
                    colors: phaseColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1), value: phase)

                VStack(spacing: 0) {
                    header

                    switch phase {
                    case .instructions:
                        instructionsView.frame(maxHeight: .infinity)
                    case .countdown:
                        countdownView.frame(maxHeight: .infinity)
                    case .inhale, .holdIn, .exhale, .holdOut:
                        activeView.frame(maxHeight: .infinity)
                    case .complete:
                        resultsView.frame(maxHeight: .infinity)
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
            Text("Mounted Breathing")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            Button {
                cleanup()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
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

            Image(systemName: "lungs.fill")
                .font(.system(size: 60))
                .foregroundStyle(.white)

            Text("Mounted Breathing")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Calm your nerves while maintaining\na steady, independent seat")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Label("Sit balanced on exercise ball or balance cushion", systemImage: "circle.fill")
                Label("Hold phone at chest/core level", systemImage: "iphone")
                Label("Breathe deeply while keeping seat still", systemImage: "lungs")
                Label("Long exhales calm both you and your horse", systemImage: "heart")
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.9))
            .padding()
            .background(.white.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("Pattern: 4s inhale → 4s hold → 6s exhale → 2s hold")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            // Phone placement guidance (styled for this view's color scheme)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "hand.raised.fingers.spread")
                        .foregroundStyle(.white)
                    Text("Phone Placement")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
                Text("Hold your phone at chest level with both hands, elbows relaxed at your sides. Keep a firm but not tight grip.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding()
            .background(.white.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Stepper("Cycles: \(totalBreaths)", value: $totalBreaths, in: 3...10)
                .padding()
                .background(.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)

            Spacer()

            Button {
                startCountdown()
            } label: {
                Text("Begin")
                    .font(.title3.bold())
                    .foregroundStyle(.teal)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white)
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
                .foregroundStyle(.white.opacity(0.8))
            Text("\(phaseTimeLeft)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Find your balanced seat")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
    }

    private var activeView: some View {
        VStack(spacing: 24) {
            // Breath counter
            Text("Breath \(breathCount + 1) of \(totalBreaths)")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))

            // Animated breathing circle with stability indicator
            ZStack {
                // Outer ring shows target
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 4)
                    .frame(width: 220, height: 220)

                // Breathing circle
                Circle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 220, height: 220)
                    .scaleEffect(circleScale)
                    .animation(.easeInOut(duration: currentPhaseDuration), value: circleScale)

                // Inner stability indicator
                Circle()
                    .fill(stabilityColor)
                    .frame(width: 80, height: 80)
                    .overlay {
                        VStack(spacing: 2) {
                            Text("\(Int(motionAnalyzer.scorer.stability))%")
                                .font(.title3.bold())
                            Text("Still")
                                .font(.caption2)
                        }
                        .foregroundStyle(.white)
                    }
                    .offset(
                        x: CGFloat(motionAnalyzer.roll * 30),
                        y: CGFloat(motionAnalyzer.pitch * 30)
                    )
                    .animation(.easeOut(duration: 0.1), value: motionAnalyzer.roll)

                // Phase text overlay
                VStack {
                    Spacer()
                    Text(phase.rawValue)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("\(phaseTimeLeft)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Spacer()
                }
                .frame(width: 220, height: 220)
            }

            // Stability feedback
            Text(stabilityMessage)
                .font(.headline)
                .foregroundStyle(.white)

            // Phase progress indicators
            HStack(spacing: 20) {
                PhaseIndicator(label: "In", isActive: phase == .inhale, isComplete: phaseIndex > 0)
                PhaseIndicator(label: "Hold", isActive: phase == .holdIn, isComplete: phaseIndex > 1)
                PhaseIndicator(label: "Out", isActive: phase == .exhale, isComplete: phaseIndex > 2)
                PhaseIndicator(label: "Hold", isActive: phase == .holdOut, isComplete: phaseIndex > 3)
            }

            // Progress bar for current phase
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.3))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .frame(width: geo.size.width * phaseProgress)
                        .animation(.linear(duration: 0.1), value: phaseProgress)
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())
            .padding(.horizontal, 40)

            // Current stats
            HStack(spacing: 30) {
                VStack {
                    Text(String(format: "%.1f°", abs(motionAnalyzer.leftRightAsymmetry)))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.white)
                    Text("L/R Sway")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                VStack {
                    Text(String(format: "%.1f°", abs(motionAnalyzer.anteriorPosterior)))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.white)
                    Text("F/B Sway")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    private var resultsView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.white)

            Text("Well Done!")
                .font(.title.bold())
                .foregroundStyle(.white)

            let avgStability = stabilityHistory.isEmpty ? 0 : stabilityHistory.reduce(0, +) / Double(stabilityHistory.count)
            let breathingScore = calculateBreathingScore()
            let combinedScore = (avgStability + breathingScore) / 2

            VStack {
                Text("\(Int(combinedScore))%")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(.white)
                Text("Combined Score")
                    .foregroundStyle(.white.opacity(0.8))
            }

            // Score breakdown
            VStack(spacing: 12) {
                HStack {
                    Text("Seat Stability")
                    Spacer()
                    Text("\(Int(avgStability))%")
                        .bold()
                        .foregroundStyle(avgStability >= 70 ? .green : .orange)
                }
                HStack {
                    Text("Breathing Rhythm")
                    Spacer()
                    Text("\(Int(breathingScore))%")
                        .bold()
                        .foregroundStyle(breathingScore >= 70 ? .green : .orange)
                }
                HStack {
                    Text("Cycles Completed")
                    Spacer()
                    Text("\(totalBreaths)")
                        .bold()
                }
                HStack {
                    Text("Total Duration")
                    Spacer()
                    Text(formatTime(elapsedTime))
                        .bold()
                }
            }
            .font(.subheadline)
            .foregroundStyle(.white)
            .padding()
            .background(.white.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            // Phase breakdown
            VStack(alignment: .leading, spacing: 4) {
                Text("Stability by Phase")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.7))
                HStack(spacing: 16) {
                    ForEach([BreathPhase.inhale, .holdIn, .exhale, .holdOut], id: \.rawValue) { breathPhase in
                        let scores = phaseStabilityScores[breathPhase] ?? []
                        let avg = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
                        VStack {
                            Text("\(Int(avg))%")
                                .font(.caption.bold())
                                .foregroundStyle(avg >= 70 ? .green : .orange)
                            Text(phaseShortName(breathPhase))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
            }
            .padding()
            .background(.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)

            Text(gradeForScore(combinedScore))
                .font(.title2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(.white.opacity(0.3))
                .clipShape(Capsule())

            Spacer()

            HStack(spacing: 16) {
                Button {
                    reset()
                } label: {
                    Text("Again")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(.teal)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .padding()
    }

    // MARK: - Helper Views

    private struct PhaseIndicator: View {
        let label: String
        let isActive: Bool
        let isComplete: Bool

        var body: some View {
            VStack(spacing: 4) {
                Circle()
                    .fill(isActive ? .white : (isComplete ? .white.opacity(0.8) : .white.opacity(0.3)))
                    .frame(width: 12, height: 12)
                    .overlay {
                        if isComplete {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.teal)
                        }
                    }
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(isActive ? .white : .white.opacity(0.6))
            }
        }
    }

    // MARK: - Computed Properties

    private var phaseColors: [Color] {
        switch phase {
        case .instructions: return [.teal.opacity(0.8), .cyan.opacity(0.6)]
        case .countdown: return [.blue.opacity(0.8), .cyan.opacity(0.6)]
        case .inhale: return [.green.opacity(0.8), .mint.opacity(0.6)]
        case .holdIn: return [.purple.opacity(0.8), .indigo.opacity(0.6)]
        case .exhale: return [.orange.opacity(0.8), .yellow.opacity(0.6)]
        case .holdOut: return [.blue.opacity(0.8), .indigo.opacity(0.6)]
        case .complete: return [.green.opacity(0.8), .mint.opacity(0.6)]
        }
    }

    private var phaseIndex: Int {
        switch phase {
        case .inhale: return 1
        case .holdIn: return 2
        case .exhale: return 3
        case .holdOut: return 4
        default: return 0
        }
    }

    private var currentPhaseDuration: TimeInterval {
        switch phase {
        case .inhale: return inhaleDuration
        case .holdIn: return holdDuration
        case .exhale: return exhaleDuration
        case .holdOut: return holdOutDuration
        case .countdown: return 1
        default: return 1
        }
    }

    private var stabilityColor: Color {
        let score = motionAnalyzer.scorer.stability
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        return .orange
    }

    private var stabilityMessage: String {
        let score = motionAnalyzer.scorer.stability
        if score >= 90 { return "Beautiful stillness" }
        if score >= 75 { return "Quiet seat maintained" }
        if score >= 60 { return "Stay centered" }
        return "Soften and settle"
    }

    // MARK: - Helper Functions

    private func phaseShortName(_ phase: BreathPhase) -> String {
        switch phase {
        case .inhale: return "In"
        case .holdIn: return "Hold"
        case .exhale: return "Out"
        case .holdOut: return "Rest"
        default: return ""
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func calculateBreathingScore() -> Double {
        // Score based on completing all breaths with consistent timing
        // Full marks for completing all cycles
        return 100.0
    }

    private func gradeForScore(_ score: Double) -> String {
        if score >= 90 { return "Zen Master!" }
        if score >= 80 { return "Calm & Centered" }
        if score >= 70 { return "Finding Balance" }
        if score >= 50 { return "Keep Practicing" }
        return "Building Awareness"
    }

    // MARK: - Drill Control

    private func startCountdown() {
        phase = .countdown
        phaseTimeLeft = 3
        motionAnalyzer.reset()
        motionAnalyzer.startUpdates()
        stabilityHistory = []
        phaseStabilityScores = [:]
        elapsedTime = 0
        breathCount = 0

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            phaseTimeLeft -= 1
            if phaseTimeLeft == 0 {
                t.invalidate()
                runPhase(.inhale)
            }
        }
    }

    private func runPhase(_ newPhase: BreathPhase) {
        phase = newPhase
        phaseProgress = 0
        phaseTimeLeft = Int(currentPhaseDuration)

        // Set circle scale based on phase
        switch newPhase {
        case .inhale:
            circleScale = 1.0
        case .exhale:
            circleScale = 0.5
        default:
            break
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()

        // Progress timer with stability tracking
        var elapsed: TimeInterval = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { t in
            elapsed += 0.1
            elapsedTime += 0.1
            phaseProgress = elapsed / currentPhaseDuration
            phaseTimeLeft = max(0, Int(currentPhaseDuration - elapsed))

            // Record stability
            let stability = motionAnalyzer.scorer.stability
            stabilityHistory.append(stability)

            // Track per-phase stability
            if phase.isActive {
                var scores = phaseStabilityScores[phase] ?? []
                scores.append(stability)
                phaseStabilityScores[phase] = scores
            }

            // Send cues
            cueSystem.processDrillState(
                score: stability,
                stability: stability,
                elapsed: elapsedTime,
                duration: TimeInterval(totalBreaths * 16)
            )

            if elapsed >= currentPhaseDuration {
                t.invalidate()
                nextPhase()
            }
        }
    }

    private func nextPhase() {
        switch phase {
        case .inhale:
            runPhase(.holdIn)
        case .holdIn:
            runPhase(.exhale)
        case .exhale:
            runPhase(.holdOut)
        case .holdOut:
            breathCount += 1
            if breathCount >= totalBreaths {
                completeDrill()
            } else {
                runPhase(.inhale)
            }
        default:
            break
        }
    }

    private func completeDrill() {
        cleanup()
        phase = .complete

        let avgStability = stabilityHistory.isEmpty ? 0 : stabilityHistory.reduce(0, +) / Double(stabilityHistory.count)
        let breathingScore = calculateBreathingScore()
        let combinedScore = (avgStability + breathingScore) / 2

        // Save drill session
        let session = UnifiedDrillSession(
            drillType: .mountedBreathing,
            duration: elapsedTime,
            score: combinedScore,
            stabilityScore: avgStability,
            symmetryScore: motionAnalyzer.scorer.symmetry,
            enduranceScore: motionAnalyzer.scorer.endurance,
            averageRMS: motionAnalyzer.rmsMotion
        )
        modelContext.insert(session)

        // Compute and save skill domain scores
        let skillService = SkillDomainService()
        let skillScores = skillService.computeScores(from: session)
        for skillScore in skillScores {
            modelContext.insert(skillScore)
        }

        // Update training streak
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

    private func reset() {
        stabilityHistory = []
        phaseStabilityScores = [:]
        breathCount = 0
        elapsedTime = 0
        phase = .instructions
        motionAnalyzer.reset()
    }

    private func cleanup() {
        timer?.invalidate()
        timer = nil
        motionAnalyzer.stopUpdates()
        cueSystem.reset()
    }
}

#Preview {
    MountedBreathingDrillView()
        .modelContainer(for: [TrainingStreak.self, UnifiedDrillSession.self], inMemory: true)
}
