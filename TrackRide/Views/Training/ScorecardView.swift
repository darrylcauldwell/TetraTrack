//
//  ScorecardView.swift
//  TrackRide
//
//  Post-ride subjective scoring for training quality
//

import SwiftUI
import SwiftData
import Speech
import AVFoundation
import Combine

struct ScorecardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let ride: Ride
    @Bindable var score: RideScore

    @State private var showingNotes = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(AppColors.primary)

                        Text("Rate Your Ride")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("How did it go today?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top)

                    // Overall feeling
                    ScoreSection(title: "Overall Feeling", icon: "heart.fill") {
                        ScoreSlider(
                            value: $score.overallFeeling,
                            description: "How satisfied are you with this ride?"
                        )
                    }

                    // Horse state
                    ScoreSection(title: "Horse", icon: "figure.equestrian.sports") {
                        ScoreRow(
                            title: "Energy Level",
                            description: "1 = Sluggish, 5 = Fresh",
                            value: $score.horseEnergy
                        )
                        ScoreRow(
                            title: "Mood",
                            description: "1 = Resistant, 5 = Willing",
                            value: $score.horseMood
                        )
                    }

                    // Training scale
                    ScoreSection(title: "Training Scale", icon: "chart.bar.fill") {
                        ScoreRow(
                            title: "Relaxation",
                            description: "Mental and physical calmness",
                            value: $score.relaxation
                        )
                        ScoreRow(
                            title: "Rhythm",
                            description: "Regularity and tempo",
                            value: $score.rhythm
                        )
                        ScoreRow(
                            title: "Suppleness",
                            description: "Flexibility and elasticity",
                            value: $score.suppleness
                        )
                        ScoreRow(
                            title: "Connection",
                            description: "Contact and throughness",
                            value: $score.connection
                        )
                        ScoreRow(
                            title: "Impulsion",
                            description: "Forward energy and engagement",
                            value: $score.impulsion
                        )
                        ScoreRow(
                            title: "Straightness",
                            description: "Alignment and balance",
                            value: $score.straightness
                        )
                        ScoreRow(
                            title: "Collection",
                            description: "Self-carriage and balance",
                            value: $score.collection
                        )
                    }

                    // Rider
                    ScoreSection(title: "Rider", icon: "person.fill") {
                        ScoreRow(
                            title: "Position",
                            description: "Balance and effectiveness",
                            value: $score.riderPosition
                        )
                    }

                    // Notes
                    ScoreSection(title: "Notes", icon: "note.text") {
                        VStack(alignment: .leading, spacing: 12) {
                            NoteField(
                                title: "Highlights",
                                placeholder: "What went well?",
                                text: $score.highlights
                            )

                            NoteField(
                                title: "Areas to Improve",
                                placeholder: "What to work on next time?",
                                text: $score.improvements
                            )

                            NoteField(
                                title: "Additional Notes",
                                placeholder: "Any other observations...",
                                text: $score.notes
                            )
                        }
                    }

                    // Summary
                    if score.hasScores {
                        ScoreSection(title: "Summary", icon: "chart.pie.fill") {
                            HStack(spacing: 20) {
                                SummaryBadge(
                                    title: "Training Scale",
                                    value: score.trainingScaleAverage,
                                    color: scoreColor(score.trainingScaleAverage)
                                )

                                SummaryBadge(
                                    title: "Overall",
                                    value: score.overallAverage,
                                    color: scoreColor(score.overallAverage)
                                )
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Scorecard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveScore()
                    }
                }
            }
        }
    }

    private func scoreColor(_ value: Double) -> Color {
        switch value {
        case 4.5...5.0: return .green
        case 3.5..<4.5: return .blue
        case 2.5..<3.5: return .orange
        default: return .red
        }
    }

    private func saveScore() {
        score.scoredAt = Date()
        score.ride = ride
        modelContext.insert(score)
        try? modelContext.save()
        dismiss()
    }
}

struct ScoreSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(AppColors.primary)
                Text(title)
                    .font(.headline)
            }

            VStack(spacing: 16) {
                content
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct ScoreRow: View {
    let title: String
    let description: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if value > 0 {
                    Text(value.scoreLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ScoreButtons(value: $value)
        }
    }
}

struct ScoreSlider: View {
    @Binding var value: Int
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)

            ScoreButtons(value: $value)

            if value > 0 {
                Text(value.scoreLabel)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(scoreColor)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var scoreColor: Color {
        switch value {
        case 5: return .green
        case 4: return .blue
        case 3: return .orange
        case 2: return .red
        default: return .red
        }
    }
}

struct ScoreButtons: View {
    @Binding var value: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { score in
                Button(action: { value = score }) {
                    Text("\(score)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(value == score ? buttonColor(score) : AppColors.elevatedSurface)
                        .foregroundStyle(value == score ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func buttonColor(_ score: Int) -> Color {
        switch score {
        case 5: return .green
        case 4: return .blue
        case 3: return .orange
        case 2: return .red
        default: return .red
        }
    }
}

struct NoteField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    @StateObject private var transcriber = VoiceTranscriber()
    @State private var showingPermissionAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                // Voice transcription button
                Button(action: toggleTranscription) {
                    Image(systemName: transcriber.isTranscribing ? "mic.fill" : "mic")
                        .font(.caption)
                        .foregroundStyle(transcriber.isTranscribing ? .red : AppColors.primary)
                        .symbolEffect(.pulse, isActive: transcriber.isTranscribing)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .top, spacing: 8) {
                TextField(placeholder, text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .writingToolsBehavior(.complete)

                if transcriber.isTranscribing {
                    VStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Listening...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 60)
                }
            }
            .padding(8)
            .background(AppColors.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(transcriber.isTranscribing ? Color.red.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
        .onChange(of: transcriber.transcribedText) { _, newValue in
            if !newValue.isEmpty {
                if text.isEmpty {
                    text = newValue
                } else {
                    text += " " + newValue
                }
            }
        }
        .alert("Microphone Access", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("TetraTrack needs microphone access for voice transcription. Please enable it in Settings.")
        }
        .onDisappear {
            if transcriber.isTranscribing {
                transcriber.stopTranscribing()
            }
        }
    }

    private func toggleTranscription() {
        if transcriber.isTranscribing {
            transcriber.stopTranscribing()
        } else {
            Task {
                let authorized = await transcriber.requestAuthorization()
                if authorized {
                    await MainActor.run {
                        transcriber.startTranscribing()
                    }
                } else {
                    await MainActor.run {
                        showingPermissionAlert = true
                    }
                }
            }
        }
    }
}

// MARK: - Voice Transcriber

@MainActor
class VoiceTranscriber: ObservableObject {
    @Published var isTranscribing = false
    @Published var transcribedText = ""
    @Published var errorMessage: String?

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)

    func requestAuthorization() async -> Bool {
        // Check speech recognition authorization
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else { return false }

        // Check microphone authorization
        let audioStatus = await AVAudioApplication.requestRecordPermission()
        return audioStatus
    }

    func startTranscribing() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition not available"
            return
        }

        // Reset
        transcribedText = ""
        errorMessage = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Failed to configure audio: \(error.localizedDescription)"
            return
        }

        // Create recognition request
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString
                }

                if error != nil || result?.isFinal == true {
                    self.stopTranscribing()
                }
            }
        }

        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isTranscribing = true
        } catch {
            errorMessage = "Failed to start audio: \(error.localizedDescription)"
        }
    }

    func stopTranscribing() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isTranscribing = false

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

struct SummaryBadge: View {
    let title: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(String(format: "%.1f", value))
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    let ride = Ride()
    let score = RideScore()

    return ScorecardView(ride: ride, score: score)
        .modelContainer(for: [Ride.self, RideScore.self], inMemory: true)
}
