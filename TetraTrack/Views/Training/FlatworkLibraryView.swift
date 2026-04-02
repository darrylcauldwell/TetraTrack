//
//  FlatworkLibraryView.swift
//  TetraTrack
//
//  Browse flatwork/dressage exercises — matching groundwork visual style
//

import SwiftUI
import SwiftData

struct FlatworkLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FlatworkExercise.name) private var exercises: [FlatworkExercise]

    @State private var searchText = ""
    @State private var selectedCategory: FlatworkCategory?
    @State private var selectedExercise: FlatworkExercise?
    @State private var hasInitialized = false
    @State private var showingAddExercise = false
    @State private var exerciseToEdit: FlatworkExercise?

    var onSelectExercise: ((FlatworkExercise) -> Void)?

    private var filteredExercises: [FlatworkExercise] {
        var result = exercises
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.exerciseDescription.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result.sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            // Category filter pills
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(FlatworkCategory.allCases) { category in
                            Button {
                                selectedCategory = selectedCategory == category ? nil : category
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: category.icon)
                                    Text(category.displayName)
                                }
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedCategory == category ? AppColors.primary : Color(.systemGray5))
                                .foregroundStyle(selectedCategory == category ? .white : .primary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Exercises
            ForEach(filteredExercises) { exercise in
                FlatworkExerciseRow(exercise: exercise)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedExercise = exercise }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
        .sheet(item: $selectedExercise) { exercise in
            FlatworkExerciseDetailView(
                exercise: exercise,
                onStartRide: onSelectExercise != nil ? { selected in
                    onSelectExercise?(selected)
                } : nil,
                onEdit: { exerciseToEdit = $0 }
            )
        }
        .sheet(isPresented: $showingAddExercise) {
            FlatworkExerciseEditorView()
        }
        .sheet(item: $exerciseToEdit) { exercise in
            FlatworkExerciseEditorView(exercise: exercise)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddExercise = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            initializeBuiltInExercisesIfNeeded()
        }
    }

    // MARK: - Initialize Built-In Exercises

    private func initializeBuiltInExercisesIfNeeded() {
        guard !hasInitialized else { return }
        hasInitialized = true

        if exercises.isEmpty {
            for exercise in FlatworkExerciseData.createBuiltInExercises() {
                modelContext.insert(exercise)
            }
            try? modelContext.save()
        }
    }
}

// MARK: - Exercise Row (Groundwork-matching style)

struct FlatworkExerciseRow: View {
    let exercise: FlatworkExercise
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: exercise.category.icon)
                        .foregroundStyle(AppColors.primary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(exercise.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            if !exercise.isBuiltIn {
                                Text("Custom")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.15))
                                    .foregroundStyle(.purple)
                                    .clipShape(Capsule())
                            }
                        }
                        Text(exercise.category.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(exercise.exerciseDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !exercise.benefits.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text(exercise.benefits.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
