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
    @State private var historyPreSelectedFilter: DateFilterOption? = nil

    private var menuItems: [DisciplineMenuItem] {
        [
            DisciplineMenuItem(
                title: "Tetrathlon Practice",
                subtitle: "2x 5-shot competition cards",
                icon: "trophy.fill",
                color: .orange,
                requiresCapture: true,  // Session capture
                action: { showingCompetition = true }
            ),
            DisciplineMenuItem(
                title: "Free Practice",
                subtitle: "Analyse single target",
                icon: "target",
                color: .blue,
                requiresCapture: true,  // Session capture
                action: { showingFreePractice = true }
            ),
            DisciplineMenuItem(
                title: "Shooting History",
                subtitle: "View patterns over time",
                icon: "chart.line.uptrend.xyaxis",
                color: .purple,
                requiresCapture: false,  // Review only - available on iPad
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
                        // Legacy fallback - just dismiss
                        showingFreePractice = false
                    },
                    onNavigateToHistory: { filter in
                        // Navigate to history with pre-selected filter
                        showingFreePractice = false
                        historyPreSelectedFilter = filter
                        // Small delay to allow dismiss animation before showing history
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingHistory = true
                        }
                    }
                )
            }
            .fullScreenCover(isPresented: $showingHistory) {
                // Use dedicated ShootingHistoryAggregateView for comprehensive shooting history
                ShootingHistoryAggregateView(
                    onDismiss: {
                        showingHistory = false
                        historyPreSelectedFilter = nil
                    },
                    initialDateFilter: historyPreSelectedFilter
                )
            }
            .sheet(isPresented: $showingSettings) {
                ShootingSettingsView()
            }
        .presentationBackground(Color.black)
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
