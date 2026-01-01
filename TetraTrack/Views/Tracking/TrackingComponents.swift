//
//  TrackingComponents.swift
//  TetraTrack
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
                        .background(AppColors.cardBackground)
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
            .presentationBackground(Color.black)
        }
        .sheet(item: $showingDisciplineSetup) { rideType in
            DisciplineSetupSheet(rideType: rideType, tracker: tracker)
                .presentationBackground(Color.black)
                .onAppear {
                    Log.ui.info("Sheet presenting for rideType: \(rideType.rawValue)")
                }
        }
        .onChange(of: showingDisciplineSetup) { oldValue, newValue in
            Log.ui.info("showingDisciplineSetup changed: \(oldValue?.rawValue ?? "nil") -> \(newValue?.rawValue ?? "nil")")
        }
        .presentationBackground(Color.black)
    }
}

// MARK: - Riding Settings View

struct RidingSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: Bindable(PocketModeManager.shared).autoActivateEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pocket Mode (Full Sensor)")
                                .font(.subheadline)
                            Text("Blacks out screen via proximity sensor, keeping all motion sensors active at full rate.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Sensor Mode")
                } footer: {
                    Text("When disabled, locking the screen with the side button limits motion sensors. Gait detection falls back to GPS speed only.")
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
                                .fill(AppColors.cardBackground)
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
    @Query(filter: #Predicate<SharingRelationship> {
        $0.receiveFallAlerts == true && $0.phoneNumber != nil
    }) private var emergencyContacts: [SharingRelationship]
    @State private var showingExerciseLibrary = false
    @State private var selectedExercise: FlatworkExercise?
    @State private var showingCountdown = false
    @State private var showingNoEmergencyContactAlert = false

    init(rideType: RideType, tracker: RideTracker) {
        Log.ui.info("DisciplineSetupSheet init: rideType=\(rideType.rawValue)")
        self.rideType = rideType
        self.tracker = tracker
    }

    var body: some View {
        let _ = Log.ui.debug("DisciplineSetupSheet body rendering for \(rideType.rawValue)")
        ZStack {
            // True black background
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(AppColors.cardBackground)
                            .clipShape(Circle())
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Discipline header
                        VStack(spacing: 16) {
                            // Icon
                            ZStack {
                                Circle()
                                    .fill(rideType.color.opacity(0.15))
                                    .frame(width: 80, height: 80)

                                Image(systemName: rideType.icon)
                                    .font(.system(size: 36))
                                    .foregroundStyle(rideType.color)
                            }

                            // Title and description
                            VStack(spacing: 8) {
                                Text(rideType.rawValue)
                                    .font(.title.weight(.bold))

                                Text(rideType.description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                        }
                        .padding(.top, 20)

                        // Start button - at the top for quick start
                        VStack(spacing: 12) {
                            GlassFloatingButton(
                                icon: "play.fill",
                                color: AppColors.startButton,
                                size: 80,
                                action: {
                                    Log.ui.info("Start button tapped for \(rideType.rawValue)")
                                    tracker.selectedRideType = rideType
                                    let hasValidContact = emergencyContacts.contains {
                                        if let phone = $0.phoneNumber {
                                            return PhoneNumberValidator.validate(phone).isAcceptable
                                        }
                                        return false
                                    }
                                    if hasValidContact {
                                        showingCountdown = true
                                    } else {
                                        showingNoEmergencyContactAlert = true
                                    }
                                }
                            )
                            .sensoryFeedback(.impact(weight: .heavy), trigger: tracker.rideState)

                            Text("Tap to Start")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

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
                            .padding(16)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 20)
                        }

                        if rideType == .schooling {
                            FlatworkSetupView(
                                selectedExercise: $selectedExercise,
                                showingExerciseLibrary: $showingExerciseLibrary
                            )
                            .padding(16)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 20)
                        }

                        // Horse selection card
                        VStack(alignment: .leading, spacing: 12) {
                            HorseSelectionView(selectedHorse: Binding(
                                get: { tracker.selectedHorse },
                                set: { tracker.selectedHorse = $0 }
                            ))
                        }
                        .padding(16)
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)

                        // Phone placement tips
                        PhonePlacementTipView()
                            .padding(.horizontal, 20)

                        // Sensor mode selection (pocket mode)
                        SensorModeCard(pocketModeManager: PocketModeManager.shared)
                            .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showingExerciseLibrary) {
            FlatworkLibraryView { exercise in
                selectedExercise = exercise
                showingExerciseLibrary = false
            }
        }
        .fullScreenCover(isPresented: $showingCountdown) {
            CountdownOverlay(
                onComplete: {
                    showingCountdown = false
                    Task {
                        Log.ui.info("Countdown complete, starting ride...")
                        await tracker.startRide()
                        Log.ui.info("Ride started, rideState = \(String(describing: tracker.rideState))")
                        await MainActor.run {
                            Log.ui.info("Dismissing sheet...")
                            dismiss()
                        }
                    }
                },
                onCancel: {
                    Log.ui.info("Countdown cancelled")
                    showingCountdown = false
                }
            )
            .presentationBackground(.clear)
        }
        .alert("No Emergency Contacts", isPresented: $showingNoEmergencyContactAlert) {
            Button("Continue Anyway") {
                showingCountdown = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("No emergency contacts have valid phone numbers. Fall detection SMS alerts won't be sent during this ride.")
        }
        .onAppear {
            Log.ui.info("DisciplineSetupSheet appeared for \(rideType.rawValue)")
        }
        .presentationBackground(Color.black)
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
        .presentationBackground(Color.black)
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
            .background(AppColors.elevatedSurface)
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
            .background(AppColors.elevatedSurface)
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
                VStack(spacing: 24) {
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
                        leftLeadPercent: tracker.leftLeadPercent,
                        rightLeadPercent: tracker.rightLeadPercent,
                        xcTimeDifference: tracker.xcTimeDifferenceFormatted,
                        xcIsAheadOfTime: tracker.xcIsAheadOfTime,
                        xcOptimumTime: tracker.xcOptimumTime,
                        currentSpeedFormatted: tracker.formattedSpeed,
                        currentGradient: tracker.currentGradientFormatted
                    )

                    // Watch sensor metrics
                    if tracker.jumpCount > 0 || tracker.activeRidingPercent > 0 {
                        Divider()
                            .padding(.horizontal)

                        RiderSensorMetricsView(
                            jumpCount: tracker.jumpCount,
                            activePercent: tracker.activeRidingPercent,
                            rideType: tracker.selectedRideType
                        )
                    }
                }
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
                            .fill(AppColors.cardBackground)
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
                        .fill(AppColors.cardBackground)
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
                            .fill(AppColors.cardBackground)
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
                            .background(AppColors.cardBackground)
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
                            .background(AppColors.cardBackground)
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
                        .background(AppColors.cardBackground)
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
        .presentationBackground(Color.black)
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
                            .background(AppColors.elevatedSurface)
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
                            .background(AppColors.elevatedSurface)
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
            .background(isActive ? AppColors.primary : AppColors.elevatedSurface)
            .foregroundStyle(isActive ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Phone Placement Tips

/// Shows tips for optimal phone placement during riding
/// Phone position significantly affects gait detection accuracy
struct PhonePlacementTipView: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header - tap to expand
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "iphone")
                        .font(.title3)
                        .foregroundStyle(AppColors.primary)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Phone Placement")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("For accurate gait detection")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    // Best option - jodhpur pocket (with position-aware calibration)
                    PlacementOptionRow(
                        icon: "checkmark.circle.fill",
                        iconColor: .green,
                        title: "Jodhpur pocket (thigh)",
                        subtitle: "Recommended - adaptive calibration compensates for leg movement",
                        isRecommended: true
                    )

                    // Good option
                    PlacementOptionRow(
                        icon: "checkmark.circle",
                        iconColor: .yellow,
                        title: "Jacket pocket (chest)",
                        subtitle: "Good accuracy - torso stays stable relative to horse",
                        isRecommended: false
                    )

                    // Not recommended
                    PlacementOptionRow(
                        icon: "xmark.circle",
                        iconColor: .red,
                        title: "Arm band or loose pocket",
                        subtitle: "Not recommended - arm swing or bouncing corrupts data",
                        isRecommended: false
                    )

                    // Security tip
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(AppColors.primary)
                        Text("Secure the phone firmly - loose phones add noise that affects detection accuracy")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// Row showing a phone placement option
private struct PlacementOptionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let isRecommended: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                    if isRecommended {
                        Text("Recommended")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Mount Position Picker

/// Segmented picker for selecting phone mount position before a ride
struct MountPositionPicker: View {
    @Binding var position: PhoneMountPosition

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "iphone.gen3")
                    .font(.title3)
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Phone Position")
                        .font(.subheadline.weight(.semibold))
                    Text("Where is your phone during this ride?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Picker("Mount Position", selection: $position) {
                ForEach(PhoneMountPosition.allCases, id: \.self) { pos in
                    Text(pos.rawValue).tag(pos)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Calibration Status Banner

/// Shows calibration progress during ride start
struct CalibrationStatusBanner: View {
    let status: GaitAnalyzer.CalibrationStatus

    var body: some View {
        if status != .ready {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(statusColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Calibrating Sensors")
                        .font(.subheadline.weight(.semibold))
                    Text(status.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
            }
            .padding(12)
            .background(statusColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var statusColor: Color {
        switch status {
        case .pending: return .orange
        case .settling: return .yellow
        case .calibrating: return .blue
        case .ready: return .green
        }
    }

    private var statusIcon: String {
        switch status {
        case .pending: return "hourglass"
        case .settling: return "waveform.path"
        case .calibrating: return "gyroscope"
        case .ready: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Sensor Mode Card

struct SensorModeCard: View {
    @Bindable var pocketModeManager: PocketModeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "sensor.fill")
                    .font(.title3)
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sensor Mode")
                        .font(.subheadline.weight(.semibold))
                    Text("Choose tracking fidelity for this session")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Toggle(isOn: $pocketModeManager.autoActivateEnabled) {
                Text("Full Sensor (Pocket Mode)")
                    .font(.subheadline.weight(.medium))
            }
            .tint(AppColors.primary)

            if pocketModeManager.autoActivateEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text("Screen turns off automatically in your pocket via proximity sensor. All sensors run at full rate.")
                            .font(.caption)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    Label {
                        Text("Gait detection, fall detection, balance analysis, and audio coaching all fully active.")
                            .font(.caption)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text("If you lock the screen with the side button, iOS limits motion sensors. Gait detection uses GPS speed only (less accurate).")
                            .font(.caption)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                    }

                    Label {
                        Text("GPS tracking, elapsed time, and audio coaching still work. Fall detection countdown is reliable.")
                            .font(.caption)
                    } icon: {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                }
                .foregroundStyle(.secondary)
            }

            if !pocketModeManager.isSensorAvailable {
                Label {
                    Text("Proximity sensor not available on this device. Reduced sensor mode will be used.")
                        .font(.caption)
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.orange)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Pocket Mode Indicator

struct PocketModeIndicator: View {
    var body: some View {
        let manager = PocketModeManager.shared
        if manager.isMonitoring {
            Image(systemName: manager.isPocketModeActive ? "sensor.fill" : "sensor")
                .font(.body.weight(.medium))
                .foregroundStyle(manager.isPocketModeActive ? AppColors.primary : .secondary)
                .frame(width: 44, height: 44)
                .background(AppColors.cardBackground)
                .clipShape(Circle())
                .animation(.easeInOut(duration: 0.3), value: manager.isPocketModeActive)
        }
    }
}
