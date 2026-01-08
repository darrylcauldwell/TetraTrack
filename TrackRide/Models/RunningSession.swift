//
//  RunningSession.swift
//  TrackRide
//
//  Running discipline - 1500m trials, pace zones, race predictor
//

import Foundation
import SwiftData
import CoreLocation

// MARK: - Running Session

@Model
final class RunningSession: TrainingSessionProtocol, PaceBasedSessionProtocol, ElevationSessionProtocol, HeartRateSessionProtocol, CadenceSessionProtocol {
    var id: UUID = UUID()
    var startDate: Date = Date()
    var endDate: Date?
    var name: String = ""
    var notes: String = ""

    // Session type
    var sessionTypeRaw: String = "easy"
    var runModeRaw: String = "outdoor"

    // Core metrics
    var totalDistance: Double = 0 // meters
    var totalDuration: TimeInterval = 0
    var totalAscent: Double = 0 // meters
    var totalDescent: Double = 0

    // Cadence
    var averageCadence: Int = 0 // steps per minute
    var maxCadence: Int = 0

    // Heart rate
    var averageHeartRate: Int = 0
    var maxHeartRate: Int = 0

    // Running power (if available)
    var averagePower: Double? // watts
    var maxPower: Double?

    // Treadmill-specific properties
    var treadmillIncline: Double? // percentage (0-15%)
    var manualDistance: Bool = false // true if distance was manually entered

    // Weather tracking
    var startWeatherData: Data?  // Encoded WeatherConditions at session start
    var endWeatherData: Data?    // Encoded WeatherConditions at session end

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \RunningSplit.session)
    var splits: [RunningSplit] = []

    @Relationship(deleteRule: .cascade, inverse: \RunningInterval.session)
    var intervals: [RunningInterval] = []

    // GPS location points for route display and trim capability
    @Relationship(deleteRule: .cascade, inverse: \RunningLocationPoint.session)
    var locationPoints: [RunningLocationPoint]? = []

    // Cached sorted points (not persisted)
    @Transient private var _cachedSortedLocationPoints: [RunningLocationPoint]?

    var sessionType: RunningSessionType {
        get { RunningSessionType(rawValue: sessionTypeRaw) ?? .easy }
        set { sessionTypeRaw = newValue.rawValue }
    }

    var runMode: RunningMode {
        get { RunningMode(rawValue: runModeRaw) ?? .outdoor }
        set { runModeRaw = newValue.rawValue }
    }

    init() {}

    init(
        name: String = "",
        sessionType: RunningSessionType = .easy,
        runMode: RunningMode = .outdoor
    ) {
        self.name = name
        self.sessionTypeRaw = sessionType.rawValue
        self.runModeRaw = runMode.rawValue
    }

    // MARK: - Computed Properties

    var averagePace: TimeInterval {
        guard totalDistance > 0 else { return 0 }
        return totalDuration / (totalDistance / 1000) // seconds per km
    }

    var averageSpeed: Double {
        guard totalDuration > 0 else { return 0 }
        return totalDistance / totalDuration // m/s
    }

    var sortedSplits: [RunningSplit] {
        splits.sorted { $0.orderIndex < $1.orderIndex }
    }

    var formattedPace: String {
        averagePace.formattedPace
    }

    var formattedDistance: String {
        totalDistance.formattedDistance
    }

    var formattedDuration: String {
        totalDuration.formattedDuration
    }

    var formattedSpeed: String {
        averageSpeed.formattedSpeed
    }

    // MARK: - Weather

    /// Decoded weather conditions at session start
    var startWeather: WeatherConditions? {
        get {
            guard let data = startWeatherData else { return nil }
            return try? JSONDecoder().decode(WeatherConditions.self, from: data)
        }
        set {
            startWeatherData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Decoded weather conditions at session end
    var endWeather: WeatherConditions? {
        get {
            guard let data = endWeatherData else { return nil }
            return try? JSONDecoder().decode(WeatherConditions.self, from: data)
        }
        set {
            endWeatherData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Whether this session has weather data
    var hasWeatherData: Bool {
        startWeather != nil
    }

    /// Brief weather summary for list display
    var weatherSummary: String? {
        startWeather?.briefSummary
    }

    /// Whether this is an outdoor session that should track weather
    var isOutdoor: Bool {
        runMode == .outdoor
    }

    /// Whether this is a treadmill session
    var isTreadmill: Bool {
        runMode == .treadmill
    }

    // MARK: - Location Points

    /// Sorted location points by timestamp (cached for efficiency)
    var sortedLocationPoints: [RunningLocationPoint] {
        if let cached = _cachedSortedLocationPoints { return cached }
        let sorted = (locationPoints ?? []).sorted { $0.timestamp < $1.timestamp }
        _cachedSortedLocationPoints = sorted
        return sorted
    }

    /// Coordinates for map display
    var coordinates: [CLLocationCoordinate2D] {
        sortedLocationPoints.map { $0.coordinate }
    }

    /// Whether this session has GPS route data
    var hasRouteData: Bool {
        !(locationPoints ?? []).isEmpty
    }

    // MARK: - Trim Functionality

    /// Apply trim to session, removing location points outside the specified time range
    func applyTrim(startTime: Date, endTime: Date, context: ModelContext) {
        // Filter location points to keep only those within trim range
        let pointsToRemove = (locationPoints ?? []).filter {
            $0.timestamp < startTime || $0.timestamp > endTime
        }

        // Delete removed points
        for point in pointsToRemove {
            context.delete(point)
        }

        // Invalidate cache
        _cachedSortedLocationPoints = nil

        // Recalculate metrics from remaining points
        recalculateMetrics()

        // Update start/end dates
        self.startDate = startTime
        self.endDate = endTime
    }

    /// Recalculate metrics from location points after trim
    func recalculateMetrics() {
        let points = sortedLocationPoints
        guard points.count > 1 else { return }

        // Recalculate total distance
        var newDistance: Double = 0
        for i in 1..<points.count {
            let prev = CLLocation(latitude: points[i-1].latitude, longitude: points[i-1].longitude)
            let curr = CLLocation(latitude: points[i].latitude, longitude: points[i].longitude)
            newDistance += curr.distance(from: prev)
        }
        totalDistance = newDistance

        // Recalculate duration
        if let first = points.first, let last = points.last {
            totalDuration = last.timestamp.timeIntervalSince(first.timestamp)
        }

        // Recalculate elevation
        var ascent: Double = 0
        var descent: Double = 0
        for i in 1..<points.count {
            let delta = points[i].altitude - points[i-1].altitude
            if delta > 0 {
                ascent += delta
            } else {
                descent += abs(delta)
            }
        }
        totalAscent = ascent
        totalDescent = descent
    }

    /// Speed anomalies (for showing vehicle detection points on trim timeline)
    var speedAnomalies: [(timestamp: Date, speed: Double)] {
        sortedLocationPoints
            .filter { $0.speed > 7.0 } // > 25 km/h
            .map { (timestamp: $0.timestamp, speed: $0.speed) }
    }
}

// MARK: - Running Split

@Model
final class RunningSplit {
    var id: UUID = UUID()
    var orderIndex: Int = 0
    var distance: Double = 1000 // meters (1km splits by default)
    var duration: TimeInterval = 0
    var cadence: Int = 0
    var heartRate: Int = 0
    var elevation: Double = 0
    var power: Double?

    // Relationship
    var session: RunningSession?

    init() {}

    init(orderIndex: Int = 0, distance: Double = 1000) {
        self.orderIndex = orderIndex
        self.distance = distance
    }

    var pace: TimeInterval {
        guard distance > 0 else { return 0 }
        return duration / (distance / 1000) // seconds per km
    }

    var speed: Double {
        guard duration > 0 else { return 0 }
        return distance / duration // m/s
    }

    var formattedPace: String {
        pace.formattedPace
    }

    var paceZone: RunningPaceZone? {
        guard let thresholdPace = session?.thresholdPace, thresholdPace > 0 else { return nil }
        return RunningPaceZone.zone(for: pace, thresholdPace: thresholdPace)
    }
}

// MARK: - Running Interval

@Model
final class RunningInterval {
    var id: UUID = UUID()
    var orderIndex: Int = 0
    var name: String = ""
    var targetDistance: Double = 400 // meters
    var targetPace: TimeInterval = 0 // seconds per km
    var targetDuration: TimeInterval = 0 // alternative to distance
    var restDuration: TimeInterval = 60
    var isCompleted: Bool = false

    // Actual results
    var actualDistance: Double = 0
    var actualDuration: TimeInterval = 0
    var actualCadence: Int = 0
    var actualHeartRate: Int = 0

    // Relationship
    var session: RunningSession?

    init() {}

    init(
        orderIndex: Int = 0,
        name: String = "",
        targetDistance: Double = 400,
        restDuration: TimeInterval = 60
    ) {
        self.orderIndex = orderIndex
        self.name = name
        self.targetDistance = targetDistance
        self.restDuration = restDuration
    }

    var actualPace: TimeInterval {
        guard actualDistance > 0 else { return 0 }
        return actualDuration / (actualDistance / 1000)
    }

    var paceDifference: TimeInterval {
        guard targetPace > 0 else { return 0 }
        return actualPace - targetPace
    }
}

// MARK: - Session Extensions

extension RunningSession {
    var thresholdPace: TimeInterval {
        // Use stored value or calculate from time trials
        // Default threshold for intermediate runner: 5:00/km
        return 300
    }
}

// MARK: - Running Session Type

enum RunningSessionType: String, Codable, CaseIterable {
    case easy = "Easy Run"
    case tempo = "Tempo Run"
    case intervals = "Intervals"
    case longRun = "Long Run"
    case recovery = "Recovery"
    case race = "Race"
    case timeTrial = "Time Trial"
    case fartlek = "Fartlek"
    case treadmill = "Treadmill"

    var icon: String {
        switch self {
        case .easy: return "figure.run"
        case .tempo: return "speedometer"
        case .intervals: return "timer"
        case .longRun: return "figure.run"
        case .recovery: return "heart"
        case .race: return "trophy"
        case .timeTrial: return "stopwatch"
        case .fartlek: return "shuffle"
        case .treadmill: return "figure.run.treadmill"
        }
    }

    var color: String {
        switch self {
        case .easy: return "green"
        case .tempo: return "yellow"
        case .intervals: return "orange"
        case .longRun: return "blue"
        case .recovery: return "gray"
        case .race: return "red"
        case .timeTrial: return "purple"
        case .fartlek: return "cyan"
        case .treadmill: return "mint"
        }
    }
}

// MARK: - Running Mode

enum RunningMode: String, Codable, CaseIterable {
    case outdoor = "Outdoor GPS"
    case track = "Track"
    case treadmill = "Treadmill"
    case indoor = "Indoor"

    var icon: String {
        switch self {
        case .outdoor: return "location.fill"
        case .track: return "circle.dashed"
        case .treadmill: return "figure.run.treadmill"
        case .indoor: return "building.2"
        }
    }

    var usesGPS: Bool {
        self == .outdoor
    }
}

// MARK: - Pace Zones

enum RunningPaceZone: Int, CaseIterable {
    case recovery = 1
    case easy = 2
    case aerobic = 3
    case tempo = 4
    case threshold = 5
    case vo2max = 6
    case speed = 7

    var name: String {
        switch self {
        case .recovery: return "Recovery"
        case .easy: return "Easy"
        case .aerobic: return "Aerobic"
        case .tempo: return "Tempo"
        case .threshold: return "Threshold"
        case .vo2max: return "VO2max"
        case .speed: return "Speed"
        }
    }

    var color: String {
        switch self {
        case .recovery: return "gray"
        case .easy: return "blue"
        case .aerobic: return "green"
        case .tempo: return "yellow"
        case .threshold: return "orange"
        case .vo2max: return "red"
        case .speed: return "purple"
        }
    }

    var paceModifier: Double {
        switch self {
        case .recovery: return 1.35
        case .easy: return 1.25
        case .aerobic: return 1.15
        case .tempo: return 1.05
        case .threshold: return 1.0
        case .vo2max: return 0.92
        case .speed: return 0.85
        }
    }

    static func zone(for pace: TimeInterval, thresholdPace: TimeInterval) -> RunningPaceZone {
        guard thresholdPace > 0 else { return .aerobic }
        let ratio = pace / thresholdPace

        switch ratio {
        case ..<0.88: return .speed
        case 0.88..<0.95: return .vo2max
        case 0.95..<1.02: return .threshold
        case 1.02..<1.1: return .tempo
        case 1.1..<1.2: return .aerobic
        case 1.2..<1.3: return .easy
        default: return .recovery
        }
    }
}

// MARK: - Race Predictor

struct RacePredictor {
    let recentTimeTrial: TimeTrialResult

    /// Predict race time using Riegel formula
    func predictTime(for distance: Double) -> TimeInterval {
        // Riegel formula: T2 = T1 * (D2/D1)^1.06
        let exponent = 1.06
        let ratio = pow(distance / recentTimeTrial.distance, exponent)
        return recentTimeTrial.time * ratio
    }

    func predictPace(for distance: Double) -> TimeInterval {
        let time = predictTime(for: distance)
        return time / (distance / 1000) // seconds per km
    }

    func formatPrediction(for distance: Double) -> String {
        let time = predictTime(for: distance)
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Get predictions for common race distances
    var predictions: [RacePrediction] {
        let distances: [(String, Double)] = [
            ("1500m", 1500),
            ("Mile", 1609.34),
            ("3K", 3000),
            ("5K", 5000),
            ("10K", 10000),
            ("Half Marathon", 21097.5),
            ("Marathon", 42195)
        ]

        return distances.map { name, distance in
            RacePrediction(
                raceName: name,
                distance: distance,
                predictedTime: predictTime(for: distance),
                predictedPace: predictPace(for: distance)
            )
        }
    }
}

struct TimeTrialResult {
    let distance: Double // meters
    let time: TimeInterval
    let date: Date

    var pace: TimeInterval {
        time / (distance / 1000)
    }

    var formattedTime: String {
        time.formattedLapTime
    }
}

struct RacePrediction: Identifiable {
    let id = UUID()
    let raceName: String
    let distance: Double
    let predictedTime: TimeInterval
    let predictedPace: TimeInterval

    var formattedTime: String {
        predictedTime.formattedDuration
    }

    var formattedPace: String {
        predictedPace.formattedPace
    }
}

// MARK: - 1500m Time Trial

struct FifteenHundredTimeTrial {
    let time: TimeInterval
    let date: Date
    let splits: [TimeInterval] // 300m or 400m splits

    var pace: TimeInterval {
        time / 1.5 // seconds per km
    }

    var estimatedVO2Max: Double {
        // Cooper formula approximation
        let distanceIn12Min = 1500 * (720 / time)
        return (distanceIn12Min - 504.9) / 44.73
    }

    var fitnessLevel: String {
        switch time {
        case ..<240: return "Elite"
        case 240..<270: return "Advanced"
        case 270..<300: return "Intermediate"
        case 300..<360: return "Beginner"
        default: return "Novice"
        }
    }

    var formattedTime: String {
        time.formattedLapTime
    }

    /// Create race predictor from this time trial
    var racePredictor: RacePredictor {
        let result = TimeTrialResult(distance: 1500, time: time, date: date)
        return RacePredictor(recentTimeTrial: result)
    }
}
