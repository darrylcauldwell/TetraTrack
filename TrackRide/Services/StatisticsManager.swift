//
//  StatisticsManager.swift
//  TrackRide
//

import Foundation
import SwiftData

// MARK: - Statistics Summary

struct RideStatistics: GaitTimeTracking {
    // Totals
    var totalRides: Int = 0
    var totalDistance: Double = 0  // meters
    var totalDuration: TimeInterval = 0  // seconds
    var totalElevationGain: Double = 0  // meters

    // Averages
    var averageDistance: Double = 0
    var averageDuration: TimeInterval = 0
    var averageSpeed: Double = 0  // m/s

    // Personal Records
    var longestRide: Ride?
    var fastestMaxSpeed: Ride?
    var mostElevationGain: Ride?
    var longestDuration: Ride?

    // Gait totals (GaitTimeTracking conformance)
    var totalWalkTime: TimeInterval = 0
    var totalTrotTime: TimeInterval = 0
    var totalCanterTime: TimeInterval = 0
    var totalGallopTime: TimeInterval = 0

    // Turn balance
    var totalLeftTurns: Int = 0
    var totalRightTurns: Int = 0

    // Lead balance (canter/gallop)
    var totalLeftLeadDuration: TimeInterval = 0
    var totalRightLeadDuration: TimeInterval = 0

    // Rein balance (flatwork)
    var totalLeftReinDuration: TimeInterval = 0
    var totalRightReinDuration: TimeInterval = 0

    // Quality metrics
    var averageSymmetry: Double = 0.0
    var averageRhythm: Double = 0.0

    // Transition stats
    var totalTransitions: Int = 0
    var averageTransitionQuality: Double = 0.0

    // MARK: - Formatted Values

    var formattedTotalDistance: String {
        totalDistance.formattedDistanceShort
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

    var turnBalancePercent: Int {
        let total = totalLeftTurns + totalRightTurns
        guard total > 0 else { return 50 }
        return Int((Double(totalLeftTurns) / Double(total)) * 100)
    }

    // gaitBreakdown is provided by GaitTimeTracking protocol extension

    // MARK: - Lead & Rein Balance

    var totalLeadDuration: TimeInterval {
        totalLeftLeadDuration + totalRightLeadDuration
    }

    var leadBalancePercent: Int {
        guard totalLeadDuration > 0 else { return 50 }
        return Int((totalLeftLeadDuration / totalLeadDuration) * 100)
    }

    var totalReinDuration: TimeInterval {
        totalLeftReinDuration + totalRightReinDuration
    }

    var reinBalancePercent: Int {
        guard totalReinDuration > 0 else { return 50 }
        return Int((totalLeftReinDuration / totalReinDuration) * 100)
    }

    var formattedAverageSymmetry: String {
        String(format: "%.0f%%", averageSymmetry)
    }

    var formattedAverageRhythm: String {
        String(format: "%.0f%%", averageRhythm)
    }

    var formattedTransitionQuality: String {
        String(format: "%.0f%%", averageTransitionQuality * 100)
    }
}

// MARK: - Time Period

enum StatisticsPeriod: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case allTime = "All Time"

    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: now) ?? now
        case .allTime:
            return Date.distantPast
        }
    }
}

// MARK: - Weekly Data Point

struct WeeklyDataPoint: Identifiable {
    let id = UUID()
    let weekStart: Date
    var rideCount: Int = 0
    var totalDistance: Double = 0
    var totalDuration: TimeInterval = 0

    var formattedWeek: String {
        Formatters.shortMonthDay(weekStart)
    }

    var distanceKm: Double {
        totalDistance / 1000.0
    }

    var durationHours: Double {
        totalDuration / 3600.0
    }
}

// MARK: - Weekly Trend Point (for lead/rein/quality metrics)

struct WeeklyTrendPoint: Identifiable {
    let id = UUID()
    let weekStart: Date
    var leadBalance: Double = 0.5      // 0-1 (0.5 = balanced)
    var reinBalance: Double = 0.5      // 0-1 (0.5 = balanced)
    var averageSymmetry: Double = 0.0  // 0-100
    var averageRhythm: Double = 0.0    // 0-100
    var rideCount: Int = 0

    var formattedWeek: String {
        Formatters.shortMonthDay(weekStart)
    }

    var leadBalancePercent: Int { Int(leadBalance * 100) }
    var reinBalancePercent: Int { Int(reinBalance * 100) }
}

// MARK: - Monthly Trend Point

struct MonthlyTrendPoint: Identifiable {
    let id = UUID()
    let monthStart: Date
    var leadBalance: Double = 0.5
    var reinBalance: Double = 0.5
    var averageSymmetry: Double = 0.0
    var averageRhythm: Double = 0.0
    var rideCount: Int = 0

    var formattedMonth: String {
        Formatters.monthYear(monthStart)
    }
}

// MARK: - Statistics Manager

final class StatisticsManager {

    static func calculateStatistics(from rides: [Ride], period: StatisticsPeriod = .allTime) -> RideStatistics {
        let filteredRides = rides.filter { $0.startDate >= period.startDate }

        var stats = RideStatistics()
        stats.totalRides = filteredRides.count

        guard !filteredRides.isEmpty else { return stats }

        // For averaging quality metrics
        var symmetrySum: Double = 0
        var rhythmSum: Double = 0
        var qualitySum: Double = 0
        var ridesWithSymmetry: Int = 0
        var ridesWithRhythm: Int = 0
        var ridesWithTransitions: Int = 0

        // Track personal records in single pass (avoids 4 separate max() calls)
        var maxDistance: Double = 0
        var maxSpeed: Double = 0
        var maxElevation: Double = 0
        var maxDuration: TimeInterval = 0

        // Calculate totals and find records in single pass
        for ride in filteredRides {
            stats.totalDistance += ride.totalDistance
            stats.totalDuration += ride.totalDuration
            stats.totalElevationGain += ride.elevationGain
            stats.totalLeftTurns += ride.leftTurns
            stats.totalRightTurns += ride.rightTurns

            // Gait times
            stats.totalWalkTime += ride.gaitDuration(for: .walk)
            stats.totalTrotTime += ride.gaitDuration(for: .trot)
            stats.totalCanterTime += ride.gaitDuration(for: .canter)
            stats.totalGallopTime += ride.gaitDuration(for: .gallop)

            // Lead tracking
            stats.totalLeftLeadDuration += ride.leftLeadDuration
            stats.totalRightLeadDuration += ride.rightLeadDuration

            // Rein tracking
            stats.totalLeftReinDuration += ride.leftReinDuration
            stats.totalRightReinDuration += ride.rightReinDuration

            // Quality metrics
            if ride.overallSymmetry > 0 {
                symmetrySum += ride.overallSymmetry
                ridesWithSymmetry += 1
            }
            if ride.overallRhythm > 0 {
                rhythmSum += ride.overallRhythm
                ridesWithRhythm += 1
            }

            // Transition stats
            stats.totalTransitions += ride.transitionCount
            if ride.transitionCount > 0 {
                qualitySum += ride.averageTransitionQuality
                ridesWithTransitions += 1
            }

            // Track personal records during iteration (single pass instead of 4x max())
            if ride.totalDistance > maxDistance {
                maxDistance = ride.totalDistance
                stats.longestRide = ride
            }
            if ride.maxSpeed > maxSpeed {
                maxSpeed = ride.maxSpeed
                stats.fastestMaxSpeed = ride
            }
            if ride.elevationGain > maxElevation {
                maxElevation = ride.elevationGain
                stats.mostElevationGain = ride
            }
            if ride.totalDuration > maxDuration {
                maxDuration = ride.totalDuration
                stats.longestDuration = ride
            }
        }

        // Calculate averages
        let count = Double(filteredRides.count)
        stats.averageDistance = stats.totalDistance / count
        stats.averageDuration = stats.totalDuration / count
        if stats.totalDuration > 0 {
            stats.averageSpeed = stats.totalDistance / stats.totalDuration
        }

        // Quality averages
        if ridesWithSymmetry > 0 {
            stats.averageSymmetry = symmetrySum / Double(ridesWithSymmetry)
        }
        if ridesWithRhythm > 0 {
            stats.averageRhythm = rhythmSum / Double(ridesWithRhythm)
        }
        if ridesWithTransitions > 0 {
            stats.averageTransitionQuality = qualitySum / Double(ridesWithTransitions)
        }

        return stats
    }

    static func weeklyBreakdown(from rides: [Ride], weeks: Int = 8) -> [WeeklyDataPoint] {
        let calendar = Calendar.current
        let now = Date()

        // Create empty weeks with index lookup map for O(1) access
        var weeklyData: [WeeklyDataPoint] = []
        var weekIndexMap: [Date: Int] = [:]  // O(1) lookup instead of firstIndex O(n)

        for i in 0..<weeks {
            if let weekStart = calendar.date(byAdding: .weekOfYear, value: -i, to: now) {
                let startOfWeek = calendar.startOfDay(for: calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart))!)
                weekIndexMap[startOfWeek] = weeklyData.count
                weeklyData.append(WeeklyDataPoint(weekStart: startOfWeek))
            }
        }

        // Fill in ride data using O(1) dictionary lookup
        for ride in rides {
            let rideWeekStart = calendar.startOfDay(for: calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: ride.startDate))!)

            if let index = weekIndexMap[rideWeekStart] {
                weeklyData[index].rideCount += 1
                weeklyData[index].totalDistance += ride.totalDistance
                weeklyData[index].totalDuration += ride.totalDuration
            }
        }

        return weeklyData.reversed()  // Oldest first
    }

    static func monthlyTotals(from rides: [Ride], months: Int = 12) -> [(month: String, distance: Double, rides: Int)] {
        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        var monthlyData: [(month: String, distance: Double, rides: Int)] = []

        for i in 0..<months {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
            let monthName = formatter.string(from: monthDate)
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))!
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!

            let monthRides = rides.filter { $0.startDate >= monthStart && $0.startDate < monthEnd }
            let totalDistance = monthRides.reduce(0) { $0 + $1.totalDistance }

            monthlyData.append((monthName, totalDistance / 1000.0, monthRides.count))
        }

        return monthlyData.reversed()
    }

    // MARK: - Quality Trends

    static func weeklyTrends(from rides: [Ride], weeks: Int = 8) -> [WeeklyTrendPoint] {
        let calendar = Calendar.current
        let now = Date()

        // Create empty weeks
        var weeklyData: [WeeklyTrendPoint] = []
        for i in 0..<weeks {
            if let weekStart = calendar.date(byAdding: .weekOfYear, value: -i, to: now) {
                let startOfWeek = calendar.startOfDay(for: calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart))!)
                weeklyData.append(WeeklyTrendPoint(weekStart: startOfWeek))
            }
        }

        // Fill in ride data
        for ride in rides {
            let rideWeekStart = calendar.startOfDay(for: calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: ride.startDate))!)

            if let index = weeklyData.firstIndex(where: { $0.weekStart == rideWeekStart }) {
                weeklyData[index].rideCount += 1

                // Accumulate for averaging
                let currentCount = weeklyData[index].rideCount

                // Lead balance (running average)
                let rideLeadBalance = ride.leadBalance
                weeklyData[index].leadBalance = ((weeklyData[index].leadBalance * Double(currentCount - 1)) + rideLeadBalance) / Double(currentCount)

                // Rein balance (running average)
                let rideReinBalance = ride.reinBalance
                weeklyData[index].reinBalance = ((weeklyData[index].reinBalance * Double(currentCount - 1)) + rideReinBalance) / Double(currentCount)

                // Symmetry (running average)
                if ride.overallSymmetry > 0 {
                    weeklyData[index].averageSymmetry = ((weeklyData[index].averageSymmetry * Double(currentCount - 1)) + ride.overallSymmetry) / Double(currentCount)
                }

                // Rhythm (running average)
                if ride.overallRhythm > 0 {
                    weeklyData[index].averageRhythm = ((weeklyData[index].averageRhythm * Double(currentCount - 1)) + ride.overallRhythm) / Double(currentCount)
                }
            }
        }

        return weeklyData.reversed()  // Oldest first
    }

    static func monthlyTrends(from rides: [Ride], months: Int = 12) -> [MonthlyTrendPoint] {
        let calendar = Calendar.current
        let now = Date()

        var monthlyData: [MonthlyTrendPoint] = []

        for i in 0..<months {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))!
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!

            let monthRides = rides.filter { $0.startDate >= monthStart && $0.startDate < monthEnd }

            var trend = MonthlyTrendPoint(monthStart: monthStart)
            trend.rideCount = monthRides.count

            guard !monthRides.isEmpty else {
                monthlyData.append(trend)
                continue
            }

            // Calculate averages for this month
            var leadBalanceSum: Double = 0
            var reinBalanceSum: Double = 0
            var symmetrySum: Double = 0
            var rhythmSum: Double = 0
            var symmetryCount: Int = 0
            var rhythmCount: Int = 0

            for ride in monthRides {
                leadBalanceSum += ride.leadBalance
                reinBalanceSum += ride.reinBalance

                if ride.overallSymmetry > 0 {
                    symmetrySum += ride.overallSymmetry
                    symmetryCount += 1
                }
                if ride.overallRhythm > 0 {
                    rhythmSum += ride.overallRhythm
                    rhythmCount += 1
                }
            }

            trend.leadBalance = leadBalanceSum / Double(monthRides.count)
            trend.reinBalance = reinBalanceSum / Double(monthRides.count)
            if symmetryCount > 0 {
                trend.averageSymmetry = symmetrySum / Double(symmetryCount)
            }
            if rhythmCount > 0 {
                trend.averageRhythm = rhythmSum / Double(rhythmCount)
            }

            monthlyData.append(trend)
        }

        return monthlyData.reversed()
    }
}
