//
//  WatchStatusCard.swift
//  TetraTrack
//
//  Shared Watch connectivity status card used by riding drills and other views.
//

import SwiftUI

struct WatchStatusCard: View {
    var discipline: WatchDiscipline = .riding

    enum WatchDiscipline {
        case riding, shooting
    }

    private var watchConnectivity: WatchConnectivityManager { WatchConnectivityManager.shared }

    private var isConnected: Bool {
        watchConnectivity.isPaired && watchConnectivity.isWatchAppInstalled && watchConnectivity.isReachable
    }

    private var isAppNotInstalled: Bool {
        watchConnectivity.isPaired && !watchConnectivity.isWatchAppInstalled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "applewatch")
                    .font(.title3)
                    .foregroundStyle(isConnected ? AppColors.primary : .secondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Watch")
                        .font(.subheadline.weight(.semibold))
                    if isConnected {
                        AccessibleStatusIndicator(.connected, size: .small)
                    } else if isAppNotInstalled {
                        AccessibleStatusIndicator(.error, size: .small)
                    } else {
                        AccessibleStatusIndicator(.standby, size: .small)
                    }
                }

                Spacer()

                if isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.success)
                }
            }

            if isConnected {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Watch will record:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    switch discipline {
                    case .shooting:
                        WatchMetricRow(icon: "hand.raised.fill", text: "Stance stability & tremor", color: .purple)
                        WatchMetricRow(icon: "waveform.path", text: "Arm movement & drift", color: .orange)
                        WatchMetricRow(icon: "scope", text: "Shot detection & timing", color: .blue)
                        WatchMetricRow(icon: "heart.fill", text: "Heart rate & breathing", color: .red)
                        WatchMetricRow(icon: "figure.stand", text: "Posture & hold steadiness", color: .green)
                    case .riding:
                        WatchMetricRow(icon: "heart.fill", text: "Real-time heart rate", color: .red)
                        WatchMetricRow(icon: "figure.equestrian.sports", text: "Gait detection & rhythm", color: .orange)
                        WatchMetricRow(icon: "arrow.up.arrow.down", text: "Vertical oscillation", color: .cyan)
                        WatchMetricRow(icon: "figure.stand", text: "Posture & balance", color: .green)
                    }
                }
            } else if isAppNotInstalled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Install TetraTrack on your Apple Watch to unlock sensor tracking.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Open the Watch app on your iPhone to install.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Open TetraTrack on your Apple Watch before starting to record sensor data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct WatchMetricRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        Label {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
        }
    }
}
