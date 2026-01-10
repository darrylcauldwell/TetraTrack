//
//  ShootingSession.swift
//  TrackRide
//
//  Shooting discipline - competition cards, scoring, and analysis
//

import Foundation
import SwiftData

// MARK: - Shooting Session

@Model
final class ShootingSession: TrainingSessionProtocol {
    var id: UUID = UUID()
    var startDate: Date = Date()
    var endDate: Date?
    var name: String = ""
    var notes: String = ""

    // Target configuration
    var targetTypeRaw: String = "olympic"
    var distance: Double = 10.0 // meters
    var numberOfEnds: Int = 6
    var arrowsPerEnd: Int = 6

    // Weather conditions
    var temperature: Double? // Celsius
    var humidity: Double? // Percentage
    var windSpeed: Double? // m/s
    var windDirectionRaw: String?

    // Equipment
    var equipmentNotes: String = ""
    var bowType: String = ""
    var arrowType: String = ""

    // Location
    var locationName: String = ""
    var latitude: Double?
    var longitude: Double?

    // Results
    @Relationship(deleteRule: .cascade, inverse: \ShootingEnd.session)
    var ends: [ShootingEnd] = []

    var targetType: ShootingTargetType {
        get { ShootingTargetType(rawValue: targetTypeRaw) ?? .olympic }
        set { targetTypeRaw = newValue.rawValue }
    }

    var windDirection: WindDirection? {
        get {
            guard let raw = windDirectionRaw else { return nil }
            return WindDirection(rawValue: raw)
        }
        set { windDirectionRaw = newValue?.rawValue }
    }

    init() {}

    init(
        name: String = "",
        targetType: ShootingTargetType = .olympic,
        distance: Double = 10.0,
        numberOfEnds: Int = 6,
        arrowsPerEnd: Int = 6
    ) {
        self.name = name
        self.targetTypeRaw = targetType.rawValue
        self.distance = distance
        self.numberOfEnds = numberOfEnds
        self.arrowsPerEnd = arrowsPerEnd
    }

    // MARK: - Protocol Conformance

    /// Shooting doesn't track distance traveled - returns 0
    var totalDistance: Double { 0 }

    /// Total duration calculated from start/end dates
    var totalDuration: TimeInterval {
        guard let end = endDate else {
            return Date().timeIntervalSince(startDate)
        }
        return end.timeIntervalSince(startDate)
    }

    // MARK: - Computed Properties

    var totalScore: Int {
        ends.reduce(0) { $0 + $1.totalScore }
    }

    var maxPossibleScore: Int {
        targetType.maxScore * numberOfEnds * arrowsPerEnd
    }

    var scorePercentage: Double {
        guard maxPossibleScore > 0 else { return 0 }
        return Double(totalScore) / Double(maxPossibleScore) * 100
    }

    var averageScorePerArrow: Double {
        let totalArrows = ends.flatMap { $0.shots }.count
        guard totalArrows > 0 else { return 0 }
        return Double(totalScore) / Double(totalArrows)
    }

    var averageScorePerEnd: Double {
        guard !ends.isEmpty else { return 0 }
        return Double(totalScore) / Double(ends.count)
    }

    var xCount: Int {
        ends.flatMap { $0.shots }.filter { $0.isX }.count
    }

    var tensCount: Int {
        ends.flatMap { $0.shots }.filter { $0.score == 10 }.count
    }

    var sortedEnds: [ShootingEnd] {
        ends.sorted { $0.orderIndex < $1.orderIndex }
    }

    var formattedDistance: String {
        distance.formattedDistance
    }

    var formattedDuration: String {
        guard let end = endDate else { return "In Progress" }
        let duration = end.timeIntervalSince(startDate)
        return duration.formattedDuration
    }

    var formattedDate: String {
        Formatters.dateTime(startDate)
    }
}

// MARK: - Shooting End

@Model
final class ShootingEnd {
    var id: UUID = UUID()
    var orderIndex: Int = 0
    var startTime: Date = Date()
    var endTime: Date?
    var notes: String = ""

    // Relationship
    var session: ShootingSession?

    @Relationship(deleteRule: .cascade, inverse: \Shot.end)
    var shots: [Shot] = []

    init() {}

    init(orderIndex: Int = 0) {
        self.orderIndex = orderIndex
    }

    var totalScore: Int {
        shots.reduce(0) { $0 + $1.score }
    }

    var sortedShots: [Shot] {
        shots.sorted { $0.orderIndex < $1.orderIndex }
    }

    var xCount: Int {
        shots.filter { $0.isX }.count
    }

    var formattedScores: String {
        sortedShots.map { $0.displayValue }.joined(separator: "-")
    }
}

// MARK: - Shot

@Model
final class Shot {
    var id: UUID = UUID()
    var orderIndex: Int = 0
    var score: Int = 0
    var isX: Bool = false
    var timestamp: Date = Date()

    // Position on target (normalized 0-1 from center)
    var positionX: Double?
    var positionY: Double?

    // Video reference
    var videoAssetIdentifier: String?

    // Relationship
    var end: ShootingEnd?

    init() {}

    init(orderIndex: Int = 0, score: Int = 0, isX: Bool = false) {
        self.orderIndex = orderIndex
        self.score = score
        self.isX = isX
    }

    var displayValue: String {
        if isX { return "X" }
        if score == 10 { return "10" }
        if score == 0 { return "M" } // Miss
        return "\(score)"
    }

    var ringColor: String {
        switch score {
        case 10: return "yellow" // X-ring/10-ring (gold)
        case 9: return "yellow" // 9-ring (gold)
        case 8, 7: return "red"
        case 6, 5: return "blue"
        case 4, 3: return "black"
        case 2, 1: return "white"
        default: return "gray" // Miss
        }
    }
}

// MARK: - Target Types

enum ShootingTargetType: String, Codable, CaseIterable {
    case olympic = "Olympic (10-ring)"
    case field = "Field Target"
    case compound = "Compound"
    case barebow = "Barebow"
    case nfaa = "NFAA 5-spot"

    var maxScore: Int {
        switch self {
        case .olympic, .compound, .barebow: return 10
        case .field: return 6
        case .nfaa: return 5
        }
    }

    var rings: [Int] {
        switch self {
        case .olympic, .compound, .barebow:
            return Array(1...10)
        case .field:
            return Array(1...6)
        case .nfaa:
            return Array(1...5)
        }
    }

    var hasXRing: Bool {
        switch self {
        case .olympic, .compound, .barebow: return true
        case .field, .nfaa: return false
        }
    }

    var icon: String {
        return "target"
    }
}

// MARK: - Wind Direction

enum WindDirection: String, Codable, CaseIterable {
    case north = "N"
    case northEast = "NE"
    case east = "E"
    case southEast = "SE"
    case south = "S"
    case southWest = "SW"
    case west = "W"
    case northWest = "NW"

    var degrees: Double {
        switch self {
        case .north: return 0
        case .northEast: return 45
        case .east: return 90
        case .southEast: return 135
        case .south: return 180
        case .southWest: return 225
        case .west: return 270
        case .northWest: return 315
        }
    }

    var arrow: String {
        switch self {
        case .north: return "arrow.up"
        case .northEast: return "arrow.up.right"
        case .east: return "arrow.right"
        case .southEast: return "arrow.down.right"
        case .south: return "arrow.down"
        case .southWest: return "arrow.down.left"
        case .west: return "arrow.left"
        case .northWest: return "arrow.up.left"
        }
    }
}

// MARK: - Scoring Calculator

struct ShootingScoreCalculator {
    let targetType: ShootingTargetType

    /// Calculate ring/zone from position on target
    /// Position is normalized (-1 to 1) from center
    func scoreFromPosition(x: Double, y: Double) -> (score: Int, isX: Bool) {
        let distance = sqrt(x * x + y * y)

        switch targetType {
        case .olympic, .compound, .barebow:
            // 10 rings, X-ring is innermost
            if distance <= 0.05 { return (10, true) } // X
            if distance <= 0.1 { return (10, false) }
            if distance <= 0.2 { return (9, false) }
            if distance <= 0.3 { return (8, false) }
            if distance <= 0.4 { return (7, false) }
            if distance <= 0.5 { return (6, false) }
            if distance <= 0.6 { return (5, false) }
            if distance <= 0.7 { return (4, false) }
            if distance <= 0.8 { return (3, false) }
            if distance <= 0.9 { return (2, false) }
            if distance <= 1.0 { return (1, false) }
            return (0, false) // Miss

        case .field:
            if distance <= 0.15 { return (6, false) }
            if distance <= 0.35 { return (5, false) }
            if distance <= 0.55 { return (4, false) }
            if distance <= 0.75 { return (3, false) }
            if distance <= 0.9 { return (2, false) }
            if distance <= 1.0 { return (1, false) }
            return (0, false)

        case .nfaa:
            if distance <= 0.2 { return (5, false) }
            if distance <= 0.4 { return (4, false) }
            if distance <= 0.6 { return (3, false) }
            if distance <= 0.8 { return (2, false) }
            if distance <= 1.0 { return (1, false) }
            return (0, false)
        }
    }

    /// Get score breakdown
    static func breakdown(for session: ShootingSession) -> ScoreBreakdown {
        let allShots = session.ends.flatMap { $0.shots }

        var distribution: [Int: Int] = [:]
        for score in 0...session.targetType.maxScore {
            distribution[score] = allShots.filter { $0.score == score }.count
        }

        return ScoreBreakdown(
            totalScore: session.totalScore,
            maxPossible: session.maxPossibleScore,
            xCount: session.xCount,
            tensCount: session.tensCount,
            distribution: distribution,
            averagePerArrow: session.averageScorePerArrow,
            averagePerEnd: session.averageScorePerEnd
        )
    }
}

struct ScoreBreakdown {
    let totalScore: Int
    let maxPossible: Int
    let xCount: Int
    let tensCount: Int
    let distribution: [Int: Int]
    let averagePerArrow: Double
    let averagePerEnd: Double

    var percentage: Double {
        guard maxPossible > 0 else { return 0 }
        return Double(totalScore) / Double(maxPossible) * 100
    }
}

// MARK: - Target Scan Analysis (for historical pattern tracking)

@Model
final class TargetScanAnalysis {
    var id: UUID = UUID()
    var scanDate: Date = Date()
    var notes: String = ""

    // Total score and shot count
    var totalScore: Int = 0
    var shotCount: Int = 0

    // Pattern metrics (for trend analysis)
    var averageX: Double = 0.5        // Average X position (0.5 = centered)
    var averageY: Double = 0.5        // Average Y position (0.5 = centered)
    var spreadX: Double = 0           // X spread (standard deviation)
    var spreadY: Double = 0           // Y spread (standard deviation)
    var totalSpread: Double = 0       // Combined spread

    // Bias from center (positive = right/low, negative = left/high)
    var horizontalBias: Double = 0
    var verticalBias: Double = 0

    // Shot positions stored as JSON for flexibility
    var shotPositionsJSON: Data?

    // Image reference (optional - stored in app documents)
    var imageFileName: String?

    // Grouping quality (computed during save)
    var groupingQualityRaw: String = "fair"

    init() {}

    // Computed properties
    var groupingQuality: GroupingQuality {
        get { GroupingQuality(rawValue: groupingQualityRaw) ?? .fair }
        set { groupingQualityRaw = newValue.rawValue }
    }

    var shotPositions: [ScanShot] {
        get {
            guard let data = shotPositionsJSON else { return [] }
            return (try? JSONDecoder().decode([ScanShot].self, from: data)) ?? []
        }
        set {
            shotPositionsJSON = try? JSONEncoder().encode(newValue)
        }
    }

    var averageScore: Double {
        guard shotCount > 0 else { return 0 }
        return Double(totalScore) / Double(shotCount)
    }

    var formattedDate: String {
        Formatters.dateTime(scanDate)
    }

    var biasDescription: String {
        var parts: [String] = []

        if abs(horizontalBias) > 0.08 {
            parts.append(horizontalBias > 0 ? "Right" : "Left")
        }
        if abs(verticalBias) > 0.08 {
            parts.append(verticalBias > 0 ? "Low" : "High")
        }

        return parts.isEmpty ? "Centered" : parts.joined(separator: " & ")
    }

    // Calculate metrics from shots
    func calculateMetrics(from shots: [ScanShot], targetCenter: CGPoint) {
        shotCount = shots.count
        totalScore = shots.reduce(0) { $0 + $1.score }

        guard !shots.isEmpty else { return }

        // Average position
        averageX = shots.map { $0.positionX }.reduce(0, +) / Double(shots.count)
        averageY = shots.map { $0.positionY }.reduce(0, +) / Double(shots.count)

        // Spread (standard deviation)
        spreadX = sqrt(shots.map { pow($0.positionX - averageX, 2) }.reduce(0, +) / Double(shots.count))
        spreadY = sqrt(shots.map { pow($0.positionY - averageY, 2) }.reduce(0, +) / Double(shots.count))
        totalSpread = sqrt(spreadX * spreadX + spreadY * spreadY)

        // Bias from target center
        horizontalBias = averageX - targetCenter.x
        verticalBias = averageY - targetCenter.y

        // Determine grouping quality
        if totalSpread < 0.05 {
            groupingQuality = .excellent
        } else if totalSpread < 0.10 {
            groupingQuality = .good
        } else if totalSpread < 0.15 {
            groupingQuality = .fair
        } else {
            groupingQuality = .poor
        }
    }
}

// MARK: - Scan Shot (for JSON storage)

struct ScanShot: Codable, Identifiable {
    var id: UUID = UUID()
    var positionX: Double
    var positionY: Double
    var score: Int
    var confidence: Double

    init(positionX: Double, positionY: Double, score: Int, confidence: Double = 1.0) {
        self.positionX = positionX
        self.positionY = positionY
        self.score = score
        self.confidence = confidence
    }
}

// MARK: - Grouping Quality

enum GroupingQuality: String, Codable, CaseIterable {
    case excellent
    case good
    case fair
    case poor

    var displayText: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Needs Work"
        }
    }

    var icon: String {
        switch self {
        case .excellent: return "star.fill"
        case .good: return "checkmark.circle.fill"
        case .fair: return "circle.fill"
        case .poor: return "exclamationmark.triangle.fill"
        }
    }

    var color: String {
        switch self {
        case .excellent: return "yellow"
        case .good: return "green"
        case .fair: return "orange"
        case .poor: return "red"
        }
    }
}
