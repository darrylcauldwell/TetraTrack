//
//  SwimmingInsightsView.swift
//  TetraTrack
//
//  Swimming insights using 4 biomechanical pillars + physiology.
//  Pillars: Stability (SWOLF), Rhythm (lap time consistency),
//  Symmetry (distance per stroke), Economy (stroke count consistency).
//  Physiology: HR recovery quality.
//

import SwiftUI
import Charts

struct SwimmingInsightsView: View {
    let session: SwimmingSession

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Biomechanical Scores

    /// Stability — SWOLF (lower = better)
    private var stabilityScore: Double {
        let swolf = session.averageSwolf
        guard swolf > 0 else { return 0 }

        if swolf < 35 { return 95 }
        if swolf < 40 { return 85 }
        if swolf < 45 { return 75 }
        if swolf < 50 { return 65 }
        if swolf < 55 { return 55 }
        if swolf < 60 { return 45 }
        return 35
    }

    /// Rhythm — lap time consistency
    private var rhythmScore: Double {
        let laps = session.sortedLaps
        guard laps.count >= 2 else { return 0 }

        let times = laps.map { $0.duration }
        let mean = times.reduce(0, +) / Double(times.count)
        guard mean > 0 else { return 0 }

        let variance = times.reduce(0) { $0 + pow($1 - mean, 2) } / Double(times.count)
        let cv = (sqrt(variance) / mean) * 100

        if cv < 5 { return 95 }
        if cv < 8 { return 80 }
        if cv < 12 { return 65 }
        if cv < 18 { return 50 }
        return 35
    }

    /// Symmetry — distance per stroke (fewer strokes = better catch & pull)
    private var symmetryScore: Double {
        let avgStrokes = session.averageStrokesPerLap
        guard avgStrokes > 0 else { return 0 }

        let adjustedStrokes = session.poolLength > 30 ? avgStrokes / 2 : avgStrokes

        if adjustedStrokes < 14 { return 95 }
        if adjustedStrokes < 16 { return 85 }
        if adjustedStrokes < 18 { return 75 }
        if adjustedStrokes < 20 { return 65 }
        if adjustedStrokes < 22 { return 55 }
        if adjustedStrokes < 26 { return 45 }
        return 35
    }

    /// Economy — stroke count consistency
    private var economyScore: Double {
        let laps = session.sortedLaps
        guard laps.count >= 2 else { return 0 }

        let strokes = laps.compactMap { $0.strokeCount > 0 ? Double($0.strokeCount) : nil }
        guard strokes.count >= 2 else { return 0 }

        let mean = strokes.reduce(0, +) / Double(strokes.count)
        guard mean > 0 else { return 0 }

        let variance = strokes.reduce(0) { $0 + pow($1 - mean, 2) } / Double(strokes.count)
        let cv = (sqrt(variance) / mean) * 100

        if cv < 5 { return 95 }
        if cv < 10 { return 80 }
        if cv < 15 { return 65 }
        if cv < 20 { return 50 }
        return 35
    }

    /// Physiology — HR recovery
    private var physiologyScore: Double {
        guard session.averageHeartRate > 0, session.maxHeartRate > 0 else { return 0 }

        if session.recoveryQuality > 0 {
            return session.recoveryQuality
        }

        let hrRange = session.maxHeartRate - session.minHeartRate
        let avgIntensity = Double(session.averageHeartRate) / Double(session.maxHeartRate) * 100

        if hrRange > 30 && avgIntensity < 80 { return 80 }
        if hrRange > 20 && avgIntensity < 85 { return 65 }
        if avgIntensity < 90 { return 50 }
        return 40
    }

    var body: some View {
        ScrollView {
            if horizontalSizeClass == .regular {
                iPadContent
            } else {
                iPhoneContent
            }
        }
        .navigationTitle("Session Insights")
        .navigationBarTitleDisplayMode(.inline)
        .glassNavigation()
        .sheetBackground()
    }

    // MARK: - iPad Layout

    private var iPadContent: some View {
        VStack(spacing: 20) {
            OverallBiomechanicalScore(
                stabilityScore: stabilityScore,
                rhythmScore: rhythmScore,
                symmetryScore: symmetryScore,
                economyScore: economyScore
            )
            sessionSummaryCard

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                stabilityCard
                rhythmCard
                symmetryCard
                economyCard
            }

            physiologyCard
        }
        .padding(24)
    }

    // MARK: - iPhone Layout

    private var iPhoneContent: some View {
        VStack(spacing: 16) {
            OverallBiomechanicalScore(
                stabilityScore: stabilityScore,
                rhythmScore: rhythmScore,
                symmetryScore: symmetryScore,
                economyScore: economyScore
            )
            sessionSummaryCard
            stabilityCard
            rhythmCard
            symmetryCard
            economyCard
            physiologyCard
        }
        .padding()
    }

    // MARK: - Session Summary Card

    private var sessionSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.pool.swim")
                    .foregroundStyle(.cyan)
                Text(session.isOpenWater ? "Open Water" : "\(Int(session.poolLength))m Pool")
                    .font(.headline)
                Spacer()
                Text(session.dominantStroke.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 24) {
                VStack {
                    Text(session.formattedDistance)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("Distance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack {
                    Text(session.formattedDuration)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("Time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack {
                    Text("\(session.lapCount)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("Laps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack {
                    Text(session.formattedPace)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("/100m")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Stability Card

    private var stabilityCard: some View {
        let swolf = session.averageSwolf
        let hasData = swolf > 0

        return PillarScoreCard(
            pillar: .stability,
            subtitle: "SWOLF",
            score: stabilityScore,
            keyMetric: hasData ? String(format: "%.0f SWOLF", swolf) : "Needs lap data",
            tip: {
                if !hasData { return "Complete laps for SWOLF calculation (time + strokes)" }
                if swolf < 40 { return "Excellent technique — efficient stroke and speed balance" }
                if swolf < 50 { return "Good technique — focus on distance per stroke" }
                if swolf < 60 { return "Work on glide phase — fewer strokes, same speed" }
                return "Focus on technique drills — catch, pull, and streamlining"
            }()
        )
    }

    // MARK: - Rhythm Card

    private var rhythmCard: some View {
        let hasData = session.lapCount >= 2

        return PillarScoreCard(
            pillar: .rhythm,
            subtitle: "Lap Consistency",
            score: rhythmScore,
            keyMetric: hasData ? session.formattedPace + " avg" : "Needs 2+ laps",
            tip: {
                if !hasData { return "Swim more laps to analyse pacing" }
                if rhythmScore >= 80 { return "Excellent pacing — very even splits" }
                if rhythmScore >= 60 { return "Good pace control — slight variation" }
                return "Pacing inconsistent — try negative splitting (start slower)"
            }()
        )
    }

    // MARK: - Symmetry Card

    private var symmetryCard: some View {
        let avgStrokes = session.averageStrokesPerLap
        let hasData = avgStrokes > 0

        return PillarScoreCard(
            pillar: .symmetry,
            subtitle: "Distance Per Stroke",
            score: symmetryScore,
            keyMetric: hasData ? String(format: "%.1f strokes/lap", avgStrokes) : "Needs stroke data",
            tip: {
                if !hasData { return "Wear Apple Watch to count strokes per lap" }
                if symmetryScore >= 80 { return "Excellent DPS — strong catch and pull phase" }
                if symmetryScore >= 60 { return "Good stroke length — focus on catch entry angle" }
                return "High stroke count — work on glide and body rotation"
            }()
        )
    }

    // MARK: - Economy Card

    private var economyCard: some View {
        let avgStrokes = session.averageStrokesPerLap
        let hasData = avgStrokes > 0 && session.lapCount >= 2

        return PillarScoreCard(
            pillar: .economy,
            subtitle: "Stroke Consistency",
            score: economyScore,
            keyMetric: avgStrokes > 0 ? String(format: "%.1f strokes/lap", avgStrokes) : "Needs 2+ laps",
            tip: {
                if !hasData { return "Swim more laps to measure stroke consistency" }
                if economyScore >= 80 { return "Very consistent stroke count — great rhythm" }
                if economyScore >= 60 { return "Good consistency — minor variation between laps" }
                return "Stroke count varies — focus on maintaining rhythm when tired"
            }()
        )
    }

    // MARK: - Physiology Card

    private var physiologyCard: some View {
        let hasHR = session.averageHeartRate > 0

        return PhysiologySectionCard(
            score: physiologyScore,
            keyMetric: hasHR ? "\(session.averageHeartRate) avg bpm" : "Needs heart rate",
            tip: {
                if !hasHR { return "Wear Apple Watch for heart rate recovery analysis" }
                if physiologyScore >= 80 { return "Strong recovery — good cardiovascular fitness" }
                if physiologyScore >= 60 { return "Decent recovery — consider rest between sets" }
                return "Recovery needs work — add more easy swimming days"
            }(),
            subtitle: "Recovery Quality"
        )
    }
}

// MARK: - Preview

#Preview("Full Data") {
    NavigationStack {
        SwimmingInsightsView(session: {
            let session = SwimmingSession(name: "Morning Swim", poolMode: .pool, poolLength: 25)
            session.totalDistance = 1500
            session.totalDuration = 1800
            session.totalStrokes = 450
            session.averageHeartRate = 145
            session.maxHeartRate = 165
            session.minHeartRate = 120
            return session
        }())
    }
}

#Preview("Minimal Data") {
    NavigationStack {
        SwimmingInsightsView(session: {
            let session = SwimmingSession(name: "Quick Dip", poolMode: .pool, poolLength: 25)
            session.totalDistance = 200
            session.totalDuration = 300
            return session
        }())
    }
}
