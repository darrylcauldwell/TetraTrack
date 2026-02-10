//
//  WatchHomeView.swift
//  TetraTrack Watch App
//
//  Summary dashboard view showing quick stats
//  Phase 2: Watch is companion-only (no session capture)
//

import SwiftUI

struct WatchHomeView: View {
    @Environment(WatchConnectivityService.self) private var connectivityService
    @State private var sessionStore = WatchSessionStore.shared

    var body: some View {
        Group {
            if connectivityService.hasActiveSession {
                // Full-screen active session view
                activeSessionFullScreen
            } else {
                // Normal summary view when idle
                VStack(spacing: 8) {
                    quickStatsSection
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Full Screen Active Session

    private var activeSessionFullScreen: some View {
        VStack(spacing: 6) {
            // Discipline and type header
            HStack {
                Image(systemName: activeDisciplineIcon)
                    .font(.title3)
                    .foregroundStyle(activeDisciplineColor)

                Text(connectivityService.rideType ?? "Training")
                    .font(.caption)
                    .fontWeight(.semibold)

                Spacer()

                // Live indicator
                Circle()
                    .fill(WatchAppColors.active)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 4)

            // Main time display - BIG
            Text(connectivityService.formattedDuration)
                .scaledFont(size: 44, weight: .bold, design: .monospaced, relativeTo: .largeTitle)
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)

            // Distance
            Text(connectivityService.formattedDistance)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(activeDisciplineColor)

            Divider()
                .padding(.vertical, 2)

            // Discipline-specific metrics
            fullScreenMetrics

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var fullScreenMetrics: some View {
        let rideType = (connectivityService.rideType ?? "").lowercased()

        if rideType.contains("cross") || rideType.contains("eventing") {
            crossCountryFullScreenMetrics
        } else if connectivityService.activeDiscipline == .riding {
            ridingFullScreenMetrics
        } else if connectivityService.activeDiscipline == .running {
            runningFullScreenMetrics
        } else {
            // Generic metrics
            genericFullScreenMetrics
        }
    }

    private var crossCountryFullScreenMetrics: some View {
        VStack(spacing: 8) {
            // Time comparison - most important for XC
            if connectivityService.optimalTime > 0 {
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("Optimal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatTime(connectivityService.optimalTime))
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                    }

                    let diff = connectivityService.timeDifference
                    VStack(spacing: 2) {
                        Text(diff <= 0 ? "AHEAD" : "BEHIND")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(diff <= 0 ? WatchAppColors.active : WatchAppColors.warning)
                        Text(formatTimeDiff(diff))
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(diff <= 0 ? WatchAppColors.active : WatchAppColors.warning)
                    }
                }
            }

            // Heart rate row
            if connectivityService.heartRate > 0 {
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                        Text("\(connectivityService.heartRate)")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }

                    if connectivityService.heartRateZone > 0 {
                        Text("Z\(connectivityService.heartRateZone)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(zoneColor(connectivityService.heartRateZone))
                    }
                }
            }
        }
    }

    private var ridingFullScreenMetrics: some View {
        VStack(spacing: 8) {
            // Gait and speed
            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("Gait")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(connectivityService.gait)
                        .font(.body)
                        .fontWeight(.semibold)
                }

                VStack(spacing: 2) {
                    Text("Speed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(connectivityService.formattedSpeed)
                        .font(.body)
                        .fontWeight(.medium)
                }
            }

            // Heart rate
            if connectivityService.heartRate > 0 {
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                        Text("\(connectivityService.heartRate)")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }

                    if connectivityService.heartRateZone > 0 {
                        Text("Z\(connectivityService.heartRateZone)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(zoneColor(connectivityService.heartRateZone))
                    }
                }
            }
        }
    }

    private var runningFullScreenMetrics: some View {
        VStack(spacing: 8) {
            // Pace
            VStack(spacing: 2) {
                Text("Pace")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(formatPace(connectivityService.speed))
                    .font(.title2)
                    .fontWeight(.bold)
            }

            // Heart rate
            if connectivityService.heartRate > 0 {
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                        Text("\(connectivityService.heartRate)")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }

                    if connectivityService.heartRateZone > 0 {
                        Text("Z\(connectivityService.heartRateZone)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(zoneColor(connectivityService.heartRateZone))
                    }
                }
            }
        }
    }

    private var genericFullScreenMetrics: some View {
        VStack(spacing: 8) {
            if connectivityService.heartRate > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    Text("\(connectivityService.heartRate)")
                        .font(.title2)
                        .fontWeight(.semibold)

                    if connectivityService.heartRateZone > 0 {
                        Text("Z\(connectivityService.heartRateZone)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(zoneColor(connectivityService.heartRateZone))
                    }
                }
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("TetraTrack")
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    Circle()
                        .fill(connectivityService.isReachable ? WatchAppColors.active : WatchAppColors.inactive)
                        .frame(width: 6, height: 6)
                    Text(connectivityService.isReachable ? "Connected" : "Not Connected")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

            }
            Spacer()

            // App icon
            Image(systemName: "figure.equestrian.sports")
                .font(.title3)
                .foregroundStyle(WatchAppColors.riding)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Quick Stats Section

    private var quickStatsSection: some View {
        VStack(spacing: 8) {
            Spacer()

            // Flame icon - large and vibrant
            Image(systemName: "flame.fill")
                .scaledFont(size: 44, relativeTo: .largeTitle)
                .foregroundStyle(streakColor)

            // Streak number - big and bold (combine local and synced)
            Text("\(combinedStreak)")
                .scaledFont(size: 56, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                .foregroundStyle(streakColor)

            // Label
            Text("Training Day Streak")
                .font(.callout)
                .fontWeight(.medium)
                .foregroundStyle(streakColor.opacity(0.8))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Combined streak from iPhone data and local pending sessions
    private var combinedStreak: Int {
        let syncedStreak = connectivityService.workload.consecutiveTrainingDays
        let localStreak = sessionStore.localStreakDays

        // If we have local sessions today, ensure streak is at least 1
        if sessionStore.hasSessionsToday {
            return max(syncedStreak, localStreak, 1)
        }

        // Otherwise take the higher of the two
        return max(syncedStreak, localStreak)
    }

    private func formatDurationShort(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private var streakColor: Color {
        let streak = combinedStreak
        if streak >= 5 { return WatchAppColors.running }  // Hot orange
        if streak >= 3 { return WatchAppColors.warning }  // Amber
        if streak >= 1 { return WatchAppColors.primary }  // Blue
        return WatchAppColors.running.opacity(0.7)  // Muted orange when 0
    }

    // MARK: - Active Session Card

    private var activeSessionCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Pulsing indicator
                Circle()
                    .fill(WatchAppColors.active)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(WatchAppColors.active.opacity(0.5), lineWidth: 2)
                            .scaleEffect(1.5)
                    )

                Text("Session Active")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(WatchAppColors.active)

                Spacer()
            }

            // Main metrics row
            HStack {
                // Discipline icon
                Image(systemName: activeDisciplineIcon)
                    .font(.title3)
                    .foregroundStyle(activeDisciplineColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(connectivityService.rideType ?? "Training")
                        .font(.caption)
                        .fontWeight(.medium)

                    Text(connectivityService.formattedDuration)
                        .font(.system(.headline, design: .monospaced))
                        .fontWeight(.bold)
                }

                Spacer()

                // Key metric
                VStack(alignment: .trailing, spacing: 2) {
                    Text(connectivityService.formattedDistance)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(activeDisciplineColor)
                    Text("Distance")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Discipline-specific metrics
            disciplineSpecificMetrics
        }
        .padding(10)
        .background(WatchAppColors.active.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Discipline-Specific Metrics

    @ViewBuilder
    private var disciplineSpecificMetrics: some View {
        let rideType = (connectivityService.rideType ?? "").lowercased()

        if rideType.contains("cross") || rideType.contains("eventing") {
            // Cross-Country: Show time comparison
            crossCountryMetrics
        } else if connectivityService.activeDiscipline == .riding {
            // Regular riding: Show gait and speed
            ridingMetrics
        } else if connectivityService.activeDiscipline == .running {
            // Running: Show pace and heart rate
            runningMetrics
        } else if connectivityService.activeDiscipline == .swimming {
            // Swimming: Show stroke count
            swimmingMetrics
        }
        // Shooting has its own dedicated view
    }

    private var crossCountryMetrics: some View {
        HStack(spacing: 12) {
            // Optimal time
            if connectivityService.optimalTime > 0 {
                VStack(spacing: 2) {
                    Text("Optimal")
                        .scaledFont(size: 9, relativeTo: .caption2)
                        .foregroundStyle(.secondary)
                    Text(formatTime(connectivityService.optimalTime))
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.medium)
                }
            }

            // Time difference (ahead/behind)
            let diff = connectivityService.timeDifference
            if diff != 0 || connectivityService.optimalTime > 0 {
                VStack(spacing: 2) {
                    Text(diff < 0 ? "Ahead" : "Behind")
                        .scaledFont(size: 9, relativeTo: .caption2)
                        .foregroundStyle(.secondary)
                    Text(formatTimeDiff(diff))
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundStyle(diff <= 0 ? WatchAppColors.active : WatchAppColors.warning)
                }
            }

            Spacer()

            // Heart rate
            if connectivityService.heartRate > 0 {
                VStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .scaledFont(size: 9, relativeTo: .caption2)
                        .foregroundStyle(.red)
                    Text("\(connectivityService.heartRate)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }

            // Heart rate zone
            if connectivityService.heartRateZone > 0 {
                VStack(spacing: 2) {
                    Text("Zone")
                        .scaledFont(size: 9, relativeTo: .caption2)
                        .foregroundStyle(.secondary)
                    Text("Z\(connectivityService.heartRateZone)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(zoneColor(connectivityService.heartRateZone))
                }
            }
        }
        .padding(.top, 4)
    }

    private var ridingMetrics: some View {
        HStack(spacing: 12) {
            // Current gait
            VStack(spacing: 2) {
                Text("Gait")
                    .scaledFont(size: 9, relativeTo: .caption2)
                    .foregroundStyle(.secondary)
                Text(connectivityService.gait)
                    .font(.caption)
                    .fontWeight(.medium)
            }

            // Speed
            VStack(spacing: 2) {
                Text("Speed")
                    .scaledFont(size: 9, relativeTo: .caption2)
                    .foregroundStyle(.secondary)
                Text(connectivityService.formattedSpeed)
                    .font(.caption)
                    .fontWeight(.medium)
            }

            Spacer()

            // Heart rate if available
            if connectivityService.heartRate > 0 {
                VStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .scaledFont(size: 9, relativeTo: .caption2)
                        .foregroundStyle(.red)
                    Text("\(connectivityService.heartRate)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }

            // Heart rate zone
            if connectivityService.heartRateZone > 0 {
                VStack(spacing: 2) {
                    Text("Zone")
                        .scaledFont(size: 9, relativeTo: .caption2)
                        .foregroundStyle(.secondary)
                    Text("Z\(connectivityService.heartRateZone)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(zoneColor(connectivityService.heartRateZone))
                }
            }
        }
        .padding(.top, 4)
    }

    private var runningMetrics: some View {
        HStack(spacing: 12) {
            // Pace (calculated from speed)
            VStack(spacing: 2) {
                Text("Pace")
                    .scaledFont(size: 9, relativeTo: .caption2)
                    .foregroundStyle(.secondary)
                Text(formatPace(connectivityService.speed))
                    .font(.caption)
                    .fontWeight(.medium)
            }

            // Heart rate
            if connectivityService.heartRate > 0 {
                VStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .scaledFont(size: 9, relativeTo: .caption2)
                        .foregroundStyle(.red)
                    Text("\(connectivityService.heartRate)")
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }

            Spacer()

            // Heart rate zone
            if connectivityService.heartRateZone > 0 {
                VStack(spacing: 2) {
                    Text("Zone")
                        .scaledFont(size: 9, relativeTo: .caption2)
                        .foregroundStyle(.secondary)
                    Text("Z\(connectivityService.heartRateZone)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(zoneColor(connectivityService.heartRateZone))
                }
            }
        }
        .padding(.top, 4)
    }

    private var swimmingMetrics: some View {
        HStack(spacing: 12) {
            // Duration is already shown
            // Show heart rate if available
            if connectivityService.heartRate > 0 {
                VStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .scaledFont(size: 9, relativeTo: .caption2)
                        .foregroundStyle(.red)
                    Text("\(connectivityService.heartRate)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }

            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - Formatting Helpers

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatTimeDiff(_ diff: TimeInterval) -> String {
        let absDiff = abs(diff)
        let sign = diff < 0 ? "-" : "+"
        if absDiff < 60 {
            return String(format: "%@%.0fs", sign, absDiff)
        } else {
            let minutes = Int(absDiff) / 60
            let seconds = Int(absDiff) % 60
            return String(format: "%@%d:%02d", sign, minutes, seconds)
        }
    }

    private func formatPace(_ speedMps: Double) -> String {
        guard speedMps > 0 else { return "--:--" }
        let paceSecondsPerKm = 1000.0 / speedMps
        let minutes = Int(paceSecondsPerKm) / 60
        let seconds = Int(paceSecondsPerKm) % 60
        return String(format: "%d:%02d/km", minutes, seconds)
    }

    private func zoneColor(_ zone: Int) -> Color {
        switch zone {
        case 1: return WatchAppColors.swimming
        case 2: return WatchAppColors.active
        case 3: return WatchAppColors.primary
        case 4: return WatchAppColors.warning
        case 5: return WatchAppColors.running
        default: return .primary
        }
    }

    private var activeDisciplineIcon: String {
        switch connectivityService.activeDiscipline {
        case .riding: return "figure.equestrian.sports"
        case .running: return "figure.run"
        case .swimming: return "figure.pool.swim"
        case .shooting: return "target"
        case .training: return "figure.mixed.cardio"
        case .idle: return "figure.stand"
        }
    }

    private var activeDisciplineColor: Color {
        switch connectivityService.activeDiscipline {
        case .riding: return WatchAppColors.riding
        case .running: return WatchAppColors.running
        case .swimming: return WatchAppColors.swimming
        case .shooting: return WatchAppColors.shooting
        case .training, .idle: return WatchAppColors.primary
        }
    }

    // MARK: - Navigation Hint

    private var navigationHint: some View {
        VStack(spacing: 4) {
            Image(systemName: "chevron.compact.down")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text("Swipe for more")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 8)
    }
}

// MARK: - Quick Stat Card

struct QuickStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(color)
            }

            Text(label)
                .scaledFont(size: 9, relativeTo: .caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(WatchAppColors.cardBackground.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Quick Stat Row (horizontal layout)

struct QuickStatRow: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(value)
                .font(.system(.headline, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(color)
                .frame(width: 36, alignment: .trailing)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(WatchAppColors.cardBackground.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Recommendation Summary Card

struct RecommendationSummaryCard: View {
    let recommendation: WorkloadData.WorkloadRecommendation

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)

            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            Spacer()

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var icon: String {
        switch recommendation {
        case .rest: return "bed.double.fill"
        case .light: return "leaf.fill"
        case .moderate: return "figure.walk"
        case .ready: return "bolt.fill"
        case .active: return "figure.run"
        }
    }

    private var color: Color {
        switch recommendation {
        case .rest: return WatchAppColors.swimming
        case .light: return WatchAppColors.active
        case .moderate: return WatchAppColors.primary
        case .ready: return WatchAppColors.warning
        case .active: return WatchAppColors.running
        }
    }

    private var title: String {
        switch recommendation {
        case .rest: return "Rest Day"
        case .light: return "Light Training"
        case .moderate: return "Moderate Day"
        case .ready: return "Ready to Train"
        case .active: return "Training Active"
        }
    }

    private var subtitle: String {
        switch recommendation {
        case .rest: return "Recover"
        case .light: return "Easy does it"
        case .moderate: return "Good to go"
        case .ready: return "Let's go!"
        case .active: return "In progress"
        }
    }
}

#Preview {
    WatchHomeView()
        .environment(WatchConnectivityService.shared)
}
