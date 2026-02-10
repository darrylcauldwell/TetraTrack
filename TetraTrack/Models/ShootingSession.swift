//
//  ShootingSession.swift
//  TetraTrack
//
//  Shooting discipline - competition cards, scoring, and analysis
//

import Foundation
import SwiftData

// MARK: - Shooting Session Context

/// Session context for tracking pressure effects on performance
enum ShootingSessionContext: String, Codable, CaseIterable {
    case freePractice = "Free Practice"
    case competitionTraining = "Competition Training"
    case competition = "Competition"

    /// Pressure level for analysis (higher = more pressure)
    var pressureLevel: Int {
        switch self {
        case .freePractice: return 1
        case .competitionTraining: return 2
        case .competition: return 3
        }
    }

    var icon: String {
        switch self {
        case .freePractice: return "target"
        case .competitionTraining: return "figure.run"
        case .competition: return "trophy.fill"
        }
    }

    var color: String {
        switch self {
        case .freePractice: return "blue"
        case .competitionTraining: return "orange"
        case .competition: return "purple"
        }
    }

    var displayName: String {
        switch self {
        case .freePractice: return "Free Practice"
        case .competitionTraining: return "Tetrathlon Practice"
        case .competition: return "Competition"
        }
    }

    var description: String {
        switch self {
        case .freePractice: return "Relaxed practice with no scoring pressure"
        case .competitionTraining: return "Practice under simulated competition conditions"
        case .competition: return "Actual competition scoring"
        }
    }

    /// Maps to ShootingSessionType for shot pattern storage
    var patternSessionType: ShootingSessionType {
        switch self {
        case .freePractice: return .freePractice
        case .competitionTraining: return .competitionTraining
        case .competition: return .competition
        }
    }
}

// MARK: - Shooting Session

@Model
final class ShootingSession: TrainingSessionProtocol {
    var id: UUID = UUID()
    var startDate: Date = Date()
    var endDate: Date?
    var name: String = ""
    var notes: String = ""

    // Session context for pressure analysis
    var sessionContextRaw: String = "Free Practice"

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

    // Sensor data from Watch (stance tracking)
    var averageStanceStability: Double = 0  // 0-100
    var averageTremorLevel: Double = 0  // 0-100
    var stanceSamplesData: Data?  // Encoded timeseries of stance samples

    // Location
    var locationName: String = ""
    var latitude: Double?
    var longitude: Double?

    // Results
    @Relationship(deleteRule: .cascade, inverse: \ShootingEnd.session)
    var ends: [ShootingEnd]? = []

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

    var sessionContext: ShootingSessionContext {
        get { ShootingSessionContext(rawValue: sessionContextRaw) ?? .freePractice }
        set { sessionContextRaw = newValue.rawValue }
    }

    init() {}

    init(
        name: String = "",
        targetType: ShootingTargetType = .olympic,
        distance: Double = 10.0,
        numberOfEnds: Int = 6,
        arrowsPerEnd: Int = 6,
        sessionContext: ShootingSessionContext = .freePractice
    ) {
        self.name = name
        self.targetTypeRaw = targetType.rawValue
        self.distance = distance
        self.numberOfEnds = numberOfEnds
        self.arrowsPerEnd = arrowsPerEnd
        self.sessionContextRaw = sessionContext.rawValue
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
        (ends ?? []).reduce(0) { $0 + $1.totalScore }
    }

    var maxPossibleScore: Int {
        targetType.maxScore * numberOfEnds * arrowsPerEnd
    }

    var scorePercentage: Double {
        guard maxPossibleScore > 0 else { return 0 }
        return Double(totalScore) / Double(maxPossibleScore) * 100
    }

    var averageScorePerArrow: Double {
        let totalArrows = (ends ?? []).flatMap { $0.shots ?? [] }.count
        guard totalArrows > 0 else { return 0 }
        return Double(totalScore) / Double(totalArrows)
    }

    var averageScorePerEnd: Double {
        guard !(ends ?? []).isEmpty else { return 0 }
        return Double(totalScore) / Double((ends ?? []).count)
    }

    var xCount: Int {
        (ends ?? []).flatMap { $0.shots ?? [] }.filter { $0.isX }.count
    }

    var tensCount: Int {
        (ends ?? []).flatMap { $0.shots ?? [] }.filter { $0.score == 10 }.count
    }

    var sortedEnds: [ShootingEnd] {
        (ends ?? []).sorted { $0.orderIndex < $1.orderIndex }
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

    // Optional link to scanned target for hole positions
    var targetScanAnalysisID: UUID?

    // Relationship
    var session: ShootingSession?

    @Relationship(deleteRule: .cascade, inverse: \Shot.end)
    var shots: [Shot]? = []

    init() {}

    init(orderIndex: Int = 0) {
        self.orderIndex = orderIndex
    }

    var totalScore: Int {
        (shots ?? []).reduce(0) { $0 + $1.score }
    }

    var sortedShots: [Shot] {
        (shots ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    var xCount: Int {
        (shots ?? []).filter { $0.isX }.count
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
        let allShots = (session.ends ?? []).flatMap { $0.shots ?? [] }

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

    // Enhanced fields (v2)
    // Crop geometry stored as JSON
    var cropGeometryJSON: Data?

    // Target alignment stored as JSON
    var targetAlignmentJSON: Data?

    // Acquisition quality stored as JSON
    var acquisitionQualityJSON: Data?

    // Pattern analysis stored as JSON
    var patternAnalysisJSON: Data?

    // Target type
    var targetTypeGeometryRaw: String?

    // Algorithm and coordinate system versioning
    var algorithmVersion: Int = 1
    var coordinateSystemVersion: Int = 1

    // Detection statistics
    var autoDetectedCount: Int = 0
    var userConfirmedCount: Int = 0
    var userAddedCount: Int = 0

    // Validation flags
    var hasValidationWarnings: Bool = false
    var validationWarningsJSON: Data?

    init() {}

    // MARK: - Computed Properties

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

    var cropGeometry: TargetCropGeometry? {
        get {
            guard let data = cropGeometryJSON else { return nil }
            return try? JSONDecoder().decode(TargetCropGeometry.self, from: data)
        }
        set {
            cropGeometryJSON = try? JSONEncoder().encode(newValue)
        }
    }

    var targetAlignment: TargetAlignment? {
        get {
            guard let data = targetAlignmentJSON else { return nil }
            return try? JSONDecoder().decode(TargetAlignment.self, from: data)
        }
        set {
            targetAlignmentJSON = try? JSONEncoder().encode(newValue)
        }
    }

    var acquisitionQuality: AcquisitionQuality? {
        get {
            guard let data = acquisitionQualityJSON else { return nil }
            return try? JSONDecoder().decode(AcquisitionQuality.self, from: data)
        }
        set {
            acquisitionQualityJSON = try? JSONEncoder().encode(newValue)
        }
    }

    var patternAnalysis: PatternAnalysis? {
        get {
            guard let data = patternAnalysisJSON else { return nil }
            return try? JSONDecoder().decode(PatternAnalysis.self, from: data)
        }
        set {
            patternAnalysisJSON = try? JSONEncoder().encode(newValue)
        }
    }

    var targetGeometryType: ShootingTargetGeometryType? {
        get {
            guard let raw = targetTypeGeometryRaw else { return nil }
            return ShootingTargetGeometryType(rawValue: raw)
        }
        set {
            targetTypeGeometryRaw = newValue?.rawValue
        }
    }

    var validationWarnings: [ValidationWarning] {
        get {
            guard let data = validationWarningsJSON else { return [] }
            return (try? JSONDecoder().decode([CodableValidationWarning].self, from: data))?
                .map { $0.toWarning() } ?? []
        }
        set {
            let codable = newValue.map { CodableValidationWarning(from: $0) }
            validationWarningsJSON = try? JSONEncoder().encode(codable)
            hasValidationWarnings = !newValue.isEmpty
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
        // Use pattern analysis if available
        if let analysis = patternAnalysis, analysis.directionalBias.isSignificant {
            return analysis.directionalBias.description ?? "Centered"
        }

        // Fall back to legacy calculation
        var parts: [String] = []

        if abs(horizontalBias) > 0.08 {
            parts.append(horizontalBias > 0 ? "Right" : "Left")
        }
        if abs(verticalBias) > 0.08 {
            parts.append(verticalBias > 0 ? "Low" : "High")
        }

        return parts.isEmpty ? "Centered" : parts.joined(separator: " & ")
    }

    /// Whether this scan needs re-analysis due to algorithm updates
    var needsReanalysis: Bool {
        algorithmVersion < PatternAnalysis.currentAlgorithmVersion
    }

    /// Whether this scan uses the new coordinate system
    var usesNewCoordinateSystem: Bool {
        coordinateSystemVersion >= CoordinateSystemVersion.current.major &&
        cropGeometry != nil
    }

    /// Detection method breakdown for display
    var detectionBreakdown: String {
        if shotCount == 0 { return "No shots" }

        var parts: [String] = []
        if autoDetectedCount > 0 {
            parts.append("\(autoDetectedCount) auto")
        }
        if userAddedCount > 0 {
            parts.append("\(userAddedCount) manual")
        }
        if userConfirmedCount > 0 && userConfirmedCount < shotCount {
            parts.append("\(userConfirmedCount) confirmed")
        }

        return parts.isEmpty ? "\(shotCount) shots" : parts.joined(separator: ", ")
    }

    // MARK: - Methods

    /// Calculate metrics from shots (legacy method, still supported)
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

        // Update detection counts
        updateDetectionCounts(from: shots)
    }

    /// Enhanced metrics calculation using new coordinate system
    func calculateEnhancedMetrics(
        from shots: [ScanShot],
        cropGeometry: TargetCropGeometry,
        targetType: ShootingTargetGeometryType
    ) {
        self.shotPositions = shots
        self.cropGeometry = cropGeometry
        self.targetGeometryType = targetType
        self.coordinateSystemVersion = CoordinateSystemVersion.current.major
        self.algorithmVersion = PatternAnalysis.currentAlgorithmVersion

        shotCount = shots.count
        totalScore = shots.reduce(0) { $0 + $1.score }

        guard !shots.isEmpty else { return }

        // Use PatternAnalyzer for comprehensive analysis
        if let analysis = PatternAnalyzer.analyze(shots: shots) {
            self.patternAnalysis = analysis

            // Update legacy fields from pattern analysis for backward compatibility
            averageX = (analysis.mpi.x + 1.0) / 2.0
            averageY = (1.0 - analysis.mpi.y) / 2.0
            totalSpread = analysis.standardDeviation
            spreadX = analysis.standardDeviation * 0.7  // Approximate
            spreadY = analysis.standardDeviation * 0.7
            horizontalBias = analysis.directionalBias.horizontalBias
            verticalBias = -analysis.directionalBias.verticalBias  // Flip for legacy

            // Map consistency rating to grouping quality
            switch analysis.consistencyRating {
            case .excellent: groupingQuality = .excellent
            case .good: groupingQuality = .good
            case .fair: groupingQuality = .fair
            case .needsWork: groupingQuality = .poor
            }
        }

        updateDetectionCounts(from: shots)
    }

    /// Update detection statistics from shots
    private func updateDetectionCounts(from shots: [ScanShot]) {
        autoDetectedCount = shots.filter { $0.detectionMethod == .autoDetected }.count
        userAddedCount = shots.filter { $0.detectionMethod == .userPlaced }.count
        userConfirmedCount = shots.filter { $0.wasUserConfirmed }.count
    }

    /// Re-analyze with current algorithm version
    func reanalyze() {
        let shots = shotPositions
        guard !shots.isEmpty else { return }

        if let geometry = cropGeometry, let targetType = targetGeometryType {
            calculateEnhancedMetrics(from: shots, cropGeometry: geometry, targetType: targetType)
        } else {
            // Legacy re-analysis
            calculateMetrics(from: shots, targetCenter: CGPoint(x: 0.5, y: 0.5))
        }

        algorithmVersion = PatternAnalysis.currentAlgorithmVersion
    }
}

// MARK: - Codable Validation Warning (for JSON storage)

private struct CodableValidationWarning: Codable {
    let code: String
    let message: String
    let field: String?

    init(from warning: ValidationWarning) {
        self.code = warning.code.rawValue
        self.message = warning.message
        self.field = warning.field
    }

    func toWarning() -> ValidationWarning {
        ValidationWarning(
            code: ValidationWarning.WarningCode(rawValue: code) ?? .manualOverrideUsed,
            message: message,
            field: field
        )
    }
}

// MARK: - Enhanced Scan Shot (for JSON storage)

struct ScanShot: Codable, Identifiable {
    var id: UUID = UUID()
    var positionX: Double
    var positionY: Double
    var score: Int
    var confidence: Double

    // Enhanced fields for new coordinate system
    var normalizedX: Double?
    var normalizedY: Double?
    var coordinateSystemVersion: Int?

    // Detection metadata
    var detectionMethodRaw: String?
    var wasUserConfirmed: Bool = false
    var userConfirmedAt: Date?

    // Hole characteristics
    var radiusPixels: Double?
    var radiusNormalized: Double?

    // Algorithm tracking
    var algorithmVersion: Int?

    init(positionX: Double, positionY: Double, score: Int, confidence: Double = 1.0) {
        self.positionX = positionX
        self.positionY = positionY
        self.score = score
        self.confidence = confidence
    }

    /// Enhanced initializer with normalized position
    init(
        normalizedPosition: NormalizedTargetPosition,
        score: Int,
        confidence: Double,
        detectionMethod: DetectionMethod = .autoDetected,
        radiusNormalized: Double? = nil
    ) {
        self.id = UUID()
        // Store both legacy and normalized positions
        self.positionX = (normalizedPosition.x + 1.0) / 2.0  // Convert to 0-1 range for legacy
        self.positionY = (1.0 - normalizedPosition.y) / 2.0  // Convert and flip Y
        self.normalizedX = normalizedPosition.x
        self.normalizedY = normalizedPosition.y
        self.coordinateSystemVersion = CoordinateSystemVersion.current.major
        self.score = score
        self.confidence = confidence
        self.detectionMethodRaw = detectionMethod.rawValue
        self.radiusNormalized = radiusNormalized
        self.algorithmVersion = PatternAnalysis.currentAlgorithmVersion
    }

    /// Get normalized position (returns new format or converts legacy)
    var normalizedPosition: NormalizedTargetPosition {
        if let x = normalizedX, let y = normalizedY {
            return NormalizedTargetPosition(x: x, y: y)
        }
        // Convert legacy position to normalized
        return NormalizedTargetPosition(
            x: positionX * 2.0 - 1.0,
            y: 1.0 - positionY * 2.0
        )
    }

    var detectionMethod: DetectionMethod {
        get {
            guard let raw = detectionMethodRaw else { return .userPlaced }
            return DetectionMethod(rawValue: raw) ?? .userPlaced
        }
        set {
            detectionMethodRaw = newValue.rawValue
        }
    }

    /// Whether this shot uses the new coordinate system
    var usesNormalizedCoordinates: Bool {
        normalizedX != nil && normalizedY != nil
    }

    /// Mark as user confirmed
    mutating func markUserConfirmed() {
        wasUserConfirmed = true
        userConfirmedAt = Date()
    }

    /// Detection method for shot
    enum DetectionMethod: String, Codable {
        case autoDetected = "auto"
        case userPlaced = "manual"
        case userAdjusted = "adjusted"
        case imported = "imported"

        var displayName: String {
            switch self {
            case .autoDetected: return "Auto-detected"
            case .userPlaced: return "Manual"
            case .userAdjusted: return "Adjusted"
            case .imported: return "Imported"
            }
        }
    }
}

// MARK: - Protocol Conformances for Analysis

extension ScanShot: ShotForAnalysis {}

extension ScanShot: ValidatableShot {}

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
