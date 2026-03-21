//
//  RunningInsightsView.swift
//  TetraTrack
//
//  Running biomechanics insights using 4 pillars + physiology.
//  Pillars: Stability (posture + oscillation), Rhythm (cadence + GCT + pacing),
//  Symmetry (stride + asymmetry + power), Economy (running economy composite).
//  Physiology: HR efficiency, recovery, fatigue, breathing.
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

    private var bestStrideLength: Double {
        session.healthKitStrideLength ?? session.estimatedStrideLength
    }

    private var bestPower: Double {
        if let hkPower = session.healthKitPower, hkPower > 0 {
            return hkPower
        }
        return bio.estimatedRunningPower(from: session)
    }

    private var watchAsymmetry: Double? {
        session.healthKitAsymmetry
    }

    // MARK: - Biomechanical Score Computations

    // Stability — posture stability and vertical oscillation
    private var stabilityScore: Double {
        var total: Double = 0
        var weight: Double = 0

        if session.postureStability > 0 {
            total += session.postureStability * 0.5
            weight += 0.5
        }

        if session.averageVerticalOscillation > 0 {
            let stride = bestStrideLength > 0 ? bestStrideLength : nil
            let oscScore = bio.oscillationScore(oscillation: session.averageVerticalOscillation, strideLength: stride)
            total += oscScore * 0.5
            weight += 0.5
        }

        return weight > 0 ? total / weight : 0
    }

    // Rhythm — cadence, GCT, pacing consistency
    private var rhythmScore: Double {
        var total: Double = 0
        var weight: Double = 0

        let cadence = session.averageCadence
        if cadence > 0 {
            let cadenceScore = bio.cadenceScore(cadence: cadence)
            total += cadenceScore * 0.4
            weight += 0.4
        }

        if session.averageGroundContactTime > 0 {
            let gct = session.averageGroundContactTime
            let gctScore: Double = gct < 250 ? 90 : (gct < 300 ? 70 : 40)
            total += gctScore * 0.3
            weight += 0.3
        }

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

    // Symmetry — stride length, asymmetry, efficiency factor, power
    private var symmetryScore: Double {
        var total: Double = 0
        var weight: Double = 0

        let stride = bestStrideLength
        if stride > 0 {
            let strideScore = bio.strideLengthScore(strideLength: stride)
            total += strideScore * 0.3
            weight += 0.3
        }

        if let asymmetry = watchAsymmetry {
            let asymmetryScore: Double
            if asymmetry < 3 { asymmetryScore = 95 }
            else if asymmetry < 6 { asymmetryScore = 80 }
            else if asymmetry < 10 { asymmetryScore = 60 }
            else { asymmetryScore = 40 }
            total += asymmetryScore * 0.25
            weight += 0.25
        }

        let ef = session.efficiencyFactor
        if ef > 0 {
            let efScore: Double
            if ef < 1.5 { efScore = 90 }
            else if ef < 2.0 { efScore = 70 }
            else { efScore = 40 }
            total += efScore * 0.25
            weight += 0.25
        }

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

    // Economy — running economy composite
    private var economyScore: Double {
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

    // Physiology — HR efficiency, HR recovery, fatigue, breathing
    private var physiologyScore: Double {
        var total: Double = 0
        var weight: Double = 0

        if session.averageHeartRate > 0 && session.maxHeartRate > 0 {
            let ratio = Double(session.averageHeartRate) / Double(session.maxHeartRate)
            let hrScore: Double
            if ratio >= 0.75 && ratio <= 0.85 { hrScore = 85 }
            else if ratio < 0.75 { hrScore = 70 }
            else { hrScore = max(40, 85 - (ratio - 0.85) * 300) }
            total += hrScore * 0.25
            weight += 0.25
        }

        if session.endFatigueScore > 0 {
            let inverseFatigue = max(0, 100 - session.endFatigueScore)
            total += inverseFatigue * 0.25
            weight += 0.25
        }

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
        .navigationTitle("Session Insights")
        .navigationBarTitleDisplayMode(.inline)
        .glassNavigation()
        .sheetBackground()
    }

    // MARK: - iPad Layout (2-column grid)

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
            formDegradationCard
            cadenceOptimalRangeCard
            strideDegradationCard
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
            formDegradationCard
            cadenceOptimalRangeCard
            strideDegradationCard
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

    // MARK: - Stability Card

    private var stabilityCard: some View {
        let osc = session.averageVerticalOscillation
        let posture = session.postureStability

        return PillarScoreCard(
            pillar: .stability,
            subtitle: "Posture & Oscillation",
            score: stabilityScore,
            keyMetric: {
                if osc > 0 { return String(format: "%.1f cm bounce", osc) }
                if posture > 0 { return "\(Int(posture))% stable" }
                return "Needs Apple Watch"
            }(),
            tip: {
                if osc > 10 { return "Focus on running tall — imagine a string pulling you up" }
                if osc > 8 { return "Good height, try engaging core more" }
                if posture > 0 && posture < 60 { return "Keep your torso steady, eyes on horizon" }
                if osc == 0 && posture == 0 { return "Run with Apple Watch to measure vertical oscillation" }
                return "Maintain your tall posture"
            }()
        )
    }

    // MARK: - Rhythm Card

    private var rhythmCard: some View {
        let cadence = session.averageCadence
        let gct = session.averageGroundContactTime

        return PillarScoreCard(
            pillar: .rhythm,
            subtitle: "Cadence & Tempo",
            score: rhythmScore,
            keyMetric: {
                if cadence > 0 { return "\(cadence) spm" }
                if gct > 0 { return "\(Int(gct)) ms contact" }
                return "Needs motion data"
            }(),
            tip: {
                if cadence > 0 && cadence < 170 { return "Aim for quicker, lighter steps (170-180 spm)" }
                if cadence > 190 { return "Cadence is high — ensure you're not overstriding" }
                if gct > 300 { return "Spend less time on ground — think 'hot coals'" }
                if gct > 250 { return "Good contact time, keep feet moving" }
                if cadence == 0 && gct == 0 { return "Carry phone or wear Apple Watch to track cadence" }
                return "Maintain your light, quick rhythm"
            }()
        )
    }

    // MARK: - Symmetry Card

    private var symmetryCard: some View {
        let stride = bestStrideLength
        let asymmetry = watchAsymmetry
        let power = bestPower

        return PillarScoreCard(
            pillar: .symmetry,
            subtitle: "Stride & Balance",
            score: symmetryScore,
            keyMetric: {
                if let asym = asymmetry { return String(format: "%.1f%% asymmetry", asym) }
                if stride > 0 { return String(format: "%.2f m stride", stride) }
                if power > 0 { return "\(Int(power)) W power" }
                return "Needs Apple Watch"
            }(),
            tip: {
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
        )
    }

    // MARK: - Economy Card

    private var economyCard: some View {
        PillarScoreCard(
            pillar: .economy,
            subtitle: "Running Economy",
            score: economyScore,
            keyMetric: {
                if economyScore > 0 { return "\(Int(economyScore))% economy" }
                return "Building baseline"
            }(),
            tip: {
                if economyScore > 0 && economyScore < 50 { return "Focus on relaxed shoulders, bent elbows, smooth arm swing" }
                if economyScore > 0 && economyScore < 70 { return "Good flow — keep movements compact and circular" }
                if economyScore == 0 { return "Economy score builds from cadence, GCT, and oscillation data" }
                return "Smooth running — maintain efficiency"
            }()
        )
    }

    // MARK: - Physiology Card

    private var physiologyCard: some View {
        let fatigue = session.endFatigueScore

        return PhysiologySectionCard(
            score: physiologyScore,
            keyMetric: {
                if let hrRec = session.healthKitHRRecoveryOneMinute, hrRec > 0 {
                    return String(format: "%.0f bpm HR recovery", hrRec)
                }
                if session.averageHeartRate > 0 {
                    return "\(session.averageHeartRate) avg bpm"
                }
                if fatigue > 0 { return "\(Int(100 - fatigue))% fresh" }
                return "Needs recovery data"
            }(),
            tip: {
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
            }(),
            subtitle: "Recovery & Effort"
        )
    }

    // MARK: - Cadence Optimal Range Card (#19)

    @ViewBuilder
    private var cadenceOptimalRangeCard: some View {
        let samples = session.runningFormSamples
        if samples.count >= 8 {
            let cadenceValues = samples.map { Double($0.cadence) }.filter { $0 > 0 }
            if !cadenceValues.isEmpty {
                let targetCadence = session.targetCadence > 0 ? Double(session.targetCadence) : 175.0
                let optimalRange = (targetCadence - 5)...(targetCadence + 5)
                let inZoneCount = cadenceValues.filter { optimalRange.contains($0) }.count
                let inZonePercent = Double(inZoneCount) / Double(cadenceValues.count) * 100

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "metronome.fill")
                            .foregroundStyle(AppColors.primary)
                        Text("Cadence Zone")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(Int(inZonePercent))% in zone")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(inZonePercent >= 70 ? AppColors.success : AppColors.warning)
                    }

                    FormTimelineChart(
                        samples: samples,
                        metric: .cadence,
                        optimalRange: optimalRange
                    )
                    .frame(height: 120)

                    HStack {
                        Text("Target: \(Int(targetCadence)) ± 5 spm")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Circle()
                            .fill(.green.opacity(0.3))
                            .frame(width: 8, height: 8)
                        Text("Optimal zone")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .glassCard()
            }
        }
    }

    // MARK: - Stride Degradation Card (#25)

    @ViewBuilder
    private var strideDegradationCard: some View {
        let splits = session.sortedSplits
        if splits.count >= 4 {
            let strideLengths = splits.compactMap { split -> Double? in
                guard split.cadence > 0, split.distance > 0, split.duration > 0 else { return nil }
                let speed = split.distance / split.duration  // m/s
                let stepsPerSecond = Double(split.cadence) / 60.0
                return stepsPerSecond > 0 ? speed / stepsPerSecond : nil
            }

            if strideLengths.count >= 4 {
                let midpoint = strideLengths.count / 2
                let firstHalf = Array(strideLengths.prefix(midpoint))
                let secondHalf = Array(strideLengths.suffix(midpoint))
                let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
                let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)

                if firstAvg > 0 {
                    let shortenedPercent = ((firstAvg - secondAvg) / firstAvg) * 100
                    StrideDegradationBadge(
                        shortenedPercent: shortenedPercent,
                        isWarning: shortenedPercent > 5
                    )
                }
            }
        }
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
