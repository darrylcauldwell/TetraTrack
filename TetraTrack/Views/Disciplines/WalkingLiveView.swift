//
//  WalkingLiveView.swift
//  TetraTrack
//
//  Live walking session view with cadence display, symmetry indicator,
//  and route-colored map.
//

import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import os

struct WalkingLiveView: View {
    @Environment(GPSSessionTracker.self) private var gpsTracker: GPSSessionTracker?
    @Environment(LocationManager.self) private var locationManager: LocationManager?
    @Environment(SessionTracker.self) private var tracker: SessionTracker?

    @State private var showingCancelConfirmation = false
    @State private var selectedTab: RunningTab = .stats

    var body: some View {
        GeometryReader { _ in
            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // Main content - swipeable stats/map
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
        .overlay(alignment: .bottom) {
            if tracker?.sessionState == .tracking || tracker?.sessionState == .paused {
                FloatingControlPanel(
                    disciplineIcon: tracker?.activePlugin?.disciplineIcon ?? "figure.walk",
                    disciplineColor: tracker?.activePlugin?.disciplineColor ?? .teal,
                    onStop: { tracker?.stopSession() }
                )
            }
        }
        .confirmationDialog("End Walking Session?", isPresented: $showingCancelConfirmation, titleVisibility: .visible) {
            Button("Save Session") {
                tracker?.stopSession()
            }
            Button("Discard", role: .destructive) {
                tracker?.discardSession()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Plugin Access

    private var walkingPlugin: WalkingPlugin? {
        tracker?.plugin(as: WalkingPlugin.self)
    }

    private var targetCadence: Int {
        walkingPlugin?.targetCadence ?? 120
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            // Page indicators
            HStack(spacing: 6) {
                Circle()
                    .fill(selectedTab == .stats ? Color.teal : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(selectedTab == .map ? Color.teal : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }

            Spacer()

            // Route match banner
            if let routeName = walkingPlugin?.matchedRouteName {
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

            // Close button
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

            // Elapsed time
            VStack(spacing: 4) {
                Text("WALKING")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(formatTime(tracker?.elapsedTime ?? 0))
                    .scaledFont(size: 56, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                    .monospacedDigit()
            }

            // Distance
            VStack(spacing: 4) {
                Text(formatDistance(tracker?.totalDistance ?? 0))
                    .scaledFont(size: 48, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                    .monospacedDigit()
                    .foregroundStyle(.teal)
                Text("distance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Cadence with target indicator
            cadenceDisplay

            // Secondary metrics row
            HStack(spacing: 24) {
                metricColumn(
                    value: (tracker?.totalDistance ?? 0) > 50 ? formatPace((tracker?.elapsedTime ?? 0) / ((tracker?.totalDistance ?? 1) / 1000)) : "--",
                    label: "Pace"
                )
                // Heart rate with zone
                VStack(spacing: 4) {
                    Text((tracker?.currentHeartRate ?? 0) > 0 ? "\(tracker?.currentHeartRate ?? 0)" : "--")
                        .font(.system(.title3, design: .rounded))
                        .monospacedDigit()
                        .bold()
                    Text("Heart Rate")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if (tracker?.currentHeartRate ?? 0) > 0 {
                        Text(tracker?.currentHeartRateZone.name ?? "")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(heartRateZoneColor(tracker?.currentHeartRateZone ?? .zone1))
                            .clipShape(Capsule())
                    }
                }
                metricColumn(
                    value: (tracker?.elevationGain ?? 0) > 0 ? String(format: "%.0f m", tracker?.elevationGain ?? 0) : "--",
                    label: "Ascent"
                )
            }
            .glassCard(material: .thin, cornerRadius: 16, padding: 16)

            Spacer()
                .frame(minHeight: 120) // Reserve space for FloatingControlPanel
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Cadence Display

    private var cadenceDisplay: some View {
        let cadence = walkingPlugin?.currentCadence ?? 0
        return VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(cadence > 0 ? "\(cadence)" : "--")
                    .scaledFont(size: 36, weight: .bold, design: .rounded, relativeTo: .title)
                    .monospacedDigit()
                Text("SPM")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Cadence target zone bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)

                    // Target zone highlight (±10 SPM from target)
                    let zoneStart = max(0, CGFloat(targetCadence - 10 - 80) / 80.0)
                    let zoneEnd = min(1, CGFloat(targetCadence + 10 - 80) / 80.0)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.teal.opacity(0.3))
                        .frame(width: geo.size.width * (zoneEnd - zoneStart), height: 8)
                        .offset(x: geo.size.width * zoneStart)

                    // Current cadence marker
                    if cadence > 0 {
                        let position = min(1, max(0, CGFloat(cadence - 80) / 80.0))
                        Circle()
                            .fill(cadenceColor(cadence))
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
        .glassCard(material: .thin, cornerRadius: 16, padding: 16)
    }

    private func cadenceColor(_ cadence: Int) -> Color {
        guard cadence > 0 else { return .gray }
        let deviation = abs(cadence - targetCadence)
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
