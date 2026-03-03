//
//  ShootingView.swift
//  TetraTrack
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
    @State private var selectedContext: ShootingSessionContext = .freePractice
    @State private var historyPreSelectedFilter: DateFilterOption? = nil

    private var menuItems: [DisciplineMenuItem] {
        [
            DisciplineMenuItem(
                title: "Free Practice",
                subtitle: "Low pressure practice session",
                icon: "target",
                color: .blue,
                requiresCapture: true,
                action: {
                    selectedContext = .freePractice
                    showingFreePractice = true
                }
            ),
            DisciplineMenuItem(
                title: "Tetrathlon Practice",
                subtitle: "Practice under competition conditions",
                icon: "figure.run",
                color: .orange,
                requiresCapture: true,
                action: {
                    selectedContext = .competitionTraining
                    showingCompetition = true
                }
            ),
            DisciplineMenuItem(
                title: "Competition",
                subtitle: "Official competition scoring",
                icon: "trophy.fill",
                color: .purple,
                requiresCapture: true,
                action: {
                    selectedContext = .competition
                    showingCompetition = true
                }
            ),
            DisciplineMenuItem(
                title: "Shooting History",
                subtitle: "View patterns and pressure insights",
                icon: "chart.line.uptrend.xyaxis",
                color: .green,
                requiresCapture: false,
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
                ShootingCompetitionView(
                    sessionContext: selectedContext,
                    onEnd: { _ in
                        showingCompetition = false
                    }
                )
            }
            .fullScreenCover(isPresented: $showingFreePractice) {
                FreePracticeView(
                    sessionContext: selectedContext,
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

// MARK: - Context Picker View

struct ShootingContextPickerView: View {
    @Binding var selectedContext: ShootingSessionContext
    let onStartSession: (ShootingSessionContext) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)
                    Text("Select Session Context")
                        .font(.title2.bold())
                    Text("Track how pressure affects your performance")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)

                // Context options
                VStack(spacing: 12) {
                    ForEach(ShootingSessionContext.allCases, id: \.self) { context in
                        ContextOptionButton(
                            context: context,
                            isSelected: selectedContext == context,
                            action: { selectedContext = context }
                        )
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Start button
                Button {
                    onStartSession(selectedContext)
                } label: {
                    Text("Start \(selectedContext.displayName)")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(contextColor(selectedContext))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }

    private func contextColor(_ context: ShootingSessionContext) -> Color {
        switch context.color {
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        default: return .gray
        }
    }
}

// MARK: - Context Option Button

private struct ContextOptionButton: View {
    let context: ShootingSessionContext
    let isSelected: Bool
    let action: () -> Void

    private var contextColor: Color {
        switch context.color {
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        default: return .gray
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: context.icon)
                    .font(.title2)
                    .foregroundStyle(contextColor)
                    .frame(width: 44, height: 44)
                    .background(contextColor.opacity(0.15))
                    .clipShape(Circle())

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(context.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Pressure indicator
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        ForEach(1...3, id: \.self) { level in
                            Circle()
                                .fill(level <= context.pressureLevel ? contextColor : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    Text("Pressure")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? contextColor : .secondary)
            }
            .padding()
            .background(isSelected ? contextColor.opacity(0.1) : AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? contextColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
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
