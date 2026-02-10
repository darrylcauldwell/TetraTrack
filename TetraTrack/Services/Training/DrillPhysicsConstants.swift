//
//  DrillPhysicsConstants.swift
//  TetraTrack
//
//  Centralized physics and biomechanics constants for drill scoring and feedback.
//  All thresholds are derived from human movement science literature or empirically
//  calibrated from user data distributions.
//

import Foundation

/// Centralized constants for physics-based drill analysis
enum DrillPhysicsConstants {

    // MARK: - Postural Sway (Human Balance Literature)

    /// Normal quiet standing sway velocity: 0.8-1.2 cm/s (Prieto et al., 1996)
    /// At typical phone holding distance (~30cm from body center), this translates to:
    /// ~0.015-0.025 radians/s of angular velocity
    enum PosturalSway {
        /// Excellent stability threshold (radians RMS)
        /// Below this = very stable, minimal sway
        static let excellentThreshold: Double = 0.02

        /// Good stability threshold (radians RMS)
        /// Below this = good balance, normal healthy adult
        static let goodThreshold: Double = 0.04

        /// Warning threshold (radians RMS)
        /// Above this = noticeable instability, attention needed
        static let warningThreshold: Double = 0.08

        /// Critical threshold (radians RMS)
        /// Above this = significant instability, position reset needed
        static let criticalThreshold: Double = 0.15

        /// Variance-to-score multiplier
        /// Converts variance (rad²) to 0-100 score decrement
        /// Calibrated so variance of 0.002 rad² → score of 0
        static let varianceMultiplier: Double = 500.0
    }

    // MARK: - Left-Right Asymmetry (Rider Symmetry Literature)

    /// Asymmetry in equestrian sports: <5° considered acceptable
    /// Professional riders typically show <3° asymmetry (Byström et al., 2015)
    enum Asymmetry {
        /// Excellent symmetry threshold (degrees)
        /// Below this = near-perfect bilateral balance
        static let excellentThreshold: Double = 2.0

        /// Good symmetry threshold (degrees)
        /// Below this = acceptable for recreational riders
        static let goodThreshold: Double = 5.0

        /// Warning threshold (degrees)
        /// Above this = noticeable lean, coaching cue needed
        static let warningThreshold: Double = 8.0

        /// Critical threshold (degrees)
        /// Above this = significant postural compensation
        static let criticalThreshold: Double = 12.0

        /// Bias-to-score multiplier
        /// Converts accumulated roll bias (radians) to score decrement
        /// 0.1 rad (~5.7°) of sustained bias → 20 point penalty
        static let biasMultiplier: Double = 200.0
    }

    // MARK: - Pitch/Forward Lean (Stirrup Pressure, Heel Position)

    /// Forward lean for heel-down position: 5-15° optimal (heel sink)
    /// Based on dressage and jumping seat biomechanics
    enum ForwardLean {
        /// Optimal pitch range for heel-down drills (radians)
        /// Negative pitch = heels down, weight back
        static let optimalPitchMin: Double = -0.26  // ~15° heels down
        static let optimalPitchMax: Double = -0.09  // ~5° heels down

        /// Excessive forward lean threshold (radians)
        /// More negative than this = too much forward tip
        static let excessiveForwardThreshold: Double = -0.35  // ~20°

        /// Toes-down threshold (radians)
        /// Positive pitch = toes pointing down (bad)
        static let toesDownThreshold: Double = 0.0
    }

    // MARK: - Frequency Domain (Tremor vs Drift)

    /// Physiological tremor: 8-12 Hz (normal), increases under fatigue
    /// Postural drift: <1 Hz, slow weight shifts
    /// (Lakie et al., 1986; Morrison & Newell, 2000)
    enum FrequencyBands {
        /// Tremor frequency band lower bound (Hz)
        /// Physiological tremor typically 8-12 Hz but can appear as low as 3-4 Hz
        /// under stress or fatigue
        static let tremorLowCutoff: Double = 3.0

        /// Drift frequency band upper bound (Hz)
        /// Slow postural adjustments < 1 Hz
        static let driftHighCutoff: Double = 1.0

        /// Stability band (Hz) - mid-range indicates controlled movement
        static let stabilityBandLow: Double = 1.0
        static let stabilityBandHigh: Double = 3.0

        /// Tremor power threshold (relative)
        /// Above this indicates significant tremor
        static let tremorPowerWarning: Double = 0.2

        /// Drift power threshold (relative)
        /// Above this indicates significant postural drift
        static let driftPowerWarning: Double = 0.3
    }

    // MARK: - Rhythm and Timing (Equestrian Posting Trot)

    /// Posting trot rhythm: 1.3-1.6 Hz typical (140-170 BPM)
    /// Coefficient of variation <10% indicates good rhythm consistency
    enum RhythmTiming {
        /// Target posting frequency range (Hz)
        static let postingFrequencyMin: Double = 1.3  // ~78 BPM
        static let postingFrequencyMax: Double = 1.8  // ~108 BPM

        /// Excellent rhythm consistency (CV %)
        /// Below this = very consistent timing
        static let excellentConsistencyCV: Double = 0.05  // 5%

        /// Good rhythm consistency (CV %)
        static let goodConsistencyCV: Double = 0.10  // 10%

        /// Warning rhythm consistency (CV %)
        static let warningConsistencyCV: Double = 0.20  // 20%

        /// CV-to-score multiplier
        /// Converts coefficient of variation to score decrement
        static let cvMultiplier: Double = 100.0
    }

    // MARK: - Reaction Time (Shooting Sports Literature)

    /// Simple visual reaction time: 180-250ms for trained athletes
    /// Target acquisition: 300-500ms acceptable, <300ms excellent
    /// (Schmidt & Lee, Motor Learning and Performance)
    enum ReactionTime {
        /// Excellent reaction time (seconds)
        static let excellentThreshold: Double = 0.25

        /// Good reaction time (seconds)
        static let goodThreshold: Double = 0.40

        /// Acceptable reaction time (seconds)
        static let acceptableThreshold: Double = 0.60

        /// Split time excellent threshold (seconds)
        /// Multi-target transitions
        static let splitExcellent: Double = 0.35

        /// Split time good threshold (seconds)
        static let splitGood: Double = 0.50

        /// Recovery time excellent (seconds)
        /// Return to stable aim after perturbation
        static let recoveryExcellent: Double = 0.30

        /// Recovery time good (seconds)
        static let recoveryGood: Double = 0.50
    }

    // MARK: - Endurance/Fatigue Detection

    /// Fatigue typically manifests as:
    /// - 10-20% performance degradation over session
    /// - Increased variability (CV increases)
    /// - Frequency shift toward tremor band
    enum FatigueDetection {
        /// Significant fatigue threshold (% decline)
        /// Performance drop of this magnitude indicates fatigue
        static let significantDeclinePercent: Double = 15.0

        /// Mild fatigue threshold (% decline)
        static let mildDeclinePercent: Double = 8.0

        /// Stability ratio threshold
        /// recentStability / initialStability below this = fatigued
        static let fatigueRatio: Double = 0.85

        /// Initial baseline window (samples at 60Hz)
        static let baselineWindowSize: Int = 180  // 3 seconds

        /// Recent performance window (samples at 60Hz)
        static let recentWindowSize: Int = 60  // 1 second
    }

    // MARK: - Scoring Weights (Per Drill Type)

    /// Subscore weights vary by drill type to reflect what matters most
    struct ScoringWeights {
        let stability: Double
        let symmetry: Double
        let endurance: Double
        let coordination: Double

        /// Default balanced weights
        static let balanced = ScoringWeights(
            stability: 0.30,
            symmetry: 0.25,
            endurance: 0.25,
            coordination: 0.20
        )

        /// Stability-focused (rider stillness, steady hold)
        static let stabilityFocused = ScoringWeights(
            stability: 0.45,
            symmetry: 0.20,
            endurance: 0.20,
            coordination: 0.15
        )

        /// Symmetry-focused (balance board, heel position)
        static let symmetryFocused = ScoringWeights(
            stability: 0.25,
            symmetry: 0.40,
            endurance: 0.20,
            coordination: 0.15
        )

        /// Endurance-focused (postural drift, stress inoculation)
        static let enduranceFocused = ScoringWeights(
            stability: 0.25,
            symmetry: 0.20,
            endurance: 0.40,
            coordination: 0.15
        )

        /// Rhythm-focused (posting rhythm, cadence training)
        static let rhythmFocused = ScoringWeights(
            stability: 0.20,
            symmetry: 0.20,
            endurance: 0.25,
            coordination: 0.35
        )
    }

    // MARK: - Cue Thresholds (Real-Time Feedback)

    /// Thresholds for generating real-time coaching cues
    enum CueThresholds {
        /// Stability score thresholds for cue generation
        static let excellentStability: Double = 85.0
        static let goodStability: Double = 65.0
        static let warningStability: Double = 45.0
        static let criticalStability: Double = 30.0

        /// Asymmetry thresholds for directional cues (degrees)
        static let asymmetryCueThreshold: Double = 5.0
        static let asymmetryCriticalThreshold: Double = 10.0

        /// Forward/back lean thresholds for cues (degrees)
        static let leanCueThreshold: Double = 8.0
        static let leanCriticalThreshold: Double = 15.0

        /// Tremor power threshold for tremor-specific cues
        static let tremorCueThreshold: Double = 0.15

        /// Drift power threshold for drift-specific cues
        static let driftCueThreshold: Double = 0.20

        /// Fatigue detection threshold for endurance cues
        static let fatigueCueThreshold: Double = 0.12  // 12% decline
    }

    // MARK: - Sample Rate and Buffer Configuration

    enum SamplingConfig {
        /// Motion update rate (Hz)
        static let motionUpdateRate: Double = 60.0

        /// FFT window size (samples) - must be power of 2
        /// 256 samples at 60Hz = 4.27 seconds
        static let fftWindowSize: Int = 256

        /// Ring buffer capacity (samples)
        /// 60 samples at 60Hz = 1 second
        static let ringBufferCapacity: Int = 60

        /// Extended buffer for frequency analysis
        /// 256 samples for FFT
        static let frequencyBufferCapacity: Int = 256

        /// EMA smoothing factor for real-time metrics
        /// Lower = smoother but slower response
        static let emaAlpha: Double = 0.15
    }
}

// MARK: - Threshold Lookup by Drill Type

extension DrillPhysicsConstants {

    /// Get appropriate scoring weights for a drill type
    static func weights(for drillType: UnifiedDrillType) -> ScoringWeights {
        switch drillType {
        // Stability-focused drills
        case .riderStillness, .steadyHold, .streamlinePosition:
            return .stabilityFocused

        // Symmetry-focused drills
        case .heelPosition, .balanceBoard, .standingBalance:
            return .symmetryFocused

        // Endurance-focused drills
        case .posturalDrift, .stressInoculation, .twoPoint:
            return .enduranceFocused

        // Rhythm-focused drills
        case .postingRhythm, .cadenceTraining, .breathingRhythm:
            return .rhythmFocused

        // Default balanced
        default:
            return .balanced
        }
    }
}
