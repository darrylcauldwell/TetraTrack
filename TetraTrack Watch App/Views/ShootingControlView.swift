//
//  ShootingControlView.swift
//  TetraTrack Watch App
//
//  Autonomous shooting session control for Apple Watch
//  Shows live steadiness gauge, shot count, HR, and mini-feedback
//

import SwiftUI
import WatchConnectivity
import TetraTrackShared
import os

struct ShootingControlView: View {
    @Environment(WatchConnectivityService.self) private var connectivityService
    @Environment(WorkoutManager.self) private var workoutManager
    @State private var shotDetector = ShootingShotDetector()
    @State private var lastShotDelta: Double?
    @State private var recentSteadiness: [Double] = []

    var body: some View {
        Group {
            if workoutManager.isWorkoutActive && workoutManager.activityType == .shooting {
                activeShootingView
            } else {
                startShootingView
            }
        }
        .onAppear {
            setupShotDetection()
        }
        .onDisappear {
            teardownShotDetection()
        }
    }

    // MARK: - Start Shooting View

    private var startShootingView: some View {
        VStack(spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 44))
                .foregroundStyle(WatchAppColors.shooting)
                .padding(.top, 8)

            if WatchSessionStore.shared.pendingCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "icloud.and.arrow.up")
                    Text("\(WatchSessionStore.shared.pendingCount) pending")
                }
                .font(.caption2)
                .foregroundStyle(.orange)
            }

            Spacer()

            Button {
                shotDetector.reset()
                recentSteadiness = []
                Task {
                    await workoutManager.startAutonomousShooting()
                }
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Shooting")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(WatchAppColors.shooting)
            .padding(.bottom, 8)
        }
        .padding(.horizontal)
    }

    // MARK: - Active Shooting View

    private var activeShootingView: some View {
        SessionPager(disciplineIcon: "target", disciplineColor: WatchAppColors.shooting, disciplineName: "Shooting") {
            VStack(spacing: 6) {
                // Hero: Steadiness + HR side by side
                HStack(spacing: 16) {
                    // Steadiness
                    VStack(spacing: 2) {
                        steadinessGauge
                        Text("steady")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    // Heart Rate
                    VStack(spacing: 2) {
                        Text("\(workoutManager.currentHeartRate)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.red)
                        Text("bpm")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider().padding(.vertical, 2)

                // Metrics row: shot count, delta, form trend
                HStack(spacing: 10) {
                    // Shot count
                    WatchMetricCell(
                        value: "\(shotDetector.shotCount)",
                        unit: "shots"
                    )

                    // Last shot delta
                    if let delta = lastShotDelta {
                        VStack(spacing: 2) {
                            HStack(spacing: 2) {
                                Image(systemName: delta >= 0 ? "arrow.up" : "arrow.down")
                                    .font(.caption2)
                                    .foregroundStyle(delta >= 0 ? .green : .orange)
                                Text(String(format: "%.0f", abs(delta)))
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(delta >= 0 ? .green : .orange)
                            }
                            Text("delta")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Form trend (3+ shots)
                    if shotDetector.shotCount >= 3 {
                        VStack(spacing: 2) {
                            Image(systemName: fatigueTrendIcon)
                                .font(.callout)
                                .foregroundStyle(fatigueTrendColor)
                            Text("form")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Timer
                Text(workoutManager.formattedElapsedTime)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    // MARK: - Steadiness Gauge

    private var steadinessGauge: some View {
        let steadiness = shotDetector.currentHoldSteadiness
        let color = steadinessColor(steadiness)

        return ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 5)
                .frame(width: 50, height: 50)
            Circle()
                .trim(from: 0, to: steadiness / 100.0)
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 50, height: 50)
            Text(String(format: "%.0f", steadiness))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    // MARK: - Fatigue Trend

    private var fatigueTrendIcon: String {
        guard recentSteadiness.count >= 3 else { return "arrow.right" }
        let mid = recentSteadiness.count / 2
        let firstAvg = recentSteadiness.prefix(mid).reduce(0, +) / Double(max(1, mid))
        let secondAvg = recentSteadiness.suffix(recentSteadiness.count - mid).reduce(0, +) / Double(max(1, recentSteadiness.count - mid))
        let delta = secondAvg - firstAvg
        if delta > 2 { return "arrow.up" }
        if delta < -2 { return "arrow.down" }
        return "arrow.right"
    }

    private var fatigueTrendColor: Color {
        guard recentSteadiness.count >= 3 else { return .primary }
        let mid = recentSteadiness.count / 2
        let firstAvg = recentSteadiness.prefix(mid).reduce(0, +) / Double(max(1, mid))
        let secondAvg = recentSteadiness.suffix(recentSteadiness.count - mid).reduce(0, +) / Double(max(1, recentSteadiness.count - mid))
        let delta = secondAvg - firstAvg
        if delta > 2 { return .green }
        if delta < -2 { return .orange }
        return .primary
    }

    private func steadinessColor(_ value: Double) -> Color {
        if value > 80 { return .green }
        if value > 60 { return .cyan }
        if value > 40 { return .orange }
        return .red
    }

    // MARK: - Shot Detection Setup

    private func setupShotDetection() {
        WatchMotionManager.shared.onMotionUpdate = { sample in
            shotDetector.processSample(sample)
        }

        workoutManager.onHeartRateUpdate = { hr in
            shotDetector.updateHeartRate(hr)
        }

        shotDetector.onShotDetected = { metrics in
            WKInterfaceDevice.current().play(.click)

            recentSteadiness.append(metrics.holdSteadiness)
            if recentSteadiness.count > 10 { recentSteadiness.removeFirst() }

            if let previous = shotDetector.lastShotMetrics,
               metrics.shotIndex > 1 {
                lastShotDelta = metrics.holdSteadiness - previous.holdSteadiness
            }

            // Accumulate for post-session transfer
            let dict = metrics.toDictionary()
            workoutManager.addShotMetrics(dict)

            // Also send real-time to iPhone if reachable (bonus live feedback)
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(dict, replyHandler: nil) { error in
                    Log.tracking.error("Failed to send shot metrics: \(error.localizedDescription)")
                }
            }
        }
    }

    private func teardownShotDetection() {
        WatchMotionManager.shared.onMotionUpdate = nil
        shotDetector.onShotDetected = nil
    }
}

#Preview {
    ShootingControlView()
        .environment(WatchConnectivityService.shared)
}
