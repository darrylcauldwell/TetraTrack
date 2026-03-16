//
//  PostSessionInsightsView.swift
//  TetraTrack
//
//  Automatically shown after a session ends.
//  Fetches the completed session model from SwiftData and
//  dispatches to the correct discipline's insights view.
//

import SwiftUI
import SwiftData

struct PostSessionInsightsView: View {
    let info: SessionTracker.CompletedSessionInfo

    @Environment(SessionTracker.self) private var tracker: SessionTracker?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            insightsContent
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            tracker?.dismissPostSession()
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var insightsContent: some View {
        switch info.disciplineType {
        case "ride":
            if let ride: Ride = fetchModel() {
                RideInsightsView(ride: ride)
            } else {
                fallbackView
            }

        case "running":
            if let session: RunningSession = fetchModel() {
                RunningInsightsView(session: session)
            } else {
                fallbackView
            }

        case "walking":
            if let session: RunningSession = fetchModel() {
                WalkingInsightsView(session: session)
            } else {
                fallbackView
            }

        case "swimming":
            if let session: SwimmingSession = fetchModel() {
                SwimmingInsightsView(session: session)
            } else {
                fallbackView
            }

        case "shooting":
            if let session: ShootingSession = fetchModel() {
                ShootingGRACEInsightsView(session: session)
            } else {
                fallbackView
            }

        default:
            fallbackView
        }
    }

    private func fetchModel<T: PersistentModel>() -> T? {
        modelContext.model(for: info.modelID) as? T
    }

    private var fallbackView: some View {
        ContentUnavailableView(
            "Session Complete",
            systemImage: "checkmark.circle",
            description: Text("Your session has been saved.")
        )
        .navigationTitle("Session Insights")
    }
}
