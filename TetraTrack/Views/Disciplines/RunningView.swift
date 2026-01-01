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
    @Query private var profiles: [RiderProfile]
    @Query private var sharingContacts: [SharingRelationship]
    @Query private var walkingRoutes: [WalkingRoute]

    @State private var activeSession: RunningSession?
    @State private var activeIntervalSettings: IntervalSettings?
    @State private var activeProgramIntervals: [ProgramInterval]?
    @State private var pendingSetup: RunningSetupConfig?
    @State private var configToStart: RunningSetupConfig?
    @State private var completedSession: RunningSession?
    @State private var pendingWalkingSetup: RunningSetupConfig?
    @State private var selectedWalkingRoute: WalkingRoute?
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
                title: "Walking",
                subtitle: "Cadence, symmetry & routes",
                icon: "figure.walk",
                color: .teal,
                action: {
                    pendingWalkingSetup = RunningSetupConfig(
                        runType: .standard(.walking),
                        title: "Walking",
                        icon: "figure.walk",
                        color: .teal,
                        runMode: .outdoor
                    )
                }
            ),
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
            .navigationDestination(item: $completedSession) { session in
                if session.sessionType == .walking {
                    WalkingDetailView(session: session)
                } else {
                    RunningSessionDetailView(session: session)
                }
            }
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
            .fullScreenCover(item: $pendingWalkingSetup) { config in
                WalkingSetupSheet(
                    config: config,
                    onStart: { finalConfig, route in
                        selectedWalkingRoute = route
                        pendingWalkingSetup = nil
                        startWalkingFromConfig(finalConfig, route: route)
                    }
                )
            }
            .fullScreenCover(item: $activeSession) { session in
                if session.sessionType == .walking {
                    WalkingLiveView(
                        session: session,
                        selectedRoute: selectedWalkingRoute,
                        shareWithFamily: shareWithFamily,
                        targetCadence: session.targetCadence,
                        onEnd: {
                            // Compute walking biomechanics scores
                            let walkingService = WalkingAnalysisService()
                            let scores = walkingService.computeScores(from: session)
                            walkingService.applyScores(scores, to: session)

                            // Fetch HealthKit walking + running metrics
                            Task {
                                let healthKit = HealthKitManager.shared
                                try? await Task.sleep(for: .seconds(2))
                                if let endDate = session.endDate {
                                    let metrics = await healthKit.fetchRunningMetrics(from: session.startDate, to: endDate)
                                    let walkingMetrics = await healthKit.fetchWalkingMetrics(from: session.startDate, to: endDate)
                                    await MainActor.run {
                                        session.healthKitAsymmetry = metrics.asymmetryPercentage
                                        session.healthKitStrideLength = metrics.strideLength
                                        session.healthKitStepCount = metrics.stepCount

                                        // Walking-specific metrics
                                        session.healthKitDoubleSupportPercentage = walkingMetrics.doubleSupportPercentage
                                        session.healthKitWalkingSpeed = walkingMetrics.walkingSpeed
                                        session.healthKitWalkingStepLength = walkingMetrics.walkingStepLength
                                        session.healthKitWalkingSteadiness = walkingMetrics.walkingSteadiness
                                        session.healthKitWalkingHeartRateAvg = walkingMetrics.walkingHeartRateAverage

                                        // Recompute symmetry with HealthKit data
                                        if metrics.asymmetryPercentage != nil || walkingMetrics.hasData {
                                            let updatedScores = walkingService.computeScores(from: session)
                                            walkingService.applyScores(updatedScores, to: session)
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
                            // Route matching and attempt recording
                            let routeService = RouteMatchingService()
                            if let route = selectedWalkingRoute {
                                // User pre-selected a route - record attempt
                                if let comparison = routeService.recordAttempt(route: route, session: session, context: modelContext) {
                                    if let encoded = try? JSONEncoder().encode(comparison) {
                                        session.routeComparisonData = encoded
                                    }
                                }
                            } else if (session.locationPoints ?? []).count >= 5 {
                                // Auto-detect matching route
                                if let matchedRoute = routeService.matchRoute(session: session, existingRoutes: walkingRoutes, context: modelContext) {
                                    if let comparison = routeService.recordAttempt(route: matchedRoute, session: session, context: modelContext) {
                                        if let encoded = try? JSONEncoder().encode(comparison) {
                                            session.routeComparisonData = encoded
                                        }
                                    }
                                }
                            }

                            try? modelContext.save()
                            Task {
                                await ArtifactConversionService.shared.convertAndSyncRunningSession(session)
                            }
                            WidgetDataSyncService.shared.syncRecentSessions(context: modelContext)
                            completedSession = session
                            activeSession = nil
                            selectedWalkingRoute = nil
                        },
                        onDiscard: {
                            modelContext.delete(session)
                            try? modelContext.save()
                            activeSession = nil
                            selectedWalkingRoute = nil
                        }
                    )
                } else if session.sessionType == .treadmill {
                    TreadmillLiveView(
                        session: session,
                        targetCadence: session.targetCadence,
                        onEnd: {
                            // HealthKit workout save is handled by WorkoutLifecycleService.endAndSave()
                            // Fetch HealthKit running metrics from Apple Watch
                            Task {
                                let healthKit = HealthKitManager.shared
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
                                        session.healthKitHRRecoveryOneMinute = metrics.heartRateRecoveryOneMinute

                                        if let gct = metrics.groundContactTime, gct > 0 {
                                            session.averageGroundContactTime = gct
                                        }
                                        if let osc = metrics.verticalOscillation, osc > 0 {
                                            session.averageVerticalOscillation = osc
                                        }
                                        try? modelContext.save()
                                    }

                                    // Delayed re-fetch for HR recovery (Apple may need time)
                                    if metrics.heartRateRecoveryOneMinute == nil {
                                        try? await Task.sleep(for: .seconds(30))
                                        let hrRecovery = await healthKit.fetchHeartRateRecoveryOneMinute(from: session.startDate, to: endDate)
                                        if let hrRecovery {
                                            await MainActor.run {
                                                session.healthKitHRRecoveryOneMinute = hrRecovery
                                                try? modelContext.save()
                                            }
                                        }
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
                        }
                    )
                } else {
                    RunningLiveView(
                        session: session,
                        intervalSettings: activeIntervalSettings,
                        programIntervals: activeProgramIntervals,
                        targetDistance: session.sessionType == .timeTrial ? selectedLevel.runDistance : 0,
                        shareWithFamily: shareWithFamily,
                        targetCadence: session.targetCadence,
                        onEnd: {
                            // HealthKit workout save is handled by WorkoutLifecycleService.endAndSave()
                            // Fetch HealthKit running metrics from Apple Watch
                            Task {
                                let healthKit = HealthKitManager.shared
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
                                        session.healthKitHRRecoveryOneMinute = metrics.heartRateRecoveryOneMinute

                                        // Update watch-derived metrics if HealthKit has better data
                                        if let gct = metrics.groundContactTime, gct > 0 {
                                            session.averageGroundContactTime = gct
                                        }
                                        if let osc = metrics.verticalOscillation, osc > 0 {
                                            session.averageVerticalOscillation = osc
                                        }
                                        try? modelContext.save()
                                    }

                                    // Delayed re-fetch for HR recovery (Apple may need time)
                                    if metrics.heartRateRecoveryOneMinute == nil {
                                        try? await Task.sleep(for: .seconds(30))
                                        let hrRecovery = await healthKit.fetchHeartRateRecoveryOneMinute(from: session.startDate, to: endDate)
                                        if let hrRecovery {
                                            await MainActor.run {
                                                session.healthKitHRRecoveryOneMinute = hrRecovery
                                                try? modelContext.save()
                                            }
                                        }
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

                            // Analyze segment PBs for outdoor GPS runs longer than 1200m
                            if session.runMode == .outdoor && session.totalDistance > 1200 {
                                Task { @MainActor in
                                    nonisolated(unsafe) let points = session.sortedLocationPoints
                                    let pbs = RunningPersonalBests.shared
                                    let segmentResults = SegmentPBAnalyzer.analyze(
                                        locationPoints: points,
                                        totalDistance: session.totalDistance,
                                        personalBests: pbs
                                    )
                                    if !segmentResults.isEmpty {
                                        await MainActor.run {
                                            session.segmentPBResults = segmentResults
                                            try? modelContext.save()
                                        }
                                    }
                                }
                            }

                            completedSession = session
                            activeSession = nil
                            activeIntervalSettings = nil
                            activeProgramIntervals = nil
                        },
                        onDiscard: {
                            modelContext.delete(session)
                            try? modelContext.save()
                            activeSession = nil
                            activeIntervalSettings = nil
                            activeProgramIntervals = nil
                        }
                    )
                }
            }
            .presentationBackground(Color.black)
    }

    // MARK: - Start from Config

    @AppStorage("targetWalkCadence") private var targetWalkCadence: Int = 120

    private func startWalkingFromConfig(_ config: RunningSetupConfig, route: WalkingRoute?) {
        let session = RunningSession(
            name: route?.name ?? "Walking",
            sessionType: .walking,
            runMode: .outdoor
        )
        session.targetCadence = targetWalkCadence
        if let route = route {
            session.matchedRouteId = route.id
        }
        modelContext.insert(session)
        selectedWalkingRoute = route
        activeSession = session
    }

    private func startProgramSession(_ programSession: ProgramSession) {
        let session = RunningSession(
            name: programSession.name,
            sessionType: .easy,
            runMode: .outdoor
        )
        session.programSessionId = programSession.id
        modelContext.insert(session)
        activeProgramIntervals = programSession.sessionDefinition
        activeSession = session
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
            modelContext.insert(session)
            activeSession = session

        case .interval(let settings):
            let session = RunningSession(
                name: "Interval Run",
                sessionType: .intervals,
                runMode: config.runMode
            )
            session.targetCadence = config.targetCadence
            modelContext.insert(session)
            activeIntervalSettings = settings
            activeSession = session

        case .pacer(let settings):
            let session = RunningSession(
                name: "Virtual Pacer Run",
                sessionType: .tempo,
                runMode: config.runMode
            )
            session.targetCadence = config.targetCadence
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
