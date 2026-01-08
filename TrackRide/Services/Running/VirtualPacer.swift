//
//  VirtualPacer.swift
//  TrackRide
//
//  Virtual pacer for target pace guidance with audio feedback
//

import Foundation
import CoreLocation
import Observation

@Observable
final class VirtualPacer {
    // MARK: - State

    private(set) var isActive: Bool = false
    private(set) var targetPace: TimeInterval = 300 // seconds per km (5:00/km default)
    private(set) var currentPace: TimeInterval = 0
    private(set) var virtualDistance: Double = 0 // Where the virtual pacer is
    private(set) var actualDistance: Double = 0
    private(set) var gapDistance: Double = 0 // Positive = ahead, negative = behind
    private(set) var gapTime: TimeInterval = 0 // Time equivalent of gap

    // MARK: - Configuration

    /// How often to announce pace status (seconds)
    var announcementInterval: TimeInterval = 60.0

    /// Minimum gap change to trigger announcement (meters)
    var gapChangeThreshold: Double = 10.0

    /// Enable/disable automatic announcements
    var autoAnnounce: Bool = true

    /// Announce every km split
    var announceKmSplits: Bool = true

    /// Target distance for the run (0 = no target)
    var targetDistance: Double = 0

    // MARK: - Private

    private var startTime: Date?
    private var lastAnnouncementTime: Date?
    private var lastAnnouncedGap: Double = 0
    private var lastKmAnnounced: Int = 0
    private var recentPaces: [TimeInterval] = []
    private let maxRecentPaces = 10

    // MARK: - Audio Coach

    private let audioCoach = AudioCoachManager.shared

    // MARK: - Singleton

    static let shared = VirtualPacer()

    private init() {}

    // MARK: - Public Methods

    /// Start virtual pacer with target pace
    /// - Parameter pace: Target pace in seconds per kilometer
    func start(targetPace pace: TimeInterval) {
        targetPace = pace
        startTime = Date()
        lastAnnouncementTime = Date()
        virtualDistance = 0
        actualDistance = 0
        gapDistance = 0
        gapTime = 0
        currentPace = 0
        lastAnnouncedGap = 0
        lastKmAnnounced = 0
        recentPaces = []
        isActive = true

        audioCoach.announceVirtualPacerStart(targetPace: targetPace)
    }

    /// Start with target finish time for a distance
    func start(targetTime: TimeInterval, forDistance distance: Double) {
        targetDistance = distance
        let pace = targetTime / (distance / 1000)
        start(targetPace: pace)

        let timeStr = formatDuration(targetTime)
        let distStr = formatDistance(distance)
        audioCoach.announce("Target: \(distStr) in \(timeStr)")
    }

    func stop() {
        guard isActive else { return }
        isActive = false

        // Final summary
        if actualDistance > 100 {
            announceFinalSummary()
        }

        startTime = nil
    }

    /// Update with current run data
    func update(distance: Double, elapsedTime: TimeInterval) {
        guard isActive, let start = startTime else { return }

        actualDistance = distance

        // Calculate where virtual pacer should be
        // Virtual pacer travels at constant target pace
        let elapsedSeconds = Date().timeIntervalSince(start)
        let targetSpeed = 1000.0 / targetPace // meters per second
        virtualDistance = elapsedSeconds * targetSpeed

        // Calculate gap
        gapDistance = actualDistance - virtualDistance
        gapTime = gapDistance / targetSpeed

        // Calculate current pace (rolling average)
        if distance > 0 && elapsedTime > 0 {
            let instantPace = elapsedTime / (distance / 1000)
            recentPaces.append(instantPace)
            if recentPaces.count > maxRecentPaces {
                recentPaces.removeFirst()
            }
            currentPace = recentPaces.reduce(0, +) / Double(recentPaces.count)
        }

        // Check for announcements
        checkForAnnouncements()
    }

    /// Force an immediate status announcement
    func announceStatus() {
        announceCurrentStatus()
    }

    /// Adjust target pace mid-run
    func adjustPace(to newPace: TimeInterval) {
        let oldPace = targetPace
        targetPace = newPace

        let change = oldPace - newPace
        let direction = change > 0 ? "faster" : "slower"
        let paceStr = formatPace(newPace)

        audioCoach.announce("Target pace adjusted to \(paceStr). \(abs(Int(change))) seconds \(direction).")
    }

    // MARK: - Private Methods

    private func checkForAnnouncements() {
        guard autoAnnounce else { return }

        let now = Date()

        // Km split announcements
        if announceKmSplits {
            let currentKm = Int(actualDistance / 1000)
            if currentKm > lastKmAnnounced && actualDistance > 100 {
                lastKmAnnounced = currentKm
                announceKmSplit(km: currentKm)
            }
        }

        // Regular interval announcements
        if let lastAnnounce = lastAnnouncementTime {
            let timeSinceAnnouncement = now.timeIntervalSince(lastAnnounce)

            if timeSinceAnnouncement >= announcementInterval {
                // Check if gap has changed significantly
                let gapChange = abs(gapDistance - lastAnnouncedGap)
                if gapChange >= gapChangeThreshold || timeSinceAnnouncement >= announcementInterval * 2 {
                    announceCurrentStatus()
                    lastAnnouncementTime = now
                    lastAnnouncedGap = gapDistance
                }
            }
        }
    }

    private func announceKmSplit(km: Int) {
        guard let start = startTime else { return }

        let elapsed = Date().timeIntervalSince(start)
        let splitPace = elapsed / Double(km)

        let remaining: Double? = targetDistance > 0 ? targetDistance - actualDistance : nil

        audioCoach.announceKmSplit(
            km: km,
            averagePace: splitPace,
            gapMeters: abs(gapDistance) > 5 ? gapDistance : nil,
            remaining: remaining
        )
    }

    private func announceCurrentStatus() {
        // Announce current pace
        audioCoach.announcePace(currentPace)

        // Announce gap status if significant
        if abs(gapDistance) > 5 {
            audioCoach.announceGapStatus(
                gapSeconds: gapTime,
                gapMeters: gapDistance,
                isAhead: gapDistance > 0
            )

            // Suggest pace adjustment if way off
            if abs(gapTime) > 10 {
                let neededPace = calculateNeededPace()
                if neededPace > 0 {
                    let neededStr = formatPace(neededPace)
                    audioCoach.announce("Need \(neededStr) to get back on track")
                }
            }
        } else {
            audioCoach.announce("Right on target pace")
        }
    }

    private func announceFinalSummary() {
        guard let start = startTime else { return }

        let totalTime = Date().timeIntervalSince(start)
        let avgPace = totalTime / (actualDistance / 1000)

        audioCoach.announceRunComplete(
            distance: actualDistance,
            duration: totalTime,
            averagePace: avgPace,
            targetPace: targetPace
        )
    }

    private func calculateNeededPace() -> TimeInterval {
        // Calculate pace needed to finish at target if we have a target distance
        guard targetDistance > 0, let start = startTime else { return 0 }

        let elapsed = Date().timeIntervalSince(start)
        let targetTime = targetDistance / 1000 * targetPace
        let remainingTime = targetTime - elapsed
        let remainingDistance = targetDistance - actualDistance

        guard remainingTime > 0, remainingDistance > 0 else { return 0 }

        return remainingTime / (remainingDistance / 1000)
    }

    // MARK: - Formatting Helpers

    private func formatPace(_ pace: TimeInterval) -> String {
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return "\(minutes) \(seconds < 10 ? "oh" : "") \(seconds)"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return "\(hours) hour\(hours > 1 ? "s" : "") \(minutes) minute\(minutes != 1 ? "s" : "")"
        } else if minutes > 0 {
            return "\(minutes) minute\(minutes != 1 ? "s" : "") \(seconds) second\(seconds != 1 ? "s" : "")"
        } else {
            return "\(seconds) second\(seconds != 1 ? "s" : "")"
        }
    }

    private func formatDistance(_ distance: Double) -> String {
        if distance >= 1000 {
            let km = distance / 1000
            if km == floor(km) {
                return "\(Int(km)) kilometer\(km != 1 ? "s" : "")"
            }
            return String(format: "%.1f kilometers", km)
        }
        return "\(Int(distance)) meters"
    }

    // MARK: - Computed Properties

    var formattedCurrentPace: String {
        let minutes = Int(currentPace) / 60
        let seconds = Int(currentPace) % 60
        return String(format: "%d:%02d/km", minutes, seconds)
    }

    var formattedTargetPace: String {
        let minutes = Int(targetPace) / 60
        let seconds = Int(targetPace) % 60
        return String(format: "%d:%02d/km", minutes, seconds)
    }

    var formattedGap: String {
        let prefix = gapDistance >= 0 ? "+" : ""
        if abs(gapTime) >= 1 {
            return String(format: "%@%.0fs", prefix, gapTime)
        }
        return String(format: "%@%.0fm", prefix, gapDistance)
    }

    var gapStatus: GapStatus {
        if gapTime > 10 { return .wellAhead }
        if gapTime > 3 { return .slightlyAhead }
        if gapTime > -3 { return .onPace }
        if gapTime > -10 { return .slightlyBehind }
        return .wellBehind
    }

    var isAhead: Bool { gapDistance > 0 }
    var isBehind: Bool { gapDistance < 0 }
    var isOnPace: Bool { abs(gapTime) <= 3 }
}

// MARK: - Gap Status

enum GapStatus {
    case wellAhead
    case slightlyAhead
    case onPace
    case slightlyBehind
    case wellBehind

    var color: String {
        switch self {
        case .wellAhead: return "blue"
        case .slightlyAhead: return "green"
        case .onPace: return "green"
        case .slightlyBehind: return "yellow"
        case .wellBehind: return "red"
        }
    }

    var icon: String {
        switch self {
        case .wellAhead: return "chevron.up.2"
        case .slightlyAhead: return "chevron.up"
        case .onPace: return "equal"
        case .slightlyBehind: return "chevron.down"
        case .wellBehind: return "chevron.down.2"
        }
    }

    var description: String {
        switch self {
        case .wellAhead: return "Well Ahead"
        case .slightlyAhead: return "Ahead"
        case .onPace: return "On Pace"
        case .slightlyBehind: return "Behind"
        case .wellBehind: return "Well Behind"
        }
    }
}

// MARK: - Pace Presets

struct PacePreset: Identifiable {
    let id = UUID()
    let name: String
    let pacePerKm: TimeInterval
    let description: String

    var formattedPace: String {
        let minutes = Int(pacePerKm) / 60
        let seconds = Int(pacePerKm) % 60
        return String(format: "%d:%02d/km", minutes, seconds)
    }

    static let presets: [PacePreset] = [
        PacePreset(name: "Easy", pacePerKm: 360, description: "6:00/km - Recovery pace"),
        PacePreset(name: "Steady", pacePerKm: 330, description: "5:30/km - Comfortable endurance"),
        PacePreset(name: "Tempo", pacePerKm: 300, description: "5:00/km - Comfortably hard"),
        PacePreset(name: "Threshold", pacePerKm: 270, description: "4:30/km - Race pace effort"),
        PacePreset(name: "Fast", pacePerKm: 240, description: "4:00/km - Hard interval pace"),
        PacePreset(name: "Sprint", pacePerKm: 210, description: "3:30/km - Near max effort")
    ]

    // Race pace presets
    static func forRace(distance: Double, targetTime: TimeInterval) -> PacePreset {
        let pace = targetTime / (distance / 1000)
        let name = "\(Int(distance / 1000))K Race"
        let formattedTime = {
            let mins = Int(targetTime) / 60
            let secs = Int(targetTime) % 60
            return "\(mins):\(String(format: "%02d", secs))"
        }()
        return PacePreset(name: name, pacePerKm: pace, description: "Target: \(formattedTime)")
    }
}
