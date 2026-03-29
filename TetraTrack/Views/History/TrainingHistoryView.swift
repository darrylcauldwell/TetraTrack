//
//  TrainingHistoryView.swift
//  TetraTrack
//
//  Unified Training History view with integrated cross-session insights
//  and shooting pattern history with thumbnails
//

import SwiftUI
import SwiftData
import HealthKit
import WidgetKit
import Charts

// MARK: - Session History View

struct SessionHistoryView: View {
    // Optional initial values for navigation from other views
    var initialDiscipline: DisciplineFilter?
    var initialTab: HistoryTab?
    var onDismiss: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \Ride.startDate, order: .reverse) private var rides: [Ride]
    @Query(sort: \RunningSession.startDate, order: .reverse) private var runningSessions: [RunningSession]
    @Query(sort: \SwimmingSession.startDate, order: .reverse) private var swimmingSessions: [SwimmingSession]
    @Query(sort: \ShootingSession.startDate, order: .reverse) private var shootingSessions: [ShootingSession]

    @State private var selectedDiscipline: DisciplineFilter = .all
    @State private var selectedTab: HistoryTab = .sessions
    @State private var selectedItem: SessionHistoryItem?
    @State private var hasAppliedInitialValues = false
    @State private var showExternalWorkouts = true

    // Shooting history state
    @State private var showingShootingHistory = false

    private var externalWorkoutService = ExternalWorkoutService.shared

    init(
        initialDiscipline: DisciplineFilter? = nil,
        initialTab: HistoryTab? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.initialDiscipline = initialDiscipline
        self.initialTab = initialTab
        self.onDismiss = onDismiss
    }

    enum HistoryTab: String, CaseIterable {
        case sessions = "Sessions"
        case insights = "Session Insights"

        var icon: String {
            switch self {
            case .sessions: return "list.bullet"
            case .insights: return "chart.line.uptrend.xyaxis"
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
            case .all: return .purple
            case .riding: return TrainingDiscipline.riding.color
            case .running: return TrainingDiscipline.running.color
            case .swimming: return TrainingDiscipline.swimming.color
            case .shooting: return TrainingDiscipline.shooting.color
            }
        }

        var trainingDiscipline: TrainingDiscipline? {
            switch self {
            case .all: return nil
            case .riding: return .riding
            case .running: return .running
            case .swimming: return .swimming
            case .shooting: return .shooting
            }
        }
    }

    private var allSessions: [SessionHistoryItem] {
        SessionHistoryItem.combined(
            rides: rides,
            runs: runningSessions,
            swims: swimmingSessions,
            shoots: shootingSessions,
            externals: externalWorkoutService.workouts,
            discipline: selectedDiscipline.trainingDiscipline,
            includeExternal: showExternalWorkouts
        )
    }

    /// Collect known HK workout UUIDs from all sessions for deduplication
    private var knownHealthKitUUIDs: Set<String> {
        var uuids = Set<String>()
        for ride in rides where !ride.healthKitWorkoutUUID.isEmpty {
            uuids.insert(ride.healthKitWorkoutUUID)
        }
        for run in runningSessions where !run.healthKitWorkoutUUID.isEmpty {
            uuids.insert(run.healthKitWorkoutUUID)
        }
        for swim in swimmingSessions where !swim.healthKitWorkoutUUID.isEmpty {
            uuids.insert(swim.healthKitWorkoutUUID)
        }
        for shoot in shootingSessions where !shoot.healthKitWorkoutUUID.isEmpty {
            uuids.insert(shoot.healthKitWorkoutUUID)
        }
        return uuids
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .navigationTitle("Training History")
        .toolbar {
            if let dismissAction = onDismiss {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismissAction() }
                }
            }
        }
        .onAppear {
            // Apply initial values if provided
            if !hasAppliedInitialValues {
                if let discipline = initialDiscipline {
                    selectedDiscipline = discipline
                    // Auto-open shooting history when navigating with shooting discipline
                    if discipline == .shooting {
                        showingShootingHistory = true
                    }
                }
                if let tab = initialTab {
                    selectedTab = tab
                }
                hasAppliedInitialValues = true
            }
            if showExternalWorkouts {
                fetchExternalWorkouts()
            }
        }
        .sheet(isPresented: $showingShootingHistory) {
            ShootingHistoryAggregateView(onDismiss: { showingShootingHistory = false })
        }
    }

    // MARK: - iPad Layout (Split View)

    private var iPadLayout: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Tab picker in sidebar
                Picker("View", selection: $selectedTab) {
                    ForEach(HistoryTab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.icon)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                if selectedTab == .sessions {
                    iPadSessionsList
                } else {
                    SessionInsightsView(
                        rides: rides,
                        runningSessions: runningSessions,
                        swimmingSessions: swimmingSessions,
                        shootingSessions: shootingSessions,
                        externalWorkouts: externalWorkoutService.workouts
                    )
                }
            }
            .navigationTitle("Session History")
        } detail: {
            if selectedTab == .sessions {
                if let item = selectedItem {
                    detailView(for: item)
                } else {
                    ContentUnavailableView(
                        "Select a Session",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Choose a session to view details")
                    )
                }
            } else {
                ContentUnavailableView(
                    "Session Insights",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("View cross-session insights in the left panel")
                )
            }
        }
    }

    private var iPadSessionsList: some View {
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
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding()

            // Show shooting history button when Shooting is selected
            if selectedDiscipline == .shooting {
                shootingHistoryButton
            } else if allSessions.isEmpty {
                ContentUnavailableView(
                    "No Sessions",
                    systemImage: "clock",
                    description: Text("Your completed sessions will appear here")
                )
            } else {
                List(selection: $selectedItem) {
                    ForEach(allSessions) { item in
                        SessionHistoryRow(item: item)
                            .tag(item)
                    }
                    .onDelete(perform: deleteSessions)
                }
                .listStyle(.sidebar)
            }
        }
    }

    // MARK: - Shooting History Button

    private var shootingHistoryButton: some View {
        VStack(spacing: 24) {
            Image(systemName: "target")
                .font(.system(size: 64))
                .foregroundStyle(.red)

            Text("Shooting History")
                .font(.title2.bold())

            Text("View detailed shot patterns, trends, and insights from your shooting sessions.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showingShootingHistory = true
            } label: {
                Label("Open Shooting History", systemImage: "arrow.up.right")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func detailView(for item: SessionHistoryItem) -> some View {
        if let ext = item.externalWorkout {
            EnrichedWorkoutDetailView(workout: ext)
        } else {
            switch item.discipline {
            case .riding:
                if let ride = item.ride {
                    RideDetailView(ride: ride)
                }
            case .running:
                if let session = item.runningSession {
                    EnrichedWorkoutDetailView(workout: session.asExternalWorkout, prebuiltEnrichment: session.asEnrichment)
                }
            case .walking:
                if let session = item.runningSession {
                    EnrichedWorkoutDetailView(workout: session.asExternalWorkout, prebuiltEnrichment: session.asEnrichment)
                }
            case .swimming:
                if let session = item.swimmingSession {
                    EnrichedWorkoutDetailView(workout: session.asExternalWorkout, prebuiltEnrichment: session.asEnrichment)
                }
            case .shooting:
                if let session = item.shootingSession {
                    ShootingSessionDetailView(session: session)
                }
            }
        }
    }

    // MARK: - iPhone Layout (Stack)

    private var iPhoneLayout: some View {
        VStack(spacing: 0) {
            // Tab picker for Sessions vs Session Insights
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
                SessionInsightsView(
                    rides: rides,
                    runningSessions: runningSessions,
                    swimmingSessions: swimmingSessions,
                    shootingSessions: shootingSessions
                )
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
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding()

            // Show shooting history button when Shooting is selected
            if selectedDiscipline == .shooting {
                shootingHistoryButton
            } else if allSessions.isEmpty {
                ContentUnavailableView(
                    "No Sessions",
                    systemImage: "clock",
                    description: Text("Your completed sessions will appear here")
                )
            } else {
                List {
                    ForEach(allSessions) { item in
                        NavigationLink(destination: destinationView(for: item)) {
                            SessionHistoryRow(item: item)
                        }
                    }
                    .onDelete(perform: deleteSessions)
                }
            }
        }
    }

    @ViewBuilder
    private func destinationView(for item: SessionHistoryItem) -> some View {
        if let ext = item.externalWorkout {
            EnrichedWorkoutDetailView(workout: ext)
        } else {
            switch item.discipline {
            case .riding:
                if let ride = item.ride {
                    RideDetailView(ride: ride)
                }
            case .running:
                if let session = item.runningSession {
                    EnrichedWorkoutDetailView(workout: session.asExternalWorkout, prebuiltEnrichment: session.asEnrichment)
                }
            case .walking:
                if let session = item.runningSession {
                    EnrichedWorkoutDetailView(workout: session.asExternalWorkout, prebuiltEnrichment: session.asEnrichment)
                }
            case .swimming:
                if let session = item.swimmingSession {
                    EnrichedWorkoutDetailView(workout: session.asExternalWorkout, prebuiltEnrichment: session.asEnrichment)
                }
            case .shooting:
                if let session = item.shootingSession {
                    ShootingSessionDetailView(session: session)
                }
            }
        }
    }

    // MARK: - External Workouts

    private func fetchExternalWorkouts() {
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        Task {
            await externalWorkoutService.fetchWorkouts(
                from: sixMonthsAgo,
                to: Date(),
                knownUUIDs: knownHealthKitUUIDs
            )
        }
    }

    // MARK: - Delete Sessions

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            let item = allSessions[index]
            // External workouts can't be deleted from TetraTrack
            guard !item.isExternal else { continue }
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
        WidgetDataSyncService.shared.syncRecentSessions(context: modelContext)
    }
}

// MARK: - Session History Row

struct SessionHistoryRow: View {
    let item: SessionHistoryItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: item.isExternal ? (item.externalWorkout?.activityIcon ?? item.discipline.icon) : item.discipline.icon)
                    .font(.title2)
                    .foregroundStyle(item.isExternal ? .blue : item.discipline.color)
                    .frame(width: 32)

                if item.isExternal {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white)
                        .background(Circle().fill(.blue).frame(width: 12, height: 12))
                        .offset(x: 4, y: 4)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.name)
                        .font(.headline)

                    if item.isExternal, let source = item.externalSourceName {
                        Text(source)
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.blue.opacity(0.7)))
                    }
                }

                HStack(spacing: 12) {
                    if !item.primaryMetric.isEmpty {
                        Label(item.primaryMetric, systemImage: "ruler")
                    }
                    Label(item.formattedDuration, systemImage: "clock")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if let secondary = item.secondaryMetric, !item.isExternal {
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

// MARK: - Session Insights View

struct SessionInsightsView: View {
    let rides: [Ride]
    let runningSessions: [RunningSession]
    let swimmingSessions: [SwimmingSession]
    let shootingSessions: [ShootingSession]
    var externalWorkouts: [ExternalWorkout] = []

    @State private var selectedLens: DisciplineLens = .unified

    enum DisciplineLens: String, CaseIterable, Identifiable {
        case unified = "All Sessions"
        case riding = "Riding"
        case running = "Running"
        case swimming = "Swimming"
        case shooting = "Shooting"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .unified: return "circle.hexagongrid"
            case .riding: return "figure.equestrian.sports"
            case .running: return "figure.run"
            case .swimming: return "figure.pool.swim"
            case .shooting: return "target"
            }
        }

        var color: Color {
            switch self {
            case .unified: return .purple
            case .riding: return TrainingDiscipline.riding.color
            case .running: return TrainingDiscipline.running.color
            case .swimming: return TrainingDiscipline.swimming.color
            case .shooting: return TrainingDiscipline.shooting.color
            }
        }
    }

    // MARK: - External Workout Helpers

    private var externalRuns: [ExternalWorkout] {
        externalWorkouts.filter { $0.activityType == .running || $0.activityType == .hiking }
    }

    private var externalWalks: [ExternalWorkout] {
        externalWorkouts.filter { $0.activityType == .walking }
    }

    private var externalSwims: [ExternalWorkout] {
        externalWorkouts.filter { $0.activityType == .swimming }
    }

    private var externalCycles: [ExternalWorkout] {
        externalWorkouts.filter { $0.activityType == .cycling }
    }

    private var externalOther: [ExternalWorkout] {
        externalWorkouts.filter {
            $0.activityType != .running && $0.activityType != .hiking &&
            $0.activityType != .walking && $0.activityType != .swimming &&
            $0.activityType != .cycling && $0.activityType != .equestrianSports
        }
    }

    // MARK: - Computed Properties

    private var totalSessions: Int {
        rides.count + runningSessions.count + swimmingSessions.count + shootingSessions.count + externalWorkouts.count
    }

    private var hasData: Bool {
        totalSessions > 0
    }

    private var recentWindowDays: Int { 14 }

    private var recentCutoff: Date {
        Calendar.current.date(byAdding: .day, value: -recentWindowDays, to: Date()) ?? Date()
    }

    private var recentRides: [Ride] {
        rides.filter { $0.startDate >= recentCutoff }
    }

    private var recentRuns: [RunningSession] {
        runningSessions.filter { $0.startDate >= recentCutoff }
    }

    private var recentSwims: [SwimmingSession] {
        swimmingSessions.filter { $0.startDate >= recentCutoff }
    }

    private var recentShoots: [ShootingSession] {
        shootingSessions.filter { $0.startDate >= recentCutoff }
    }

    private var recentExternalRuns: [ExternalWorkout] {
        externalRuns.filter { $0.startDate >= recentCutoff }
    }

    private var recentExternalWalks: [ExternalWorkout] {
        externalWalks.filter { $0.startDate >= recentCutoff }
    }

    private var recentExternalSwims: [ExternalWorkout] {
        externalSwims.filter { $0.startDate >= recentCutoff }
    }

    private var recentExternalCycles: [ExternalWorkout] {
        externalCycles.filter { $0.startDate >= recentCutoff }
    }

    private var recentExternalOther: [ExternalWorkout] {
        externalOther.filter { $0.startDate >= recentCutoff }
    }

    /// Combined run count (TetraTrack + HealthKit)
    private var totalRunCount: Int { runningSessions.count + externalRuns.count }
    private var totalSwimCount: Int { swimmingSessions.count + externalSwims.count }
    private var recentRunCount: Int { recentRuns.count + recentExternalRuns.count }
    private var recentSwimCount: Int { recentSwims.count + recentExternalSwims.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !hasData {
                    emptyStateView
                } else {
                    // Unified Overview Layer (always visible at top)
                    unifiedOverviewSection

                    // Fitness & Recovery (always visible)
                    fitnessTrendsSection
                    recoveryIntelligenceSection

                    // Discipline Lens Selector
                    disciplineLensSelector

                    // Aggregated Insights based on selected lens
                    if selectedLens == .unified {
                        crossDisciplineTransferSection
                        consistencyVariabilitySection
                    } else {
                        pillarScoreTrendsSection
                        consistencyVariabilitySection
                        disciplineSpecificInsights
                    }

                    // Cross-Discipline Transfer (persistent)
                    if selectedLens != .unified {
                        crossDisciplineTransferSection
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Session Data")
                .font(.headline)

            Text("Complete sessions in Riding, Running, Swimming, or Shooting to see cross-session insights.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - Unified Overview Section

    private var unifiedOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.pie")
                    .foregroundStyle(.purple)
                Text("Cross-Session Overview")
                    .font(.headline)
                Spacer()
                Text("Last \(recentWindowDays) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Session distribution
            sessionDistributionRow

            Divider()

            // Training frequency pattern
            trainingFrequencyInsight

            Divider()

            // Movement domain synthesis
            movementDomainSynthesis
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var sessionDistributionRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                sessionCountPill("Ride", count: rides.count, recent: recentRides.count, color: .green, icon: "figure.equestrian.sports")
                sessionCountPill("Run", count: totalRunCount, recent: recentRunCount, color: .orange, icon: "figure.run")
                sessionCountPill("Swim", count: totalSwimCount, recent: recentSwimCount, color: .blue, icon: "figure.pool.swim")
                sessionCountPill("Shoot", count: shootingSessions.count, recent: recentShoots.count, color: .red, icon: "target")
            }

            if !externalWalks.isEmpty || !externalCycles.isEmpty || !externalOther.isEmpty {
                HStack(spacing: 12) {
                    if !externalWalks.isEmpty {
                        sessionCountPill("Walk", count: externalWalks.count, recent: recentExternalWalks.count, color: .mint, icon: "figure.walk")
                    }
                    if !externalCycles.isEmpty {
                        sessionCountPill("Cycle", count: externalCycles.count, recent: recentExternalCycles.count, color: .cyan, icon: "figure.outdoor.cycle")
                    }
                    if !externalOther.isEmpty {
                        sessionCountPill("Other", count: externalOther.count, recent: recentExternalOther.count, color: .purple, icon: "figure.mixed.cardio")
                    }
                }
            }
        }
    }

    private func sessionCountPill(_ name: String, count: Int, recent: Int, color: Color, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(count > 0 ? color : .gray.opacity(0.4))

            Text("\(count)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(count > 0 ? .primary : .secondary)

            if recent > 0 {
                Text("+\(recent)")
                    .font(.caption2)
                    .foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var trainingFrequencyInsight: some View {
        let recentExternalCount = externalWorkouts.filter { $0.startDate >= recentCutoff }.count
        let recentTotal = recentRides.count + recentRuns.count + recentSwims.count + recentShoots.count + recentExternalCount
        let avgPerWeek = Double(recentTotal) / 2.0

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(.blue)
                Text("Training Frequency")
                    .font(.subheadline.bold())
            }

            if recentTotal == 0 {
                Text("No sessions in the last \(recentWindowDays) days.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(recentTotal) sessions in \(recentWindowDays) days (\(String(format: "%.1f", avgPerWeek)) per week average)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Discipline balance assessment — includes external workouts
                let disciplineCount = [
                    recentRides.count > 0,
                    recentRunCount > 0,
                    recentSwimCount > 0,
                    recentShoots.count > 0
                ].filter { $0 }.count

                if disciplineCount == 4 {
                    InsightBadge(text: "All four disciplines active", style: .positive)
                } else if disciplineCount >= 2 {
                    InsightBadge(text: "\(disciplineCount) of 4 disciplines active", style: .neutral)
                } else {
                    InsightBadge(text: "Single discipline focus", style: .attention)
                }
            }
        }
    }

    private var movementDomainSynthesis: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "figure.mixed.cardio")
                    .foregroundStyle(.mint)
                Text("Movement Patterns")
                    .font(.subheadline.bold())
            }

            // Synthesize patterns across disciplines
            VStack(alignment: .leading, spacing: 6) {
                if !rides.isEmpty {
                    let avgSymmetry = rides.reduce(0) { $0 + $1.overallSymmetry } / Double(rides.count)

                    if avgSymmetry > 0 {
                        MovementPatternRow(
                            domain: "Symmetry & Balance",
                            value: String(format: "%.0f%%", avgSymmetry),
                            trend: symmetryTrend,
                            icon: "arrow.left.and.right"
                        )
                    }
                }

                if !runningSessions.isEmpty {
                    let avgCadence = runningSessions.reduce(0) { $0 + $1.averageCadence } / runningSessions.count
                    MovementPatternRow(
                        domain: "Rhythm & Cadence",
                        value: "\(avgCadence) spm",
                        trend: cadenceTrend,
                        icon: "metronome"
                    )
                }

                if !shootingSessions.isEmpty {
                    let avgScore = shootingSessions.reduce(0) { $0 + $1.scorePercentage } / Double(shootingSessions.count)
                    MovementPatternRow(
                        domain: "Precision & Control",
                        value: String(format: "%.0f%%", avgScore),
                        trend: precisionTrend,
                        icon: "scope"
                    )
                }

                if !swimmingSessions.isEmpty {
                    let avgSwolf = swimmingSessions.reduce(0) { $0 + $1.averageSwolf } / Double(swimmingSessions.count)
                    if avgSwolf > 0 {
                        MovementPatternRow(
                            domain: "Efficiency",
                            value: String(format: "%.0f", avgSwolf),
                            trend: efficiencyTrend,
                            icon: "wind"
                        )
                    }
                }
            }
        }
    }

    // MARK: - Discipline Lens Selector

    private var disciplineLensSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus Lens")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DisciplineLens.allCases) { lens in
                        let isSelected = selectedLens == lens
                        let hasData = lensHasData(lens)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedLens = lens
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: lens.icon)
                                    .font(.caption)
                                Text(lens.rawValue)
                                    .font(.subheadline)
                            }
                            .fontWeight(isSelected ? .semibold : .regular)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? lens.color.opacity(0.15) : Color.clear)
                            .foregroundStyle(isSelected ? lens.color : (hasData ? .primary : .secondary))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(isSelected ? lens.color.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!hasData && lens != .unified)
                    }
                }
            }
        }
    }

    private func lensHasData(_ lens: DisciplineLens) -> Bool {
        switch lens {
        case .unified: return hasData
        case .riding: return !rides.isEmpty
        case .running: return !runningSessions.isEmpty
        case .swimming: return !swimmingSessions.isEmpty
        case .shooting: return !shootingSessions.isEmpty
        }
    }

    // MARK: - Consistency vs Variability Section

    private var consistencyVariabilitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(.cyan)
                Text("Consistency vs Variability")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 12) {
                // Riding consistency
                if rides.count >= 3 {
                    let durations = rides.prefix(10).map { $0.totalDuration }
                    let durationCV = coefficientOfVariation(durations)

                    ConsistencyRow(
                        metric: "Ride Duration",
                        variability: durationCV,
                        sampleSize: min(rides.count, 10),
                        discipline: .riding
                    )
                }

                // Running consistency
                if runningSessions.count >= 3 {
                    let paces = runningSessions.prefix(10).map { $0.averagePace }
                    let paceCV = coefficientOfVariation(paces)

                    ConsistencyRow(
                        metric: "Running Pace",
                        variability: paceCV,
                        sampleSize: min(runningSessions.count, 10),
                        discipline: .running
                    )
                }

                // Shooting consistency
                if shootingSessions.count >= 3 {
                    let scores = shootingSessions.prefix(10).map { $0.scorePercentage }
                    let scoreCV = coefficientOfVariation(scores)

                    ConsistencyRow(
                        metric: "Shooting Accuracy",
                        variability: scoreCV,
                        sampleSize: min(shootingSessions.count, 10),
                        discipline: .shooting
                    )
                }

                // Swimming consistency
                if swimmingSessions.count >= 3 {
                    let swolfs = swimmingSessions.prefix(10).compactMap { $0.averageSwolf > 0 ? $0.averageSwolf : nil }
                    if swolfs.count >= 3 {
                        let swolfCV = coefficientOfVariation(swolfs)
                        ConsistencyRow(
                            metric: "SWOLF Score",
                            variability: swolfCV,
                            sampleSize: swolfs.count,
                            discipline: .swimming
                        )
                    }
                }
            }

            if rides.count < 3 && runningSessions.count < 3 && shootingSessions.count < 3 && swimmingSessions.count < 3 {
                Text("Complete at least 3 sessions in any discipline to see consistency patterns.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Discipline Specific Insights

    @ViewBuilder
    private var disciplineSpecificInsights: some View {
        switch selectedLens {
        case .unified:
            EmptyView()
        case .riding:
            ridingAggregatedInsights
        case .running:
            runningAggregatedInsights
        case .swimming:
            swimmingAggregatedInsights
        case .shooting:
            shootingAggregatedInsights
        }
    }

    private var ridingAggregatedInsights: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "figure.equestrian.sports")
                    .foregroundStyle(.green)
                Text("Riding Patterns")
                    .font(.headline)
                Spacer()
                Text("\(rides.count) sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if rides.isEmpty {
                Text("No riding sessions recorded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // Biomechanical patterns
                biomechanicalPatternsSection

                Divider()

                // Gait trends
                gaitTrendsSection

                Divider()

                // Changes over time
                ridingChangesOverTime
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var biomechanicalPatternsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recurring Patterns")
                .font(.subheadline.bold())

            let recentRideCount = min(rides.count, 14)
            let ridesForAnalysis = Array(rides.prefix(14))

            // Left turn bias pattern
            let leftBiasCount = ridesForAnalysis.filter { $0.turnBalancePercent > 55 }.count
            let rightBiasCount = ridesForAnalysis.filter { $0.turnBalancePercent < 45 }.count

            if leftBiasCount >= 3 {
                PatternRow(
                    pattern: "Left turn preference",
                    frequency: "\(leftBiasCount) of \(recentRideCount)",
                    type: .observation
                )
            }
            if rightBiasCount >= 3 {
                PatternRow(
                    pattern: "Right turn preference",
                    frequency: "\(rightBiasCount) of \(recentRideCount)",
                    type: .observation
                )
            }

            // Symmetry patterns
            let asymmetricCount = ridesForAnalysis.filter { $0.overallSymmetry > 0 && $0.overallSymmetry < 75 }.count
            if asymmetricCount >= 3 {
                PatternRow(
                    pattern: "Rein asymmetry detected",
                    frequency: "\(asymmetricCount) of \(recentRideCount)",
                    type: .attention
                )
            }

            if leftBiasCount < 3 && rightBiasCount < 3 && asymmetricCount < 3 {
                Text("No recurring patterns detected in recent sessions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var gaitTrendsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gait Quality Trends")
                .font(.subheadline.bold())

            let ridesWithGaits = rides.filter { !($0.gaitSegments ?? []).isEmpty }

            if ridesWithGaits.count >= 2 {
                // Lead consistency across sessions
                let ridesWithLeadData = ridesWithGaits.filter { $0.totalLeadDuration > 0 }
                if ridesWithLeadData.count >= 2 {
                    HStack {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("Lead balance: \(leadBalanceStatus(for: ridesWithLeadData))")
                            .font(.caption)
                    }
                }

                // Rhythm consistency
                let ridesWithRhythm = ridesWithGaits.compactMap { ride -> Double? in
                    let segments = ride.gaitSegments ?? []
                    let rhythmScores = segments.compactMap { $0.rhythmScore > 0 ? $0.rhythmScore : nil }
                    return rhythmScores.isEmpty ? nil : rhythmScores.reduce(0, +) / Double(rhythmScores.count)
                }

                if ridesWithRhythm.count >= 2 {
                    let avgRhythm = ridesWithRhythm.reduce(0, +) / Double(ridesWithRhythm.count)
                    HStack {
                        Image(systemName: "metronome")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("Average rhythm score: \(String(format: "%.0f%%", avgRhythm)) across \(ridesWithRhythm.count) sessions")
                            .font(.caption)
                    }
                }
            } else {
                Text("Complete more sessions with gait data to see trends.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var ridingChangesOverTime: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Changes (Last \(recentWindowDays) Days)")
                .font(.subheadline.bold())

            if recentRides.count >= 2 {
                // Compare recent to older
                let olderRides = rides.filter { ride in !recentRides.contains(where: { $0.id == ride.id }) }.prefix(recentRides.count)

                if !olderRides.isEmpty {
                    // Duration trend
                    let recentAvgDuration = recentRides.reduce(0) { $0 + $1.totalDuration } / Double(recentRides.count)
                    let olderAvgDuration = olderRides.reduce(0) { $0 + $1.totalDuration } / Double(olderRides.count)
                    let durationDelta = ((recentAvgDuration - olderAvgDuration) / olderAvgDuration) * 100

                    if abs(durationDelta) >= 10 {
                        DeltaRow(
                            metric: "Avg duration",
                            delta: durationDelta,
                            unit: "%"
                        )
                    }
                } else {
                    Text("Need older sessions to compare trends.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Complete more recent sessions to see changes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var runningAggregatedInsights: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "figure.run")
                    .foregroundStyle(.orange)
                Text("Running Patterns")
                    .font(.headline)
                Spacer()
                Text("\(totalRunCount) sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if runningSessions.isEmpty {
                Text("No running sessions recorded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // Pace patterns
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pace Patterns")
                        .font(.subheadline.bold())

                    let avgPace = runningSessions.reduce(0) { $0 + $1.averagePace } / Double(runningSessions.count)
                    let avgCadence = runningSessions.reduce(0) { $0 + $1.averageCadence } / runningSessions.count

                    HStack {
                        VStack(alignment: .leading) {
                            Text(avgPace.formattedPace)
                                .font(.title2.bold().monospacedDigit())
                            Text("Avg pace /km")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("\(avgCadence)")
                                .font(.title2.bold().monospacedDigit())
                            Text("Avg cadence")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Pace consistency
                    if runningSessions.count >= 3 {
                        let paces = runningSessions.map { $0.averagePace }
                        let paceCV = coefficientOfVariation(paces)

                        if paceCV < 5 {
                            InsightBadge(text: "Highly consistent pacing", style: .positive)
                        } else if paceCV < 15 {
                            InsightBadge(text: "Moderate pace variation", style: .neutral)
                        } else {
                            InsightBadge(text: "Variable pacing across sessions", style: .attention)
                        }
                    }
                }

                Divider()

                // Changes over time
                VStack(alignment: .leading, spacing: 8) {
                    Text("Changes (Last \(recentWindowDays) Days)")
                        .font(.subheadline.bold())

                    if recentRuns.count >= 2 {
                        let olderRuns = runningSessions.filter { run in !recentRuns.contains(where: { $0.id == run.id }) }.prefix(recentRuns.count)

                        if !olderRuns.isEmpty {
                            let recentAvgPace = recentRuns.reduce(0) { $0 + $1.averagePace } / Double(recentRuns.count)
                            let olderAvgPace = olderRuns.reduce(0) { $0 + $1.averagePace } / Double(olderRuns.count)
                            let paceDelta = olderAvgPace - recentAvgPace // Negative pace = faster

                            if abs(paceDelta) >= 5 {
                                DeltaRow(
                                    metric: "Pace",
                                    delta: paceDelta,
                                    unit: "sec/km",
                                    invertColor: true
                                )
                            }
                        }
                    } else {
                        Text("Complete more recent sessions to see changes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var swimmingAggregatedInsights: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "figure.pool.swim")
                    .foregroundStyle(.blue)
                Text("Swimming Patterns")
                    .font(.headline)
                Spacer()
                Text("\(totalSwimCount) sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if swimmingSessions.isEmpty {
                Text("No swimming sessions recorded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // Efficiency patterns
                VStack(alignment: .leading, spacing: 8) {
                    Text("Efficiency Patterns")
                        .font(.subheadline.bold())

                    let avgSwolf = swimmingSessions.reduce(0) { $0 + $1.averageSwolf } / Double(swimmingSessions.count)
                    let totalLaps = swimmingSessions.reduce(0) { $0 + $1.lapCount }

                    HStack {
                        VStack(alignment: .leading) {
                            Text(String(format: "%.0f", avgSwolf))
                                .font(.title2.bold().monospacedDigit())
                            Text("Avg SWOLF")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("\(totalLaps)")
                                .font(.title2.bold().monospacedDigit())
                            Text("Total laps")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // SWOLF consistency
                    if swimmingSessions.count >= 3 {
                        let swolfs = swimmingSessions.compactMap { $0.averageSwolf > 0 ? $0.averageSwolf : nil }
                        if swolfs.count >= 3 {
                            let swolfCV = coefficientOfVariation(swolfs)

                            if swolfCV < 5 {
                                InsightBadge(text: "Highly consistent stroke efficiency", style: .positive)
                            } else if swolfCV < 10 {
                                InsightBadge(text: "Moderate efficiency variation", style: .neutral)
                            } else {
                                InsightBadge(text: "Variable stroke efficiency", style: .attention)
                            }
                        }
                    }
                }

                Divider()

                // Typical session summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Typical Session")
                        .font(.subheadline.bold())

                    let avgDuration = swimmingSessions.reduce(0) { $0 + $1.totalDuration } / Double(swimmingSessions.count)
                    let avgDistance = swimmingSessions.reduce(0) { $0 + $1.totalDistance } / Double(swimmingSessions.count)

                    Text("Typical session: \(Int(avgDistance))m in \(avgDuration.formattedDuration)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var shootingAggregatedInsights: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(.red)
                Text("Shooting Patterns")
                    .font(.headline)
                Spacer()
                Text("\(shootingSessions.count) sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if shootingSessions.isEmpty {
                Text("No shooting sessions recorded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // Accuracy patterns
                VStack(alignment: .leading, spacing: 8) {
                    Text("Accuracy Patterns")
                        .font(.subheadline.bold())

                    let avgScore = shootingSessions.reduce(0) { $0 + $1.scorePercentage } / Double(shootingSessions.count)
                    let totalXs = shootingSessions.reduce(0) { $0 + $1.xCount }

                    HStack {
                        VStack(alignment: .leading) {
                            Text(String(format: "%.0f%%", avgScore))
                                .font(.title2.bold().monospacedDigit())
                            Text("Avg accuracy")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("\(totalXs)")
                                .font(.title2.bold().monospacedDigit())
                            Text("Total X's")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Score consistency
                    if shootingSessions.count >= 3 {
                        let scores = shootingSessions.map { $0.scorePercentage }
                        let scoreCV = coefficientOfVariation(scores)

                        if scoreCV < 5 {
                            InsightBadge(text: "Highly consistent accuracy", style: .positive)
                        } else if scoreCV < 15 {
                            InsightBadge(text: "Moderate score variation", style: .neutral)
                        } else {
                            InsightBadge(text: "Variable accuracy across sessions", style: .attention)
                        }
                    }
                }

                Divider()

                // Fatigue/degradation patterns
                VStack(alignment: .leading, spacing: 8) {
                    Text("Performance Patterns")
                        .font(.subheadline.bold())

                    // Check for score degradation within sessions (end fatigue)
                    let degradationInfo = computeShootingDegradation()

                    if degradationInfo.degradationCount >= 2 {
                        PatternRow(
                            pattern: "Late-session score drop",
                            frequency: "\(degradationInfo.degradationCount) of \(degradationInfo.totalSessions)",
                            type: .attention
                        )
                    }

                    let avgPerArrow = shootingSessions.reduce(0) { $0 + $1.averageScorePerArrow } / Double(shootingSessions.count)
                    Text("Average score per arrow: \(String(format: "%.2f", avgPerArrow))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Cross-Discipline Transfer Section

    private var crossDisciplineTransferSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.indigo)
                Text("Cross-Discipline Transfer")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 12) {
                // Rhythm transfer: Running ↔ Swimming
                if !runningSessions.isEmpty && !swimmingSessions.isEmpty {
                    TransferInsightRow(
                        from: "Running",
                        to: "Swimming",
                        domain: "Breathing Rhythm",
                        insight: "Cadence discipline in running reinforces stroke timing and breath patterns"
                    )
                }

                // Endurance transfer: Swimming ↔ Running
                if !swimmingSessions.isEmpty && !runningSessions.isEmpty {
                    TransferInsightRow(
                        from: "Swimming",
                        to: "Running",
                        domain: "Aerobic Capacity",
                        insight: "Low-impact swim conditioning supports running recovery and base fitness"
                    )
                }

                // Balance transfer: Riding ↔ Running
                if !rides.isEmpty && !runningSessions.isEmpty {
                    TransferInsightRow(
                        from: "Riding",
                        to: "Running",
                        domain: "Dynamic Balance",
                        insight: "Saddle balance work translates to improved running form stability"
                    )
                }

                // Focus transfer: Shooting ↔ Riding
                if !shootingSessions.isEmpty && !rides.isEmpty {
                    TransferInsightRow(
                        from: "Shooting",
                        to: "Riding",
                        domain: "Mental Focus",
                        insight: "Precision focus in shooting supports collected work and transitions"
                    )
                }

                if rides.isEmpty && runningSessions.isEmpty && swimmingSessions.isEmpty && shootingSessions.isEmpty {
                    Text("Complete sessions across multiple disciplines to see transfer insights.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Trend Calculations

    private var symmetryTrend: InsightTrend {
        guard recentRides.count >= 2 else { return .stable }
        let recentSymmetries = recentRides.compactMap { $0.overallSymmetry > 0 ? $0.overallSymmetry : nil }
        guard recentSymmetries.count >= 2 else { return .stable }

        let firstHalf = recentSymmetries.prefix(recentSymmetries.count / 2)
        let secondHalf = recentSymmetries.suffix(recentSymmetries.count / 2)

        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)

        if secondAvg > firstAvg + 3 { return .improving }
        if secondAvg < firstAvg - 3 { return .declining }
        return .stable
    }

    private var cadenceTrend: InsightTrend {
        guard recentRuns.count >= 2 else { return .stable }
        let cadences = recentRuns.map { Double($0.averageCadence) }

        let firstHalf = cadences.prefix(cadences.count / 2)
        let secondHalf = cadences.suffix(cadences.count / 2)

        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)

        if secondAvg > firstAvg + 2 { return .improving }
        if secondAvg < firstAvg - 2 { return .declining }
        return .stable
    }

    private var precisionTrend: InsightTrend {
        guard recentShoots.count >= 2 else { return .stable }
        let scores = recentShoots.map { $0.scorePercentage }

        let firstHalf = scores.prefix(scores.count / 2)
        let secondHalf = scores.suffix(scores.count / 2)

        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)

        if secondAvg > firstAvg + 2 { return .improving }
        if secondAvg < firstAvg - 2 { return .declining }
        return .stable
    }

    private var efficiencyTrend: InsightTrend {
        guard recentSwims.count >= 2 else { return .stable }
        let swolfs = recentSwims.compactMap { $0.averageSwolf > 0 ? $0.averageSwolf : nil }
        guard swolfs.count >= 2 else { return .stable }

        let firstHalf = swolfs.prefix(swolfs.count / 2)
        let secondHalf = swolfs.suffix(swolfs.count / 2)

        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)

        // Lower SWOLF = better
        if secondAvg < firstAvg - 2 { return .improving }
        if secondAvg > firstAvg + 2 { return .declining }
        return .stable
    }

    // MARK: - Helper Functions

    private func coefficientOfVariation(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        guard mean > 0 else { return 0 }
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
        let stdDev = sqrt(variance)
        return (stdDev / mean) * 100
    }

    private func computeShootingDegradation() -> (degradationCount: Int, totalSessions: Int) {
        let sessionsWithMultipleEnds = shootingSessions.filter { ($0.ends ?? []).count >= 3 }
        guard sessionsWithMultipleEnds.count >= 2 else {
            return (0, sessionsWithMultipleEnds.count)
        }

        var degradationCount = 0
        for session in sessionsWithMultipleEnds {
            let ends = (session.ends ?? []).sorted(by: { $0.orderIndex < $1.orderIndex })
            if ends.count >= 3 {
                let halfCount = ends.count / 2
                let firstHalf = Array(ends.prefix(halfCount))
                let secondHalf = Array(ends.suffix(halfCount))
                let firstHalfAvg = firstHalf.reduce(0) { $0 + $1.totalScore } / halfCount
                let secondHalfAvg = secondHalf.reduce(0) { $0 + $1.totalScore } / halfCount
                if secondHalfAvg < firstHalfAvg - 2 {
                    degradationCount += 1
                }
            }
        }
        return (degradationCount, sessionsWithMultipleEnds.count)
    }

    private func leadBalanceStatus(for ridesWithLeadData: [Ride]) -> String {
        let avgLeadBalance = ridesWithLeadData.reduce(0) { $0 + abs(Double($1.leadBalancePercent) - 50) } / Double(ridesWithLeadData.count)
        if avgLeadBalance < 10 {
            return "Well balanced (\(String(format: "%.0f", 50 - avgLeadBalance))–\(String(format: "%.0f", 50 + avgLeadBalance))% range)"
        } else if avgLeadBalance < 20 {
            return "Moderate imbalance (±\(String(format: "%.0f", avgLeadBalance))%)"
        } else {
            return "Significant imbalance (±\(String(format: "%.0f", avgLeadBalance))%)"
        }
    }

    // MARK: - Trend Computation Helper

    private func computeTrend(values: [Double], inverted: Bool = false) -> (recent: Double, previous: Double, trend: InsightTrend) {
        let recentSlice = Array(values.prefix(5))
        let previousSlice = Array(values.dropFirst(5).prefix(5))
        guard !recentSlice.isEmpty else { return (0, 0, .stable) }
        let recentAvg = recentSlice.reduce(0, +) / Double(recentSlice.count)
        guard !previousSlice.isEmpty else { return (recentAvg, 0, .stable) }
        let previousAvg = previousSlice.reduce(0, +) / Double(previousSlice.count)
        let delta = recentAvg - previousAvg
        let threshold = max(previousAvg * 0.03, 1.0)
        let trend: InsightTrend
        if inverted {
            trend = delta < -threshold ? .improving : (delta > threshold ? .declining : .stable)
        } else {
            trend = delta > threshold ? .improving : (delta < -threshold ? .declining : .stable)
        }
        return (recentAvg, previousAvg, trend)
    }

    // MARK: - Fitness Trends Section

    private var fitnessTrendsSection: some View {
        let calendar = Calendar.current
        let now = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: now) ?? now

        let thisWeekRides = rides.filter { $0.startDate >= sevenDaysAgo }
        let thisWeekRuns = runningSessions.filter { $0.startDate >= sevenDaysAgo }
        let thisWeekSwims = swimmingSessions.filter { $0.startDate >= sevenDaysAgo }
        let thisWeekShoots = shootingSessions.filter { $0.startDate >= sevenDaysAgo }
        let thisWeekExternal = externalWorkouts.filter { $0.startDate >= sevenDaysAgo }
        let thisWeek = thisWeekRides.count + thisWeekRuns.count + thisWeekSwims.count + thisWeekShoots.count + thisWeekExternal.count

        let lastWeekRides = rides.filter { $0.startDate >= fourteenDaysAgo && $0.startDate < sevenDaysAgo }
        let lastWeekRuns = runningSessions.filter { $0.startDate >= fourteenDaysAgo && $0.startDate < sevenDaysAgo }
        let lastWeekSwims = swimmingSessions.filter { $0.startDate >= fourteenDaysAgo && $0.startDate < sevenDaysAgo }
        let lastWeekShoots = shootingSessions.filter { $0.startDate >= fourteenDaysAgo && $0.startDate < sevenDaysAgo }
        let lastWeekExternal = externalWorkouts.filter { $0.startDate >= fourteenDaysAgo && $0.startDate < sevenDaysAgo }
        let lastWeek = lastWeekRides.count + lastWeekRuns.count + lastWeekSwims.count + lastWeekShoots.count + lastWeekExternal.count

        let volumeTrend: InsightTrend = thisWeek > lastWeek ? .improving : (thisWeek == lastWeek ? .stable : .declining)
        let volumeInsight: String = {
            if lastWeek == 0 { return "No sessions recorded last week for comparison" }
            if thisWeek > lastWeek { return "Up from \(lastWeek) sessions last week — great momentum" }
            if thisWeek == lastWeek { return "Same volume as last week — steady routine" }
            return "Down from \(lastWeek) sessions last week"
        }()

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.green)
                Text("Fitness Trends")
                    .font(.headline)
            }

            InsightTrendRow(
                icon: "calendar",
                label: "Training Volume",
                value: "\(thisWeek) sessions/week",
                trend: volumeTrend,
                insight: volumeInsight
            )

            if rides.count >= 3 {
                let rhythmValues = rides.map(\.overallRhythm).filter { $0 > 0 }
                if rhythmValues.count >= 3 {
                    let result = computeTrend(values: rhythmValues)
                    InsightTrendRow(
                        icon: "metronome",
                        label: "Riding Rhythm",
                        value: String(format: "%.0f%%", result.recent),
                        trend: result.trend,
                        insight: result.previous > 0 ? "Recent avg \(String(format: "%.0f", result.recent))% vs previous \(String(format: "%.0f", result.previous))%" : "Building baseline from \(rhythmValues.count) sessions"
                    )
                }
            }

            if runningSessions.count >= 3 {
                let cadenceValues = runningSessions.map { Double($0.averageCadence) }.filter { $0 > 0 }
                if cadenceValues.count >= 3 {
                    let result = computeTrend(values: cadenceValues)
                    InsightTrendRow(
                        icon: "figure.run",
                        label: "Running Cadence",
                        value: "\(Int(result.recent)) spm",
                        trend: result.trend,
                        insight: result.previous > 0 ? "Recent avg \(Int(result.recent)) vs previous \(Int(result.previous)) spm" : "Building baseline from \(cadenceValues.count) sessions"
                    )
                }

                let gctValues = runningSessions.map(\.averageGroundContactTime).filter { $0 > 0 }
                if gctValues.count >= 3 {
                    let result = computeTrend(values: gctValues, inverted: true)
                    InsightTrendRow(
                        icon: "timer",
                        label: "Running GCT",
                        value: String(format: "%.0f ms", result.recent),
                        trend: result.trend,
                        insight: result.previous > 0 ? "Shorter is more efficient — recent \(String(format: "%.0f", result.recent)) vs previous \(String(format: "%.0f", result.previous)) ms" : "Building baseline from \(gctValues.count) sessions"
                    )
                }
            }

            if swimmingSessions.count >= 3 {
                let swolfValues = swimmingSessions.map(\.averageSwolf).filter { $0 > 0 }
                if swolfValues.count >= 3 {
                    let result = computeTrend(values: swolfValues, inverted: true)
                    InsightTrendRow(
                        icon: "figure.pool.swim",
                        label: "Swimming SWOLF",
                        value: String(format: "%.0f", result.recent),
                        trend: result.trend,
                        insight: result.previous > 0 ? "Recent avg \(String(format: "%.0f", result.recent)) vs previous \(String(format: "%.0f", result.previous))" : "Building baseline from \(swolfValues.count) sessions"
                    )
                }

                let strokeValues = swimmingSessions.map(\.averageStrokesPerLap).filter { $0 > 0 }
                if strokeValues.count >= 3 {
                    let result = computeTrend(values: strokeValues, inverted: true)
                    InsightTrendRow(
                        icon: "water.waves",
                        label: "Strokes/Lap",
                        value: String(format: "%.1f", result.recent),
                        trend: result.trend,
                        insight: result.previous > 0 ? "Fewer strokes = more efficient — recent \(String(format: "%.1f", result.recent)) vs previous \(String(format: "%.1f", result.previous))" : "Building baseline from \(strokeValues.count) sessions"
                    )
                }
            }

            if shootingSessions.count >= 3 {
                let scoreValues = shootingSessions.map(\.scorePercentage).filter { $0 > 0 }
                if scoreValues.count >= 3 {
                    let result = computeTrend(values: scoreValues)
                    InsightTrendRow(
                        icon: "target",
                        label: "Shooting Score",
                        value: String(format: "%.0f%%", result.recent),
                        trend: result.trend,
                        insight: result.previous > 0 ? "Recent avg \(String(format: "%.0f", result.recent))% vs previous \(String(format: "%.0f", result.previous))%" : "Building baseline from \(scoreValues.count) sessions"
                    )
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Recovery Intelligence Section

    private var recoveryIntelligenceSection: some View {
        let calendar = Calendar.current
        let now = Date()
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: now) ?? now

        // Discipline balance in last 14 days
        let recent14Rides = rides.filter { $0.startDate >= fourteenDaysAgo }.count
        let recent14Runs = (runningSessions.filter { $0.startDate >= fourteenDaysAgo }.count) + (externalWorkouts.filter { $0.startDate >= fourteenDaysAgo && ($0.activityType == .running || $0.activityType == .hiking) }.count)
        let recent14Swims = (swimmingSessions.filter { $0.startDate >= fourteenDaysAgo }.count) + (externalWorkouts.filter { $0.startDate >= fourteenDaysAgo && $0.activityType == .swimming }.count)
        let recent14Shoots = shootingSessions.filter { $0.startDate >= fourteenDaysAgo }.count
        let recent14Total = recent14Rides + recent14Runs + recent14Swims + recent14Shoots

        // Average HR across all recent sessions
        var allRecentHRs: [Double] = []
        for ride in rides.prefix(10) where ride.averageHeartRate > 0 {
            allRecentHRs.append(Double(ride.averageHeartRate))
        }
        for run in runningSessions.prefix(10) where run.averageHeartRate > 0 {
            allRecentHRs.append(Double(run.averageHeartRate))
        }
        for swim in swimmingSessions.prefix(10) where swim.averageHeartRate > 0 {
            allRecentHRs.append(Double(swim.averageHeartRate))
        }
        for shoot in shootingSessions.prefix(10) where shoot.averageHeartRate > 0 {
            allRecentHRs.append(Double(shoot.averageHeartRate))
        }
        let hrResult = computeTrend(values: allRecentHRs, inverted: true)

        // Riding fatigue degradation trend
        let fatigueTrend: (hasData: Bool, result: (recent: Double, previous: Double, trend: InsightTrend)) = {
            let fatigueValues = rides.map(\.endFatigueScore).filter { $0 > 0 }
            if fatigueValues.count >= 3 {
                return (true, computeTrend(values: fatigueValues, inverted: true))
            }
            return (false, (0, 0, .stable))
        }()

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.text.clipboard")
                    .foregroundStyle(.pink)
                Text("Recovery Intelligence")
                    .font(.headline)
            }

            // Discipline balance
            if recent14Total > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Training Balance (14 days)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 2) {
                        if recent14Rides > 0 {
                            balanceBar(count: recent14Rides, total: recent14Total, color: TrainingDiscipline.riding.color, label: "Ride")
                        }
                        if recent14Runs > 0 {
                            balanceBar(count: recent14Runs, total: recent14Total, color: TrainingDiscipline.running.color, label: "Run")
                        }
                        if recent14Swims > 0 {
                            balanceBar(count: recent14Swims, total: recent14Total, color: TrainingDiscipline.swimming.color, label: "Swim")
                        }
                        if recent14Shoots > 0 {
                            balanceBar(count: recent14Shoots, total: recent14Total, color: TrainingDiscipline.shooting.color, label: "Shoot")
                        }
                    }
                    .frame(height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    let disciplineCount = [recent14Rides, recent14Runs, recent14Swims, recent14Shoots].filter { $0 > 0 }.count
                    Text(disciplineCount >= 3 ? "Well-rounded training across \(disciplineCount) disciplines" : (disciplineCount == 2 ? "Training in \(disciplineCount) disciplines — consider adding variety" : "Single-discipline focus — cross-training benefits recovery"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            // Average HR trend
            if allRecentHRs.count >= 3 {
                InsightTrendRow(
                    icon: "heart.fill",
                    label: "Avg Heart Rate",
                    value: "\(Int(hrResult.recent)) bpm",
                    trend: hrResult.trend,
                    insight: hrResult.previous > 0 ? "Lower resting effort may indicate improved fitness" : "Building HR baseline from recent sessions"
                )
            }

            // Riding fatigue trend
            if fatigueTrend.hasData {
                let ft = fatigueTrend.result
                InsightTrendRow(
                    icon: "bolt.heart",
                    label: "Ride Fatigue",
                    value: String(format: "%.0f", ft.recent),
                    trend: ft.trend,
                    insight: ft.previous > 0 ? "End-of-session fatigue: recent \(String(format: "%.0f", ft.recent)) vs previous \(String(format: "%.0f", ft.previous))" : "Tracking fatigue build-up across rides"
                )
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func balanceBar(count: Int, total: Int, color: Color, label: String) -> some View {
        let fraction = Double(count) / Double(total)
        let percentage = Int(fraction * 100)
        return GeometryReader { geo in
            ZStack {
                color
                if geo.size.width > 30 {
                    Text("\(percentage)%")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(width: nil)
        .layoutPriority(Double(count))
        .accessibilityLabel("\(label) \(percentage)%")
    }

    // MARK: - Pillar Score Trends Section

    @ViewBuilder
    private var pillarScoreTrendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(selectedLens.color)
                Text("Metric Trends")
                    .font(.headline)
            }

            switch selectedLens {
            case .riding:
                ridingMetricTrends
            case .running:
                runningMetricTrends
            case .swimming:
                swimmingMetricTrends
            case .shooting:
                shootingMetricTrends
            case .unified:
                EmptyView()
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var ridingMetricTrends: some View {
        if rides.count < 3 {
            Text("Need at least 3 rides to show trends")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            let rhythmValues = rides.map(\.overallRhythm).filter { $0 > 0 }
            let symmetryValues = rides.map(\.overallSymmetry).filter { $0 > 0 }
            let stabilityValues = rides.map(\.riderStabilityBaseline).filter { $0 > 0 }
            let fatigueValues = rides.map(\.endFatigueScore).filter { $0 > 0 }

            if rhythmValues.count >= 3 {
                let r = computeTrend(values: rhythmValues)
                InsightTrendRow(icon: "metronome", label: "Rhythm", value: String(format: "%.0f%%", r.recent), trend: r.trend, insight: r.previous > 0 ? "Recent \(String(format: "%.0f", r.recent))% vs previous \(String(format: "%.0f", r.previous))%" : "Baseline: \(String(format: "%.0f", r.recent))%")
            }
            if symmetryValues.count >= 3 {
                let r = computeTrend(values: symmetryValues)
                InsightTrendRow(icon: "arrow.left.and.right", label: "Symmetry", value: String(format: "%.0f%%", r.recent), trend: r.trend, insight: r.previous > 0 ? "Recent \(String(format: "%.0f", r.recent))% vs previous \(String(format: "%.0f", r.previous))%" : "Baseline: \(String(format: "%.0f", r.recent))%")
            }
            if stabilityValues.count >= 3 {
                let r = computeTrend(values: stabilityValues)
                InsightTrendRow(icon: "figure.equestrian.sports", label: "Rider Stability", value: String(format: "%.1f", r.recent), trend: r.trend, insight: r.previous > 0 ? "Recent \(String(format: "%.1f", r.recent)) vs previous \(String(format: "%.1f", r.previous))" : "Baseline: \(String(format: "%.1f", r.recent))")
            }
            if fatigueValues.count >= 3 {
                let r = computeTrend(values: fatigueValues, inverted: true)
                InsightTrendRow(icon: "bolt.heart", label: "End Fatigue", value: String(format: "%.0f", r.recent), trend: r.trend, insight: r.previous > 0 ? "Lower is better — recent \(String(format: "%.0f", r.recent)) vs previous \(String(format: "%.0f", r.previous))" : "Baseline: \(String(format: "%.0f", r.recent))")
            }
        }
    }

    @ViewBuilder
    private var runningMetricTrends: some View {
        if runningSessions.count < 3 {
            Text("Need at least 3 runs to show trends")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            let cadenceValues = runningSessions.map { Double($0.averageCadence) }.filter { $0 > 0 }
            let gctValues = runningSessions.map(\.averageGroundContactTime).filter { $0 > 0 }
            let voValues = runningSessions.map(\.averageVerticalOscillation).filter { $0 > 0 }

            if cadenceValues.count >= 3 {
                let r = computeTrend(values: cadenceValues)
                InsightTrendRow(icon: "metronome", label: "Cadence", value: "\(Int(r.recent)) spm", trend: r.trend, insight: r.previous > 0 ? "Recent \(Int(r.recent)) vs previous \(Int(r.previous)) spm" : "Baseline: \(Int(r.recent)) spm")
            }
            if gctValues.count >= 3 {
                let r = computeTrend(values: gctValues, inverted: true)
                InsightTrendRow(icon: "timer", label: "Ground Contact", value: String(format: "%.0f ms", r.recent), trend: r.trend, insight: r.previous > 0 ? "Shorter is more efficient — recent \(String(format: "%.0f", r.recent)) vs previous \(String(format: "%.0f", r.previous)) ms" : "Baseline: \(String(format: "%.0f", r.recent)) ms")
            }
            if voValues.count >= 3 {
                let r = computeTrend(values: voValues, inverted: true)
                let voInsight = r.previous > 0
                    ? "Less bounce = more efficient — \(String(format: "%.1f", r.recent)) vs \(String(format: "%.1f", r.previous)) cm"
                    : "Baseline: \(String(format: "%.1f", r.recent)) cm"
                InsightTrendRow(
                    icon: "arrow.up.and.down", label: "Vertical Oscillation",
                    value: String(format: "%.1f cm", r.recent),
                    trend: r.trend, insight: voInsight
                )
            }
        }
    }

    @ViewBuilder
    private var swimmingMetricTrends: some View {
        if swimmingSessions.count < 3 {
            Text("Need at least 3 swims to show trends")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            let swolfValues = swimmingSessions.map(\.averageSwolf).filter { $0 > 0 }
            let strokeValues = swimmingSessions.map(\.averageStrokesPerLap).filter { $0 > 0 }

            if swolfValues.count >= 3 {
                let r = computeTrend(values: swolfValues, inverted: true)
                InsightTrendRow(icon: "figure.pool.swim", label: "SWOLF", value: String(format: "%.0f", r.recent), trend: r.trend, insight: r.previous > 0 ? "Lower is better — recent \(String(format: "%.0f", r.recent)) vs previous \(String(format: "%.0f", r.previous))" : "Baseline: \(String(format: "%.0f", r.recent))")
            }
            if strokeValues.count >= 3 {
                let r = computeTrend(values: strokeValues, inverted: true)
                InsightTrendRow(icon: "water.waves", label: "Strokes/Lap", value: String(format: "%.1f", r.recent), trend: r.trend, insight: r.previous > 0 ? "Fewer strokes = more efficient — recent \(String(format: "%.1f", r.recent)) vs previous \(String(format: "%.1f", r.previous))" : "Baseline: \(String(format: "%.1f", r.recent))")
            }
        }
    }

    @ViewBuilder
    private var shootingMetricTrends: some View {
        if shootingSessions.count < 3 {
            Text("Need at least 3 shooting sessions to show trends")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            let stabilityValues = shootingSessions.map(\.stabilityScore).filter { $0 > 0 }
            let rhythmValues = shootingSessions.map(\.rhythmScore).filter { $0 > 0 }
            let symmetryValues = shootingSessions.map(\.symmetryScore).filter { $0 > 0 }
            let economyValues = shootingSessions.map(\.economyScore).filter { $0 > 0 }

            if stabilityValues.count >= 3 {
                let r = computeTrend(values: stabilityValues)
                InsightTrendRow(icon: "scope", label: "Stability", value: String(format: "%.0f%%", r.recent), trend: r.trend, insight: r.previous > 0 ? "Recent \(String(format: "%.0f", r.recent))% vs previous \(String(format: "%.0f", r.previous))%" : "Baseline: \(String(format: "%.0f", r.recent))%")
            }
            if rhythmValues.count >= 3 {
                let r = computeTrend(values: rhythmValues)
                InsightTrendRow(icon: "metronome", label: "Rhythm", value: String(format: "%.0f%%", r.recent), trend: r.trend, insight: r.previous > 0 ? "Recent \(String(format: "%.0f", r.recent))% vs previous \(String(format: "%.0f", r.previous))%" : "Baseline: \(String(format: "%.0f", r.recent))%")
            }
            if symmetryValues.count >= 3 {
                let r = computeTrend(values: symmetryValues)
                InsightTrendRow(icon: "arrow.left.and.right", label: "Symmetry", value: String(format: "%.0f%%", r.recent), trend: r.trend, insight: r.previous > 0 ? "Recent \(String(format: "%.0f", r.recent))% vs previous \(String(format: "%.0f", r.previous))%" : "Baseline: \(String(format: "%.0f", r.recent))%")
            }
            if economyValues.count >= 3 {
                let r = computeTrend(values: economyValues)
                InsightTrendRow(icon: "bolt", label: "Economy", value: String(format: "%.0f%%", r.recent), trend: r.trend, insight: r.previous > 0 ? "Recent \(String(format: "%.0f", r.recent))% vs previous \(String(format: "%.0f", r.previous))%" : "Baseline: \(String(format: "%.0f", r.recent))%")
            }
        }
    }
}

// MARK: - Supporting Types

enum InsightTrend {
    case improving, stable, declining

    var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        }
    }

    var color: Color {
        switch self {
        case .improving: return .green
        case .stable: return .blue
        case .declining: return .orange
        }
    }
}

enum PatternType {
    case strength, observation, attention
}

// MARK: - Supporting Views

struct MovementPatternRow: View {
    let domain: String
    let value: String
    let trend: InsightTrend
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(domain)
                .font(.caption)

            Spacer()

            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Image(systemName: trend.icon)
                .font(.caption2)
                .foregroundStyle(trend.color)
        }
    }
}

struct InsightBadge: View {
    let text: String
    let style: InsightStyle

    enum InsightStyle {
        case positive, neutral, attention

        var color: Color {
            switch self {
            case .positive: return .green
            case .neutral: return .blue
            case .attention: return .orange
            }
        }
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(style.color.opacity(0.15))
            .foregroundStyle(style.color)
            .clipShape(Capsule())
    }
}

struct InsightTrendRow: View {
    let icon: String
    let label: String
    let value: String
    let trend: InsightTrend
    let insight: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(value)
                    .font(.subheadline.bold().monospacedDigit())
                Image(systemName: trend.icon)
                    .foregroundStyle(trend.color)
                    .font(.caption)
            }
            Text(insight)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct ConsistencyRow: View {
    let metric: String
    let variability: Double
    let sampleSize: Int
    let discipline: SessionHistoryView.DisciplineFilter

    var consistencyLabel: String {
        if variability < 5 { return "Very consistent" }
        if variability < 10 { return "Consistent" }
        if variability < 20 { return "Moderate variation" }
        return "High variation"
    }

    var consistencyColor: Color {
        if variability < 5 { return .green }
        if variability < 10 { return .blue }
        if variability < 20 { return .orange }
        return .red
    }

    var body: some View {
        HStack {
            Image(systemName: discipline.icon)
                .font(.caption)
                .foregroundStyle(discipline.color)
                .frame(width: 20)

            Text(metric)
                .font(.caption)

            Spacer()

            Text(consistencyLabel)
                .font(.caption)
                .foregroundStyle(consistencyColor)

            Text("(\(sampleSize) sessions)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

struct PatternRow: View {
    let pattern: String
    let frequency: String
    let type: PatternType

    var icon: String {
        switch type {
        case .strength: return "checkmark.circle.fill"
        case .observation: return "info.circle.fill"
        case .attention: return "exclamationmark.circle.fill"
        }
    }

    var color: Color {
        switch type {
        case .strength: return .green
        case .observation: return .blue
        case .attention: return .orange
        }
    }

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            Text(pattern)
                .font(.caption)

            Spacer()

            Text(frequency)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct DeltaRow: View {
    let metric: String
    let delta: Double
    let unit: String
    var invertColor: Bool = false

    var isPositive: Bool {
        invertColor ? delta < 0 : delta > 0
    }

    var color: Color {
        isPositive ? .green : .orange
    }

    var arrow: String {
        delta > 0 ? "↑" : "↓"
    }

    var body: some View {
        HStack {
            Text(metric)
                .font(.caption)

            Spacer()

            Text("\(arrow) \(String(format: "%.1f", abs(delta))) \(unit)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(color)
        }
    }
}

struct TransferInsightRow: View {
    let from: String
    let to: String
    let domain: String
    let insight: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(from)
                    .font(.caption.bold())
                Image(systemName: "arrow.right")
                    .font(.caption2)
                Text(to)
                    .font(.caption.bold())
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(domain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(insight)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Shooting History Supporting Views

private struct ShootingHistoryStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppColors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct ShootingThumbnailView: View {
    let pattern: StoredTargetPattern

    @State private var thumbnailImage: UIImage?
    @State private var hasLoadedThumbnail = false

    var body: some View {
        VStack(spacing: 8) {
            if let thumbnail = thumbnailImage {
                ShootingImageWithHoleOverlay(
                    image: thumbnail,
                    normalizedShots: pattern.normalizedShots,
                    clusterMpi: CGPoint(x: pattern.clusterMpiX, y: pattern.clusterMpiY)
                )
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if !hasLoadedThumbnail {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .frame(height: 280)
                    .overlay {
                        ProgressView()
                    }
            } else {
                shootingPatternCanvas
                Text("Target photo not available on this device")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        thumbnailImage = TargetThumbnailService.shared.loadThumbnail(forPatternId: pattern.id)
        hasLoadedThumbnail = true
    }

    private var shootingPatternCanvas: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxRadius = min(size.width, size.height) / 2 - 20

            // Background
            let bgCircle = Path(ellipseIn: CGRect(
                x: center.x - maxRadius,
                y: center.y - maxRadius,
                width: maxRadius * 2,
                height: maxRadius * 2
            ))
            context.fill(bgCircle, with: .color(Color(.systemGray5)))

            // Concentric rings
            for i in 1...5 {
                let radius = maxRadius * CGFloat(i) / 5
                let circle = Path(ellipseIn: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
                context.stroke(circle, with: .color(.gray.opacity(0.5)), lineWidth: 1)
            }

            // Crosshair
            var hLine = Path()
            hLine.move(to: CGPoint(x: center.x - 10, y: center.y))
            hLine.addLine(to: CGPoint(x: center.x + 10, y: center.y))
            context.stroke(hLine, with: .color(.gray), lineWidth: 1)

            var vLine = Path()
            vLine.move(to: CGPoint(x: center.x, y: center.y - 10))
            vLine.addLine(to: CGPoint(x: center.x, y: center.y + 10))
            context.stroke(vLine, with: .color(.gray), lineWidth: 1)

            // Shot holes
            for shot in pattern.normalizedShots {
                let x = center.x + shot.x * maxRadius
                let y = center.y + shot.y * maxRadius

                let outerCircle = Path(ellipseIn: CGRect(x: x - 7, y: y - 7, width: 14, height: 14))
                context.stroke(outerCircle, with: .color(.white), lineWidth: 2)

                let innerCircle = Path(ellipseIn: CGRect(x: x - 5, y: y - 5, width: 10, height: 10))
                context.fill(innerCircle, with: .color(.red))
            }

            // MPI marker
            let mpiX = center.x + pattern.clusterMpiX * maxRadius
            let mpiY = center.y + pattern.clusterMpiY * maxRadius

            let mpiOuter = Path(ellipseIn: CGRect(x: mpiX - 10, y: mpiY - 10, width: 20, height: 20))
            context.stroke(mpiOuter, with: .color(.yellow), lineWidth: 2)

            let mpiCenter = Path(ellipseIn: CGRect(x: mpiX - 4, y: mpiY - 4, width: 8, height: 8))
            context.fill(mpiCenter, with: .color(.yellow))
        }
        .frame(height: 280)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

private struct ShootingImageWithHoleOverlay: View {
    let image: UIImage
    let normalizedShots: [CGPoint]
    let clusterMpi: CGPoint

    private func calculateLayout(frameSize: CGSize) -> (displaySize: CGSize, offset: CGSize) {
        let imageSize = image.size
        let imageAspect = imageSize.width / imageSize.height
        let frameAspect = frameSize.width / frameSize.height

        if imageAspect > frameAspect {
            let width = frameSize.width
            let height = width / imageAspect
            return (CGSize(width: width, height: height), CGSize(width: 0, height: (frameSize.height - height) / 2))
        } else {
            let height = frameSize.height
            let width = height * imageAspect
            return (CGSize(width: width, height: height), CGSize(width: (frameSize.width - width) / 2, height: 0))
        }
    }

    private func denormalizedPosition(_ normalized: CGPoint, displaySize: CGSize) -> CGPoint {
        let centerX = displaySize.width / 2
        let centerY = displaySize.height / 2
        let maxRadius = min(displaySize.width, displaySize.height) / 2
        return CGPoint(
            x: centerX + (normalized.x * maxRadius),
            y: centerY + (normalized.y * maxRadius)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = calculateLayout(frameSize: geometry.size)

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: layout.displaySize.width, height: layout.displaySize.height)

                ForEach(Array(normalizedShots.enumerated()), id: \.offset) { _, normalizedPoint in
                    let pos = denormalizedPosition(normalizedPoint, displaySize: layout.displaySize)
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .shadow(color: .black.opacity(0.5), radius: 1)
                        .position(x: pos.x, y: pos.y)
                }

                let mpiPos = denormalizedPosition(clusterMpi, displaySize: layout.displaySize)
                Circle()
                    .stroke(Color.yellow, lineWidth: 2)
                    .frame(width: 16, height: 16)
                    .position(x: mpiPos.x, y: mpiPos.y)

                Circle()
                    .fill(Color.yellow)
                    .frame(width: 6, height: 6)
                    .position(x: mpiPos.x, y: mpiPos.y)
            }
            .frame(width: layout.displaySize.width, height: layout.displaySize.height)
            .offset(x: layout.offset.width, y: layout.offset.height)
        }
    }
}

private struct ShootingDayGroup: View {
    let date: Date
    let patterns: [StoredTargetPattern]
    let onSelectPattern: (StoredTargetPattern) -> Void

    private var dateHeader: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "EEEE, MMMM d"
            return formatter.string(from: date)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dateHeader)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(patterns.count) target\(patterns.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if patterns.count == 1 {
                ShootingSessionCard(pattern: patterns[0], onTap: { onSelectPattern(patterns[0]) })
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(patterns) { pattern in
                            ShootingSessionCard(pattern: pattern, onTap: { onSelectPattern(pattern) })
                        }
                    }
                }
            }
        }
    }
}

private struct ShootingSessionCard: View {
    let pattern: StoredTargetPattern
    let onTap: () -> Void

    @State private var thumbnailImage: UIImage?

    private var sessionTypeColor: Color {
        switch pattern.sessionType.color {
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        default: return .gray
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    if let thumbnail = thumbnailImage {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(AppColors.elevatedSurface)
                            .frame(width: 120, height: 120)
                            .overlay {
                                Image(systemName: "target")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                            }
                    }

                    VStack {
                        HStack {
                            Spacer()
                            Circle()
                                .fill(sessionTypeColor)
                                .frame(width: 10, height: 10)
                                .padding(6)
                        }
                        Spacer()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(pattern.timestamp, format: .dateTime.hour().minute())
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        Text("\(pattern.shotCount) shots")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 120, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            thumbnailImage = TargetThumbnailService.shared.loadThumbnail(forPatternId: pattern.id)
        }
    }
}

private struct ShootingPatternDetailView: View {
    let pattern: StoredTargetPattern

    @Environment(\.dismiss) private var dismiss
    @State private var thumbnailImage: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text(pattern.timestamp, format: .dateTime.weekday().month().day().year())
                            .font(.headline)
                        Text(pattern.sessionType.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()

                    if let thumbnail = thumbnailImage {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                    }

                    HStack(spacing: 20) {
                        VStack {
                            Text("\(pattern.shotCount)")
                                .font(.title2.bold())
                            Text("Shots")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()
                            .frame(height: 40)

                        VStack {
                            Text(String(format: "%.2f", pattern.clusterRadius))
                                .font(.title2.bold())
                            Text("Spread")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()
                            .frame(height: 40)

                        VStack {
                            Text("\(pattern.outlierCount)")
                                .font(.title2.bold())
                            Text("Outliers")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .navigationTitle("Session Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                thumbnailImage = TargetThumbnailService.shared.loadThumbnail(forPatternId: pattern.id)
            }
        }
    }
}

// MARK: - Legacy Type Alias for Compatibility

typealias TrainingHistoryView = SessionHistoryView
typealias TrainingHistoryItem = SessionHistoryItem
typealias TrainingHistoryRow = SessionHistoryRow

// MARK: - Preview

#Preview {
    NavigationStack {
        SessionHistoryView()
    }
    .modelContainer(for: [Ride.self, RunningSession.self, SwimmingSession.self, ShootingSession.self], inMemory: true)
}
