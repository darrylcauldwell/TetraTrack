//
//  RunningPhase.swift
//  TetraTrack
//
//  Running gait phase classification and phone-sourced form samples

import Foundation

// MARK: - Running Phase

enum RunningPhase: String, Codable, CaseIterable, Identifiable {
    case walking = "Walking"
    case jogging = "Jogging"
    case running = "Running"
    case sprinting = "Sprinting"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .walking: return "figure.walk"
        case .jogging: return "figure.run"
        case .running: return "figure.run"
        case .sprinting: return "figure.run.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .walking: return "blue"
        case .jogging: return "green"
        case .running: return "orange"
        case .sprinting: return "red"
        }
    }

    /// Map running phase to equestrian GaitType for live sharing route colors
    var toGaitType: GaitType {
        switch self {
        case .walking: return .walk
        case .jogging: return .trot
        case .running: return .canter
        case .sprinting: return .gallop
        }
    }

    /// Classify running phase from GPS speed (m/s) for post-session analysis.
    /// Uses fixed thresholds without hysteresis — appropriate for one-shot classification.
    static func fromGPSSpeed(_ speedMS: Double) -> RunningPhase {
        if speedMS >= 4.5 { return .sprinting }
        if speedMS >= 2.8 { return .running }
        if speedMS >= 1.5 { return .jogging }
        return .walking
    }

    /// Typical stride frequency range (Hz) for this phase
    var strideFrequencyRange: ClosedRange<Double> {
        switch self {
        case .walking: return 0.8...1.2
        case .jogging: return 1.2...1.5
        case .running: return 1.5...1.8
        case .sprinting: return 1.8...2.5
        }
    }
}

// MARK: - Phone Placement Protocol

/// Shared protocol for phone placement across disciplines.
/// Each discipline defines its own enum with discipline-specific properties,
/// but shares filterAlpha for MotionManager configuration.
protocol PhonePlacementConfigurable {
    var filterAlpha: Double { get }
}

// MARK: - Running Phone Placement

enum RunningPhonePlacement: String, Codable, CaseIterable, Identifiable, PhonePlacementConfigurable {
    case shortsThigh = "shortsThigh"
    case waistband = "waistband"
    case jacketChest = "jacketChest"
    case armband = "armband"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shortsThigh: return "Shorts/Leggings Pocket"
        case .waistband: return "Waistband/Belt"
        case .jacketChest: return "Jacket Pocket"
        case .armband: return "Armband"
        }
    }

    var icon: String {
        switch self {
        case .shortsThigh: return "figure.run"
        case .waistband: return "figure.stand"
        case .jacketChest: return "tshirt.fill"
        case .armband: return "applewatch.side.right"
        }
    }

    /// G-force threshold for foot strike detection.
    /// Thigh is closest to ground contact (strongest signal). Chest is attenuated.
    /// Armband needs higher threshold to reject arm swing peaks.
    var impactThreshold: Double {
        switch self {
        case .shortsThigh: return 1.2
        case .waistband: return 1.0
        case .jacketChest: return 0.8
        case .armband: return 1.5
        }
    }

    /// EMA filter alpha (lower = more smoothing)
    var filterAlpha: Double {
        switch self {
        case .shortsThigh: return 0.5
        case .waistband: return 0.5
        case .jacketChest: return 0.6
        case .armband: return 0.4
        }
    }

    var accuracyHint: String {
        switch self {
        case .shortsThigh: return "Best accuracy"
        case .waistband: return "Good accuracy"
        case .jacketChest: return "Good accuracy"
        case .armband: return "Reduced accuracy — arm swing adds noise"
        }
    }

    var isRecommended: Bool { self == .shortsThigh }
}

// MARK: - Running Phase Breakdown

/// Time spent in each running phase during a session
struct RunningPhaseBreakdown: Codable {
    var walkingSeconds: TimeInterval = 0
    var joggingSeconds: TimeInterval = 0
    var runningSeconds: TimeInterval = 0
    var sprintingSeconds: TimeInterval = 0

    var totalSeconds: TimeInterval {
        walkingSeconds + joggingSeconds + runningSeconds + sprintingSeconds
    }

    func percentage(for phase: RunningPhase) -> Double {
        guard totalSeconds > 0 else { return 0 }
        let phaseTime: TimeInterval
        switch phase {
        case .walking: phaseTime = walkingSeconds
        case .jogging: phaseTime = joggingSeconds
        case .running: phaseTime = runningSeconds
        case .sprinting: phaseTime = sprintingSeconds
        }
        return (phaseTime / totalSeconds) * 100
    }

    mutating func addTime(_ seconds: TimeInterval, for phase: RunningPhase) {
        switch phase {
        case .walking: walkingSeconds += seconds
        case .jogging: joggingSeconds += seconds
        case .running: runningSeconds += seconds
        case .sprinting: sprintingSeconds += seconds
        }
    }
}
