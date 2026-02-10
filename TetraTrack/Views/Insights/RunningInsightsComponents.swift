//
//  RunningInsightsComponents.swift
//  TetraTrack
//
//  Supporting components for RunningInsightsView
//  Includes running-specific gauges, charts, and coach insight rows
//

import SwiftUI
import Charts

// MARK: - GRACE Running Method Pillar

enum GRACEPillar: String, CaseIterable {
    case grow, rhythm, align, circle, enjoy

    var letter: String {
        switch self {
        case .grow: return "G"
        case .rhythm: return "R"
        case .align: return "A"
        case .circle: return "C"
        case .enjoy: return "E"
        }
    }

    var title: String {
        switch self {
        case .grow: return "Grow"
        case .rhythm: return "Rhythm"
        case .align: return "Align"
        case .circle: return "Circle"
        case .enjoy: return "Enjoy"
        }
    }

    var subtitle: String {
        switch self {
        case .grow: return "Run Tall"
        case .rhythm: return "Light & Quick"
        case .align: return "Forward Lean"
        case .circle: return "Smooth Motion"
        case .enjoy: return "Wellbeing & Progress"
        }
    }

    var cue: String {
        switch self {
        case .grow: return "Grow tall — imagine a string pulling the top of your head skyward"
        case .rhythm: return "Think light, alert, engaged. Feel buoyancy in your core"
        case .align: return "Tilt forward from ankles, not waist. Plant underneath your centre of mass"
        case .circle: return "Feel for the wheel with your heel. Upper body like a train carriage"
        case .enjoy: return "The best training is the training you enjoy and can sustain"
        }
    }

    var icon: String {
        switch self {
        case .grow: return "arrow.up.and.person.rectangle.portrait"
        case .rhythm: return "metronome"
        case .align: return "arrow.right.and.line.vertical.and.arrow.left"
        case .circle: return "circle.circle"
        case .enjoy: return "face.smiling"
        }
    }

    var color: Color {
        switch self {
        case .grow: return .green
        case .rhythm: return .cyan
        case .align: return .orange
        case .circle: return .purple
        case .enjoy: return .pink
        }
    }
}

// MARK: - GRACE Pillar Header

struct GRACEPillarHeader: View {
    let pillar: GRACEPillar

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(pillar.letter)
                    .font(.title.bold())
                    .foregroundStyle(pillar.color)
                    .frame(width: 36, height: 36)
                    .background(pillar.color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(pillar.letter) — \(pillar.title): \(pillar.subtitle)")
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(pillar.cue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                        .lineLimit(2)
                }
            }
        }
    }
}

// MARK: - Running Form Gauge

struct RunningFormGauge: View {
    let value: Double
    let maxValue: Double
    let title: String
    let unit: String
    let isInverted: Bool // lower is better (for oscillation, GCT)
    let greenRange: ClosedRange<Double>
    let yellowRange: ClosedRange<Double>

    private var gaugeColor: Color {
        if greenRange.contains(value) {
            return AppColors.success
        } else if yellowRange.contains(value) {
            return AppColors.warning
        } else {
            return AppColors.error
        }
    }

    private var progress: Double {
        min(value / maxValue, 1.0)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(gaugeColor.opacity(0.2), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: progress)

                VStack(spacing: 0) {
                    Text(String(format: "%.0f", value))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(gaugeColor)

                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 60, height: 60)

            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

// MARK: - Pace Zone Timeline

struct PaceZoneTimeline: View {
    let splits: [RunningSplit]
    let thresholdPace: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(splits) { split in
                        let zone = RunningPaceZone.zone(for: split.pace, thresholdPace: thresholdPace)
                        Rectangle()
                            .fill(paceZoneColor(zone))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(height: 24)

            // Legend
            HStack(spacing: 12) {
                ForEach([RunningPaceZone.easy, .aerobic, .tempo, .threshold, .vo2max], id: \.self) { zone in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(paceZoneColor(zone))
                            .frame(width: 6, height: 6)
                        Text(zone.name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func paceZoneColor(_ zone: RunningPaceZone) -> Color {
        switch zone {
        case .recovery: return .gray
        case .easy: return .blue
        case .aerobic: return .green
        case .tempo: return .yellow
        case .threshold: return .orange
        case .vo2max: return .red
        case .speed: return .purple
        }
    }
}

// MARK: - Elevation Profile Chart

struct ElevationProfileChart: View {
    let points: [RunningLocationPoint]

    var body: some View {
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                LineMark(
                    x: .value("Distance", index),
                    y: .value("Altitude", point.altitude)
                )
                .foregroundStyle(AppColors.success.opacity(0.6))

                AreaMark(
                    x: .value("Distance", index),
                    y: .value("Altitude", point.altitude)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [AppColors.success.opacity(0.3), AppColors.success.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisValueLabel {
                    if let alt = value.as(Double.self) {
                        Text("\(Int(alt))m")
                            .font(.caption2)
                    }
                }
            }
        }
    }
}

// MARK: - Split Comparison Chart

struct SplitComparisonChart: View {
    let splits: [RunningSplit]
    let thresholdPace: TimeInterval

    private var averagePace: TimeInterval {
        guard !splits.isEmpty else { return 0 }
        return splits.reduce(0) { $0 + $1.pace } / Double(splits.count)
    }

    private var splitPattern: String {
        guard splits.count >= 2 else { return "Single split" }
        let firstHalf = splits.prefix(splits.count / 2)
        let secondHalf = splits.suffix(splits.count / 2)
        let firstAvg = firstHalf.reduce(0) { $0 + $1.pace } / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0) { $0 + $1.pace } / Double(secondHalf.count)
        if secondAvg < firstAvg - 5 {
            return "Negative split"
        } else if secondAvg > firstAvg + 5 {
            return "Positive split"
        }
        return "Even pacing"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(splitPattern)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(splitPattern == "Negative split" ? AppColors.success : splitPattern == "Positive split" ? AppColors.warning : .primary)

                Spacer()

                if let bestSplit = splits.min(by: { $0.pace < $1.pace }) {
                    Text("Best: km \(bestSplit.orderIndex + 1) (\(bestSplit.formattedPace))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Chart {
                ForEach(splits) { split in
                    let zone = RunningPaceZone.zone(for: split.pace, thresholdPace: thresholdPace)
                    BarMark(
                        x: .value("Split", "km \(split.orderIndex + 1)"),
                        y: .value("Pace", split.pace)
                    )
                    .foregroundStyle(paceZoneColor(zone))
                }

                if averagePace > 0 {
                    RuleMark(y: .value("Average", averagePace))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { value in
                    AxisValueLabel {
                        if let pace = value.as(Double.self) {
                            Text(pace.formattedPace)
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
        }
    }

    private func paceZoneColor(_ zone: RunningPaceZone) -> Color {
        switch zone {
        case .recovery: return .gray
        case .easy: return .blue
        case .aerobic: return .green
        case .tempo: return .yellow
        case .threshold: return .orange
        case .vo2max: return .red
        case .speed: return .purple
        }
    }
}

// MARK: - Running Economy Badge

struct RunningEconomyBadge: View {
    let cadence: Int
    let oscillation: Double
    let groundContactTime: Double
    var biomechanics: RunnerBiomechanics? = nil

    private var economyScore: Double {
        var score: Double = 0
        var factors: Double = 0

        if cadence > 0 {
            if let bio = biomechanics {
                score += bio.cadenceScore(cadence: cadence)
            } else {
                if cadence >= 170 && cadence <= 190 { score += 90 }
                else if cadence >= 160 && cadence <= 200 { score += 70 }
                else { score += 40 }
            }
            factors += 1
        }

        if oscillation > 0 {
            if let bio = biomechanics {
                score += bio.oscillationScore(oscillation: oscillation)
            } else {
                if oscillation < 8 { score += 90 }
                else if oscillation < 10 { score += 70 }
                else { score += 40 }
            }
            factors += 1
        }

        if groundContactTime > 0 {
            if groundContactTime < 250 { score += 90 }
            else if groundContactTime < 300 { score += 70 }
            else { score += 40 }
            factors += 1
        }

        return factors > 0 ? score / factors : 0
    }

    private var economyColor: Color {
        switch economyScore {
        case 0..<50: return AppColors.error
        case 50..<70: return AppColors.warning
        case 70..<85: return AppColors.success
        default: return AppColors.primary
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .foregroundStyle(economyColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Running Economy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(Int(economyScore))/100")
                    .font(.headline)
                    .foregroundStyle(economyColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(economyColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Form Timeline Chart

struct FormTimelineChart: View {
    let samples: [RunningFormSample]
    let metric: FormMetric
    var optimalRange: ClosedRange<Double>? = nil

    enum FormMetric {
        case cadence, oscillation, groundContactTime
    }

    private var filteredData: [(index: Int, value: Double)] {
        samples.enumerated().compactMap { index, sample in
            let val: Double
            switch metric {
            case .cadence:
                val = Double(sample.cadence)
            case .oscillation:
                val = sample.oscillation
            case .groundContactTime:
                val = sample.groundContactTime
            }
            return val > 0 ? (index: index, value: val) : nil
        }
    }

    private var metricColor: Color {
        switch metric {
        case .cadence: return AppColors.primary
        case .oscillation: return AppColors.warning
        case .groundContactTime: return .cyan
        }
    }

    private var metricTitle: String {
        switch metric {
        case .cadence: return "Cadence (spm)"
        case .oscillation: return "V. Oscillation (cm)"
        case .groundContactTime: return "GCT (ms)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(metricTitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            Chart {
                // Optimal range shaded band
                if let range = optimalRange {
                    RectangleMark(
                        yStart: .value("Lower", range.lowerBound),
                        yEnd: .value("Upper", range.upperBound)
                    )
                    .foregroundStyle(.green.opacity(0.1))
                }

                ForEach(filteredData, id: \.index) { item in
                    LineMark(
                        x: .value("Time", item.index),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(metricColor.opacity(0.8))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis(.hidden)
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxis {
                AxisMarks(position: .trailing) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(String(format: "%.0f", v))
                                .font(.caption2)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Running Power Badge

struct RunningPowerBadge: View {
    let power: Double
    let maxPower: Double?

    private var powerColor: Color {
        if power < 150 { return .blue }
        if power < 250 { return .green }
        if power < 350 { return .orange }
        return .red
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.title3)
                    .foregroundStyle(powerColor)
                Text("Power")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.0f W", power))
                    .font(.title3.bold())
                    .foregroundStyle(powerColor)

                if let maxP = maxPower, maxP > 0 {
                    Text(String(format: "Max: %.0f W", maxP))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(powerColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Stride Length Chart

struct StrideLengthChart: View {
    let strideLengths: [(splitIndex: Int, strideLength: Double)]
    var biomechanics: RunnerBiomechanics? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Stride Length per Split")
                .font(.caption)
                .foregroundStyle(.secondary)

            Chart {
                ForEach(strideLengths, id: \.splitIndex) { item in
                    BarMark(
                        x: .value("Split", "km \(item.splitIndex + 1)"),
                        y: .value("Stride", item.strideLength)
                    )
                    .foregroundStyle(strideColor(item.strideLength))
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxis {
                AxisMarks(position: .trailing) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(String(format: "%.2fm", v))
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 120)

            HStack(spacing: 8) {
                if let avg = averageStride {
                    Text(String(format: "Avg: %.2f m", avg))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text("Optimal: \(optimalRangeText)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var optimalRangeText: String {
        biomechanics?.formattedStrideRange ?? "1.00-1.30m"
    }

    private var averageStride: Double? {
        guard !strideLengths.isEmpty else { return nil }
        return strideLengths.reduce(0) { $0 + $1.strideLength } / Double(strideLengths.count)
    }

    private func strideColor(_ stride: Double) -> Color {
        if let bio = biomechanics {
            let score = bio.strideLengthScore(strideLength: stride)
            if score >= 90 { return AppColors.success }
            if score >= 70 { return AppColors.warning }
            return AppColors.error
        }
        if stride >= 1.0 && stride <= 1.3 { return AppColors.success }
        if stride >= 0.8 && stride <= 1.5 { return AppColors.warning }
        return AppColors.error
    }
}

// MARK: - Efficiency Factor Card

struct EfficiencyFactorCard: View {
    let efficiencyFactor: Double
    let cardiacDecoupling: Double

    private var efColor: Color {
        // Lower EF = more efficient (faster pace relative to HR)
        if efficiencyFactor < 1.5 { return AppColors.success }
        if efficiencyFactor < 2.0 { return AppColors.warning }
        return AppColors.error
    }

    private var decouplingColor: Color {
        let absDecoupling = abs(cardiacDecoupling)
        if absDecoupling < 3 { return AppColors.success }
        if absDecoupling < 5 { return AppColors.warning }
        return AppColors.error
    }

    var body: some View {
        HStack(spacing: 20) {
            // Efficiency Factor
            if efficiencyFactor > 0 {
                VStack(spacing: 4) {
                    Text(String(format: "%.2f", efficiencyFactor))
                        .font(.title2.bold())
                        .foregroundStyle(efColor)
                    Text("Efficiency Factor")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("pace/HR ratio")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }

            // Cardiac Decoupling
            if cardiacDecoupling != 0 {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: cardiacDecoupling > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)
                            .foregroundStyle(decouplingColor)
                        Text(String(format: "%.1f%%", cardiacDecoupling))
                            .font(.title2.bold())
                            .foregroundStyle(decouplingColor)
                    }
                    Text("Cardiac Drift")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(abs(cardiacDecoupling) < 5 ? "Good aerobic fitness" : "Needs improvement")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Recovery Score Card

struct RecoveryScoreCard: View {
    let peakHR: Int
    let recoveryHR: Int
    let recoveryScore: Double

    private var hrDrop: Int { peakHR - recoveryHR }

    private var scoreColor: Color {
        if recoveryScore >= 75 { return AppColors.success }
        if recoveryScore >= 50 { return AppColors.warning }
        return AppColors.error
    }

    private var ratingText: String {
        if hrDrop >= 30 { return "Excellent" }
        if hrDrop >= 20 { return "Good" }
        if hrDrop >= 10 { return "Fair" }
        return "Poor"
    }

    var body: some View {
        HStack(spacing: 16) {
            // Recovery gauge
            ZStack {
                Circle()
                    .stroke(scoreColor.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: min(recoveryScore / 100, 1))
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(Int(recoveryScore))")
                        .font(.title3.bold())
                        .foregroundStyle(scoreColor)
                    Text("Recovery")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 70, height: 70)

            // Details
            VStack(alignment: .leading, spacing: 6) {
                Text(ratingText)
                    .font(.headline)
                    .foregroundStyle(scoreColor)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Peak HR")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text("\(peakHR) bpm")
                            .font(.caption)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("60s Post")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text("\(recoveryHR) bpm")
                            .font(.caption)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Drop")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text("\(hrDrop) bpm")
                            .font(.caption)
                            .foregroundStyle(scoreColor)
                    }
                }
            }
        }
    }
}

// MARK: - Training Stress Card

struct TrainingStressCard: View {
    let tss: Double
    let intensityFactor: Double
    let duration: TimeInterval

    private var tssColor: Color {
        if tss < 50 { return AppColors.success }
        if tss < 100 { return AppColors.warning }
        if tss < 150 { return .orange }
        return AppColors.error
    }

    private var tssLabel: String {
        if tss < 50 { return "Easy" }
        if tss < 100 { return "Moderate" }
        if tss < 150 { return "Hard" }
        return "Very Hard"
    }

    var body: some View {
        HStack(spacing: 16) {
            // TSS display
            VStack(spacing: 4) {
                Text(String(format: "%.0f", tss))
                    .font(.title.bold())
                    .foregroundStyle(tssColor)
                Text("TSS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 70)

            Divider()
                .frame(height: 50)

            // Details
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(tssLabel)
                        .font(.subheadline.bold())
                        .foregroundStyle(tssColor)
                    Spacer()
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Intensity")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(String(format: "%.2f IF", intensityFactor))
                            .font(.caption)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Duration")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(duration.formattedDuration)
                            .font(.caption)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(tssColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Race Prediction Row

struct RacePredictionRow: View {
    let prediction: RacePrediction

    var body: some View {
        HStack {
            Text(prediction.raceName)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(width: 100, alignment: .leading)

            Spacer()

            Text(prediction.formattedTime)
                .font(.subheadline.monospacedDigit())
                .fontWeight(.medium)
                .foregroundStyle(AppColors.primary)

            Spacer()

            Text(prediction.formattedPace + " /km")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Posture & Technique Section

struct PostureTechniqueCard: View {
    let postureStability: Double
    let averageOscillation: Double
    let averageGCT: Double
    let cadence: Int
    let strideLength: Double
    var biomechanics: RunnerBiomechanics? = nil

    private var techniqueScore: Double {
        var total: Double = 0
        var weight: Double = 0

        // Posture stability (30%)
        if postureStability > 0 {
            total += postureStability * 0.3
            weight += 0.3
        }

        // Cadence efficiency (20%)
        if cadence > 0 {
            let cadScore: Double
            if let bio = biomechanics {
                cadScore = bio.cadenceScore(cadence: cadence)
            } else {
                cadScore = (cadence >= 170 && cadence <= 190) ? 90 :
                    (cadence >= 160 && cadence <= 200) ? 70 : 40
            }
            total += cadScore * 0.2
            weight += 0.2
        }

        // Oscillation efficiency (20%) - lower is better
        if averageOscillation > 0 {
            let oscScore: Double
            if let bio = biomechanics {
                let stride = strideLength > 0 ? strideLength : nil
                oscScore = bio.oscillationScore(oscillation: averageOscillation, strideLength: stride)
            } else {
                oscScore = averageOscillation < 8 ? 90 :
                    averageOscillation < 10 ? 70 : 40
            }
            total += oscScore * 0.2
            weight += 0.2
        }

        // GCT efficiency (15%) - lower is better
        if averageGCT > 0 {
            let gctScore: Double = averageGCT < 250 ? 90 :
                averageGCT < 300 ? 70 : 40
            total += gctScore * 0.15
            weight += 0.15
        }

        // Stride length (15%)
        if strideLength > 0 {
            let slScore: Double
            if let bio = biomechanics {
                slScore = bio.strideLengthScore(strideLength: strideLength)
            } else {
                slScore = (strideLength >= 1.0 && strideLength <= 1.3) ? 90 :
                    (strideLength >= 0.8 && strideLength <= 1.5) ? 70 : 40
            }
            total += slScore * 0.15
            weight += 0.15
        }

        return weight > 0 ? total / weight : 0
    }

    private var techniqueColor: Color {
        if techniqueScore >= 75 { return AppColors.success }
        if techniqueScore >= 50 { return AppColors.warning }
        return AppColors.error
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Overall technique score
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(techniqueColor.opacity(0.2), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: min(techniqueScore / 100, 1))
                        .stroke(techniqueColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(Int(techniqueScore))")
                            .font(.title2.bold())
                            .foregroundStyle(techniqueColor)
                        Text("/100")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Technique Score")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("Posture, cadence, oscillation, contact & stride")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Component breakdown
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                if postureStability > 0 {
                    techniqueMetric(
                        icon: "figure.stand",
                        title: "Posture",
                        value: String(format: "%.0f", postureStability),
                        unit: "/100",
                        rating: postureStability > 70 ? "Stable" : postureStability > 40 ? "Fair" : "Unstable",
                        color: postureStability > 70 ? AppColors.success : postureStability > 40 ? AppColors.warning : AppColors.error
                    )
                }

                if cadence > 0 {
                    let cadOptimal = biomechanics?.isCadenceOptimal(cadence) ?? (cadence >= 170 && cadence <= 190)
                    techniqueMetric(
                        icon: "metronome",
                        title: "Turnover",
                        value: "\(cadence)",
                        unit: "spm",
                        rating: cadOptimal ? "Optimal" : "Adjust",
                        color: cadOptimal ? AppColors.success : AppColors.warning
                    )
                }

                if averageOscillation > 0 {
                    techniqueMetric(
                        icon: "arrow.up.arrow.down",
                        title: "Bounce",
                        value: String(format: "%.1f", averageOscillation),
                        unit: "cm",
                        rating: averageOscillation < 8 ? "Efficient" : averageOscillation < 10 ? "Fair" : "Bouncy",
                        color: averageOscillation < 8 ? AppColors.success : averageOscillation < 10 ? AppColors.warning : AppColors.error
                    )
                }

                if averageGCT > 0 {
                    techniqueMetric(
                        icon: "shoe.fill",
                        title: "Contact",
                        value: String(format: "%.0f", averageGCT),
                        unit: "ms",
                        rating: averageGCT < 250 ? "Quick" : averageGCT < 300 ? "Normal" : "Slow",
                        color: averageGCT < 250 ? AppColors.success : averageGCT < 300 ? AppColors.warning : AppColors.error
                    )
                }

                if strideLength > 0 {
                    let strideOptimal = biomechanics?.optimalStrideRange.contains(strideLength) ?? (strideLength >= 1.0 && strideLength <= 1.3)
                    techniqueMetric(
                        icon: "ruler",
                        title: "Stride",
                        value: String(format: "%.2f", strideLength),
                        unit: "m",
                        rating: strideOptimal ? "Optimal" : "Adjust",
                        color: strideOptimal ? AppColors.success : AppColors.warning
                    )
                }
            }
        }
    }

    private func techniqueMetric(icon: String, title: String, value: String, unit: String, rating: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                HStack(spacing: 4) {
                    Text(value)
                        .font(.subheadline.bold())
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(rating)
                    .font(.caption2)
                    .foregroundStyle(color)
            }
        }
        .padding(8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Running Coach Insight Row

struct RunningCoachInsightRow: View {
    let icon: String
    let category: String
    let insight: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppColors.warning)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(category)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)

                Text(insight)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Per-Split Efficiency Chart (1.3)

struct PerSplitEfficiencyChart: View {
    let efficiencies: [Double]
    let splitLabels: [String]
    var deteriorationPercent: Double = 0
    var isSignificant: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Efficiency Factor by Split")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if isSignificant {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                        Text(String(format: "%.0f%%", abs(deteriorationPercent)))
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(deteriorationPercent > 0 ? AppColors.warning : AppColors.success)
                }
            }

            Chart {
                ForEach(Array(zip(efficiencies.indices, efficiencies)), id: \.0) { index, ef in
                    let label = index < splitLabels.count ? splitLabels[index] : "Split \(index + 1)"
                    BarMark(
                        x: .value("Split", label),
                        y: .value("EF", ef)
                    )
                    .foregroundStyle(efColor(ef, index: index))
                }
            }
            .chartYAxisLabel("Pace/HR Ratio")
            .frame(height: 150)
        }
    }

    private func efColor(_ ef: Double, index: Int) -> Color {
        let isLate = Double(index) / Double(max(efficiencies.count - 1, 1)) > 0.66
        if isSignificant && isLate { return AppColors.warning }
        return AppColors.primary
    }
}

// MARK: - Form Degradation Badge (1.4)

struct FormDegradationBadge: View {
    let analysis: FormDegradationAnalysis

    var body: some View {
        if analysis.hasDegradation {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppColors.warning)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Form Degradation Detected")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.warning)
                    Text(analysis.summary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(10)
            .background(AppColors.warning.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Breathing Efficiency Card (2.4)

struct BreathingEfficiencyCard: View {
    let breathingRate: Double
    let averageHeartRate: Int

    private var breathsPerHundredBeats: Double {
        guard averageHeartRate > 0 else { return 0 }
        return (breathingRate / Double(averageHeartRate)) * 100
    }

    private var isElevated: Bool {
        breathsPerHundredBeats > 30  // High breathing relative to HR
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lungs.fill")
                    .foregroundStyle(AppColors.cyan)
                Text("Breathing Efficiency")
                    .font(.subheadline.weight(.medium))
                Spacer()
            }

            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text(String(format: "%.0f", breathingRate))
                        .font(.title3.weight(.bold))
                    Text("br/min")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 2) {
                    Text(String(format: "%.0f", breathsPerHundredBeats))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(isElevated ? AppColors.warning : AppColors.success)
                    Text("per 100 beats")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("\(averageHeartRate)")
                        .font(.title3.weight(.bold))
                    Text("avg HR")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if isElevated {
                Text("Breathing rate high relative to effort -- check technique")
                    .font(.caption)
                    .foregroundStyle(AppColors.warning)
                    .italic()
            }
        }
        .padding(12)
        .background(AppColors.cyan.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Stride Degradation Badge (2.12)

struct StrideDegradationBadge: View {
    let shortenedPercent: Double
    let isWarning: Bool

    var body: some View {
        if isWarning {
            HStack(spacing: 6) {
                Image(systemName: "figure.run")
                    .foregroundStyle(AppColors.warning)
                Text("Stride shortened \(String(format: "%.0f%%", shortenedPercent)) in second half -- muscular fatigue indicator")
                    .font(.caption)
                    .foregroundStyle(AppColors.warning)
            }
            .padding(8)
            .background(AppColors.warning.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Weather Impact Badge (2.11)

struct WeatherImpactBadge: View {
    let temperature: Double?
    let windSpeed: Double?
    let humidity: Double?
    let conditionDescription: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "cloud.sun.fill")
                .font(.title3)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 4) {
                if let desc = conditionDescription {
                    Text(desc)
                        .font(.subheadline.weight(.medium))
                }
                HStack(spacing: 12) {
                    if let temp = temperature {
                        Label(String(format: "%.0f\u{00B0}C", temp), systemImage: "thermometer")
                            .font(.caption)
                    }
                    if let wind = windSpeed, wind > 0 {
                        Label(String(format: "%.0f km/h", wind * 3.6), systemImage: "wind")
                            .font(.caption)
                    }
                    if let hum = humidity, hum > 0 {
                        Label(String(format: "%.0f%%", hum * 100), systemImage: "humidity.fill")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.orange.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - SpO2 Warning Badge (2.14)

struct SpO2WarningBadge: View {
    let averageSpO2: Double
    let minSpO2: Double

    private var isDesaturation: Bool { minSpO2 > 0 && minSpO2 < 94 }

    var body: some View {
        if isDesaturation {
            HStack(spacing: 8) {
                Image(systemName: "o2.circle.fill")
                    .foregroundStyle(AppColors.error)
                VStack(alignment: .leading, spacing: 2) {
                    Text("SpO2 Desaturation Warning")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.error)
                    Text("SpO2 dropped to \(String(format: "%.0f%%", minSpO2)) -- monitor at altitude or high intensity")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .background(AppColors.error.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Preview

#Preview("Running Form Gauge") {
    HStack(spacing: 20) {
        RunningFormGauge(
            value: 178,
            maxValue: 210,
            title: "Cadence",
            unit: "spm",
            isInverted: false,
            greenRange: 170...190,
            yellowRange: 160...200
        )

        RunningFormGauge(
            value: 7.5,
            maxValue: 15,
            title: "Oscillation",
            unit: "cm",
            isInverted: true,
            greenRange: 0...8,
            yellowRange: 0...10
        )

        RunningFormGauge(
            value: 240,
            maxValue: 400,
            title: "GCT",
            unit: "ms",
            isInverted: true,
            greenRange: 0...250,
            yellowRange: 0...300
        )
    }
    .padding()
    .background(AppColors.cardBackground)
}
