//
//  WatchDiagnosticsView.swift
//  TetraTrack Watch App
//
//  Build version, WCSession status, and workout state diagnostics.
//

import SwiftUI
import WatchConnectivity

struct WatchDiagnosticsView: View {
    @Environment(WatchConnectivityService.self) private var connectivityService
    @State private var workoutManager = WorkoutManager.shared

    private var buildVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }

    private var wcSessionState: String {
        guard WCSession.isSupported() else { return "Not supported" }
        let session = WCSession.default
        switch session.activationState {
        case .activated: return "Activated"
        case .inactive: return "Inactive"
        case .notActivated: return "Not activated"
        @unknown default: return "Unknown"
        }
    }

    private var isReachable: Bool {
        WCSession.isSupported() && WCSession.default.isReachable
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Diagnostics")
                    .font(.headline)

                Group {
                    diagRow("Build", buildVersion)
                    diagRow("WCSession", wcSessionState)
                    diagRow("Reachable", isReachable ? "Yes" : "No")
                }

                Divider()

                Group {
                    diagRow("Workout", workoutManager.isWorkoutActive ? "Active" : "Idle")
                    diagRow("From iPhone", workoutManager.isMirroredFromiPhone ? "Yes" : "No")
                    diagRow("HR", "\(workoutManager.currentHeartRate) bpm")
                    diagRow("Tick", "\(workoutManager.motionSendTickCount)")
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private func diagRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption2)
                .monospacedDigit()
        }
    }
}
