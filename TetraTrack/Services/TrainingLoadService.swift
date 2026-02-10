//
//  TrainingLoadService.swift
//  TetraTrack
//
//  Training load tracking with CTL/ATL/TSB (Performance Management Chart)
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Training Load Service

@Observable
final class TrainingLoadService {

    // MARK: - Types

    struct DailyTSS: Identifiable {
        let id = UUID()
        let date: Date
        var ridingTSS: Double = 0
        var runningTSS: Double = 0
        var swimmingTSS: Double = 0
        var shootingTSS: Double = 0

        var totalTSS: Double {
            ridingTSS + runningTSS + swimmingTSS + shootingTSS
        }
    }

    struct PMCData: Identifiable {
        let id = UUID()
        let date: Date
        let ctl: Double  // Chronic Training Load (fitness)
        let atl: Double  // Acute Training Load (fatigue)
        let tsb: Double  // Training Stress Balance (form)
    }

    enum FormStatus: String {
        case fresh = "Fresh"
        case optimal = "Optimal"
        case fatigued = "Fatigued"
        case overreaching = "Overreaching"

        var color: Color {
            switch self {
            case .fresh: return .blue
            case .optimal: return .green
            case .fatigued: return .orange
            case .overreaching: return .red
            }
        }

        var icon: String {
            switch self {
            case .fresh: return "battery.100"
            case .optimal: return "bolt.fill"
            case .fatigued: return "battery.25"
            case .overreaching: return "exclamationmark.triangle.fill"
            }
        }
    }

    // MARK: - Constants

    private static let ctlDays: Double = 42  // Chronic (fitness) time constant
    private static let atlDays: Double = 7   // Acute (fatigue) time constant

    // MARK: - Computation

    /// Compute daily TSS from all session types
    static func computeDailyTSS(
        rides: [Ride],
        runs: [RunningSession],
        swims: [SwimmingSession],
        shoots: [ShootingSession],
        days: Int = 90
    ) -> [DailyTSS] {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())

        var dailyMap: [Date: DailyTSS] = [:]

        // Initialize all days
        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: endDate) else { continue }
            let day = calendar.startOfDay(for: date)
            dailyMap[day] = DailyTSS(date: day)
        }

        // Riding TSS (MET-based)
        for ride in rides {
            let day = calendar.startOfDay(for: ride.startDate)
            guard dailyMap[day] != nil else { continue }
            let hours = ride.totalDuration / 3600.0
            guard hours > 0 else { continue }
            // MET approximation: use default riding MET of 4.0
            let met = 4.0
            let tss = hours * pow(met / 5.0, 2) * 100
            dailyMap[day]?.ridingTSS += tss
        }

        // Running TSS (hrTSS)
        for run in runs {
            let day = calendar.startOfDay(for: run.startDate)
            guard dailyMap[day] != nil else { continue }
            let hours = run.totalDuration / 3600.0
            guard hours > 0 else { continue }
            if run.averageHeartRate > 0 {
                let maxHR = max(Double(run.maxHeartRate), 190.0)
                let lthr = 0.85 * maxHR
                let intensityFactor = Double(run.averageHeartRate) / lthr
                dailyMap[day]?.runningTSS += hours * pow(intensityFactor, 2) * 100
            } else {
                // Duration-based fallback
                dailyMap[day]?.runningTSS += hours * 60  // ~60 TSS/hour default
            }
        }

        // Swimming TSS (hrTSS or duration-based)
        for swim in swims {
            let day = calendar.startOfDay(for: swim.startDate)
            guard dailyMap[day] != nil else { continue }
            let hours = swim.totalDuration / 3600.0
            guard hours > 0 else { continue }
            if swim.averageHeartRate > 0 {
                let maxHR = max(Double(swim.maxHeartRate), 190.0)
                let lthr = 0.85 * maxHR
                let intensityFactor = Double(swim.averageHeartRate) / lthr
                dailyMap[day]?.swimmingTSS += hours * pow(intensityFactor, 2) * 100
            } else {
                dailyMap[day]?.swimmingTSS += hours * 50  // ~50 TSS/hour default
            }
        }

        // Shooting TSS (duration-based, low intensity)
        for shoot in shoots {
            let day = calendar.startOfDay(for: shoot.startDate)
            guard dailyMap[day] != nil else { continue }
            let hours = shoot.totalDuration / 3600.0
            guard hours > 0 else { continue }
            dailyMap[day]?.shootingTSS += hours * 20  // ~20 TSS/hour
        }

        return dailyMap.values.sorted { $0.date < $1.date }
    }

    /// Compute PMC (CTL/ATL/TSB) from daily TSS values
    static func computePMC(dailyTSS: [DailyTSS]) -> [PMCData] {
        guard !dailyTSS.isEmpty else { return [] }

        let sorted = dailyTSS.sorted { $0.date < $1.date }
        var pmc: [PMCData] = []
        var ctl: Double = 0
        var atl: Double = 0

        let ctlDecay = exp(-1.0 / ctlDays)
        let atlDecay = exp(-1.0 / atlDays)

        for day in sorted {
            ctl = ctl * ctlDecay + day.totalTSS * (1 - ctlDecay)
            atl = atl * atlDecay + day.totalTSS * (1 - atlDecay)
            let tsb = ctl - atl

            pmc.append(PMCData(
                date: day.date,
                ctl: ctl,
                atl: atl,
                tsb: tsb
            ))
        }

        return pmc
    }

    /// Get current form status from TSB
    static func formStatus(tsb: Double) -> FormStatus {
        switch tsb {
        case 15...: return .fresh
        case 0..<15: return .optimal
        case -15..<0: return .fatigued
        default: return .overreaching
        }
    }

    /// Weekly load summary per discipline
    static func weeklyLoadSummary(dailyTSS: [DailyTSS], weeks: Int = 8) -> [(week: String, riding: Double, running: Double, swimming: Double, shooting: Double)] {
        let calendar = Calendar.current
        var weeklyData: [(week: String, riding: Double, running: Double, swimming: Double, shooting: Double)] = []

        let endDate = calendar.startOfDay(for: Date())

        for weekOffset in 0..<weeks {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: endDate) else { continue }
            guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { continue }

            let weekDays = dailyTSS.filter { $0.date >= weekStart && $0.date < weekEnd }

            let label = "W\(weeks - weekOffset)"
            weeklyData.append((
                week: label,
                riding: weekDays.reduce(0) { $0 + $1.ridingTSS },
                running: weekDays.reduce(0) { $0 + $1.runningTSS },
                swimming: weekDays.reduce(0) { $0 + $1.swimmingTSS },
                shooting: weekDays.reduce(0) { $0 + $1.shootingTSS }
            ))
        }

        return weeklyData.reversed()
    }
}
