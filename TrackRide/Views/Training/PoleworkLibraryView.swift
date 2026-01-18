//
//  PoleworkLibraryView.swift
//  TrackRide
//
//  Browse polework exercises with dynamic stride calculations
//

import SwiftUI
import SwiftData

struct PoleworkLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PoleworkExercise.name) private var exercises: [PoleworkExercise]
    @Query(filter: #Predicate<Horse> { !$0.isArchived }, sort: \Horse.name) private var horses: [Horse]

    @State private var searchText = ""
    @State private var selectedCategory: PoleworkCategory?
    @State private var selectedDifficulty: PoleworkDifficulty?
    @State private var selectedHorse: Horse?
    @State private var showHorsePicker = false
    @State private var hasInitialized = false
    @State private var showingAddExercise = false
    @State private var exerciseToEdit: PoleworkExercise?

    /// Derived horse size from selected horse, or .average if no horse selected
    private var currentHorseSize: HorseSize {
        selectedHorse?.horseSize ?? .average
    }

    var filteredExercises: [PoleworkExercise] {
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Horse Size Selector Bar
                horseSizeBar

                // Filters
                filterBar

                // Exercise list
                exerciseList
            }
            .navigationTitle("Polework Exercises")
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
                    Button {
                        showHorsePicker = true
                    } label: {
                        Label("Horse", systemImage: "figure.equestrian.sports")
                    }
                }
            }
            .sheet(isPresented: $showHorsePicker) {
                horsePickerSheet
            }
            .sheet(isPresented: $showingAddExercise) {
                PoleworkExerciseEditorView()
            }
            .sheet(item: $exerciseToEdit) { exercise in
                PoleworkExerciseEditorView(exercise: exercise)
            }
            .onAppear {
                initializeBuiltInExercisesIfNeeded()
            }
        }
    }

    // MARK: - Horse Selection Bar

    private var horseSizeBar: some View {
        HStack {
            Image(systemName: "figure.equestrian.sports")
                .foregroundStyle(.orange)

            if let horse = selectedHorse {
                VStack(alignment: .leading, spacing: 2) {
                    Text(horse.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if horse.hasHeightSet {
                        Text("\(horse.formattedHeight) • \(currentHorseSize.shortName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Height not set • Using average")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("No horse selected")
                        .font(.subheadline)

                    Text("Using average distances")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Quick reference button
            NavigationLink {
                QuickReferenceView(horse: selectedHorse, horseSize: currentHorseSize)
            } label: {
                Label("Reference", systemImage: "list.bullet.rectangle")
                    .font(.caption)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .onTapGesture {
            showHorsePicker = true
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
                    ForEach(PoleworkCategory.allCases) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            Label(category.displayName, systemImage: category.icon)
                        }
                    }
                } label: {
                    PoleworkFilterChip(
                        title: selectedCategory?.displayName ?? "Category",
                        isActive: selectedCategory != nil
                    )
                }

                // Difficulty filter
                Menu {
                    Button("All Levels") {
                        selectedDifficulty = nil
                    }
                    ForEach(PoleworkDifficulty.allCases) { level in
                        Button(level.displayName) {
                            selectedDifficulty = level
                        }
                    }
                } label: {
                    PoleworkFilterChip(
                        title: selectedDifficulty?.displayName ?? "Level",
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
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        List {
            // User exercises section (if any)
            let userExercises = filteredExercises.filter { !$0.isBuiltIn }
            if !userExercises.isEmpty {
                Section {
                    ForEach(userExercises) { exercise in
                        NavigationLink(destination: PoleworkExerciseDetailView(
                            exercise: exercise,
                            horse: selectedHorse,
                            onEdit: { exerciseToEdit = $0 }
                        )) {
                            PoleworkExerciseRow(exercise: exercise, horseSize: currentHorseSize, isUserCreated: true)
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
                }
            }

            // Built-in exercises by category
            ForEach(PoleworkCategory.allCases) { category in
                let categoryExercises = filteredExercises.filter { $0.category == category && $0.isBuiltIn }
                if !categoryExercises.isEmpty {
                    Section {
                        ForEach(categoryExercises) { exercise in
                            NavigationLink(destination: PoleworkExerciseDetailView(
                                exercise: exercise,
                                horse: selectedHorse,
                                onEdit: { exerciseToEdit = $0 }
                            )) {
                                PoleworkExerciseRow(exercise: exercise, horseSize: currentHorseSize, isUserCreated: false)
                            }
                        }
                    } header: {
                        Label(category.displayName, systemImage: category.icon)
                    }
                }
            }

            if filteredExercises.isEmpty {
                emptyStateView
            }
        }
        .listStyle(.insetGrouped)
    }

    private func deleteUserExercises(at offsets: IndexSet, from exercises: [PoleworkExercise]) {
        for index in offsets {
            let exercise = exercises[index]
            modelContext.delete(exercise)
        }
        try? modelContext.save()
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
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

    // MARK: - Horse Picker Sheet

    private var horsePickerSheet: some View {
        NavigationStack {
            List {
                // No horse option
                Section {
                    Button {
                        selectedHorse = nil
                        showHorsePicker = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("No Horse Selected")
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Text("Uses average distances (15.2-16.2hh)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selectedHorse == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }

                // Horses with height set
                let horsesWithHeight = horses.filter { $0.hasHeightSet }
                if !horsesWithHeight.isEmpty {
                    Section {
                        ForEach(horsesWithHeight) { horse in
                            Button {
                                selectedHorse = horse
                                showHorsePicker = false
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(horse.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)

                                        Text("\(horse.formattedHeight) • \(horse.horseSize.shortName)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if selectedHorse?.id == horse.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Your Horses")
                    }
                }

                // Horses without height (encourage setting it)
                let horsesWithoutHeight = horses.filter { !$0.hasHeightSet }
                if !horsesWithoutHeight.isEmpty {
                    Section {
                        ForEach(horsesWithoutHeight) { horse in
                            Button {
                                selectedHorse = horse
                                showHorsePicker = false
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(horse.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)

                                        Text("Height not set • Uses average")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }

                                    Spacer()

                                    if selectedHorse?.id == horse.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Set Height for Accurate Distances")
                    } footer: {
                        Text("Add height to your horse's profile for personalized pole distances.")
                    }
                }
            }
            .navigationTitle("Select Horse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showHorsePicker = false
                    }
                }
            }
        }
    }

    // MARK: - Methods

    private func clearFilters() {
        selectedCategory = nil
        selectedDifficulty = nil
    }

    private func initializeBuiltInExercisesIfNeeded() {
        guard !hasInitialized else { return }
        hasInitialized = true

        if exercises.isEmpty {
            let builtIn = PoleworkExerciseData.createBuiltInExercises()
            for exercise in builtIn {
                modelContext.insert(exercise)
            }
            try? modelContext.save()
        }
    }
}

// MARK: - Polework Exercise Row

struct PoleworkExerciseRow: View {
    let exercise: PoleworkExercise
    let horseSize: HorseSize
    var isUserCreated: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(isUserCreated ? Color.purple.opacity(0.2) : Color.orange.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: exercise.category.icon)
                    .foregroundStyle(isUserCreated ? .purple : .orange)
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

                // Distance preview
                let spacing = exercise.formattedSpacing(for: horseSize)
                Text("\(exercise.numberOfPoles) poles • \(spacing.metres)")
                    .font(.caption)
                    .foregroundStyle(.orange)

                HStack(spacing: 4) {
                    Text(exercise.difficulty.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(difficultyColor.opacity(0.2))
                        .foregroundStyle(difficultyColor)
                        .clipShape(Capsule())

                    if exercise.isRaised {
                        Text("Raised")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.2))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }

                    if exercise.isGrid {
                        Text("Grid")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()
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

// MARK: - Polework Filter Chip

struct PoleworkFilterChip: View {
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
        .background(isActive ? Color.orange : Color(.tertiarySystemBackground))
        .foregroundStyle(isActive ? .white : .primary)
        .clipShape(Capsule())
    }
}

// MARK: - Quick Reference View

struct QuickReferenceView: View {
    var horse: Horse?
    let horseSize: HorseSize

    var body: some View {
        List {
            // Horse info section
            Section {
                if let horse = horse {
                    HStack(spacing: 12) {
                        Image(systemName: "figure.equestrian.sports")
                            .font(.title2)
                            .foregroundStyle(.orange)
                            .frame(width: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(horse.name)
                                .font(.headline)

                            if horse.hasHeightSet {
                                Text("\(horse.formattedHeight) • \(horseSize.displayName)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Height not set • Using \(horseSize.displayName)")
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "questionmark.circle")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .frame(width: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("No horse selected")
                                .font(.headline)

                            Text("Using average distances (\(horseSize.displayName))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Distances Calculated For")
            }

            Section {
                ForEach(PoleExerciseType.allCases) { type in
                    let distance = PoleStrideCalculator.formattedDistance(for: type, horseSize: horseSize)
                    HStack {
                        Label(type.displayName, systemImage: type.icon)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(distance.metres)
                                .font(.headline)
                            Text(distance.feet)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Pole Distances")
            } footer: {
                Text("These are recommended starting distances. Adjust based on your horse's individual stride length.")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tips for Setting Up")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    bulletPoint("Start with the calculated distance")
                    bulletPoint("Watch your horse's movement through the poles")
                    bulletPoint("If hitting poles, try slightly longer distances")
                    bulletPoint("If reaching, try slightly shorter distances")
                    bulletPoint("Raised poles need slightly longer distances")
                }
            }
        }
        .navigationTitle("Quick Reference")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }
}

#Preview {
    PoleworkLibraryView()
        .modelContainer(for: [PoleworkExercise.self], inMemory: true)
}
