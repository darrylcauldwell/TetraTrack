//
//  SwimmingView.swift
//  TetraTrack
//
//  Swimming discipline - timed test, training sessions, SWOLF tracking
//

import SwiftUI
import SwiftData
import WidgetKit
import HealthKit

struct SwimmingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionTracker.self) private var tracker: SessionTracker?

    @State private var showingSettings = false
    @State private var showingIntervalSetup = false
    @State private var intervalSettings = SwimmingIntervalSettings()
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
        DisciplineMenuView(
                items: menuItems,
                header: WatchConnectivityManager.shared.isPaired
                    ? AnyView(SwimmingWatchStatusCard())
                    : nil
            )
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
                        startSession(type: .intervals)
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

        let isTest = type == .threeMinuteTest

        let session = SwimmingSession(
            name: name,
            poolMode: poolMode,
            poolLength: poolLength
        )
        modelContext.insert(session)

        let plugin = SwimmingPlugin(
            session: session,
            intervalSettings: type == .intervals ? intervalSettings : nil,
            isThreeMinuteTest: isTest,
            testDuration: selectedLevel.swimDuration,
            freeSwimTargetDuration: freeSwimTargetDuration > 0 ? freeSwimTargetDuration : nil
        )
        Task {
            await tracker?.startSession(plugin: plugin)
        }
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
