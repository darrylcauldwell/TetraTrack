//
//  GPSSignalIndicator.swift
//  TrackRide
//
//  Visual indicator for GPS signal quality
//

import SwiftUI

/// Compact GPS signal strength indicator with bars
struct GPSSignalIndicator: View {
    let quality: GPSSignalQuality
    var showLabel: Bool = false
    var compact: Bool = true

    var body: some View {
        HStack(spacing: compact ? 2 : 4) {
            // Signal bars
            HStack(spacing: 1) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(index < quality.bars ? quality.color : Color.gray.opacity(0.3))
                        .frame(width: compact ? 3 : 4, height: barHeight(for: index))
                }
            }

            if showLabel {
                Text(quality.rawValue)
                    .font(.caption2)
                    .foregroundStyle(quality.color)
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = compact ? 6 : 8
        let increment: CGFloat = compact ? 2 : 3
        return baseHeight + CGFloat(index) * increment
    }
}

/// Expanded GPS signal indicator with accuracy details
struct GPSSignalDetailView: View {
    let quality: GPSSignalQuality
    let accuracy: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: quality.icon)
                    .foregroundStyle(quality.color)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("GPS Signal: \(quality.rawValue)")
                        .font(.headline)

                    if accuracy >= 0 {
                        Text("Accuracy: ±\(Int(accuracy))m")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                GPSSignalIndicator(quality: quality, compact: false)
            }

            Text(quality.impactDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

#Preview("GPS Signal Indicator") {
    VStack(spacing: 20) {
        ForEach(GPSSignalQuality.allCases, id: \.self) { quality in
            HStack {
                GPSSignalIndicator(quality: quality)
                GPSSignalIndicator(quality: quality, showLabel: true)
                GPSSignalIndicator(quality: quality, showLabel: true, compact: false)
            }
        }
    }
    .padding()
}

#Preview("GPS Signal Detail") {
    VStack(spacing: 16) {
        GPSSignalDetailView(quality: .excellent, accuracy: 3)
        GPSSignalDetailView(quality: .good, accuracy: 8)
        GPSSignalDetailView(quality: .fair, accuracy: 18)
        GPSSignalDetailView(quality: .poor, accuracy: 45)
        GPSSignalDetailView(quality: .none, accuracy: -1)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
