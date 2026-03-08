//
//  DressageTestPracticeView.swift
//  TetraTrack
//
//  Overlay for practising a dressage test during a ride
//

import SwiftUI

struct DressageTestPracticeView: View {
    let plugin: RidingPlugin

    private var movements: [DressageMovement] {
        guard let test = plugin.selectedDressageTest else { return [] }
        return DressageTestData.movements[test] ?? []
    }

    private var currentMovement: DressageMovement? {
        guard plugin.currentMovementIndex < movements.count else { return nil }
        return movements[plugin.currentMovementIndex]
    }

    private var isTestComplete: Bool {
        plugin.currentMovementIndex >= movements.count
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "list.number")
                    .foregroundStyle(.indigo)
                Text(plugin.selectedDressageTest?.displayName ?? "Test")
                    .font(.headline)
                Spacer()
                Text("\(plugin.currentMovementIndex + 1) of \(movements.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if isTestComplete {
                // Test complete
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                    Text("Test Complete")
                        .font(.headline)
                    if !plugin.movementScores.isEmpty {
                        let total = plugin.movementScores.reduce(0, +)
                        let max = movements.count * 10
                        Text("\(total)/\(max) (\(String(format: "%.1f", Double(total) / Double(max) * 100))%)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            } else if let movement = currentMovement {
                // Current movement
                VStack(spacing: 8) {
                    // Marker letter
                    Text(movement.marker)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.indigo)

                    // Instruction
                    Text(movement.instruction)
                        .font(.title3)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)

                // Score entry
                HStack(spacing: 8) {
                    ForEach(0...10, id: \.self) { score in
                        Button {
                            scoreAndAdvance(score)
                        } label: {
                            Text("\(score)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .frame(width: 28, height: 28)
                                .background(scoreColor(score).opacity(0.2))
                                .foregroundStyle(scoreColor(score))
                                .clipShape(Circle())
                        }
                    }
                }

                // Next button (skip scoring)
                Button {
                    advanceMovement()
                } label: {
                    Text("Next")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.indigo.opacity(0.15))
                        .foregroundStyle(.indigo)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: plugin.currentMovementIndex)
            }

            // Progress bar
            GeometryReader { geo in
                let progress = movements.isEmpty ? 0 : Double(plugin.currentMovementIndex) / Double(movements.count)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.indigo)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func scoreAndAdvance(_ score: Int) {
        plugin.movementScores.append(score)
        plugin.currentMovementIndex += 1
        saveExecutionIfComplete()
    }

    private func advanceMovement() {
        plugin.currentMovementIndex += 1
        saveExecutionIfComplete()
    }

    private func saveExecutionIfComplete() {
        guard isTestComplete, let test = plugin.selectedDressageTest, let ride = plugin.currentRide else { return }

        let movementScoreRecords = movements.enumerated().map { index, movement in
            DressageMovementScore(
                movementNumber: movement.number,
                score: index < plugin.movementScores.count ? plugin.movementScores[index] : nil
            )
        }

        let execution = DressageTestExecution(
            testName: test.displayName,
            movementScores: movementScoreRecords,
            maxPossibleScore: Double(movements.count * 10)
        )

        ride.dressageTestExecution = execution
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 8...10: return .green
        case 6...7: return .blue
        case 4...5: return .yellow
        default: return .red
        }
    }
}

// MARK: - Dressage Test Scoresheet Card (for ride insights)

struct DressageTestScoresheetCard: View {
    let execution: DressageTestExecution

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.number")
                    .foregroundStyle(.indigo)
                Text(execution.testName)
                    .font(.headline)
                Spacer()
                Text(String(format: "%.1f%%", execution.percentage))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(percentageColor)
            }

            // Score summary
            HStack {
                Text("Total: \(Int(execution.totalScore))/\(Int(execution.maxPossibleScore))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Per-movement scores
            let scored = execution.movementScores.filter { $0.score != nil }
            if !scored.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 10), spacing: 4) {
                    ForEach(execution.movementScores) { ms in
                        VStack(spacing: 2) {
                            Text("\(ms.movementNumber)")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                            Text(ms.score != nil ? "\(ms.score!)" : "-")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(ms.score != nil ? scoreColor(ms.score!) : .secondary)
                        }
                        .frame(minWidth: 24, minHeight: 30)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var percentageColor: Color {
        switch execution.percentage {
        case 70...: return .green
        case 60..<70: return .blue
        case 50..<60: return .yellow
        default: return .red
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 8...10: return .green
        case 6...7: return .blue
        case 4...5: return .yellow
        default: return .red
        }
    }
}

// MARK: - Dressage Test Setup Card (for DisciplineSetupSheet)

struct DressageTestSetupCard: View {
    @Binding var selectedTest: DressageTest?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.number")
                    .foregroundStyle(.indigo)
                Text("Practice a Test")
                    .font(.headline)
            }

            Toggle("Enable test practice", isOn: Binding(
                get: { selectedTest != nil },
                set: { enabled in
                    if enabled {
                        selectedTest = .introA
                    } else {
                        selectedTest = nil
                    }
                }
            ))

            if selectedTest != nil {
                Picker("Test", selection: Binding(
                    get: { selectedTest ?? .introA },
                    set: { selectedTest = $0 }
                )) {
                    ForEach(DressageTest.allCases, id: \.self) { test in
                        Text(test.displayName).tag(test)
                    }
                }
                .pickerStyle(.navigationLink)

                if let test = selectedTest, let movements = DressageTestData.movements[test] {
                    Text("\(movements.count) movements")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
