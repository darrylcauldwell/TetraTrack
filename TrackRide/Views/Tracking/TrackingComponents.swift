//
//  TrackingComponents.swift
//  TrackRide
//
//  Extracted subviews from TrackingView for better maintainability

import SwiftUI
import SwiftData
import os

// MARK: - Idle Setup View

struct IdleSetupView: View {
    let tracker: RideTracker
    @Environment(LocationManager.self) private var locationManager: LocationManager?
    @State private var showingDisciplineSetup: RideType?
    @State private var showingSettings = false

    var body: some View {
        let _ = Log.ui.debug("IdleSetupView body rendering")
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Ride type options - row-based list
                    ForEach(RideType.allCases, id: \.self) { rideType in
                        DisciplineRow(
                            title: rideType.rawValue,
                            subtitle: rideType.description,
                            icon: rideType.icon,
                            color: rideType.color,
                            action: {
                                Log.ui.info("Discipline button tapped: \(rideType.rawValue)")
                                showingDisciplineSetup = rideType
                            }
                        )
                    }

                    // Permission warning
                    if let manager = locationManager, manager.permissionDenied {
                        HStack(spacing: 12) {
                            Image(systemName: "location.slash")
                                .font(.title2)
                                .foregroundStyle(AppColors.error)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Location access required")
                                    .font(.headline)
                                Text("Enable in Settings")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppColors.error.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                RidingSettingsView()
            }
        }
        .sheet(item: $showingDisciplineSetup) { rideType in
            DisciplineSetupSheet(rideType: rideType, tracker: tracker)
                .onAppear {
                    Log.ui.info("Sheet presenting for rideType: \(rideType.rawValue)")
                }
        }
        .onChange(of: showingDisciplineSetup) { oldValue, newValue in
            Log.ui.info("showingDisciplineSetup changed: \(oldValue?.rawValue ?? "nil") -> \(newValue?.rawValue ?? "nil")")
        }
    }
}

// MARK: - Riding Settings View

struct RidingSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Preferences") {
                    Text("Riding settings coming soon")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Riding Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Discipline Selection View

struct DisciplineSelectionView: View {
    @Binding var showingDisciplineSetup: RideType?

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text("Select Discipline")
                .font(.headline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(RideType.allCases, id: \.self) { rideType in
                    Button {
                        Log.ui.info("Discipline button tapped: \(rideType.rawValue)")
                        showingDisciplineSetup = rideType
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: rideType.icon)
                                .font(.title2)
                                .foregroundStyle(rideType.color)

                            Text(rideType.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.ultraThinMaterial)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Discipline Setup Sheet

struct DisciplineSetupSheet: View {
    let rideType: RideType
    let tracker: RideTracker
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationManager.self) private var locationManager: LocationManager?
    @State private var showingExerciseLibrary = false
    @State private var selectedExercise: FlatworkExercise?

    init(rideType: RideType, tracker: RideTracker) {
        Log.ui.info("DisciplineSetupSheet init: rideType=\(rideType.rawValue)")
        self.rideType = rideType
        self.tracker = tracker
    }

    var body: some View {
        let _ = Log.ui.debug("DisciplineSetupSheet body rendering for \(rideType.rawValue)")
        NavigationStack {
            ZStack {
                // Glass background gradient
                LinearGradient(
                    colors: [
                        AppColors.light,
                        rideType.color.opacity(0.1),
                        AppColors.light.opacity(0.5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Discipline-specific setup
                        if rideType == .crossCountry {
                            XCSetupView(
                                optimumTime: Binding(
                                    get: { tracker.xcOptimumTime },
                                    set: { tracker.xcOptimumTime = $0 }
                                ),
                                courseDistance: Binding(
                                    get: { tracker.xcCourseDistance },
                                    set: { tracker.xcCourseDistance = $0 }
                                )
                            )
                            .padding(.horizontal)
                        }

                        if rideType == .schooling {
                            FlatworkSetupView(
                                selectedExercise: $selectedExercise,
                                showingExerciseLibrary: $showingExerciseLibrary
                            )
                            .padding(.horizontal)
                        }

                        // Horse selection
                        HorseSelectionView(selectedHorse: Binding(
                            get: { tracker.selectedHorse },
                            set: { tracker.selectedHorse = $0 }
                        ))
                        .padding(.horizontal)

                        Spacer(minLength: 40)

                        // Start button
                        GlassFloatingButton(
                            icon: "play.fill",
                            color: AppColors.startButton,
                            size: 80,
                            action: {
                                Log.ui.info("Start button tapped for \(rideType.rawValue)")
                                tracker.selectedRideType = rideType
                                Task {
                                    Log.ui.info("Starting ride task...")
                                    await tracker.startRide()
                                    Log.ui.info("Ride started, rideState = \(String(describing: tracker.rideState))")
                                    // Dismiss after ride starts to avoid UI issues
                                    await MainActor.run {
                                        Log.ui.info("Dismissing sheet...")
                                        dismiss()
                                    }
                                }
                            }
                        )
                        .sensoryFeedback(.impact(weight: .heavy), trigger: tracker.rideState)

                        Text("Tap to Start")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingExerciseLibrary) {
            FlatworkLibraryView { exercise in
                selectedExercise = exercise
                showingExerciseLibrary = false
            }
        }
        .onAppear {
            Log.ui.info("DisciplineSetupSheet appeared for \(rideType.rawValue)")
        }
    }
}

// MARK: - Flatwork Setup View

struct FlatworkSetupView: View {
    @Binding var selectedExercise: FlatworkExercise?
    @Binding var showingExerciseLibrary: Bool
    @State private var showingPoleworkLibrary = false
    @State private var selectedPolework: PoleworkExercise?
    @State private var selectedTab: ExerciseTab = .flatwork

    enum ExerciseTab {
        case flatwork
        case polework
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Exercise Setup")
                .font(.headline)
                .foregroundStyle(.primary)

            // Tab selector
            Picker("Exercise Type", selection: $selectedTab) {
                Text("Flatwork").tag(ExerciseTab.flatwork)
                Text("Polework").tag(ExerciseTab.polework)
            }
            .pickerStyle(.segmented)

            if selectedTab == .flatwork {
                flatworkContent
            } else {
                poleworkContent
            }
        }
        .sheet(isPresented: $showingPoleworkLibrary) {
            NavigationStack {
                PoleworkLibraryView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") {
                                showingPoleworkLibrary = false
                            }
                        }
                    }
            }
        }
    }

    // MARK: - Flatwork Content

    @ViewBuilder
    private var flatworkContent: some View {
        // Selected flatwork exercise display
        if let exercise = selectedExercise {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppColors.primary.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: exercise.category.icon)
                            .font(.title3)
                            .foregroundStyle(AppColors.primary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Focus Exercise")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(exercise.name)
                            .font(.headline)
                    }

                    Spacer()

                    Button {
                        selectedExercise = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                // Difficulty and gaits
                HStack(spacing: 8) {
                    Text(exercise.difficulty.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(difficultyColor(for: exercise.difficulty).opacity(0.15))
                        .foregroundStyle(difficultyColor(for: exercise.difficulty))
                        .clipShape(Capsule())

                    Spacer()

                    HStack(spacing: 4) {
                        ForEach(exercise.requiredGaits) { gait in
                            Image(systemName: gait.icon)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        // Browse flatwork exercises button
        Button {
            showingExerciseLibrary = true
        } label: {
            HStack {
                Image(systemName: "figure.equestrian.sports")
                    .font(.title3)

                Text(selectedExercise == nil ? "Browse Flatwork Exercises" : "Change Exercise")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppColors.primary.opacity(0.1))
            .foregroundStyle(AppColors.primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }

        if selectedExercise == nil {
            Text("Circles, transitions, lateral work, and more")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Polework Content

    @ViewBuilder
    private var poleworkContent: some View {
        // Selected polework exercise display
        if let polework = selectedPolework {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: polework.category.icon)
                            .font(.title3)
                            .foregroundStyle(.orange)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Polework Exercise")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(polework.name)
                            .font(.headline)
                    }

                    Spacer()

                    Button {
                        selectedPolework = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                // Distance info
                let spacing = polework.formattedSpacing(for: .average)
                HStack(spacing: 8) {
                    Label("\(polework.numberOfPoles) poles", systemImage: "minus")
                        .font(.caption)

                    Spacer()

                    Text(spacing.metres)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                }
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        // Browse polework exercises button
        Button {
            showingPoleworkLibrary = true
        } label: {
            HStack {
                Image(systemName: "ruler")
                    .font(.title3)

                Text(selectedPolework == nil ? "Browse Polework Exercises" : "Change Exercise")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.orange.opacity(0.1))
            .foregroundStyle(.orange)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }

        if selectedPolework == nil {
            Text("Ground poles, grids, cavaletti with calculated distances")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    private func difficultyColor(for difficulty: FlatworkDifficulty) -> Color {
        switch difficulty {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
}

// MARK: - Stats Content View

struct StatsContentView: View {
    let tracker: RideTracker
    var onPauseResume: (() -> Void)? = nil
    var onStop: (() -> Void)? = nil
    var onDiscard: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Weather at top right
            if let weather = tracker.currentWeather {
                HStack {
                    Spacer()
                    WeatherBadgeView(weather: weather)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            // Tap hint at top
            Text(tracker.rideState == .paused ? "Tap to Resume" : "Tap to Pause")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            // Stats - scrollable if needed
            ScrollView(showsIndicators: false) {
                LiveStatsView(
                    duration: tracker.formattedElapsedTime,
                    distance: tracker.formattedDistance,
                    speed: tracker.formattedSpeed,
                    gait: tracker.currentGait,
                    isPaused: tracker.rideState == .paused,
                    lead: tracker.currentLead,
                    rein: tracker.currentRein,
                    symmetry: tracker.currentSymmetry,
                    rhythm: tracker.currentRhythm,
                    rideType: tracker.selectedRideType,
                    averageSpeed: tracker.formattedAverageSpeed,
                    elevation: tracker.formattedElevation,
                    elevationGain: tracker.formattedElevationGain,
                    walkPercent: tracker.walkPercent,
                    trotPercent: tracker.trotPercent,
                    canterPercent: tracker.canterPercent,
                    gallopPercent: tracker.gallopPercent,
                    heartRate: tracker.currentHeartRate,
                    heartRateZone: tracker.currentHeartRateZone,
                    averageHeartRate: tracker.averageHeartRate,
                    maxHeartRate: tracker.maxHeartRate,
                    leftReinPercent: tracker.leftReinPercent,
                    rightReinPercent: tracker.rightReinPercent,
                    leftTurnPercent: tracker.leftTurnPercent,
                    rightTurnPercent: tracker.rightTurnPercent,
                    totalTurns: tracker.totalTurns,
                    leftLeadPercent: tracker.leftLeadPercent,
                    rightLeadPercent: tracker.rightLeadPercent,
                    xcTimeDifference: tracker.xcTimeDifferenceFormatted,
                    xcIsAheadOfTime: tracker.xcIsAheadOfTime,
                    xcOptimumTime: tracker.xcOptimumTime,
                    currentSpeedFormatted: tracker.formattedSpeed,
                    currentGradient: tracker.currentGradientFormatted
                )
                .padding(.horizontal)
            }

            Spacer(minLength: 20)

            // Pause/Resume button with stop option
            PauseResumeButton(
                isPaused: tracker.rideState == .paused,
                onTap: {
                    onPauseResume?()
                },
                onStop: onStop,
                onDiscard: onDiscard
            )
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Pause/Resume Button with Stop option

struct PauseResumeButton: View {
    let isPaused: Bool
    let onTap: () -> Void
    var onStop: (() -> Void)? = nil
    var onDiscard: (() -> Void)? = nil
    @State private var showingStopOptions = false

    private let buttonSize: CGFloat = 120
    private let stopButtonSize: CGFloat = 70

    var body: some View {
        HStack(spacing: 24) {
            // Stop button - only visible when paused
            if isPaused {
                Button {
                    showingStopOptions = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: stopButtonSize, height: stopButtonSize)
                            .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.1), radius: 6, y: 3)

                        Circle()
                            .fill(Color.red.opacity(0.9))
                            .frame(width: stopButtonSize - 12, height: stopButtonSize - 12)

                        Image(systemName: "stop.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }

            // Main pause/resume button
            Button(action: onTap) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: buttonSize, height: buttonSize)
                        .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.15), radius: 10, y: 5)

                    Circle()
                        .fill(isPaused ? AppColors.startButton.opacity(0.9) : AppColors.warning.opacity(0.9))
                        .frame(width: buttonSize - 16, height: buttonSize - 16)

                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                }
            }
        }
        .animation(.spring(response: 0.3), value: isPaused)
        .confirmationDialog("End Session", isPresented: $showingStopOptions, titleVisibility: .visible) {
            Button("Save") {
                onStop?()
            }
            Button("Discard", role: .destructive) {
                onDiscard?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to save or discard this session?")
        }
    }
}

// MARK: - Pause/Stop Button

struct PauseStopButton: View {
    let isPaused: Bool
    let onPauseResume: () -> Void
    let onStop: () -> Void
    let onDiscard: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var showingStopOptions = false

    private let buttonSize: CGFloat = 180
    private let stopThreshold: CGFloat = -100

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background track for swipe
                Capsule()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: buttonSize + 40, height: buttonSize / 2)
                    .overlay(alignment: .leading) {
                        HStack {
                            Image(systemName: "stop.fill")
                                .font(.title2)
                                .foregroundStyle(.red.opacity(0.6))
                                .padding(.leading, 20)
                            Spacer()
                        }
                    }
                    .opacity(dragOffset < -20 ? 1 : 0)

                // Main button
                Button(action: onPauseResume) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: buttonSize, height: buttonSize)
                            .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.15), radius: 10, y: 5)

                        Circle()
                            .fill(isPaused ? AppColors.startButton.opacity(0.9) : AppColors.warning.opacity(0.9))
                            .frame(width: buttonSize - 20, height: buttonSize - 20)

                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.white)
                    }
                }
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width < 0 {
                                dragOffset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            if dragOffset < stopThreshold {
                                // Show save/discard options
                                withAnimation(.spring()) {
                                    dragOffset = 0
                                }
                                showingStopOptions = true
                            } else {
                                withAnimation(.spring()) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
            }

        }
        .confirmationDialog("End Session", isPresented: $showingStopOptions, titleVisibility: .visible) {
            Button("Save") {
                onStop()
            }
            Button("Discard", role: .destructive) {
                onDiscard()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to save or discard this session?")
        }
    }
}

// MARK: - XC Setup View

struct XCSetupView: View {
    @Binding var optimumTime: TimeInterval
    @Binding var courseDistance: Double

    @State private var minutes: Int = 0
    @State private var seconds: Int = 0
    @State private var distanceMeters: Int = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Cross Country Setup")
                .font(.headline)
                .foregroundStyle(.primary)

            // Optimum Time
            VStack(alignment: .leading, spacing: 8) {
                Text("Optimum Time")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    HStack {
                        TextField("0", value: $minutes, format: .number)
                            .keyboardType(.numberPad)
                            .frame(width: 50)
                            .multilineTextAlignment(.center)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Text("min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        TextField("0", value: $seconds, format: .number)
                            .keyboardType(.numberPad)
                            .frame(width: 50)
                            .multilineTextAlignment(.center)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Text("sec")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Course Distance
            VStack(alignment: .leading, spacing: 8) {
                Text("Course Distance")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("0", value: $distanceMeters, format: .number)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                        .multilineTextAlignment(.center)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text("meters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Speed calculation hint
            if minutes > 0 || seconds > 0, distanceMeters > 0 {
                let totalSeconds = Double(minutes * 60 + seconds)
                let speedMps = Double(distanceMeters) / totalSeconds
                let speedKmh = speedMps * 3.6

                Text("Target speed: \(String(format: "%.1f", speedKmh)) km/h")
                    .font(.caption)
                    .foregroundStyle(AppColors.primary)
            }
        }
        .onChange(of: minutes) { _, _ in updateBindings() }
        .onChange(of: seconds) { _, _ in updateBindings() }
        .onChange(of: distanceMeters) { _, _ in updateBindings() }
        .onAppear {
            // Initialize from bindings
            minutes = Int(optimumTime) / 60
            seconds = Int(optimumTime) % 60
            distanceMeters = Int(courseDistance)
        }
    }

    private func updateBindings() {
        optimumTime = TimeInterval(minutes * 60 + seconds)
        courseDistance = Double(distanceMeters)
    }
}

// MARK: - Active Exercise View (During Ride)

struct ActiveExerciseView: View {
    @State private var selectedTab: ExerciseType = .flatwork
    @State private var showingFlatworkDetail: FlatworkExercise?
    @State private var showingPoleworkDetail: PoleworkExercise?

    enum ExerciseType {
        case flatwork
        case polework
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "figure.equestrian.sports")
                    .font(.largeTitle)
                    .foregroundStyle(AppColors.primary)

                Text("Exercise Library")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Quick reference during your ride")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)

            // Type selector
            Picker("Exercise Type", selection: $selectedTab) {
                Text("Flatwork").tag(ExerciseType.flatwork)
                Text("Polework").tag(ExerciseType.polework)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Content
            if selectedTab == .flatwork {
                FlatworkQuickList(showingDetail: $showingFlatworkDetail)
            } else {
                PoleworkQuickList(showingDetail: $showingPoleworkDetail)
            }
        }
        .sheet(item: $showingFlatworkDetail) { exercise in
            NavigationStack {
                FlatworkExerciseDetailView(exercise: exercise)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showingFlatworkDetail = nil
                            }
                        }
                    }
            }
        }
        .sheet(item: $showingPoleworkDetail) { exercise in
            NavigationStack {
                PoleworkExerciseDetailView(exercise: exercise)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showingPoleworkDetail = nil
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Flatwork Quick List

struct FlatworkQuickList: View {
    @Query(sort: \FlatworkExercise.name) private var exercises: [FlatworkExercise]
    @Binding var showingDetail: FlatworkExercise?
    @State private var selectedCategory: FlatworkCategory?

    var filteredExercises: [FlatworkExercise] {
        guard let category = selectedCategory else { return exercises }
        return exercises.filter { $0.category == category }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryFilterButton(title: "All", isActive: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    ForEach(FlatworkCategory.allCases) { category in
                        CategoryFilterButton(
                            title: category.displayName,
                            icon: category.icon,
                            isActive: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Exercise list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredExercises) { exercise in
                        Button {
                            showingDetail = exercise
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: exercise.category.icon)
                                    .font(.title3)
                                    .foregroundStyle(AppColors.primary)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)

                                    Text(exercise.difficulty.displayName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Polework Quick List

struct PoleworkQuickList: View {
    @Query(sort: \PoleworkExercise.name) private var exercises: [PoleworkExercise]
    @Binding var showingDetail: PoleworkExercise?
    @State private var selectedCategory: PoleworkCategory?

    var filteredExercises: [PoleworkExercise] {
        guard let category = selectedCategory else { return exercises }
        return exercises.filter { $0.category == category }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryFilterButton(title: "All", isActive: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    ForEach(PoleworkCategory.allCases) { category in
                        CategoryFilterButton(
                            title: category.displayName,
                            icon: category.icon,
                            isActive: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Exercise list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredExercises) { exercise in
                        Button {
                            showingDetail = exercise
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: exercise.category.icon)
                                    .font(.title3)
                                    .foregroundStyle(.orange)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)

                                    let spacing = exercise.formattedSpacing(for: .average)
                                    Text("\(exercise.numberOfPoles) poles • \(spacing.metres)")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Category Filter Button

struct CategoryFilterButton: View {
    let title: String
    var icon: String? = nil
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? AppColors.primary : Color(.tertiarySystemBackground))
            .foregroundStyle(isActive ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}
