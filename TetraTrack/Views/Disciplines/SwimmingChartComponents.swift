//
//  SwimmingChartComponents.swift
//  TetraTrack
//
//  Charts for swimming split analysis and SWOLF tracking
//

import SwiftUI
import Charts

// MARK: - Split Chart Data

struct SwimmingSplitData: Identifiable {
    let id = UUID()
    let lengthNumber: Int
    let pace: TimeInterval // seconds per 100m
    let zone: SwimmingPaceZone?
}

// MARK: - Swimming Split Chart

struct SwimmingSplitChart: View {
    let lengthTimes: [TimeInterval]
    let poolLength: Double
    var thresholdPace: TimeInterval = 0
    var compact: Bool = false

    private var splitData: [SwimmingSplitData] {
        lengthTimes.enumerated().map { index, time in
            let pace = time / (poolLength / 100) // seconds per 100m
            let zone: SwimmingPaceZone? = thresholdPace > 0
                ? SwimmingPaceZone.zone(for: pace, thresholdPace: thresholdPace)
                : nil
            return SwimmingSplitData(lengthNumber: index + 1, pace: pace, zone: zone)
        }
    }

    private var averagePace: TimeInterval {
        guard !splitData.isEmpty else { return 0 }
        return splitData.map(\.pace).reduce(0, +) / Double(splitData.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !compact {
                Text("Split Times")
                    .font(.headline)
            }

            Chart {
                ForEach(splitData) { split in
                    LineMark(
                        x: .value("Length", split.lengthNumber),
                        y: .value("Pace", split.pace)
                    )
                    .foregroundStyle(splitLineColor(for: split))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Length", split.lengthNumber),
                        y: .value("Pace", split.pace)
                    )
                    .foregroundStyle(splitPointColor(for: split))
                    .symbolSize(compact ? 20 : 40)
                }

                // Average pace line
                if averagePace > 0 {
                    RuleMark(y: .value("Average", averagePace))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .annotation(position: .top, alignment: .trailing) {
                            if !compact {
                                Text("Avg")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                }
            }
            .frame(height: compact ? 100 : 200)
            .chartXScale(domain: 0...splitData.count)
            .chartXAxis {
                AxisMarks(values: Array(0...splitData.count)) { value in
                    AxisValueLabel {
                        if let num = value.as(Int.self) {
                            Text("\(num)")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let pace = value.as(Double.self) {
                            Text(formatPace(pace))
                                .font(.caption2)
                        }
                    }
                    if !compact {
                        AxisGridLine()
                    }
                }
            }
            .chartYScale(domain: yAxisDomain)
        }
    }

    private var yAxisDomain: ClosedRange<Double> {
        let paces = splitData.map(\.pace)
        guard let minPace = paces.min(), let maxPace = paces.max() else {
            return 60...180
        }
        let padding = max((maxPace - minPace) * 0.2, 5)
        return max(0, minPace - padding)...(maxPace + padding)
    }

    private func splitLineColor(for split: SwimmingSplitData) -> Color {
        if let zone = split.zone {
            return zoneColor(zone)
        }
        return .blue
    }

    private func splitPointColor(for split: SwimmingSplitData) -> Color {
        if let zone = split.zone {
            return zoneColor(zone)
        }
        return .blue
    }

    private func zoneColor(_ zone: SwimmingPaceZone) -> Color {
        switch zone {
        case .recovery: return .gray
        case .endurance: return .blue
        case .tempo: return .green
        case .threshold: return .yellow
        case .speed: return .red
        }
    }

    private func formatPace(_ secondsPer100m: Double) -> String {
        let mins = Int(secondsPer100m) / 60
        let secs = Int(secondsPer100m) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - SWOLF Chart Data

struct SwimmingSWOLFData: Identifiable {
    let id = UUID()
    let lengthNumber: Int
    let swolf: Int
}

// MARK: - Swimming SWOLF Chart

struct SwimmingSWOLFChart: View {
    let lengthTimes: [TimeInterval]
    let lengthStrokes: [Int]
    var compact: Bool = false

    private var swolfData: [SwimmingSWOLFData] {
        zip(lengthTimes, lengthStrokes).enumerated().map { index, pair in
            let swolf = Int(pair.0) + pair.1
            return SwimmingSWOLFData(lengthNumber: index + 1, swolf: swolf)
        }
    }

    private var averageSWOLF: Double {
        guard !swolfData.isEmpty else { return 0 }
        return Double(swolfData.map(\.swolf).reduce(0, +)) / Double(swolfData.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !compact {
                Text("SWOLF per Length")
                    .font(.headline)
            }

            Chart {
                ForEach(swolfData) { data in
                    BarMark(
                        x: .value("Length", data.lengthNumber),
                        y: .value("SWOLF", data.swolf)
                    )
                    .foregroundStyle(swolfColor(for: data.swolf))
                }

                // Average line
                if averageSWOLF > 0 {
                    RuleMark(y: .value("Average", averageSWOLF))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .annotation(position: .top, alignment: .trailing) {
                            if !compact {
                                Text(String(format: "Avg: %.0f", averageSWOLF))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                }
            }
            .frame(height: compact ? 100 : 200)
            .chartXScale(domain: 0...swolfData.count)
            .chartXAxis {
                AxisMarks(values: Array(0...swolfData.count)) { value in
                    AxisValueLabel {
                        if let num = value.as(Int.self) {
                            Text("\(num)")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .font(.caption2)
                    if !compact {
                        AxisGridLine()
                    }
                }
            }
        }
    }

    private func swolfColor(for swolf: Int) -> Color {
        if swolf < 40 { return .green }
        if swolf < 55 { return .yellow }
        return .orange
    }
}

// MARK: - Lap Split Chart (from saved laps)

struct SwimmingLapSplitChart: View {
    let laps: [SwimmingLap]
    var thresholdPace: TimeInterval = 0

    var body: some View {
        SwimmingSplitChart(
            lengthTimes: laps.map(\.duration),
            poolLength: laps.first?.distance ?? 25.0,
            thresholdPace: thresholdPace,
            compact: false
        )
    }
}

struct SwimmingLapSWOLFChart: View {
    let laps: [SwimmingLap]

    var body: some View {
        SwimmingSWOLFChart(
            lengthTimes: laps.map(\.duration),
            lengthStrokes: laps.map(\.strokeCount),
            compact: false
        )
    }
}

// MARK: - Stroke Rate Per Lap Chart

struct StrokeRatePerLapChart: View {
    let laps: [SwimmingLap]

    private var strokeRateData: [(lap: Int, strokeRate: Double, swolf: Int)] {
        laps.enumerated().compactMap { index, lap in
            guard lap.duration > 0, lap.strokeCount > 0 else { return nil }
            let rate = Double(lap.strokeCount) / (lap.duration / 60.0)  // strokes per minute
            return (lap: index + 1, strokeRate: rate, swolf: lap.swolf)
        }
    }

    private var hasFatigue: Bool {
        guard strokeRateData.count >= 4 else { return false }
        let mid = strokeRateData.count / 2
        let firstHalfAvg = strokeRateData.prefix(mid).map(\.strokeRate).reduce(0, +) / Double(mid)
        let secondHalfAvg = strokeRateData.suffix(from: mid).map(\.strokeRate).reduce(0, +) / Double(strokeRateData.count - mid)
        // Increasing stroke rate with same/slower pace = fatigue
        return secondHalfAvg > firstHalfAvg * 1.05
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Stroke Rate Trend")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if hasFatigue {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                        Text("Fatigue detected")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.orange)
                }
            }

            if strokeRateData.count >= 2 {
                Chart {
                    ForEach(strokeRateData, id: \.lap) { data in
                        BarMark(
                            x: .value("Lap", "Lap \(data.lap)"),
                            y: .value("Rate", data.strokeRate)
                        )
                        .foregroundStyle(strokeRateColor(data.strokeRate, lap: data.lap))
                    }
                }
                .chartYAxisLabel("Strokes/min")
                .frame(height: 120)

                // SWOLF trend
                if strokeRateData.contains(where: { $0.swolf > 0 }) {
                    Chart {
                        ForEach(strokeRateData.filter { $0.swolf > 0 }, id: \.lap) { data in
                            LineMark(
                                x: .value("Lap", "Lap \(data.lap)"),
                                y: .value("SWOLF", data.swolf)
                            )
                            .foregroundStyle(.cyan)

                            PointMark(
                                x: .value("Lap", "Lap \(data.lap)"),
                                y: .value("SWOLF", data.swolf)
                            )
                            .foregroundStyle(.cyan)
                        }
                    }
                    .chartYAxisLabel("SWOLF")
                    .frame(height: 80)

                    Text("SWOLF = time + strokes per length (lower = more efficient)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text("Need at least 2 laps for analysis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func strokeRateColor(_ rate: Double, lap: Int) -> Color {
        let isLate = Double(lap) / Double(max(strokeRateData.count, 1)) > 0.66
        if hasFatigue && isLate { return .orange }
        return .blue
    }
}

// MARK: - Previews

#Preview("Stroke Rate Chart") {
    StrokeRatePerLapChart(laps: [])
        .padding()
}

#Preview("Split Chart") {
    SwimmingSplitChart(
        lengthTimes: [35, 33, 34, 36, 32, 35, 37, 34],
        poolLength: 25.0,
        thresholdPace: 130
    )
    .padding()
}

#Preview("Split Chart Compact") {
    SwimmingSplitChart(
        lengthTimes: [35, 33, 34, 36, 32],
        poolLength: 25.0,
        compact: true
    )
    .padding()
}

#Preview("SWOLF Chart") {
    SwimmingSWOLFChart(
        lengthTimes: [35, 33, 34, 36, 32, 35, 37, 34],
        lengthStrokes: [18, 17, 18, 19, 16, 18, 20, 17]
    )
    .padding()
}
