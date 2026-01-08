//
//  PoleworkExerciseEditorView.swift
//  TrackRide
//
//  Create and edit polework exercises with pole distance calculations
//

import SwiftUI
import SwiftData

struct PoleworkExerciseEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let exercise: PoleworkExercise?
    let onSave: ((PoleworkExercise) -> Void)?

    // Basic info
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var difficulty: PoleworkDifficulty = .beginner
    @State private var category: PoleworkCategory = .groundPoles

    // Pole configuration
    @State private var exerciseType: PoleExerciseType = .trotPoles
    @State private var numberOfPoles: Int = 4
    @State private var isRaised: Bool = false
    @State private var raiseHeightCm: Double = 15
    @State private var arrangement: PoleLayoutConfig.PoleArrangement = .straight

    // Gaits
    @State private var selectedGaits: Set<FlatworkGait> = [.trot]

    // Content
    @State private var instructions: [String] = []
    @State private var benefits: [String] = []
    @State private var tips: [String] = []
    @State private var safetyNotes: [String] = []
    @State private var photos: [Data] = []
    @State private var videoAssetIdentifiers: [String] = []
    @State private var videoThumbnails: [Data] = []

    // Input fields
    @State private var newInstruction: String = ""
    @State private var newBenefit: String = ""
    @State private var newTip: String = ""
    @State private var newSafetyNote: String = ""

    @State private var showingDeleteConfirmation = false
    @State private var previewHorseSize: HorseSize = .average

    var isEditing: Bool { exercise != nil }
    var canEdit: Bool { exercise == nil || !(exercise?.isBuiltIn ?? true) }

    init(exercise: PoleworkExercise? = nil, onSave: ((PoleworkExercise) -> Void)? = nil) {
        self.exercise = exercise
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                // Basic Info
                Section {
                    TextField("Exercise Name", text: $name)
                        .disabled(!canEdit)

                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .disabled(!canEdit)
                } header: {
                    Text("Basic Information")
                }

                // Classification
                Section {
                    Picker("Category", selection: $category) {
                        ForEach(PoleworkCategory.allCases) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }
                    .disabled(!canEdit)

                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(PoleworkDifficulty.allCases) { diff in
                            Text(diff.displayName).tag(diff)
                        }
                    }
                    .disabled(!canEdit)
                } header: {
                    Text("Classification")
                }

                // Pole Configuration
                Section {
                    Picker("Exercise Type", selection: $exerciseType) {
                        ForEach(PoleExerciseType.allCases) { type in
                            Label(type.displayName, systemImage: type.icon).tag(type)
                        }
                    }
                    .disabled(!canEdit)

                    Stepper("Number of Poles: \(numberOfPoles)", value: $numberOfPoles, in: 1...12)
                        .disabled(!canEdit)

                    Picker("Arrangement", selection: $arrangement) {
                        Text("Straight").tag(PoleLayoutConfig.PoleArrangement.straight)
                        Text("Fan").tag(PoleLayoutConfig.PoleArrangement.fan)
                        Text("Circle").tag(PoleLayoutConfig.PoleArrangement.circle)
                        Text("Serpentine").tag(PoleLayoutConfig.PoleArrangement.serpentine)
                    }
                    .disabled(!canEdit)

                    Toggle("Raised Poles", isOn: $isRaised)
                        .disabled(!canEdit)

                    if isRaised {
                        HStack {
                            Text("Height")
                            Slider(value: $raiseHeightCm, in: 5...30, step: 5)
                                .disabled(!canEdit)
                            Text("\(Int(raiseHeightCm)) cm")
                                .foregroundStyle(.secondary)
                                .frame(width: 50)
                        }
                    }
                } header: {
                    Text("Pole Configuration")
                }

                // Distance Preview
                Section {
                    Picker("Preview for", selection: $previewHorseSize) {
                        ForEach(HorseSize.allCases) { size in
                            Text(size.shortName).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)

                    let distance = PoleStrideCalculator.formattedDistance(for: exerciseType, horseSize: previewHorseSize)
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Pole Spacing")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(distance.metres)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.orange)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Imperial")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(distance.feet)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Distance Preview")
                } footer: {
                    Text("Distances are calculated based on horse size and exercise type.")
                }

                // Required Gaits
                Section {
                    ForEach(FlatworkGait.allCases) { gait in
                        Toggle(isOn: Binding(
                            get: { selectedGaits.contains(gait) },
                            set: { isOn in
                                if isOn {
                                    selectedGaits.insert(gait)
                                } else {
                                    selectedGaits.remove(gait)
                                }
                            }
                        )) {
                            Label(gait.displayName, systemImage: gait.icon)
                        }
                        .disabled(!canEdit)
                    }
                } header: {
                    Text("Required Gaits")
                }

                // Instructions
                Section {
                    ForEach(Array(instructions.enumerated()), id: \.offset) { index, instruction in
                        HStack {
                            Text("\(index + 1).")
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            Text(instruction)
                            Spacer()
                            if canEdit {
                                Button {
                                    instructions.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                    .onMove { from, to in
                        if canEdit {
                            instructions.move(fromOffsets: from, toOffset: to)
                        }
                    }

                    if canEdit {
                        HStack {
                            TextField("Add instruction...", text: $newInstruction)
                            Button {
                                if !newInstruction.isEmpty {
                                    instructions.append(newInstruction)
                                    newInstruction = ""
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            .disabled(newInstruction.isEmpty)
                        }
                    }
                } header: {
                    Text("Instructions")
                }

                // Benefits
                Section {
                    ForEach(Array(benefits.enumerated()), id: \.offset) { index, benefit in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text(benefit)
                            Spacer()
                            if canEdit {
                                Button {
                                    benefits.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }

                    if canEdit {
                        HStack {
                            TextField("Add benefit...", text: $newBenefit)
                            Button {
                                if !newBenefit.isEmpty {
                                    benefits.append(newBenefit)
                                    newBenefit = ""
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            .disabled(newBenefit.isEmpty)
                        }
                    }
                } header: {
                    Text("Benefits")
                }

                // Tips
                Section {
                    ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                            Text(tip)
                            Spacer()
                            if canEdit {
                                Button {
                                    tips.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }

                    if canEdit {
                        HStack {
                            TextField("Add tip...", text: $newTip)
                            Button {
                                if !newTip.isEmpty {
                                    tips.append(newTip)
                                    newTip = ""
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            .disabled(newTip.isEmpty)
                        }
                    }
                } header: {
                    Text("Tips")
                }

                // Safety Notes
                Section {
                    ForEach(Array(safetyNotes.enumerated()), id: \.offset) { index, note in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text(note)
                            Spacer()
                            if canEdit {
                                Button {
                                    safetyNotes.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }

                    if canEdit {
                        HStack {
                            TextField("Add safety note...", text: $newSafetyNote)
                            Button {
                                if !newSafetyNote.isEmpty {
                                    safetyNotes.append(newSafetyNote)
                                    newSafetyNote = ""
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            .disabled(newSafetyNote.isEmpty)
                        }
                    }
                } header: {
                    Text("Safety Notes")
                }

                // Media (Photos & Videos)
                Section {
                    ExerciseMediaSection(
                        photos: $photos,
                        videoAssetIdentifiers: $videoAssetIdentifiers,
                        videoThumbnails: $videoThumbnails,
                        canEdit: canEdit
                    )
                } header: {
                    Text("Photos & Videos")
                } footer: {
                    Text("Add photos and videos showing the pole layout, distances, or setup reference.")
                }

                // Delete button for user-created exercises
                if isEditing && canEdit {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("Delete Exercise", systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                }

                // Read-only notice for built-in exercises
                if isEditing && !canEdit {
                    Section {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.secondary)
                            Text("This is a built-in exercise and cannot be edited. You can duplicate it to create your own version.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? (canEdit ? "Edit Exercise" : "View Exercise") : "New Polework")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                if canEdit {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveExercise()
                        }
                        .disabled(name.isEmpty)
                    }
                }

                // Duplicate button for built-in exercises
                if isEditing && !canEdit {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            duplicateExercise()
                        } label: {
                            Label("Duplicate", systemImage: "doc.on.doc")
                        }
                    }
                }
            }
            .onAppear {
                loadExercise()
            }
            .confirmationDialog("Delete Exercise", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    deleteExercise()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this exercise? This cannot be undone.")
            }
        }
    }

    private func loadExercise() {
        guard let exercise = exercise else { return }
        name = exercise.name
        description = exercise.exerciseDescription
        difficulty = exercise.difficulty
        category = exercise.category
        exerciseType = exercise.exerciseType
        numberOfPoles = exercise.numberOfPoles
        isRaised = exercise.isRaised
        raiseHeightCm = exercise.raiseHeightCm
        arrangement = exercise.arrangement
        selectedGaits = Set(exercise.requiredGaits)
        instructions = exercise.instructions
        benefits = exercise.benefits
        tips = exercise.tips
        safetyNotes = exercise.safetyNotes
        photos = exercise.photos
        videoAssetIdentifiers = exercise.videoAssetIdentifiers
        videoThumbnails = exercise.videoThumbnails
    }

    private func saveExercise() {
        if let exercise = exercise, canEdit {
            // Update existing
            exercise.name = name
            exercise.exerciseDescription = description
            exercise.difficulty = difficulty
            exercise.category = category
            exercise.exerciseType = exerciseType
            exercise.numberOfPoles = numberOfPoles
            exercise.isRaised = isRaised
            exercise.raiseHeightCm = raiseHeightCm
            exercise.arrangement = arrangement
            exercise.requiredGaits = Array(selectedGaits)
            exercise.instructions = instructions
            exercise.benefits = benefits
            exercise.tips = tips
            exercise.safetyNotes = safetyNotes
            exercise.photos = photos
            exercise.videoAssetIdentifiers = videoAssetIdentifiers
            exercise.videoThumbnails = videoThumbnails
            onSave?(exercise)
        } else {
            // Create new
            let newExercise = PoleworkExercise(
                name: name,
                description: description,
                difficulty: difficulty,
                category: category,
                exerciseType: exerciseType,
                numberOfPoles: numberOfPoles,
                isRaised: isRaised,
                raiseHeightCm: raiseHeightCm,
                arrangement: arrangement,
                instructions: instructions,
                benefits: benefits,
                tips: tips,
                safetyNotes: safetyNotes,
                requiredGaits: Array(selectedGaits)
            )
            newExercise.isBuiltIn = false
            newExercise.photos = photos
            newExercise.videoAssetIdentifiers = videoAssetIdentifiers
            newExercise.videoThumbnails = videoThumbnails
            modelContext.insert(newExercise)
            onSave?(newExercise)
        }

        try? modelContext.save()
        dismiss()
    }

    private func duplicateExercise() {
        let duplicate = PoleworkExercise(
            name: "\(name) (Copy)",
            description: description,
            difficulty: difficulty,
            category: category,
            exerciseType: exerciseType,
            numberOfPoles: numberOfPoles,
            isRaised: isRaised,
            raiseHeightCm: raiseHeightCm,
            arrangement: arrangement,
            instructions: instructions,
            benefits: benefits,
            tips: tips,
            safetyNotes: safetyNotes,
            requiredGaits: Array(selectedGaits)
        )
        duplicate.isBuiltIn = false
        duplicate.photos = photos
        duplicate.videoAssetIdentifiers = videoAssetIdentifiers
        duplicate.videoThumbnails = videoThumbnails
        modelContext.insert(duplicate)
        try? modelContext.save()
        dismiss()
    }

    private func deleteExercise() {
        if let exercise = exercise {
            modelContext.delete(exercise)
            try? modelContext.save()
        }
        dismiss()
    }
}

#Preview {
    PoleworkExerciseEditorView()
        .modelContainer(for: PoleworkExercise.self, inMemory: true)
}
