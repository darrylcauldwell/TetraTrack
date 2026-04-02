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
            // Category filter
            Section {
                HStack {
                    Menu {
                        Button("All Categories") { selectedCategory = nil }
                        Divider()
                        ForEach(FlatworkCategory.allCases) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                Label(category.displayName, systemImage: category.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: selectedCategory?.icon ?? "square.grid.2x2")
                            Text(selectedCategory?.displayName ?? "Category")
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedCategory != nil ? AppColors.primary : Color(.systemGray5))
                        .foregroundStyle(selectedCategory != nil ? .white : .primary)
                        .clipShape(Capsule())
                    }

                    if selectedCategory != nil {
                        Button { selectedCategory = nil } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
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

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(exercise.isBuiltIn ? AppColors.primary.opacity(0.2) : Color.purple.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: exercise.category.icon)
                    .foregroundStyle(exercise.isBuiltIn ? AppColors.primary : .purple)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(exercise.name)
                        .font(.headline)
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}
