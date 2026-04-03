//
//  ShootingTrainingComponents.swift
//  TetraTrack
//
//  Training views for shooting discipline
//

import SwiftUI
import SwiftData

// MARK: - Training View

struct ShootingTrainingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingBalanceDrill = false
    @State private var showingBreathingDrill = false
    @State private var showingDryFireDrill = false
    @State private var showingReactionDrill = false
    @State private var showingFocusDrill = false
    @State private var showingRecoilControlDrill = false
    @State private var showingSplitTimeDrill = false
    @State private var showingPosturalDriftDrill = false
    @State private var showingStressInoculationDrill = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
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

                        // Advanced Drills Section
                        Text("Advanced Training")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)

                        // Recoil Control Drill
                        Button { showingRecoilControlDrill = true } label: {
                            DisciplineCard(
                                title: "Recoil Control",
                                subtitle: "Recovery speed",
                                icon: "arrow.uturn.backward",
                                color: .red
                            )
                        }
                        .buttonStyle(.plain)

                        // Split Time Drill
                        Button { showingSplitTimeDrill = true } label: {
                            DisciplineCard(
                                title: "Split Time",
                                subtitle: "Target transitions",
                                icon: "timer",
                                color: .yellow
                            )
                        }
                        .buttonStyle(.plain)

                        // Postural Drift Drill
                        Button { showingPosturalDriftDrill = true } label: {
                            DisciplineCard(
                                title: "Postural Drift",
                                subtitle: "Endurance hold",
                                icon: "figure.walk.motion",
                                color: .indigo
                            )
                        }
                        .buttonStyle(.plain)

                        // Stress Inoculation Drill
                        Button { showingStressInoculationDrill = true } label: {
                            DisciplineCard(
                                title: "Stress Inoculation",
                                subtitle: "Elevated HR",
                                icon: "heart.text.square",
                                color: .pink
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
            .fullScreenCover(isPresented: $showingRecoilControlDrill) {
                RecoilControlDrillView()
            }
            .fullScreenCover(isPresented: $showingSplitTimeDrill) {
                SplitTimeDrillView()
            }
            .fullScreenCover(isPresented: $showingPosturalDriftDrill) {
                PosturalDriftDrillView()
            }
            .fullScreenCover(isPresented: $showingStressInoculationDrill) {
                StressInoculationDrillView()
            }
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
        .background(AppColors.cardBackground)
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
