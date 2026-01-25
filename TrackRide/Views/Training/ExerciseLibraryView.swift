//
//  ExerciseLibraryView.swift
//  TrackRide
//
//  Browse arena exercises and schooling figures
//

import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory?
    @State private var selectedDifficulty: ExerciseDifficulty?
    @State private var selectedExercise: Exercise?
    @State private var hasInitialized = false

    var filteredExercises: [Exercise] {
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
            if $0.difficulty.sortOrder != $1.difficulty.sortOrder {
                return $0.difficulty.sortOrder < $1.difficulty.sortOrder
            }
            return $0.name < $1.name
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Category filter
                        Menu {
                            Button("All Categories") {
                                selectedCategory = nil
                            }
                            ForEach(ExerciseCategory.allCases, id: \.self) { category in
                                Button(category.rawValue) {
                                    selectedCategory = category
                                }
                            }
                        } label: {
                            FilterChip(
                                title: selectedCategory?.rawValue ?? "Category",
                                isActive: selectedCategory != nil
                            )
                        }

                        // Difficulty filter
                        Menu {
                            Button("All Levels") {
                                selectedDifficulty = nil
                            }
                            ForEach(ExerciseDifficulty.allCases, id: \.self) { level in
                                Button(level.rawValue) {
                                    selectedDifficulty = level
                                }
                            }
                        } label: {
                            FilterChip(
                                title: selectedDifficulty?.rawValue ?? "Level",
                                isActive: selectedDifficulty != nil
                            )
                        }

                        // Clear filters
                        if selectedCategory != nil || selectedDifficulty != nil {
                            Button(action: clearFilters) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(AppColors.cardBackground)

                // Exercise list
                List {
                    ForEach(ExerciseCategory.allCases, id: \.self) { category in
                        let categoryExercises = filteredExercises.filter { $0.category == category }
                        if !categoryExercises.isEmpty {
                            Section(category.rawValue) {
                                ForEach(categoryExercises) { exercise in
                                    ExerciseRow(exercise: exercise)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedExercise = exercise
                                        }
                                }
                            }
                        }
                    }

                    if filteredExercises.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)

                            Text("No exercises found")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            Text("Try adjusting your filters")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Exercise Library")
            .searchable(text: $searchText, prompt: "Search exercises")
            .sheet(item: $selectedExercise) { exercise in
                NavigationStack {
                    ExerciseDetailView(exercise: exercise)
                }
            }
            .onAppear {
                initializeBuiltInExercisesIfNeeded()
            }
            .presentationBackground(Color.black)
        }
    }

    private func clearFilters() {
        selectedCategory = nil
        selectedDifficulty = nil
    }

    private func initializeBuiltInExercisesIfNeeded() {
        guard !hasInitialized else { return }
        hasInitialized = true

        if exercises.isEmpty {
            let builtIn = Exercise.createBuiltInExercises()
            for exercise in builtIn {
                modelContext.insert(exercise)
            }
            try? modelContext.save()
        }
    }
}

struct FilterChip: View {
    let title: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.subheadline)
            Image(systemName: "chevron.down")
                .font(.caption2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? AppColors.primary : AppColors.elevatedSurface)
        .foregroundStyle(isActive ? .white : .primary)
        .clipShape(Capsule())
    }
}

struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: exercise.category.icon)
                    .foregroundStyle(AppColors.primary)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(exercise.name)
                        .font(.headline)

                    if exercise.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Text(exercise.exerciseDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Text(exercise.difficulty.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(difficultyColor.opacity(0.2))
                        .foregroundStyle(difficultyColor)
                        .clipShape(Capsule())
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
        case .novice: return .blue
        case .elementary: return .orange
        case .medium: return .purple
        case .advanced: return .red
        }
    }
}

struct ExerciseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var exercise: Exercise

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: exercise.category.icon)
                            .font(.title)
                            .foregroundStyle(AppColors.primary)

                        VStack(alignment: .leading) {
                            Text(exercise.name)
                                .font(.title2)
                                .fontWeight(.bold)

                            HStack(spacing: 8) {
                                Text(exercise.category.rawValue)
                                Text("•")
                                Text(exercise.difficulty.rawValue)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(action: toggleFavorite) {
                            Image(systemName: exercise.isFavorite ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundStyle(exercise.isFavorite ? .red : .secondary)
                        }
                    }

                    Text(exercise.exerciseDescription)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Instructions
                if !exercise.instructions.isEmpty {
                    DetailSection(title: "How to Ride", icon: "list.number") {
                        Text(exercise.instructions)
                            .font(.body)
                    }
                }

                // Tips
                if !exercise.tips.isEmpty {
                    DetailSection(title: "Tips", icon: "lightbulb.fill") {
                        Text(exercise.tips)
                            .font(.body)
                    }
                }

                // Common Mistakes
                if !exercise.commonMistakes.isEmpty {
                    DetailSection(title: "Common Mistakes", icon: "exclamationmark.triangle.fill") {
                        Text(exercise.commonMistakes)
                            .font(.body)
                    }
                }

                // Benefits
                if !exercise.benefits.isEmpty {
                    DetailSection(title: "Benefits", icon: "checkmark.circle.fill") {
                        Text(exercise.benefits)
                            .font(.body)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func toggleFavorite() {
        exercise.isFavorite.toggle()
        try? modelContext.save()
    }
}

struct DetailSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(AppColors.primary)
                Text(title)
                    .font(.headline)
            }

            content
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ExerciseLibraryView()
        .modelContainer(for: [Exercise.self], inMemory: true)
}
