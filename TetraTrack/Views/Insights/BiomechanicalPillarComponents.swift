//
//  BiomechanicalPillarComponents.swift
//  TetraTrack
//
//  Shared components for the 4 biomechanical pillars
//  (Rhythm, Symmetry, Economy, Stability) and Physiology section.
//  Extracted from the duplicated pillarCard() template across all 5 insight views.
//

import SwiftUI

// MARK: - Biomechanical Pillar

enum BiomechanicalPillar: String, CaseIterable {
    case stability, rhythm, symmetry, economy, posture

    var title: String {
        switch self {
        case .stability: return "Stability"
        case .rhythm: return "Rhythm"
        case .symmetry: return "Symmetry"
        case .economy: return "Economy"
        case .posture: return "Posture"
        }
    }

    var icon: String {
        switch self {
        case .stability: return "arrow.up.circle.fill"
        case .rhythm: return "metronome.fill"
        case .symmetry: return "arrow.left.arrow.right"
        case .economy: return "arrow.triangle.2.circlepath"
        case .posture: return "figure.stand"
        }
    }

    var color: Color {
        switch self {
        case .stability: return .green
        case .rhythm: return .indigo
        case .symmetry: return .orange
        case .economy: return .purple
        case .posture: return .orange
        }
    }

    var abbreviation: String {
        String(title.prefix(3)).uppercased()
    }
}

// MARK: - Pillar Score Card

/// Reusable card for displaying a single biomechanical pillar score.
/// Replaces the duplicated `pillarCard()` function from all insight views.
struct PillarScoreCard: View {
    let pillar: BiomechanicalPillar
    var subtitle: String = ""
    let score: Double
    let keyMetric: String
    let tip: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: pillar.icon)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(pillar.color)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(pillar.title)
                        .font(.headline)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(score > 0 ? "\(Int(score))" : "-")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(score > 0 ? scoreColor(score) : .secondary)
            }

            // Key metric
            HStack(spacing: 6) {
                Image(systemName: pillar.icon)
                    .font(.caption)
                    .foregroundStyle(pillar.color)
                Text(keyMetric)
                    .font(.subheadline)
            }

            // Tip
            Text(tip)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Overall Biomechanical Score

/// Header showing the overall biomechanical score with mini pillar badges.
/// Replaces the duplicated `overallGraceScore` computed property.
struct OverallBiomechanicalScore: View {
    let stabilityScore: Double
    let rhythmScore: Double
    var symmetryScore: Double = 0
    let economyScore: Double
    var postureScore: Double = 0

    /// Third pillar is symmetry by default, or posture if symmetry is 0 and posture is provided
    private var thirdPillar: (BiomechanicalPillar, Double) {
        postureScore > 0 && symmetryScore == 0
            ? (.posture, postureScore)
            : (.symmetry, symmetryScore)
    }

    private var scores: [Double] {
        [stabilityScore, rhythmScore, thirdPillar.1, economyScore].filter { $0 > 0 }
    }

    private var overall: Double {
        scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("Biomechanical Score")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("\(Int(overall))")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(scoreColor(overall))

            HStack(spacing: 16) {
                pillarMini(.stability, score: stabilityScore)
                pillarMini(.rhythm, score: rhythmScore)
                pillarMini(thirdPillar.0, score: thirdPillar.1)
                pillarMini(.economy, score: economyScore)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func pillarMini(_ pillar: BiomechanicalPillar, score: Double) -> some View {
        VStack(spacing: 4) {
            Text(pillar.abbreviation)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(score > 0 ? "\(Int(score))" : "-")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(score > 0 ? scoreColor(score) : .secondary)
        }
    }
}

// MARK: - Physiology Section Card

/// Card for physiological data (HR, recovery, fatigue, breathing).
/// This data was previously lumped into the "E: Enjoy" GRACE pillar
/// but is now a separate section since it's not biomechanical.
struct PhysiologySectionCard: View {
    let score: Double
    let keyMetric: String
    let tip: String
    var subtitle: String = "Effort & Recovery"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "heart.fill")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.red)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Physiology")
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(score > 0 ? "\(Int(score))" : "-")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(score > 0 ? scoreColor(score) : .secondary)
            }

            // Key metric
            HStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg")
                    .font(.caption)
                    .foregroundStyle(.red)
                Text(keyMetric)
                    .font(.subheadline)
            }

            // Tip
            Text(tip)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Shared Score Color

func scoreColor(_ score: Double) -> Color {
    switch score {
    case 80...: return .green
    case 60..<80: return .blue
    case 40..<60: return .yellow
    default: return .orange
    }
}
