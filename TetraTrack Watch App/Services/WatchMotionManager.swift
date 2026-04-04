//
//  WatchMotionManager.swift
//  TetraTrack Watch App
//
//  Captures accelerometer and gyroscope data for discipline-specific analysis.
//  Watch acts as a sensor companion - data is sent to iPhone for processing.
//
//  Provides:
//  - Shooting: Stance stability (accelerometer/gyroscope)
//  - Swimming: Stroke detection (motion patterns)
//  - Running: Ground contact time, cadence
//  - Riding: Biomechanics data
//  - Skills drills: Balance, reaction timing
//
//  Enhanced sensors (Phase 3):
//  - Barometric altimeter: Elevation tracking
//  - Water submersion: Auto-detect swimming
//  - Compass: Heading/bearing
//  - Breathing rate: Estimated from motion
//  - SpO2: Oxygen saturation (via HealthKit)
//

import Foundation
import CoreMotion
import CoreLocation
import Observation
import os

/// Motion data sample from Watch sensors
nonisolated struct WatchMotionSample: Codable {
    let timestamp: TimeInterval
    let accelerationX: Double
    let accelerationY: Double
    let accelerationZ: Double
    let rotationX: Double
    let rotationY: Double
    let rotationZ: Double
    let pitch: Double
    let roll: Double
    let yaw: Double

    // Quaternion for frame transformation
    let quaternionW: Double
    let quaternionX: Double
    let quaternionY: Double
    let quaternionZ: Double

    var accelerationMagnitude: Double {
        sqrt(accelerationX * accelerationX + accelerationY * accelerationY + accelerationZ * accelerationZ)
    }

    var rotationMagnitude: Double {
        sqrt(rotationX * rotationX + rotationY * rotationY + rotationZ * rotationZ)
    }
}

/// Type of motion tracking for different disciplines
enum WatchMotionMode: String, Codable {
    case shooting    // Stance stability for dry fire drills
    case swimming    // Stroke detection and counting
    case running     // Vertical oscillation and ground contact
    case walking     // Cadence and ground contact (lower thresholds than running)
    case riding      // Biomechanics for equestrian
    case idle
}

/// Computed results from background motion processing, applied to @Observable properties on main.
nonisolated private struct MotionResults {
    // Shooting
    var stanceStability: Double?
    var movementMagnitude: Double?
    // Swimming
    var strokeCount: Int?
    var strokeRate: Double?
    var didDetectStroke: Bool = false
    // Running / Walking
    var verticalOscillation: Double?
    var groundContactTime: Double?
    var cadence: Int?
    var didDetectStep: Bool = false
    // Riding
    var postureStability: Double?
    var rhythmScore: Double?
    // Enhanced
    var posturePitch: Double?
    var postureRoll: Double?
    var tremorLevel: Double?
    var movementIntensity: Double?
    var breathingRate: Double?
}

/// Captures and processes Watch IMU data for all training disciplines.
/// Acts as a sensor companion - computed metrics are sent to iPhone.
///
/// Motion updates are delivered to a serial background queue for processing.
/// Computed results are dispatched to main for @Observable property assignment.
@MainActor
@Observable
final class WatchMotionManager: NSObject {
    // MARK: - State

    private(set) var isTracking: Bool = false
    // nonisolated(unsafe) because currentMode is read from motionQueue in processMotion switch.
    // Written only from main thread in startTracking/stopTracking (before/after motionQueue runs).
    nonisolated(unsafe) private(set) var currentMode: WatchMotionMode = .idle

    // Shooting metrics — nonisolated(unsafe) because read as fallback from motionQueue
    nonisolated(unsafe) private(set) var stanceStability: Double = 0.0  // 0-100%
    nonisolated(unsafe) private(set) var movementMagnitude: Double = 0.0

    // Swimming metrics — strokeRate read from motionQueue as last-known value
    private(set) var strokeCount: Int = 0
    nonisolated(unsafe) private(set) var strokeRate: Double = 0.0  // strokes per minute

    // Running metrics
    private(set) var verticalOscillation: Double = 0.0  // cm
    private(set) var groundContactTime: Double = 0.0  // ms
    private(set) var cadence: Int = 0  // steps per minute

    // Riding metrics
    private(set) var postureStability: Double = 0.0  // 0-100%
    private(set) var rhythmScore: Double = 0.0  // 0-100%

    // Enhanced sensor metrics (Phase 3)
    private(set) var relativeAltitude: Double = 0.0      // Meters from session start
    private(set) var altitudeChangeRate: Double = 0.0    // Meters per second
    private(set) var barometricPressure: Double = 0.0    // kPa
    private(set) var isSubmerged: Bool = false           // Water detection
    private(set) var waterDepth: Double = 0.0            // Meters
    private(set) var compassHeading: Double = 0.0        // Degrees 0-360
    private(set) var breathingRate: Double = 0.0         // Breaths per minute
    private(set) var posturePitch: Double = 0.0          // Forward/back lean degrees
    private(set) var postureRoll: Double = 0.0           // Left/right lean degrees
    private(set) var tremorLevel: Double = 0.0           // High-frequency shake 0-100
    private(set) var movementIntensity: Double = 0.0     // Overall activity 0-100

    // MARK: - Private

    private let motionManager = CMMotionManager()
    private let altimeter = CMAltimeter()
    private let locationManager = CLLocationManager()

    /// Serial queue for 50Hz motion processing — keeps DSP off the main thread.
    private let motionQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "dev.dreamfold.TetraTrack.motionProcessing"
        q.maxConcurrentOperationCount = 1
        q.qualityOfService = .userInitiated
        return q
    }()

    // All mutable buffers below are only accessed on the serial motionQueue.
    // nonisolated(unsafe) because they are accessed from nonisolated DSP methods
    // that run exclusively on motionQueue — thread safety is guaranteed by the serial queue.
    nonisolated(unsafe) private var sampleBuffer: [WatchMotionSample] = []
    nonisolated(unsafe) private var lastStrokeTime: Date?
    nonisolated(unsafe) private var strokeTimes: [TimeInterval] = []
    nonisolated(unsafe) private var runningPeaks: [TimeInterval] = []
    nonisolated(unsafe) private var lastPeakTime: TimeInterval = 0
    nonisolated(unsafe) private var peakDetectionThreshold: Double = 1.2

    // Cumulative stroke counter on motionQueue; synced to public strokeCount on main.
    nonisolated(unsafe) private var _internalStrokeCount: Int = 0

    // Altitude tracking
    private var startAltitude: Double?
    private var lastAltitude: Double = 0
    private var lastAltitudeTime: Date?

    // Water submersion (watchOS 10+)
    #if os(watchOS)
    @ObservationIgnored
    private var _waterSubmersionManager: CMWaterSubmersionManager?

    @available(watchOS 10.0, *)
    private var waterSubmersionManager: CMWaterSubmersionManager {
        if let existing = _waterSubmersionManager {
            return existing
        }
        let manager = CMWaterSubmersionManager()
        manager.delegate = self
        _waterSubmersionManager = manager
        return manager
    }
    #endif

    // Breathing rate estimation
    nonisolated(unsafe) private var breathingSamples: [Double] = []
    nonisolated(unsafe) private var lastBreathingCalc: Date?

    // Tremor analysis (high-frequency motion)
    nonisolated(unsafe) private var tremorBuffer: [Double] = []

    // Callbacks
    var onMotionUpdate: ((WatchMotionSample) -> Void)?
    var onStrokeDetected: (() -> Void)?
    var onStepDetected: (() -> Void)?

    // MARK: - Singleton

    static let shared = WatchMotionManager()

    private override init() {
        super.init()
    }

    // MARK: - Tracking Control

    func startTracking(mode: WatchMotionMode) {
        guard !isTracking else { return }
        guard motionManager.isDeviceMotionAvailable else {
            Log.location.warning("Device motion not available")
            return
        }

        currentMode = mode
        resetMetrics()

        // Configure update interval based on mode
        let interval: TimeInterval = switch mode {
        case .shooting: 1.0 / 50.0   // 50Hz for stability analysis
        case .swimming: 1.0 / 25.0   // 25Hz for stroke detection
        case .running: 1.0 / 50.0    // 50Hz for ground contact
        case .walking: 1.0 / 50.0    // 50Hz for cadence detection
        case .riding: 1.0 / 50.0     // 50Hz for biomechanics
        case .idle: 1.0 / 10.0
        }

        motionManager.deviceMotionUpdateInterval = interval

        // Deliver to background motionQueue — all processing happens off main.
        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, error in
            guard let self = self, let motion = motion else {
                if let error = error {
                    Log.location.error("Motion update error: \(error.localizedDescription)")
                }
                return
            }

            self.processMotion(motion)
        }

        // Start barometric altimeter (low-frequency ~1Hz, stays on main)
        startAltimeter()

        // Start compass heading
        startCompass()

        // Start water submersion detection (if available)
        startWaterDetection()

        isTracking = true
        Log.location.info("Started tracking - mode: \(mode.rawValue)")
    }

    func stopTracking() {
        guard isTracking else { return }

        motionManager.stopDeviceMotionUpdates()
        stopAltimeter()
        stopCompass()
        stopWaterDetection()

        isTracking = false
        currentMode = .idle

        Log.location.info("Stopped tracking")
    }

    // MARK: - Private Methods

    private func resetMetrics() {
        // Reset buffers (safe — called before motionQueue starts delivering)
        sampleBuffer = []
        strokeTimes = []
        runningPeaks = []
        lastPeakTime = 0
        lastStrokeTime = nil
        _internalStrokeCount = 0
        breathingSamples = []
        lastBreathingCalc = nil
        tremorBuffer = []

        // Reset @Observable properties (on main before tracking starts)
        stanceStability = 100.0
        movementMagnitude = 0.0
        strokeCount = 0
        strokeRate = 0.0
        verticalOscillation = 0.0
        groundContactTime = 0.0
        cadence = 0
        postureStability = 100.0
        rhythmScore = 100.0

        // Enhanced sensor metrics
        startAltitude = nil
        relativeAltitude = 0.0
        altitudeChangeRate = 0.0
        barometricPressure = 0.0
        lastAltitude = 0
        lastAltitudeTime = nil
        isSubmerged = false
        waterDepth = 0.0
        compassHeading = 0.0
        breathingRate = 0.0
        posturePitch = 0.0
        postureRoll = 0.0
        tremorLevel = 0.0
        movementIntensity = 0.0
    }

    /// Called on motionQueue. Computes all metrics on background, then dispatches results to main.
    nonisolated private func processMotion(_ motion: CMDeviceMotion) {
        let q = motion.attitude.quaternion
        let sample = WatchMotionSample(
            timestamp: motion.timestamp,
            accelerationX: motion.userAcceleration.x,
            accelerationY: motion.userAcceleration.y,
            accelerationZ: motion.userAcceleration.z,
            rotationX: motion.rotationRate.x,
            rotationY: motion.rotationRate.y,
            rotationZ: motion.rotationRate.z,
            pitch: motion.attitude.pitch,
            roll: motion.attitude.roll,
            yaw: motion.attitude.yaw,
            quaternionW: q.w,
            quaternionX: q.x,
            quaternionY: q.y,
            quaternionZ: q.z
        )

        sampleBuffer.append(sample)

        // Keep buffer size manageable (last 5 seconds at 50Hz = 250 samples)
        if sampleBuffer.count > 250 {
            sampleBuffer.removeFirst(sampleBuffer.count - 250)
        }

        // Compute discipline-specific metrics (returns values, no property mutation)
        var results = MotionResults()

        switch currentMode {
        case .shooting:
            let r = computeShootingMotion(sample)
            results.stanceStability = r.stability
            results.movementMagnitude = r.magnitude
        case .swimming:
            let r = computeSwimmingMotion(sample)
            results.strokeCount = r.strokeCount
            results.strokeRate = r.strokeRate
            results.didDetectStroke = r.didDetectStroke
        case .running:
            let r = computeRunningMotion(sample)
            results.verticalOscillation = r.oscillation
            results.groundContactTime = r.groundContact
            results.cadence = r.cadence
            results.didDetectStep = r.didStep
        case .walking:
            let r = computeWalkingMotion(sample)
            results.verticalOscillation = r.oscillation
            results.groundContactTime = r.groundContact
            results.cadence = r.cadence
            results.didDetectStep = r.didStep
        case .riding:
            let r = computeRidingMotion(sample)
            results.postureStability = r.postureStability
            results.rhythmScore = r.rhythmScore
        case .idle:
            break
        }

        // Always compute enhanced metrics for all modes
        let enhanced = computeEnhancedMetrics(sample)
        results.posturePitch = enhanced.pitch
        results.postureRoll = enhanced.roll
        results.tremorLevel = enhanced.tremor
        results.movementIntensity = enhanced.intensity
        results.breathingRate = enhanced.breathing

        // Single dispatch to main: assign all properties + fire callbacks
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // Shooting
            if let v = results.stanceStability { self.stanceStability = v }
            if let v = results.movementMagnitude { self.movementMagnitude = v }

            // Swimming
            if let v = results.strokeCount { self.strokeCount = v }
            if let v = results.strokeRate { self.strokeRate = v }

            // Running / Walking
            if let v = results.verticalOscillation { self.verticalOscillation = v }
            if let v = results.groundContactTime { self.groundContactTime = v }
            if let v = results.cadence { self.cadence = v }

            // Riding
            if let v = results.postureStability { self.postureStability = v }
            if let v = results.rhythmScore { self.rhythmScore = v }

            // Enhanced
            if let v = results.posturePitch { self.posturePitch = v }
            if let v = results.postureRoll { self.postureRoll = v }
            if let v = results.tremorLevel { self.tremorLevel = v }
            if let v = results.movementIntensity { self.movementIntensity = v }
            if let v = results.breathingRate { self.breathingRate = v }

            // Callbacks
            self.onMotionUpdate?(sample)

            if results.didDetectStroke {
                self.onStrokeDetected?()
                HapticManager.shared.playClickHaptic()
            }

            if results.didDetectStep {
                self.onStepDetected?()
            }
        }
    }

    // MARK: - Shooting Analysis (motionQueue)

    nonisolated private func computeShootingMotion(_ sample: WatchMotionSample) -> (stability: Double, magnitude: Double) {
        let recentSamples = Array(sampleBuffer.suffix(25))  // Last 0.5 seconds
        guard recentSamples.count >= 10 else { return (stanceStability, movementMagnitude) }

        let avgMagnitude = recentSamples.map { $0.accelerationMagnitude }.reduce(0, +) / Double(recentSamples.count)
        let rotationVar = calculateVariance(recentSamples.map { $0.rotationMagnitude })

        let movementPenalty = min(avgMagnitude * 100, 50)
        let rotationPenalty = min(rotationVar * 20, 30)
        let stability = max(0, min(100, 100 - movementPenalty - rotationPenalty))

        return (stability, avgMagnitude)
    }

    // MARK: - Swimming Analysis (motionQueue)

    nonisolated private func computeSwimmingMotion(_ sample: WatchMotionSample) -> (strokeCount: Int, strokeRate: Double, didDetectStroke: Bool) {
        let lateralAccel = abs(sample.accelerationX)
        let threshold: Double = 0.8

        let now = Date()
        let minStrokeInterval: TimeInterval = 0.5

        var didDetect = false
        var currentRate = strokeRate  // Read last-known rate for return

        if lateralAccel > threshold {
            if let lastStroke = lastStrokeTime {
                let interval = now.timeIntervalSince(lastStroke)
                if interval >= minStrokeInterval {
                    _internalStrokeCount += 1
                    strokeTimes.append(interval)
                    lastStrokeTime = now

                    if strokeTimes.count > 10 {
                        strokeTimes.removeFirst()
                    }

                    if strokeTimes.count >= 2 {
                        let avgInterval = strokeTimes.reduce(0, +) / Double(strokeTimes.count)
                        currentRate = 60.0 / avgInterval
                    }

                    didDetect = true
                }
            } else {
                _internalStrokeCount = 1
                lastStrokeTime = now
                didDetect = true
            }
        }

        return (_internalStrokeCount, currentRate, didDetect)
    }

    // MARK: - Running Analysis (motionQueue)

    nonisolated private func computeRunningMotion(_ sample: WatchMotionSample) -> (oscillation: Double?, groundContact: Double?, cadence: Int?, didStep: Bool) {
        let verticalAccel = sample.accelerationY
        let timestamp = sample.timestamp

        let impactThreshold: Double = 1.5
        let minStepInterval: TimeInterval = 0.25

        var didStep = false
        var computedCadence: Int?

        if verticalAccel > impactThreshold && (timestamp - lastPeakTime) > minStepInterval {
            runningPeaks.append(timestamp)
            lastPeakTime = timestamp

            if runningPeaks.count > 20 {
                runningPeaks.removeFirst()
            }

            if runningPeaks.count >= 4 {
                var intervals: [TimeInterval] = []
                for i in 1..<runningPeaks.count {
                    intervals.append(runningPeaks[i] - runningPeaks[i-1])
                }
                let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
                computedCadence = Int(60.0 / avgInterval)
            }

            didStep = true
        }

        let recentSamples = Array(sampleBuffer.suffix(50))
        guard recentSamples.count >= 20 else {
            return (nil, nil, computedCadence, didStep)
        }

        let verticalAccels = recentSamples.map { $0.accelerationY }
        let maxVert = verticalAccels.max() ?? 0
        let minVert = verticalAccels.min() ?? 0
        let oscillationRange = maxVert - minVert
        let oscillation = oscillationRange * 4.0

        let contactSamples = recentSamples.filter { $0.accelerationY > 0.5 }
        let contactRatio = Double(contactSamples.count) / Double(recentSamples.count)
        let groundContact = contactRatio * 1000 * 0.5

        return (oscillation, groundContact, computedCadence, didStep)
    }

    // MARK: - Walking Analysis (motionQueue)

    nonisolated private func computeWalkingMotion(_ sample: WatchMotionSample) -> (oscillation: Double?, groundContact: Double?, cadence: Int?, didStep: Bool) {
        let verticalAccel = sample.accelerationY
        let timestamp = sample.timestamp

        let impactThreshold: Double = 0.15
        let minStepInterval: TimeInterval = 0.3

        var didStep = false
        var computedCadence: Int?

        if verticalAccel > impactThreshold && (timestamp - lastPeakTime) > minStepInterval {
            runningPeaks.append(timestamp)
            lastPeakTime = timestamp

            if runningPeaks.count > 20 {
                runningPeaks.removeFirst()
            }

            if runningPeaks.count >= 4 {
                var intervals: [TimeInterval] = []
                for i in 1..<runningPeaks.count {
                    intervals.append(runningPeaks[i] - runningPeaks[i-1])
                }
                let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
                let newCadence = min(Int(60.0 / avgInterval), 180)
                computedCadence = newCadence
            }

            didStep = true
        }

        let recentSamples = Array(sampleBuffer.suffix(50))
        guard recentSamples.count >= 20 else {
            return (nil, nil, computedCadence, didStep)
        }

        let verticalAccels = recentSamples.map { $0.accelerationY }
        let maxVert = verticalAccels.max() ?? 0
        let minVert = verticalAccels.min() ?? 0
        let oscillationRange = maxVert - minVert
        let oscillation = oscillationRange * 2.5

        let contactSamples = recentSamples.filter { $0.accelerationY > 0.3 }
        let contactRatio = Double(contactSamples.count) / Double(recentSamples.count)
        let groundContact = contactRatio * 1000 * 0.6

        return (oscillation, groundContact, computedCadence, didStep)
    }

    // MARK: - Riding Analysis (motionQueue)

    nonisolated private func computeRidingMotion(_ sample: WatchMotionSample) -> (postureStability: Double?, rhythmScore: Double?) {
        let recentSamples = Array(sampleBuffer.suffix(50))
        guard recentSamples.count >= 20 else { return (nil, nil) }

        let rollVariance = calculateVariance(recentSamples.map { $0.roll })
        let pitchVariance = calculateVariance(recentSamples.map { $0.pitch })

        let rollPenalty = min(rollVariance * 50, 40)
        let pitchPenalty = min(pitchVariance * 50, 40)
        let posture = max(0, min(100, 100 - rollPenalty - pitchPenalty))

        let verticalAccels = recentSamples.map { $0.accelerationY }
        let accelVariance = calculateVariance(verticalAccels)

        let idealVariance: Double = 0.3
        let varianceDeviation = abs(accelVariance - idealVariance)
        let rhythm = max(0, min(100, 100 - varianceDeviation * 100))

        return (posture, rhythm)
    }

    // MARK: - Barometric Altimeter

    private func startAltimeter() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            Log.location.warning("Altimeter not available")
            return
        }

        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else {
                if let error = error {
                    Log.location.error("Altimeter error: \(error.localizedDescription)")
                }
                return
            }

            let altitude = data.relativeAltitude.doubleValue
            let pressure = data.pressure.doubleValue  // kPa

            // Set start altitude on first reading
            if self.startAltitude == nil {
                self.startAltitude = altitude
            }

            // Calculate relative altitude from session start
            self.relativeAltitude = altitude - (self.startAltitude ?? 0)
            self.barometricPressure = pressure

            // Calculate climb rate (meters per second)
            let now = Date()
            if let lastTime = self.lastAltitudeTime {
                let timeDelta = now.timeIntervalSince(lastTime)
                if timeDelta > 0 {
                    let altitudeDelta = altitude - self.lastAltitude
                    self.altitudeChangeRate = altitudeDelta / timeDelta
                }
            }

            self.lastAltitude = altitude
            self.lastAltitudeTime = now
        }

        Log.location.info("Altimeter started")
    }

    private func stopAltimeter() {
        altimeter.stopRelativeAltitudeUpdates()
    }

    // MARK: - Compass Heading

    private func startCompass() {
        guard CLLocationManager.headingAvailable() else {
            Log.location.warning("Compass not available")
            return
        }

        locationManager.delegate = self
        locationManager.startUpdatingHeading()
        Log.location.info("Compass started")
    }

    private func stopCompass() {
        locationManager.stopUpdatingHeading()
    }

    // MARK: - Water Submersion Detection

    private func startWaterDetection() {
        #if os(watchOS)
        if #available(watchOS 10.0, *) {
            guard CMWaterSubmersionManager.waterSubmersionAvailable else {
                Log.location.warning("Water submersion detection not available on this device")
                return
            }

            // Setting delegate starts water submersion updates automatically
            _ = waterSubmersionManager
            Log.location.info("Water submersion detection started")
        } else {
            Log.location.info("Water submersion requires watchOS 10+")
        }
        #endif
    }

    private func stopWaterDetection() {
        #if os(watchOS)
        if #available(watchOS 10.0, *) {
            // CMWaterSubmersionManager stops automatically when delegate is nil
            // We don't nil it here since it's a lazy var, but updates stop when tracking stops
            isSubmerged = false
            waterDepth = 0.0
            Log.location.info("Water submersion detection stopped")
        }
        #endif
    }

    // MARK: - Enhanced Motion Analysis (motionQueue)

    nonisolated private func computeEnhancedMetrics(_ sample: WatchMotionSample) -> (pitch: Double, roll: Double, tremor: Double?, intensity: Double?, breathing: Double?) {
        let pitch = sample.pitch * 180.0 / .pi
        let roll = sample.roll * 180.0 / .pi

        let tremor = calculateTremorLevel(sample)
        let intensity = calculateMovementIntensity(sample)
        let breathing = estimateBreathingRate(sample)

        return (pitch, roll, tremor, intensity, breathing)
    }

    nonisolated private func calculateTremorLevel(_ sample: WatchMotionSample) -> Double? {
        let accelMag = sample.accelerationMagnitude

        tremorBuffer.append(accelMag)
        if tremorBuffer.count > 25 {  // 0.5 seconds at 50Hz
            tremorBuffer.removeFirst()
        }

        guard tremorBuffer.count >= 10 else { return nil }

        let variance = calculateVariance(tremorBuffer)
        return min(100, variance * 2000)
    }

    nonisolated private func calculateMovementIntensity(_ sample: WatchMotionSample) -> Double? {
        let recentSamples = Array(sampleBuffer.suffix(50))
        guard recentSamples.count >= 10 else { return nil }

        let avgMagnitude = recentSamples.map { $0.accelerationMagnitude }.reduce(0, +) / Double(recentSamples.count)
        let maxMagnitude = recentSamples.map { $0.accelerationMagnitude }.max() ?? 0

        return min(100, (avgMagnitude + maxMagnitude) * 25)
    }

    nonisolated private func estimateBreathingRate(_ sample: WatchMotionSample) -> Double? {
        breathingSamples.append(sample.accelerationZ)

        if breathingSamples.count > 500 {
            breathingSamples.removeFirst()
        }

        // Only calculate every 2 seconds
        let now = Date()
        if let lastCalc = lastBreathingCalc, now.timeIntervalSince(lastCalc) < 2.0 {
            return nil
        }
        lastBreathingCalc = now

        guard breathingSamples.count >= 200 else { return nil }

        let smoothed = movingAverage(breathingSamples, windowSize: 25)
        var crossings = 0
        for i in 1..<smoothed.count {
            if (smoothed[i-1] < 0 && smoothed[i] >= 0) ||
               (smoothed[i-1] >= 0 && smoothed[i] < 0) {
                crossings += 1
            }
        }

        let rawRate = Double(crossings) / 2.0 * 6.0
        return min(30, max(8, rawRate))
    }

    nonisolated private func movingAverage(_ values: [Double], windowSize: Int) -> [Double] {
        guard values.count >= windowSize else { return values }
        var result: [Double] = []
        for i in 0..<(values.count - windowSize + 1) {
            let window = Array(values[i..<(i + windowSize)])
            let avg = window.reduce(0, +) / Double(windowSize)
            result.append(avg)
        }
        return result
    }

    // MARK: - Helpers

    nonisolated private func calculateVariance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { ($0 - mean) * ($0 - mean) }
        return squaredDiffs.reduce(0, +) / Double(values.count - 1)
    }

    // MARK: - Public API

    /// Get current metrics for sending to iPhone
    func currentMetrics() -> WatchMotionMetrics {
        WatchMotionMetrics(
            mode: currentMode,
            stanceStability: stanceStability,
            movementMagnitude: movementMagnitude,
            strokeCount: strokeCount,
            strokeRate: strokeRate,
            verticalOscillation: verticalOscillation,
            groundContactTime: groundContactTime,
            cadence: cadence,
            postureStability: postureStability,
            rhythmScore: rhythmScore,
            timestamp: Date(),
            // Enhanced sensor data
            relativeAltitude: relativeAltitude,
            altitudeChangeRate: altitudeChangeRate,
            barometricPressure: barometricPressure,
            isSubmerged: isSubmerged,
            waterDepth: waterDepth,
            compassHeading: compassHeading,
            breathingRate: breathingRate,
            posturePitch: posturePitch,
            postureRoll: postureRoll,
            tremorLevel: tremorLevel,
            movementIntensity: movementIntensity
        )
    }
}

/// Aggregated metrics to send to iPhone
nonisolated struct WatchMotionMetrics: Codable {
    let mode: WatchMotionMode
    let stanceStability: Double
    let movementMagnitude: Double
    let strokeCount: Int
    let strokeRate: Double
    let verticalOscillation: Double
    let groundContactTime: Double
    let cadence: Int
    let postureStability: Double
    let rhythmScore: Double
    let timestamp: Date

    // Enhanced sensor data
    let relativeAltitude: Double
    let altitudeChangeRate: Double
    let barometricPressure: Double
    let isSubmerged: Bool
    let waterDepth: Double
    let compassHeading: Double
    let breathingRate: Double
    let posturePitch: Double
    let postureRoll: Double
    let tremorLevel: Double
    let movementIntensity: Double
}

// MARK: - CLLocationManagerDelegate

extension WatchMotionManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Use true heading if available, otherwise magnetic
        if newHeading.trueHeading >= 0 {
            compassHeading = newHeading.trueHeading
        } else {
            compassHeading = newHeading.magneticHeading
        }
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        return false  // Don't interrupt workout with calibration UI
    }
}

// MARK: - CMWaterSubmersionManagerDelegate

#if os(watchOS)
@available(watchOS 10.0, *)
extension WatchMotionManager: CMWaterSubmersionManagerDelegate {
    nonisolated func manager(_ manager: CMWaterSubmersionManager, didUpdate event: CMWaterSubmersionEvent) {
        nonisolated(unsafe) let evt = event
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch evt.state {
            case .notSubmerged:
                self.isSubmerged = false
                self.waterDepth = 0.0
                Log.location.info("Water state: Not submerged")

            case .submerged:
                self.isSubmerged = true
                Log.location.info("Water state: Submerged")

            case .unknown:
                Log.location.debug("Water state: Unknown")

            @unknown default:
                Log.location.debug("Water state: Unhandled state")
            }
        }
    }

    nonisolated func manager(_ manager: CMWaterSubmersionManager, didUpdate measurement: CMWaterSubmersionMeasurement) {
        nonisolated(unsafe) let m = measurement
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Update water depth from the measurement
            if let depth = m.depth {
                self.waterDepth = depth.converted(to: .meters).value
                Log.location.debug("Water depth: \(self.waterDepth)m")
            }

            // Submersion state from measurement (DepthState has shallow/deep variants)
            switch m.submersionState {
            case .notSubmerged:
                self.isSubmerged = false
            case .submergedShallow, .submergedDeep:
                self.isSubmerged = true
            case .unknown, .approachingMaxDepth, .pastMaxDepth, .sensorDepthError:
                break
            @unknown default:
                break
            }
        }
    }

    func manager(_ manager: CMWaterSubmersionManager, errorOccurred error: any Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            Log.location.error("Water submersion error: \(error.localizedDescription)")
            self.isSubmerged = false
            self.waterDepth = 0.0
        }
    }

    func manager(_ manager: CMWaterSubmersionManager, didUpdate measurement: CMWaterTemperature) {
        // Water temperature updates - can be used for swimming analysis
        Log.location.debug("Water temperature: \(measurement.temperature.converted(to: .celsius).value)°C")
    }
}
#endif
