//
//  WatchDiagnosticsSettingsView.swift
//  TetraTrack
//
//  Watch connectivity diagnostics for debugging session data flow.
//

import SwiftUI
import WatchConnectivity

struct WatchDiagnosticsSettingsView: View {
    private let watchManager = WatchConnectivityManager.shared
    private let workoutService = WorkoutLifecycleService.shared

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }

    private var wcState: String {
        guard WCSession.isSupported() else { return "Not supported" }
        switch WCSession.default.activationState {
        case .activated: return "Activated"
        case .inactive: return "Inactive"
        case .notActivated: return "Not activated"
        @unknown default: return "Unknown"
        }
    }

    private var breadcrumbs: [String] {
        UserDefaults.standard.stringArray(forKey: "watchDiagnosticBreadcrumbs") ?? []
    }

    var body: some View {
        List {
            Section("iPhone App") {
                row("Build", appVersion)
            }

            Section("Watch Connectivity") {
                row("WCSession", wcState)
                row("Paired", watchManager.isPaired ? "Yes" : "No")
                row("App Installed", watchManager.isWatchAppInstalled ? "Yes" : "No")
                row("Reachable", watchManager.isReachable ? "Yes" : "No")
            }

            Section("Watch Data (Last Received)") {
                row("Heart Rate", "\(watchManager.lastReceivedHeartRate) bpm")
                row("HR Sequence", "\(watchManager.heartRateSequence)")
                row("Cadence", "\(watchManager.cadence) spm")
            }

            Section("Builder Stats (from Watch)") {
                row("Calories", String(format: "%.0f kcal", workoutService.liveActiveCalories))
                row("Distance", String(format: "%.0f m", workoutService.liveDistance))
                row("Steps", "\(workoutService.liveStepCount)")
                row("Stroke Count", "\(workoutService.liveSwimmingStrokeCount)")
            }

            Section("Running Metrics (from Watch)") {
                row("Speed", String(format: "%.2f m/s", workoutService.liveRunningSpeed))
                row("Power", String(format: "%.0f W", workoutService.liveRunningPower))
                row("Stride Length", String(format: "%.2f m", workoutService.liveRunningStrideLength))
                row("Ground Contact", String(format: "%.0f ms", workoutService.liveGroundContactTime))
                row("Vert. Oscillation", String(format: "%.1f cm", workoutService.liveVerticalOscillation))
            }

            Section("Workout State") {
                row("State", "\(workoutService.state)")
                row("iPhone HR", "\(workoutService.liveHeartRate) bpm")
            }

            if !breadcrumbs.isEmpty {
                Section("Watch Diagnostic Log") {
                    ForEach(breadcrumbs.reversed(), id: \.self) { crumb in
                        Text(crumb)
                            .font(.caption2)
                            .monospacedDigit()
                    }
                }
            }
        }
        .navigationTitle("Watch Diagnostics")
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
