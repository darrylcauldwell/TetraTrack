//
//  CoachingNotesSheet.swift
//  TetraTrack
//
//  Coaching notes input for trusted contacts watching a live tracking session
//

import SwiftUI

struct CoachingNotesSheet: View {
    let session: LiveTrackingSession
    @Binding var noteText: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Input section
                HStack(spacing: 12) {
                    TextField("Add coaching note...", text: $noteText)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTextFieldFocused)
                        .submitLabel(.send)
                        .onSubmit { addNote() }

                    Button {
                        addNote()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                    .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)

                // Notes list
                if session.coachingNotes.isEmpty {
                    ContentUnavailableView(
                        "No Notes Yet",
                        systemImage: "note.text",
                        description: Text("Add coaching observations for the rider to review after their session.")
                    )
                } else {
                    List(session.coachingNotes.reversed()) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.text)
                                .font(.body)

                            HStack {
                                Text(note.authorName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                if let start = session.startTime {
                                    let elapsed = note.timestamp.timeIntervalSince(start)
                                    Text("at \(elapsed.formattedDuration)")
                                        .font(.caption)
                                }
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Coaching Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
        .sheetBackground()
    }

    private func addNote() {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        session.addCoachingNote(text: trimmed, authorName: "Coach")
        noteText = ""
    }
}

// MARK: - Coaching Notes Card (for ride insights)

struct CoachingNotesCard: View {
    let notes: [CoachingNote]
    let rideStartDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundStyle(.blue)
                Text("Coaching Notes")
                    .font(.headline)
                Spacer()
                Text("\(notes.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(notes) { note in
                HStack(alignment: .top, spacing: 8) {
                    let elapsed = note.timestamp.timeIntervalSince(rideStartDate)
                    Text(elapsed.formattedDuration)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.blue)
                        .frame(width: 50, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.text)
                            .font(.subheadline)
                        Text(note.authorName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
