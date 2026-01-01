//
//  ProgramDetailView.swift
//  TetraTrack
//
//  Week-by-week breakdown of a training program with progress tracking
//

import SwiftUI
import SwiftData

struct ProgramDetailView: View {
    @Bindable var program: TrainingProgram
    var onStartSession: ((ProgramSession) -> Void)?
    @Environment(\.modelContext) private var modelContext

    private let programService = TrainingProgramService()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Program header with progress
                programHeader

                // Start next session button
                if program.status == .active, let next = program.nextSession, onStartSession != nil {
                    startSessionButton(next)
                }

                // Week-by-week breakdown
                ForEach(1...program.totalWeeks, id: \.self) { weekNum in
                    ProgramWeekCard(
                        weekNumber: weekNum,
                        isCurrentWeek: weekNum == program.currentWeek,
                        sessions: program.sortedSessions.filter { $0.weekNumber == weekNum },
                        weekDefinition: program.programDefinition.first { $0.weekNumber == weekNum }
                    )
                }

                // Action buttons
                if program.status == .active {
                    actionButtons
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .navigationTitle(program.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Start Session Button

    private func startSessionButton(_ session: ProgramSession) -> some View {
        Button {
            onStartSession?(session)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start Next Session")
                        .font(.headline)
                    Text(session.name)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Text(session.formattedTargetDuration)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.green)
            )
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Program Header

    private var programHeader: some View {
        VStack(spacing: 16) {
            // Progress ring + stats
            HStack(spacing: 20) {
                ProgramProgressRing(
                    progress: program.progressFraction,
                    size: 80
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Week \(program.currentWeek) of \(program.totalWeeks)")
                        .font(.headline)

                    Text(program.formattedProgress)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if program.status == .active {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption)
                            if let end = program.targetEndDate {
                                Text("Target: \(end.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                            }
                        }
                        .foregroundStyle(.secondary)
                    }

                    if program.status == .completed {
                        Label("Completed", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                    }
                }

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                programService.togglePause(program, context: modelContext)
            } label: {
                HStack {
                    Image(systemName: program.status == .paused ? "play.fill" : "pause.fill")
                    Text(program.status == .paused ? "Resume" : "Pause")
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.yellow.opacity(0.2))
                )
                .foregroundStyle(.yellow)
            }

            Button {
                programService.abandonProgram(program, context: modelContext)
            } label: {
                HStack {
                    Image(systemName: "xmark")
                    Text("Abandon")
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.2))
                )
                .foregroundStyle(.red)
            }
        }
    }
}
