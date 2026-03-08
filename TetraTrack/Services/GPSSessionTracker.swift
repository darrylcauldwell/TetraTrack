//
//  GPSSessionTracker.swift
//  TetraTrack
//

import CoreLocation
import CoreMotion
import Observation
import SwiftData
import os

/// Shared GPS session tracker used by all disciplines (riding, running, walking, swimming).
/// Manages filtered location tracking, distance accumulation, route storage, wall-clock timer,
/// elevation tracking (barometric + GPS fallback), and GPS signal quality.
///
/// Discipline-specific logic hooks in via `onLocationProcessed` callback.
@Observable
final class GPSSessionTracker {
    // MARK: - Observable State (views bind to these)

    /// Total distance traveled in meters (from filtered GPS)
    private(set) var totalDistance: Double = 0

    /// Route coordinates for map display
    private(set) var routeCoordinates: [CLLocationCoordinate2D] = []

    /// Current speed in m/s from latest filtered location
    private(set) var currentSpeed: Double = 0

    /// Wall-clock elapsed time in seconds (handles pause/resume)
    private(set) var elapsedTime: TimeInterval = 0

    /// Whether the session is paused
    var isPaused: Bool = false

    /// Elevation gain from barometer (or GPS fallback) in meters
    private(set) var elevationGain: Double = 0

    /// Elevation loss from barometer (or GPS fallback) in meters
    private(set) var elevationLoss: Double = 0

    /// Current altitude in meters
    private(set) var currentElevation: Double = 0

    /// GPS signal quality based on horizontal accuracy
    private(set) var gpsSignalQuality: GPSSignalQuality = .none

    /// Raw horizontal accuracy in meters (-1 = no signal)
    private(set) var gpsHorizontalAccuracy: Double = -1

    /// Whether the GPS filter warm-up is complete
    private(set) var isWarmedUp: Bool = false

    /// Max speed recorded during this session (m/s)
    private(set) var maxSpeed: Double = 0

    /// Whether pedometer is currently the distance source (during GPS gaps)
    private(set) var isUsingPedometerFallback: Bool = false

    /// Cumulative pedometer distance this session (diagnostic)
    private(set) var pedometerDistance: Double = 0

    /// Cumulative pedometer step count this session
    private(set) var pedometerSteps: Int = 0

    // MARK: - Discipline Hooks

    /// Called after filtering for each valid location.
    /// Parameters: (filteredLocation, distanceDelta)
    var onLocationProcessed: ((CLLocation, Double) -> Void)?

    /// Called for each valid location to persist discipline-specific location points.
    /// Parameters: (filteredLocation, modelContext)
    var insertLocationPoint: ((CLLocation, ModelContext) -> Void)?

    // MARK: - Dependencies

    private let locationManager: LocationManager
    private let filter = GPSLocationFilter()

    // MARK: - Private State

    private var lastFilteredLocation: CLLocation?
    private var subscriberId: String?
    private var timerSource: DispatchSourceTimer?
    private var sessionStartTime: Date?
    private var pausedAccumulated: TimeInterval = 0
    private var lastPauseTime: Date?
    private var modelContext: ModelContext?

    // Diagnostic counters for location tracking (#107)
    private var rawLocationCount: Int = 0
    private var filteredLocationCount: Int = 0
    private var persistedLocationCount: Int = 0

    // Barometric elevation
    private let altimeter = CMAltimeter()
    private var useBarometer: Bool = false
    private var barometerReferenceAltitude: Double?
    private var lastBarometricRelativeAltitude: Double = 0
    private var lastGPSAltitude: Double?

    // Pedometer fallback for GPS gaps (running/walking only)
    private let pedometer = CMPedometer()
    private var isPedometerActive: Bool = false
    private var lastPedometerDistance: Double = 0
    private var pedometerDistanceOffset: Double = 0
    private var pedometerGapAccumulated: Double = 0
    private var lastGPSAcceptTime: Date?
    private var currentActivityType: GPSActivityType?

    private static let pedometerCorrectionFactor: Double = 0.90
    private static let gpsGapThreshold: TimeInterval = 5.0

    // Workout route builder integration
    private var workoutLifecycle: WorkoutLifecycleService?

    init(locationManager: LocationManager) {
        self.locationManager = locationManager
    }

    // MARK: - Session Lifecycle

    /// Start a GPS tracking session.
    /// - Parameters:
    ///   - subscriberId: Unique ID for the LocationManager subscriber (e.g. "ride", "running")
    ///   - activityType: The activity type for GPS filtering thresholds
    ///   - modelContext: SwiftData context for persisting location points
    ///   - workoutLifecycle: Optional workout lifecycle for HealthKit route data
    func start(
        subscriberId: String,
        activityType: GPSActivityType,
        modelContext: ModelContext? = nil,
        workoutLifecycle: WorkoutLifecycleService? = nil
    ) async {
        self.subscriberId = subscriberId
        self.modelContext = modelContext
        Log.location.info("GPS session starting — subscriber: \(subscriberId), activity: \(String(describing: activityType)), modelContext: \(modelContext != nil ? "available" : "NIL")")
        self.workoutLifecycle = workoutLifecycle
        self.currentActivityType = activityType

        // Reset state
        totalDistance = 0
        routeCoordinates = []
        currentSpeed = 0
        elapsedTime = 0
        isPaused = false
        elevationGain = 0
        elevationLoss = 0
        currentElevation = 0
        maxSpeed = 0
        gpsSignalQuality = .none
        gpsHorizontalAccuracy = -1
        isWarmedUp = false
        lastFilteredLocation = nil
        pausedAccumulated = 0
        lastPauseTime = nil
        sessionStartTime = nil
        lastBarometricRelativeAltitude = 0
        barometerReferenceAltitude = nil
        rawLocationCount = 0
        filteredLocationCount = 0
        persistedLocationCount = 0
        lastGPSAltitude = nil

        // Reset pedometer state
        isUsingPedometerFallback = false
        pedometerDistance = 0
        pedometerSteps = 0
        lastPedometerDistance = 0
        pedometerDistanceOffset = 0
        pedometerGapAccumulated = 0
        lastGPSAcceptTime = nil
        isPedometerActive = false

        // Configure and start filter
        filter.configure(activityType: activityType)
        filter.start()

        // Subscribe to location updates
        locationManager.subscribe(id: subscriberId) { [weak self] location in
            self?.handleRawLocation(location)
        }

        // Start location tracking
        await locationManager.startTracking()

        // Ensure barometer, pedometer, and timer start on main thread.
        // The async start() resumes on a cooperative thread pool thread after the
        // await above. Observable property mutations and DispatchSource timer creation
        // must happen on main to avoid data races with SwiftUI observation.
        await MainActor.run {
            startBarometer()
            startPedometer()
            startTimer()
        }
    }

    /// Pause the GPS session (stops location updates and timer)
    func pause() {
        guard !isPaused else { return }
        isPaused = true
        lastPauseTime = Date()
        locationManager.stopTracking()
        timerSource?.cancel()
        timerSource = nil
        stopBarometer()
        stopPedometer()
    }

    /// Resume a paused GPS session
    func resume() {
        guard isPaused else { return }
        isPaused = false
        if let pauseTime = lastPauseTime {
            pausedAccumulated += Date().timeIntervalSince(pauseTime)
        }
        lastPauseTime = nil

        Task {
            await locationManager.startTracking()
        }
        startBarometer()
        startPedometer()
        startTimer()
    }

    /// Stop the GPS session and clean up
    func stop() {
        Log.location.info("GPS session ending — raw: \(self.rawLocationCount), filtered: \(self.filteredLocationCount), persisted: \(self.persistedLocationCount), routeCoords: \(self.routeCoordinates.count)")

        // Unsubscribe from location updates
        if let id = subscriberId {
            locationManager.unsubscribe(id: id)
        }
        locationManager.stopTracking()

        // Stop timer
        timerSource?.cancel()
        timerSource = nil

        // Stop barometer
        stopBarometer()

        // Stop pedometer
        stopPedometer()

        // Reset filter
        filter.reset()

        // Clear hooks
        subscriberId = nil
        modelContext = nil
        workoutLifecycle = nil
        currentActivityType = nil
    }

    // MARK: - Location Processing

    private func handleRawLocation(_ location: CLLocation) {
        guard !isPaused else { return }

        rawLocationCount += 1

        // Update GPS signal quality (always, even if filtered out)
        gpsHorizontalAccuracy = location.horizontalAccuracy
        gpsSignalQuality = GPSSignalQuality(horizontalAccuracy: location.horizontalAccuracy)

        // Run through filter pipeline
        guard let filtered = filter.processLocation(location) else {
            // Log every 50th rejection to avoid spam
            if rawLocationCount % 50 == 0 {
                Log.location.debug("GPS filter stats: \(self.rawLocationCount) raw, \(self.filteredLocationCount) accepted, \(self.persistedLocationCount) persisted, accuracy=\(location.horizontalAccuracy)")
            }
            return
        }

        filteredLocationCount += 1

        // Update warm-up state from filter
        isWarmedUp = filter.isWarmedUp

        // Record that GPS filter accepted a point
        let wasInPedometerFallback = isUsingPedometerFallback
        lastGPSAcceptTime = Date()

        // Speed
        if filtered.speed >= 0 {
            currentSpeed = filtered.speed
            if filtered.speed > maxSpeed {
                maxSpeed = filtered.speed
            }
        }

        // Recovery from pedometer gap: skip GPS jump delta to avoid double-counting
        if wasInPedometerFallback {
            isUsingPedometerFallback = false
            pedometerGapAccumulated = 0

            // Set lastFilteredLocation to current (no distance jump)
            lastFilteredLocation = filtered

            // Still update route, elevation, persist, and feed workout builder
            routeCoordinates.append(filtered.coordinate)
            if !useBarometer {
                trackGPSElevation(altitude: filtered.altitude)
            }
            currentElevation = filtered.altitude
            if let ctx = modelContext {
                insertLocationPoint?(filtered, ctx)
                persistedLocationCount += 1
            } else {
                Log.location.warning("Cannot persist location point — modelContext is nil")
            }
            if let lifecycle = workoutLifecycle {
                Task {
                    await lifecycle.addRouteData([filtered])
                }
            }

            // Notify with zero delta — pedometer already counted the gap
            onLocationProcessed?(filtered, 0)
            return
        }

        // Distance
        var distanceDelta: Double = 0
        if let last = lastFilteredLocation {
            let timeDelta = filtered.timestamp.timeIntervalSince(last.timestamp)
            guard timeDelta > 0 else { return }
            distanceDelta = filtered.distance(from: last)
            totalDistance += distanceDelta
        }

        // Route
        routeCoordinates.append(filtered.coordinate)

        // Elevation (GPS fallback when barometer not available)
        if !useBarometer {
            trackGPSElevation(altitude: filtered.altitude)
        }
        currentElevation = filtered.altitude

        // Persist location point via discipline hook
        if let ctx = modelContext {
            insertLocationPoint?(filtered, ctx)
            persistedLocationCount += 1
        } else {
            Log.location.warning("Cannot persist location point — modelContext is nil")
        }

        // Feed to workout route builder
        if let lifecycle = workoutLifecycle {
            Task {
                await lifecycle.addRouteData([filtered])
            }
        }

        lastFilteredLocation = filtered

        // Notify discipline-specific handler
        onLocationProcessed?(filtered, distanceDelta)
    }

    // MARK: - Timer (Wall-Clock)

    private func startTimer() {
        timerSource?.cancel()
        if sessionStartTime == nil {
            sessionStartTime = Date()
        }

        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now(), repeating: .seconds(1))
        source.setEventHandler { [weak self] in
            guard let self, let start = self.sessionStartTime, !self.isPaused else { return }
            self.elapsedTime = Date().timeIntervalSince(start) - self.pausedAccumulated
        }
        source.resume()
        timerSource = source
    }

    // MARK: - Barometric Elevation

    private func startBarometer() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            useBarometer = false
            return
        }
        useBarometer = true
        lastBarometricRelativeAltitude = 0

        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let self, let data, error == nil else { return }
            let relativeAlt = data.relativeAltitude.doubleValue

            // Set reference on first reading
            if self.barometerReferenceAltitude == nil {
                self.barometerReferenceAltitude = relativeAlt
                self.lastBarometricRelativeAltitude = relativeAlt
                return
            }

            let delta = relativeAlt - self.lastBarometricRelativeAltitude
            // Deadband: ignore tiny fluctuations (< 0.3m)
            if abs(delta) > 0.3 {
                if delta > 0 {
                    self.elevationGain += delta
                } else {
                    self.elevationLoss += abs(delta)
                }
                self.lastBarometricRelativeAltitude = relativeAlt
            }
        }
    }

    private func stopBarometer() {
        if useBarometer {
            altimeter.stopRelativeAltitudeUpdates()
        }
    }

    // MARK: - Pedometer Fallback

    private func startPedometer() {
        guard let activityType = currentActivityType,
              activityType.supportsPedometerFallback,
              CMPedometer.isDistanceAvailable() else {
            return
        }

        // Check authorization — .restricted or .denied means pedometer is unavailable
        let status = CMPedometer.authorizationStatus()
        guard status == .authorized || status == .notDetermined else {
            return
        }

        // Preserve accumulated distance across pause/resume
        pedometerDistanceOffset += lastPedometerDistance
        lastPedometerDistance = 0

        isPedometerActive = true

        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            guard let data, error == nil else { return }
            DispatchQueue.main.async {
                self?.handlePedometerUpdate(data)
            }
        }
    }

    private func stopPedometer() {
        guard isPedometerActive else { return }
        pedometer.stopUpdates()
        isPedometerActive = false
    }

    private func handlePedometerUpdate(_ data: CMPedometerData) {
        guard !isPaused else { return }

        let cumulativeDistance = (data.distance?.doubleValue ?? 0) * Self.pedometerCorrectionFactor
        let pedometerDelta = cumulativeDistance - lastPedometerDistance
        lastPedometerDistance = cumulativeDistance

        // Update diagnostic totals
        pedometerDistance = pedometerDistanceOffset + cumulativeDistance
        pedometerSteps = Int(truncating: data.numberOfSteps)

        // Check if we're in a GPS gap
        guard let lastAccept = lastGPSAcceptTime else {
            // No GPS point accepted yet — pedometer is only source
            if pedometerDelta > 0 {
                totalDistance += pedometerDelta
                pedometerGapAccumulated += pedometerDelta
                isUsingPedometerFallback = true
            }
            return
        }

        let gapDuration = Date().timeIntervalSince(lastAccept)
        if gapDuration > Self.gpsGapThreshold && pedometerDelta > 0 {
            totalDistance += pedometerDelta
            pedometerGapAccumulated += pedometerDelta
            isUsingPedometerFallback = true
        }
    }

    // MARK: - GPS Elevation Fallback

    private func trackGPSElevation(altitude: Double) {
        if let lastAlt = lastGPSAltitude {
            let delta = altitude - lastAlt
            // Deadband: ignore GPS altitude noise (< 2m)
            if abs(delta) > 2.0 {
                if delta > 0 {
                    elevationGain += delta
                } else {
                    elevationLoss += abs(delta)
                }
                lastGPSAltitude = altitude
            }
        } else {
            lastGPSAltitude = altitude
        }
    }
}
