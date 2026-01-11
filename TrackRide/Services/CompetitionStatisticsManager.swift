//
//  CompetitionStatisticsManager.swift
//  TrackRide
//
//  Statistics and personal bests for triathlon/tetrathlon competitions
//

import Foundation
import SwiftData

// MARK: - Competition Personal Best

struct CompetitionPB: Identifiable {
    let id = UUID()
    let discipline: String
    let value: Double
    let formattedValue: String
    let venue: String
    let date: Date
    let competition: Competition

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Discipline Trend Point

struct DisciplineTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let competition: Competition
    var shootingPoints: Double?
    var swimmingPoints: Double?
    var runningPoints: Double?
    var ridingPoints: Double?
    var totalPoints: Double?

    var formattedDate: String {
        Formatters.shortMonthDay(date)
    }
}

// MARK: - Competition Statistics

struct CompetitionStatistics {
    // Counts
    var totalCompetitions: Int = 0
    var completedCompetitions: Int = 0
    var tetrathlonCount: Int = 0
    var triathlonCount: Int = 0

    // Point totals
    var totalPoints: Double = 0
    var averageTotalPoints: Double = 0

    // Discipline averages
    var averageShootingPoints: Double = 0
    var averageSwimmingPoints: Double = 0
    var averageRunningPoints: Double = 0
    var averageRidingPoints: Double = 0

    // Personal bests (discipline-specific)
    var bestShooting: CompetitionPB?
    var bestSwimming: CompetitionPB?  // Best distance in fixed time
    var bestRunning: CompetitionPB?   // Best time
    var bestRiding: CompetitionPB?    // Lowest penalties
    var bestTotal: CompetitionPB?     // Best overall points

    // Trend data for charts
    var trendPoints: [DisciplineTrendPoint] = []

    // MARK: - Formatted Values

    var formattedAverageTotalPoints: String {
        String(format: "%.0f", averageTotalPoints)
    }

    var formattedTotalPoints: String {
        String(format: "%.0f", totalPoints)
    }

    var formattedAverageShootingPoints: String {
        String(format: "%.0f", averageShootingPoints)
    }

    var formattedAverageSwimmingPoints: String {
        String(format: "%.0f", averageSwimmingPoints)
    }

    var formattedAverageRunningPoints: String {
        String(format: "%.0f", averageRunningPoints)
    }

    var formattedAverageRidingPoints: String {
        String(format: "%.0f", averageRidingPoints)
    }
}

// MARK: - Competition Type Filter

enum CompetitionTypeFilter: String, CaseIterable {
    case all = "All"
    case tetrathlon = "Tetrathlon"
    case triathlon = "Triathlon"

    var displayName: String { rawValue }
}

// MARK: - Competition Statistics Manager

final class CompetitionStatisticsManager {

    static func calculateStatistics(
        from competitions: [Competition],
        period: StatisticsPeriod = .allTime,
        typeFilter: CompetitionTypeFilter = .all
    ) -> CompetitionStatistics {
        // Filter by period and completion status
        var filteredCompetitions = competitions.filter {
            $0.date >= period.startDate && $0.isCompleted
        }

        // Filter by competition type
        switch typeFilter {
        case .tetrathlon:
            filteredCompetitions = filteredCompetitions.filter { $0.competitionType == .tetrathlon }
        case .triathlon:
            filteredCompetitions = filteredCompetitions.filter { $0.competitionType == .triathlon }
        case .all:
            // Include both tetrathlon and triathlon
            filteredCompetitions = filteredCompetitions.filter {
                $0.competitionType == .tetrathlon || $0.competitionType == .triathlon
            }
        }

        var stats = CompetitionStatistics()
        stats.totalCompetitions = competitions.filter {
            $0.competitionType == .tetrathlon || $0.competitionType == .triathlon
        }.count
        stats.completedCompetitions = filteredCompetitions.count

        guard !filteredCompetitions.isEmpty else { return stats }

        // Counters for averaging
        var shootingPointsSum: Double = 0
        var swimmingPointsSum: Double = 0
        var runningPointsSum: Double = 0
        var ridingPointsSum: Double = 0
        var totalPointsSum: Double = 0

        var shootingCount: Int = 0
        var swimmingCount: Int = 0
        var runningCount: Int = 0
        var ridingCount: Int = 0
        var totalCount: Int = 0

        // Track personal bests in single pass
        var bestShootingScore: Int = 0
        var bestSwimmingDistance: Double = 0
        var bestRunningTime: TimeInterval = .infinity
        var bestRidingScore: Double = .infinity  // Lower is better for penalties
        var bestTotalPoints: Double = 0

        // Build trend points
        var trendPoints: [DisciplineTrendPoint] = []

        // Sort competitions by date for trend data
        let sortedCompetitions = filteredCompetitions.sorted { $0.date < $1.date }

        for competition in sortedCompetitions {
            stats.tetrathlonCount += competition.competitionType == .tetrathlon ? 1 : 0
            stats.triathlonCount += competition.competitionType == .triathlon ? 1 : 0

            var trendPoint = DisciplineTrendPoint(date: competition.date, competition: competition)

            // Shooting (higher score is better)
            if let shootingPoints = competition.shootingPoints {
                shootingPointsSum += shootingPoints
                shootingCount += 1
                trendPoint.shootingPoints = shootingPoints

                if let score = competition.shootingScore, score > bestShootingScore {
                    bestShootingScore = score
                    stats.bestShooting = CompetitionPB(
                        discipline: "Shooting",
                        value: Double(score),
                        formattedValue: "\(score) pts",
                        venue: competition.venue.isEmpty ? competition.name : competition.venue,
                        date: competition.date,
                        competition: competition
                    )
                }
            }

            // Swimming (greater distance in fixed time is better)
            if let swimmingPoints = competition.swimmingPoints {
                swimmingPointsSum += swimmingPoints
                swimmingCount += 1
                trendPoint.swimmingPoints = swimmingPoints

                if let distance = competition.swimmingDistance, distance > bestSwimmingDistance {
                    bestSwimmingDistance = distance
                    stats.bestSwimming = CompetitionPB(
                        discipline: "Swimming",
                        value: distance,
                        formattedValue: String(format: "%.0fm", distance),
                        venue: competition.venue.isEmpty ? competition.name : competition.venue,
                        date: competition.date,
                        competition: competition
                    )
                }
            }

            // Running (lower time is better)
            if let runningPoints = competition.runningPoints {
                runningPointsSum += runningPoints
                runningCount += 1
                trendPoint.runningPoints = runningPoints

                if let time = competition.runningTime, time < bestRunningTime {
                    bestRunningTime = time
                    let minutes = Int(time) / 60
                    let seconds = Int(time) % 60
                    stats.bestRunning = CompetitionPB(
                        discipline: "Running",
                        value: time,
                        formattedValue: String(format: "%d:%02d", minutes, seconds),
                        venue: competition.venue.isEmpty ? competition.name : competition.venue,
                        date: competition.date,
                        competition: competition
                    )
                }
            }

            // Riding (lower penalties is better)
            if let ridingPoints = competition.ridingPoints {
                ridingPointsSum += ridingPoints
                ridingCount += 1
                trendPoint.ridingPoints = ridingPoints

                if let penalties = competition.ridingScore, penalties < bestRidingScore {
                    bestRidingScore = penalties
                    stats.bestRiding = CompetitionPB(
                        discipline: "Riding",
                        value: penalties,
                        formattedValue: String(format: "%.0f pen", penalties),
                        venue: competition.venue.isEmpty ? competition.name : competition.venue,
                        date: competition.date,
                        competition: competition
                    )
                }
            }

            // Total points
            if let total = competition.storedTotalPoints {
                totalPointsSum += total
                totalCount += 1
                trendPoint.totalPoints = total

                if total > bestTotalPoints {
                    bestTotalPoints = total
                    stats.bestTotal = CompetitionPB(
                        discipline: "Overall",
                        value: total,
                        formattedValue: String(format: "%.0f pts", total),
                        venue: competition.venue.isEmpty ? competition.name : competition.venue,
                        date: competition.date,
                        competition: competition
                    )
                }
            }

            trendPoints.append(trendPoint)
        }

        // Calculate averages
        if shootingCount > 0 {
            stats.averageShootingPoints = shootingPointsSum / Double(shootingCount)
        }
        if swimmingCount > 0 {
            stats.averageSwimmingPoints = swimmingPointsSum / Double(swimmingCount)
        }
        if runningCount > 0 {
            stats.averageRunningPoints = runningPointsSum / Double(runningCount)
        }
        if ridingCount > 0 {
            stats.averageRidingPoints = ridingPointsSum / Double(ridingCount)
        }
        if totalCount > 0 {
            stats.totalPoints = totalPointsSum
            stats.averageTotalPoints = totalPointsSum / Double(totalCount)
        }

        stats.trendPoints = trendPoints

        return stats
    }
}
