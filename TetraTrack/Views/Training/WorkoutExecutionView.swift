//
//  WorkoutExecutionView.swift
//  TetraTrack
//
//  Execute a structured workout with audio cues
//

import SwiftUI

struct WorkoutExecutionView: View {
    @Environment(\.dismiss) private var dismiss
    let template: WorkoutTemplate

    @State private var currentBlockIndex: Int = 0
    @State private var remainingSeconds: Int = 0
    @State private var isPaused: Bool = false
    @State private var isComplete: Bool = false
    @State private var timer: Timer?
    @State private var totalElapsed: TimeInterval = 0
    @State private var elapsedTimer: Timer?

    private let audioCoach = AudioCoachManager.shared

    var currentBlock: WorkoutBlock? {
        guard currentBlockIndex < template.sortedBlocks.count else { return nil }
        return template.sortedBlocks[currentBlockIndex]
    }

    var body: some View {
        ZStack {
            // Background color based on current block intensity
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Text(template.name)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Spacer()

                    // Placeholder for symmetry
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundStyle(.clear)
                }
                .padding()

                Spacer()

                if isComplete {
                    // Completion view
                    VStack(spacing: 24) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.white)

                        Text("Workout Complete!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Text("Total time: \(formattedTotalElapsed)")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.8))

                        Button(action: { dismiss() }) {
                            Text("Done")
                                .font(.headline)
                                .foregroundStyle(backgroundColor)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 12)
                                .background(.white)
                                .clipShape(Capsule())
                        }
                        .padding(.top)
                    }
                } else if let block = currentBlock {
                    // Current interval display
                    VStack(spacing: 8) {
                        // Progress indicator
                        HStack(spacing: 4) {
                            ForEach(0..<template.sortedBlocks.count, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(index < currentBlockIndex ? .white : (index == currentBlockIndex ? .white.opacity(0.8) : .white.opacity(0.3)))
                                    .frame(height: 4)
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 20)

                        // Interval number
                        Text("Interval \(currentBlockIndex + 1) of \(template.sortedBlocks.count)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))

                        // Block name
                        Text(block.name.isEmpty ? "Interval" : block.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        // Target gait
                        if let gait = block.targetGait {
                            Text(gait.rawValue.uppercased())
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(.top, 4)
                        }

                        // Intensity
                        Text(block.intensity.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.2))
                            .clipShape(Capsule())
                            .padding(.top, 8)
                    }

                    Spacer()

                    // Timer display
                    VStack(spacing: 8) {
                        Text(formattedRemaining)
                            .scaledFont(size: 100, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                            .foregroundStyle(.white)
                            .monospacedDigit()

                        // Next up preview
                        if currentBlockIndex + 1 < template.sortedBlocks.count {
                            let nextBlock = template.sortedBlocks[currentBlockIndex + 1]
                            Text("Next: \(nextBlock.name.isEmpty ? "Interval" : nextBlock.name)")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }

                    Spacer()

                    // Controls
                    HStack(spacing: 40) {
                        // Previous
                        Button(action: previousBlock) {
                            Image(systemName: "backward.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                                .frame(width: 60, height: 60)
                                .background(.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                        .disabled(currentBlockIndex == 0)
                        .opacity(currentBlockIndex == 0 ? 0.5 : 1)

                        // Play/Pause
                        Button(action: togglePause) {
                            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                                .font(.largeTitle)
                                .foregroundStyle(backgroundColor)
                                .frame(width: 80, height: 80)
                                .background(.white)
                                .clipShape(Circle())
                        }

                        // Skip
                        Button(action: nextBlock) {
                            Image(systemName: "forward.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                                .frame(width: 60, height: 60)
                                .background(.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.bottom, 40)
                }

                Spacer()
            }
        }
        .onAppear {
            startWorkout()
        }
        .onDisappear {
            stopTimers()
        }
    }

    private var backgroundColor: Color {
        guard let block = currentBlock else { return .green }

        switch block.intensity {
        case .recovery: return .green
        case .easy: return .blue
        case .moderate: return .orange
        case .hard: return .red
        case .maximum: return .purple
        }
    }

    private var formattedRemaining: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var formattedTotalElapsed: String {
        let minutes = Int(totalElapsed) / 60
        let seconds = Int(totalElapsed) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startWorkout() {
        currentBlockIndex = 0
        totalElapsed = 0
        isComplete = false
        isPaused = false

        startCurrentBlock()
        startElapsedTimer()
    }

    private func startCurrentBlock() {
        guard let block = currentBlock else {
            completeWorkout()
            return
        }

        remainingSeconds = block.durationSeconds

        // Audio announcement
        audioCoach.announceWorkoutBlock(
            name: block.name.isEmpty ? "Interval \(currentBlockIndex + 1)" : block.name,
            duration: TimeInterval(block.durationSeconds),
            gait: block.targetGait
        )

        startTimer()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard !isPaused else { return }

            remainingSeconds -= 1

            // Countdown announcements
            audioCoach.announceCountdown(remainingSeconds)

            if remainingSeconds <= 0 {
                nextBlock()
            }
        }
    }

    private func startElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard !isPaused else { return }
            totalElapsed += 1
        }
    }

    private func stopTimers() {
        timer?.invalidate()
        timer = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    private func togglePause() {
        isPaused.toggle()
        if isPaused {
            audioCoach.announce("Paused")
        } else {
            audioCoach.announce("Resuming")
        }
    }

    private func nextBlock() {
        currentBlockIndex += 1
        if currentBlockIndex >= template.sortedBlocks.count {
            completeWorkout()
        } else {
            startCurrentBlock()
        }
    }

    private func previousBlock() {
        guard currentBlockIndex > 0 else { return }
        currentBlockIndex -= 1
        startCurrentBlock()
    }

    private func completeWorkout() {
        stopTimers()
        isComplete = true
        audioCoach.announceWorkoutComplete()
    }
}

#Preview {
    let template = WorkoutTemplate(name: "Test Workout", description: "A test workout")
    template.addBlock(WorkoutBlock(name: "Warm-up", durationSeconds: 10, targetGait: .walk, intensity: .easy))
    template.addBlock(WorkoutBlock(name: "Work", durationSeconds: 10, targetGait: .trot, intensity: .moderate))
    template.addBlock(WorkoutBlock(name: "Cool-down", durationSeconds: 10, targetGait: .walk, intensity: .recovery))

    return WorkoutExecutionView(template: template)
}
