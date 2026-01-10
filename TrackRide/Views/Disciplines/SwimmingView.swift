//
//  SwimmingView.swift
//  TrackRide
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
    @AppStorage("swimmingPoolLength") private var poolLength: Double = 25
    @AppStorage("swimmingPoolMode") private var poolModeRaw: String = SwimmingPoolMode.pool.rawValue
    @AppStorage("selectedCompetitionLevel") private var selectedLevelRaw: String = CompetitionLevel.junior.rawValue

    private var poolMode: SwimmingPoolMode {
        SwimmingPoolMode(rawValue: poolModeRaw) ?? .pool
    }

    private var selectedLevel: CompetitionLevel {
        CompetitionLevel(rawValue: selectedLevelRaw) ?? .junior
    }

    private var menuItems: [DisciplineMenuItem] {
        [
            DisciplineMenuItem(
                title: "Tetrathlon",
                subtitle: selectedLevel.formattedSwimDuration,
                icon: "stopwatch.fill",
                color: .orange,
                action: { startSession(type: .threeMinuteTest) }
            ),
            DisciplineMenuItem(
                title: "Training",
                subtitle: "Free swim",
                icon: "figure.pool.swim",
                color: AppColors.primary,
                action: { startSession(type: .training) }
            )
        ]
    }

    var body: some View {
        DisciplineMenuView(items: menuItems)
            .navigationTitle("Swimming")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape")
                }
            }
        }
            .sheet(isPresented: $showingSettings) {
                SwimmingSettingsView(
                    poolLength: $poolLength,
                    poolModeRaw: $poolModeRaw
                )
            }
            .fullScreenCover(item: $activeSession) { session in
                SwimmingLiveView(
                    session: session,
                    poolLength: poolLength,
                    isThreeMinuteTest: session.name.contains("Test"),
                    testDuration: selectedLevel.swimDuration,
                    onEnd: {
                        // Save to HealthKit
                        Task {
                            let healthKit = HealthKitManager.shared
                            let _ = await healthKit.saveSwimmingSessionAsWorkout(session)
                        }
                        // Sync sessions to widgets
                        WidgetDataSyncService.shared.syncRecentSessions(context: modelContext)
                        activeSession = nil
                    },
                    onDiscard: {
                        // Delete without saving
                        modelContext.delete(session)
                        try? modelContext.save()
                        activeSession = nil
                    }
                )
            }
    }

    private func startSession(type: SwimSessionType) {
        let name: String
        switch type {
        case .threeMinuteTest:
            name = "\(selectedLevel.displayName) Test"
        case .training:
            name = "Training"
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
