//
//  WatchSensorAnalyzer.swift
//  TetraTrack
//
//  Processes enhanced Watch sensor data into actionable metrics for all disciplines.
//  Provides altitude tracking, posture analysis, fatigue detection, and more.
//

import Foundation
import Observation

/// Comprehensive analyzer for Watch sensor data across all disciplines
@Observable
final class WatchSensorAnalyzer: Resettable {

    // MARK: - Singleton

    static let shared = WatchSensorAnalyzer()

    // MARK: - Altitude Metrics

    /// Current altitude relative to session start (meters)
    private(set) var relativeAltitude: Double = 0.0

    /// Rate of altitude change (m/s, positive = ascending)
    private(set) var altitudeChangeRate: Double = 0.0

    /// Total elevation gained during session (meters)
    private(set) var totalElevationGain: Double = 0.0

    /// Total elevation lost during session (meters)
    private(set) var totalElevationLoss: Double = 0.0

    /// Altitude profile samples for visualization
    private(set) var altitudeProfile: [AltitudeSample] = []

    /// Current barometric pressure (kPa)
    private(set) var barometricPressure: Double = 0.0

    // MARK: - Jump Detection (Riding)

    /// Number of jumps detected this session
    private(set) var jumpCount: Int = 0

    /// Details of detected jumps
    private(set) var detectedJumps: [JumpEvent] = []

    /// Whether currently airborne (potential jump in progress)
    private(set) var isAirborne: Bool = false

    // MARK: - Posture Metrics

    /// Forward/back lean angle (degrees, positive = forward)
    private(set) var posturePitch: Double = 0.0

    /// Left/right lean angle (degrees, positive = right)
    private(set) var postureRoll: Double = 0.0

    /// Posture stability score (0-100, higher = more stable)
    private(set) var postureStability: Double = 100.0

    /// Time spent in good posture (seconds)
    private(set) var goodPostureTime: TimeInterval = 0.0

    /// Time spent in poor posture (seconds)
    private(set) var poorPostureTime: TimeInterval = 0.0

    // MARK: - Compass/Navigation

    /// Current compass heading (degrees, 0-360)
    private(set) var compassHeading: Double = 0.0

    /// Heading change rate (degrees/second)
    private(set) var headingChangeRate: Double = 0.0

    /// Detected turns from compass data
    private(set) var compassTurns: [CompassTurn] = []

    // MARK: - Fatigue Metrics

    /// Current tremor level (0-100, higher = more tremor)
    private(set) var tremorLevel: Double = 0.0

    /// Current breathing rate (breaths per minute)
    private(set) var breathingRate: Double = 0.0

    /// Breathing rate trend (positive = increasing)
    private(set) var breathingRateTrend: Double = 0.0

    /// Overall fatigue score (0-100, higher = more fatigued)
    private(set) var fatigueScore: Double = 0.0

    /// Fatigue samples over time for trend analysis
    private(set) var fatigueTrend: [FatigueSample] = []

    // MARK: - Activity Metrics

    /// Current movement intensity (0-100)
    private(set) var movementIntensity: Double = 0.0

    /// Average movement intensity this session
    private(set) var averageIntensity: Double = 0.0

    /// Time in active sections (high intensity)
    private(set) var activeTime: TimeInterval = 0.0

    /// Time in passive sections (low intensity)
    private(set) var passiveTime: TimeInterval = 0.0

    // MARK: - SpO2 Metrics

    /// Current oxygen saturation (%)
    private(set) var oxygenSaturation: Double = 0.0

    /// SpO2 trend (positive = improving)
    private(set) var spo2Trend: Double = 0.0

    /// Minimum SpO2 this session
    private(set) var minSpO2: Double = 100.0

    /// SpO2 samples for recovery analysis
    private(set) var spo2Samples: [SpO2Sample] = []

    // MARK: - Water Detection (Swimming)

    /// Whether currently submerged
    private(set) var isSubmerged: Bool = false

    /// Current water depth (meters)
    private(set) var waterDepth: Double = 0.0

    /// Total submerged time this session
    private(set) var totalSubmergedTime: TimeInterval = 0.0

    /// Number of submersion events
    private(set) var submersionCount: Int = 0

    // MARK: - Training Load (Cross-Discipline)

    /// Combined training load score
    private(set) var trainingLoadScore: Double = 0.0

    /// Recovery quality score (0-100)
    private(set) var recoveryQuality: Double = 100.0

    // MARK: - Private State

    private var lastAltitude: Double?
    private var lastHeading: Double?
    private var lastUpdateTime: Date?
    private var sessionStartTime: Date?
    private var intensitySamples: [Double] = []
    private var breathingRateSamples: [Double] = []
    private var pitchSamples: [Double] = []
    private var rollSamples: [Double] = []
    private var submersionStartTime: Date?

    // Jump detection state
    private var preLandingAltitude: Double?
    private var jumpStartTime: Date?
    private var peakJumpAltitude: Double = 0.0

    // Turn detection state
    private var turnStartHeading: Double?
    private var turnStartTime: Date?
    private var isTurning: Bool = false

    private init() {
        setupWatchConnectivityListener()
    }

    // MARK: - Setup

    private func setupWatchConnectivityListener() {
        let watchManager = WatchConnectivityManager.shared
        watchManager.onEnhancedSensorUpdate = { [weak self] in
            self?.processWatchSensorUpdate()
        }
    }

    // MARK: - Reset

    func reset() {
        relativeAltitude = 0.0
        altitudeChangeRate = 0.0
        totalElevationGain = 0.0
        totalElevationLoss = 0.0
        altitudeProfile = []
        barometricPressure = 0.0

        jumpCount = 0
        detectedJumps = []
        isAirborne = false

        posturePitch = 0.0
        postureRoll = 0.0
        postureStability = 100.0
        goodPostureTime = 0.0
        poorPostureTime = 0.0

        compassHeading = 0.0
        headingChangeRate = 0.0
        compassTurns = []

        tremorLevel = 0.0
        breathingRate = 0.0
        breathingRateTrend = 0.0
        fatigueScore = 0.0
        fatigueTrend = []

        movementIntensity = 0.0
        averageIntensity = 0.0
        activeTime = 0.0
        passiveTime = 0.0

        oxygenSaturation = 0.0
        spo2Trend = 0.0
        minSpO2 = 100.0
        spo2Samples = []

        isSubmerged = false
        waterDepth = 0.0
        totalSubmergedTime = 0.0
        submersionCount = 0

        trainingLoadScore = 0.0
        recoveryQuality = 100.0

        lastAltitude = nil
        lastHeading = nil
        lastUpdateTime = nil
        sessionStartTime = nil
        intensitySamples = []
        breathingRateSamples = []
        pitchSamples = []
        rollSamples = []
        submersionStartTime = nil
        preLandingAltitude = nil
        jumpStartTime = nil
        peakJumpAltitude = 0.0
        turnStartHeading = nil
        turnStartTime = nil
        isTurning = false
    }

    // MARK: - Start/Stop Session

    func startSession() {
        reset()
        sessionStartTime = Date()
    }

    func stopSession() {
        // Finalize any in-progress events
        if isSubmerged, let startTime = submersionStartTime {
            totalSubmergedTime += Date().timeIntervalSince(startTime)
        }
    }

    // MARK: - Process Watch Sensor Update

    private func processWatchSensorUpdate() {
        let watchManager = WatchConnectivityManager.shared
        let now = Date()
        let dt = lastUpdateTime.map { now.timeIntervalSince($0) } ?? 0.1
        lastUpdateTime = now

        // Process altitude
        processAltitude(
            relative: watchManager.relativeAltitude,
            changeRate: watchManager.altitudeChangeRate,
            pressure: watchManager.barometricPressure,
            dt: dt
        )

        // Process posture
        processPosture(
            pitch: watchManager.posturePitch,
            roll: watchManager.postureRoll,
            dt: dt
        )

        // Process compass
        processCompass(
            heading: watchManager.compassHeading,
            dt: dt
        )

        // Process fatigue indicators
        processFatigue(
            tremor: watchManager.tremorLevel,
            breathing: watchManager.breathingRate,
            intensity: watchManager.movementIntensity,
            dt: dt
        )

        // Process SpO2
        processSpO2(spo2: watchManager.oxygenSaturation)

        // Process water detection
        processWaterDetection(
            submerged: watchManager.isSubmerged,
            depth: watchManager.waterDepth,
            dt: dt
        )

        // Update training load
        updateTrainingLoad(dt: dt)
    }

    // MARK: - Altitude Processing

    private func processAltitude(relative: Double, changeRate: Double, pressure: Double, dt: TimeInterval) {
        relativeAltitude = relative
        altitudeChangeRate = changeRate
        barometricPressure = pressure

        // Track elevation gain/loss
        if let last = lastAltitude {
            let delta = relative - last
            if delta > 0.5 {  // Threshold to avoid noise
                totalElevationGain += delta
            } else if delta < -0.5 {
                totalElevationLoss += abs(delta)
            }
        }
        lastAltitude = relative

        // Add to altitude profile (sample every ~2 seconds)
        if altitudeProfile.isEmpty || (altitudeProfile.last?.timestamp.timeIntervalSinceNow ?? -10) < -2 {
            altitudeProfile.append(AltitudeSample(
                timestamp: Date(),
                altitude: relative,
                pressure: pressure
            ))
            // Keep last ~2 hours of altitude data (3600 samples at 2s intervals)
            if altitudeProfile.count > 3600 {
                altitudeProfile.removeFirst()
            }
        }

        // Jump detection
        detectJump(altitude: relative, changeRate: changeRate)
    }

    private func detectJump(altitude: Double, changeRate: Double) {
        // Jump detection: rapid altitude increase followed by decrease
        let jumpThreshold = 0.3  // 30cm minimum jump height
        let airborneThreshold = 1.5  // m/s vertical velocity

        if !isAirborne && changeRate > airborneThreshold {
            // Takeoff detected
            isAirborne = true
            jumpStartTime = Date()
            preLandingAltitude = altitude
            peakJumpAltitude = altitude
        } else if isAirborne {
            // Track peak altitude
            peakJumpAltitude = max(peakJumpAltitude, altitude)

            // Landing detection: altitude decreasing and back near pre-jump level
            if changeRate < -airborneThreshold / 2 {
                if let preAlt = preLandingAltitude, let startTime = jumpStartTime {
                    let jumpHeight = peakJumpAltitude - preAlt
                    if jumpHeight >= jumpThreshold {
                        let jump = JumpEvent(
                            timestamp: startTime,
                            height: jumpHeight,
                            duration: Date().timeIntervalSince(startTime),
                            landingImpact: abs(changeRate)
                        )
                        detectedJumps.append(jump)
                        jumpCount += 1
                        // Keep last 500 jumps (reasonable max for any session)
                        if detectedJumps.count > 500 {
                            detectedJumps.removeFirst()
                        }
                    }
                }
                isAirborne = false
                preLandingAltitude = nil
                jumpStartTime = nil
            }
        }
    }

    // MARK: - Posture Processing

    private func processPosture(pitch: Double, roll: Double, dt: TimeInterval) {
        posturePitch = pitch
        postureRoll = roll

        // Add to rolling samples
        pitchSamples.append(pitch)
        rollSamples.append(roll)
        if pitchSamples.count > 100 {
            pitchSamples.removeFirst()
            rollSamples.removeFirst()
        }

        // Calculate posture stability (inverse of variance)
        if pitchSamples.count >= 10 {
            let pitchVariance = calculateVariance(pitchSamples.suffix(20))
            let rollVariance = calculateVariance(rollSamples.suffix(20))
            let totalVariance = pitchVariance + rollVariance

            // Convert variance to stability score (0-100)
            // Low variance = high stability
            postureStability = max(0, min(100, 100 - totalVariance * 2))
        }

        // Track good vs poor posture time
        // Good posture: relatively upright, minimal excessive lean
        let isGoodPosture = abs(pitch) < 30 && abs(roll) < 20
        if isGoodPosture {
            goodPostureTime += dt
        } else {
            poorPostureTime += dt
        }
    }

    // MARK: - Compass Processing

    private func processCompass(heading: Double, dt: TimeInterval) {
        let previousHeading = compassHeading
        compassHeading = heading

        // Calculate heading change rate (accounting for wraparound)
        var headingDelta = heading - previousHeading
        if headingDelta > 180 { headingDelta -= 360 }
        if headingDelta < -180 { headingDelta += 360 }

        if dt > 0 {
            headingChangeRate = headingDelta / dt
        }

        // Turn detection
        detectTurn(heading: heading, changeRate: headingChangeRate)

        lastHeading = heading
    }

    private func detectTurn(heading: Double, changeRate: Double) {
        let turnThreshold = 15.0  // degrees/second to consider turning
        let minTurnAngle = 45.0   // minimum total turn to count

        if !isTurning && abs(changeRate) > turnThreshold {
            // Start of turn
            isTurning = true
            turnStartHeading = heading
            turnStartTime = Date()
        } else if isTurning {
            if abs(changeRate) < turnThreshold / 2 {
                // End of turn
                if let startHeading = turnStartHeading, let startTime = turnStartTime {
                    var totalAngle = heading - startHeading
                    if totalAngle > 180 { totalAngle -= 360 }
                    if totalAngle < -180 { totalAngle += 360 }

                    if abs(totalAngle) >= minTurnAngle {
                        let turn = CompassTurn(
                            timestamp: startTime,
                            angle: totalAngle,
                            duration: Date().timeIntervalSince(startTime),
                            direction: totalAngle > 0 ? CompassTurnDirection.right : CompassTurnDirection.left
                        )
                        compassTurns.append(turn)
                        // Keep last 1000 turns (reasonable max for any session)
                        if compassTurns.count > 1000 {
                            compassTurns.removeFirst()
                        }
                    }
                }
                isTurning = false
                turnStartHeading = nil
                turnStartTime = nil
            }
        }
    }

    // MARK: - Fatigue Processing

    private func processFatigue(tremor: Double, breathing: Double, intensity: Double, dt: TimeInterval) {
        tremorLevel = tremor
        breathingRate = breathing
        movementIntensity = intensity

        // Track breathing rate trend
        breathingRateSamples.append(breathing)
        if breathingRateSamples.count > 60 {
            breathingRateSamples.removeFirst()
        }

        if breathingRateSamples.count >= 10 {
            let recentAvg = breathingRateSamples.suffix(10).reduce(0, +) / 10
            let olderAvg = breathingRateSamples.prefix(10).reduce(0, +) / 10
            breathingRateTrend = recentAvg - olderAvg
        }

        // Track intensity samples for average
        intensitySamples.append(intensity)
        if intensitySamples.count > 300 {
            intensitySamples.removeFirst()
        }
        averageIntensity = intensitySamples.reduce(0, +) / Double(max(1, intensitySamples.count))

        // Track active vs passive time
        let activityThreshold = 40.0
        if intensity >= activityThreshold {
            activeTime += dt
        } else {
            passiveTime += dt
        }

        // Calculate fatigue score
        // Components: tremor (40%), breathing rate increase (30%), duration (30%)
        let tremorComponent = tremor * 0.4
        let breathingComponent = max(0, breathingRateTrend) * 3  // Scaled
        let sessionDuration = sessionStartTime.map { Date().timeIntervalSince($0) / 3600 } ?? 0
        let durationComponent = min(30, sessionDuration * 30)  // Max 30 points for 1 hour

        fatigueScore = min(100, tremorComponent + breathingComponent + durationComponent)

        // Record fatigue sample (every ~10 seconds)
        if fatigueTrend.isEmpty || (fatigueTrend.last?.timestamp.timeIntervalSinceNow ?? -20) < -10 {
            fatigueTrend.append(FatigueSample(
                timestamp: Date(),
                fatigue: fatigueScore,
                tremor: tremor,
                breathingRate: breathing
            ))
            // Keep last ~2 hours of fatigue data (720 samples at 10s intervals)
            if fatigueTrend.count > 720 {
                fatigueTrend.removeFirst()
            }
        }
    }

    // MARK: - SpO2 Processing

    private func processSpO2(spo2: Double) {
        guard spo2 > 0 else { return }

        let previousSpO2 = oxygenSaturation
        oxygenSaturation = spo2

        // Track minimum
        if spo2 < minSpO2 && spo2 > 70 {  // Sanity check
            minSpO2 = spo2
        }

        // Calculate trend
        if previousSpO2 > 0 {
            spo2Trend = spo2 - previousSpO2
        }

        // Record sample (every ~30 seconds)
        if spo2Samples.isEmpty || (spo2Samples.last?.timestamp.timeIntervalSinceNow ?? -60) < -30 {
            spo2Samples.append(SpO2Sample(
                timestamp: Date(),
                spo2: spo2
            ))
            // Keep last ~2 hours of SpO2 data (240 samples at 30s intervals)
            if spo2Samples.count > 240 {
                spo2Samples.removeFirst()
            }
        }
    }

    // MARK: - Water Detection Processing

    private func processWaterDetection(submerged: Bool, depth: Double, dt: TimeInterval) {
        let wasSubmerged = isSubmerged
        isSubmerged = submerged
        waterDepth = depth

        if submerged && !wasSubmerged {
            // Just entered water
            submersionStartTime = Date()
            submersionCount += 1
        } else if !submerged && wasSubmerged {
            // Just exited water
            if let startTime = submersionStartTime {
                totalSubmergedTime += Date().timeIntervalSince(startTime)
            }
            submersionStartTime = nil
        } else if submerged {
            // Still submerged - track time
            // (accumulated on exit, but track for real-time display)
        }
    }

    // MARK: - Training Load

    private func updateTrainingLoad(dt: TimeInterval) {
        // Combined training load from multiple factors
        // Heart rate would be added here if available from main tracker

        let intensityLoad = movementIntensity * dt / 60  // Per minute
        let fatigueLoad = fatigueScore * dt / 120

        trainingLoadScore += intensityLoad + fatigueLoad

        // Recovery quality based on SpO2 and breathing
        if oxygenSaturation > 0 {
            // Good recovery: SpO2 > 95%, breathing rate decreasing or stable
            let spo2Factor = max(0, (oxygenSaturation - 90) / 10)  // 0-1 scale
            let breathingFactor = breathingRateTrend <= 0 ? 1.0 : max(0, 1 - breathingRateTrend / 5)
            recoveryQuality = (spo2Factor * 50 + breathingFactor * 50)
        }
    }

    // MARK: - Utility Methods

    private func calculateVariance(_ samples: ArraySlice<Double>) -> Double {
        guard samples.count > 1 else { return 0 }
        let mean = samples.reduce(0, +) / Double(samples.count)
        let squaredDiffs = samples.map { ($0 - mean) * ($0 - mean) }
        return squaredDiffs.reduce(0, +) / Double(samples.count - 1)
    }

    // MARK: - Discipline-Specific Summaries

    /// Get riding-specific metrics summary
    func getRidingSummary() -> RidingSensorSummary {
        RidingSensorSummary(
            jumpCount: jumpCount,
            jumps: detectedJumps,
            totalElevationGain: totalElevationGain,
            totalElevationLoss: totalElevationLoss,
            postureStability: postureStability,
            goodPosturePercent: goodPostureTime > 0 ? (goodPostureTime / (goodPostureTime + poorPostureTime)) * 100 : 100,
            compassTurns: compassTurns,
            fatigueScore: fatigueScore,
            activePercent: activeTime > 0 ? (activeTime / (activeTime + passiveTime)) * 100 : 50
        )
    }

    /// Get running-specific metrics summary
    func getRunningSummary() -> RunningSensorSummary {
        RunningSensorSummary(
            totalElevationGain: totalElevationGain,
            totalElevationLoss: totalElevationLoss,
            averageBreathingRate: breathingRateSamples.isEmpty ? 0 : breathingRateSamples.reduce(0, +) / Double(breathingRateSamples.count),
            breathingRateTrend: breathingRateTrend,
            minSpO2: minSpO2,
            currentSpO2: oxygenSaturation,
            postureStability: postureStability,
            fatigueScore: fatigueScore,
            trainingLoadScore: trainingLoadScore
        )
    }

    /// Get swimming-specific metrics summary
    func getSwimmingSummary() -> SwimmingSensorSummary {
        SwimmingSensorSummary(
            totalSubmergedTime: totalSubmergedTime,
            submersionCount: submersionCount,
            maxDepth: waterDepth,  // Would track max separately if needed
            currentSpO2: oxygenSaturation,
            minSpO2: minSpO2,
            recoveryQuality: recoveryQuality
        )
    }

    /// Get shooting-specific metrics summary
    func getShootingSummary() -> ShootingSensorSummary {
        ShootingSensorSummary(
            tremorLevel: tremorLevel,
            breathingRate: breathingRate,
            posturePitch: posturePitch,
            postureRoll: postureRoll,
            postureStability: postureStability,
            movementIntensity: movementIntensity,
            stillnessScore: max(0, 100 - movementIntensity)
        )
    }

    /// Get cross-discipline training load summary
    func getTrainingLoadSummary() -> TrainingLoadSummary {
        TrainingLoadSummary(
            totalLoad: trainingLoadScore,
            fatigueScore: fatigueScore,
            recoveryQuality: recoveryQuality,
            averageIntensity: averageIntensity,
            breathingRateTrend: breathingRateTrend,
            spo2Trend: spo2Trend
        )
    }
}

// MARK: - Data Types

struct AltitudeSample {
    let timestamp: Date
    let altitude: Double
    let pressure: Double
}

struct JumpEvent {
    let timestamp: Date
    let height: Double  // meters
    let duration: TimeInterval
    let landingImpact: Double  // acceleration magnitude
}

enum CompassTurnDirection {
    case left, right
}

struct CompassTurn {
    let timestamp: Date
    let angle: Double  // degrees (negative = left, positive = right)
    let duration: TimeInterval
    let direction: CompassTurnDirection
}

struct FatigueSample {
    let timestamp: Date
    let fatigue: Double
    let tremor: Double
    let breathingRate: Double
}

struct SpO2Sample {
    let timestamp: Date
    let spo2: Double
}

// MARK: - Discipline Summaries

struct RidingSensorSummary {
    let jumpCount: Int
    let jumps: [JumpEvent]
    let totalElevationGain: Double
    let totalElevationLoss: Double
    let postureStability: Double
    let goodPosturePercent: Double
    let compassTurns: [CompassTurn]
    let fatigueScore: Double
    let activePercent: Double
}

struct RunningSensorSummary {
    let totalElevationGain: Double
    let totalElevationLoss: Double
    let averageBreathingRate: Double
    let breathingRateTrend: Double
    let minSpO2: Double
    let currentSpO2: Double
    let postureStability: Double
    let fatigueScore: Double
    let trainingLoadScore: Double
}

struct SwimmingSensorSummary {
    let totalSubmergedTime: TimeInterval
    let submersionCount: Int
    let maxDepth: Double
    let currentSpO2: Double
    let minSpO2: Double
    let recoveryQuality: Double
}

struct ShootingSensorSummary {
    let tremorLevel: Double
    let breathingRate: Double
    let posturePitch: Double
    let postureRoll: Double
    let postureStability: Double
    let movementIntensity: Double
    let stillnessScore: Double
}

struct TrainingLoadSummary {
    let totalLoad: Double
    let fatigueScore: Double
    let recoveryQuality: Double
    let averageIntensity: Double
    let breathingRateTrend: Double
    let spo2Trend: Double
}
