//
//  ShootingView.swift
//  TrackRide
//
//  Shooting discipline - practice, competition cards, drills, and scoring
//

import SwiftUI
import SwiftData
import AVFoundation
import Vision
import PhotosUI
import CoreMotion
import HealthKit
import Combine
import WidgetKit

struct ShootingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showingCompetition = false
    @State private var showingFreePractice = false
    @State private var showingTraining = false
    @State private var showingSettings = false

    private var personalBests: ShootingPersonalBests { ShootingPersonalBests.shared }

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                // Competition Practice button
                Button { showingCompetition = true } label: {
                    DisciplineCard(
                        title: "Competition",
                        subtitle: "2x 5-shot cards",
                        icon: "trophy.fill",
                        color: .orange
                    )
                }
                .buttonStyle(.plain)

                // Free Practice button
                Button { showingFreePractice = true } label: {
                    DisciplineCard(
                        title: "Target Practice",
                        subtitle: "Scan & analyse",
                        icon: "target",
                        color: .blue
                    )
                }
                .buttonStyle(.plain)

                // Training Drills button
                Button { showingTraining = true } label: {
                    DisciplineCard(
                        title: "Training",
                        subtitle: "Drills & balance",
                        icon: "figure.stand",
                        color: AppColors.primary
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .navigationTitle("Shooting")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape")
                }
            }
        }
            .fullScreenCover(isPresented: $showingCompetition) {
                ShootingCompetitionView(onEnd: { _ in
                    showingCompetition = false
                })
            }
            .fullScreenCover(isPresented: $showingFreePractice) {
                FreePracticeView(onEnd: {
                    showingFreePractice = false
                })
            }
            .sheet(isPresented: $showingTraining) {
                ShootingTrainingView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingSettings) {
                ShootingSettingsView()
            }
    }
}

// Components moved to ShootingComponents.swift:
// - ShootTypeButton, ShootingPersonalBests, ShootingSettingsView
// - ShootingSessionSetupView, ShootingSessionDetailView, MiniStatCard, EndRow
//
// Components moved to ShootingCompetitionComponents.swift:
// - ShootingCompetitionView, FreePracticeView, ScannedTarget
// - ScannedTargetRow, TargetAnalysisView
//
// Components moved to ShootingScannerComponents.swift:
// - TargetScannerView, DetectedHole, ScoreEditButton
// - AnnotatedTargetImage, CameraPreviewView, CameraViewController
// - TargetAnalyzer
//
// Components moved to ShootingTrainingComponents.swift:
// - ShootingTrainingView, ShootingStreakBanner
// - TrainingDrillRow, TrainingDrillCard

#Preview {
    ShootingView()
        .modelContainer(for: ShootingSession.self, inMemory: true)
}
