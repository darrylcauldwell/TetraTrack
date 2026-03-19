//
//  WalkingDetailView.swift
//  TetraTrack
//
//  Post-session walking detail view with biomechanics dashboard,
//  route comparison, and running readiness indicator.
//

import SwiftUI
import SwiftData
import Charts
import MapKit

struct WalkingDetailView: View {
    @Bindable var session: RunningSession

    @Environment(\.modelContext) private var modelContext
    @Query private var walkingRoutes: [WalkingRoute]

    private var matchedRoute: WalkingRoute? {
        guard let routeId = session.matchedRouteId else { return nil }
        return walkingRoutes.first { $0.id == routeId }
    }

    private let analysisService = WalkingAnalysisService()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary header
                summaryHeader

                // Biomechanics dashboard
                if session.hasWalkingScores {
                    WalkingSteadinessCard(
                        postureScore: session.goodPosturePercent > 0 ? session.goodPosturePercent : session.postureStability,
                        rhythmScore: session.walkingRhythmScore,
                        stabilityScore: session.walkingStabilityScore
                    )
                }

                // Walk Insights link
                if session.hasWalkingScores || session.averageHeartRate > 0 {
                    NavigationLink(destination: WalkingInsightsView(session: session)) {
                        HStack {
                            Image(systemName: "figure.walk")
                                .font(.title2)
                                .foregroundStyle(.teal)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Session Insights")
                                    .font(.headline)
                                Text("Stability · Rhythm · Posture · Economy")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Route comparison
                if let comparison = session.routeComparison {
                    RouteComparisonCard(comparison: comparison)
                }

                // Route trend chart
                if let route = matchedRoute, route.trends.count >= 2 {
                    WalkingTrendChart(trends: route.trends)
                }

                // Running readiness
                if session.hasWalkingScores {
                    RunningCorrelationCard(
                        readinessScore: analysisService.runningReadiness(from: session),
                        readinessLabel: analysisService.runningReadinessLabel(
                            score: analysisService.runningReadiness(from: session)
                        )
                    )
                }

                // Key metrics
                metricsGrid

                // Splits
                if !session.sortedSplits.isEmpty {
                    splitsSection
                }

                // Map
                if session.hasRouteData {
                    mapSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .navigationTitle("Walking")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.black)
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        VStack(spacing: 16) {
            // Icon + route name
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(0.2))
                        .frame(width: 56, height: 56)
                    Image(systemName: "figure.walk")
                        .font(.title2)
                        .foregroundStyle(.teal)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.name.isEmpty ? "Walking" : session.name)
                        .font(.title3.bold())
                    Text(session.startDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Big metrics
            HStack(spacing: 24) {
                summaryMetric(
                    value: session.formattedDistance,
                    label: "Distance"
                )
                summaryMetric(
                    value: session.formattedDuration,
                    label: "Duration"
                )
                summaryMetric(
                    value: session.formattedPace,
                    label: "Pace"
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    private func summaryMetric(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded))
                .monospacedDigit()
                .bold()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metrics")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "metronome")
                            .font(.caption)
                            .foregroundStyle(.teal)
                        Text("Avg Cadence")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(session.averageCadence > 0 ? "\(session.averageCadence) SPM" : "--")
                        .font(.title3.bold())
                    if session.targetCadence > 0 {
                        Text("Target: \(session.targetCadence) SPM")
                            .font(.caption2)
                            .foregroundStyle(walkingCadenceTargetColor)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                metricCard(
                    icon: "heart.fill",
                    label: "Avg Heart Rate",
                    value: session.formattedAverageHeartRate
                )
                metricCard(
                    icon: "arrow.up.right",
                    label: "Ascent",
                    value: session.totalAscent > 0 ? String(format: "%.0f m", session.totalAscent) : "--"
                )
                metricCard(
                    icon: "arrow.down.right",
                    label: "Descent",
                    value: session.totalDescent > 0 ? String(format: "%.0f m", session.totalDescent) : "--"
                )
                if session.averageCadence > 0 {
                    metricCard(
                        icon: "ruler",
                        label: "Step Length",
                        value: {
                            if let stepLength = session.healthKitWalkingStepLength, stepLength > 0 {
                                return String(format: "%.2f m", stepLength)
                            }
                            return session.estimatedStrideLength > 0
                                ? String(format: "%.2f m", session.estimatedStrideLength) : "--"
                        }()
                    )
                }
                if let steps = session.healthKitStepCount {
                    metricCard(
                        icon: "shoeprints.fill",
                        label: "Steps",
                        value: "\(steps)"
                    )
                }
                if let doubleSupport = session.healthKitDoubleSupportPercentage, doubleSupport > 0 {
                    metricCard(
                        icon: "figure.stand",
                        label: "Double Support",
                        value: String(format: "%.1f%%", doubleSupport)
                    )
                }
                if let walkSpeed = session.healthKitWalkingSpeed, walkSpeed > 0 {
                    metricCard(
                        icon: "speedometer",
                        label: "Walking Speed",
                        value: String(format: "%.2f m/s", walkSpeed)
                    )
                }
                if let steadiness = session.healthKitWalkingSteadiness, steadiness > 0 {
                    metricCard(
                        icon: "figure.walk.motion",
                        label: "Steadiness",
                        value: String(format: "%.0f%%", steadiness)
                    )
                }
                if let walkHR = session.healthKitWalkingHeartRateAvg, walkHR > 0 {
                    metricCard(
                        icon: "heart.text.square",
                        label: "Walking HR Avg",
                        value: String(format: "%.0f bpm", walkHR)
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    private var walkingCadenceTargetColor: Color {
        guard session.averageCadence > 0, session.targetCadence > 0 else { return .secondary }
        let deviation = abs(session.averageCadence - session.targetCadence)
        if deviation <= 5 { return .green }
        if deviation <= 10 { return .yellow }
        return .orange
    }

    private func metricCard(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.teal)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(.body, design: .rounded))
                .monospacedDigit()
                .bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - Splits

    private var splitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Splits")
                .font(.headline)

            ForEach(session.sortedSplits, id: \.id) { split in
                HStack {
                    Text("km \(split.orderIndex + 1)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .leading)

                    Text(split.formattedPace)
                        .font(.system(.body, design: .rounded))
                        .monospacedDigit()
                        .bold()

                    Spacer()

                    if split.cadence > 0 {
                        Text("\(split.cadence) SPM")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if split.heartRate > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                            Text("\(split.heartRate)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Map

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Route")
                .font(.headline)

            SessionRouteMapView(
                coordinates: session.coordinates,
                routeColors: .solid(.teal)
            )
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}
