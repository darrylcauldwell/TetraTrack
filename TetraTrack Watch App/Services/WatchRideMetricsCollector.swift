//
//  WatchRideMetricsCollector.swift
//  TetraTrack Watch App
//
//  Collects ride-type-specific metrics during autonomous Watch rides.
//  Jump detection, turn counting, arm steadiness, posting rhythm, halt detection.
//

import Foundation
import CoreMotion
import CoreLocation
import Observation
import os

/// Summary of metrics collected during a Watch ride
struct WatchRideSummary: Codable, Sendable {
    let rideType: String
    let jumpCount: Int
    let leftTurnCount: Int
    let rightTurnCount: Int
    let armSteadiness: Double  // 0-100%
    let postingRhythm: Double  // 0-100%
    let haltCount: Int
    let hkWorkoutUUID: String

    func toDictionary() -> [String: Any] {
        [
            "tt_rideSummary": true,
            "tt_rideType": rideType,
            "tt_jumpCount": jumpCount,
            "tt_leftTurnCount": leftTurnCount,
            "tt_rightTurnCount": rightTurnCount,
            "tt_armSteadiness": armSteadiness,
            "tt_postingRhythm": postingRhythm,
            "tt_haltCount": haltCount,
            "tt_hkWorkoutUUID": hkWorkoutUUID
        ]
    }

    static func from(dictionary: [String: Any]) -> WatchRideSummary? {
        guard dictionary["tt_rideSummary"] as? Bool == true,
              let rideType = dictionary["tt_rideType"] as? String,
              let hkWorkoutUUID = dictionary["tt_hkWorkoutUUID"] as? String else {
            return nil
        }
        return WatchRideSummary(
            rideType: rideType,
            jumpCount: dictionary["tt_jumpCount"] as? Int ?? 0,
            leftTurnCount: dictionary["tt_leftTurnCount"] as? Int ?? 0,
            rightTurnCount: dictionary["tt_rightTurnCount"] as? Int ?? 0,
            armSteadiness: dictionary["tt_armSteadiness"] as? Double ?? 0,
            postingRhythm: dictionary["tt_postingRhythm"] as? Double ?? 0,
            haltCount: dictionary["tt_haltCount"] as? Int ?? 0,
            hkWorkoutUUID: hkWorkoutUUID
        )
    }
}

/// Ride type for Watch-side selection (mirrors iPhone RideType active cases)
enum WatchRideType: String, CaseIterable, Identifiable {
    case ride = "Ride"
    case dressage = "Dressage"
    case showjumping = "Showjumping"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .ride: return "figure.equestrian.sports"
        case .dressage: return "figure.equestrian.sports"
        case .showjumping: return "arrow.up.forward"
        }
    }

    var description: String {
        switch self {
        case .ride: return "General riding"
        case .dressage: return "Dressage"
        case .showjumping: return "Showjumping"
        }
    }
}

/// Collects ride-specific metrics from Watch sensors
@MainActor
@Observable
final class WatchRideMetricsCollector {
    // MARK: - Observable Metrics

    private(set) var jumpCount: Int = 0
    private(set) var leftTurnCount: Int = 0
    private(set) var rightTurnCount: Int = 0
    private(set) var armSteadiness: Double = 0  // 0-100, higher = steadier
    private(set) var postingRhythm: Double = 0  // 0-100, higher = more regular
    private(set) var haltCount: Int = 0
    private(set) var isCollecting: Bool = false

    // MARK: - Private State

    private var rideType: WatchRideType = .ride
    private let motionManager = CMMotionManager()
    private let altimeter = CMAltimeter()
    private let locationManager = CLLocationManager()

    // Jump detection
    private var baselineAltitude: Double?
    private var peakAltitude: Double?
    private var isAirborne = false
    private var jumpStartTime: Date?
    private let jumpAltitudeThreshold: Double = 0.5  // meters

    // Turn detection
    private var previousHeading: Double?
    private var headingAccumulator: Double = 0
    private var lastTurnTime: Date?
    private let turnThreshold: Double = 30  // degrees for a counted turn

    // Arm steadiness — rolling variance of acceleration magnitude
    private var accelBuffer: [Double] = []
    private let accelBufferSize = 250  // 5 seconds at 50Hz

    // Posting rhythm — vertical acceleration oscillation regularity
    private var verticalAccelBuffer: [Double] = []
    private let verticalBufferSize = 500  // 10 seconds at 50Hz

    // Halt detection
    private var lowMotionStart: Date?
    private var isInHalt = false
    private let haltThreshold: Double = 0.1  // g variance
    private let haltMinDuration: TimeInterval = 3.0

    private let motionQueue = OperationQueue()

    // MARK: - Lifecycle

    func start(rideType: WatchRideType) {
        self.rideType = rideType
        resetMetrics()
        isCollecting = true

        motionQueue.name = "dev.dreamfold.tetratrack.rideMetrics"
        motionQueue.maxConcurrentOperationCount = 1

        startMotionUpdates()

        // Jump detection via altimeter (showjumping + ride)
        if rideType == .showjumping || rideType == .ride {
            startAltimeterUpdates()
        }

        // Turn detection via heading (dressage)
        if rideType == .dressage {
            startHeadingUpdates()
        }

        Log.tracking.info("WatchRideMetricsCollector started for \(rideType.rawValue)")
    }

    func stop() -> WatchRideSummary {
        isCollecting = false
        motionManager.stopDeviceMotionUpdates()
        altimeter.stopRelativeAltitudeUpdates()
        locationManager.stopUpdatingHeading()
        headingTimer?.invalidate()
        headingTimer = nil

        let jumps = self.jumpCount
        let leftTurns = self.leftTurnCount
        let rightTurns = self.rightTurnCount
        let steady = self.armSteadiness
        let rhythm = self.postingRhythm
        let halts = self.haltCount
        let type = self.rideType.rawValue

        let summary = WatchRideSummary(
            rideType: type,
            jumpCount: jumps,
            leftTurnCount: leftTurns,
            rightTurnCount: rightTurns,
            armSteadiness: steady,
            postingRhythm: rhythm,
            haltCount: halts,
            hkWorkoutUUID: "" // Set by caller after workout save
        )
        Log.tracking.info("WatchRideMetricsCollector stopped: jumps=\(jumps), turns L=\(leftTurns) R=\(rightTurns)")
        return summary
    }

    // MARK: - Motion Updates (Arm Steadiness, Posting Rhythm, Halts)

    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 50.0  // 50Hz

        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, _ in
            guard let motion else { return }
            Task { @MainActor [weak self] in
                self?.processMotion(motion)
            }
        }
    }

    private func processMotion(_ motion: CMDeviceMotion) {
        let accelMag = sqrt(
            motion.userAcceleration.x * motion.userAcceleration.x +
            motion.userAcceleration.y * motion.userAcceleration.y +
            motion.userAcceleration.z * motion.userAcceleration.z
        )

        // Arm steadiness — inverse of acceleration variance
        accelBuffer.append(accelMag)
        if accelBuffer.count > accelBufferSize { accelBuffer.removeFirst() }
        if accelBuffer.count >= 50 {
            let mean = accelBuffer.reduce(0, +) / Double(accelBuffer.count)
            let variance = accelBuffer.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(accelBuffer.count)
            // Map variance to 0-100 score (lower variance = higher steadiness)
            // Typical riding variance: 0.01 (very steady) to 0.5 (very bouncy)
            let score = max(0, min(100, 100 - variance * 200))
            armSteadiness = score
        }

        // Posting rhythm — regularity of vertical oscillation
        let vertAccel = motion.userAcceleration.z  // vertical component
        verticalAccelBuffer.append(vertAccel)
        if verticalAccelBuffer.count > verticalBufferSize { verticalAccelBuffer.removeFirst() }
        if verticalAccelBuffer.count >= 200 {
            postingRhythm = computePostingRhythm()
        }

        // Halt detection — near-zero movement for >3 seconds
        let totalAccel = accelMag + abs(motion.rotationRate.x) + abs(motion.rotationRate.y) + abs(motion.rotationRate.z)
        if totalAccel < haltThreshold {
            if lowMotionStart == nil { lowMotionStart = Date() }
            if let start = lowMotionStart, !isInHalt, Date().timeIntervalSince(start) >= haltMinDuration {
                isInHalt = true
                haltCount += 1
            }
        } else {
            lowMotionStart = nil
            isInHalt = false
        }
    }

    /// Compute posting rhythm from vertical acceleration autocorrelation
    private func computePostingRhythm() -> Double {
        let n = verticalAccelBuffer.count
        guard n >= 200 else { return 0 }

        let mean = verticalAccelBuffer.reduce(0, +) / Double(n)
        let centered = verticalAccelBuffer.map { $0 - mean }
        let variance = centered.reduce(0) { $0 + $1 * $1 } / Double(n)
        guard variance > 0.001 else { return 0 }  // No significant oscillation

        // Autocorrelation at typical posting frequency (1-3 Hz = lags 17-50 at 50Hz)
        var maxCorrelation: Double = 0
        for lag in 17...50 {
            var correlation: Double = 0
            let loopEnd = n - lag
            for i in 0..<loopEnd {
                correlation += centered[i] * centered[i + lag]
            }
            correlation /= Double(loopEnd) * variance
            maxCorrelation = max(maxCorrelation, correlation)
        }

        // Map autocorrelation (0-1) to rhythm score (0-100)
        return max(0, min(100, maxCorrelation * 100))
    }

    // MARK: - Altimeter (Jump Detection)

    private func startAltimeterUpdates() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }

        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            Task { @MainActor [weak self] in
                self?.processAltitude(data.relativeAltitude.doubleValue)
            }
        }
    }

    private func processAltitude(_ altitude: Double) {
        if baselineAltitude == nil { baselineAltitude = altitude }

        let relativeAlt = altitude - (baselineAltitude ?? 0)

        if !isAirborne && relativeAlt > jumpAltitudeThreshold {
            // Takeoff detected
            isAirborne = true
            jumpStartTime = Date()
            peakAltitude = relativeAlt
        } else if isAirborne {
            if relativeAlt > (peakAltitude ?? 0) {
                peakAltitude = relativeAlt
            }
            if relativeAlt < jumpAltitudeThreshold * 0.5 {
                // Landing detected
                isAirborne = false
                jumpCount += 1
                jumpStartTime = nil
                peakAltitude = nil
                // Update baseline after jump
                baselineAltitude = altitude
            }
        } else {
            // Slowly adapt baseline when on ground
            baselineAltitude = (baselineAltitude ?? altitude) * 0.99 + altitude * 0.01
        }
    }

    // MARK: - Heading (Turn Detection)

    private var headingTimer: Timer?

    private func startHeadingUpdates() {
        locationManager.startUpdatingHeading()
        headingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isCollecting else { return }
                if let heading = self.locationManager.heading {
                    self.processHeading(heading.magneticHeading)
                }
            }
        }
    }

    private func processHeading(_ heading: Double) {
        guard let prev = previousHeading else {
            previousHeading = heading
            return
        }

        // Calculate shortest angular difference
        var delta = heading - prev
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }

        headingAccumulator += delta
        previousHeading = heading

        // Debounce: don't count turns too frequently
        let now = Date()
        if let lastTurn = lastTurnTime, now.timeIntervalSince(lastTurn) < 1.0 {
            return
        }

        if abs(headingAccumulator) >= turnThreshold {
            if headingAccumulator > 0 {
                rightTurnCount += 1
            } else {
                leftTurnCount += 1
            }
            headingAccumulator = 0
            lastTurnTime = now
        }
    }

    // MARK: - Reset

    private func resetMetrics() {
        jumpCount = 0
        leftTurnCount = 0
        rightTurnCount = 0
        armSteadiness = 0
        postingRhythm = 0
        haltCount = 0
        baselineAltitude = nil
        peakAltitude = nil
        isAirborne = false
        jumpStartTime = nil
        previousHeading = nil
        headingAccumulator = 0
        lastTurnTime = nil
        accelBuffer = []
        verticalAccelBuffer = []
        lowMotionStart = nil
        isInHalt = false
    }
}
