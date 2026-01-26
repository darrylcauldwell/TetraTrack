//
//  LocationManager.swift
//  TrackRide
//

import CoreLocation
import Observation
import os

/// A tracked point with location and gait information for map display
struct TrackedPoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let gait: GaitType
    let timestamp: Date
}

/// Circular buffer for O(1) append and automatic size limiting
struct CircularBuffer<T> {
    private var storage: [T?]
    private var writeIndex: Int = 0
    private var count_: Int = 0
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        self.storage = Array(repeating: nil, count: capacity)
    }

    var count: Int { count_ }
    var isEmpty: Bool { count_ == 0 }

    mutating func append(_ element: T) {
        storage[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity
        if count_ < capacity {
            count_ += 1
        }
    }

    mutating func removeAll() {
        storage = Array(repeating: nil, count: capacity)
        writeIndex = 0
        count_ = 0
    }

    /// Returns elements in chronological order (oldest first)
    var elements: [T] {
        guard count_ > 0 else { return [] }
        if count_ < capacity {
            return storage[0..<count_].compactMap { $0 }
        }
        // Buffer is full - return from writeIndex (oldest) to end, then start to writeIndex
        let tail = storage[writeIndex..<capacity].compactMap { $0 }
        let head = storage[0..<writeIndex].compactMap { $0 }
        return tail + head
    }
}

@Observable
final class LocationManager: NSObject {
    // Published state
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentLocation: CLLocation?
    var isTracking: Bool = false
    var locationError: Error?

    // GPS Signal Quality (updated with each location update)
    var gpsSignalQuality: GPSSignalQuality = .none
    var gpsHorizontalAccuracy: Double = -1  // Raw accuracy in meters (-1 = no signal)

    // Tracked points for gait-colored map display (circular buffer for O(1) appends)
    private var _trackedPointsBuffer = CircularBuffer<TrackedPoint>(capacity: 1000)
    var trackedPoints: [TrackedPoint] { _trackedPointsBuffer.elements }
    var currentGait: GaitType = .stationary

    private let locationManager = CLLocationManager()
    private var updateTask: Task<Void, Never>?
    private var backgroundSession: CLBackgroundActivitySession?

    // Callback for new locations during tracking
    var onLocationUpdate: ((CLLocation) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5  // meters - balance accuracy vs battery
        // Note: allowsBackgroundLocationUpdates is set in startTracking after authorization check
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.activityType = .fitness
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    var hasPermission: Bool {
        authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
    }

    var needsPermission: Bool {
        authorizationStatus == .notDetermined
    }

    var permissionDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    func startTracking() async {
        Log.location.debug("startTracking() called, hasPermission=\(self.hasPermission), status=\(String(describing: self.authorizationStatus))")
        guard hasPermission else {
            Log.location.warning("startTracking() aborted - no permission")
            return
        }

        isTracking = true
        locationError = nil

        // Enable background location updates (requires authorization)
        if authorizationStatus == .authorizedAlways {
            Log.location.debug("Enabling background location updates...")
            locationManager.allowsBackgroundLocationUpdates = true
        } else {
            Log.location.info("Background location updates not enabled - only 'When In Use' authorization")
        }

        // Start background session for iOS 17+ (only with Always authorization)
        if authorizationStatus == .authorizedAlways {
            Log.location.debug("Starting background activity session...")
            backgroundSession = CLBackgroundActivitySession()
            Log.location.debug("Background session created")
        }

        // Use new iOS 17 CLLocationUpdate API
        Log.location.debug("Starting location updates task...")
        updateTask = Task {
            do {
                Log.location.debug("Creating CLLocationUpdate.liveUpdates...")
                let updates = CLLocationUpdate.liveUpdates(.fitness)
                Log.location.info("Location updates stream created, waiting for updates...")
                for try await update in updates {
                    guard !Task.isCancelled else {
                        Log.location.debug("Location updates cancelled")
                        break
                    }

                    if let location = update.location {
                        await MainActor.run {
                            self.currentLocation = location
                            // Update GPS signal quality
                            self.gpsHorizontalAccuracy = location.horizontalAccuracy
                            self.gpsSignalQuality = GPSSignalQuality(horizontalAccuracy: location.horizontalAccuracy)
                            self.onLocationUpdate?(location)
                        }
                    }
                }
            } catch {
                Log.location.error("Location updates failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.locationError = error
                    self.isTracking = false
                }
            }
        }
        Log.location.debug("Location updates task started")
    }

    func stopTracking() {
        isTracking = false
        updateTask?.cancel()
        updateTask = nil
        backgroundSession?.invalidate()
        backgroundSession = nil
    }

    // MARK: - Gait-Colored Route Tracking

    /// Update the current gait for route coloring
    func updateGait(_ gait: GaitType) {
        currentGait = gait
    }

    /// Add a tracked point with current gait (O(1) operation via circular buffer)
    func addTrackedPoint(_ location: CLLocation) {
        let point = TrackedPoint(
            coordinate: location.coordinate,
            gait: currentGait,
            timestamp: Date()
        )
        _trackedPointsBuffer.append(point)
    }

    /// Clear tracked points when starting a new ride
    func clearTrackedPoints() {
        _trackedPointsBuffer.removeAll()
        currentGait = .stationary
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = error
    }
}
