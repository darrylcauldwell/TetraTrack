//
//  SteadyHoldDrillView.swift
//  TrackRide
//
//  Steady hold drill using device motion sensors for aiming stability practice
//

import SwiftUI
import CoreMotion
import Combine

// MARK: - Steady Hold Drill View

struct SteadyHoldDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var motionManager = SteadyHoldMotionManager()

    @State private var isRunning = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var targetDuration: TimeInterval = 10
    @State private var timer: Timer?
    @State private var wobbleHistory: [Double] = []
    @State private var bestScore: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.cyan.opacity(0.1).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Steady Hold")
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

                    // Content area - centered in remaining space
                    if !isRunning && wobbleHistory.isEmpty {
                        instructionsView
                            .frame(maxHeight: .infinity)
                    } else if isRunning {
                        activeView
                            .frame(maxHeight: .infinity)
                    } else {
                        resultsView
                            .frame(maxHeight: .infinity)
                    }
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
            motionManager.stopUpdates()
        }
    }

    private var instructionsView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "scope")
                .font(.system(size: 60))
                .foregroundStyle(.cyan)

            Text("Steady Hold Drill")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("Hold phone like you're aiming", systemImage: "iphone")
                Label("Keep crosshairs centered", systemImage: "scope")
                Label("Minimize all movement", systemImage: "hand.raised")
                Label("Practice your trigger squeeze", systemImage: "hand.point.up")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Picker("Duration", selection: $targetDuration) {
                Text("5s").tag(TimeInterval(5))
                Text("10s").tag(TimeInterval(10))
                Text("15s").tag(TimeInterval(15))
                Text("20s").tag(TimeInterval(20))
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 32)

            Spacer()

            Button {
                startDrill()
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

    private var activeView: some View {
        VStack(spacing: 24) {
            // Timer
            Text(String(format: "%.1f", targetDuration - elapsedTime))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()

            // Scope view with moving crosshair
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: 250, height: 250)

                // Score rings
                ForEach([0.2, 0.4, 0.6, 0.8, 1.0], id: \.self) { scale in
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        .frame(width: 250 * scale, height: 250 * scale)
                }

                // Crosshairs (fixed)
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 1, height: 250)
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 250, height: 1)

                // Moving dot (represents wobble)
                Circle()
                    .fill(wobbleColor)
                    .frame(width: 20, height: 20)
                    .offset(
                        x: CGFloat(motionManager.pitch * 100),
                        y: CGFloat(motionManager.roll * 100)
                    )
                    .animation(.easeOut(duration: 0.05), value: motionManager.pitch)

                // Center target
                Circle()
                    .fill(.cyan)
                    .frame(width: 10, height: 10)
            }

            // Wobble meter
            VStack(spacing: 4) {
                Text("Wobble")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                        Rectangle()
                            .fill(wobbleColor)
                            .frame(width: geo.size.width * (1 - min(motionManager.wobble, 1)))
                    }
                }
                .frame(height: 20)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 40)

            Text(wobbleMessage)
                .font(.headline)
                .foregroundStyle(wobbleColor)
        }
    }

    private var resultsView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Complete!")
                .font(.title.bold())

            let avgWobble = wobbleHistory.reduce(0, +) / Double(wobbleHistory.count)
            let steadyScore = max(0, 100 - Int(avgWobble * 200))

            VStack {
                Text("\(steadyScore)")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(.cyan)
                Text("Steadiness Score")
                    .foregroundStyle(.secondary)
            }

            Text(gradeForScore(steadyScore))
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(gradeColor(steadyScore).opacity(0.2))
                .foregroundStyle(gradeColor(steadyScore))
                .clipShape(Capsule())

            Spacer()

            HStack(spacing: 16) {
                Button {
                    wobbleHistory = []
                    elapsedTime = 0
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

    private var wobbleColor: Color {
        if motionManager.wobble < 0.1 { return .green }
        if motionManager.wobble < 0.3 { return .yellow }
        return .red
    }

    private var wobbleMessage: String {
        if motionManager.wobble < 0.05 { return "Perfect!" }
        if motionManager.wobble < 0.1 { return "Excellent hold" }
        if motionManager.wobble < 0.2 { return "Good stability" }
        if motionManager.wobble < 0.3 { return "Some movement" }
        return "Hold steady!"
    }

    private func gradeForScore(_ score: Int) -> String {
        if score >= 90 { return "Sniper Grade" }
        if score >= 80 { return "Expert" }
        if score >= 70 { return "Proficient" }
        if score >= 50 { return "Developing" }
        return "Keep Practicing"
    }

    private func gradeColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        return .orange
    }

    private func startDrill() {
        isRunning = true
        elapsedTime = 0
        wobbleHistory = []
        motionManager.startUpdates()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsedTime += 0.1
            wobbleHistory.append(motionManager.wobble)

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

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - Steady Hold Motion Manager

class SteadyHoldMotionManager: ObservableObject {
    private let motionManager = CMMotionManager()

    @Published var pitch: Double = 0
    @Published var roll: Double = 0
    @Published var wobble: Double = 0

    private var referencePitch: Double?
    private var referenceRoll: Double?

    func startUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }

        referencePitch = nil
        referenceRoll = nil

        motionManager.deviceMotionUpdateInterval = 1/60
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, let self = self else { return }

            // Set reference point on first reading
            if self.referencePitch == nil {
                self.referencePitch = motion.attitude.pitch
                self.referenceRoll = motion.attitude.roll
            }

            // Calculate deviation from reference
            self.pitch = motion.attitude.pitch - (self.referencePitch ?? 0)
            self.roll = motion.attitude.roll - (self.referenceRoll ?? 0)

            // Calculate total wobble
            self.wobble = sqrt(self.pitch * self.pitch + self.roll * self.roll)
        }
    }

    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}
