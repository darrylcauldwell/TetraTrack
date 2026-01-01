//
//  WalkingInsightsView.swift
//  TetraTrack
//
//  Walking insights using the GRACE framework.
//  Pillars: Grow (walk upright/steadiness), Rhythm (step tempo),
//  Align (symmetry), Circle (gait economy), Enjoy (endurance).
//

import SwiftUI

struct WalkingInsightsView: View {
    let session: RunningSession

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - GRACE Scores

    /// G: Grow — walk upright, gait steadiness
    private var growScore: Double {
        session.walkingStabilityScore
    }

    /// R: Rhythm — step tempo, cadence consistency
    private var rhythmScore: Double {
        session.walkingRhythmScore
    }

    /// A: Align — left-right symmetry
    private var alignScore: Double {
        session.walkingSymmetryScore
    }

    /// C: Circle — gait economy from pace and cadence efficiency
    private var circleScore: Double {
        var total: Double = 0
        var weight: Double = 0

        // Pace efficiency (50%) — optimal walking speed is ~1.2-1.4 m/s
        if session.totalDistance > 0 && session.totalDuration > 0 {
            let avgSpeed = session.totalDistance / session.totalDuration
            if avgSpeed > 0 {
                if avgSpeed >= 1.1 && avgSpeed <= 1.5 { total += 85 * 0.5 }
                else if avgSpeed >= 0.9 && avgSpeed <= 1.7 { total += 70 * 0.5 }
                else { total += 50 * 0.5 }
                weight += 0.5
            }
        }

        // Step efficiency (50%) — steps per meter, lower = longer strides = more economical
        if session.averageCadence > 0 && session.totalDistance > 0 && session.totalDuration > 0 {
            let stepsPerMinute = Double(session.averageCadence)
            let metersPerMinute = session.totalDistance / (session.totalDuration / 60)
            if metersPerMinute > 0 {
                let stepsPerMeter = stepsPerMinute / metersPerMinute
                if stepsPerMeter < 1.5 { total += 85 * 0.5 }
                else if stepsPerMeter < 2.0 { total += 70 * 0.5 }
                else { total += 50 * 0.5 }
                weight += 0.5
            }
        }

        return weight > 0 ? total / weight : 0
    }

    /// E: Enjoy — heart rate efficiency / endurance
    private var enjoyScore: Double {
        guard session.averageHeartRate > 0, session.maxHeartRate > 0 else { return 0 }

        let avgHR = Double(session.averageHeartRate)
        let maxHR = Double(session.maxHeartRate)
        guard maxHR > 0 else { return 0 }

        let efficiency = avgHR / maxHR
        let hrRange = maxHR - Double(session.minHeartRate > 0 ? session.minHeartRate : session.averageHeartRate)

        var score: Double = 0

        // Efficiency component (60% weight)
        if efficiency < 0.75 { score += 60 }
        else if efficiency < 0.80 { score += 50 }
        else if efficiency < 0.85 { score += 40 }
        else if efficiency < 0.90 { score += 30 }
        else { score += 20 }

        // HR range component (40% weight)
        if hrRange > 30 { score += 40 }
        else if hrRange > 20 { score += 32 }
        else if hrRange > 15 { score += 24 }
        else if hrRange > 10 { score += 16 }
        else { score += 10 }

        return min(score, 100)
    }

    var body: some View {
        ScrollView {
            if horizontalSizeClass == .regular {
                iPadContent
            } else {
                iPhoneContent
            }
        }
        .navigationTitle("GRACE Insights")
        .navigationBarTitleDisplayMode(.inline)
        .glassNavigation()
        .presentationBackground(Color.black)
    }

    // MARK: - iPad Layout

    private var iPadContent: some View {
        VStack(spacing: 20) {
            overallGraceScore
            sessionSummaryCard

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                growCard
                rhythmCard
                alignCard
                circleCard
            }

            enjoyCard
        }
        .padding(24)
    }

    // MARK: - iPhone Layout

    private var iPhoneContent: some View {
        VStack(spacing: 16) {
            overallGraceScore
            sessionSummaryCard
            growCard
            rhythmCard
            alignCard
            circleCard
            enjoyCard
        }
        .padding()
    }

    // MARK: - Overall Score

    private var overallGraceScore: some View {
        let scores = [growScore, rhythmScore, alignScore, circleScore, enjoyScore].filter { $0 > 0 }
        let overall = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)

        return VStack(spacing: 8) {
            Text("GRACE Score")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("\(Int(overall))")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(scoreColor(overall))

            HStack(spacing: 16) {
                pillarMini("G", score: growScore)
                pillarMini("R", score: rhythmScore)
                pillarMini("A", score: alignScore)
                pillarMini("C", score: circleScore)
                pillarMini("E", score: enjoyScore)
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
                Image(systemName: "figure.walk")
                    .foregroundStyle(.teal)
                Text("Walking")
                    .font(.headline)
                Spacer()
                if session.averageCadence > 0 {
                    Text("\(session.averageCadence) SPM")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
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
                    Text(session.formattedPace)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("Pace")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if session.averageCadence > 0 {
                    VStack {
                        Text("\(session.averageCadence)")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                        Text("Cadence")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - G: Grow Card

    private var growCard: some View {
        let hasData = growScore > 0
        let steadiness = session.healthKitWalkingSteadiness

        let keyMetric: String = {
            if let steadiness, steadiness > 0 {
                return String(format: "%.0f%% Apple Steadiness", steadiness)
            }
            if hasData { return "Score: \(Int(growScore))" }
            return "No steadiness data"
        }()

        let tip: String = {
            if !hasData { return "Wear Apple Watch for gait steadiness analysis" }
            if growScore >= 80 { return "Very steady gait — consistent pace and smooth movement" }
            if growScore >= 60 { return "Good stability — minor pace fluctuations detected" }
            if growScore >= 40 { return "Moderate variability — focus on posture and even terrain" }
            return "Gait unsteady — try shorter walks on flat ground and build up gradually"
        }()

        return pillarCard(
            letter: "G",
            title: "Grow",
            subtitle: "Walk Upright",
            score: growScore,
            keyMetric: keyMetric,
            tip: tip,
            icon: "arrow.up.circle.fill",
            color: .green
        )
    }

    // MARK: - R: Rhythm Card

    private var rhythmCard: some View {
        let hasData = rhythmScore > 0
        let cadence = session.averageCadence

        let keyMetric: String = {
            if cadence > 0 {
                let target = session.targetCadence > 0 ? session.targetCadence : 120
                let diff = cadence - target
                if diff >= 0 {
                    return "\(cadence) SPM (+\(diff) vs target)"
                } else {
                    return "\(cadence) SPM (\(diff) vs target)"
                }
            }
            if hasData { return "Score: \(Int(rhythmScore))" }
            return "No cadence data"
        }()

        let tip: String = {
            if !hasData { return "Walk for longer to capture cadence consistency data" }
            if rhythmScore >= 80 { return "Very consistent cadence — great walking rhythm" }
            if rhythmScore >= 60 { return "Good rhythm — slight cadence variation between segments" }
            if rhythmScore >= 40 { return "Moderate variation — try using a metronome app to build rhythm" }
            return "Cadence inconsistent — focus on maintaining steady step rate"
        }()

        return pillarCard(
            letter: "R",
            title: "Rhythm",
            subtitle: "Step Tempo",
            score: rhythmScore,
            keyMetric: keyMetric,
            tip: tip,
            icon: "metronome.fill",
            color: .indigo
        )
    }

    // MARK: - A: Align Card

    private var alignCard: some View {
        let hasData = alignScore > 0
        let asymmetry = session.healthKitAsymmetry
        let doubleSupport = session.healthKitDoubleSupportPercentage

        let keyMetric: String = {
            if let asymmetry, asymmetry > 0 {
                return String(format: "%.1f%% asymmetry", asymmetry)
            }
            if let doubleSupport, doubleSupport > 0 {
                return String(format: "%.1f%% double support", doubleSupport)
            }
            if hasData { return "Score: \(Int(alignScore))" }
            return "No Watch data"
        }()

        let tip: String = {
            if !hasData { return "Wear Apple Watch for left-right balance analysis" }
            if alignScore >= 80 { return "Excellent symmetry — even stride pattern on both sides" }
            if alignScore >= 60 { return "Good balance — minor asymmetry between left and right strides" }
            if alignScore >= 40 { return "Moderate imbalance — focus on even weight distribution" }
            return "Significant asymmetry — consider gait assessment or targeted exercises"
        }()

        return pillarCard(
            letter: "A",
            title: "Align",
            subtitle: "Symmetry",
            score: alignScore,
            keyMetric: keyMetric,
            tip: tip,
            icon: "arrow.left.arrow.right",
            color: .orange
        )
    }

    // MARK: - C: Circle Card

    private var circleCard: some View {
        let hasData = circleScore > 0

        let keyMetric: String = {
            if hasData { return "\(Int(circleScore))% economy" }
            return "Needs pace + cadence"
        }()

        let tip: String = {
            if !hasData { return "Walk with consistent pace and cadence for economy analysis" }
            if circleScore >= 80 { return "Very efficient gait — optimal speed and stride length" }
            if circleScore >= 60 { return "Good economy — minor room for improvement" }
            return "Gait efficiency low — try maintaining a natural, brisk pace"
        }()

        return pillarCard(
            letter: "C",
            title: "Circle",
            subtitle: "Gait Economy",
            score: circleScore,
            keyMetric: keyMetric,
            tip: tip,
            icon: "arrow.triangle.2.circlepath",
            color: .purple
        )
    }

    // MARK: - E: Enjoy Card

    private var enjoyCard: some View {
        let hasHR = session.averageHeartRate > 0

        let keyMetric: String = {
            if hasHR { return "\(session.averageHeartRate) avg bpm" }
            return "Needs heart rate"
        }()

        let tip: String = {
            if !hasHR { return "Wear Apple Watch for heart rate efficiency analysis" }
            if enjoyScore >= 80 { return "Excellent efficiency — heart rate well controlled during walk" }
            if enjoyScore >= 60 { return "Good cardiovascular effort — steady heart rate response" }
            if enjoyScore >= 40 { return "Moderate effort — try maintaining a conversational pace" }
            return "High cardiac effort — consider shorter walks or slower pace to build base"
        }()

        return pillarCard(
            letter: "E",
            title: "Enjoy",
            subtitle: "Endurance",
            score: enjoyScore,
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
        WalkingInsightsView(session: {
            let session = RunningSession()
            session.sessionTypeRaw = "walking"
            session.totalDistance = 3200
            session.totalDuration = 2400
            session.averageCadence = 115
            session.targetCadence = 120
            session.averageHeartRate = 105
            session.maxHeartRate = 128
            session.minHeartRate = 85
            session.walkingSymmetryScore = 78
            session.walkingRhythmScore = 82
            session.walkingStabilityScore = 71
            session.healthKitDoubleSupportPercentage = 28.5
            session.healthKitWalkingSteadiness = 85
            return session
        }())
    }
}

#Preview("Minimal Data") {
    NavigationStack {
        WalkingInsightsView(session: {
            let session = RunningSession()
            session.sessionTypeRaw = "walking"
            session.totalDistance = 1000
            session.totalDuration = 900
            return session
        }())
    }
}
