//
//  HorseStatisticsManager.swift
//  TrackRide
//
//  Statistics calculations for individual horses including workload tracking

import Foundation

// MARK: - Horse Statistics

struct HorseStatistics: GaitTimeTracking {
    // Totals
    var totalRides: Int = 0
    var totalDistance: Double = 0  // meters
    var totalDuration: TimeInterval = 0  // seconds
    var totalElevationGain: Double = 0  // meters

    // Averages
    var averageDistance: Double = 0
    var averageDuration: TimeInterval = 0
    var averageSpeed: Double = 0  // m/s

    // Gait totals (GaitTimeTracking conformance)
    var totalWalkTime: TimeInterval = 0
    var totalTrotTime: TimeInterval = 0
    var totalCanterTime: TimeInterval = 0
    var totalGallopTime: TimeInterval = 0

    // This period
    var ridesThisWeek: Int = 0
    var ridesThisMonth: Int = 0

    // MARK: - Formatted Values

    var formattedTotalDistance: String {
        totalDistance.formattedDistance
    }

    var formattedTotalDuration: String {
        totalDuration.formattedDuration
    }

    var formattedAverageDistance: String {
        averageDistance.formattedDistance
    }

    var formattedAverageDuration: String {
        averageDuration.formattedDuration
    }

    var formattedAverageSpeed: String {
        averageSpeed.formattedSpeed
    }

    // gaitBreakdown is provided by GaitTimeTracking protocol extension
}

// MARK: - Workload Level

enum WorkloadLevel: String, CaseIterable {
    case rest = "Rest"
    case light = "Light"
    case moderate = "Moderate"
    case heavy = "Heavy"
    case overworked = "Overworked"

    var color: String {
        switch self {
        case .rest: return "secondary"
        case .light: return "success"
        case .moderate: return "primary"
        case .heavy: return "warning"
        case .overworked: return "error"
        }
    }

    var icon: String {
        switch self {
        case .rest: return "moon.zzz"
        case .light: return "leaf"
        case .moderate: return "figure.walk"
        case .heavy: return "flame"
        case .overworked: return "exclamationmark.triangle"
        }
    }
}

// MARK: - Workload Data

struct WorkloadData {
    var level: WorkloadLevel = .rest
    var last7DaysRides: Int = 0
    var last7DaysDuration: TimeInterval = 0
    var last7DaysDistance: Double = 0
    var daysSinceLastRide: Int?
    var recommendation: String = ""

    var formattedLast7DaysDuration: String {
        last7DaysDuration.formattedDuration
    }

    var formattedLast7DaysDistance: String {
        last7DaysDistance.formattedDistanceShort
    }
}

// MARK: - Weekly Ride Data (for charts)

struct WeeklyHorseData: Identifiable {
    let id = UUID()
    let weekStart: Date
    var rideCount: Int = 0
    var totalDistance: Double = 0
    var totalDuration: TimeInterval = 0

    var formattedWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: weekStart)
    }

    var distanceKm: Double {
        totalDistance / 1000.0
    }
}

// MARK: - Horse Statistics Manager

enum HorseStatisticsManager {

    // MARK: - Calculate Statistics

    static func calculateStatistics(for horse: Horse, period: StatisticsPeriod = .allTime) -> HorseStatistics {
        let rides = horse.activeRides.filter { $0.startDate >= period.startDate }

        var stats = HorseStatistics()
        stats.totalRides = rides.count

        guard !rides.isEmpty else { return stats }

        // Calculate totals
        for ride in rides {
            stats.totalDistance += ride.totalDistance
            stats.totalDuration += ride.totalDuration
            stats.totalElevationGain += ride.elevationGain

            // Gait times
            stats.totalWalkTime += ride.gaitDuration(for: .walk)
            stats.totalTrotTime += ride.gaitDuration(for: .trot)
            stats.totalCanterTime += ride.gaitDuration(for: .canter)
            stats.totalGallopTime += ride.gaitDuration(for: .gallop)
        }

        // Calculate averages
        let count = Double(rides.count)
        stats.averageDistance = stats.totalDistance / count
        stats.averageDuration = stats.totalDuration / count
        if stats.totalDuration > 0 {
            stats.averageSpeed = stats.totalDistance / stats.totalDuration
        }

        // Period counts
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        stats.ridesThisWeek = horse.activeRides.filter { $0.startDate >= weekAgo }.count
        stats.ridesThisMonth = horse.activeRides.filter { $0.startDate >= monthAgo }.count

        return stats
    }

    // MARK: - Weekly Breakdown

    static func weeklyBreakdown(for horse: Horse, weeks: Int = 8) -> [WeeklyHorseData] {
        let calendar = Calendar.current
        let now = Date()
        let rides = horse.activeRides

        // Create empty weeks
        var weeklyData: [WeeklyHorseData] = []
        for i in 0..<weeks {
            if let weekStart = calendar.date(byAdding: .weekOfYear, value: -i, to: now) {
                let startOfWeek = calendar.startOfDay(for: calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart))!)
                weeklyData.append(WeeklyHorseData(weekStart: startOfWeek))
            }
        }

        // Fill in ride data
        for ride in rides {
            let rideWeekStart = calendar.startOfDay(for: calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: ride.startDate))!)

            if let index = weeklyData.firstIndex(where: { $0.weekStart == rideWeekStart }) {
                weeklyData[index].rideCount += 1
                weeklyData[index].totalDistance += ride.totalDistance
                weeklyData[index].totalDuration += ride.totalDuration
            }
        }

        return weeklyData.reversed()  // Oldest first
    }

    // MARK: - Calculate Workload

    static func calculateWorkload(for horse: Horse) -> WorkloadData {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        let recentRides = horse.activeRides.filter { $0.startDate >= weekAgo }

        var workload = WorkloadData()
        workload.last7DaysRides = recentRides.count
        workload.last7DaysDuration = recentRides.reduce(0) { $0 + $1.totalDuration }
        workload.last7DaysDistance = recentRides.reduce(0) { $0 + $1.totalDistance }
        workload.daysSinceLastRide = horse.daysSinceLastRide

        // Determine workload level based on rides and duration in last 7 days
        // These thresholds can be adjusted
        let hoursThisWeek = workload.last7DaysDuration / 3600.0

        switch (workload.last7DaysRides, hoursThisWeek) {
        case (0, _):
            workload.level = .rest
            if let days = workload.daysSinceLastRide, days > 7 {
                workload.recommendation = "Consider a light session to maintain fitness"
            } else {
                workload.recommendation = "Rest day - recovery is important"
            }

        case (1...2, 0..<2):
            workload.level = .light
            workload.recommendation = "Light workload - good for maintenance or building up"

        case (2...3, 2..<4), (1...2, 2..<4):
            workload.level = .moderate
            workload.recommendation = "Moderate workload - well balanced"

        case (4...5, _), (_, 4..<6):
            workload.level = .heavy
            workload.recommendation = "Heavy workload - ensure adequate rest between sessions"

        case (6..., _), (_, 6...):
            workload.level = .overworked
            workload.recommendation = "Consider reducing workload to prevent fatigue"

        default:
            workload.level = .moderate
            workload.recommendation = "Moderate workload"
        }

        return workload
    }

    // MARK: - Recent Rides

    static func recentRides(for horse: Horse, limit: Int = 5) -> [Ride] {
        Array(horse.activeRides.sorted { $0.startDate > $1.startDate }.prefix(limit))
    }
}
