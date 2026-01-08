//
//  ElevationProfileView.swift
//  TrackRide
//

import SwiftUI
import Charts

struct ElevationProfileView: View {
    let profile: [(distance: Double, altitude: Double)]

    private var minAltitude: Double {
        profile.map { $0.altitude }.min() ?? 0
    }

    private var maxAltitude: Double {
        profile.map { $0.altitude }.max() ?? 100
    }

    private var altitudeRange: Double {
        max(maxAltitude - minAltitude, 10)  // Minimum 10m range
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Elevation Profile")
                .font(.headline)

            if profile.isEmpty {
                Text("No elevation data")
                    .foregroundStyle(.secondary)
                    .frame(height: 150)
            } else {
                Chart {
                    ForEach(Array(profile.enumerated()), id: \.offset) { _, point in
                        AreaMark(
                            x: .value("Distance", point.distance / 1000),  // km
                            y: .value("Altitude", point.altitude)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.primary.opacity(0.6), AppColors.primary.opacity(0.2)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Distance", point.distance / 1000),
                            y: .value("Altitude", point.altitude)
                        )
                        .foregroundStyle(AppColors.primary)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .chartXAxisLabel("Distance (km)")
                .chartYAxisLabel("Altitude (m)")
                .chartYScale(domain: (minAltitude - 5)...(maxAltitude + 5))
                .frame(height: 150)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ElevationProfileView(profile: [
        (0, 100),
        (500, 105),
        (1000, 115),
        (1500, 110),
        (2000, 120),
        (2500, 118),
        (3000, 125),
    ])
    .padding()
}
