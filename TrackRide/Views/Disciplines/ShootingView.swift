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

    private var menuItems: [DisciplineMenuItem] {
        [
            DisciplineMenuItem(
                title: "Competition",
                subtitle: "2x 5-shot cards",
                icon: "trophy.fill",
                color: .orange,
                action: { showingCompetition = true }
            ),
            DisciplineMenuItem(
                title: "Target Practice",
                subtitle: "Scan & analyse",
                icon: "target",
                color: .blue,
                action: { showingFreePractice = true }
            ),
            DisciplineMenuItem(
                title: "Training",
                subtitle: "Drills & balance",
                icon: "figure.stand",
                color: AppColors.primary,
                action: { showingTraining = true }
            )
        ]
    }

    var body: some View {
        DisciplineMenuView(items: menuItems)
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
                    .presentationDragIndicator(.hidden)
                    .interactiveDismissDisabled()
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
