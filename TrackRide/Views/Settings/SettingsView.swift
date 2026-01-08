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
    private var healthKit = HealthKitManager.shared
    private var watchConnectivity = WatchConnectivityManager.shared
    @AppStorage("demonstrationDataEnabled") private var demonstrationDataEnabled: Bool = false

    // Data management confirmation dialogs
    @State private var showingClearTrainingConfirmation = false
    @State private var showingClearTasksConfirmation = false
    @State private var showingClearCompetitionsConfirmation = false
    @State private var showingClearAllConfirmation = false

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
                            Label("Connected to Apple Health", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(AppColors.success)

                            Toggle("Sync profile from Health", isOn: Binding(
                                get: { profile.useHealthKitData },
                                set: { profile.useHealthKitData = $0 }
                            ))

                            if profile.useHealthKitData {
                                Button(action: syncFromHealthKit) {
                                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                                }

                                if let lastSync = profile.lastUpdatedFromHealthKit {
                                    Text("Last synced: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            Button(action: requestHealthKitAccess) {
                                Label("Connect to Apple Health", systemImage: "heart.fill")
                            }

                            Text("Allow TetraTrack to read your weight and height for accurate calorie calculations")
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
                Section("Apple Watch") {
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
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(watchConnectivity.isReachable ? .green : .orange)
                                            .frame(width: 8, height: 8)
                                        Text(watchConnectivity.isReachable ? "Connected" : "Not reachable")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text("App not installed")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text("No Watch paired")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if watchConnectivity.isPaired && watchConnectivity.isWatchAppInstalled {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppColors.success)
                        }
                    }

                    if watchConnectivity.isPaired && watchConnectivity.isWatchAppInstalled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Watch Features")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            WatchFeatureRow(icon: "play.fill", title: "Start/Stop rides from Watch")
                            WatchFeatureRow(icon: "heart.fill", title: "Live heart rate streaming")
                            WatchFeatureRow(icon: "figure.equestrian.sports", title: "View ride stats on wrist")
                            WatchFeatureRow(icon: "hand.tap.fill", title: "Haptic feedback for events")
                        }
                        .padding(.vertical, 4)
                    } else if !watchConnectivity.isPaired {
                        Text("Pair an Apple Watch to enable live heart rate monitoring and wrist controls during your rides.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Install the TetraTrack app on your Apple Watch to:")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            WatchFeatureRow(icon: "heart.fill", title: "Stream live heart rate")
                            WatchFeatureRow(icon: "play.fill", title: "Control rides from wrist")
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Safety Section
                Section("Safety") {
                    NavigationLink(destination: EmergencyContactsView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.2.badge.gearshape.fill")
                                .font(.title2)
                                .foregroundStyle(AppColors.error)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Emergency Contacts")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text("Set up contacts for fall detection alerts")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "figure.fall")
                                .foregroundStyle(AppColors.error)
                            Text("Fall Detection")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        Text("TetraTrack monitors for falls while you ride. If a fall is detected, you'll have 30 seconds to respond before your emergency contacts are notified with your location.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
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

                // Calorie Calculation Info
                Section("Calorie Calculation") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How calories are calculated")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("TetraTrack uses MET (Metabolic Equivalent) values specific to each gait to calculate calories burned during your ride.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            METInfoRow(gait: "Walk", met: "2.5", color: AppColors.walk)
                            METInfoRow(gait: "Trot", met: "5.5", color: AppColors.trot)
                            METInfoRow(gait: "Canter", met: "7.0", color: AppColors.canter)
                            METInfoRow(gait: "Gallop", met: "8.5", color: AppColors.gallop)
                        }

                        Text("Formula: Calories = MET x Weight(kg) x Hours")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }

                // Offline Maps Section
                Section("Offline Maps") {
                    VStack(alignment: .leading, spacing: 12) {
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

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
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
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
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

                                Text("Remove all training, tasks, and competitions")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    }
                    .disabled(trainingSessionCount == 0 && competitionTasks.isEmpty && competitions.isEmpty)
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

                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
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
                if profile.useHealthKitData && healthKit.isAuthorized {
                    await healthKit.fetchBodyMeasurements()
                }
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
                Text("This will permanently delete ALL your training history, horses, tasks, and competitions. This action cannot be undone.")
            }
        }
    }

    private func requestHealthKitAccess() {
        Task {
            let authorized = await healthKit.requestAuthorization()
            if authorized && profile.useHealthKitData {
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

#Preview {
    SettingsView()
        .modelContainer(for: [RiderProfile.self], inMemory: true)
}
