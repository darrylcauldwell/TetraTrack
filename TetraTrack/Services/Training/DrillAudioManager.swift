//
//  DrillAudioManager.swift
//  TetraTrack
//
//  Audio feedback manager for drill exercises
//

import AVFoundation
import UIKit

/// Manages audio feedback during drill sessions
final class DrillAudioManager {

    // MARK: - Singleton

    static let shared = DrillAudioManager()

    // MARK: - Properties

    private let synthesizer = AVSpeechSynthesizer()
    private var audioSession: AVAudioSession { AVAudioSession.sharedInstance() }

    /// Whether voice cues are enabled
    var voiceEnabled: Bool = true

    /// Speech rate (0.0 to 1.0)
    var speechRate: Float = 0.5

    // MARK: - Initialization

    private init() {}

    // MARK: - Audio Session Configuration

    /// Configure audio session for drill playback
    func configureForDrill() {
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch {
            // Audio session configuration failed silently
        }
    }

    /// Deactivate audio session
    func deactivate() {
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Audio session deactivation failed silently
        }
    }

    // MARK: - Voice Cues

    /// Speak a message using text-to-speech
    func speak(_ message: String, priority: SpeechPriority = .normal) {
        guard voiceEnabled else { return }

        // Cancel current speech for high priority
        if priority == .high && synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = speechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        // Use a pleasant voice
        if let voice = AVSpeechSynthesisVoice(language: "en-GB") {
            utterance.voice = voice
        }

        synthesizer.speak(utterance)
    }

    /// Countdown from a number with voice cues
    func countdown(from count: Int, completion: @escaping () -> Void) {
        guard count > 0 else {
            completion()
            return
        }

        var remaining = count

        func announceNext() {
            guard remaining > 0 else {
                speak("Go!", priority: .high)
                completion()
                return
            }

            speak("\(remaining)", priority: .normal)
            remaining -= 1

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                announceNext()
            }
        }

        announceNext()
    }

    /// Announce drill start
    func announceDrillStart(drillName: String) {
        speak("Starting \(drillName). Get ready.")
    }

    /// Announce drill complete
    func announceDrillComplete(score: Int) {
        let message: String
        if score >= 80 {
            message = "Excellent work! Score: \(score) percent."
        } else if score >= 60 {
            message = "Good effort. Score: \(score) percent."
        } else {
            message = "Keep practicing. Score: \(score) percent."
        }
        speak(message)
    }

    /// Announce time remaining
    func announceTimeRemaining(_ seconds: Int) {
        if seconds == 30 {
            speak("30 seconds remaining.")
        } else if seconds == 10 {
            speak("10 seconds remaining. Push through!")
        } else if seconds == 5 {
            speak("5 seconds.")
        }
    }

    // MARK: - Encouragement Cues

    /// Provide encouragement based on performance
    func encouragePerformance(stability: Double) {
        let message: String
        if stability >= 90 {
            message = ["Perfect!", "Excellent stability!", "Outstanding!"].randomElement()!
        } else if stability >= 70 {
            message = ["Good!", "Keep it up!", "Nice work!"].randomElement()!
        } else if stability >= 50 {
            message = ["Focus!", "Steady now.", "Stay with it."].randomElement()!
        } else {
            message = ["Reset position.", "Regain control.", "Center yourself."].randomElement()!
        }
        speak(message)
    }

    /// Announce rhythm feedback
    func announceRhythmFeedback(accuracy: Double) {
        if accuracy >= 90 {
            speak("Perfect timing!")
        } else if accuracy >= 70 {
            speak("Good rhythm.")
        } else if accuracy < 50 {
            speak("Adjust your timing.")
        }
    }

    // MARK: - Sound Effects (System Sounds)

    /// Play metronome tick using system sound
    func playMetronomeTick() {
        AudioServicesPlaySystemSound(1104) // Tock sound
    }

    /// Play success sound
    func playSuccessSound() {
        AudioServicesPlaySystemSound(1025) // Success sound
    }

    /// Play warning sound
    func playWarningSound() {
        AudioServicesPlaySystemSound(1073) // Warning sound
    }

    /// Play error sound
    func playErrorSound() {
        AudioServicesPlaySystemSound(1053) // Error sound
    }

    // MARK: - Stop

    /// Stop all audio
    func stopAll() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    // MARK: - Types

    enum SpeechPriority {
        case normal
        case high
    }
}
