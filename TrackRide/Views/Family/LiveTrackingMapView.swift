//
//  LiveTrackingMapView.swift
//  TrackRide
//
//  Live family tracking with gait-colored route display
//

import SwiftUI
import SwiftData
import MapKit

struct LiveTrackingMapView: View {
    let session: LiveTrackingSession
    @State private var position: MapCameraPosition
    @State private var refreshTimer: Timer?
    @State private var familySharing = FamilySharingManager.shared
    @State private var showRouteOverlay = true
    @State private var showingExerciseLibrary = false

    init(session: LiveTrackingSession) {
        self.session = session
        self._position = State(initialValue: .region(MKCoordinateRegion(
            center: session.currentCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))
    }

    var body: some View {
        ZStack {
            // Map with gait-colored route
            Map(position: $position) {
                // Gait-colored route polylines
                if showRouteOverlay {
                    ForEach(session.groupedRouteSegments()) { segment in
                        MapPolyline(coordinates: segment.coordinates)
                            .stroke(AppColors.gait(segment.gaitType), lineWidth: 4)
                    }
                }

                // Rider location marker
                Annotation(session.riderName, coordinate: session.currentCoordinate) {
                    RiderMarker(session: session)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapUserLocationButton()
            }

            // Stats overlay
            VStack {
                // Top stats card
                LiveStatsCard(session: session)

                Spacer()

                // Bottom controls
                HStack(spacing: 16) {
                    // Toggle route visibility
                    Button(action: { showRouteOverlay.toggle() }) {
                        VStack(spacing: 4) {
                            Image(systemName: showRouteOverlay ? "point.topleft.down.to.point.bottomright.curvepath.fill" : "point.topleft.down.to.point.bottomright.curvepath")
                                .font(.title2)
                            Text("Route")
                                .font(.caption2)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Spacer()

                    // Center on rider button
                    Button(action: centerOnRider) {
                        VStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.title2)
                            Text("Center")
                                .font(.caption2)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }

            // Gait legend
            if showRouteOverlay && !session.routePoints.isEmpty {
                VStack {
                    Spacer()
                    GaitLegend()
                        .padding(.bottom, 100)
                }
            }
        }
        .navigationTitle("Live Tracking")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingExerciseLibrary = true
                } label: {
                    Label("Exercises", systemImage: "figure.equestrian.sports")
                }
            }
        }
        .sheet(isPresented: $showingExerciseLibrary) {
            NavigationStack {
                SpectatorExerciseLibraryView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showingExerciseLibrary = false
                            }
                        }
                    }
            }
        }
        .onAppear {
            startRefreshing()
        }
        .onDisappear {
            stopRefreshing()
        }
    }

    private func centerOnRider() {
        withAnimation {
            position = .region(MKCoordinateRegion(
                center: session.currentCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }

    private func startRefreshing() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            Task {
                await familySharing.fetchFamilyLocations()
            }
        }
    }

    private func stopRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Rider Marker

struct RiderMarker: View {
    let session: LiveTrackingSession

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .fill(.white)
                .frame(width: 48, height: 48)
                .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.15), radius: 4, y: 2)

            // Inner colored circle based on gait
            Circle()
                .fill(session.isStationary ? AppColors.warning : gaitColor)
                .frame(width: 40, height: 40)

            // Horse icon
            Image(systemName: "figure.equestrian.sports")
                .foregroundStyle(.white)
                .font(.system(size: 20))

            // Live pulse indicator
            if session.isActive && !session.isStationary {
                Circle()
                    .stroke(gaitColor, lineWidth: 2)
                    .frame(width: 48, height: 48)
                    .scaleEffect(1.3)
                    .opacity(0.5)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: session.lastUpdateTime)
            }

            // Warning indicator if stationary too long
            if session.isStationary && session.stationaryDuration > 120 {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppColors.error)
                    .font(.caption)
                    .offset(x: 18, y: -18)
            }
        }
    }

    private var gaitColor: Color {
        AppColors.gait(session.gait)
    }
}

// MARK: - Live Stats Card

struct LiveStatsCard: View {
    let session: LiveTrackingSession

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text(session.riderName.isEmpty ? "Family Member" : session.riderName)
                    .font(.headline)

                Spacer()

                // Status indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(session.isActive ? AppColors.active : AppColors.inactive)
                        .frame(width: 8, height: 8)
                    Text(session.isActive ? "Live" : "Inactive")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(session.isActive ? AppColors.active.opacity(0.1) : Color.gray.opacity(0.1))
                .clipShape(Capsule())
            }

            Divider()

            // Stats row
            HStack(spacing: 0) {
                LiveStatItem(title: "Distance", value: session.formattedDistance, icon: "arrow.left.and.right")
                Divider().frame(height: 30)
                LiveStatItem(title: "Duration", value: session.formattedDuration, icon: "clock")
                Divider().frame(height: 30)
                LiveStatItem(title: "Speed", value: session.formattedSpeed, icon: "speedometer")
            }

            // Current gait
            HStack {
                Image(systemName: session.gait.icon)
                Text(session.gait.rawValue)
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(gaitColor.opacity(0.2))
            .foregroundStyle(gaitColor)
            .clipShape(Capsule())

            // Stationary warning
            if session.isStationary && session.stationaryDuration > 60 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppColors.warning)
                    Text("Stationary for \(Int(session.stationaryDuration / 60)) min")
                        .font(.subheadline)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(AppColors.warning.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Last update
            Text("Updated \(timeAgo(session.lastUpdateTime))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
    }

    private var gaitColor: Color {
        AppColors.gait(session.gait)
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60)) min ago"
        } else {
            return "\(Int(seconds / 3600)) hr ago"
        }
    }
}

// MARK: - Live Stat Item

struct LiveStatItem: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Gait Legend

struct GaitLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            GaitLegendItem(gait: .walk)
            GaitLegendItem(gait: .trot)
            GaitLegendItem(gait: .canter)
            GaitLegendItem(gait: .gallop)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

struct GaitLegendItem: View {
    let gait: GaitType

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(AppColors.gait(gait))
                .frame(width: 8, height: 8)
            Text(gait.rawValue)
                .font(.caption2)
        }
    }
}

// MARK: - Spectator Exercise Library View

struct SpectatorExerciseLibraryView: View {
    @State private var selectedTab: SpectatorExerciseTab = .flatwork
    @State private var selectedHorseSize: HorseSize = .average

    enum SpectatorExerciseTab {
        case flatwork
        case polework
        case reference
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("Category", selection: $selectedTab) {
                Text("Flatwork").tag(SpectatorExerciseTab.flatwork)
                Text("Polework").tag(SpectatorExerciseTab.polework)
                Text("Reference").tag(SpectatorExerciseTab.reference)
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            switch selectedTab {
            case .flatwork:
                SpectatorFlatworkList()
            case .polework:
                SpectatorPoleworkList(horseSize: $selectedHorseSize)
            case .reference:
                SpectatorQuickReference(horseSize: $selectedHorseSize)
            }
        }
        .navigationTitle("Exercise Library")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Spectator Flatwork List

struct SpectatorFlatworkList: View {
    @Query(sort: \FlatworkExercise.name) private var exercises: [FlatworkExercise]
    @State private var selectedCategory: FlatworkCategory?
    @State private var showingDetail: FlatworkExercise?

    var filteredExercises: [FlatworkExercise] {
        guard let category = selectedCategory else { return exercises }
        return exercises.filter { $0.category == category }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SpectatorFilterChip(title: "All", isActive: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    ForEach(FlatworkCategory.allCases) { category in
                        SpectatorFilterChip(
                            title: category.displayName,
                            isActive: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(.secondarySystemBackground))

            // Exercise list
            List(filteredExercises) { exercise in
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
                }
            }
            .listStyle(.plain)
        }
        .sheet(item: $showingDetail) { exercise in
            NavigationStack {
                FlatworkExerciseDetailView(exercise: exercise)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showingDetail = nil
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Spectator Polework List

struct SpectatorPoleworkList: View {
    @Query(sort: \PoleworkExercise.name) private var exercises: [PoleworkExercise]
    @Binding var horseSize: HorseSize
    @State private var selectedCategory: PoleworkCategory?
    @State private var showingDetail: PoleworkExercise?

    var filteredExercises: [PoleworkExercise] {
        guard let category = selectedCategory else { return exercises }
        return exercises.filter { $0.category == category }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Horse size selector
            HStack {
                Image(systemName: "ruler")
                    .foregroundStyle(.orange)
                Text("Horse size:")
                    .font(.caption)
                Picker("Size", selection: $horseSize) {
                    ForEach(HorseSize.allCases) { size in
                        Text(size.shortName).tag(size)
                    }
                }
                .pickerStyle(.menu)
                .tint(.orange)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))

            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SpectatorFilterChip(title: "All", isActive: selectedCategory == nil, color: .orange) {
                        selectedCategory = nil
                    }
                    ForEach(PoleworkCategory.allCases) { category in
                        SpectatorFilterChip(
                            title: category.displayName,
                            isActive: selectedCategory == category,
                            color: .orange
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(.secondarySystemBackground))

            // Exercise list
            List(filteredExercises) { exercise in
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

                            let spacing = exercise.formattedSpacing(for: horseSize)
                            Text("\(exercise.numberOfPoles) poles • \(spacing.metres)")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .listStyle(.plain)
        }
        .sheet(item: $showingDetail) { exercise in
            NavigationStack {
                PoleworkExerciseDetailView(exercise: exercise)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showingDetail = nil
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Spectator Quick Reference

struct SpectatorQuickReference: View {
    @Binding var horseSize: HorseSize

    var body: some View {
        List {
            // Horse size picker
            Section {
                Picker("Horse Size", selection: $horseSize) {
                    ForEach(HorseSize.allCases) { size in
                        Text(size.displayName).tag(size)
                    }
                }
            } header: {
                Text("Select Horse Size")
            }

            // Pole distances
            Section {
                ForEach(PoleExerciseType.allCases) { type in
                    let distance = PoleStrideCalculator.formattedDistance(for: type, horseSize: horseSize)
                    HStack {
                        Label(type.displayName, systemImage: type.icon)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(distance.metres)
                                .font(.headline)
                            Text(distance.feet)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Pole Distances")
            } footer: {
                Text("Recommended starting distances. Adjust based on the horse's individual stride.")
            }

            // Tips section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    tipRow("Start with calculated distance")
                    tipRow("Watch the horse's rhythm through poles")
                    tipRow("If hitting poles, try longer distances")
                    tipRow("If reaching, try shorter distances")
                    tipRow("Raised poles need slightly longer gaps")
                }
            } header: {
                Text("Setup Tips")
            }
        }
    }

    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Spectator Filter Chip

struct SpectatorFilterChip: View {
    let title: String
    let isActive: Bool
    var color: Color = AppColors.primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? color : Color(.tertiarySystemBackground))
                .foregroundStyle(isActive ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

#Preview {
    NavigationStack {
        LiveTrackingMapView(session: {
            let session = LiveTrackingSession()
            session.riderName = "Emma"
            session.isActive = true
            session.currentLatitude = 51.5074
            session.currentLongitude = -0.1278
            session.totalDistance = 5670
            session.elapsedDuration = 3600
            session.currentSpeed = 3.5
            session.currentGait = GaitType.trot.rawValue
            return session
        }())
    }
}
