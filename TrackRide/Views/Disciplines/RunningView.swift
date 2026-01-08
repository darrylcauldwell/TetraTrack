//
//  RunningView.swift
//  TrackRide
//
//  Running discipline - 1500m trials, intervals, race predictor
//

import SwiftUI
import SwiftData
import CoreLocation
import WidgetKit
import os

struct RunningView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var activeSession: RunningSession?
    @State private var showingIntervalSetup = false
    @State private var showingPacerSetup = false
    @State private var showingTreadmillEntry = false
    @State private var activeIntervalSettings: IntervalSettings?
    @State private var activePacerSettings: PacerSettings?
    @AppStorage("selectedCompetitionLevel") private var selectedLevelRaw: String = CompetitionLevel.junior.rawValue
    @AppStorage("runningTrackMode") private var trackMode: Bool = false

    private var selectedLevel: CompetitionLevel {
        CompetitionLevel(rawValue: selectedLevelRaw) ?? .junior
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Track/GPS Mode Toggle
                HStack {
                    Text("Mode")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Mode", selection: $trackMode) {
                        Label("GPS", systemImage: "location.fill").tag(false)
                        Label("Track", systemImage: "circle.dashed").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                .padding(.horizontal, 16)

                // Run type options - row-based list
                VStack(spacing: 12) {
                    // Run button
                    RunTypeButton(
                        title: "Run",
                        icon: "figure.run",
                        color: AppColors.primary,
                        subtitle: "Free GPS run",
                        action: { startSession(type: .easy) }
                    )

                    // Virtual Pacer button
                    RunTypeButton(
                        title: "Virtual Pacer",
                        icon: "person.line.dotted.person.fill",
                        color: .cyan,
                        subtitle: "Target pace",
                        action: { showingPacerSetup = true }
                    )

                    // Interval Run button
                    RunTypeButton(
                        title: "Intervals",
                        icon: "timer",
                        color: .orange,
                        subtitle: "Training sets",
                        action: { showingIntervalSetup = true }
                    )

                    // Tetrathlon Practice button
                    RunTypeButton(
                        title: "Tetrathlon",
                        icon: "stopwatch.fill",
                        color: .purple,
                        subtitle: selectedLevel.formattedRunDistance,
                        action: { startSession(type: .timeTrial) }
                    )

                    // Treadmill button
                    RunTypeButton(
                        title: "Treadmill",
                        icon: "figure.run.treadmill",
                        color: .mint,
                        subtitle: "Manual entry",
                        action: { showingTreadmillEntry = true }
                    )
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 12)
        }
        .navigationTitle("Running")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingIntervalSetup) {
                IntervalSetupView(onStart: { settings in
                    showingIntervalSetup = false
                    startIntervalSession(settings: settings)
                })
            }
            .sheet(isPresented: $showingPacerSetup) {
                VirtualPacerSetupView(onStart: { settings in
                    showingPacerSetup = false
                    startPacerSession(settings: settings)
                })
            }
            .fullScreenCover(item: $activeSession) { session in
                RunningLiveView(
                    session: session,
                    intervalSettings: activeIntervalSettings,
                    targetDistance: session.sessionType == .timeTrial ? selectedLevel.runDistance : 0,
                    onEnd: {
                        // Check for personal best on tetrathlon
                        if session.sessionType == .timeTrial && session.totalDistance >= selectedLevel.runDistance * 0.95 {
                            RunningPersonalBests.shared.updatePersonalBest(
                                for: selectedLevel.runDistance,
                                time: session.totalDuration
                            )
                        }
                        // Save to HealthKit
                        Task {
                            let healthKit = HealthKitManager.shared
                            let _ = await healthKit.saveRunningSessionAsWorkout(session)
                        }
                        // Sync sessions to widgets
                        WidgetDataSyncService.shared.syncRecentSessions(context: modelContext)
                        activeSession = nil
                        activeIntervalSettings = nil
                        activePacerSettings = nil
                    },
                    onDiscard: {
                        // Delete without saving
                        modelContext.delete(session)
                        try? modelContext.save()
                        activeSession = nil
                        activeIntervalSettings = nil
                        activePacerSettings = nil
                    }
                )
            }
            .sheet(isPresented: $showingTreadmillEntry) {
                TreadmillEntryView(
                    onSave: { duration, distance, speed, incline in
                        saveTreadmillSession(duration: duration, distance: distance, speed: speed, incline: incline)
                    },
                    onCancel: {
                        showingTreadmillEntry = false
                    }
                )
            }
    }

    private func startSession(type: RunningSessionType) {
        let session = RunningSession(
            name: type.rawValue,
            sessionType: type,
            runMode: trackMode ? .track : .outdoor
        )
        modelContext.insert(session)
        activeSession = session
    }

    private func startIntervalSession(settings: IntervalSettings) {
        let session = RunningSession(
            name: "Interval Run",
            sessionType: .intervals,
            runMode: trackMode ? .track : .outdoor
        )
        modelContext.insert(session)
        activeIntervalSettings = settings
        activeSession = session
    }

    private func startPacerSession(settings: PacerSettings) {
        let session = RunningSession(
            name: "Virtual Pacer Run",
            sessionType: .tempo,
            runMode: trackMode ? .track : .outdoor
        )
        modelContext.insert(session)
        activePacerSettings = settings

        // Start the virtual pacer
        if settings.useTargetTime && settings.targetDistance > 0 {
            VirtualPacer.shared.start(targetTime: settings.targetTime, forDistance: settings.targetDistance)
        } else {
            VirtualPacer.shared.start(targetPace: settings.targetPace)
        }

        activeSession = session
    }

    private func saveTreadmillSession(duration: TimeInterval, distance: Double, speed: Double, incline: Double) {
        let session = RunningSession(
            name: "Treadmill",
            sessionType: .treadmill,
            runMode: .treadmill
        )
        session.manualDistance = true
        session.totalDuration = duration
        session.totalDistance = distance * 1000  // Convert km to meters
        session.endDate = Date()
        session.startDate = Date().addingTimeInterval(-duration)

        // Store speed and incline in notes or dedicated fields if available
        if speed > 0 || incline > 0 {
            var notes = [String]()
            if speed > 0 {
                notes.append(String(format: "Avg Speed: %.1f km/h", speed))
            }
            if incline > 0 {
                notes.append(String(format: "Incline: %.1f%%", incline))
            }
            session.notes = notes.joined(separator: "\n")
        }

        modelContext.insert(session)
        try? modelContext.save()

        // Save to HealthKit
        Task {
            let healthKit = HealthKitManager.shared
            let _ = await healthKit.saveRunningSessionAsWorkout(session)
        }

        // Sync sessions to widgets
        WidgetDataSyncService.shared.syncRecentSessions(context: modelContext)

        showingTreadmillEntry = false
    }
}

// Components moved to RunningComponents.swift:
// - PacerSettings, RunTypeButton, IntervalSettings, IntervalSetupView
// - VirtualPacerSetupView, RunningSettingsView, LevelPickerView
// - RunningPersonalBests, RunningPauseStopButton, RunningSessionDetailView
// - RunMiniStat, SplitRow
//
// Components moved to RunningLiveComponents.swift:
// - RunningLiveView, TreadmillLiveView, TreadmillDistanceInputView

#Preview {
    RunningView()
        .modelContainer(for: RunningSession.self, inMemory: true)
}
