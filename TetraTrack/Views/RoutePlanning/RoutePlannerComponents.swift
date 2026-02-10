//
//  RoutePlannerComponents.swift
//  TetraTrack
//

import SwiftUI

// MARK: - Saved Routes View

/// List of saved routes
struct SavedRoutesView: View {
    @Environment(\.routePlanning) private var routePlanning
    @Environment(\.dismiss) private var dismiss

    let onSelect: (PlannedRoute) -> Void

    @State private var routes: [PlannedRoute] = []
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        NavigationStack {
            Group {
                if routes.isEmpty {
                    ContentUnavailableView(
                        "No Saved Routes",
                        systemImage: "map",
                        description: Text("Routes you save will appear here")
                    )
                } else {
                    List {
                        ForEach(routes) { route in
                            SavedRouteRow(route: route)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onSelect(route)
                                    dismiss()
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deleteRoute(route)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Saved Routes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { loadRoutes() }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
    }

    private func loadRoutes() {
        do {
            routes = try routePlanning.getSavedRoutes()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func deleteRoute(_ route: PlannedRoute) {
        do {
            try routePlanning.deleteRoute(route)
            routes.removeAll { $0.id == route.id }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

private struct SavedRouteRow: View {
    let route: PlannedRoute

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(route.name)
                    .font(.body.weight(.medium))
                Spacer()
                if route.isLoopRoute {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            HStack(spacing: 12) {
                Label(route.formattedDistance, systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                Label(route.formattedDuration, systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let wayType = route.primaryWayType {
                Text("Mostly \(wayType)")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Route Details View

/// Detailed view of a calculated route
struct RouteDetailsView: View {
    @Environment(\.dismiss) private var dismiss

    let route: CalculatedRoute
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            List {
                // Summary section
                Section("Summary") {
                    LabeledContent("Distance", value: formatDistance(route.totalDistance))
                    LabeledContent("Est. Duration", value: formatDuration(route.estimatedDuration))
                }

                // Way type breakdown
                Section("Route Composition") {
                    ForEach(route.wayTypeBreakdown.sorted(by: { $0.value > $1.value }), id: \.key) { wayType, distance in
                        HStack {
                            Text(wayType.capitalized)
                            Spacer()
                            Text(formatDistance(distance))
                                .foregroundStyle(.secondary)
                            Text("(\(Int((distance / route.totalDistance) * 100))%)")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }

                // Surface breakdown
                Section("Surface Types") {
                    ForEach(route.surfaceBreakdown.sorted(by: { $0.value > $1.value }), id: \.key) { surface, distance in
                        HStack {
                            Text(surface.capitalized)
                            Spacer()
                            Text(formatDistance(distance))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Route Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
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

// MARK: - Routing Preferences View

/// Settings for route calculation preferences
struct RoutingPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var preferences: RoutingPreferences

    var body: some View {
        NavigationStack {
            Form {
                Section("Route Preferences") {
                    Toggle("Prefer Bridleways", isOn: $preferences.preferBridleways)
                    Toggle("Avoid Roads", isOn: $preferences.avoidRoads)
                    Toggle("Prefer Grass Surface", isOn: $preferences.preferGrassSurface)
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("How Preferences Work", systemImage: "info.circle")
                            .font(.subheadline.weight(.semibold))
                        Text("These preferences adjust the cost calculations for route finding. The router will try to find paths that match your preferences while still finding a reasonable route.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview("Saved Routes") {
    SavedRoutesView { _ in }
}

#Preview("Preferences") {
    RoutingPreferencesView(preferences: .constant(RoutingPreferences()))
}
