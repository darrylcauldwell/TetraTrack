//
//  DrillSessionDetailView.swift
//  TetraTrack
//
//  Rich detail view for a completed training drill session
//

import SwiftUI

struct DrillSessionDetailView: View {
    let session: UnifiedDrillSession
    @Environment(\.dismiss) private var dismiss

    private var scoreColor: Color {
        if session.score >= 80 { return .green }
        if session.score >= 60 { return .orange }
        return .red
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(scoreColor.opacity(0.2))
                                .frame(width: 64, height: 64)
                            Image(systemName: session.drillType.icon)
                                .font(.title2)
                                .foregroundStyle(scoreColor)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.drillType.displayName)
                                .font(.title2.bold())
                            Text(session.drillType.primaryDiscipline.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(session.startDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Divider()

                    // Overall score — colour-coded
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(scoreColor.opacity(0.2), lineWidth: 8)
                                .frame(width: 120, height: 120)
                            Circle()
                                .trim(from: 0, to: session.score / 100)
                                .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .frame(width: 120, height: 120)
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 0) {
                                Text(String(format: "%.0f", session.score))
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundStyle(scoreColor)
                                Text("%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(scoreLabel)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(scoreColor)
                    }
                    .frame(maxWidth: .infinity)

                    // Duration
                    HStack {
                        Label("Duration", systemImage: "clock")
                            .font(.subheadline)
                        Spacer()
                        Text(session.duration.formatted(.number.precision(.fractionLength(0))) + "s")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Subscores
                    if hasSubscores {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Subscores")
                                .font(.headline)

                            VStack(spacing: 8) {
                                if session.stabilityScore > 0 {
                                    subscoreBar(label: "Stability", value: session.stabilityScore, icon: "hand.raised")
                                }
                                if session.symmetryScore > 0 {
                                    subscoreBar(label: "Symmetry", value: session.symmetryScore, icon: "arrow.left.and.right")
                                }
                                if session.enduranceScore > 0 {
                                    subscoreBar(label: "Endurance", value: session.enduranceScore, icon: "flame")
                                }
                                if session.coordinationScore > 0 {
                                    subscoreBar(label: "Coordination", value: session.coordinationScore, icon: "figure.walk")
                                }
                                if session.breathingScore > 0 {
                                    subscoreBar(label: "Breathing", value: session.breathingScore, icon: "lungs")
                                }
                                if session.rhythmScore > 0 {
                                    subscoreBar(label: "Rhythm", value: session.rhythmScore, icon: "metronome")
                                }
                            }
                        }
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Notes
                    if !session.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                            Text(session.notes)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("Drill Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var scoreLabel: String {
        if session.score >= 80 { return "Excellent" }
        if session.score >= 60 { return "Good" }
        if session.score >= 40 { return "Developing" }
        return "Needs Work"
    }

    private var hasSubscores: Bool {
        session.stabilityScore > 0 || session.symmetryScore > 0 ||
        session.enduranceScore > 0 || session.coordinationScore > 0 ||
        session.breathingScore > 0 || session.rhythmScore > 0
    }

    private func subscoreBar(label: String, value: Double, icon: String) -> some View {
        let color = subscoreColor(value)
        return HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .frame(width: 100, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * value / 100)
                }
            }
            .frame(height: 8)
            Text(String(format: "%.0f", value))
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(color)
                .frame(width: 30, alignment: .trailing)
        }
    }

    private func subscoreColor(_ value: Double) -> Color {
        if value >= 80 { return .green }
        if value >= 60 { return .orange }
        return .red
    }
}
