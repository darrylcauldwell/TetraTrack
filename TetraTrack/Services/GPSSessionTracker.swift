//
//  GPSSessionTracker.swift
//  TetraTrack
//

import CoreLocation
import CoreMotion
import Observation
import SwiftData
import os

/// GPS session diagnostics for debugging location persistence issues
@Observable
final class GPSDiagnostics {
    private(set) var totalRawReceived: Int = 0
    private(set) var totalFilterAccepted: Int = 0
    private(set) var totalFilterRejected: Int = 0
    private(set) var totalPersisted: Int = 0
    private(set) var lastRejectReason: GPSFilterRejectReason?
    private(set) var lastPersistedAt: Date?
    private(set) var lastCheckpointAt: Date?
    private(set) var checkpointCount: Int = 0

    func recordRawReceived() { totalRawReceived += 1 }
    func recordAccepted() { totalFilterAccepted += 1 }
    func recordRejected(_ reason: GPSFilterRejectReason) {
        totalFilterRejected += 1
        lastRejectReason = reason
    }
    func recordPersisted() {
        totalPersisted += 1
        lastPersistedAt = Date()
    }
    func recordCheckpoint() {
        checkpointCount += 1
        lastCheckpointAt = Date()
    }
    func reset() {
        totalRawReceived = 0
        totalFilterAccepted = 0
        totalFilterRejected = 0
        totalPersisted = 0
        lastRejectReason = nil
        lastPersistedAt = nil
        lastCheckpointAt = nil
        checkpointCount = 0
    }
}

/// Delegate for discipline-specific GPS session behavior.
/// GPSSessionTracker owns persistence and checkpoint saves; disciplines provide
/// location point creation and analysis logic.
protocol GPSSessionDelegate: AnyObject {
    /// Create a discipline-specific location point model. GPSSessionTracker inserts it.
    func createLocationPoint(from location: CLLocation) -> (any PersistentModel)?
    /// Called after location is processed and persisted. For discipline-specific analysis.
    func didProcessLocation(_ location: CLLocation, distanceDelta: Double, tracker: GPSSessionTracker)
}

/// Configuration for starting a GPS session
struct GPSSessionConfig {
    let subscriberId: String
    let activityType: GPSActivityType
    let checkpointInterval: TimeInterval
    let modelContext: ModelContext
    let workoutLifecycle: WorkoutLifecycleService?
}

/// Shared GPS session tracker used by all disciplines (riding, running, walking, swimming).
/// Manages filtered location tracking, distance accumulation, route storage, wall-clock timer,
/// elevation tracking (barometric + GPS fallback), GPS signal quality, persistence, and checkpoint saves.
///
/// Discipline-specific logic hooks in via `GPSSessionDelegate`.
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

    /// Current cadence in steps per minute (from pedometer)
    private(set) var pedometerCadence: Int = 0

    /// Cumulative floors ascended this session
    private(set) var pedometerFloorsAscended: Int = 0

    /// Cumulative floors descended this session
    private(set) var pedometerFloorsDescended: Int = 0

    /// GPS diagnostics for debugging persistence issues
    private(set) var diagnostics = GPSDiagnostics()

    // MARK: - Delegate

    /// Discipline-specific delegate for location point creation and analysis
    weak var delegate: GPSSessionDelegate?

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
    private var config: GPSSessionConfig?
    private var lastCheckpointTime: TimeInterval = 0

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

    init(locationManager: LocationManager) {
        self.locationManager = locationManager
    }

    // MARK: - Session Lifecycle

    /// Start a GPS tracking session with config and delegate.
    /// GPSSessionTracker owns persistence and checkpoint saves; the delegate provides
    /// location point creation and discipline-specific analysis.
    func start(config: GPSSessionConfig, delegate: GPSSessionDelegate) async {
        self.config = config
        self.delegate = delegate
        self.subscriberId = config.subscriberId
        self.currentActivityType = config.activityType
        Log.location.info("GPS session starting: delegate=\(type(of: delegate)), subscriber=\(config.subscriberId), activity=\(String(describing: config.activityType))")

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
        lastGPSAltitude = nil
        lastCheckpointTime = 0
        diagnostics.reset()

        // Reset pedometer state
        isUsingPedometerFallback = false
        pedometerDistance = 0
        pedometerSteps = 0
        pedometerCadence = 0
        pedometerFloorsAscended = 0
        pedometerFloorsDescended = 0
        lastPedometerDistance = 0
        pedometerDistanceOffset = 0
        pedometerGapAccumulated = 0
        lastGPSAcceptTime = nil
        isPedometerActive = false

        // Configure and start filter
        filter.configure(activityType: config.activityType)
        filter.start()

        // Subscribe to location updates
        locationManager.subscribe(id: config.subscriberId) { [weak self] location in
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

        // Log integrity report
        let duration = Int(elapsedTime)
        let raw = diagnostics.totalRawReceived
        let accepted = diagnostics.totalFilterAccepted
        let rejected = diagnostics.totalFilterRejected
        let persisted = diagnostics.totalPersisted
        let checkpoints = diagnostics.checkpointCount
        let pedFallback = isUsingPedometerFallback ? "active" : "inactive"
        Log.location.info("GPS session stopped: duration=\(duration)s, raw=\(raw), accepted=\(accepted), rejected=\(rejected), persisted=\(persisted), checkpoints=\(checkpoints), pedometer=\(pedFallback)")

        // Clear config and delegate
        subscriberId = nil
        config = nil
        delegate = nil
        currentActivityType = nil
    }

    // MARK: - Location Processing

    private func handleRawLocation(_ location: CLLocation) {
        guard !isPaused else { return }

        diagnostics.recordRawReceived()

        // Update GPS signal quality (always, even if filtered out)
        gpsHorizontalAccuracy = location.horizontalAccuracy
        gpsSignalQuality = GPSSignalQuality(horizontalAccuracy: location.horizontalAccuracy)

        // Run through filter pipeline with reject reason tracking
        let result = filter.processLocationWithReason(location)
        let filtered: CLLocation
        switch result {
        case .success(let loc):
            filtered = loc
            diagnostics.recordAccepted()
        case .failure(let reason):
            diagnostics.recordRejected(reason)
            return
        }

        // Update warm-up state from filter
        let wasWarmedUp = isWarmedUp
        isWarmedUp = filter.isWarmedUp
        if !wasWarmedUp && isWarmedUp {
            let rawCount = diagnostics.totalRawReceived
            Log.location.info("GPS filter warmed up after \(rawCount) raw locations")
        }

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
            let gapDist = String(format: "%.1f", pedometerGapAccumulated)
            Log.location.info("Pedometer fallback deactivated: GPS recovered, gap distance=\(gapDist)m")
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
            persistLocationPoint(filtered)
            if let lifecycle = config?.workoutLifecycle {
                Task {
                    await lifecycle.addRouteData([filtered])
                }
            }

            // Notify with zero delta — pedometer already counted the gap
            delegate?.didProcessLocation(filtered, distanceDelta: 0, tracker: self)
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

        // Persist location point via delegate
        persistLocationPoint(filtered)

        // Feed to workout route builder
        if let lifecycle = config?.workoutLifecycle {
            Task {
                await lifecycle.addRouteData([filtered])
            }
        }

        lastFilteredLocation = filtered

        // Notify discipline-specific handler
        delegate?.didProcessLocation(filtered, distanceDelta: distanceDelta, tracker: self)
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

            // Periodic filter stats (every 30s)
            if Int(self.elapsedTime) > 0, Int(self.elapsedTime) % 30 == 0 {
                let total = self.diagnostics.totalFilterAccepted + self.diagnostics.totalFilterRejected
                if total > 0 {
                    let rejectRate = Double(self.diagnostics.totalFilterRejected) / Double(total) * 100
                    if rejectRate > 50 {
                        Log.location.warning("GPS filter rejection rate high: \(String(format: "%.0f", rejectRate))% (\(self.diagnostics.totalFilterRejected)/\(total))")
                    }
                }
            }

            // Checkpoint save at configured interval
            if let config = self.config {
                let interval = config.checkpointInterval
                if interval > 0,
                   self.elapsedTime >= interval,
                   Int(self.elapsedTime / interval) > Int(self.lastCheckpointTime / interval) {
                    self.lastCheckpointTime = self.elapsedTime
                    do {
                        try config.modelContext.save()
                        self.diagnostics.recordCheckpoint()
                        Log.location.debug("GPS checkpoint: \(self.diagnostics.totalPersisted) points, \(Int(self.elapsedTime))s")
                    } catch {
                        Log.location.error("GPS checkpoint save failed: \(error)")
                    }
                }
            }
        }
        source.resume()
        timerSource = source
    }

    // MARK: - Persistence

    /// Persist a filtered location point via delegate. GPSSessionTracker owns the insert.
    private func persistLocationPoint(_ location: CLLocation) {
        guard let config else { return }
        guard let delegate else {
            Log.location.error("persistLocationPoint: delegate is nil — location point will be lost")
            return
        }
        if let point = delegate.createLocationPoint(from: location) {
            config.modelContext.insert(point)
            diagnostics.recordPersisted()
        } else {
            Log.location.error("persistLocationPoint: delegate returned nil point")
        }
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

        // Extract cadence and floor data
        if let cadence = data.currentCadence {
            pedometerCadence = Int(cadence.doubleValue * 60)  // steps/sec → steps/min
            let steps = Int(truncating: data.numberOfSteps)
            let cad = pedometerCadence
            Log.tracking.error("TT: pedometer cadence=\(cad) spm, steps=\(steps)")
        }
        pedometerFloorsAscended = data.floorsAscended?.intValue ?? 0
        pedometerFloorsDescended = data.floorsDescended?.intValue ?? 0

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
            if !isUsingPedometerFallback {
                let gap = String(format: "%.1f", gapDuration)
                Log.location.info("Pedometer fallback activated: GPS gap \(gap)s")
            }
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
