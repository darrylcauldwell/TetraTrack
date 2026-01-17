//
//  TargetGeometry.swift
//  TrackRide
//
//  Physical target specifications and scoring calculations
//  Based on UIPM tetrathlon air pistol target standards
//
//  IMPORTANT: Tetrathlon targets use "stadium" shaped rings (running track shape),
//  NOT ellipses. Each ring consists of:
//  - Two semicircles (top and bottom)
//  - Two straight vertical lines connecting them
//

import Foundation
import CoreGraphics

// MARK: - Stadium Shape Geometry

/// Represents a stadium shape (running track / discorectangle)
/// Consists of two semicircles of radius R connected by straight vertical lines of height H
struct StadiumGeometry {
    /// Radius of the semicircles at top and bottom
    let semicircleRadius: Double

    /// Height of the straight section (vertical distance between semicircle centers)
    let straightHeight: Double

    /// Total width of the stadium
    var totalWidth: Double { semicircleRadius * 2 }

    /// Total height of the stadium
    var totalHeight: Double { straightHeight + (semicircleRadius * 2) }

    /// Aspect ratio (width / height)
    var aspectRatio: Double { totalWidth / totalHeight }

    /// Y coordinate of the top semicircle center (normalized from -1 to 1)
    var topSemicircleY: Double { -straightHeight / (straightHeight + semicircleRadius * 2) }

    /// Y coordinate of the bottom semicircle center (normalized from -1 to 1)
    var bottomSemicircleY: Double { straightHeight / (straightHeight + semicircleRadius * 2) }

    /// Check if a normalized point (-1 to 1) is inside this stadium
    /// - Parameter point: Normalized point where -1 to 1 spans the full stadium
    /// - Returns: True if point is inside the stadium
    func contains(normalizedPoint point: CGPoint) -> Bool {
        return signedDistance(to: point) <= 0
    }

    /// Calculate the signed distance from a point to the stadium boundary
    /// Negative = inside, Positive = outside, Zero = on boundary
    /// - Parameter point: Normalized point
    /// - Returns: Signed distance (negative inside, positive outside)
    func signedDistance(to point: CGPoint) -> Double {
        // Convert normalized point to stadium-local coordinates
        // X: -1 to 1 maps to -totalWidth/2 to totalWidth/2
        // Y: -1 to 1 maps to -totalHeight/2 to totalHeight/2
        let localX = point.x * (totalWidth / 2)
        let localY = point.y * (totalHeight / 2)

        let halfStraight = straightHeight / 2

        // Determine which region the point is in
        if localY < -halfStraight {
            // In top semicircle region
            let semicircleCenter = CGPoint(x: 0, y: -halfStraight)
            let dx = localX - semicircleCenter.x
            let dy = localY - semicircleCenter.y
            let distanceToCenter = sqrt(dx * dx + dy * dy)
            return distanceToCenter - semicircleRadius
        } else if localY > halfStraight {
            // In bottom semicircle region
            let semicircleCenter = CGPoint(x: 0, y: halfStraight)
            let dx = localX - semicircleCenter.x
            let dy = localY - semicircleCenter.y
            let distanceToCenter = sqrt(dx * dx + dy * dy)
            return distanceToCenter - semicircleRadius
        } else {
            // In straight section - horizontal distance to side boundary
            return abs(localX) - semicircleRadius
        }
    }

    /// Calculate distance from point to stadium boundary (always positive)
    /// Returns 0 if exactly on boundary, positive value if inside or outside
    func distanceToBoundary(from point: CGPoint) -> Double {
        return abs(signedDistance(to: point))
    }

    /// Calculate normalized distance (0 = center, 1 = boundary)
    /// Uses the signed distance scaled appropriately
    func normalizedDistance(from point: CGPoint) -> Double {
        // For a stadium, we need to compute distance relative to center
        // The center is at (0, 0) in normalized coordinates

        let localX = point.x * (totalWidth / 2)
        let localY = point.y * (totalHeight / 2)

        let halfStraight = straightHeight / 2

        // Calculate distance from center to the boundary in the direction of the point
        // This gives us the "effective radius" in that direction

        if abs(localY) <= halfStraight {
            // Point is in the straight section
            // Distance to boundary is horizontal: semicircleRadius - abs(localX)
            // Normalized distance is abs(localX) / semicircleRadius
            return abs(localX) / semicircleRadius
        } else {
            // Point is in semicircle region
            let semicircleCenterY = localY < 0 ? -halfStraight : halfStraight
            let dx = localX
            let dy = localY - semicircleCenterY
            let distanceFromSemicircleCenter = sqrt(dx * dx + dy * dy)
            return distanceFromSemicircleCenter / semicircleRadius
        }
    }
}

// MARK: - Tetrathlon Target Geometry (Stadium-based)

/// Physical dimensions of tetrathlon air pistol target
/// Based on UIPM specifications with STADIUM (running track) shaped rings
struct TetrathlonTargetGeometry {

    // MARK: - Physical Dimensions

    /// Total target card dimensions (mm)
    static let cardWidth: Double = 170
    static let cardHeight: Double = 170

    /// Aspect ratio of the scoring area (width / height)
    /// Tetrathlon targets are taller than wide
    static let aspectRatio: Double = 0.77

    /// The ratio of straight section height to semicircle radius
    /// This determines the "stadium-ness" of the shape
    /// Higher value = more elongated, lower value = more circular
    static let straightToRadiusRatio: Double = 0.6

    // MARK: - Scoring Ring Boundaries (CALIBRATED)

    /// Normalized scoring ring boundaries as fraction of the outer target boundary
    /// These values are CALIBRATED to match real paper targets
    ///
    /// CRITICAL: The 10 ring must be sized correctly so that visually central
    /// shots are classified as 10, not 8.
    ///
    /// Format: (score, normalizedBoundary)
    /// where normalizedBoundary is the fraction of distance from center to outer edge
    static let normalizedScoringRadii: [(score: Int, normalizedRadius: Double)] = [
        (10, 0.12),    // 12% - 10 ring (innermost, "bull")
        (8, 0.35),     // 35% - 8 ring
        (6, 0.55),     // 55% - 6 ring
        (4, 0.75),     // 75% - 4 ring
        (2, 1.0),      // 100% - 2 ring (outer edge)
    ]

    /// Standard air pistol pellet diameter (mm)
    static let pelletDiameter: Double = 4.5

    /// Pellet radius as fraction of target radius
    static let normalizedPelletRadius: Double = 0.035

    // MARK: - Stadium Geometry for Each Ring

    /// Get the stadium geometry for a specific scoring ring
    /// - Parameter normalizedRadius: The normalized radius (0-1) of the ring boundary
    /// - Returns: StadiumGeometry for that ring
    static func stadiumGeometry(forNormalizedRadius normalizedRadius: Double) -> StadiumGeometry {
        // Base dimensions for the outer ring (normalizedRadius = 1.0)
        // The outer ring defines our coordinate system
        let outerSemicircleRadius = 1.0 / (1.0 + straightToRadiusRatio)
        let outerStraightHeight = outerSemicircleRadius * straightToRadiusRatio * 2

        // Scale down for inner rings
        return StadiumGeometry(
            semicircleRadius: outerSemicircleRadius * normalizedRadius,
            straightHeight: outerStraightHeight * normalizedRadius
        )
    }

    /// The outer stadium geometry (score = 2 ring)
    static let outerStadium: StadiumGeometry = stadiumGeometry(forNormalizedRadius: 1.0)

    // MARK: - Score Calculation (Stadium-based)

    /// Calculate score from normalized target position using STADIUM geometry
    /// Uses distance to nearest boundary point, not center distance
    static func score(from position: NormalizedTargetPosition) -> Int {
        let point = CGPoint(x: position.x, y: position.y)

        // Check each ring from innermost to outermost
        for (score, normalizedRadius) in normalizedScoringRadii {
            let stadium = stadiumGeometry(forNormalizedRadius: normalizedRadius)

            // Use normalized distance which accounts for stadium shape
            let normalizedDist = stadium.normalizedDistance(from: point)

            // If point is within this ring's boundary (distance <= 1.0 relative to ring)
            if normalizedDist <= 1.0 {
                return score
            }
        }

        return 0  // Miss - outside all rings
    }

    /// Calculate score with pellet edge consideration using stadium geometry
    /// Uses the "inside edge" rule - pellet must break the line
    static func scoreWithPelletEdge(
        from position: NormalizedTargetPosition,
        pelletRadiusNormalized: Double = normalizedPelletRadius
    ) -> Int {
        let point = CGPoint(x: position.x, y: position.y)

        // Check each ring from innermost to outermost
        for (score, normalizedRadius) in normalizedScoringRadii {
            let stadium = stadiumGeometry(forNormalizedRadius: normalizedRadius)

            // Get signed distance (negative = inside, positive = outside)
            let signedDist = stadium.signedDistance(to: point)

            // Pellet touches line if center is within pelletRadius of boundary
            // signedDist + pelletRadius <= 0 means pellet edge is inside
            if signedDist - pelletRadiusNormalized <= 0 {
                return score
            }
        }

        return 0  // Miss
    }

    /// Get the normalized stadium distance for a position
    /// Returns the distance as a fraction of the outer boundary (0 = center, 1 = outer edge)
    static func normalizedStadiumDistance(from position: NormalizedTargetPosition) -> Double {
        let point = CGPoint(x: position.x, y: position.y)
        return outerStadium.normalizedDistance(from: point)
    }

    /// Get the scoring ring radius for a given score (normalized)
    static func ringRadius(for score: Int) -> Double? {
        normalizedScoringRadii.first { $0.score == score }?.normalizedRadius
    }

    /// Check if a position is within the target boundary using stadium geometry
    static func isWithinTarget(_ position: NormalizedTargetPosition) -> Bool {
        let point = CGPoint(x: position.x, y: position.y)
        return outerStadium.contains(normalizedPoint: point)
    }

    /// Check if a position is near the target boundary (for edge warnings)
    static func isNearEdge(_ position: NormalizedTargetPosition, threshold: Double = 0.95) -> Bool {
        let distance = normalizedStadiumDistance(from: position)
        return distance > threshold && distance <= 1.0
    }

    // MARK: - Stadium Path Generation (for SwiftUI drawing)

    /// Generate a SwiftUI Path for a stadium ring at the given normalized radius
    /// - Parameters:
    ///   - normalizedRadius: Ring boundary as fraction of outer target (0-1)
    ///   - center: Center point in screen coordinates
    ///   - maxRadius: Maximum radius in screen coordinates (half the smaller dimension)
    /// - Returns: A Path representing the stadium shape
    static func stadiumPath(
        forNormalizedRadius normalizedRadius: Double,
        center: CGPoint,
        maxRadius: CGFloat
    ) -> (path: CGPath, width: CGFloat, height: CGFloat) {
        // Calculate the actual screen dimensions for this ring
        let stadium = stadiumGeometry(forNormalizedRadius: normalizedRadius)

        // Screen dimensions
        let screenWidth = CGFloat(stadium.totalWidth) * maxRadius
        let screenHeight = CGFloat(stadium.totalHeight) * maxRadius
        let screenSemicircleRadius = CGFloat(stadium.semicircleRadius) * maxRadius
        let screenHalfStraight = CGFloat(stadium.straightHeight) / 2 * maxRadius

        // Create the path
        let path = CGMutablePath()

        // Start at top-left of straight section
        let topLeftX = center.x - screenSemicircleRadius
        let topLeftY = center.y - screenHalfStraight

        path.move(to: CGPoint(x: topLeftX, y: topLeftY))

        // Top semicircle (going clockwise from left to right)
        path.addArc(
            center: CGPoint(x: center.x, y: center.y - screenHalfStraight),
            radius: screenSemicircleRadius,
            startAngle: .pi,
            endAngle: 0,
            clockwise: false
        )

        // Right straight section (going down)
        path.addLine(to: CGPoint(x: center.x + screenSemicircleRadius, y: center.y + screenHalfStraight))

        // Bottom semicircle (going clockwise from right to left)
        path.addArc(
            center: CGPoint(x: center.x, y: center.y + screenHalfStraight),
            radius: screenSemicircleRadius,
            startAngle: 0,
            endAngle: .pi,
            clockwise: false
        )

        // Left straight section (going up) - closes the path
        path.closeSubpath()

        return (path, screenWidth, screenHeight)
    }
}

// MARK: - Olympic Target Geometry (Circular - unchanged)

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

        for ring in scoringRings {
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
        case .tetrathlon: return "Tetrathlon (Stadium)"
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

    /// Calculate tetrathlon score from this position using stadium geometry
    var tetrathlonScore: Int {
        TetrathlonTargetGeometry.score(from: self)
    }

    /// Calculate Olympic pistol score from this position
    var olympicScore: Int {
        OlympicPistolTargetGeometry.score(from: self)
    }

    /// Get the stadium-based normalized distance (for Tetrathlon targets)
    var stadiumNormalizedDistance: Double {
        TetrathlonTargetGeometry.normalizedStadiumDistance(from: self)
    }

    /// Check if this position is on or near a scoring ring boundary
    func isOnScoringRing(targetType: ShootingTargetGeometryType, tolerance: Double = 0.02) -> Bool {
        let radii = targetType.normalizedScoringRadii

        switch targetType {
        case .tetrathlon:
            let stadiumDist = stadiumNormalizedDistance
            return radii.contains { _, ringRadius in
                abs(stadiumDist - ringRadius) < tolerance
            }
        case .olympicPistol:
            let distance = radialDistance
            return radii.contains { _, ringRadius in
                abs(distance - ringRadius) < tolerance
            }
        }
    }
}

// MARK: - Developer Validation Support

extension TetrathlonTargetGeometry {

    /// Validate that ring classification matches visual expectation
    /// Returns true if 75%+ of shots in the visual bull classify as 10
    static func validateBullClassification(shots: [CGPoint]) -> Bool {
        guard !shots.isEmpty else { return true }

        let tenRingRadius = normalizedScoringRadii.first { $0.score == 10 }?.normalizedRadius ?? 0.12

        // Count shots that are visually in the bull (using raw distance heuristic)
        // and check if they're classified correctly
        var visualBullShots = 0
        var correctlyClassified = 0

        for shot in shots {
            let rawDistance = sqrt(shot.x * shot.x + shot.y * shot.y)

            // Visual bull check (rough estimate based on typical target appearance)
            let isVisuallyInBull = rawDistance < tenRingRadius * 1.1  // Small buffer

            if isVisuallyInBull {
                visualBullShots += 1

                let position = NormalizedTargetPosition(x: shot.x, y: shot.y)
                let classifiedScore = score(from: position)

                if classifiedScore == 10 {
                    correctlyClassified += 1
                }
            }
        }

        guard visualBullShots > 0 else { return true }

        let accuracy = Double(correctlyClassified) / Double(visualBullShots)
        return accuracy >= 0.75
    }

    /// Debug helper: Get detailed classification info for a shot
    static func debugClassification(for position: NormalizedTargetPosition) -> String {
        let point = CGPoint(x: position.x, y: position.y)
        let score = score(from: position)
        let stadiumDist = normalizedStadiumDistance(from: position)

        var info = "Position: (\(String(format: "%.3f", position.x)), \(String(format: "%.3f", position.y)))\n"
        info += "Stadium Distance: \(String(format: "%.3f", stadiumDist))\n"
        info += "Classified Score: \(score)\n"
        info += "Ring Boundaries:\n"

        for (ringScore, radius) in normalizedScoringRadii {
            let stadium = stadiumGeometry(forNormalizedRadius: radius)
            let dist = stadium.normalizedDistance(from: point)
            info += "  \(ringScore) ring (r=\(String(format: "%.3f", radius))): dist=\(String(format: "%.3f", dist))"
            if dist <= 1.0 {
                info += " ✓"
            }
            info += "\n"
        }

        return info
    }
}
