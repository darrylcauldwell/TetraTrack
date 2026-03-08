//
//  WalkingView.swift
//  TetraTrack
//
//  Walking discipline - cadence, symmetry & route tracking
//

import SwiftUI
import SwiftData
import WidgetKit

struct WalkingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var sharingContacts: [SharingRelationship]
    @Query private var walkingRoutes: [WalkingRoute]

    @State private var activeSession: RunningSession?
    @State private var pendingWalkingSetup: RunningSetupConfig?
    @State private var selectedWalkingRoute: WalkingRoute?
    @State private var completedSession: RunningSession?
    @AppStorage("targetWalkCadence") private var targetWalkCadence: Int = 120

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
            )
        ]
    }

    var body: some View {
        DisciplineMenuView(items: menuItems)
            .navigationTitle("Walking")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $completedSession) { session in
                WalkingDetailView(session: session)
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
                WalkingLiveView(
                    session: session,
                    selectedRoute: selectedWalkingRoute,
                    shareWithFamily: shareWithFamily,
                    targetCadence: session.targetCadence,
                    onEnd: {
                        let walkingService = WalkingAnalysisService()
                        let scores = walkingService.computeScores(from: session)
                        walkingService.applyScores(scores, to: session)

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

                                    session.healthKitDoubleSupportPercentage = walkingMetrics.doubleSupportPercentage
                                    session.healthKitWalkingSpeed = walkingMetrics.walkingSpeed
                                    session.healthKitWalkingStepLength = walkingMetrics.walkingStepLength
                                    session.healthKitWalkingSteadiness = walkingMetrics.walkingSteadiness
                                    session.healthKitWalkingHeartRateAvg = walkingMetrics.walkingHeartRateAverage

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

                        let routeService = RouteMatchingService()
                        if let route = selectedWalkingRoute {
                            if let comparison = routeService.recordAttempt(route: route, session: session, context: modelContext) {
                                if let encoded = try? JSONEncoder().encode(comparison) {
                                    session.routeComparisonData = encoded
                                }
                            }
                        } else if (session.locationPoints ?? []).count >= 5 {
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
            }
            .presentationBackground(Color.black)
    }

    // MARK: - Start Walking

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
}

#Preview {
    WalkingView()
        .modelContainer(for: RunningSession.self, inMemory: true)
}
