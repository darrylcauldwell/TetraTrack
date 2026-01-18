//
//  ScoringInfoView.swift
//  TrackRide
//
//  Pony Club Tetrathlon/Triathlon scoring explanation
//  Based on 2025/2026 Pony Club Tetrathlon Rule Book
//

import SwiftUI

/// View explaining the Pony Club Tetrathlon/Triathlon scoring system
struct ScoringInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Scoring is based on the 2025/2026 Pony Club Tetrathlon Rule Book.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                shootingSection
                swimmingSection
                runningSection
                ridingSection
            }
            .navigationTitle("Scoring Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Shooting Section

    private var shootingSection: some View {
        Section("Shooting") {
            VStack(alignment: .leading, spacing: 12) {
                Text("10 shots at a target, maximum score 100")
                    .font(.subheadline)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Target rings:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Group {
                        HStack {
                            Circle().fill(.yellow).frame(width: 12, height: 12)
                            Text("Bull: 10 points")
                        }
                        HStack {
                            Circle().fill(.red).frame(width: 12, height: 12)
                            Text("Inner: 8 points")
                        }
                        HStack {
                            Circle().fill(.blue).frame(width: 12, height: 12)
                            Text("Magpie: 6 points")
                        }
                        HStack {
                            Circle().fill(.gray).frame(width: 12, height: 12)
                            Text("Outer: 4 points")
                        }
                        HStack {
                            Circle().stroke(.gray, lineWidth: 1).frame(width: 12, height: 12)
                            Text("Outside outer: 2 points")
                        }
                        HStack {
                            RoundedRectangle(cornerRadius: 2).stroke(.gray, lineWidth: 1).frame(width: 12, height: 12)
                            Text("Border/Off target: 0 points")
                        }
                    }
                    .font(.caption)
                }

                Text("Scores are always even numbers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Swimming Section

    private var swimmingSection: some View {
        Section("Swimming") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Distance swum in a fixed time period")
                    .font(.subheadline)

                formulaRow(formula: "Points = 1000 + ((distance - standard) × 3)")

                Text("3 points per metre over/under the standard distance")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                standardsTable(
                    title: "Standard Distances (for 1000 points)",
                    rows: [
                        ("Open Boys", "285m", "4 min"),
                        ("Open Girls", "225m", "3 min"),
                        ("Intermediate", "225m", "3 min"),
                        ("Junior", "185m", "3 min"),
                        ("Minimus/Tadpole", "125m", "2 min"),
                        ("Beanies", "125m", "2 min")
                    ]
                )
            }
        }
    }

    // MARK: - Running Section

    private var runningSection: some View {
        Section("Running") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Time to complete a set distance")
                    .font(.subheadline)

                formulaRow(formula: "Points = 1000 - ((time - standard) × 3)")

                VStack(alignment: .leading, spacing: 4) {
                    Text("3 points per second over/under the standard time")
                    Text("Times are rounded up to the next whole second")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                standardsTable(
                    title: "Standard Times (for 1000 points)",
                    rows: [
                        ("Open Boys", "3000m", "10:30"),
                        ("Open Girls", "1500m", "5:20"),
                        ("Intermediate Boys", "2000m", "7:00"),
                        ("Intermediate Girls", "1500m", "5:20"),
                        ("Junior", "1500m", "5:40"),
                        ("Minimus/Tadpole", "1000m", "4:00"),
                        ("Beanies", "500m", "2:00")
                    ]
                )

                Text("Open Boys: Reduces to 1 point/second after 13:16")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
    }

    // MARK: - Riding Section

    private var ridingSection: some View {
        Section("Riding") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Show jumping course")
                    .font(.subheadline)

                formulaRow(formula: "Points = 1400 - penalties")

                Text("Clear round within time = 1400 points")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Penalties:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Group {
                        Text("Knock down: 4 faults")
                        Text("First refusal: 4 faults")
                        Text("Second refusal: 8 faults")
                        Text("Fall: 8 faults")
                        Text("Time fault: 0.4 per second over time")
                        Text("Retirement: 500 points deducted")
                        Text("Fence not attempted: 50 points each")
                    }
                    .font(.caption)
                }
            }
        }
    }

    // MARK: - Helper Views

    private func formulaRow(formula: String) -> some View {
        HStack {
            Text(formula)
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func standardsTable(title: String, rows: [(String, String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                ForEach(rows, id: \.0) { row in
                    HStack {
                        Text(row.0)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(row.1)
                            .frame(width: 60, alignment: .trailing)
                        Text(row.2)
                            .frame(width: 50, alignment: .trailing)
                    }
                    .font(.caption)
                }
            }
            .padding(8)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

#Preview {
    ScoringInfoView()
}
