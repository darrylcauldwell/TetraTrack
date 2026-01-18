//
//  RidingTrainingComponents.swift
//  TrackRide
//
//  Training views for riding discipline - off-horse drills for improving rider fitness and balance
//

import SwiftUI
import SwiftData

// MARK: - Riding Training View

struct RidingTrainingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var streaks: [TrainingStreak]

    @State private var showingHeelPositionDrill = false
    @State private var showingCoreStabilityDrill = false
    @State private var showingTwoPointDrill = false
    @State private var showingBalanceBoardDrill = false
    @State private var showingHipMobilityDrill = false
    @State private var showingPostingRhythmDrill = false
    @State private var showingRiderStillnessDrill = false
    @State private var showingStirrupPressureDrill = false

    private var streak: TrainingStreak? {
        streaks.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Training Streak Banner
                    RidingStreakBanner(streak: streak, modelContext: modelContext)

                    // Training drills - single column
                    VStack(spacing: 12) {
                        // Heel Position Drill
                        Button { showingHeelPositionDrill = true } label: {
                            DisciplineCard(
                                title: "Heel Position",
                                subtitle: "Heels down balance",
                                icon: "figure.stand",
                                color: .green
                            )
                        }
                        .buttonStyle(.plain)

                        // Core Stability Drill
                        Button { showingCoreStabilityDrill = true } label: {
                            DisciplineCard(
                                title: "Core Stability",
                                subtitle: "Independent seat",
                                icon: "figure.core.training",
                                color: .blue
                            )
                        }
                        .buttonStyle(.plain)

                        // Two-Point Hold Drill
                        Button { showingTwoPointDrill = true } label: {
                            DisciplineCard(
                                title: "Two-Point",
                                subtitle: "Half-seat hold",
                                icon: "figure.gymnastics",
                                color: .orange
                            )
                        }
                        .buttonStyle(.plain)

                        // Balance Board Drill
                        Button { showingBalanceBoardDrill = true } label: {
                            DisciplineCard(
                                title: "Balance Board",
                                subtitle: "Movement absorption",
                                icon: "figure.surfing",
                                color: .purple
                            )
                        }
                        .buttonStyle(.plain)

                        // Movement Science Drills Section
                        Text("Movement Science")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)

                        // Hip Mobility Drill
                        Button { showingHipMobilityDrill = true } label: {
                            DisciplineCard(
                                title: "Hip Mobility",
                                subtitle: "Following motion",
                                icon: "figure.flexibility",
                                color: .pink
                            )
                        }
                        .buttonStyle(.plain)

                        // Posting Rhythm Drill
                        Button { showingPostingRhythmDrill = true } label: {
                            DisciplineCard(
                                title: "Posting Rhythm",
                                subtitle: "Metronome training",
                                icon: "metronome",
                                color: .indigo
                            )
                        }
                        .buttonStyle(.plain)

                        // Rider Stillness Drill
                        Button { showingRiderStillnessDrill = true } label: {
                            DisciplineCard(
                                title: "Rider Stillness",
                                subtitle: "Quiet aids",
                                icon: "person.and.background.dotted",
                                color: .teal
                            )
                        }
                        .buttonStyle(.plain)

                        // Stirrup Pressure Drill
                        Button { showingStirrupPressureDrill = true } label: {
                            DisciplineCard(
                                title: "Stirrup Pressure",
                                subtitle: "Heel weight",
                                icon: "arrow.down.to.line",
                                color: .mint
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Riding Drills")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.medium))
                    }
                }
            }
            .fullScreenCover(isPresented: $showingHeelPositionDrill) {
                HeelPositionDrillView()
            }
            .fullScreenCover(isPresented: $showingCoreStabilityDrill) {
                CoreStabilityDrillView()
            }
            .fullScreenCover(isPresented: $showingTwoPointDrill) {
                TwoPointHoldDrillView()
            }
            .fullScreenCover(isPresented: $showingBalanceBoardDrill) {
                BalanceBoardDrillView()
            }
            .fullScreenCover(isPresented: $showingHipMobilityDrill) {
                HipMobilityDrillView()
            }
            .fullScreenCover(isPresented: $showingPostingRhythmDrill) {
                PostingRhythmDrillView()
            }
            .fullScreenCover(isPresented: $showingRiderStillnessDrill) {
                RiderStillnessDrillView()
            }
            .fullScreenCover(isPresented: $showingStirrupPressureDrill) {
                StirrupPressureDrillView()
            }
        }
    }
}

// MARK: - Riding Streak Banner

struct RidingStreakBanner: View {
    let streak: TrainingStreak?
    let modelContext: ModelContext

    private var currentStreak: Int {
        streak?.effectiveCurrentStreak ?? 0
    }

    private var longestStreak: Int {
        streak?.longestStreak ?? 0
    }

    private var totalTrainingDays: Int {
        streak?.totalTrainingDays ?? 0
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header row
            HStack {
                Text("Training Streak")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                if totalTrainingDays > 0 {
                    Text("\(totalTrainingDays) days trained")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Current streak row
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.body)
                        .foregroundStyle(currentStreak > 0 ? .orange : .gray)
                    Text("Current Streak")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(currentStreak) \(currentStreak == 1 ? "day" : "days")")
                    .font(.subheadline.bold())
            }

            // Best streak row
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.body)
                        .foregroundStyle(.yellow)
                    Text("Best Streak")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(longestStreak) \(longestStreak == 1 ? "day" : "days")")
                    .font(.subheadline.bold())
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    RidingTrainingView()
        .modelContainer(for: TrainingStreak.self, inMemory: true)
}
