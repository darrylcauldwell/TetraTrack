//
//  HeartRateDisplayView.swift
//  TetraTrack
//
//  Live heart rate display for tracking view
//

import SwiftUI

struct HeartRateDisplayView: View {
    let heartRate: Int
    let zone: HeartRateZone
    let averageHeartRate: Int?
    let maxHeartRate: Int?

    @State private var animateHeart = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                // Current heart rate with animated heart
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .font(.title2)
                            .foregroundStyle(zoneColor)
                            .scaleEffect(animateHeart ? 1.15 : 1.0)
                            .animation(
                                heartRate > 0 ?
                                    .easeInOut(duration: 60.0 / Double(max(heartRate, 60)))
                                        .repeatForever(autoreverses: true) :
                                    .default,
                                value: animateHeart
                            )

                        Text("\(heartRate)")
                            .font(.system(.largeTitle, design: .rounded))
                            .fontWeight(.bold)
                            .monospacedDigit()

                        Text("bpm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Zone indicator
                    Text(zone.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(zoneColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(zoneColor.opacity(0.15))
                        .clipShape(Capsule())
                }

                Spacer()

                // Avg/Max stats
                VStack(alignment: .trailing, spacing: 8) {
                    if let avg = averageHeartRate, avg > 0 {
                        HStack(spacing: 4) {
                            Text("Avg")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(avg)")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                    }

                    if let max = maxHeartRate, max > 0 {
                        HStack(spacing: 4) {
                            Text("Max")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(max)")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                    }
                }
            }

            // Zone progress bar
            ZoneProgressBar(currentZone: zone)
        }
        .onAppear {
            animateHeart = true
        }
    }

    private var zoneColor: Color {
        switch zone {
        case .zone1: return .gray
        case .zone2: return .blue
        case .zone3: return .green
        case .zone4: return .orange
        case .zone5: return .red
        }
    }
}

// MARK: - Zone Progress Bar

struct ZoneProgressBar: View {
    let currentZone: HeartRateZone

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(HeartRateZone.allCases, id: \.self) { zone in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(zone == currentZone ? zoneColor(for: zone) : zoneColor(for: zone).opacity(0.3))
                        .frame(height: zone == currentZone ? 8 : 4)
                        .animation(.easeInOut(duration: 0.3), value: currentZone)
                }
            }
        }
        .frame(height: 8)
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
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        HeartRateDisplayView(
            heartRate: 145,
            zone: .zone3,
            averageHeartRate: 130,
            maxHeartRate: 165
        )
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 2)
        .padding()

        HeartRateDisplayView(
            heartRate: 175,
            zone: .zone5,
            averageHeartRate: 150,
            maxHeartRate: 180
        )
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 2)
        .padding()
    }
}
