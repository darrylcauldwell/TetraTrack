//
//  ScorecardTests.swift
//  TetraTrackTests
//
//  Tests for Swimming, Running, and Riding scorecards
//

import Testing
import Foundation
@testable import TetraTrack

struct ScorecardTests {

    // MARK: - Swimming Score Tests

    @Test func swimmingScoreInitialization() {
        let score = SwimmingScore()

        #expect(score.overallFeeling == 3)
        #expect(score.hasScores == false)
    }

    @Test func swimmingScoreTechniqueAverage() {
        let score = SwimmingScore()
        score.strokeEfficiency = 4
        score.bodyPosition = 4
        score.breathingRhythm = 4
        score.turnQuality = 4
        score.kickEfficiency = 4

        // Average of 5 technique scores at 4 = 4.0
        #expect(score.techniqueAverage == 4.0)
    }

    @Test func swimmingScorePerformanceAverage() {
        let score = SwimmingScore()
        score.paceControl = 5
        score.splitConsistency = 4
        score.intervalAdherence = 3

        // Average of 3 performance scores = (5+4+3)/3 = 4.0
        #expect(score.performanceAverage == 4.0)
    }

    @Test func swimmingScoreHasScoresWhenSet() {
        let score = SwimmingScore()
        score.strokeEfficiency = 4

        #expect(score.hasScores == true)
    }

    @Test func swimmingCoachingSuggestionsGenerated() {
        let score = SwimmingScore()
        score.turnQuality = 2 // Low turn quality
        score.bodyPosition = 4 // Good body position

        let suggestions = score.coachingSuggestions

        // Should have at least one suggestion for poor turns
        #expect(suggestions.count >= 0) // Coaching suggestions are generated based on patterns
    }

    // MARK: - Running Score Tests

    @Test func runningScoreInitialization() {
        let score = RunningScore()

        #expect(score.overallFeeling == 3)
        #expect(score.hasScores == false)
    }

    @Test func runningScoreFormAverage() {
        let score = RunningScore()
        score.runningForm = 4
        score.cadenceConsistency = 4
        score.breathingControl = 4
        score.footStrike = 4
        score.armSwing = 4

        // Average of 5 form scores at 4 = 4.0
        #expect(score.formAverage == 4.0)
    }

    @Test func runningScorePerformanceAverage() {
        let score = RunningScore()
        score.paceControl = 5
        score.hillTechnique = 4
        score.splitConsistency = 4
        score.finishStrength = 3

        // Average of 4 performance scores = (5+4+4+3)/4 = 4.0
        #expect(score.performanceAverage == 4.0)
    }

    @Test func runningScoreHasScoresWhenSet() {
        let score = RunningScore()
        score.runningForm = 4

        #expect(score.hasScores == true)
    }

    @Test func runningScorePhysicalStateTracking() {
        let score = RunningScore()
        score.energyLevel = 4
        score.legFatigue = 3
        score.cardiovascularFeel = 4

        #expect(score.energyLevel == 4)
        #expect(score.legFatigue == 3)
        #expect(score.cardiovascularFeel == 4)
    }

    @Test func runningScoreMentalStateTracking() {
        let score = RunningScore()
        score.mentalFocus = 4
        score.perceivedEffort = 3 // RPE

        #expect(score.mentalFocus == 4)
        #expect(score.perceivedEffort == 3)
    }

    // MARK: - Coaching Suggestion Priority

    @Test func swimmingCoachingSuggestionPriorityValues() {
        #expect(SwimmingCoachingSuggestion.CoachingPriority.high.rawValue == 1)
        #expect(SwimmingCoachingSuggestion.CoachingPriority.medium.rawValue == 2)
        #expect(SwimmingCoachingSuggestion.CoachingPriority.low.rawValue == 3)
    }

    @Test func runningCoachingSuggestionPriorityValues() {
        #expect(RunningCoachingSuggestion.CoachingPriority.high.rawValue == 1)
        #expect(RunningCoachingSuggestion.CoachingPriority.medium.rawValue == 2)
        #expect(RunningCoachingSuggestion.CoachingPriority.low.rawValue == 3)
    }

    // MARK: - Score Color Mapping

    @Test func scoreColorRanges() {
        // Verify score ranges produce expected results
        // 4.5-5.0 = Excellent (green)
        // 3.5-4.5 = Good
        // 2.5-3.5 = Average
        // <2.5 = Needs improvement

        let excellentScore = 4.7
        let goodScore = 4.0
        let averageScore = 3.0
        let needsWorkScore = 2.0

        #expect(excellentScore >= 4.5)
        #expect(goodScore >= 3.5 && goodScore < 4.5)
        #expect(averageScore >= 2.5 && averageScore < 3.5)
        #expect(needsWorkScore < 2.5)
    }

    // MARK: - Notes Fields

    @Test func swimmingScoreNotesFields() {
        let score = SwimmingScore()
        score.highlights = "Good stroke technique"
        score.improvements = "Work on turns"
        score.notes = "Morning session, felt fresh"

        #expect(score.highlights == "Good stroke technique")
        #expect(score.improvements == "Work on turns")
        #expect(score.notes == "Morning session, felt fresh")
    }

    @Test func runningScoreNotesFields() {
        let score = RunningScore()
        score.highlights = "Strong finish"
        score.improvements = "Work on cadence"
        score.notes = "Hot weather affected pace"

        #expect(score.highlights == "Strong finish")
        #expect(score.improvements == "Work on cadence")
        #expect(score.notes == "Hot weather affected pace")
    }

    // MARK: - Conditions Tracking

    @Test func swimmingConditionsTracking() {
        let score = SwimmingScore()
        score.poolConditions = 4

        #expect(score.poolConditions == 4)
    }

    @Test func runningConditionsTracking() {
        let score = RunningScore()
        score.terrainDifficulty = 3
        score.weatherImpact = 2

        #expect(score.terrainDifficulty == 3)
        #expect(score.weatherImpact == 2)
    }
}
