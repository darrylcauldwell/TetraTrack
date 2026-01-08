//
//  Lead.swift
//  TrackRide
//
//  Lead leg detection for canter and gallop gaits

import SwiftUI

// MARK: - Lead

/// Represents which leg is leading in canter/gallop
enum Lead: String, Codable, CaseIterable {
    case left = "Left"
    case right = "Right"
    case unknown = "Unknown"

    /// SF Symbol icon for the lead
    var icon: String {
        switch self {
        case .left:
            return "arrow.turn.up.left"
        case .right:
            return "arrow.turn.up.right"
        case .unknown:
            return "questionmark.circle"
        }
    }

    /// Color associated with lead
    var color: Color {
        switch self {
        case .left:
            return AppColors.turnLeft
        case .right:
            return AppColors.turnRight
        case .unknown:
            return Color.secondary
        }
    }

    /// Whether the lead is known (not unknown)
    var isKnown: Bool {
        self != .unknown
    }

    /// Description of the lead
    var description: String {
        switch self {
        case .left:
            return "Left leg leading"
        case .right:
            return "Right leg leading"
        case .unknown:
            return "Lead not detected"
        }
    }
}

// MARK: - Rein Direction

/// Represents which rein (direction) the horse is working on
enum ReinDirection: String, Codable, CaseIterable {
    case left = "Left"
    case right = "Right"
    case straight = "Straight"

    /// SF Symbol icon for the rein direction
    var icon: String {
        switch self {
        case .left:
            return "arrow.counterclockwise"
        case .right:
            return "arrow.clockwise"
        case .straight:
            return "arrow.up"
        }
    }

    /// Color associated with rein direction
    var color: Color {
        switch self {
        case .left:
            return AppColors.turnLeft
        case .right:
            return AppColors.turnRight
        case .straight:
            return Color.secondary
        }
    }

    /// Whether currently on a rein (not straight)
    var isOnRein: Bool {
        self != .straight
    }

    /// Description of the rein direction
    var description: String {
        switch self {
        case .left:
            return "Working on left rein"
        case .right:
            return "Working on right rein"
        case .straight:
            return "Going straight"
        }
    }
}
