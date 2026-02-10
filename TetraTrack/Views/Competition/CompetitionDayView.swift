//
//  CompetitionDayView.swift
//  TetraTrack
//
//  Competition day dashboard showing today's/next competition with
//  discipline cards for live data capture
//

import SwiftUI
import SwiftData

struct CompetitionDayView: View {
    @Query(sort: \Competition.date, order: .forward) private var allCompetitions: [Competition]
    @State private var selectedCompetition: Competition?
    @State private var activeDiscipline: TriathlonDiscipline?
    @State private var dayManager = CompetitionDayManager()

    /// Today's competitions or the next upcoming one
    private var relevantCompetitions: [Competition] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // First try today's competitions
        let todayComps = allCompetitions.filter {
            calendar.isDateInToday($0.date) ||
            (($0.endDate != nil) && $0.date <= Date() && $0.endDate! >= today)
        }
        if !todayComps.isEmpty { return todayComps }

        // Fall back to next upcoming (not completed)
        let upcoming = allCompetitions.filter { $0.date >= today && !$0.isCompleted }
        return Array(upcoming.prefix(3))
    }

    /// Filter to tetrathlon/triathlon competitions only
    private var competitionDayCompetitions: [Competition] {
        relevantCompetitions.filter {
            $0.competitionType == .tetrathlon || $0.competitionType == .triathlon
        }
    }

    /// Disciplines to show for the selected competition
    private var disciplinesToShow: [TriathlonDiscipline] {
        guard let comp = selectedCompetition else { return [] }
        if comp.competitionType == .tetrathlon {
            return orderedDisciplines(for: comp, all: [.shooting, .swimming, .running, .riding])
        } else {
            return orderedDisciplines(for: comp, all: comp.triathlonDisciplines)
        }
    }

    /// Order disciplines by start time if available, otherwise keep default order
    private func orderedDisciplines(for competition: Competition, all disciplines: [TriathlonDiscipline]) -> [TriathlonDiscipline] {
        let times: [(TriathlonDiscipline, Date?)] = disciplines.map { disc in
            switch disc {
            case .shooting: return (disc, competition.shootingStartTime)
            case .swimming: return (disc, competition.swimStartTime)
            case .running: return (disc, competition.runningStartTime)
            case .riding: return (disc, nil)
            }
        }

        let withTimes = times.filter { $0.1 != nil }
        if withTimes.count >= 2 {
            return times.sorted { a, b in
                guard let aTime = a.1 else { return false }
                guard let bTime = b.1 else { return true }
                return aTime < bTime
            }.map(\.0)
        }

        return disciplines
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if competitionDayCompetitions.isEmpty {
                    emptyStateView
                } else {
                    // Competition picker if multiple
                    if competitionDayCompetitions.count > 1 {
                        competitionPicker
                    }

                    if let competition = selectedCompetition {
                        competitionHeader(competition)
                        disciplineCards(competition)

                        // Health data sections for completed disciplines
                        healthDataSections
                    }
                }
            }
            .padding()
        }
        .onAppear {
            if selectedCompetition == nil {
                selectedCompetition = competitionDayCompetitions.first
            }
        }
        .fullScreenCover(item: $activeDiscipline) { discipline in
            if let competition = selectedCompetition {
                disciplineView(for: discipline, competition: competition)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "flag.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Competition Today")
                .font(.title3.bold())

            Text("Check the Calendar tab for upcoming competitions, or add a new one.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 60)
    }

    // MARK: - Competition Picker

    private var competitionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(competitionDayCompetitions, id: \.id) { comp in
                    Button {
                        selectedCompetition = comp
                    } label: {
                        VStack(spacing: 4) {
                            Text(comp.name)
                                .font(.subheadline.bold())
                                .lineLimit(1)
                            Text(comp.level.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(selectedCompetition?.id == comp.id ? AppColors.primary.opacity(0.15) : AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedCompetition?.id == comp.id ? AppColors.primary : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Competition Header

    private func competitionHeader(_ competition: Competition) -> some View {
        VStack(spacing: 8) {
            Text(competition.name)
                .font(.title2.bold())

            HStack(spacing: 12) {
                if !competition.venue.isEmpty {
                    Label(competition.venue, systemImage: "mappin")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if !competition.location.isEmpty {
                    Label(competition.location, systemImage: "mappin")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Label(competition.formattedDate, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Image(systemName: competition.competitionType.icon)
                Text(competition.competitionType.rawValue)
                Text("·")
                Text(competition.level.displayName)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let totalPoints = totalPointsForCompetition(competition), totalPoints > 0 {
                Text(String(format: "%.0f total points", totalPoints))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(AppColors.primary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Discipline Cards

    private func disciplineCards(_ competition: Competition) -> some View {
        VStack(spacing: 12) {
            ForEach(disciplinesToShow, id: \.self) { discipline in
                disciplineCard(discipline, competition: competition)
            }
        }
    }

    private func disciplineCard(_ discipline: TriathlonDiscipline, competition: Competition) -> some View {
        let status = disciplineStatus(discipline, competition: competition)
        let score = disciplineScore(discipline, competition: competition)
        let points = disciplinePoints(discipline, competition: competition)
        let scheduledTime = disciplineScheduledTime(discipline, competition: competition)

        return Button {
            dayManager.startDiscipline(discipline)
            activeDiscipline = discipline
        } label: {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: discipline.icon)
                    .font(.title2)
                    .foregroundStyle(status == .done ? .green : (status == .inProgress ? .orange : AppColors.primary))
                    .frame(width: 44, height: 44)
                    .background(status == .done ? Color.green.opacity(0.15) : (status == .inProgress ? Color.orange.opacity(0.15) : AppColors.primary.opacity(0.1)))
                    .clipShape(Circle())

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(discipline.rawValue)
                        .font(.body.bold())
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        if let time = scheduledTime {
                            Text(time, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(status.label)
                            .font(.caption.bold())
                            .foregroundStyle(status.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(status.color.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Spacer()

                // Score/Points
                VStack(alignment: .trailing, spacing: 2) {
                    if let score = score {
                        Text(score)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                    if let pts = points {
                        Text(String(format: "%.0f pts", pts))
                            .font(.caption.monospacedDigit().bold())
                            .foregroundStyle(AppColors.primary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Discipline View Router

    @ViewBuilder
    private func disciplineView(for discipline: TriathlonDiscipline, competition: Competition) -> some View {
        switch discipline {
        case .running:
            RunningStopwatchView(competition: competition) {
                dayManager.completeDiscipline(discipline, competition: competition)
                activeDiscipline = nil
            }
        case .swimming:
            SwimmingCompetitionTrackerView(competition: competition) {
                dayManager.completeDiscipline(discipline, competition: competition)
                activeDiscipline = nil
            }
        case .shooting:
            ShootingCompetitionDayView(competition: competition) {
                dayManager.completeDiscipline(discipline, competition: competition)
                activeDiscipline = nil
            }
        case .riding:
            RidingCompetitionDayView(competition: competition) {
                dayManager.completeDiscipline(discipline, competition: competition)
                activeDiscipline = nil
            }
        }
    }

    // MARK: - Health Data Sections

    @ViewBuilder
    private var healthDataSections: some View {
        let completedWithHealth = disciplinesToShow.filter { dayManager.healthMetrics[$0]?.hasData == true }

        if !completedWithHealth.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Health Data")
                    .font(.headline)

                ForEach(completedWithHealth, id: \.self) { discipline in
                    if let metrics = dayManager.healthMetrics[discipline] {
                        healthMetricsCard(discipline: discipline, metrics: metrics)
                    }
                }
            }
        }

        if dayManager.isLoadingHealth {
            HStack(spacing: 8) {
                ProgressView()
                Text("Loading health data...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private func healthMetricsCard(discipline: TriathlonDiscipline, metrics: CompetitionHealthMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: discipline.icon)
                    .foregroundStyle(AppColors.primary)
                Text("\(discipline.rawValue) Health Data")
                    .font(.subheadline.bold())
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                if let avgHR = metrics.averageHeartRate {
                    healthMetricItem(label: "Avg Heart Rate", value: String(format: "%.0f bpm", avgHR))
                }
                if let maxHR = metrics.maxHeartRate {
                    healthMetricItem(label: "Max Heart Rate", value: String(format: "%.0f bpm", maxHR))
                }
                if let minHR = metrics.minHeartRate {
                    healthMetricItem(label: "Min Heart Rate", value: String(format: "%.0f bpm", minHR))
                }
                if let cal = metrics.activeCalories {
                    healthMetricItem(label: "Calories", value: String(format: "%.0f kcal", cal))
                }
                if let running = metrics.runningMetrics, running.hasData {
                    if let power = running.power {
                        healthMetricItem(label: "Power", value: String(format: "%.0f W", power))
                    }
                    if let stride = running.strideLength {
                        healthMetricItem(label: "Stride", value: String(format: "%.2f m", stride))
                    }
                    if let gct = running.groundContactTime {
                        healthMetricItem(label: "Ground Contact", value: String(format: "%.0f ms", gct))
                    }
                    if let speed = running.speed {
                        let pace = 1000.0 / (speed * 60.0)
                        healthMetricItem(label: "Pace", value: String(format: "%.1f min/km", pace))
                    }
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func healthMetricItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.monospacedDigit().bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private enum DisciplineStatus {
        case pending, inProgress, done

        var label: String {
            switch self {
            case .pending: return "Pending"
            case .inProgress: return "In Progress"
            case .done: return "Done"
            }
        }

        var color: Color {
            switch self {
            case .pending: return .secondary
            case .inProgress: return .orange
            case .done: return .green
            }
        }
    }

    private func disciplineStatus(_ discipline: TriathlonDiscipline, competition: Competition) -> DisciplineStatus {
        // Check if currently active via the manager
        if dayManager.activeDiscipline == discipline {
            return .inProgress
        }

        switch discipline {
        case .shooting:
            return competition.shootingScore != nil ? .done : .pending
        case .swimming:
            return competition.swimmingDistance != nil && competition.swimmingDistance! > 0 ? .done : .pending
        case .running:
            return competition.runningTime != nil && competition.runningTime! > 0 ? .done : .pending
        case .riding:
            return competition.ridingScore != nil ? .done : .pending
        }
    }

    private func disciplineScore(_ discipline: TriathlonDiscipline, competition: Competition) -> String? {
        switch discipline {
        case .shooting:
            guard let score = competition.shootingScore else { return nil }
            return "\(score / 10)/100"
        case .swimming:
            guard let distance = competition.swimmingDistance, distance > 0 else { return nil }
            return "\(Int(distance))m"
        case .running:
            guard let time = competition.runningTime, time > 0 else { return nil }
            return PonyClubScoringService.formatTime(time)
        case .riding:
            guard let penalties = competition.ridingScore else { return nil }
            return String(format: "%.1f penalties", penalties)
        }
    }

    private func disciplinePoints(_ discipline: TriathlonDiscipline, competition: Competition) -> Double? {
        switch discipline {
        case .shooting: return competition.shootingPoints
        case .swimming: return competition.swimmingPoints
        case .running: return competition.runningPoints
        case .riding: return competition.ridingPoints
        }
    }

    private func disciplineScheduledTime(_ discipline: TriathlonDiscipline, competition: Competition) -> Date? {
        switch discipline {
        case .shooting: return competition.shootingStartTime
        case .swimming: return competition.swimStartTime
        case .running: return competition.runningStartTime
        case .riding: return nil
        }
    }

    private func totalPointsForCompetition(_ competition: Competition) -> Double? {
        let shooting = competition.shootingPoints ?? 0
        let swimming = competition.swimmingPoints ?? 0
        let running = competition.runningPoints ?? 0
        let riding = competition.ridingPoints ?? 0
        let total = shooting + swimming + running + riding
        return total > 0 ? total : nil
    }
}

// MARK: - TriathlonDiscipline Identifiable for fullScreenCover

extension TriathlonDiscipline: @retroactive Identifiable {
    public var id: String { rawValue }
}

#Preview {
    NavigationStack {
        CompetitionDayView()
    }
}
