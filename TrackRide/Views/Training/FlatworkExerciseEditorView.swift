//
//  FlatworkExerciseEditorView.swift
//  TrackRide
//
//  Create and edit flatwork exercises
//

import SwiftUI
import SwiftData

struct FlatworkExerciseEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let exercise: FlatworkExercise?
    let onSave: ((FlatworkExercise) -> Void)?

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var difficulty: FlatworkDifficulty = .beginner
    @State private var category: FlatworkCategory = .figures
    @State private var selectedGaits: Set<FlatworkGait> = []
    @State private var instructions: [String] = []
    @State private var benefits: [String] = []
    @State private var tips: [String] = []
    @State private var photos: [Data] = []
    @State private var videoAssetIdentifiers: [String] = []
    @State private var videoThumbnails: [Data] = []

    @State private var newInstruction: String = ""
    @State private var newBenefit: String = ""
    @State private var newTip: String = ""

    @State private var showingDeleteConfirmation = false

    var isEditing: Bool { exercise != nil }
    var canEdit: Bool { exercise == nil || !(exercise?.isBuiltIn ?? true) }

    init(exercise: FlatworkExercise? = nil, onSave: ((FlatworkExercise) -> Void)? = nil) {
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

                // Category & Difficulty
                Section {
                    Picker("Category", selection: $category) {
                        ForEach(FlatworkCategory.allCases) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }
                    .disabled(!canEdit)

                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(FlatworkDifficulty.allCases) { diff in
                            Text(diff.displayName).tag(diff)
                        }
                    }
                    .disabled(!canEdit)
                } header: {
                    Text("Classification")
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
                    Text("Add photos and videos showing the exercise pattern, arena layout, or demonstration.")
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
            .navigationTitle(isEditing ? (canEdit ? "Edit Exercise" : "View Exercise") : "New Exercise")
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
        selectedGaits = Set(exercise.requiredGaits)
        instructions = exercise.instructions
        benefits = exercise.benefits
        tips = exercise.tips
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
            exercise.requiredGaits = Array(selectedGaits)
            exercise.instructions = instructions
            exercise.benefits = benefits
            exercise.tips = tips
            exercise.photos = photos
            exercise.videoAssetIdentifiers = videoAssetIdentifiers
            exercise.videoThumbnails = videoThumbnails
            onSave?(exercise)
        } else {
            // Create new
            let newExercise = FlatworkExercise(
                name: name,
                description: description,
                difficulty: difficulty,
                category: category,
                instructions: instructions,
                benefits: benefits,
                tips: tips,
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
        let duplicate = FlatworkExercise(
            name: "\(name) (Copy)",
            description: description,
            difficulty: difficulty,
            category: category,
            instructions: instructions,
            benefits: benefits,
            tips: tips,
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
    FlatworkExerciseEditorView()
        .modelContainer(for: FlatworkExercise.self, inMemory: true)
}
