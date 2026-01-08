//
//  FlatworkLibraryView.swift
//  TrackRide
//
//  Browse flatwork/dressage exercises with filtering and search
//

import SwiftUI
import SwiftData

struct FlatworkLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FlatworkExercise.name) private var exercises: [FlatworkExercise]

    @State private var searchText = ""
    @State private var selectedCategory: FlatworkCategory?
    @State private var selectedDifficulty: FlatworkDifficulty?
    @State private var selectedExercise: FlatworkExercise?
    @State private var hasInitialized = false
    @State private var showingAddExercise = false
    @State private var exerciseToEdit: FlatworkExercise?

    // Callback for when an exercise is selected to start a ride
    var onSelectExercise: ((FlatworkExercise) -> Void)?

    private var filteredExercises: [FlatworkExercise] {
        var result = exercises

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if let difficulty = selectedDifficulty {
            result = result.filter { $0.difficulty == difficulty }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.exerciseDescription.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result.sorted {
            if $0.category.sortOrder != $1.category.sortOrder {
                return $0.category.sortOrder < $1.category.sortOrder
            }
            if $0.difficulty.sortOrder != $1.difficulty.sortOrder {
                return $0.difficulty.sortOrder < $1.difficulty.sortOrder
            }
            return $0.name < $1.name
        }
    }

    private var exercisesByCategory: [(FlatworkCategory, [FlatworkExercise])] {
        let grouped = Dictionary(grouping: filteredExercises) { $0.category }
        return FlatworkCategory.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { category in
                guard let exercises = grouped[category], !exercises.isEmpty else { return nil }
                return (category, exercises)
            }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                filterBar

                // Exercise list
                if exercisesByCategory.isEmpty {
                    emptyStateView
                } else {
                    exerciseListView
                }
            }
            .navigationTitle("Flatwork Exercises")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingAddExercise = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedExercise) { exercise in
                FlatworkExerciseDetailView(
                    exercise: exercise,
                    onStartRide: onSelectExercise != nil ? { selectedExercise in
                        dismiss()
                        onSelectExercise?(selectedExercise)
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
            .onAppear {
                initializeBuiltInExercisesIfNeeded()
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Category filter
                Menu {
                    Button("All Categories") {
                        selectedCategory = nil
                    }
                    Divider()
                    ForEach(FlatworkCategory.allCases) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            Label(category.displayName, systemImage: category.icon)
                        }
                    }
                } label: {
                    FlatworkFilterChip(
                        title: selectedCategory?.displayName ?? "Category",
                        icon: selectedCategory?.icon ?? "square.grid.2x2",
                        isActive: selectedCategory != nil
                    )
                }

                // Difficulty filter
                Menu {
                    Button("All Levels") {
                        selectedDifficulty = nil
                    }
                    Divider()
                    ForEach(FlatworkDifficulty.allCases) { difficulty in
                        Button(difficulty.displayName) {
                            selectedDifficulty = difficulty
                        }
                    }
                } label: {
                    FlatworkFilterChip(
                        title: selectedDifficulty?.displayName ?? "Level",
                        icon: "chart.bar.fill",
                        isActive: selectedDifficulty != nil
                    )
                }

                // Clear filters button
                if selectedCategory != nil || selectedDifficulty != nil {
                    Button {
                        withAnimation {
                            selectedCategory = nil
                            selectedDifficulty = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Exercise List

    private var exerciseListView: some View {
        List {
            // User exercises section (if any)
            let userExercises = filteredExercises.filter { !$0.isBuiltIn }
            if !userExercises.isEmpty {
                Section {
                    ForEach(userExercises) { exercise in
                        FlatworkExerciseRow(exercise: exercise, isUserCreated: true)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedExercise = exercise
                            }
                    }
                    .onDelete { indexSet in
                        deleteUserExercises(at: indexSet, from: userExercises)
                    }
                } header: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.purple)
                        Text("My Exercises")
                    }
                    .font(.headline)
                }
            }

            // Built-in exercises by category
            ForEach(exercisesByCategory, id: \.0) { category, categoryExercises in
                let builtInExercises = categoryExercises.filter { $0.isBuiltIn }
                if !builtInExercises.isEmpty {
                    Section {
                        ForEach(builtInExercises) { exercise in
                            FlatworkExerciseRow(exercise: exercise, isUserCreated: false)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedExercise = exercise
                                }
                        }
                    } header: {
                        HStack(spacing: 8) {
                            Image(systemName: category.icon)
                                .foregroundStyle(AppColors.primary)
                            Text(category.displayName)
                        }
                        .font(.headline)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func deleteUserExercises(at offsets: IndexSet, from exercises: [FlatworkExercise]) {
        for index in offsets {
            let exercise = exercises[index]
            modelContext.delete(exercise)
        }
        try? modelContext.save()
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No exercises found")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Try adjusting your filters or search terms")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            if selectedCategory != nil || selectedDifficulty != nil {
                Button("Clear Filters") {
                    withAnimation {
                        selectedCategory = nil
                        selectedDifficulty = nil
                    }
                }
                .buttonStyle(.bordered)
                .tint(AppColors.primary)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Data Initialization

    private func initializeBuiltInExercisesIfNeeded() {
        guard !hasInitialized else { return }
        hasInitialized = true

        if exercises.isEmpty {
            let builtIn = FlatworkExerciseData.createBuiltInExercises()
            for exercise in builtIn {
                modelContext.insert(exercise)
            }
            try? modelContext.save()
        }
    }
}

// MARK: - Filter Chip

struct FlatworkFilterChip: View {
    let title: String
    let icon: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)

            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            Image(systemName: "chevron.down")
                .font(.caption2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isActive ? AppColors.primary : Color(.tertiarySystemBackground))
        .foregroundStyle(isActive ? .white : .primary)
        .clipShape(Capsule())
    }
}

// MARK: - Exercise Row

struct FlatworkExerciseRow: View {
    let exercise: FlatworkExercise
    var isUserCreated: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            ZStack {
                Circle()
                    .fill(isUserCreated ? Color.purple.opacity(0.15) : AppColors.primary.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: exercise.category.icon)
                    .font(.title3)
                    .foregroundStyle(isUserCreated ? .purple : AppColors.primary)
            }

            // Exercise info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(exercise.name)
                        .font(.headline)

                    if exercise.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if isUserCreated {
                        Text("Custom")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }
                }

                Text(exercise.exerciseDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                // Tags row
                HStack(spacing: 8) {
                    // Difficulty tag
                    Text(exercise.difficulty.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(difficultyColor.opacity(0.15))
                        .foregroundStyle(difficultyColor)
                        .clipShape(Capsule())

                    // Gait tags
                    HStack(spacing: 4) {
                        ForEach(exercise.requiredGaits) { gait in
                            Image(systemName: gait.icon)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var difficultyColor: Color {
        switch exercise.difficulty {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
}

// MARK: - Preview

#Preview {
    FlatworkLibraryView()
        .modelContainer(for: [FlatworkExercise.self], inMemory: true)
}
