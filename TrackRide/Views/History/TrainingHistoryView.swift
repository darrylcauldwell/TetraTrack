//
//  TrainingHistoryView.swift
//  TrackRide
//
//  Session History view with integrated cross-session insights
//

import SwiftUI
import SwiftData
import WidgetKit

// MARK: - Session History View

struct SessionHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Ride.startDate, order: .reverse) private var rides: [Ride]
    @Query(sort: \RunningSession.startDate, order: .reverse) private var runningSessions: [RunningSession]
    @Query(sort: \SwimmingSession.startDate, order: .reverse) private var swimmingSessions: [SwimmingSession]
    @Query(sort: \ShootingSession.startDate, order: .reverse) private var shootingSessions: [ShootingSession]

    @State private var selectedDiscipline: DisciplineFilter = .all
    @State private var selectedTab: HistoryTab = .sessions

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
            case .riding: return .green
            case .running: return .orange
            case .swimming: return .blue
            case .shooting: return .red
            }
        }
    }

    private var allSessions: [SessionHistoryItem] {
        var items: [SessionHistoryItem] = []

        if selectedDiscipline == .all || selectedDiscipline == .riding {
            items += rides.map { SessionHistoryItem(ride: $0) }
        }
        if selectedDiscipline == .all || selectedDiscipline == .running {
            items += runningSessions.map { SessionHistoryItem(runningSession: $0) }
        }
        if selectedDiscipline == .all || selectedDiscipline == .swimming {
            items += swimmingSessions.map { SessionHistoryItem(swimmingSession: $0) }
        }
        if selectedDiscipline == .all || selectedDiscipline == .shooting {
            items += shootingSessions.map { SessionHistoryItem(shootingSession: $0) }
        }

        return items.sorted { $0.date > $1.date }
    }

    var body: some View {
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
        .navigationTitle("Session History")
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
        WidgetDataSyncService.shared.syncRecentSessions(context: modelContext)
    }
}

// MARK: - Session History Item

struct SessionHistoryItem: Identifiable {
    let id: UUID
    let discipline: SessionHistoryView.DisciplineFilter
    let date: Date
    let name: String
    let duration: TimeInterval
    let primaryMetric: String
    let secondaryMetric: String?

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

// MARK: - Session History Row

struct SessionHistoryRow: View {
    let item: SessionHistoryItem

    var body: some View {
        HStack(spacing: 12) {
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

// MARK: - Session Insights View

struct SessionInsightsView: View {
    let rides: [Ride]
    let runningSessions: [RunningSession]
    let swimmingSessions: [SwimmingSession]
    let shootingSessions: [ShootingSession]

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
            case .riding: return .green
            case .running: return .orange
            case .swimming: return .blue
            case .shooting: return .red
            }
        }
    }

    // MARK: - Computed Properties

    private var totalSessions: Int {
        rides.count + runningSessions.count + swimmingSessions.count + shootingSessions.count
    }

    private var hasData: Bool {
        totalSessions > 0
    }

    private var recentWindowDays: Int { 14 }

    private var recentRides: [Ride] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -recentWindowDays, to: Date()) ?? Date()
        return rides.filter { $0.startDate >= cutoff }
    }

    private var recentRuns: [RunningSession] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -recentWindowDays, to: Date()) ?? Date()
        return runningSessions.filter { $0.startDate >= cutoff }
    }

    private var recentSwims: [SwimmingSession] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -recentWindowDays, to: Date()) ?? Date()
        return swimmingSessions.filter { $0.startDate >= cutoff }
    }

    private var recentShoots: [ShootingSession] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -recentWindowDays, to: Date()) ?? Date()
        return shootingSessions.filter { $0.startDate >= cutoff }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !hasData {
                    emptyStateView
                } else {
                    // Unified Overview Layer (always visible at top)
                    unifiedOverviewSection

                    // Discipline Lens Selector
                    disciplineLensSelector

                    // Aggregated Insights based on selected lens
                    if selectedLens == .unified {
                        crossDisciplineTransferSection
                        consistencyVariabilitySection
                    } else {
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
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var sessionDistributionRow: some View {
        HStack(spacing: 12) {
            sessionCountPill("Ride", count: rides.count, recent: recentRides.count, color: .green, icon: "figure.equestrian.sports")
            sessionCountPill("Run", count: runningSessions.count, recent: recentRuns.count, color: .orange, icon: "figure.run")
            sessionCountPill("Swim", count: swimmingSessions.count, recent: recentSwims.count, color: .blue, icon: "figure.pool.swim")
            sessionCountPill("Shoot", count: shootingSessions.count, recent: recentShoots.count, color: .red, icon: "target")
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
        let recentTotal = recentRides.count + recentRuns.count + recentSwims.count + recentShoots.count
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

                // Discipline balance assessment
                let disciplineCount = [recentRides.count > 0, recentRuns.count > 0, recentSwims.count > 0, recentShoots.count > 0].filter { $0 }.count

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
                    let avgStability = rides.reduce(0) { $0 + $1.averageRiderStability } / Double(rides.count)
                    let avgSymmetry = rides.reduce(0) { $0 + $1.overallSymmetry } / Double(rides.count)

                    if avgStability > 0 || avgSymmetry > 0 {
                        MovementPatternRow(
                            domain: "Stability & Balance",
                            value: avgStability > 0 ? String(format: "%.0f%%", avgStability) : "--",
                            trend: stabilityTrend,
                            icon: "figure.stand"
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

                    if rides.first(where: { $0.averageRiderStability > 0 }) != nil {
                        let stabilities = rides.prefix(10).compactMap { $0.averageRiderStability > 0 ? $0.averageRiderStability : nil }
                        if stabilities.count >= 3 {
                            let stabilityCV = coefficientOfVariation(stabilities)
                            ConsistencyRow(
                                metric: "Rider Stability",
                                variability: stabilityCV,
                                sampleSize: stabilities.count,
                                discipline: .riding
                            )
                        }
                    }
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
        .background(Color(.secondarySystemBackground))
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
        .background(Color(.secondarySystemBackground))
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

            // Stability patterns
            let lowStabilityCount = ridesForAnalysis.filter { $0.averageRiderStability > 0 && $0.averageRiderStability < 70 }.count
            let highStabilityCount = ridesForAnalysis.filter { $0.averageRiderStability >= 80 }.count

            if lowStabilityCount >= 3 {
                PatternRow(
                    pattern: "Stability below 70%",
                    frequency: "\(lowStabilityCount) of \(recentRideCount)",
                    type: .attention
                )
            }
            if highStabilityCount >= 5 {
                PatternRow(
                    pattern: "Stability above 80%",
                    frequency: "\(highStabilityCount) of \(recentRideCount)",
                    type: .strength
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

            if leftBiasCount < 3 && rightBiasCount < 3 && lowStabilityCount < 3 && highStabilityCount < 5 && asymmetricCount < 3 {
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

                    // Stability trend
                    let recentStabilities = recentRides.compactMap { $0.averageRiderStability > 0 ? $0.averageRiderStability : nil }
                    let olderStabilities = olderRides.compactMap { $0.averageRiderStability > 0 ? $0.averageRiderStability : nil }

                    if recentStabilities.count >= 2 && olderStabilities.count >= 2 {
                        let recentAvg = recentStabilities.reduce(0, +) / Double(recentStabilities.count)
                        let olderAvg = olderStabilities.reduce(0, +) / Double(olderStabilities.count)
                        let stabilityDelta = recentAvg - olderAvg

                        if abs(stabilityDelta) >= 3 {
                            DeltaRow(
                                metric: "Rider stability",
                                delta: stabilityDelta,
                                unit: "pts"
                            )
                        }
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
                Text("\(runningSessions.count) sessions")
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
        .background(Color(.secondarySystemBackground))
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
                Text("\(swimmingSessions.count) sessions")
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

                // Breathing patterns if available
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session Patterns")
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
        .background(Color(.secondarySystemBackground))
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
        .background(Color(.secondarySystemBackground))
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
                // Stability transfer: Riding ↔ Shooting
                if !rides.isEmpty && !shootingSessions.isEmpty {
                    let avgRiderStability = rides.compactMap { $0.averageRiderStability > 0 ? $0.averageRiderStability : nil }
                    let avgShootingScore = shootingSessions.map { $0.scorePercentage }

                    if !avgRiderStability.isEmpty && !avgShootingScore.isEmpty {
                        TransferInsightRow(
                            from: "Riding",
                            to: "Shooting",
                            domain: "Core Stability",
                            insight: "Rider stability training supports steady hold and breath control in shooting"
                        )
                    }
                }

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
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Trend Calculations

    private var stabilityTrend: InsightTrend {
        guard recentRides.count >= 2 else { return .stable }
        let recentStabilities = recentRides.compactMap { $0.averageRiderStability > 0 ? $0.averageRiderStability : nil }
        guard recentStabilities.count >= 2 else { return .stable }

        let firstHalf = recentStabilities.prefix(recentStabilities.count / 2)
        let secondHalf = recentStabilities.suffix(recentStabilities.count / 2)

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
        let sessionsWithMultipleEnds = shootingSessions.filter { $0.ends.count >= 3 }
        guard sessionsWithMultipleEnds.count >= 2 else {
            return (0, sessionsWithMultipleEnds.count)
        }

        var degradationCount = 0
        for session in sessionsWithMultipleEnds {
            let ends = session.ends.sorted(by: { $0.orderIndex < $1.orderIndex })
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
