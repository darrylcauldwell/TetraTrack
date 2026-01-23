//
//  WatchInsightsView.swift
//  TrackRide Watch App
//
//  Glanceable insights view showing recent training summaries
//  Part of Phase 2: Watch app as companion-only dashboard
//

import SwiftUI

/// Represents a training session summary received from iPhone
struct TrainingSessionSummary: Identifiable, Codable {
    let id: UUID
    let discipline: String  // "riding", "running", "swimming", "shooting"
    let date: Date
    let duration: TimeInterval
    let keyMetric: String   // e.g., "5.2 km" or "32 strokes/min"
    let keyMetricLabel: String  // e.g., "Distance" or "Stroke Rate"
}

struct WatchInsightsView: View {
    @Environment(WatchConnectivityService.self) private var connectivityService
    @State private var sessionStore = WatchSessionStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("Recent Training")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 4)

                if allSessions.isEmpty {
                    emptyStateView
                } else {
                    // Show pending local sessions first
                    ForEach(sessionStore.pendingSessions.sorted(by: { $0.startDate > $1.startDate }).prefix(5)) { session in
                        LocalSessionCard(session: session)
                    }

                    // Then synced sessions from iPhone
                    ForEach(connectivityService.recentSessions.prefix(5)) { session in
                        SessionSummaryCard(session: session)
                    }
                }

                // Connection status
                connectionStatusView
                    .padding(.top, 8)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    /// Combined count of all sessions
    private var allSessions: [Any] {
        let local = sessionStore.pendingSessions as [Any]
        let synced = connectivityService.recentSessions as [Any]
        return local + synced
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundStyle(WatchAppColors.primary)

            Text("No Recent Sessions")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("Start training from your iPhone to see summaries here")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Connection Status

    private var connectionStatusView: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connectivityService.isReachable ? WatchAppColors.active : WatchAppColors.inactive)
                .frame(width: 8, height: 8)

            Text(connectivityService.isReachable ? "iPhone Connected" : "iPhone Not Connected")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Session Summary Card

struct SessionSummaryCard: View {
    let session: TrainingSessionSummary

    var body: some View {
        HStack(spacing: 10) {
            // Discipline icon
            ZStack {
                Circle()
                    .fill(disciplineColor.opacity(0.2))
                    .frame(width: 32, height: 32)

                Image(systemName: disciplineIcon)
                    .font(.body)
                    .foregroundStyle(disciplineColor)
            }

            // Session details
            VStack(alignment: .leading, spacing: 2) {
                Text(session.discipline.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text(formattedDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Key metric
            VStack(alignment: .trailing, spacing: 2) {
                Text(session.keyMetric)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(disciplineColor)

                Text(formattedDuration)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(WatchAppColors.cardBackground.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Helpers

    private var disciplineIcon: String {
        switch session.discipline.lowercased() {
        case "riding": return "figure.equestrian.sports"
        case "running": return "figure.run"
        case "swimming": return "figure.pool.swim"
        case "shooting": return "target"
        default: return "figure.mixed.cardio"
        }
    }

    private var disciplineColor: Color {
        switch session.discipline.lowercased() {
        case "riding": return WatchAppColors.riding
        case "running": return WatchAppColors.running
        case "swimming": return WatchAppColors.swimming
        case "shooting": return WatchAppColors.shooting
        default: return WatchAppColors.primary
        }
    }

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: session.date, relativeTo: Date())
    }

    private var formattedDuration: String {
        let hours = Int(session.duration) / 3600
        let minutes = (Int(session.duration) % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        }
        return String(format: "%dm", minutes)
    }
}

// MARK: - Local Session Card (for pending Watch sessions)

struct LocalSessionCard: View {
    let session: WatchSession

    var body: some View {
        HStack(spacing: 10) {
            // Discipline icon with pending indicator
            ZStack {
                Circle()
                    .fill(disciplineColor.opacity(0.2))
                    .frame(width: 32, height: 32)

                Image(systemName: disciplineIcon)
                    .font(.body)
                    .foregroundStyle(disciplineColor)
            }
            .overlay(
                // Pending sync indicator
                Circle()
                    .fill(.orange)
                    .frame(width: 8, height: 8)
                    .offset(x: 10, y: -10)
            )

            // Session details
            VStack(alignment: .leading, spacing: 2) {
                Text(session.discipline.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text(formattedDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Key metric
            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedDistance)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(disciplineColor)

                Text(formattedDuration)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(WatchAppColors.cardBackground.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Helpers

    private var disciplineIcon: String {
        switch session.discipline {
        case .riding: return "figure.equestrian.sports"
        case .running: return "figure.run"
        case .swimming: return "figure.pool.swim"
        }
    }

    private var disciplineColor: Color {
        switch session.discipline {
        case .riding: return WatchAppColors.riding
        case .running: return WatchAppColors.running
        case .swimming: return WatchAppColors.swimming
        }
    }

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: session.startDate, relativeTo: Date())
    }

    private var formattedDuration: String {
        let hours = Int(session.duration) / 3600
        let minutes = (Int(session.duration) % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        }
        return String(format: "%dm", max(1, minutes))
    }

    private var formattedDistance: String {
        if session.distance >= 1000 {
            return String(format: "%.1f km", session.distance / 1000)
        }
        return String(format: "%.0f m", session.distance)
    }
}

#Preview {
    WatchInsightsView()
        .environment(WatchConnectivityService.shared)
}
