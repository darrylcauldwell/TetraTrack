//
//  DebugThresholdControlsView.swift
//  TrackRide
//
//  Debug-only UI for adjusting detection thresholds in real-time.
//  Allows developers to tune parameters and see immediate effect.
//

import SwiftUI

#if DEBUG

// MARK: - Threshold Controls View

/// Debug view for adjusting hole detection thresholds
struct DebugThresholdControlsView: View {
    @Binding var config: HoleDetectionConfig
    let onReprocess: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header toggle
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(.orange)
                    Text("Detection Thresholds")
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(AppColors.cardBackground)
            }
            .buttonStyle(.plain)

            if isExpanded {
                controlsContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private var controlsContent: some View {
        VStack(spacing: 16) {
            // Circularity threshold
            ThresholdSlider(
                title: "Min Circularity",
                value: $config.minCircularity,
                range: 0.3...0.9,
                description: "How circular a candidate must be (1.0 = perfect circle)"
            )

            // Confidence thresholds
            ThresholdSlider(
                title: "Auto-Accept Confidence",
                value: $config.autoAcceptConfidence,
                range: 0.5...0.99,
                description: "Confidence level for automatic acceptance"
            )

            ThresholdSlider(
                title: "Suggestion Confidence",
                value: $config.suggestionConfidence,
                range: 0.3...0.8,
                description: "Minimum confidence to show as suggestion"
            )

            ThresholdSlider(
                title: "Minimum Confidence",
                value: $config.minimumConfidence,
                range: 0.1...0.5,
                description: "Below this, candidates are rejected"
            )

            // Scoring ring filter
            Toggle(isOn: $config.filterScoringRingArtifacts) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Filter Scoring Ring Artifacts")
                        .font(.subheadline)
                    Text("Reject candidates near scoring ring lines")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ThresholdSlider(
                title: "Ring Tolerance",
                value: $config.scoringRingTolerance,
                range: 0.01...0.05,
                description: "Distance from ring to filter"
            )
            .disabled(!config.filterScoringRingArtifacts)
            .opacity(config.filterScoringRingArtifacts ? 1.0 : 0.5)

            // Local background toggle
            Toggle(isOn: $config.useLocalBackground) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use Local Background")
                        .font(.subheadline)
                    Text("Compare candidates against local region")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Max candidates
            HStack {
                Text("Max Candidates")
                    .font(.subheadline)
                Spacer()
                Stepper("\(config.maxCandidates)", value: $config.maxCandidates, in: 10...100, step: 5)
                    .fixedSize()
            }

            Divider()

            // Action buttons
            HStack {
                Button("Reset to Defaults") {
                    withAnimation {
                        config = HoleDetectionConfig()
                    }
                    onReprocess()
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    onReprocess()
                } label: {
                    Label("Reprocess", systemImage: "arrow.clockwise")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }

            // Presets
            presetButtons
        }
        .padding()
        .background(AppColors.elevatedSurface)
    }

    private var presetButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Presets")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    PresetButton(title: "Strict", icon: "shield.fill") {
                        config = .strict
                        onReprocess()
                    }

                    PresetButton(title: "Balanced", icon: "dial.medium") {
                        config = .default
                        onReprocess()
                    }

                    PresetButton(title: "Sensitive", icon: "eye.fill") {
                        config = .sensitive
                        onReprocess()
                    }

                    PresetButton(title: "Dark Targets", icon: "moon.fill") {
                        config = .forDarkTargets
                        onReprocess()
                    }
                }
            }
        }
    }
}

// MARK: - Threshold Slider

private struct ThresholdSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(value: $value, in: range)
                .tint(.orange)

            Text(description)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Preset Button

private struct PresetButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.quaternarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Detection Config Presets

extension HoleDetectionConfig {
    /// Strict detection with fewer false positives
    static var strict: HoleDetectionConfig {
        var config = HoleDetectionConfig()
        config.minCircularity = 0.7
        config.autoAcceptConfidence = 0.92
        config.suggestionConfidence = 0.7
        config.minimumConfidence = 0.4
        config.filterScoringRingArtifacts = true
        config.scoringRingTolerance = 0.03
        return config
    }

    /// Sensitive detection for difficult images
    static var sensitive: HoleDetectionConfig {
        var config = HoleDetectionConfig()
        config.minCircularity = 0.4
        config.autoAcceptConfidence = 0.75
        config.suggestionConfidence = 0.4
        config.minimumConfidence = 0.2
        config.filterScoringRingArtifacts = false
        return config
    }

    /// Optimized for targets with dark half
    static var forDarkTargets: HoleDetectionConfig {
        var config = HoleDetectionConfig()
        config.minCircularity = 0.45
        config.autoAcceptConfidence = 0.8
        config.suggestionConfidence = 0.45
        config.minimumConfidence = 0.25
        config.filterScoringRingArtifacts = true
        config.scoringRingTolerance = 0.025
        config.useLocalBackground = true
        return config
    }
}

// MARK: - Quality Threshold Controls

/// Controls for adjusting quality assessment thresholds
struct DebugQualityThresholdControls: View {
    @Binding var minSharpness: Double
    @Binding var minContrast: Double
    @Binding var darkAreaThreshold: Double
    let onReassess: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Quality Thresholds")
                .font(.subheadline.bold())

            ThresholdSlider(
                title: "Min Sharpness",
                value: $minSharpness,
                range: 0.1...0.5,
                description: "Minimum sharpness to accept"
            )

            ThresholdSlider(
                title: "Min Contrast",
                value: $minContrast,
                range: 0.05...0.3,
                description: "Minimum contrast to accept"
            )

            ThresholdSlider(
                title: "Dark Area Visibility",
                value: $darkAreaThreshold,
                range: 0.1...0.5,
                description: "Min visibility in dark areas"
            )

            Button("Reassess Quality") {
                onReassess()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Compact Threshold Display

/// Compact display of current thresholds
struct ThresholdBadges: View {
    let config: HoleDetectionConfig

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ThresholdBadge(
                    label: "Circ",
                    value: String(format: "%.0f%%", config.minCircularity * 100)
                )

                ThresholdBadge(
                    label: "Auto",
                    value: String(format: "%.0f%%", config.autoAcceptConfidence * 100)
                )

                ThresholdBadge(
                    label: "Min",
                    value: String(format: "%.0f%%", config.minimumConfidence * 100)
                )

                if config.filterScoringRingArtifacts {
                    ThresholdBadge(
                        label: "Ring",
                        value: "On",
                        color: .green
                    )
                }

                if config.useLocalBackground {
                    ThresholdBadge(
                        label: "Local",
                        value: "On",
                        color: .blue
                    )
                }
            }
        }
    }
}

private struct ThresholdBadge: View {
    let label: String
    let value: String
    var color: Color = .orange

    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2.bold())
                .foregroundStyle(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State var config = HoleDetectionConfig()

        var body: some View {
            VStack {
                DebugThresholdControlsView(config: $config) {
                    print("Reprocess")
                }
                .padding()

                ThresholdBadges(config: config)
                    .padding()

                Spacer()
            }
        }
    }

    return PreviewWrapper()
}

#endif
