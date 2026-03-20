//
//  AudioCoachManagerTests.swift
//  TetraTrackTests
//
//  Tests for AudioCoachManager including form reminders
//

import Testing
import Foundation
@testable import TetraTrack

@MainActor
struct AudioCoachManagerTests {

    // MARK: - Default Settings

    @Test func defaultSettingsEnabled() {
        let manager = AudioCoachManager()

        #expect(manager.isEnabled == true)
        #expect(manager.announceRunningFormReminders == true)
    }

    @Test func defaultFormReminderInterval() {
        let manager = AudioCoachManager()

        // Default is 5 minutes (300 seconds)
        #expect(manager.formReminderIntervalSeconds == 300)
    }

    // MARK: - Running Form Cues

    @Test func runningFormCueCount() {
        let allCues = AudioCoachManager.RunningFormCue.allCases

        #expect(allCues.count == 10)
    }

    @Test func runningFormCueSpokenText() {
        #expect(AudioCoachManager.RunningFormCue.shortenStride.spokenText == "Shorten your stride")
        #expect(AudioCoachManager.RunningFormCue.focusOnCore.spokenText == "Focus on your core")
        #expect(AudioCoachManager.RunningFormCue.weightOverCentre.spokenText == "Weight over centre of gravity")
        #expect(AudioCoachManager.RunningFormCue.highKnees.spokenText == "High knees")
        #expect(AudioCoachManager.RunningFormCue.lightFeet.spokenText == "Light feet")
    }

    @Test func runningFormCueTips() {
        #expect(AudioCoachManager.RunningFormCue.shortenStride.tip == "land beneath your hips")
        #expect(AudioCoachManager.RunningFormCue.focusOnCore.tip == "engage your abs")
        #expect(AudioCoachManager.RunningFormCue.highKnees.tip == "drive your knees forward")
        #expect(AudioCoachManager.RunningFormCue.lightFeet.tip == "quick and quiet footfalls")
    }

    @Test func allFormCuesHaveTips() {
        for cue in AudioCoachManager.RunningFormCue.allCases {
            #expect(cue.tip != nil)
        }
    }

    // MARK: - Running Form Issues

    @Test func runningFormIssueTypes() {
        // Verify all issue types exist
        let issues: [RunningFormIssue] = [
            .overstriding,
            .lowCadence,
            .tensionDetected
        ]

        #expect(issues.count == 3)
    }

    // MARK: - Announcement Toggle Settings

    @Test func announceGaitChangesDefault() {
        let manager = AudioCoachManager()
        #expect(manager.announceGaitChanges == true)
    }

    @Test func announceDistanceMilestonesDefault() {
        let manager = AudioCoachManager()
        #expect(manager.announceDistanceMilestones == true)
    }

    @Test func announceHeartRateZonesDefault() {
        let manager = AudioCoachManager()
        #expect(manager.announceHeartRateZones == true)
    }

    @Test func announceWorkoutIntervalsDefault() {
        let manager = AudioCoachManager()
        #expect(manager.announceWorkoutIntervals == true)
    }

    // MARK: - Milestone Intervals

    @Test func defaultDistanceMilestone() {
        let manager = AudioCoachManager()

        #expect(manager.distanceMilestoneKm == 1.0)
    }

    @Test func defaultTimeMilestone() {
        let manager = AudioCoachManager()

        #expect(manager.timeMilestoneMinutes == 15)
    }

    // MARK: - Volume and Speech Rate

    @Test func defaultVolume() {
        let manager = AudioCoachManager()

        #expect(manager.volume == 0.8)
    }

    @Test func defaultSpeechRate() {
        let manager = AudioCoachManager()

        #expect(manager.speechRate == 0.5)
    }

    // MARK: - Instance Isolation

    @Test func mutationDoesNotLeakBetweenInstances() {
        let a = AudioCoachManager()
        let b = AudioCoachManager()

        a.isEnabled = false

        #expect(a.isEnabled == false)
        #expect(b.isEnabled == true)
    }

    // MARK: - Coaching Level Presets

    @Test func applyRunningCoachingLevelSilent() {
        let manager = AudioCoachManager()

        manager.applyRunningCoachingLevel(.silent)

        #expect(manager.announceRunningPace == false)
        #expect(manager.announceRunningLaps == false)
        #expect(manager.announceSessionStartEnd == false)
        #expect(manager.announceVirtualPacer == false)
        #expect(manager.announceCadenceFeedback == false)
        #expect(manager.announcePBRaceCoaching == false)
        #expect(manager.announceRunningBiomechanics == false)
        #expect(manager.announceRunningFormReminders == false)
    }

    @Test func applyRidingCoachingLevelEssential() {
        let manager = AudioCoachManager()

        manager.applyRidingCoachingLevel(.essential)

        #expect(manager.announceGaitChanges == false)
        #expect(manager.announceDistanceMilestones == true)
        #expect(manager.announceTimeMilestones == false)
        #expect(manager.announceHeartRateZones == false)
        #expect(manager.announceWorkoutIntervals == false)
        #expect(manager.announceRidingBiomechanics == false)
        #expect(manager.announceCrossCountry == true)
    }
}
