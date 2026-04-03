//
//  RidingTrainingComponents.swift
//  TetraTrack
//
//  Training views for riding discipline - off-horse drills for improving rider fitness and balance
//

import SwiftUI
import SwiftData

// MARK: - Riding Training View

struct RidingTrainingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingHeelPositionDrill = false
    @State private var showingCoreStabilityDrill = false
    @State private var showingTwoPointDrill = false
    @State private var showingBalanceBoardDrill = false
    @State private var showingHipMobilityDrill = false
    @State private var showingPostingRhythmDrill = false
    @State private var showingRiderStillnessDrill = false
    @State private var showingStirrupPressureDrill = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
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

#Preview {
    RidingTrainingView()
        .modelContainer(for: UnifiedDrillSession.self, inMemory: true)
}
