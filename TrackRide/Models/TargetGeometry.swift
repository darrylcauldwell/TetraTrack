//
//  TargetGeometry.swift
//  TrackRide
//
//  Physical target specifications and scoring calculations
//  Based on UIPM tetrathlon air pistol target standards
//

import Foundation
import CoreGraphics

// MARK: - Tetrathlon Target Geometry

/// Physical dimensions of tetrathlon air pistol target
/// Based on UIPM specifications
struct TetrathlonTargetGeometry {

    // MARK: - Physical Dimensions

    /// Total target card dimensions (mm)
    static let cardWidth: Double = 170
    static let cardHeight: Double = 170

    /// Scoring zone outer semi-axes (mm) - elliptical zones
    /// Zone boundaries from center outward: score, X semi-axis, Y semi-axis
    static let scoringZones: [(score: Int, semiAxisX: Double, semiAxisY: Double)] = [
        (10, 5.75, 7.5),      // Inner 10 (X-ring equivalent)
        (8, 20.0, 26.0),      // 8 zone
        (6, 34.25, 44.5),     // 6 zone
        (4, 48.5, 63.0),      // 4 zone
        (2, 62.75, 81.5),     // 2 zone (outer edge)
    ]

    /// Normalized scoring zone radii (as fraction of outer boundary)
    static let normalizedScoringRadii: [(score: Int, normalizedRadius: Double)] = [
        (10, 0.092),   // ~9.2% of target radius
        (8, 0.319),    // ~32%
        (6, 0.546),    // ~55%
        (4, 0.773),    // ~77%
        (2, 1.0),      // 100% (outer edge)
    ]

    /// Standard air pistol pellet diameter (mm)
    static let pelletDiameter: Double = 4.5

    /// Pellet radius as fraction of target radius
    static let normalizedPelletRadius: Double = 0.035

    /// Target aspect ratio (width / height)
    static let aspectRatio: Double = 0.77

    // MARK: - Score Calculation

    /// Calculate score from position in millimeters from center
    static func score(atX x: Double, atY y: Double) -> Int {
        for zone in scoringZones {
            let normalizedDistance = sqrt(
                pow(x / zone.semiAxisX, 2) + pow(y / zone.semiAxisY, 2)
            )
            if normalizedDistance <= 1.0 {
                return zone.score
            }
        }
        return 0  // Miss
    }

    /// Calculate score from normalized target position
    static func score(from position: NormalizedTargetPosition) -> Int {
        let ellipticalDistance = position.ellipticalDistance(aspectRatio: aspectRatio)

        for (score, normalizedRadius) in normalizedScoringRadii {
            if ellipticalDistance <= normalizedRadius {
                return score
            }
        }
        return 0  // Miss
    }

    /// Calculate score with pellet edge consideration
    /// Uses the "inside edge" rule - pellet must break the line
    static func scoreWithPelletEdge(
        from position: NormalizedTargetPosition,
        pelletRadiusNormalized: Double = normalizedPelletRadius
    ) -> Int {
        // Subtract pellet radius from distance (pellet just needs to touch line)
        let effectiveDistance = max(0, position.radialDistance - pelletRadiusNormalized)

        for (score, normalizedRadius) in normalizedScoringRadii {
            if effectiveDistance <= normalizedRadius {
                return score
            }
        }
        return 0  // Miss
    }

    /// Get the scoring ring radius for a given score (normalized)
    static func ringRadius(for score: Int) -> Double? {
        normalizedScoringRadii.first { $0.score == score }?.normalizedRadius
    }

    /// Check if a position is within the target boundary
    static func isWithinTarget(_ position: NormalizedTargetPosition) -> Bool {
        position.ellipticalDistance(aspectRatio: aspectRatio) <= 1.0
    }

    /// Check if a position is near the target boundary (for edge warnings)
    static func isNearEdge(_ position: NormalizedTargetPosition, threshold: Double = 0.95) -> Bool {
        let distance = position.ellipticalDistance(aspectRatio: aspectRatio)
        return distance > threshold && distance <= 1.0
    }
}

// MARK: - Olympic Target Geometry

/// Physical dimensions of Olympic 10m air pistol target
struct OlympicPistolTargetGeometry {

    /// Target diameter (mm)
    static let targetDiameter: Double = 155.5

    /// Scoring ring diameters (mm) - concentric circles
    static let scoringRings: [(score: Int, diameter: Double)] = [
        (10, 11.5),   // Inner 10 (also X-ring)
        (9, 27.5),
        (8, 43.5),
        (7, 59.5),
        (6, 75.5),
        (5, 91.5),
        (4, 107.5),
        (3, 123.5),
        (2, 139.5),
        (1, 155.5),   // Outer edge
    ]

    /// Standard pellet diameter (mm)
    static let pelletDiameter: Double = 4.5

    /// Target aspect ratio (always 1.0 for circular)
    static let aspectRatio: Double = 1.0

    /// Calculate score from position in millimeters from center
    static func score(atX x: Double, atY y: Double) -> Int {
        let distance = sqrt(x * x + y * y) * 2  // Convert to diameter
        for ring in scoringRings {
            if distance <= ring.diameter {
                return ring.score
            }
        }
        return 0  // Miss
    }

    /// Calculate score from normalized target position
    static func score(from position: NormalizedTargetPosition) -> Int {
        let normalizedDistance = position.radialDistance

        for (index, ring) in scoringRings.enumerated() {
            let normalizedRadius = ring.diameter / targetDiameter
            if normalizedDistance <= normalizedRadius {
                return ring.score
            }
        }
        return 0  // Miss
    }
}

// MARK: - Target Type Enum

/// Supported target types with their geometry
enum ShootingTargetGeometryType: String, Codable, CaseIterable {
    case tetrathlon
    case olympicPistol

    var displayName: String {
        switch self {
        case .tetrathlon: return "Tetrathlon (Elliptical)"
        case .olympicPistol: return "Olympic 10m Air Pistol"
        }
    }

    var aspectRatio: Double {
        switch self {
        case .tetrathlon: return TetrathlonTargetGeometry.aspectRatio
        case .olympicPistol: return OlympicPistolTargetGeometry.aspectRatio
        }
    }

    var pelletDiameterMM: Double {
        switch self {
        case .tetrathlon: return TetrathlonTargetGeometry.pelletDiameter
        case .olympicPistol: return OlympicPistolTargetGeometry.pelletDiameter
        }
    }

    var maxScore: Int {
        switch self {
        case .tetrathlon: return 10
        case .olympicPistol: return 10
        }
    }

    var validScores: [Int] {
        switch self {
        case .tetrathlon: return [0, 2, 4, 6, 8, 10]  // Even numbers only
        case .olympicPistol: return Array(0...10)
        }
    }

    /// Calculate score from normalized position
    func score(from position: NormalizedTargetPosition) -> Int {
        switch self {
        case .tetrathlon:
            return TetrathlonTargetGeometry.score(from: position)
        case .olympicPistol:
            return OlympicPistolTargetGeometry.score(from: position)
        }
    }

    /// Get normalized scoring ring radii for visualization
    var normalizedScoringRadii: [(score: Int, radius: Double)] {
        switch self {
        case .tetrathlon:
            return TetrathlonTargetGeometry.normalizedScoringRadii.map { (score: $0.score, radius: $0.normalizedRadius) }
        case .olympicPistol:
            return OlympicPistolTargetGeometry.scoringRings.map { ring in
                (ring.score, ring.diameter / OlympicPistolTargetGeometry.targetDiameter)
            }
        }
    }
}

// MARK: - Scoring Ring Model

/// Model for a scoring ring (for visualization)
struct ScoringRing: Identifiable {
    let id = UUID()
    let score: Int
    let normalizedRadius: Double
    let color: String

    static func rings(for targetType: ShootingTargetGeometryType) -> [ScoringRing] {
        let radii = targetType.normalizedScoringRadii
        return radii.map { score, radius in
            ScoringRing(
                score: score,
                normalizedRadius: radius,
                color: ringColor(for: score)
            )
        }
    }

    private static func ringColor(for score: Int) -> String {
        switch score {
        case 10: return "yellow"
        case 9, 8: return "red"
        case 7, 6: return "blue"
        case 5, 4, 3: return "black"
        case 2, 1: return "white"
        default: return "gray"
        }
    }
}

// MARK: - Distance Calculations

extension NormalizedTargetPosition {

    /// Calculate tetrathlon score from this position
    var tetrathlonScore: Int {
        TetrathlonTargetGeometry.score(from: self)
    }

    /// Calculate Olympic pistol score from this position
    var olympicScore: Int {
        OlympicPistolTargetGeometry.score(from: self)
    }

    /// Check if this position is on or near a scoring ring boundary
    func isOnScoringRing(targetType: ShootingTargetGeometryType, tolerance: Double = 0.02) -> Bool {
        let radii = targetType.normalizedScoringRadii
        let distance = ellipticalDistance(aspectRatio: targetType.aspectRatio)

        return radii.contains { _, ringRadius in
            abs(distance - ringRadius) < tolerance
        }
    }
}
