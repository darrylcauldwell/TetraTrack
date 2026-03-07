//
//  RunningInsightsView.swift
//  TetraTrack
//
//  Running biomechanics insights using the GRACE framework
//  (Becky Lyne's GRACE Running Method — gracefullrunning.com).
//  Pillars: Grow (run tall), Rhythm (light & quick), Align (forward lean),
//  Circle (smooth motion), Enjoy (wellbeing & progress).
//  All scores are data-driven from HealthKit and session metrics.
//

import SwiftUI
import SwiftData
import Charts

struct RunningInsightsView: View {
    let session: RunningSession

    @Query private var profiles: [RiderProfile]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var bio: RunnerBiomechanics {
        RunnerBiomechanics(profile: profiles.first)
    }

    // MARK: - HealthKit Data Helpers

    /// Stride length preferring Apple Watch data over phone estimates
    private var bestStrideLength: Double {
        session.healthKitStrideLength ?? session.estimatedStrideLength
    }

    /// Running power preferring Apple Watch data
    private var bestPower: Double {
        if let hkPower = session.healthKitPower, hkPower > 0 {
            return hkPower
        }
        return bio.estimatedRunningPower(from: session)
    }

    /// Asymmetry from Apple Watch (phone can't reliably measure this)
    private var watchAsymmetry: Double? {
        session.healthKitAsymmetry
    }

    // MARK: - GRACE Score Computations

    // G: Grow — posture stability and vertical oscillation
    private var growScore: Double {
        var total: Double = 0
        var weight: Double = 0

        // Posture stability (50%)
        if session.postureStability > 0 {
            total += session.postureStability * 0.5
            weight += 0.5
        }

        // Inverted oscillation (50%) — lower oscillation = higher score
        if session.averageVerticalOscillation > 0 {
            let stride = bestStrideLength > 0 ? bestStrideLength : nil
            let oscScore = bio.oscillationScore(oscillation: session.averageVerticalOscillation, strideLength: stride)
            total += oscScore * 0.5
            weight += 0.5
        }

        return weight > 0 ? total / weight : 0
    }

    // R: Rhythm — cadence, GCT, pacing consistency
    private var rhythmScore: Double {
        var total: Double = 0
        var weight: Double = 0

        // Cadence proximity to optimal (40%)
        let cadence = session.averageCadence
        if cadence > 0 {
            let cadenceScore = bio.cadenceScore(cadence: cadence)
            total += cadenceScore * 0.4
            weight += 0.4
        }

        // Inverted GCT (30%) — lower GCT = higher score
        if session.averageGroundContactTime > 0 {
            let gct = session.averageGroundContactTime
            let gctScore: Double = gct < 250 ? 90 : (gct < 300 ? 70 : 40)
            total += gctScore * 0.3
            weight += 0.3
        }

        // Pacing CV (30%) — lower CV = higher score
        let splits = session.sortedSplits
        if splits.count >= 2 {
            let paces = splits.map { $0.pace }
            let mean = paces.reduce(0, +) / Double(paces.count)
            if mean > 0 {
                let variance = paces.reduce(0) { $0 + pow($1 - mean, 2) } / Double(paces.count)
                let cv = (sqrt(variance) / mean) * 100
                let pacingScore: Double
                if cv < 3 { pacingScore = 95 }
                else if cv < 6 { pacingScore = 75 }
                else if cv < 10 { pacingScore = 50 }
                else { pacingScore = 30 }
                total += pacingScore * 0.3
                weight += 0.3
            }
        }

        return weight > 0 ? total / weight : 0
    }

    // A: Align — stride length, asymmetry, efficiency factor, power
    private var alignScore: Double {
        var total: Double = 0
        var weight: Double = 0

        // Stride length scored relative to leg length (30%)
        let stride = bestStrideLength
        if stride > 0 {
            let strideScore = bio.strideLengthScore(strideLength: stride)
            total += strideScore * 0.3
            weight += 0.3
        }

        // Asymmetry from Apple Watch (25%) — lower is better
        if let asymmetry = watchAsymmetry {
            let asymmetryScore: Double
            if asymmetry < 3 { asymmetryScore = 95 }
            else if asymmetry < 6 { asymmetryScore = 80 }
            else if asymmetry < 10 { asymmetryScore = 60 }
            else { asymmetryScore = 40 }
            total += asymmetryScore * 0.25
            weight += 0.25
        }

        // Efficiency factor (25%)
        let ef = session.efficiencyFactor
        if ef > 0 {
            let efScore: Double
            if ef < 1.5 { efScore = 90 }
            else if ef < 2.0 { efScore = 70 }
            else { efScore = 40 }
            total += efScore * 0.25
            weight += 0.25
        }

        // Power metric (20%) — prefers Apple Watch via bestPower
        let power = bestPower
        if power > 0 {
            let powerPerKg = bio.wattsPerKg(power: power)
            let powerScore: Double
            if powerPerKg >= 3.0 && powerPerKg <= 5.0 { powerScore = 85 }
            else if powerPerKg < 3.0 { powerScore = 70 }
            else { powerScore = 60 }
            total += powerScore * 0.2
            weight += 0.2
        }

        return weight > 0 ? total / weight : 0
    }

    // C: Circle — running economy composite
    private var circleScore: Double {
        var score: Double = 0
        var factors: Double = 0

        if session.averageCadence > 0 {
            score += bio.cadenceScore(cadence: session.averageCadence)
            factors += 1
        }

        if session.averageVerticalOscillation > 0 {
            let stride = bestStrideLength > 0 ? bestStrideLength : nil
            score += bio.oscillationScore(oscillation: session.averageVerticalOscillation, strideLength: stride)
            factors += 1
        }

        if session.averageGroundContactTime > 0 {
            if session.averageGroundContactTime < 250 { score += 90 }
            else if session.averageGroundContactTime < 300 { score += 70 }
            else { score += 40 }
            factors += 1
        }

        return factors > 0 ? score / factors : 0
    }

    // E: Enjoy — HR efficiency, HR recovery, fatigue, breathing
    private var enjoyScore: Double {
        var total: Double = 0
        var weight: Double = 0

        // HR efficiency (25%)
        if session.averageHeartRate > 0 && session.maxHeartRate > 0 {
            let ratio = Double(session.averageHeartRate) / Double(session.maxHeartRate)
            let hrScore: Double
            if ratio >= 0.75 && ratio <= 0.85 { hrScore = 85 }
            else if ratio < 0.75 { hrScore = 70 }
            else { hrScore = max(40, 85 - (ratio - 0.85) * 300) }
            total += hrScore * 0.25
            weight += 0.25
        }

        // Inverse fatigue (25%)
        if session.endFatigueScore > 0 {
            let inverseFatigue = max(0, 100 - session.endFatigueScore)
            total += inverseFatigue * 0.25
            weight += 0.25
        }

        // Recovery score (25%) — prefer Apple Watch HR Recovery 1-min
        if let hrRecovery = session.healthKitHRRecoveryOneMinute, hrRecovery > 0 {
            let recoveryFromHK: Double
            if hrRecovery >= 30 { recoveryFromHK = 95 }
            else if hrRecovery >= 20 { recoveryFromHK = 75 }
            else if hrRecovery >= 10 { recoveryFromHK = 50 }
            else { recoveryFromHK = 30 }
            total += recoveryFromHK * 0.25
            weight += 0.25
        } else {
            let recovery = session.recoveryScore
            if recovery > 0 {
                total += recovery * 0.25
                weight += 0.25
            }
        }

        // Breathing efficiency (25%) — breathing rate relative to HR
        if session.averageBreathingRate > 0 && session.averageHeartRate > 0 {
            let breathsPerHundredBeats = (session.averageBreathingRate / Double(session.averageHeartRate)) * 100
            let breathScore: Double
            if breathsPerHundredBeats < 20 { breathScore = 90 }
            else if breathsPerHundredBeats < 25 { breathScore = 75 }
            else if breathsPerHundredBeats < 30 { breathScore = 55 }
            else { breathScore = 35 }
            total += breathScore * 0.25
            weight += 0.25
        }

        return weight > 0 ? total / weight : 0
    }

    // MARK: - Body

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

    // MARK: - iPad Layout (2-column grid)

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
            formDegradationCard
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
            formDegradationCard
        }
        .padding()
    }

    // MARK: - Session Summary Card

    private var sessionSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.run")
                    .foregroundStyle(.blue)
                Text("Running")
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

    // MARK: - G: Grow Card

    private var growCard: some View {
        let osc = session.averageVerticalOscillation
        let posture = session.postureStability

        let keyMetric: String = {
            if osc > 0 { return String(format: "%.1f cm bounce", osc) }
            if posture > 0 { return "\(Int(posture))% stable" }
            return "Needs Apple Watch"
        }()

        let tip: String = {
            if osc > 10 { return "Focus on running tall — imagine a string pulling you up" }
            if osc > 8 { return "Good height, try engaging core more" }
            if posture > 0 && posture < 60 { return "Keep your torso steady, eyes on horizon" }
            if osc == 0 && posture == 0 { return "Run with Apple Watch to measure vertical oscillation" }
            return "Maintain your tall posture"
        }()

        return pillarCard(
            letter: "G",
            title: "Grow",
            subtitle: "Run Tall",
            score: growScore,
            keyMetric: keyMetric,
            tip: tip,
            icon: "arrow.up.circle.fill",
            color: .green
        )
    }

    // MARK: - R: Rhythm Card

    private var rhythmCard: some View {
        let cadence = session.averageCadence
        let gct = session.averageGroundContactTime

        let keyMetric: String = {
            if cadence > 0 { return "\(cadence) spm" }
            if gct > 0 { return "\(Int(gct)) ms contact" }
            return "Needs motion data"
        }()

        let tip: String = {
            if cadence > 0 && cadence < 170 { return "Aim for quicker, lighter steps (170-180 spm)" }
            if cadence > 190 { return "Cadence is high — ensure you're not overstriding" }
            if gct > 300 { return "Spend less time on ground — think 'hot coals'" }
            if gct > 250 { return "Good contact time, keep feet moving" }
            if cadence == 0 && gct == 0 { return "Carry phone or wear Apple Watch to track cadence" }
            return "Maintain your light, quick rhythm"
        }()

        return pillarCard(
            letter: "R",
            title: "Rhythm",
            subtitle: "Light & Quick",
            score: rhythmScore,
            keyMetric: keyMetric,
            tip: tip,
            icon: "metronome.fill",
            color: .indigo
        )
    }

    // MARK: - A: Align Card

    private var alignCard: some View {
        let stride = bestStrideLength
        let asymmetry = watchAsymmetry
        let power = bestPower

        let keyMetric: String = {
            if let asym = asymmetry { return String(format: "%.1f%% asymmetry", asym) }
            if stride > 0 { return String(format: "%.2f m stride", stride) }
            if power > 0 { return "\(Int(power)) W power" }
            return "Needs Apple Watch"
        }()

        let tip: String = {
            if let asym = asymmetry, asym > 8 { return "Work on single-leg strength to improve balance" }
            if let asym = asymmetry, asym > 5 { return "Slight imbalance — focus on even footstrikes" }
            if stride > 0 {
                let ratio = bio.strideRatio(strideLength: stride)
                if ratio > 2.8 { return "Overstriding — land with feet under hips" }
                if ratio < 2.2 { return "Short stride — work on hip mobility" }
            }
            if asymmetry == nil && stride == 0 { return "Apple Watch measures stride length and symmetry" }
            return "Good alignment — maintain forward lean"
        }()

        return pillarCard(
            letter: "A",
            title: "Align",
            subtitle: "Forward Lean",
            score: alignScore,
            keyMetric: keyMetric,
            tip: tip,
            icon: "figure.walk",
            color: .orange
        )
    }

    // MARK: - C: Circle Card

    private var circleCard: some View {
        let keyMetric: String = {
            if circleScore > 0 { return "\(Int(circleScore))% economy" }
            return "Building baseline"
        }()

        let tip: String = {
            if circleScore > 0 && circleScore < 50 { return "Focus on relaxed shoulders, bent elbows, smooth arm swing" }
            if circleScore > 0 && circleScore < 70 { return "Good flow — keep movements compact and circular" }
            if circleScore == 0 { return "Economy score builds from cadence, GCT, and oscillation data" }
            return "Smooth running — maintain efficiency"
        }()

        return pillarCard(
            letter: "C",
            title: "Circle",
            subtitle: "Smooth Motion",
            score: circleScore,
            keyMetric: keyMetric,
            tip: tip,
            icon: "arrow.triangle.2.circlepath",
            color: .purple
        )
    }

    // MARK: - E: Enjoy Card

    private var enjoyCard: some View {
        let fatigue = session.endFatigueScore

        let keyMetric: String = {
            if let hrRec = session.healthKitHRRecoveryOneMinute, hrRec > 0 {
                return String(format: "%.0f bpm HR recovery", hrRec)
            }
            if session.averageHeartRate > 0 {
                return "\(session.averageHeartRate) avg bpm"
            }
            if fatigue > 0 { return "\(Int(100 - fatigue))% fresh" }
            return "Needs recovery data"
        }()

        let tip: String = {
            if let hrRec = session.healthKitHRRecoveryOneMinute, hrRec < 10 {
                return "Slow HR recovery — prioritise aerobic base training"
            }
            if fatigue > 70 { return "High fatigue — prioritise sleep and nutrition" }
            if fatigue > 50 { return "Some fatigue — good effort today" }
            if session.averageBreathingRate > 0 && session.averageHeartRate > 0 {
                let breathsPerHundredBeats = (session.averageBreathingRate / Double(session.averageHeartRate)) * 100
                if breathsPerHundredBeats > 30 { return "Breathing rate high relative to effort — check technique" }
            }
            if session.averageHeartRate == 0 && fatigue == 0 { return "Wear Apple Watch for heart rate and recovery data" }
            return "Well recovered — enjoy your running!"
        }()

        return pillarCard(
            letter: "E",
            title: "Enjoy",
            subtitle: "Wellbeing",
            score: enjoyScore,
            keyMetric: keyMetric,
            tip: tip,
            icon: "heart.fill",
            color: .red
        )
    }

    // MARK: - Form Degradation Card

    @ViewBuilder
    private var formDegradationCard: some View {
        let samples = session.runningFormSamples
        if samples.count >= 8 {
            let analysis = bio.formDegradation(
                oscillationSamples: samples.map(\.oscillation),
                gctSamples: samples.map(\.groundContactTime),
                cadenceSamples: samples.map { Double($0.cadence) }
            )
            FormDegradationBadge(analysis: analysis)
        }
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
            // Header row
            HStack {
                // Letter badge
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

                // Score
                Text(score > 0 ? "\(Int(score))" : "-")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(score > 0 ? scoreColor(score) : .secondary)
            }

            // Key metric
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(keyMetric)
                    .font(.subheadline)
            }

            // Actionable tip
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

#Preview {
    NavigationStack {
        RunningInsightsView(session: {
            let session = RunningSession()
            session.totalDistance = 5000
            session.totalDuration = 1500
            session.averageCadence = 175
            session.maxCadence = 188
            session.averageHeartRate = 155
            session.maxHeartRate = 182
            session.averageVerticalOscillation = 8.2
            session.averageGroundContactTime = 245
            session.averageBreathingRate = 28
            session.averageSpO2 = 96
            session.minSpO2 = 93
            session.endFatigueScore = 45
            session.postureStability = 72
            session.trainingLoadScore = 85
            return session
        }())
    }
}
