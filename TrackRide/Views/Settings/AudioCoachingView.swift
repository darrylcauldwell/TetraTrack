//
//  AudioCoachingView.swift
//  TrackRide
//
//  Settings for voice coaching during rides
//

import SwiftUI

struct AudioCoachingView: View {
    @State private var audioCoach = AudioCoachManager.shared

    var body: some View {
        List {
            // Main toggle
            Section {
                Toggle("Enable Voice Coaching", isOn: $audioCoach.isEnabled)
                    .onChange(of: audioCoach.isEnabled) { _, _ in
                        audioCoach.saveSettings()
                    }
            } footer: {
                Text("Voice coaching provides spoken cues during your ride for gait changes, milestones, and workout intervals.")
            }

            if audioCoach.isEnabled {
                // Voice settings
                Section("Voice Settings") {
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

                    Button("Test Voice") {
                        audioCoach.announce("This is how your voice coaching will sound during rides.")
                    }
                }

                // Announcement types
                Section("Announcements") {
                    Toggle("Gait Changes", isOn: $audioCoach.announceGaitChanges)
                        .onChange(of: audioCoach.announceGaitChanges) { _, _ in
                            audioCoach.saveSettings()
                        }

                    Toggle("Distance Milestones", isOn: $audioCoach.announceDistanceMilestones)
                        .onChange(of: audioCoach.announceDistanceMilestones) { _, _ in
                            audioCoach.saveSettings()
                        }

                    Toggle("Time Milestones", isOn: $audioCoach.announceTimeMilestones)
                        .onChange(of: audioCoach.announceTimeMilestones) { _, _ in
                            audioCoach.saveSettings()
                        }

                    Toggle("Heart Rate Zones", isOn: $audioCoach.announceHeartRateZones)
                        .onChange(of: audioCoach.announceHeartRateZones) { _, _ in
                            audioCoach.saveSettings()
                        }

                    Toggle("Workout Intervals", isOn: $audioCoach.announceWorkoutIntervals)
                        .onChange(of: audioCoach.announceWorkoutIntervals) { _, _ in
                            audioCoach.saveSettings()
                        }
                }

                // Milestone intervals
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

                // Examples
                Section("Examples") {
                    VStack(alignment: .leading, spacing: 12) {
                        ExampleAnnouncementRow(icon: "figure.equestrian.sports", text: "\"Cantering\"")
                        ExampleAnnouncementRow(icon: "point.topleft.down.to.point.bottomright.curvepath", text: "\"One kilometre\"")
                        ExampleAnnouncementRow(icon: "clock", text: "\"15 minutes\"")
                        ExampleAnnouncementRow(icon: "heart.fill", text: "\"Heart rate zone 3. Tempo\"")
                        ExampleAnnouncementRow(icon: "timer", text: "\"Interval 2. Trot for 3 minutes\"")
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Voice Coaching")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            audioCoach.loadSettings()
        }
    }

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

struct ExampleAnnouncementRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.primary)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .italic()
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        AudioCoachingView()
    }
}
