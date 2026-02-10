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
struct WatchMotionSample: Codable {
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
    case riding      // Biomechanics for equestrian
    case idle
}

/// Captures and processes Watch IMU data for all training disciplines.
/// Acts as a sensor companion - computed metrics are sent to iPhone.
@Observable
final class WatchMotionManager: NSObject {
    // MARK: - State

    private(set) var isTracking: Bool = false
    private(set) var currentMode: WatchMotionMode = .idle

    // Shooting metrics
    private(set) var stanceStability: Double = 0.0  // 0-100%
    private(set) var movementMagnitude: Double = 0.0

    // Swimming metrics
    private(set) var strokeCount: Int = 0
    private(set) var strokeRate: Double = 0.0  // strokes per minute

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
    private var sampleBuffer: [WatchMotionSample] = []
    private var lastStrokeTime: Date?
    private var strokeTimes: [TimeInterval] = []
    private var runningPeaks: [TimeInterval] = []
    private var lastPeakTime: TimeInterval = 0
    private var peakDetectionThreshold: Double = 1.2  // G-force threshold

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
    private var breathingSamples: [Double] = []
    private var lastBreathingCalc: Date?

    // Tremor analysis (high-frequency motion)
    private var tremorBuffer: [Double] = []

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
        case .riding: 1.0 / 50.0     // 50Hz for biomechanics
        case .idle: 1.0 / 10.0
        }

        motionManager.deviceMotionUpdateInterval = interval

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else {
                if let error = error {
                    Log.location.error("Motion update error: \(error.localizedDescription)")
                }
                return
            }

            self.processMotion(motion)
        }

        // Start barometric altimeter
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
        sampleBuffer = []
        stanceStability = 100.0
        movementMagnitude = 0.0
        strokeCount = 0
        strokeRate = 0.0
        strokeTimes = []
        verticalOscillation = 0.0
        groundContactTime = 0.0
        cadence = 0
        runningPeaks = []
        lastPeakTime = 0
        lastStrokeTime = nil
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
        breathingSamples = []
        lastBreathingCalc = nil
        posturePitch = 0.0
        postureRoll = 0.0
        tremorLevel = 0.0
        tremorBuffer = []
        movementIntensity = 0.0
    }

    private func processMotion(_ motion: CMDeviceMotion) {
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
            yaw: motion.attitude.yaw
        )

        sampleBuffer.append(sample)

        // Keep buffer size manageable (last 5 seconds at 50Hz = 250 samples)
        if sampleBuffer.count > 250 {
            sampleBuffer.removeFirst(sampleBuffer.count - 250)
        }

        // Process based on mode
        switch currentMode {
        case .shooting:
            processShootingMotion(sample)
        case .swimming:
            processSwimmingMotion(sample)
        case .running:
            processRunningMotion(sample)
        case .riding:
            processRidingMotion(sample)
        case .idle:
            break
        }

        // Always process enhanced metrics for all modes
        processEnhancedMetrics(sample)

        onMotionUpdate?(sample)
    }

    // MARK: - Shooting Analysis

    private func processShootingMotion(_ sample: WatchMotionSample) {
        // Calculate stance stability from recent samples
        // Lower movement = higher stability
        let recentSamples = Array(sampleBuffer.suffix(25))  // Last 0.5 seconds
        guard recentSamples.count >= 10 else { return }

        // Calculate average movement magnitude
        let avgMagnitude = recentSamples.map { $0.accelerationMagnitude }.reduce(0, +) / Double(recentSamples.count)
        movementMagnitude = avgMagnitude

        // Calculate rotation variance
        let rotationVar = calculateVariance(recentSamples.map { $0.rotationMagnitude })

        // Stability score: lower movement and rotation = higher stability
        // Scale so typical steady hold is 70-90%, perfect stillness is 100%
        let movementPenalty = min(avgMagnitude * 100, 50)  // Max 50% penalty
        let rotationPenalty = min(rotationVar * 20, 30)     // Max 30% penalty

        stanceStability = max(0, min(100, 100 - movementPenalty - rotationPenalty))
    }

    // MARK: - Swimming Analysis

    private func processSwimmingMotion(_ sample: WatchMotionSample) {
        // Detect strokes using lateral acceleration peaks
        // Swimming strokes create distinctive acceleration patterns

        let lateralAccel = abs(sample.accelerationX)  // Lateral (arm swing) acceleration
        let threshold: Double = 0.8  // G threshold for stroke detection

        // Simple peak detection with debouncing
        let now = Date()
        let minStrokeInterval: TimeInterval = 0.5  // Minimum 0.5s between strokes (max 120 strokes/min)

        if lateralAccel > threshold {
            if let lastStroke = lastStrokeTime {
                let interval = now.timeIntervalSince(lastStroke)
                if interval >= minStrokeInterval {
                    strokeCount += 1
                    strokeTimes.append(interval)
                    lastStrokeTime = now

                    // Keep last 10 stroke times for rate calculation
                    if strokeTimes.count > 10 {
                        strokeTimes.removeFirst()
                    }

                    // Calculate stroke rate
                    if strokeTimes.count >= 2 {
                        let avgInterval = strokeTimes.reduce(0, +) / Double(strokeTimes.count)
                        strokeRate = 60.0 / avgInterval  // Strokes per minute
                    }

                    onStrokeDetected?()
                    HapticManager.shared.playClickHaptic()
                }
            } else {
                // First stroke
                strokeCount = 1
                lastStrokeTime = now
                onStrokeDetected?()
            }
        }
    }

    // MARK: - Running Analysis

    private func processRunningMotion(_ sample: WatchMotionSample) {
        // Analyze vertical oscillation and ground contact time
        // Running creates vertical acceleration peaks at foot strike and toe-off

        let verticalAccel = sample.accelerationY  // Vertical acceleration (Y on wrist)
        let timestamp = sample.timestamp

        // Detect foot strike peaks (positive vertical acceleration spike)
        let impactThreshold: Double = 1.5  // G threshold for foot strike
        let minStepInterval: TimeInterval = 0.25  // Max cadence ~240 spm

        if verticalAccel > impactThreshold && (timestamp - lastPeakTime) > minStepInterval {
            runningPeaks.append(timestamp)
            lastPeakTime = timestamp

            // Keep last 20 peaks
            if runningPeaks.count > 20 {
                runningPeaks.removeFirst()
            }

            // Calculate cadence from peak intervals
            if runningPeaks.count >= 4 {
                var intervals: [TimeInterval] = []
                for i in 1..<runningPeaks.count {
                    intervals.append(runningPeaks[i] - runningPeaks[i-1])
                }
                let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
                cadence = Int(60.0 / avgInterval)  // Steps per minute
            }

            onStepDetected?()
        }

        // Calculate vertical oscillation from recent samples
        let recentSamples = Array(sampleBuffer.suffix(50))  // Last 1 second
        guard recentSamples.count >= 20 else { return }

        let verticalAccels = recentSamples.map { $0.accelerationY }
        let maxVert = verticalAccels.max() ?? 0
        let minVert = verticalAccels.min() ?? 0

        // Convert acceleration range to estimated oscillation in cm
        // This is an approximation based on typical running biomechanics
        let oscillationRange = maxVert - minVert
        verticalOscillation = oscillationRange * 4.0  // Scale factor to cm

        // Estimate ground contact time from acceleration pattern
        // Ground contact shows sustained positive vertical acceleration
        let contactSamples = recentSamples.filter { $0.accelerationY > 0.5 }
        let contactRatio = Double(contactSamples.count) / Double(recentSamples.count)

        // Typical ground contact is 200-300ms, scale from ratio
        // At 50Hz, 250ms contact = 12.5 samples out of 50 = 25%
        groundContactTime = contactRatio * 1000 * 0.5  // Convert to ms estimate
    }

    // MARK: - Riding Analysis

    private func processRidingMotion(_ sample: WatchMotionSample) {
        // Analyze rider posture and rhythm during riding
        // Measures how well the rider maintains stable position and moves with the horse

        let recentSamples = Array(sampleBuffer.suffix(50))  // Last 1 second
        guard recentSamples.count >= 20 else { return }

        // Posture stability: low roll/pitch variance = stable position
        let rollVariance = calculateVariance(recentSamples.map { $0.roll })
        let pitchVariance = calculateVariance(recentSamples.map { $0.pitch })

        // Convert variance to stability score (lower variance = higher stability)
        let rollPenalty = min(rollVariance * 50, 40)
        let pitchPenalty = min(pitchVariance * 50, 40)
        postureStability = max(0, min(100, 100 - rollPenalty - pitchPenalty))

        // Rhythm score: consistent vertical movement pattern
        // Good riding shows regular, rhythmic vertical oscillation matching gait
        let verticalAccels = recentSamples.map { $0.accelerationY }
        let accelVariance = calculateVariance(verticalAccels)

        // Some variance is expected (movement with horse), but should be consistent
        // Very low variance = too stiff, very high = bouncing/unbalanced
        let idealVariance: Double = 0.3
        let varianceDeviation = abs(accelVariance - idealVariance)
        rhythmScore = max(0, min(100, 100 - varianceDeviation * 100))
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

    // MARK: - Enhanced Motion Analysis

    private func processEnhancedMetrics(_ sample: WatchMotionSample) {
        // Update posture angles (convert radians to degrees)
        posturePitch = sample.pitch * 180.0 / .pi
        postureRoll = sample.roll * 180.0 / .pi

        // Calculate tremor level (high-frequency motion > 3Hz)
        calculateTremorLevel(sample)

        // Calculate movement intensity
        calculateMovementIntensity(sample)

        // Estimate breathing rate (from chest wall motion patterns)
        estimateBreathingRate(sample)
    }

    private func calculateTremorLevel(_ sample: WatchMotionSample) {
        // Tremor is high-frequency (>3Hz) small amplitude motion
        // Use a high-pass filter approach by looking at rapid changes
        let accelMag = sample.accelerationMagnitude

        tremorBuffer.append(accelMag)
        if tremorBuffer.count > 25 {  // 0.5 seconds at 50Hz
            tremorBuffer.removeFirst()
        }

        guard tremorBuffer.count >= 10 else { return }

        // Calculate variance of recent samples (high variance = tremor)
        let variance = calculateVariance(tremorBuffer)

        // Scale to 0-100 range (typical tremor variance 0.001-0.05)
        tremorLevel = min(100, variance * 2000)
    }

    private func calculateMovementIntensity(_ sample: WatchMotionSample) {
        // Overall movement intensity based on acceleration magnitude
        let recentSamples = Array(sampleBuffer.suffix(50))
        guard recentSamples.count >= 10 else { return }

        let avgMagnitude = recentSamples.map { $0.accelerationMagnitude }.reduce(0, +) / Double(recentSamples.count)
        let maxMagnitude = recentSamples.map { $0.accelerationMagnitude }.max() ?? 0

        // Scale: 0G = 0%, 2G average = 100%
        movementIntensity = min(100, (avgMagnitude + maxMagnitude) * 25)
    }

    private func estimateBreathingRate(_ sample: WatchMotionSample) {
        // Breathing creates subtle chest wall motion in the 0.2-0.4 Hz range
        // (12-24 breaths per minute)
        // Best detected from Z-axis acceleration when Watch is on wrist

        breathingSamples.append(sample.accelerationZ)

        // Keep 10 seconds of samples at 50Hz = 500 samples
        if breathingSamples.count > 500 {
            breathingSamples.removeFirst()
        }

        // Only calculate every 2 seconds
        let now = Date()
        if let lastCalc = lastBreathingCalc, now.timeIntervalSince(lastCalc) < 2.0 {
            return
        }
        lastBreathingCalc = now

        guard breathingSamples.count >= 200 else { return }  // Need at least 4 seconds

        // Simple peak detection in breathing frequency range
        // Count zero-crossings of smoothed signal
        let smoothed = movingAverage(breathingSamples, windowSize: 25)  // 0.5s smoothing
        var crossings = 0
        for i in 1..<smoothed.count {
            if (smoothed[i-1] < 0 && smoothed[i] >= 0) ||
               (smoothed[i-1] >= 0 && smoothed[i] < 0) {
                crossings += 1
            }
        }

        // Each breath cycle has 2 zero crossings
        // Samples span ~10 seconds, so multiply by 6 for per-minute rate
        let rawRate = Double(crossings) / 2.0 * 6.0

        // Clamp to reasonable breathing range (8-30 breaths/min)
        breathingRate = min(30, max(8, rawRate))
    }

    private func movingAverage(_ values: [Double], windowSize: Int) -> [Double] {
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

    private func calculateVariance(_ values: [Double]) -> Double {
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
            compassHeading: compassHeading,
            breathingRate: breathingRate,
            posturePitch: posturePitch,
            postureRoll: postureRoll,
            tremorLevel: tremorLevel,
            movementIntensity: movementIntensity
        )
    }

    /// Get raw motion sample for detailed iPhone analysis
    func latestSample() -> WatchMotionSample? {
        sampleBuffer.last
    }

    /// Get recent samples buffer for bulk transfer to iPhone
    func recentSamples(count: Int = 50) -> [WatchMotionSample] {
        Array(sampleBuffer.suffix(count))
    }
}

/// Aggregated metrics to send to iPhone
struct WatchMotionMetrics: Codable {
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
    func manager(_ manager: CMWaterSubmersionManager, didUpdate event: CMWaterSubmersionEvent) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch event.state {
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

    func manager(_ manager: CMWaterSubmersionManager, didUpdate measurement: CMWaterSubmersionMeasurement) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Update water depth from the measurement
            if let depth = measurement.depth {
                self.waterDepth = depth.converted(to: .meters).value
                Log.location.debug("Water depth: \(self.waterDepth)m")
            }

            // Submersion state from measurement (DepthState has shallow/deep variants)
            switch measurement.submersionState {
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
