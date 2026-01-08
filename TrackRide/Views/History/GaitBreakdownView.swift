//
//  GaitBreakdownView.swift
//  TrackRide
//

import SwiftUI
import Charts

struct GaitBreakdownView: View {
    let ride: Ride

    private var gaitData: [(gait: GaitType, duration: TimeInterval, percentage: Double)] {
        ride.gaitBreakdown
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gait Breakdown")
                .font(.headline)

            if gaitData.isEmpty {
                Text("No gait data recorded")
                    .foregroundStyle(.secondary)
            } else {
                // Pie chart
                Chart(gaitData, id: \.gait) { item in
                    SectorMark(
                        angle: .value("Duration", item.duration),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(gaitColor(item.gait))
                    .cornerRadius(4)
                }
                .frame(height: 150)

                // Legend
                VStack(spacing: 8) {
                    ForEach(gaitData, id: \.gait) { item in
                        HStack {
                            Circle()
                                .fill(gaitColor(item.gait))
                                .frame(width: 12, height: 12)

                            Image(systemName: item.gait.icon)
                                .frame(width: 20)

                            Text(item.gait.rawValue)
                                .font(.subheadline)

                            Spacer()

                            Text(formatDuration(item.duration))
                                .font(.subheadline)
                                .monospacedDigit()

                            Text(String(format: "%.0f%%", item.percentage))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func gaitColor(_ gait: GaitType) -> Color {
        AppColors.gait(gait)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    GaitBreakdownView(ride: Ride())
        .padding()
}
