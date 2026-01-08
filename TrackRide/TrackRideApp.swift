//
//  TrackRideApp.swift
//  TrackRide
//
//  Created by Darryl Cauldwell on 01/01/2026.
//

import SwiftUI
import SwiftData
import WidgetKit
import os

@main
struct TrackRideApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Ride.self,
            LocationPoint.self,
            GaitSegment.self,
            ReinSegment.self,
            GaitTransition.self,
            LiveTrackingSession.self,
            FamilyMember.self,
            RiderProfile.self,
            Horse.self,
            Competition.self,
            CompetitionTask.self,
            FlatworkExercise.self,
            PoleworkExercise.self,
            TrainingStreak.self,
            ScheduledWorkout.self,
            RunningLocationPoint.self,
            // Route planning models
            PlannedRoute.self,
            RouteWaypoint.self,
            OSMNode.self,
            DownloadedRegion.self,
        ])
        // TODO: RE-ENABLE CLOUDKIT FOR PRODUCTION
        // When you have a paid Apple Developer account:
        // 1. Change cloudKitDatabase: .none → .automatic
        // 2. Restore TrackRide.entitlements from TrackRide.entitlements.cloudkit-backup
        // 3. Re-add setupCloudKitSubscriptions() call in .task below
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none  // Disabled for personal development team
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var locationManager = LocationManager()
    @State private var rideTracker: RideTracker?
    @State private var isConfigured = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(locationManager)
                .environment(rideTracker)
                .onAppear {
                    Log.app.info("ContentView.onAppear - rideTracker is \(rideTracker == nil ? "nil" : "set")")
                    // Create RideTracker on first appear if needed
                    if rideTracker == nil {
                        Log.app.info("Creating RideTracker...")
                        let tracker = RideTracker(locationManager: locationManager)
                        rideTracker = tracker
                        Log.app.info("RideTracker created")
                    }
                    configureAppIfNeeded()
                }
                .task {
                // Request notification permissions
                await NotificationManager.shared.requestAuthorization()
                // TODO: Re-enable when CloudKit is available
                // await NotificationManager.shared.setupCloudKitSubscriptions()
            }
            .onReceive(NotificationCenter.default.publisher(for: .startRideFromSiri)) { notification in
                handleStartRide(notification: notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: .stopRideFromSiri)) { _ in
                rideTracker?.stopRide()
            }
            .onReceive(NotificationCenter.default.publisher(for: .pauseRideFromSiri)) { _ in
                rideTracker?.pauseRide()
            }
            .onReceive(NotificationCenter.default.publisher(for: .resumeRideFromSiri)) { _ in
                rideTracker?.resumeRide()
            }
            .onReceive(NotificationCenter.default.publisher(for: .getStatusFromSiri)) { _ in
                announceCurrentStatus()
            }
            .onReceive(NotificationCenter.default.publisher(for: .enableAudioFromSiri)) { _ in
                setAudioCoaching(enabled: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: .disableAudioFromSiri)) { _ in
                setAudioCoaching(enabled: false)
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleAudioFromSiri)) { _ in
                toggleAudioCoaching()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(from: oldPhase, to: newPhase)
            }
        }
        .modelContainer(sharedModelContainer)
    }

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            // When app goes to background, stop any pending audio announcements
            // This prevents audio playing unexpectedly when AirPods connect
            AudioCoachManager.shared.stopSpeaking()

            // If there's no active ride, clean up any lingering location tracking
            if rideTracker?.rideState == .idle {
                locationManager.stopTracking()
            }

            Log.app.info("App entered background - cleared pending audio")

        case .inactive:
            // Stop pending audio when app becomes inactive too
            AudioCoachManager.shared.stopSpeaking()

        case .active:
            // App became active - no special handling needed
            break

        @unknown default:
            break
        }
    }

    private func configureAppIfNeeded() {
        // Only run one-time setup once
        guard !isConfigured else { return }
        guard let tracker = rideTracker else { return }

        // Configure RideTracker with model context
        tracker.configure(with: sharedModelContainer.mainContext)

        // Activate Watch connectivity
        WatchConnectivityManager.shared.activate()

        // Sync widget data on app launch
        WidgetDataSyncService.shared.syncAllWidgetData(context: sharedModelContainer.mainContext)

        // Configure route planning service
        ServiceContainer.shared.routePlanning.configure(with: sharedModelContainer.mainContext)

        isConfigured = true
    }

    private func announceCurrentStatus() {
        let audioCoach = AudioCoachManager.shared
        let fallDetectionActive = FallDetectionManager.shared.isMonitoring

        if rideTracker?.rideState == .tracking {
            audioCoach.announceSafetyStatus(fallDetectionActive: fallDetectionActive)
        } else if rideTracker?.rideState == .paused {
            audioCoach.announce("Ride is paused. Tracking will resume when you continue.")
        } else {
            audioCoach.announce("No ride in progress. Say start my ride to begin tracking.")
        }
    }

    private func setAudioCoaching(enabled: Bool) {
        let audioCoach = AudioCoachManager.shared
        audioCoach.isEnabled = enabled
        audioCoach.saveSettings()

        // Announce the change (temporarily enable to speak this message)
        if !enabled {
            audioCoach.isEnabled = true
            audioCoach.announce("Audio coaching disabled")
            // Disable after announcement plays
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                audioCoach.isEnabled = false
            }
        } else {
            audioCoach.announce("Audio coaching enabled")
        }
    }

    private func toggleAudioCoaching() {
        let audioCoach = AudioCoachManager.shared
        setAudioCoaching(enabled: !audioCoach.isEnabled)
    }

    private func handleStartRide(notification: Notification) {
        guard let tracker = rideTracker else { return }

        if let rideTypeRaw = notification.userInfo?["rideType"] as? String,
           let rideType = RideType(rawValue: rideTypeRaw) {
            tracker.selectedRideType = rideType
        }

        Task {
            await tracker.startRide()
        }
    }
}
