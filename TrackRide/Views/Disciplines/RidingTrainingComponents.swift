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
                    RidingStreakBanner(streak: streak, modelContext: modelContext)

                    // Training drills - two column grid
                    LazyVGrid(columns: columns, spacing: 12) {
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
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Riding Drills")
            .navigationBarTitleDisplayMode(.inline)
            .glassNavigation()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
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
        }
    }
}

// MARK: - Riding Streak Banner

struct RidingStreakBanner: View {
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
                // Icon with streak count
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
            return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if currentStreak >= 3 {
            return LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
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
            return "figure.equestrian.sports"
        }
    }

    private var streakMessage: String {
        if currentStreak >= 7 {
            return "You're on fire! Keep the momentum going."
        } else if currentStreak >= 3 {
            return "Great consistency! Building rider fitness."
        } else if currentStreak > 0 {
            return "Good start! Train daily to build your streak."
        } else {
            return "Complete a drill today to start your streak!"
        }
    }
}

#Preview {
    RidingTrainingView()
        .modelContainer(for: TrainingStreak.self, inMemory: true)
}
