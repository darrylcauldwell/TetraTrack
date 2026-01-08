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

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Training Streak Banner
                    ShootingStreakBanner(streak: streak, modelContext: modelContext)

                    // Training drills - two column grid
                    LazyVGrid(columns: columns, spacing: 12) {
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
            .glassNavigation()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
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
        streak?.currentStreak ?? 0
    }

    private var longestStreak: Int {
        streak?.longestStreak ?? 0
    }

    private var totalTrainingDays: Int {
        streak?.totalTrainingDays ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main streak display
            HStack(spacing: 16) {
                // Flame icon with streak count
                ZStack {
                    Circle()
                        .fill(streakGradient)
                        .frame(width: 60, height: 60)

                    VStack(spacing: -2) {
                        Image(systemName: streakIcon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("\(currentStreak)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(currentStreak > 0 ? "Day Streak!" : "Start Training")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(streakMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Stats column
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                        Text("\(longestStreak)")
                            .font(.subheadline.bold())
                    }
                    Text("Best")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)

            // Training days info
            if totalTrainingDays > 0 {
                Divider()
                    .padding(.horizontal)

                HStack {
                    Label("\(totalTrainingDays) training days", systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let lastDate = streak?.lastActivityDate {
                        Text(lastDate, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
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

    private var streakGradient: LinearGradient {
        if currentStreak >= 7 {
            return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if currentStreak >= 3 {
            return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if currentStreak > 0 {
            return LinearGradient(colors: [AppColors.primary, AppColors.primary.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            return LinearGradient(colors: [.gray, .gray.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var streakIcon: String {
        if currentStreak >= 7 {
            return "flame.fill"
        } else if currentStreak >= 3 {
            return "bolt.fill"
        } else if currentStreak > 0 {
            return "star.fill"
        } else {
            return "target"
        }
    }

    private var streakMessage: String {
        if currentStreak >= 7 {
            return "You're on fire! Keep the momentum going."
        } else if currentStreak >= 3 {
            return "Great consistency! Build that muscle memory."
        } else if currentStreak > 0 {
            return "Good start! Train daily to build your streak."
        } else {
            return "Complete a drill today to start your streak!"
        }
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
