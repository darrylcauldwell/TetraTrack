//
//  DisciplineScoreCardView.swift
//  TrackRide
//
//  Inline editable score card for Triathlon/Tetrathlon results
//

import SwiftUI

/// Inline editable score card for entering and displaying discipline results
struct DisciplineScoreCardView: View {
    @Bindable var competition: Competition

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
            total += PonyClubScoringService.calculateSwimmingPoints(timeInSeconds: swimTime, distanceMeters: swimDistance)
        }

        let runTime = Double(runMinutes * 60 + runSeconds)
        if showDiscipline(.running), runTime > 0 {
            total += PonyClubScoringService.calculateRunningPoints(timeInSeconds: runTime)
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
                    Spacer()
                    if totalPoints > 0 {
                        Text(String(format: "%.0f pts", totalPoints))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(AppColors.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.tertiarySystemBackground))

                // Discipline rows
                VStack(spacing: 0) {
                    ForEach(Array(disciplinesToShow.enumerated()), id: \.element) { index, discipline in
                        disciplineRow(for: discipline)

                        if index < disciplinesToShow.count - 1 {
                            Divider()
                                .padding(.leading, 48)
                        }
                    }
                }
                .background(Color(.secondarySystemBackground))

                // Placements
                if isTriathlon {
                    Divider()

                    VStack(spacing: 0) {
                        placementRow(label: "Individual", text: $individualPlacementText)
                        Divider().padding(.leading, 16)
                        placementRow(label: "Team", text: $teamPlacementText)
                    }
                    .background(Color(.secondarySystemBackground))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onAppear { loadExistingResults() }
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

    // MARK: - Shooting Row

    @ViewBuilder
    private func shootingRow() -> some View {
        HStack(spacing: 12) {
            Image(systemName: TriathlonDiscipline.shooting.icon)
                .font(.system(size: 18))
                .foregroundStyle(AppColors.primary)
                .frame(width: 28)

            Text("Shoot")
                .font(.body)

            Spacer()

            HStack(spacing: 4) {
                TextField("—", text: $shootingScoreText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 44)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .onChange(of: shootingScoreText) { _, _ in saveResults() }

                Text("/100")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            pointsLabel(for: shootingPoints)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var shootingPoints: Double? {
        guard let score = Int(shootingScoreText), score > 0 else { return nil }
        return PonyClubScoringService.calculateShootingPoints(rawScore: score * 10)
    }

    // MARK: - Swimming Row

    @ViewBuilder
    private func swimmingRow() -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: TriathlonDiscipline.swimming.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Swim")
                        .font(.body)
                    Text(competition.level.formattedSwimDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if swimDistance > 0 {
                    Text("\(Int(swimDistance))m")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                pointsLabel(for: swimmingPoints)
            }

            // Swim inputs
            HStack(spacing: 16) {
                Spacer()

                HStack(spacing: 6) {
                    Text("Pool")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Menu {
                        ForEach([20.0, 25.0, 33.0, 50.0], id: \.self) { length in
                            Button("\(Int(length))m") {
                                poolLength = length
                                saveResults()
                            }
                        }
                    } label: {
                        Text("\(Int(poolLength))m")
                            .font(.subheadline)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                HStack(spacing: 6) {
                    Text("Lengths")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Menu {
                        ForEach(0..<21, id: \.self) { num in
                            Button("\(num)") {
                                swimLengths = num
                                saveResults()
                            }
                        }
                    } label: {
                        Text("\(swimLengths)")
                            .font(.subheadline)
                            .frame(minWidth: 24)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                HStack(spacing: 6) {
                    Text("+")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Menu {
                        ForEach(0..<Int(poolLength), id: \.self) { num in
                            Button("\(num)m") {
                                swimExtraMeters = num
                                saveResults()
                            }
                        }
                    } label: {
                        Text("\(swimExtraMeters)m")
                            .font(.subheadline)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var swimmingPoints: Double? {
        guard swimDistance > 0 else { return nil }
        return PonyClubScoringService.calculateSwimmingPoints(timeInSeconds: swimTime, distanceMeters: swimDistance)
    }

    // MARK: - Running Row

    @ViewBuilder
    private func runningRow() -> some View {
        HStack(spacing: 12) {
            Image(systemName: TriathlonDiscipline.running.icon)
                .font(.system(size: 18))
                .foregroundStyle(AppColors.primary)
                .frame(width: 28)

            Text("Run")
                .font(.body)

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
                        .frame(minWidth: 24)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Text(":")
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
                        .frame(minWidth: 28)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            pointsLabel(for: runningPoints)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var runningPoints: Double? {
        let time = Double(runMinutes * 60 + runSeconds)
        guard time > 0 else { return nil }
        return PonyClubScoringService.calculateRunningPoints(timeInSeconds: time)
    }

    // MARK: - Riding Row

    @ViewBuilder
    private func ridingRow() -> some View {
        HStack(spacing: 12) {
            Image(systemName: TriathlonDiscipline.riding.icon)
                .font(.system(size: 18))
                .foregroundStyle(AppColors.primary)
                .frame(width: 28)

            Text("Ride")
                .font(.body)

            Spacer()

            HStack(spacing: 4) {
                TextField("—", text: $ridingPenalties)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 44)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .onChange(of: ridingPenalties) { _, _ in saveResults() }

                Text("pen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            pointsLabel(for: ridingPoints)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var ridingPoints: Double? {
        guard let penalties = Double(ridingPenalties) else { return nil }
        return PonyClubScoringService.calculateRidingPoints(penalties: penalties)
    }

    // MARK: - Points Label

    @ViewBuilder
    private func pointsLabel(for points: Double?) -> some View {
        if let pts = points {
            Text(String(format: "%.0f", pts))
                .font(.subheadline.monospacedDigit().bold())
                .foregroundStyle(AppColors.primary)
                .frame(width: 50, alignment: .trailing)
        } else {
            Text("—")
                .foregroundStyle(.tertiary)
                .frame(width: 50, alignment: .trailing)
        }
    }

    // MARK: - Placement Row

    @ViewBuilder
    private func placementRow(label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.body)

            Spacer()

            HStack(spacing: 0) {
                TextField("—", text: text)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 44)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .onChange(of: text.wrappedValue) { _, _ in saveResults() }

                if let num = Int(text.wrappedValue), num > 0 {
                    Text(ordinalSuffix(for: num))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 2)
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
                competition.swimmingPoints = PonyClubScoringService.calculateSwimmingPoints(timeInSeconds: swimTime, distanceMeters: swimDistance)
            }
        }

        // Running
        if showDiscipline(.running) {
            let runTime = Double(runMinutes * 60 + runSeconds)
            competition.runningTime = runTime > 0 ? runTime : nil
            if runTime > 0 {
                competition.runningPoints = PonyClubScoringService.calculateRunningPoints(timeInSeconds: runTime)
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
        if isTriathlon {
            competition.individualPlacement = Int(individualPlacementText)
            competition.teamPlacement = Int(teamPlacementText)
        }

        // Mark completed if all disciplines have results
        var hasAll = true
        if showDiscipline(.shooting) && competition.shootingPoints == nil { hasAll = false }
        if showDiscipline(.swimming) && competition.swimmingPoints == nil { hasAll = false }
        if showDiscipline(.running) && competition.runningPoints == nil { hasAll = false }
        if showDiscipline(.riding) && competition.ridingPoints == nil { hasAll = false }
        competition.isCompleted = hasAll && totalPoints > 0
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
