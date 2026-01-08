//
//  SymmetryRhythmView.swift
//  TrackRide
//
//  Displays overall symmetry and rhythm quality metrics

import SwiftUI

struct SymmetryRhythmView: View {
    let ride: Ride

    private var hasData: Bool {
        ride.overallSymmetry > 0 || ride.overallRhythm > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Movement Quality")
                .font(.headline)

            if !hasData {
                Text("No quality metrics recorded")
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 24) {
                    // Symmetry gauge
                    CircularGaugeView(
                        value: ride.overallSymmetry,
                        maxValue: 100,
                        title: "Symmetry",
                        color: symmetryColor
                    )

                    // Rhythm gauge
                    CircularGaugeView(
                        value: ride.overallRhythm,
                        maxValue: 100,
                        title: "Rhythm",
                        color: rhythmColor
                    )

                    // Transition quality (if available)
                    if ride.transitionCount > 0 {
                        CircularGaugeView(
                            value: ride.averageTransitionQuality * 100,
                            maxValue: 100,
                            title: "Transitions",
                            subtitle: "\(ride.transitionCount) total",
                            color: transitionColor
                        )
                    }
                }
                .frame(maxWidth: .infinity)

                // Transition breakdown
                if ride.transitionCount > 0 {
                    Divider()

                    HStack {
                        VStack(alignment: .leading) {
                            Text("Upward")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(ride.upwardTransitionCount)")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }

                        Spacer()

                        VStack {
                            Text("Total")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(ride.transitionCount)")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("Downward")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(ride.downwardTransitionCount)")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var symmetryColor: Color {
        colorForScore(ride.overallSymmetry)
    }

    private var rhythmColor: Color {
        colorForScore(ride.overallRhythm)
    }

    private var transitionColor: Color {
        colorForScore(ride.averageTransitionQuality * 100)
    }

    private func colorForScore(_ score: Double) -> Color {
        switch score {
        case 0..<50: return AppColors.error
        case 50..<70: return AppColors.warning
        case 70..<85: return AppColors.success
        default: return AppColors.primary
        }
    }
}

struct CircularGaugeView: View {
    let value: Double
    let maxValue: Double
    let title: String
    var subtitle: String? = nil
    let color: Color

    private var progress: Double {
        min(value / maxValue, 1.0)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 8)

                // Progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: progress)

                // Value text
                VStack(spacing: 0) {
                    Text(String(format: "%.0f", value))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(color)

                    Text("%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 70, height: 70)

            Text(title)
                .font(.caption)
                .fontWeight(.medium)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    SymmetryRhythmView(ride: {
        let ride = Ride()
        ride.leftReinSymmetry = 85
        ride.rightReinSymmetry = 82
        ride.leftReinRhythm = 78
        ride.rightReinRhythm = 81
        ride.leftReinDuration = 300
        ride.rightReinDuration = 280
        return ride
    }())
    .padding()
}
