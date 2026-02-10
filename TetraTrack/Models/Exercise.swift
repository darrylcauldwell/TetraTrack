//
//  Exercise.swift
//  TetraTrack
//
//  Arena exercises and schooling figures
//

import Foundation

// MARK: - Pole Layout

enum PoleLayout: String, Codable, CaseIterable {
    case straight = "Straight Line"
    case curved = "Curved/Arc"
    case fan = "Fan"
    case raised = "Raised"
    case bounce = "Bounce"
    case grid = "Grid"

    var icon: String {
        switch self {
        case .straight: return "line.3.horizontal"
        case .curved: return "arrow.up.right.and.arrow.down.left"
        case .fan: return "chevron.up"
        case .raised: return "arrow.up"
        case .bounce: return "arrow.up.arrow.down"
        case .grid: return "square.grid.3x3"
        }
    }
}

// MARK: - Pole Spacing Calculator

struct PoleSpacingCalculator {
    /// Base pole spacings for a 15hh horse (in meters)
    static let walkSpacing: Double = 0.75  // 75cm
    static let trotSpacing: Double = 1.30  // 1.3m
    static let canterSpacing: Double = 3.0 // 3m
    static let bounceSpacing: Double = 3.3 // 3.3m (one non-jumping stride)

    /// Calculate adjusted spacing based on horse height
    /// - Parameters:
    ///   - baseSpacing: The base spacing for a 15hh horse
    ///   - horseHeightHands: The horse's height in hands
    /// - Returns: Adjusted spacing in meters
    static func adjustedSpacing(baseSpacing: Double, forHeightHands horseHeightHands: Double) -> Double {
        // Adjustment factor: approximately 5cm per hand difference from 15hh
        let baseHeight: Double = 15.0
        let adjustmentPerHand: Double = 0.05 // 5cm per hand
        let heightDifference = horseHeightHands - baseHeight
        let adjustment = heightDifference * adjustmentPerHand

        return baseSpacing + adjustment
    }

    /// Get recommended pole spacings for a horse
    static func recommendedSpacings(forHeightHands height: Double) -> PoleSpacings {
        PoleSpacings(
            walk: adjustedSpacing(baseSpacing: walkSpacing, forHeightHands: height),
            trot: adjustedSpacing(baseSpacing: trotSpacing, forHeightHands: height),
            canter: adjustedSpacing(baseSpacing: canterSpacing, forHeightHands: height),
            bounce: adjustedSpacing(baseSpacing: bounceSpacing, forHeightHands: height)
        )
    }

    /// Format spacing for display
    static func formatSpacing(_ meters: Double) -> String {
        if meters < 1.0 {
            return String(format: "%.0fcm", meters * 100)
        }
        return String(format: "%.2fm", meters)
    }
}

struct PoleSpacings {
    let walk: Double
    let trot: Double
    let canter: Double
    let bounce: Double

    var formattedWalk: String { PoleSpacingCalculator.formatSpacing(walk) }
    var formattedTrot: String { PoleSpacingCalculator.formatSpacing(trot) }
    var formattedCanter: String { PoleSpacingCalculator.formatSpacing(canter) }
    var formattedBounce: String { PoleSpacingCalculator.formatSpacing(bounce) }
}

