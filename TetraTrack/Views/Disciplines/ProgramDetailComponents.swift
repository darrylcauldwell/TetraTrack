//
//  ProgramDetailComponents.swift
//  TetraTrack
//
//  Reusable components for training program views:
//  week cards, session cards, progress ring
//

import SwiftUI

// MARK: - Program Week Card

struct ProgramWeekCard: View {
    let weekNumber: Int
    let isCurrentWeek: Bool
    let sessions: [ProgramSession]
    let weekDefinition: ProgramWeek?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Week header
            HStack {
                HStack(spacing: 6) {
                    if isCurrentWeek {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                    Text("Week \(weekNumber)")
                        .font(.subheadline.bold())
                }

                if let theme = weekDefinition?.theme {
                    Text("- \(theme)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                let completed = sessions.filter { $0.isCompleted }.count
                Text("\(completed)/\(sessions.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Session rows
            ForEach(sessions) { session in
                ProgramSessionCard(session: session)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    isCurrentWeek
                        ? RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        : nil
                )
        )
    }
}

// MARK: - Program Session Card

struct ProgramSessionCard: View {
    let session: ProgramSession

    var body: some View {
        HStack(spacing: 10) {
            // Status icon
            Image(systemName: session.status.icon)
                .font(.subheadline)
                .foregroundStyle(statusColor)
                .frame(width: 20)

            // Session info
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.caption)
                    .bold()

                // Interval summary
                let intervals = session.sessionDefinition
                if !intervals.isEmpty {
                    HStack(spacing: 4) {
                        let walkTime = session.totalWalkTime
                        let runTime = session.totalRunTime
                        if runTime > 0 {
                            Label(formatDuration(runTime), systemImage: "figure.run")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                        if walkTime > 0 {
                            Label(formatDuration(walkTime), systemImage: "figure.walk")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }

            Spacer()

            // Duration
            Text(session.formattedTargetDuration)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Actual result (if completed)
            if session.isCompleted, session.actualDistanceMeters > 0 {
                Text(String(format: "%.1f km", session.actualDistanceMeters / 1000))
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch session.status {
        case .upcoming: return .secondary
        case .completed: return .green
        case .skipped: return .yellow
        case .missed: return .red
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes) min"
    }
}

// MARK: - Program Progress Ring

struct ProgramProgressRing: View {
    let progress: Double
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.green.opacity(0.2), lineWidth: 8)
                .frame(width: size, height: size)
            Circle()
                .trim(from: 0, to: min(1, progress))
                .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(progress * 100))")
                    .font(.system(.title3, design: .rounded))
                    .bold()
                Text("%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
