//
//  ReactionDrillView.swift
//  TrackRide
//
//  Range commands drill with voice-guided target shooting practice
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Reaction Drill View

struct ReactionDrillView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var voiceManager = RangeOfficerVoice()
    @State private var phase: RangePhase = .idle
    @State private var currentRound = 0
    @State private var totalRounds = 10
    @State private var targetVisible = false
    @State private var targetAppearTime: Date?
    @State private var reactionTimes: [TimeInterval] = []
    @State private var hits = 0
    @State private var misses = 0

    enum RangePhase: String {
        case idle = "Ready to Begin"
        case load = "LOAD"
        case ready = "Are you ready?"
        case watch = "Watch and shoot!"
        case shoot = "SHOOT!"
        case hit = "HIT!"
        case miss = "MISS"
        case complete = "Session Complete"
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background changes with phase
                phaseBackground
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.3), value: phase)

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Range Commands")
                            .font(.headline)
                        Spacer()
                        Button {
                            voiceManager.stop()
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

                    // Content area - centered in remaining space
                    if phase == .idle {
                        instructionsView
                            .frame(maxHeight: .infinity)
                    } else if phase == .complete {
                        resultsView
                            .frame(maxHeight: .infinity)
                    } else {
                        shootingView
                            .frame(maxHeight: .infinity)
                    }
                }
            }
        }
        .onDisappear {
            voiceManager.stop()
        }
    }

    private var phaseBackground: some View {
        Group {
            switch phase {
            case .idle, .complete:
                Color.orange.opacity(0.1)
            case .load, .ready:
                Color.yellow.opacity(0.2)
            case .watch:
                Color.orange.opacity(0.3)
            case .shoot:
                Color.red.opacity(0.4)
            case .hit:
                Color.green.opacity(0.4)
            case .miss:
                Color.red.opacity(0.3)
            }
        }
    }

    private var instructionsView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

            Text("Range Commands")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                commandRow(command: "\"Load\"", description: "Get ready, stay safe")
                commandRow(command: "\"Are you ready?\"", description: "Final check")
                commandRow(command: "\"Watch and shoot\"", description: "Target appears - TAP!")
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text("Tap the target as fast as possible\nwhen it appears after the command!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                startSession()
            } label: {
                Text("Start Session")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
        }
        .padding(.horizontal)
    }

    private func commandRow(command: String, description: String) -> some View {
        HStack {
            Text(command)
                .font(.headline)
                .foregroundStyle(.orange)
                .frame(width: 160, alignment: .leading)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var shootingView: some View {
        VStack {
            // Stats bar
            HStack {
                VStack(alignment: .leading) {
                    Text("Round \(currentRound)/\(totalRounds)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        Label("\(hits)", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Label("\(misses)", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
                Spacer()
                if !reactionTimes.isEmpty {
                    let avg = reactionTimes.reduce(0, +) / Double(reactionTimes.count)
                    Text(String(format: "Avg: %.3fs", avg))
                        .font(.headline)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal)

            Spacer()

            // Command display
            Text(phase.rawValue)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(phase == .shoot ? .red : .primary)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.2), value: phase)

            Spacer()

            // Target area
            ZStack {
                // Target background
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    .frame(width: 200, height: 200)

                if targetVisible {
                    // Active target - tap to hit
                    Button {
                        hitTarget()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 180, height: 180)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 140, height: 140)
                            Circle()
                                .fill(Color.red)
                                .frame(width: 100, height: 100)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 60, height: 60)
                            Circle()
                                .fill(Color.black)
                                .frame(width: 20, height: 20)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 250)

            Spacer()

            // Last reaction time
            if let lastTime = reactionTimes.last {
                Text(String(format: "Last: %.3fs", lastTime))
                    .font(.title3.bold())
                    .monospacedDigit()
                    .foregroundStyle(lastTime < 0.3 ? .green : (lastTime < 0.5 ? .orange : .red))
            }

            Spacer()
        }
        // Tap anywhere as miss if target is showing
        .contentShape(Rectangle())
        .onTapGesture {
            if targetVisible {
                // Missed the target
                missTarget()
            }
        }
    }

    private var resultsView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "flag.checkered")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

            Text("Session Complete!")
                .font(.title.bold())

            VStack(spacing: 16) {
                HStack(spacing: 32) {
                    VStack {
                        Text("\(hits)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.green)
                        Text("Hits")
                            .foregroundStyle(.secondary)
                    }
                    VStack {
                        Text("\(misses)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.red)
                        Text("Misses")
                            .foregroundStyle(.secondary)
                    }
                }

                if !reactionTimes.isEmpty {
                    Divider()
                    let avgReaction = reactionTimes.reduce(0, +) / Double(reactionTimes.count)
                    let bestReaction = reactionTimes.min() ?? 0
                    VStack(spacing: 8) {
                        Text(String(format: "Average: %.3fs", avgReaction))
                            .font(.headline)
                        Text(String(format: "Best: %.3fs", bestReaction))
                            .font(.headline)
                            .foregroundStyle(.green)
                    }
                }

                // Rating
                let accuracy = hits + misses > 0 ? Double(hits) / Double(hits + misses) : 0
                Text(accuracyRating(accuracy))
                    .font(.title2.bold())
                    .foregroundStyle(.orange)
                    .padding(.top)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer()

            HStack(spacing: 16) {
                Button {
                    resetSession()
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
                        .background(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }

    private func accuracyRating(_ accuracy: Double) -> String {
        switch accuracy {
        case 0.9...1.0: return "Excellent Shooter!"
        case 0.7..<0.9: return "Good Shooting!"
        case 0.5..<0.7: return "Keep Practicing"
        default: return "Needs Work"
        }
    }

    private func startSession() {
        currentRound = 0
        hits = 0
        misses = 0
        reactionTimes = []
        startNextRound()
    }

    private func startNextRound() {
        currentRound += 1

        if currentRound > totalRounds {
            phase = .complete
            voiceManager.speak("Session complete. Well done.")
            return
        }

        // Load command
        phase = .load
        voiceManager.speak("Load") {
            // Random delay before ready
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 1.5...2.5)) {
                self.askReady()
            }
        }
    }

    private func askReady() {
        phase = .ready
        voiceManager.speak("Are you ready?") {
            // Random delay before watch and shoot
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 1.0...3.0)) {
                self.watchAndShoot()
            }
        }
    }

    private func watchAndShoot() {
        phase = .watch
        voiceManager.speak("Watch and shoot") {
            // Random delay before target appears
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.3...1.5)) {
                self.showTarget()
            }
        }
    }

    private func showTarget() {
        phase = .shoot
        targetAppearTime = Date()

        withAnimation(.spring(response: 0.2)) {
            targetVisible = true
        }

        // Auto-miss after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.targetVisible {
                self.missTarget()
            }
        }
    }

    private func hitTarget() {
        guard targetVisible, let appearTime = targetAppearTime else { return }

        let reactionTime = Date().timeIntervalSince(appearTime)
        reactionTimes.append(reactionTime)
        hits += 1

        withAnimation {
            targetVisible = false
        }

        phase = .hit
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        voiceManager.speak(String(format: "%.2f seconds", reactionTime)) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startNextRound()
            }
        }
    }

    private func missTarget() {
        guard targetVisible else { return }

        misses += 1

        withAnimation {
            targetVisible = false
        }

        phase = .miss
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)

        voiceManager.speak("Miss") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startNextRound()
            }
        }
    }

    private func resetSession() {
        phase = .idle
        currentRound = 0
        hits = 0
        misses = 0
        reactionTimes = []
        targetVisible = false
    }
}

// MARK: - Range Officer Voice

class RangeOfficerVoice: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String, completion: (() -> Void)? = nil) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        utterance.pitchMultiplier = 0.9
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")

        if let completion = completion {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(text.count) * 0.08 + 0.5) {
                completion()
            }
        }

        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

// MARK: - Reaction Target

struct ReactionTarget: Identifiable {
    let id = UUID()
    let position: CGPoint
    let size: CGFloat
    let color: Color
    let spawnTime: Date
}
