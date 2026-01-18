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

    // Voice selection
    var selectedVoiceIdentifier: String = "" // Empty = default en-GB voice

    // MARK: - Riding Announcements
    var announceGaitChanges: Bool = true
    var announceDistanceMilestones: Bool = true
    var announceTimeMilestones: Bool = true
    var announceHeartRateZones: Bool = true
    var announceWorkoutIntervals: Bool = true

    // MARK: - Running Announcements
    var announceRunningFormReminders: Bool = true
    var announceRunningPace: Bool = true
    var announceRunningLaps: Bool = true
    var announceVirtualPacer: Bool = true
    var announceCadenceFeedback: Bool = true
    var announcePBRaceCoaching: Bool = true

    // MARK: - Cross-Country/Eventing Announcements
    var announceCrossCountry: Bool = true

    // MARK: - Swimming Announcements
    var announceSwimmingLaps: Bool = true
    var announceSwimmingRest: Bool = true
    var announceSwimmingPace: Bool = true

    // MARK: - Shooting Announcements
    var announceShootingDrills: Bool = true
    var announceShootingStance: Bool = true

    // MARK: - General Announcements
    var announceSessionStartEnd: Bool = true
    var announceSafetyStatus: Bool = true
    var announceSessionSummary: Bool = true

    // MARK: - Biomechanics Announcements (Real-time feedback)
    var announceRidingBiomechanics: Bool = true
    var announceRunningBiomechanics: Bool = true

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

    // MARK: - Voice Selection

    /// Get the selected voice, or default to en-GB
    var selectedVoice: AVSpeechSynthesisVoice? {
        if !selectedVoiceIdentifier.isEmpty,
           let voice = AVSpeechSynthesisVoice(identifier: selectedVoiceIdentifier) {
            return voice
        }
        return AVSpeechSynthesisVoice(language: "en-GB")
    }

    /// Get all available English voices for selection
    static var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { voice1, voice2 in
                // Sort by quality (enhanced first), then by name
                if voice1.quality != voice2.quality {
                    return voice1.quality.rawValue > voice2.quality.rawValue
                }
                return voice1.name < voice2.name
            }
    }

    /// Get display name for a voice
    static func displayName(for voice: AVSpeechSynthesisVoice) -> String {
        let qualityLabel: String
        switch voice.quality {
        case .enhanced:
            qualityLabel = " (Enhanced)"
        case .premium:
            qualityLabel = " (Premium)"
        default:
            qualityLabel = ""
        }

        // Extract country from language code
        let country: String
        switch voice.language {
        case "en-GB": country = "🇬🇧"
        case "en-US": country = "🇺🇸"
        case "en-AU": country = "🇦🇺"
        case "en-IE": country = "🇮🇪"
        case "en-ZA": country = "🇿🇦"
        case "en-IN": country = "🇮🇳"
        default: country = "🌐"
        }

        return "\(country) \(voice.name)\(qualityLabel)"
    }

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
        utterance.voice = selectedVoice
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
        static let selectedVoiceIdentifier = "audioCoach.selectedVoiceIdentifier"

        // Riding
        static let announceGaitChanges = "audioCoach.announceGaitChanges"
        static let announceDistanceMilestones = "audioCoach.announceDistanceMilestones"
        static let announceTimeMilestones = "audioCoach.announceTimeMilestones"
        static let announceHeartRateZones = "audioCoach.announceHeartRateZones"
        static let announceWorkoutIntervals = "audioCoach.announceWorkoutIntervals"

        // Running
        static let announceRunningFormReminders = "audioCoach.announceRunningFormReminders"
        static let announceRunningPace = "audioCoach.announceRunningPace"
        static let announceRunningLaps = "audioCoach.announceRunningLaps"
        static let announceVirtualPacer = "audioCoach.announceVirtualPacer"
        static let announceCadenceFeedback = "audioCoach.announceCadenceFeedback"
        static let announcePBRaceCoaching = "audioCoach.announcePBRaceCoaching"

        // Cross-Country
        static let announceCrossCountry = "audioCoach.announceCrossCountry"

        // Swimming
        static let announceSwimmingLaps = "audioCoach.announceSwimmingLaps"
        static let announceSwimmingRest = "audioCoach.announceSwimmingRest"
        static let announceSwimmingPace = "audioCoach.announceSwimmingPace"

        // Shooting
        static let announceShootingDrills = "audioCoach.announceShootingDrills"
        static let announceShootingStance = "audioCoach.announceShootingStance"

        // General
        static let announceSessionStartEnd = "audioCoach.announceSessionStartEnd"
        static let announceSafetyStatus = "audioCoach.announceSafetyStatus"
        static let announceSessionSummary = "audioCoach.announceSessionSummary"

        // Biomechanics
        static let announceRidingBiomechanics = "audioCoach.announceRidingBiomechanics"
        static let announceRunningBiomechanics = "audioCoach.announceRunningBiomechanics"

        // Intervals
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
        if let voiceId = defaults.string(forKey: Keys.selectedVoiceIdentifier) {
            selectedVoiceIdentifier = voiceId
        }

        // Riding
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

        // Running
        if defaults.object(forKey: Keys.announceRunningFormReminders) != nil {
            announceRunningFormReminders = defaults.bool(forKey: Keys.announceRunningFormReminders)
        }
        if defaults.object(forKey: Keys.announceRunningPace) != nil {
            announceRunningPace = defaults.bool(forKey: Keys.announceRunningPace)
        }
        if defaults.object(forKey: Keys.announceRunningLaps) != nil {
            announceRunningLaps = defaults.bool(forKey: Keys.announceRunningLaps)
        }
        if defaults.object(forKey: Keys.announceVirtualPacer) != nil {
            announceVirtualPacer = defaults.bool(forKey: Keys.announceVirtualPacer)
        }
        if defaults.object(forKey: Keys.announceCadenceFeedback) != nil {
            announceCadenceFeedback = defaults.bool(forKey: Keys.announceCadenceFeedback)
        }
        if defaults.object(forKey: Keys.announcePBRaceCoaching) != nil {
            announcePBRaceCoaching = defaults.bool(forKey: Keys.announcePBRaceCoaching)
        }

        // Cross-Country
        if defaults.object(forKey: Keys.announceCrossCountry) != nil {
            announceCrossCountry = defaults.bool(forKey: Keys.announceCrossCountry)
        }

        // Swimming
        if defaults.object(forKey: Keys.announceSwimmingLaps) != nil {
            announceSwimmingLaps = defaults.bool(forKey: Keys.announceSwimmingLaps)
        }
        if defaults.object(forKey: Keys.announceSwimmingRest) != nil {
            announceSwimmingRest = defaults.bool(forKey: Keys.announceSwimmingRest)
        }
        if defaults.object(forKey: Keys.announceSwimmingPace) != nil {
            announceSwimmingPace = defaults.bool(forKey: Keys.announceSwimmingPace)
        }

        // Shooting
        if defaults.object(forKey: Keys.announceShootingDrills) != nil {
            announceShootingDrills = defaults.bool(forKey: Keys.announceShootingDrills)
        }
        if defaults.object(forKey: Keys.announceShootingStance) != nil {
            announceShootingStance = defaults.bool(forKey: Keys.announceShootingStance)
        }

        // General
        if defaults.object(forKey: Keys.announceSessionStartEnd) != nil {
            announceSessionStartEnd = defaults.bool(forKey: Keys.announceSessionStartEnd)
        }
        if defaults.object(forKey: Keys.announceSafetyStatus) != nil {
            announceSafetyStatus = defaults.bool(forKey: Keys.announceSafetyStatus)
        }
        if defaults.object(forKey: Keys.announceSessionSummary) != nil {
            announceSessionSummary = defaults.bool(forKey: Keys.announceSessionSummary)
        }

        // Biomechanics
        if defaults.object(forKey: Keys.announceRidingBiomechanics) != nil {
            announceRidingBiomechanics = defaults.bool(forKey: Keys.announceRidingBiomechanics)
        }
        if defaults.object(forKey: Keys.announceRunningBiomechanics) != nil {
            announceRunningBiomechanics = defaults.bool(forKey: Keys.announceRunningBiomechanics)
        }

        // Intervals
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
        defaults.set(selectedVoiceIdentifier, forKey: Keys.selectedVoiceIdentifier)

        // Riding
        defaults.set(announceGaitChanges, forKey: Keys.announceGaitChanges)
        defaults.set(announceDistanceMilestones, forKey: Keys.announceDistanceMilestones)
        defaults.set(announceTimeMilestones, forKey: Keys.announceTimeMilestones)
        defaults.set(announceHeartRateZones, forKey: Keys.announceHeartRateZones)
        defaults.set(announceWorkoutIntervals, forKey: Keys.announceWorkoutIntervals)

        // Running
        defaults.set(announceRunningFormReminders, forKey: Keys.announceRunningFormReminders)
        defaults.set(announceRunningPace, forKey: Keys.announceRunningPace)
        defaults.set(announceRunningLaps, forKey: Keys.announceRunningLaps)
        defaults.set(announceVirtualPacer, forKey: Keys.announceVirtualPacer)
        defaults.set(announceCadenceFeedback, forKey: Keys.announceCadenceFeedback)
        defaults.set(announcePBRaceCoaching, forKey: Keys.announcePBRaceCoaching)

        // Cross-Country
        defaults.set(announceCrossCountry, forKey: Keys.announceCrossCountry)

        // Swimming
        defaults.set(announceSwimmingLaps, forKey: Keys.announceSwimmingLaps)
        defaults.set(announceSwimmingRest, forKey: Keys.announceSwimmingRest)
        defaults.set(announceSwimmingPace, forKey: Keys.announceSwimmingPace)

        // Shooting
        defaults.set(announceShootingDrills, forKey: Keys.announceShootingDrills)
        defaults.set(announceShootingStance, forKey: Keys.announceShootingStance)

        // General
        defaults.set(announceSessionStartEnd, forKey: Keys.announceSessionStartEnd)
        defaults.set(announceSafetyStatus, forKey: Keys.announceSafetyStatus)
        defaults.set(announceSessionSummary, forKey: Keys.announceSessionSummary)

        // Biomechanics
        defaults.set(announceRidingBiomechanics, forKey: Keys.announceRidingBiomechanics)
        defaults.set(announceRunningBiomechanics, forKey: Keys.announceRunningBiomechanics)

        // Intervals
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

// MARK: - PB Race Coaching

extension AudioCoachManager {
    /// Announce start of PB race attempt
    func announcePBRaceStart(pbTime: TimeInterval, distance: Double) {
        guard isEnabled else { return }

        let pbFormatted = formatDurationForSpeech(pbTime)
        let distanceFormatted = formatDistanceForSpeech(distance)

        announce("Racing your personal best. Target: \(distanceFormatted) in \(pbFormatted). Good luck!")
    }

    /// Announce PB checkpoint status - call at distance checkpoints (e.g., every 250m for 1500m)
    /// For 1500m race: checkpoints at ~250m, 500m, 750m, 1000m, 1250m = 5 cues
    func announcePBCheckpoint(
        checkpoint: Int,
        totalCheckpoints: Int,
        distanceCovered: Double,
        totalDistance: Double,
        currentTime: TimeInterval,
        expectedTime: TimeInterval
    ) {
        guard isEnabled else { return }

        let timeDifference = currentTime - expectedTime
        let absDiff = Int(abs(timeDifference))
        _ = totalDistance - distanceCovered  // Distance remaining calculated but not announced

        // Distance announcement
        let distanceText: String
        if distanceCovered >= 1000 {
            distanceText = String(format: "%.1f k", distanceCovered / 1000)
        } else {
            distanceText = "\(Int(distanceCovered)) meters"
        }

        var message = "\(distanceText). "

        // Pace status
        if abs(timeDifference) <= 2 {
            message += "On PB pace"
        } else if timeDifference < 0 {
            // Ahead
            if absDiff >= 8 {
                message += "\(absDiff) seconds ahead. Excellent!"
            } else {
                message += "\(absDiff) seconds ahead"
            }
        } else {
            // Behind
            if absDiff >= 10 {
                message += "\(absDiff) seconds behind. Push harder!"
            } else if absDiff >= 5 {
                message += "\(absDiff) seconds behind. Pick it up"
            } else {
                message += "\(absDiff) seconds behind. Stay with it"
            }
        }

        // Add contextual encouragement at key checkpoints
        let percentComplete = (distanceCovered / totalDistance) * 100
        if percentComplete >= 80 {
            message += ". Final push!"
        } else if percentComplete >= 50 && percentComplete < 55 {
            message += ". Halfway there"
        }

        announce(message)
    }

    /// Announce PB pace status - call periodically during race (legacy method)
    func announcePBPaceStatus(currentTime: TimeInterval, expectedTime: TimeInterval, distanceCovered: Double, totalDistance: Double) {
        guard isEnabled else { return }

        let timeDifference = currentTime - expectedTime
        let absDiff = Int(abs(timeDifference))

        // Calculate percentage complete
        let percentComplete = (distanceCovered / totalDistance) * 100

        var message = ""

        if abs(timeDifference) <= 3 {
            // On track (within 3 seconds)
            message = "On track for PB pace"
            if percentComplete > 50 {
                message += ". Keep it up!"
            }
        } else if timeDifference < 0 {
            // Ahead of PB pace
            if absDiff >= 10 {
                message = "Excellent! \(absDiff) seconds ahead of PB pace"
            } else {
                message = "\(absDiff) seconds ahead of PB pace. Great work!"
            }
        } else {
            // Behind PB pace
            if absDiff >= 15 {
                message = "Warning. \(absDiff) seconds behind PB pace. Dig deep!"
            } else if absDiff >= 10 {
                message = "\(absDiff) seconds behind PB pace. You can catch up!"
            } else {
                message = "\(absDiff) seconds behind PB pace. Stay focused"
            }
        }

        announce(message)
    }

    /// Announce projected finish vs PB
    func announcePBProjection(projectedTime: TimeInterval, pbTime: TimeInterval, distanceRemaining: Double) {
        guard isEnabled else { return }

        let difference = projectedTime - pbTime
        let absDiff = Int(abs(difference))

        var message = ""

        if abs(difference) <= 5 {
            message = "Projected finish right on your PB"
        } else if difference < 0 {
            message = "On pace for new PB by \(absDiff) seconds!"
        } else {
            let remainingFormatted = formatDistanceForSpeech(distanceRemaining)
            message = "Currently \(absDiff) seconds off PB. \(remainingFormatted) to go. Push hard!"
        }

        announce(message)
    }

    /// Announce PB race completion
    func announcePBRaceComplete(finalTime: TimeInterval, pbTime: TimeInterval, isNewPB: Bool) {
        guard isEnabled else { return }

        let difference = finalTime - pbTime
        let absDiff = Int(abs(difference))
        let timeFormatted = formatDurationForSpeech(finalTime)

        var message = "Finished in \(timeFormatted). "

        if isNewPB {
            message += "Congratulations! New personal best by \(absDiff) seconds!"
        } else if abs(difference) <= 3 {
            message += "Matched your personal best. Great consistency!"
        } else {
            message += "\(absDiff) seconds behind your personal best. Good effort!"
        }

        announce(message)
    }

    /// Announce encouragement during PB race
    func announcePBEncouragement(percentComplete: Double, isAhead: Bool) {
        guard isEnabled else { return }

        var message = ""

        if percentComplete >= 90 {
            message = isAhead ? "Final stretch! Maintain your lead!" : "Final push! Give it everything!"
        } else if percentComplete >= 75 {
            message = isAhead ? "Three quarters done. Stay strong!" : "Dig deep. You've got this!"
        } else if percentComplete >= 50 {
            message = isAhead ? "Halfway there. Looking good!" : "Halfway. Time to push!"
        } else if percentComplete >= 25 {
            message = "Quarter done. Settle into your rhythm"
        }

        if !message.isEmpty {
            announce(message)
        }
    }
}

// MARK: - Riding Biomechanics Coaching

extension AudioCoachManager {
    // Throttle tracking for biomechanics announcements
    private static var lastSymmetryWarning: Date?
    private static var lastRhythmWarning: Date?
    private static var lastBalanceWarning: Date?
    private static var lastImpulsionWarning: Date?
    private static var lastStabilityWarning: Date?
    private static var lastTransitionFeedback: Date?

    /// Throttle interval for biomechanics announcements (seconds)
    private static let biomechanicsThrottleInterval: TimeInterval = 30

    /// Process symmetry score and announce if asymmetry detected
    /// - Parameter score: Symmetry score 0-100 (100 = perfect symmetry)
    func processSymmetry(_ score: Double) {
        guard isEnabled, announceRidingBiomechanics else { return }

        // Throttle announcements
        if let lastWarning = Self.lastSymmetryWarning,
           Date().timeIntervalSince(lastWarning) < Self.biomechanicsThrottleInterval {
            return
        }

        // Announce if symmetry drops below threshold
        if score < 70 {
            Self.lastSymmetryWarning = Date()
            if score < 50 {
                announce("Significant asymmetry detected. Check your position and your horse's movement")
            } else {
                announce("Slight left-right imbalance. Center your weight")
            }
        }
    }

    /// Process rhythm regularity and announce if irregular
    /// - Parameter score: Rhythm regularity 0-100 (100 = perfect rhythm)
    func processRhythm(_ score: Double) {
        guard isEnabled, announceRidingBiomechanics else { return }

        if let lastWarning = Self.lastRhythmWarning,
           Date().timeIntervalSince(lastWarning) < Self.biomechanicsThrottleInterval {
            return
        }

        if score < 60 {
            Self.lastRhythmWarning = Date()
            if score < 40 {
                announce("Rhythm very irregular. Steady your pace and establish a consistent tempo")
            } else {
                announce("Rhythm inconsistent. Focus on maintaining an even tempo")
            }
        }
    }

    /// Process rein balance and announce if imbalanced
    /// - Parameter balance: Rein balance -1 to +1 (0 = centered, negative = left bias, positive = right bias)
    func processReinBalance(_ balance: Double) {
        guard isEnabled, announceRidingBiomechanics else { return }

        if let lastWarning = Self.lastBalanceWarning,
           Date().timeIntervalSince(lastWarning) < Self.biomechanicsThrottleInterval {
            return
        }

        let absBalance = abs(balance)
        if absBalance > 0.3 {
            Self.lastBalanceWarning = Date()
            if balance < -0.3 {
                announce("Leaning left. Center your weight over your horse")
            } else {
                announce("Leaning right. Center your weight over your horse")
            }
        }
    }

    /// Process impulsion score and provide coaching
    /// - Parameter score: Impulsion 0-100
    func processImpulsion(_ score: Double, gait: GaitType) {
        guard isEnabled, announceRidingBiomechanics else { return }
        guard gait != .walk && gait != .stationary else { return }

        if let lastWarning = Self.lastImpulsionWarning,
           Date().timeIntervalSince(lastWarning) < Self.biomechanicsThrottleInterval * 2 {
            return
        }

        if score < 40 {
            Self.lastImpulsionWarning = Date()
            announce("Low impulsion. Ask for more forward energy from your horse")
        } else if score > 85 {
            Self.lastImpulsionWarning = Date()
            announce("Excellent impulsion. Maintain this forward energy")
        }
    }

    /// Process rider stability score
    /// - Parameter score: Stability 0-100 (100 = very stable)
    func processRiderStability(_ score: Double) {
        guard isEnabled, announceRidingBiomechanics else { return }

        if let lastWarning = Self.lastStabilityWarning,
           Date().timeIntervalSince(lastWarning) < Self.biomechanicsThrottleInterval {
            return
        }

        if score < 50 {
            Self.lastStabilityWarning = Date()
            if score < 30 {
                announce("Position unstable. Sit deep, relax your hips, and follow your horse's movement")
            } else {
                announce("Work on your stability. Keep a steady, balanced position")
            }
        }
    }

    /// Announce transition quality feedback
    /// - Parameter quality: Transition quality 0-100
    func announceTransitionQuality(_ quality: Double, from oldGait: GaitType, to newGait: GaitType) {
        guard isEnabled, announceRidingBiomechanics else { return }

        if let lastFeedback = Self.lastTransitionFeedback,
           Date().timeIntervalSince(lastFeedback) < 10 {
            return
        }

        Self.lastTransitionFeedback = Date()

        if quality >= 80 {
            announce("Smooth transition. Well done")
        } else if quality < 50 {
            let transitionName = "\(oldGait.rawValue) to \(newGait.rawValue)"
            announce("Abrupt \(transitionName) transition. Prepare earlier and use half-halts")
        }
    }

    /// Announce engagement feedback
    /// - Parameter score: Engagement 0-100
    func processEngagement(_ score: Double) {
        guard isEnabled, announceRidingBiomechanics else { return }

        // Only announce exceptional engagement
        if score > 85 {
            announce("Excellent engagement. Your horse is working well from behind")
        }
    }

    /// Announce straightness feedback
    /// - Parameter score: Straightness 0-100
    func processStraightness(_ score: Double) {
        guard isEnabled, announceRidingBiomechanics else { return }

        if score < 60 {
            announce("Horse drifting. Use your legs to maintain straightness")
        }
    }
}

// MARK: - Running Biomechanics Coaching

extension AudioCoachManager {
    private static var lastAsymmetryWarning: Date?
    private static var lastStabilityFeedback: Date?
    private static var lastGroundContactWarning: Date?

    /// Process running motion asymmetry
    /// - Parameter asymmetry: Left-right asymmetry (-1 to +1, 0 = balanced)
    func processRunningAsymmetry(_ asymmetry: Double) {
        guard isEnabled, announceRunningBiomechanics else { return }

        if let lastWarning = Self.lastAsymmetryWarning,
           Date().timeIntervalSince(lastWarning) < 45 {
            return
        }

        let absAsymmetry = abs(asymmetry)
        if absAsymmetry > 0.15 {
            Self.lastAsymmetryWarning = Date()
            if asymmetry > 0 {
                announce("Right-side dominant. Balance your stride")
            } else {
                announce("Left-side dominant. Balance your stride")
            }
        }
    }

    /// Process rotational stability for running
    /// - Parameter stability: Rotational stability 0-100
    func processRunningStability(_ stability: Double) {
        guard isEnabled, announceRunningBiomechanics else { return }

        if let lastFeedback = Self.lastStabilityFeedback,
           Date().timeIntervalSince(lastFeedback) < 60 {
            return
        }

        if stability < 60 {
            Self.lastStabilityFeedback = Date()
            announce("Core rotation detected. Engage your core and run tall")
        }
    }

    /// Process vertical oscillation (bounce)
    /// - Parameter oscillation: Oscillation frequency in Hz
    func processVerticalOscillation(_ oscillation: Double) {
        guard isEnabled, announceRunningBiomechanics else { return }

        // High oscillation indicates too much bounce
        if oscillation > 3.5 {
            announce("Too much vertical bounce. Run smoother, push forward not up")
        }
    }

    /// Process ground contact time (rhythm consistency)
    /// - Parameter consistency: Rhythm consistency 0-100
    func processRunningRhythm(_ consistency: Double) {
        guard isEnabled, announceRunningBiomechanics else { return }

        if let lastWarning = Self.lastGroundContactWarning,
           Date().timeIntervalSince(lastWarning) < 45 {
            return
        }

        if consistency < 70 {
            Self.lastGroundContactWarning = Date()
            announce("Uneven rhythm. Focus on consistent foot strikes")
        }
    }
}

// MARK: - Swimming Announcements
// Note: Voice coaching during swimming is impractical as swimmers cannot hear underwater.
// These methods are for pre/post swim and poolside announcements only.

extension AudioCoachManager {
    /// Announce swimming session start (before entering water)
    func announceSwimmingStart(targetLaps: Int?, targetDistance: Double?) {
        guard isEnabled, announceSwimmingLaps else { return }

        var message = "Swimming session started"
        if let laps = targetLaps {
            message += ". Target: \(laps) lengths"
        } else if let distance = targetDistance {
            message += ". Target: \(Int(distance)) meters"
        }
        announce(message)
    }

    /// Announce swimming session complete (after exiting water)
    func announceSwimmingComplete(laps: Int, distance: Double, duration: TimeInterval) {
        guard isEnabled, announceSwimmingLaps else { return }

        let minutes = Int(duration) / 60
        let distanceKm = distance / 1000

        var message = "Swimming complete. \(laps) lengths"
        if distanceKm >= 1 {
            message += ". \(String(format: "%.1f", distanceKm)) kilometers"
        } else {
            message += ". \(Int(distance)) meters"
        }
        message += " in \(minutes) minutes"

        // Add pace per 100m
        if distance > 0 {
            let pacePer100 = (duration / distance) * 100
            let paceMinutes = Int(pacePer100) / 60
            let paceSeconds = Int(pacePer100) % 60
            message += ". Average pace \(paceMinutes):\(String(format: "%02d", paceSeconds)) per 100"
        }

        announce(message)
    }
}

// MARK: - Shooting Stance Coaching

extension AudioCoachManager {
    private static var lastStanceWarning: Date?
    private static var lastStabilityAnnouncement: Date?

    /// Process shooting stance stability
    /// - Parameter stability: Stance stability 0-100
    func processShootingStance(_ stability: Double) {
        guard isEnabled, announceShootingStance else { return }

        if let lastWarning = Self.lastStanceWarning,
           Date().timeIntervalSince(lastWarning) < 10 {
            return
        }

        if stability < 50 {
            Self.lastStanceWarning = Date()
            if stability < 30 {
                announce("Unstable. Reset your stance")
            } else {
                announce("Steady. Control your breathing")
            }
        } else if stability > 90 {
            if let lastAnnouncement = Self.lastStabilityAnnouncement,
               Date().timeIntervalSince(lastAnnouncement) < 30 {
                return
            }
            Self.lastStabilityAnnouncement = Date()
            announce("Excellent stability. Hold and shoot")
        }
    }

    /// Announce shooting drill start
    func announceShootingDrillStart(_ drillName: String) {
        guard isEnabled, announceShootingDrills else { return }
        announce("Starting \(drillName). Get ready")
    }

    /// Announce shooting drill score
    func announceShootingDrillScore(_ score: Int, total: Int) {
        guard isEnabled, announceShootingDrills else { return }

        let percentage = total > 0 ? (score * 100) / total : 0

        if percentage >= 90 {
            announce("Excellent! Score \(score) out of \(total). \(percentage) percent")
        } else if percentage >= 70 {
            announce("Good shooting. Score \(score) out of \(total). \(percentage) percent")
        } else {
            announce("Score \(score) out of \(total). \(percentage) percent. Keep practicing")
        }
    }

    /// Announce breathing cue for shooting
    func announceShootingBreathingCue() {
        guard isEnabled, announceShootingStance else { return }
        announce("Breathe in. Hold. Squeeze")
    }
}
