//
//  DrillPerformanceCorrelator.swift
//  TetraTrack
//
//  Links drill improvements to ride/shooting performance metrics
//

import Foundation
import SwiftData

/// Result of correlation analysis between drill and performance metrics
struct CorrelationResult: Identifiable {
    let id = UUID()
    let drillMetric: String      // e.g., "coreStability.score"
    let performanceMetric: String // e.g., "balanceScore"
    let coefficient: Double      // -1 to 1 (Pearson correlation)
    let significance: Significance
    let sampleSize: Int

    enum Significance: String {
        case strong = "Strong"
        case moderate = "Moderate"
        case weak = "Weak"
        case none = "No correlation"

        init(coefficient: Double, sampleSize: Int) {
            let absCoef = abs(coefficient)
            // Require more samples for weaker correlations
            if sampleSize < 5 {
                self = .none
            } else if absCoef >= 0.7 {
                self = .strong
            } else if absCoef >= 0.4 {
                self = .moderate
            } else if absCoef >= 0.2 {
                self = .weak
            } else {
                self = .none
            }
        }
    }

    var isPositive: Bool { coefficient > 0 }

    var description: String {
        let direction = isPositive ? "positive" : "negative"
        return "\(significance.rawValue) \(direction) correlation between \(drillMetric) and \(performanceMetric)"
    }
}

/// Correlates drill performance with ride/shooting outcomes
@Observable
final class DrillPerformanceCorrelator {

    /// Generate insight about drill-performance relationships
    func generateCorrelationInsight(
        results: [CorrelationResult]
    ) -> String? {
        guard let strongest = results.first(where: { $0.significance == .strong || $0.significance == .moderate }) else {
            return nil
        }

        let drillName = strongest.drillMetric.components(separatedBy: ".").first ?? "Training"

        if strongest.isPositive {
            return "Your \(drillName) practice shows a \(strongest.significance.rawValue.lowercased()) positive correlation with \(strongest.performanceMetric). Keep it up!"
        } else {
            return "Interestingly, your \(drillName) scores have a negative correlation with \(strongest.performanceMetric). Consider varying your approach."
        }
    }

    // MARK: - Private Helpers

    /// Convert sessions to time-windowed average scores
    private func sessionsToTimeWindowedScores<S: DrillSessionProtocol>(_ sessions: [S]) -> [(Date, Double)] {
        // Group by week and average
        let calendar = Calendar.current
        var weeklyScores: [DateComponents: [Double]] = [:]

        for session in sessions {
            let weekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: session.startDate)
            weeklyScores[weekComponents, default: []].append(session.score)
        }

        return weeklyScores.compactMap { components, scores -> (Date, Double)? in
            guard let date = calendar.date(from: components) else { return nil }
            let avg = scores.reduce(0, +) / Double(scores.count)
            return (date, avg)
        }.sorted { $0.0 < $1.0 }
    }

    /// Calculate Pearson correlation coefficient between two time series
    private func calculateCorrelation(
        _ series1: [(Date, Double)],
        _ series2: [(Date, Double)]
    ) -> Double? {
        // Align series by finding overlapping time periods
        guard !series1.isEmpty, !series2.isEmpty else { return nil }

        // Simple approach: use values that fall within similar time ranges
        let values1 = series1.map(\.1)
        let values2 = series2.map(\.1)

        guard values1.count >= 3, values2.count >= 3 else { return nil }

        // Take the minimum length
        let n = min(values1.count, values2.count)
        let x = Array(values1.suffix(n))
        let y = Array(values2.suffix(n))

        return pearsonCorrelation(x, y)
    }

    /// Calculate Pearson correlation coefficient
    private func pearsonCorrelation(_ x: [Double], _ y: [Double]) -> Double? {
        guard x.count == y.count, x.count >= 3 else { return nil }

        let n = Double(x.count)
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).map { $0 * $1 }.reduce(0, +)
        let sumX2 = x.map { $0 * $0 }.reduce(0, +)
        let sumY2 = y.map { $0 * $0 }.reduce(0, +)

        let numerator = (n * sumXY) - (sumX * sumY)
        let denominator = sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY))

        guard denominator > 0.001 else { return nil }

        return numerator / denominator
    }
}

// MARK: - Protocol for Common Drill Session Properties

protocol DrillSessionProtocol {
    var startDate: Date { get }
    var score: Double { get }
}
