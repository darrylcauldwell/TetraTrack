//
//  SettingsView.swift
//  TetraTrack
//

import SwiftUI
import SwiftData

// MARK: - Settings Section Enum

enum SettingsSection: String, CaseIterable, Identifiable {
    case horses = "Horses"
    case profile = "Rider Profile"
    case health = "Apple Health"
    case watch = "Apple Watch"
    case coaching = "Voice Coaching"
    case training = "Training"
    case maps = "Offline Maps"
    case shooting = "Shooting Development"
    case data = "Data Management"
    case demo = "Demonstration Data"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .horses: return "figure.equestrian.sports"
        case .profile: return "person.circle.fill"
        case .health: return "heart.fill"
        case .watch: return "applewatch"
        case .coaching: return "speaker.wave.3.fill"
        case .training: return "timer"
        case .maps: return "map.fill"
        case .shooting: return "brain"
        case .data: return "externaldrive.fill"
        case .demo: return "sparkles.rectangle.stack"
        }
    }

    var color: Color {
        switch self {
        case .horses: return AppColors.primary
        case .profile: return AppColors.primary
        case .health: return .red
        case .watch: return AppColors.primary
        case .coaching: return AppColors.primary
        case .training: return AppColors.primary
        case .maps: return AppColors.primary
        case .shooting: return .purple
        case .data: return .red
        case .demo: return .orange
        }
    }
}

struct SettingsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Bindable private var localizationManager = LocalizationManager.shared
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

    // iPad navigation state
    @State private var selectedSection: SettingsSection? = .horses

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
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .task {
            healthKit.checkAuthorizationStatus()
            if healthKit.isAuthorized {
                await healthKit.updateProfileFromHealthKit(profile)
            }
            checkDownloadedRegions()
        }
        .confirmationDialog(
            "Clear Session History",
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

    // MARK: - iPad Layout (Split View)

    private var iPadLayout: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                ForEach(SettingsSection.allCases.filter { section in
                    // Filter out demo section if not applicable
                    section != .demo || shouldShowDemoOption
                }) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .foregroundStyle(section.color)
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Settings")
        } detail: {
            if let section = selectedSection {
                settingsSectionDetail(for: section)
            } else {
                ContentUnavailableView(
                    "Select a Section",
                    systemImage: "gear",
                    description: Text("Choose a settings category from the sidebar")
                )
            }
        }
    }

    @ViewBuilder
    private func settingsSectionDetail(for section: SettingsSection) -> some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                switch section {
                case .horses:
                    horsesContent
                case .profile:
                    profileContent
                case .health:
                    healthContent
                case .watch:
                    watchContent
                case .coaching:
                    coachingContent
                case .training:
                    trainingContent
                case .maps:
                    mapsContent
                case .shooting:
                    shootingContent
                case .data:
                    dataManagementContent
                case .demo:
                    demoContent
                }
            }
            .padding(Spacing.xl)
        }
        .navigationTitle(section.rawValue)
    }

    // MARK: - iPhone Layout (Standard List)

    private var iPhoneLayout: some View {
        NavigationStack {
            settingsList
                .navigationTitle("Settings")
        }
    }

    private var settingsList: some View {
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

                // Language Section
                Section("Language") {
                    Picker(selection: $localizationManager.selectedLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            HStack {
                                Text(language.flag)
                                Text(language.displayName)
                            }
                            .tag(language)
                        }
                    } label: {
                        Label("App Language", systemImage: "globe")
                    }
                    .pickerStyle(.navigationLink)
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
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Apple Health: Connected")

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
                                        AccessibleStatusIndicator(.connected, size: .small)
                                    } else {
                                        HStack(spacing: 4) {
                                            Image(systemName: "exclamationmark.circle.fill")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.orange)
                                            Text("App not active")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                        .accessibilityElement(children: .combine)
                                        .accessibilityLabel("Watch app not active")
                                    }
                                } else {
                                    HStack(spacing: 4) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.red)
                                        Text("App not installed")
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel("Watch app not installed")
                                }
                            } else {
                                AccessibleStatusIndicator(.disconnected, size: .small)
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

                    NavigationLink(destination: FlatworkLibraryView()) {
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

                // Route Planning Data Section - temporarily disabled
                // Will be re-enabled when route planning feature is complete

                // Shooting ML Development Section
                Section("Shooting Development") {
                    NavigationLink(destination: MLTrainingDashboardView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "brain")
                                .font(.title2)
                                .foregroundStyle(.purple)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("ML Training Data")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text("View collection progress for hole detection")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Data Management Section
                Section {
                    // Clear Session History
                    Button(role: .destructive) {
                        showingClearTrainingConfirmation = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.title2)
                                .foregroundStyle(.red)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Clear Session History")
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
                    .accessibleButton(
                        "Clear Session History",
                        hint: trainingSessionCount > 0 ? "Delete \(trainingSessionCount) training sessions" : "No sessions to delete"
                    )

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
                    .accessibleButton(
                        "Clear Tasks",
                        hint: !competitionTasks.isEmpty ? "Delete \(competitionTasks.count) competition tasks" : "No tasks to delete"
                    )

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
                    .accessibleButton(
                        "Clear Competitions",
                        hint: !competitions.isEmpty ? "Delete \(competitions.count) competitions" : "No competitions to delete"
                    )

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
                    .accessibleButton(
                        "Clear All Data",
                        hint: "Permanently delete all training history, horses, tasks, competitions, and downloaded map data"
                    )
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
        }

    // MARK: - iPad Section Content Views

    private var horsesContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            NavigationLink(destination: HorseListView()) {
                SettingsRowContent(
                    icon: "figure.equestrian.sports",
                    iconColor: AppColors.primary,
                    title: "My Horses",
                    subtitle: "Manage your horses"
                )
            }
            .buttonStyle(.plain)
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var profileContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
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

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var healthContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
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
                    .padding()
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    if let lastSync = profile.lastUpdatedFromHealthKit {
                        HStack {
                            Text("Last synced")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button(action: syncFromHealthKit) {
                        Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.borderedProminent)
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
                    .buttonStyle(.plain)
                    .padding()
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("Sync your weight and height for accurate calorie calculations. Workouts will be saved to Apple Health.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Label("Apple Health not available", systemImage: "xmark.circle")
                    .foregroundStyle(.secondary)
                    .padding()
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var watchContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "applewatch")
                    .font(.title2)
                    .foregroundStyle(watchConnectivity.isPaired ? AppColors.primary : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Watch Status")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    watchStatusIndicator
                }

                Spacer()

                if watchConnectivity.isPaired && watchConnectivity.isWatchAppInstalled && watchConnectivity.isReachable {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.success)
                }
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

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
                .padding()
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    @ViewBuilder
    private var watchStatusIndicator: some View {
        if watchConnectivity.isPaired {
            if watchConnectivity.isWatchAppInstalled {
                if watchConnectivity.isReachable {
                    AccessibleStatusIndicator(.connected, size: .small)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                        Text("App not active")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Watch app not active")
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                    Text("App not installed")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Watch app not installed")
            }
        } else {
            AccessibleStatusIndicator(.disconnected, size: .small)
        }
    }

    private var coachingContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            NavigationLink(destination: AudioCoachingView()) {
                SettingsRowContent(
                    icon: "speaker.wave.3.fill",
                    iconColor: AppColors.primary,
                    title: "Voice Coaching",
                    subtitle: "Spoken cues for gaits, milestones, and intervals"
                )
            }
            .buttonStyle(.plain)
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var trainingContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            NavigationLink(destination: WorkoutListView()) {
                SettingsRowContent(
                    icon: "timer",
                    iconColor: AppColors.primary,
                    title: "Structured Workouts",
                    subtitle: "Build and run interval training sessions"
                )
            }
            .buttonStyle(.plain)
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            NavigationLink(destination: FlatworkLibraryView()) {
                SettingsRowContent(
                    icon: "book.fill",
                    iconColor: AppColors.primary,
                    title: "Exercise Library",
                    subtitle: "Arena exercises and schooling figures"
                )
            }
            .buttonStyle(.plain)
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            NavigationLink(destination: RecoveryTrendsView()) {
                SettingsRowContent(
                    icon: "heart.text.square.fill",
                    iconColor: AppColors.error,
                    title: "Recovery Trends",
                    subtitle: "Track HRV and readiness over time"
                )
            }
            .buttonStyle(.plain)
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var mapsContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: 12) {
                Image(systemName: "map.fill")
                    .font(.title2)
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 32)

                Text("Prepare for No Signal Areas")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("Many riding trails have limited or no mobile coverage. Download your planned riding area in Apple Maps before you start to ensure the map displays correctly during your ride.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding()
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))

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
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(action: openAppleMaps) {
                Label("Open Apple Maps", systemImage: "arrow.up.forward.app")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var shootingContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            NavigationLink(destination: MLTrainingDashboardView()) {
                SettingsRowContent(
                    icon: "brain",
                    iconColor: .purple,
                    title: "ML Training Data",
                    subtitle: "View collection progress for hole detection"
                )
            }
            .buttonStyle(.plain)
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var dataManagementContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Button(role: .destructive) {
                showingClearTrainingConfirmation = true
            } label: {
                SettingsRowContent(
                    icon: "clock.arrow.circlepath",
                    iconColor: .red,
                    title: "Clear Session History",
                    subtitle: "\(trainingSessionCount) sessions"
                )
            }
            .buttonStyle(.plain)
            .disabled(trainingSessionCount == 0)
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(role: .destructive) {
                showingClearTasksConfirmation = true
            } label: {
                SettingsRowContent(
                    icon: "checklist",
                    iconColor: .red,
                    title: "Clear Tasks",
                    subtitle: "\(competitionTasks.count) tasks"
                )
            }
            .buttonStyle(.plain)
            .disabled(competitionTasks.isEmpty)
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(role: .destructive) {
                showingClearCompetitionsConfirmation = true
            } label: {
                SettingsRowContent(
                    icon: "calendar",
                    iconColor: .red,
                    title: "Clear Competitions",
                    subtitle: "\(competitions.count) competitions"
                )
            }
            .buttonStyle(.plain)
            .disabled(competitions.isEmpty)
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(role: .destructive) {
                showingClearAllConfirmation = true
            } label: {
                SettingsRowContent(
                    icon: "trash.fill",
                    iconColor: .red,
                    title: "Clear All Data",
                    subtitle: "Remove all training, tasks, competitions, and map data"
                )
            }
            .buttonStyle(.plain)
            .disabled(trainingSessionCount == 0 && competitionTasks.isEmpty && competitions.isEmpty && horses.isEmpty && !hasDownloadedRegions)
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("Data is synced to iCloud. Clearing data will remove it from all your devices.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let blocking = blockingDataInfo {
                Text("Existing data: \(blocking)")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var demoContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
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
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("Toggle on to see example training history, horses, and competitions. Toggle off to remove all demonstration data.")
                .font(.caption)
                .foregroundStyle(.secondary)
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

// MARK: - Settings Row Content (iPad)

struct SettingsRowContent: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

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
