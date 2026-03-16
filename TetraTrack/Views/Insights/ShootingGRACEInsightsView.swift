//
//  ShootingGRACEInsightsView.swift
//  TetraTrack
//
//  Shooting insights using 4 biomechanical pillars + physiology.
//  Pillars: Stability (stance), Rhythm (shot timing), Symmetry (hold steadiness),
//  Economy (hold duration efficiency).
//  Physiology: Composure (HR + tremor + fatigue).
//

import SwiftUI
import Charts

struct ShootingGRACEInsightsView: View {
    let session: ShootingSession

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            if sizeClass == .regular {
                iPadContent
            } else {
                iPhoneContent
            }
        }
        .navigationTitle("Session Insights")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - iPhone Layout

    private var iPhoneContent: some View {
        VStack(spacing: 16) {
            OverallBiomechanicalScore(
                stabilityScore: session.stabilityScore,
                rhythmScore: session.rhythmScore,
                symmetryScore: session.symmetryScore,
                economyScore: session.economyScore
            )
            sessionSummaryCard
            stabilityCard
            rhythmCard
            symmetryCard
            economyCard
            physiologyCard
            perShotSteadinessChart
            fatigueComparisonCard
        }
        .padding()
    }

    // MARK: - iPad Layout

    private var iPadContent: some View {
        VStack(spacing: 16) {
            OverallBiomechanicalScore(
                stabilityScore: session.stabilityScore,
                rhythmScore: session.rhythmScore,
                symmetryScore: session.symmetryScore,
                economyScore: session.economyScore
            )
            sessionSummaryCard

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                stabilityCard
                rhythmCard
                symmetryCard
                economyCard
            }

            physiologyCard
            perShotSteadinessChart
            fatigueComparisonCard
        }
        .padding(24)
    }

    // MARK: - Session Summary

    private var sessionSummaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(.red)
                Text("Session Summary")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(session.totalScore)")
                        .font(.title2.bold())
                    Text("Total Score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    let allShots = (session.ends ?? []).flatMap { $0.shots ?? [] }
                    Text("\(allShots.count)")
                        .font(.title2.bold())
                    Text("Shots")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text(String(format: "%.1f", session.averageScorePerArrow))
                        .font(.title2.bold())
                    Text("Avg/Shot")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            HStack {
                Image(systemName: session.sessionContext.icon)
                    .font(.caption)
                Text(session.sessionContext.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Pillar Cards

    private var stabilityCard: some View {
        PillarScoreCard(
            pillar: .stability,
            subtitle: "Stance",
            score: session.stabilityScore,
            keyMetric: String(format: "%.0f%% stance stability", session.averageStanceStability),
            tip: standTallTip
        )
    }

    private var rhythmCard: some View {
        PillarScoreCard(
            pillar: .rhythm,
            subtitle: "Shot Timing",
            score: session.rhythmScore,
            keyMetric: String(format: "%.2f CV consistency", session.shotTimingConsistencyCV),
            tip: shotTimingTip
        )
    }

    private var symmetryCard: some View {
        PillarScoreCard(
            pillar: .symmetry,
            subtitle: "Hold Steadiness",
            score: session.symmetryScore,
            keyMetric: String(format: "%.0f%% hold steadiness", session.averageHoldSteadiness),
            tip: aimTrueTip
        )
    }

    private var economyCard: some View {
        PillarScoreCard(
            pillar: .economy,
            subtitle: "Shot Cycle",
            score: session.economyScore,
            keyMetric: String(format: "%.1fs avg hold", session.averageHoldDuration),
            tip: shotEconomyTip
        )
    }

    private var physiologyCard: some View {
        PhysiologySectionCard(
            score: session.composureScore,
            keyMetric: session.averageHeartRate > 0
                ? "\(session.averageHeartRate) bpm avg HR"
                : "No HR data",
            tip: composureTip,
            subtitle: "Composure"
        )
    }

    // MARK: - Per-Shot Steadiness Chart

    private var perShotSteadinessChart: some View {
        let shots = (session.ends ?? [])
            .flatMap { $0.shots ?? [] }
            .sorted { $0.orderIndex < $1.orderIndex }
            .filter { $0.hasSensorData }

        return Group {
            if !shots.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "chart.xyaxis.line")
                            .foregroundStyle(.cyan)
                        Text("Shot-by-Shot Steadiness")
                            .font(.headline)
                    }

                    Chart {
                        ForEach(Array(shots.enumerated()), id: \.offset) { index, shot in
                            let endIndex = shot.end?.orderIndex ?? 0
                            BarMark(
                                x: .value("Shot", index + 1),
                                y: .value("Steadiness", shot.holdSteadiness)
                            )
                            .foregroundStyle(endColor(endIndex))
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .chartYAxis {
                        AxisMarks(values: [0, 25, 50, 75, 100])
                    }
                    .frame(height: 200)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Fatigue Comparison

    private var fatigueComparisonCard: some View {
        Group {
            if session.firstHalfSteadiness > 0 || session.secondHalfSteadiness > 0 {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "battery.75percent")
                            .foregroundStyle(.orange)
                        Text("Fatigue Analysis")
                            .font(.headline)
                    }

                    HStack(spacing: 24) {
                        VStack(spacing: 4) {
                            Text(String(format: "%.0f%%", session.firstHalfSteadiness))
                                .font(.title3.bold())
                            Text("First Half")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                        Image(systemName: session.steadinessDegradation > 10 ? "arrow.down.right" : "arrow.right")
                            .font(.title3)
                            .foregroundStyle(session.steadinessDegradation > 10 ? .orange : .green)

                        VStack(spacing: 4) {
                            Text(String(format: "%.0f%%", session.secondHalfSteadiness))
                                .font(.title3.bold())
                            Text("Second Half")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    if session.steadinessDegradation > 10 {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text(String(format: "%.0f%% steadiness degradation — build endurance with extended dry-fire practice", session.steadinessDegradation))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                            Text("Excellent fatigue resistance — your steadiness remained consistent throughout")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Tips

    private var standTallTip: String {
        let stability = session.averageStanceStability
        if stability >= 80 {
            return "Your platform is rock-solid. Maintain this by continuing core stability work."
        } else if stability >= 60 {
            return "Good base. Focus on distributing weight evenly and keeping knees slightly bent."
        } else {
            return "Widen your stance to shoulder width and plant your feet before raising. Practice dry-fire with focus on a stable base."
        }
    }

    private var shotTimingTip: String {
        let cv = session.shotTimingConsistencyCV
        if cv < 0.15 {
            return "Metronome-like timing. Your consistent rhythm is a significant competitive advantage."
        } else if cv < 0.25 {
            return "Good rhythm. Try counting a consistent cadence between shots to tighten your timing."
        } else {
            return "Variable timing between shots. Develop a pre-shot routine: breathe, raise, settle, commit."
        }
    }

    private var aimTrueTip: String {
        let steadiness = session.averageHoldSteadiness
        if steadiness >= 80 {
            return "Excellent hold control. Your aim point barely moves during the hold phase."
        } else if steadiness >= 60 {
            return "Steady hold. Try extending your hold time in practice to build endurance in the aim phase."
        } else {
            return "Your hold shows movement. Practice box breathing before each shot and strengthen your support arm."
        }
    }

    private var shotEconomyTip: String {
        let holdDuration = session.averageHoldDuration
        if holdDuration >= 5 && holdDuration <= 10 {
            return "Ideal shot cycle. You're committing to your shots with good timing."
        } else if holdDuration < 5 {
            return "Fast cycle time. Ensure you're settling fully before committing to the shot."
        } else {
            return "Trust your aim and commit to the shot sooner. Extended holds increase fatigue and tremor."
        }
    }

    private var composureTip: String {
        let degradation = session.steadinessDegradation
        let hr = session.averageHeartRate

        if degradation > 20 {
            return "Build endurance with extended dry-fire practice. Your steadiness drops significantly in the second half."
        } else if hr > 100 {
            return "Elevated heart rate affects precision. Develop a pre-shot routine to manage nerves."
        } else if session.averageTremorLevel > 50 {
            return "Practice box breathing before each shot to reduce tremor. 4 seconds in, 4 hold, 4 out, 4 hold."
        } else {
            return "You're composed under pressure. Your body stays calm and your steadiness holds firm."
        }
    }

    // MARK: - Helpers

    private func endColor(_ endIndex: Int) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .cyan, .red]
        return colors[endIndex % colors.count]
    }
}
