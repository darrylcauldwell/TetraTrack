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
    @State private var showingHistory = false
    @State private var showingSettings = false

    private var menuItems: [DisciplineMenuItem] {
        [
            DisciplineMenuItem(
                title: "Tetrathlon Practice",
                subtitle: "2x 5-shot competition cards",
                icon: "trophy.fill",
                color: .orange,
                action: { showingCompetition = true }
            ),
            DisciplineMenuItem(
                title: "Free Practice",
                subtitle: "Analyse single target",
                icon: "target",
                color: .blue,
                action: { showingFreePractice = true }
            ),
            DisciplineMenuItem(
                title: "Shooting History",
                subtitle: "View patterns over time",
                icon: "chart.line.uptrend.xyaxis",
                color: .purple,
                action: { showingHistory = true }
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
                FreePracticeView(
                    onEnd: {
                        showingFreePractice = false
                    },
                    onAnalysisComplete: {
                        // Navigate to history after completing analysis
                        showingFreePractice = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingHistory = true
                        }
                    }
                )
            }
            .fullScreenCover(isPresented: $showingHistory) {
                ShootingHistoryAggregateView(onDismiss: {
                    showingHistory = false
                })
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
