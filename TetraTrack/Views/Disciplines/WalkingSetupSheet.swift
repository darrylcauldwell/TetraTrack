//
//  WalkingSetupSheet.swift
//  TetraTrack
//
//  Pre-session setup sheet for walking — route selection, target cadence,
//  audio coaching, and start button.
//

import SwiftUI
import SwiftData

struct WalkingSetupSheet: View {
    let config: RunningSetupConfig
    let onStart: (RunningSetupConfig, WalkingRoute?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WalkingRoute.lastWalkedDate, order: .reverse) private var savedRoutes: [WalkingRoute]

    @State private var showingCountdown = false
    @State private var showingAudioCoachingSettings = false
    @State private var showingNewRoute = false
    @State private var selectedRoute: WalkingRoute?
    @State private var newRouteName: String = ""
    @AppStorage("targetWalkCadence") private var targetCadence: Int = 120

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                ScrollView {
                    VStack(spacing: 32) {
                        // Discipline icon + title
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.teal.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                Image(systemName: "figure.walk")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.teal)
                            }
                            Text("Walking")
                                .font(.title2.bold())
                            Text("Track cadence, symmetry & routes")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)

                        // Start button
                        Button {
                            showingCountdown = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.teal)
                                    .frame(width: 80, height: 80)
                                    .shadow(color: Color.teal.opacity(0.4), radius: 12, y: 4)
                                Image(systemName: "play.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.white)
                            }
                        }

                        // Watch status card
                        if WatchConnectivityManager.shared.isPaired {
                            WatchStatusCard()
                                .padding(.horizontal, 20)
                        }

                        // Route selection
                        routeSelectionCard

                        // Target cadence
                        targetCadenceCard

                        // Coaching level picker
                        CoachingLevelCard(showingSettings: $showingAudioCoachingSettings)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .fullScreenCover(isPresented: $showingCountdown) {
            CountdownOverlay(
                onComplete: {
                    showingCountdown = false
                    onStart(config, selectedRoute)
                },
                onCancel: {
                    showingCountdown = false
                }
            )
            .presentationBackground(.clear)
        }
        .sheet(isPresented: $showingAudioCoachingSettings) {
            NavigationStack {
                AudioCoachingView()
            }
            .presentationBackground(Color.black)
        }
        .alert("New Route", isPresented: $showingNewRoute) {
            TextField("Route name (e.g., School Run)", text: $newRouteName)
            Button("Create") {
                if !newRouteName.isEmpty {
                    let route = WalkingRoute(name: newRouteName, startLatitude: 0, startLongitude: 0)
                    modelContext.insert(route)
                    selectedRoute = route
                    newRouteName = ""
                }
            }
            Button("Cancel", role: .cancel) {
                newRouteName = ""
            }
        }
        .presentationBackground(Color.black)
    }

    // MARK: - Route Selection Card

    private var routeSelectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map")
                    .foregroundStyle(.teal)
                Text("Route")
                    .font(.headline)
                Text("Optional")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Save a route for walks you do regularly to track your progress over time.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !savedRoutes.isEmpty {
                // Saved routes list
                ForEach(savedRoutes.prefix(5)) { route in
                    Button {
                        if selectedRoute?.id == route.id {
                            selectedRoute = nil
                        } else {
                            selectedRoute = route
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(route.name)
                                    .font(.subheadline.bold())
                                HStack(spacing: 8) {
                                    Text(route.formattedDistance)
                                    Text("\(route.walkCount) walks")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedRoute?.id == route.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.teal)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedRoute?.id == route.id ? Color.teal.opacity(0.15) : Color.white.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // New route button
            Button {
                showingNewRoute = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("New Route")
                }
                .font(.subheadline)
                .foregroundStyle(.teal)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    // MARK: - Target Cadence Card

    private var targetCadenceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "metronome")
                    .foregroundStyle(.teal)
                Text("Target Cadence")
                    .font(.headline)
            }

            HStack {
                Text("\(targetCadence) SPM")
                    .font(.system(.title3, design: .rounded))
                    .monospacedDigit()
                    .bold()

                Spacer()

                Stepper("", value: $targetCadence, in: 90...160, step: 5)
                    .labelsHidden()
            }

            Text("120 SPM is a typical comfortable walking cadence.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
}
