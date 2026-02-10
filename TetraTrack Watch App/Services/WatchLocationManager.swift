//
//  WatchLocationManager.swift
//  TetraTrack Watch App
//
//  GPS location tracking for autonomous Watch sessions
//  Uses adaptive sampling to balance accuracy and storage
//

import Foundation
import CoreLocation
import Observation
import os

/// Location point captured during a Watch session
struct WatchLocationPoint: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let speed: Double  // m/s
    let course: Double // degrees
    let horizontalAccuracy: Double
    let verticalAccuracy: Double

    init(from location: CLLocation) {
        self.id = UUID()
        self.timestamp = location.timestamp
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.speed = max(0, location.speed)
        self.course = location.course >= 0 ? location.course : 0
        self.horizontalAccuracy = location.horizontalAccuracy
        self.verticalAccuracy = location.verticalAccuracy
    }
}

/// Manages GPS tracking on Apple Watch with adaptive sampling
@Observable
final class WatchLocationManager: NSObject {
    static let shared = WatchLocationManager()

    // MARK: - State

    private(set) var isTracking = false
    private(set) var hasPermission = false
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    // MARK: - Current Metrics

    private(set) var currentSpeed: Double = 0  // m/s
    private(set) var currentAltitude: Double = 0  // meters
    private(set) var totalDistance: Double = 0  // meters
    private(set) var elevationGain: Double = 0  // meters
    private(set) var elevationLoss: Double = 0  // meters
    private(set) var currentLocation: CLLocation?

    // MARK: - Location Points

    private(set) var locationPoints: [WatchLocationPoint] = []

    // MARK: - Adaptive Sampling Config

    /// Minimum interval between samples when moving steadily (seconds)
    private let steadySampleInterval: TimeInterval = 5.0

    /// Speed change threshold to trigger immediate sample (m/s)
    private let speedChangeThreshold: Double = 2.0

    /// Direction change threshold to trigger immediate sample (degrees)
    private let directionChangeThreshold: Double = 15.0

    /// Altitude change threshold to trigger immediate sample (meters)
    private let altitudeChangeThreshold: Double = 5.0

    /// Sample interval when stationary (seconds)
    private let stationarySampleInterval: TimeInterval = 30.0

    /// Speed below which considered stationary (m/s)
    private let stationarySpeedThreshold: Double = 0.5

    // MARK: - Private

    private let locationManager = CLLocationManager()
    private var lastSampledLocation: CLLocation?
    private var lastSampleTime: Date?
    private var lastAltitudeForElevation: Double?

    // MARK: - Initialization

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .fitness
        // Note: On watchOS, background location is handled by HKWorkoutSession
        // allowsBackgroundLocationUpdates is not needed/supported
        updateAuthorizationStatus()
    }

    // MARK: - Authorization

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    private func updateAuthorizationStatus() {
        authorizationStatus = locationManager.authorizationStatus
        hasPermission = authorizationStatus == .authorizedWhenInUse ||
                        authorizationStatus == .authorizedAlways
    }

    // MARK: - Tracking Control

    func startTracking() {
        guard hasPermission else {
            Log.location.warning("No permission to track location")
            requestPermission()
            return
        }

        guard !isTracking else { return }

        // Reset state
        locationPoints = []
        totalDistance = 0
        elevationGain = 0
        elevationLoss = 0
        currentSpeed = 0
        currentAltitude = 0
        lastSampledLocation = nil
        lastSampleTime = nil
        lastAltitudeForElevation = nil

        // Start location updates
        locationManager.startUpdatingLocation()
        isTracking = true

        Log.location.info("Started tracking")
    }

    func stopTracking() {
        guard isTracking else { return }

        locationManager.stopUpdatingLocation()
        isTracking = false

        Log.location.info("Stopped tracking - \(self.locationPoints.count) points captured")
    }

    // MARK: - Adaptive Sampling Logic

    private func shouldSampleLocation(_ location: CLLocation) -> Bool {
        let now = Date()

        // Always sample the first point
        guard let lastSample = lastSampledLocation,
              let lastTime = lastSampleTime else {
            return true
        }

        let timeSinceLastSample = now.timeIntervalSince(lastTime)
        let isStationary = location.speed < stationarySpeedThreshold

        // Time-based sampling
        if isStationary {
            // When stationary, sample less frequently
            if timeSinceLastSample >= stationarySampleInterval {
                return true
            }
        } else {
            // When moving, sample at steady interval minimum
            if timeSinceLastSample >= steadySampleInterval {
                return true
            }
        }

        // Change-based sampling (only if enough time has passed to avoid spam)
        if timeSinceLastSample >= 1.0 {
            // Speed change
            let speedChange = abs(location.speed - lastSample.speed)
            if speedChange >= speedChangeThreshold {
                return true
            }

            // Direction change (only if moving)
            if location.speed >= stationarySpeedThreshold &&
               lastSample.course >= 0 && location.course >= 0 {
                var directionChange = abs(location.course - lastSample.course)
                if directionChange > 180 {
                    directionChange = 360 - directionChange
                }
                if directionChange >= directionChangeThreshold {
                    return true
                }
            }

            // Altitude change
            let altitudeChange = abs(location.altitude - lastSample.altitude)
            if altitudeChange >= altitudeChangeThreshold {
                return true
            }
        }

        return false
    }

    private func processLocation(_ location: CLLocation) {
        // Update current metrics
        currentSpeed = max(0, location.speed)
        currentAltitude = location.altitude
        currentLocation = location

        // Calculate distance from last sampled point
        if let lastSample = lastSampledLocation {
            let distance = location.distance(from: lastSample)
            // Only add distance if it seems reasonable (filter GPS noise)
            if distance < 100 && location.horizontalAccuracy < 50 {
                totalDistance += distance
            }
        }

        // Calculate elevation changes
        if let lastAlt = lastAltitudeForElevation {
            let altChange = location.altitude - lastAlt
            if abs(altChange) > 1.0 {  // Filter noise
                if altChange > 0 {
                    elevationGain += altChange
                } else {
                    elevationLoss += abs(altChange)
                }
                lastAltitudeForElevation = location.altitude
            }
        } else {
            lastAltitudeForElevation = location.altitude
        }

        // Check if we should sample this location
        if shouldSampleLocation(location) {
            let point = WatchLocationPoint(from: location)
            locationPoints.append(point)
            lastSampledLocation = location
            lastSampleTime = Date()
        }
    }

    // MARK: - Data Access

    /// Get encoded location points for transfer
    func getEncodedPoints() -> Data? {
        try? JSONEncoder().encode(locationPoints)
    }

    /// Clear stored points (after successful sync)
    func clearPoints() {
        locationPoints = []
    }

    /// Average speed during session (m/s)
    var averageSpeed: Double {
        guard !locationPoints.isEmpty else { return 0 }
        let speeds = locationPoints.map { $0.speed }.filter { $0 > 0 }
        guard !speeds.isEmpty else { return 0 }
        return speeds.reduce(0, +) / Double(speeds.count)
    }

    /// Maximum speed during session (m/s)
    var maxSpeed: Double {
        locationPoints.map { $0.speed }.max() ?? 0
    }
}

// MARK: - CLLocationManagerDelegate

extension WatchLocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isTracking else { return }

        for location in locations {
            // Filter out inaccurate readings
            guard location.horizontalAccuracy >= 0,
                  location.horizontalAccuracy < 100 else {
                continue
            }

            processLocation(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Log.location.error("Location error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updateAuthorizationStatus()
        Log.location.info("Authorization changed to \(self.authorizationStatus.rawValue)")
    }
}
