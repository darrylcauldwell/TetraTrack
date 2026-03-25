//
//  RunningView.swift
//  TetraTrack
//
//  Running discipline - 1500m trials, intervals, race predictor
//

import SwiftUI
import SwiftData
import CoreLocation
import WidgetKit
import HealthKit
import os

// MARK: - Setup Config

struct RunningSetupConfig: Identifiable {
    let id = UUID()
    let runType: PendingRunStart
    let title: String
    let icon: String
    let color: Color
    var runMode: RunningMode = .outdoor
    var targetCadence: Int = 0
    var trackLength: Double = 400.0
}

enum PendingRunStart {
    case standard(RunningSessionType)
    case interval(IntervalSettings)
    case pacer(PacerSettings)
}

// MARK: - Running View

struct RunningView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionTracker.self) private var tracker: SessionTracker?
    @Query private var profiles: [RiderProfile]
    @Query private var sharingContacts: [SharingRelationship]

    @State private var pendingSetup: RunningSetupConfig?
    @State private var configToStart: RunningSetupConfig?
    @State private var showingTrainingPrograms = false
    @AppStorage("selectedCompetitionLevel") private var selectedLevelRaw: String = CompetitionLevel.junior.rawValue

    private var selectedLevel: CompetitionLevel {
        CompetitionLevel(rawValue: selectedLevelRaw) ?? .junior
    }

    /// Whether any contact has live tracking enabled (from main sharing settings)
    private var shareWithFamily: Bool {
        sharingContacts.contains { $0.canViewLiveTracking }
    }

    private var menuItems: [DisciplineMenuItem] {
        [
            DisciplineMenuItem(
                title: "Outdoor Run",
                subtitle: "GPS route tracking",
                icon: "figure.run",
                color: AppColors.primary,
                action: {
                    pendingSetup = RunningSetupConfig(
                        runType: .standard(.easy),
                        title: "Outdoor Run",
                        icon: "figure.run",
                        color: AppColors.primary,
                        runMode: .outdoor
                    )
                }
            ),
            DisciplineMenuItem(
                title: "Track Run",
                subtitle: "Automatic lap detection",
                icon: "circle.dashed",
                color: .cyan,
                action: {
                    pendingSetup = RunningSetupConfig(
                        runType: .standard(.easy),
                        title: "Track Run",
                        icon: "circle.dashed",
                        color: .cyan,
                        runMode: .track
                    )
                }
            ),
            DisciplineMenuItem(
                title: "Virtual Pacer",
                subtitle: "Target pace",
                icon: "person.line.dotted.person.fill",
                color: .cyan,
                action: {
                    pendingSetup = RunningSetupConfig(
                        runType: .pacer(PacerSettings()),
                        title: "Virtual Pacer",
                        icon: "person.line.dotted.person.fill",
                        color: .cyan
                    )
                }
            ),
            DisciplineMenuItem(
                title: "Intervals",
                subtitle: "Training sets",
                icon: "timer",
                color: .orange,
                action: {
                    pendingSetup = RunningSetupConfig(
                        runType: .interval(IntervalSettings()),
                        title: "Intervals",
                        icon: "timer",
                        color: .orange
                    )
                }
            ),
            DisciplineMenuItem(
                title: "Tetrathlon Practice",
                subtitle: selectedLevel.formattedRunDistance,
                icon: "stopwatch.fill",
                color: .purple,
                action: {
                    pendingSetup = RunningSetupConfig(
                        runType: .standard(.timeTrial),
                        title: "Tetrathlon Practice",
                        icon: "stopwatch.fill",
                        color: .purple
                    )
                }
            ),
            DisciplineMenuItem(
                title: "Treadmill",
                subtitle: "Indoor tracked run",
                icon: "figure.run.treadmill",
                color: .mint,
                action: {
                    pendingSetup = RunningSetupConfig(
                        runType: .standard(.treadmill),
                        title: "Treadmill",
                        icon: "figure.run.treadmill",
                        color: .mint
                    )
                }
            ),
            DisciplineMenuItem(
                title: "Training Programs",
                subtitle: "C25K, 10K, Half Marathon",
                icon: "chart.line.uptrend.xyaxis",
                color: .green,
                requiresCapture: false,
                action: {
                    showingTrainingPrograms = true
                }
            )
        ]
    }

    var body: some View {
        DisciplineMenuView(items: menuItems)
            .navigationTitle("Running")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showingTrainingPrograms) {
                ProgramListView(onStartSession: { programSession in
                    startProgramSession(programSession)
                    showingTrainingPrograms = false
                })
            }
            .sheet(item: $pendingSetup, onDismiss: {
                if let config = configToStart {
                    configToStart = nil
                    startFromConfig(config)
                }
            }) { config in
                RunningSetupSheet(
                    config: config,
                    selectedLevel: selectedLevel,
                    onStart: { finalConfig in
                        configToStart = finalConfig
                        pendingSetup = nil
                    }
                )
            }
            .sheetBackground()
    }

    // MARK: - Start from Config

    private func startProgramSession(_ programSession: ProgramSession) {
        let session = RunningSession(
            name: programSession.name,
            sessionType: .easy,
            runMode: .outdoor
        )
        session.programSessionId = programSession.id

        tracker?.isSharingWithFamily = shareWithFamily
        let plugin = RunningPlugin(
            session: session,
            intervalSettings: nil,
            programIntervals: programSession.sessionDefinition,
            targetDistance: 0,
            targetCadence: 0
        )
        Task {
            await tracker?.startSession(plugin: plugin)
        }
    }

    private func startFromConfig(_ config: RunningSetupConfig) {
        switch config.runType {
        case .standard(let type):
            let session = RunningSession(
                name: config.title,
                sessionType: type,
                runMode: config.runMode
            )
            session.targetCadence = config.targetCadence
            session.trackLength = config.trackLength

            tracker?.isSharingWithFamily = shareWithFamily
            let plugin = RunningPlugin(
                session: session,
                intervalSettings: nil,
                programIntervals: nil,
                targetDistance: type == .timeTrial ? selectedLevel.runDistance : 0,
                targetCadence: config.targetCadence
            )
            Task {
                await tracker?.startSession(plugin: plugin)
            }

        case .interval(let settings):
            let session = RunningSession(
                name: "Interval Run",
                sessionType: .intervals,
                runMode: config.runMode
            )
            session.targetCadence = config.targetCadence

            tracker?.isSharingWithFamily = shareWithFamily
            let plugin = RunningPlugin(
                session: session,
                intervalSettings: settings,
                programIntervals: nil,
                targetDistance: 0,
                targetCadence: config.targetCadence
            )
            Task {
                await tracker?.startSession(plugin: plugin)
            }

        case .pacer(let settings):
            let session = RunningSession(
                name: "Virtual Pacer Run",
                sessionType: .tempo,
                runMode: config.runMode
            )
            session.targetCadence = config.targetCadence
            if settings.useTargetTime && settings.targetDistance > 0 {
                VirtualPacer.shared.start(targetTime: settings.targetTime, forDistance: settings.targetDistance)
            } else {
                VirtualPacer.shared.start(targetPace: settings.targetPace)
            }

            tracker?.isSharingWithFamily = shareWithFamily
            let plugin = RunningPlugin(
                session: session,
                intervalSettings: nil,
                programIntervals: nil,
                targetDistance: 0,
                targetCadence: config.targetCadence
            )
            Task {
                await tracker?.startSession(plugin: plugin)
            }
        }
    }
}

// Components moved to RunningComponents.swift:
// - PacerSettings, RunTypeButton, IntervalSettings, IntervalSetupView
// - VirtualPacerSetupView, RunningSettingsView, LevelPickerView
// - RunningPersonalBests, RunningPauseStopButton, RunningSessionDetailView
// - RunMiniStat, SplitRow
//
// Components moved to RunningLiveComponents.swift:
// - RunningLiveView, TreadmillLiveView, TreadmillDistanceInputView

#Preview {
    RunningView()
        .modelContainer(for: RunningSession.self, inMemory: true)
}
