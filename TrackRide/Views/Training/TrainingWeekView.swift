//
//  TrainingWeekView.swift
//  TrackRide
//
//  Interactive weekly training plan with draggable drills,
//  coaching alignment, and weekly focus display.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct TrainingWeekView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ScheduledWorkout.scheduledDate, order: .forward)
    private var allWorkouts: [ScheduledWorkout]

    @Query private var profiles: [AthleteProfile]

    @Query(sort: \UnifiedDrillSession.startDate, order: .reverse)
    private var recentSessions: [UnifiedDrillSession]

    @Query(sort: \TrainingWeekFocus.weekStartDate, order: .reverse)
    private var weekFocuses: [TrainingWeekFocus]

    @State private var selectedWorkout: ScheduledWorkout?
    @State private var showAddDrill = false
    @State private var addDrillDate: Date?
    @State private var isGeneratingPlan = false
    @State private var draggedWorkout: ScheduledWorkout?
    @State private var refreshID = UUID()  // Force view refresh

    private let planService = TrainingPlanService()
    private let calendar = Calendar.current

    private var profile: AthleteProfile? {
        profiles.first
    }

    /// Get the start of the current week (Monday)
    private var weekStart: Date {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        // weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
        let daysToMonday = (weekday == 1) ? -6 : (2 - weekday)
        return calendar.date(byAdding: .day, value: daysToMonday, to: today) ?? today
    }

    /// Get all 7 days of the week
    private var weekDays: [Date] {
        (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart)
        }
    }

    /// Get only today and future days (up to end of week)
    private var upcomingDays: [Date] {
        let today = calendar.startOfDay(for: Date())
        return weekDays.filter { $0 >= today }
    }

    /// Current week's focus (if any)
    private var currentWeekFocus: TrainingWeekFocus? {
        weekFocuses.first { focus in
            let start = calendar.startOfDay(for: focus.weekStartDate)
            return start == weekStart
        }
    }

    /// Filter workouts to current week
    private var weekWorkouts: [ScheduledWorkout] {
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        return allWorkouts.filter { workout in
            workout.scheduledDate >= weekStart && workout.scheduledDate < weekEnd
        }
    }

    /// Group workouts by day
    private func workoutsForDay(_ day: Date) -> [ScheduledWorkout] {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        return weekWorkouts
            .filter { $0.scheduledDate >= dayStart && $0.scheduledDate < dayEnd && !$0.isSkipped }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Completed count
    private var completedCount: Int {
        weekWorkouts.filter { $0.isCompleted }.count
    }

    /// Total active (not skipped) count
    private var totalActiveCount: Int {
        weekWorkouts.filter { !$0.isSkipped }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Weekly focus header
                weeklyFocusHeader

                // Progress summary
                progressSummary

                // Day rows (vertical layout)
                dayColumnsSection
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .id(refreshID)  // Force refresh when ID changes
        .navigationTitle("Training Week")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        regeneratePlan()
                    } label: {
                        Label("Refresh Plan", systemImage: "arrow.clockwise")
                    }
                    .disabled(isGeneratingPlan)

                    Button {
                        showAddDrill = true
                        addDrillDate = calendar.startOfDay(for: Date())
                    } label: {
                        Label("Add Drill", systemImage: "plus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $selectedWorkout) { workout in
            DrillLauncherSheet(workout: workout) {
                markWorkoutCompleted(workout)
            }
        }
        .sheet(isPresented: $showAddDrill) {
            if let date = addDrillDate {
                AddDrillSheet(targetDate: date) { drillType, duration in
                    addManualDrill(drillType: drillType, date: date, duration: duration)
                }
            }
        }
        .onAppear {
            if weekWorkouts.isEmpty && !isGeneratingPlan {
                regeneratePlan()
            }
        }
    }

    // MARK: - Weekly Focus Header

    private var weeklyFocusHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This Week's Focus")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let focus = currentWeekFocus {
                        HStack(spacing: 8) {
                            Image(systemName: focus.focusDomain.icon)
                                .foregroundStyle(focus.focusDomain.colorValue)
                            Text(focus.focusDomain.displayName)
                                .font(.title2.bold())

                            if let secondary = focus.secondaryFocusDomain {
                                Text("+")
                                    .foregroundStyle(.secondary)
                                Image(systemName: secondary.icon)
                                    .foregroundStyle(secondary.colorValue)
                                Text(secondary.displayName)
                                    .font(.headline)
                            }
                        }
                    } else {
                        Text("Balanced Training")
                            .font(.title2.bold())
                    }
                }

                Spacer()

                // Week date range
                VStack(alignment: .trailing, spacing: 2) {
                    Text(weekRangeText)
                        .font(.subheadline.bold())
                    Text(currentWeekFocus?.weekRangeDescription ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Coaching insight
            if let focus = currentWeekFocus, !focus.focusRationale.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)

                    Text(focus.focusRationale)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var weekRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
    }

    // MARK: - Progress Summary

    private var progressSummary: some View {
        HStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 64, height: 64)

                Circle()
                    .trim(from: 0, to: totalActiveCount > 0 ? CGFloat(completedCount) / CGFloat(totalActiveCount) : 0)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))

                Text("\(completedCount)/\(totalActiveCount)")
                    .font(.caption.bold())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(progressMessage)
                    .font(.subheadline.bold())

                // Domain breakdown
                let domains = Set(weekWorkouts.map { $0.targetDomain })
                HStack(spacing: 4) {
                    ForEach(Array(domains).prefix(4), id: \.self) { domain in
                        Image(systemName: domain.icon)
                            .font(.caption)
                            .foregroundStyle(domain.colorValue)
                    }
                }
            }

            Spacer()

            // Generate button if empty
            if weekWorkouts.isEmpty {
                Button {
                    regeneratePlan()
                } label: {
                    Label("Generate", systemImage: "wand.and.stars")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.blue)
                        .clipShape(Capsule())
                }
                .disabled(isGeneratingPlan)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var progressMessage: String {
        if totalActiveCount == 0 {
            return "No drills scheduled"
        } else if completedCount == 0 {
            return "Ready to start!"
        } else if completedCount == totalActiveCount {
            return "Week complete!"
        } else {
            let remaining = totalActiveCount - completedCount
            return "\(remaining) drill\(remaining == 1 ? "" : "s") remaining"
        }
    }

    // MARK: - Day Columns Section

    private var dayColumnsSection: some View {
        VStack(spacing: 16) {
            ForEach(upcomingDays, id: \.self) { day in
                DayRow(
                    date: day,
                    workouts: workoutsForDay(day),
                    isToday: calendar.isDateInToday(day),
                    onTapWorkout: { workout in
                        selectedWorkout = workout
                    },
                    onDeleteWorkout: { workout in
                        deleteWorkout(workout)
                    },
                    onSkipWorkout: { workout in
                        skipWorkout(workout)
                    },
                    onAddDrill: {
                        addDrillDate = day
                        showAddDrill = true
                    }
                )
            }

            // Show message if no upcoming days have drills
            if upcomingDays.allSatisfy({ workoutsForDay($0).isEmpty }) {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No drills scheduled")
                        .font(.headline)
                    Text("Tap Generate to create a training plan")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }

    // MARK: - Actions

    private func regeneratePlan() {
        isGeneratingPlan = true

        // Run on main actor to ensure SwiftData context is accessed correctly
        Task { @MainActor in
            do {
                // Auto-create profile if none exists
                let activeProfile: AthleteProfile
                if let existingProfile = profile {
                    activeProfile = existingProfile
                } else {
                    let newProfile = AthleteProfile()
                    modelContext.insert(newProfile)
                    try modelContext.save()
                    activeProfile = newProfile
                }

                // Pass weekStart to ensure alignment with view's week
                try planService.regeneratePlan(
                    context: modelContext,
                    profile: activeProfile,
                    recentSessions: Array(recentSessions.prefix(14)),
                    weekStart: weekStart
                )

                // Create or update week focus
                createWeekFocus(profile: activeProfile)

                try modelContext.save()

                // Force view refresh
                refreshID = UUID()
            } catch {
                print("Failed to regenerate plan: \(error)")
            }
            isGeneratingPlan = false
        }
    }

    private func createWeekFocus(profile: AthleteProfile) {
        let domains = SkillDomain.allCases

        // Check if profile has any meaningful data
        let hasData = profile.hasData

        var weakestDomain: SkillDomain = .stability
        var lowestScore: Double = 100
        var secondaryDomain: SkillDomain?
        var secondLowestScore: Double = 100

        if hasData {
            // Find weakest domain to focus on
            for domain in domains {
                let score = profile.score(for: domain)
                if score < lowestScore {
                    lowestScore = score
                    weakestDomain = domain
                }
            }

            // Find secondary focus
            for domain in domains where domain != weakestDomain {
                let score = profile.score(for: domain)
                if score < secondLowestScore {
                    secondLowestScore = score
                    secondaryDomain = domain
                }
            }
        } else {
            // New user - use a balanced starter focus
            weakestDomain = .stability
            secondaryDomain = .balance
            lowestScore = 0
            secondLowestScore = 0
        }

        // Generate rationale
        let rationale: String
        if !hasData {
            rationale = "Welcome! This week focuses on building a solid foundation in \(weakestDomain.displayName.lowercased()) and \(secondaryDomain?.displayName.lowercased() ?? "balance"). These skills transfer across all disciplines."
        } else if lowestScore < 50 {
            rationale = "Your \(weakestDomain.displayName.lowercased()) needs focused attention. This week's drills target building a stronger foundation."
        } else if lowestScore < 70 {
            rationale = "Developing your \(weakestDomain.displayName.lowercased()) will unlock better performance across all disciplines."
        } else {
            rationale = "Maintaining your strong base while pushing for improvement in \(weakestDomain.displayName.lowercased())."
        }

        // Delete existing focus for this week
        let existingFocuses = weekFocuses.filter { focus in
            calendar.startOfDay(for: focus.weekStartDate) == weekStart
        }
        for focus in existingFocuses {
            modelContext.delete(focus)
        }

        // Create new focus
        let focus = TrainingWeekFocus(
            weekStartDate: weekStart,
            focusDomain: weakestDomain,
            secondaryFocusDomain: secondaryDomain,
            focusRationale: rationale,
            coachingInsight: hasData ? weakestDomain.coachingTip : "Complete drills to unlock personalized coaching insights based on your performance."
        )
        modelContext.insert(focus)
    }

    private func markWorkoutCompleted(_ workout: ScheduledWorkout) {
        workout.markCompleted()
        try? modelContext.save()
    }

    private func deleteWorkout(_ workout: ScheduledWorkout) {
        modelContext.delete(workout)
        try? modelContext.save()
    }

    private func skipWorkout(_ workout: ScheduledWorkout) {
        workout.markSkipped()
        try? modelContext.save()
    }

    private func moveWorkout(_ workout: ScheduledWorkout, to newDate: Date) {
        let newDateStart = calendar.startOfDay(for: newDate)
        workout.moveToDate(newDateStart)

        // Update order index to be last in the new day
        let existingInDay = workoutsForDay(newDate)
        let maxOrder = existingInDay.map { $0.orderIndex }.max() ?? -1
        workout.orderIndex = maxOrder + 1

        try? modelContext.save()
    }

    private func addManualDrill(drillType: UnifiedDrillType, date: Date, duration: TimeInterval) {
        let existingInDay = workoutsForDay(date)
        let maxOrder = existingInDay.map { $0.orderIndex }.max() ?? -1

        let workout = ScheduledWorkout(
            drillType: drillType,
            scheduledDate: date,
            intensity: 3,
            duration: duration,
            rationale: "Manually added drill",
            priority: 2,
            targetDomain: drillType.primaryDomain,
            orderIndex: maxOrder + 1,
            isManuallyAdded: true
        )
        modelContext.insert(workout)
        try? modelContext.save()
    }
}

// MARK: - Day Row (Vertical Layout)

struct DayRow: View {
    let date: Date
    let workouts: [ScheduledWorkout]
    let isToday: Bool
    let onTapWorkout: (ScheduledWorkout) -> Void
    let onDeleteWorkout: (ScheduledWorkout) -> Void
    let onSkipWorkout: (ScheduledWorkout) -> Void
    let onAddDrill: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Day header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayName)
                        .font(.headline)
                        .foregroundStyle(isToday ? .blue : .primary)

                    Text(dateString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isToday {
                    Text("Today")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue)
                        .clipShape(Capsule())
                }

                // Add drill button
                Button(action: onAddDrill) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }

            // Workout cards - horizontal scroll for multiple drills
            if workouts.isEmpty {
                Text("Rest day - no drills scheduled")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
                    .padding(.vertical, 8)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(workouts) { workout in
                        ScheduledDrillCardCompact(
                            workout: workout,
                            onTap: { onTapWorkout(workout) },
                            onDelete: { onDeleteWorkout(workout) },
                            onSkip: { onSkipWorkout(workout) }
                        )
                    }
                }
            }
        }
        .padding()
        .background(isToday ? Color.blue.opacity(0.05) : Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isToday ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }

    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"  // Full day name
        return formatter.string(from: date)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }
}

// MARK: - Compact Drill Card (for grid layout)

struct ScheduledDrillCardCompact: View {
    let workout: ScheduledWorkout
    let onTap: () -> Void
    let onDelete: () -> Void
    let onSkip: () -> Void

    var body: some View {
        Button(action: {
            if !workout.isCompleted {
                onTap()
            }
        }) {
            VStack(spacing: 8) {
                // Icon with domain color
                ZStack {
                    Circle()
                        .fill(workout.targetDomain.colorValue.opacity(workout.isCompleted ? 0.3 : 0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: workout.drillType.icon)
                        .font(.title3)
                        .foregroundStyle(workout.isCompleted ? .gray : workout.targetDomain.colorValue)

                    // Completion checkmark
                    if workout.isCompleted {
                        Circle()
                            .fill(.green)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .offset(x: 14, y: -14)
                    }
                }

                // Drill name
                Text(workout.drillType.shortName)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .foregroundStyle(workout.isCompleted ? .secondary : .primary)

                // Duration
                Text(workout.formattedDuration)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(workout.targetDomain.colorValue.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(workout.isCompleted)
        .contextMenu {
            if !workout.isCompleted {
                Button {
                    onTap()
                } label: {
                    Label("Start Drill", systemImage: "play.fill")
                }

                Button {
                    onSkip()
                } label: {
                    Label("Skip", systemImage: "forward.fill")
                }

                Divider()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }

    private var cardBackground: Color {
        if workout.isCompleted {
            return Color(uiColor: .tertiarySystemBackground)
        } else {
            return workout.targetDomain.colorValue.opacity(0.08)
        }
    }
}

// MARK: - Day Column (Legacy - Horizontal Layout)

struct DayColumn: View {
    let date: Date
    let workouts: [ScheduledWorkout]
    let isToday: Bool
    let onTapWorkout: (ScheduledWorkout) -> Void
    let onDeleteWorkout: (ScheduledWorkout) -> Void
    let onSkipWorkout: (ScheduledWorkout) -> Void
    let onAddDrill: () -> Void
    let onDropWorkout: (ScheduledWorkout) -> Void
    @Binding var draggedWorkout: ScheduledWorkout?

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 8) {
            // Day header
            VStack(spacing: 2) {
                Text(dayName)
                    .font(.caption.bold())
                    .foregroundStyle(isToday ? .blue : .secondary)

                Text(dayNumber)
                    .font(.title3.bold())
                    .foregroundStyle(isToday ? .blue : .primary)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(isToday ? Color.blue.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Workout cards
            VStack(spacing: 8) {
                ForEach(workouts) { workout in
                    ScheduledDrillCard(
                        workout: workout,
                        onTap: { onTapWorkout(workout) },
                        onDelete: { onDeleteWorkout(workout) },
                        onSkip: { onSkipWorkout(workout) }
                    )
                    .onDrag {
                        draggedWorkout = workout
                        return NSItemProvider(object: workout.id.uuidString as NSString)
                    }
                }

                // Add drill button
                Button(action: onAddDrill) {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(minHeight: 120)

            Spacer(minLength: 0)
        }
        .frame(width: 100)
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onDrop(of: [.text], isTargeted: nil) { providers in
            if let workout = draggedWorkout {
                onDropWorkout(workout)
                draggedWorkout = nil
                return true
            }
            return false
        }
    }

    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

// MARK: - Scheduled Drill Card

struct ScheduledDrillCard: View {
    let workout: ScheduledWorkout
    let onTap: () -> Void
    let onDelete: () -> Void
    let onSkip: () -> Void

    @State private var showActions = false

    var body: some View {
        Button(action: {
            if !workout.isCompleted {
                onTap()
            }
        }) {
            VStack(spacing: 6) {
                // Icon with domain color
                ZStack {
                    Circle()
                        .fill(workout.targetDomain.colorValue.opacity(workout.isCompleted ? 0.3 : 0.2))
                        .frame(width: 36, height: 36)

                    Image(systemName: workout.drillType.icon)
                        .font(.body)
                        .foregroundStyle(workout.isCompleted ? .gray : workout.targetDomain.colorValue)

                    // Completion checkmark
                    if workout.isCompleted {
                        Circle()
                            .fill(.green)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .offset(x: 12, y: -12)
                    }
                }

                // Drill name
                Text(workout.drillType.shortName)
                    .font(.caption2.bold())
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(workout.isCompleted ? .secondary : .primary)

                // Duration
                Text(workout.formattedDuration)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(workout.targetDomain.colorValue.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(workout.isCompleted)
        .contextMenu {
            if !workout.isCompleted {
                Button {
                    onTap()
                } label: {
                    Label("Start Drill", systemImage: "play.fill")
                }

                Button {
                    onSkip()
                } label: {
                    Label("Skip", systemImage: "forward.fill")
                }

                Divider()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }

    private var cardBackground: Color {
        if workout.isCompleted {
            return Color(.tertiarySystemBackground)
        } else {
            return workout.targetDomain.colorValue.opacity(0.08)
        }
    }
}

// MARK: - Add Drill Sheet

struct AddDrillSheet: View {
    @Environment(\.dismiss) private var dismiss
    let targetDate: Date
    let onAdd: (UnifiedDrillType, TimeInterval) -> Void

    @State private var selectedDrill: UnifiedDrillType?
    @State private var selectedDomain: SkillDomain?
    @State private var duration: Double = 30

    private var filteredDrills: [UnifiedDrillType] {
        if let domain = selectedDomain {
            return UnifiedDrillType.allCases.filter { $0.primaryDomain == domain }
        }
        return UnifiedDrillType.allCases
    }

    var body: some View {
        NavigationStack {
            List {
                // Domain filter
                Section("Filter by Focus Area") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button {
                                selectedDomain = nil
                            } label: {
                                Text("All")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedDomain == nil ? .blue : Color(.tertiarySystemBackground))
                                    .foregroundStyle(selectedDomain == nil ? .white : .primary)
                                    .clipShape(Capsule())
                            }

                            ForEach(SkillDomain.allCases, id: \.self) { domain in
                                Button {
                                    selectedDomain = domain
                                } label: {
                                    Label(domain.displayName, systemImage: domain.icon)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(selectedDomain == domain ? domain.colorValue : Color(.tertiarySystemBackground))
                                        .foregroundStyle(selectedDomain == domain ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                // Drill selection
                Section("Select Drill") {
                    ForEach(filteredDrills, id: \.self) { drill in
                        Button {
                            selectedDrill = drill
                            duration = Double(drill.suggestedDuration)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: drill.icon)
                                    .font(.title3)
                                    .foregroundStyle(drill.primaryDomain.colorValue)
                                    .frame(width: 36)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(drill.displayName)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)

                                    Text(drill.primaryDomain.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if selectedDrill == drill {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }

                // Duration
                if selectedDrill != nil {
                    Section("Duration") {
                        VStack(spacing: 12) {
                            Text("\(Int(duration)) seconds")
                                .font(.headline)

                            Slider(value: $duration, in: 15...180, step: 15)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Add Drill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let drill = selectedDrill {
                            onAdd(drill, duration)
                        }
                        dismiss()
                    }
                    .disabled(selectedDrill == nil)
                }
            }
        }
    }
}

// MARK: - Drill Launcher Sheet

struct DrillLauncherSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let workout: ScheduledWorkout
    let onComplete: () -> Void

    @State private var showDrillView = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Drill info
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(workout.targetDomain.colorValue.opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: workout.drillType.icon)
                            .font(.system(size: 44))
                            .foregroundStyle(workout.targetDomain.colorValue)
                    }

                    Text(workout.drillType.displayName)
                        .font(.title.bold())

                    // Workout details
                    HStack(spacing: 20) {
                        VStack {
                            Text(workout.formattedDuration)
                                .font(.headline)
                            Text("Duration")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()
                            .frame(height: 40)

                        VStack {
                            Text(workout.intensityDescription)
                                .font(.headline)
                            Text("Intensity")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()
                            .frame(height: 40)

                        VStack {
                            Image(systemName: workout.targetDomain.icon)
                                .font(.headline)
                                .foregroundStyle(workout.targetDomain.colorValue)
                            Text(workout.targetDomain.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Rationale
                if !workout.rationale.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Why This Drill?", systemImage: "lightbulb")
                            .font(.subheadline.bold())

                        Text(workout.rationale)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        showDrillView = true
                    } label: {
                        Text("Start Drill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(workout.targetDomain.colorValue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        onComplete()
                        dismiss()
                    } label: {
                        Text("Mark as Complete")
                            .font(.subheadline)
                            .foregroundStyle(workout.targetDomain.colorValue)
                    }
                }
            }
            .padding()
            .navigationTitle("Scheduled Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showDrillView) {
                DrillViewFactory.view(for: workout.drillType, modelContext: modelContext)
                    .onDisappear {
                        onComplete()
                        dismiss()
                    }
            }
        }
    }
}

// MARK: - UnifiedDrillType Extensions

extension UnifiedDrillType {
    var shortName: String {
        switch self {
        // Riding
        case .heelPosition: return "Heels"
        case .coreStability: return "Core"
        case .twoPoint: return "2-Point"
        case .balanceBoard: return "Balance"
        case .hipMobility: return "Hips"
        case .postingRhythm: return "Posting"
        case .riderStillness: return "Stillness"
        case .stirrupPressure: return "Stirrups"
        case .extendedSeatHold: return "Endurance"
        case .mountedBreathing: return "Breathing"
        // Shooting
        case .standingBalance: return "Balance"
        case .boxBreathing: return "Breathing"
        case .dryFire: return "Dry Fire"
        case .reactionTime: return "Reaction"
        case .steadyHold: return "Hold"
        case .recoilControl: return "Recoil"
        case .splitTime: return "Split"
        case .posturalDrift: return "Posture"
        case .stressInoculation: return "Stress"
        // Running
        case .cadenceTraining: return "Cadence"
        case .runningHipMobility: return "Hips"
        case .runningCoreStability: return "Core"
        case .breathingPatterns: return "Breathing"
        case .plyometrics: return "Plyo"
        case .singleLegBalance: return "Balance"
        // Swimming
        case .breathingRhythm: return "Breathing"
        case .swimmingCoreStability: return "Core"
        case .shoulderMobility: return "Shoulders"
        case .streamlinePosition: return "Streamline"
        case .kickEfficiency: return "Kick"
        }
    }

    var primaryDomain: SkillDomain {
        switch self {
        // Stability
        case .coreStability, .riderStillness, .steadyHold, .standingBalance,
             .runningCoreStability, .swimmingCoreStability, .streamlinePosition, .posturalDrift:
            return .stability
        // Balance
        case .balanceBoard, .heelPosition, .twoPoint:
            return .balance
        // Symmetry (mapped from Mobility)
        case .hipMobility, .runningHipMobility, .shoulderMobility:
            return .symmetry
        // Rhythm
        case .postingRhythm, .cadenceTraining, .breathingRhythm, .kickEfficiency:
            return .rhythm
        // Endurance
        case .stressInoculation, .plyometrics:
            return .endurance
        // Calmness
        case .boxBreathing, .breathingPatterns, .dryFire:
            return .calmness
        // Default to stability for other drill types
        default:
            return .stability
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TrainingWeekView()
    }
    .modelContainer(for: [
        ScheduledWorkout.self,
        AthleteProfile.self,
        UnifiedDrillSession.self,
        TrainingWeekFocus.self
    ], inMemory: true)
}
