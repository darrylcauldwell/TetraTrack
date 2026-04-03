//
//  WalkingRoute.swift
//  TetraTrack
//
//  Saved walking route for repeat tracking and progression analysis
//

import Foundation
import SwiftData

// MARK: - Walking Route

@Model
final class WalkingRoute {
    var id: UUID = UUID()
    var name: String = ""
    var createdDate: Date = Date()
    var lastWalkedDate: Date = Date()
    var walkCount: Int = 0

    // Route geometry
    var routeDistanceMeters: Double = 0
    var startLatitude: Double = 0
    var startLongitude: Double = 0
    var endLatitude: Double = 0
    var endLongitude: Double = 0

    // Aggregate stats
    var averageDurationSeconds: Double = 0
    var bestDurationSeconds: Double = 0
    var averagePacePerKm: Double = 0
    var bestPacePerKm: Double = 0

    // Trend data (encoded [WalkingRouteTrend])
    var trendData: Data?

    // Relationship
    @Relationship(deleteRule: .cascade, inverse: \WalkingRouteAttempt.route)
    var attempts: [WalkingRouteAttempt]? = []

    init() {}

    init(name: String, startLatitude: Double, startLongitude: Double) {
        self.name = name
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
    }

    // MARK: - Computed Properties

    var sortedAttempts: [WalkingRouteAttempt] {
        (attempts ?? []).sorted { $0.date > $1.date }
    }

    var trends: [WalkingRouteTrend] {
        get {
            guard let data = trendData else { return [] }
            return (try? JSONDecoder().decode([WalkingRouteTrend].self, from: data)) ?? []
        }
        set {
            trendData = try? JSONEncoder().encode(newValue)
        }
    }

    var formattedDistance: String {
        if routeDistanceMeters >= 1000 {
            return String(format: "%.1f km", routeDistanceMeters / 1000)
        }
        return String(format: "%.0f m", routeDistanceMeters)
    }

    var formattedBestPace: String {
        guard bestPacePerKm > 0 else { return "--" }
        let minutes = Int(bestPacePerKm) / 60
        let seconds = Int(bestPacePerKm) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    /// Update aggregate stats from all attempts
    func updateAggregates() {
        let allAttempts = attempts ?? []
        guard !allAttempts.isEmpty else { return }

        walkCount = allAttempts.count
        lastWalkedDate = allAttempts.map(\.date).max() ?? Date()

        let durations = allAttempts.map(\.durationSeconds)
        averageDurationSeconds = durations.reduce(0, +) / Double(durations.count)
        bestDurationSeconds = durations.min() ?? 0

        let paces = allAttempts.map(\.pacePerKm).filter { $0 > 0 }
        if !paces.isEmpty {
            averagePacePerKm = paces.reduce(0, +) / Double(paces.count)
            bestPacePerKm = paces.min() ?? 0
        }

        // Update trend data
        trends = allAttempts.sorted { $0.date < $1.date }.map { attempt in
            WalkingRouteTrend(
                date: attempt.date,
                durationSeconds: attempt.durationSeconds,
                pacePerKm: attempt.pacePerKm,
                symmetryScore: attempt.symmetryScore,
                rhythmScore: attempt.rhythmScore,
                stabilityScore: attempt.stabilityScore
            )
        }
    }
}

// MARK: - Walking Route Trend

nonisolated struct WalkingRouteTrend: Codable, Identifiable, Sendable {
    var id: Date { date }
    let date: Date
    let durationSeconds: Double
    let pacePerKm: Double
    let symmetryScore: Double
    let rhythmScore: Double
    let stabilityScore: Double
}

// MARK: - Walking Route Comparison

nonisolated struct WalkingRouteComparison: Codable, Sendable {
    let routeId: UUID
    let routeName: String
    let attemptNumber: Int

    // Deltas vs previous attempt
    let paceDelta: Double          // seconds/km (negative = faster)
    let cadenceDelta: Double       // SPM delta
    let symmetryDelta: Double      // score delta
    let rhythmDelta: Double        // score delta
    let stabilityDelta: Double     // score delta
    let durationDelta: Double      // seconds (negative = faster)

    // Deltas vs route average
    let paceVsAverage: Double
    let durationVsAverage: Double

    var isPaceImproved: Bool { paceDelta < 0 }
    var isDurationImproved: Bool { durationDelta < 0 }
}
