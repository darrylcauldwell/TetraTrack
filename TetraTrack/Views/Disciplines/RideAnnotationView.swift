//
//  RideAnnotationView.swift
//  TetraTrack
//
//  Post-ride annotation sheet for Watch-primary rides.
//  Allows assigning horse, scores, and notes after a ride.
//

import SwiftUI
import SwiftData

struct RideAnnotationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Horse> { !$0.isArchived }, sort: \Horse.name) private var horses: [Horse]

    let ride: Ride

    @State private var selectedHorse: Horse?
    @State private var notes: String
    @State private var dressageScore: String = ""
    @State private var sjFaults: String = ""
    @State private var sjTimePenalties: String = ""

    init(ride: Ride) {
        self.ride = ride
        _selectedHorse = State(initialValue: ride.horse)
        _notes = State(initialValue: ride.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Ride type
                Section("Ride Type") {
                    HStack {
                        Image(systemName: ride.rideType.icon)
                            .foregroundStyle(ride.rideType.color)
                        Text(ride.rideType.rawValue)
                    }
                }

                // Horse selection
                Section("Horse") {
                    if horses.isEmpty {
                        Text("No horses added yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(horses) { horse in
                                    horseCard(horse)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // Watch metrics (read-only)
                if ride.detectedJumpCount > 0 || ride.leftTurnCount > 0 || ride.armSteadiness > 0 {
                    Section("Watch Metrics") {
                        if ride.detectedJumpCount > 0 {
                            LabeledContent("Jumps", value: "\(ride.detectedJumpCount)")
                        }
                        if ride.leftTurnCount > 0 || ride.rightTurnCount > 0 {
                            LabeledContent("Turns", value: "L:\(ride.leftTurnCount) R:\(ride.rightTurnCount)")
                        }
                        if ride.armSteadiness > 0 {
                            LabeledContent("Arm Steadiness", value: String(format: "%.0f%%", ride.armSteadiness))
                        }
                        if ride.postingRhythm > 0 {
                            LabeledContent("Posting Rhythm", value: String(format: "%.0f%%", ride.postingRhythm))
                        }
                        if ride.haltCount > 0 {
                            LabeledContent("Halts", value: "\(ride.haltCount)")
                        }
                    }
                }

                // Scores (type-specific)
                if ride.rideType == .dressage {
                    Section("Dressage Score") {
                        TextField("Score (e.g. 65.5)", text: $dressageScore)
                            .keyboardType(.decimalPad)
                    }
                }

                if ride.rideType == .showjumping {
                    Section("Showjumping") {
                        TextField("Faults", text: $sjFaults)
                            .keyboardType(.numberPad)
                        TextField("Time Penalties", text: $sjTimePenalties)
                            .keyboardType(.decimalPad)
                    }
                }

                // Notes
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Ride Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAnnotation()
                        dismiss()
                    }
                }
            }
        }
    }

    private func horseCard(_ horse: Horse) -> some View {
        Button {
            selectedHorse = horse
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "figure.equestrian.sports")
                    .font(.title2)
                    .foregroundStyle(selectedHorse?.id == horse.id ? .white : .green)
                Text(horse.name)
                    .font(.caption2)
                    .foregroundStyle(selectedHorse?.id == horse.id ? .white : .primary)
            }
            .frame(width: 70, height: 70)
            .background(selectedHorse?.id == horse.id ? Color.green : Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func saveAnnotation() {
        ride.horse = selectedHorse
        ride.notes = notes
        try? modelContext.save()
    }
}
