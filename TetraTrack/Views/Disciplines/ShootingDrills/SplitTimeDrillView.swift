//
//  SplitTimeDrillView.swift
//  TetraTrack
//
//  Multi-target transition speed drill
//

import SwiftUI
import SwiftData
import CoreMotion
import Combine

struct SplitTimeDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var motionManager = SplitTimeMotionManager()
    @State private var isRunning = false
    @State private var currentTarget = 0
    @State private var totalTargets = 5
    @State private var targetPositions: [(x: Double, y: Double)] = []
    @State private var splitTimes: [TimeInterval] = []
    @State private var lastTransitionTime: Date?
    @State private var isOnTarget = false
    @State private var targetAcquiredTime: Date?
    @State private var stabilityAtTransitions: [Double] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppColors.shooting.opacity(Opacity.light).ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if !isRunning && splitTimes.isEmpty {
                        instructionsView
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
        }
        .onDisappear {
            motionManager.stopUpdates()
        }
    }

    private var header: some View {
        HStack {
            Text("Split Time")
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
                    .background(AppColors.cardBackground)
                    .clipShape(Circle())
            }
        }
        .padding()
    }

    private var instructionsView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "timer")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.warning)

            Text("Split Time Drill")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Label("Targets appear in sequence", systemImage: "1.circle.fill")
                Label("Acquire each target by aiming at it", systemImage: "scope")
                Label("Hold steady briefly to confirm", systemImage: "checkmark.circle")
                Label("Transition quickly to next target", systemImage: "arrow.right")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Stepper("Targets: \(totalTargets)", value: $totalTargets, in: 3...8)
                .padding()
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 32)

            Spacer()

            Button {
                startDrill()
            } label: {
                Text("Start")
                    .font(.title3.bold())
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.warning)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
        }
        .padding(.horizontal)
    }

    private var activeDrillView: some View {
        VStack(spacing: 16) {
            // Progress
            HStack {
                ForEach(0..<totalTargets, id: \.self) { index in
                    Circle()
                        .fill(targetIndicatorColor(for: index))
                        .frame(width: 16, height: 16)
                }
            }

            // Target area
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 280, height: 280)

                // All target positions (dimmed)
                ForEach(0..<totalTargets, id: \.self) { index in
                    if index != currentTarget {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                            .frame(width: 50, height: 50)
                            .offset(
                                x: CGFloat(targetPositions[safe: index]?.x ?? 0),
                                y: CGFloat(targetPositions[safe: index]?.y ?? 0)
                            )
                    }
                }

                // Current target
                if currentTarget < totalTargets, let pos = targetPositions[safe: currentTarget] {
                    ZStack {
                        Circle()
                            .fill(isOnTarget ? AppColors.active.opacity(0.3) : AppColors.warning.opacity(0.3))
                            .frame(width: 60, height: 60)

                        Circle()
                            .stroke(isOnTarget ? AppColors.active : AppColors.warning, lineWidth: 4)
                            .frame(width: 50, height: 50)

                        Text("\(currentTarget + 1)")
                            .font(.headline.bold())
                            .foregroundStyle(isOnTarget ? .green : .yellow)
                    }
                    .offset(x: CGFloat(pos.x), y: CGFloat(pos.y))
                }

                // Aim indicator
                Circle()
                    .fill(isOnTarget ? .green : .red)
                    .frame(width: 16, height: 16)
                    .offset(
                        x: CGFloat(motionManager.pitch * 140),
                        y: CGFloat(motionManager.roll * 140)
                    )
                    .animation(.easeOut(duration: 0.05), value: motionManager.pitch)

                // Crosshairs
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: 280)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 280, height: 1)
            }

            // Status
            Text(isOnTarget ? "HOLD..." : "Acquire Target \(currentTarget + 1)")
                .font(.title3.bold())
                .foregroundStyle(isOnTarget ? .green : .yellow)

            // Split times
            if !splitTimes.isEmpty {
                VStack(spacing: 4) {
                    Text("Split Times")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(splitTimes.indices, id: \.self) { index in
                            Text(String(format: "%.2fs", splitTimes[index]))
                                .font(.caption.monospacedDigit())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(splitTimeColor(splitTimes[index]).opacity(0.2))
                                .foregroundStyle(splitTimeColor(splitTimes[index]))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Stats
            HStack(spacing: 30) {
                VStack {
                    Text("\(currentTarget)/\(totalTargets)")
                        .font(.headline)
                    Text("Targets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !splitTimes.isEmpty {
                    VStack {
                        let avg = splitTimes.reduce(0, +) / Double(splitTimes.count)
                        Text(String(format: "%.2fs", avg))
                            .font(.headline)
                        Text("Avg Split")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var resultsView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "flag.checkered")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.warning)

            Text("Complete!")
                .font(.title.bold())

            let avgSplit = splitTimes.isEmpty ? 0 : splitTimes.reduce(0, +) / Double(splitTimes.count)
            let bestSplit = splitTimes.min() ?? 0

            VStack(spacing: 8) {
                Text(String(format: "%.2fs", avgSplit))
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(AppColors.warning)
                Text("Average Split Time")
                    .foregroundStyle(.secondary)
            }

            // Split time breakdown
            VStack(spacing: 8) {
                ForEach(splitTimes.indices, id: \.self) { index in
                    HStack {
                        Text("Target \(index + 1) → \(index + 2)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.3fs", splitTimes[index]))
                            .bold()
                            .foregroundStyle(splitTimeColor(splitTimes[index]))
                    }
                }
            }
            .font(.subheadline)
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            HStack(spacing: 24) {
                VStack {
                    Text(String(format: "%.3fs", bestSplit))
                        .font(.title3.bold())
                        .foregroundStyle(AppColors.active)
                    Text("Best")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    let totalTime = splitTimes.reduce(0, +)
                    Text(String(format: "%.2fs", totalTime))
                        .font(.title3.bold())
                    Text("Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            let score = max(0, min(100, (1.5 - avgSplit) / 1.5 * 100))
            Text(gradeForScore(score))
                .font(.title2.bold())
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(gradeColor(score).opacity(0.2))
                .foregroundStyle(gradeColor(score))
                .clipShape(Capsule())

            Spacer()

            HStack(spacing: 16) {
                Button {
                    splitTimes = []
                    currentTarget = 0
                } label: {
                    Text("Try Again")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.warning)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }

    private func targetIndicatorColor(for index: Int) -> Color {
        if index < currentTarget { return .green }
        if index == currentTarget { return .yellow }
        return .gray.opacity(0.3)
    }

    private func splitTimeColor(_ time: TimeInterval) -> Color {
        if time < 0.4 { return AppColors.active }
        if time < 0.7 { return AppColors.warning }
        return AppColors.running
    }

    private func gradeForScore(_ score: Double) -> String {
        if score >= 80 { return "Speed Demon!" }
        if score >= 60 { return "Quick Transitions" }
        if score >= 40 { return "Steady Progress" }
        return "Keep Practicing"
    }

    private func gradeColor(_ score: Double) -> Color {
        if score >= 70 { return AppColors.active }
        if score >= 50 { return AppColors.warning }
        return AppColors.running
    }

    private func startDrill() {
        isRunning = true
        currentTarget = 0
        splitTimes = []
        stabilityAtTransitions = []

        // Generate random target positions
        targetPositions = (0..<totalTargets).map { _ in
            (x: Double.random(in: -100...100), y: Double.random(in: -100...100))
        }

        motionManager.startUpdates()
        lastTransitionTime = Date()
        checkTargetAcquisition()
    }

    private func checkTargetAcquisition() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            guard isRunning, currentTarget < totalTargets else {
                timer.invalidate()
                return
            }

            guard let targetPos = targetPositions[safe: currentTarget] else { return }

            // Check if aim is on target
            let aimX = motionManager.pitch * 140
            let aimY = motionManager.roll * 140
            let distance = sqrt(pow(aimX - targetPos.x, 2) + pow(aimY - targetPos.y, 2))

            let wasOnTarget = isOnTarget
            isOnTarget = distance < 30  // Target radius

            if isOnTarget && !wasOnTarget {
                // Just acquired target
                targetAcquiredTime = Date()

                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }

            if isOnTarget, let acquiredTime = targetAcquiredTime {
                // Check if held on target long enough (0.2s)
                if Date().timeIntervalSince(acquiredTime) > 0.2 {
                    // Target confirmed!
                    if let lastTime = lastTransitionTime {
                        let splitTime = Date().timeIntervalSince(lastTime)
                        splitTimes.append(splitTime)
                    }

                    lastTransitionTime = Date()
                    currentTarget += 1

                    let successGenerator = UINotificationFeedbackGenerator()
                    successGenerator.notificationOccurred(.success)

                    if currentTarget >= totalTargets {
                        timer.invalidate()
                        endDrill()
                    }

                    targetAcquiredTime = nil
                }
            } else if !isOnTarget {
                targetAcquiredTime = nil
            }
        }
    }

    private func endDrill() {
        isRunning = false
        motionManager.stopUpdates()

        let avgSplit = splitTimes.isEmpty ? 1.0 : splitTimes.reduce(0, +) / Double(splitTimes.count)
        let score = max(0, min(100, (1.5 - avgSplit) / 1.5 * 100))

        // Save session
        let session = ShootingDrillSession(
            drillType: .splitTime,
            duration: splitTimes.reduce(0, +),
            score: score,
            stabilityScore: 0,
            transitionScore: score,
            averageSplitTime: avgSplit
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

// MARK: - Safe Array Access

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Split Time Motion Manager

@MainActor
class SplitTimeMotionManager: ObservableObject {
    private let motionManager = CMMotionManager()

    @Published var pitch: Double = 0
    @Published var roll: Double = 0

    private var referencePitch: Double?
    private var referenceRoll: Double?

    func startUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }

        referencePitch = nil
        referenceRoll = nil

        motionManager.deviceMotionUpdateInterval = 1/60
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, let self = self else { return }

            if self.referencePitch == nil {
                self.referencePitch = motion.attitude.pitch
                self.referenceRoll = motion.attitude.roll
            }

            self.pitch = motion.attitude.pitch - (self.referencePitch ?? 0)
            self.roll = motion.attitude.roll - (self.referenceRoll ?? 0)
        }
    }

    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}

#Preview {
    SplitTimeDrillView()
}
