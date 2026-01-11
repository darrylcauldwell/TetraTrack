//
//  DisciplineScoreCardView.swift
//  TrackRide
//
//  Score card displaying discipline results for Triathlon/Tetrathlon
//

import SwiftUI

/// Score card displaying all discipline results for a competition
struct DisciplineScoreCardView: View {
    let competition: Competition

    private var isTetrathlon: Bool {
        competition.competitionType == .tetrathlon
    }

    private var isTriathlon: Bool {
        competition.competitionType == .triathlon
    }

    var body: some View {
        if isTetrathlon || isTriathlon {
            VStack(alignment: .leading, spacing: 12) {
                Text("Discipline Scores")
                    .font(.headline)
                    .padding(.bottom, 4)

                if isTetrathlon {
                    // Tetrathlon: Fixed 4 disciplines
                    disciplineRow(for: .shooting)
                    disciplineRow(for: .swimming)
                    disciplineRow(for: .running)
                    disciplineRow(for: .riding)
                } else {
                    // Triathlon: Configurable 3 disciplines in order
                    ForEach(competition.triathlonDisciplines, id: \.self) { discipline in
                        disciplineRow(for: discipline)
                    }
                }

                Divider()

                // Total
                HStack {
                    Text("Total")
                        .font(.headline)
                    Spacer()
                    if let total = competition.storedTotalPoints {
                        Text(String(format: "%.0f pts", total))
                            .font(.headline)
                            .foregroundStyle(AppColors.primary)
                    } else {
                        Text("—")
                            .foregroundStyle(.secondary)
                    }
                }

                // Placements (Triathlon)
                if isTriathlon {
                    if competition.individualPlacement != nil || competition.teamPlacement != nil {
                        Divider()

                        HStack(spacing: 0) {
                            // Individual placement
                            VStack(alignment: .center, spacing: 4) {
                                Text("Individual")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let individual = competition.individualPlacement {
                                    Text(formatPlacement(individual))
                                        .font(.title2.bold())
                                        .foregroundStyle(AppColors.primary)
                                } else {
                                    Text("—")
                                        .font(.title2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .frame(maxWidth: .infinity)

                            Divider()
                                .frame(height: 40)

                            // Team placement
                            VStack(alignment: .center, spacing: 4) {
                                Text("Team")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let team = competition.teamPlacement {
                                    Text(formatPlacement(team))
                                        .font(.title2.bold())
                                        .foregroundStyle(AppColors.primary)
                                } else {
                                    Text("—")
                                        .font(.title2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private func disciplineRow(for discipline: TriathlonDiscipline) -> some View {
        switch discipline {
        case .shooting:
            DisciplineScoreRow(
                discipline: "Shooting",
                icon: discipline.icon,
                rawValue: competition.shootingScore.map { "\($0)" },
                points: competition.shootingPoints
            )
        case .swimming:
            DisciplineScoreRow(
                discipline: "Swimming",
                icon: discipline.icon,
                rawValue: competition.swimmingTime.map { formatSwimTime($0) },
                points: competition.swimmingPoints,
                subtitle: competition.swimmingDistance.map { "\(Int($0))m" }
            )
        case .running:
            DisciplineScoreRow(
                discipline: "Running",
                icon: discipline.icon,
                rawValue: competition.runningTime.map { formatRunTime($0) },
                points: competition.runningPoints
            )
        case .riding:
            DisciplineScoreRow(
                discipline: "Riding",
                icon: discipline.icon,
                rawValue: competition.ridingScore.map { String(format: "%.1f pen", $0) },
                points: competition.ridingPoints
            )
        }
    }

    private func formatSwimTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let hundredths = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        if minutes > 0 {
            return String(format: "%d:%02d.%02d", minutes, secs, hundredths)
        } else {
            return String(format: "%d.%02d", secs, hundredths)
        }
    }

    private func formatRunTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func formatPlacement(_ place: Int) -> String {
        let suffix: String
        switch place {
        case 1: suffix = "st"
        case 2: suffix = "nd"
        case 3: suffix = "rd"
        default: suffix = "th"
        }
        return "\(place)\(suffix)"
    }
}

/// Single discipline score row
struct DisciplineScoreRow: View {
    let discipline: String
    let icon: String
    let rawValue: String?
    let points: Double?
    var subtitle: String? = nil

    var body: some View {
        HStack {
            // Icon and discipline name
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 24)
                    .foregroundStyle(AppColors.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(discipline)
                        .font(.subheadline)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Raw value
            if let raw = rawValue {
                Text(raw)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .trailing)
            } else {
                Text("—")
                    .foregroundStyle(.tertiary)
                    .frame(width: 80, alignment: .trailing)
            }

            // Points
            if let pts = points {
                Text(String(format: "%.0f", pts))
                    .font(.subheadline.monospacedDigit())
                    .fontWeight(.medium)
                    .frame(width: 60, alignment: .trailing)
            } else {
                Text("—")
                    .foregroundStyle(.tertiary)
                    .frame(width: 60, alignment: .trailing)
            }
        }
    }
}

// MARK: - Triathlon/Tetrathlon Results Entry View

/// View for entering and viewing Triathlon/Tetrathlon results
struct TriathlonResultsView: View {
    @Bindable var competition: Competition

    @State private var showingResultsEditor = false

    private var isTetrathlon: Bool {
        competition.competitionType == .tetrathlon
    }

    /// Check if a discipline should be shown (always for tetrathlon, configurable for triathlon)
    private func showDiscipline(_ discipline: TriathlonDiscipline) -> Bool {
        if isTetrathlon {
            return true
        }
        return competition.hasTriathlonDiscipline(discipline)
    }

    private var hasAnyResults: Bool {
        (showDiscipline(.shooting) && competition.shootingScore != nil) ||
        (showDiscipline(.swimming) && competition.swimmingTime != nil) ||
        (showDiscipline(.running) && competition.runningTime != nil) ||
        (showDiscipline(.riding) && competition.ridingScore != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(isTetrathlon ? "Tetrathlon Results" : "Triathlon Results")
                    .font(.headline)
                Spacer()
                Button {
                    showingResultsEditor = true
                } label: {
                    Label(hasAnyResults ? "Edit" : "Add Results", systemImage: hasAnyResults ? "pencil" : "plus")
                        .font(.subheadline)
                }
            }

            if hasAnyResults {
                DisciplineScoreCardView(competition: competition)
            } else {
                Text("No results entered yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .sheet(isPresented: $showingResultsEditor) {
            TriathlonResultsEditorView(competition: competition)
        }
    }
}

/// Editor view for entering Triathlon/Tetrathlon results
struct TriathlonResultsEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var competition: Competition

    // Raw result inputs
    @State private var shootingScoreText: String = ""
    @State private var swimMinutes: Int = 0
    @State private var swimSeconds: Int = 0
    @State private var swimHundredths: Int = 0
    @State private var poolLength: Double = 25  // Pool length in meters
    @State private var swimLengths: Int = 4     // Number of lengths swum
    @State private var runMinutes: Int = 0
    @State private var runSeconds: Int = 0
    @State private var ridingPenalties: String = ""

    /// Calculated swim distance from pool length × lengths
    private var swimDistance: Double {
        poolLength * Double(swimLengths)
    }

    // Placements (Triathlon only)
    @State private var individualPlacementText: String = ""
    @State private var teamPlacementText: String = ""

    private var isTetrathlon: Bool {
        competition.competitionType == .tetrathlon
    }

    /// Check if a discipline should be shown (always for tetrathlon, configurable for triathlon)
    private func showDiscipline(_ discipline: TriathlonDiscipline) -> Bool {
        if isTetrathlon {
            return true  // Tetrathlon always has all 4 disciplines
        }
        return competition.hasTriathlonDiscipline(discipline)
    }

    /// Returns the form section for entering results for a specific discipline
    @ViewBuilder
    private func disciplineSection(for discipline: TriathlonDiscipline) -> some View {
        switch discipline {
        case .shooting:
            Section("Shooting") {
                HStack {
                    Text("Score")
                    Spacer()
                    TextField("0", text: $shootingScoreText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("/ 1000")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Points")
                        .font(.headline)
                    Spacer()
                    if let score = Int(shootingScoreText) {
                        Text(PonyClubScoringService.formatPoints(PonyClubScoringService.calculateShootingPoints(rawScore: score)))
                            .font(.title2.bold())
                            .foregroundStyle(AppColors.primary)
                    } else {
                        Text("Enter score")
                            .foregroundStyle(.tertiary)
                    }
                }
            }

        case .swimming:
            Section("Swimming") {
                HStack {
                    Text("Pool Length")
                    Spacer()
                    Picker("Pool", selection: $poolLength) {
                        Text("20m").tag(20.0)
                        Text("25m").tag(25.0)
                        Text("33m").tag(33.0)
                        Text("50m").tag(50.0)
                    }
                    .pickerStyle(.menu)
                }

                HStack {
                    Text("Lengths")
                    Spacer()
                    Picker("Lengths", selection: $swimLengths) {
                        ForEach(1..<21) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                HStack {
                    Text("Total Distance")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(swimDistance))m")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Time")
                    Spacer()
                    Picker("Min", selection: $swimMinutes) {
                        ForEach(0..<10) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    Text(":")
                    Picker("Sec", selection: $swimSeconds) {
                        ForEach(0..<60) { Text(String(format: "%02d", $0)).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    Text(".")
                    Picker("Hun", selection: $swimHundredths) {
                        ForEach(0..<100) { Text(String(format: "%02d", $0)).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                // Always show points calculation
                let swimTime = Double(swimMinutes * 60 + swimSeconds) + Double(swimHundredths) / 100.0
                HStack {
                    Text("Points")
                        .font(.headline)
                    Spacer()
                    if swimTime > 0 {
                        Text(PonyClubScoringService.formatPoints(PonyClubScoringService.calculateSwimmingPoints(timeInSeconds: swimTime, distanceMeters: swimDistance)))
                            .font(.title2.bold())
                            .foregroundStyle(AppColors.primary)
                    } else {
                        Text("Enter time")
                            .foregroundStyle(.tertiary)
                    }
                }
            }

        case .running:
            Section("Running (1500m)") {
                HStack {
                    Text("Time")
                    Spacer()
                    Picker("Min", selection: $runMinutes) {
                        ForEach(0..<20) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    Text(":")
                    Picker("Sec", selection: $runSeconds) {
                        ForEach(0..<60) { Text(String(format: "%02d", $0)).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                let runTime = Double(runMinutes * 60 + runSeconds)
                HStack {
                    Text("Points")
                        .font(.headline)
                    Spacer()
                    if runTime > 0 {
                        Text(PonyClubScoringService.formatPoints(PonyClubScoringService.calculateRunningPoints(timeInSeconds: runTime)))
                            .font(.title2.bold())
                            .foregroundStyle(AppColors.primary)
                    } else {
                        Text("Enter time")
                            .foregroundStyle(.tertiary)
                    }
                }
            }

        case .riding:
            Section("Riding") {
                HStack {
                    Text("Penalties")
                    Spacer()
                    TextField("0", text: $ridingPenalties)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }

                HStack {
                    Text("Points")
                        .font(.headline)
                    Spacer()
                    if let penalties = Double(ridingPenalties) {
                        Text(PonyClubScoringService.formatPoints(PonyClubScoringService.calculateRidingPoints(penalties: penalties)))
                            .font(.title2.bold())
                            .foregroundStyle(AppColors.primary)
                    } else {
                        Text("Enter penalties")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    /// Get the list of disciplines to display in the correct order
    private var disciplinesToShow: [TriathlonDiscipline] {
        if isTetrathlon {
            return [.shooting, .swimming, .running, .riding]
        } else {
            return competition.triathlonDisciplines
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Show disciplines in the configured order
                ForEach(disciplinesToShow, id: \.self) { discipline in
                    disciplineSection(for: discipline)
                }

                // Placements (Triathlon only)
                if !isTetrathlon {
                    Section("Placements") {
                        HStack {
                            Text("Individual")
                            Spacer()
                            TextField("—", text: $individualPlacementText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                        }

                        HStack {
                            Text("Team")
                            Spacer()
                            TextField("—", text: $teamPlacementText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                        }
                    }
                }

                // Total
                Section("Total") {
                    HStack {
                        Text("Total Points")
                            .font(.headline)
                        Spacer()
                        Text(calculateTotalDisplay())
                            .font(.headline)
                            .foregroundStyle(AppColors.primary)
                    }
                }
            }
            .navigationTitle(isTetrathlon ? "Tetrathlon Results" : "Triathlon Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveResults() }
                }
            }
            .onAppear { loadExistingResults() }
        }
    }

    private func loadExistingResults() {
        if let score = competition.shootingScore {
            shootingScoreText = "\(score)"
        }

        if let time = competition.swimmingTime {
            swimMinutes = Int(time) / 60
            swimSeconds = Int(time) % 60
            swimHundredths = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        }

        // Load swimming distance - try to infer pool length and lengths
        if let distance = competition.swimmingDistance {
            // Try common pool lengths to find a match
            let poolLengths: [Double] = [25, 20, 33, 50]
            for pool in poolLengths {
                let lengths = distance / pool
                if lengths == lengths.rounded() && lengths >= 1 && lengths <= 20 {
                    poolLength = pool
                    swimLengths = Int(lengths)
                    break
                }
            }
            // If no exact match found, default to 25m pool and calculate lengths
            if swimDistance != distance {
                poolLength = 25
                swimLengths = max(1, Int((distance / 25).rounded()))
            }
        }

        if let time = competition.runningTime {
            runMinutes = Int(time) / 60
            runSeconds = Int(time) % 60
        }

        if let penalties = competition.ridingScore {
            ridingPenalties = String(format: "%.1f", penalties)
        }

        if let individual = competition.individualPlacement {
            individualPlacementText = "\(individual)"
        }

        if let team = competition.teamPlacement {
            teamPlacementText = "\(team)"
        }
    }

    private func calculateTotalDisplay() -> String {
        var total: Double = 0
        var hasAny = false

        if showDiscipline(.shooting), let score = Int(shootingScoreText) {
            total += PonyClubScoringService.calculateShootingPoints(rawScore: score)
            hasAny = true
        }

        let swimTime = Double(swimMinutes * 60 + swimSeconds) + Double(swimHundredths) / 100.0
        if showDiscipline(.swimming), swimTime > 0 {
            total += PonyClubScoringService.calculateSwimmingPoints(timeInSeconds: swimTime, distanceMeters: swimDistance)
            hasAny = true
        }

        let runTime = Double(runMinutes * 60 + runSeconds)
        if showDiscipline(.running), runTime > 0 {
            total += PonyClubScoringService.calculateRunningPoints(timeInSeconds: runTime)
            hasAny = true
        }

        if showDiscipline(.riding), let penalties = Double(ridingPenalties) {
            total += PonyClubScoringService.calculateRidingPoints(penalties: penalties)
            hasAny = true
        }

        return hasAny ? String(format: "%.0f", total) : "—"
    }

    private func saveResults() {
        // Save raw results based on which disciplines are included
        if showDiscipline(.shooting) {
            competition.shootingScore = Int(shootingScoreText)
        }

        if showDiscipline(.swimming) {
            competition.swimmingDistance = swimDistance
            let swimTime = Double(swimMinutes * 60 + swimSeconds) + Double(swimHundredths) / 100.0
            competition.swimmingTime = swimTime > 0 ? swimTime : nil
        }

        if showDiscipline(.running) {
            let runTime = Double(runMinutes * 60 + runSeconds)
            competition.runningTime = runTime > 0 ? runTime : nil
        }

        if showDiscipline(.riding) {
            competition.ridingScore = Double(ridingPenalties)
        }

        // Calculate and save points for included disciplines
        if showDiscipline(.shooting), let score = competition.shootingScore {
            competition.shootingPoints = PonyClubScoringService.calculateShootingPoints(rawScore: score)
        }

        if showDiscipline(.swimming), let time = competition.swimmingTime, let distance = competition.swimmingDistance {
            competition.swimmingPoints = PonyClubScoringService.calculateSwimmingPoints(timeInSeconds: time, distanceMeters: distance)
        }

        if showDiscipline(.running), let time = competition.runningTime {
            competition.runningPoints = PonyClubScoringService.calculateRunningPoints(timeInSeconds: time)
        }

        if showDiscipline(.riding), let penalties = competition.ridingScore {
            competition.ridingPoints = PonyClubScoringService.calculateRidingPoints(penalties: penalties)
        }

        // Calculate total - sum up only included disciplines
        var total: Double = 0
        var hasAllResults = true

        if showDiscipline(.shooting) {
            if let pts = competition.shootingPoints {
                total += pts
            } else {
                hasAllResults = false
            }
        }

        if showDiscipline(.swimming) {
            if let pts = competition.swimmingPoints {
                total += pts
            } else {
                hasAllResults = false
            }
        }

        if showDiscipline(.running) {
            if let pts = competition.runningPoints {
                total += pts
            } else {
                hasAllResults = false
            }
        }

        if showDiscipline(.riding) {
            if let pts = competition.ridingPoints {
                total += pts
            } else {
                hasAllResults = false
            }
        }

        if total > 0 {
            competition.storedTotalPoints = total
        }

        // Save placements (Triathlon only)
        if !isTetrathlon {
            competition.individualPlacement = Int(individualPlacementText)
            competition.teamPlacement = Int(teamPlacementText)
        }

        // Mark as completed if all included discipline results are entered
        competition.isCompleted = hasAllResults && total > 0

        dismiss()
    }
}

#Preview {
    VStack {
        // Preview with sample data
        DisciplineScoreCardView(competition: {
            let comp = Competition()
            comp.competitionTypeRaw = "triathlon"
            comp.shootingScore = 920
            comp.shootingPoints = 920
            comp.swimmingTime = 95.5
            comp.swimmingDistance = 100
            comp.swimmingPoints = 870
            comp.runningTime = 378
            comp.runningPoints = 904
            comp.storedTotalPoints = 2694
            comp.individualPlacement = 3
            comp.teamPlacement = 1
            return comp
        }())
    }
    .padding()
}
