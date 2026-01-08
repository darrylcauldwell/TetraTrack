//
//  CompetitionComponents.swift
//  TrackRide
//
//  Competition subviews extracted from CompetitionCalendarView
//

import SwiftUI
import SwiftData
import Combine
import WidgetKit

// MARK: - Next Competition Card

struct NextCompetitionCard: View {
    let competition: Competition
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: competition.competitionType.icon)
                    .font(.title2)
                Text("Next Competition")
                    .font(.headline)
                Spacer()
                Text(competition.level.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.primary.opacity(0.2))
                    .clipShape(Capsule())
            }

            Text(competition.name)
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            // Countdown
            CountdownView(targetDate: competition.date, now: now)

            HStack {
                Label(competition.location, systemImage: "mappin")
                Spacer()
                Text(competition.formattedDate)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if competition.isEntered {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Entered")
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.primary.opacity(0.3), lineWidth: 2)
        )
        .padding(.horizontal)
        .onReceive(timer) { _ in
            now = Date()
        }
    }
}

// MARK: - Countdown View

struct CountdownView: View {
    let targetDate: Date
    let now: Date

    private var components: (days: Int, hours: Int, minutes: Int, seconds: Int) {
        let interval = targetDate.timeIntervalSince(now)
        guard interval > 0 else { return (0, 0, 0, 0) }

        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60

        return (days, hours, minutes, seconds)
    }

    var body: some View {
        HStack(spacing: 12) {
            CountdownUnit(value: components.days, label: "Days")
            CountdownSeparator()
            CountdownUnit(value: components.hours, label: "Hours")
            CountdownSeparator()
            CountdownUnit(value: components.minutes, label: "Mins")
            CountdownSeparator()
            CountdownUnit(value: components.seconds, label: "Secs")
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CountdownUnit: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(AppColors.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 50)
    }
}

struct CountdownSeparator: View {
    var body: some View {
        Text(":")
            .font(.title2.bold())
            .foregroundStyle(.secondary)
    }
}

// MARK: - Competition Row View

struct CompetitionRowView: View {
    let competition: Competition

    var body: some View {
        HStack(spacing: 12) {
            // Date badge
            VStack(spacing: 2) {
                Text(dayOfMonth)
                    .font(.title2.bold())
                Text(monthAbbrev)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 50)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(competition.name)
                        .font(.headline)
                    Spacer()
                    if competition.isEntered {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }

                HStack {
                    Image(systemName: competition.competitionType.icon)
                        .font(.caption)
                    Text(competition.competitionType.rawValue)
                    Text("•")
                    Text(competition.level.rawValue)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack {
                    Image(systemName: "mappin")
                    Text(competition.location)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // Countdown
            if competition.isUpcoming {
                Text(competition.countdownText)
                    .font(.caption.bold())
                    .foregroundStyle(competition.daysUntil <= 7 ? .orange : .secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var dayOfMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: competition.date)
    }

    private var monthAbbrev: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: competition.date)
    }
}

// MARK: - Entry Deadline Row View

struct EntryDeadlineRowView: View {
    let competition: Competition

    var body: some View {
        HStack(spacing: 12) {
            // Date badge
            VStack(spacing: 2) {
                Text(dayOfMonth)
                    .font(.title2.bold())
                Text(monthAbbrev)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 50)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text("Entry deadline")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                        .strikethrough(competition.isEntered)
                    Spacer()
                    if competition.isEntered {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Entered")
                                .foregroundStyle(.green)
                        }
                        .font(.caption)
                    }
                }

                Text(competition.name)
                    .font(.headline)
                    .foregroundStyle(competition.isEntered ? .secondary : .primary)
                    .strikethrough(competition.isEntered)

                HStack {
                    Image(systemName: "mappin")
                    Text(competition.location)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // Countdown
            if !competition.isEntered, let deadline = competition.entryDeadline {
                let daysLeft = competition.daysUntilEntryDeadline ?? 0
                Text(deadlineCountdown(deadline))
                    .font(.caption.bold())
                    .foregroundStyle(daysLeft <= 3 ? .red : (daysLeft <= 7 ? .orange : .secondary))
            }
        }
        .padding()
        .background(competition.isEntered ? Color(.secondarySystemBackground) : Color.orange.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(competition.isEntered ? Color.clear : Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private var dayOfMonth: String {
        guard let deadline = competition.entryDeadline else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: deadline)
    }

    private var monthAbbrev: String {
        guard let deadline = competition.entryDeadline else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: deadline)
    }

    private func deadlineCountdown(_ deadline: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: now, to: deadline)

        guard let days = components.day else { return "" }

        if days < 0 {
            return "Overdue"
        } else if days == 0 {
            return "Today!"
        } else if days == 1 {
            return "Tomorrow"
        } else if days < 7 {
            return "\(days) days"
        } else {
            let weeks = days / 7
            return weeks == 1 ? "1 week" : "\(weeks) weeks"
        }
    }
}

// MARK: - Stable Deadline Row View

struct StableDeadlineRowView: View {
    let competition: Competition

    var body: some View {
        HStack(spacing: 12) {
            // Date badge
            VStack(spacing: 2) {
                Text(dayOfMonth)
                    .font(.title2.bold())
                Text(monthAbbrev)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 50)
            .padding(.vertical, 8)
            .background(Color.purple.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "bed.double.fill")
                        .foregroundStyle(.purple)
                        .font(.caption)
                    Text("Stable booking deadline")
                        .font(.subheadline.bold())
                        .foregroundStyle(.purple)
                        .strikethrough(competition.isStableBooked)
                    Spacer()
                    if competition.isStableBooked {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Booked")
                                .foregroundStyle(.green)
                        }
                        .font(.caption)
                    }
                }

                Text(competition.name)
                    .font(.headline)
                    .foregroundStyle(competition.isStableBooked ? .secondary : .primary)
                    .strikethrough(competition.isStableBooked)

                HStack {
                    Image(systemName: "mappin")
                    Text(competition.location)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // Countdown
            if !competition.isStableBooked, let deadline = competition.stableDeadline {
                let daysLeft = competition.daysUntilStableDeadline ?? 0
                Text(deadlineCountdown(deadline))
                    .font(.caption.bold())
                    .foregroundStyle(daysLeft <= 3 ? .red : (daysLeft <= 7 ? .orange : .secondary))
            }
        }
        .padding()
        .background(competition.isStableBooked ? Color(.secondarySystemBackground) : Color.purple.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(competition.isStableBooked ? Color.clear : Color.purple.opacity(0.3), lineWidth: 1)
        )
    }

    private var dayOfMonth: String {
        guard let deadline = competition.stableDeadline else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: deadline)
    }

    private var monthAbbrev: String {
        guard let deadline = competition.stableDeadline else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: deadline)
    }

    private func deadlineCountdown(_ deadline: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: now, to: deadline)

        guard let days = components.day else { return "" }

        if days < 0 {
            return "Overdue"
        } else if days == 0 {
            return "Today!"
        } else if days == 1 {
            return "Tomorrow"
        } else if days < 7 {
            return "\(days) days"
        } else {
            let weeks = days / 7
            return weeks == 1 ? "1 week" : "\(weeks) weeks"
        }
    }
}

// MARK: - Competition Detail View

struct CompetitionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var competition: Competition
    @Query private var allTasks: [CompetitionTask]

    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingScorecard = false
    @State private var showingMediaEditor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: competition.competitionType.icon)
                            .font(.largeTitle)
                            .foregroundStyle(AppColors.primary)

                        Text(competition.name)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)

                        HStack {
                            Text(competition.competitionType.rawValue)
                            Text("•")
                            Text(competition.level.rawValue)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding()

                    // Countdown or status
                    if competition.isUpcoming {
                        CountdownView(targetDate: competition.date, now: Date())
                            .padding(.horizontal)
                    } else if competition.isCompleted {
                        CompletedBadge()
                    }

                    // Details
                    VStack(spacing: 16) {
                        DetailRow(icon: "calendar", title: "Date", value: competition.formattedDateRange)
                        DetailRow(icon: "mappin", title: "Location", value: competition.location)

                        if !competition.venue.isEmpty {
                            DetailRow(icon: "building.2", title: "Venue", value: competition.venue)
                        }

                        if let deadline = competition.entryDeadline {
                            DetailRow(
                                icon: "clock",
                                title: "Entry Deadline",
                                value: formatDate(deadline),
                                highlight: competition.daysUntilEntryDeadline ?? 0 <= 7
                            )
                        }

                        if let fee = competition.entryFee {
                            DetailRow(icon: "sterlingsign.circle", title: "Entry Fee", value: String(format: "£%.2f", fee))
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Disciplines & Scorecard
                    if !competition.competitionType.disciplines.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Disciplines")
                                    .font(.headline)
                                Spacer()
                                Button {
                                    showingScorecard = true
                                } label: {
                                    Label("Scorecard", systemImage: "list.clipboard")
                                        .font(.caption)
                                }
                            }

                            ForEach(competition.competitionType.disciplines, id: \.self) { discipline in
                                HStack {
                                    Image(systemName: iconForDiscipline(discipline))
                                    Text(discipline)
                                    Spacer()
                                    scoreForDiscipline(discipline)
                                }
                                .padding(.vertical, 8)
                            }

                            // Total score if available
                            if competition.hasAnyScore {
                                Divider()
                                HStack {
                                    Text("Total Points")
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text("\(competition.totalPoints)")
                                        .font(.title3.bold())
                                        .foregroundStyle(AppColors.primary)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Status toggles
                    VStack(spacing: 12) {
                        Toggle(isOn: $competition.isEntered) {
                            Label("Entered", systemImage: competition.isEntered ? "checkmark.circle.fill" : "circle")
                        }
                        .onChange(of: competition.isEntered) { _, isEntered in
                            syncEntryTaskCompletion(isEntered: isEntered)
                        }

                        if competition.stableDeadline != nil {
                            Toggle(isOn: $competition.isStableBooked) {
                                Label("Stable Booked", systemImage: competition.isStableBooked ? "bed.double.fill" : "bed.double")
                            }
                            .onChange(of: competition.isStableBooked) { _, isBooked in
                                syncStableTaskCompletion(isBooked: isBooked)
                            }
                        }

                        Toggle(isOn: $competition.isTravelPlanned) {
                            Label("Travel Planned", systemImage: competition.isTravelPlanned ? "car.fill" : "car")
                        }
                        .onChange(of: competition.isTravelPlanned) { _, isPlanned in
                            syncTravelTaskCompletion(isPlanned: isPlanned)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Notes
                    if !competition.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                            Text(competition.notes)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Media Gallery (photos and videos)
                    if !competition.photos.isEmpty || !competition.videoAssetIdentifiers.isEmpty {
                        CompetitionMediaGallery(
                            photos: competition.photos,
                            videoAssetIdentifiers: competition.videoAssetIdentifiers,
                            videoThumbnails: competition.videoThumbnails
                        )
                        .padding(.horizontal)
                    }

                    // Add Media button
                    Button {
                        showingMediaEditor = true
                    } label: {
                        HStack {
                            Image(systemName: "photo.badge.plus")
                            Text(competition.photos.isEmpty && competition.videoAssetIdentifiers.isEmpty ? "Add Photos & Videos" : "Edit Photos & Videos")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    // Preparation tasks (SwiftData-backed)
                    CompetitionTasksSection(competition: competition)
                        .padding(.horizontal)

                    // Legacy todo list for follow-up tasks
                    CompetitionTodoListView(competition: competition)
                        .padding(.horizontal)

                    // Delete button
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Competition", systemImage: "trash")
                    }
                    .padding(.top)
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { showingEditSheet = true }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                CompetitionEditView(competition: competition)
            }
            .sheet(isPresented: $showingScorecard) {
                CompetitionScorecardView(competition: competition)
            }
            .sheet(isPresented: $showingMediaEditor) {
                CompetitionMediaEditorView(competition: competition)
            }
            .confirmationDialog("Delete Competition", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    modelContext.delete(competition)
                    // Sync competitions to widgets
                    WidgetDataSyncService.shared.syncCompetitions(context: modelContext)
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this competition?")
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func iconForDiscipline(_ discipline: String) -> String {
        switch discipline.lowercased() {
        case "riding", "dressage", "show jumping", "cross country":
            return "figure.equestrian.sports"
        case "shooting":
            return "target"
        case "swimming":
            return "figure.pool.swim"
        case "running":
            return "figure.run"
        default:
            return "star"
        }
    }

    @ViewBuilder
    private func scoreForDiscipline(_ discipline: String) -> some View {
        switch discipline.lowercased() {
        case "riding":
            if let score = competition.ridingScore {
                Text(String(format: "%.1f", score))
                    .foregroundStyle(.secondary)
            }
        case "shooting":
            if let score = competition.shootingScore {
                Text("\(score)")
                    .foregroundStyle(.secondary)
            }
        case "swimming":
            if let distance = competition.swimmingDistance {
                Text(String(format: "%.0fm", distance))
                    .foregroundStyle(.secondary)
            }
        case "running":
            if let time = competition.runningTime {
                Text(formatTime(time))
                    .foregroundStyle(.secondary)
            }
        default:
            EmptyView()
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func syncEntryTaskCompletion(isEntered: Bool) {
        // Find the entry task for this competition
        guard let task = allTasks.first(where: { task in
            task.competition?.id == competition.id &&
            task.category == .entries &&
            task.title.hasPrefix("Submit entry:")
        }) else { return }

        // Sync completion status
        task.isCompleted = isEntered
        task.completedAt = isEntered ? Date() : nil
    }

    private func syncStableTaskCompletion(isBooked: Bool) {
        // Find the stable booking task for this competition
        guard let task = allTasks.first(where: { task in
            task.competition?.id == competition.id &&
            task.category == .venue &&
            task.title.hasPrefix("Book stable:")
        }) else { return }

        // Sync completion status
        task.isCompleted = isBooked
        task.completedAt = isBooked ? Date() : nil
    }

    private func syncTravelTaskCompletion(isPlanned: Bool) {
        // Find the travel planning task for this competition
        guard let task = allTasks.first(where: { task in
            task.competition?.id == competition.id &&
            task.category == .travel &&
            task.title.hasPrefix("Plan travel:")
        }) else { return }

        // Sync completion status
        task.isCompleted = isPlanned
        task.completedAt = isPlanned ? Date() : nil
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    var highlight: Bool = false

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(highlight ? .orange : .primary)
        }
    }
}

// MARK: - Completed Badge

struct CompletedBadge: View {
    var body: some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
            Text("Completed")
        }
        .font(.headline)
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.green)
        .clipShape(Capsule())
    }
}

// MARK: - Competition Edit View

struct CompetitionEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Horse> { !$0.isArchived }, sort: \Horse.name) private var horses: [Horse]
    @Query private var allTasks: [CompetitionTask]

    let competition: Competition?

    @State private var name = ""
    @State private var date = Date()
    @State private var endDate: Date?
    @State private var hasEndDate = false
    @State private var location = ""
    @State private var venue = ""
    @State private var competitionType: CompetitionType = .tetrathlon
    @State private var level: CompetitionLevel = .junior
    @State private var notes = ""
    @State private var hasEntryDeadline = false
    @State private var entryDeadline = Date()
    @State private var entryFee: Double?
    @State private var websiteURL = ""
    @State private var selectedHorse: Horse?

    // Stable booking
    @State private var hasStableDeadline = false
    @State private var stableDeadline = Date()

    // Travel plan
    @State private var startTime: Date?
    @State private var courseWalkTime: Date?
    @State private var estimatedArrivalAtVenue: Date?
    @State private var estimatedTravelMinutes: Int?
    @State private var travelRouteNotes = ""
    @State private var departureFromYard: Date?
    @State private var departureFromVenue: Date?
    @State private var arrivalBackAtYard: Date?

    var isEditing: Bool { competition != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event Details") {
                    TextField("Competition Name", text: $name)

                    Picker("Type", selection: $competitionType) {
                        ForEach(CompetitionType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    Picker("Level", selection: $level) {
                        ForEach(CompetitionLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                }

                // Horse selection
                if !horses.isEmpty {
                    Section("Horse") {
                        Picker("Competing Horse", selection: $selectedHorse) {
                            Text("Not Selected").tag(nil as Horse?)
                            ForEach(horses) { horse in
                                HStack {
                                    HorseAvatarView(horse: horse, size: 24)
                                    Text(horse.name)
                                }
                                .tag(horse as Horse?)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }

                Section("Date & Location") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    Toggle("Multi-day Event", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("End Date", selection: Binding(
                            get: { endDate ?? date },
                            set: { endDate = $0 }
                        ), displayedComponents: .date)
                    }

                    TextField("Location", text: $location)
                    TextField("Venue (optional)", text: $venue)
                }

                Section("Entry & Booking") {
                    Toggle("Entry Deadline", isOn: $hasEntryDeadline)
                    if hasEntryDeadline {
                        DatePicker("Entry Deadline", selection: $entryDeadline, displayedComponents: .date)
                    }

                    Toggle("Stable Booking Deadline", isOn: $hasStableDeadline)
                    if hasStableDeadline {
                        DatePicker("Stable Deadline", selection: $stableDeadline, displayedComponents: .date)
                    }

                    TextField("Entry Fee (optional)", value: $entryFee, format: .currency(code: "GBP"))
                        .keyboardType(.decimalPad)

                    TextField("Website URL (optional)", text: $websiteURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }

                Section("Travel Plan") {
                    DatePicker("Start Time", selection: Binding(
                        get: { startTime ?? date },
                        set: { startTime = $0 }
                    ), displayedComponents: [.date, .hourAndMinute])

                    DatePicker("Course Walk Time", selection: Binding(
                        get: { courseWalkTime ?? date },
                        set: { courseWalkTime = $0 }
                    ), displayedComponents: [.date, .hourAndMinute])

                    DatePicker("Arrival at Venue", selection: Binding(
                        get: { estimatedArrivalAtVenue ?? date },
                        set: { estimatedArrivalAtVenue = $0 }
                    ), displayedComponents: [.date, .hourAndMinute])

                    TextField("Travel Time (minutes)", value: $estimatedTravelMinutes, format: .number)
                        .keyboardType(.numberPad)

                    DatePicker("Depart from Yard", selection: Binding(
                        get: { departureFromYard ?? date },
                        set: { departureFromYard = $0 }
                    ), displayedComponents: [.date, .hourAndMinute])

                    DatePicker("Depart from Venue", selection: Binding(
                        get: { departureFromVenue ?? date },
                        set: { departureFromVenue = $0 }
                    ), displayedComponents: [.date, .hourAndMinute])

                    DatePicker("Arrive Back Home", selection: Binding(
                        get: { arrivalBackAtYard ?? date },
                        set: { arrivalBackAtYard = $0 }
                    ), displayedComponents: [.date, .hourAndMinute])

                    TextField("Route Notes", text: $travelRouteNotes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(isEditing ? "Edit Competition" : "Add Competition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let comp = competition {
                    name = comp.name
                    date = comp.date
                    endDate = comp.endDate
                    hasEndDate = comp.endDate != nil
                    location = comp.location
                    venue = comp.venue
                    competitionType = comp.competitionType
                    level = comp.level
                    notes = comp.notes
                    hasEntryDeadline = comp.entryDeadline != nil
                    entryDeadline = comp.entryDeadline ?? Date()
                    entryFee = comp.entryFee
                    websiteURL = comp.websiteURL
                    selectedHorse = comp.horse

                    // Stable booking
                    hasStableDeadline = comp.stableDeadline != nil
                    stableDeadline = comp.stableDeadline ?? Date()

                    // Travel plan
                    startTime = comp.startTime
                    courseWalkTime = comp.courseWalkTime
                    estimatedArrivalAtVenue = comp.estimatedArrivalAtVenue
                    estimatedTravelMinutes = comp.estimatedTravelMinutes
                    travelRouteNotes = comp.travelRouteNotes
                    departureFromYard = comp.departureFromYard
                    departureFromVenue = comp.departureFromVenue
                    arrivalBackAtYard = comp.arrivalBackAtYard
                }
            }
        }
    }

    private func save() {
        let comp = competition ?? Competition()

        comp.name = name
        comp.date = date
        comp.endDate = hasEndDate ? endDate : nil
        comp.location = location
        comp.venue = venue
        comp.competitionType = competitionType
        comp.level = level
        comp.notes = notes
        comp.entryDeadline = hasEntryDeadline ? entryDeadline : nil
        comp.entryFee = entryFee
        comp.websiteURL = websiteURL
        comp.horse = selectedHorse

        // Stable booking
        comp.stableDeadline = hasStableDeadline ? stableDeadline : nil

        // Travel plan
        comp.startTime = startTime
        comp.courseWalkTime = courseWalkTime
        comp.estimatedArrivalAtVenue = estimatedArrivalAtVenue
        comp.estimatedTravelMinutes = estimatedTravelMinutes
        comp.travelRouteNotes = travelRouteNotes
        comp.departureFromYard = departureFromYard
        comp.departureFromVenue = departureFromVenue
        comp.arrivalBackAtYard = arrivalBackAtYard

        if competition == nil {
            modelContext.insert(comp)
        }

        // Auto-create entry deadline task if deadline is set
        if hasEntryDeadline {
            createOrUpdateEntryTask(for: comp)
        }

        // Auto-create stable booking task if deadline is set
        if hasStableDeadline {
            createOrUpdateStableTask(for: comp)
        }

        // Auto-create travel planning task (due 2 days before event)
        createOrUpdateTravelTask(for: comp)

        // Sync competitions to widgets
        WidgetDataSyncService.shared.syncCompetitions(context: modelContext)
        dismiss()
    }

    private func createOrUpdateEntryTask(for comp: Competition) {
        // Check if an entry task already exists for this competition
        let existingTask = allTasks.first { task in
            task.competition?.id == comp.id &&
            task.category == .entries &&
            task.title.hasPrefix("Submit entry:")
        }

        if let task = existingTask {
            // Update existing task's due date if changed
            task.dueDate = comp.entryDeadline
        } else {
            // Create new entry deadline task
            let task = CompetitionTask()
            task.title = "Submit entry: \(comp.name)"
            task.dueDate = comp.entryDeadline
            task.category = .entries
            task.priority = .high
            task.competition = comp
            task.isCompleted = comp.isEntered
            if comp.isEntered {
                task.completedAt = Date()
            }
            modelContext.insert(task)
        }
    }

    private func createOrUpdateStableTask(for comp: Competition) {
        // Check if a stable booking task already exists for this competition
        let existingTask = allTasks.first { task in
            task.competition?.id == comp.id &&
            task.category == .venue &&
            task.title.hasPrefix("Book stable:")
        }

        if let task = existingTask {
            // Update existing task's due date if changed
            task.dueDate = comp.stableDeadline
        } else {
            // Create new stable booking task
            let task = CompetitionTask()
            task.title = "Book stable: \(comp.name)"
            task.dueDate = comp.stableDeadline
            task.category = .venue
            task.priority = .high
            task.competition = comp
            task.isCompleted = comp.isStableBooked
            if comp.isStableBooked {
                task.completedAt = Date()
            }
            modelContext.insert(task)
        }
    }

    private func createOrUpdateTravelTask(for comp: Competition) {
        // Check if a travel planning task already exists for this competition
        let existingTask = allTasks.first { task in
            task.competition?.id == comp.id &&
            task.category == .travel &&
            task.title.hasPrefix("Plan travel:")
        }

        // Calculate due date (2 days before event)
        let dueDate = Calendar.current.date(byAdding: .day, value: -2, to: comp.date)

        if let task = existingTask {
            // Update existing task's due date if changed
            task.dueDate = dueDate
        } else {
            // Create new travel planning task
            let task = CompetitionTask()
            task.title = "Plan travel: \(comp.name)"
            task.dueDate = dueDate
            task.category = .travel
            task.priority = .medium
            task.competition = comp
            task.isCompleted = comp.isTravelPlanned
            if comp.isTravelPlanned {
                task.completedAt = Date()
            }
            modelContext.insert(task)
        }
    }
}

// MARK: - Competition Scorecard View

struct CompetitionScorecardView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var competition: Competition

    @State private var ridingScore: String = ""
    @State private var shootingScore: String = ""
    @State private var swimmingDistance: String = ""
    @State private var runningMinutes: String = ""
    @State private var runningSeconds: String = ""
    @State private var placement: String = ""
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                // Competition info header
                Section {
                    VStack(alignment: .center, spacing: 8) {
                        Image(systemName: competition.competitionType.icon)
                            .font(.largeTitle)
                            .foregroundStyle(AppColors.primary)
                        Text(competition.name)
                            .font(.headline)
                        Text(competition.formattedDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                // Discipline scores
                Section("Discipline Scores") {
                    if competition.competitionType.disciplines.contains("Riding") ||
                       competition.competitionType.disciplines.contains("Dressage") {
                        HStack {
                            Label("Riding", systemImage: "figure.equestrian.sports")
                            Spacer()
                            TextField("Score", text: $ridingScore)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("pts")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if competition.competitionType.disciplines.contains("Shooting") {
                        HStack {
                            Label("Shooting", systemImage: "target")
                            Spacer()
                            TextField("Score", text: $shootingScore)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("/200")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if competition.competitionType.disciplines.contains("Swimming") {
                        HStack {
                            Label("Swimming", systemImage: "figure.pool.swim")
                            Spacer()
                            TextField("Distance", text: $swimmingDistance)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("m")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if competition.competitionType.disciplines.contains("Running") {
                        HStack {
                            Label("Running", systemImage: "figure.run")
                            Spacer()
                            TextField("Min", text: $runningMinutes)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 50)
                            Text(":")
                            TextField("Sec", text: $runningSeconds)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 50)
                        }
                    }
                }

                // Overall result
                Section("Result") {
                    HStack {
                        Label("Placement", systemImage: "medal")
                        Spacer()
                        TextField("e.g. 3rd", text: $placement)
                            .multilineTextAlignment(.trailing)
                    }

                    // Calculated total
                    if calculatedTotal > 0 {
                        HStack {
                            Label("Total Points", systemImage: "sum")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(calculatedTotal)")
                                .font(.title3.bold())
                                .foregroundStyle(AppColors.primary)
                        }
                    }
                }

                // Notes
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Scorecard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveScores() }
                }
            }
            .onAppear {
                loadExistingScores()
            }
        }
    }

    private var calculatedTotal: Int {
        var total = 0

        if let riding = Double(ridingScore) {
            total += Int(riding)
        }
        if let shooting = Int(shootingScore) {
            total += shooting
        }
        // Swimming and running would need conversion formulas based on competition rules
        // For now, just show what we have

        return total
    }

    private func loadExistingScores() {
        if let score = competition.ridingScore {
            ridingScore = String(format: "%.1f", score)
        }
        if let score = competition.shootingScore {
            shootingScore = "\(score)"
        }
        if let distance = competition.swimmingDistance {
            swimmingDistance = "\(Int(distance))"
        }
        if let time = competition.runningTime {
            let mins = Int(time) / 60
            let secs = Int(time) % 60
            runningMinutes = "\(mins)"
            runningSeconds = String(format: "%02d", secs)
        }
        placement = competition.placement ?? ""
        notes = competition.resultNotes ?? ""
    }

    private func saveScores() {
        competition.ridingScore = Double(ridingScore)
        competition.shootingScore = Int(shootingScore)
        competition.swimmingDistance = Double(swimmingDistance)

        if let mins = Int(runningMinutes), let secs = Int(runningSeconds) {
            competition.runningTime = TimeInterval(mins * 60 + secs)
        }

        competition.placement = placement.isEmpty ? nil : placement
        competition.resultNotes = notes.isEmpty ? nil : notes
        competition.isCompleted = true

        dismiss()
    }
}

// MARK: - Competition Todo List View

struct CompetitionTodoListView: View {
    @Bindable var competition: Competition
    @State private var newTodoText = ""
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "checklist")
                        .foregroundStyle(AppColors.primary)
                    Text("Follow-up Tasks")
                        .font(.headline)

                    if competition.pendingTodosCount > 0 {
                        Text("\(competition.pendingTodosCount)")
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
                // Add new todo
                HStack {
                    TextField("Add task (e.g., collect rosette)", text: $newTodoText)
                        .textFieldStyle(.roundedBorder)

                    Button(action: addTodo) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(newTodoText.isEmpty ? .gray : AppColors.primary)
                    }
                    .disabled(newTodoText.isEmpty)
                }

                // Todo list
                if competition.todos.isEmpty {
                    Text("No tasks yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(competition.todos) { todo in
                        TodoItemRow(todo: todo, onToggle: {
                            competition.toggleTodo(todo.id)
                        }, onDelete: {
                            competition.removeTodo(todo.id)
                        })
                    }
                }

                // Common task suggestions
                if competition.todos.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Suggestions:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            SuggestionChip(text: "Collect rosette", action: { addSuggestion("Collect rosette") })
                            SuggestionChip(text: "Request certificate", action: { addSuggestion("Request qualification certificate") })
                        }
                        HStack(spacing: 8) {
                            SuggestionChip(text: "Pay entry fee", action: { addSuggestion("Pay entry fee") })
                            SuggestionChip(text: "Book travel", action: { addSuggestion("Book travel/accommodation") })
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func addTodo() {
        guard !newTodoText.isEmpty else { return }
        competition.addTodo(newTodoText)
        newTodoText = ""
    }

    private func addSuggestion(_ text: String) {
        competition.addTodo(text)
    }
}

struct TodoItemRow: View {
    let todo: CompetitionTodo
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
            }

            Text(todo.title)
                .strikethrough(todo.isCompleted)
                .foregroundStyle(todo.isCompleted ? .secondary : .primary)

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SuggestionChip: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppColors.primary.opacity(0.1))
                .foregroundStyle(AppColors.primary)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Competition Filter Chip

struct CompetitionFilterChip: View {
    let label: String
    let icon: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppColors.primary.opacity(0.15))
        .foregroundStyle(AppColors.primary)
        .clipShape(Capsule())
    }
}

// MARK: - Competition Filter Sheet

struct CompetitionFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    let horses: [Horse]
    let venues: [String]
    @Binding var selectedHorse: Horse?
    @Binding var selectedVenue: String?
    @Binding var selectedType: CompetitionType?
    @Binding var selectedLevel: CompetitionLevel?

    var body: some View {
        NavigationStack {
            Form {
                // Horse filter
                Section("Horse") {
                    Picker("Horse", selection: $selectedHorse) {
                        Text("All Horses").tag(nil as Horse?)
                        ForEach(horses) { horse in
                            HStack {
                                HorseAvatarView(horse: horse, size: 24)
                                Text(horse.name)
                            }
                            .tag(horse as Horse?)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                // Venue filter
                if !venues.isEmpty {
                    Section("Venue") {
                        Picker("Venue", selection: $selectedVenue) {
                            Text("All Venues").tag(nil as String?)
                            ForEach(venues, id: \.self) { venue in
                                Text(venue).tag(venue as String?)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }

                // Competition type filter
                Section("Competition Type") {
                    Picker("Type", selection: $selectedType) {
                        Text("All Types").tag(nil as CompetitionType?)
                        ForEach(CompetitionType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.rawValue)
                            }
                            .tag(type as CompetitionType?)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                // Level filter
                Section("Level") {
                    Picker("Level", selection: $selectedLevel) {
                        Text("All Levels").tag(nil as CompetitionLevel?)
                        ForEach(CompetitionLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level as CompetitionLevel?)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                // Clear all filters
                Section {
                    Button("Clear All Filters", role: .destructive) {
                        selectedHorse = nil
                        selectedVenue = nil
                        selectedType = nil
                        selectedLevel = nil
                    }
                }
            }
            .navigationTitle("Filter Competitions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
