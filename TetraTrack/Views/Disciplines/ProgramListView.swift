//
//  ProgramListView.swift
//  TetraTrack
//
//  Browse and manage structured training programs
//

import SwiftUI
import SwiftData

struct ProgramListView: View {
    var onStartSession: ((ProgramSession) -> Void)?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrainingProgram.startDate, order: .reverse) private var programs: [TrainingProgram]

    @State private var selectedProgramType: TrainingProgramType?
    @State private var selectedProgram: TrainingProgram?

    private let programService = TrainingProgramService()

    private var activeProgram: TrainingProgram? {
        programs.first { $0.status == .active }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Active program card
                if let active = activeProgram {
                    activeProgramCard(active)
                }

                // Browse programs
                VStack(alignment: .leading, spacing: 12) {
                    Text("Programs")
                        .font(.headline)
                        .padding(.horizontal, 4)

                    ForEach(TrainingProgramType.allCases) { type in
                        Button {
                            selectedProgramType = type
                        } label: {
                            programTypeCard(type)
                        }
                        .buttonStyle(.plain)
                        .disabled(activeProgram != nil)
                    }

                    if activeProgram != nil {
                        Text("Complete or abandon your current program to start a new one.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                }

                // Past programs
                let pastPrograms = programs.filter { $0.status == .completed || $0.status == .abandoned }
                if !pastPrograms.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("History")
                            .font(.headline)
                            .padding(.horizontal, 4)

                        ForEach(pastPrograms) { program in
                            Button {
                                selectedProgram = program
                            } label: {
                                pastProgramRow(program)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .navigationTitle("Training Programs")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedProgramType) { type in
            ProgramSetupSheet(
                programType: type,
                onStart: { startDate in
                    let program = programService.createProgram(
                        type: type,
                        startDate: startDate,
                        context: modelContext
                    )
                    selectedProgramType = nil
                    selectedProgram = program
                }
            )
        }
        .navigationDestination(item: $selectedProgram) { program in
            ProgramDetailView(program: program, onStartSession: onStartSession)
        }
    }

    // MARK: - Active Program Card

    private func activeProgramCard(_ program: TrainingProgram) -> some View {
        Button {
            selectedProgram = program
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(program.name)
                            .font(.title3.bold())
                        Text("Week \(program.currentWeek) of \(program.totalWeeks)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.green.opacity(0.2), lineWidth: 6)
                            .frame(width: 50, height: 50)
                        Circle()
                            .trim(from: 0, to: program.progressFraction)
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(program.progressFraction * 100))%")
                            .font(.caption.bold())
                    }
                }

                // Next session preview
                if let next = program.nextSession {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(.green)
                        Text("Next: \(next.name)")
                            .font(.subheadline)
                        Spacer()
                        Text("Continue")
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.green.opacity(0.1))
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Program Type Card

    private func programTypeCard(_ type: TrainingProgramType) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: type.icon)
                    .font(.title3)
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(type.displayName)
                    .font(.subheadline.bold())
                Text(type.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Past Program Row

    private func pastProgramRow(_ program: TrainingProgram) -> some View {
        HStack {
            Image(systemName: program.status.icon)
                .foregroundStyle(program.status == .completed ? .green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(program.name)
                    .font(.subheadline)
                Text(program.startDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(program.formattedProgress)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}
