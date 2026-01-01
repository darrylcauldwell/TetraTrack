//
//  DisciplineScoreCardView.swift
//  TetraTrack
//
//  Inline editable score card for Triathlon/Tetrathlon results
//

import SwiftUI
import CoreLocation

/// Inline editable score card for entering and displaying discipline results
struct DisciplineScoreCardView: View {
    @Bindable var competition: Competition

    // Weather service for auto-fetching weather on completion
    private let weatherService = WeatherService.shared

    // Scoring info sheet
    @State private var showScoringInfo = false
    @State private var activeLiveDiscipline: TriathlonDiscipline?

    // Input state for each discipline
    @State private var shootingScoreText: String = ""
    @State private var poolLength: Double = 25
    @State private var swimLengths: Int = 0
    @State private var swimExtraMeters: Int = 0
    @State private var runMinutes: Int = 0
    @State private var runSeconds: Int = 0
    @State private var ridingPenalties: String = ""
    @State private var individualPlacementText: String = ""
    @State private var teamPlacementText: String = ""

    @State private var hasLoaded = false

    private var isTetrathlon: Bool {
        competition.competitionType == .tetrathlon
    }

    private var isTriathlon: Bool {
        competition.competitionType == .triathlon
    }

    /// Check if a discipline should be shown
    private func showDiscipline(_ discipline: TriathlonDiscipline) -> Bool {
        if isTetrathlon { return true }
        return competition.hasTriathlonDiscipline(discipline)
    }

    /// Calculated swim distance
    private var swimDistance: Double {
        poolLength * Double(swimLengths) + Double(swimExtraMeters)
    }

    /// Fixed swim time based on competition level
    private var swimTime: TimeInterval {
        competition.level.swimDuration
    }

    /// Get disciplines in correct order
    private var disciplinesToShow: [TriathlonDiscipline] {
        if isTetrathlon {
            return [.shooting, .swimming, .running, .riding]
        } else {
            return competition.triathlonDisciplines
        }
    }

    /// Get ordinal suffix for a number (1st, 2nd, 3rd, 4th, etc.)
    private func ordinalSuffix(for number: Int) -> String {
        let tens = number % 100
        let ones = number % 10

        if tens >= 11 && tens <= 13 {
            return "th"
        } else {
            switch ones {
            case 1: return "st"
            case 2: return "nd"
            case 3: return "rd"
            default: return "th"
            }
        }
    }

    /// Calculate total points from current inputs
    private var totalPoints: Double {
        var total: Double = 0

        if showDiscipline(.shooting), let score = Int(shootingScoreText), score > 0 {
            total += PonyClubScoringService.calculateShootingPoints(rawScore: score * 10)
        }

        if showDiscipline(.swimming), swimDistance > 0 {
            total += PonyClubScoringService.calculateSwimmingPoints(
                distanceMeters: swimDistance,
                ageCategory: competition.level.scoringCategory,
                gender: competition.level.scoringGender
            )
        }

        let runTime = Double(runMinutes * 60 + runSeconds)
        if showDiscipline(.running), runTime > 0 {
            total += PonyClubScoringService.calculateRunningPoints(
                timeInSeconds: runTime,
                ageCategory: competition.level.scoringCategory,
                gender: competition.level.scoringGender
            )
        }

        if showDiscipline(.riding), let penalties = Double(ridingPenalties) {
            total += PonyClubScoringService.calculateRidingPoints(penalties: penalties)
        }

        return total
    }

    var body: some View {
        if isTetrathlon || isTriathlon {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Score Card")
                        .font(.headline)

                    Button {
                        showScoringInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if totalPoints > 0 {
                        Text(String(format: "%.0f pts", totalPoints))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(AppColors.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppColors.elevatedSurface)

                // Discipline rows
                VStack(spacing: 0) {
                    ForEach(Array(disciplinesToShow.enumerated()), id: \.element) { index, discipline in
                        disciplineRow(for: discipline)

                        if index < disciplinesToShow.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(AppColors.cardBackground)

                // Placements
                Divider()

                VStack(spacing: 0) {
                    placementRow(label: "Individual Placement", text: $individualPlacementText)
                    Divider().padding(.leading, 16)
                    placementRow(label: "Team Placement", text: $teamPlacementText)
                }
                .background(AppColors.cardBackground)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onAppear { loadExistingResults() }
            .sheet(isPresented: $showScoringInfo) {
                ScoringInfoView()
            }
            .fullScreenCover(item: $activeLiveDiscipline) { discipline in
                liveEntryView(for: discipline)
            }
            .presentationBackground(Color.black)
        }
    }

    // MARK: - Discipline Row

    @ViewBuilder
    private func disciplineRow(for discipline: TriathlonDiscipline) -> some View {
        switch discipline {
        case .shooting:
            shootingRow()
        case .swimming:
            swimmingRow()
        case .running:
            runningRow()
        case .riding:
            ridingRow()
        }
    }

    // MARK: - Live Entry Button

    private func liveEntryButton(for discipline: TriathlonDiscipline) -> some View {
        Button {
            activeLiveDiscipline = discipline
        } label: {
            Label("Live", systemImage: "bolt.fill")
                .font(.caption.bold())
                .foregroundStyle(AppColors.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.primary.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private func liveEntryView(for discipline: TriathlonDiscipline) -> some View {
        switch discipline {
        case .running:
            RunningStopwatchView(competition: competition) {
                activeLiveDiscipline = nil
                reloadResults()
            }
        case .swimming:
            SwimmingCompetitionTrackerView(competition: competition) {
                activeLiveDiscipline = nil
                reloadResults()
            }
        case .shooting:
            ShootingCompetitionDayView(competition: competition) {
                activeLiveDiscipline = nil
                reloadResults()
            }
        case .riding:
            RidingCompetitionDayView(competition: competition) {
                activeLiveDiscipline = nil
                reloadResults()
            }
        }
    }

    /// Force reload results from model after live entry
    private func reloadResults() {
        hasLoaded = false
        loadExistingResults()
    }

    // MARK: - Shooting Row

    @ViewBuilder
    private func shootingRow() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row with points
            HStack {
                Image(systemName: TriathlonDiscipline.shooting.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 24)

                Text("Shooting")
                    .font(.body.weight(.medium))

                liveEntryButton(for: .shooting)

                Spacer()

                if let pts = shootingPoints {
                    Text(String(format: "%.0f pts", pts))
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(AppColors.primary)
                }
            }

            // Input row
            HStack {
                Text("Score")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 8) {
                    TextField("0", text: $shootingScoreText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 60)
                        .padding(.vertical, 8)
                        .background(AppColors.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onChange(of: shootingScoreText) { _, newValue in
                            validateShootingScore(newValue)
                            saveResults()
                        }

                    Text("/ 100")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 32)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var shootingPoints: Double? {
        guard let score = Int(shootingScoreText), score > 0 else { return nil }
        return PonyClubScoringService.calculateShootingPoints(rawScore: score * 10)
    }

    /// Validate shooting score: max 100, even numbers only
    private func validateShootingScore(_ value: String) {
        // Filter to digits only
        let filtered = value.filter { $0.isNumber }

        guard let number = Int(filtered) else {
            if filtered.isEmpty {
                shootingScoreText = ""
            }
            return
        }

        // Cap at 100
        let capped = min(number, 100)

        // Round to nearest even number
        let evenScore = (capped / 2) * 2

        let newValue = "\(evenScore)"
        if shootingScoreText != newValue {
            shootingScoreText = newValue
        }
    }

    // MARK: - Swimming Row

    @ViewBuilder
    private func swimmingRow() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row with distance and points
            HStack {
                Image(systemName: TriathlonDiscipline.swimming.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Swimming")
                        .font(.body.weight(.medium))
                    Text(competition.level.formattedSwimDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                liveEntryButton(for: .swimming)

                Spacer()

                if swimDistance > 0 {
                    Text("\(Int(swimDistance))m")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 8)
                }

                if let pts = swimmingPoints {
                    Text(String(format: "%.0f pts", pts))
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(AppColors.primary)
                }
            }

            // Pool length row
            HStack {
                Text("Pool Length")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Menu {
                    ForEach([20.0, 25.0, 33.0, 50.0], id: \.self) { length in
                        Button("\(Int(length))m") {
                            poolLength = length
                            saveResults()
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("\(Int(poolLength))m")
                            .font(.subheadline)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(AppColors.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.leading, 32)

            // Lengths row
            HStack {
                Text("Lengths")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Menu {
                    ForEach(0..<21, id: \.self) { num in
                        Button("\(num)") {
                            swimLengths = num
                            saveResults()
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("\(swimLengths)")
                            .font(.subheadline)
                            .frame(minWidth: 24)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(AppColors.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.leading, 32)

            // Extra meters row
            HStack {
                Text("Extra Meters")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Menu {
                    ForEach(0..<Int(poolLength), id: \.self) { num in
                        Button("\(num)m") {
                            swimExtraMeters = num
                            saveResults()
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("\(swimExtraMeters)m")
                            .font(.subheadline)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(AppColors.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.leading, 32)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var swimmingPoints: Double? {
        guard swimDistance > 0 else { return nil }
        return PonyClubScoringService.calculateSwimmingPoints(
            distanceMeters: swimDistance,
            ageCategory: competition.level.scoringCategory,
            gender: competition.level.scoringGender
        )
    }

    // MARK: - Running Row

    @ViewBuilder
    private func runningRow() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row with points
            HStack {
                Image(systemName: TriathlonDiscipline.running.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 24)

                Text("Running")
                    .font(.body.weight(.medium))

                liveEntryButton(for: .running)

                Spacer()

                if let pts = runningPoints {
                    Text(String(format: "%.0f pts", pts))
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(AppColors.primary)
                }
            }

            // Time input row
            HStack {
                Text("Time")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 4) {
                    Menu {
                        ForEach(0..<20, id: \.self) { min in
                            Button("\(min)") {
                                runMinutes = min
                                saveResults()
                            }
                        }
                    } label: {
                        Text("\(runMinutes)")
                            .font(.subheadline.monospacedDigit())
                            .frame(minWidth: 32)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 8)
                            .background(AppColors.elevatedSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Text(":")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Menu {
                        ForEach(0..<60, id: \.self) { sec in
                            Button(String(format: "%02d", sec)) {
                                runSeconds = sec
                                saveResults()
                            }
                        }
                    } label: {
                        Text(String(format: "%02d", runSeconds))
                            .font(.subheadline.monospacedDigit())
                            .frame(minWidth: 32)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 8)
                            .background(AppColors.elevatedSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Text("min:sec")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.leading, 32)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var runningPoints: Double? {
        let time = Double(runMinutes * 60 + runSeconds)
        guard time > 0 else { return nil }
        return PonyClubScoringService.calculateRunningPoints(
            timeInSeconds: time,
            ageCategory: competition.level.scoringCategory,
            gender: competition.level.scoringGender
        )
    }

    // MARK: - Riding Row

    @ViewBuilder
    private func ridingRow() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row with points
            HStack {
                Image(systemName: TriathlonDiscipline.riding.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 24)

                Text("Riding")
                    .font(.body.weight(.medium))

                liveEntryButton(for: .riding)

                Spacer()

                if let pts = ridingPoints {
                    Text(String(format: "%.0f pts", pts))
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(AppColors.primary)
                }
            }

            // Penalties input row
            HStack {
                Text("Penalties")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 8) {
                    TextField("0", text: $ridingPenalties)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 60)
                        .padding(.vertical, 8)
                        .background(AppColors.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onChange(of: ridingPenalties) { _, _ in saveResults() }

                    Text("faults")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 32)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var ridingPoints: Double? {
        guard let penalties = Double(ridingPenalties) else { return nil }
        return PonyClubScoringService.calculateRidingPoints(penalties: penalties)
    }

    // MARK: - Placement Row

    @ViewBuilder
    private func placementRow(label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 2) {
                TextField("—", text: text)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 50)
                    .padding(.vertical, 8)
                    .background(AppColors.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onChange(of: text.wrappedValue) { _, _ in saveResults() }

                if let num = Int(text.wrappedValue), num > 0 {
                    Text(ordinalSuffix(for: num))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Load/Save

    private func loadExistingResults() {
        guard !hasLoaded else { return }
        hasLoaded = true

        // Shooting (stored as /1000, display as /100)
        if let score = competition.shootingScore {
            shootingScoreText = "\(score / 10)"
        }

        // Swimming distance
        if let distance = competition.swimmingDistance {
            let poolLengths: [Double] = [25, 20, 33, 50]
            var matched = false
            for pool in poolLengths {
                let wholeLengths = Int(distance / pool)
                let extra = distance - (pool * Double(wholeLengths))
                if wholeLengths >= 0 && wholeLengths <= 20 && extra >= 0 && extra < pool {
                    poolLength = pool
                    swimLengths = wholeLengths
                    swimExtraMeters = Int(extra.rounded())
                    matched = true
                    break
                }
            }
            if !matched {
                poolLength = 25
                swimLengths = min(Int(distance / 25), 20)
                swimExtraMeters = Int(distance.truncatingRemainder(dividingBy: 25))
            }
        }

        // Running
        if let time = competition.runningTime {
            runMinutes = Int(time) / 60
            runSeconds = Int(time) % 60
        }

        // Riding
        if let penalties = competition.ridingScore {
            ridingPenalties = String(format: "%.1f", penalties)
        }

        // Placements
        if let individual = competition.individualPlacement {
            individualPlacementText = "\(individual)"
        }
        if let team = competition.teamPlacement {
            teamPlacementText = "\(team)"
        }
    }

    private func saveResults() {
        // Shooting
        if showDiscipline(.shooting), let score = Int(shootingScoreText) {
            competition.shootingScore = score * 10
            competition.shootingPoints = PonyClubScoringService.calculateShootingPoints(rawScore: score * 10)
        }

        // Swimming
        if showDiscipline(.swimming) {
            competition.swimmingDistance = swimDistance
            competition.swimmingTime = swimTime
            if swimDistance > 0 {
                competition.swimmingPoints = PonyClubScoringService.calculateSwimmingPoints(
                    distanceMeters: swimDistance,
                    ageCategory: competition.level.scoringCategory,
                    gender: competition.level.scoringGender
                )
            }
        }

        // Running
        if showDiscipline(.running) {
            let runTime = Double(runMinutes * 60 + runSeconds)
            competition.runningTime = runTime > 0 ? runTime : nil
            if runTime > 0 {
                competition.runningPoints = PonyClubScoringService.calculateRunningPoints(
                    timeInSeconds: runTime,
                    ageCategory: competition.level.scoringCategory,
                    gender: competition.level.scoringGender
                )
            }
        }

        // Riding
        if showDiscipline(.riding), let penalties = Double(ridingPenalties) {
            competition.ridingScore = penalties
            competition.ridingPoints = PonyClubScoringService.calculateRidingPoints(penalties: penalties)
        }

        // Total
        if totalPoints > 0 {
            competition.storedTotalPoints = totalPoints
        }

        // Placements
        competition.individualPlacement = Int(individualPlacementText)
        competition.teamPlacement = Int(teamPlacementText)

        // Mark completed if all disciplines have results
        var hasAll = true
        if showDiscipline(.shooting) && competition.shootingPoints == nil { hasAll = false }
        if showDiscipline(.swimming) && competition.swimmingPoints == nil { hasAll = false }
        if showDiscipline(.running) && competition.runningPoints == nil { hasAll = false }
        if showDiscipline(.riding) && competition.ridingPoints == nil { hasAll = false }

        let wasCompleted = competition.isCompleted
        competition.isCompleted = hasAll && totalPoints > 0

        // Auto-fetch weather when competition becomes completed
        if !wasCompleted && competition.isCompleted && !competition.hasWeatherData {
            fetchWeatherForCompletion()
        }
    }

    /// Fetch weather conditions for the competition venue
    private func fetchWeatherForCompletion() {
        guard let lat = competition.venueLatitude,
              let lon = competition.venueLongitude else { return }

        let location = CLLocation(latitude: lat, longitude: lon)

        Task {
            do {
                let weather = try await weatherService.fetchWeather(for: location)
                await MainActor.run {
                    competition.weather = weather
                }
            } catch {
                // Weather fetch failed silently - not critical for completion
            }
        }
    }
}

#Preview {
    @Previewable @State var competition: Competition = {
        let comp = Competition()
        comp.competitionTypeRaw = "triathlon"
        comp.levelRaw = "Junior"
        return comp
    }()

    ScrollView {
        DisciplineScoreCardView(competition: competition)
            .padding()
    }
}
