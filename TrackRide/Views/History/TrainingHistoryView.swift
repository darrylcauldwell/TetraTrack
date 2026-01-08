//
//  TrainingHistoryView.swift
//  TrackRide
//
//  Unified history view for all training disciplines with integrated insights
//

import SwiftUI
import SwiftData
import WidgetKit

struct TrainingHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Ride.startDate, order: .reverse) private var rides: [Ride]
    @Query(sort: \RunningSession.startDate, order: .reverse) private var runningSessions: [RunningSession]
    @Query(sort: \SwimmingSession.startDate, order: .reverse) private var swimmingSessions: [SwimmingSession]
    @Query(sort: \ShootingSession.startDate, order: .reverse) private var shootingSessions: [ShootingSession]

    @State private var selectedDiscipline: DisciplineFilter = .all
    @State private var selectedTab: HistoryTab = .sessions

    enum HistoryTab: String, CaseIterable {
        case sessions = "Sessions"
        case insights = "Insights"

        var icon: String {
            switch self {
            case .sessions: return "list.bullet"
            case .insights: return "apple.intelligence"
            }
        }
    }

    enum DisciplineFilter: String, CaseIterable {
        case all = "All"
        case riding = "Riding"
        case running = "Running"
        case swimming = "Swimming"
        case shooting = "Shooting"

        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .riding: return "figure.equestrian.sports"
            case .running: return "figure.run"
            case .swimming: return "figure.pool.swim"
            case .shooting: return "target"
            }
        }

        var color: Color {
            switch self {
            case .all: return .primary
            case .riding: return .green
            case .running: return .orange
            case .swimming: return .blue
            case .shooting: return .red
            }
        }
    }

    private var allSessions: [TrainingHistoryItem] {
        var items: [TrainingHistoryItem] = []

        if selectedDiscipline == .all || selectedDiscipline == .riding {
            items += rides.map { TrainingHistoryItem(ride: $0) }
        }
        if selectedDiscipline == .all || selectedDiscipline == .running {
            items += runningSessions.map { TrainingHistoryItem(runningSession: $0) }
        }
        if selectedDiscipline == .all || selectedDiscipline == .swimming {
            items += swimmingSessions.map { TrainingHistoryItem(swimmingSession: $0) }
        }
        if selectedDiscipline == .all || selectedDiscipline == .shooting {
            items += shootingSessions.map { TrainingHistoryItem(shootingSession: $0) }
        }

        return items.sorted { $0.date > $1.date }
    }

    // Stats for insights tab
    private var ridesThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return rides.filter { $0.startDate >= weekAgo }.count
    }

    private var runsThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return runningSessions.filter { $0.startDate >= weekAgo }.count
    }

    private var swimsThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return swimmingSessions.filter { $0.startDate >= weekAgo }.count
    }

    private var shootsThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return shootingSessions.filter { $0.startDate >= weekAgo }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker for Sessions vs Insights
            Picker("View", selection: $selectedTab) {
                ForEach(HistoryTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top)

            if selectedTab == .sessions {
                sessionsView
            } else {
                insightsView
            }
        }
        .navigationTitle("Training History")
        .toolbar {
            if selectedTab == .sessions && !allSessions.isEmpty {
                EditButton()
            }
        }
    }

    // MARK: - Sessions View

    private var sessionsView: some View {
        VStack(spacing: 0) {
            // Discipline filter dropdown
            HStack {
                Menu {
                    ForEach(DisciplineFilter.allCases, id: \.self) { filter in
                        Button {
                            selectedDiscipline = filter
                        } label: {
                            Label(filter.rawValue, systemImage: filter.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: selectedDiscipline.icon)
                            .foregroundStyle(selectedDiscipline.color)
                        Text(selectedDiscipline.rawValue)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding()

            if allSessions.isEmpty {
                ContentUnavailableView(
                    "No Training Sessions",
                    systemImage: "clock",
                    description: Text("Your completed sessions will appear here")
                )
            } else {
                List {
                    ForEach(allSessions) { item in
                        NavigationLink(destination: destinationView(for: item)) {
                            TrainingHistoryRow(item: item)
                        }
                    }
                    .onDelete(perform: deleteSessions)
                }
            }
        }
    }

    // MARK: - Insights View

    private var insightsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Apple Intelligence Training Insights
                AIInsightsView(rides: Array(rides.prefix(30)))
                    .padding(.horizontal)

                // Activity Summary
                activitySummaryCard
                    .padding(.horizontal)

                // Recent Activity
                if !allSessions.isEmpty {
                    recentActivityCard
                        .padding(.horizontal)
                }

                Spacer(minLength: 20)
            }
            .padding(.top)
        }
    }

    // MARK: - Activity Summary Card

    private var activitySummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.blue)
                Text("Activity Summary")
                    .font(.headline)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ActivityStatBox(
                    icon: "figure.equestrian.sports",
                    color: .green,
                    total: rides.count,
                    thisWeek: ridesThisWeek,
                    label: "Rides"
                )

                ActivityStatBox(
                    icon: "figure.run",
                    color: .orange,
                    total: runningSessions.count,
                    thisWeek: runsThisWeek,
                    label: "Runs"
                )

                ActivityStatBox(
                    icon: "figure.pool.swim",
                    color: .blue,
                    total: swimmingSessions.count,
                    thisWeek: swimsThisWeek,
                    label: "Swims"
                )

                ActivityStatBox(
                    icon: "target",
                    color: .red,
                    total: shootingSessions.count,
                    thisWeek: shootsThisWeek,
                    label: "Shoots"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Recent Activity Card

    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.orange)
                Text("Recent Activity")
                    .font(.headline)
            }

            VStack(spacing: 8) {
                ForEach(allSessions.prefix(5)) { item in
                    HStack {
                        Image(systemName: item.discipline.icon)
                            .font(.caption)
                            .foregroundStyle(item.discipline.color)
                            .frame(width: 20)

                        Text(item.name)
                            .font(.subheadline)

                        Spacer()

                        Text(item.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    @ViewBuilder
    private func destinationView(for item: TrainingHistoryItem) -> some View {
        switch item.discipline {
        case .riding:
            if let ride = item.ride {
                RideDetailView(ride: ride)
            }
        case .running:
            if let session = item.runningSession {
                RunningSessionDetailView(session: session)
            }
        case .swimming:
            if let session = item.swimmingSession {
                SwimmingSessionDetailView(session: session)
            }
        case .shooting:
            if let session = item.shootingSession {
                ShootingSessionDetailView(session: session)
            }
        case .all:
            EmptyView()
        }
    }

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            let item = allSessions[index]
            if let ride = item.ride {
                modelContext.delete(ride)
            } else if let session = item.runningSession {
                modelContext.delete(session)
            } else if let session = item.swimmingSession {
                modelContext.delete(session)
            } else if let session = item.shootingSession {
                modelContext.delete(session)
            }
        }
        // Sync sessions to widgets
        WidgetDataSyncService.shared.syncRecentSessions(context: modelContext)
    }
}

// MARK: - Training History Item

struct TrainingHistoryItem: Identifiable {
    let id: UUID
    let discipline: TrainingHistoryView.DisciplineFilter
    let date: Date
    let name: String
    let duration: TimeInterval
    let primaryMetric: String
    let secondaryMetric: String?

    // References to original objects
    var ride: Ride?
    var runningSession: RunningSession?
    var swimmingSession: SwimmingSession?
    var shootingSession: ShootingSession?

    init(ride: Ride) {
        self.id = ride.id
        self.discipline = .riding
        self.date = ride.startDate
        self.name = ride.name.isEmpty ? "Ride" : ride.name
        self.duration = ride.totalDuration
        self.primaryMetric = ride.formattedDistance
        self.secondaryMetric = ride.horse?.name
        self.ride = ride
    }

    init(runningSession: RunningSession) {
        self.id = runningSession.id
        self.discipline = .running
        self.date = runningSession.startDate
        self.name = runningSession.name.isEmpty ? "Run" : runningSession.name
        self.duration = runningSession.totalDuration
        self.primaryMetric = runningSession.formattedDistance
        self.secondaryMetric = runningSession.formattedPace
        self.runningSession = runningSession
    }

    init(swimmingSession: SwimmingSession) {
        self.id = swimmingSession.id
        self.discipline = .swimming
        self.date = swimmingSession.startDate
        self.name = swimmingSession.name.isEmpty ? "Swim" : swimmingSession.name
        self.duration = swimmingSession.totalDuration
        self.primaryMetric = swimmingSession.formattedDistance
        self.secondaryMetric = "\(swimmingSession.lapCount) laps"
        self.swimmingSession = swimmingSession
    }

    init(shootingSession: ShootingSession) {
        self.id = shootingSession.id
        self.discipline = .shooting
        self.date = shootingSession.startDate
        self.name = shootingSession.name.isEmpty ? "Shooting" : shootingSession.name
        self.duration = shootingSession.totalDuration
        self.primaryMetric = "\(shootingSession.totalScore) pts"
        self.secondaryMetric = "\(shootingSession.ends.count) ends"
        self.shootingSession = shootingSession
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var formattedDuration: String {
        duration.formattedDuration
    }
}

// MARK: - Training History Row

struct TrainingHistoryRow: View {
    let item: TrainingHistoryItem

    var body: some View {
        HStack(spacing: 12) {
            // Discipline icon
            Image(systemName: item.discipline.icon)
                .font(.title2)
                .foregroundStyle(item.discipline.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)

                HStack(spacing: 12) {
                    Label(item.primaryMetric, systemImage: "ruler")
                    Label(item.formattedDuration, systemImage: "clock")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if let secondary = item.secondaryMetric {
                    Text(secondary)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Text(item.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Activity Stat Box

struct ActivityStatBox: View {
    let icon: String
    let color: Color
    let total: Int
    let thisWeek: Int
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text("\(total)")
                .font(.title2.bold())

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            if thisWeek > 0 {
                Text("+\(thisWeek) this week")
                    .font(.caption2)
                    .foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        TrainingHistoryView()
    }
    .modelContainer(for: [Ride.self, RunningSession.self, SwimmingSession.self, ShootingSession.self], inMemory: true)
}
