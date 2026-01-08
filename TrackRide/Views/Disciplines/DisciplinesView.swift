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
                VStack(spacing: 20) {
                    // Cards grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        NavigationLink(destination: TrackingView()) {
                            DisciplineCard(
                                title: "Riding",
                                icon: "figure.equestrian.sports",
                                color: .green
                            )
                        }

                        NavigationLink(destination: RunningView()) {
                            DisciplineCard(
                                title: "Running",
                                icon: "figure.run",
                                color: .orange
                            )
                        }

                        NavigationLink(destination: SwimmingView()) {
                            DisciplineCard(
                                title: "Swimming",
                                icon: "figure.pool.swim",
                                color: .blue
                            )
                        }

                        NavigationLink(destination: ShootingView()) {
                            DisciplineCard(
                                title: "Shooting",
                                icon: "target",
                                color: .red
                            )
                        }

                        NavigationLink(destination: TrainingHistoryView()) {
                            DisciplineCard(
                                title: "Training History",
                                icon: "clock.arrow.circlepath",
                                color: .gray
                            )
                        }

                        NavigationLink(destination: CompetitionCalendarView()) {
                            DisciplineCard(
                                title: "Competition Calendar",
                                icon: "calendar",
                                color: .purple
                            )
                        }

                        NavigationLink(destination: TaskListView()) {
                            DisciplineCard(
                                title: "Tasks",
                                icon: "checklist",
                                color: .teal
                            )
                        }

                        NavigationLink(destination: FamilyView()) {
                            DisciplineCard(
                                title: "Live Sharing",
                                icon: "location.fill.viewfinder",
                                color: .cyan
                            )
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 20)
                }
                .padding(.top)
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
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(color)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    DisciplinesView()
}
