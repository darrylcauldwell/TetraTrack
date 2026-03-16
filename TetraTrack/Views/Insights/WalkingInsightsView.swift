//
//  WalkingInsightsView.swift
//  TetraTrack
//
//  Walking insights using 4 biomechanical pillars + physiology.
//  Pillars: Stability (gait steadiness), Rhythm (step tempo consistency),
//  Symmetry (L/R balance), Economy (gait efficiency).
//  Physiology: HR efficiency / endurance.
//

import SwiftUI

struct WalkingInsightsView: View {
    let session: RunningSession

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Biomechanical Scores

    /// Stability — gait steadiness (from Watch)
    private var stabilityScore: Double {
        session.walkingStabilityScore
    }

    /// Rhythm — step tempo consistency
    private var rhythmScore: Double {
        session.walkingRhythmScore
    }

    /// Symmetry — left-right balance
    private var symmetryScore: Double {
        session.walkingSymmetryScore
    }

    /// Economy — gait economy from pace and cadence efficiency
    private var economyScore: Double {
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

        // Step efficiency (50%)
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

    /// Physiology — HR efficiency / endurance
    private var physiologyScore: Double {
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
        .navigationTitle("Session Insights")
        .navigationBarTitleDisplayMode(.inline)
        .glassNavigation()
        .presentationBackground(Color.black)
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

    // MARK: - Stability Card

    private var stabilityCard: some View {
        let hasData = stabilityScore > 0
        let steadiness = session.healthKitWalkingSteadiness

        return PillarScoreCard(
            pillar: .stability,
            subtitle: "Gait Steadiness",
            score: stabilityScore,
            keyMetric: {
                if let steadiness, steadiness > 0 {
                    return String(format: "%.0f%% Apple Steadiness", steadiness)
                }
                if hasData { return "Score: \(Int(stabilityScore))" }
                return "No steadiness data"
            }(),
            tip: {
                if !hasData { return "Wear Apple Watch for gait steadiness analysis" }
                if stabilityScore >= 80 { return "Very steady gait — consistent pace and smooth movement" }
                if stabilityScore >= 60 { return "Good stability — minor pace fluctuations detected" }
                if stabilityScore >= 40 { return "Moderate variability — focus on posture and even terrain" }
                return "Gait unsteady — try shorter walks on flat ground and build up gradually"
            }()
        )
    }

    // MARK: - Rhythm Card

    private var rhythmCard: some View {
        let hasData = rhythmScore > 0
        let cadence = session.averageCadence

        return PillarScoreCard(
            pillar: .rhythm,
            subtitle: "Step Tempo",
            score: rhythmScore,
            keyMetric: {
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
            }(),
            tip: {
                if !hasData { return "Walk for longer to capture cadence consistency data" }
                if rhythmScore >= 80 { return "Very consistent cadence — great walking rhythm" }
                if rhythmScore >= 60 { return "Good rhythm — slight cadence variation between segments" }
                if rhythmScore >= 40 { return "Moderate variation — try using a metronome app to build rhythm" }
                return "Cadence inconsistent — focus on maintaining steady step rate"
            }()
        )
    }

    // MARK: - Symmetry Card

    private var symmetryCard: some View {
        let hasData = symmetryScore > 0
        let asymmetry = session.healthKitAsymmetry
        let doubleSupport = session.healthKitDoubleSupportPercentage

        return PillarScoreCard(
            pillar: .symmetry,
            subtitle: "L/R Balance",
            score: symmetryScore,
            keyMetric: {
                if let asymmetry, asymmetry > 0 {
                    return String(format: "%.1f%% asymmetry", asymmetry)
                }
                if let doubleSupport, doubleSupport > 0 {
                    return String(format: "%.1f%% double support", doubleSupport)
                }
                if hasData { return "Score: \(Int(symmetryScore))" }
                return "No Watch data"
            }(),
            tip: {
                if !hasData { return "Wear Apple Watch for left-right balance analysis" }
                if symmetryScore >= 80 { return "Excellent symmetry — even stride pattern on both sides" }
                if symmetryScore >= 60 { return "Good balance — minor asymmetry between left and right strides" }
                if symmetryScore >= 40 { return "Moderate imbalance — focus on even weight distribution" }
                return "Significant asymmetry — consider gait assessment or targeted exercises"
            }()
        )
    }

    // MARK: - Economy Card

    private var economyCard: some View {
        let hasData = economyScore > 0

        return PillarScoreCard(
            pillar: .economy,
            subtitle: "Gait Efficiency",
            score: economyScore,
            keyMetric: hasData ? "\(Int(economyScore))% economy" : "Needs pace + cadence",
            tip: {
                if !hasData { return "Walk with consistent pace and cadence for economy analysis" }
                if economyScore >= 80 { return "Very efficient gait — optimal speed and stride length" }
                if economyScore >= 60 { return "Good economy — minor room for improvement" }
                return "Gait efficiency low — try maintaining a natural, brisk pace"
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
                if !hasHR { return "Wear Apple Watch for heart rate efficiency analysis" }
                if physiologyScore >= 80 { return "Excellent efficiency — heart rate well controlled during walk" }
                if physiologyScore >= 60 { return "Good cardiovascular effort — steady heart rate response" }
                if physiologyScore >= 40 { return "Moderate effort — try maintaining a conversational pace" }
                return "High cardiac effort — consider shorter walks or slower pace to build base"
            }(),
            subtitle: "HR Efficiency"
        )
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
