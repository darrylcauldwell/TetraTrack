//
//  AIDataCollector.swift
//  TetraTrack
//
//  Comprehensive data collection for AI analysis
//  Captures ALL available metrics - even seemingly irrelevant ones
//  AI may find unexpected correlations in this data
//

import Foundation
import CoreMotion
import CoreLocation
import AVFoundation
import UIKit
#if canImport(WeatherKit)
import WeatherKit
#endif

// MARK: - AI Data Snapshot

/// Comprehensive data snapshot for AI training and analysis
/// Captures everything available at a moment in time
struct AIDataSnapshot: Codable, Sendable {
    let timestamp: Date
    let sessionID: UUID

    // MARK: - Motion Data (50Hz sampling compressed to key features)
    var motion: MotionSnapshot?

    // MARK: - Location Data
    var location: LocationSnapshot?

    // MARK: - Environmental Data
    var environment: EnvironmentSnapshot?

    // MARK: - Device State
    var device: DeviceSnapshot?

    // MARK: - Temporal Context
    var temporal: TemporalContext?

    // MARK: - Physiological Estimates
    var physiology: PhysiologySnapshot?

    // MARK: - Audio Environment
    var audio: AudioSnapshot?

    // MARK: - Derived Metrics
    var derived: DerivedMetrics?
}

// MARK: - Motion Snapshot

struct MotionSnapshot: Codable, Sendable {
    // Raw acceleration (g-force)
    let accelerationX: Double
    let accelerationY: Double
    let accelerationZ: Double
    let accelerationMagnitude: Double

    // Rotation rates (rad/s)
    let rotationX: Double
    let rotationY: Double
    let rotationZ: Double
    let rotationMagnitude: Double

    // Attitude (radians)
    let pitch: Double
    let roll: Double
    let yaw: Double

    // Gravity vector
    let gravityX: Double
    let gravityY: Double
    let gravityZ: Double

    // User acceleration (without gravity)
    let userAccelX: Double
    let userAccelY: Double
    let userAccelZ: Double

    // Statistical features (computed over last N samples)
    let accelVariance: Double
    let accelSkewness: Double
    let accelKurtosis: Double
    let rotationVariance: Double

    // Frequency domain features
    let dominantFrequency: Double
    let spectralEntropy: Double
    let peakMagnitude: Double

    // Impact/vibration metrics
    let maxImpact: Double
    let impactCount: Int
    let vibrationLevel: Double

    // Stability metrics
    let stabilityIndex: Double
    let jerkMagnitude: Double  // Rate of change of acceleration

    // Motion classification confidence
    let stationaryConfidence: Double
    let walkingConfidence: Double
    let runningConfidence: Double
    let unknownConfidence: Double
}

// MARK: - Location Snapshot

struct LocationSnapshot: Codable, Sendable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let altitudeAccuracy: Double

    let speed: Double  // m/s
    let speedAccuracy: Double
    let course: Double  // degrees
    let courseAccuracy: Double

    let horizontalAccuracy: Double
    let verticalAccuracy: Double

    // Derived location metrics
    let distanceFromStart: Double
    let distanceFromLast: Double
    let bearingChange: Double
    let elevationChange: Double
    let slopeAngle: Double  // Terrain slope in degrees

    // GPS quality indicators
    let gpsSignalStrength: Double  // Estimated from accuracy
    let hdop: Double?  // Horizontal dilution of precision

    // Geomagnetic data
    let magneticHeading: Double?
    let trueHeading: Double?
    let headingAccuracy: Double?

    // Floor level (indoor)
    let floor: Int?
}

// MARK: - Environment Snapshot

struct EnvironmentSnapshot: Codable, Sendable {
    // Weather (if available)
    let temperature: Double?  // Celsius
    let humidity: Double?  // 0-100%
    let pressure: Double?  // hPa (barometric)
    let windSpeed: Double?  // m/s
    let windDirection: Double?  // degrees
    let uvIndex: Double?
    let visibility: Double?  // meters
    let cloudCover: Double?  // 0-100%
    let precipitationIntensity: Double?
    let precipitationProbability: Double?
    let weatherCondition: String?  // clear, cloudy, rain, etc.

    // Pressure trends (useful for horse/rider comfort)
    let pressureChange3h: Double?  // Change in last 3 hours
    let pressureTrend: String?  // rising, falling, stable

    // Sun position (affects visibility, shadows)
    let sunAltitude: Double?  // degrees above horizon
    let sunAzimuth: Double?
    let isDaylight: Bool
    let minutesToSunrise: Int?
    let minutesToSunset: Int?

    // Moon phase (some believe affects horse behavior)
    let moonPhase: Double?  // 0-1 (new to full)
    let moonIllumination: Double?

    // Ambient light (from device sensors)
    let ambientLightLevel: Double?

    // Air quality (if available)
    let aqiIndex: Int?
    let pollenLevel: String?
}

// MARK: - Device Snapshot

struct DeviceSnapshot: Codable, Sendable {
    // Battery
    let batteryLevel: Double  // 0-1
    let batteryState: String  // charging, unplugged, full
    let isLowPowerMode: Bool

    // Thermal
    let thermalState: String  // nominal, fair, serious, critical

    // Connectivity
    let isWifiConnected: Bool
    let isCellularConnected: Bool
    let cellularSignalStrength: Int?

    // Device orientation
    let deviceOrientation: String  // portrait, landscape, faceUp, etc.
    let isFlat: Bool

    // Processing state
    let cpuUsage: Double?
    let memoryUsage: Double?

    // Sensor availability
    let hasAccelerometer: Bool
    let hasGyroscope: Bool
    let hasMagnetometer: Bool
    let hasBarometer: Bool

    // Device model info (affects sensor quality)
    let deviceModel: String
    let osVersion: String

    // Watch connection
    let isWatchConnected: Bool
    let watchBatteryLevel: Double?
}

// MARK: - Temporal Context

struct TemporalContext: Codable, Sendable {
    let timestamp: Date
    let timeOfDay: Double  // 0-24 hours as decimal
    let dayOfWeek: Int  // 1-7
    let dayOfMonth: Int
    let month: Int
    let weekOfYear: Int
    let isWeekend: Bool

    // Session timing
    let secondsSinceSessionStart: Double
    let secondsSinceLastEvent: Double

    // Circadian context
    let hoursFromMidnight: Double
    let hoursFromNoon: Double
    let isTypicalTrainingTime: Bool?  // Based on user patterns

    // Historical context
    let daysSinceLastRide: Int?
    let ridesThisWeek: Int?
    let ridesThisMonth: Int?

    // Recovery context
    let hoursSinceLastRide: Double?
    let hoursSinceSleep: Double?  // If HealthKit sleep data available

    // Seasonal
    let season: String  // spring, summer, fall, winter
    let daylightHours: Double?
}

// MARK: - Physiology Snapshot

struct PhysiologySnapshot: Codable, Sendable {
    // Heart rate
    let heartRate: Double?
    let heartRateVariability: Double?  // SDNN in ms
    let restingHeartRate: Double?
    let heartRateReserve: Double?  // Current HR - Resting HR
    let percentMaxHR: Double?
    let hrZone: Int?  // 1-5

    // Trends
    let hrTrend5min: String?  // rising, falling, stable
    let hrvTrend: String?

    // Estimated stress/recovery
    let stressLevel: Double?  // 0-100 estimated from HRV
    let recoveryScore: Double?  // 0-100

    // Activity metrics from HealthKit
    let stepCount: Int?
    let activeCalories: Double?
    let standHours: Int?

    // Blood oxygen (if available)
    let oxygenSaturation: Double?

    // Respiratory
    let respiratoryRate: Double?

    // Energy
    let estimatedCaloriesBurned: Double
    let cumulativeCalories: Double

    // Fatigue indicators
    let estimatedFatigueLevel: Double?  // 0-100
    let performanceDeclinePercent: Double?
}

// MARK: - Audio Snapshot

struct AudioSnapshot: Codable, Sendable {
    // Ambient sound levels (dB)
    let ambientLevel: Double?
    let peakLevel: Double?
    let averageLevel: Double?

    // Audio characteristics
    let dominantFrequency: Double?
    let spectralCentroid: Double?

    // Classification (if possible)
    let isQuiet: Bool
    let hasTraffic: Bool?
    let hasVoices: Bool?
    let hasAnimalSounds: Bool?

    // Noise consistency
    let noiseVariance: Double?
}

// MARK: - Derived Metrics

struct DerivedMetrics: Codable, Sendable {
    // Current gait analysis
    let detectedGait: String
    let gaitConfidence: Double
    let gaitDuration: Double  // Seconds in current gait

    // Stride metrics
    let strideRate: Double?  // Strides per minute
    let strideVariability: Double?
    let estimatedStrideLength: Double?

    // Balance metrics
    let leftRightBalance: Double  // 0-100, 50 is balanced
    let leadLeg: String?  // left, right, none
    let leadConfidence: Double?

    // Movement quality
    let rhythmScore: Double?  // 0-100
    let symmetryScore: Double?  // 0-100
    let smoothnessScore: Double?  // 0-100

    // Efficiency metrics
    let speedEfficiency: Double?  // Speed vs energy
    let movementEconomy: Double?

    // Anomaly detection
    let anomalyScore: Double?  // How unusual is current movement
    let deviationFromBaseline: Double?

    // Trend indicators
    let performanceTrend: String?  // improving, declining, stable
    let fatigueTrend: String?

    // Session quality
    let cumulativeQualityScore: Double
    let consistencyScore: Double
}

// MARK: - AI Data Collector

@MainActor
final class AIDataCollector {
    static let shared = AIDataCollector()

    private var currentSessionID: UUID?
    private var sessionStartTime: Date?
    private var snapshots: [AIDataSnapshot] = []
    private var motionBuffer: [CMDeviceMotion] = []
    private let bufferSize = 100  // Last 2 seconds at 50Hz

    private var lastSnapshot: AIDataSnapshot?
    private var snapshotInterval: TimeInterval = 1.0  // Capture every second

    // Statistical accumulators
    private var accelHistory: [Double] = []
    private var rotationHistory: [Double] = []

    private init() {}

    // MARK: - Session Management

    func startSession() -> UUID {
        let sessionID = UUID()
        currentSessionID = sessionID
        sessionStartTime = Date()
        snapshots = []
        motionBuffer = []
        accelHistory = []
        rotationHistory = []
        return sessionID
    }

    func endSession() -> [AIDataSnapshot] {
        let captured = snapshots
        currentSessionID = nil
        sessionStartTime = nil
        snapshots = []
        return captured
    }

    // MARK: - Data Capture

    func recordMotion(_ motion: CMDeviceMotion) {
        motionBuffer.append(motion)
        if motionBuffer.count > bufferSize {
            motionBuffer.removeFirst()
        }

        // Track acceleration magnitude history
        let mag = sqrt(
            pow(motion.userAcceleration.x, 2) +
            pow(motion.userAcceleration.y, 2) +
            pow(motion.userAcceleration.z, 2)
        )
        accelHistory.append(mag)
        if accelHistory.count > 500 { accelHistory.removeFirst() }

        let rotMag = sqrt(
            pow(motion.rotationRate.x, 2) +
            pow(motion.rotationRate.y, 2) +
            pow(motion.rotationRate.z, 2)
        )
        rotationHistory.append(rotMag)
        if rotationHistory.count > 500 { rotationHistory.removeFirst() }
    }

    func captureSnapshot(
        location: CLLocation?,
        heartRate: Double?,
        hrv: Double?,
        gaitType: String,
        gaitConfidence: Double
    ) {
        guard let sessionID = currentSessionID,
              let startTime = sessionStartTime else { return }

        let now = Date()

        // Check interval
        if let last = lastSnapshot,
           now.timeIntervalSince(last.timestamp) < snapshotInterval {
            return
        }

        let snapshot = AIDataSnapshot(
            timestamp: now,
            sessionID: sessionID,
            motion: buildMotionSnapshot(),
            location: buildLocationSnapshot(location),
            environment: buildEnvironmentSnapshot(),
            device: buildDeviceSnapshot(),
            temporal: buildTemporalContext(sessionStart: startTime),
            physiology: buildPhysiologySnapshot(heartRate: heartRate, hrv: hrv),
            audio: nil,  // Would require audio session
            derived: buildDerivedMetrics(gaitType: gaitType, gaitConfidence: gaitConfidence)
        )

        snapshots.append(snapshot)
        lastSnapshot = snapshot
    }

    // MARK: - Snapshot Builders

    private func buildMotionSnapshot() -> MotionSnapshot? {
        guard let latest = motionBuffer.last else { return nil }

        let accel = latest.userAcceleration
        let rot = latest.rotationRate
        let att = latest.attitude
        let grav = latest.gravity

        // Calculate statistical features
        let variance = calculateVariance(accelHistory)
        let skewness = calculateSkewness(accelHistory)
        let kurtosis = calculateKurtosis(accelHistory)
        let rotVariance = calculateVariance(rotationHistory)

        // Impact detection
        let impacts = accelHistory.filter { $0 > 1.5 }  // > 1.5g
        let maxImpact = accelHistory.max() ?? 0

        // Jerk (rate of change of acceleration)
        var jerk = 0.0
        if motionBuffer.count >= 2 {
            let prev = motionBuffer[motionBuffer.count - 2]
            let dt = latest.timestamp - prev.timestamp
            if dt > 0 {
                jerk = sqrt(
                    pow(accel.x - prev.userAcceleration.x, 2) +
                    pow(accel.y - prev.userAcceleration.y, 2) +
                    pow(accel.z - prev.userAcceleration.z, 2)
                ) / dt
            }
        }

        // Stability index (inverse of variance, normalized)
        let stability = 1.0 / (1.0 + variance * 10)

        return MotionSnapshot(
            accelerationX: accel.x,
            accelerationY: accel.y,
            accelerationZ: accel.z,
            accelerationMagnitude: sqrt(accel.x*accel.x + accel.y*accel.y + accel.z*accel.z),
            rotationX: rot.x,
            rotationY: rot.y,
            rotationZ: rot.z,
            rotationMagnitude: sqrt(rot.x*rot.x + rot.y*rot.y + rot.z*rot.z),
            pitch: att.pitch,
            roll: att.roll,
            yaw: att.yaw,
            gravityX: grav.x,
            gravityY: grav.y,
            gravityZ: grav.z,
            userAccelX: accel.x,
            userAccelY: accel.y,
            userAccelZ: accel.z,
            accelVariance: variance,
            accelSkewness: skewness,
            accelKurtosis: kurtosis,
            rotationVariance: rotVariance,
            dominantFrequency: estimateDominantFrequency(),
            spectralEntropy: 0,  // Would need FFT
            peakMagnitude: maxImpact,
            maxImpact: maxImpact,
            impactCount: impacts.count,
            vibrationLevel: variance,
            stabilityIndex: stability,
            jerkMagnitude: jerk,
            stationaryConfidence: 0,
            walkingConfidence: 0,
            runningConfidence: 0,
            unknownConfidence: 0
        )
    }

    private func buildLocationSnapshot(_ location: CLLocation?) -> LocationSnapshot? {
        guard let loc = location else { return nil }

        // Estimate GPS signal strength from accuracy
        let signalStrength = max(0, min(1, (50 - loc.horizontalAccuracy) / 50))

        // Calculate slope if we have previous location
        var slope = 0.0
        if let lastSnap = lastSnapshot,
           let lastLoc = lastSnap.location {
            let distDelta = loc.distance(from: CLLocation(
                latitude: lastLoc.latitude,
                longitude: lastLoc.longitude
            ))
            let elevDelta = loc.altitude - lastLoc.altitude
            if distDelta > 0 {
                slope = atan(elevDelta / distDelta) * 180 / .pi
            }
        }

        return LocationSnapshot(
            latitude: loc.coordinate.latitude,
            longitude: loc.coordinate.longitude,
            altitude: loc.altitude,
            altitudeAccuracy: loc.verticalAccuracy,
            speed: max(0, loc.speed),
            speedAccuracy: loc.speedAccuracy,
            course: loc.course >= 0 ? loc.course : 0,
            courseAccuracy: loc.courseAccuracy,
            horizontalAccuracy: loc.horizontalAccuracy,
            verticalAccuracy: loc.verticalAccuracy,
            distanceFromStart: 0,  // Would need session tracking
            distanceFromLast: 0,
            bearingChange: 0,
            elevationChange: 0,
            slopeAngle: slope,
            gpsSignalStrength: signalStrength,
            hdop: nil,
            magneticHeading: nil,
            trueHeading: nil,
            headingAccuracy: nil,
            floor: loc.floor?.level
        )
    }

    private func buildEnvironmentSnapshot() -> EnvironmentSnapshot {
        let calendar = Calendar.current
        let now = Date()

        // Calculate sun position approximation
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let timeDecimal = Double(hour) + Double(minute) / 60.0
        let isDaylight = timeDecimal >= 6 && timeDecimal <= 20

        // Moon phase calculation (simplified)
        let moonCycle = 29.53  // days
        let refNewMoon = Date(timeIntervalSince1970: 947181600)  // Jan 6, 2000
        let daysSinceRef = now.timeIntervalSince(refNewMoon) / 86400
        let moonPhase = (daysSinceRef.truncatingRemainder(dividingBy: moonCycle)) / moonCycle

        return EnvironmentSnapshot(
            temperature: nil,
            humidity: nil,
            pressure: nil,
            windSpeed: nil,
            windDirection: nil,
            uvIndex: nil,
            visibility: nil,
            cloudCover: nil,
            precipitationIntensity: nil,
            precipitationProbability: nil,
            weatherCondition: nil,
            pressureChange3h: nil,
            pressureTrend: nil,
            sunAltitude: nil,
            sunAzimuth: nil,
            isDaylight: isDaylight,
            minutesToSunrise: nil,
            minutesToSunset: nil,
            moonPhase: moonPhase,
            moonIllumination: abs(moonPhase - 0.5) * 2,
            ambientLightLevel: nil,
            aqiIndex: nil,
            pollenLevel: nil
        )
    }

    private func buildDeviceSnapshot() -> DeviceSnapshot {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true

        let thermalState: String
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermalState = "nominal"
        case .fair: thermalState = "fair"
        case .serious: thermalState = "serious"
        case .critical: thermalState = "critical"
        @unknown default: thermalState = "unknown"
        }

        let batteryState: String
        switch device.batteryState {
        case .charging: batteryState = "charging"
        case .full: batteryState = "full"
        case .unplugged: batteryState = "unplugged"
        case .unknown: batteryState = "unknown"
        @unknown default: batteryState = "unknown"
        }

        let orientation: String
        switch device.orientation {
        case .portrait: orientation = "portrait"
        case .portraitUpsideDown: orientation = "portraitUpsideDown"
        case .landscapeLeft: orientation = "landscapeLeft"
        case .landscapeRight: orientation = "landscapeRight"
        case .faceUp: orientation = "faceUp"
        case .faceDown: orientation = "faceDown"
        case .unknown: orientation = "unknown"
        @unknown default: orientation = "unknown"
        }

        return DeviceSnapshot(
            batteryLevel: Double(device.batteryLevel),
            batteryState: batteryState,
            isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermalState: thermalState,
            isWifiConnected: false,  // Would need network monitoring
            isCellularConnected: false,
            cellularSignalStrength: nil,
            deviceOrientation: orientation,
            isFlat: device.orientation == .faceUp || device.orientation == .faceDown,
            cpuUsage: nil,
            memoryUsage: nil,
            hasAccelerometer: true,
            hasGyroscope: true,
            hasMagnetometer: true,
            hasBarometer: true,
            deviceModel: device.model,
            osVersion: device.systemVersion,
            isWatchConnected: false,
            watchBatteryLevel: nil
        )
    }

    private func buildTemporalContext(sessionStart: Date) -> TemporalContext {
        let now = Date()
        let calendar = Calendar.current

        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let timeDecimal = Double(hour) + Double(minute) / 60.0

        let dayOfWeek = calendar.component(.weekday, from: now)
        let month = calendar.component(.month, from: now)

        let season: String
        switch month {
        case 3...5: season = "spring"
        case 6...8: season = "summer"
        case 9...11: season = "fall"
        default: season = "winter"
        }

        return TemporalContext(
            timestamp: now,
            timeOfDay: timeDecimal,
            dayOfWeek: dayOfWeek,
            dayOfMonth: calendar.component(.day, from: now),
            month: month,
            weekOfYear: calendar.component(.weekOfYear, from: now),
            isWeekend: dayOfWeek == 1 || dayOfWeek == 7,
            secondsSinceSessionStart: now.timeIntervalSince(sessionStart),
            secondsSinceLastEvent: lastSnapshot.map { now.timeIntervalSince($0.timestamp) } ?? 0,
            hoursFromMidnight: timeDecimal,
            hoursFromNoon: abs(timeDecimal - 12),
            isTypicalTrainingTime: nil,
            daysSinceLastRide: nil,
            ridesThisWeek: nil,
            ridesThisMonth: nil,
            hoursSinceLastRide: nil,
            hoursSinceSleep: nil,
            season: season,
            daylightHours: nil
        )
    }

    private func buildPhysiologySnapshot(heartRate: Double?, hrv: Double?) -> PhysiologySnapshot {
        let maxHR = 190.0  // Would come from user profile
        let restingHR = 60.0  // Would come from user profile

        var percentMax: Double?
        var reserve: Double?
        var zone: Int?

        if let hr = heartRate {
            percentMax = (hr / maxHR) * 100
            reserve = hr - restingHR

            switch percentMax! {
            case 0..<60: zone = 1
            case 60..<70: zone = 2
            case 70..<80: zone = 3
            case 80..<90: zone = 4
            default: zone = 5
            }
        }

        // Estimate stress from HRV (lower HRV = higher stress)
        var stress: Double?
        if let hrvValue = hrv {
            stress = max(0, min(100, 100 - hrvValue))
        }

        return PhysiologySnapshot(
            heartRate: heartRate,
            heartRateVariability: hrv,
            restingHeartRate: restingHR,
            heartRateReserve: reserve,
            percentMaxHR: percentMax,
            hrZone: zone,
            hrTrend5min: nil,
            hrvTrend: nil,
            stressLevel: stress,
            recoveryScore: hrv.map { min(100, $0) },
            stepCount: nil,
            activeCalories: nil,
            standHours: nil,
            oxygenSaturation: nil,
            respiratoryRate: nil,
            estimatedCaloriesBurned: 0,
            cumulativeCalories: 0,
            estimatedFatigueLevel: nil,
            performanceDeclinePercent: nil
        )
    }

    private func buildDerivedMetrics(gaitType: String, gaitConfidence: Double) -> DerivedMetrics {
        DerivedMetrics(
            detectedGait: gaitType,
            gaitConfidence: gaitConfidence,
            gaitDuration: 0,
            strideRate: nil,
            strideVariability: nil,
            estimatedStrideLength: nil,
            leftRightBalance: 50,
            leadLeg: nil,
            leadConfidence: nil,
            rhythmScore: nil,
            symmetryScore: nil,
            smoothnessScore: nil,
            speedEfficiency: nil,
            movementEconomy: nil,
            anomalyScore: nil,
            deviationFromBaseline: nil,
            performanceTrend: nil,
            fatigueTrend: nil,
            cumulativeQualityScore: 0,
            consistencyScore: 0
        )
    }

    // MARK: - Statistical Helpers

    private func calculateVariance(_ data: [Double]) -> Double {
        guard data.count > 1 else { return 0 }
        let mean = data.reduce(0, +) / Double(data.count)
        let squaredDiffs = data.map { pow($0 - mean, 2) }
        return squaredDiffs.reduce(0, +) / Double(data.count - 1)
    }

    private func calculateSkewness(_ data: [Double]) -> Double {
        guard data.count > 2 else { return 0 }
        let mean = data.reduce(0, +) / Double(data.count)
        let variance = calculateVariance(data)
        guard variance > 0 else { return 0 }
        let stdDev = sqrt(variance)
        let cubedDiffs = data.map { pow(($0 - mean) / stdDev, 3) }
        return cubedDiffs.reduce(0, +) / Double(data.count)
    }

    private func calculateKurtosis(_ data: [Double]) -> Double {
        guard data.count > 3 else { return 0 }
        let mean = data.reduce(0, +) / Double(data.count)
        let variance = calculateVariance(data)
        guard variance > 0 else { return 0 }
        let stdDev = sqrt(variance)
        let fourthPowerDiffs = data.map { pow(($0 - mean) / stdDev, 4) }
        return fourthPowerDiffs.reduce(0, +) / Double(data.count) - 3  // Excess kurtosis
    }

    private func estimateDominantFrequency() -> Double {
        // Simplified: count zero crossings in acceleration
        guard accelHistory.count > 10 else { return 0 }
        let mean = accelHistory.reduce(0, +) / Double(accelHistory.count)
        var crossings = 0
        for i in 1..<accelHistory.count {
            if (accelHistory[i-1] - mean) * (accelHistory[i] - mean) < 0 {
                crossings += 1
            }
        }
        // Frequency = crossings / (2 * duration)
        let duration = Double(accelHistory.count) / 50.0  // 50Hz sampling
        return Double(crossings) / (2 * duration)
    }

    // MARK: - Data Export

    func exportSessionData() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(snapshots)
    }
}
