//
//  BreathingDrillView.swift
//  TrackRide
//
//  Box breathing drill for calming nerves and steadying aim
//

import SwiftUI

// MARK: - Breathing Drill View

struct BreathingDrillView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var phase: BreathPhase = .ready
    @State private var breathCount = 0
    @State private var totalBreaths = 5
    @State private var timer: Timer?
    @State private var phaseProgress: CGFloat = 0
    @State private var circleScale: CGFloat = 0.5
    @State private var phaseTimeLeft: Int = 4

    enum BreathPhase: String {
        case ready = "Ready"
        case inhale = "Breathe In"
        case hold1 = "Hold..."
        case exhale = "Breathe Out"
        case hold2 = "Hold"
        case complete = "Complete"
    }

    private let inhaleDuration: TimeInterval = 4
    private let holdDuration: TimeInterval = 4
    private let exhaleDuration: TimeInterval = 4

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
                    // Header
                    HStack {
                        Text("Box Breathing")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            timer?.invalidate()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    .padding()

                    // Content area - centered in remaining space
                    if phase == .ready {
                        readyView
                            .frame(maxHeight: .infinity)
                    } else if phase == .complete {
                        completeView
                            .frame(maxHeight: .infinity)
                    } else {
                        activeView
                            .frame(maxHeight: .infinity)
                    }
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private var readyView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "wind")
                .font(.system(size: 60))
                .foregroundStyle(.white)

            Text("Box Breathing")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Used by Navy SEALs and marksmen\nto calm nerves and steady aim")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Circle().fill(.white).frame(width: 6, height: 6)
                    Text("Inhale for 4 seconds")
                }
                HStack {
                    Circle().fill(.white).frame(width: 6, height: 6)
                    Text("Hold for 4 seconds")
                }
                HStack {
                    Circle().fill(.white).frame(width: 6, height: 6)
                    Text("Exhale for 4 seconds")
                }
                HStack {
                    Circle().fill(.white).frame(width: 6, height: 6)
                    Text("Hold for 4 seconds")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.9))
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
                startBreathing()
            } label: {
                Text("Begin")
                    .font(.title3.bold())
                    .foregroundStyle(.blue)
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

    private var activeView: some View {
        VStack(spacing: 32) {
            // Breath counter
            Text("Breath \(breathCount + 1) of \(totalBreaths)")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))

            // Animated circle
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 4)
                    .frame(width: 250, height: 250)

                Circle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 250, height: 250)
                    .scaleEffect(circleScale)
                    .animation(.easeInOut(duration: currentPhaseDuration), value: circleScale)

                VStack {
                    Text(phase.rawValue)
                        .font(.title.bold())
                    Text(phaseTimeRemaining)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(.white)
            }

            // Progress bar
            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(.white.opacity(0.3))
                        Rectangle()
                            .fill(.white)
                            .frame(width: geo.size.width * phaseProgress)
                            .animation(.linear(duration: 0.1), value: phaseProgress)
                    }
                }
                .frame(height: 8)
                .clipShape(Capsule())

                HStack {
                    ForEach(0..<4) { i in
                        Circle()
                            .fill(phaseIndex > i ? .white : .white.opacity(0.3))
                            .frame(width: 12, height: 12)
                        if i < 3 { Spacer() }
                    }
                }
            }
            .padding(.horizontal, 40)
        }
    }

    private var completeView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.white)

            Text("Well Done!")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text("You completed \(totalBreaths) breathing cycles")
                .foregroundStyle(.white.opacity(0.8))

            Text("Your heart rate and nerves should be calmer.\nYou're ready to shoot!")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button {
                    phase = .ready
                    breathCount = 0
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
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }

    private var phaseColors: [Color] {
        switch phase {
        case .ready: return [.blue.opacity(0.8), .cyan.opacity(0.6)]
        case .inhale: return [.green.opacity(0.8), .mint.opacity(0.6)]
        case .hold1, .hold2: return [.purple.opacity(0.8), .indigo.opacity(0.6)]
        case .exhale: return [.orange.opacity(0.8), .yellow.opacity(0.6)]
        case .complete: return [.green.opacity(0.8), .mint.opacity(0.6)]
        }
    }

    private var phaseIndex: Int {
        switch phase {
        case .inhale: return 1
        case .hold1: return 2
        case .exhale: return 3
        case .hold2: return 4
        default: return 0
        }
    }

    private var currentPhaseDuration: TimeInterval {
        switch phase {
        case .inhale, .exhale: return 4
        case .hold1, .hold2: return 4
        default: return 1
        }
    }

    private var phaseTimeRemaining: String {
        "\(phaseTimeLeft)"
    }

    private func startBreathing() {
        breathCount = 0
        runPhase(.inhale)
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

        // Progress timer
        var elapsed: TimeInterval = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { t in
            elapsed += 0.1
            phaseProgress = elapsed / currentPhaseDuration
            phaseTimeLeft = Int(currentPhaseDuration - elapsed) + 1

            if elapsed >= currentPhaseDuration {
                t.invalidate()
                nextPhase()
            }
        }
    }

    private func nextPhase() {
        switch phase {
        case .inhale:
            runPhase(.hold1)
        case .hold1:
            runPhase(.exhale)
        case .exhale:
            runPhase(.hold2)
        case .hold2:
            breathCount += 1
            if breathCount >= totalBreaths {
                phase = .complete
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            } else {
                runPhase(.inhale)
            }
        default:
            break
        }
    }
}
