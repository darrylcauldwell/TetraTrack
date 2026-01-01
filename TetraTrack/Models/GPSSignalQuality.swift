//
//  GPSSignalQuality.swift
//  TetraTrack
//
//  GPS signal quality indicator based on horizontal accuracy
//

import SwiftUI

/// GPS signal quality levels based on horizontal accuracy
enum GPSSignalQuality: String, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case none = "No Signal"

    /// Create from horizontal accuracy in meters
    /// Lower accuracy value = better signal
    init(horizontalAccuracy: Double) {
        if horizontalAccuracy < 0 {
            // Negative accuracy means invalid/no signal
            self = .none
        } else if horizontalAccuracy <= 5 {
            self = .excellent
        } else if horizontalAccuracy <= 10 {
            self = .good
        } else if horizontalAccuracy <= 25 {
            self = .fair
        } else {
            self = .poor
        }
    }

    /// Number of signal bars (0-4)
    var bars: Int {
        switch self {
        case .excellent: return 4
        case .good: return 3
        case .fair: return 2
        case .poor: return 1
        case .none: return 0
        }
    }

    /// Color for the signal indicator
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .green
        case .fair: return .yellow
        case .poor: return .orange
        case .none: return .red
        }
    }

    /// SF Symbol for the signal
    var icon: String {
        switch self {
        case .excellent, .good:
            return "location.fill"
        case .fair:
            return "location.fill"
        case .poor:
            return "location"
        case .none:
            return "location.slash"
        }
    }

    /// Description of impact on tracking
    var impactDescription: String {
        switch self {
        case .excellent:
            return "Optimal tracking accuracy"
        case .good:
            return "Good tracking accuracy"
        case .fair:
            return "Reduced accuracy - distance/speed may be less precise"
        case .poor:
            return "Poor signal - tracking may be inaccurate"
        case .none:
            return "No GPS signal - tracking unavailable"
        }
    }

    /// Whether gait detection should rely more on GPS speed
    var trustGPSSpeed: Bool {
        switch self {
        case .excellent, .good: return true
        case .fair, .poor, .none: return false
        }
    }
}
