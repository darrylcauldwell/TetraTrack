//
//  GaitTransition.swift
//  TrackRide
//
//  Model for tracking gait transitions during rides

import Foundation
import SwiftData

// MARK: - Gait Transition Model

@Model
final class GaitTransition {
    var id: UUID = UUID()
    var fromGaitType: String = GaitType.stationary.rawValue
    var toGaitType: String = GaitType.stationary.rawValue
    var timestamp: Date = Date()
    var transitionQuality: Double = 0.0  // 0-1 score (1 = smooth, 0 = abrupt)

    // Relationship to ride - optional for CloudKit
    var ride: Ride?

    init() {}

    init(from: GaitType, to: GaitType, timestamp: Date, quality: Double = 0.0) {
        self.fromGaitType = from.rawValue
        self.toGaitType = to.rawValue
        self.timestamp = timestamp
        self.transitionQuality = quality
    }

    // MARK: - Computed Properties

    /// The source gait as enum
    var fromGait: GaitType {
        get { GaitType(rawValue: fromGaitType) ?? .stationary }
        set { fromGaitType = newValue.rawValue }
    }

    /// The destination gait as enum
    var toGait: GaitType {
        get { GaitType(rawValue: toGaitType) ?? .stationary }
        set { toGaitType = newValue.rawValue }
    }

    /// Whether this is an upward transition (faster gait)
    var isUpwardTransition: Bool {
        let gaitOrder: [GaitType] = [.stationary, .walk, .trot, .canter, .gallop]
        guard let fromIndex = gaitOrder.firstIndex(of: fromGait),
              let toIndex = gaitOrder.firstIndex(of: toGait) else {
            return false
        }
        return toIndex > fromIndex
    }

    /// Whether this is a downward transition (slower gait)
    var isDownwardTransition: Bool {
        let gaitOrder: [GaitType] = [.stationary, .walk, .trot, .canter, .gallop]
        guard let fromIndex = gaitOrder.firstIndex(of: fromGait),
              let toIndex = gaitOrder.firstIndex(of: toGait) else {
            return false
        }
        return toIndex < fromIndex
    }

    /// Description of the transition
    var transitionDescription: String {
        "\(fromGait.rawValue) → \(toGait.rawValue)"
    }

    /// Formatted quality score as percentage
    var formattedQuality: String {
        String(format: "%.0f%%", transitionQuality * 100)
    }

    /// Quality rating (poor, fair, good, excellent)
    var qualityRating: String {
        switch transitionQuality {
        case 0..<0.25:
            return "Poor"
        case 0.25..<0.5:
            return "Fair"
        case 0.5..<0.75:
            return "Good"
        default:
            return "Excellent"
        }
    }
}
