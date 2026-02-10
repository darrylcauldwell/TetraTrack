//
//  SwimmingInsightsView.swift
//  TetraTrack
//
//  Concise, actionable swimming insights with pillar-based scoring.
//  Pillars: Technique (SWOLF), Efficiency (strokes), Pace, Recovery
//

import SwiftUI
import Charts

struct SwimmingInsightsView: View {
    let session: SwimmingSession

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Scores

    /// Technique score based on SWOLF (lower = better)
    private var techniqueScore: Double {
        let swolf = session.averageSwolf
        guard swolf > 0 else { return 0 }

        // SWOLF benchmarks (25m pool): Elite <35, Good 35-45, Average 45-60, Beginner >60
        if swolf < 35 { return 95 }
        if swolf < 40 { return 85 }
        if swolf < 45 { return 75 }
        if swolf < 50 { return 65 }
        if swolf < 55 { return 55 }
        if swolf < 60 { return 45 }
        return 35
    }

    /// Efficiency score based on strokes per lap consistency
    private var efficiencyScore: Double {
        let laps = session.sortedLaps
        guard laps.count >= 2 else { return 0 }

        let strokes = laps.compactMap { $0.strokeCount > 0 ? Double($0.strokeCount) : nil }
        guard strokes.count >= 2 else { return 0 }

        let mean = strokes.reduce(0, +) / Double(strokes.count)
        guard mean > 0 else { return 0 }

        let variance = strokes.reduce(0) { $0 + pow($1 - mean, 2) } / Double(strokes.count)
        let cv = (sqrt(variance) / mean) * 100

        // Lower CV = more consistent strokes = higher score
        if cv < 5 { return 95 }
        if cv < 10 { return 80 }
        if cv < 15 { return 65 }
        if cv < 20 { return 50 }
        return 35
    }

    /// Pace score based on lap time consistency
    private var paceScore: Double {
        let laps = session.sortedLaps
        guard laps.count >= 2 else { return 0 }

        let times = laps.map { $0.duration }
        let mean = times.reduce(0, +) / Double(times.count)
        guard mean > 0 else { return 0 }

        let variance = times.reduce(0) { $0 + pow($1 - mean, 2) } / Double(times.count)
        let cv = (sqrt(variance) / mean) * 100

        // Lower CV = more consistent pacing = higher score
        if cv < 5 { return 95 }
        if cv < 8 { return 80 }
        if cv < 12 { return 65 }
        if cv < 18 { return 50 }
        return 35
    }

    /// Recovery score based on HR data
    private var recoveryScore: Double {
        guard session.averageHeartRate > 0, session.maxHeartRate > 0 else { return 0 }

        // Use recovery quality if available
        if session.recoveryQuality > 0 {
            return session.recoveryQuality
        }

        // Otherwise estimate from HR range
        let hrRange = session.maxHeartRate - session.minHeartRate
        let avgIntensity = Double(session.averageHeartRate) / Double(session.maxHeartRate) * 100

        // Good recovery = moderate HR range with controlled average
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
        .navigationTitle("Swim Insights")
        .navigationBarTitleDisplayMode(.inline)
        .glassNavigation()
        .presentationBackground(Color.black)
    }

    // MARK: - iPad Layout

    private var iPadContent: some View {
        VStack(spacing: 20) {
            overallSwimScore
            sessionSummaryCard

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                techniqueCard
                efficiencyCard
                paceCard
                recoveryCard
            }
        }
        .padding(24)
    }

    // MARK: - iPhone Layout

    private var iPhoneContent: some View {
        VStack(spacing: 16) {
            overallSwimScore
            sessionSummaryCard
            techniqueCard
            efficiencyCard
            paceCard
            recoveryCard
        }
        .padding()
    }

    // MARK: - Overall Score

    private var overallSwimScore: some View {
        let scores = [techniqueScore, efficiencyScore, paceScore, recoveryScore].filter { $0 > 0 }
        let overall = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)

        return VStack(spacing: 8) {
            Text("Swim Score")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("\(Int(overall))")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(scoreColor(overall))

            HStack(spacing: 20) {
                pillarMini("T", score: techniqueScore)
                pillarMini("E", score: efficiencyScore)
                pillarMini("P", score: paceScore)
                pillarMini("R", score: recoveryScore)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func pillarMini(_ letter: String, score: Double) -> some View {
        VStack(spacing: 4) {
            Text(letter)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(score > 0 ? "\(Int(score))" : "-")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(score > 0 ? scoreColor(score) : .secondary)
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...: return .green
        case 60..<80: return .blue
        case 40..<60: return .yellow
        default: return .orange
        }
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

    // MARK: - Technique Card

    private var techniqueCard: some View {
        let swolf = session.averageSwolf
        let hasData = swolf > 0

        let keyMetric: String = {
            if hasData { return String(format: "%.0f SWOLF", swolf) }
            return "Needs lap data"
        }()

        let tip: String = {
            if !hasData { return "Complete laps for SWOLF calculation (time + strokes)" }
            if swolf < 40 { return "Excellent technique - efficient stroke and speed balance" }
            if swolf < 50 { return "Good technique - focus on distance per stroke" }
            if swolf < 60 { return "Work on glide phase - less strokes, same speed" }
            return "Focus on technique drills - catch, pull, and streamlining"
        }()

        return pillarCard(
            letter: "T",
            title: "Technique",
            subtitle: "Stroke Efficiency",
            score: techniqueScore,
            keyMetric: keyMetric,
            tip: tip,
            icon: "waveform.path",
            color: .cyan
        )
    }

    // MARK: - Efficiency Card

    private var efficiencyCard: some View {
        let avgStrokes = session.averageStrokesPerLap
        let hasData = avgStrokes > 0 && session.lapCount >= 2

        let keyMetric: String = {
            if avgStrokes > 0 { return String(format: "%.1f strokes/lap", avgStrokes) }
            return "Needs 2+ laps"
        }()

        let tip: String = {
            if !hasData { return "Swim more laps to measure stroke consistency" }
            if efficiencyScore >= 80 { return "Very consistent stroke count - great rhythm" }
            if efficiencyScore >= 60 { return "Good consistency - minor variation between laps" }
            return "Stroke count varies - focus on maintaining rhythm when tired"
        }()

        return pillarCard(
            letter: "E",
            title: "Efficiency",
            subtitle: "Stroke Consistency",
            score: efficiencyScore,
            keyMetric: keyMetric,
            tip: tip,
            icon: "arrow.triangle.2.circlepath",
            color: .blue
        )
    }

    // MARK: - Pace Card

    private var paceCard: some View {
        let hasData = session.lapCount >= 2

        let keyMetric: String = {
            if hasData { return session.formattedPace + " avg" }
            return "Needs 2+ laps"
        }()

        let tip: String = {
            if !hasData { return "Swim more laps to analyze pacing" }
            if paceScore >= 80 { return "Excellent pacing - very even splits" }
            if paceScore >= 60 { return "Good pace control - slight variation" }
            return "Pacing inconsistent - try negative splitting (start slower)"
        }()

        return pillarCard(
            letter: "P",
            title: "Pace",
            subtitle: "Speed Consistency",
            score: paceScore,
            keyMetric: keyMetric,
            tip: tip,
            icon: "speedometer",
            color: .purple
        )
    }

    // MARK: - Recovery Card

    private var recoveryCard: some View {
        let hasHR = session.averageHeartRate > 0

        let keyMetric: String = {
            if hasHR { return "\(session.averageHeartRate) avg bpm" }
            return "Needs heart rate"
        }()

        let tip: String = {
            if !hasHR { return "Wear Apple Watch for heart rate recovery analysis" }
            if recoveryScore >= 80 { return "Strong recovery - good cardiovascular fitness" }
            if recoveryScore >= 60 { return "Decent recovery - consider rest between sets" }
            return "Recovery needs work - add more easy swimming days"
        }()

        return pillarCard(
            letter: "R",
            title: "Recovery",
            subtitle: "Heart Rate Control",
            score: recoveryScore,
            keyMetric: keyMetric,
            tip: tip,
            icon: "heart.fill",
            color: .red
        )
    }

    // MARK: - Pillar Card Template

    private func pillarCard(
        letter: String,
        title: String,
        subtitle: String,
        score: Double,
        keyMetric: String,
        tip: String,
        icon: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(letter)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(color)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(score > 0 ? "\(Int(score))" : "-")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(score > 0 ? scoreColor(score) : .secondary)
            }

            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(keyMetric)
                    .font(.subheadline)
            }

            Text(tip)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
