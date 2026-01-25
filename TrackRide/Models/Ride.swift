//
//  Ride.swift
//  TrackRide
//

import Foundation
import SwiftData
import CoreLocation
import os

@Model
final class Ride: GaitTimeTracking {
    // MARK: - Indexes for Query Performance
    // These indexes optimize frequently used queries (ride history, filtering by discipline)
    #Index<Ride>([\.startDate], [\.rideTypeValue])
    // All properties have defaults for CloudKit compatibility
    var id: UUID = UUID()

    @Attribute(.spotlight)
    var startDate: Date = Date()
    var endDate: Date?  // Optional for CloudKit
    var totalDistance: Double = 0.0  // meters
    var totalDuration: TimeInterval = 0.0  // seconds
    var name: String = ""
    var notes: String = ""
    var elevationGain: Double = 0.0  // meters
    var elevationLoss: Double = 0.0  // meters
    var maxSpeed: Double = 0.0  // m/s

    // Turn tracking
    var leftTurns: Int = 0
    var rightTurns: Int = 0
    var totalLeftAngle: Double = 0.0  // degrees
    var totalRightAngle: Double = 0.0  // degrees

    // Ride type
    var rideTypeValue: String = RideType.hack.rawValue

    // Lead tracking (for canter/gallop)
    var leftLeadDuration: TimeInterval = 0.0
    var rightLeadDuration: TimeInterval = 0.0

    // Rein tracking (for flatwork)
    var leftReinDuration: TimeInterval = 0.0
    var rightReinDuration: TimeInterval = 0.0
    var leftReinSymmetry: Double = 0.0  // 0-100%
    var rightReinSymmetry: Double = 0.0  // 0-100%
    var leftReinRhythm: Double = 0.0  // 0-100%
    var rightReinRhythm: Double = 0.0  // 0-100%

    // Heart rate tracking
    var averageHeartRate: Int = 0
    var maxHeartRate: Int = 0
    var minHeartRate: Int = 0
    var heartRateSamplesData: Data?  // Encoded [HeartRateSample]
    var recoveryMetricsData: Data?   // Encoded RecoveryMetrics

    // Weather tracking
    var startWeatherData: Data?  // Encoded WeatherConditions at ride start
    var endWeatherData: Data?    // Encoded WeatherConditions at ride end

    // AI Summary
    var aiSummaryData: Data?     // Encoded SessionSummary
    var voiceNotesData: Data?    // Encoded [String] voice notes from session

    // MARK: - Biomechanical Metrics (Physics-Based)

    /// Average stride length across session (meters)
    var averageStrideLength: Double = 0.0

    /// Average stride frequency across session (Hz)
    var averageStrideFrequency: Double = 0.0

    /// Average impulsion across session (0-100)
    var averageImpulsion: Double = 0.0

    /// Average engagement across session (0-100)
    var averageEngagement: Double = 0.0

    /// Average straightness across session (0-100)
    var averageStraightness: Double = 0.0

    /// Average rider stability across session (0-100)
    var averageRiderStability: Double = 0.0

    /// Total training load for session
    var totalTrainingLoad: Double = 0.0

    /// Per-gait stride metrics (encoded JSON)
    var strideMetricsData: Data?

    // MARK: - Cached Transient Properties (not persisted, avoid repeated computation)
    @Transient private var _cachedHeartRateSamples: [HeartRateSample]?
    @Transient private var _cachedRecoveryMetrics: RecoveryMetrics??
    @Transient private var _cachedStartWeather: WeatherConditions??
    @Transient private var _cachedEndWeather: WeatherConditions??
    @Transient private var _cachedAISummary: SessionSummary??
    @Transient private var _cachedVoiceNotes: [String]?
    @Transient private var _cachedGaitDurations: [GaitType: TimeInterval]?
    @Transient private var _cachedSortedLocationPoints: [LocationPoint]?
    @Transient private var _cachedElevationProfile: [(distance: Double, altitude: Double)]?
    @Transient private var _cachedTransitionCounts: (upward: Int, downward: Int)?

    // Relationships - MUST be optional for CloudKit
    @Relationship(deleteRule: .cascade, inverse: \LocationPoint.ride)
    var locationPoints: [LocationPoint]? = []

    @Relationship(deleteRule: .cascade, inverse: \GaitSegment.ride)
    var gaitSegments: [GaitSegment]? = []

    @Relationship(deleteRule: .cascade, inverse: \ReinSegment.ride)
    var reinSegments: [ReinSegment]? = []

    @Relationship(deleteRule: .cascade, inverse: \GaitTransition.ride)
    var gaitTransitions: [GaitTransition]? = []

    @Relationship(deleteRule: .cascade, inverse: \RidePhoto.ride)
    var photos: [RidePhoto]? = []

    @Relationship(deleteRule: .cascade, inverse: \RideScore.ride)
    var scores: [RideScore]? = []

    // Horse association - optional for backwards compatibility
    var horse: Horse?

    init() {}

    // MARK: - Computed Properties

    var averageSpeed: Double {
        guard totalDuration > 0 else { return 0 }
        return totalDistance / totalDuration  // m/s
    }

    var formattedDistance: String {
        totalDistance.formattedDistance
    }

    var formattedDuration: String {
        totalDuration.formattedDuration
    }

    var formattedAverageSpeed: String {
        averageSpeed.formattedSpeed
    }

    var formattedMaxSpeed: String {
        maxSpeed.formattedSpeed
    }

    var formattedDate: String {
        Formatters.dateTime(startDate)
    }

    var sortedLocationPoints: [LocationPoint] {
        if let cached = _cachedSortedLocationPoints { return cached }
        let sorted = (locationPoints ?? []).sorted { $0.timestamp < $1.timestamp }
        _cachedSortedLocationPoints = sorted
        return sorted
    }

    var coordinates: [CLLocationCoordinate2D] {
        sortedLocationPoints.map { $0.coordinate }
    }

    // MARK: - Turn Stats

    var turnStats: TurnStats {
        TurnStats(
            leftTurns: leftTurns,
            rightTurns: rightTurns,
            totalLeftAngle: totalLeftAngle,
            totalRightAngle: totalRightAngle
        )
    }

    var turnBalancePercent: Int {
        let total = leftTurns + rightTurns
        guard total > 0 else { return 50 }
        return Int((Double(leftTurns) / Double(total)) * 100)
    }

    // MARK: - Gait Stats

    var sortedGaitSegments: [GaitSegment] {
        (gaitSegments ?? []).sorted { $0.startTime < $1.startTime }
    }

    /// Computes and caches all gait durations at once (avoids N+1 filtering)
    private func computeGaitDurations() -> [GaitType: TimeInterval] {
        if let cached = _cachedGaitDurations { return cached }
        var durations: [GaitType: TimeInterval] = [:]
        for segment in (gaitSegments ?? []) {
            durations[segment.gait, default: 0] += segment.duration
        }
        _cachedGaitDurations = durations
        return durations
    }

    func gaitDuration(for gaitType: GaitType) -> TimeInterval {
        computeGaitDurations()[gaitType] ?? 0
    }

    // MARK: - GaitTimeTracking Conformance

    var totalWalkTime: TimeInterval { gaitDuration(for: .walk) }
    var totalTrotTime: TimeInterval { gaitDuration(for: .trot) }
    var totalCanterTime: TimeInterval { gaitDuration(for: .canter) }
    var totalGallopTime: TimeInterval { gaitDuration(for: .gallop) }

    func gaitDistance(for gaitType: GaitType) -> Double {
        sortedGaitSegments
            .filter { $0.gait == gaitType }
            .reduce(0) { $0 + $1.distance }
    }

    func gaitPercentage(for gaitType: GaitType) -> Double {
        guard totalDuration > 0 else { return 0 }
        return (gaitDuration(for: gaitType) / totalDuration) * 100
    }

    var gaitBreakdown: [(gait: GaitType, duration: TimeInterval, percentage: Double)] {
        GaitType.allCases.compactMap { gait in
            let duration = gaitDuration(for: gait)
            guard duration > 0 else { return nil }
            return (gait, duration, gaitPercentage(for: gait))
        }
    }

    // MARK: - Elevation

    var formattedElevationGain: String {
        elevationGain.formattedElevation
    }

    var formattedElevationLoss: String {
        elevationLoss.formattedElevation
    }

    var elevationProfile: [(distance: Double, altitude: Double)] {
        if let cached = _cachedElevationProfile { return cached }

        var cumulativeDistance: Double = 0
        var profile: [(Double, Double)] = []
        var lastPoint: LocationPoint?

        for point in sortedLocationPoints {
            if let last = lastPoint {
                let delta = CLLocation(latitude: point.latitude, longitude: point.longitude)
                    .distance(from: CLLocation(latitude: last.latitude, longitude: last.longitude))
                cumulativeDistance += delta
            }
            profile.append((cumulativeDistance, point.altitude))
            lastPoint = point
        }

        _cachedElevationProfile = profile
        return profile
    }

    // MARK: - Ride Type

    var rideType: RideType {
        get { RideType(rawValue: rideTypeValue) ?? .hack }
        set { rideTypeValue = newValue.rawValue }
    }

    // MARK: - Lead Stats

    /// Total time in canter/gallop with known lead
    var totalLeadDuration: TimeInterval {
        leftLeadDuration + rightLeadDuration
    }

    /// Lead balance as ratio (0.5 = balanced, 0 = all right, 1 = all left)
    var leadBalance: Double {
        guard totalLeadDuration > 0 else { return 0.5 }
        return leftLeadDuration / totalLeadDuration
    }

    /// Lead balance as percentage (50 = balanced)
    var leadBalancePercent: Int {
        Int(leadBalance * 100)
    }

    /// Formatted left lead duration
    var formattedLeftLeadDuration: String {
        leftLeadDuration.formattedDuration
    }

    /// Formatted right lead duration
    var formattedRightLeadDuration: String {
        rightLeadDuration.formattedDuration
    }

    /// Percentage of canter/gallop time with correct lead (lead matches rein direction)
    var correctLeadPercentage: Double {
        let canterSegments = sortedGaitSegments.filter {
            ($0.gait == .canter || $0.gait == .gallop) && $0.hasKnownLead
        }
        guard !canterSegments.isEmpty else { return 100.0 }
        let correctDuration = canterSegments.filter { $0.isCorrectLead }.reduce(0) { $0 + $1.duration }
        let totalDuration = canterSegments.reduce(0) { $0 + $1.duration }
        guard totalDuration > 0 else { return 100.0 }
        return (correctDuration / totalDuration) * 100
    }

    /// Duration of cross-canter (incorrect lead for rein direction)
    var crossCanterDuration: TimeInterval {
        sortedGaitSegments
            .filter { ($0.gait == .canter || $0.gait == .gallop) && $0.hasKnownLead && !$0.isCorrectLead }
            .reduce(0) { $0 + $1.duration }
    }

    /// Formatted cross-canter duration
    var formattedCrossCanterDuration: String {
        crossCanterDuration.formattedDuration
    }

    /// Average vertical-yaw coherence across all segments
    var averageVerticalYawCoherence: Double {
        let segments = sortedGaitSegments.filter { $0.verticalYawCoherence > 0 }
        guard !segments.isEmpty else { return 0 }
        return segments.reduce(0) { $0 + $1.verticalYawCoherence } / Double(segments.count)
    }

    // MARK: - Rein Stats

    /// Total time on reins
    var totalReinDuration: TimeInterval {
        leftReinDuration + rightReinDuration
    }

    /// Rein balance as ratio (0.5 = balanced)
    var reinBalance: Double {
        guard totalReinDuration > 0 else { return 0.5 }
        return leftReinDuration / totalReinDuration
    }

    /// Rein balance as percentage
    var reinBalancePercent: Int {
        Int(reinBalance * 100)
    }

    /// Overall symmetry score (weighted by rein duration)
    var overallSymmetry: Double {
        guard totalReinDuration > 0 else { return 0.0 }
        return (leftReinSymmetry * leftReinDuration + rightReinSymmetry * rightReinDuration) / totalReinDuration
    }

    /// Overall rhythm score (weighted by rein duration)
    var overallRhythm: Double {
        guard totalReinDuration > 0 else { return 0.0 }
        return (leftReinRhythm * leftReinDuration + rightReinRhythm * rightReinDuration) / totalReinDuration
    }

    /// Formatted left rein duration
    var formattedLeftReinDuration: String {
        leftReinDuration.formattedDuration
    }

    /// Formatted right rein duration
    var formattedRightReinDuration: String {
        rightReinDuration.formattedDuration
    }

    /// Sorted rein segments by time
    var sortedReinSegments: [ReinSegment] {
        (reinSegments ?? []).sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Transition Stats

    /// Sorted gait transitions by time
    var sortedGaitTransitions: [GaitTransition] {
        (gaitTransitions ?? []).sorted { $0.timestamp < $1.timestamp }
    }

    /// Total number of transitions
    var transitionCount: Int {
        (gaitTransitions ?? []).count
    }

    /// Average transition quality (0-1)
    var averageTransitionQuality: Double {
        let transitions = gaitTransitions ?? []
        guard !transitions.isEmpty else { return 0.0 }
        return transitions.reduce(0) { $0 + $1.transitionQuality } / Double(transitions.count)
    }

    /// Computes both transition counts in a single pass (cached)
    private func computeTransitionCounts() -> (upward: Int, downward: Int) {
        if let cached = _cachedTransitionCounts { return cached }
        var upward = 0
        var downward = 0
        for transition in (gaitTransitions ?? []) {
            if transition.isUpwardTransition { upward += 1 }
            if transition.isDownwardTransition { downward += 1 }
        }
        let result = (upward: upward, downward: downward)
        _cachedTransitionCounts = result
        return result
    }

    /// Count of upward transitions
    var upwardTransitionCount: Int {
        computeTransitionCounts().upward
    }

    /// Count of downward transitions
    var downwardTransitionCount: Int {
        computeTransitionCounts().downward
    }

    // MARK: - Helper Methods

    static func defaultName(for date: Date) -> String {
        "Ride - \(Formatters.fullDayMonth(date))"
    }

    // MARK: - Heart Rate

    /// Decoded heart rate samples (cached to avoid repeated JSON decoding)
    var heartRateSamples: [HeartRateSample] {
        get {
            if let cached = _cachedHeartRateSamples { return cached }
            guard let data = heartRateSamplesData else { return [] }
            do {
                let decoded = try JSONDecoder().decode([HeartRateSample].self, from: data)
                _cachedHeartRateSamples = decoded
                return decoded
            } catch {
                Log.app.error("Failed to decode heartRateSamples: \(error)")
                _cachedHeartRateSamples = []
                return []
            }
        }
        set {
            heartRateSamplesData = try? JSONEncoder().encode(newValue)
            _cachedHeartRateSamples = newValue
        }
    }

    /// Decoded recovery metrics (cached to avoid repeated JSON decoding)
    var recoveryMetrics: RecoveryMetrics? {
        get {
            if let cached = _cachedRecoveryMetrics { return cached }
            guard let data = recoveryMetricsData else { return nil }
            do {
                let decoded = try JSONDecoder().decode(RecoveryMetrics.self, from: data)
                _cachedRecoveryMetrics = .some(decoded)
                return decoded
            } catch {
                Log.app.error("Failed to decode recoveryMetrics: \(error)")
                _cachedRecoveryMetrics = .some(nil)
                return nil
            }
        }
        set {
            recoveryMetricsData = try? JSONEncoder().encode(newValue)
            _cachedRecoveryMetrics = .some(newValue)
        }
    }

    /// Heart rate statistics computed from samples
    var heartRateStatistics: HeartRateStatistics {
        HeartRateStatistics(samples: heartRateSamples)
    }

    /// Whether this ride has heart rate data
    var hasHeartRateData: Bool {
        averageHeartRate > 0 || !heartRateSamples.isEmpty
    }

    /// Formatted average heart rate
    var formattedAverageHeartRate: String {
        guard averageHeartRate > 0 else { return "--" }
        return "\(averageHeartRate) bpm"
    }

    /// Formatted max heart rate
    var formattedMaxHeartRate: String {
        guard maxHeartRate > 0 else { return "--" }
        return "\(maxHeartRate) bpm"
    }

    /// Formatted min heart rate
    var formattedMinHeartRate: String {
        guard minHeartRate > 0 else { return "--" }
        return "\(minHeartRate) bpm"
    }

    // MARK: - Weather

    /// Decoded weather conditions at ride start (cached to avoid repeated JSON decoding)
    var startWeather: WeatherConditions? {
        get {
            if let cached = _cachedStartWeather { return cached }
            guard let data = startWeatherData else { return nil }
            do {
                let decoded = try JSONDecoder().decode(WeatherConditions.self, from: data)
                _cachedStartWeather = .some(decoded)
                return decoded
            } catch {
                Log.app.error("Failed to decode startWeather: \(error)")
                _cachedStartWeather = .some(nil)
                return nil
            }
        }
        set {
            startWeatherData = try? JSONEncoder().encode(newValue)
            _cachedStartWeather = .some(newValue)
        }
    }

    /// Decoded weather conditions at ride end (cached to avoid repeated JSON decoding)
    var endWeather: WeatherConditions? {
        get {
            if let cached = _cachedEndWeather { return cached }
            guard let data = endWeatherData else { return nil }
            do {
                let decoded = try JSONDecoder().decode(WeatherConditions.self, from: data)
                _cachedEndWeather = .some(decoded)
                return decoded
            } catch {
                Log.app.error("Failed to decode endWeather: \(error)")
                _cachedEndWeather = .some(nil)
                return nil
            }
        }
        set {
            endWeatherData = try? JSONEncoder().encode(newValue)
            _cachedEndWeather = .some(newValue)
        }
    }

    /// Weather statistics for the ride
    var weatherStats: WeatherStats {
        WeatherStats(startConditions: startWeather, endConditions: endWeather)
    }

    /// Whether this ride has weather data
    var hasWeatherData: Bool {
        startWeather != nil
    }

    /// Brief weather summary for list display
    var weatherSummary: String? {
        startWeather?.briefSummary
    }

    /// Riding conditions assessment
    var ridingConditionsAssessment: RidingConditions? {
        startWeather?.ridingConditions
    }

    // MARK: - AI Summary

    /// Decoded AI session summary (cached to avoid repeated JSON decoding)
    var aiSummary: SessionSummary? {
        get {
            if let cached = _cachedAISummary { return cached }
            guard let data = aiSummaryData else { return nil }
            do {
                let decoded = try JSONDecoder().decode(SessionSummary.self, from: data)
                _cachedAISummary = .some(decoded)
                return decoded
            } catch {
                Log.app.error("Failed to decode aiSummary: \(error)")
                _cachedAISummary = .some(nil)
                return nil
            }
        }
        set {
            aiSummaryData = try? JSONEncoder().encode(newValue)
            _cachedAISummary = .some(newValue)
        }
    }

    /// Voice notes recorded during the session
    var voiceNotes: [String] {
        get {
            if let cached = _cachedVoiceNotes { return cached }
            guard let data = voiceNotesData else { return [] }
            do {
                let decoded = try JSONDecoder().decode([String].self, from: data)
                _cachedVoiceNotes = decoded
                return decoded
            } catch {
                Log.app.error("Failed to decode voiceNotes: \(error)")
                _cachedVoiceNotes = []
                return []
            }
        }
        set {
            voiceNotesData = try? JSONEncoder().encode(newValue)
            _cachedVoiceNotes = newValue
        }
    }

    /// Whether this ride has an AI summary
    var hasAISummary: Bool {
        aiSummary != nil
    }

    /// Brief summary headline for list display
    var summaryHeadline: String? {
        aiSummary?.headline
    }

    // MARK: - Trim Functionality

    /// Apply trim to ride, removing location points outside the specified time range
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
        _cachedGaitDurations = nil
        _cachedElevationProfile = nil

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
        var gain: Double = 0
        var loss: Double = 0
        for i in 1..<points.count {
            let delta = points[i].altitude - points[i-1].altitude
            if delta > 0 {
                gain += delta
            } else {
                loss += abs(delta)
            }
        }
        elevationGain = gain
        elevationLoss = loss

        // Recalculate max speed from remaining points
        maxSpeed = points.map { $0.speed }.max() ?? 0
    }

    /// Speed anomalies (for showing vehicle detection points on trim timeline)
    var speedAnomalies: [(timestamp: Date, speed: Double)] {
        sortedLocationPoints
            .filter { $0.speed > 15.0 } // > 54 km/h
            .map { (timestamp: $0.timestamp, speed: $0.speed) }
    }
}
