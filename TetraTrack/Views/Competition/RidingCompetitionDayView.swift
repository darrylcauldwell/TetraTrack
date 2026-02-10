//
//  RidingCompetitionDayView.swift
//  TetraTrack
//
//  Competition day riding penalty entry
//

import SwiftUI
import CoreLocation

struct RidingCompetitionDayView: View {
    @Bindable var competition: Competition
    let onDismiss: () -> Void

    @State private var penaltiesText: String = ""
    @State private var notes: String = ""
    @State private var hasLoaded = false

    private var penalties: Double? {
        Double(penaltiesText)
    }

    private var calculatedPoints: Double? {
        guard let p = penalties else { return nil }
        return PonyClubScoringService.calculateRidingPoints(penalties: p)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if competition.ridingScore != nil {
                        existingResultView
                    } else {
                        entryView
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Riding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onDismiss() }
                }
            }
            .onAppear { loadExisting() }
        }
    }

    // MARK: - Entry View

    private var entryView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Text("Riding Penalties")
                    .font(.headline)

                Text("Enter total jumping penalties from the score sheet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    TextField("0", text: $penaltiesText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .frame(width: 140)
                        .padding()
                        .background(AppColors.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("faults")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                // Quick penalty buttons
                HStack(spacing: 8) {
                    ForEach([0.0, 4.0, 8.0, 12.0, 20.0], id: \.self) { penalty in
                        Button {
                            penaltiesText = penalty == 0 ? "0" : String(format: "%.0f", penalty)
                        } label: {
                            Text(penalty == 0 ? "Clear" : "\(Int(penalty))")
                                .font(.subheadline.bold())
                                .foregroundStyle(penaltiesText == (penalty == 0 ? "0" : String(format: "%.0f", penalty)) ? .white : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(penaltiesText == (penalty == 0 ? "0" : String(format: "%.0f", penalty)) ? AppColors.primary : AppColors.elevatedSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
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

            // Notes
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes (optional)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("e.g., rail down at fence 4", text: $notes, axis: .vertical)
                    .lineLimit(3...5)
                    .padding()
                    .background(AppColors.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                saveResult()
            } label: {
                Label("Save Result", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(penalties != nil ? Color.green : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(penalties == nil)
        }
    }

    // MARK: - Existing Result

    private var existingResultView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Riding Result")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let p = competition.ridingScore {
                    Text(String(format: "%.1f", p))
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                    Text("penalties")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            if let points = competition.ridingPoints {
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
                competition.ridingScore = nil
                competition.ridingPoints = nil
                penaltiesText = ""
                notes = ""
            } label: {
                Label("Re-enter Result", systemImage: "arrow.counterclockwise")
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

    private func loadExisting() {
        guard !hasLoaded else { return }
        hasLoaded = true
        if let p = competition.ridingScore {
            penaltiesText = String(format: "%.1f", p)
        }
        if let n = competition.resultNotes, !n.isEmpty {
            notes = n
        }
    }

    private func saveResult() {
        guard let p = penalties else { return }
        competition.ridingScore = p
        competition.ridingPoints = PonyClubScoringService.calculateRidingPoints(penalties: p)
        if !notes.isEmpty {
            competition.resultNotes = notes
        }
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
    RidingCompetitionDayView(
        competition: Competition(name: "Test", date: Date(), competitionType: .tetrathlon, level: .junior),
        onDismiss: {}
    )
}
