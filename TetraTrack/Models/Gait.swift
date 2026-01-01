//
//  Gait.swift
//  TetraTrack
//

import Foundation
import SwiftData

// MARK: - Gait Type

enum GaitType: String, Codable, CaseIterable {
    case stationary = "Stationary"
    case walk = "Walk"
    case trot = "Trot"
    case canter = "Canter"
    case gallop = "Gallop"

    var color: String {
        switch self {
        case .stationary: return "gray"
        case .walk: return "green"
        case .trot: return "blue"
        case .canter: return "orange"
        case .gallop: return "red"
        }
    }

    var icon: String {
        switch self {
        case .stationary: return "pause.circle"
        case .walk: return "figure.walk"
        case .trot: return "gauge.with.dots.needle.33percent"
        case .canter: return "gauge.with.dots.needle.67percent"
        case .gallop: return "bolt.fill"
        }
    }

    // Typical speed ranges in m/s for horse gaits
    // Adjusted for arena/schooling work where gaits are more collected
    static func fromSpeed(_ speed: Double) -> GaitType {
        switch speed {
        case ..<0.4: return .stationary    // Standing still
        case 0.4..<1.7: return .walk       // ~1.5-6 km/h (collected to medium walk)
        case 1.7..<3.5: return .trot       // ~6-12.5 km/h (collected to working trot)
        case 3.5..<5.5: return .canter     // ~12.5-20 km/h (collected to working canter)
        default: return .gallop            // >20 km/h (extended canter / gallop)
        }
    }
}

// MARK: - Phone Mount Position

/// Phone mounting position on rider, affects calibration and filtering
enum PhoneMountPosition: String, Codable, CaseIterable, PhonePlacementConfigurable {
    case jodhpurThigh = "Jodhpur Pocket"
    case jacketChest = "Jacket Pocket"

    /// Number of motion samples to wait before calibrating (at 100Hz)
    var calibrationDelay: Int {
        switch self {
        case .jodhpurThigh: return 100  // 1s - thigh bounces more, need longer settling
        case .jacketChest: return 50    // 0.5s - torso is more stable
        }
    }

    /// EMA filter alpha for motion filtering (lower = more smoothing)
    var filterAlpha: Double {
        switch self {
        case .jodhpurThigh: return 0.4  // More smoothing for bouncy thigh
        case .jacketChest: return 0.6   // Less smoothing for stable torso
        }
    }

    /// Calibration drift threshold in radians
    var driftThreshold: Double {
        switch self {
        case .jodhpurThigh: return 0.50  // More tolerant - thigh moves more
        case .jacketChest: return 0.35   // Tighter threshold for stable torso
        }
    }
}

// MARK: - Gait Segment Model

@Model
final class GaitSegment {
    var id: UUID = UUID()
    var gaitType: String = GaitType.stationary.rawValue  // Store as string for SwiftData
    var startTime: Date = Date()
    var endTime: Date?
    var distance: Double = 0.0  // meters
    var averageSpeed: Double = 0.0  // m/s

    // Lead tracking (for canter/gallop)
    var leadValue: String = Lead.unknown.rawValue
    var leadConfidence: Double = 0.0  // 0-1 confidence score

    // Rhythm tracking
    var rhythmScore: Double = 0.0  // 0-100%

    // MARK: - Spectral Metrics (Physics-Based)

    /// Stride frequency from FFT analysis (Hz)
    var strideFrequency: Double = 0.0

    /// Spectral entropy: signal complexity (0-1)
    var spectralEntropy: Double = 0.0

    /// Harmonic ratio H2 (2nd harmonic / fundamental)
    var harmonicRatioH2: Double = 0.0

    /// Harmonic ratio H3 (3rd harmonic / fundamental)
    var harmonicRatioH3: Double = 0.0

    /// Vertical-yaw coherence: phase coupling strength (0-1)
    /// Measures how well vertical bounce correlates with rotational movement
    var verticalYawCoherence: Double = 0.0

    // Relationship to ride - optional for CloudKit
    var ride: Ride?

    init() {}

    init(gaitType: GaitType, startTime: Date) {
        self.gaitType = gaitType.rawValue
        self.startTime = startTime
    }

    var gait: GaitType {
        get { GaitType(rawValue: gaitType) ?? .stationary }
        set { gaitType = newValue.rawValue }
    }

    /// The detected lead (for canter/gallop)
    var lead: Lead {
        get { Lead(rawValue: leadValue) ?? .unknown }
        set { leadValue = newValue.rawValue }
    }

    /// Whether lead detection is applicable for this gait
    var isLeadApplicable: Bool {
        gait == .canter || gait == .gallop
    }

    /// Whether lead was successfully detected
    var hasKnownLead: Bool {
        isLeadApplicable && lead != .unknown && leadConfidence >= 0.7
    }

    /// Whether the lead is correct for the current rein direction
    /// Correct lead: left lead on left rein, right lead on right rein
    /// Cross-canter: opposite lead to rein direction
    var isCorrectLead: Bool {
        guard isLeadApplicable, lead != .unknown else { return true }
        guard let ride = self.ride else { return true }

        // Find the rein segment that overlaps with this gait segment
        let overlappingRein = ride.sortedReinSegments.first { rein in
            let reinEnd = rein.endTime ?? Date.distantFuture
            return rein.startTime <= self.startTime && reinEnd >= self.startTime
        }

        guard let rein = overlappingRein else { return true }

        // Match lead to rein direction
        switch (rein.reinDirection, self.lead) {
        case (.left, .left), (.right, .right), (.straight, _):
            return true
        case (.left, .right), (.right, .left):
            return false  // Cross-canter
        default:
            return true
        }
    }

    var duration: TimeInterval {
        guard let end = endTime else { return 0 }
        return end.timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        duration.formattedDuration
    }

    var formattedRhythm: String {
        String(format: "%.0f%%", rhythmScore)
    }

    var formattedLeadConfidence: String {
        String(format: "%.0f%%", leadConfidence * 100)
    }

    // MARK: - Spectral Formatted Strings

    var formattedStrideFrequency: String {
        String(format: "%.1f Hz", strideFrequency)
    }
}
