//
//  WalkingLiveView.swift
//  TetraTrack
//
//  Live walking session view with cadence display, symmetry indicator,
//  and route-colored map.
//
//  Session management (GPS, HealthKit, Watch, timer, splits, sharing)
//  is handled by RunningTracker — this view only owns UI layout.
//

import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import os

struct WalkingLiveView: View {
    @Bindable var session: RunningSession
    var selectedRoute: WalkingRoute?
    var shareWithFamily: Bool = false
    var targetCadence: Int = 120
    let onEnd: () -> Void
    var onDiscard: (() -> Void)?

    @Environment(RunningTracker.self) private var tracker: RunningTracker?
    @Environment(LocationManager.self) private var locationManager: LocationManager?
    @Environment(GPSSessionTracker.self) private var gpsTracker: GPSSessionTracker?

    @State private var selectedTab: RunningTab = .stats
    @State private var showingCancelConfirmation = false
    @State private var hasStartedServices = false

    // Cadence feedback timing (view-only UI concern)
    @State private var lastCadenceAnnouncementMark: Int = 0
    @State private var lastSymmetryCheckMark: Int = 0

    // Route matching state
    @State private var matchedRouteName: String?

    var body: some View {
        GeometryReader { _ in
            VStack(spacing: 0) {
                headerView
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                TabView(selection: $selectedTab) {
                    walkingStatsView
                        .tag(RunningTab.stats)

                    walkingMapView
                        .tag(RunningTab.map)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .onAppear {
            if !hasStartedServices {
                startSession()
            }
        }
        .confirmationDialog("End Walking Session?", isPresented: $showingCancelConfirmation, titleVisibility: .visible) {
            Button("Save Session") {
                tracker?.stop()
                onEnd()
            }
            Button("Discard", role: .destructive) {
                tracker?.discard()
                onDiscard?()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(selectedTab == .stats ? Color.teal : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(selectedTab == .map ? Color.teal : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }

            Spacer()

            if let routeName = matchedRouteName {
                HStack(spacing: 4) {
                    Image(systemName: "repeat")
                        .font(.caption2)
                    Text(routeName)
                        .font(.caption2.bold())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.teal.opacity(0.3)))
                .foregroundStyle(.teal)
            }

            Spacer()

            Button {
                showingCancelConfirmation = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Walking Stats View

    private var walkingStatsView: some View {
        VStack(spacing: 16) {
            Spacer()

            VStack(spacing: 4) {
                Text("WALKING")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(formatTime(tracker?.elapsedTime ?? 0))
                    .scaledFont(size: 56, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                    .monospacedDigit()
            }

            VStack(spacing: 4) {
                Text(formatDistance(tracker?.totalDistance ?? 0))
                    .scaledFont(size: 48, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                    .monospacedDigit()
                    .foregroundStyle(.teal)
                Text("distance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            cadenceDisplay

            HStack(spacing: 24) {
                metricColumn(
                    value: (tracker?.totalDistance ?? 0) > 50 ? formatPace(session.averagePace) : "--",
                    label: "Pace"
                )
                metricColumn(
                    value: (tracker?.currentHeartRate ?? 0) > 0 ? "\(tracker?.currentHeartRate ?? 0)" : "--",
                    label: "Heart Rate"
                )
                metricColumn(
                    value: (tracker?.elevationGain ?? 0) > 0 ? String(format: "%.0f m", tracker?.elevationGain ?? 0) : "--",
                    label: "Ascent"
                )
            }

            Spacer()

            controlButtons
                .padding(.bottom, 32)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Cadence Display

    private var cadenceDisplay: some View {
        let currentCadence = tracker?.currentCadence ?? 0
        return VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(currentCadence > 0 ? "\(currentCadence)" : "--")
                    .scaledFont(size: 36, weight: .bold, design: .rounded, relativeTo: .title)
                    .monospacedDigit()
                Text("SPM")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)

                    let zoneStart = max(0, CGFloat(targetCadence - 10 - 80) / 80.0)
                    let zoneEnd = min(1, CGFloat(targetCadence + 10 - 80) / 80.0)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.teal.opacity(0.3))
                        .frame(width: geo.size.width * (zoneEnd - zoneStart), height: 8)
                        .offset(x: geo.size.width * zoneStart)

                    if currentCadence > 0 {
                        let position = min(1, max(0, CGFloat(currentCadence - 80) / 80.0))
                        Circle()
                            .fill(cadenceColor)
                            .frame(width: 12, height: 12)
                            .offset(x: geo.size.width * position - 6)
                    }
                }
            }
            .frame(height: 12)
            .padding(.horizontal, 20)

            Text("Target: \(targetCadence) SPM")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var cadenceColor: Color {
        let currentCadence = tracker?.currentCadence ?? 0
        guard currentCadence > 0 else { return .gray }
        let deviation = abs(currentCadence - targetCadence)
        if deviation <= 5 { return .green }
        if deviation <= 10 { return .teal }
        if deviation <= 20 { return .yellow }
        return .orange
    }

    // MARK: - Walking Map View

    private var walkingMapView: some View {
        LiveSessionMapView(
            routeSegments: {
                let coords = gpsTracker?.routeCoordinates ?? []
                guard coords.count > 1 else { return [] }
                return [RouteSegment(coordinates: coords, color: .teal)]
            }(),
            currentLocation: locationManager?.currentLocation,
            onBack: { selectedTab = .stats }
        )
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        let isTracking = tracker?.sessionState == .tracking
        return HStack(spacing: 40) {
            Button {
                if isTracking {
                    tracker?.pause()
                } else {
                    tracker?.resume()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(isTracking ? Color.yellow : Color.teal)
                        .frame(width: 70, height: 70)
                    Image(systemName: isTracking ? "pause.fill" : "play.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.black)
                }
            }

            Button {
                showingCancelConfirmation = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 70, height: 70)
                    Image(systemName: "stop.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Helpers

    private func metricColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded))
                .monospacedDigit()
                .bold()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Session Lifecycle

    private func startSession() {
        guard !hasStartedServices else { return }
        hasStartedServices = true

        if let route = selectedRoute {
            session.matchedRouteId = route.id
            matchedRouteName = route.name
        }

        guard let tracker else {
            Log.location.error("Walking: RunningTracker not available")
            return
        }

        Task {
            await tracker.startSession(
                session,
                mode: .walking,
                shareWithFamily: shareWithFamily,
                targetCadence: targetCadence
            )
        }
    }

    // MARK: - Formatters

    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }

    private func formatPace(_ paceSecondsPerKm: TimeInterval) -> String {
        let minutes = Int(paceSecondsPerKm) / 60
        let seconds = Int(paceSecondsPerKm) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
