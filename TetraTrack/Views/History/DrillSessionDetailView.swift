//
//  DrillSessionDetailView.swift
//  TetraTrack
//
//  Detail view for a completed training drill session
//

import SwiftUI

struct DrillSessionDetailView: View {
    let session: UnifiedDrillSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.2))
                                .frame(width: 64, height: 64)
                            Image(systemName: session.drillType.icon)
                                .font(.title2)
                                .foregroundStyle(.purple)
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

                    // Overall score
                    VStack(spacing: 4) {
                        Text(String(format: "%.0f", session.score))
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(.purple)
                        Text("Overall Score")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider()

                    // Duration
                    HStack {
                        Label("Duration", systemImage: "clock")
                            .font(.subheadline)
                        Spacer()
                        Text(session.duration.formatted(.number.precision(.fractionLength(0))) + "s")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    // Subscores
                    if hasSubscores {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Subscores")
                                .font(.headline)

                            if session.stabilityScore > 0 {
                                subscoreRow(label: "Stability", value: session.stabilityScore, icon: "hand.raised")
                            }
                            if session.symmetryScore > 0 {
                                subscoreRow(label: "Symmetry", value: session.symmetryScore, icon: "arrow.left.and.right")
                            }
                            if session.enduranceScore > 0 {
                                subscoreRow(label: "Endurance", value: session.enduranceScore, icon: "flame")
                            }
                            if session.coordinationScore > 0 {
                                subscoreRow(label: "Coordination", value: session.coordinationScore, icon: "figure.walk")
                            }
                            if session.breathingScore > 0 {
                                subscoreRow(label: "Breathing", value: session.breathingScore, icon: "lungs")
                            }
                            if session.rhythmScore > 0 {
                                subscoreRow(label: "Rhythm", value: session.rhythmScore, icon: "metronome")
                            }
                        }
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

    private var hasSubscores: Bool {
        session.stabilityScore > 0 || session.symmetryScore > 0 ||
        session.enduranceScore > 0 || session.coordinationScore > 0 ||
        session.breathingScore > 0 || session.rhythmScore > 0
    }

    private func subscoreRow(label: String, value: Double, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.purple)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(String(format: "%.0f", value))
                .font(.subheadline.bold())
                .foregroundStyle(.purple)
        }
    }
}
