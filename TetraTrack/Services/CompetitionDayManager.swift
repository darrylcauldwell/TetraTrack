//
//  CompetitionDayManager.swift
//  TetraTrack
//
//  Coordinates competition day workflow: discipline tracking,
//  HealthKit retrospective queries, and auto-completion
//

import Foundation
import SwiftUI
import CoreLocation

@Observable
final class CompetitionDayManager {
    var activeDiscipline: TriathlonDiscipline?
    var healthMetrics: [TriathlonDiscipline: CompetitionHealthMetrics] = [:]
    var isLoadingHealth = false

    private let healthKitManager = HealthKitManager.shared
    private let weatherService = WeatherService.shared

    // MARK: - Discipline Lifecycle

    func startDiscipline(_ discipline: TriathlonDiscipline) {
        activeDiscipline = discipline
    }

    func completeDiscipline(_ discipline: TriathlonDiscipline, competition: Competition) {
        activeDiscipline = nil

        // Fetch HealthKit metrics for the completed discipline
        let timeWindow = disciplineTimeWindow(discipline, competition: competition)
        if let (start, end) = timeWindow {
            fetchHealthMetrics(for: discipline, from: start, to: end)
        }

        // Check if all disciplines are complete
        checkAutoCompletion(competition)
    }

    // MARK: - HealthKit Retrospective

    func fetchHealthMetrics(for discipline: TriathlonDiscipline, from startDate: Date, to endDate: Date) {
        isLoadingHealth = true
        Task {
            let metrics = await healthKitManager.fetchCompetitionMetrics(from: startDate, to: endDate)
            await MainActor.run {
                healthMetrics[discipline] = metrics
                isLoadingHealth = false
            }
        }
    }

    /// Derive start/end time window for a discipline from competition data
    private func disciplineTimeWindow(_ discipline: TriathlonDiscipline, competition: Competition) -> (Date, Date)? {
        switch discipline {
        case .running:
            guard let start = competition.runningStartTime,
                  let time = competition.runningTime else { return nil }
            return (start, start.addingTimeInterval(time))

        case .swimming:
            guard let start = competition.swimStartTime else { return nil }
            let duration = competition.level.swimDuration
            return (start, start.addingTimeInterval(duration))

        case .shooting:
            guard let start = competition.shootingStartTime else { return nil }
            // Shooting typically takes 10-15 minutes
            return (start, start.addingTimeInterval(900))

        case .riding:
            // Riding doesn't have a dedicated start time on the model
            return nil
        }
    }

    // MARK: - Auto-Completion

    func checkAutoCompletion(_ competition: Competition) {
        let isTetrathlon = competition.competitionType == .tetrathlon

        func showDiscipline(_ discipline: TriathlonDiscipline) -> Bool {
            if isTetrathlon { return true }
            return competition.hasTriathlonDiscipline(discipline)
        }

        var hasAll = true
        if showDiscipline(.shooting) && competition.shootingPoints == nil { hasAll = false }
        if showDiscipline(.swimming) && competition.swimmingPoints == nil { hasAll = false }
        if showDiscipline(.running) && competition.runningPoints == nil { hasAll = false }
        if showDiscipline(.riding) && competition.ridingPoints == nil { hasAll = false }

        if hasAll {
            let shooting: Double = competition.shootingPoints ?? 0
            let swimming: Double = competition.swimmingPoints ?? 0
            let running: Double = competition.runningPoints ?? 0
            let riding: Double = competition.ridingPoints ?? 0
            let total = shooting + swimming + running + riding
            if total > 0 {
                competition.isCompleted = true
                competition.storedTotalPoints = total

                // Auto-fetch weather on completion
                if !competition.hasWeatherData {
                    fetchWeatherForCompletion(competition)
                }
            }
        }
    }

    private func fetchWeatherForCompletion(_ competition: Competition) {
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
                // Weather fetch failed silently - not critical
            }
        }
    }
}
