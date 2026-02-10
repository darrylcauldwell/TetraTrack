//
//  WorkoutBuilderView.swift
//  TetraTrack
//
//  Create and edit structured workout templates
//

import SwiftUI
import SwiftData

struct WorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse) private var templates: [WorkoutTemplate]

    @State private var showingNewWorkout = false
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var hasInitializedBuiltIn = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Built-in workouts
                    let builtIn = templates.filter { $0.isBuiltIn }
                    if !builtIn.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            GlassSectionHeader("Built-in Workouts", icon: "checkmark.seal.fill")

                            VStack(spacing: 10) {
                                ForEach(builtIn) { template in
                                    Button {
                                        selectedTemplate = template
                                    } label: {
                                        WorkoutTemplateRow(template: template)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Custom workouts
                    let custom = templates.filter { !$0.isBuiltIn }
                    VStack(alignment: .leading, spacing: 12) {
                        GlassSectionHeader("My Workouts", icon: "person.fill")

                        if custom.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "timer")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)

                                Text("No custom workouts yet")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Text("Create structured interval workouts to guide your training sessions")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .glassCard(material: .ultraThin, cornerRadius: 16)
                            .padding(.horizontal)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(custom) { template in
                                    Button {
                                        selectedTemplate = template
                                    } label: {
                                        WorkoutTemplateRow(template: template)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Create button
                    Button(action: { showingNewWorkout = true }) {
                        Label("Create New Workout", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(GlassButtonStyle(tint: AppColors.primary))
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Workouts")
            .glassNavigation()
            .sheet(isPresented: $showingNewWorkout) {
                NavigationStack {
                    WorkoutBuilderView(template: nil)
                }
            }
            .sheet(item: $selectedTemplate) { template in
                NavigationStack {
                    WorkoutDetailView(template: template)
                }
            }
            .onAppear {
                initializeBuiltInWorkoutsIfNeeded()
            }
            .presentationBackground(Color.black)
        }
    }

    private func initializeBuiltInWorkoutsIfNeeded() {
        guard !hasInitializedBuiltIn else { return }
        hasInitializedBuiltIn = true

        // Check if built-in workouts exist
        let builtInCount = templates.filter { $0.isBuiltIn }.count
        if builtInCount == 0 {
            // Create built-in templates
            let builtInTemplates = WorkoutTemplate.createBuiltInTemplates()
            for template in builtInTemplates {
                modelContext.insert(template)
            }
            try? modelContext.save()
        }
    }

    private func deleteCustomWorkouts(at offsets: IndexSet) {
        let custom = templates.filter { !$0.isBuiltIn }
        for index in offsets {
            modelContext.delete(custom[index])
        }
    }
}

struct WorkoutTemplateRow: View {
    let template: WorkoutTemplate

    var body: some View {
        HStack(spacing: 12) {
            // Glass icon bubble
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: "timer")
                    .font(.title3)
                    .foregroundStyle(AppColors.primary)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(template.name)
                        .font(.headline)

                    if template.isBuiltIn {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(AppColors.primary)
                    }
                }

                Text("\((template.blocks ?? []).count) intervals • \(template.formattedTotalDuration)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    GlassChip(template.discipline.rawValue, color: AppColors.primary)

                    Text(template.difficulty.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let template: WorkoutTemplate

    @State private var showingExecution = false

    var body: some View {
        List {
            // Header
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(template.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    if !template.workoutDescription.isEmpty {
                        Text(template.workoutDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 16) {
                        Label(template.formattedTotalDuration, systemImage: "clock")
                        Label("\((template.blocks ?? []).count) intervals", systemImage: "list.bullet")
                        Label(template.difficulty.rawValue, systemImage: template.difficulty.icon)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            // Intervals
            Section("Intervals") {
                ForEach(template.sortedBlocks) { block in
                    WorkoutBlockRow(block: block, index: template.sortedBlocks.firstIndex(of: block) ?? 0)
                }
            }

            // Start button
            Section {
                Button(action: { showingExecution = true }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Workout")
                    }
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .fullScreenCover(isPresented: $showingExecution) {
            WorkoutExecutionView(template: template)
        }
    }
}

struct WorkoutBlockRow: View {
    let block: WorkoutBlock
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            // Index
            Text("\(index + 1)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(intensityColor)
                .clipShape(Circle())

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(block.name.isEmpty ? "Interval \(index + 1)" : block.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text(block.formattedDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let gait = block.targetGait {
                        Text(gait.rawValue.capitalized)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(gaitColor(gait).opacity(0.2))
                            .foregroundStyle(gaitColor(gait))
                            .clipShape(Capsule())
                    }

                    Text(block.intensity.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var intensityColor: Color {
        switch block.intensity {
        case .recovery: return .green
        case .easy: return .blue
        case .moderate: return .yellow
        case .hard: return .orange
        case .maximum: return .red
        }
    }

    private func gaitColor(_ gait: GaitType) -> Color {
        switch gait {
        case .stationary: return .gray
        case .walk: return AppColors.walk
        case .trot: return AppColors.trot
        case .canter: return AppColors.canter
        case .gallop: return AppColors.gallop
        }
    }
}

// MARK: - Workout Builder

struct WorkoutBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let template: WorkoutTemplate?

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var discipline: RideType = .schooling
    @State private var difficulty: WorkoutDifficulty = .intermediate
    @State private var blocks: [WorkoutBlock] = []
    @State private var showingAddBlock = false

    var body: some View {
        Form {
            Section("Workout Details") {
                TextField("Workout Name", text: $name)
                TextField("Description (optional)", text: $description)

                Picker("Discipline", selection: $discipline) {
                    ForEach(RideType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                Picker("Difficulty", selection: $difficulty) {
                    ForEach(WorkoutDifficulty.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
            }

            Section("Intervals") {
                if blocks.isEmpty {
                    Text("Add intervals to build your workout")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                        WorkoutBlockRow(block: block, index: index)
                    }
                    .onMove(perform: moveBlocks)
                    .onDelete(perform: deleteBlocks)
                }

                Button(action: { showingAddBlock = true }) {
                    Label("Add Interval", systemImage: "plus.circle")
                }
            }

            if !blocks.isEmpty {
                Section {
                    HStack {
                        Text("Total Duration")
                        Spacer()
                        Text(formattedTotalDuration)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(template == nil ? "New Workout" : "Edit Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveWorkout()
                }
                .disabled(name.isEmpty || blocks.isEmpty)
            }
        }
        .sheet(isPresented: $showingAddBlock) {
            NavigationStack {
                AddBlockView { block in
                    block.orderIndex = blocks.count
                    blocks.append(block)
                }
            }
        }
        .onAppear {
            if let template = template {
                name = template.name
                description = template.workoutDescription
                discipline = template.discipline
                difficulty = template.difficulty
                blocks = template.sortedBlocks
            }
        }
        .presentationBackground(Color.black)
    }

    private var formattedTotalDuration: String {
        let total = blocks.reduce(0) { $0 + $1.durationSeconds }
        let minutes = total / 60
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remaining = minutes % 60
            return "\(hours)h \(remaining)m"
        }
    }

    private func moveBlocks(from source: IndexSet, to destination: Int) {
        blocks.move(fromOffsets: source, toOffset: destination)
        for (index, block) in blocks.enumerated() {
            block.orderIndex = index
        }
    }

    private func deleteBlocks(at offsets: IndexSet) {
        blocks.remove(atOffsets: offsets)
        for (index, block) in blocks.enumerated() {
            block.orderIndex = index
        }
    }

    private func saveWorkout() {
        let workout = template ?? WorkoutTemplate()
        workout.name = name
        workout.workoutDescription = description
        workout.discipline = discipline
        workout.difficulty = difficulty
        workout.isBuiltIn = false

        // Clear existing blocks if editing
        if template != nil {
            for block in workout.blocks ?? [] {
                modelContext.delete(block)
            }
            workout.blocks?.removeAll()
        }

        // Add new blocks
        for block in blocks {
            workout.addBlock(block)
            modelContext.insert(block)
        }

        if template == nil {
            modelContext.insert(workout)
        }

        try? modelContext.save()
        dismiss()
    }
}

struct AddBlockView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (WorkoutBlock) -> Void

    @State private var name: String = ""
    @State private var minutes: Int = 3
    @State private var seconds: Int = 0
    @State private var targetGait: GaitType?
    @State private var intensity: WorkoutIntensity = .moderate

    var body: some View {
        Form {
            Section("Interval Details") {
                TextField("Name (e.g., 'Warm-up trot')", text: $name)

                HStack {
                    Stepper("Minutes: \(minutes)", value: $minutes, in: 0...30)
                }

                HStack {
                    Stepper("Seconds: \(seconds)", value: $seconds, in: 0...55, step: 5)
                }

                Picker("Target Gait", selection: $targetGait) {
                    Text("Any").tag(nil as GaitType?)
                    ForEach(GaitType.allCases.filter { $0 != .stationary }, id: \.self) { gait in
                        Text(gait.rawValue.capitalized).tag(gait as GaitType?)
                    }
                }

                Picker("Intensity", selection: $intensity) {
                    ForEach(WorkoutIntensity.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
            }

            Section {
                Text(intensity.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Add Interval")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    let block = WorkoutBlock(
                        name: name,
                        durationSeconds: minutes * 60 + seconds,
                        targetGait: targetGait,
                        intensity: intensity
                    )
                    onSave(block)
                    dismiss()
                }
                .disabled(minutes == 0 && seconds == 0)
            }
        }
    }
}

#Preview {
    WorkoutListView()
        .modelContainer(for: [WorkoutTemplate.self, WorkoutBlock.self], inMemory: true)
}
