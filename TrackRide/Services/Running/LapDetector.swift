//
//  LapDetector.swift
//  TrackRide
//
//  400m track auto-lap detection using GPS proximity to start point
//

import Foundation
import CoreLocation
import Observation

@Observable
final class LapDetector {
    // MARK: - State

    private(set) var isActive: Bool = false
    private(set) var lapCount: Int = 0
    private(set) var currentLapDistance: Double = 0
    private(set) var lapTimes: [TimeInterval] = []
    private(set) var lastLapTime: TimeInterval = 0
    private(set) var fastestLap: TimeInterval = 0
    private(set) var averageLapTime: TimeInterval = 0

    // MARK: - Configuration

    /// Track length in meters (default 400m)
    var trackLength: Double = 400.0

    /// Proximity threshold to trigger lap (meters)
    var proximityThreshold: Double = 15.0

    /// Minimum distance before allowing lap trigger (prevents double-counting)
    var minimumLapDistance: Double = 350.0

    /// Minimum time between laps (seconds)
    var minimumLapTime: TimeInterval = 45.0

    // MARK: - Private

    private var startLocation: CLLocationCoordinate2D?
    private var lastLocation: CLLocation?
    private var lapStartTime: Date?
    private var totalDistance: Double = 0
    private var lastLapTriggerTime: Date?

    // MARK: - Callbacks

    var onLapCompleted: ((Int, TimeInterval) -> Void)?
    var onApproachingLap: ((Double) -> Void)? // Distance to start

    // MARK: - Audio Coach

    private let audioCoach = AudioCoachManager.shared

    // MARK: - Singleton

    static let shared = LapDetector()

    private init() {}

    // MARK: - Public Methods

    /// Start lap detection at current location
    func start(at location: CLLocationCoordinate2D) {
        startLocation = location
        lapStartTime = Date()
        lastLapTriggerTime = Date()
        lapCount = 0
        lapTimes = []
        currentLapDistance = 0
        totalDistance = 0
        lastLapTime = 0
        fastestLap = 0
        averageLapTime = 0
        isActive = true

        audioCoach.announceTrackModeStart()
    }

    /// Start with manual first lap (runner starts mid-track)
    func startWithManualFirstLap() {
        lapStartTime = Date()
        lastLapTriggerTime = nil
        lapCount = 0
        lapTimes = []
        currentLapDistance = 0
        totalDistance = 0
        isActive = true
        startLocation = nil // Will be set on first manual lap

        audioCoach.announce("Track mode started. Mark your first lap manually.")
    }

    func stop() {
        isActive = false
        startLocation = nil
        lapStartTime = nil
        lastLocation = nil

        if lapCount > 0 {
            audioCoach.announceTrackSessionComplete(lapCount: lapCount)
        }
    }

    /// Process new GPS location
    func processLocation(_ location: CLLocation) {
        guard isActive else { return }

        // Update distance
        if let last = lastLocation {
            let delta = location.distance(from: last)
            // Filter GPS jumps
            if delta < 50 {
                currentLapDistance += delta
                totalDistance += delta
            }
        }
        lastLocation = location

        // Check for lap completion
        guard let start = startLocation else { return }

        let distanceToStart = location.distance(from: CLLocation(
            latitude: start.latitude,
            longitude: start.longitude
        ))

        // Approaching start notification
        if distanceToStart < 50 && distanceToStart > proximityThreshold {
            onApproachingLap?(distanceToStart)
        }

        // Check lap trigger conditions
        let canTriggerLap = shouldTriggerLap(distanceToStart: distanceToStart)

        if canTriggerLap {
            completeLap()
        }
    }

    /// Manual lap trigger
    func triggerManualLap() {
        guard isActive else { return }

        // Set start location on first manual lap if not set
        if startLocation == nil, let location = lastLocation {
            startLocation = location.coordinate
        }

        completeLap()
    }

    // MARK: - Private Methods

    private func shouldTriggerLap(distanceToStart: Double) -> Bool {
        // Must be close to start
        guard distanceToStart <= proximityThreshold else { return false }

        // Must have covered minimum distance
        guard currentLapDistance >= minimumLapDistance else { return false }

        // Must have minimum time since last lap
        if let lastTrigger = lastLapTriggerTime {
            let timeSinceLastLap = Date().timeIntervalSince(lastTrigger)
            guard timeSinceLastLap >= minimumLapTime else { return false }
        }

        return true
    }

    private func completeLap() {
        lapCount += 1

        // Calculate lap time
        let now = Date()
        if let start = lapStartTime {
            lastLapTime = now.timeIntervalSince(start)
            lapTimes.append(lastLapTime)

            // Update fastest lap
            if fastestLap == 0 || lastLapTime < fastestLap {
                fastestLap = lastLapTime
            }

            // Update average
            averageLapTime = lapTimes.reduce(0, +) / Double(lapTimes.count)
        }

        // Reset for next lap
        lapStartTime = now
        lastLapTriggerTime = now
        currentLapDistance = 0

        // Notify
        onLapCompleted?(lapCount, lastLapTime)

        // Audio announcement
        announceLapCompletion()
    }

    private func announceLapCompletion() {
        let previousLapTime: TimeInterval? = lapTimes.count > 1 ? lapTimes[lapTimes.count - 2] : nil
        let isFastest = lastLapTime == fastestLap && lapCount > 1

        audioCoach.announceLapWithComparison(
            lapCount,
            lapTime: lastLapTime,
            previousLapTime: previousLapTime,
            isFastest: isFastest
        )
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int((time.truncatingRemainder(dividingBy: 1)) * 10)

        if minutes > 0 {
            return "\(minutes) \(minutes == 1 ? "minute" : "minutes") \(seconds) seconds"
        } else {
            return "\(seconds) point \(tenths) seconds"
        }
    }

    // MARK: - Computed Properties

    var formattedLastLap: String {
        guard lastLapTime > 0 else { return "--:--" }
        let minutes = Int(lastLapTime) / 60
        let seconds = Int(lastLapTime) % 60
        let tenths = Int((lastLapTime.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }

    var formattedFastestLap: String {
        guard fastestLap > 0 else { return "--:--" }
        let minutes = Int(fastestLap) / 60
        let seconds = Int(fastestLap) % 60
        let tenths = Int((fastestLap.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }

    var formattedAverageLap: String {
        guard averageLapTime > 0 else { return "--:--" }
        let minutes = Int(averageLapTime) / 60
        let seconds = Int(averageLapTime) % 60
        let tenths = Int((averageLapTime.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }

    /// Estimated 400m pace based on lap times
    var estimated400mPace: TimeInterval {
        guard averageLapTime > 0 else { return 0 }
        return averageLapTime * (400.0 / trackLength)
    }

    /// Projected finish time for target distance
    func projectedTime(forDistance targetDistance: Double) -> TimeInterval {
        guard averageLapTime > 0, trackLength > 0 else { return 0 }
        let lapsNeeded = targetDistance / trackLength
        return lapsNeeded * averageLapTime
    }
}

// MARK: - Track Presets

enum TrackPreset: String, CaseIterable {
    case outdoor400m = "400m Outdoor"
    case indoor200m = "200m Indoor"
    case outdoor200m = "200m Outdoor"
    case custom = "Custom"

    var length: Double {
        switch self {
        case .outdoor400m: return 400.0
        case .indoor200m: return 200.0
        case .outdoor200m: return 200.0
        case .custom: return 400.0
        }
    }

    var proximityThreshold: Double {
        switch self {
        case .outdoor400m: return 15.0
        case .indoor200m: return 8.0
        case .outdoor200m: return 10.0
        case .custom: return 15.0
        }
    }

    var minimumLapDistance: Double {
        switch self {
        case .outdoor400m: return 350.0
        case .indoor200m: return 170.0
        case .outdoor200m: return 170.0
        case .custom: return 350.0
        }
    }
}
