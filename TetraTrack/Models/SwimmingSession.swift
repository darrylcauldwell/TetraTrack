//
//  SwimmingSession.swift
//  TetraTrack
//
//  Swimming discipline - SWOLF, stroke detection, pace zones
//

import Foundation
import SwiftData
import CoreLocation

// MARK: - Swimming Session

@Model
final class SwimmingSession: TrainingSessionProtocol, PaceBasedSessionProtocol {
    var id: UUID = UUID()
    var startDate: Date = Date()
    var endDate: Date?
    var name: String = ""
    var notes: String = ""

    // Pool configuration
    var poolModeRaw: String = "pool"
    var poolLength: Double = 25.0 // meters
    var isIndoor: Bool = true

    // Results
    var totalDistance: Double = 0 // meters
    var totalDuration: TimeInterval = 0
    var totalStrokes: Int = 0

    // Heart rate data
    var averageHeartRate: Int = 0
    var maxHeartRate: Int = 0
    var minHeartRate: Int = 0
    var heartRateSamplesData: Data?

    // Enhanced sensor metrics (from Watch)
    var totalSubmergedTime: TimeInterval = 0    // seconds underwater
    var submersionCount: Int = 0                // number of submersion events
    var averageSpO2: Double = 0                 // percentage (0-100)
    var minSpO2: Double = 0                     // percentage (0-100)
    var recoveryQuality: Double = 0             // 0-100
    var averageBreathingRate: Double = 0        // breaths per minute

    @Transient private var _cachedHeartRateSamples: [HeartRateSample]?

    // Relationship
    @Relationship(deleteRule: .cascade, inverse: \SwimmingLap.session)
    var laps: [SwimmingLap]? = []

    @Relationship(deleteRule: .cascade, inverse: \SwimmingInterval.session)
    var intervals: [SwimmingInterval]? = []

    @Relationship(deleteRule: .cascade, inverse: \SwimmingLocationPoint.session)
    var locationPoints: [SwimmingLocationPoint]? = []

    var poolMode: SwimmingPoolMode {
        get { SwimmingPoolMode(rawValue: poolModeRaw) ?? .pool }
        set { poolModeRaw = newValue.rawValue }
    }

    init() {}

    init(
        name: String = "",
        poolMode: SwimmingPoolMode = .pool,
        poolLength: Double = 25.0
    ) {
        self.name = name
        self.poolModeRaw = poolMode.rawValue
        self.poolLength = poolLength
    }

    // MARK: - Computed Properties

    var lapCount: Int {
        (laps ?? []).count
    }

    var averagePace: TimeInterval {
        guard totalDistance > 0 else { return 0 }
        return totalDuration / (totalDistance / 100) // seconds per 100m
    }

    var averageSwolf: Double {
        let validLaps = (laps ?? []).filter { $0.swolf > 0 }
        guard !validLaps.isEmpty else { return 0 }
        return Double(validLaps.reduce(0) { $0 + $1.swolf }) / Double(validLaps.count)
    }

    var averageStrokesPerLap: Double {
        guard !(laps ?? []).isEmpty else { return 0 }
        return Double(totalStrokes) / Double((laps ?? []).count)
    }

    var dominantStroke: SwimmingStroke {
        let strokeCounts = Dictionary(grouping: (laps ?? []), by: { $0.stroke })
            .mapValues { $0.count }
        return strokeCounts.max(by: { $0.value < $1.value })?.key ?? .freestyle
    }

    var sortedLaps: [SwimmingLap] {
        (laps ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    var formattedPace: String {
        averagePace.formattedSwimPace
    }

    var formattedDistance: String {
        totalDistance.formattedDistance
    }

    var formattedDuration: String {
        totalDuration.formattedDuration
    }

    var isOpenWater: Bool {
        poolMode == .openWater
    }

    // MARK: - Route Data

    var hasRouteData: Bool {
        !(locationPoints ?? []).isEmpty
    }

    var sortedLocationPoints: [SwimmingLocationPoint] {
        (locationPoints ?? []).sorted { $0.timestamp < $1.timestamp }
    }

    var coordinates: [CLLocationCoordinate2D] {
        sortedLocationPoints.map(\.coordinate)
    }

    // MARK: - Heart Rate

    var heartRateSamples: [HeartRateSample] {
        get {
            if let cached = _cachedHeartRateSamples { return cached }
            guard let data = heartRateSamplesData else { return [] }
            do {
                let decoded = try JSONDecoder().decode([HeartRateSample].self, from: data)
                _cachedHeartRateSamples = decoded
                return decoded
            } catch {
                _cachedHeartRateSamples = []
                return []
            }
        }
        set {
            heartRateSamplesData = try? JSONEncoder().encode(newValue)
            _cachedHeartRateSamples = newValue
        }
    }

    var heartRateStatistics: HeartRateStatistics {
        HeartRateStatistics(samples: heartRateSamples)
    }

    var hasHeartRateData: Bool {
        averageHeartRate > 0 || !heartRateSamples.isEmpty
    }

    var formattedAverageHeartRate: String {
        guard averageHeartRate > 0 else { return "--" }
        return "\(averageHeartRate) bpm"
    }

    var formattedMaxHeartRate: String {
        guard maxHeartRate > 0 else { return "--" }
        return "\(maxHeartRate) bpm"
    }

    var formattedMinHeartRate: String {
        guard minHeartRate > 0 else { return "--" }
        return "\(minHeartRate) bpm"
    }
}

// MARK: - Swimming Lap

@Model
final class SwimmingLap {
    var id: UUID = UUID()
    var orderIndex: Int = 0
    var startTime: Date = Date()
    var endTime: Date?
    var distance: Double = 25.0 // meters
    var duration: TimeInterval = 0
    var strokeCount: Int = 0
    var strokeRaw: String = "freestyle"

    // Relationship
    var session: SwimmingSession?

    var stroke: SwimmingStroke {
        get { SwimmingStroke(rawValue: strokeRaw) ?? .freestyle }
        set { strokeRaw = newValue.rawValue }
    }

    init() {}

    init(orderIndex: Int = 0, distance: Double = 25.0) {
        self.orderIndex = orderIndex
        self.distance = distance
    }

    // SWOLF = strokes + seconds for length
    var swolf: Int {
        strokeCount + Int(duration)
    }

    var pace: TimeInterval {
        guard distance > 0 else { return 0 }
        return duration / (distance / 100) // seconds per 100m
    }

    var strokeRate: Double {
        guard duration > 0 else { return 0 }
        return Double(strokeCount) / (duration / 60) // strokes per minute
    }

    var formattedPace: String {
        pace.formattedSwimPace
    }
}

// MARK: - Swimming Interval

@Model
final class SwimmingInterval {
    var id: UUID = UUID()
    var orderIndex: Int = 0
    var name: String = ""
    var targetDistance: Double = 100 // meters
    var targetPace: TimeInterval = 0 // seconds per 100m
    var restDuration: TimeInterval = 0
    var isCompleted: Bool = false

    // Actual results
    var actualDistance: Double = 0
    var actualDuration: TimeInterval = 0
    var actualStrokes: Int = 0

    // Relationship
    var session: SwimmingSession?

    init() {}

    init(
        orderIndex: Int = 0,
        name: String = "",
        targetDistance: Double = 100,
        targetPace: TimeInterval = 0,
        restDuration: TimeInterval = 30
    ) {
        self.orderIndex = orderIndex
        self.name = name
        self.targetDistance = targetDistance
        self.targetPace = targetPace
        self.restDuration = restDuration
    }

    var actualPace: TimeInterval {
        guard actualDistance > 0 else { return 0 }
        return actualDuration / (actualDistance / 100)
    }

    var paceDifference: TimeInterval {
        guard targetPace > 0 else { return 0 }
        return actualPace - targetPace
    }

    var formattedTargetPace: String {
        targetPace.formattedSwimPace
    }
}

// MARK: - Swimming Stroke

enum SwimmingStroke: String, Codable, CaseIterable {
    case freestyle = "Freestyle"
    case backstroke = "Backstroke"
    case breaststroke = "Breaststroke"
    case butterfly = "Butterfly"
    case individual = "IM"
    case mixed = "Mixed"

    var icon: String {
        switch self {
        case .freestyle: return "figure.pool.swim"
        case .backstroke: return "figure.pool.swim"
        case .breaststroke: return "figure.pool.swim"
        case .butterfly: return "figure.pool.swim"
        case .individual: return "figure.pool.swim"
        case .mixed: return "figure.pool.swim"
        }
    }

    var abbreviation: String {
        switch self {
        case .freestyle: return "FR"
        case .backstroke: return "BK"
        case .breaststroke: return "BR"
        case .butterfly: return "FL"
        case .individual: return "IM"
        case .mixed: return "MX"
        }
    }
}

// MARK: - Pool Mode

enum SwimmingPoolMode: String, Codable, CaseIterable {
    case pool = "Pool"
    case openWater = "Open Water"

    var icon: String {
        switch self {
        case .pool: return "square.fill"
        case .openWater: return "water.waves"
        }
    }
}

// MARK: - Pace Zones

enum SwimmingPaceZone: Int, CaseIterable {
    case recovery = 1
    case endurance = 2
    case tempo = 3
    case threshold = 4
    case speed = 5

    var name: String {
        switch self {
        case .recovery: return "Recovery"
        case .endurance: return "Endurance"
        case .tempo: return "Tempo"
        case .threshold: return "Threshold"
        case .speed: return "Speed"
        }
    }

    var color: String {
        switch self {
        case .recovery: return "gray"
        case .endurance: return "blue"
        case .tempo: return "green"
        case .threshold: return "yellow"
        case .speed: return "red"
        }
    }

    var paceModifier: Double {
        switch self {
        case .recovery: return 1.3 // 30% slower than threshold
        case .endurance: return 1.15
        case .tempo: return 1.05
        case .threshold: return 1.0 // Base pace
        case .speed: return 0.9 // 10% faster than threshold
        }
    }

    /// Get zone from pace relative to threshold
    static func zone(for pace: TimeInterval, thresholdPace: TimeInterval) -> SwimmingPaceZone {
        guard thresholdPace > 0 else { return .endurance }
        let ratio = pace / thresholdPace

        switch ratio {
        case ..<0.95: return .speed
        case 0.95..<1.02: return .threshold
        case 1.02..<1.1: return .tempo
        case 1.1..<1.25: return .endurance
        default: return .recovery
        }
    }
}

// MARK: - 3-Minute Test Protocol

struct ThreeMinuteSwimTest {
    let testDate: Date
    let distance: Double // meters swum in 3 minutes
    let strokeCount: Int
    let stroke: SwimmingStroke

    var pace: TimeInterval {
        guard distance > 0 else { return 0 }
        return 180 / (distance / 100) // seconds per 100m
    }

    var swolf: Double {
        // Average SWOLF for the test
        let lapsSwum = distance / 25 // Assuming 25m pool
        guard lapsSwum > 0 else { return 0 }
        let avgStrokesPerLap = Double(strokeCount) / lapsSwum
        let avgTimePerLap = 180 / lapsSwum
        return avgStrokesPerLap + avgTimePerLap
    }

    var thresholdPace: TimeInterval {
        // CSS (Critical Swim Speed) approximation
        pace * 1.05 // Threshold is slightly faster than 3-min test pace
    }

    var formattedPace: String {
        pace.formattedSwimPace
    }

    var fitnessLevel: String {
        switch pace {
        case ..<90: return "Elite"
        case 90..<105: return "Advanced"
        case 105..<120: return "Intermediate"
        case 120..<150: return "Beginner"
        default: return "Novice"
        }
    }
}
