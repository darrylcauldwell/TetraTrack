//
//  AudioCoachingView.swift
//  TrackRide
//
//  Settings for voice coaching across all disciplines
//

import SwiftUI
import AVFoundation

struct AudioCoachingView: View {
    @State private var audioCoach = AudioCoachManager.shared
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []

    var body: some View {
        List {
            // Main toggle
            Section {
                Toggle("Enable Voice Coaching", isOn: $audioCoach.isEnabled)
                    .onChange(of: audioCoach.isEnabled) { _, _ in
                        audioCoach.saveSettings()
                    }
            } footer: {
                Text("Voice coaching provides spoken cues during sessions for all four disciplines.")
            }

            if audioCoach.isEnabled {
                // Voice Settings
                voiceSettingsSection

                // General Announcements
                generalSection

                // Riding
                ridingSection

                // Running
                runningSection

                // Swimming
                swimmingSection

                // Shooting
                shootingSection

                // Cross-Country/Eventing
                crossCountrySection

                // Milestone Intervals
                intervalsSection
            }
        }
        .navigationTitle("Voice Coaching")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            audioCoach.loadSettings()
            availableVoices = AudioCoachManager.availableVoices(for: audioCoach.coachLanguage)
        }
    }

    // MARK: - Voice Settings Section

    private var voiceSettingsSection: some View {
        Section("Voice Settings") {
            // Coach Language Selection
            Picker("Coach Language", selection: $audioCoach.coachLanguage) {
                ForEach(CoachLanguage.allCases) { language in
                    HStack {
                        Text(language.flag)
                        Text(language.displayName)
                    }
                    .tag(language)
                }
            }
            .onChange(of: audioCoach.coachLanguage) { _, newLanguage in
                // Reset voice selection when language changes
                audioCoach.selectedVoiceIdentifier = ""
                availableVoices = AudioCoachManager.availableVoices(for: newLanguage)
                audioCoach.saveSettings()
            }

            // Voice Selection (filtered by language)
            Picker("Voice", selection: $audioCoach.selectedVoiceIdentifier) {
                Text(defaultVoiceLabel).tag("")
                ForEach(availableVoices, id: \.identifier) { voice in
                    Text(AudioCoachManager.displayName(for: voice))
                        .tag(voice.identifier)
                }
            }
            .onChange(of: audioCoach.selectedVoiceIdentifier) { _, _ in
                audioCoach.saveSettings()
            }

            // Volume
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Volume")
                    Spacer()
                    Text("\(Int(audioCoach.volume * 100))%")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $audioCoach.volume, in: 0.2...1.0, step: 0.1)
                    .onChange(of: audioCoach.volume) { _, _ in
                        audioCoach.saveSettings()
                    }
            }

            // Speech Rate
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Speech Rate")
                    Spacer()
                    Text(speechRateLabel)
                        .foregroundStyle(.secondary)
                }
                Slider(value: $audioCoach.speechRate, in: 0.3...0.7, step: 0.1)
                    .onChange(of: audioCoach.speechRate) { _, _ in
                        audioCoach.saveSettings()
                    }
            }

            // Test Button
            Button("Test Voice") {
                let testMessage = testVoiceMessage
                audioCoach.announce(testMessage)
            }
        }
    }

    /// Default voice label based on selected language
    private var defaultVoiceLabel: String {
        switch audioCoach.coachLanguage {
        case .english: return "Default (British English)"
        case .german: return "Standard (Deutsch)"
        case .french: return "Par défaut (Français)"
        }
    }

    /// Test message in the selected language
    private var testVoiceMessage: String {
        switch audioCoach.coachLanguage {
        case .english:
            return "This is how your voice coaching will sound during sessions."
        case .german:
            return "So wird dein Sprachcoaching während der Trainingseinheiten klingen."
        case .french:
            return "Voici comment sonnera votre coaching vocal pendant les séances."
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        Section {
            AnnouncementToggle(
                title: "Session Start & End",
                description: "Announce when sessions begin and complete",
                isOn: $audioCoach.announceSessionStartEnd
            )

            AnnouncementToggle(
                title: "Safety Status",
                description: "Periodic check-ins confirming tracking is active",
                isOn: $audioCoach.announceSafetyStatus
            )

            AnnouncementToggle(
                title: "Session Summaries",
                description: "Read AI-generated session summary aloud",
                isOn: $audioCoach.announceSessionSummary
            )

            AnnouncementToggle(
                title: "Heart Rate Zones",
                description: "Announce zone changes (Recovery, Endurance, Tempo, Threshold, Maximum)",
                isOn: $audioCoach.announceHeartRateZones
            )
        } header: {
            Label("General", systemImage: "speaker.wave.3")
        }
    }

    // MARK: - Riding Section

    private var ridingSection: some View {
        Section {
            AnnouncementToggle(
                title: "Gait Changes",
                description: "Announce transitions between walk, trot, canter, and gallop",
                isOn: $audioCoach.announceGaitChanges
            )

            AnnouncementToggle(
                title: "Distance Milestones",
                description: "Announce distance covered at regular intervals",
                isOn: $audioCoach.announceDistanceMilestones
            )

            AnnouncementToggle(
                title: "Time Milestones",
                description: "Announce elapsed time at regular intervals",
                isOn: $audioCoach.announceTimeMilestones
            )

            AnnouncementToggle(
                title: "Workout Intervals",
                description: "Announce interval blocks and countdowns",
                isOn: $audioCoach.announceWorkoutIntervals
            )

            AnnouncementToggle(
                title: "Biomechanics Coaching",
                description: "Real-time feedback on symmetry, rhythm, balance, impulsion, and rider stability",
                isOn: $audioCoach.announceRidingBiomechanics
            )
        } header: {
            Label("Riding", systemImage: "figure.equestrian.sports")
        } footer: {
            Text("Example: \"Cantering\" • \"Rhythm inconsistent\" • \"Excellent impulsion\"")
        }
    }

    // MARK: - Running Section

    private var runningSection: some View {
        Section {
            AnnouncementToggle(
                title: "Pace Updates",
                description: "Announce current and average pace per kilometre",
                isOn: $audioCoach.announceRunningPace
            )

            AnnouncementToggle(
                title: "Lap Completions",
                description: "Announce lap times for track running",
                isOn: $audioCoach.announceRunningLaps
            )

            AnnouncementToggle(
                title: "Virtual Pacer",
                description: "Gap status updates when racing virtual pacer",
                isOn: $audioCoach.announceVirtualPacer
            )

            AnnouncementToggle(
                title: "Cadence Feedback",
                description: "Guidance when cadence is outside optimal range",
                isOn: $audioCoach.announceCadenceFeedback
            )

            AnnouncementToggle(
                title: "Form Reminders",
                description: "Periodic running form cues and tips",
                isOn: $audioCoach.announceRunningFormReminders
            )

            AnnouncementToggle(
                title: "PB Race Coaching",
                description: "Real-time guidance when racing personal bests",
                isOn: $audioCoach.announcePBRaceCoaching
            )

            AnnouncementToggle(
                title: "Biomechanics Coaching",
                description: "Real-time feedback on asymmetry, stability, and vertical oscillation",
                isOn: $audioCoach.announceRunningBiomechanics
            )

            // Form reminder interval
            if audioCoach.announceRunningFormReminders {
                Picker("Form Reminder Interval", selection: Binding(
                    get: { Int(audioCoach.formReminderIntervalSeconds) },
                    set: { audioCoach.formReminderIntervalSeconds = TimeInterval($0); audioCoach.saveSettings() }
                )) {
                    Text("Every 3 minutes").tag(180)
                    Text("Every 5 minutes").tag(300)
                    Text("Every 10 minutes").tag(600)
                }
            }
        } header: {
            Label("Running", systemImage: "figure.run")
        } footer: {
            Text("Example: \"Pace 5:30 per kilometre\" • \"Core rotation detected\" • \"Balance your stride\"")
        }
    }

    // MARK: - Swimming Section

    private var swimmingSection: some View {
        Section {
            AnnouncementToggle(
                title: "Session Announcements",
                description: "Announce session start and completion summary",
                isOn: $audioCoach.announceSwimmingLaps
            )

            AnnouncementToggle(
                title: "Rest Intervals",
                description: "Announce rest periods between sets",
                isOn: $audioCoach.announceSwimmingRest
            )

            AnnouncementToggle(
                title: "Pace Summary",
                description: "Announce average pace at session end",
                isOn: $audioCoach.announceSwimmingPace
            )
        } header: {
            Label("Swimming", systemImage: "figure.pool.swim")
        } footer: {
            Text("Announcements play before entering and after exiting the water. Voice cues cannot be heard while swimming.")
        }
    }

    // MARK: - Shooting Section

    private var shootingSection: some View {
        Section {
            AnnouncementToggle(
                title: "Drill Feedback",
                description: "Audio cues for shooting drills and competitions",
                isOn: $audioCoach.announceShootingDrills
            )

            AnnouncementToggle(
                title: "Stance Coaching",
                description: "Real-time feedback on stance stability during aiming",
                isOn: $audioCoach.announceShootingStance
            )
        } header: {
            Label("Shooting", systemImage: "target")
        } footer: {
            Text("Example: \"Load\" • \"Excellent stability\" • \"Score 85%\"")
        }
    }

    // MARK: - Cross-Country Section

    private var crossCountrySection: some View {
        Section {
            AnnouncementToggle(
                title: "Cross-Country Timing",
                description: "Minute markers, time faults, and speeding warnings",
                isOn: $audioCoach.announceCrossCountry
            )
        } header: {
            Label("Cross-Country / Eventing", systemImage: "flag.checkered")
        } footer: {
            Text("Example: \"2 minutes approaching\" • \"Time fault warning. 5 seconds slow\"")
        }
    }

    // MARK: - Intervals Section

    private var intervalsSection: some View {
        Section("Milestone Intervals") {
            Picker("Distance", selection: $audioCoach.distanceMilestoneKm) {
                Text("Every 0.5 km").tag(0.5)
                Text("Every 1 km").tag(1.0)
                Text("Every 2 km").tag(2.0)
                Text("Every 5 km").tag(5.0)
            }
            .onChange(of: audioCoach.distanceMilestoneKm) { _, _ in
                audioCoach.saveSettings()
            }

            Picker("Time", selection: $audioCoach.timeMilestoneMinutes) {
                Text("Every 5 minutes").tag(5)
                Text("Every 10 minutes").tag(10)
                Text("Every 15 minutes").tag(15)
                Text("Every 30 minutes").tag(30)
            }
            .onChange(of: audioCoach.timeMilestoneMinutes) { _, _ in
                audioCoach.saveSettings()
            }
        }
    }

    // MARK: - Helpers

    private var speechRateLabel: String {
        if audioCoach.speechRate < 0.4 {
            return "Slow"
        } else if audioCoach.speechRate < 0.6 {
            return "Normal"
        } else {
            return "Fast"
        }
    }
}

// MARK: - Announcement Toggle Component

struct AnnouncementToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: isOn) { _, _ in
            AudioCoachManager.shared.saveSettings()
        }
    }
}

#Preview {
    NavigationStack {
        AudioCoachingView()
    }
}
