//
//  ServiceProtocols.swift
//  TrackRide
//
//  Protocols for dependency injection - enables testing and decoupling

import Foundation
import CoreLocation
import SwiftData

// MARK: - Audio Coach Protocol

/// Protocol for voice coaching services during rides
protocol AudioCoaching: AnyObject {
    var isEnabled: Bool { get set }
    var volume: Float { get set }

    func startSession()
    func endSession(distance: Double, duration: TimeInterval)
    func announce(_ message: String)
    func stopSpeaking()

    func processGaitChange(from oldGait: GaitType, to newGait: GaitType)
    func processDistance(_ distance: Double)
    func processTime(_ elapsed: TimeInterval)
    func processHeartRateZone(_ zone: HeartRateZone)

    func announceSessionSummary(_ narrative: String)
    func processSafetyStatus(elapsedTime: TimeInterval, fallDetectionActive: Bool)
    func resetSafetyStatus()
}

// MARK: - Weather Service Protocol

/// Protocol for weather data fetching
protocol WeatherFetching: AnyObject {
    var currentConditions: WeatherConditions? { get }
    var isLoading: Bool { get }
    var lastError: Error? { get }

    @MainActor
    func fetchWeather(for location: CLLocation) async throws -> WeatherConditions

    @MainActor
    func fetchWeatherWithForecast(for location: CLLocation) async throws -> (current: WeatherConditions, precipChance: Double)

    func clearCache()
}

// MARK: - Family Sharing Protocol

/// Protocol for CloudKit-based family location sharing
protocol FamilySharing: AnyObject {
    var isSignedIn: Bool { get }
    var isCloudKitAvailable: Bool { get }
    var currentUserName: String { get }
    var sharedWithMe: [LiveTrackingSession] { get }
    var mySession: LiveTrackingSession? { get }

    func setup() async
    func startSharingLocation() async
    func stopSharingLocation() async
    func updateSharedLocation(
        location: CLLocation,
        gait: GaitType,
        distance: Double,
        duration: TimeInterval
    ) async
    @discardableResult
    func fetchFamilyLocations() async -> Bool
    func shareWithFamilyMember(email: String) async -> URL?
}

// MARK: - Unified Sharing Protocol

/// Protocol for the unified sharing coordinator
/// Provides access to all sharing functionality through a single interface
protocol UnifiedSharing: FamilySharing {
    // Account state
    var currentUserID: String { get }
    var isSetupComplete: Bool { get }
    var errorMessage: String? { get }

    // Linked riders
    var linkedRiders: [LinkedRider] { get }

    // Relationship management
    func fetchRelationships() throws -> [SharingRelationship]
    func fetchRelationships(type: RelationshipType) throws -> [SharingRelationship]
    func fetchFamilyMembers() throws -> [SharingRelationship]
    func fetchEmergencyContacts() throws -> [SharingRelationship]
    func createRelationship(
        name: String,
        type: RelationshipType,
        email: String?,
        phoneNumber: String?,
        preset: PermissionPreset?
    ) -> SharingRelationship?
    func deleteRelationship(_ relationship: SharingRelationship) async

    // Share link generation
    func generateShareLink(for relationship: SharingRelationship) async -> URL?
    func acceptShare(from url: URL) async -> Bool
    func isCloudKitShareURL(_ url: URL) -> Bool

    // Artifact sharing
    func shareArtifact(
        _ artifact: TrainingArtifact,
        with relationship: SharingRelationship,
        expiresIn: TimeInterval?
    ) async throws -> ArtifactShare
    func revokeArtifactShare(_ share: ArtifactShare) async throws
    func shares(for artifactID: UUID) async -> [ArtifactShare]
    func cleanupExpiredShares() async
}

// MARK: - Fall Detection Protocol

/// Protocol for fall detection and emergency alerts
protocol FallDetecting: AnyObject {
    var isMonitoring: Bool { get }
    var fallDetected: Bool { get }
    var countdownSeconds: Int { get }

    func startMonitoring()
    func stopMonitoring()
    func confirmOK()
    func requestEmergency()
}

// MARK: - Health Kit Protocol

/// Protocol for HealthKit integration
protocol HealthKitIntegrating: AnyObject {
    var isAuthorized: Bool { get }

    func requestAuthorization() async throws
    func saveWorkout(
        activityType: String,
        startDate: Date,
        endDate: Date,
        distance: Double,
        calories: Double
    ) async throws
}

// MARK: - Watch Connectivity Protocol

/// Protocol for Watch communication
protocol WatchConnecting: AnyObject {
    var isReachable: Bool { get }
    var isPaired: Bool { get }

    func activate()
    func sendStatusUpdate(
        rideState: SharedRideState,
        duration: TimeInterval,
        distance: Double,
        speed: Double,
        gait: String,
        heartRate: Int?,
        heartRateZone: Int?,
        averageHeartRate: Int?,
        maxHeartRate: Int?,
        horseName: String?,
        rideType: String?,
        walkPercent: Double?,
        trotPercent: Double?,
        canterPercent: Double?,
        gallopPercent: Double?,
        leftTurnCount: Int?,
        rightTurnCount: Int?,
        leftReinPercent: Double?,
        rightReinPercent: Double?,
        leftLeadPercent: Double?,
        rightLeadPercent: Double?,
        symmetryScore: Double?,
        rhythmScore: Double?,
        optimalTime: TimeInterval?,
        timeDifference: TimeInterval?,
        elevation: Double?
    )
}

// MARK: - Route Planning Protocol

/// Protocol for offline route planning services
protocol RoutePlanning: AnyObject {
    /// Whether the service is configured with a model context
    var isConfigured: Bool { get }

    /// Currently active downloads
    var activeDownloads: [String: OSMDataManager.DownloadProgress] { get }

    /// Configure with model context and container
    @MainActor
    func configure(with context: ModelContext, container: ModelContainer)

    /// Download a region for offline routing
    @MainActor
    func downloadRegion(_ region: AvailableRegion) async throws

    /// Delete a downloaded region
    @MainActor
    func deleteRegion(_ regionId: String) async throws

    /// Check if a region is downloaded
    @MainActor
    func isRegionDownloaded(_ regionId: String) async throws -> Bool

    /// Get all downloaded regions
    @MainActor
    func getDownloadedRegions() throws -> [DownloadedRegion]

    /// Fix bounds for an already downloaded region (if bounds were stored incorrectly)
    @MainActor
    func fixRegionBounds(_ region: AvailableRegion) throws

    /// Get incomplete downloads that can be resumed
    @MainActor
    func getIncompleteDownloads() -> [DownloadState]

    /// Resume an incomplete download
    @MainActor
    func resumeDownload(_ state: DownloadState) async throws

    /// Cancel and clean up an incomplete download
    @MainActor
    func cancelDownload(_ regionId: String) async

    /// Calculate a route between points
    func calculateRoute(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        via waypoints: [CLLocationCoordinate2D],
        preferences: RoutingPreferences
    ) async throws -> CalculatedRoute

    /// Calculate a loop route
    func calculateLoopRoute(
        from start: CLLocationCoordinate2D,
        targetDistance: Double,
        preferences: RoutingPreferences
    ) async throws -> CalculatedRoute
}
