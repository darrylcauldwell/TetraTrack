//
//  HeartRateSummaryView.swift
//  TetraTrack
//
//  Post-ride heart rate summary card
//

import SwiftUI
import Charts

struct HeartRateSummaryView: View {
    let ride: Ride

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                Text("Heart Rate")
                    .font(.headline)
            }

            // Stats grid
            HStack(spacing: 24) {
                HeartRateStatItem(
                    title: "Average",
                    value: ride.formattedAverageHeartRate,
                    icon: "waveform.path.ecg"
                )

                HeartRateStatItem(
                    title: "Maximum",
                    value: ride.formattedMaxHeartRate,
                    icon: "arrow.up"
                )

                HeartRateStatItem(
                    title: "Minimum",
                    value: ride.formattedMinHeartRate,
                    icon: "arrow.down"
                )
            }

            // Zone breakdown
            if !ride.heartRateSamples.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Time in Zones")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HeartRateZoneChart(statistics: ride.heartRateStatistics)
                        .frame(height: 120)
                }
            }

            // Heart rate over time chart
            if ride.heartRateSamples.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Heart Rate Over Time")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HeartRateTimelineChart(samples: ride.heartRateSamples)
                        .frame(height: 150)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Heart Rate Stat Item

struct HeartRateStatItem: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Heart Rate Zone Chart

struct HeartRateZoneChart: View {
    let statistics: HeartRateStatistics

    var body: some View {
        Chart {
            ForEach(HeartRateZone.allCases, id: \.self) { zone in
                let duration = statistics.zoneDurations[zone] ?? 0
                let percentage = statistics.zonePercentage(for: zone)

                BarMark(
                    x: .value("Zone", zone.name),
                    y: .value("Duration", duration)
                )
                .foregroundStyle(zoneColor(for: zone))
                .annotation(position: .top) {
                    if percentage > 0 {
                        Text(String(format: "%.0f%%", percentage))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let seconds = value.as(TimeInterval.self) {
                        Text(formatDuration(seconds))
                            .font(.caption2)
                    }
                }
            }
        }
    }

    private func zoneColor(for zone: HeartRateZone) -> Color {
        switch zone {
        case .zone1: return .gray
        case .zone2: return .blue
        case .zone3: return .green
        case .zone4: return .orange
        case .zone5: return .red
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes > 0 {
            return "\(minutes)m"
        }
        return "\(Int(seconds))s"
    }
}

// MARK: - Heart Rate Timeline Chart

struct HeartRateTimelineChart: View {
    let samples: [HeartRateSample]

    var body: some View {
        Chart {
            ForEach(samples) { sample in
                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("BPM", sample.bpm)
                )
                .foregroundStyle(zoneGradient)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("BPM", sample.bpm)
                )
                .foregroundStyle(zoneGradient.opacity(0.2))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartYScale(domain: yAxisDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatTime(date))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel()
                    .font(.caption2)
                AxisGridLine()
            }
        }
    }

    private var yAxisDomain: ClosedRange<Int> {
        let bpms = samples.map(\.bpm)
        let minBPM = (bpms.min() ?? 60) - 10
        let maxBPM = (bpms.max() ?? 180) + 10
        return minBPM...maxBPM
    }

    private var zoneGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .green, .orange, .red],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        HeartRateSummaryView(ride: Ride())
            .padding()
    }
}
