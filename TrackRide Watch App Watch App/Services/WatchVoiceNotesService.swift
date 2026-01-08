//
//  WatchVoiceNotesService.swift
//  TrackRide Watch App
//
//  Voice notes service for Apple Watch - uses system dictation
//

import Foundation
import WatchKit

@Observable
final class WatchVoiceNotesService: NSObject {
    static let shared = WatchVoiceNotesService()

    private(set) var isRecording: Bool = false
    var onTranscriptionComplete: ((String) -> Void)?

    private override init() {
        super.init()
    }

    // MARK: - Recording Control

    /// Start dictation using watchOS text input controller
    @MainActor
    func startDictation() {
        guard !isRecording else { return }
        isRecording = true

        // Get the current interface controller
        guard let rootController = WKApplication.shared().rootInterfaceController else {
            isRecording = false
            return
        }

        // Present dictation interface
        rootController.presentTextInputController(
            withSuggestions: nil,
            allowedInputMode: .allowEmoji
        ) { [weak self] results in
            guard let self else { return }

            DispatchQueue.main.async {
                self.isRecording = false

                // Process dictation results
                if let results = results as? [String], !results.isEmpty {
                    let text = results.joined(separator: " ")
                    if !text.isEmpty {
                        WKInterfaceDevice.current().play(.success)
                        self.onTranscriptionComplete?(text)
                    } else {
                        WKInterfaceDevice.current().play(.failure)
                    }
                } else {
                    WKInterfaceDevice.current().play(.failure)
                }
            }
        }

        WKInterfaceDevice.current().play(.start)
    }

    @MainActor
    func stopRecording() {
        // Dictation stops automatically when user taps Done
        isRecording = false
    }

    // MARK: - Helper

    func appendNote(_ newNote: String, to existingNotes: String) -> String {
        if existingNotes.isEmpty {
            return newNote
        } else {
            return existingNotes + "\n" + newNote
        }
    }
}
