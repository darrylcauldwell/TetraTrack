//
//  AudioCoachManager.swift
//  TrackRide
//
//  Voice coaching with AVSpeechSynthesizer for ride announcements
//

import Foundation
import AVFoundation
import AudioToolbox
import Observation
import os
#if os(iOS)
import UIKit
#endif

@Observable
final class AudioCoachManager: AudioCoaching {
    // MARK: - Settings

    var isEnabled: Bool = true
    var volume: Float = 0.8
    var speechRate: Float = 0.5 // 0.0-1.0, default is 0.5

    // Announcement toggles
    var announceGaitChanges: Bool = true
    var announceDistanceMilestones: Bool = true
    var announceTimeMilestones: Bool = true
    var announceHeartRateZones: Bool = true
    var announceWorkoutIntervals: Bool = true
    var announceRunningFormReminders: Bool = true

    // Running form reminder interval (in seconds)
    var formReminderIntervalSeconds: TimeInterval = 300 // Every 5 minutes by default

    // Milestone intervals
    var distanceMilestoneKm: Double = 1.0
    var timeMilestoneMinutes: Int = 15

    // MARK: - State

    private(set) var isSpeaking: Bool = false
    private(set) var lastAnnouncement: String?

    // MARK: - Private

    private let synthesizer = AVSpeechSynthesizer()
    private var lastDistanceMilestone: Double = 0
    private var lastTimeMilestone: TimeInterval = 0
    private var lastHeartRateZone: HeartRateZone?
    private var lastGait: GaitType = .stationary

    // Queue for announcements to avoid overlapping
    private var announcementQueue: [String] = []
    private var isProcessingQueue: Bool = false

    // MARK: - Singleton

    static let shared = AudioCoachManager()

    private init() {
        setupAudioSession()
    }

    // MARK: - Audio Session

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        } catch {
            Log.audio.error("Failed to setup audio session: \(error)")
        }
    }

    // MARK: - Public Methods

    func startSession() {
        lastDistanceMilestone = 0
        lastTimeMilestone = 0
        lastHeartRateZone = nil
        lastGait = .stationary
        announcementQueue.removeAll()

        if isEnabled {
            announce("Ride started. Have a great ride!")
        }
    }

    func endSession(distance: Double, duration: TimeInterval) {
        guard isEnabled else { return }

        let distanceKm = distance / 1000.0
        let minutes = Int(duration) / 60

        if distanceKm >= 1.0 {
            announce("Ride complete. You covered \(String(format: "%.1f", distanceKm)) kilometres in \(minutes) minutes.")
        } else {
            let meters = Int(distance)
            announce("Ride complete. You covered \(meters) metres in \(minutes) minutes.")
        }
    }

    // MARK: - Session Summary Readback

    /// Read AI-generated session summary aloud
    func announceSessionSummary(_ narrative: String) {
        guard isEnabled else { return }

        // Add a brief pause before reading summary
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.announce(narrative)
        }
    }

    // MARK: - Periodic Safety Status

    private var lastSafetyAnnouncement: Date?
    private var safetyAnnouncementInterval: TimeInterval = 20 * 60  // 20 minutes

    /// Announce safety status periodically during session
    func processSafetyStatus(elapsedTime: TimeInterval, fallDetectionActive: Bool) {
        guard isEnabled else { return }

        // Check if enough time has passed since last announcement
        let now = Date()
        if let lastAnnouncement = lastSafetyAnnouncement,
           now.timeIntervalSince(lastAnnouncement) < safetyAnnouncementInterval {
            return
        }

        // Only announce after at least 20 minutes of session time
        guard elapsedTime >= safetyAnnouncementInterval else { return }

        lastSafetyAnnouncement = now

        var message = "Status check. Tracking active"
        if fallDetectionActive {
            message += ". Fall detection on"
        }
        message += ". All systems normal."

        announce(message)
    }

    /// Reset safety announcement timer (call when session starts)
    func resetSafetyStatus() {
        lastSafetyAnnouncement = nil
    }

    /// Announce safety status on demand
    func announceSafetyStatus(fallDetectionActive: Bool) {
        guard isEnabled else { return }

        var message = "Tracking is active"
        if fallDetectionActive {
            message += ". Fall detection is on"
        }
        message += ". All systems running normally."

        announce(message)
    }

    /// Read full session summary with metrics
    func announceDetailedSummary(
        headline: String,
        praise: [String],
        improvements: [String],
        encouragement: String
    ) {
        guard isEnabled else { return }

        var narrative = headline + ". "

        if !praise.isEmpty {
            narrative += "Great work on: " + praise.prefix(3).joined(separator: ", ") + ". "
        }

        if !improvements.isEmpty {
            narrative += "For next time, consider: " + improvements.prefix(2).joined(separator: ", ") + ". "
        }

        narrative += encouragement

        announceSessionSummary(narrative)
    }

    // MARK: - Gait Announcements

    func processGaitChange(from oldGait: GaitType, to newGait: GaitType) {
        guard isEnabled, announceGaitChanges else { return }
        guard oldGait != newGait, newGait != .stationary else { return }

        // Avoid announcing too frequently
        guard newGait != lastGait else { return }
        lastGait = newGait

        let message: String
        switch newGait {
        case .walk:
            message = "Walking"
        case .trot:
            message = "Trotting"
        case .canter:
            message = "Cantering"
        case .gallop:
            message = "Galloping"
        case .stationary:
            return
        }

        announce(message)
    }

    // MARK: - Distance Milestones

    func processDistance(_ distance: Double) {
        guard isEnabled, announceDistanceMilestones else { return }

        let distanceKm = distance / 1000.0
        let milestoneKm = floor(distanceKm / distanceMilestoneKm) * distanceMilestoneKm

        if milestoneKm > lastDistanceMilestone && milestoneKm > 0 {
            lastDistanceMilestone = milestoneKm

            if milestoneKm == 1.0 {
                announce("One kilometre")
            } else {
                announce("\(Int(milestoneKm)) kilometres")
            }
        }
    }

    // MARK: - Time Milestones

    func processTime(_ elapsed: TimeInterval) {
        guard isEnabled, announceTimeMilestones else { return }

        let milestoneSeconds = Double(timeMilestoneMinutes * 60)
        let currentMilestone = floor(elapsed / milestoneSeconds) * milestoneSeconds

        if currentMilestone > lastTimeMilestone && currentMilestone > 0 {
            lastTimeMilestone = currentMilestone

            let minutes = Int(currentMilestone) / 60
            if minutes == 1 {
                announce("One minute")
            } else if minutes < 60 {
                announce("\(minutes) minutes")
            } else {
                let hours = minutes / 60
                let remainingMinutes = minutes % 60
                if remainingMinutes == 0 {
                    announce("\(hours) hour\(hours > 1 ? "s" : "")")
                } else {
                    announce("\(hours) hour\(hours > 1 ? "s" : "") \(remainingMinutes) minutes")
                }
            }
        }
    }

    // MARK: - Heart Rate Zones

    func processHeartRateZone(_ zone: HeartRateZone) {
        guard isEnabled, announceHeartRateZones else { return }
        guard zone != lastHeartRateZone else { return }

        lastHeartRateZone = zone

        let message: String
        switch zone {
        case .zone1:
            message = "Heart rate zone 1. Recovery"
        case .zone2:
            message = "Heart rate zone 2. Endurance"
        case .zone3:
            message = "Heart rate zone 3. Tempo"
        case .zone4:
            message = "Heart rate zone 4. Threshold"
        case .zone5:
            message = "Heart rate zone 5. Maximum"
        }

        announce(message)
    }

    // MARK: - Workout Intervals

    func announceWorkoutBlock(name: String, duration: TimeInterval, gait: GaitType?) {
        guard isEnabled, announceWorkoutIntervals else { return }

        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60

        var message = name

        if let gait = gait {
            message += ". \(gait.rawValue.capitalized)"
        }

        if minutes > 0 && seconds > 0 {
            message += " for \(minutes) minutes \(seconds) seconds"
        } else if minutes > 0 {
            message += " for \(minutes) minute\(minutes > 1 ? "s" : "")"
        } else {
            message += " for \(seconds) seconds"
        }

        announce(message)
    }

    func announceWorkoutComplete() {
        guard isEnabled, announceWorkoutIntervals else { return }
        announce("Workout complete. Great job!")
    }

    func announceCountdown(_ seconds: Int) {
        guard isEnabled, announceWorkoutIntervals else { return }

        if seconds <= 5 && seconds > 0 {
            announce("\(seconds)")
        } else if seconds == 10 {
            announce("10 seconds")
        } else if seconds == 30 {
            announce("30 seconds remaining")
        }
    }

    // MARK: - Custom Announcements

    func announce(_ message: String) {
        guard isEnabled else { return }

        announcementQueue.append(message)
        processQueue()
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        announcementQueue.removeAll()
        isProcessingQueue = false
        isSpeaking = false
    }

    // MARK: - Private Methods

    private func processQueue() {
        guard !isProcessingQueue, !announcementQueue.isEmpty else { return }

        isProcessingQueue = true
        speakNext()
    }

    private func speakNext() {
        guard !announcementQueue.isEmpty else {
            isProcessingQueue = false
            isSpeaking = false
            return
        }

        let message = announcementQueue.removeFirst()
        lastAnnouncement = message

        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = speechRate
        utterance.volume = volume
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.pitchMultiplier = 1.0

        // Add slight pause between announcements
        utterance.postUtteranceDelay = 0.3

        isSpeaking = true

        // Use delegate to chain announcements
        synthesizer.speak(utterance)

        // Schedule next announcement after this one completes
        let estimatedDuration = Double(message.count) * 0.05 + 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + estimatedDuration) { [weak self] in
            self?.speakNext()
        }
    }
}

// MARK: - UserDefaults Persistence

extension AudioCoachManager {
    private enum Keys {
        static let isEnabled = "audioCoach.isEnabled"
        static let volume = "audioCoach.volume"
        static let speechRate = "audioCoach.speechRate"
        static let announceGaitChanges = "audioCoach.announceGaitChanges"
        static let announceDistanceMilestones = "audioCoach.announceDistanceMilestones"
        static let announceTimeMilestones = "audioCoach.announceTimeMilestones"
        static let announceHeartRateZones = "audioCoach.announceHeartRateZones"
        static let announceWorkoutIntervals = "audioCoach.announceWorkoutIntervals"
        static let announceRunningFormReminders = "audioCoach.announceRunningFormReminders"
        static let distanceMilestoneKm = "audioCoach.distanceMilestoneKm"
        static let timeMilestoneMinutes = "audioCoach.timeMilestoneMinutes"
        static let formReminderIntervalSeconds = "audioCoach.formReminderIntervalSeconds"
    }

    func loadSettings() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: Keys.isEnabled) != nil {
            isEnabled = defaults.bool(forKey: Keys.isEnabled)
        }
        if defaults.object(forKey: Keys.volume) != nil {
            volume = defaults.float(forKey: Keys.volume)
        }
        if defaults.object(forKey: Keys.speechRate) != nil {
            speechRate = defaults.float(forKey: Keys.speechRate)
        }
        if defaults.object(forKey: Keys.announceGaitChanges) != nil {
            announceGaitChanges = defaults.bool(forKey: Keys.announceGaitChanges)
        }
        if defaults.object(forKey: Keys.announceDistanceMilestones) != nil {
            announceDistanceMilestones = defaults.bool(forKey: Keys.announceDistanceMilestones)
        }
        if defaults.object(forKey: Keys.announceTimeMilestones) != nil {
            announceTimeMilestones = defaults.bool(forKey: Keys.announceTimeMilestones)
        }
        if defaults.object(forKey: Keys.announceHeartRateZones) != nil {
            announceHeartRateZones = defaults.bool(forKey: Keys.announceHeartRateZones)
        }
        if defaults.object(forKey: Keys.announceWorkoutIntervals) != nil {
            announceWorkoutIntervals = defaults.bool(forKey: Keys.announceWorkoutIntervals)
        }
        if defaults.object(forKey: Keys.announceRunningFormReminders) != nil {
            announceRunningFormReminders = defaults.bool(forKey: Keys.announceRunningFormReminders)
        }
        if defaults.object(forKey: Keys.distanceMilestoneKm) != nil {
            distanceMilestoneKm = defaults.double(forKey: Keys.distanceMilestoneKm)
        }
        if defaults.object(forKey: Keys.timeMilestoneMinutes) != nil {
            timeMilestoneMinutes = defaults.integer(forKey: Keys.timeMilestoneMinutes)
        }
        if defaults.object(forKey: Keys.formReminderIntervalSeconds) != nil {
            formReminderIntervalSeconds = defaults.double(forKey: Keys.formReminderIntervalSeconds)
        }
    }

    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(isEnabled, forKey: Keys.isEnabled)
        defaults.set(volume, forKey: Keys.volume)
        defaults.set(speechRate, forKey: Keys.speechRate)
        defaults.set(announceGaitChanges, forKey: Keys.announceGaitChanges)
        defaults.set(announceDistanceMilestones, forKey: Keys.announceDistanceMilestones)
        defaults.set(announceTimeMilestones, forKey: Keys.announceTimeMilestones)
        defaults.set(announceHeartRateZones, forKey: Keys.announceHeartRateZones)
        defaults.set(announceWorkoutIntervals, forKey: Keys.announceWorkoutIntervals)
        defaults.set(announceRunningFormReminders, forKey: Keys.announceRunningFormReminders)
        defaults.set(distanceMilestoneKm, forKey: Keys.distanceMilestoneKm)
        defaults.set(timeMilestoneMinutes, forKey: Keys.timeMilestoneMinutes)
        defaults.set(formReminderIntervalSeconds, forKey: Keys.formReminderIntervalSeconds)
    }
}

// MARK: - Running Announcements

extension AudioCoachManager {
    /// Announce running pace
    func announcePace(_ paceSecondsPerKm: TimeInterval) {
        let message = "Current pace \(formatPaceForSpeech(paceSecondsPerKm))"
        announce(message)
    }

    /// Announce lap completion for track running
    func announceLap(_ lapNumber: Int, lapTime: TimeInterval) {
        let timeStr = formatTimeForSpeech(lapTime)
        announce("Lap \(lapNumber). \(timeStr)")
    }

    /// Announce lap with comparison to previous
    func announceLapWithComparison(_ lapNumber: Int, lapTime: TimeInterval, previousLapTime: TimeInterval?, isFastest: Bool) {
        var message = "Lap \(lapNumber). \(formatTimeForSpeech(lapTime))."

        if let previous = previousLapTime {
            let difference = lapTime - previous
            if abs(difference) > 1 {
                if difference < 0 {
                    message += " \(formatTimeForSpeech(abs(difference))) faster."
                } else {
                    message += " \(formatTimeForSpeech(difference)) slower."
                }
            } else {
                message += " Even pace."
            }
        }

        if isFastest && lapNumber > 1 {
            message += " Fastest lap!"
        }

        announce(message)
    }

    /// Announce virtual pacer gap status
    func announceGapStatus(gapSeconds: TimeInterval, gapMeters: Double, isAhead: Bool) {
        var message = ""
        let absGapSecs = Int(abs(gapSeconds))
        let absGapMeters = Int(abs(gapMeters))

        if isAhead {
            if absGapSecs > 0 {
                message = "\(absGapSecs) seconds ahead of target."
            } else {
                message = "\(absGapMeters) meters ahead."
            }
        } else {
            if absGapSecs > 0 {
                message = "\(absGapSecs) seconds behind target."
            } else {
                message = "\(absGapMeters) meters behind."
            }
        }

        announce(message)
    }

    /// Announce km split for running
    func announceKmSplit(km: Int, averagePace: TimeInterval, gapMeters: Double?, remaining: Double?) {
        var message = "Kilometer \(km). Average pace \(formatPaceForSpeech(averagePace))."

        if let gap = gapMeters, abs(gap) > 5 {
            if gap > 0 {
                message += " \(Int(gap)) meters ahead."
            } else {
                message += " \(Int(abs(gap))) meters behind."
            }
        } else if gapMeters != nil {
            message += " On target."
        }

        if let rem = remaining, rem > 0 {
            message += " \(formatDistanceForSpeech(rem)) to go."
        }

        announce(message)
    }

    /// Announce interval start for running
    func announceRunningIntervalStart(name: String, targetPace: TimeInterval?) {
        var message = "\(name) starting"
        if let pace = targetPace {
            message += ". Target pace \(formatPaceForSpeech(pace))"
        }
        announce(message)
    }

    /// Announce interval rest
    func announceIntervalRest(duration: TimeInterval) {
        let seconds = Int(duration)
        if seconds >= 60 {
            let mins = seconds / 60
            announce("Rest for \(mins) minute\(mins > 1 ? "s" : "")")
        } else {
            announce("Rest for \(seconds) seconds")
        }
    }

    /// Countdown for running intervals
    func runningCountdown(_ seconds: Int) {
        if seconds <= 5 && seconds > 0 {
            announce("\(seconds)")
        } else if seconds == 10 {
            announce("10 seconds")
        }
    }

    /// Announce track mode start
    func announceTrackModeStart() {
        announce("Track mode started. Lap detection active.")
    }

    /// Announce track session complete
    func announceTrackSessionComplete(lapCount: Int) {
        announce("Track session complete. \(lapCount) laps recorded.")
    }

    /// Announce virtual pacer start
    func announceVirtualPacerStart(targetPace: TimeInterval) {
        announce("Virtual pacer started at \(formatPaceForSpeech(targetPace)).")
    }

    /// Announce run complete summary
    func announceRunComplete(distance: Double, duration: TimeInterval, averagePace: TimeInterval, targetPace: TimeInterval?) {
        var message = "Run complete. \(formatDistanceForSpeech(distance)) in \(formatDurationForSpeech(duration)). Average pace \(formatPaceForSpeech(averagePace))."

        if let target = targetPace {
            let diff = averagePace - target
            if abs(diff) > 5 {
                if diff < 0 {
                    message += " \(Int(abs(diff))) seconds per kilometer faster than target."
                } else {
                    message += " \(Int(diff)) seconds per kilometer slower than target."
                }
            } else {
                message += " Target pace achieved!"
            }
        }

        announce(message)
    }

    // MARK: - Running Cadence Feedback

    private static var lastCadenceWarning: Date?
    private static var lastCadenceValue: Int = 0

    /// Optimal cadence range for running (steps per minute)
    private static let optimalCadenceRange = 170...180

    /// Announce cadence feedback if outside optimal range
    func processCadence(_ cadence: Int) {
        guard isEnabled else { return }

        // Throttle cadence warnings to every 30 seconds
        if let lastWarning = Self.lastCadenceWarning,
           Date().timeIntervalSince(lastWarning) < 30 {
            return
        }

        // Only announce if significantly outside optimal range
        if cadence < Self.optimalCadenceRange.lowerBound - 5 {
            Self.lastCadenceWarning = Date()
            announce("Cadence \(cadence). Try to increase your step rate")
        } else if cadence > Self.optimalCadenceRange.upperBound + 10 {
            Self.lastCadenceWarning = Date()
            announce("Cadence \(cadence). You can slow your step rate")
        }

        Self.lastCadenceValue = cadence
    }

    /// Announce current cadence on demand
    func announceCadence(_ cadence: Int) {
        guard isEnabled else { return }

        var message = "Cadence \(cadence) steps per minute"
        if Self.optimalCadenceRange.contains(cadence) {
            message += ". Good rhythm"
        } else if cadence < Self.optimalCadenceRange.lowerBound {
            message += ". Try shorter, quicker steps"
        } else {
            message += ". Slightly high"
        }

        announce(message)
    }

    /// Announce pace alert when significantly off target
    func announcePaceAlert(currentPace: TimeInterval, targetPace: TimeInterval) {
        guard isEnabled else { return }

        let difference = currentPace - targetPace
        let absDiff = Int(abs(difference))

        // Only alert if more than 15 seconds per km off target
        guard absDiff > 15 else { return }

        if difference > 0 {
            announce("Pace warning. \(absDiff) seconds per kilometre slower than target. Pick it up!")
        } else {
            announce("Pace warning. \(absDiff) seconds per kilometre faster than target. Ease off")
        }
    }

    // MARK: - Running Format Helpers

    private func formatPaceForSpeech(_ pace: TimeInterval) -> String {
        pace.spokenPace
    }

    private func formatTimeForSpeech(_ time: TimeInterval) -> String {
        time.spokenLapTime
    }

    private func formatDistanceForSpeech(_ distance: Double) -> String {
        distance.spokenDistance
    }

    private func formatDurationForSpeech(_ duration: TimeInterval) -> String {
        duration.spokenDuration
    }
}

// MARK: - Cross Country Announcements

extension AudioCoachManager {
    private static var lastTimeFaultWarning: Date?
    private static var lastSpeedingWarning: Date?

    /// Announce 10 seconds before minute marker with triple haptic + beep
    func announceXCMinuteWarning(minute: Int) {
        guard isEnabled else { return }

        // Triple haptic feedback
        triggerXCHaptic(.minuteMarker)

        // Beep sound
        playXCBeep()

        announce("\(minute) minute\(minute > 1 ? "s" : "") approaching")
    }

    /// Announce time fault warning if >20s off pace
    func announceXCTimeFault(secondsOff: Int) {
        guard isEnabled else { return }

        // Throttle warnings to every 10 seconds
        if let lastWarning = Self.lastTimeFaultWarning,
           Date().timeIntervalSince(lastWarning) < 10 {
            return
        }
        Self.lastTimeFaultWarning = Date()

        // Urgent double haptic
        triggerXCHaptic(.timeFault)

        let absSeconds = abs(secondsOff)
        if secondsOff > 0 {
            announce("Time fault warning. \(absSeconds) seconds slow")
        } else {
            announce("Time fault warning. \(absSeconds) seconds fast")
        }
    }

    /// Announce speeding penalty warning if >15s early
    func announceXCSpeedingWarning() {
        guard isEnabled else { return }

        // Throttle warnings to every 15 seconds
        if let lastWarning = Self.lastSpeedingWarning,
           Date().timeIntervalSince(lastWarning) < 15 {
            return
        }
        Self.lastSpeedingWarning = Date()

        // Warning haptic
        triggerXCHaptic(.speeding)

        announce("Slow down. Speeding penalty risk")
    }

    /// Announce optimum time status at finish
    func announceXCFinish(timeDifference: TimeInterval) {
        guard isEnabled else { return }

        let absSeconds = Int(abs(timeDifference))

        if absSeconds <= 5 {
            announce("Excellent! Finished within optimum time")
        } else if timeDifference > 0 {
            announce("Finished \(absSeconds) seconds over optimum time")
        } else {
            announce("Finished \(absSeconds) seconds under optimum time. Possible speeding penalty")
        }
    }

    // MARK: - XC Haptic Feedback

    enum XCHapticType {
        case minuteMarker   // Triple haptic
        case timeFault      // Urgent double haptic
        case speeding       // Warning haptic
    }

    private func triggerXCHaptic(_ type: XCHapticType) {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()

        switch type {
        case .minuteMarker:
            // Triple haptic
            generator.notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                generator.notificationOccurred(.success)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                generator.notificationOccurred(.success)
            }

        case .timeFault:
            // Urgent double haptic
            generator.notificationOccurred(.warning)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.notificationOccurred(.warning)
            }

        case .speeding:
            // Single warning haptic
            generator.notificationOccurred(.error)
        }
        #endif
    }

    private func playXCBeep() {
        // Play system sound for minute marker
        #if os(iOS)
        AudioServicesPlaySystemSound(1057) // Short beep sound
        #endif
    }
}

// MARK: - Running Form Reminders

extension AudioCoachManager {
    /// Available running form cues
    enum RunningFormCue: String, CaseIterable {
        case shortenStride = "Shorten your stride"
        case focusOnCore = "Focus on your core"
        case weightOverCentre = "Weight over centre of gravity"
        case highKnees = "High knees"
        case lightFeet = "Light feet"
        case relaxShoulders = "Relax your shoulders"
        case armsAt90 = "Arms at ninety degrees"
        case lookAhead = "Look ahead, not down"
        case breatheRhythmically = "Breathe rhythmically"
        case quickTurnover = "Quick foot turnover"

        var spokenText: String {
            rawValue
        }

        /// Get a contextual tip to accompany the cue
        var tip: String? {
            switch self {
            case .shortenStride:
                return "land beneath your hips"
            case .focusOnCore:
                return "engage your abs"
            case .weightOverCentre:
                return "stay tall and balanced"
            case .highKnees:
                return "drive your knees forward"
            case .lightFeet:
                return "quick and quiet footfalls"
            case .relaxShoulders:
                return "drop any tension"
            case .armsAt90:
                return "swing forward and back"
            case .lookAhead:
                return "keep your chin level"
            case .breatheRhythmically:
                return "match breaths to steps"
            case .quickTurnover:
                return "faster cadence, not longer strides"
            }
        }
    }

    // Track form reminder state
    private static var lastFormReminderTime: Date?
    private static var formCueIndex: Int = 0
    private static var isRunningSessionActive: Bool = false

    /// Start tracking form reminders for a running session
    func startRunningFormReminders() {
        Self.lastFormReminderTime = Date()
        Self.formCueIndex = 0
        Self.isRunningSessionActive = true
    }

    /// Stop tracking form reminders
    func stopRunningFormReminders() {
        Self.isRunningSessionActive = false
        Self.lastFormReminderTime = nil
    }

    /// Process elapsed time and trigger form reminder if interval has passed
    func processRunningFormReminder(elapsedTime: TimeInterval) {
        guard isEnabled, announceRunningFormReminders, Self.isRunningSessionActive else { return }

        let now = Date()

        // Check if enough time has passed since last reminder
        if let lastReminder = Self.lastFormReminderTime {
            let timeSinceLastReminder = now.timeIntervalSince(lastReminder)
            if timeSinceLastReminder < formReminderIntervalSeconds {
                return
            }
        }

        // Don't start form reminders until at least 2 minutes into the run
        guard elapsedTime >= 120 else { return }

        Self.lastFormReminderTime = now
        announceNextFormCue()
    }

    /// Announce the next form cue in rotation
    private func announceNextFormCue() {
        let cues = RunningFormCue.allCases
        let cue = cues[Self.formCueIndex % cues.count]

        var message = cue.spokenText
        if let tip = cue.tip {
            message += ". \(tip)"
        }

        announce(message)

        // Advance to next cue for variety
        Self.formCueIndex += 1
    }

    /// Announce a specific form cue on demand
    func announceFormCue(_ cue: RunningFormCue, withTip: Bool = true) {
        guard isEnabled else { return }

        var message = cue.spokenText
        if withTip, let tip = cue.tip {
            message += ". \(tip)"
        }

        announce(message)
    }

    /// Announce form correction based on detected issues
    func announceFormCorrection(for issue: RunningFormIssue) {
        guard isEnabled, announceRunningFormReminders else { return }

        let message: String
        switch issue {
        case .overstriding:
            message = "Shorten your stride. Land beneath your hips, not in front"
        case .lowCadence:
            message = "Quick foot turnover. Faster steps, not longer strides"
        case .highBounce:
            message = "Light feet. Reduce vertical bounce, move forward"
        case .tensionDetected:
            message = "Relax your shoulders. Drop any tension in your upper body"
        case .slowTurnover:
            message = "High knees. Drive your knees forward for power"
        }

        announce(message)
    }

    /// Announce encouragement with form tip
    func announceFormEncouragement() {
        guard isEnabled else { return }

        let encouragements = [
            "Good form! Keep it up",
            "Looking strong. Stay relaxed",
            "Nice rhythm. Maintain this pace",
            "Great running. Stay focused",
            "Excellent technique. Keep going"
        ]

        if let encouragement = encouragements.randomElement() {
            announce(encouragement)
        }
    }
}

/// Running form issues that can trigger corrections
enum RunningFormIssue {
    case overstriding       // Stride too long
    case lowCadence         // Steps per minute too low
    case highBounce         // Too much vertical oscillation
    case tensionDetected    // Shoulder tension detected
    case slowTurnover       // Foot ground contact too long
}
