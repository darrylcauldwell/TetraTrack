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

    // MARK: - Singleton

    @Test func audioCoachManagerSingleton() {
        let manager1 = AudioCoachManager.shared
        let manager2 = AudioCoachManager.shared

        #expect(manager1 === manager2)
    }

    // MARK: - Default Settings

    @Test func defaultSettingsEnabled() {
        let manager = AudioCoachManager.shared

        #expect(manager.isEnabled == true)
        #expect(manager.announceRunningFormReminders == true)
    }

    @Test func defaultFormReminderInterval() {
        let manager = AudioCoachManager.shared

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
        let manager = AudioCoachManager.shared
        #expect(manager.announceGaitChanges == true)
    }

    @Test func announceDistanceMilestonesDefault() {
        let manager = AudioCoachManager.shared
        #expect(manager.announceDistanceMilestones == true)
    }

    @Test func announceHeartRateZonesDefault() {
        let manager = AudioCoachManager.shared
        #expect(manager.announceHeartRateZones == true)
    }

    @Test func announceWorkoutIntervalsDefault() {
        let manager = AudioCoachManager.shared
        #expect(manager.announceWorkoutIntervals == true)
    }

    // MARK: - Milestone Intervals

    @Test func defaultDistanceMilestone() {
        let manager = AudioCoachManager.shared

        #expect(manager.distanceMilestoneKm == 1.0)
    }

    @Test func defaultTimeMilestone() {
        let manager = AudioCoachManager.shared

        #expect(manager.timeMilestoneMinutes == 15)
    }

    // MARK: - Volume and Speech Rate

    @Test func defaultVolume() {
        let manager = AudioCoachManager.shared

        #expect(manager.volume == 0.8)
    }

    @Test func defaultSpeechRate() {
        let manager = AudioCoachManager.shared

        #expect(manager.speechRate == 0.5)
    }
}
