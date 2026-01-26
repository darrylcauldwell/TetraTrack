//
//  PostSessionSummaryService.swift
//  TrackRide
//
//  Generates AI-powered post-session summaries with praise and improvement suggestions
//  Includes voice notes, reads back via audio, and stores in session history
//

import Foundation

/// Post-session AI summary with praise and improvement opportunities
struct SessionSummary: Codable {
    let generatedAt: Date
    let headline: String
    let praise: [String]
    let improvements: [String]
    let keyMetrics: [String]
    let encouragement: String
    let overallRating: Int  // 1-5 stars
    let voiceNotesIncluded: [String]

    /// Full narrative text for audio readback
    var narrativeText: String {
        var text = headline + ". "

        if !praise.isEmpty {
            text += "Great work on: " + praise.joined(separator: ", ") + ". "
        }

        if !improvements.isEmpty {
            text += "Areas to focus on: " + improvements.joined(separator: ", ") + ". "
        }

        text += encouragement

        return text
    }

    /// Shorter version for quick audio summary
    var briefNarrative: String {
        var text = headline + ". "
        if let firstPraise = praise.first {
            text += "Well done on \(firstPraise). "
        }
        if let firstImprovement = improvements.first {
            text += "Next time, focus on \(firstImprovement). "
        }
        text += encouragement
        return text
    }
}

/// Service for generating and managing post-session summaries
final class PostSessionSummaryService {
    static let shared = PostSessionSummaryService()

    private init() {}

    // MARK: - Generate Summary for Ride

    /// Generate AI summary for a completed ride, incorporating voice notes
    @available(iOS 26.0, *)
    func generateRideSummary(
        ride: Ride,
        voiceNotes: [String]
    ) async throws -> SessionSummary {
        let intelligenceService = IntelligenceService.shared

        guard intelligenceService.isAvailable else {
            // Fall back to rule-based summary if AI not available
            return generateFallbackRideSummary(ride: ride, voiceNotes: voiceNotes)
        }

        // Build enhanced prompt with voice notes
        let rideSummary = try await intelligenceService.summarizeRide(ride)

        return SessionSummary(
            generatedAt: Date(),
            headline: rideSummary.headline,
            praise: rideSummary.achievements,
            improvements: rideSummary.improvements,
            keyMetrics: buildKeyMetrics(for: ride),
            encouragement: rideSummary.encouragement,
            overallRating: rideSummary.rating,
            voiceNotesIncluded: voiceNotes
        )
    }

    /// Generate fallback summary when AI is not available
    func generateFallbackRideSummary(
        ride: Ride,
        voiceNotes: [String]
    ) -> SessionSummary {
        var praise: [String] = []
        var improvements: [String] = []

        // Analyze metrics for praise
        if ride.totalDistance > 5000 {
            praise.append("covering good distance today")
        }
        if ride.totalDuration > 1800 {
            praise.append("putting in solid saddle time")
        }
        if abs(ride.turnBalancePercent - 50) < 10 {
            praise.append("maintaining excellent turn balance")
        }
        if abs(ride.leadBalancePercent - 50) < 10 {
            praise.append("working evenly on both leads")
        }
        if ride.gaitPercentage(for: .canter) > 20 {
            praise.append("getting good canter work in")
        }

        // Analyze metrics for improvements
        if abs(ride.turnBalancePercent - 50) > 20 {
            let direction = ride.turnBalancePercent > 50 ? "right" : "left"
            improvements.append("working more to the \(direction)")
        }
        if abs(ride.leadBalancePercent - 50) > 20 {
            let lead = ride.leadBalancePercent > 50 ? "right" : "left"
            improvements.append("practicing more \(lead) lead canter")
        }
        if ride.gaitPercentage(for: .walk) > 60 {
            improvements.append("adding more trot and canter work")
        }

        // Default praise if none found
        if praise.isEmpty {
            praise.append("getting out and riding")
        }

        // Build headline
        let headline: String
        switch ride.rideType {
        case .hack:
            headline = "Nice hack covering \(ride.formattedDistance)"
        case .schooling:
            headline = "Productive schooling session of \(ride.formattedDuration)"
        case .dressage:
            headline = "Focused dressage session of \(ride.formattedDuration)"
        case .crossCountry:
            headline = "Exciting cross-country session"
        }

        // Encouragement based on performance
        let encouragement: String
        if praise.count > improvements.count {
            encouragement = "Keep up the great work!"
        } else if improvements.count > praise.count {
            encouragement = "Every ride is progress. Keep at it!"
        } else {
            encouragement = "Well done, see you next time!"
        }

        // Calculate rating
        let rating = min(5, max(1, 3 + praise.count - improvements.count))

        return SessionSummary(
            generatedAt: Date(),
            headline: headline,
            praise: praise,
            improvements: improvements,
            keyMetrics: buildKeyMetrics(for: ride),
            encouragement: encouragement,
            overallRating: rating,
            voiceNotesIncluded: voiceNotes
        )
    }

    private func buildKeyMetrics(for ride: Ride) -> [String] {
        var metrics: [String] = []

        metrics.append("Distance: \(ride.formattedDistance)")
        metrics.append("Duration: \(ride.formattedDuration)")

        if ride.averageHeartRate > 0 {
            metrics.append("Avg HR: \(ride.averageHeartRate) bpm")
        }

        if ride.elevationGain > 50 {
            metrics.append("Elevation gain: \(ride.formattedElevationGain)")
        }

        // Add gait breakdown
        let gaitBreakdown = GaitType.allCases.compactMap { gait -> String? in
            let percent = ride.gaitPercentage(for: gait)
            guard percent > 5 else { return nil }
            return "\(gait.rawValue.capitalized): \(Int(percent))%"
        }.joined(separator: ", ")

        if !gaitBreakdown.isEmpty {
            metrics.append("Gaits: \(gaitBreakdown)")
        }

        return metrics
    }

    // MARK: - Generate Summary for Running Session

    func generateRunningSessionSummary(
        session: RunningSession,
        voiceNotes: [String]
    ) -> SessionSummary {
        var praise: [String] = []
        var improvements: [String] = []

        // Analyze running metrics
        if session.totalDistance > 5000 {
            praise.append("great distance today")
        }

        let avgCadence = session.averageCadence
        if avgCadence >= 170 && avgCadence <= 180 {
            praise.append("maintaining optimal cadence")
        } else if avgCadence > 0 && avgCadence < 165 {
            improvements.append("increasing your step rate")
        }

        if session.averageHeartRate > 0 && session.averageHeartRate < 160 {
            praise.append("keeping heart rate controlled")
        }

        if praise.isEmpty {
            praise.append("completing your run")
        }

        let headline = "Run complete: \(session.formattedDistance) in \(session.formattedDuration)"

        let encouragement = session.totalDistance > 5000
            ? "Strong effort today!"
            : "Every step counts. Great job getting out there!"

        let rating = min(5, max(1, 3 + praise.count - improvements.count))

        // Format pace
        let paceMinutes = Int(session.averagePace) / 60
        let paceSeconds = Int(session.averagePace) % 60
        let formattedPace = String(format: "%d:%02d", paceMinutes, paceSeconds)

        return SessionSummary(
            generatedAt: Date(),
            headline: headline,
            praise: praise,
            improvements: improvements,
            keyMetrics: [
                "Distance: \(session.formattedDistance)",
                "Duration: \(session.formattedDuration)",
                "Avg Pace: \(formattedPace)/km"
            ],
            encouragement: encouragement,
            overallRating: rating,
            voiceNotesIncluded: voiceNotes
        )
    }

    // MARK: - Generate Summary for Swimming Session

    func generateSwimmingSessionSummary(
        session: SwimmingSession,
        voiceNotes: [String]
    ) -> SessionSummary {
        var praise: [String] = []
        let improvements: [String] = []

        // Analyze swimming metrics
        let lapCount = session.lapCount
        if lapCount > 20 {
            praise.append("solid volume today")
        }

        let avgStrokesPerLap = session.averageStrokesPerLap
        if avgStrokesPerLap > 0 && avgStrokesPerLap <= 20 {
            praise.append("efficient stroke count")
        }

        let avgSwolf = session.averageSwolf
        if avgSwolf > 0 && avgSwolf < 40 {
            praise.append("good SWOLF efficiency")
        }

        if praise.isEmpty {
            praise.append("getting your swim in")
        }

        let headline = "Swim complete: \(lapCount) lengths in \(session.formattedDuration)"

        let encouragement = lapCount > 40
            ? "Impressive session!"
            : "Consistency is key. Well done!"

        let rating = min(5, max(1, 3 + praise.count - improvements.count))

        return SessionSummary(
            generatedAt: Date(),
            headline: headline,
            praise: praise,
            improvements: improvements,
            keyMetrics: [
                "Lengths: \(lapCount)",
                "Duration: \(session.formattedDuration)",
                "Total strokes: \(session.totalStrokes)"
            ],
            encouragement: encouragement,
            overallRating: rating,
            voiceNotesIncluded: voiceNotes
        )
    }

    // MARK: - Audio Readback

    /// Read the session summary aloud via AirPods
    func readSummaryAloud(_ summary: SessionSummary, brief: Bool = false) {
        let audioCoach = AudioCoachManager.shared

        if brief {
            audioCoach.announceSessionSummary(summary.briefNarrative)
        } else {
            audioCoach.announceSessionSummary(summary.narrativeText)
        }
    }
}
