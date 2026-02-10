//
//  RunnerBiomechanics.swift
//  TetraTrack
//
//  Personalised running biomechanics calculations based on runner's height, weight, and heart rate.
//  Replaces hardcoded 70kg / fixed thresholds with values derived from RiderProfile.
//

import Foundation

struct RunnerBiomechanics {

    // MARK: - Stored Properties

    let bodyMassKg: Double
    let heightCm: Double
    let maxHeartRate: Int
    let restingHeartRate: Int

    // MARK: - Initialisers

    /// Initialise from a RiderProfile. Nil profile falls back to defaults (70 kg, 170 cm).
    init(profile: RiderProfile?) {
        self.bodyMassKg = profile?.weight ?? 70.0
        self.heightCm = profile?.height ?? 170.0
        self.maxHeartRate = profile?.maxHeartRate ?? 180
        self.restingHeartRate = profile?.restingHeartRate ?? 60
    }

    /// Explicit initialiser for tests and previews.
    init(bodyMassKg: Double = 70.0, heightCm: Double = 170.0, maxHeartRate: Int = 180, restingHeartRate: Int = 60) {
        self.bodyMassKg = bodyMassKg
        self.heightCm = heightCm
        self.maxHeartRate = maxHeartRate
        self.restingHeartRate = restingHeartRate
    }

    // MARK: - Derived Properties

    /// Height in metres.
    var heightM: Double {
        heightCm / 100.0
    }

    /// Estimated leg length using anthropometric standard (height x 0.53).
    var legLengthM: Double {
        heightM * 0.53
    }

    /// Frontal area (m^2) from DuBois BSA x projection factor.
    /// Formula: 0.266 * h^0.725 * m^0.425 * 0.24
    var frontalArea: Double {
        0.266 * pow(heightM, 0.725) * pow(bodyMassKg, 0.425) * 0.24
    }

    /// Estimated Lactate Threshold Heart Rate (85% of max HR).
    var estimatedLTHR: Double {
        0.85 * Double(maxHeartRate)
    }

    /// Height-adjusted optimal cadence centre (spm).
    /// Scales 180 spm by sqrt(170 / height_cm) so shorter runners get higher cadence targets.
    var optimalCadenceCenter: Double {
        180.0 * sqrt(170.0 / heightCm)
    }

    /// Optimal cadence range: centre +/- 10 spm.
    var optimalCadenceRange: ClosedRange<Double> {
        (optimalCadenceCenter - 10)...(optimalCadenceCenter + 10)
    }

    /// Acceptable cadence range: centre +/- 20 spm.
    var acceptableCadenceRange: ClosedRange<Double> {
        (optimalCadenceCenter - 20)...(optimalCadenceCenter + 20)
    }

    /// Optimal stride length range based on leg length (1.8x - 2.5x leg length).
    var optimalStrideRange: ClosedRange<Double> {
        (legLengthM * 1.8)...(legLengthM * 2.5)
    }

    // MARK: - Running Power

    /// Estimated running power (watts) using actual body mass and height-derived frontal area.
    func estimatedRunningPower(from session: RunningSession) -> Double {
        guard session.averageSpeed > 0 else { return 0 }
        let g: Double = 9.81
        let speed = session.averageSpeed

        // Grade from elevation
        let grade = session.totalDistance > 0 ? (session.totalAscent - session.totalDescent) / session.totalDistance : 0

        // Rolling resistance cost
        let Cr: Double = 0.98
        let rollingPower = Cr * bodyMassKg * speed

        // Grade resistance
        let gradePower = bodyMassKg * g * grade * speed

        // Air resistance
        let Cd: Double = 0.9
        let rho: Double = 1.225
        let aeroPower = 0.5 * Cd * frontalArea * rho * pow(speed, 3)

        return max(0, rollingPower + gradePower + aeroPower)
    }

    /// Watts per kilogram using actual body mass.
    func wattsPerKg(power: Double) -> Double {
        guard bodyMassKg > 0 else { return 0 }
        return power / bodyMassKg
    }

    // MARK: - Training Stress

    /// Training Stress Score using Coggan hrTSS formula with profile LTHR.
    /// TSS = hours * (avgHR / LTHR)^2 * 100
    func trainingStress(from session: RunningSession) -> Double {
        guard session.totalDuration > 0, session.averageHeartRate > 0 else { return 0 }
        let hours = session.totalDuration / 3600.0
        let if_ = Double(session.averageHeartRate) / estimatedLTHR
        return hours * pow(if_, 2) * 100
    }

    /// Intensity factor: average HR relative to LTHR.
    func intensityFactor(averageHR: Int) -> Double {
        guard averageHR > 0 else { return 0 }
        return Double(averageHR) / estimatedLTHR
    }

    // MARK: - Stride & Cadence Scoring

    /// Stride / leg length ratio.
    func strideRatio(strideLength: Double) -> Double {
        guard legLengthM > 0 else { return 0 }
        return strideLength / legLengthM
    }

    /// Score stride length (0-100) relative to leg length.
    /// Optimal ratio is 1.8-2.5x leg length.
    func strideLengthScore(strideLength: Double) -> Double {
        guard strideLength > 0, legLengthM > 0 else { return 0 }
        let ratio = strideLength / legLengthM
        let optimalLow = 1.8
        let optimalHigh = 2.5

        if ratio >= optimalLow && ratio <= optimalHigh {
            return 90
        } else if ratio >= (optimalLow - 0.4) && ratio <= (optimalHigh + 0.4) {
            // Acceptable but not optimal
            return 70
        } else {
            return 40
        }
    }

    /// Score vertical oscillation (0-100).
    /// Uses vertical ratio (oscillation / stride x 100) when stride is available, absolute fallback otherwise.
    func oscillationScore(oscillation: Double, strideLength: Double? = nil) -> Double {
        guard oscillation > 0 else { return 0 }

        // Use vertical ratio when stride length is available
        if let stride = strideLength, stride > 0 {
            let vr = verticalRatio(oscillation: oscillation, strideLength: stride)
            if vr < 8 { return 95 }
            if vr < 10 { return 70 }
            return 40
        }

        // Absolute fallback
        if oscillation < 8 { return 95 }
        if oscillation < 10 { return 70 }
        return 40
    }

    /// Vertical ratio: oscillation (cm) / stride (m) x 100 -> percentage.
    /// Elite < 8%, good 8-10%.
    func verticalRatio(oscillation: Double, strideLength: Double) -> Double {
        guard strideLength > 0 else { return 0 }
        // Convert oscillation from cm to m, divide by stride, x 100 for percentage
        return (oscillation / 100.0) / strideLength * 100
    }

    /// Score cadence (0-100) relative to height-adjusted optimal range.
    func cadenceScore(cadence: Int) -> Double {
        guard cadence > 0 else { return 0 }
        let c = Double(cadence)
        if optimalCadenceRange.contains(c) { return 95 }
        if acceptableCadenceRange.contains(c) { return 70 }
        // Further away -> lower score
        let distance = min(abs(c - optimalCadenceCenter), 40)
        return max(40, 95 - (distance * 1.375))
    }

    /// Whether cadence falls within the personalised optimal range.
    func isCadenceOptimal(_ cadence: Int) -> Bool {
        optimalCadenceRange.contains(Double(cadence))
    }

    // MARK: - Formatted Ranges (for UI text)

    /// Formatted optimal cadence range string, e.g. "170-190".
    var formattedCadenceRange: String {
        "\(Int(optimalCadenceRange.lowerBound))-\(Int(optimalCadenceRange.upperBound))"
    }

    /// Formatted optimal stride range string, e.g. "1.00-1.30m".
    var formattedStrideRange: String {
        String(format: "%.2f-%.2fm", optimalStrideRange.lowerBound, optimalStrideRange.upperBound)
    }

    // MARK: - Form Degradation Detection (1.4)

    /// Analyze form degradation by comparing first and last quartiles of form samples.
    func formDegradation(oscillationSamples: [Double], gctSamples: [Double], cadenceSamples: [Double]) -> FormDegradationAnalysis {
        func quartileAverage(_ samples: [Double], first: Bool) -> Double {
            guard samples.count >= 4 else { return samples.isEmpty ? 0 : samples.reduce(0, +) / Double(samples.count) }
            let quarter = samples.count / 4
            let slice = first ? samples.prefix(quarter) : samples.suffix(quarter)
            return slice.reduce(0, +) / Double(slice.count)
        }

        let oscQ1 = quartileAverage(oscillationSamples, first: true)
        let oscQ4 = quartileAverage(oscillationSamples, first: false)
        let gctQ1 = quartileAverage(gctSamples, first: true)
        let gctQ4 = quartileAverage(gctSamples, first: false)
        let cadQ1 = quartileAverage(cadenceSamples, first: true)
        let cadQ4 = quartileAverage(cadenceSamples, first: false)

        return FormDegradationAnalysis(
            oscillationDelta: oscQ4 - oscQ1,
            gctDelta: gctQ4 - gctQ1,
            cadenceDelta: cadQ1 - cadQ4  // Cadence drop is degradation
        )
    }

    // MARK: - Stride Degradation Warning (2.12)

    /// Compare first-half vs second-half average stride length. Returns percentage shortening.
    func strideDegradation(splitStrideLengths: [Double]) -> (shortenedPercent: Double, isWarning: Bool) {
        guard splitStrideLengths.count >= 2 else { return (0, false) }
        let mid = splitStrideLengths.count / 2
        let firstHalf = Array(splitStrideLengths.prefix(mid))
        let secondHalf = Array(splitStrideLengths.suffix(from: mid))

        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)

        guard firstAvg > 0 else { return (0, false) }
        let percentChange = ((firstAvg - secondAvg) / firstAvg) * 100
        return (percentChange, percentChange > 3.0)
    }

    // MARK: - Per-Split Efficiency (1.3)

    /// Compute efficiency factor (pace / HR) per split. Returns array of EF values.
    func perSplitEfficiency(splitPaces: [Double], splitHeartRates: [Int]) -> [Double] {
        zip(splitPaces, splitHeartRates).map { pace, hr in
            guard hr > 0, pace > 0 else { return 0 }
            return pace / Double(hr)
        }
    }

    /// Detect efficiency deterioration: final third EF vs first third EF
    func efficiencyDeterioration(efficiencies: [Double]) -> (deteriorationPercent: Double, isSignificant: Bool) {
        guard efficiencies.count >= 3 else { return (0, false) }
        let third = efficiencies.count / 3
        let firstThird = Array(efficiencies.prefix(third))
        let lastThird = Array(efficiencies.suffix(third))

        let firstAvg = firstThird.reduce(0, +) / Double(firstThird.count)
        let lastAvg = lastThird.reduce(0, +) / Double(lastThird.count)

        guard firstAvg > 0 else { return (0, false) }
        let percentChange = ((lastAvg - firstAvg) / firstAvg) * 100
        return (percentChange, abs(percentChange) > 10)
    }
}

// MARK: - Form Degradation Analysis

struct FormDegradationAnalysis {
    let oscillationDelta: Double  // cm change Q1 vs Q4
    let gctDelta: Double  // ms change Q1 vs Q4
    let cadenceDelta: Double  // spm change Q1 vs Q4

    var oscillationDegraded: Bool { oscillationDelta > 1.0 }
    var gctDegraded: Bool { gctDelta > 20 }
    var cadenceDegraded: Bool { cadenceDelta > 5 }
    var hasDegradation: Bool { oscillationDegraded || gctDegraded || cadenceDegraded }

    var summary: String {
        var parts: [String] = []
        if oscillationDegraded { parts.append("oscillation +\(String(format: "%.1f", oscillationDelta))cm") }
        if gctDegraded { parts.append("GCT +\(String(format: "%.0f", gctDelta))ms") }
        if cadenceDegraded { parts.append("cadence -\(String(format: "%.0f", cadenceDelta))spm") }
        return parts.isEmpty ? "Form maintained" : parts.joined(separator: ", ")
    }
}
