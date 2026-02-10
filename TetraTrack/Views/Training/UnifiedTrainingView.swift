//
//  UnifiedTrainingView.swift
//  TetraTrack
//
//  Unified training view for all disciplines organized by movement patterns
//

import SwiftUI
import SwiftData

struct UnifiedTrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UnifiedDrillSession.startDate, order: .reverse) private var drillSessions: [UnifiedDrillSession]

    @State private var selectedDiscipline: Discipline
    @State private var selectedDrill: UnifiedDrillType?
    @State private var showCoaching = false
    @State private var showDrillHistory = false
    @State private var showTrainingWeek = false
    @State private var showCompetitionSimulation = false
    @State private var showChallenges = false

    init(initialDiscipline: Discipline = .all) {
        _selectedDiscipline = State(initialValue: initialDiscipline)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Discipline Filter
                    disciplinePicker

                    // Streak Banner
                    UnifiedStreakBanner(sessions: drillSessions)

                    // Special Training Modes
                    specialTrainingSection

                    // Drill Categories (Cross-discipline insights now in Coaching view)
                    ForEach(categoriesForDiscipline) { category in
                        let drills = UnifiedDrillType.drills(for: selectedDiscipline, in: category)
                        if !drills.isEmpty {
                            DrillCategorySection(
                                category: category,
                                drills: drills,
                                sessions: drillSessions,
                                onDrillSelected: { drill in
                                    selectedDrill = drill
                                }
                            )
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Skills")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showTrainingWeek = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCoaching = true
                    } label: {
                        Image(systemName: "brain.head.profile")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showDrillHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }
            .fullScreenCover(item: $selectedDrill) { drill in
                DrillViewFactory.view(for: drill, modelContext: modelContext)
            }
            .sheet(isPresented: $showCoaching) {
                NavigationStack {
                    UnifiedCoachingDashboardView()
                }
            }
            .sheet(isPresented: $showDrillHistory) {
                NavigationStack {
                    UnifiedDrillHistoryView()
                }
            }
            .sheet(isPresented: $showTrainingWeek) {
                NavigationStack {
                    TrainingWeekView()
                }
            }
            .sheet(isPresented: $showCompetitionSimulation) {
                CompetitionSimulationView()
            }
            .sheet(isPresented: $showChallenges) {
                CrossDisciplineChallengeView()
            }
            .presentationBackground(Color.black)
        }
    }

    // MARK: - Special Training Section

    private var specialTrainingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Modes")
                .font(.headline)
                .padding(.horizontal, 4)

            HStack(spacing: 12) {
                // Competition Simulation
                Button {
                    showCompetitionSimulation = true
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.yellow.opacity(0.2))
                                .frame(width: 50, height: 50)
                            Image(systemName: "flag.checkered")
                                .font(.title2)
                                .foregroundStyle(.yellow)
                        }
                        Text("Competition\nSimulation")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                // Cross-Discipline Challenges
                Button {
                    showChallenges = true
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.2))
                                .frame(width: 50, height: 50)
                            Image(systemName: "trophy.fill")
                                .font(.title2)
                                .foregroundStyle(.purple)
                        }
                        Text("Cross-Discipline\nChallenges")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Discipline Picker

    private var disciplinePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Discipline.allCases) { discipline in
                    DisciplineChip(
                        discipline: discipline,
                        isSelected: selectedDiscipline == discipline,
                        onTap: { selectedDiscipline = discipline }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Categories for Selected Discipline

    private var categoriesForDiscipline: [MovementCategory] {
        if selectedDiscipline == .all {
            return MovementCategory.allCases
        }

        // Filter to categories that have drills for this discipline
        return MovementCategory.allCases.filter { category in
            !UnifiedDrillType.drills(for: selectedDiscipline, in: category).isEmpty
        }
    }
}

// MARK: - Discipline Chip

private struct DisciplineChip: View {
    let discipline: Discipline
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: discipline.icon)
                    .font(.caption)
                Text(discipline.displayName)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? discipline.color : AppColors.elevatedSurface)
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Drill Category Section

struct DrillCategorySection: View {
    let category: MovementCategory
    let drills: [UnifiedDrillType]
    let sessions: [UnifiedDrillSession]
    let onDrillSelected: (UnifiedDrillType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category Header
            HStack {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundStyle(category.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.displayName)
                        .font(.headline)
                    Text(category.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Text("\(drills.count)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(category.color)
            }

            Divider()

            // Drill Cards
            VStack(spacing: 0) {
                ForEach(Array(drills.enumerated()), id: \.element.id) { index, drill in
                    DrillCard(
                        drill: drill,
                        sessions: sessions.filter { $0.drillType == drill },
                        onTap: { onDrillSelected(drill) }
                    )

                    // Add divider between cards (not after the last one)
                    if index < drills.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Drill Card

private struct DrillCard: View {
    let drill: UnifiedDrillType
    let sessions: [UnifiedDrillSession]
    let onTap: () -> Void

    private var averageScore: Double? {
        guard !sessions.isEmpty else { return nil }
        return sessions.map(\.score).reduce(0, +) / Double(sessions.count)
    }

    private var subtitle: String {
        if let avg = averageScore {
            return "\(sessions.count) sessions · \(Int(avg))% avg"
        } else {
            return drill.primaryCategory.displayName
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(drill.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Discipline Badges

private struct DisciplineBadges: View {
    let disciplines: Set<Discipline>
    let primaryDiscipline: Discipline

    var body: some View {
        HStack(spacing: 2) {
            // Always show primary discipline first
            Image(systemName: primaryDiscipline.icon)
                .font(.system(size: 8))
                .foregroundStyle(primaryDiscipline.color)

            // Show additional disciplines if multi-discipline
            if disciplines.count > 1 {
                ForEach(sortedAdditionalDisciplines, id: \.self) { discipline in
                    Image(systemName: discipline.icon)
                        .font(.system(size: 8))
                        .foregroundStyle(discipline.color.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(AppColors.elevatedSurface)
        .clipShape(Capsule())
    }

    /// Get additional disciplines sorted, excluding primary and .all
    private var sortedAdditionalDisciplines: [Discipline] {
        Array(disciplines)
            .filter { $0 != primaryDiscipline && $0 != .all }
            .sorted { $0.rawValue < $1.rawValue }
            .prefix(2)
            .map { $0 }
    }
}

// MARK: - Unified Coaching Dashboard (All Insights in One Place)

struct UnifiedCoachingDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UnifiedDrillSession.startDate, order: .reverse) private var sessions: [UnifiedDrillSession]
    @Query(sort: \Ride.startDate, order: .reverse) private var rides: [Ride]
    @Query(sort: \RunningSession.startDate, order: .reverse) private var runningSessions: [RunningSession]
    @Query(sort: \SwimmingSession.startDate, order: .reverse) private var swimmingSessions: [SwimmingSession]
    @Query(sort: \ShootingSession.startDate, order: .reverse) private var shootingSessions: [ShootingSession]

    @State private var coachingEngine = CoachingEngine()
    @State private var trendAnalyzer = DrillTrendAnalyzer()
    @State private var selectedDiscipline: Discipline = .all

    /// Check if any training data exists across all disciplines
    private var hasAnyTrainingData: Bool {
        !rides.isEmpty || !runningSessions.isEmpty || !swimmingSessions.isEmpty ||
        !shootingSessions.isEmpty || !sessions.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Discipline Filter for Coaching
                Picker("Focus", selection: $selectedDiscipline) {
                    ForEach(Discipline.allCases) { discipline in
                        Text(discipline.displayName).tag(discipline)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Cross-Discipline Training (when All selected)
                if selectedDiscipline == .all && !sessions.isEmpty {
                    crossDisciplineSection
                }

                // Performance Insights
                insightsSection

                // Areas to Improve
                weaknessesSection

                // Today's Workout
                todaysWorkoutSection

                // Progress by Category
                progressSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Coaching")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    // MARK: - Cross-Discipline Training

    private var crossDisciplineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .font(.title2)
                    .foregroundStyle(.purple)
                Text("Cross-Training Benefits")
                    .font(.headline)
                Spacer()
            }

            let insight = trendAnalyzer.generateCrossDisciplineInsights(sessions: sessions)
            Text(insight)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Universal drill count
            let universalDrills = sessions.filter { $0.benefitsDisciplines.count > 2 }
            if !universalDrills.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("\(universalDrills.count) sessions benefit multiple disciplines")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                Text("Insights")
                    .font(.headline)
                Spacer()
            }

            let insight = trendAnalyzer.generateInsightSummary(sessions: sessions)
            Text(insight)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let improvement = trendAnalyzer.overallImprovement(sessions: sessions) {
                HStack {
                    Image(systemName: improvement > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundStyle(improvement > 0 ? .green : .orange)
                    Text(String(format: "%.0f%% %@", abs(improvement), improvement > 0 ? "improvement" : "decline"))
                        .font(.caption.bold())
                        .foregroundStyle(improvement > 0 ? .green : .orange)
                    Text("this month")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var weaknessesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("Areas to Improve")
                    .font(.headline)
                Spacer()
            }

            let weaknesses = coachingEngine.identifyWeaknesses(
                drillHistory: sessions,
                focusDiscipline: selectedDiscipline
            ).prefix(3)

            if weaknesses.isEmpty {
                Text("No significant weaknesses detected. Keep up the good work!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(weaknesses)) { weakness in
                    UnifiedWeaknessCard(weakness: weakness)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var todaysWorkoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.run")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("Today's Workout")
                    .font(.headline)
                Spacer()
            }

            let weaknesses = coachingEngine.identifyWeaknesses(
                drillHistory: sessions,
                focusDiscipline: selectedDiscipline
            )

            let recommendations = coachingEngine.recommendDrills(
                weaknesses: weaknesses,
                recentDrills: sessions,
                focusDiscipline: selectedDiscipline
            )

            let workout = coachingEngine.generateDailyWorkout(recommendations: recommendations)

            if workout.isEmpty {
                Text("Complete some drills to get personalized recommendations")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(workout) { rec in
                    UnifiedWorkoutDrillCard(recommendation: rec)
                }

                let totalTime = workout.reduce(0) { $0 + $1.suggestedDuration }
                HStack {
                    Spacer()
                    Text("Total: \(Int(totalTime / 60)) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundStyle(.green)
                Text("Progress by Category")
                    .font(.headline)
                Spacer()
            }

            ForEach(MovementCategory.allCases) { category in
                let trend = trendAnalyzer.categoryTrend(for: category, sessions: sessions)
                UnifiedTrendRow(name: category.displayName, trend: trend, color: category.color)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Unified Weakness Card

private struct UnifiedWeaknessCard: View {
    let weakness: Weakness

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(severityColor)
                .frame(width: 4, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(weakness.area)
                        .font(.subheadline.bold())
                    Spacer()
                    Text(weakness.discipline.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(weakness.discipline.color.opacity(0.2))
                        .foregroundStyle(weakness.discipline.color)
                        .clipShape(Capsule())
                }
                Text(weakness.evidence)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private var severityColor: Color {
        if weakness.severity > 0.7 { return .red }
        if weakness.severity > 0.4 { return .orange }
        return .yellow
    }
}

// MARK: - Unified Workout Drill Card

private struct UnifiedWorkoutDrillCard: View {
    let recommendation: DrillRecommendation

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(recommendation.drillName)
                        .font(.subheadline.bold())
                    Text(recommendation.formattedDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColors.elevatedSurface)
                        .clipShape(Capsule())

                    if recommendation.isCrossTraining {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }
                }
                Text(recommendation.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: recommendation.discipline.icon)
                .foregroundStyle(recommendation.discipline.color)
        }
        .padding(.vertical, 8)
    }

    private var priorityColor: Color {
        switch recommendation.priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
}

// MARK: - Unified Trend Row

private struct UnifiedTrendRow: View {
    let name: String
    let trend: TrendDirection
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(name)
                .font(.caption)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: trendIcon)
                    .font(.caption2)
                Text(trend.description)
                    .font(.caption2)
            }
            .foregroundStyle(trendColor)
        }
    }

    private var trendIcon: String {
        switch trend {
        case .improving: return "arrow.up"
        case .declining: return "arrow.down"
        case .stable: return "minus"
        case .insufficient: return "questionmark"
        }
    }

    private var trendColor: Color {
        switch trend {
        case .improving: return .green
        case .declining: return .orange
        case .stable: return .blue
        case .insufficient: return .gray
        }
    }
}

// MARK: - Drill History View

struct UnifiedDrillHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UnifiedDrillSession.startDate, order: .reverse) private var unifiedSessions: [UnifiedDrillSession]
    @Query(sort: \RidingDrillSession.startDate, order: .reverse) private var ridingDrillSessions: [RidingDrillSession]
    @Query(sort: \ShootingDrillSession.startDate, order: .reverse) private var shootingDrillSessions: [ShootingDrillSession]

    /// Combined and sorted list of all drill sessions
    private var allDrillSessions: [DrillHistoryItem] {
        var items: [DrillHistoryItem] = []

        // Add unified sessions
        items += unifiedSessions.map { DrillHistoryItem(unifiedSession: $0) }

        // Add legacy riding drill sessions
        items += ridingDrillSessions.map { DrillHistoryItem(ridingSession: $0) }

        // Add legacy shooting drill sessions
        items += shootingDrillSessions.map { DrillHistoryItem(shootingSession: $0) }

        // Sort by date, most recent first
        return items.sorted { $0.date > $1.date }
    }

    var body: some View {
        Group {
            if allDrillSessions.isEmpty {
                ContentUnavailableView(
                    "No Drill History",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Complete some drills to see your history here")
                )
            } else {
                List {
                    ForEach(allDrillSessions) { item in
                        DrillHistoryRow(item: item)
                    }
                }
            }
        }
        .navigationTitle("Drill History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
}

/// Unified item for drill history display
private struct DrillHistoryItem: Identifiable {
    let id: UUID
    let name: String
    let date: Date
    let duration: TimeInterval
    let score: Double
    let icon: String
    let color: Color
    let category: String

    init(unifiedSession: UnifiedDrillSession) {
        self.id = unifiedSession.id
        self.name = unifiedSession.name
        self.date = unifiedSession.startDate
        self.duration = unifiedSession.duration
        self.score = unifiedSession.score
        self.icon = unifiedSession.drillType.icon
        self.color = unifiedSession.drillType.color
        self.category = unifiedSession.drillType.primaryCategory.displayName
    }

    init(ridingSession: RidingDrillSession) {
        self.id = ridingSession.id
        self.name = ridingSession.name
        self.date = ridingSession.startDate
        self.duration = ridingSession.duration
        self.score = ridingSession.score
        self.icon = "figure.equestrian.sports"
        self.color = .brown
        self.category = "Riding"
    }

    init(shootingSession: ShootingDrillSession) {
        self.id = shootingSession.id
        self.name = shootingSession.name
        self.date = shootingSession.startDate
        self.duration = shootingSession.duration
        self.score = shootingSession.score
        self.icon = "target"
        self.color = .red
        self.category = "Shooting"
    }

    var formattedScore: String {
        "\(Int(score))%"
    }

    var formattedDuration: String {
        duration.formattedDuration
    }
}

/// Row view for drill history items
private struct DrillHistoryRow: View {
    let item: DrillHistoryItem

    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(item.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: item.icon)
                    .foregroundStyle(item.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 8) {
                    Text(item.category)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(item.color.opacity(0.15))
                        .foregroundStyle(item.color)
                        .clipShape(Capsule())
                    Text(item.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.formattedScore)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(scoreColor(item.score))
                Text(item.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .orange }
        return .red
    }
}

// MARK: - Training Insights View (Standalone)

/// Dedicated view for Apple Intelligence tetrathlon training analysis
struct TrainingInsightsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Ride.startDate, order: .reverse) private var rides: [Ride]
    @Query(sort: \RunningSession.startDate, order: .reverse) private var runningSessions: [RunningSession]
    @Query(sort: \SwimmingSession.startDate, order: .reverse) private var swimmingSessions: [SwimmingSession]
    @Query(sort: \ShootingSession.startDate, order: .reverse) private var shootingSessions: [ShootingSession]
    @Query(sort: \UnifiedDrillSession.startDate, order: .reverse) private var drillSessions: [UnifiedDrillSession]

    @State private var isLoading = false
    @State private var insights: MultiDisciplineInsights?
    @State private var selectedDisciplineTab: DisciplineInsightTab = .overview

    enum DisciplineInsightTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case riding = "Riding"
        case running = "Running"
        case swimming = "Swimming"
        case shooting = "Shooting"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .overview: return "chart.pie"
            case .riding: return "figure.equestrian.sports"
            case .running: return "figure.run"
            case .swimming: return "figure.pool.swim"
            case .shooting: return "target"
            }
        }

        var color: Color {
            switch self {
            case .overview: return .purple
            case .riding: return TrainingDiscipline.riding.swiftUIColor
            case .running: return TrainingDiscipline.running.swiftUIColor
            case .swimming: return TrainingDiscipline.swimming.swiftUIColor
            case .shooting: return TrainingDiscipline.shooting.swiftUIColor
            }
        }
    }

    private var isAppleIntelligenceAvailable: Bool {
        if #available(iOS 26.0, *) {
            return IntelligenceService.shared.isAvailable
        }
        return false
    }

    private var hasData: Bool {
        !rides.isEmpty || !runningSessions.isEmpty || !swimmingSessions.isEmpty ||
        !shootingSessions.isEmpty || !drillSessions.isEmpty
    }

    private var totalSessions: Int {
        rides.count + runningSessions.count + swimmingSessions.count + shootingSessions.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with Apple Intelligence branding
                headerSection

                // Discipline tabs
                disciplineTabPicker

                // Content based on selected tab
                switch selectedDisciplineTab {
                case .overview:
                    overviewSection
                case .riding:
                    ridingSection
                case .running:
                    runningSection
                case .swimming:
                    swimmingSection
                case .shooting:
                    shootingSection
                }

                // AI-generated insights
                if isAppleIntelligenceAvailable {
                    aiInsightsSection
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Training Insights")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear {
            if isAppleIntelligenceAvailable && insights == nil && hasData && !isLoading {
                generateInsights()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "apple.intelligence")
                .font(.system(size: 40))
                .foregroundStyle(.purple)

            Text("Training Analysis")
                .font(.title2.bold())

            Text("Insights across all four disciplines")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Session counts row
            HStack(spacing: 16) {
                sessionCountBadge("Ride", count: rides.count, color: .brown, icon: "figure.equestrian.sports")
                sessionCountBadge("Run", count: runningSessions.count, color: .green, icon: "figure.run")
                sessionCountBadge("Swim", count: swimmingSessions.count, color: .blue, icon: "figure.pool.swim")
                sessionCountBadge("Shoot", count: shootingSessions.count, color: .red, icon: "target")
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func sessionCountBadge(_ name: String, count: Int, color: Color, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(count > 0 ? color : .gray.opacity(0.4))
            Text("\(count)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(count > 0 ? .primary : .secondary)
            Text(name)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Discipline Tabs

    private var disciplineTabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DisciplineInsightTab.allCases) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDisciplineTab = tab
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                            Text(tab.rawValue)
                        }
                        .font(.subheadline)
                        .fontWeight(selectedDisciplineTab == tab ? .semibold : .regular)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedDisciplineTab == tab ? tab.color.opacity(0.15) : Color.clear)
                        .foregroundStyle(selectedDisciplineTab == tab ? tab.color : .secondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Overview Section

    private var overviewSection: some View {
        VStack(spacing: 16) {
            // Training balance pie chart representation
            trainingBalanceCard

            // Drill sessions card
            if !drillSessions.isEmpty {
                drillSessionsCard
            }
        }
    }

    private var trainingBalanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Training Balance", systemImage: "chart.pie")
                .font(.headline)

            if totalSessions == 0 {
                Text("Start tracking sessions to see your training balance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                // Simple bar representation of balance
                VStack(spacing: 8) {
                    balanceBar("Riding", count: rides.count, color: .brown)
                    balanceBar("Running", count: runningSessions.count, color: .green)
                    balanceBar("Swimming", count: swimmingSessions.count, color: .blue)
                    balanceBar("Shooting", count: shootingSessions.count, color: .red)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func balanceBar(_ name: String, count: Int, color: Color) -> some View {
        let maxCount = max(rides.count, runningSessions.count, swimmingSessions.count, shootingSessions.count, 1)
        let percentage = Double(count) / Double(maxCount)

        return HStack {
            Text(name)
                .font(.subheadline)
                .frame(width: 70, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: max(4, geo.size.width * percentage))
                }
            }
            .frame(height: 20)

            Text("\(count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
        }
    }

    private var drillSessionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Skill Drills", systemImage: "figure.flexibility")
                .font(.headline)

            let avgScore = drillSessions.isEmpty ? 0 : drillSessions.reduce(0) { $0 + $1.score } / Double(drillSessions.count)

            HStack {
                VStack(alignment: .leading) {
                    Text("\(drillSessions.count)")
                        .font(.title.bold())
                    Text("Total Drills")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("\(Int(avgScore))%")
                        .font(.title.bold())
                        .foregroundStyle(.purple)
                    Text("Avg Score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Drills build foundational skills that transfer across all disciplines")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Discipline Sections

    private var ridingSection: some View {
        disciplineDetailSection(
            title: "Riding Analysis",
            icon: "figure.equestrian.sports",
            color: .brown,
            sessionCount: rides.count,
            stats: ridingStats,
            emptyMessage: "Track riding sessions to see detailed insights"
        )
    }

    private var ridingStats: [(String, String)] {
        guard !rides.isEmpty else { return [] }
        let totalDistance = rides.reduce(0) { $0 + $1.totalDistance }
        let totalDuration = rides.reduce(0) { $0 + $1.totalDuration }
        let avgBalance = rides.reduce(0) { $0 + $1.turnBalancePercent } / rides.count

        return [
            ("Total Distance", String(format: "%.1f km", totalDistance / 1000)),
            ("Total Time", totalDuration.formattedDuration),
            ("Turn Balance", "\(avgBalance)% L/R"),
            ("Sessions", "\(rides.count)")
        ]
    }

    private var runningSection: some View {
        disciplineDetailSection(
            title: "Running Analysis",
            icon: "figure.run",
            color: .green,
            sessionCount: runningSessions.count,
            stats: runningStats,
            emptyMessage: "Track running sessions to see pace and cadence insights"
        )
    }

    private var runningStats: [(String, String)] {
        guard !runningSessions.isEmpty else { return [] }
        let totalDistance = runningSessions.reduce(0) { $0 + $1.totalDistance }
        let avgPace = runningSessions.reduce(0) { $0 + $1.averagePace } / Double(runningSessions.count)
        let avgCadence = runningSessions.reduce(0) { $0 + $1.averageCadence } / runningSessions.count

        return [
            ("Total Distance", String(format: "%.1f km", totalDistance / 1000)),
            ("Avg Pace", avgPace.formattedPace + " /km"),
            ("Avg Cadence", "\(avgCadence) spm"),
            ("Sessions", "\(runningSessions.count)")
        ]
    }

    private var swimmingSection: some View {
        disciplineDetailSection(
            title: "Swimming Analysis",
            icon: "figure.pool.swim",
            color: .blue,
            sessionCount: swimmingSessions.count,
            stats: swimmingStats,
            emptyMessage: "Track swimming sessions to see SWOLF and efficiency insights"
        )
    }

    private var swimmingStats: [(String, String)] {
        guard !swimmingSessions.isEmpty else { return [] }
        let totalDistance = swimmingSessions.reduce(0) { $0 + $1.totalDistance }
        let avgSwolf = swimmingSessions.reduce(0) { $0 + $1.averageSwolf } / Double(swimmingSessions.count)
        let totalLaps = swimmingSessions.reduce(0) { $0 + $1.lapCount }

        return [
            ("Total Distance", String(format: "%.0f m", totalDistance)),
            ("Avg SWOLF", String(format: "%.1f", avgSwolf)),
            ("Total Laps", "\(totalLaps)"),
            ("Sessions", "\(swimmingSessions.count)")
        ]
    }

    private var shootingSection: some View {
        disciplineDetailSection(
            title: "Shooting Analysis",
            icon: "target",
            color: .red,
            sessionCount: shootingSessions.count,
            stats: shootingStats,
            emptyMessage: "Track shooting sessions to see accuracy insights"
        )
    }

    private var shootingStats: [(String, String)] {
        guard !shootingSessions.isEmpty else { return [] }
        let avgScore = shootingSessions.reduce(0) { $0 + $1.scorePercentage } / Double(shootingSessions.count)
        let avgPerArrow = shootingSessions.reduce(0) { $0 + $1.averageScorePerArrow } / Double(shootingSessions.count)
        let totalXs = shootingSessions.reduce(0) { $0 + $1.xCount }

        return [
            ("Avg Score", String(format: "%.1f%%", avgScore)),
            ("Avg/Arrow", String(format: "%.2f", avgPerArrow)),
            ("Total X's", "\(totalXs)"),
            ("Sessions", "\(shootingSessions.count)")
        ]
    }

    private func disciplineDetailSection(
        title: String,
        icon: String,
        color: Color,
        sessionCount: Int,
        stats: [(String, String)],
        emptyMessage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(sessionCount) sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if stats.isEmpty {
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(stats, id: \.0) { stat in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stat.1)
                                .font(.title3.bold())
                            Text(stat.0)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(color.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - AI Insights Section

    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("AI Analysis")
                    .font(.headline)
                Spacer()

                if !isLoading {
                    Button {
                        generateInsights()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline)
                    }
                    .disabled(!hasData)
                }
            }

            if isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Analyzing your training...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else if let insights = insights {
                VStack(alignment: .leading, spacing: 10) {
                    // Trend
                    HStack {
                        Image(systemName: trendIcon(for: insights.trend))
                        Text(insights.trend.capitalized)
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(trendColor(for: insights.trend).opacity(0.15))
                    .foregroundStyle(trendColor(for: insights.trend))
                    .clipShape(Capsule())

                    Text(insights.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Divider()

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        VStack(alignment: .leading) {
                            Text("Strongest")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(insights.strongestDiscipline)
                                .font(.subheadline.bold())
                        }

                        Spacer()

                        Image(systemName: "target")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading) {
                            Text("Focus Area")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(insights.weakestDiscipline)
                                .font(.subheadline.bold())
                        }
                    }

                    if !insights.keyInsight.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.yellow)
                            Text(insights.keyInsight)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
            } else if hasData {
                Button {
                    generateInsights()
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Generate AI Analysis")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.purple)
            } else {
                Text("Add training sessions to enable AI analysis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func trendIcon(for trend: String) -> String {
        switch trend.lowercased() {
        case "improving": return "arrow.up.right"
        case "maintaining": return "arrow.right"
        case "declining": return "arrow.down.right"
        default: return "minus"
        }
    }

    private func trendColor(for trend: String) -> Color {
        switch trend.lowercased() {
        case "improving": return .green
        case "maintaining": return .blue
        case "declining": return .orange
        default: return .gray
        }
    }

    private func generateInsights() {
        guard hasData else { return }
        isLoading = true

        Task {
            if #available(iOS 26.0, *) {
                let service = IntelligenceService.shared
                if service.isAvailable {
                    do {
                        let result = try await service.analyzeMultiDisciplineTraining(
                            rides: rides,
                            runningSessions: runningSessions,
                            swimmingSessions: swimmingSessions,
                            shootingSessions: shootingSessions,
                            drillSessions: drillSessions
                        )
                        await MainActor.run {
                            self.insights = result
                            self.isLoading = false
                        }
                        return
                    } catch {
                        // Fall through to sample
                    }
                }
            }
            await MainActor.run {
                self.insights = generateSampleInsights()
                self.isLoading = false
            }
        }
    }

    private func generateSampleInsights() -> MultiDisciplineInsights {
        let disciplineCounts: [(String, Int)] = [
            ("Riding", rides.count),
            ("Running", runningSessions.count),
            ("Swimming", swimmingSessions.count),
            ("Shooting", shootingSessions.count)
        ]

        let strongest = disciplineCounts.max(by: { $0.1 < $1.1 })?.0 ?? "Riding"
        let weakest = disciplineCounts.filter { $0.1 > 0 }.min(by: { $0.1 < $1.1 })?.0 ??
                      disciplineCounts.filter { $0.1 == 0 }.first?.0 ?? "Swimming"

        let trend = totalSessions >= 5 ? "improving" : "maintaining"

        let summary: String
        if totalSessions == 0 {
            summary = "Start tracking your tetrathlon training to get personalized insights."
        } else if totalSessions < 5 {
            summary = "Building your training history. Keep training across all disciplines."
        } else {
            summary = "You've completed \(totalSessions) sessions with good discipline variety."
        }

        let keyInsight: String
        if !drillSessions.isEmpty {
            keyInsight = "Your \(drillSessions.count) drill sessions build skills that transfer across all disciplines."
        } else {
            keyInsight = "Consider adding skill drills to accelerate your progress in all disciplines."
        }

        return MultiDisciplineInsights(
            trend: trend,
            summary: summary,
            strongestDiscipline: strongest,
            weakestDiscipline: weakest,
            balanceAssessment: "Review balance above",
            crossTrainingOpportunities: [],
            recommendations: [],
            keyInsight: keyInsight,
            encouragement: "Keep training!"
        )
    }
}

// MARK: - AI Insights Card (Multi-Discipline)

/// Apple Intelligence insights card for comprehensive tetrathlon training analysis
private struct AIInsightsCard: View {
    let rides: [Ride]
    let runningSessions: [RunningSession]
    let swimmingSessions: [SwimmingSession]
    let shootingSessions: [ShootingSession]
    let drillSessions: [UnifiedDrillSession]

    @State private var isLoading = false
    @State private var insights: MultiDisciplineInsights?

    /// Check if Apple Intelligence is available
    private var isAppleIntelligenceAvailable: Bool {
        if #available(iOS 26.0, *) {
            return IntelligenceService.shared.isAvailable
        }
        return false
    }

    /// Check if any training data is available
    private var hasData: Bool {
        !rides.isEmpty || !runningSessions.isEmpty || !swimmingSessions.isEmpty ||
        !shootingSessions.isEmpty || !drillSessions.isEmpty
    }

    /// Count total sessions across all disciplines
    private var totalSessions: Int {
        rides.count + runningSessions.count + swimmingSessions.count + shootingSessions.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "apple.intelligence")
                    .font(.title2)
                    .foregroundStyle(.purple)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Intelligence")
                        .font(.headline)
                    Text("Training Analysis")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if isAppleIntelligenceAvailable && !isLoading {
                    Button {
                        generateInsights()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline)
                    }
                    .disabled(!hasData)
                }
            }

            // Skill category summary
            skillCategorySummary

            if !isAppleIntelligenceAvailable {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("Requires iPhone 15 Pro or later with iOS 26")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Analyzing all disciplines...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            } else if let insights = insights {
                insightsContent(insights)
            } else {
                Button {
                    generateInsights()
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Analyze All Disciplines")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.purple)
                .disabled(!hasData)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            if isAppleIntelligenceAvailable && insights == nil && hasData && !isLoading {
                generateInsights()
            }
        }
    }

    /// Count drills by skill category
    private var skillCategoryCounts: [MovementCategory: Int] {
        var counts: [MovementCategory: Int] = [:]
        for session in drillSessions {
            let category = session.drillType.primaryCategory
            counts[category, default: 0] += 1
        }
        return counts
    }

    /// Mini icons showing activity in each skill category
    private var skillCategorySummary: some View {
        let counts = skillCategoryCounts
        let categories: [MovementCategory] = [.stability, .balance, .mobility, .breathing, .rhythm]

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    skillCategoryIcon(category, count: counts[category] ?? 0)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func skillCategoryIcon(_ category: MovementCategory, count: Int) -> some View {
        VStack(spacing: 2) {
            Image(systemName: category.icon)
                .font(.caption)
                .foregroundStyle(count > 0 ? category.color : .gray.opacity(0.4))
            Text("\(count)")
                .font(.caption2)
                .foregroundStyle(count > 0 ? .primary : .secondary)
            Text(category.displayName)
                .scaledFont(size: 8, relativeTo: .caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 50)
    }

    @ViewBuilder
    private func insightsContent(_ insights: MultiDisciplineInsights) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Trend badge
            HStack {
                Image(systemName: trendIcon(for: insights.trend))
                Text(insights.trend.capitalized)
            }
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(trendColor(for: insights.trend).opacity(0.15))
            .foregroundStyle(trendColor(for: insights.trend))
            .clipShape(Capsule())

            // Summary
            Text(insights.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            // Strongest discipline
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                Text("Strongest: \(insights.strongestDiscipline)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Weakest / focus area
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "target")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("Focus on: \(insights.weakestDiscipline)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Key insight
            if !insights.keyInsight.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text(insights.keyInsight)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }

    private func trendIcon(for trend: String) -> String {
        switch trend.lowercased() {
        case "improving": return "arrow.up.right"
        case "maintaining": return "arrow.right"
        case "declining": return "arrow.down.right"
        default: return "minus"
        }
    }

    private func trendColor(for trend: String) -> Color {
        switch trend.lowercased() {
        case "improving": return .green
        case "maintaining": return .blue
        case "declining": return .orange
        default: return .gray
        }
    }

    private func generateInsights() {
        guard hasData else { return }
        isLoading = true

        Task {
            if #available(iOS 26.0, *) {
                let service = IntelligenceService.shared
                if service.isAvailable {
                    do {
                        let result = try await service.analyzeMultiDisciplineTraining(
                            rides: rides,
                            runningSessions: runningSessions,
                            swimmingSessions: swimmingSessions,
                            shootingSessions: shootingSessions,
                            drillSessions: drillSessions
                        )
                        await MainActor.run {
                            self.insights = result
                            self.isLoading = false
                        }
                        return
                    } catch {
                        // Fall through to sample
                    }
                }
            }
            await MainActor.run {
                self.insights = generateSampleInsights()
                self.isLoading = false
            }
        }
    }

    private func generateSampleInsights() -> MultiDisciplineInsights {
        // Determine strongest/weakest based on session counts
        let disciplineCounts: [(String, Int)] = [
            ("Riding", rides.count),
            ("Running", runningSessions.count),
            ("Swimming", swimmingSessions.count),
            ("Shooting", shootingSessions.count)
        ]

        let strongest = disciplineCounts.max(by: { $0.1 < $1.1 })?.0 ?? "Riding"
        let weakest = disciplineCounts.filter { $0.1 > 0 }.min(by: { $0.1 < $1.1 })?.0 ??
                      disciplineCounts.filter { $0.1 == 0 }.first?.0 ?? "Swimming"

        let trend = totalSessions >= 5 ? "improving" : "maintaining"

        let summary: String
        if totalSessions == 0 {
            summary = "Start tracking your tetrathlon training to get personalized insights."
        } else if totalSessions < 5 {
            summary = "Building your training history. Keep training across all disciplines for better insights."
        } else {
            summary = "You've completed \(totalSessions) sessions. Your training shows good discipline variety."
        }

        var recommendations: [String] = []
        if rides.isEmpty { recommendations.append("Add riding sessions to complete your tetrathlon training") }
        if runningSessions.isEmpty { recommendations.append("Running sessions will improve your 1500m performance") }
        if swimmingSessions.isEmpty { recommendations.append("Swimming practice needed for competition readiness") }
        if shootingSessions.isEmpty { recommendations.append("Shooting practice is key for consistent scoring") }

        let balanceAssessment: String
        let activeDisciplines = disciplineCounts.filter { $0.1 > 0 }.count
        if activeDisciplines == 4 {
            balanceAssessment = "Excellent discipline coverage"
        } else if activeDisciplines >= 2 {
            balanceAssessment = "Good start, add more disciplines"
        } else {
            balanceAssessment = "Focus on training variety"
        }

        let keyInsight: String
        if !drillSessions.isEmpty {
            keyInsight = "Your \(drillSessions.count) drill sessions build skills that transfer across all disciplines."
        } else if strongest == weakest {
            keyInsight = "Even training distribution - consider adding more variety."
        } else {
            keyInsight = "Your \(strongest.lowercased()) strength can support \(weakest.lowercased()) improvement through skill transfer."
        }

        return MultiDisciplineInsights(
            trend: trend,
            summary: summary,
            strongestDiscipline: strongest,
            weakestDiscipline: weakest,
            balanceAssessment: balanceAssessment,
            crossTrainingOpportunities: ["Balance drills benefit riding and shooting", "Running cadence transfers to swimming rhythm"],
            recommendations: recommendations.isEmpty ? ["Maintain current training balance"] : recommendations,
            keyInsight: keyInsight,
            encouragement: "Keep training across all four disciplines!"
        )
    }
}

#Preview {
    UnifiedTrainingView()
        .modelContainer(for: [UnifiedDrillSession.self, Ride.self], inMemory: true)
}
