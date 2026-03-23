//
//  RunningMetricCards.swift
//  TetraTrack
//
//  Shared metric card components used across running, walking, treadmill live views.
//  Consolidates HR zone display, cadence display, elevation display, and color helpers.
//

import SwiftUI

// MARK: - Heart Rate Zone Color

/// Maps a HeartRateZone to a SwiftUI Color using the existing colorName property.
func heartRateZoneColor(_ zone: HeartRateZone) -> Color {
    switch zone {
    case .zone1: return .gray
    case .zone2: return .blue
    case .zone3: return .green
    case .zone4: return .orange
    case .zone5: return .red
    }
}

// MARK: - Cadence Rating Color

/// Consolidated cadence color logic — replaces duplicated `cadenceColor` and `treadmillCadenceColor`.
func cadenceRatingColor(cadence: Int, target: Int) -> Color {
    if target > 0 {
        let deviation = abs(cadence - target)
        if deviation <= 5 { return .green }
        if deviation <= 15 { return .yellow }
        return .orange
    }
    // No target: use ideal range (170-190 spm)
    if cadence >= 170 && cadence <= 190 { return .green }
    if cadence >= 160 && cadence <= 200 { return .yellow }
    return .orange
}

// MARK: - Heart Rate Zone Card

/// Displays heart rate with zone indicator. Two modes:
/// - `prominent`: zone is the hero element (for easy/recovery runs where HR zone is primary training signal)
/// - `compact`: zone badge alongside HR (for tempo/race where pace is primary)
struct HeartRateZoneCard: View {
    let heartRate: Int
    let zone: HeartRateZone
    var averageHeartRate: Int = 0
    var maxHeartRate: Int = 0
    var isProminent: Bool = true

    private var zoneColor: Color { heartRateZoneColor(zone) }

    var body: some View {
        if isProminent {
            prominentLayout
        } else {
            compactLayout
        }
    }

    // MARK: - Prominent Layout (Zone is hero)

    private var prominentLayout: some View {
        VStack(spacing: 8) {
            // Zone badge — large
            Text(zone.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(zoneColor)
                .clipShape(Capsule())

            // HR value
            HStack(spacing: 6) {
                Image(systemName: heartRate > 0 ? "heart.fill" : "heart")
                    .foregroundStyle(heartRate > 0 ? zoneColor : .gray)
                    .symbolEffect(.pulse, options: .repeating, isActive: heartRate > 0)
                Text(heartRate > 0 ? "\(heartRate)" : "--")
                    .scaledFont(size: 32, weight: .bold, design: .rounded, relativeTo: .title)
                    .monospacedDigit()
                Text("bpm")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Avg / Max row
            if averageHeartRate > 0 || maxHeartRate > 0 {
                HStack(spacing: 16) {
                    if averageHeartRate > 0 {
                        VStack(spacing: 2) {
                            Text("\(averageHeartRate)")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                            Text("Avg")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if maxHeartRate > 0 {
                        VStack(spacing: 2) {
                            Text("\(maxHeartRate)")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.red)
                            Text("Max")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Zone progress bar
            ZoneProgressBar(currentZone: zone)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .glassCard(material: .thin, cornerRadius: 12, padding: 0)
    }

    // MARK: - Compact Layout (Badge alongside HR)

    private var compactLayout: some View {
        HStack(spacing: 12) {
            // HR value
            HStack(spacing: 6) {
                Image(systemName: heartRate > 0 ? "heart.fill" : "heart")
                    .foregroundStyle(heartRate > 0 ? .red : .gray)
                    .symbolEffect(.pulse, options: .repeating, isActive: heartRate > 0)
                Text(heartRate > 0 ? "\(heartRate)" : "--")
                    .scaledFont(size: 24, weight: .bold, design: .rounded, relativeTo: .title3)
                    .monospacedDigit()
            }

            // Zone capsule
            if heartRate > 0 {
                Text(zone.name)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(zoneColor)
                    .clipShape(Capsule())
            }

            Spacer()

            // Avg / Max
            if averageHeartRate > 0 {
                VStack(spacing: 2) {
                    Text("\(averageHeartRate)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                    Text("Avg")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if maxHeartRate > 0 {
                VStack(spacing: 2) {
                    Text("\(maxHeartRate)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.red)
                    Text("Max")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .glassCard(material: .thin, cornerRadius: 12, padding: 0)
    }
}

// MARK: - Cadence Card

/// Displays cadence with source label (Watch/Pedometer), target indicator, and optional form metrics.
struct CadenceCard: View {
    let cadence: Int
    var isWatchSource: Bool = false
    var target: Int = 0
    var verticalOscillation: Double = 0
    var groundContactTime: Double = 0

    var body: some View {
        HStack(spacing: 24) {
            // Cadence
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("Cadence")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !isWatchSource && cadence > 0 {
                        Text("(Pedometer)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                HStack(spacing: 2) {
                    Text(cadence > 0 ? "\(cadence)" : "--")
                        .scaledFont(size: 22, weight: .semibold, design: .rounded, relativeTo: .title3)
                    Text("spm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(cadence > 0 ? cadenceRatingColor(cadence: cadence, target: target) : .secondary)
                if target > 0 {
                    Text("Target: \(target)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Vertical Oscillation (Watch only)
            if isWatchSource && verticalOscillation > 0 {
                VStack(spacing: 4) {
                    Text("Oscillation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 2) {
                        Text(String(format: "%.1f", verticalOscillation))
                            .scaledFont(size: 22, weight: .semibold, design: .rounded, relativeTo: .title3)
                        Text("cm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(oscillationColor(verticalOscillation))
                }
            }

            // Ground Contact Time (Watch only)
            if isWatchSource && groundContactTime > 0 {
                VStack(spacing: 4) {
                    Text("Contact")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 2) {
                        Text(String(format: "%.0f", groundContactTime))
                            .scaledFont(size: 22, weight: .semibold, design: .rounded, relativeTo: .title3)
                        Text("ms")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(gctColor(groundContactTime))
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .glassCard(material: .thin, cornerRadius: 12, padding: 0)
    }

    private func oscillationColor(_ value: Double) -> Color {
        if value <= 8.0 { return .green }
        if value <= 10.0 { return .yellow }
        return .orange
    }

    private func gctColor(_ value: Double) -> Color {
        if value <= 250 { return .green }
        if value <= 300 { return .yellow }
        return .orange
    }
}

// MARK: - Elevation Card

/// Compact elevation gain/loss display for live sessions.
struct ElevationCard: View {
    let gain: Double
    var loss: Double = 0

    var body: some View {
        HStack(spacing: 24) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.green)
                    .font(.caption)
                Text(String(format: "%.0fm", gain))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
            }
            if loss > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.right")
                        .foregroundStyle(.red)
                        .font(.caption)
                    Text(String(format: "%.0fm", loss))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .glassCard(material: .thin, cornerRadius: 12, padding: 0)
    }
}
