//
//  RoutePlanningService.swift
//  TrackRide
//

import Foundation
import SwiftData
import CoreLocation
import os

/// Combined service for offline route planning
/// Coordinates OSMDataManager (downloads) and HorseRoutingEngine (routing)
@Observable
@MainActor
final class RoutePlanningService: RoutePlanning {

    // MARK: - State

    private(set) var isConfigured = false
    private var dataManager: OSMDataManager
    private var routingEngine: HorseRoutingEngine?
    private var modelContext: ModelContext?

    private let logger = Logger(subsystem: "com.trackride", category: "RoutePlanningService")

    // MARK: - RoutePlanning Protocol

    var activeDownloads: [String: OSMDataManager.DownloadProgress] {
        dataManager.activeDownloads
    }

    // MARK: - Initialization

    init() {
        self.dataManager = OSMDataManager()
    }

    func configure(with context: ModelContext, container: ModelContainer) {
        guard !isConfigured else { return }

        self.modelContext = context
        self.dataManager.configure(with: context, container: container)
        self.routingEngine = HorseRoutingEngine(modelContext: context)
        self.isConfigured = true

        logger.info("RoutePlanningService configured")
    }

    // MARK: - Region Management

    func downloadRegion(_ region: AvailableRegion) async throws {
        try await dataManager.downloadRegion(region)
    }

    func deleteRegion(_ regionId: String) async throws {
        try await dataManager.deleteRegion(regionId)
    }

    func isRegionDownloaded(_ regionId: String) async throws -> Bool {
        try await dataManager.isRegionDownloaded(regionId)
    }

    func getDownloadedRegions() throws -> [DownloadedRegion] {
        try dataManager.getDownloadedRegions()
    }

    /// Fix bounds for an already downloaded region
    /// This is needed if the region was downloaded with incorrect bounds (from parsed data instead of predefined bounds)
    func fixRegionBounds(_ region: AvailableRegion) throws {
        try dataManager.fixRegionBounds(region)
    }

    /// Get incomplete downloads that can be resumed
    func getIncompleteDownloads() -> [DownloadState] {
        dataManager.getIncompleteDownloads()
    }

    /// Restore download state from persistence (call when app returns to foreground)
    func restoreDownloadState() {
        dataManager.restoreDownloadState()
    }

    /// Resume an incomplete download
    func resumeDownload(_ state: DownloadState) async throws {
        try await dataManager.resumeDownload(state)
    }

    /// Cancel and clean up an incomplete download
    func cancelDownload(_ regionId: String) async {
        await dataManager.cancelDownload(regionId)
    }

    /// Find available regions that contain a coordinate
    func availableRegions(for coordinate: CLLocationCoordinate2D) -> [AvailableRegion] {
        AvailableRegion.ukRegions.filter { $0.contains(coordinate) }
    }

    /// Check if routing data is available for a coordinate
    func hasDataForLocation(_ coordinate: CLLocationCoordinate2D) throws -> Bool {
        let regions = try dataManager.regionsContaining(coordinate)
        return !regions.isEmpty
    }

    // MARK: - Route Calculation

    func calculateRoute(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        via waypoints: [CLLocationCoordinate2D] = [],
        preferences: RoutingPreferences = RoutingPreferences()
    ) async throws -> CalculatedRoute {

        guard let engine = routingEngine else {
            throw RoutingError.regionNotDownloaded
        }

        // Check we have data for start location
        guard try hasDataForLocation(start) else {
            throw OSMDataError.noRegionForLocation
        }

        return try await engine.calculateRoute(
            from: start,
            to: end,
            via: waypoints,
            preferences: preferences
        )
    }

    func calculateLoopRoute(
        from start: CLLocationCoordinate2D,
        targetDistance: Double,
        preferences: RoutingPreferences = RoutingPreferences()
    ) async throws -> CalculatedRoute {

        guard let engine = routingEngine else {
            throw RoutingError.regionNotDownloaded
        }

        // Check we have data for start location
        guard try hasDataForLocation(start) else {
            throw OSMDataError.noRegionForLocation
        }

        return try await engine.calculateLoopRoute(
            from: start,
            targetDistance: targetDistance,
            preferences: preferences
        )
    }

    // MARK: - Route Saving

    /// Save a calculated route to SwiftData
    func saveRoute(
        _ route: CalculatedRoute,
        name: String,
        waypoints: [RouteWaypoint]
    ) throws -> PlannedRoute {

        guard let context = modelContext else {
            throw OSMDataError.notConfigured
        }

        let plannedRoute = PlannedRoute()
        plannedRoute.name = name.isEmpty ? PlannedRoute.defaultName(for: Date()) : name
        plannedRoute.coordinates = route.coordinates
        plannedRoute.totalDistance = route.totalDistance
        plannedRoute.estimatedDurationWalk = route.estimatedDuration
        plannedRoute.surfaceBreakdown = route.surfaceBreakdown
        plannedRoute.wayTypeBreakdown = route.wayTypeBreakdown

        // Add waypoints
        for waypoint in waypoints {
            waypoint.route = plannedRoute
        }
        plannedRoute.waypoints = waypoints

        context.insert(plannedRoute)
        try context.save()

        logger.info("Saved route: \(name) with \(route.coordinates.count) points")

        return plannedRoute
    }

    /// Get all saved routes
    func getSavedRoutes() throws -> [PlannedRoute] {
        guard let context = modelContext else {
            throw OSMDataError.notConfigured
        }

        let descriptor = FetchDescriptor<PlannedRoute>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Delete a saved route
    func deleteRoute(_ route: PlannedRoute) throws {
        guard let context = modelContext else {
            throw OSMDataError.notConfigured
        }

        context.delete(route)
        try context.save()
    }
}
