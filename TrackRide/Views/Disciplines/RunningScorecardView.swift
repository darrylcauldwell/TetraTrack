//
//  RunningScorecardView.swift
//  TrackRide
//
//  Post-run subjective scoring with smart coaching suggestions
//

import SwiftUI
import SwiftData

struct RunningScorecardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let session: RunningSession
    @Bindable var score: RunningScore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 50))
                            .foregroundStyle(.orange)

                        Text("Rate Your Run")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("How did the session go?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top)

                    // Overall feeling
                    ScoreSection(title: "Overall Feeling", icon: "heart.fill") {
                        ScoreSlider(
                            value: $score.overallFeeling,
                            description: "How satisfied are you with this run?"
                        )
                    }

                    // Conditions
                    ScoreSection(title: "Conditions", icon: "cloud.sun.fill") {
                        ScoreRow(
                            title: "Terrain Difficulty",
                            description: "Route challenge level",
                            value: $score.terrainDifficulty
                        )
                        ScoreRow(
                            title: "Weather Impact",
                            description: "How weather affected the run",
                            value: $score.weatherImpact
                        )
                    }

                    // Running form
                    ScoreSection(title: "Running Form", icon: "figure.run") {
                        ScoreRow(
                            title: "Running Form",
                            description: "Posture, alignment, and mechanics",
                            value: $score.runningForm
                        )
                        ScoreRow(
                            title: "Cadence Consistency",
                            description: "Step turnover rhythm",
                            value: $score.cadenceConsistency
                        )
                        ScoreRow(
                            title: "Breathing Control",
                            description: "Breathing rhythm and comfort",
                            value: $score.breathingControl
                        )
                        ScoreRow(
                            title: "Foot Strike",
                            description: "Landing pattern quality",
                            value: $score.footStrike
                        )
                        ScoreRow(
                            title: "Arm Swing",
                            description: "Arm movement efficiency",
                            value: $score.armSwing
                        )
                    }

                    // Performance
                    ScoreSection(title: "Performance", icon: "speedometer") {
                        ScoreRow(
                            title: "Pace Control",
                            description: "Maintaining target pace/effort",
                            value: $score.paceControl
                        )
                        ScoreRow(
                            title: "Hill Technique",
                            description: "Uphill and downhill form",
                            value: $score.hillTechnique
                        )
                        ScoreRow(
                            title: "Split Consistency",
                            description: "Even km splits",
                            value: $score.splitConsistency
                        )
                        ScoreRow(
                            title: "Finish Strength",
                            description: "Ability to maintain pace at end",
                            value: $score.finishStrength
                        )
                    }

                    // Physical state
                    ScoreSection(title: "Physical State", icon: "heart.fill") {
                        ScoreRow(
                            title: "Energy Level",
                            description: "Overall energy throughout",
                            value: $score.energyLevel
                        )
                        ScoreRow(
                            title: "Leg Fatigue",
                            description: "1 = Exhausted, 5 = Fresh",
                            value: $score.legFatigue
                        )
                        ScoreRow(
                            title: "Cardiovascular Feel",
                            description: "Heart rate and breathing comfort",
                            value: $score.cardiovascularFeel
                        )
                    }

                    // Mental state
                    ScoreSection(title: "Mental State", icon: "brain.head.profile") {
                        ScoreRow(
                            title: "Mental Focus",
                            description: "Concentration and motivation",
                            value: $score.mentalFocus
                        )
                        ScoreRow(
                            title: "Perceived Effort (RPE)",
                            description: "1 = Very Easy, 5 = Maximum",
                            value: $score.perceivedEffort
                        )
                    }

                    // Notes
                    ScoreSection(title: "Notes", icon: "note.text") {
                        VStack(alignment: .leading, spacing: 12) {
                            NoteField(
                                title: "Highlights",
                                placeholder: "What went well?",
                                text: $score.highlights
                            )

                            NoteField(
                                title: "Areas to Improve",
                                placeholder: "What to work on next time?",
                                text: $score.improvements
                            )

                            NoteField(
                                title: "Additional Notes",
                                placeholder: "Any other observations...",
                                text: $score.notes
                            )
                        }
                    }

                    // Summary
                    if score.hasScores {
                        ScoreSection(title: "Summary", icon: "chart.pie.fill") {
                            HStack(spacing: 20) {
                                SummaryBadge(
                                    title: "Form",
                                    value: score.formAverage,
                                    color: scoreColor(score.formAverage)
                                )

                                SummaryBadge(
                                    title: "Performance",
                                    value: score.performanceAverage,
                                    color: scoreColor(score.performanceAverage)
                                )

                                SummaryBadge(
                                    title: "Overall",
                                    value: score.overallAverage,
                                    color: scoreColor(score.overallAverage)
                                )
                            }
                        }

                        // Smart Coaching Suggestions
                        if !score.coachingSuggestions.isEmpty {
                            ScoreSection(title: "Coaching Suggestions", icon: "lightbulb.fill") {
                                VStack(spacing: 12) {
                                    ForEach(score.coachingSuggestions) { suggestion in
                                        RunningCoachingCard(suggestion: suggestion)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Run Scorecard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveScore()
                    }
                }
            }
        }
    }

    private func scoreColor(_ value: Double) -> Color {
        switch value {
        case 4.5...5.0: return .green
        case 3.5..<4.5: return .orange
        case 2.5..<3.5: return .yellow
        default: return .red
        }
    }

    private func saveScore() {
        score.scoredAt = Date()
        score.session = session
        modelContext.insert(score)
        try? modelContext.save()

        // Compute and save skill domain scores
        let skillService = SkillDomainService()
        let skillScores = skillService.computeScores(from: session, score: score)
        for skillScore in skillScores {
            modelContext.insert(skillScore)
        }
        try? modelContext.save()

        dismiss()
    }
}

// MARK: - Coaching Card

struct RunningCoachingCard: View {
    let suggestion: RunningCoachingSuggestion

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: suggestion.icon)
                .font(.title2)
                .foregroundStyle(priorityColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(suggestion.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Text(priorityLabel)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(priorityColor.opacity(0.2))
                        .foregroundStyle(priorityColor)
                        .clipShape(Capsule())
                }

                Text(suggestion.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var priorityColor: Color {
        switch suggestion.priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }

    private var priorityLabel: String {
        switch suggestion.priority {
        case .high: return "Priority"
        case .medium: return "Suggested"
        case .low: return "Optional"
        }
    }
}

#Preview {
    let session = RunningSession(name: "Morning Run")
    let score = RunningScore()

    return RunningScorecardView(session: session, score: score)
        .modelContainer(for: [RunningSession.self, RunningScore.self], inMemory: true)
}
