//
//  TrackRideApp.swift
//  TrackRide
//
//  Created by Darryl Cauldwell on 01/01/2026.
//

import SwiftUI
import SwiftData
import WidgetKit
import CloudKit
import os
#if os(iOS)
import UIKit
#endif

@main
struct TrackRideApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - iPad Review-Only Mode
    /// Determines the ViewContext based on device idiom.
    /// iPad operates in review-only mode with no capture capabilities.
    /// iPhone operates in full capture mode.
    private var viewContext: ViewContext {
        #if os(iOS)
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        return isIPad
            ? ViewContext.athleteReview()  // iPad is always review-only
            : ViewContext.athleteCapture() // iPhone can capture
        #else
        return ViewContext.athleteCapture() // Default for other platforms
        #endif
    }

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
            TrainingWeekFocus.self,
            RidingDrillSession.self,
            ShootingDrillSession.self,
            UnifiedDrillSession.self,
            RunningSession.self,
            SwimmingSession.self,
            ShootingSession.self,
            RunningLocationPoint.self,
            // Route planning models
            PlannedRoute.self,
            RouteWaypoint.self,
            OSMNode.self,
            DownloadedRegion.self,
            // Shooting analysis
            TargetScanAnalysis.self,
            // Skill domain tracking
            SkillDomainScore.self,
            AthleteProfile.self,
            // Family sharing models
            TrainingArtifact.self,
            SharedCompetition.self,
            SharingRelationship.self,
            PendingShareRequest.self,
        ])
        // Try CloudKit first, fall back to local-only if it fails
        // Explicitly specify the CloudKit container for sync
        let cloudKitConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.MyHorse.TrackRide")
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [cloudKitConfig])
            #if DEBUG
            print("✅ CloudKit ModelContainer created successfully")
            print("📦 Container: iCloud.MyHorse.TrackRide")
            #endif

            // Check iCloud account status asynchronously
            Task {
                await checkCloudKitStatus()
            }

            return container
        } catch {
            // CloudKit failed - log error and fall back to local-only storage
            #if DEBUG
            print("❌ CloudKit ModelContainer failed: \(error)")
            print("⚠️ Falling back to local-only storage - data will NOT sync")
            #endif

            // Notify sync status monitor about the fallback
            Task { @MainActor in
                SyncStatusMonitor.shared.setLocalOnlyMode(
                    reason: "CloudKit initialization failed: \(error.localizedDescription)"
                )

                // Also send a user notification about sync issues
                await NotificationManager.shared.sendSyncFailureNotification(
                    reason: "Your data is being stored locally only. iCloud sync is not available."
                )
            }

            let localConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )

            do {
                return try ModelContainer(for: schema, configurations: [localConfig])
            } catch {
                #if DEBUG
                print("Local ModelContainer also failed: \(error)")
                #endif
                fatalError("Could not create ModelContainer: \(error)")
            }
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
                .viewContext(viewContext)
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
                _ = await NotificationManager.shared.requestAuthorization()
                // Setup CloudKit subscriptions (handles errors internally)
                await NotificationManager.shared.setupCloudKitSubscriptions()
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
            .onOpenURL { url in
                handleIncomingURL(url)
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
            // App became active - restore download state from persistence
            // This ensures UI shows correct state if a download completed/failed while in background
            ServiceContainer.shared.routePlanning.restoreDownloadState()

            // Re-index competitions for Maps and Siri Suggestions
            indexUpcomingCompetitions()

            Log.app.info("App became active - restored download state and re-indexed competitions")

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
        ServiceContainer.shared.routePlanning.configure(with: sharedModelContainer.mainContext, container: sharedModelContainer)

        // Index upcoming competitions for Maps and Siri Suggestions
        indexUpcomingCompetitions()

        isConfigured = true
    }

    private func indexUpcomingCompetitions() {
        let context = sharedModelContainer.mainContext
        let now = Date()
        let descriptor = FetchDescriptor<Competition>(
            predicate: #Predicate<Competition> { $0.isEntered && $0.date > now },
            sortBy: [SortDescriptor(\.date)]
        )

        do {
            let competitions = try context.fetch(descriptor)
            CompetitionUserActivityService.shared.indexUpcomingCompetitions(competitions)
        } catch {
            Log.app.error("Failed to fetch competitions for indexing: \(error)")
        }
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

    private func handleIncomingURL(_ url: URL) {
        Log.app.info("Received URL: \(url)")

        // Handle CloudKit share URLs
        let sharingCoordinator = UnifiedSharingCoordinator.shared
        if sharingCoordinator.isCloudKitShareURL(url) {
            Task {
                // Store as pending request instead of auto-accepting
                // This allows the user to review and accept/decline in the app
                await storePendingShareRequest(from: url)
            }
        }
    }

    private func storePendingShareRequest(from url: URL) async {
        // SECURITY: Don't auto-accept shares. Store as pending for user review.
        Log.app.info("Storing share request as pending for user approval")

        do {
            // Fetch share metadata WITHOUT accepting to get owner info
            let (ownerID, ownerName) = try await UnifiedSharingCoordinator.shared.fetchShareMetadata(from: url)

            // Check if we already have a pending request from this owner
            if let repository = UnifiedSharingCoordinator.shared.repository {
                let hasPending = try repository.hasPendingRequest(fromOwnerID: ownerID)
                if hasPending {
                    Log.app.info("Already have pending request from \(ownerName), ignoring duplicate")
                    return
                }
            }

            // Create pending request (don't accept yet)
            await UnifiedSharingCoordinator.shared.addPendingRequest(
                ownerID: ownerID,
                ownerName: ownerName,
                shareURL: url
            )

            // Send local notification about pending request
            await NotificationManager.shared.sendPendingShareRequestNotification(from: ownerName)

            Log.app.info("Stored pending share request from \(ownerName)")

        } catch {
            Log.app.error("Failed to process share URL: \(error.localizedDescription)")

            // If we can't get metadata, still store with generic info
            await UnifiedSharingCoordinator.shared.addPendingRequest(
                ownerID: "unknown",
                ownerName: "Someone",
                shareURL: url
            )
        }
    }

    /// Check CloudKit account status and log diagnostics
    private static func checkCloudKitStatus() async {
        #if DEBUG
        let container = CKContainer(identifier: "iCloud.MyHorse.TrackRide")

        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                print("✅ iCloud account: Available")
                // Check if we can access the private database
                let privateDB = container.privateCloudDatabase
                let query = CKQuery(recordType: "CD_Ride", predicate: NSPredicate(value: true))
                do {
                    _ = try await privateDB.records(matching: query, resultsLimit: 1)
                    print("✅ CloudKit private database: Accessible")
                } catch {
                    print("⚠️ CloudKit query failed: \(error.localizedDescription)")
                    print("   This may be normal if no data exists yet")
                }
            case .noAccount:
                print("❌ iCloud account: Not signed in")
                print("   → User needs to sign into iCloud in Settings")
            case .restricted:
                print("❌ iCloud account: Restricted")
                print("   → Parental controls may be blocking iCloud")
            case .couldNotDetermine:
                print("⚠️ iCloud account: Could not determine status")
            case .temporarilyUnavailable:
                print("⚠️ iCloud account: Temporarily unavailable")
            @unknown default:
                print("⚠️ iCloud account: Unknown status")
            }
        } catch {
            print("❌ Failed to check iCloud status: \(error)")
        }
        #endif
    }
}
