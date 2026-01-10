//
//  DisciplinesView.swift
//  TrackRide
//
//  Hub view for all Tetrathlon disciplines
//

import SwiftUI

struct DisciplinesView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    NavigationLink(destination: RidingView()) {
                        DisciplineCard(
                            title: "Riding",
                            subtitle: "Track rides & training drills",
                            icon: "figure.equestrian.sports",
                            color: .green
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: RunningView()) {
                        DisciplineCard(
                            title: "Running",
                            subtitle: "Time trials & intervals",
                            icon: "figure.run",
                            color: .orange
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: SwimmingView()) {
                        DisciplineCard(
                            title: "Swimming",
                            subtitle: "Timed tests & training",
                            icon: "figure.pool.swim",
                            color: .blue
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: ShootingView()) {
                        DisciplineCard(
                            title: "Shooting",
                            subtitle: "Competition & practice",
                            icon: "target",
                            color: .red
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: TrainingHistoryView()) {
                        DisciplineCard(
                            title: "Training History",
                            subtitle: "View past sessions",
                            icon: "clock.arrow.circlepath",
                            color: .gray
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: CompetitionCalendarView()) {
                        DisciplineCard(
                            title: "Competitions",
                            subtitle: "Calendar & preparation",
                            icon: "calendar",
                            color: .purple
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: TaskListView()) {
                        DisciplineCard(
                            title: "Tasks",
                            subtitle: "Preparation checklist",
                            icon: "checklist",
                            color: .teal
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: FamilyView()) {
                        DisciplineCard(
                            title: "Live Sharing",
                            subtitle: "Family & emergency contacts",
                            icon: "location.fill.viewfinder",
                            color: .cyan
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }
}

struct DisciplineCard: View {
    let title: String
    var subtitle: String = ""
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            // Icon on the left
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(color)
                .frame(width: 44)

            // Text on the right
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    DisciplinesView()
}
