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

    /// Calculate total points from current inputs
    private var totalPoints: Double {
        var total: Double = 0

        if showDiscipline(.shooting), let score = Int(shootingScoreText) {
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
            VStack(alignment: .leading, spacing: 16) {
                // Header
                Text("Disciplines")
                    .font(.headline)

                // Discipline rows
                ForEach(disciplinesToShow, id: \.self) { discipline in
                    disciplineInputRow(for: discipline)
                }

                Divider()

                // Total
                HStack {
                    Text("Total")
                        .font(.headline)
                    Spacer()
                    Text(totalPoints > 0 ? String(format: "%.0f pts", totalPoints) : "—")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(totalPoints > 0 ? AppColors.primary : .secondary)
                }

                // Placements (Triathlon only)
                if isTriathlon {
                    Divider()

                    HStack {
                        Text("Individual")
                        Spacer()
                        TextField("—", text: $individualPlacementText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                            .onChange(of: individualPlacementText) { _, _ in saveResults() }
                    }

                    HStack {
                        Text("Team")
                        Spacer()
                        TextField("—", text: $teamPlacementText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                            .onChange(of: teamPlacementText) { _, _ in saveResults() }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onAppear { loadExistingResults() }
        }
    }

    @ViewBuilder
    private func disciplineInputRow(for discipline: TriathlonDiscipline) -> some View {
        VStack(spacing: 8) {
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
    }

    // MARK: - Shooting Row

    @ViewBuilder
    private func shootingRow() -> some View {
        HStack(alignment: .center) {
            // Icon and label
            HStack(spacing: 8) {
                Image(systemName: TriathlonDiscipline.shooting.icon)
                    .frame(width: 24)
                    .foregroundStyle(AppColors.primary)
                Text("Shoot")
                    .font(.subheadline)
            }

            Spacer()

            // Input
            HStack(spacing: 4) {
                TextField("0", text: $shootingScoreText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 50)
                    .onChange(of: shootingScoreText) { _, _ in saveResults() }
                Text("/100")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Points
            if let score = Int(shootingScoreText), score > 0 {
                Text(String(format: "%.0f", PonyClubScoringService.calculateShootingPoints(rawScore: score * 10)))
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 50, alignment: .trailing)
            } else {
                Text("—")
                    .foregroundStyle(.tertiary)
                    .frame(width: 50, alignment: .trailing)
            }
        }
    }

    // MARK: - Swimming Row

    @ViewBuilder
    private func swimmingRow() -> some View {
        VStack(spacing: 6) {
            // Main row
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: TriathlonDiscipline.swimming.icon)
                        .frame(width: 24)
                        .foregroundStyle(AppColors.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Swim")
                            .font(.subheadline)
                        Text(competition.level.formattedSwimDuration)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Distance display
                Text("\(Int(swimDistance))m")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)

                // Points
                if swimDistance > 0 {
                    Text(String(format: "%.0f", PonyClubScoringService.calculateSwimmingPoints(timeInSeconds: swimTime, distanceMeters: swimDistance)))
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(AppColors.primary)
                        .frame(width: 50, alignment: .trailing)
                } else {
                    Text("—")
                        .foregroundStyle(.tertiary)
                        .frame(width: 50, alignment: .trailing)
                }
            }

            // Swim inputs row
            HStack(spacing: 12) {
                Spacer()

                // Pool length
                HStack(spacing: 4) {
                    Text("Pool:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $poolLength) {
                        Text("20m").tag(20.0)
                        Text("25m").tag(25.0)
                        Text("33m").tag(33.0)
                        Text("50m").tag(50.0)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .onChange(of: poolLength) { _, _ in saveResults() }
                }

                // Lengths
                HStack(spacing: 4) {
                    Text("Lengths:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $swimLengths) {
                        ForEach(0..<21) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .onChange(of: swimLengths) { _, _ in saveResults() }
                }

                // Extra meters
                HStack(spacing: 4) {
                    Text("+")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $swimExtraMeters) {
                        ForEach(0..<50) { Text("\($0)m").tag($0) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .onChange(of: swimExtraMeters) { _, _ in saveResults() }
                }
            }
        }
    }

    // MARK: - Running Row

    @ViewBuilder
    private func runningRow() -> some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                Image(systemName: TriathlonDiscipline.running.icon)
                    .frame(width: 24)
                    .foregroundStyle(AppColors.primary)
                Text("Run")
                    .font(.subheadline)
            }

            Spacer()

            // Time input
            HStack(spacing: 2) {
                Picker("", selection: $runMinutes) {
                    ForEach(0..<20) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .onChange(of: runMinutes) { _, _ in saveResults() }

                Text(":")
                    .foregroundStyle(.secondary)

                Picker("", selection: $runSeconds) {
                    ForEach(0..<60) { Text(String(format: "%02d", $0)).tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .onChange(of: runSeconds) { _, _ in saveResults() }
            }

            // Points
            let runTime = Double(runMinutes * 60 + runSeconds)
            if runTime > 0 {
                Text(String(format: "%.0f", PonyClubScoringService.calculateRunningPoints(timeInSeconds: runTime)))
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 50, alignment: .trailing)
            } else {
                Text("—")
                    .foregroundStyle(.tertiary)
                    .frame(width: 50, alignment: .trailing)
            }
        }
    }

    // MARK: - Riding Row

    @ViewBuilder
    private func ridingRow() -> some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                Image(systemName: TriathlonDiscipline.riding.icon)
                    .frame(width: 24)
                    .foregroundStyle(AppColors.primary)
                Text("Ride")
                    .font(.subheadline)
            }

            Spacer()

            // Penalties input
            HStack(spacing: 4) {
                TextField("0", text: $ridingPenalties)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 50)
                    .onChange(of: ridingPenalties) { _, _ in saveResults() }
                Text("pen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Points
            if let penalties = Double(ridingPenalties) {
                Text(String(format: "%.0f", PonyClubScoringService.calculateRidingPoints(penalties: penalties)))
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 50, alignment: .trailing)
            } else {
                Text("—")
                    .foregroundStyle(.tertiary)
                    .frame(width: 50, alignment: .trailing)
            }
        }
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
