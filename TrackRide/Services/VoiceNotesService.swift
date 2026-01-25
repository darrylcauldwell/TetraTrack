//
//  VoiceNotesService.swift
//  TrackRide
//
//  Hands-free voice notes with Speech recognition and AirPods support
//

import Foundation
import Speech
import AVFoundation
import MediaPlayer
import Observation
import os

@Observable
final class VoiceNotesService: NSObject {
    static let shared = VoiceNotesService()

    // MARK: - State

    private(set) var isRecording: Bool = false
    private(set) var isAuthorized: Bool = false
    private(set) var transcribedText: String = ""
    private(set) var recordingLevel: Float = 0.0

    // Error state
    private(set) var lastError: String?

    // MARK: - Private Properties

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // Silence detection
    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 2.0 // Stop after 2 seconds of silence
    private var lastSpeechTime: Date = Date()

    // Callbacks
    var onTranscriptionComplete: ((String) -> Void)?
    var onRecordingStateChanged: ((Bool) -> Void)?

    // AirPods integration
    private var remoteCommandsConfigured = false
    private var airPodsEnabled = true

    // Audio feedback
    private let audioCoach = AudioCoachManager.shared

    // MARK: - Initialization

    private override init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB"))
        super.init()
        speechRecognizer?.delegate = self
        // Don't check authorization on init - wait until user actually taps mic button
        // This prevents permission prompts appearing when views load
    }

    deinit {
        // Clean up remote command handlers to prevent memory leaks
        if remoteCommandsConfigured {
            let commandCenter = MPRemoteCommandCenter.shared()
            commandCenter.togglePlayPauseCommand.removeTarget(nil)
            commandCenter.nextTrackCommand.removeTarget(nil)
        }
        // Stop any active recording
        silenceTimer?.invalidate()
        audioEngine.stop()
    }

    // MARK: - Authorization

    func checkAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.isAuthorized = (status == .authorized)
            }
        }
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                let authorized = (status == .authorized)
                Task { @MainActor in
                    self?.isAuthorized = authorized
                }
                continuation.resume(returning: authorized)
            }
        }
    }

    // MARK: - AirPods Remote Command Integration

    func configureRemoteCommands(enabled: Bool = true) {
        airPodsEnabled = enabled

        let commandCenter = MPRemoteCommandCenter.shared()

        if enabled && !remoteCommandsConfigured {
            // Use play/pause command for voice notes when not playing audio
            commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
                guard let self = self else { return .commandFailed }

                // Toggle recording
                if self.isRecording {
                    self.stopRecording()
                } else {
                    Task {
                        await self.startRecording()
                    }
                }
                return .success
            }

            // Alternative: Use next track for dedicated voice note trigger
            commandCenter.nextTrackCommand.addTarget { [weak self] _ in
                guard let self = self else { return .commandFailed }

                if !self.isRecording {
                    Task {
                        await self.startRecording()
                    }
                }
                return .success
            }

            remoteCommandsConfigured = true
        } else if !enabled && remoteCommandsConfigured {
            commandCenter.togglePlayPauseCommand.removeTarget(nil)
            commandCenter.nextTrackCommand.removeTarget(nil)
            remoteCommandsConfigured = false
        }
    }

    func disableRemoteCommands() {
        configureRemoteCommands(enabled: false)
    }

    // MARK: - Recording Control

    @MainActor
    func startRecording() async {
        guard !isRecording else { return }

        if !isAuthorized {
            let authorized = await requestAuthorization()
            guard authorized else {
                lastError = "Speech recognition not authorized"
                return
            }
        }

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            lastError = "Speech recognition not available"
            return
        }

        // Stop any existing task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            lastError = "Failed to configure audio session: \(error.localizedDescription)"
            return
        }

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            lastError = "Failed to create recognition request"
            return
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true

        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)

            // Calculate audio level for visual feedback
            self?.calculateAudioLevel(buffer: buffer)
        }

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                Task { @MainActor in
                    self.transcribedText = result.bestTranscription.formattedString
                    self.lastSpeechTime = Date()
                }
            }

            if error != nil || (result?.isFinal ?? false) {
                Task { @MainActor in
                    self.finishRecording()
                }
            }
        }

        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            transcribedText = ""
            lastSpeechTime = Date()
            onRecordingStateChanged?(true)

            // Audio feedback
            audioCoach.announce("Recording")

            // Start silence detection
            startSilenceDetection()

        } catch {
            lastError = "Failed to start audio engine: \(error.localizedDescription)"
            finishRecording()
        }
    }

    @MainActor
    func stopRecording() {
        guard isRecording else { return }
        finishRecording()
    }

    @MainActor
    private func finishRecording() {
        // Stop silence timer
        silenceTimer?.invalidate()
        silenceTimer = nil

        // Stop audio engine
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // End recognition
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        isRecording = false
        recordingLevel = 0.0
        onRecordingStateChanged?(false)

        // Reset audio session for playback
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try audioSession.setActive(true)
        } catch {
            Log.audio.error("Failed to reset audio session: \(error)")
        }

        // Notify completion with transcribed text
        let finalText = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalText.isEmpty {
            onTranscriptionComplete?(finalText)
            audioCoach.announce("Note saved")
        } else {
            audioCoach.announce("No note recorded")
        }
    }

    // MARK: - Silence Detection

    private func startSilenceDetection() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let timeSinceLastSpeech = Date().timeIntervalSince(self.lastSpeechTime)
            if timeSinceLastSpeech >= self.silenceThreshold && !self.transcribedText.isEmpty {
                Task { @MainActor in
                    self.stopRecording()
                }
            }
        }
    }

    // MARK: - Audio Level

    private func calculateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)

        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelDataValue[i])
        }

        let average = sum / Float(frameLength)
        let level = min(1.0, average * 10) // Normalize to 0-1

        Task { @MainActor in
            self.recordingLevel = level
        }
    }

    // MARK: - Append to Existing Notes

    func appendNote(_ newNote: String, to existingNotes: String) -> String {
        if existingNotes.isEmpty {
            return newNote
        } else {
            // Add timestamp separator
            let timestamp = Date().formatted(date: .omitted, time: .shortened)
            return existingNotes + "\n\n[\(timestamp)] " + newNote
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension VoiceNotesService: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available && isRecording {
                stopRecording()
                lastError = "Speech recognition became unavailable"
            }
        }
    }
}
