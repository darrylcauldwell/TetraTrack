//
//  WalkingDetailView.swift
//  TetraTrack
//
//  Unified walking detail view — used for both post-session insights
//  and training history. Shows biomechanical pillar analysis, metrics,
//  splits, map, route comparison, and running readiness.
//

import SwiftUI
import SwiftData
import Charts
import MapKit

struct WalkingDetailView: View {
    @Bindable var session: RunningSession

    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var walkingRoutes: [WalkingRoute]

    private var matchedRoute: WalkingRoute? {
        guard let routeId = session.matchedRouteId else { return nil }
        return walkingRoutes.first { $0.id == routeId }
    }

    private let analysisService = WalkingAnalysisService()

    // MARK: - Biomechanical Scores

    private var stabilityScore: Double {
        session.walkingStabilityScore
    }

    private var rhythmScore: Double {
        session.walkingRhythmScore
    }

    private var postureScore: Double {
        session.goodPosturePercent > 0 ? session.goodPosturePercent : session.postureStability
    }

    private var economyScore: Double {
        var total: Double = 0
        var weight: Double = 0

        if session.totalDistance > 0 && session.totalDuration > 0 {
            let avgSpeed = session.totalDistance / session.totalDuration
            if avgSpeed > 0 {
                if avgSpeed >= 1.1 && avgSpeed <= 1.5 { total += 85 * 0.5 }
                else if avgSpeed >= 0.9 && avgSpeed <= 1.7 { total += 70 * 0.5 }
                else { total += 50 * 0.5 }
                weight += 0.5
            }
        }

        if session.averageCadence > 0 && session.totalDistance > 0 && session.totalDuration > 0 {
            let stepsPerMinute = Double(session.averageCadence)
            let metersPerMinute = session.totalDistance / (session.totalDuration / 60)
            if metersPerMinute > 0 {
                let stepsPerMeter = stepsPerMinute / metersPerMinute
                if stepsPerMeter < 1.5 { total += 85 * 0.5 }
                else if stepsPerMeter < 2.0 { total += 70 * 0.5 }
                else { total += 50 * 0.5 }
                weight += 0.5
            }
        }

        return weight > 0 ? total / weight : 0
    }

    private var physiologyScore: Double {
        guard session.averageHeartRate > 0, session.maxHeartRate > 0 else { return 0 }

        let avgHR = Double(session.averageHeartRate)
        let maxHR = Double(session.maxHeartRate)
        guard maxHR > 0 else { return 0 }

        let efficiency = avgHR / maxHR
        let hrRange = maxHR - Double(session.minHeartRate > 0 ? session.minHeartRate : session.averageHeartRate)

        var score: Double = 0

        if efficiency < 0.75 { score += 60 }
        else if efficiency < 0.80 { score += 50 }
        else if efficiency < 0.85 { score += 40 }
        else if efficiency < 0.90 { score += 30 }
        else { score += 20 }

        if hrRange > 30 { score += 40 }
        else if hrRange > 20 { score += 32 }
        else if hrRange > 15 { score += 24 }
        else if hrRange > 10 { score += 16 }
        else { score += 10 }

        return min(score, 100)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summaryHeader

                // Biomechanical pillar analysis
                if session.hasWalkingScores || session.averageHeartRate > 0 {
                    OverallBiomechanicalScore(
                        stabilityScore: stabilityScore,
                        rhythmScore: rhythmScore,
                        economyScore: economyScore,
                        postureScore: postureScore
                    )

                    if horizontalSizeClass == .regular {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 16) {
                            stabilityCard
                            rhythmCard
                            postureCard
                            economyCard
                        }
                    } else {
                        stabilityCard
                        rhythmCard
                        postureCard
                        economyCard
                    }

                    physiologyCard
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

                // Weather
                if session.hasWeatherData {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "cloud.sun")
                            Text("Weather")
                                .font(.headline)
                        }

                        if let startWeather = session.startWeather {
                            WeatherDetailView(weather: startWeather, title: "Start Conditions")
                        }

                        if let endWeather = session.endWeather, session.startWeather?.condition != endWeather.condition {
                            WeatherChangeSummaryView(stats: session.weatherStats)
                        }
                    }
                }

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

    // MARK: - Pillar Cards

    private var stabilityCard: some View {
        let hasData = stabilityScore > 0
        let steadiness = session.healthKitWalkingSteadiness

        return PillarScoreCard(
            pillar: .stability,
            subtitle: "Gait Steadiness",
            score: stabilityScore,
            keyMetric: {
                if let steadiness, steadiness > 0 {
                    return String(format: "%.0f%% Apple Steadiness", steadiness)
                }
                if hasData { return "Score: \(Int(stabilityScore))" }
                return "No steadiness data"
            }(),
            tip: {
                if !hasData { return "Wear Apple Watch for gait steadiness analysis" }
                if stabilityScore >= 80 { return "Very steady gait — consistent pace and smooth movement" }
                if stabilityScore >= 60 { return "Good stability — minor pace fluctuations detected" }
                if stabilityScore >= 40 { return "Moderate variability — focus on posture and even terrain" }
                return "Gait unsteady — try shorter walks on flat ground and build up gradually"
            }()
        )
    }

    private var rhythmCard: some View {
        let hasData = rhythmScore > 0
        let cadence = session.averageCadence

        return PillarScoreCard(
            pillar: .rhythm,
            subtitle: "Step Tempo",
            score: rhythmScore,
            keyMetric: {
                if cadence > 0 {
                    let target = session.targetCadence > 0 ? session.targetCadence : 120
                    let diff = cadence - target
                    if diff >= 0 {
                        return "\(cadence) SPM (+\(diff) vs target)"
                    } else {
                        return "\(cadence) SPM (\(diff) vs target)"
                    }
                }
                if hasData { return "Score: \(Int(rhythmScore))" }
                return "No cadence data"
            }(),
            tip: {
                if !hasData { return "Walk for longer to capture cadence consistency data" }
                if rhythmScore >= 80 { return "Very consistent cadence — great walking rhythm" }
                if rhythmScore >= 60 { return "Good rhythm — slight cadence variation between segments" }
                if rhythmScore >= 40 { return "Moderate variation — try using a metronome app to build rhythm" }
                return "Cadence inconsistent — focus on maintaining steady step rate"
            }()
        )
    }

    private var postureCard: some View {
        let hasData = postureScore > 0
        let goodPercent = session.goodPosturePercent
        let stability = session.postureStability

        return PillarScoreCard(
            pillar: .posture,
            subtitle: "Upper Body",
            score: postureScore,
            keyMetric: {
                if goodPercent > 0 {
                    return String(format: "%.0f%% good posture", goodPercent)
                }
                if stability > 0 {
                    return String(format: "%.0f%% stability", stability)
                }
                if hasData { return "Score: \(Int(postureScore))" }
                return "Wear Apple Watch for posture tracking"
            }(),
            tip: {
                if !hasData { return "Apple Watch tracks upper body stability while walking" }
                if postureScore >= 80 { return "Excellent posture — stable upper body throughout the walk" }
                if postureScore >= 60 { return "Good posture — minor instability in some segments" }
                if postureScore >= 40 { return "Moderate instability — focus on keeping shoulders relaxed and core engaged" }
                return "Significant instability — try shorter walks with focus on upright posture"
            }()
        )
    }

    private var economyCard: some View {
        let hasData = economyScore > 0

        return PillarScoreCard(
            pillar: .economy,
            subtitle: "Gait Efficiency",
            score: economyScore,
            keyMetric: hasData ? "\(Int(economyScore))% economy" : "Needs pace + cadence",
            tip: {
                if !hasData { return "Walk with consistent pace and cadence for economy analysis" }
                if economyScore >= 80 { return "Very efficient gait — optimal speed and stride length" }
                if economyScore >= 60 { return "Good economy — minor room for improvement" }
                return "Gait efficiency low — try maintaining a natural, brisk pace"
            }()
        )
    }

    private var physiologyCard: some View {
        let hasHR = session.averageHeartRate > 0

        return PhysiologySectionCard(
            score: physiologyScore,
            keyMetric: hasHR ? "\(session.averageHeartRate) avg bpm" : "Needs heart rate",
            tip: {
                if !hasHR { return "Wear Apple Watch for heart rate efficiency analysis" }
                if physiologyScore >= 80 { return "Excellent efficiency — heart rate well controlled during walk" }
                if physiologyScore >= 60 { return "Good cardiovascular effort — steady heart rate response" }
                if physiologyScore >= 40 { return "Moderate effort — try maintaining a conversational pace" }
                return "High cardiac effort — consider shorter walks or slower pace to build base"
            }(),
            subtitle: "HR Efficiency"
        )
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
