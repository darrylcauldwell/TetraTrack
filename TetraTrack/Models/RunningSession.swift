//
//  RunningSession.swift
//  TetraTrack
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
    var minHeartRate: Int = 0
    var heartRateSamplesData: Data?  // Encoded [HeartRateSample]

    // Running form metrics (from Watch motion sensors)
    var averageVerticalOscillation: Double = 0  // cm
    var averageGroundContactTime: Double = 0    // ms

    // HealthKit metrics (from Apple Watch via HealthKit - more accurate than phone)
    var healthKitAsymmetry: Double?             // percentage (0 = perfect symmetry)
    var healthKitStrideLength: Double?          // meters
    var healthKitPower: Double?                 // watts (Series 6+)
    var healthKitSpeed: Double?                 // m/s
    var healthKitStepCount: Int?                // steps during session

    // Enhanced sensor metrics (from Watch)
    var averageBreathingRate: Double = 0    // breaths per minute
    var averageSpO2: Double = 0             // percentage (0-100)
    var minSpO2: Double = 0                 // percentage (0-100)
    var endFatigueScore: Double = 0         // 0-100
    var postureStability: Double = 0        // 0-100
    var trainingLoadScore: Double = 0

    // Running form timeseries (from Watch)
    var runningFormSamplesData: Data?  // Encoded [RunningFormSample]

    // Recovery metrics
    var recoveryHeartRate: Int = 0     // HR 60s after session end
    var peakHeartRateAtEnd: Int = 0    // HR at moment of stopping

    // Running power (if available)
    var averagePower: Double? // watts
    var maxPower: Double?

    // iPhone motion sensor metrics (from RunningMotionAnalyzer)
    var phoneAverageCadence: Int = 0
    var phoneMaxCadence: Int = 0
    var averageAsymmetryIndex: Double = 0             // percentage
    var averageImpactLoadValue: Double = 0            // g-force
    var peakImpactLoad: Double = 0                    // g-force
    var impactLoadTrendValue: Double = 0              // percentage change
    var totalStepCount: Int = 0
    var runningPhaseBreakdownData: Data?              // Encoded RunningPhaseBreakdown
    var phoneMotionEnabled: Bool = false              // whether phone sensors were active

    // Treadmill-specific properties
    var treadmillIncline: Double? // percentage (0-15%)
    var manualDistance: Bool = false // true if distance was manually entered

    // Weather tracking
    var startWeatherData: Data?  // Encoded WeatherConditions at session start
    var endWeatherData: Data?    // Encoded WeatherConditions at session end

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \RunningSplit.session)
    var splits: [RunningSplit]? = []

    @Relationship(deleteRule: .cascade, inverse: \RunningInterval.session)
    var intervals: [RunningInterval]? = []

    // GPS location points for route display and trim capability
    @Relationship(deleteRule: .cascade, inverse: \RunningLocationPoint.session)
    var locationPoints: [RunningLocationPoint]? = []

    // Cached sorted points (not persisted)
    @Transient private var _cachedSortedLocationPoints: [RunningLocationPoint]?
    @Transient private var _cachedHeartRateSamples: [HeartRateSample]?
    @Transient private var _cachedFormSamples: [RunningFormSample]?

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
        (splits ?? []).sorted { $0.orderIndex < $1.orderIndex }
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

    // MARK: - Running Form Samples

    var runningFormSamples: [RunningFormSample] {
        get {
            if let cached = _cachedFormSamples { return cached }
            guard let data = runningFormSamplesData else { return [] }
            do {
                let decoded = try JSONDecoder().decode([RunningFormSample].self, from: data)
                _cachedFormSamples = decoded
                return decoded
            } catch {
                _cachedFormSamples = []
                return []
            }
        }
        set {
            runningFormSamplesData = try? JSONEncoder().encode(newValue)
            _cachedFormSamples = newValue
        }
    }

    // MARK: - Phase Breakdown

    @Transient private var _cachedPhaseBreakdown: RunningPhaseBreakdown?

    var runningPhaseBreakdown: RunningPhaseBreakdown {
        get {
            if let cached = _cachedPhaseBreakdown { return cached }
            guard let data = runningPhaseBreakdownData else { return RunningPhaseBreakdown() }
            do {
                let decoded = try JSONDecoder().decode(RunningPhaseBreakdown.self, from: data)
                _cachedPhaseBreakdown = decoded
                return decoded
            } catch {
                _cachedPhaseBreakdown = RunningPhaseBreakdown()
                return RunningPhaseBreakdown()
            }
        }
        set {
            runningPhaseBreakdownData = try? JSONEncoder().encode(newValue)
            _cachedPhaseBreakdown = newValue
        }
    }

    /// Phase breakdown computed from GPS speed data, falling back to stored real-time data
    /// for backward compatibility with older sessions.
    var effectivePhaseBreakdown: RunningPhaseBreakdown {
        // Use stored real-time data if available (from older sessions)
        let stored = runningPhaseBreakdown
        if stored.totalSeconds > 0 { return stored }

        // Compute from GPS speed data
        let points = sortedLocationPoints
        guard points.count > 1 else { return RunningPhaseBreakdown() }
        var breakdown = RunningPhaseBreakdown()
        for i in 1..<points.count {
            let dt = points[i].timestamp.timeIntervalSince(points[i-1].timestamp)
            guard dt > 0 && dt < 30 else { continue } // skip gaps
            let phase = RunningPhase.fromGPSSpeed(points[i].speed)
            breakdown.addTime(dt, for: phase)
        }
        return breakdown
    }

    /// Whether this session has phone motion data
    var hasPhoneMotionData: Bool {
        phoneMotionEnabled && phoneAverageCadence > 0
    }

    // MARK: - Derived Metrics

    /// Stride length derived from cadence and speed: stride = speed / (cadence/60)
    var estimatedStrideLength: Double {
        guard averageCadence > 0, averageSpeed > 0 else { return 0 }
        return averageSpeed / (Double(averageCadence) / 60.0) // meters
    }

    /// Estimated running power (watts) from pace, grade, and assumed body weight
    /// Uses simplified model: P = (body_mass * g * grade * speed) + (0.5 * Cd * A * rho * speed^3) + (Cr * body_mass * g * speed)
    var estimatedRunningPower: Double {
        guard averageSpeed > 0 else { return 0 }
        let bodyMass: Double = 70.0 // kg assumption
        let g: Double = 9.81
        let speed = averageSpeed // m/s

        // Grade from elevation
        let grade = totalDistance > 0 ? (totalAscent - totalDescent) / totalDistance : 0

        // Rolling resistance cost
        let Cr: Double = 0.98 // metabolic cost of running (J/kg/m)
        let rollingPower = Cr * bodyMass * speed

        // Grade resistance
        let gradePower = bodyMass * g * grade * speed

        // Air resistance (simplified)
        let Cd: Double = 0.9  // drag coefficient
        let A: Double = 0.45  // frontal area m^2
        let rho: Double = 1.225 // air density kg/m^3
        let aeroPower = 0.5 * Cd * A * rho * pow(speed, 3)

        return max(0, rollingPower + gradePower + aeroPower)
    }

    /// Efficiency factor: pace-to-HR ratio. Lower = more efficient.
    /// Computed as normalized graded pace (sec/km) / average HR
    var efficiencyFactor: Double {
        guard averageHeartRate > 0, averagePace > 0 else { return 0 }
        return averagePace / Double(averageHeartRate)
    }

    /// Cardiac drift / decoupling: compares first-half vs second-half efficiency
    /// Positive % means HR drifted up relative to pace (cardiovascular drift)
    var cardiacDecoupling: Double {
        let splits = sortedSplits
        guard splits.count >= 2 else { return 0 }

        let mid = splits.count / 2
        let firstHalf = Array(splits.prefix(mid))
        let secondHalf = Array(splits.suffix(from: mid))

        let firstPace = firstHalf.reduce(0) { $0 + $1.pace } / Double(firstHalf.count)
        let secondPace = secondHalf.reduce(0) { $0 + $1.pace } / Double(secondHalf.count)
        let firstHR = firstHalf.filter { $0.heartRate > 0 }
        let secondHR = secondHalf.filter { $0.heartRate > 0 }

        guard !firstHR.isEmpty, !secondHR.isEmpty else { return 0 }

        let firstAvgHR = Double(firstHR.reduce(0) { $0 + $1.heartRate }) / Double(firstHR.count)
        let secondAvgHR = Double(secondHR.reduce(0) { $0 + $1.heartRate }) / Double(secondHR.count)

        guard firstAvgHR > 0, secondAvgHR > 0, firstPace > 0, secondPace > 0 else { return 0 }

        let firstEF = firstPace / firstAvgHR
        let secondEF = secondPace / secondAvgHR

        guard firstEF > 0 else { return 0 }
        return ((secondEF - firstEF) / firstEF) * 100 // percentage
    }

    /// Training Stress Score (TSS): based on HR zones and duration
    /// TSS = (duration_seconds / 3600) * intensity_factor^2 * 100
    var trainingStress: Double {
        guard totalDuration > 0, averageHeartRate > 0 else { return 0 }

        // Intensity factor from HR (fraction of max HR)
        let estimatedMax = Double(max(maxHeartRate, 190))
        let intensityFactor = Double(averageHeartRate) / estimatedMax

        // TSS formula
        let hours = totalDuration / 3600.0
        return hours * pow(intensityFactor, 2) * 100
    }

    /// Recovery score: based on HR drop from peak to 60s post-session
    /// Higher = better recovery (faster HR drop)
    var recoveryScore: Double {
        guard peakHeartRateAtEnd > 0, recoveryHeartRate > 0 else { return 0 }
        let drop = peakHeartRateAtEnd - recoveryHeartRate
        // Excellent recovery: >30 bpm drop in 60s
        // Good: 20-30, Fair: 10-20, Poor: <10
        return min(100, Double(drop) * (100.0 / 40.0))
    }

    /// Per-split stride lengths derived from split pace and cadence
    var splitStrideLengths: [(splitIndex: Int, strideLength: Double)] {
        sortedSplits.compactMap { split in
            guard split.cadence > 0, split.pace > 0, split.distance > 0 else { return nil }
            let speed = split.distance / split.duration
            let stride = speed / (Double(split.cadence) / 60.0)
            return (splitIndex: split.orderIndex, strideLength: stride)
        }
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

// MARK: - Running Form Sample

struct RunningFormSample: Codable, Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let cadence: Int       // spm
    public let oscillation: Double // cm
    public let groundContactTime: Double // ms

    public init(timestamp: Date = Date(), cadence: Int = 0, oscillation: Double = 0, groundContactTime: Double = 0) {
        self.id = UUID()
        self.timestamp = timestamp
        self.cadence = cadence
        self.oscillation = oscillation
        self.groundContactTime = groundContactTime
    }

    /// Stride length derived from cadence and pace (needs speed passed in)
    func strideLength(atSpeed speed: Double) -> Double {
        guard cadence > 0, speed > 0 else { return 0 }
        return speed / (Double(cadence) / 60.0)
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
