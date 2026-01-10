//
//  ShootingTrainingComponents.swift
//  TrackRide
//
//  Training views for shooting discipline
//

import SwiftUI
import SwiftData

// MARK: - Training View

struct ShootingTrainingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var streaks: [TrainingStreak]

    @State private var showingBalanceDrill = false
    @State private var showingBreathingDrill = false
    @State private var showingDryFireDrill = false
    @State private var showingReactionDrill = false
    @State private var showingFocusDrill = false

    private var streak: TrainingStreak? {
        streaks.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Training Streak Banner
                    ShootingStreakBanner(streak: streak, modelContext: modelContext)

                    // Training drills - single column
                    VStack(spacing: 12) {
                        // Balance Drill
                        Button { showingBalanceDrill = true } label: {
                            DisciplineCard(
                                title: "Balance",
                                subtitle: "One-leg stand",
                                icon: "figure.stand",
                                color: .purple
                            )
                        }
                        .buttonStyle(.plain)

                        // Breathing Exercise
                        Button { showingBreathingDrill = true } label: {
                            DisciplineCard(
                                title: "Breathing",
                                subtitle: "Box technique",
                                icon: "wind",
                                color: .blue
                            )
                        }
                        .buttonStyle(.plain)

                        // Dry Fire Practice
                        Button { showingDryFireDrill = true } label: {
                            DisciplineCard(
                                title: "Dry Fire",
                                subtitle: "Trigger control",
                                icon: "hand.point.up.fill",
                                color: .green
                            )
                        }
                        .buttonStyle(.plain)

                        // Reaction Training
                        Button { showingReactionDrill = true } label: {
                            DisciplineCard(
                                title: "Reaction",
                                subtitle: "Tap targets",
                                icon: "bolt.fill",
                                color: .orange
                            )
                        }
                        .buttonStyle(.plain)

                        // Focus Drill
                        Button { showingFocusDrill = true } label: {
                            DisciplineCard(
                                title: "Steady Hold",
                                subtitle: "Track wobble",
                                icon: "scope",
                                color: .cyan
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Training Drills")
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
            .fullScreenCover(isPresented: $showingBalanceDrill) {
                BalanceDrillView()
            }
            .fullScreenCover(isPresented: $showingBreathingDrill) {
                BreathingDrillView()
            }
            .fullScreenCover(isPresented: $showingDryFireDrill) {
                DryFireDrillView()
            }
            .fullScreenCover(isPresented: $showingReactionDrill) {
                ReactionDrillView()
            }
            .fullScreenCover(isPresented: $showingFocusDrill) {
                SteadyHoldDrillView()
            }
        }
    }
}

// MARK: - Shooting Streak Banner

struct ShootingStreakBanner: View {
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

// MARK: - Training Drill Row (for List) - Glass Design

struct TrainingDrillRow: View {
    let title: String
    var subtitle: String = ""
    let description: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            // Glass icon bubble
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if !subtitle.isEmpty {
                        GlassChip(subtitle, color: color)
                    }
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Training Drill Card

struct TrainingDrillCard: View {
    let title: String
    var subtitle: String = ""
    let description: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            // Glass icon bubble
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                    if !subtitle.isEmpty {
                        GlassChip(subtitle, color: color)
                    }
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .glassCard(material: .thin, cornerRadius: 16, padding: 16)
    }
}

// Drill views extracted to ShootingDrills/ directory:
// - BalanceDrillView.swift
// - BreathingDrillView.swift
// - DryFireDrillView.swift
// - ReactionDrillView.swift
// - SteadyHoldDrillView.swift
