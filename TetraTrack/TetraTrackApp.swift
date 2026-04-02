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

    /// Whether the app is running as a test host for unit tests.
    /// Xcode sets XCTestConfigurationFilePath when injecting a test bundle.
    private static var isUnitTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Whether the app was launched for screenshot capture (simctl-based)
    private static var isScreenshotMode: Bool {
        ScreenshotScreen.isScreenshotMode
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Ride.self,
            GPSPoint.self,
            GaitSegment.self,
            ReinSegment.self,
            GaitTransition.self,
            RidePhase.self,
            LiveTrackingSession.self,
            FamilyMember.self,
            RiderProfile.self,
            Horse.self,
            Competition.self,
            CompetitionTask.self,
            FlatworkExercise.self,
            PoleworkExercise.self,
            TrainingStreak.self,
            // ScheduledWorkout and TrainingWeekFocus removed — training calendar deleted (#310)
            RidingDrillSession.self,   // SCHEMA-ONLY: CloudKit backward compat
            ShootingDrillSession.self, // SCHEMA-ONLY: CloudKit backward compat
            LocationPoint.self,        // SCHEMA-ONLY: CloudKit backward compat
            RunningLocationPoint.self, // SCHEMA-ONLY: CloudKit backward compat
            SwimmingLocationPoint.self, // SCHEMA-ONLY: CloudKit backward compat
            UnifiedDrillSession.self,
            RunningSession.self,       // SCHEMA-ONLY: CloudKit backward compat (capture removed, uses HealthKit)
            SwimmingSession.self,      // SCHEMA-ONLY: CloudKit backward compat (capture removed, uses HealthKit)
            ShootingSession.self,
            // Route planning models
            // PlannedRoute, RouteWaypoint, OSMNode, DownloadedRegion removed — route planning deleted (#307)
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

        // UI testing, unit testing, screenshot mode, and CI: use in-memory local-only storage to avoid CloudKit crashes
        if isUITesting || isUnitTesting || isScreenshotMode {
            Log.app.info("Testing/screenshot mode: using in-memory local-only ModelContainer")
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

        // Simulator: use local-only storage to avoid CloudKit mirroring crash
        #if targetEnvironment(simulator)
        Log.app.info("Simulator detected: using local-only ModelContainer (no CloudKit)")
        let simConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [simConfig])
        } catch {
            fatalError("Could not create simulator ModelContainer: \(error)")
        }
        #endif

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
    // SessionTracker removed — all disciplines are Watch-primary (#309)
    @State private var isConfigured = false
    @State private var showShareLinkAlert = false
    @State private var shareLinkAlertMessage = ""

    // Key for persisting pending share URLs that arrive before app is ready
    private static let pendingShareURLKey = "pendingShareURLToProcess"

    var body: some Scene {
        WindowGroup {
            rootContentView
        }
        .modelContainer(sharedModelContainer)
    }

    @ViewBuilder
    private var rootContentView: some View {
        if Self.isUnitTesting {
            Color.clear // Minimal view for unit test host — avoids CloudKit singleton access
        } else if let screen = ScreenshotScreen.fromLaunchArguments() {
        ScreenshotRouterView(screen: screen)
            .environment(\.locale, LocalizationManager.shared.locale)
            .environment(locationManager)
            .viewContext(viewContext)
            .onAppear(perform: handleAppear)
        } else {
        ContentView()
            .environment(\.locale, LocalizationManager.shared.locale)
            .environment(locationManager)
            .viewContext(viewContext)
            .onAppear(perform: handleAppear)
            .task { await handleInitialSetup() }
            .modifier(SiriNotificationModifier(
                onStartRide: handleStartRide,
                onAnnounceStatus: announceCurrentStatus
            ))
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(from: oldPhase, to: newPhase)
            }
            .onOpenURL { url in handleIncomingURL(url) }
            .onReceive(NotificationCenter.default.publisher(for: .didAcceptCloudKitShare)) { notification in
                handleCloudKitShareAccepted(notification: notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: .didReceiveShareURL)) { notification in
                handleShareURLNotification(notification)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb, perform: handleWebUserActivity)
            .alert("Share Link Received", isPresented: $showShareLinkAlert) {
                Button("OK") { showShareLinkAlert = false }
            } message: {
                Text(shareLinkAlertMessage)
            }
        }
    }

    private func handleAppear() {
        configureAppIfNeeded()
    }

    private func handleInitialSetup() async {
        guard !Self.isUITesting, !Self.isUnitTesting, !Self.isScreenshotMode else { return }
        _ = await NotificationManager.shared.requestAuthorization()
        #if !targetEnvironment(simulator)
        await NotificationManager.shared.setupCloudKitSubscriptions()
        #else
        await saveBundledTargetsToPhotosIfNeeded()
        #endif
    }

    /// Save bundled test target images to the simulator's Photos library (once only)
    #if targetEnvironment(simulator)
    private func saveBundledTargetsToPhotosIfNeeded() async {
        let key = "bundledTargetsSavedToPhotos"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        guard let resourceURL = Bundle.main.resourceURL else { return }
        let folder = resourceURL.appendingPathComponent("SimulatorTargets")
        guard FileManager.default.fileExists(atPath: folder.path) else { return }

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        ) else { return }

        let imageExtensions = Set(["jpeg", "jpg", "png"])
        for url in contents where imageExtensions.contains(url.pathExtension.lowercased()) {
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            }
        }

        UserDefaults.standard.set(true, forKey: key)
        Log.app.info("Saved bundled target images to simulator Photos library")
    }
    #endif

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        // All sessions are Watch-primary — no iPhone session state to manage

        switch newPhase {
        case .background:
            // Audio coaching removed (#309)

            // Suspend family location refresh loop to prevent battery drain
            if !Self.isUITesting, !Self.isUnitTesting {
                UnifiedSharingCoordinator.shared.suspendWatchingForBackground()
            }

            Log.app.info("App entered background")

        case .inactive:
            break

        case .active:
            guard !Self.isUITesting, !Self.isUnitTesting else { break }

            // App became active - restore download state from persistence
            // This ensures UI shows correct state if a download completed/failed while in background
            // Route planning restore removed (#307)

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
        // SessionTracker configuration removed — all sessions Watch-primary (#309)

        // Auto-generate screenshot data when launched in screenshot mode
        if Self.isScreenshotMode {
            ScreenshotDataGenerator.generateScreenshotData(in: sharedModelContainer.mainContext)
            try? sharedModelContainer.mainContext.save()
            Log.app.info("Screenshot mode: generated demonstration data")
        }

        // Skip CloudKit and connectivity services during testing or screenshot capture
        guard !Self.isUITesting, !Self.isUnitTesting, !Self.isScreenshotMode else {
            isConfigured = true
            return
        }

        // Workout recovery removed — sessions are Watch-primary (#309)

        // Activate Watch connectivity
        WatchConnectivityManager.shared.activate()

        // Process any pending ride summaries from Watch autonomous rides
        processPendingRideSummaries()

        // Sync widget data on app launch
        WidgetDataSyncService.shared.syncAllWidgetData(context: sharedModelContainer.mainContext)

        // Route planning service removed (#307)

        // Configure family sharing coordinator
        UnifiedSharingCoordinator.shared.configure(with: sharedModelContainer.mainContext)

        // Initialize CloudKit schema for family sharing (creates record types in Development mode)
        // Skip on simulator — CloudKit is not available without iCloud sign-in
        #if !targetEnvironment(simulator)
        Task {
            let schemaInitializer = CloudKitSchemaInitializer()
            let result = await schemaInitializer.initializeSchema()
            if result.success {
                Log.app.info("CloudKit schema initialized: \(result.recordTypesCreated.joined(separator: ", "))")
            } else {
                Log.app.warning("CloudKit schema initialization: \(result.errors.joined(separator: "; "))")
            }
        }
        #endif

        // Migrate personal bests from UserDefaults to iCloud Key-Value Store
        SwimmingPersonalBests.migrateFromUserDefaults()
        ShootingPersonalBests.migrateFromUserDefaults()

        // Index upcoming competitions for Maps and Siri Suggestions
        indexUpcomingCompetitions()

        isConfigured = true

        // Process any pending share URL that arrived before app was ready
        processPendingShareURLIfNeeded()
    }

    /// Log any pending ride summaries from Watch (actual Ride creation happens lazily
    /// when user opens the equestrian workout in EnrichedWorkoutDetailView)
    private func processPendingRideSummaries() {
        let count = WatchConnectivityManager.shared.pendingRideSummaries.count
        if count > 0 {
            Log.app.info("Found \(count) pending ride summaries from Watch")
        }
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

    // Voice coaching functions removed (#309)
    private func announceCurrentStatus() {}
    private func setAudioCoaching(enabled: Bool) {}
    private func toggleAudioCoaching() {}

    private func handleStartRide(notification: Notification) {
        // Riding is now Watch-primary — iPhone no longer starts ride sessions
        Log.app.info("Ride start request received but riding is Watch-primary")
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

// MARK: - Siri Notification Modifier

/// Extracts Siri .onReceive handlers into a ViewModifier to reduce type-checker
/// complexity in the main App body.
// Siri session control removed — all disciplines are Watch-primary (#309)
private struct SiriNotificationModifier: ViewModifier {
    var onStartRide: (Notification) -> Void
    var onAnnounceStatus: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .startRideFromSiri)) { notification in
                onStartRide(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: .getStatusFromSiri)) { _ in
                onAnnounceStatus()
            }
    }
}
