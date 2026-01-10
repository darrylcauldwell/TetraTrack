//
//  SettingsView.swift
//  TrackRide
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var profiles: [RiderProfile]
    @Query private var rides: [Ride]
    @Query private var horses: [Horse]
    @Query private var runningSessions: [RunningSession]
    @Query private var swimmingSessions: [SwimmingSession]
    @Query private var shootingSessions: [ShootingSession]
    @Query private var competitions: [Competition]
    @Query private var competitionTasks: [CompetitionTask]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.routePlanning) private var routePlanning
    private var healthKit = HealthKitManager.shared
    private var watchConnectivity = WatchConnectivityManager.shared
    @AppStorage("demonstrationDataEnabled") private var demonstrationDataEnabled: Bool = false

    // Data management confirmation dialogs
    @State private var showingClearTrainingConfirmation = false
    @State private var showingClearTasksConfirmation = false
    @State private var showingClearCompetitionsConfirmation = false
    @State private var showingClearAllConfirmation = false
    @State private var hasDownloadedRegions = false

    private var profile: RiderProfile {
        if let existing = profiles.first {
            return existing
        }
        let newProfile = RiderProfile()
        modelContext.insert(newProfile)
        return newProfile
    }

    /// Check if user has created any of their own data
    /// If demo mode is off and there's data, they must have created it themselves
    private var hasUserData: Bool {
        // If demo mode is enabled, check if there's more data than demo would create
        // Otherwise, any data means user has created something
        if demonstrationDataEnabled {
            // Demo creates 3 horses, 8 rides, 4 run sessions, 2 swim sessions, 2 shoot sessions, 3 competitions
            // If we have more than this, user has added their own
            return horses.count > 3 ||
                   rides.count > 8 ||
                   runningSessions.count > 4 ||
                   swimmingSessions.count > 2 ||
                   shootingSessions.count > 2 ||
                   competitions.count > 3
        } else {
            // Demo mode is off - any data means user created it
            return !rides.isEmpty ||
                   !horses.isEmpty ||
                   !runningSessions.isEmpty ||
                   !swimmingSessions.isEmpty ||
                   !shootingSessions.isEmpty ||
                   !competitions.isEmpty
        }
    }

    /// Whether to show the demonstration data toggle
    private var shouldShowDemoOption: Bool {
        // Only show if user hasn't created their own data while demo is off
        // Or if demo mode is currently on (so they can turn it off)
        demonstrationDataEnabled || !hasUserData
    }

    /// Debug info showing what data is blocking demo mode
    private var blockingDataInfo: String? {
        guard !demonstrationDataEnabled && hasUserData else { return nil }
        var blocking: [String] = []
        if !horses.isEmpty { blocking.append("\(horses.count) horse(s)") }
        if !rides.isEmpty { blocking.append("\(rides.count) ride(s)") }
        if !runningSessions.isEmpty { blocking.append("\(runningSessions.count) run(s)") }
        if !swimmingSessions.isEmpty { blocking.append("\(swimmingSessions.count) swim(s)") }
        if !shootingSessions.isEmpty { blocking.append("\(shootingSessions.count) shoot(s)") }
        if !competitions.isEmpty { blocking.append("\(competitions.count) competition(s)") }
        return blocking.isEmpty ? nil : blocking.joined(separator: ", ")
    }

    /// Total count of all training sessions
    private var trainingSessionCount: Int {
        rides.count + runningSessions.count + swimmingSessions.count + shootingSessions.count
    }

    var body: some View {
        NavigationStack {
            List {
                // Horses Section
                Section("Horses") {
                    NavigationLink(destination: HorseListView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "figure.equestrian.sports")
                                .font(.title2)
                                .foregroundStyle(AppColors.primary)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("My Horses")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text("Manage your horses")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Rider Profile Section
                Section("Rider Profile") {
                    NavigationLink(destination: RiderProfileView(profile: profile)) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title)
                                .foregroundStyle(AppColors.primary)

                            VStack(alignment: .leading) {
                                Text("Your Profile")
                                    .font(.headline)
                                Text("\(profile.formattedWeight) | \(profile.formattedHeight)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // HealthKit Section
                Section {
                    if healthKit.isAvailable {
                        if healthKit.isAuthorized {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(.red)
                                Text("Connected to Apple Health")
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppColors.success)
                            }

                            if let lastSync = profile.lastUpdatedFromHealthKit {
                                HStack {
                                    Text("Last synced")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Button(action: syncFromHealthKit) {
                                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                            }
                        } else {
                            Button(action: requestHealthKitAccess) {
                                HStack {
                                    Image(systemName: "heart.fill")
                                        .foregroundStyle(.red)
                                    Text("Connect to Apple Health")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .foregroundStyle(.primary)

                            Text("Sync your weight and height for accurate calorie calculations. Workouts will be saved to Apple Health.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Label("Apple Health not available", systemImage: "xmark.circle")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Apple Health")
                } footer: {
                    if healthKit.isAuthorized {
                        Text("Workouts are automatically saved to Apple Health.")
                    }
                }

                // Apple Watch Section
                Section {
                    HStack {
                        Image(systemName: "applewatch")
                            .font(.title2)
                            .foregroundStyle(watchConnectivity.isPaired ? AppColors.primary : .secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Watch Status")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            if watchConnectivity.isPaired {
                                if watchConnectivity.isWatchAppInstalled {
                                    if watchConnectivity.isReachable {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(.green)
                                                .frame(width: 8, height: 8)
                                            Text("Connected")
                                                .font(.caption)
                                                .foregroundStyle(.green)
                                        }
                                    } else {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(.orange)
                                                .frame(width: 8, height: 8)
                                            Text("App not active")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                } else {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(.red)
                                            .frame(width: 8, height: 8)
                                        Text("App not installed")
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    }
                                }
                            } else {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(.secondary)
                                        .frame(width: 8, height: 8)
                                    Text("No Watch paired")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Spacer()

                        // Only show checkmark when fully connected
                        if watchConnectivity.isPaired && watchConnectivity.isWatchAppInstalled && watchConnectivity.isReachable {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppColors.success)
                        }
                    }

                    // Show guidance when not fully connected
                    if watchConnectivity.isPaired && watchConnectivity.isWatchAppInstalled && !watchConnectivity.isReachable {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Open TetraTrack on your Apple Watch to enable live communication.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("The watch app will connect automatically when you start a ride.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    if watchConnectivity.isPaired && watchConnectivity.isWatchAppInstalled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Watch Features")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            WatchFeatureRow(icon: "play.fill", title: "Start/Stop sessions from Watch")
                            WatchFeatureRow(icon: "heart.fill", title: "Live heart rate streaming")
                            WatchFeatureRow(icon: "figure.equestrian.sports", title: "View stats on wrist")
                            WatchFeatureRow(icon: "hand.tap.fill", title: "Haptic feedback for events")
                        }
                    } else if !watchConnectivity.isPaired {
                        Text("Pair an Apple Watch to enable live heart rate monitoring and wrist controls during your sessions.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Install the TetraTrack app on your Apple Watch to:")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            WatchFeatureRow(icon: "heart.fill", title: "Stream live heart rate")
                            WatchFeatureRow(icon: "play.fill", title: "Control sessions from wrist")
                        }
                    }
                } header: {
                    Text("Apple Watch")
                }

                // Audio Coaching Section
                Section("Voice Coaching") {
                    NavigationLink(destination: AudioCoachingView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.title2)
                                .foregroundStyle(AppColors.primary)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Voice Coaching")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text("Spoken cues for gaits, milestones, and intervals")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Training Section
                Section("Training") {
                    NavigationLink(destination: WorkoutListView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "timer")
                                .font(.title2)
                                .foregroundStyle(AppColors.primary)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Structured Workouts")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text("Build and run interval training sessions")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    NavigationLink(destination: ExerciseLibraryView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "book.fill")
                                .font(.title2)
                                .foregroundStyle(AppColors.primary)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Exercise Library")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text("Arena exercises and schooling figures")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    NavigationLink(destination: RecoveryTrendsView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "heart.text.square.fill")
                                .font(.title2)
                                .foregroundStyle(AppColors.error)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Recovery Trends")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text("Track HRV and readiness over time")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Offline Maps Section
                Section("Offline Maps") {
                    HStack(spacing: 12) {
                        Image(systemName: "map.fill")
                            .font(.title2)
                            .foregroundStyle(AppColors.primary)
                            .frame(width: 32)

                        Text("Prepare for No Signal Areas")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Text("Many riding trails have limited or no mobile coverage. Download your planned riding area in Apple Maps before you start to ensure the map displays correctly during your ride.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("How to download offline maps:")
                            .font(.caption)
                            .fontWeight(.medium)

                        OfflineMapStep(number: 1, text: "Open the Apple Maps app")
                        OfflineMapStep(number: 2, text: "Tap your profile picture (bottom right)")
                        OfflineMapStep(number: 3, text: "Select \"Offline Maps\"")
                        OfflineMapStep(number: 4, text: "Tap \"Download New Map\"")
                        OfflineMapStep(number: 5, text: "Navigate to your riding area and adjust the region")
                        OfflineMapStep(number: 6, text: "Tap \"Download\"")
                    }

                    Button(action: openAppleMaps) {
                        Label("Open Apple Maps", systemImage: "arrow.up.forward.app")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }

                // Route Planning Data Section
                Section {
                    Text("Route planning uses OpenStreetMap data for bridleways and trails. Download your riding area to enable route planning.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Show all regions with their status
                    RouteDataRegionsList()
                } header: {
                    Text("Route Planning Data")
                } footer: {
                    Text("Route data is separate from Apple Maps. Swipe left on a downloaded region to remove it.")
                        .font(.caption2)
                }

                // Data Management Section
                Section {
                    // Clear Training History
                    Button(role: .destructive) {
                        showingClearTrainingConfirmation = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.title2)
                                .foregroundStyle(.red)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Clear Training History")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text("\(trainingSessionCount) sessions")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    }
                    .disabled(trainingSessionCount == 0)

                    // Clear Tasks
                    Button(role: .destructive) {
                        showingClearTasksConfirmation = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "checklist")
                                .font(.title2)
                                .foregroundStyle(.red)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Clear Tasks")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text("\(competitionTasks.count) tasks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    }
                    .disabled(competitionTasks.isEmpty)

                    // Clear Competitions
                    Button(role: .destructive) {
                        showingClearCompetitionsConfirmation = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .font(.title2)
                                .foregroundStyle(.red)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Clear Competitions")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text("\(competitions.count) competitions")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    }
                    .disabled(competitions.isEmpty)

                    // Clear All Data
                    Button(role: .destructive) {
                        showingClearAllConfirmation = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "trash.fill")
                                .font(.title2)
                                .foregroundStyle(.red)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Clear All Data")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text("Remove all training, tasks, competitions, and map data")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    }
                    .disabled(trainingSessionCount == 0 && competitionTasks.isEmpty && competitions.isEmpty && horses.isEmpty && !hasDownloadedRegions)
                } header: {
                    Text("Data Management")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Data is synced to iCloud. Clearing data will remove it from all your devices.")
                        if let blocking = blockingDataInfo {
                            Text("Existing data: \(blocking)")
                                .foregroundStyle(.orange)
                        }
                    }
                }

                // Demonstration Data Section - Only visible if user hasn't created their own data
                if shouldShowDemoOption {
                    Section {
                        Toggle(isOn: $demonstrationDataEnabled) {
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles.rectangle.stack")
                                    .font(.title2)
                                    .foregroundStyle(.orange)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Demonstration Data")
                                        .font(.subheadline)
                                        .fontWeight(.medium)

                                    Text(demonstrationDataEnabled ? "Sample training history is shown" : "Add sample data to explore the app")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onChange(of: demonstrationDataEnabled) { _, newValue in
                            if newValue {
                                generateDemonstrationData()
                            } else {
                                clearDemonstrationData()
                            }
                        }
                    } footer: {
                        Text("Toggle on to see example training history, horses, and competitions. Toggle off to remove all demonstration data.")
                    }
                }
            }
            .navigationTitle("Settings")
            .task {
                healthKit.checkAuthorizationStatus()
                if healthKit.isAuthorized {
                    await healthKit.updateProfileFromHealthKit(profile)
                }
                // Check if there are downloaded regions
                checkDownloadedRegions()
            }
            .confirmationDialog(
                "Clear Training History",
                isPresented: $showingClearTrainingConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete \(trainingSessionCount) Sessions", role: .destructive) {
                    clearTrainingHistory()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your rides, runs, swims, and shooting sessions. This action cannot be undone.")
            }
            .confirmationDialog(
                "Clear Tasks",
                isPresented: $showingClearTasksConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete \(competitionTasks.count) Tasks", role: .destructive) {
                    clearTasks()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your competition tasks. This action cannot be undone.")
            }
            .confirmationDialog(
                "Clear Competitions",
                isPresented: $showingClearCompetitionsConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete \(competitions.count) Competitions", role: .destructive) {
                    clearCompetitions()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your competitions and their associated tasks. This action cannot be undone.")
            }
            .confirmationDialog(
                "Clear All Data",
                isPresented: $showingClearAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete All Data", role: .destructive) {
                    clearAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete ALL your training history, horses, tasks, competitions, and downloaded map data. This action cannot be undone.")
            }
        }
    }

    private func requestHealthKitAccess() {
        Task {
            let authorized = await healthKit.requestAuthorization()
            if authorized {
                await healthKit.updateProfileFromHealthKit(profile)
            }
        }
    }

    private func syncFromHealthKit() {
        Task {
            await healthKit.updateProfileFromHealthKit(profile)
        }
    }

    private func openAppleMaps() {
        if let url = URL(string: "maps://") {
            UIApplication.shared.open(url)
        }
    }

    private func generateDemonstrationData() {
        ScreenshotDataGenerator.generateScreenshotData(in: modelContext)
        try? modelContext.save()
    }

    private func clearDemonstrationData() {
        // Clear rides
        let rideDescriptor = FetchDescriptor<Ride>()
        if let allRides = try? modelContext.fetch(rideDescriptor) {
            allRides.forEach { modelContext.delete($0) }
        }

        // Clear horses
        let horseDescriptor = FetchDescriptor<Horse>()
        if let allHorses = try? modelContext.fetch(horseDescriptor) {
            allHorses.forEach { modelContext.delete($0) }
        }

        // Clear competitions
        let compDescriptor = FetchDescriptor<Competition>()
        if let comps = try? modelContext.fetch(compDescriptor) {
            comps.forEach { modelContext.delete($0) }
        }

        // Clear running sessions
        let runDescriptor = FetchDescriptor<RunningSession>()
        if let runs = try? modelContext.fetch(runDescriptor) {
            runs.forEach { modelContext.delete($0) }
        }

        // Clear swimming sessions
        let swimDescriptor = FetchDescriptor<SwimmingSession>()
        if let swims = try? modelContext.fetch(swimDescriptor) {
            swims.forEach { modelContext.delete($0) }
        }

        // Clear shooting sessions
        let shootDescriptor = FetchDescriptor<ShootingSession>()
        if let shoots = try? modelContext.fetch(shootDescriptor) {
            shoots.forEach { modelContext.delete($0) }
        }

        try? modelContext.save()
    }

    private func clearTrainingHistory() {
        // Clear rides
        for ride in rides {
            modelContext.delete(ride)
        }

        // Clear running sessions
        for session in runningSessions {
            modelContext.delete(session)
        }

        // Clear swimming sessions
        for session in swimmingSessions {
            modelContext.delete(session)
        }

        // Clear shooting sessions
        for session in shootingSessions {
            modelContext.delete(session)
        }

        try? modelContext.save()

        // Sync to widgets
        WidgetDataSyncService.shared.syncRecentSessions(context: modelContext)
    }

    private func clearTasks() {
        for task in competitionTasks {
            modelContext.delete(task)
        }

        try? modelContext.save()

        // Sync to widgets
        WidgetDataSyncService.shared.syncTasks(context: modelContext)
    }

    private func clearCompetitions() {
        // Clearing competitions will cascade delete associated tasks
        for competition in competitions {
            modelContext.delete(competition)
        }

        try? modelContext.save()

        // Sync to widgets
        WidgetDataSyncService.shared.syncCompetitions(context: modelContext)
        WidgetDataSyncService.shared.syncTasks(context: modelContext)
    }

    private func clearAllData() {
        clearTrainingHistory()
        clearTasks()
        clearCompetitions()
        clearHorses()
        clearRouteMapData()
    }

    private func clearRouteMapData() {
        // Use the OSMDataManager to properly delete all regions
        // This handles batch deletion of potentially thousands of nodes
        Task {
            do {
                let regions = try routePlanning.getDownloadedRegions()
                for region in regions {
                    try await routePlanning.deleteRegion(region.regionId)
                }
                await MainActor.run {
                    hasDownloadedRegions = false
                }
            } catch {
                // Silent fail - data may already be cleared
            }
        }
    }

    private func checkDownloadedRegions() {
        do {
            let regions = try routePlanning.getDownloadedRegions()
            hasDownloadedRegions = !regions.isEmpty
        } catch {
            hasDownloadedRegions = false
        }
    }

    private func clearHorses() {
        // Fetch ALL horses directly (including archived) to ensure complete deletion
        let descriptor = FetchDescriptor<Horse>()
        if let allHorses = try? modelContext.fetch(descriptor) {
            for horse in allHorses {
                modelContext.delete(horse)
            }
        }

        try? modelContext.save()
    }
}

// Components moved to SettingsComponents.swift:
// - OfflineMapStep
// - WatchFeatureRow
// - METInfoRow
// - RiderProfileView
// - CalorieExampleRow
// - WeightPickerView
// - HeightPickerView
// - DateOfBirthPickerView

// MARK: - Route Data Regions List

struct RouteDataRegionsList: View {
    @Environment(\.routePlanning) private var routePlanning
    @State private var downloadedRegions: [DownloadedRegion] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var regionToDelete: DownloadedRegion?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        Group {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            } else {
                ForEach(AvailableRegion.ukRegions) { region in
                    RouteDataRegionRow(
                        region: region,
                        downloadedRegion: downloadedRegion(for: region),
                        downloadProgress: routePlanning.activeDownloads[region.id],
                        onDownload: { downloadRegion(region) },
                        onDelete: { deleteRegion(region) }
                    )
                }
            }
        }
        .onAppear { loadDownloadedRegions() }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
    }

    private func downloadedRegion(for region: AvailableRegion) -> DownloadedRegion? {
        downloadedRegions.first { $0.regionId == region.id }
    }

    private func loadDownloadedRegions() {
        do {
            downloadedRegions = try routePlanning.getDownloadedRegions()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
        isLoading = false
    }

    private func downloadRegion(_ region: AvailableRegion) {
        Task {
            do {
                try await routePlanning.downloadRegion(region)
                await MainActor.run { loadDownloadedRegions() }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }

    private func deleteRegion(_ region: AvailableRegion) {
        // CRITICAL: SwiftUI's swipe delete expects synchronous data source updates.
        // We must update the local state FIRST before any async work.
        // Using withAnimation helps SwiftUI properly coordinate with UICollectionView.

        // 1. Optimistically remove from local state IMMEDIATELY with animation
        let deletedRegion = downloadedRegions.first { $0.regionId == region.id }
        withAnimation {
            downloadedRegions.removeAll { $0.regionId == region.id }
        }

        // 2. Perform actual deletion in background
        Task {
            do {
                try await routePlanning.deleteRegion(region.id)
                // Success - state is already correct
            } catch {
                // Failed - restore the item and show error
                await MainActor.run {
                    withAnimation {
                        if let deletedRegion = deletedRegion {
                            downloadedRegions.append(deletedRegion)
                        }
                    }
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Route Data Region Row

struct RouteDataRegionRow: View {
    let region: AvailableRegion
    let downloadedRegion: DownloadedRegion?
    let downloadProgress: OSMDataManager.DownloadProgress?
    let onDownload: () -> Void
    let onDelete: () -> Void

    private var isDownloaded: Bool {
        downloadedRegion != nil
    }

    private var isDownloading: Bool {
        if let progress = downloadProgress {
            return progress.phase != .complete && progress.phase != .failed
        }
        return false
    }

    var body: some View {
        HStack(spacing: 12) {
            // Region info (no left icon - status shown on right only)
            VStack(alignment: .leading, spacing: 2) {
                Text(region.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                if let downloaded = downloadedRegion {
                    HStack(spacing: 8) {
                        Text(downloaded.formattedFileSize)
                        if downloaded.isStale {
                            Text("• Update available")
                                .foregroundStyle(.orange)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else if let progress = downloadProgress {
                    Text(progress.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("~\(region.formattedEstimatedSize)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Action button / status indicator (right side only)
            if isDownloading {
                // Show progress percentage
                if let progress = downloadProgress {
                    Text("\(Int(progress.progress * 100))%")
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                        .monospacedDigit()
                }
            } else if isDownloaded {
                // Downloaded checkmark
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            } else {
                // Download button
                Button(action: onDownload) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if isDownloaded {
                Button(role: .destructive) {
                    // Delete immediately without confirmation
                    // Swipe delete is already a deliberate gesture
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

}

#Preview {
    SettingsView()
        .modelContainer(for: [RiderProfile.self], inMemory: true)
}
