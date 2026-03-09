//
//  GPSLocationFilter.swift
//  TetraTrack
//

import CoreLocation
import Observation
import os

/// Activity types for GPS filtering — each has different speed and accuracy thresholds
enum GPSActivityType {
    case riding
    case running
    case walking
    case swimming

    /// Maximum plausible speed in m/s for this activity
    var maxSpeed: Double {
        switch self {
        case .riding:   return 25   // 90 km/h
        case .running:  return 12   // 43 km/h
        case .walking:  return 4    // 14 km/h
        case .swimming: return 3    // 11 km/h
        }
    }

    /// Reject locations with horizontal accuracy above this (meters)
    var accuracyRejectThreshold: Double {
        switch self {
        case .riding:   return 30
        case .running:  return 50
        case .walking:  return 50
        case .swimming: return 100
        }
    }

    /// Locations above this accuracy are trusted less by Kalman filter
    var accuracyReducedTrustThreshold: Double {
        switch self {
        case .riding:   return 15
        case .running:  return 20
        case .walking:  return 20
        case .swimming: return 50
        }
    }

    /// Whether this activity type can use CMPedometer as a fallback distance source during GPS gaps
    var supportsPedometerFallback: Bool {
        switch self {
        case .running, .walking: return true
        case .riding, .swimming: return false
        }
    }

    /// Kalman process noise scalar — higher = more responsive, lower = smoother
    var processNoiseScalar: Double {
        switch self {
        case .riding:   return 3.0
        case .running:  return 2.0
        case .walking:  return 1.0
        case .swimming: return 0.5
        }
    }
}

/// A 2D Kalman filter for GPS smoothing.
/// State vector: [lat, lon, velocity_lat, velocity_lon]
/// Measurement: [lat, lon] from CLLocation
private struct KalmanState {
    // State: [lat, lon, vLat, vLon]
    var lat: Double = 0
    var lon: Double = 0
    var vLat: Double = 0
    var vLon: Double = 0

    // Error covariance (diagonal approximation for performance)
    var pLat: Double = 1000
    var pLon: Double = 1000
    var pVLat: Double = 1000
    var pVLon: Double = 1000

    var isInitialized: Bool = false

    mutating func initialize(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
        self.vLat = 0
        self.vLon = 0
        self.pLat = 1000
        self.pLon = 1000
        self.pVLat = 1000
        self.pVLon = 1000
        self.isInitialized = true
    }

    /// Predict step: advance state by dt seconds
    mutating func predict(dt: Double, processNoise: Double) {
        // State prediction: position += velocity * dt
        lat += vLat * dt
        lon += vLon * dt

        // Covariance prediction (simplified diagonal)
        let q = processNoise * dt
        pLat += pVLat * dt * dt + q
        pLon += pVLon * dt * dt + q
        pVLat += q
        pVLon += q
    }

    /// Update step: incorporate a GPS measurement
    mutating func update(measuredLat: Double, measuredLon: Double, measurementNoise: Double) {
        // Kalman gain for position
        let kLat = pLat / (pLat + measurementNoise)
        let kLon = pLon / (pLon + measurementNoise)

        // Kalman gain for velocity (derived from position innovation)
        let kVLat = pVLat / (pLat + measurementNoise)
        let kVLon = pVLon / (pLon + measurementNoise)

        // Innovation (measurement residual)
        let innovLat = measuredLat - lat
        let innovLon = measuredLon - lon

        // State update
        lat += kLat * innovLat
        lon += kLon * innovLon
        vLat += kVLat * innovLat
        vLon += kVLon * innovLon

        // Covariance update
        pLat *= (1 - kLat)
        pLon *= (1 - kLon)
        pVLat *= (1 - kVLat)
        pVLon *= (1 - kVLon)
    }
}

/// Reason a raw GPS location was rejected by the filter pipeline
enum GPSFilterRejectReason: Error {
    case invalidAccuracy        // horizontalAccuracy < 0
    case staleTimestamp          // older than 10s
    case accuracyTooLow          // above activity threshold
    case warmingUp               // within 5s warm-up window
    case speedTooHigh            // exceeds activity max speed
    case accelerationTooHigh     // physically impossible
    case zeroTimeDelta           // duplicate timestamp
}

/// GPS filtering pipeline: staleness → accuracy gating → speed outlier rejection → Kalman smoothing.
/// Produces cleaned CLLocations with reduced noise and eliminated outliers.
@Observable
final class GPSLocationFilter {
    /// Whether the filter has passed the warm-up period and is producing output
    private(set) var isWarmedUp: Bool = false

    private var activityType: GPSActivityType = .running
    private var kalman = KalmanState()
    private var lastFilteredLocation: CLLocation?
    private var lastRawLocation: CLLocation?
    private var startTime: Date?
    private var warmUpBuffer: [CLLocation] = []

    private static let warmUpDuration: TimeInterval = 5
    private static let warmUpAccuracyThreshold: Double = 15
    private static let stalenessThreshold: TimeInterval = 10
    private static let maxAcceleration: Double = 10 // m/s²

    /// Configure filter for a specific activity type
    func configure(activityType: GPSActivityType) {
        self.activityType = activityType
    }

    /// Start a new filtering session
    func start() {
        reset()
        startTime = Date()
    }

    /// Reset all filter state
    func reset() {
        isWarmedUp = false
        kalman = KalmanState()
        lastFilteredLocation = nil
        lastRawLocation = nil
        startTime = nil
        warmUpBuffer.removeAll()
    }

    /// Process a raw CLLocation through the filter pipeline.
    /// Returns a smoothed CLLocation, or nil if the location was rejected.
    func processLocation(_ raw: CLLocation) -> CLLocation? {
        switch processLocationWithReason(raw) {
        case .success(let filtered): return filtered
        case .failure: return nil
        }
    }

    /// Process a raw CLLocation through the filter pipeline with reject reason.
    /// Returns `.success` with a smoothed CLLocation, or `.failure` with the reject reason.
    func processLocationWithReason(_ raw: CLLocation) -> Result<CLLocation, GPSFilterRejectReason> {
        // Stage 1: Timestamp & staleness
        guard raw.horizontalAccuracy >= 0 else { return .failure(.invalidAccuracy) }
        guard Date().timeIntervalSince(raw.timestamp) <= Self.stalenessThreshold else { return .failure(.staleTimestamp) }

        // Stage 2: Accuracy gating
        guard raw.horizontalAccuracy <= activityType.accuracyRejectThreshold else { return .failure(.accuracyTooLow) }

        // Warm-up handling: buffer locations for first N seconds
        if let start = startTime, !isWarmedUp {
            let elapsed = Date().timeIntervalSince(start)
            if elapsed < Self.warmUpDuration {
                warmUpBuffer.append(raw)
                return .failure(.warmingUp)
            }
            // Warm-up period ended — find best-accuracy location to initialize
            let bestLocation = warmUpBuffer
                .filter { $0.horizontalAccuracy < Self.warmUpAccuracyThreshold }
                .min(by: { $0.horizontalAccuracy < $1.horizontalAccuracy })
                ?? warmUpBuffer.last
                ?? raw
            initializeKalman(with: bestLocation)
            isWarmedUp = true
            lastRawLocation = bestLocation
            lastFilteredLocation = bestLocation
            return .success(bestLocation)
        }

        // Stage 3: Speed-based outlier rejection
        if let lastRaw = lastRawLocation {
            let timeDelta = raw.timestamp.timeIntervalSince(lastRaw.timestamp)
            if timeDelta > 0 {
                let distance = raw.distance(from: lastRaw)
                let impliedSpeed = distance / timeDelta

                // Reject if speed exceeds activity maximum
                if impliedSpeed > activityType.maxSpeed {
                    return .failure(.speedTooHigh)
                }

                // Reject if acceleration is physically impossible
                let lastSpeed = lastRaw.speed >= 0 ? lastRaw.speed : 0
                let acceleration = abs(impliedSpeed - lastSpeed) / timeDelta
                if acceleration > Self.maxAcceleration {
                    return .failure(.accelerationTooHigh)
                }
            }
        }

        lastRawLocation = raw

        // Stage 4: Kalman filter smoothing
        if !kalman.isInitialized {
            initializeKalman(with: raw)
            lastFilteredLocation = raw
            return .success(raw)
        }

        let dt = lastFilteredLocation.map { raw.timestamp.timeIntervalSince($0.timestamp) } ?? 1.0
        guard dt > 0 else { return .failure(.zeroTimeDelta) }

        // Predict
        kalman.predict(dt: dt, processNoise: activityType.processNoiseScalar)

        // Measurement noise from horizontal accuracy
        // Scale accuracy to degrees² (rough approximation: 1 degree ≈ 111,000m)
        let metersPerDegree = 111_000.0
        let accuracyDegrees = raw.horizontalAccuracy / metersPerDegree
        var measurementNoise = accuracyDegrees * accuracyDegrees

        // Increase noise for reduced-trust locations
        if raw.horizontalAccuracy > activityType.accuracyReducedTrustThreshold {
            measurementNoise *= 4.0
        }

        // Update
        kalman.update(
            measuredLat: raw.coordinate.latitude,
            measuredLon: raw.coordinate.longitude,
            measurementNoise: measurementNoise
        )

        // Build filtered CLLocation with Kalman-smoothed coordinates
        let filtered = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: kalman.lat, longitude: kalman.lon),
            altitude: raw.altitude,
            horizontalAccuracy: raw.horizontalAccuracy,
            verticalAccuracy: raw.verticalAccuracy,
            course: raw.course,
            speed: raw.speed,
            timestamp: raw.timestamp
        )

        lastFilteredLocation = filtered
        return .success(filtered)
    }

    private func initializeKalman(with location: CLLocation) {
        kalman.initialize(lat: location.coordinate.latitude, lon: location.coordinate.longitude)
    }
}
