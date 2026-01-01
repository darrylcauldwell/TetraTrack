//
//  TetraTrackApp.swift
//  TetraTrack
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
struct TetraTrackApp: App {
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

    /// Whether the app was launched for UI testing (skips CloudKit to avoid CI crashes)
    private static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITesting")
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
            SwimmingLocationPoint.self,
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
            LinkedRiderRecord.self,
        ])

        // UI testing and CI: use in-memory local-only storage to avoid CloudKit crashes
        if isUITesting {
            Log.app.info("UI Testing mode: using in-memory local-only ModelContainer")
            let testConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            do {
                return try ModelContainer(for: schema, configurations: [testConfig])
            } catch {
                fatalError("Could not create test ModelContainer: \(error)")
            }
        }

        // Try CloudKit first, fall back to local-only if it fails
        // Explicitly specify the CloudKit container for sync
        let cloudKitConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.dev.dreamfold.TetraTrack")
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [cloudKitConfig])
            Log.app.info("CloudKit ModelContainer created successfully - Container: iCloud.dev.dreamfold.TetraTrack")

            // Check iCloud account status asynchronously
            Task {
                await checkCloudKitStatus()
            }

            return container
        } catch {
            // CloudKit failed - log error and fall back to local-only storage
            Log.app.error("CloudKit ModelContainer failed: \(error.localizedDescription) - Falling back to local-only storage")

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
                Log.app.fault("Local ModelContainer also failed: \(error.localizedDescription)")
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    @State private var locationManager = LocationManager()
    @State private var gpsTracker: GPSSessionTracker?
    @State private var rideTracker: RideTracker?
    @State private var isConfigured = false
    @State private var showShareLinkAlert = false
    @State private var shareLinkAlertMessage = ""

    // Key for persisting pending share URLs that arrive before app is ready
    private static let pendingShareURLKey = "pendingShareURLToProcess"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, LocalizationManager.shared.locale)
                .environment(locationManager)
                .environment(gpsTracker)
                .environment(rideTracker)
                .viewContext(viewContext)
                .onAppear {
                    Log.app.info("ContentView.onAppear - rideTracker is \(rideTracker == nil ? "nil" : "set")")
                    // Create GPSSessionTracker on first appear if needed
                    if gpsTracker == nil {
                        Log.app.info("Creating GPSSessionTracker...")
                        gpsTracker = GPSSessionTracker(locationManager: locationManager)
                        Log.app.info("GPSSessionTracker created")
                    }
                    // Create RideTracker on first appear if needed
                    if rideTracker == nil, let gps = gpsTracker {
                        Log.app.info("Creating RideTracker...")
                        let tracker = RideTracker(locationManager: locationManager, gpsTracker: gps)
                        rideTracker = tracker
                        Log.app.info("RideTracker created")
                    }
                    configureAppIfNeeded()
                }
                .task {
                guard !Self.isUITesting else { return }
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
            .onReceive(NotificationCenter.default.publisher(for: .didAcceptCloudKitShare)) { notification in
                handleCloudKitShareAccepted(notification: notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: .didReceiveShareURL)) { notification in
                handleShareURLNotification(notification)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb, perform: handleWebUserActivity)
            .alert("Share Link Received", isPresented: $showShareLinkAlert) {
                Button("OK") {
                    showShareLinkAlert = false
                }
            } message: {
                Text(shareLinkAlertMessage)
            }
        }
        .modelContainer(sharedModelContainer)
    }

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        let hasActiveRide = rideTracker?.rideState == .tracking || rideTracker?.rideState == .paused

        switch newPhase {
        case .background:
            // Only stop audio if there is no active ride.
            // During an active ride, audio coaching and safety announcements
            // must continue playing with the screen off.
            if !hasActiveRide {
                AudioCoachManager.shared.stopSpeaking()
            }

            // Only clean up location tracking if nothing is actively using it.
            // Running and swimming sessions also use LocationManager, not just rides.
            // Each session is responsible for stopping tracking on end/discard.
            if rideTracker?.rideState == .idle && !locationManager.isTracking {
                locationManager.stopTracking()
            }

            // Checkpoint save ride data when entering background
            if hasActiveRide {
                rideTracker?.checkpointSave()
                Log.app.info("Checkpoint save triggered for active ride entering background")
            }

            // Suspend family location refresh loop to prevent battery drain
            if !Self.isUITesting {
                UnifiedSharingCoordinator.shared.suspendWatchingForBackground()
            }

            Log.app.info("App entered background - active ride: \(hasActiveRide)")

        case .inactive:
            // Only stop audio when no ride is active
            if !hasActiveRide {
                AudioCoachManager.shared.stopSpeaking()
            }

        case .active:
            guard !Self.isUITesting else { break }

            // App became active - restore download state from persistence
            // This ensures UI shows correct state if a download completed/failed while in background
            ServiceContainer.shared.routePlanning.restoreDownloadState()

            // Resume family location refresh loop if views were watching before background
            UnifiedSharingCoordinator.shared.resumeWatchingForForeground()

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

        // Auto-generate screenshot data when launched with -screenshotMode
        if ProcessInfo.processInfo.arguments.contains("-screenshotMode") {
            ScreenshotDataGenerator.generateScreenshotData(in: sharedModelContainer.mainContext)
            try? sharedModelContainer.mainContext.save()
            Log.app.info("Screenshot mode: generated demonstration data")
        }

        // Skip CloudKit and connectivity services during UI testing
        guard !Self.isUITesting else {
            isConfigured = true
            return
        }

        // Activate Watch connectivity
        WatchConnectivityManager.shared.activate()

        // Sync widget data on app launch
        WidgetDataSyncService.shared.syncAllWidgetData(context: sharedModelContainer.mainContext)

        // Configure route planning service
        ServiceContainer.shared.routePlanning.configure(with: sharedModelContainer.mainContext, container: sharedModelContainer)

        // Configure family sharing coordinator
        UnifiedSharingCoordinator.shared.configure(with: sharedModelContainer.mainContext)

        // Initialize CloudKit schema for family sharing (creates record types in Development mode)
        Task {
            let schemaInitializer = CloudKitSchemaInitializer()
            let result = await schemaInitializer.initializeSchema()
            if result.success {
                Log.app.info("CloudKit schema initialized: \(result.recordTypesCreated.joined(separator: ", "))")
            } else {
                Log.app.warning("CloudKit schema initialization: \(result.errors.joined(separator: "; "))")
            }
        }

        // Migrate personal bests from UserDefaults to iCloud Key-Value Store
        RunningPersonalBests.migrateFromUserDefaults()
        SwimmingPersonalBests.migrateFromUserDefaults()
        ShootingPersonalBests.migrateFromUserDefaults()

        // Index upcoming competitions for Maps and Siri Suggestions
        indexUpcomingCompetitions()

        isConfigured = true

        // Process any pending share URL that arrived before app was ready
        processPendingShareURLIfNeeded()
    }

    /// Process a share URL that was persisted because the app wasn't ready when it arrived.
    /// This is a fallback for cold-launch scenarios where SceneDelegate's
    /// userDidAcceptCloudKitShareWith doesn't fire.
    private func processPendingShareURLIfNeeded() {
        guard let urlString = UserDefaults.standard.string(forKey: Self.pendingShareURLKey),
              let url = URL(string: urlString) else {
            return
        }

        Log.app.info("Found persisted share URL, processing: \(urlString)")

        // Clear the stored URL immediately to prevent reprocessing
        UserDefaults.standard.removeObject(forKey: Self.pendingShareURLKey)

        Task {
            await acceptShareFromURL(url)
        }
    }

    /// Fallback share acceptance from URL — only used for pending URLs that
    /// couldn't be processed by SceneDelegate (e.g., cold launch before scene connected).
    private func acceptShareFromURL(_ url: URL) async {
        do {
            let container = CKContainer.default()
            let metadata = try await container.shareMetadata(for: url)

            let ownerName = metadata.ownerIdentity.nameComponents?.formatted() ?? "Family Member"
            let ownerID = metadata.share.owner.userIdentity.userRecordID?.recordName ?? "unknown"

            try await container.accept(metadata)
            Log.app.info("Accepted pending share from \(ownerName)")

            await MainActor.run {
                UnifiedSharingCoordinator.shared.addLinkedRider(riderID: ownerID, name: ownerName)
                showShareLinkAlert = true
                shareLinkAlertMessage = "Connected with \(ownerName)!"
            }
        } catch {
            Log.app.error("Failed to process pending share URL: \(error)")

            let errorMsg: String
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                errorMsg = "Share not found.\n\nBoth phones must use the same build type (both Xcode or both TestFlight).\n\nYour build: \(SceneDelegate.buildEnvironmentDescription)"
            } else {
                errorMsg = "Could not process share: \(error.localizedDescription)"
            }

            await MainActor.run {
                showShareLinkAlert = true
                shareLinkAlertMessage = errorMsg
            }
        }
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
        Log.app.info("handleIncomingURL called: \(url)")

        let sharingCoordinator = UnifiedSharingCoordinator.shared
        if sharingCoordinator.isCloudKitShareURL(url) {
            // CloudKit share URLs are handled by SceneDelegate's
            // userDidAcceptCloudKitShareWith callback. We only need to
            // persist the URL as a fallback for cold-launch scenarios
            // where the SceneDelegate callback doesn't fire.
            Log.app.info("CloudKit share URL detected, deferring to SceneDelegate")

            if sharingCoordinator.repository == nil || !isConfigured {
                Log.app.info("App not fully configured, persisting URL for later: \(url.absoluteString)")
                UserDefaults.standard.set(url.absoluteString, forKey: Self.pendingShareURLKey)
                UserDefaults.standard.synchronize()
            }
        } else {
            Log.app.info("URL is not a CloudKit share URL")
        }
    }

    /// Handle share URL notification from SceneDelegate
    private func handleShareURLNotification(_ notification: Notification) {
        if let url = notification.userInfo?["url"] as? URL {
            Log.app.info("Received share URL notification: \(url)")
            handleIncomingURL(url)
        }
    }

    /// Handle web user activity (for iCloud share URLs)
    private func handleWebUserActivity(_ userActivity: NSUserActivity) {
        Log.app.info("onContinueUserActivity: NSUserActivityTypeBrowsingWeb")
        if let url = userActivity.webpageURL {
            Log.app.info("Web URL: \(url.absoluteString)")
            if url.host?.contains("icloud.com") == true {
                handleIncomingURL(url)
            }
        }
    }

    /// Handle CloudKit share acceptance notification from SceneDelegate.
    /// SceneDelegate already handles acceptance — this just logs for diagnostics.
    private func handleCloudKitShareAccepted(notification: Notification) {
        guard let metadata = notification.userInfo?["metadata"] as? CKShare.Metadata else {
            return
        }
        Log.app.info("TetraTrackApp received share notification (SceneDelegate handles acceptance). Owner: \(metadata.ownerIdentity.nameComponents?.formatted() ?? "Unknown")")
    }

    /// Check CloudKit account status and log diagnostics
    private static func checkCloudKitStatus() async {
        let container = CKContainer.default()

        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                Log.app.info("iCloud account: Available")
                // Check if we can access the private database
                let privateDB = container.privateCloudDatabase
                let query = CKQuery(recordType: "CD_Ride", predicate: NSPredicate(value: true))
                do {
                    _ = try await privateDB.records(matching: query, resultsLimit: 1)
                    Log.app.info("CloudKit private database: Accessible")
                } catch {
                    Log.app.warning("CloudKit query failed: \(error.localizedDescription) - This may be normal if no data exists yet")
                }
            case .noAccount:
                Log.app.warning("iCloud account: Not signed in - User needs to sign into iCloud in Settings")
            case .restricted:
                Log.app.warning("iCloud account: Restricted - Parental controls may be blocking iCloud")
            case .couldNotDetermine:
                Log.app.warning("iCloud account: Could not determine status")
            case .temporarilyUnavailable:
                Log.app.warning("iCloud account: Temporarily unavailable")
            @unknown default:
                Log.app.warning("iCloud account: Unknown status")
            }
        } catch {
            Log.app.error("Failed to check iCloud status: \(error.localizedDescription)")
        }
    }
}
