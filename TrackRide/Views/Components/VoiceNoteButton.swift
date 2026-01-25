//
//  VoiceNoteButton.swift
//  TrackRide
//
//  Reusable microphone button for voice notes across all disciplines
//

import SwiftUI

struct VoiceNoteButton: View {
    let onNoteSaved: (String) -> Void

    @State private var voiceService = VoiceNotesService.shared
    @State private var showingPermissionAlert = false

    var body: some View {
        Button(action: toggleRecording) {
            ZStack {
                // Background circle
                Circle()
                    .fill(voiceService.isRecording ? Color.red : AppColors.cardBackground)
                    .frame(width: 56, height: 56)

                // Recording level indicator
                if voiceService.isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 3)
                        .frame(width: 56 + (CGFloat(voiceService.recordingLevel) * 20), height: 56 + (CGFloat(voiceService.recordingLevel) * 20))
                        .animation(.easeOut(duration: 0.1), value: voiceService.recordingLevel)
                }

                // Microphone icon
                Image(systemName: voiceService.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(voiceService.isRecording ? .white : .primary)
            }
        }
        .buttonStyle(.plain)
        .alert("Microphone Access Required", isPresented: $showingPermissionAlert) {
            Button("Settings", role: nil) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable microphone and speech recognition access in Settings to use voice notes.")
        }
        .onAppear {
            setupVoiceService()
        }
    }

    private func setupVoiceService() {
        voiceService.onTranscriptionComplete = { text in
            onNoteSaved(text)
        }
    }

    private func toggleRecording() {
        if voiceService.isRecording {
            voiceService.stopRecording()
        } else {
            Task {
                if !voiceService.isAuthorized {
                    let authorized = await voiceService.requestAuthorization()
                    if !authorized {
                        showingPermissionAlert = true
                        return
                    }
                }
                await voiceService.startRecording()
            }
        }
    }
}

// MARK: - Compact Version for Toolbars

struct VoiceNoteToolbarButton: View {
    let onNoteSaved: (String) -> Void

    @State private var voiceService = VoiceNotesService.shared
    @State private var showingPermissionAlert = false

    var body: some View {
        Button(action: toggleRecording) {
            ZStack {
                if voiceService.isRecording {
                    // Pulsing recording indicator
                    Circle()
                        .fill(Color.red)
                        .frame(width: 32, height: 32)

                    Image(systemName: "stop.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20))
                }
            }
        }
        .alert("Microphone Access Required", isPresented: $showingPermissionAlert) {
            Button("Settings", role: nil) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable microphone and speech recognition access in Settings to use voice notes.")
        }
        .onAppear {
            setupVoiceService()
        }
    }

    private func setupVoiceService() {
        voiceService.onTranscriptionComplete = { text in
            onNoteSaved(text)
        }
    }

    private func toggleRecording() {
        if voiceService.isRecording {
            voiceService.stopRecording()
        } else {
            Task {
                if !voiceService.isAuthorized {
                    let authorized = await voiceService.requestAuthorization()
                    if !authorized {
                        showingPermissionAlert = true
                        return
                    }
                }
                await voiceService.startRecording()
            }
        }
    }
}

// MARK: - Recording Overlay (shows transcription in progress)

struct VoiceNoteRecordingOverlay: View {
    @State private var voiceService = VoiceNotesService.shared

    var body: some View {
        if voiceService.isRecording {
            VStack(spacing: 16) {
                // Recording indicator
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .modifier(PulsingModifier())

                    Text("Recording...")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                // Live transcription
                if !voiceService.transcribedText.isEmpty {
                    Text(voiceService.transcribedText)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .lineLimit(3)
                }

                // Tap to stop hint
                Text("Tap mic or pause speaking to save")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding()
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Pulsing Animation Modifier

struct PulsingModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Notes Display Component

struct NotesSection: View {
    @Binding var notes: String
    let onDelete: () -> Void

    @State private var isEditing = false
    @State private var editedNotes = ""

    var body: some View {
        if !notes.isEmpty || isEditing {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Notes")
                        .font(.headline)

                    Spacer()

                    if !notes.isEmpty {
                        Button(action: {
                            editedNotes = notes
                            isEditing = true
                        }) {
                            Image(systemName: "pencil")
                                .font(.subheadline)
                        }

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }
                }

                if isEditing {
                    TextEditor(text: $editedNotes)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    HStack {
                        Button("Cancel") {
                            isEditing = false
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button("Save") {
                            notes = editedNotes
                            isEditing = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    Text(notes)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        VoiceNoteButton { note in
            print("Note saved: \(note)")
        }

        VoiceNoteToolbarButton { note in
            print("Note saved: \(note)")
        }
    }
    .padding()
}
