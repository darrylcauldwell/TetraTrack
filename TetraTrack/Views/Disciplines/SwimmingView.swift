//
//  SwimmingView.swift
//  TetraTrack
//
//  Swimming discipline - timed test, training sessions, SWOLF tracking
//

import SwiftUI
import SwiftData
import WidgetKit

struct SwimmingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var activeSession: SwimmingSession?
    @State private var showingSettings = false
    @State private var showingIntervalSetup = false
    @State private var intervalSettings = SwimmingIntervalSettings()
    @State private var activeIntervalSettings: SwimmingIntervalSettings?
    @AppStorage("swimmingPoolLength") private var poolLength: Double = 25
    @AppStorage("swimmingPoolMode") private var poolModeRaw: String = SwimmingPoolMode.pool.rawValue
    @AppStorage("selectedCompetitionLevel") private var selectedLevelRaw: String = CompetitionLevel.junior.rawValue
    @AppStorage("freeSwimTargetDuration") private var freeSwimTargetDuration: Double = 0

    private var poolMode: SwimmingPoolMode {
        SwimmingPoolMode(rawValue: poolModeRaw) ?? .pool
    }

    private var selectedLevel: CompetitionLevel {
        CompetitionLevel(rawValue: selectedLevelRaw) ?? .junior
    }

    private var menuItems: [DisciplineMenuItem] {
        [
            DisciplineMenuItem(
                title: "Tetrathlon Practice",
                subtitle: selectedLevel.formattedSwimDuration,
                icon: "stopwatch.fill",
                color: .orange,
                action: { startSession(type: .threeMinuteTest) }
            ),
            DisciplineMenuItem(
                title: "Free Swim",
                subtitle: freeSwimTargetDuration > 0 ? "\(Int(freeSwimTargetDuration / 60)) min session" : "Open session",
                icon: "figure.pool.swim",
                color: AppColors.primary,
                action: { startSession(type: .training) }
            ),
            DisciplineMenuItem(
                title: "Intervals",
                subtitle: "Structured sets",
                icon: "repeat",
                color: .cyan,
                action: { showingIntervalSetup = true }
            )
        ]
    }

    var body: some View {
        DisciplineMenuView(items: menuItems)
            .navigationTitle("Swimming")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    NavigationLink {
                        SwimmingTrendsView()
                    } label: {
                        Image(systemName: "chart.xyaxis.line")
                    }

                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
            .sheet(isPresented: $showingSettings) {
                SwimmingSettingsView(
                    poolLength: $poolLength,
                    poolModeRaw: $poolModeRaw,
                    freeSwimTargetDuration: $freeSwimTargetDuration
                )
            }
            .sheet(isPresented: $showingIntervalSetup) {
                SwimmingIntervalSetupView(
                    settings: $intervalSettings,
                    poolLength: poolLength,
                    onStart: {
                        activeIntervalSettings = intervalSettings
                        startSession(type: .intervals)
                    }
                )
            }
            .fullScreenCover(item: $activeSession) { session in
                SwimmingLiveView(
                    session: session,
                    poolLength: poolLength,
                    isThreeMinuteTest: session.name.contains("Test"),
                    testDuration: selectedLevel.swimDuration,
                    freeSwimTargetDuration: freeSwimTargetDuration > 0 ? freeSwimTargetDuration : nil,
                    intervalSettings: activeIntervalSettings,
                    onEnd: {
                        activeIntervalSettings = nil
                        // Update CSS threshold pace after timed test
                        if session.name.contains("Test") && session.totalDistance > 0 {
                            var pbs = SwimmingPersonalBests.shared
                            pbs.updateThresholdPace(
                                from: session.totalDistance,
                                testDuration: selectedLevel.swimDuration
                            )
                            pbs.updatePersonalBest(
                                distance: session.totalDistance,
                                time: session.totalDuration
                            )
                        }
                        // Save to HealthKit
                        Task {
                            let healthKit = HealthKitManager.shared
                            let _ = await healthKit.saveSwimmingSessionAsWorkout(session)
                        }
                        // Compute and save skill domain scores (basic without subjective score)
                        let skillService = SkillDomainService()
                        let skillScores = skillService.computeScores(from: session, score: nil)
                        for skillScore in skillScores {
                            modelContext.insert(skillScore)
                        }
                        try? modelContext.save()
                        // Convert to TrainingArtifact and sync to CloudKit for family sharing
                        Task {
                            await ArtifactConversionService.shared.convertAndSyncSwimmingSession(session)
                        }
                        // Sync sessions to widgets
                        WidgetDataSyncService.shared.syncRecentSessions(context: modelContext)
                        activeSession = nil
                    },
                    onDiscard: {
                        // Delete without saving
                        activeIntervalSettings = nil
                        modelContext.delete(session)
                        try? modelContext.save()
                        activeSession = nil
                    }
                )
            }
        .presentationBackground(Color.black)
    }

    private func startSession(type: SwimSessionType) {
        let name: String
        switch type {
        case .threeMinuteTest:
            name = "\(selectedLevel.displayName) Test"
        case .training:
            name = "Training"
        case .intervals:
            name = "Intervals"
        }

        let session = SwimmingSession(
            name: name,
            poolMode: poolMode,
            poolLength: poolLength
        )
        modelContext.insert(session)
        activeSession = session
    }

    enum SwimSessionType: String {
        case threeMinuteTest = "Timed Test"
        case training = "Training"
        case intervals = "Intervals"
    }
}

// Components moved to SwimmingComponents.swift:
// - SwimTypeButton
// - SwimmingSettingsView
// - SwimmingPersonalBests
// - SwimmingLiveView
// - SwimmingSessionDetailView
// - SwimMiniStat
// - LapRow

#Preview {
    SwimmingView()
        .modelContainer(for: SwimmingSession.self, inMemory: true)
}
