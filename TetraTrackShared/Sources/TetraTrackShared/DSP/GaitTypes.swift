//
//  GaitTypes.swift
//  TetraTrackShared
//
//  Shared gait analysis types used by both iPhone and Watch DSP pipelines
//

import Foundation

// MARK: - Sensor Mount

/// Sensor mounting position — determines emission parameter tuning
public enum SensorMount: String, Sendable {
    case trunk   // Phone in pocket (thigh/chest) — current defaults
    case wrist   // Apple Watch on wrist
}

// MARK: - Feature Vector

/// Feature vector for gait classification
public struct GaitFeatureVector: Sendable {
    public let strideFrequency: Double      // f0 from FFT (Hz)
    public let h2Ratio: Double              // Harmonic ratio at 2*f0
    public let h3Ratio: Double              // Harmonic ratio at 3*f0
    public let spectralEntropy: Double      // Signal complexity (0-1)
    public let xyCoherence: Double          // Left-right symmetry (0-1)
    public let zYawCoherence: Double        // Vertical-rotational coupling (0-1)
    public let normalizedVerticalRMS: Double // RMS(Z) normalized by weight
    public let yawRateRMS: Double           // RMS of yaw rate (rad/s)
    public let gpsSpeed: Double             // Speed from GPS (m/s) for sanity checking
    public let gpsAccuracy: Double          // GPS horizontal accuracy in meters (lower = better)
    public let watchVerticalOscillation: Double // Watch vertical bounce (cm)
    public let watchMovementIntensity: Double   // Watch movement intensity (0-100)
    public let watchRhythmScore: Double          // Watch rhythm/sync score (0-100)
    public let watchPostureStability: Double      // Watch posture stability (0-100)
    public let watchDataAge: Double             // Seconds since last Watch update (999 = no Watch)
    public let strideLength: Double              // Derived: gpsSpeed / strideFrequency (meters)
    public let cadenceRegularity: Double         // CV of recent stride frequencies (0 = perfect, 1 = chaotic)

    public static let zero = GaitFeatureVector(
        strideFrequency: 0, h2Ratio: 0, h3Ratio: 0, spectralEntropy: 0,
        xyCoherence: 0, zYawCoherence: 0, normalizedVerticalRMS: 0,
        yawRateRMS: 0, gpsSpeed: 0, gpsAccuracy: 100,
        watchVerticalOscillation: 0, watchMovementIntensity: 0,
        watchRhythmScore: 0, watchPostureStability: 0, watchDataAge: 999,
        strideLength: 0, cadenceRegularity: 0
    )

    public init(
        strideFrequency: Double,
        h2Ratio: Double,
        h3Ratio: Double,
        spectralEntropy: Double,
        xyCoherence: Double,
        zYawCoherence: Double,
        normalizedVerticalRMS: Double,
        yawRateRMS: Double,
        gpsSpeed: Double,
        gpsAccuracy: Double,
        watchVerticalOscillation: Double = 0,
        watchMovementIntensity: Double = 0,
        watchRhythmScore: Double = 0,
        watchPostureStability: Double = 0,
        watchDataAge: Double = 999,
        strideLength: Double = 0,
        cadenceRegularity: Double = 0
    ) {
        self.strideFrequency = strideFrequency
        self.h2Ratio = h2Ratio
        self.h3Ratio = h3Ratio
        self.spectralEntropy = spectralEntropy
        self.xyCoherence = xyCoherence
        self.zYawCoherence = zYawCoherence
        self.normalizedVerticalRMS = normalizedVerticalRMS
        self.yawRateRMS = yawRateRMS
        self.gpsSpeed = gpsSpeed
        self.gpsAccuracy = gpsAccuracy
        self.watchVerticalOscillation = watchVerticalOscillation
        self.watchMovementIntensity = watchMovementIntensity
        self.watchRhythmScore = watchRhythmScore
        self.watchPostureStability = watchPostureStability
        self.watchDataAge = watchDataAge
        self.strideLength = strideLength
        self.cadenceRegularity = cadenceRegularity
    }
}

// MARK: - Riding Context

/// Detected riding context from GPS trajectory analysis
public enum RidingContext: String, Sendable {
    case arena        // Bounding box < 150m, high turn rate
    case hack         // Bounding box > 500m, linear travel
    case crossCountry // High speed segments + varied terrain
    case unknown      // Insufficient data or ambiguous
}

// MARK: - HMM Gait State

/// HMM gait state
public enum HMMGaitState: Int, CaseIterable, Sendable {
    case stationary = 0
    case walk = 1
    case trot = 2
    case canter = 3
    case gallop = 4

    public var name: String {
        switch self {
        case .stationary: return "Stationary"
        case .walk: return "Walk"
        case .trot: return "Trot"
        case .canter: return "Canter"
        case .gallop: return "Gallop"
        }
    }
}

// MARK: - Gaussian Emission

/// Gaussian emission parameters for a feature
public struct GaussianEmission: Sendable {
    public var mean: Double
    public var variance: Double

    public init(mean: Double, variance: Double) {
        self.mean = mean
        self.variance = variance
    }

    /// Compute probability density for a value
    public func probability(_ value: Double) -> Double {
        guard variance > 1e-10 else { return value == mean ? 1.0 : 0.0 }
        let exponent = -((value - mean) * (value - mean)) / (2 * variance)
        let coefficient = 1.0 / sqrt(2 * .pi * variance)
        return coefficient * exp(exponent)
    }

    /// Compute log probability density for a value
    /// Using log avoids underflow when multiplying many small probabilities
    public func logProbability(_ value: Double) -> Double {
        guard variance > 1e-10 else { return value == mean ? 0.0 : -1000.0 }
        let logCoeff = -0.5 * log(2 * .pi * variance)
        let exponent = -((value - mean) * (value - mean)) / (2 * variance)
        return logCoeff + exponent
    }
}

// MARK: - Biomechanical Priors

/// Biomechanical parameters for gait analysis, specific to horse type/breed
public struct BiomechanicalPriors: Codable, Equatable, Sendable {
    /// Expected stride frequency range for walk (Hz)
    public let walkFrequencyRange: ClosedRange<Double>

    /// Expected stride frequency range for trot (Hz)
    public let trotFrequencyRange: ClosedRange<Double>

    /// Expected stride frequency range for canter (Hz)
    public let canterFrequencyRange: ClosedRange<Double>

    /// Expected stride frequency range for gallop (Hz)
    public let gallopFrequencyRange: ClosedRange<Double>

    /// Stride length coefficients for physics-based calculation
    /// stride = k * height * (Az/g)^0.25
    public let strideCoefficients: StrideCoefficients

    /// Typical weight for this breed type (kg)
    public let typicalWeight: Double

    /// Typical height for this breed type (hands)
    public let typicalHeight: Double

    /// Default priors for a standard 15.2hh horse
    public static let `default` = BiomechanicalPriors(
        walkFrequencyRange: 1.0...2.2,
        trotFrequencyRange: 2.0...3.8,
        canterFrequencyRange: 1.8...3.0,
        gallopFrequencyRange: 3.0...6.0,
        strideCoefficients: StrideCoefficients(walk: 2.2, trot: 2.7, canter: 3.3, gallop: 4.0),
        typicalWeight: 500,
        typicalHeight: 15.2
    )

    public init(
        walkFrequencyRange: ClosedRange<Double>,
        trotFrequencyRange: ClosedRange<Double>,
        canterFrequencyRange: ClosedRange<Double>,
        gallopFrequencyRange: ClosedRange<Double>,
        strideCoefficients: StrideCoefficients,
        typicalWeight: Double,
        typicalHeight: Double
    ) {
        self.walkFrequencyRange = walkFrequencyRange
        self.trotFrequencyRange = trotFrequencyRange
        self.canterFrequencyRange = canterFrequencyRange
        self.gallopFrequencyRange = gallopFrequencyRange
        self.strideCoefficients = strideCoefficients
        self.typicalWeight = typicalWeight
        self.typicalHeight = typicalHeight
    }
}

/// Stride length coefficients per gait
public struct StrideCoefficients: Codable, Equatable, Sendable {
    public let walk: Double
    public let trot: Double
    public let canter: Double
    public let gallop: Double

    public init(walk: Double, trot: Double, canter: Double, gallop: Double) {
        self.walk = walk
        self.trot = trot
        self.canter = canter
        self.gallop = gallop
    }
}

// MARK: - Learned Gait Parameters

/// Learned per-horse parameters from accumulated ride data
public struct LearnedGaitParameters: Codable, Sendable {
    public var walkFrequencyCenter: Double?
    public var trotFrequencyCenter: Double?
    public var canterFrequencyCenter: Double?
    public var gallopFrequencyCenter: Double?
    public var walkH2Mean: Double?
    public var trotH2Mean: Double?
    public var canterH3Mean: Double?
    public var gallopEntropyMean: Double?
    public var rideCount: Int = 0
    public var lastUpdate: Date?
    public var referenceWeight: Double?

    private enum CodingKeys: String, CodingKey {
        case walkFrequencyCenter, trotFrequencyCenter
        case canterFrequencyCenter, gallopFrequencyCenter
        case walkH2Mean, trotH2Mean
        case canterH3Mean, gallopEntropyMean
        case rideCount, lastUpdate, referenceWeight
    }

    public init(
        walkFrequencyCenter: Double? = nil,
        trotFrequencyCenter: Double? = nil,
        canterFrequencyCenter: Double? = nil,
        gallopFrequencyCenter: Double? = nil,
        walkH2Mean: Double? = nil,
        trotH2Mean: Double? = nil,
        canterH3Mean: Double? = nil,
        gallopEntropyMean: Double? = nil,
        rideCount: Int = 0,
        lastUpdate: Date? = nil,
        referenceWeight: Double? = nil
    ) {
        self.walkFrequencyCenter = walkFrequencyCenter
        self.trotFrequencyCenter = trotFrequencyCenter
        self.canterFrequencyCenter = canterFrequencyCenter
        self.gallopFrequencyCenter = gallopFrequencyCenter
        self.walkH2Mean = walkH2Mean
        self.trotH2Mean = trotH2Mean
        self.canterH3Mean = canterH3Mean
        self.gallopEntropyMean = gallopEntropyMean
        self.rideCount = rideCount
        self.lastUpdate = lastUpdate
        self.referenceWeight = referenceWeight
    }

    // Explicit Codable for backward compatibility (rideCount defaults to 0 when missing)
    public nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.walkFrequencyCenter = try container.decodeIfPresent(Double.self, forKey: .walkFrequencyCenter)
        self.trotFrequencyCenter = try container.decodeIfPresent(Double.self, forKey: .trotFrequencyCenter)
        self.canterFrequencyCenter = try container.decodeIfPresent(Double.self, forKey: .canterFrequencyCenter)
        self.gallopFrequencyCenter = try container.decodeIfPresent(Double.self, forKey: .gallopFrequencyCenter)
        self.walkH2Mean = try container.decodeIfPresent(Double.self, forKey: .walkH2Mean)
        self.trotH2Mean = try container.decodeIfPresent(Double.self, forKey: .trotH2Mean)
        self.canterH3Mean = try container.decodeIfPresent(Double.self, forKey: .canterH3Mean)
        self.gallopEntropyMean = try container.decodeIfPresent(Double.self, forKey: .gallopEntropyMean)
        self.rideCount = try container.decodeIfPresent(Int.self, forKey: .rideCount) ?? 0
        self.lastUpdate = try container.decodeIfPresent(Date.self, forKey: .lastUpdate)
        self.referenceWeight = try container.decodeIfPresent(Double.self, forKey: .referenceWeight)
    }

    public nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(walkFrequencyCenter, forKey: .walkFrequencyCenter)
        try container.encodeIfPresent(trotFrequencyCenter, forKey: .trotFrequencyCenter)
        try container.encodeIfPresent(canterFrequencyCenter, forKey: .canterFrequencyCenter)
        try container.encodeIfPresent(gallopFrequencyCenter, forKey: .gallopFrequencyCenter)
        try container.encodeIfPresent(walkH2Mean, forKey: .walkH2Mean)
        try container.encodeIfPresent(trotH2Mean, forKey: .trotH2Mean)
        try container.encodeIfPresent(canterH3Mean, forKey: .canterH3Mean)
        try container.encodeIfPresent(gallopEntropyMean, forKey: .gallopEntropyMean)
        try container.encode(rideCount, forKey: .rideCount)
        try container.encodeIfPresent(lastUpdate, forKey: .lastUpdate)
        try container.encodeIfPresent(referenceWeight, forKey: .referenceWeight)
    }
}

// MARK: - FFT Result

/// Result of FFT analysis on a signal window
public struct FFTResult: Sendable {
    public let dominantFrequency: Double
    public let powerAtF0: Double
    public let h2Ratio: Double
    public let h3Ratio: Double
    public let spectralEntropy: Double
    public let frequencyResolution: Double

    public init(
        dominantFrequency: Double,
        powerAtF0: Double,
        h2Ratio: Double,
        h3Ratio: Double,
        spectralEntropy: Double,
        frequencyResolution: Double
    ) {
        self.dominantFrequency = dominantFrequency
        self.powerAtF0 = powerAtF0
        self.h2Ratio = h2Ratio
        self.h3Ratio = h3Ratio
        self.spectralEntropy = spectralEntropy
        self.frequencyResolution = frequencyResolution
    }
}

// MARK: - Diagnostic Entry

/// Codable diagnostic entry for persistent storage and export
public struct GaitDiagnosticEntry: Codable, Sendable {
    public let timestamp: Date
    public let detectedGait: String
    public let confidence: Double
    public let stateProbabilities: [String: Double]
    public let strideFrequency: Double
    public let h2Ratio: Double
    public let h3Ratio: Double
    public let spectralEntropy: Double
    public let xyCoherence: Double
    public let zYawCoherence: Double
    public let normalizedVerticalRMS: Double
    public let yawRateRMS: Double
    public let gpsSpeed: Double
    public let gpsAccuracy: Double
    public let watchVerticalOscillation: Double
    public let watchMovementIntensity: Double
    public let watchRhythmScore: Double
    public let watchPostureStability: Double
    public let watchDataAge: Double

    public init(
        timestamp: Date,
        detectedGait: String,
        confidence: Double,
        stateProbabilities: [String: Double],
        strideFrequency: Double,
        h2Ratio: Double,
        h3Ratio: Double,
        spectralEntropy: Double,
        xyCoherence: Double,
        zYawCoherence: Double,
        normalizedVerticalRMS: Double,
        yawRateRMS: Double,
        gpsSpeed: Double,
        gpsAccuracy: Double,
        watchVerticalOscillation: Double = 0,
        watchMovementIntensity: Double = 0,
        watchRhythmScore: Double = 0,
        watchPostureStability: Double = 0,
        watchDataAge: Double = 999
    ) {
        self.timestamp = timestamp
        self.detectedGait = detectedGait
        self.confidence = confidence
        self.stateProbabilities = stateProbabilities
        self.strideFrequency = strideFrequency
        self.h2Ratio = h2Ratio
        self.h3Ratio = h3Ratio
        self.spectralEntropy = spectralEntropy
        self.xyCoherence = xyCoherence
        self.zYawCoherence = zYawCoherence
        self.normalizedVerticalRMS = normalizedVerticalRMS
        self.yawRateRMS = yawRateRMS
        self.gpsSpeed = gpsSpeed
        self.gpsAccuracy = gpsAccuracy
        self.watchVerticalOscillation = watchVerticalOscillation
        self.watchMovementIntensity = watchMovementIntensity
        self.watchRhythmScore = watchRhythmScore
        self.watchPostureStability = watchPostureStability
        self.watchDataAge = watchDataAge
    }
}

// MARK: - Diagnostic Structures (DEBUG)

#if DEBUG
/// Diagnostic snapshot for gait classification analysis
public struct GaitDiagnosticSnapshot: CustomStringConvertible {
    public let timestamp: Date
    public let currentGait: HMMGaitState
    public let proposedGait: HMMGaitState
    public let confidence: Double
    public let stateProbs: [String: Double]
    public let features: GaitFeatureSnapshot
    public let horseProfile: HorseProfileSnapshot?
    public let transitionInfo: String

    public init(
        timestamp: Date,
        currentGait: HMMGaitState,
        proposedGait: HMMGaitState,
        confidence: Double,
        stateProbs: [String: Double],
        features: GaitFeatureSnapshot,
        horseProfile: HorseProfileSnapshot?,
        transitionInfo: String
    ) {
        self.timestamp = timestamp
        self.currentGait = currentGait
        self.proposedGait = proposedGait
        self.confidence = confidence
        self.stateProbs = stateProbs
        self.features = features
        self.horseProfile = horseProfile
        self.transitionInfo = transitionInfo
    }

    public var description: String {
        let probsStr = stateProbs.map { "\($0.key)=\(String(format: "%.3f", $0.value))" }.joined(separator: ", ")
        return """
        [GAIT_DIAG] {
          "timestamp": "\(ISO8601DateFormatter().string(from: timestamp))",
          "current_gait": "\(currentGait.name)",
          "proposed_gait": "\(proposedGait.name)",
          "confidence": \(String(format: "%.3f", confidence)),
          "state_probs": {\(probsStr)},
          "features": \(features.jsonString),
          "horse_profile": \(horseProfile?.jsonString ?? "null"),
          "transition": "\(transitionInfo)"
        }
        """
    }
}

/// Feature snapshot for diagnostics
public struct GaitFeatureSnapshot {
    public let strideFrequency: Double
    public let h2Ratio: Double
    public let h3Ratio: Double
    public let h3h2Ratio: Double
    public let spectralEntropy: Double
    public let verticalRMSRaw: Double
    public let verticalRMSNormalized: Double
    public let yawRMS: Double
    public let xyCoherence: Double
    public let zYawCoherence: Double
    public let gpsSpeed: Double
    public let watchVerticalOscillation: Double
    public let watchMovementIntensity: Double
    public let watchRhythmScore: Double
    public let watchPostureStability: Double
    public let watchDataAge: Double

    public init(
        strideFrequency: Double,
        h2Ratio: Double,
        h3Ratio: Double,
        h3h2Ratio: Double,
        spectralEntropy: Double,
        verticalRMSRaw: Double,
        verticalRMSNormalized: Double,
        yawRMS: Double,
        xyCoherence: Double,
        zYawCoherence: Double,
        gpsSpeed: Double,
        watchVerticalOscillation: Double = 0,
        watchMovementIntensity: Double = 0,
        watchRhythmScore: Double = 0,
        watchPostureStability: Double = 0,
        watchDataAge: Double = 999
    ) {
        self.strideFrequency = strideFrequency
        self.h2Ratio = h2Ratio
        self.h3Ratio = h3Ratio
        self.h3h2Ratio = h3h2Ratio
        self.spectralEntropy = spectralEntropy
        self.verticalRMSRaw = verticalRMSRaw
        self.verticalRMSNormalized = verticalRMSNormalized
        self.yawRMS = yawRMS
        self.xyCoherence = xyCoherence
        self.zYawCoherence = zYawCoherence
        self.gpsSpeed = gpsSpeed
        self.watchVerticalOscillation = watchVerticalOscillation
        self.watchMovementIntensity = watchMovementIntensity
        self.watchRhythmScore = watchRhythmScore
        self.watchPostureStability = watchPostureStability
        self.watchDataAge = watchDataAge
    }

    // swiftlint:disable line_length
    public var jsonString: String {
        """
        {"f0": \(String(format: "%.2f", strideFrequency)), "H2": \(String(format: "%.3f", h2Ratio)), "H3": \(String(format: "%.3f", h3Ratio)), "H3/H2": \(String(format: "%.3f", h3h2Ratio)), "entropy": \(String(format: "%.3f", spectralEntropy)), "rms_raw": \(String(format: "%.4f", verticalRMSRaw)), "rms_norm": \(String(format: "%.4f", verticalRMSNormalized)), "yaw_rms": \(String(format: "%.3f", yawRMS)), "xy_coh": \(String(format: "%.3f", xyCoherence)), "z_yaw_coh": \(String(format: "%.3f", zYawCoherence)), "gps_speed": \(String(format: "%.2f", gpsSpeed)), "watch_vo": \(String(format: "%.2f", watchVerticalOscillation)), "watch_mi": \(String(format: "%.1f", watchMovementIntensity)), "watch_rs": \(String(format: "%.1f", watchRhythmScore)), "watch_ps": \(String(format: "%.1f", watchPostureStability)), "watch_age": \(String(format: "%.1f", watchDataAge))}
        """
    }
    // swiftlint:enable line_length
}

/// Horse profile snapshot for diagnostics
public struct HorseProfileSnapshot {
    public let present: Bool
    public let breed: String?
    public let heightHands: Double?
    public let weightKg: Double?

    public init(present: Bool, breed: String?, heightHands: Double?, weightKg: Double?) {
        self.present = present
        self.breed = breed
        self.heightHands = heightHands
        self.weightKg = weightKg
    }

    public var jsonString: String {
        if !present { return "null" }
        return """
        {"present": true, "breed": "\(breed ?? "unknown")", "height": \(heightHands.map { String(format: "%.1f", $0) } ?? "null"), "weight": \(weightKg.map { String(format: "%.0f", $0) } ?? "null")}
        """
    }
}

/// Transition dynamics result for hypothesis testing
public struct TransitionDynamicsResult {
    public let fromState: HMMGaitState
    public let toState: HMMGaitState
    public let stepsToTransition: Int
    public let timeToTransitionSeconds: Double
    public let finalProbability: Double
    public let probabilityHistory: [Double]

    public init(
        fromState: HMMGaitState,
        toState: HMMGaitState,
        stepsToTransition: Int,
        timeToTransitionSeconds: Double,
        finalProbability: Double,
        probabilityHistory: [Double]
    ) {
        self.fromState = fromState
        self.toState = toState
        self.stepsToTransition = stepsToTransition
        self.timeToTransitionSeconds = timeToTransitionSeconds
        self.finalProbability = finalProbability
        self.probabilityHistory = probabilityHistory
    }

    public var summary: String {
        """
        Transition \(fromState.name) -> \(toState.name): \(stepsToTransition) steps (\(String(format: "%.2f", timeToTransitionSeconds))s), final P=\(String(format: "%.3f", finalProbability))
        """
    }
}

#endif
