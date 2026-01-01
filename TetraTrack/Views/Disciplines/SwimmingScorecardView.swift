//
//  SwimmingScorecardView.swift
//  TetraTrack
//
//  Post-swim subjective scoring with smart coaching suggestions
//

import SwiftUI
import SwiftData

struct SwimmingScorecardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let session: SwimmingSession
    @Bindable var score: SwimmingScore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "figure.pool.swim")
                            .font(.system(size: 50))
                            .foregroundStyle(.cyan)

                        Text("Rate Your Swim")
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
                            description: "How satisfied are you with this swim?"
                        )
                    }

                    // Pool conditions
                    ScoreSection(title: "Conditions", icon: "drop.fill") {
                        ScoreRow(
                            title: "Pool Conditions",
                            description: "Water temp, lane availability, etc.",
                            value: $score.poolConditions
                        )
                    }

                    // Technique
                    ScoreSection(title: "Technique", icon: "water.waves") {
                        ScoreRow(
                            title: "Stroke Efficiency",
                            description: "Smoothness and power of strokes",
                            value: $score.strokeEfficiency
                        )
                        ScoreRow(
                            title: "Body Position",
                            description: "Horizontal position in the water",
                            value: $score.bodyPosition
                        )
                        ScoreRow(
                            title: "Breathing Rhythm",
                            description: "Consistency of breathing pattern",
                            value: $score.breathingRhythm
                        )
                        ScoreRow(
                            title: "Turn Quality",
                            description: "Flip turns and wall push-offs",
                            value: $score.turnQuality
                        )
                        ScoreRow(
                            title: "Kick Efficiency",
                            description: "Leg kick power and rhythm",
                            value: $score.kickEfficiency
                        )
                    }

                    // Performance
                    ScoreSection(title: "Performance", icon: "speedometer") {
                        ScoreRow(
                            title: "Pace Control",
                            description: "Maintaining target pace",
                            value: $score.paceControl
                        )
                        ScoreRow(
                            title: "Split Consistency",
                            description: "Even lap times across the session",
                            value: $score.splitConsistency
                        )
                        ScoreRow(
                            title: "Interval Adherence",
                            description: "Hit your interval targets",
                            value: $score.intervalAdherence
                        )
                    }

                    // Physical state
                    ScoreSection(title: "Physical State", icon: "figure.pool.swim") {
                        ScoreRow(
                            title: "Endurance Feel",
                            description: "Overall energy and stamina",
                            value: $score.enduranceFeel
                        )
                        ScoreRow(
                            title: "Arm Fatigue",
                            description: "1 = Exhausted, 5 = Fresh",
                            value: $score.armFatigue
                        )
                        ScoreRow(
                            title: "Leg Fatigue",
                            description: "1 = Exhausted, 5 = Fresh",
                            value: $score.legFatigue
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
                                    title: "Technique",
                                    value: score.techniqueAverage,
                                    color: scoreColor(score.techniqueAverage)
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
                                        SwimmingCoachingCard(suggestion: suggestion)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Swim Scorecard")
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
        case 3.5..<4.5: return .cyan
        case 2.5..<3.5: return .orange
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

struct SwimmingCoachingCard: View {
    let suggestion: SwimmingCoachingSuggestion

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
        .background(AppColors.elevatedSurface)
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
    let session = SwimmingSession(name: "Morning Swim")
    let score = SwimmingScore()

    return SwimmingScorecardView(session: session, score: score)
        .modelContainer(for: [SwimmingSession.self, SwimmingScore.self], inMemory: true)
}
