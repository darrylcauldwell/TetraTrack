//
//  ShootingCompetitionDayView.swift
//  TetraTrack
//
//  Competition day shooting entry - scan target cards or enter score manually
//

import SwiftUI
import CoreLocation

struct ShootingCompetitionDayView: View {
    @Bindable var competition: Competition
    let onDismiss: () -> Void

    @State private var mode: EntryMode = .choose
    @State private var manualScoreText: String = ""
    @State private var showingScanView = false

    enum EntryMode {
        case choose
        case manual
        case scan
    }

    private var manualScore: Int? {
        guard let value = Int(manualScoreText), value >= 0, value <= 100 else { return nil }
        // Round to nearest even
        return (value / 2) * 2
    }

    private var calculatedPoints: Double? {
        if let existing = competition.shootingScore {
            return PonyClubScoringService.calculateShootingPoints(rawScore: existing)
        }
        guard let score = manualScore else { return nil }
        return PonyClubScoringService.calculateShootingPoints(rawScore: score * 10)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Show existing result if already entered
                    if let score = competition.shootingScore {
                        existingResultView(score: score)
                    } else {
                        switch mode {
                        case .choose:
                            chooseEntryMode
                        case .manual:
                            manualEntryView
                        case .scan:
                            EmptyView() // Handled by fullScreenCover
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Shooting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onDismiss() }
                }
            }
            .fullScreenCover(isPresented: $showingScanView) {
                ShootingCompetitionView(
                    sessionContext: .competition,
                    onEnd: { _ in
                        // Dismiss handled here; score bridged via onComplete
                        showingScanView = false
                    },
                    onComplete: { totalScore in
                        // Bridge score from ShootingSession to competition
                        competition.shootingScore = totalScore * 10
                        competition.shootingPoints = PonyClubScoringService.calculateShootingPoints(rawScore: totalScore * 10)
                        checkAutoCompletion()
                    }
                )
            }
        }
    }

    // MARK: - Choose Entry Mode

    private var chooseEntryMode: some View {
        VStack(spacing: 16) {
            Text("How would you like to record the shooting score?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Scan target cards option
            Button {
                showingScanView = true
                mode = .scan
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scan Target Cards")
                            .font(.headline)
                        Text("Take photos of target cards to auto-score")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .foregroundStyle(.white)
                .padding()
                .background(Color.orange)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Manual entry option
            Button {
                mode = .manual
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "hand.tap")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enter Score Manually")
                            .font(.headline)
                        Text("Type in the score from the card")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .foregroundStyle(.primary)
                .padding()
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Manual Entry

    private var manualEntryView: some View {
        VStack(spacing: 20) {
            Button {
                mode = .choose
            } label: {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.subheadline)
                .foregroundStyle(AppColors.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                Text("Shooting Score")
                    .font(.headline)

                HStack(spacing: 12) {
                    TextField("0", text: $manualScoreText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .frame(width: 120)
                        .padding()
                        .background(AppColors.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("/ 100")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                if let points = calculatedPoints {
                    VStack(spacing: 2) {
                        Text(String(format: "%.0f", points))
                            .font(.title.bold())
                            .foregroundStyle(AppColors.primary)
                        Text("points")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                saveManualScore()
            } label: {
                Label("Save Score", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(manualScore != nil ? Color.green : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(manualScore == nil)
        }
    }

    // MARK: - Existing Result

    private func existingResultView(score: Int) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Score Recorded")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(score / 10)")
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                Text("out of 100")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            if let points = calculatedPoints {
                VStack(spacing: 2) {
                    Text(String(format: "%.0f", points))
                        .font(.title.bold())
                        .foregroundStyle(AppColors.primary)
                    Text("points")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                // Allow re-entry
                competition.shootingScore = nil
                competition.shootingPoints = nil
                manualScoreText = ""
                mode = .choose
            } label: {
                Label("Re-enter Score", systemImage: "arrow.counterclockwise")
                    .font(.headline)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private func saveManualScore() {
        guard let score = manualScore else { return }
        competition.shootingScore = score * 10
        competition.shootingPoints = PonyClubScoringService.calculateShootingPoints(rawScore: score * 10)
        checkAutoCompletion()
    }

    private func checkAutoCompletion() {
        let isTetrathlon = competition.competitionType == .tetrathlon
        let showRiding = isTetrathlon
        let showShooting = isTetrathlon || competition.hasTriathlonDiscipline(.shooting)
        let showSwimming = isTetrathlon || competition.hasTriathlonDiscipline(.swimming)
        let showRunning = isTetrathlon || competition.hasTriathlonDiscipline(.running)

        var hasAll = true
        if showShooting && competition.shootingPoints == nil { hasAll = false }
        if showSwimming && competition.swimmingPoints == nil { hasAll = false }
        if showRunning && competition.runningPoints == nil { hasAll = false }
        if showRiding && competition.ridingPoints == nil { hasAll = false }

        if hasAll {
            let shooting: Double = competition.shootingPoints ?? 0
            let swimming: Double = competition.swimmingPoints ?? 0
            let running: Double = competition.runningPoints ?? 0
            let riding: Double = competition.ridingPoints ?? 0
            let total = shooting + swimming + running + riding
            if total > 0 {
                let wasCompleted = competition.isCompleted
                competition.isCompleted = true
                competition.storedTotalPoints = total

                if !wasCompleted && !competition.hasWeatherData {
                    fetchWeatherForCompletion()
                }
            }
        }
    }

    private func fetchWeatherForCompletion() {
        guard let lat = competition.venueLatitude,
              let lon = competition.venueLongitude else { return }
        let location = CLLocation(latitude: lat, longitude: lon)
        Task {
            if let weather = try? await WeatherService.shared.fetchWeather(for: location) {
                await MainActor.run { competition.weather = weather }
            }
        }
    }
}

#Preview {
    ShootingCompetitionDayView(
        competition: Competition(name: "Test", date: Date(), competitionType: .tetrathlon, level: .junior),
        onDismiss: {}
    )
}
