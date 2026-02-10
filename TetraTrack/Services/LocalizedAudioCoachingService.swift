//
//  LocalizedAudioCoachingService.swift
//  TetraTrack
//
//  Audio coaching service that provides voice feedback in the user's selected language.
//  Uses AVSpeechSynthesizer with appropriate voices for Dutch, German, French, Swedish, and English.
//

import AVFoundation
import SwiftUI

// MARK: - Supported Coaching Languages

enum CoachingLanguage: String, CaseIterable, Codable {
    case english = "en"
    case german = "de"
    case french = "fr"
    case dutch = "nl"
    case swedish = "sv"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .dutch: return "Nederlands"
        case .swedish: return "Svenska"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .english: return "en-GB"  // British English for consistency with UK focus
        case .german: return "de-DE"
        case .french: return "fr-FR"
        case .dutch: return "nl-NL"
        case .swedish: return "sv-SE"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇬🇧"
        case .german: return "🇩🇪"
        case .french: return "🇫🇷"
        case .dutch: return "🇳🇱"
        case .swedish: return "🇸🇪"
        }
    }

    /// Detect from current locale
    static var fromSystemLocale: CoachingLanguage {
        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        switch languageCode {
        case "de": return .german
        case "fr": return .french
        case "nl": return .dutch
        case "sv": return .swedish
        default: return .english
        }
    }
}

// MARK: - Coaching Message Types

enum CoachingMessageType: String {
    // General
    case sessionStarted
    case sessionEnded
    case milestone

    // Shooting specific
    case greatShot
    case goodGrouping
    case focusBreathing
    case takeTime
    case excellentConsistency
    case groupsTightening
    case steadyImprovement
    case pressureReminder

    // Riding specific
    case rideStarted
    case gaitChange
    case speedAlert
    case distanceMilestone

    // Running specific
    case runStarted
    case paceUpdate
    case lapCompleted

    // Swimming specific
    case swimStarted
    case lapAlert
    case strokeEfficiency
}

// MARK: - Audio Coaching Service

@Observable
final class LocalizedAudioCoachingService {
    static let shared = LocalizedAudioCoachingService()

    // MARK: - Properties

    private let synthesizer = AVSpeechSynthesizer()
    private var currentVoice: AVSpeechSynthesisVoice?

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "audioCoachingEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "audioCoachingEnabled") }
    }

    var selectedLanguage: CoachingLanguage {
        get {
            if let raw = UserDefaults.standard.string(forKey: "coachingLanguage"),
               let language = CoachingLanguage(rawValue: raw) {
                return language
            }
            return .fromSystemLocale
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "coachingLanguage")
            updateVoice()
        }
    }

    var speechRate: Float {
        get { UserDefaults.standard.float(forKey: "coachingSpeechRate").nonZero ?? 0.5 }
        set { UserDefaults.standard.set(newValue, forKey: "coachingSpeechRate") }
    }

    var volume: Float {
        get { UserDefaults.standard.float(forKey: "coachingVolume").nonZero ?? 0.8 }
        set { UserDefaults.standard.set(newValue, forKey: "coachingVolume") }
    }

    // MARK: - Initialization

    private init() {
        updateVoice()
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    private func updateVoice() {
        // Find the best voice for the selected language
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let localeIdentifier = selectedLanguage.localeIdentifier

        // Prefer enhanced or premium voices
        currentVoice = voices.first { voice in
            voice.language.hasPrefix(selectedLanguage.rawValue) &&
            (voice.quality == .enhanced || voice.quality == .premium)
        } ?? voices.first { voice in
            voice.language.hasPrefix(selectedLanguage.rawValue)
        }

        // Fallback to locale identifier match
        if currentVoice == nil {
            currentVoice = AVSpeechSynthesisVoice(language: localeIdentifier)
        }
    }

    // MARK: - Speech Methods

    /// Speak a predefined coaching message
    func speak(message: CoachingMessageType, context: [String: Any]? = nil) {
        guard isEnabled else { return }

        let text = localizedMessage(for: message, context: context)
        speakText(text)
    }

    /// Speak custom text
    func speakText(_ text: String) {
        guard isEnabled, !text.isEmpty else { return }

        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .word)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = currentVoice
        utterance.rate = speechRate
        utterance.volume = volume
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.2

        synthesizer.speak(utterance)
    }

    /// Speak a localized string key
    func speakLocalized(_ key: String, comment: String = "") {
        let text = NSLocalizedString(key, comment: comment)
        speakText(text)
    }

    /// Stop any current speech
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    // MARK: - Localized Messages

    private func localizedMessage(for type: CoachingMessageType, context: [String: Any]?) -> String {
        switch type {
        case .sessionStarted:
            return NSLocalizedString("Session started. Good luck!", comment: "Audio coaching")

        case .sessionEnded:
            return NSLocalizedString("Session complete. Great work!", comment: "Audio coaching")

        case .milestone:
            if let milestone = context?["milestone"] as? String {
                return String(format: NSLocalizedString("Milestone reached: %@", comment: "Audio coaching"), milestone)
            }
            return NSLocalizedString("Milestone reached!", comment: "Audio coaching")

        case .greatShot:
            return NSLocalizedString("Great shot!", comment: "Audio coaching")

        case .goodGrouping:
            return NSLocalizedString("Good grouping", comment: "Audio coaching")

        case .focusBreathing:
            return NSLocalizedString("Focus on your breathing", comment: "Audio coaching")

        case .takeTime:
            return NSLocalizedString("Take your time", comment: "Audio coaching")

        case .excellentConsistency:
            return NSLocalizedString("Excellent consistency", comment: "Audio coaching")

        case .groupsTightening:
            return NSLocalizedString("Your groups are tightening", comment: "Audio coaching")

        case .steadyImprovement:
            return NSLocalizedString("Steady improvement", comment: "Audio coaching")

        case .pressureReminder:
            return NSLocalizedString("Remember to breathe and stay relaxed", comment: "Audio coaching")

        case .rideStarted:
            return NSLocalizedString("Ride started. Stay safe!", comment: "Audio coaching")

        case .gaitChange:
            if let gait = context?["gait"] as? String {
                return String(format: NSLocalizedString("Gait: %@", comment: "Audio coaching"), gait)
            }
            return NSLocalizedString("Gait changed", comment: "Audio coaching")

        case .speedAlert:
            if let speed = context?["speed"] as? Double {
                return String(format: NSLocalizedString("Speed: %.1f kilometers per hour", comment: "Audio coaching"), speed)
            }
            return ""

        case .distanceMilestone:
            if let distance = context?["distance"] as? Double {
                return String(format: NSLocalizedString("%.1f kilometers completed", comment: "Audio coaching"), distance)
            }
            return NSLocalizedString("Distance milestone!", comment: "Audio coaching")

        case .runStarted:
            return NSLocalizedString("Run started. Let's go!", comment: "Audio coaching")

        case .paceUpdate:
            if let pace = context?["pace"] as? String {
                return String(format: NSLocalizedString("Current pace: %@", comment: "Audio coaching"), pace)
            }
            return ""

        case .lapCompleted:
            if let lap = context?["lap"] as? Int {
                return String(format: NSLocalizedString("Lap %d completed", comment: "Audio coaching"), lap)
            }
            return NSLocalizedString("Lap completed!", comment: "Audio coaching")

        case .swimStarted:
            return NSLocalizedString("Swim started. Enjoy your session!", comment: "Audio coaching")

        case .lapAlert:
            if let laps = context?["laps"] as? Int {
                return String(format: NSLocalizedString("%d lengths completed", comment: "Audio coaching"), laps)
            }
            return NSLocalizedString("Length completed", comment: "Audio coaching")

        case .strokeEfficiency:
            if let swolf = context?["swolf"] as? Int {
                return String(format: NSLocalizedString("SWOLF score: %d", comment: "Audio coaching"), swolf)
            }
            return ""
        }
    }

    // MARK: - Voice Availability

    /// Get available voices for current language
    func availableVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { voice in
            voice.language.hasPrefix(selectedLanguage.rawValue)
        }
    }

    /// Check if enhanced voices are available
    var hasEnhancedVoice: Bool {
        availableVoices().contains { $0.quality == .enhanced || $0.quality == .premium }
    }
}

// MARK: - Float Extension

private extension Float {
    var nonZero: Float? {
        self == 0 ? nil : self
    }
}

// MARK: - Preview Support

#if DEBUG
extension LocalizedAudioCoachingService {
    static var preview: LocalizedAudioCoachingService {
        let service = LocalizedAudioCoachingService.shared
        service.isEnabled = true
        return service
    }
}
#endif
