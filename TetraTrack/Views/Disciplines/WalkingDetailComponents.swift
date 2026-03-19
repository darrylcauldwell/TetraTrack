//
//  WalkingDetailComponents.swift
//  TetraTrack
//
//  Reusable components for walking detail views:
//  steadiness gauges, route comparison, trend chart, running correlation
//

import SwiftUI
import Charts

// MARK: - Walking Steadiness Card

struct WalkingSteadinessCard: View {
    let postureScore: Double
    let rhythmScore: Double
    let stabilityScore: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Biomechanics")
                .font(.headline)

            HStack(spacing: 16) {
                gaugeView(
                    label: "Posture",
                    score: postureScore,
                    icon: "figure.stand",
                    color: .orange
                )
                gaugeView(
                    label: "Rhythm",
                    score: rhythmScore,
                    icon: "metronome",
                    color: .indigo
                )
                gaugeView(
                    label: "Stability",
                    score: stabilityScore,
                    icon: "figure.stand",
                    color: .teal
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    private func gaugeView(label: String, score: Double, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)
                Circle()
                    .trim(from: 0, to: min(1, score / 100))
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Image(systemName: icon)
                        .font(.caption2)
                        .foregroundStyle(color)
                    Text(String(format: "%.0f", score))
                        .font(.system(.caption, design: .rounded))
                        .bold()
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Route Comparison Card

struct RouteComparisonCard: View {
    let comparison: WalkingRouteComparison

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "repeat")
                    .foregroundStyle(.teal)
                Text("vs Previous (\(comparison.routeName))")
                    .font(.headline)
            }

            Text("Walk #\(comparison.attemptNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                deltaMetric(
                    label: "Pace",
                    delta: comparison.paceDelta,
                    format: { String(format: "%+.0fs/km", $0) },
                    isLowerBetter: true
                )
                deltaMetric(
                    label: "Duration",
                    delta: comparison.durationDelta,
                    format: { String(format: "%+.0fs", $0) },
                    isLowerBetter: true
                )
                deltaMetric(
                    label: "Cadence",
                    delta: comparison.cadenceDelta,
                    format: { String(format: "%+.0f SPM", $0) },
                    isLowerBetter: false
                )
            }

            if comparison.symmetryDelta != 0 || comparison.rhythmDelta != 0 || comparison.stabilityDelta != 0 {
                Divider()
                    .background(Color.white.opacity(0.1))

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    deltaMetric(
                        label: "Symmetry",
                        delta: comparison.symmetryDelta,
                        format: { String(format: "%+.0f", $0) },
                        isLowerBetter: false
                    )
                    deltaMetric(
                        label: "Rhythm",
                        delta: comparison.rhythmDelta,
                        format: { String(format: "%+.0f", $0) },
                        isLowerBetter: false
                    )
                    deltaMetric(
                        label: "Stability",
                        delta: comparison.stabilityDelta,
                        format: { String(format: "%+.0f", $0) },
                        isLowerBetter: false
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

    private func deltaMetric(label: String, delta: Double, format: (Double) -> String, isLowerBetter: Bool) -> some View {
        VStack(spacing: 4) {
            let isImproved = isLowerBetter ? delta < 0 : delta > 0
            let color: Color = abs(delta) < 0.5 ? .gray : (isImproved ? .green : .orange)
            Text(format(delta))
                .font(.system(.subheadline, design: .rounded))
                .monospacedDigit()
                .bold()
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Walking Trend Chart

struct WalkingTrendChart: View {
    let trends: [WalkingRouteTrend]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.teal)
                Text("Route Trends")
                    .font(.headline)
            }

            Chart(trends) { trend in
                LineMark(
                    x: .value("Date", trend.date),
                    y: .value("Pace", trend.pacePerKm / 60) // minutes per km
                )
                .foregroundStyle(.teal)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", trend.date),
                    y: .value("Pace", trend.pacePerKm / 60)
                )
                .foregroundStyle(.teal)
                .symbolSize(30)
            }
            .chartYAxisLabel("Pace (min/km)")
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 150)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Running Correlation Card

struct RunningCorrelationCard: View {
    let readinessScore: Double
    let readinessLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.run")
                    .foregroundStyle(.green)
                Text("Running Readiness")
                    .font(.headline)
            }

            HStack(spacing: 16) {
                // Readiness gauge
                ZStack {
                    Circle()
                        .stroke(Color.green.opacity(0.2), lineWidth: 8)
                        .frame(width: 70, height: 70)
                    Circle()
                        .trim(from: 0, to: min(1, readinessScore / 100))
                        .stroke(readinessColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text(String(format: "%.0f", readinessScore))
                            .font(.system(.title3, design: .rounded))
                            .bold()
                        Text(readinessLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Walking biomechanics predict running form quality.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if readinessScore >= 80 {
                        Text("Your gait is strong and symmetrical. Great foundation for running.")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else if readinessScore >= 60 {
                        Text("Solid walking form. Keep working on consistency.")
                            .font(.caption)
                            .foregroundStyle(.teal)
                    } else if readinessScore >= 40 {
                        Text("Some asymmetry detected. Focus on even strides.")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    } else {
                        Text("Building walking fitness. Keep at it!")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    private var readinessColor: Color {
        switch readinessScore {
        case 80...: return .green
        case 60..<80: return .teal
        case 40..<60: return .yellow
        default: return .orange
        }
    }
}
