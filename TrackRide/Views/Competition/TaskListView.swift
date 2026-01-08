//
//  TaskListView.swift
//  TrackRide
//
//  Competition task list view for tracking preparation tasks
//

import SwiftUI
import SwiftData
import WidgetKit

// MARK: - Task List View

struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CompetitionTask.createdAt, order: .reverse) private var allTasks: [CompetitionTask]

    @State private var showingAddTask = false
    @State private var selectedTask: CompetitionTask?
    @State private var groupMode: GroupMode = .category
    @State private var showCompleted = false

    enum GroupMode: String, CaseIterable {
        case category = "Category"
        case dueDate = "Due Date"
        case priority = "Priority"
    }

    private var pendingTasks: [CompetitionTask] {
        allTasks.filter { !$0.isCompleted }.sortedByPriorityAndDate
    }

    private var completedTasks: [CompetitionTask] {
        allTasks.filter { $0.isCompleted }.sorted { ($0.completedAt ?? Date()) > ($1.completedAt ?? Date()) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats header
                    taskStatsHeader

                    // Group mode picker
                    Picker("Group by", selection: $groupMode) {
                        ForEach(GroupMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Pending tasks
                    if pendingTasks.isEmpty {
                        emptyStateView
                    } else {
                        pendingTasksSection
                    }

                    // Completed tasks (collapsible)
                    if !completedTasks.isEmpty {
                        completedTasksSection
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddTask = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                TaskEditView(task: nil, competition: nil)
            }
            .sheet(item: $selectedTask) { task in
                TaskEditView(task: task, competition: task.competition)
            }
        }
    }

    // MARK: - Stats Header

    private var taskStatsHeader: some View {
        HStack(spacing: 16) {
            TaskStatBadge(
                count: pendingTasks.count,
                label: "Pending",
                color: AppColors.primary
            )

            TaskStatBadge(
                count: pendingTasks.filter { $0.isOverdue }.count,
                label: "Overdue",
                color: AppColors.error
            )

            TaskStatBadge(
                count: pendingTasks.filter { $0.isDueSoon }.count,
                label: "Due Soon",
                color: AppColors.warning
            )

            TaskStatBadge(
                count: completedTasks.count,
                label: "Done",
                color: AppColors.active
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Pending Tasks Section

    @ViewBuilder
    private var pendingTasksSection: some View {
        switch groupMode {
        case .category:
            categoryGroupedTasks
        case .dueDate:
            dueDateGroupedTasks
        case .priority:
            priorityGroupedTasks
        }
    }

    private var categoryGroupedTasks: some View {
        let grouped = pendingTasks.groupedByCategory
        let sortedCategories = TaskCategory.allCases.filter { grouped[$0] != nil }

        return ForEach(sortedCategories) { category in
            if let tasks = grouped[category], !tasks.isEmpty {
                TaskGroupSection(
                    title: category.displayName,
                    icon: category.icon,
                    tasks: tasks.sortedByPriorityAndDate,
                    onToggle: toggleTask,
                    onTap: { selectedTask = $0 },
                    onDelete: deleteTask
                )
            }
        }
    }

    private var dueDateGroupedTasks: some View {
        let grouped = pendingTasks.groupedByDueDate
        let sortOrder = ["Overdue", "Today", "Tomorrow", "This Week", "This Month", "Later", "No Due Date"]
        let sortedKeys = sortOrder.filter { grouped[$0] != nil }

        return ForEach(sortedKeys, id: \.self) { key in
            if let tasks = grouped[key], !tasks.isEmpty {
                TaskGroupSection(
                    title: key,
                    icon: iconForDueDateGroup(key),
                    tasks: tasks.sortedByPriorityAndDate,
                    onToggle: toggleTask,
                    onTap: { selectedTask = $0 },
                    onDelete: deleteTask,
                    highlightColor: colorForDueDateGroup(key)
                )
            }
        }
    }

    private var priorityGroupedTasks: some View {
        let grouped = Dictionary(grouping: pendingTasks) { $0.priority }
        let sortedPriorities = TaskPriority.allCases.sorted()

        return ForEach(sortedPriorities, id: \.self) { priority in
            if let tasks = grouped[priority], !tasks.isEmpty {
                TaskGroupSection(
                    title: "\(priority.rawValue) Priority",
                    icon: priority.icon,
                    tasks: tasks.sortedByPriorityAndDate,
                    onToggle: toggleTask,
                    onTap: { selectedTask = $0 },
                    onDelete: deleteTask,
                    highlightColor: colorForPriority(priority)
                )
            }
        }
    }

    // MARK: - Completed Tasks Section

    private var completedTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation { showCompleted.toggle() } }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.active)
                    Text("Completed")
                        .font(.headline)
                    Text("(\(completedTasks.count))")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: showCompleted ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            if showCompleted {
                LazyVStack(spacing: 8) {
                    ForEach(completedTasks) { task in
                        TaskRowView(
                            task: task,
                            onToggle: { toggleTask(task) },
                            onTap: { selectedTask = task }
                        )
                        .opacity(0.7)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Tasks", systemImage: "checklist")
        } description: {
            Text("Add tasks to track your competition preparation")
        } actions: {
            Button("Add Task") {
                showingAddTask = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 40)
    }

    // MARK: - Helper Methods

    private func toggleTask(_ task: CompetitionTask) {
        withAnimation {
            task.toggleCompletion()
        }

        // Bidirectional sync: update competition status based on task type
        if task.category == .entries && task.title.hasPrefix("Submit entry:") {
            task.competition?.isEntered = task.isCompleted
        } else if task.category == .venue && task.title.hasPrefix("Book stable:") {
            task.competition?.isStableBooked = task.isCompleted
        } else if task.category == .travel && task.title.hasPrefix("Plan travel:") {
            task.competition?.isTravelPlanned = task.isCompleted
        }

        // Sync tasks to widgets
        WidgetDataSyncService.shared.syncTasks(context: modelContext)
    }

    private func deleteTask(_ task: CompetitionTask) {
        withAnimation {
            modelContext.delete(task)
        }
        // Sync tasks to widgets
        WidgetDataSyncService.shared.syncTasks(context: modelContext)
    }

    private func iconForDueDateGroup(_ key: String) -> String {
        switch key {
        case "Overdue": return "exclamationmark.circle"
        case "Today": return "calendar.circle"
        case "Tomorrow": return "sunrise"
        case "This Week": return "calendar"
        case "This Month": return "calendar.badge.clock"
        case "Later": return "clock"
        default: return "questionmark.circle"
        }
    }

    private func colorForDueDateGroup(_ key: String) -> Color? {
        switch key {
        case "Overdue": return AppColors.error
        case "Today": return AppColors.warning
        case "Tomorrow": return AppColors.cardOrange
        default: return nil
        }
    }

    private func colorForPriority(_ priority: TaskPriority) -> Color? {
        switch priority {
        case .high: return AppColors.error
        case .medium: return AppColors.warning
        case .low: return nil
        }
    }
}

// MARK: - Task Stat Badge

struct TaskStatBadge: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2.bold())
                .foregroundStyle(count > 0 ? color : .secondary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Task Group Section

struct TaskGroupSection: View {
    let title: String
    let icon: String
    let tasks: [CompetitionTask]
    let onToggle: (CompetitionTask) -> Void
    let onTap: (CompetitionTask) -> Void
    let onDelete: (CompetitionTask) -> Void
    var highlightColor: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(highlightColor ?? AppColors.primary)
                Text(title)
                    .font(.headline)
                Text("(\(tasks.count))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)

            LazyVStack(spacing: 8) {
                ForEach(tasks) { task in
                    TaskRowView(
                        task: task,
                        onToggle: { onToggle(task) },
                        onTap: { onTap(task) }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            onDelete(task)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Task Row View

struct TaskRowView: View {
    let task: CompetitionTask
    let onToggle: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Completion toggle
                Button(action: onToggle) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(task.isCompleted ? AppColors.active : .secondary)
                }
                .buttonStyle(.plain)

                // Task details
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(task.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .strikethrough(task.isCompleted)
                            .foregroundStyle(task.isCompleted ? .secondary : .primary)

                        if task.priority == .high && !task.isCompleted {
                            Image(systemName: "exclamationmark")
                                .font(.caption)
                                .foregroundStyle(AppColors.error)
                        }
                    }

                    HStack(spacing: 8) {
                        // Category badge
                        HStack(spacing: 4) {
                            Image(systemName: task.category.icon)
                            Text(task.category.displayName)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                        // Due date
                        if let dueDateText = task.dueDateText {
                            Text(dueDateText)
                                .font(.caption2)
                                .foregroundStyle(dueDateColor)
                        }

                        // Competition link
                        if let competition = task.competition {
                            HStack(spacing: 2) {
                                Image(systemName: "link")
                                Text(competition.name)
                                    .lineLimit(1)
                            }
                            .font(.caption2)
                            .foregroundStyle(AppColors.primary)
                        }
                    }
                }

                Spacer()

                // Priority indicator
                if !task.isCompleted {
                    Circle()
                        .fill(priorityColor)
                        .frame(width: 8, height: 8)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var dueDateColor: Color {
        if task.isOverdue {
            return AppColors.error
        } else if task.isDueToday {
            return AppColors.warning
        } else if task.isDueSoon {
            return AppColors.cardOrange
        }
        return .secondary
    }

    private var priorityColor: Color {
        switch task.priority {
        case .high: return AppColors.error
        case .medium: return AppColors.warning
        case .low: return AppColors.inactive
        }
    }
}

// MARK: - Task Edit View

struct TaskEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Competition.date, order: .reverse) private var competitions: [Competition]

    let task: CompetitionTask?
    let competition: Competition?

    @State private var title = ""
    @State private var notes = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var priority: TaskPriority = .medium
    @State private var category: TaskCategory = .other
    @State private var selectedCompetition: Competition?
    @State private var showingDeleteConfirmation = false

    var isEditing: Bool { task != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Title", text: $title)

                    Picker("Category", selection: $category) {
                        ForEach(TaskCategory.allCases) { cat in
                            Label(cat.displayName, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }

                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { p in
                            HStack {
                                Image(systemName: p.icon)
                                Text(p.rawValue)
                            }
                            .tag(p)
                        }
                    }
                }

                Section("Due Date") {
                    Toggle("Set Due Date", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker(
                            "Due Date",
                            selection: $dueDate,
                            displayedComponents: [.date]
                        )
                    }
                }

                Section("Competition") {
                    Picker("Link to Competition", selection: $selectedCompetition) {
                        Text("None").tag(nil as Competition?)
                        ForEach(competitions.filter { $0.isUpcoming || $0.isToday }) { comp in
                            Text(comp.name).tag(comp as Competition?)
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete Task", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.isEmpty)
                }
            }
            .confirmationDialog("Delete Task", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let task {
                        modelContext.delete(task)
                    }
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this task?")
            }
            .onAppear {
                if let task {
                    title = task.title
                    notes = task.notes
                    hasDueDate = task.dueDate != nil
                    dueDate = task.dueDate ?? Date()
                    priority = task.priority
                    category = task.category
                    selectedCompetition = task.competition
                } else if let competition {
                    selectedCompetition = competition
                    // Set due date to competition date by default
                    hasDueDate = true
                    dueDate = competition.date
                }
            }
        }
    }

    private func save() {
        let taskToSave = task ?? CompetitionTask()

        taskToSave.title = title
        taskToSave.notes = notes
        taskToSave.dueDate = hasDueDate ? dueDate : nil
        taskToSave.priority = priority
        taskToSave.category = category
        taskToSave.competition = selectedCompetition

        if task == nil {
            modelContext.insert(taskToSave)
        }

        // Sync tasks to widgets
        WidgetDataSyncService.shared.syncTasks(context: modelContext)
        dismiss()
    }
}

// MARK: - Competition Tasks Section (for CompetitionDetailView)

struct CompetitionTasksSection: View {
    @Environment(\.modelContext) private var modelContext
    let competition: Competition
    @Query private var allTasks: [CompetitionTask]

    @State private var showingAddTask = false
    @State private var selectedTask: CompetitionTask?
    @State private var isExpanded = true

    private var competitionTasks: [CompetitionTask] {
        allTasks.filter { $0.competition?.id == competition.id }
    }

    private var pendingTasks: [CompetitionTask] {
        competitionTasks.filter { !$0.isCompleted }.sortedByPriorityAndDate
    }

    private var completedTasks: [CompetitionTask] {
        competitionTasks.filter { $0.isCompleted }
    }

    init(competition: Competition) {
        self.competition = competition
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "checklist")
                        .foregroundStyle(AppColors.primary)
                    Text("Preparation Tasks")
                        .font(.headline)

                    if pendingTasks.count > 0 {
                        Text("\(pendingTasks.count)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(AppColors.primary)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                // Quick add button
                Button(action: { showingAddTask = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AppColors.primary)
                        Text("Add Task")
                            .foregroundStyle(AppColors.primary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                // Pending tasks
                if pendingTasks.isEmpty && completedTasks.isEmpty {
                    Text("No tasks yet. Add tasks to prepare for this competition.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(pendingTasks) { task in
                        CompactTaskRow(task: task) {
                            withAnimation { task.toggleCompletion() }
                            // Bidirectional sync for competition tasks
                            if task.category == .entries && task.title.hasPrefix("Submit entry:") {
                                task.competition?.isEntered = task.isCompleted
                            } else if task.category == .venue && task.title.hasPrefix("Book stable:") {
                                task.competition?.isStableBooked = task.isCompleted
                            } else if task.category == .travel && task.title.hasPrefix("Plan travel:") {
                                task.competition?.isTravelPlanned = task.isCompleted
                            }
                        } onTap: {
                            selectedTask = task
                        }
                    }

                    // Completed tasks summary
                    if !completedTasks.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppColors.active)
                            Text("\(completedTasks.count) completed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }

                // Quick task suggestions
                if competitionTasks.isEmpty {
                    quickTaskSuggestions
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showingAddTask) {
            TaskEditView(task: nil, competition: competition)
        }
        .sheet(item: $selectedTask) { task in
            TaskEditView(task: task, competition: competition)
        }
    }

    private var quickTaskSuggestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Add:")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    QuickTaskButton(title: "Submit entry", category: .entries) {
                        addQuickTask("Submit entry", category: .entries)
                    }
                    QuickTaskButton(title: "Book transport", category: .travel) {
                        addQuickTask("Book transport", category: .travel)
                    }
                    QuickTaskButton(title: "Check equipment", category: .equipment) {
                        addQuickTask("Check equipment", category: .equipment)
                    }
                    QuickTaskButton(title: "Plan route", category: .venue) {
                        addQuickTask("Plan route to venue", category: .venue)
                    }
                }
            }
        }
    }

    private func addQuickTask(_ title: String, category: TaskCategory) {
        let task = CompetitionTask(
            title: title,
            dueDate: competition.entryDeadline ?? Calendar.current.date(byAdding: .day, value: -1, to: competition.date),
            priority: .medium,
            category: category,
            competition: competition
        )
        modelContext.insert(task)
        // Sync tasks to widgets
        WidgetDataSyncService.shared.syncTasks(context: modelContext)
    }
}

// MARK: - Compact Task Row (for Competition Detail)

struct CompactTaskRow: View {
    let task: CompetitionTask
    let onToggle: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Button(action: onToggle) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(task.isCompleted ? AppColors.active : .secondary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.subheadline)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)

                    if let dueDateText = task.dueDateText, !task.isCompleted {
                        Text(dueDateText)
                            .font(.caption2)
                            .foregroundStyle(task.isOverdue ? AppColors.error : .secondary)
                    }
                }

                Spacer()

                // Priority indicator
                if task.priority == .high && !task.isCompleted {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(AppColors.error)
                }

                // Category icon
                Image(systemName: task.category.icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Task Button

struct QuickTaskButton: View {
    let title: String
    let category: TaskCategory
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: category.icon)
                Text(title)
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppColors.primary.opacity(0.1))
            .foregroundStyle(AppColors.primary)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Preview

#Preview {
    TaskListView()
        .modelContainer(for: [CompetitionTask.self, Competition.self], inMemory: true)
}
