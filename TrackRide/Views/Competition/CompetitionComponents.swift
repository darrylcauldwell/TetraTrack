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
import Photos
import MapKit

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

    // Auto-discovered photos and videos from competition days
    @State private var discoveredPhotos: [PHAsset] = []
    @State private var discoveredVideos: [PHAsset] = []
    @State private var hasLoadedMedia = false
    @State private var selectedVideo: PHAsset?

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

                    // Showjumping Classes & Results (only for showjumping competitions)
                    if competition.competitionType == .showJumping {
                        ShowjumpingResultsView(competition: competition)
                            .padding(.horizontal)
                    }

                    // Dressage Classes & Results (only for dressage competitions)
                    if competition.competitionType == .dressage {
                        DressageResultsView(competition: competition)
                            .padding(.horizontal)
                    }

                    // Triathlon/Tetrathlon Results
                    if competition.competitionType == .triathlon || competition.competitionType == .tetrathlon {
                        TriathlonResultsView(competition: competition)
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

                    // Media Gallery Section (auto-discovered + manually added)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Photos & Videos")
                                .font(.headline)
                            Spacer()
                            let totalCount = discoveredPhotos.count + discoveredVideos.count + competition.photos.count + competition.videoAssetIdentifiers.count
                            if totalCount > 0 {
                                NavigationLink(destination: CompetitionMediaFullGalleryView(
                                    competition: competition,
                                    discoveredPhotos: discoveredPhotos,
                                    discoveredVideos: discoveredVideos
                                )) {
                                    Text("View All (\(totalCount))")
                                        .font(.subheadline)
                                        .foregroundStyle(AppColors.primary)
                                }
                            }
                        }

                        if discoveredPhotos.isEmpty && discoveredVideos.isEmpty && competition.photos.isEmpty && competition.videoAssetIdentifiers.isEmpty {
                            // Empty state
                            HStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.title2)
                                    .foregroundStyle(.tertiary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("No photos or videos")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    if competition.endDate != nil {
                                        Text("Media taken during the competition days will appear here")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    } else {
                                        Text("Media taken on the competition day will appear here")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            // Media thumbnail preview
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    // Auto-discovered photos
                                    ForEach(discoveredPhotos.prefix(3), id: \.localIdentifier) { asset in
                                        PhotoThumbnail(asset: asset)
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    // Auto-discovered videos
                                    ForEach(discoveredVideos.prefix(2), id: \.localIdentifier) { asset in
                                        VideoThumbnail(asset: asset)
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .onTapGesture {
                                                selectedVideo = asset
                                            }
                                    }
                                    // Manually added photos (stored as Data)
                                    ForEach(Array(competition.photos.prefix(2).enumerated()), id: \.offset) { index, photoData in
                                        if let uiImage = UIImage(data: photoData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 80, height: 80)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                    }
                                    // Show more indicator
                                    let totalCount = discoveredPhotos.count + discoveredVideos.count + competition.photos.count + competition.videoAssetIdentifiers.count
                                    if totalCount > 7 {
                                        NavigationLink(destination: CompetitionMediaFullGalleryView(
                                            competition: competition,
                                            discoveredPhotos: discoveredPhotos,
                                            discoveredVideos: discoveredVideos
                                        )) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(AppColors.cardBackground)
                                                    .frame(width: 80, height: 80)
                                                VStack {
                                                    Text("+\(totalCount - 7)")
                                                        .font(.title3)
                                                        .fontWeight(.semibold)
                                                    Text("more")
                                                        .font(.caption2)
                                                }
                                                .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Manual add button
                        Button {
                            showingMediaEditor = true
                        } label: {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                                Text("Add More Photos & Videos")
                            }
                            .font(.subheadline)
                        }
                        .buttonStyle(.bordered)
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
            .sheet(item: $selectedVideo) { video in
                VideoPlayerView(asset: video)
            }
            .task {
                await loadMedia()
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

    private func loadMedia() async {
        guard !hasLoadedMedia else { return }
        hasLoadedMedia = true

        let photoService = RidePhotoService.shared
        if !photoService.isAuthorized {
            _ = await photoService.requestAuthorization()
        }

        // Fetch photos/videos from competition day(s) - handles multi-day automatically
        let (photos, videos) = await photoService.findMediaForCompetition(competition)

        await MainActor.run {
            discoveredPhotos = photos
            discoveredVideos = videos
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
    @State private var venueLatitude: Double?
    @State private var venueLongitude: Double?
    @State private var showingAddressSearch = false
    @State private var competitionType: CompetitionType = .tetrathlon
    @State private var level: CompetitionLevel = .junior
    // Triathlon discipline configuration
    @State private var triathlonDiscipline1: TriathlonDiscipline = .shooting
    @State private var triathlonDiscipline2: TriathlonDiscipline = .running
    @State private var triathlonDiscipline3: TriathlonDiscipline = .swimming
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
    @State private var travelHours: Int = 0
    @State private var travelMins: Int = 0
    @State private var appleMapsEstimateMinutes: Int?
    @State private var isCalculatingRoute = false
    @State private var travelRouteNotes = ""
    // Outbound yard stop
    @State private var arriveAtYard: Date?
    @State private var departureFromYard: Date?
    // Return yard stop
    @State private var departureFromVenue: Date?
    @State private var arrivalBackAtYard: Date?
    @State private var departFromYardReturn: Date?

    // Showjumping classes
    @State private var showjumpingClasses: [ShowjumpingClass] = []
    @State private var newClassName = ""
    @State private var showingAddClass = false

    // Dressage classes
    @State private var dressageClasses: [DressageClass] = []
    @State private var newDressageTest = ""

    // Tetrathlon start times and allocations
    @State private var shootingStartTime: Date?
    @State private var shootingDetail: String = ""
    @State private var shootingLane: Int?
    @State private var runningStartTime: Date?
    @State private var swimWarmupTime: Date?
    @State private var swimStartTime: Date?
    @State private var prizeGivingTime: Date?

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

                    // Triathlon discipline selection (only for triathlon)
                    if competitionType == .triathlon {
                        Picker("Discipline 1", selection: $triathlonDiscipline1) {
                            ForEach(TriathlonDiscipline.allCases, id: \.self) { discipline in
                                Label(discipline.rawValue, systemImage: discipline.icon).tag(discipline)
                            }
                        }

                        Picker("Discipline 2", selection: $triathlonDiscipline2) {
                            ForEach(TriathlonDiscipline.allCases, id: \.self) { discipline in
                                Label(discipline.rawValue, systemImage: discipline.icon).tag(discipline)
                            }
                        }

                        Picker("Discipline 3", selection: $triathlonDiscipline3) {
                            ForEach(TriathlonDiscipline.allCases, id: \.self) { discipline in
                                Label(discipline.rawValue, systemImage: discipline.icon).tag(discipline)
                            }
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

                    Button {
                        showingAddressSearch = true
                    } label: {
                        HStack {
                            Text("Venue")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(venue.isEmpty ? "Search..." : venue)
                                .foregroundStyle(venue.isEmpty ? .secondary : .primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showingAddressSearch) {
                        AddressSearchView { result in
                            venue = result.address
                            venueLatitude = result.latitude
                            venueLongitude = result.longitude
                        }
                    }

                    // Map preview when venue has coordinates
                    if let lat = venueLatitude, let lon = venueLongitude {
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))) {
                            Marker(venue.isEmpty ? "Venue" : venue, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                                .tint(.red)
                        }
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }

                Section("Entry & Booking") {
                    Toggle("Entry Deadline", isOn: $hasEntryDeadline)
                    if hasEntryDeadline {
                        DatePicker("Entry Deadline", selection: $entryDeadline, displayedComponents: .date)
                    }

                    // Stable booking not applicable for tetrathlon/triathlon competitions
                    if competitionType != .tetrathlon && competitionType != .triathlon {
                        Toggle("Stable Booking Deadline", isOn: $hasStableDeadline)
                        if hasStableDeadline {
                            DatePicker("Stable Deadline", selection: $stableDeadline, displayedComponents: .date)
                        }
                    }

                    TextField("Entry Fee (optional)", value: $entryFee, format: .currency(code: "GBP"))
                        .keyboardType(.decimalPad)

                    TextField("Website URL (optional)", text: $websiteURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }

                // Showjumping Classes Section (only for Show Jumping competitions)
                if competitionType == .showJumping {
                    Section {
                        ForEach(showjumpingClasses) { classEntry in
                            ShowjumpingClassEditRow(
                                classEntry: classEntry,
                                onUpdate: { updated in
                                    if let index = showjumpingClasses.firstIndex(where: { $0.id == updated.id }) {
                                        showjumpingClasses[index] = updated
                                    }
                                },
                                onDelete: {
                                    showjumpingClasses.removeAll { $0.id == classEntry.id }
                                }
                            )
                        }

                        // Add new class
                        HStack {
                            TextField("Add class (e.g., 90cm)", text: $newClassName)
                            Button {
                                guard !newClassName.isEmpty else { return }
                                showjumpingClasses.append(ShowjumpingClass(name: newClassName))
                                newClassName = ""
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(AppColors.primary)
                            }
                            .disabled(newClassName.isEmpty)
                        }

                        // Quick add buttons
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(ShowjumpingHeight.allCases, id: \.self) { height in
                                    Button(height.displayName) {
                                        // Only add if not already present
                                        if !showjumpingClasses.contains(where: { $0.name == height.displayName }) {
                                            showjumpingClasses.append(ShowjumpingClass(name: height.displayName))
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .disabled(showjumpingClasses.contains { $0.name == height.displayName })
                                }
                            }
                        }
                    } header: {
                        Text("Classes to Enter")
                    } footer: {
                        Text("Add the showjumping classes you plan to enter. You can record results for each class after the competition.")
                    }
                }

                // Dressage Classes Section (only for Dressage competitions)
                if competitionType == .dressage {
                    Section {
                        ForEach(dressageClasses) { classEntry in
                            DressageClassEditRow(
                                classEntry: classEntry,
                                onUpdate: { updated in
                                    if let index = dressageClasses.firstIndex(where: { $0.id == updated.id }) {
                                        dressageClasses[index] = updated
                                    }
                                },
                                onDelete: {
                                    dressageClasses.removeAll { $0.id == classEntry.id }
                                }
                            )
                        }

                        // Add new class
                        HStack {
                            TextField("Add test (e.g., Prelim 12)", text: $newDressageTest)
                            Button {
                                guard !newDressageTest.isEmpty else { return }
                                dressageClasses.append(DressageClass(testName: newDressageTest))
                                newDressageTest = ""
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(AppColors.primary)
                            }
                            .disabled(newDressageTest.isEmpty)
                        }

                        // Quick add buttons
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(DressageTest.allCases, id: \.self) { test in
                                    Button(test.displayName) {
                                        if !dressageClasses.contains(where: { $0.testName == test.displayName }) {
                                            dressageClasses.append(DressageClass(testName: test.displayName))
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .disabled(dressageClasses.contains { $0.testName == test.displayName })
                                }
                            }
                        }
                    } header: {
                        Text("Tests to Enter")
                    } footer: {
                        Text("Add the dressage tests you plan to ride. You can record scores and percentages after the competition.")
                    }
                }

                // Tetrathlon Start Times (only for tetrathlon/triathlon competitions)
                if competitionType == .tetrathlon || competitionType == .triathlon {
                    Section("Discipline Times") {
                        DatePicker("Shooting Start", selection: Binding(
                            get: { shootingStartTime ?? date },
                            set: { shootingStartTime = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])

                        TextField("Shooting Detail", text: $shootingDetail)
                            .textInputAutocapitalization(.words)

                        TextField("Shooting Lane", value: $shootingLane, format: .number)
                            .keyboardType(.numberPad)

                        DatePicker("Running Start", selection: Binding(
                            get: { runningStartTime ?? date },
                            set: { runningStartTime = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])

                        DatePicker("Swim Warmup", selection: Binding(
                            get: { swimWarmupTime ?? date },
                            set: { swimWarmupTime = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])

                        DatePicker("Swim Start", selection: Binding(
                            get: { swimStartTime ?? date },
                            set: { swimStartTime = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])

                        DatePicker("Prize Giving", selection: Binding(
                            get: { prizeGivingTime ?? date },
                            set: { prizeGivingTime = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section("Travel Plan - Outbound") {
                    DatePicker("Leave Home", selection: Binding(
                        get: { startTime ?? date },
                        set: { startTime = $0 }
                    ), displayedComponents: [.date, .hourAndMinute])

                    // Yard stop for horse competitions (not triathlon)
                    if competitionType != .triathlon {
                        DatePicker("Arrive at Yard", selection: Binding(
                            get: { arriveAtYard ?? date },
                            set: { arriveAtYard = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])

                        DatePicker("Depart from Yard", selection: Binding(
                            get: { departureFromYard ?? date },
                            set: { departureFromYard = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                    }

                    // Travel time in hours and minutes
                    HStack {
                        Text("Journey Time")
                        Spacer()
                        Picker("Hours", selection: $travelHours) {
                            ForEach(0..<13) { hour in
                                Text("\(hour)h").tag(hour)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .onChange(of: travelHours) {
                            estimatedTravelMinutes = (travelHours * 60) + travelMins
                        }

                        Picker("Minutes", selection: $travelMins) {
                            ForEach(0..<60) { min in
                                Text("\(min)m").tag(min)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .onChange(of: travelMins) {
                            estimatedTravelMinutes = (travelHours * 60) + travelMins
                        }
                    }

                    // Apple Maps route estimate (only shown when venue has coordinates)
                    if venueLatitude != nil && venueLongitude != nil {
                        HStack {
                            Text("Maps Estimate")
                                .foregroundStyle(.secondary)
                            Spacer()
                            if isCalculatingRoute {
                                ProgressView()
                                    .controlSize(.small)
                            } else if let estimate = appleMapsEstimateMinutes {
                                Text(formatTravelTime(estimate))
                                    .foregroundStyle(.secondary)
                            } else {
                                Button("Calculate") {
                                    calculateRouteTime()
                                }
                                .font(.subheadline)
                            }
                        }
                    }

                    DatePicker("Arrive at Venue", selection: Binding(
                        get: { estimatedArrivalAtVenue ?? date },
                        set: { estimatedArrivalAtVenue = $0 }
                    ), displayedComponents: [.date, .hourAndMinute])

                    // Course walk not applicable for tetrathlon/triathlon/dressage
                    if competitionType != .tetrathlon && competitionType != .triathlon && competitionType != .dressage {
                        DatePicker("Course Walk Time", selection: Binding(
                            get: { courseWalkTime ?? date },
                            set: { courseWalkTime = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section("Travel Plan - Return") {
                    DatePicker("Depart from Venue", selection: Binding(
                        get: { departureFromVenue ?? date },
                        set: { departureFromVenue = $0 }
                    ), displayedComponents: [.date, .hourAndMinute])

                    // Yard stop for horse competitions (not triathlon)
                    if competitionType != .triathlon {
                        DatePicker("Arrive at Yard", selection: Binding(
                            get: { arrivalBackAtYard ?? date },
                            set: { arrivalBackAtYard = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])

                        DatePicker("Depart from Yard", selection: Binding(
                            get: { departFromYardReturn ?? date },
                            set: { departFromYardReturn = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                    }

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
                    venueLatitude = comp.venueLatitude
                    venueLongitude = comp.venueLongitude
                    competitionType = comp.competitionType
                    level = comp.level
                    // Triathlon disciplines
                    triathlonDiscipline1 = comp.triathlonDiscipline1
                    triathlonDiscipline2 = comp.triathlonDiscipline2
                    triathlonDiscipline3 = comp.triathlonDiscipline3
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
                    if let minutes = comp.estimatedTravelMinutes {
                        travelHours = minutes / 60
                        travelMins = minutes % 60
                    }
                    travelRouteNotes = comp.travelRouteNotes
                    // Outbound yard stop
                    arriveAtYard = comp.arriveAtYard
                    departureFromYard = comp.departureFromYard
                    // Return yard stop
                    departureFromVenue = comp.departureFromVenue
                    arrivalBackAtYard = comp.arrivalBackAtYard
                    departFromYardReturn = comp.departFromYardReturn

                    // Showjumping classes
                    showjumpingClasses = comp.showjumpingClasses

                    // Dressage classes
                    dressageClasses = comp.dressageClasses

                    // Tetrathlon start times and allocations
                    shootingStartTime = comp.shootingStartTime
                    shootingDetail = comp.shootingDetail ?? ""
                    shootingLane = comp.shootingLane
                    runningStartTime = comp.runningStartTime
                    swimWarmupTime = comp.swimWarmupTime
                    swimStartTime = comp.swimStartTime
                    prizeGivingTime = comp.prizeGivingTime
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
        comp.venueLatitude = venueLatitude
        comp.venueLongitude = venueLongitude
        comp.competitionType = competitionType
        comp.level = level
        // Triathlon disciplines
        comp.triathlonDiscipline1 = triathlonDiscipline1
        comp.triathlonDiscipline2 = triathlonDiscipline2
        comp.triathlonDiscipline3 = triathlonDiscipline3
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
        // Outbound yard stop
        comp.arriveAtYard = arriveAtYard
        comp.departureFromYard = departureFromYard
        // Return yard stop
        comp.departureFromVenue = departureFromVenue
        comp.arrivalBackAtYard = arrivalBackAtYard
        comp.departFromYardReturn = departFromYardReturn

        // Showjumping classes (only save if showjumping)
        if competitionType == .showJumping {
            comp.showjumpingClasses = showjumpingClasses
        }

        // Dressage classes (only save if dressage)
        if competitionType == .dressage {
            comp.dressageClasses = dressageClasses
        }

        // Tetrathlon start times and allocations (only save if tetrathlon/triathlon)
        if competitionType == .tetrathlon || competitionType == .triathlon {
            comp.shootingStartTime = shootingStartTime
            comp.shootingDetail = shootingDetail.isEmpty ? nil : shootingDetail
            comp.shootingLane = shootingLane
            comp.runningStartTime = runningStartTime
            comp.swimWarmupTime = swimWarmupTime
            comp.swimStartTime = swimStartTime
            comp.prizeGivingTime = prizeGivingTime
        }

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

    private func formatTravelTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }

    private func calculateRouteTime() {
        guard let destLat = venueLatitude,
              let destLon = venueLongitude else { return }

        isCalculatingRoute = true

        Task {
            let request = MKDirections.Request()

            // Use current location as origin
            request.source = MKMapItem.forCurrentLocation()

            // Destination is the venue
            let destCoord = CLLocationCoordinate2D(latitude: destLat, longitude: destLon)
            let destPlacemark = MKPlacemark(coordinate: destCoord)
            request.destination = MKMapItem(placemark: destPlacemark)

            request.transportType = .automobile

            // Set departure time if we have arrival time (to account for traffic)
            if let arrivalTime = estimatedArrivalAtVenue {
                request.arrivalDate = arrivalTime
            }

            let directions = MKDirections(request: request)

            do {
                let response = try await directions.calculate()
                if let route = response.routes.first {
                    await MainActor.run {
                        appleMapsEstimateMinutes = Int(route.expectedTravelTime / 60)
                        isCalculatingRoute = false
                    }
                }
            } catch {
                await MainActor.run {
                    isCalculatingRoute = false
                }
            }
        }
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

// MARK: - Competition Media Full Gallery

struct CompetitionMediaFullGalleryView: View {
    let competition: Competition
    let discoveredPhotos: [PHAsset]
    let discoveredVideos: [PHAsset]

    @State private var selectedPhoto: PHAsset?
    @State private var selectedVideo: PHAsset?

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Auto-discovered Photos
                if !discoveredPhotos.isEmpty {
                    Text("Photos from Competition (\(discoveredPhotos.count))")
                        .font(.headline)
                        .padding(.horizontal)

                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(discoveredPhotos, id: \.localIdentifier) { asset in
                            PhotoThumbnail(asset: asset)
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                                .onTapGesture {
                                    selectedPhoto = asset
                                }
                        }
                    }
                }

                // Auto-discovered Videos
                if !discoveredVideos.isEmpty {
                    Text("Videos from Competition (\(discoveredVideos.count))")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, discoveredPhotos.isEmpty ? 0 : 8)

                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(discoveredVideos, id: \.localIdentifier) { asset in
                            VideoThumbnail(asset: asset)
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                                .onTapGesture {
                                    selectedVideo = asset
                                }
                        }
                    }
                }

                // Manually added photos
                if !competition.photos.isEmpty {
                    Text("Added Photos (\(competition.photos.count))")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(Array(competition.photos.enumerated()), id: \.offset) { index, photoData in
                            if let uiImage = UIImage(data: photoData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipped()
                            }
                        }
                    }
                }

                // Multi-day info
                if let endDate = competition.endDate, endDate != competition.date {
                    Text("Showing media from \(formattedDateRange(competition.date, endDate))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
        }
        .navigationTitle("Competition Media")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedPhoto) { asset in
            PhotoDetailView(asset: asset)
        }
        .sheet(item: $selectedVideo) { asset in
            VideoPlayerView(asset: asset)
        }
    }

    private func formattedDateRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

// MARK: - Showjumping Class Edit Row

struct ShowjumpingClassEditRow: View {
    let classEntry: ShowjumpingClass
    let onUpdate: (ShowjumpingClass) -> Void
    let onDelete: () -> Void

    @State private var selectedStatus: ShowjumpingClass.EntryStatus

    init(classEntry: ShowjumpingClass, onUpdate: @escaping (ShowjumpingClass) -> Void, onDelete: @escaping () -> Void) {
        self.classEntry = classEntry
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self._selectedStatus = State(initialValue: classEntry.entryStatus)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(classEntry.name)
                    .fontWeight(.medium)

                if classEntry.hasResults {
                    Text(classEntry.resultSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Menu {
                ForEach(ShowjumpingClass.EntryStatus.allCases, id: \.self) { status in
                    Button {
                        var updated = classEntry
                        updated.entryStatus = status
                        onUpdate(updated)
                        selectedStatus = status
                    } label: {
                        Label(status.rawValue, systemImage: status.icon)
                    }
                }

                Divider()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: selectedStatus.icon)
                    Text(selectedStatus.rawValue)
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.15))
                .foregroundStyle(statusColor)
                .clipShape(Capsule())
            }
        }
    }

    private var statusColor: Color {
        switch selectedStatus {
        case .planning: return .orange
        case .entered: return .green
        case .scratched: return .red
        case .completed: return AppColors.primary
        }
    }
}

// MARK: - Showjumping Results View

struct ShowjumpingResultsView: View {
    @Bindable var competition: Competition
    @State private var editingClass: ShowjumpingClass?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "arrow.up.forward")
                    .foregroundStyle(AppColors.primary)
                Text("Showjumping Results")
                    .font(.headline)
            }

            if competition.showjumpingClasses.isEmpty {
                Text("No classes entered for this competition")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(competition.showjumpingClasses) { classEntry in
                    ShowjumpingClassResultRow(
                        classEntry: classEntry,
                        onTap: {
                            editingClass = classEntry
                        }
                    )
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(item: $editingClass) { classEntry in
            ShowjumpingClassResultEditor(
                classEntry: classEntry,
                onSave: { updated in
                    competition.updateShowjumpingClass(updated)
                    editingClass = nil
                }
            )
        }
    }
}

struct ShowjumpingClassResultRow: View {
    let classEntry: ShowjumpingClass
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(classEntry.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    if classEntry.hasResults {
                        HStack(spacing: 12) {
                            if let faults = classEntry.faults {
                                Label(faults == 0 ? "Clear" : "\(faults) faults", systemImage: faults == 0 ? "checkmark.circle.fill" : "xmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(faults == 0 ? .green : .orange)
                            }
                            if let time = classEntry.formattedTime {
                                Label(time, systemImage: "stopwatch")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let placing = classEntry.placing {
                                Label(ordinalString(placing), systemImage: "medal")
                                    .font(.caption)
                                    .foregroundStyle(placing <= 3 ? .yellow : .secondary)
                            }
                        }
                    } else {
                        Text("Tap to add result")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func ordinalString(_ n: Int) -> String {
        let suffix: String
        let ones = n % 10
        let tens = (n / 10) % 10

        if tens == 1 {
            suffix = "th"
        } else {
            switch ones {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }
}

struct ShowjumpingClassResultEditor: View {
    let classEntry: ShowjumpingClass
    let onSave: (ShowjumpingClass) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var faults: String = ""
    @State private var timeMinutes: String = ""
    @State private var timeSeconds: String = ""
    @State private var jumpOffFaults: String = ""
    @State private var jumpOffMinutes: String = ""
    @State private var jumpOffSeconds: String = ""
    @State private var placing: String = ""
    @State private var points: String = ""
    @State private var notes: String = ""
    @State private var hasJumpOff = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Round Result") {
                    HStack {
                        Text("Faults")
                        Spacer()
                        TextField("0", text: $faults)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }

                    HStack {
                        Text("Time")
                        Spacer()
                        TextField("0", text: $timeMinutes)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 40)
                        Text(":")
                        TextField("00.00", text: $timeSeconds)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }

                Section {
                    Toggle("Jump-off", isOn: $hasJumpOff)

                    if hasJumpOff {
                        HStack {
                            Text("J/O Faults")
                            Spacer()
                            TextField("0", text: $jumpOffFaults)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                        }

                        HStack {
                            Text("J/O Time")
                            Spacer()
                            TextField("0", text: $jumpOffMinutes)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 40)
                            Text(":")
                            TextField("00.00", text: $jumpOffSeconds)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                        }
                    }
                } header: {
                    Text("Jump-off")
                }

                Section("Placing") {
                    HStack {
                        Text("Placing")
                        Spacer()
                        TextField("e.g., 1", text: $placing)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }

                    HStack {
                        Text("Points")
                        Spacer()
                        TextField("Optional", text: $points)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                Section("Notes") {
                    TextField("Notes about this round", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(classEntry.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear {
                loadData()
            }
        }
    }

    private func loadData() {
        if let f = classEntry.faults {
            faults = "\(f)"
        }
        if let time = classEntry.time {
            let minutes = Int(time) / 60
            let seconds = time.truncatingRemainder(dividingBy: 60)
            timeMinutes = minutes > 0 ? "\(minutes)" : ""
            timeSeconds = String(format: "%.2f", seconds)
        }
        if let jof = classEntry.jumpOffFaults {
            jumpOffFaults = "\(jof)"
            hasJumpOff = true
        }
        if let jot = classEntry.jumpOffTime {
            let minutes = Int(jot) / 60
            let seconds = jot.truncatingRemainder(dividingBy: 60)
            jumpOffMinutes = minutes > 0 ? "\(minutes)" : ""
            jumpOffSeconds = String(format: "%.2f", seconds)
            hasJumpOff = true
        }
        if let p = classEntry.placing {
            placing = "\(p)"
        }
        if let pts = classEntry.points {
            points = String(format: "%.1f", pts)
        }
        notes = classEntry.notes
    }

    private func save() {
        var updated = classEntry
        updated.faults = Int(faults)
        updated.placing = Int(placing)
        updated.points = Double(points)
        updated.notes = notes
        updated.entryStatus = .completed

        // Parse time
        let mins = Double(timeMinutes) ?? 0
        let secs = Double(timeSeconds) ?? 0
        if mins > 0 || secs > 0 {
            updated.time = (mins * 60) + secs
        }

        // Parse jump-off
        if hasJumpOff {
            updated.jumpOffFaults = Int(jumpOffFaults)
            let joMins = Double(jumpOffMinutes) ?? 0
            let joSecs = Double(jumpOffSeconds) ?? 0
            if joMins > 0 || joSecs > 0 {
                updated.jumpOffTime = (joMins * 60) + joSecs
            }
        }

        onSave(updated)
    }
}

// MARK: - Dressage Class Edit Row

struct DressageClassEditRow: View {
    let classEntry: DressageClass
    let onUpdate: (DressageClass) -> Void
    let onDelete: () -> Void

    @State private var selectedStatus: DressageClass.EntryStatus

    init(classEntry: DressageClass, onUpdate: @escaping (DressageClass) -> Void, onDelete: @escaping () -> Void) {
        self.classEntry = classEntry
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self._selectedStatus = State(initialValue: classEntry.entryStatus)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(classEntry.testName)
                    .fontWeight(.medium)

                if !classEntry.className.isEmpty {
                    Text(classEntry.className)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if classEntry.hasResults {
                    Text(classEntry.resultSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Menu {
                ForEach(DressageClass.EntryStatus.allCases, id: \.self) { status in
                    Button {
                        var updated = classEntry
                        updated.entryStatus = status
                        onUpdate(updated)
                        selectedStatus = status
                    } label: {
                        Label(status.rawValue, systemImage: status.icon)
                    }
                }

                Divider()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: selectedStatus.icon)
                    Text(selectedStatus.rawValue)
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.15))
                .foregroundStyle(statusColor)
                .clipShape(Capsule())
            }
        }
    }

    private var statusColor: Color {
        switch selectedStatus {
        case .planning: return .orange
        case .entered: return .green
        case .scratched: return .red
        case .completed: return AppColors.primary
        }
    }
}

// MARK: - Dressage Results View

struct DressageResultsView: View {
    @Bindable var competition: Competition
    @State private var editingClass: DressageClass?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "circle.hexagonpath")
                    .foregroundStyle(AppColors.primary)
                Text("Dressage Results")
                    .font(.headline)
            }

            if competition.dressageClasses.isEmpty {
                Text("No tests entered for this competition")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(competition.dressageClasses) { classEntry in
                    DressageClassResultRow(
                        classEntry: classEntry,
                        onTap: {
                            editingClass = classEntry
                        }
                    )
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(item: $editingClass) { classEntry in
            DressageClassResultEditor(
                classEntry: classEntry,
                onSave: { updated in
                    competition.updateDressageClass(updated)
                    editingClass = nil
                }
            )
        }
    }
}

struct DressageClassResultRow: View {
    let classEntry: DressageClass
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(classEntry.testName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    if classEntry.hasResults {
                        HStack(spacing: 12) {
                            if let pct = classEntry.formattedPercentage {
                                Label(pct, systemImage: "percent")
                                    .font(.caption)
                                    .foregroundStyle(percentageColor)
                            }
                            if let placing = classEntry.placing {
                                Label(ordinalString(placing), systemImage: "medal")
                                    .font(.caption)
                                    .foregroundStyle(placing <= 3 ? .yellow : .secondary)
                            }
                        }
                    } else {
                        Text("Tap to add result")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var percentageColor: Color {
        guard let pct = classEntry.calculatedPercentage else { return .secondary }
        if pct >= 70 { return .green }
        if pct >= 65 { return .blue }
        if pct >= 60 { return .orange }
        return .secondary
    }

    private func ordinalString(_ n: Int) -> String {
        let suffix: String
        let ones = n % 10
        let tens = (n / 10) % 10

        if tens == 1 {
            suffix = "th"
        } else {
            switch ones {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }
}

struct DressageClassResultEditor: View {
    let classEntry: DressageClass
    let onSave: (DressageClass) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var score: String = ""
    @State private var maxScore: String = ""
    @State private var percentage: String = ""
    @State private var collectiveMarks: String = ""
    @State private var placing: String = ""
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Score") {
                    HStack {
                        Text("Score")
                        Spacer()
                        TextField("Marks", text: $score)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("/")
                        TextField("Max", text: $maxScore)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    HStack {
                        Text("Percentage")
                        Spacer()
                        TextField("e.g., 65.5", text: $percentage)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("%")
                    }

                    HStack {
                        Text("Collective Marks")
                        Spacer()
                        TextField("Optional", text: $collectiveMarks)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                Section("Placing") {
                    HStack {
                        Text("Placing")
                        Spacer()
                        TextField("e.g., 1", text: $placing)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }

                Section("Notes") {
                    TextField("Notes about this test", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(classEntry.testName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear {
                loadData()
            }
        }
    }

    private func loadData() {
        if let s = classEntry.score {
            score = String(format: "%.1f", s)
        }
        if let m = classEntry.maxScore {
            maxScore = String(format: "%.0f", m)
        }
        if let p = classEntry.percentage {
            percentage = String(format: "%.2f", p)
        }
        if let c = classEntry.collectiveMarks {
            collectiveMarks = String(format: "%.1f", c)
        }
        if let pl = classEntry.placing {
            placing = "\(pl)"
        }
        notes = classEntry.notes
    }

    private func save() {
        var updated = classEntry
        updated.score = Double(score)
        updated.maxScore = Double(maxScore)
        updated.percentage = Double(percentage)
        updated.collectiveMarks = Double(collectiveMarks)
        updated.placing = Int(placing)
        updated.notes = notes
        updated.entryStatus = .completed

        onSave(updated)
    }
}
