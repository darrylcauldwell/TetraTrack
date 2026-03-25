//
//  WalkingView.swift
//  TetraTrack
//
//  Walking discipline - cadence, symmetry & route tracking
//

import SwiftUI
import SwiftData
import WidgetKit
import HealthKit

struct WalkingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionTracker.self) private var tracker: SessionTracker?
    @Query private var sharingContacts: [SharingRelationship]

    @State private var pendingWalkingSetup: RunningSetupConfig?
    @State private var selectedWalkingRoute: WalkingRoute?
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
            .sheetBackground()
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
        tracker?.isSharingWithFamily = shareWithFamily
        let plugin = WalkingPlugin(
            session: session,
            selectedRoute: route,
            targetCadence: targetWalkCadence
        )
        Task {
            await tracker?.startSession(plugin: plugin)
        }
    }
}

#Preview {
    WalkingView()
        .modelContainer(for: RunningSession.self, inMemory: true)
}
