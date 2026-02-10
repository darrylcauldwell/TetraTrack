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
import os

// MARK: - Setup Config

struct RunningSetupConfig: Identifiable {
    let id = UUID()
    let runType: PendingRunStart
    let title: String
    let icon: String
    let color: Color
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
    @Query private var profiles: [RiderProfile]
    @Query private var sharingContacts: [SharingRelationship]

    @State private var activeSession: RunningSession?
    @State private var activeIntervalSettings: IntervalSettings?
    @State private var pendingSetup: RunningSetupConfig?
    @State private var configToStart: RunningSetupConfig?
    @State private var completedSession: RunningSession?
    @AppStorage("selectedCompetitionLevel") private var selectedLevelRaw: String = CompetitionLevel.junior.rawValue
    @AppStorage("runningTrackMode") private var trackMode: Bool = false
    @AppStorage("runningFallDetection") private var fallDetectionEnabled: Bool = true

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
                title: "Run",
                subtitle: trackMode ? "Track run" : "Free GPS run",
                icon: "figure.run",
                color: AppColors.primary,
                action: {
                    pendingSetup = RunningSetupConfig(
                        runType: .standard(.easy),
                        title: "Run",
                        icon: "figure.run",
                        color: AppColors.primary
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
            )
        ]
    }

    var body: some View {
        DisciplineMenuView(items: menuItems)
            .navigationTitle("Running")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $completedSession) { session in
                RunningSessionDetailView(session: session)
            }
            .sheet(item: $pendingSetup, onDismiss: {
                if let config = configToStart {
                    configToStart = nil
                    startFromConfig(config)
                }
            }) { config in
                RunningSetupSheet(
                    config: config,
                    trackMode: $trackMode,
                    selectedLevel: selectedLevel,
                    onStart: { finalConfig in
                        configToStart = finalConfig
                        pendingSetup = nil
                    }
                )
            }
            .fullScreenCover(item: $activeSession) { session in
                if session.sessionType == .treadmill {
                    TreadmillLiveView(
                        session: session,
                        onEnd: {
                            Task {
                                let healthKit = HealthKitManager.shared
                                let _ = await healthKit.saveRunningSessionAsWorkout(session, riderWeight: profiles.first?.weight ?? 70.0)

                                // Fetch HealthKit running metrics from Apple Watch
                                try? await Task.sleep(for: .seconds(2))
                                if let endDate = session.endDate {
                                    let metrics = await healthKit.fetchRunningMetrics(from: session.startDate, to: endDate)
                                    await MainActor.run {
                                        // Store all HealthKit metrics (more accurate than phone)
                                        session.healthKitAsymmetry = metrics.asymmetryPercentage
                                        session.healthKitStrideLength = metrics.strideLength
                                        session.healthKitPower = metrics.power
                                        session.healthKitSpeed = metrics.speed
                                        session.healthKitStepCount = metrics.stepCount

                                        if let gct = metrics.groundContactTime, gct > 0 {
                                            session.averageGroundContactTime = gct
                                        }
                                        if let osc = metrics.verticalOscillation, osc > 0 {
                                            session.averageVerticalOscillation = osc
                                        }
                                        try? modelContext.save()
                                    }
                                }
                            }
                            let skillService = SkillDomainService()
                            let skillScores = skillService.computeScores(from: session, score: nil)
                            for skillScore in skillScores {
                                modelContext.insert(skillScore)
                            }
                            try? modelContext.save()
                            Task {
                                await ArtifactConversionService.shared.convertAndSyncRunningSession(session)
                            }
                            WidgetDataSyncService.shared.syncRecentSessions(context: modelContext)
                            completedSession = session
                            activeSession = nil
                        },
                        onDiscard: {
                            modelContext.delete(session)
                            try? modelContext.save()
                            activeSession = nil
                        },
                        fallDetectionEnabled: fallDetectionEnabled
                    )
                } else {
                    RunningLiveView(
                        session: session,
                        intervalSettings: activeIntervalSettings,
                        targetDistance: session.sessionType == .timeTrial ? selectedLevel.runDistance : 0,
                        shareWithFamily: shareWithFamily,
                        fallDetectionEnabled: fallDetectionEnabled,
                        onEnd: {
                            Task {
                                let healthKit = HealthKitManager.shared
                                let _ = await healthKit.saveRunningSessionAsWorkout(session, riderWeight: profiles.first?.weight ?? 70.0)

                                // Fetch HealthKit running metrics from Apple Watch
                                // Allow a short delay for HealthKit to process the workout
                                try? await Task.sleep(for: .seconds(2))
                                if let endDate = session.endDate {
                                    let metrics = await healthKit.fetchRunningMetrics(from: session.startDate, to: endDate)
                                    await MainActor.run {
                                        // Store all HealthKit metrics (more accurate than phone)
                                        session.healthKitAsymmetry = metrics.asymmetryPercentage
                                        session.healthKitStrideLength = metrics.strideLength
                                        session.healthKitPower = metrics.power
                                        session.healthKitSpeed = metrics.speed
                                        session.healthKitStepCount = metrics.stepCount

                                        // Update watch-derived metrics if HealthKit has better data
                                        if let gct = metrics.groundContactTime, gct > 0 {
                                            session.averageGroundContactTime = gct
                                        }
                                        if let osc = metrics.verticalOscillation, osc > 0 {
                                            session.averageVerticalOscillation = osc
                                        }
                                        try? modelContext.save()
                                    }
                                }
                            }
                            let skillService = SkillDomainService()
                            let skillScores = skillService.computeScores(from: session, score: nil)
                            for skillScore in skillScores {
                                modelContext.insert(skillScore)
                            }
                            try? modelContext.save()
                            Task {
                                await ArtifactConversionService.shared.convertAndSyncRunningSession(session)
                            }
                            WidgetDataSyncService.shared.syncRecentSessions(context: modelContext)
                            completedSession = session
                            activeSession = nil
                            activeIntervalSettings = nil
                        },
                        onDiscard: {
                            modelContext.delete(session)
                            try? modelContext.save()
                            activeSession = nil
                            activeIntervalSettings = nil
                        }
                    )
                }
            }
            .presentationBackground(Color.black)
    }

    // MARK: - Start from Config

    private func startFromConfig(_ config: RunningSetupConfig) {
        switch config.runType {
        case .standard(let type):
            let session = RunningSession(
                name: type.rawValue,
                sessionType: type,
                runMode: trackMode ? .track : .outdoor
            )
            modelContext.insert(session)
            activeSession = session

        case .interval(let settings):
            let session = RunningSession(
                name: "Interval Run",
                sessionType: .intervals,
                runMode: trackMode ? .track : .outdoor
            )
            modelContext.insert(session)
            activeIntervalSettings = settings
            activeSession = session

        case .pacer(let settings):
            let session = RunningSession(
                name: "Virtual Pacer Run",
                sessionType: .tempo,
                runMode: trackMode ? .track : .outdoor
            )
            modelContext.insert(session)
            if settings.useTargetTime && settings.targetDistance > 0 {
                VirtualPacer.shared.start(targetTime: settings.targetTime, forDistance: settings.targetDistance)
            } else {
                VirtualPacer.shared.start(targetPace: settings.targetPace)
            }
            activeSession = session
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
