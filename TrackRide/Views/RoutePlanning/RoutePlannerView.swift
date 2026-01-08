//
//  RoutePlannerView.swift
//  TrackRide
//

import SwiftUI
import MapKit

/// Main view for planning horse riding routes
struct RoutePlannerView: View {
    @Environment(\.routePlanning) private var routePlanning
    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var waypoints: [RouteWaypoint] = []
    @State private var calculatedRoute: CalculatedRoute?
    @State private var isCalculating = false

    @State private var routeMode: RouteMode = .pointToPoint
    @State private var targetLoopDistance: Double = 10.0  // km
    @State private var preferences = RoutingPreferences()

    @State private var showingRegionDownload = false
    @State private var showingSavedRoutes = false
    @State private var showingPreferences = false
    @State private var showingRouteDetails = false
    @State private var showingSaveDialog = false

    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingNoDataWarning = false

    @State private var routeName = ""

    enum RouteMode: String, CaseIterable {
        case pointToPoint = "Point to Point"
        case loop = "Loop"
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                mapView
                controlPanel
            }
            .navigationTitle("Plan Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSavedRoutes = true
                    } label: {
                        Image(systemName: "folder")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingPreferences = true
                        } label: {
                            Label("Preferences", systemImage: "slider.horizontal.3")
                        }
                        Button {
                            showingRegionDownload = true
                        } label: {
                            Label("Download Maps", systemImage: "arrow.down.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingRegionDownload) {
                RegionDownloadView()
            }
            .sheet(isPresented: $showingSavedRoutes) {
                SavedRoutesView { route in
                    loadSavedRoute(route)
                }
            }
            .sheet(isPresented: $showingPreferences) {
                RoutingPreferencesView(preferences: $preferences)
            }
            .sheet(isPresented: $showingRouteDetails) {
                if let route = calculatedRoute {
                    RouteDetailsView(route: route) {
                        showingSaveDialog = true
                    }
                }
            }
            .alert("Save Route", isPresented: $showingSaveDialog) {
                TextField("Route name", text: $routeName)
                Button("Cancel", role: .cancel) {}
                Button("Save") { saveRoute() }
            } message: {
                Text("Enter a name for this route")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
            .alert("Map Data Required", isPresented: $showingNoDataWarning) {
                Button("Download") { showingRegionDownload = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please download map data for this area to plan routes.")
            }
        }
    }

    // MARK: - Map View

    private var mapView: some View {
        MapReader { proxy in
            Map(position: $mapPosition) {
                // Waypoint markers
                ForEach(waypoints) { waypoint in
                    Annotation(
                        waypoint.displayName,
                        coordinate: waypoint.coordinate
                    ) {
                        WaypointMarkerView(waypoint: waypoint)
                    }
                }

                // Calculated route polyline
                if let route = calculatedRoute {
                    MapPolyline(coordinates: route.coordinates)
                        .stroke(.blue, style: StrokeStyle(
                            lineWidth: 4,
                            lineCap: .round,
                            lineJoin: .round
                        ))
                }

                // Ghost line connecting waypoints when no route calculated
                if calculatedRoute == nil && waypoints.count >= 2 {
                    MapPolyline(coordinates: waypoints.map(\.coordinate))
                        .stroke(.gray.opacity(0.5), style: StrokeStyle(
                            lineWidth: 3,
                            dash: [10, 5]
                        ))
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .onTapGesture { screenPoint in
                handleMapTap(at: screenPoint, proxy: proxy)
            }
        }
    }

    // MARK: - Control Panel

    private var controlPanel: some View {
        VStack(spacing: 12) {
            // Mode picker
            Picker("Mode", selection: $routeMode) {
                ForEach(RouteMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .onChange(of: routeMode) { _, newMode in
                if newMode == .loop {
                    // In loop mode, keep only start waypoint
                    waypoints = waypoints.filter { $0.waypointType == .start }.prefix(1).map { $0 }
                }
                calculatedRoute = nil
            }

            // Loop distance slider (when in loop mode)
            if routeMode == .loop {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target Distance: \(targetLoopDistance.formatted(.number.precision(.fractionLength(1)))) km")
                        .font(.subheadline)
                    Slider(value: $targetLoopDistance, in: 2...30, step: 0.5)
                }
                .padding(.horizontal)
            }

            // Action buttons
            HStack(spacing: 16) {
                Button {
                    clearWaypoints()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(waypoints.isEmpty)

                Spacer()

                if calculatedRoute != nil {
                    Button {
                        showingRouteDetails = true
                    } label: {
                        Label("Details", systemImage: "info.circle")
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    calculateRoute()
                } label: {
                    if isCalculating {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Label("Route", systemImage: "point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCalculateRoute || isCalculating)
            }
            .padding(.horizontal)

            // Route summary
            if let route = calculatedRoute {
                routeSummaryCard(route)
            }
        }
        .padding(.vertical)
        .background(.ultraThinMaterial)
    }

    private func routeSummaryCard(_ route: CalculatedRoute) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDistance(route.totalDistance))
                    .font(.title2.bold())
                Text("Est. \(formatDuration(route.estimatedDuration)) at walk")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let bridlewayPct = route.wayTypeBreakdown["bridleway"].map({ ($0 / route.totalDistance) * 100 }) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.equestrian.sports")
                        Text("\(Int(bridlewayPct))% bridleway")
                    }
                    .font(.caption)
                    .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Computed Properties

    private var canCalculateRoute: Bool {
        if routeMode == .loop {
            return waypoints.contains { $0.waypointType == .start }
        }
        return waypoints.count >= 2
    }

    // MARK: - Actions

    private func handleMapTap(at point: CGPoint, proxy: MapProxy) {
        guard let coordinate = proxy.convert(point, from: .local) else { return }

        // Check if we have data for this location
        do {
            guard try routePlanning.hasDataForLocation(coordinate) else {
                showingNoDataWarning = true
                return
            }
        } catch {
            // If check fails, try anyway
        }

        // Add appropriate waypoint type
        let waypointType: WaypointType
        if waypoints.isEmpty {
            waypointType = .start
        } else if routeMode == .loop {
            waypointType = .via
        } else {
            waypointType = .end
        }

        // In point-to-point mode, convert previous end to via
        if routeMode == .pointToPoint && waypointType == .end {
            for i in waypoints.indices where waypoints[i].waypointType == .end {
                waypoints[i].waypointType = .via
            }
        }

        let waypoint = RouteWaypoint(
            coordinate: coordinate,
            type: waypointType,
            orderIndex: waypoints.count
        )
        waypoints.append(waypoint)
        calculatedRoute = nil

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func handleMapLongPress(at point: CGPoint, proxy: MapProxy) {
        guard let coordinate = proxy.convert(point, from: .local) else { return }

        // Long press adds an avoid point
        let waypoint = RouteWaypoint(
            coordinate: coordinate,
            type: .avoid,
            orderIndex: waypoints.count
        )
        waypoints.append(waypoint)
        calculatedRoute = nil

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    private func clearWaypoints() {
        waypoints.removeAll()
        calculatedRoute = nil
    }

    private func calculateRoute() {
        isCalculating = true

        Task {
            do {
                if routeMode == .loop {
                    guard let start = waypoints.first(where: { $0.waypointType == .start }) else {
                        throw RoutingError.noNearbyNodes
                    }
                    calculatedRoute = try await routePlanning.calculateLoopRoute(
                        from: start.coordinate,
                        targetDistance: targetLoopDistance * 1000,  // Convert km to m
                        preferences: preferences
                    )
                } else {
                    let orderedWaypoints = waypoints
                        .filter { $0.waypointType != .avoid }
                        .sorted { $0.orderIndex < $1.orderIndex }

                    guard orderedWaypoints.count >= 2 else {
                        throw RoutingError.noNearbyNodes
                    }

                    let start = orderedWaypoints.first!.coordinate
                    let end = orderedWaypoints.last!.coordinate
                    let via = orderedWaypoints.dropFirst().dropLast().map(\.coordinate)

                    calculatedRoute = try await routePlanning.calculateRoute(
                        from: start,
                        to: end,
                        via: Array(via),
                        preferences: preferences
                    )
                }

                // Fit map to route
                if let route = calculatedRoute, !route.coordinates.isEmpty {
                    let region = MKCoordinateRegion(
                        center: route.coordinates[route.coordinates.count / 2],
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                    mapPosition = .region(region)
                }

            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }

            isCalculating = false
        }
    }

    private func saveRoute() {
        guard let route = calculatedRoute else { return }

        do {
            _ = try routePlanning.saveRoute(
                route,
                name: routeName.isEmpty ? "Route" : routeName,
                waypoints: waypoints
            )
            routeName = ""
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func loadSavedRoute(_ route: PlannedRoute) {
        // Load waypoints
        waypoints = route.sortedWaypoints

        // Create calculated route from saved data
        calculatedRoute = CalculatedRoute(
            coordinates: route.coordinates,
            totalDistance: route.totalDistance,
            estimatedDuration: route.estimatedDurationWalk,
            segments: [],  // Segments not stored
            wayTypeBreakdown: route.wayTypeBreakdown,
            surfaceBreakdown: route.surfaceBreakdown
        )

        // Fit map to route
        if !route.coordinates.isEmpty {
            let region = MKCoordinateRegion(
                center: route.coordinates[route.coordinates.count / 2],
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            mapPosition = .region(region)
        }
    }

    // MARK: - Formatting

    private func formatDistance(_ meters: Double) -> String {
        let km = meters / 1000
        return km.formatted(.number.precision(.fractionLength(1))) + " km"
    }

    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }
}

// MARK: - Waypoint Marker View

struct WaypointMarkerView: View {
    let waypoint: RouteWaypoint

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: 36, height: 36)
                .shadow(radius: 2)

            Image(systemName: waypoint.waypointType.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var backgroundColor: Color {
        switch waypoint.waypointType {
        case .start: return .green
        case .end: return .red
        case .via: return .blue
        case .avoid: return .orange
        }
    }
}

#Preview {
    RoutePlannerView()
}
