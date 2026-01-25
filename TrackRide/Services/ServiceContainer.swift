//
//  ServiceContainer.swift
//  TrackRide
//
//  Dependency injection container for services
//  Enables testing by allowing mock implementations

import SwiftUI

// MARK: - Service Container

/// Central container for all injectable services
/// Use this for constructor injection in non-View classes
@MainActor
final class ServiceContainer {
    // Production singleton with real implementations
    static let shared = ServiceContainer()

    // Services (using protocols for testability)
    let audioCoach: AudioCoaching
    let weatherService: WeatherFetching
    let familySharing: FamilySharing
    let unifiedSharing: UnifiedSharingCoordinator
    let fallDetection: FallDetecting
    let watchConnectivity: WatchConnecting
    let routePlanning: RoutePlanningService

    /// Initialize with default (production) implementations
    private init() {
        self.audioCoach = AudioCoachManager.shared
        self.weatherService = WeatherService.shared
        self.unifiedSharing = UnifiedSharingCoordinator.shared
        self.familySharing = UnifiedSharingCoordinator.shared  // Use unified coordinator
        self.fallDetection = FallDetectionManager.shared
        self.watchConnectivity = WatchConnectivityManager.shared
        self.routePlanning = RoutePlanningService()
    }

    /// Initialize with custom implementations (for testing)
    init(
        audioCoach: AudioCoaching,
        weatherService: WeatherFetching,
        familySharing: FamilySharing,
        unifiedSharing: UnifiedSharingCoordinator? = nil,
        fallDetection: FallDetecting,
        watchConnectivity: WatchConnecting,
        routePlanning: RoutePlanningService? = nil
    ) {
        self.audioCoach = audioCoach
        self.weatherService = weatherService
        self.familySharing = familySharing
        self.unifiedSharing = unifiedSharing ?? UnifiedSharingCoordinator.shared
        self.fallDetection = fallDetection
        self.watchConnectivity = watchConnectivity
        self.routePlanning = routePlanning ?? RoutePlanningService()
    }
}

// MARK: - Environment Keys

private struct AudioCoachKey: EnvironmentKey {
    static let defaultValue: AudioCoaching = AudioCoachManager.shared
}

private struct WeatherServiceKey: EnvironmentKey {
    static let defaultValue: WeatherFetching = WeatherService.shared
}

private struct FamilySharingKey: EnvironmentKey {
    static let defaultValue: FamilySharing = UnifiedSharingCoordinator.shared
}

private struct UnifiedSharingKey: EnvironmentKey {
    static let defaultValue: UnifiedSharingCoordinator = UnifiedSharingCoordinator.shared
}

private struct FallDetectionKey: EnvironmentKey {
    static let defaultValue: FallDetecting = FallDetectionManager.shared
}

private struct WatchConnectivityKey: EnvironmentKey {
    static let defaultValue: WatchConnecting = WatchConnectivityManager.shared
}

private struct RoutePlanningKey: EnvironmentKey {
    static let defaultValue: RoutePlanningService = ServiceContainer.shared.routePlanning
}

// MARK: - Environment Values Extension

extension EnvironmentValues {
    var audioCoach: AudioCoaching {
        get { self[AudioCoachKey.self] }
        set { self[AudioCoachKey.self] = newValue }
    }

    var weatherService: WeatherFetching {
        get { self[WeatherServiceKey.self] }
        set { self[WeatherServiceKey.self] = newValue }
    }

    var familySharing: FamilySharing {
        get { self[FamilySharingKey.self] }
        set { self[FamilySharingKey.self] = newValue }
    }

    var unifiedSharing: UnifiedSharingCoordinator {
        get { self[UnifiedSharingKey.self] }
        set { self[UnifiedSharingKey.self] = newValue }
    }

    var fallDetection: FallDetecting {
        get { self[FallDetectionKey.self] }
        set { self[FallDetectionKey.self] = newValue }
    }

    var watchConnectivity: WatchConnecting {
        get { self[WatchConnectivityKey.self] }
        set { self[WatchConnectivityKey.self] = newValue }
    }

    var routePlanning: RoutePlanningService {
        get { self[RoutePlanningKey.self] }
        set { self[RoutePlanningKey.self] = newValue }
    }
}

// MARK: - View Modifier for Injecting Test Services

extension View {
    /// Inject custom services for testing or previews
    func withServices(_ container: ServiceContainer) -> some View {
        self
            .environment(\.audioCoach, container.audioCoach)
            .environment(\.weatherService, container.weatherService)
            .environment(\.familySharing, container.familySharing)
            .environment(\.unifiedSharing, container.unifiedSharing)
            .environment(\.fallDetection, container.fallDetection)
            .environment(\.watchConnectivity, container.watchConnectivity)
            .environment(\.routePlanning, container.routePlanning)
    }
}
