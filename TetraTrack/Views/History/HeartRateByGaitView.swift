//
//  HeartRateByGaitView.swift
//  TetraTrack
//
//  Heart rate breakdown by gait type chart

import SwiftUI
import Charts

struct HeartRateByGaitView: View {
    let ride: Ride

    private var gaitHRData: [GaitHREntry] {
        let samples = ride.heartRateSamples
        let segments = ride.sortedGaitSegments
        guard !samples.isEmpty, !segments.isEmpty else { return [] }

        var grouped: [GaitType: [Int]] = [:]

        for sample in samples {
            if let segment = segments.first(where: { seg in
                sample.timestamp >= seg.startTime &&
                sample.timestamp <= (seg.endTime ?? seg.startTime)
            }) {
                grouped[segment.gait, default: []].append(sample.bpm)
            }
        }

        return grouped.compactMap { gait, bpms in
            guard !bpms.isEmpty else { return nil }
            let avg = bpms.reduce(0, +) / bpms.count
            let min = bpms.min() ?? avg
            let max = bpms.max() ?? avg
            return GaitHREntry(gait: gait, avgBPM: avg, minBPM: min, maxBPM: max, sampleCount: bpms.count)
        }
        .sorted { $0.gait.sortOrder < $1.gait.sortOrder }
    }

    var body: some View {
        let data = gaitHRData
        if !data.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "heart.text.clipboard")
                        .foregroundStyle(.red)
                    Text("Heart Rate by Gait")
                        .font(.headline)
                }

                Chart(data) { entry in
                    BarMark(
                        x: .value("Gait", entry.gait.rawValue),
                        y: .value("BPM", entry.avgBPM)
                    )
                    .foregroundStyle(AppColors.gait(entry.gait))
                    .annotation(position: .top) {
                        Text("\(entry.avgBPM)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .monospacedDigit()
                    }
                }
                .chartYScale(domain: yAxisDomain(data))
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let bpm = value.as(Int.self) {
                                Text("\(bpm)")
                                    .font(.caption2)
                            }
                        }
                        AxisGridLine()
                    }
                }
                .frame(height: 150)

                // Legend with min/max
                ForEach(data) { entry in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(AppColors.gait(entry.gait))
                            .frame(width: 10, height: 10)
                        Image(systemName: entry.gait.icon)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(entry.gait.rawValue)
                            .font(.caption)
                        Spacer()
                        Text("\(entry.minBPM)–\(entry.maxBPM) bpm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func yAxisDomain(_ data: [GaitHREntry]) -> ClosedRange<Int> {
        let allMin = (data.map(\.minBPM).min() ?? 60) - 10
        let allMax = (data.map(\.maxBPM).max() ?? 180) + 10
        return allMin...allMax
    }
}

// MARK: - Data Model

private struct GaitHREntry: Identifiable {
    let gait: GaitType
    let avgBPM: Int
    let minBPM: Int
    let maxBPM: Int
    let sampleCount: Int

    var id: String { gait.rawValue }
}

private extension GaitType {
    var sortOrder: Int {
        switch self {
        case .stationary: return 0
        case .walk: return 1
        case .trot: return 2
        case .canter: return 3
        case .gallop: return 4
        }
    }
}
