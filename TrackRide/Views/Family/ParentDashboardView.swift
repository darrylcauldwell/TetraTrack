//
//  ParentDashboardView.swift
//  TrackRide
//
//  Parent's view of child's training data - shows summaries, trends, and live tracking.
//  iPad-adaptive layout using NavigationSplitView for review mode.
//

import SwiftUI
import SwiftData
import MapKit

struct ParentDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var familySharing = FamilySharingManager.shared
    @State private var statisticsService = ArtifactStatisticsService()

    @State private var artifacts: [TrainingArtifact] = []
    @State private var competitions: [SharedCompetition] = []
    @State private var isLoading = true
    @State private var selectedTab: DashboardTab = .activity
    @State private var selectedArtifact: TrainingArtifact?
    @State private var viewContext: ViewContext

    enum DashboardTab: String, CaseIterable, Identifiable {
        case activity = "Activity"
        case competitions = "Competitions"
        case trends = "Trends"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .activity: return "figure.run"
            case .competitions: return "calendar"
            case .trends: return "chart.line.uptrend.xyaxis"
            }
        }
    }

    init() {
        let familySharing = FamilySharingManager.shared
        _viewContext = State(initialValue: familySharing.createViewContext())
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .environment(\.viewContext, viewContext)
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }

    // MARK: - iPad Layout (NavigationSplitView)

    private var iPadLayout: some View {
        NavigationSplitView {
            // Sidebar with tabs and live session
            List {
                // Live session section
                if let activeSession = familySharing.sharedWithMe.first(where: { $0.isActive }) {
                    Section {
                        Button {
                            // Navigate to live tracking
                        } label: {
                            LiveSessionSidebarItem(session: activeSession)
                        }
                        .buttonStyle(.plain)
                    } header: {
                        HStack {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Text("Live Now")
                        }
                    }
                }

                // Navigation tabs
                Section("Dashboard") {
                    ForEach(DashboardTab.allCases) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            Label(tab.rawValue, systemImage: tab.icon)
                                .foregroundStyle(selectedTab == tab ? .blue : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Recent activity quick access
                if !artifacts.isEmpty {
                    Section("Recent Sessions") {
                        ForEach(artifacts.prefix(5)) { artifact in
                            Button {
                                selectedArtifact = artifact
                            } label: {
                                ArtifactSidebarItem(artifact: artifact)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle(viewContext.athleteName ?? "Family Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SyncStatusView()
                }
            }
        } content: {
            // Main content based on selected tab
            Group {
                switch selectedTab {
                case .activity:
                    activityContentView
                case .competitions:
                    competitionsContentView
                case .trends:
                    trendsContentView
                }
            }
            .navigationTitle(selectedTab.rawValue)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: refresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        } detail: {
            // Detail view for selected artifact
            if let artifact = selectedArtifact {
                ArtifactDetailView(artifact: artifact)
            } else {
                ContentUnavailableView(
                    "Select a Session",
                    systemImage: "figure.run",
                    description: Text("Choose a training session from the list to view details")
                )
            }
        }
    }

    // MARK: - iPhone Layout (NavigationStack)

    private var iPhoneLayout: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Athlete header for parent view
                AthleteHeaderView()

                // Active session card (if any child is currently training)
                if let activeSession = familySharing.sharedWithMe.first(where: { $0.isActive }) {
                    LiveTrackingCard(session: activeSession)
                        .padding()
                }

                // Tab picker
                Picker("View", selection: $selectedTab) {
                    ForEach(DashboardTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Content
                if isLoading {
                    ProgressView("Loading...")
                        .frame(maxHeight: .infinity)
                } else {
                    TabView(selection: $selectedTab) {
                        activityTab
                            .tag(DashboardTab.activity)

                        competitionsTab
                            .tag(DashboardTab.competitions)

                        trendsTab
                            .tag(DashboardTab.trends)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle("Family Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: refresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    // MARK: - iPad Content Views

    private var activityContentView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Statistics overview cards
                StatisticsOverviewGrid(statistics: statisticsService.statistics)
                    .padding(.horizontal)

                // This week summary
                WeekSummaryCard(artifacts: thisWeekArtifacts)
                    .padding(.horizontal)

                // Recent activity
                if !artifacts.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 12) {
                        ForEach(artifacts) { artifact in
                            Button {
                                selectedArtifact = artifact
                            } label: {
                                ArtifactSummaryRow(artifact: artifact, showFullMetrics: false)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                } else {
                    ContentUnavailableView(
                        "No Activity Yet",
                        systemImage: "figure.run",
                        description: Text("Training sessions will appear here when completed")
                    )
                }
            }
            .padding(.vertical)
        }
    }

    private var competitionsContentView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                let upcoming = competitions.filter { $0.isUpcoming }.sorted { $0.date < $1.date }
                let past = competitions.filter { $0.isPast }.sorted { $0.date > $1.date }

                if !upcoming.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Upcoming")
                            .font(.headline)
                            .padding(.horizontal)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 12) {
                            ForEach(upcoming) { competition in
                                CompetitionCard(competition: competition)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                if !past.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Past")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 12) {
                            ForEach(past.prefix(10)) { competition in
                                CompetitionCard(competition: competition)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                if competitions.isEmpty {
                    ContentUnavailableView(
                        "No Competitions",
                        systemImage: "calendar",
                        description: Text("Competitions will appear here when added")
                    )
                }
            }
            .padding(.vertical)
        }
    }

    private var trendsContentView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 350))], spacing: 20) {
                // Discipline breakdown
                FamilyDisciplineBreakdownChart(artifacts: artifacts)

                // Weekly activity
                FamilyWeeklyActivityChart(artifacts: artifacts)

                // Personal bests
                PersonalBestsCard(artifacts: artifacts)

                // Discipline-specific stats
                DisciplineStatisticsGrid(service: statisticsService)
            }
            .padding()
        }
    }

    // MARK: - Activity Tab

    private var activityTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // This week summary
                WeekSummaryCard(artifacts: thisWeekArtifacts)
                    .padding(.horizontal)

                // Recent activity
                if !artifacts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Activity")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(artifacts.prefix(10)) { artifact in
                            ArtifactSummaryRow(artifact: artifact, showFullMetrics: false)
                                .padding(.horizontal)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Activity Yet",
                        systemImage: "figure.run",
                        description: Text("Training sessions will appear here when completed")
                    )
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Competitions Tab

    private var competitionsTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Upcoming competitions
                let upcoming = competitions.filter { $0.isUpcoming }.sorted { $0.date < $1.date }

                if !upcoming.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Upcoming")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(upcoming) { competition in
                            CompetitionCard(competition: competition)
                                .padding(.horizontal)
                        }
                    }
                }

                // Past competitions
                let past = competitions.filter { $0.isPast }.sorted { $0.date > $1.date }

                if !past.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Past")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        ForEach(past.prefix(5)) { competition in
                            CompetitionCard(competition: competition)
                                .padding(.horizontal)
                        }
                    }
                }

                if competitions.isEmpty {
                    ContentUnavailableView(
                        "No Competitions",
                        systemImage: "calendar",
                        description: Text("Competitions will appear here when added")
                    )
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Trends Tab

    private var trendsTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Sessions by discipline chart
                FamilyDisciplineBreakdownChart(artifacts: artifacts)
                    .padding(.horizontal)

                // Weekly activity chart
                FamilyWeeklyActivityChart(artifacts: artifacts)
                    .padding(.horizontal)

                // Personal bests
                PersonalBestsCard(artifacts: artifacts)
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Helpers

    private var thisWeekArtifacts: [TrainingArtifact] {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return artifacts.filter { $0.startTime >= weekAgo }
    }

    private func loadData() async {
        isLoading = true
        viewContext.beginSync()

        // Fetch from CloudKit
        artifacts = await familySharing.fetchFamilyArtifacts()
        competitions = await familySharing.fetchFamilyCompetitions()

        // Update statistics service
        statisticsService.updateStatistics(from: artifacts)

        isLoading = false
        viewContext.completeSync()
    }

    private func refresh() {
        Task {
            await loadData()
        }
    }
}

// MARK: - iPad Sidebar Components

/// Sidebar item for live tracking session
struct LiveSessionSidebarItem: View {
    let session: LiveTrackingSession

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.green.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: "figure.equestrian.sports")
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(session.riderName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text(session.formattedDistance)
                    Text(session.formattedDuration)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

/// Sidebar item for artifact quick access
struct ArtifactSidebarItem: View {
    let artifact: TrainingArtifact

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: artifact.discipline.icon)
                .foregroundStyle(disciplineColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(artifact.name.isEmpty ? artifact.discipline.rawValue : artifact.name)
                    .font(.subheadline)
                    .lineLimit(1)

                Text(artifact.startTime.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var disciplineColor: Color {
        switch artifact.discipline {
        case .riding: return .brown
        case .running: return .green
        case .swimming: return .blue
        case .shooting: return .orange
        }
    }
}

// MARK: - Statistics Overview Grid

struct StatisticsOverviewGrid: View {
    let statistics: ArtifactStatistics

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
            StatisticsCard(
                title: "Total Sessions",
                value: "\(statistics.totalSessions)",
                icon: "flame.fill",
                color: .orange
            )

            StatisticsCard(
                title: "This Week",
                value: "\(statistics.sessionsThisWeek)",
                icon: "calendar",
                color: .blue
            )

            StatisticsCard(
                title: "Active Time",
                value: statistics.formattedTotalDuration,
                icon: "clock.fill",
                color: .purple
            )

            StatisticsCard(
                title: "Streak",
                value: "\(statistics.currentStreak) days",
                icon: "flame",
                color: .red
            )
        }
    }
}

struct StatisticsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Discipline Statistics Grid

struct DisciplineStatisticsGrid: View {
    let service: ArtifactStatisticsService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Discipline")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 12) {
                // Riding
                let ridingStats = service.ridingStatistics()
                if ridingStats.sessionCount > 0 {
                    DisciplineStatCard(
                        discipline: .riding,
                        sessions: ridingStats.sessionCount,
                        detail: "\(ridingStats.uniqueHorses) horses"
                    )
                }

                // Running
                let runningStats = service.runningStatistics()
                if runningStats.sessionCount > 0 {
                    DisciplineStatCard(
                        discipline: .running,
                        sessions: runningStats.sessionCount,
                        detail: runningStats.formattedTotalDistance
                    )
                }

                // Swimming
                let swimmingStats = service.swimmingStatistics()
                if swimmingStats.sessionCount > 0 {
                    DisciplineStatCard(
                        discipline: .swimming,
                        sessions: swimmingStats.sessionCount,
                        detail: "\(swimmingStats.totalLaps) laps"
                    )
                }

                // Shooting
                let shootingStats = service.shootingStatistics()
                if shootingStats.sessionCount > 0 {
                    DisciplineStatCard(
                        discipline: .shooting,
                        sessions: shootingStats.sessionCount,
                        detail: shootingStats.formattedAccuracy
                    )
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DisciplineStatCard: View {
    let discipline: TrainingDiscipline
    let sessions: Int
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: discipline.icon)
                .font(.title2)
                .foregroundStyle(disciplineColor)
                .frame(width: 44, height: 44)
                .background(disciplineColor.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(discipline.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text("\(sessions) sessions")
                    Text("•")
                    Text(detail)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var disciplineColor: Color {
        switch discipline {
        case .riding: return .brown
        case .running: return .green
        case .swimming: return .blue
        case .shooting: return .orange
        }
    }
}

// MARK: - Artifact Detail View

struct ArtifactDetailView: View {
    let artifact: TrainingArtifact
    @Environment(\.viewContext) private var viewContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: artifact.discipline.icon)
                        .font(.largeTitle)
                        .foregroundStyle(disciplineColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(artifact.name.isEmpty ? artifact.discipline.rawValue : artifact.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(artifact.formattedDate)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if artifact.personalBest {
                        Label("Personal Best", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.yellow.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Core metrics
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
                    MetricCard(title: "Duration", value: artifact.formattedDuration, icon: "clock")

                    if let distance = artifact.distance {
                        MetricCard(title: "Distance", value: distance.formattedDistance, icon: "arrow.left.and.right")
                    }

                    if let heartRate = artifact.averageHeartRate {
                        MetricCard(title: "Avg Heart Rate", value: "\(heartRate) bpm", icon: "heart.fill")
                    }

                    if let calories = artifact.caloriesBurned {
                        MetricCard(title: "Calories", value: "\(calories)", icon: "flame.fill")
                    }
                }

                // Discipline-specific details
                disciplineSpecificView

                // Notes
                if let notes = artifact.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)

                        Text(notes)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var disciplineSpecificView: some View {
        switch artifact.discipline {
        case .riding:
            if let data = artifact.getRidingData() {
                RidingDetailCard(data: data)
            }
        case .running:
            if let data = artifact.getRunningData() {
                RunningDetailCard(data: data)
            }
        case .swimming:
            if let data = artifact.getSwimmingData() {
                SwimmingDetailCard(data: data)
            }
        case .shooting:
            if let data = artifact.getShootingData() {
                ShootingDetailCard(data: data)
            }
        }
    }

    private var disciplineColor: Color {
        switch artifact.discipline {
        case .riding: return .brown
        case .running: return .green
        case .swimming: return .blue
        case .shooting: return .orange
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Discipline Detail Cards

struct RidingDetailCard: View {
    let data: RidingArtifactData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Riding Details")
                .font(.headline)

            if let horse = data.horseName {
                HStack {
                    Image(systemName: "pawprint.fill")
                    Text(horse)
                }
                .font(.subheadline)
            }

            HStack(spacing: 16) {
                GaitDurationPill(gait: "Walk", duration: data.gaitDurations["walk"] ?? 0)
                GaitDurationPill(gait: "Trot", duration: data.gaitDurations["trot"] ?? 0)
                GaitDurationPill(gait: "Canter", duration: data.gaitDurations["canter"] ?? 0)
            }

            HStack(spacing: 16) {
                Text("Avg Speed: \(String(format: "%.1f", data.averageSpeed * 3.6)) km/h")
                Text("Max: \(String(format: "%.1f", data.maxSpeed * 3.6)) km/h")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct GaitDurationPill: View {
    let gait: String
    let duration: TimeInterval

    var body: some View {
        VStack(spacing: 4) {
            Text(gait)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(duration.formattedDuration)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
        .clipShape(Capsule())
    }
}

struct RunningDetailCard: View {
    let data: RunningArtifactData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Running Details")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                DetailStatItem(title: "Pace", value: data.averagePace.formattedPace)
                DetailStatItem(title: "Cadence", value: "\(data.averageCadence) spm")
                DetailStatItem(title: "Elevation", value: String(format: "%.0fm", data.elevationGain))
                DetailStatItem(title: "Mode", value: data.runMode.capitalized)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SwimmingDetailCard: View {
    let data: SwimmingArtifactData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Swimming Details")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                DetailStatItem(title: "Laps", value: "\(data.lapCount)")
                DetailStatItem(title: "SWOLF", value: String(format: "%.0f", data.averageSwolf))
                DetailStatItem(title: "Strokes", value: "\(data.totalStrokes)")
                DetailStatItem(title: "Stroke", value: data.dominantStroke.capitalized)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ShootingDetailCard: View {
    let data: ShootingArtifactData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shooting Details")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                DetailStatItem(title: "Score", value: "\(data.totalScore)/\(data.maxPossibleScore)")
                DetailStatItem(title: "Shots", value: "\(data.shotCount)")
                DetailStatItem(title: "Average", value: String(format: "%.1f", data.averageScore))
                DetailStatItem(title: "Type", value: data.shootingSessionType.capitalized)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct DetailStatItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Live Tracking Card

struct LiveTrackingCard: View {
    let session: LiveTrackingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(.green)
                    .frame(width: 10, height: 10)
                Text("Live")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)

                Spacer()

                Text(session.riderName)
                    .font(.headline)
            }

            // Mini map
            Map {
                Marker(session.riderName, coordinate: session.currentCoordinate)
                    .tint(.green)
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                StatPill(icon: "figure.equestrian.sports", value: session.formattedDistance)
                StatPill(icon: "clock", value: session.formattedDuration)
                StatPill(icon: "speedometer", value: session.formattedSpeed)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Week Summary Card

struct WeekSummaryCard: View {
    let artifacts: [TrainingArtifact]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline)

            HStack(spacing: 16) {
                SummaryStatView(
                    value: "\(artifacts.count)",
                    label: "Sessions",
                    icon: "flame.fill",
                    color: .orange
                )

                SummaryStatView(
                    value: formattedTotalDuration,
                    label: "Active Time",
                    icon: "clock.fill",
                    color: .blue
                )

                SummaryStatView(
                    value: disciplineCount,
                    label: "Disciplines",
                    icon: "star.fill",
                    color: .purple
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var formattedTotalDuration: String {
        let total = artifacts.reduce(0) { $0 + $1.duration }
        return total.formattedDuration
    }

    private var disciplineCount: String {
        let disciplines = Set(artifacts.map { $0.discipline })
        return "\(disciplines.count)"
    }
}

// MARK: - Summary Stat View

struct SummaryStatView: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Artifact Summary Row

struct ArtifactSummaryRow: View {
    let artifact: TrainingArtifact
    let showFullMetrics: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Discipline icon
            Image(systemName: artifact.discipline.icon)
                .font(.title2)
                .foregroundStyle(disciplineColor)
                .frame(width: 44, height: 44)
                .background(disciplineColor.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(artifact.name.isEmpty ? artifact.discipline.rawValue : artifact.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(artifact.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(artifact.formattedDuration)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if showFullMetrics, let distance = artifact.distance {
                    Text(distance.formattedDistance)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var disciplineColor: Color {
        switch artifact.discipline {
        case .riding: return .brown
        case .running: return .green
        case .swimming: return .blue
        case .shooting: return .orange
        }
    }
}

// MARK: - Competition Card

struct CompetitionCard: View {
    let competition: SharedCompetition

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(competition.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(competition.venue)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(competition.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if competition.isUpcoming {
                Text(competition.formattedDaysUntil)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue)
                    .clipShape(Capsule())
            } else if competition.isCompleted, let results = competition.results {
                if let points = results.totalPoints {
                    Text("\(points) pts")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

// MARK: - Family Discipline Breakdown Chart

struct FamilyDisciplineBreakdownChart: View {
    let artifacts: [TrainingArtifact]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Discipline")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(TrainingDiscipline.allCases, id: \.self) { discipline in
                    let count = artifacts.filter { $0.discipline == discipline }.count
                    if count > 0 {
                        VStack(spacing: 4) {
                            Image(systemName: discipline.icon)
                                .font(.title3)
                            Text("\(count)")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text(discipline.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(disciplineColor(discipline).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func disciplineColor(_ discipline: TrainingDiscipline) -> Color {
        switch discipline {
        case .riding: return .brown
        case .running: return .green
        case .swimming: return .blue
        case .shooting: return .orange
        }
    }
}

// MARK: - Family Weekly Activity Chart

struct FamilyWeeklyActivityChart: View {
    let artifacts: [TrainingArtifact]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Activity")
                .font(.headline)

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<7, id: \.self) { dayOffset in
                    let day = Calendar.current.date(byAdding: .day, value: -6 + dayOffset, to: Date()) ?? Date()
                    let count = artifactsForDay(day).count

                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(count > 0 ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: max(CGFloat(count) * 20, 8))

                        Text(dayLabel(day))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func artifactsForDay(_ date: Date) -> [TrainingArtifact] {
        let calendar = Calendar.current
        return artifacts.filter { calendar.isDate($0.startTime, inSameDayAs: date) }
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

// MARK: - Personal Bests Card

struct PersonalBestsCard: View {
    let artifacts: [TrainingArtifact]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Personal Bests")
                .font(.headline)

            let pbs = artifacts.filter { $0.personalBest }

            if pbs.isEmpty {
                Text("No personal bests yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(pbs.prefix(3)) { artifact in
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)

                        Text(artifact.discipline.rawValue)
                            .font(.subheadline)

                        Spacer()

                        Text(artifact.formattedDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ParentDashboardView()
}
