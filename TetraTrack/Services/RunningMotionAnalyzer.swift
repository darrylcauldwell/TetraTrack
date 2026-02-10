//
//  RunningMotionAnalyzer.swift
//  TetraTrack
//
//  iPhone IMU-based running form analysis for REAL-TIME feedback.
//  Processes accelerometer + gyroscope data at 100Hz to derive:
//  - Cadence (real-time, FFT-based)
//  - Phase classification (walking/jogging/running/sprinting)
//  - Impact loading (foot strike g-force)
//  - Step counting

import Foundation
import CoreMotion
import Observation
import os

@Observable
final class RunningMotionAnalyzer {

    // MARK: - Public Outputs

    /// Detected cadence from phone IMU (steps per minute)
    var phoneCadence: Int = 0

    /// Current impact load at foot strike (g-force)
    var currentImpactLoad: Double = 0

    /// Session average impact load
    var averageImpactLoad: Double = 0

    /// Impact load trend (% change from first quarter to current)
    var impactLoadTrend: Double = 0

    /// Current running phase
    var currentPhase: RunningPhase = .walking

    /// Whether analysis is active
    var isAnalyzing: Bool = false

    /// Stride frequency (Hz) from FFT
    var strideFrequency: Double = 0

    // MARK: - Phone Placement

    private var placement: RunningPhonePlacement = .shortsThigh

    // MARK: - Session Data Collection

    /// Phase breakdown for session persistence
    private(set) var phaseBreakdown = RunningPhaseBreakdown()

    // MARK: - DSP Components

    // Fix 5: Zero-padded FFT — 512-point FFT with 256 real samples zero-padded to 512
    // Doubles frequency resolution to ~0.195 Hz (~23 spm) without extra data or latency
    private let fftProcessor = FFTProcessor(windowSize: 512, sampleRate: 100)

    // MARK: - Sensor Buffers (256 samples = 2.56s at 100Hz)

    private var verticalBuffer: [Double] = []
    private var lateralBuffer: [Double] = []
    private var forwardBuffer: [Double] = []
    private let bufferSize = 256

    // MARK: - Foot Strike Detection

    /// Recent impact loads for trend calculation
    private var firstQuarterImpactLoads: [Double] = []
    private var recentImpactLoads: [Double] = []
    private let impactLoadWindow = 50

    // MARK: - Stride Cycle Detection

    private var lastStrikeTime: Date?
    private var strideDurations: [TimeInterval] = []
    private let strideDurationWindow = 10
    private var minStepInterval: TimeInterval = 0.2  // 300 spm max

    // MARK: - Step Counting

    // Fix 1: Actual step counting — incremented per detected foot strike
    private var totalStepCount: Int = 0

    // MARK: - Cadence Tracking

    // Fix 2: Track true average and max cadence across the session
    private var cadenceSum: Double = 0
    private var cadenceCount: Int = 0
    private var maxCadenceObserved: Int = 0

    // MARK: - Adaptive Impact Threshold

    // Fix 4: Adaptive impact threshold from baseline acceleration peaks
    private var baselinePeaks: [Double] = []
    private var adaptiveThreshold: Double?
    private let peakCollectionFloor: Double = 0.5

    // MARK: - Session Impact Tracking

    // Fix 7: True session-wide impact average (not windowed)
    private var sessionImpactSum: Double = 0
    private var sessionImpactCount: Int = 0
    private var sessionPeakImpact: Double = 0

    // MARK: - Competition Level

    // Fix 8: Competition-level-aware phase thresholds
    private var competitionLevel: CompetitionLevel?

    // MARK: - Impact Load Baseline

    private var baselineCadences: [Int] = []
    private var baselineImpactLoads: [Double] = []
    private var isBaselinePhase: Bool = true

    // Fix 6: Activity-based baseline — require actual running data, not just elapsed time
    private let baselineMaxDuration: TimeInterval = 180
    private let baselineMinDuration: TimeInterval = 60
    private let baselineMinCadenceReadings: Int = 20
    private let baselineMinCadence: Int = 100
    private var baselineActiveCadenceCount: Int = 0

    // MARK: - Phase Detection

    private var lastPhaseChangeTime: Date?
    private let phaseChangeDebounce: TimeInterval = 10.0
    private var consecutivePhaseReadings: Int = 0
    private var pendingPhase: RunningPhase?
    private let phaseConfirmationCount: Int = 3  // Need 3 consecutive readings to confirm

    // MARK: - FFT Timing

    private var lastFFTTime: Date = .distantPast
    private let fftUpdateInterval: TimeInterval = 0.5  // 2 Hz update

    // MARK: - GPS Speed (optional, for power & phase confirmation)

    private var lastGPSSpeed: Double = 0
    private var gpsSpeedBuffer: [Double] = []
    private let gpsSpeedBufferSize: Int = 5  // Smooth over 5 readings

    // MARK: - Session Timing

    private var sessionStartTime: Date?
    private var lastSampleTime: Date?
    private var lastPhase: RunningPhase = .walking

    // MARK: - Smoothing

    private var smoothedCadence: Double = 0
    private var smoothedImpactLoad: Double = 0
    private let smoothingAlpha: Double = 0.3

    // MARK: - Per-Kilometre Tracking

    private var lastAnnouncedKm: Int = 0
    private var lastKnownDistance: Double = 0

    // MARK: - Form Alert State

    /// Callback for form degradation alerts
    var onFormAlert: ((RunningFormAlert) -> Void)?

    /// Callback for per-kilometre summaries
    var onKilometreSummary: ((Int, Int) -> Void)?  // (km, cadence)

    private var lastAlertTime: Date = .distantPast
    private let alertCooldown: TimeInterval = 120  // 2 minutes between alerts

    // MARK: - Lifecycle

    // Fix 8: Added optional competitionLevel parameter (default nil for backward compatibility)
    func startAnalyzing(placement: RunningPhonePlacement = .shortsThigh, competitionLevel: CompetitionLevel? = nil) {
        guard !isAnalyzing else { return }

        self.placement = placement
        self.competitionLevel = competitionLevel
        isAnalyzing = true
        sessionStartTime = Date()
        lastPhaseChangeTime = Date()
        isBaselinePhase = true

        clearBuffers()
        resetMetrics()

        Log.tracking.info("RunningMotionAnalyzer started")
    }

    func stopAnalyzing() {
        guard isAnalyzing else { return }

        isAnalyzing = false

        Log.tracking.info("RunningMotionAnalyzer stopped - \(self.totalStepCount) steps")
    }

    func reset() {
        isAnalyzing = false
        placement = .shortsThigh
        competitionLevel = nil
        clearBuffers()
        resetMetrics()
        phaseBreakdown = RunningPhaseBreakdown()
        totalStepCount = 0
        sessionStartTime = nil
    }

    // MARK: - Process Motion Sample

    /// Process a motion sample from MotionManager (called at 100Hz)
    func processMotionSample(_ sample: MotionSample) {
        guard isAnalyzing else { return }

        let now = sample.timestamp

        // Buffer vertical, lateral, forward acceleration
        verticalBuffer.append(sample.verticalAcceleration)
        lateralBuffer.append(sample.lateralAcceleration)
        forwardBuffer.append(sample.forwardAcceleration)

        if verticalBuffer.count > bufferSize {
            verticalBuffer.removeFirst()
            lateralBuffer.removeFirst()
            forwardBuffer.removeFirst()
        }

        // Foot strike detection using acceleration magnitude (Fix 9)
        detectFootStrike(sample: sample, timestamp: now)

        // Track time spent in each running phase
        if let prevTime = lastSampleTime {
            let dt = now.timeIntervalSince(prevTime)
            if dt > 0 && dt < 1.0 {
                phaseBreakdown.addTime(dt, for: currentPhase)
            }
        }

        lastSampleTime = now

        // Fix 6: Activity-based baseline — require both time AND active running data
        if isBaselinePhase, let start = sessionStartTime {
            let elapsed = now.timeIntervalSince(start)
            let hasEnoughActivity = baselineActiveCadenceCount >= baselineMinCadenceReadings
            let pastMinDuration = elapsed >= baselineMinDuration
            let pastMaxDuration = elapsed >= baselineMaxDuration

            if (pastMinDuration && hasEnoughActivity) || pastMaxDuration {
                // Fix 4: Compute adaptive threshold from baseline peaks
                if !baselinePeaks.isEmpty {
                    let sorted = baselinePeaks.sorted()
                    let p25Index = sorted.count / 4
                    let p25 = sorted[p25Index]
                    adaptiveThreshold = max(p25, placement.impactThreshold * 0.5)
                }
                isBaselinePhase = false
            }
        }

        // Periodic FFT analysis
        if now.timeIntervalSince(lastFFTTime) >= fftUpdateInterval {
            performSpectralAnalysis()
            lastFFTTime = now

            // Check for form alerts (impact load, cadence)
            checkFormAlerts()
        }
    }

    /// Update GPS speed for power calculation and phase confirmation
    func updateGPSSpeed(_ speedMS: Double) {
        let clamped = max(0, speedMS)
        gpsSpeedBuffer.append(clamped)
        if gpsSpeedBuffer.count > gpsSpeedBufferSize {
            gpsSpeedBuffer.removeFirst()
        }
        // Use smoothed average to reduce noise-driven phase transitions
        lastGPSSpeed = gpsSpeedBuffer.reduce(0, +) / Double(gpsSpeedBuffer.count)
    }

    /// Update current distance for per-kilometre announcements
    func updateDistance(_ distanceMeters: Double) {
        lastKnownDistance = distanceMeters
        let currentKm = Int(distanceMeters / 1000)
        if currentKm > lastAnnouncedKm && currentKm > 0 {
            lastAnnouncedKm = currentKm
            onKilometreSummary?(currentKm, phoneCadence)
        }
    }

    // MARK: - Spectral Analysis

    private func performSpectralAnalysis() {
        guard verticalBuffer.count >= bufferSize else { return }

        // Fix 5: Zero-pad 256 real samples to 512 for better frequency resolution
        let realSamples = Array(verticalBuffer.suffix(bufferSize))
        let zeroPadded = realSamples + [Double](repeating: 0, count: 512 - bufferSize)

        _ = fftProcessor.processWindow(zeroPadded)

        // Extract stride frequency in human running range (1.0-4.0 Hz)
        let (freq, _) = fftProcessor.findDominantFrequency(inRange: 1.0...4.0)

        if freq > 0 {
            strideFrequency = freq

            // Fix 3: Harmonic-aware cadence — check if dominant peak is stride or step frequency
            let h2Ratio = fftProcessor.computeHarmonicRatio(fundamental: freq, harmonic: 2)
            let cadenceMultiplier: Double
            if h2Ratio > 0.3 {
                // Strong harmonic at 2x → fundamental is stride frequency, multiply by 2
                cadenceMultiplier = 2.0
            } else {
                // No strong harmonic → peak is already step frequency
                cadenceMultiplier = 1.0
            }

            let rawCadence = freq * 60.0 * cadenceMultiplier
            smoothedCadence = smoothedCadence == 0 ? rawCadence : smoothedCadence * (1 - smoothingAlpha) + rawCadence * smoothingAlpha
            phoneCadence = Int(smoothedCadence.rounded())

            // Fix 2: Accumulate cadence for true session average/max
            if phoneCadence > 0 {
                cadenceSum += smoothedCadence
                cadenceCount += 1
                if phoneCadence > maxCadenceObserved {
                    maxCadenceObserved = phoneCadence
                }
            }
        }

        // Collect baseline data
        if isBaselinePhase && phoneCadence > 0 {
            baselineCadences.append(phoneCadence)
            // Fix 6: Track active cadence readings for activity-based baseline
            if phoneCadence >= baselineMinCadence {
                baselineActiveCadenceCount += 1
            }
        }

        classifyPhase()
    }

    // MARK: - Foot Strike Detection

    private func detectFootStrike(sample: MotionSample, timestamp: Date) {
        // Fix 9: Use acceleration magnitude instead of vertical-only
        // This is orientation-invariant — works regardless of phone tilt in pocket
        let accelMag = sample.accelerationMagnitude

        // Fix 4: Use adaptive threshold if available, otherwise fall back to placement default
        let strikeThreshold: Double = adaptiveThreshold ?? placement.impactThreshold
        guard accelMag > strikeThreshold else {
            // Fix 4: Collect peaks during baseline for adaptive threshold calculation
            if isBaselinePhase && accelMag > peakCollectionFloor {
                baselinePeaks.append(accelMag)
            }
            return
        }

        // Fix 4: Also collect peaks that exceed threshold during baseline
        if isBaselinePhase {
            baselinePeaks.append(accelMag)
        }

        // Debounce: minimum time between strikes
        if let lastStrike = lastStrikeTime {
            let interval = timestamp.timeIntervalSince(lastStrike)
            guard interval > minStepInterval else { return }

            // Record stride duration
            strideDurations.append(interval)
            if strideDurations.count > strideDurationWindow {
                strideDurations.removeFirst()
            }
        }

        lastStrikeTime = timestamp

        // Fix 1: Increment actual step count per detected foot strike
        totalStepCount += 1

        // Impact load tracking - this is unique to phone IMU (not in HealthKit)
        // Fix 9: Use magnitude for impact load value
        let impactG = accelMag
        smoothedImpactLoad = smoothedImpactLoad == 0 ? impactG : smoothedImpactLoad * (1 - smoothingAlpha) + impactG * smoothingAlpha
        currentImpactLoad = smoothedImpactLoad

        // Fix 7: Accumulate session-wide impact stats
        sessionImpactSum += impactG
        sessionImpactCount += 1
        if impactG > sessionPeakImpact {
            sessionPeakImpact = impactG
        }

        // Fix 7: Compute true session average (not windowed)
        averageImpactLoad = sessionImpactSum / Double(sessionImpactCount)

        recentImpactLoads.append(impactG)
        if recentImpactLoads.count > impactLoadWindow {
            recentImpactLoads.removeFirst()
        }

        // Track first quarter for trend
        if isBaselinePhase {
            firstQuarterImpactLoads.append(impactG)
            baselineImpactLoads.append(impactG)
        }

        // Compute impact load trend
        if !firstQuarterImpactLoads.isEmpty && recentImpactLoads.count >= 10 {
            let firstAvg = firstQuarterImpactLoads.reduce(0, +) / Double(firstQuarterImpactLoads.count)
            let recentAvg = recentImpactLoads.reduce(0, +) / Double(recentImpactLoads.count)
            if firstAvg > 0 {
                impactLoadTrend = ((recentAvg - firstAvg) / firstAvg) * 100
            }
        }
    }

    // MARK: - Phase Classification

    private func classifyPhase() {
        let now = Date()

        // Debounce phase changes — minimum 10 seconds between transitions
        if let lastChange = lastPhaseChangeTime,
           now.timeIntervalSince(lastChange) < phaseChangeDebounce {
            return
        }

        var newPhase: RunningPhase

        if lastGPSSpeed > 0 {
            // GPS is authoritative for outdoor runs — direct measure of pace
            newPhase = classifyGPSPhase(speed: lastGPSSpeed)
        } else if strideFrequency > 0 {
            // IMU fallback only when GPS unavailable (e.g. treadmill)
            // Fix 8: Scale IMU thresholds by competition level
            let scale = speedScaleFactor
            if strideFrequency < 1.2 * scale {
                newPhase = .walking
            } else if strideFrequency < 1.5 * scale {
                newPhase = .jogging
            } else if strideFrequency < 1.8 * scale {
                newPhase = .running
            } else {
                newPhase = .sprinting
            }
        } else {
            return
        }

        if newPhase != currentPhase {
            // Require consecutive consistent readings before committing to a transition
            if newPhase == pendingPhase {
                consecutivePhaseReadings += 1
            } else {
                pendingPhase = newPhase
                consecutivePhaseReadings = 1
            }

            // Only transition after enough consecutive confirmations
            if consecutivePhaseReadings >= phaseConfirmationCount {
                lastPhase = currentPhase
                currentPhase = newPhase
                lastPhaseChangeTime = now
                pendingPhase = nil
                consecutivePhaseReadings = 0

                // Announce phase transition
                onFormAlert?(.phaseTransition(from: lastPhase, to: newPhase))
            }
        } else {
            // Readings match current phase — reset any pending transition
            pendingPhase = nil
            consecutivePhaseReadings = 0
        }
    }

    /// GPS speed classification with hysteresis to prevent threshold bouncing.
    /// When moving UP a level, require exceeding the threshold by a margin.
    /// When moving DOWN, require dropping below by a margin.
    private func classifyGPSPhase(speed: Double) -> RunningPhase {
        let currentOrder = RunningPhase.allCases.firstIndex(of: currentPhase) ?? 0

        // Fix 8: Scale thresholds and hysteresis by competition level
        let scale = speedScaleFactor
        let hysteresis: Double = 0.4 * scale

        let walkJogThreshold = 1.5 * scale
        let jogRunThreshold = 2.8 * scale
        let runSprintThreshold = 4.5 * scale

        if currentOrder <= 0 {
            // Currently walking — need to clearly exceed walk/jog threshold to move up
            if speed >= walkJogThreshold + hysteresis { return .jogging }
            return .walking
        } else if currentOrder == 1 {
            // Currently jogging
            if speed < walkJogThreshold - hysteresis { return .walking }
            if speed >= jogRunThreshold + hysteresis { return .running }
            return .jogging
        } else if currentOrder == 2 {
            // Currently running
            if speed < jogRunThreshold - hysteresis { return .jogging }
            if speed >= runSprintThreshold + hysteresis { return .sprinting }
            return .running
        } else {
            // Currently sprinting
            if speed < runSprintThreshold - hysteresis { return .running }
            return .sprinting
        }
    }

    // Fix 8: Speed scale factor based on competition level
    private var speedScaleFactor: Double {
        guard let level = competitionLevel else { return 1.0 }
        switch level {
        case .minimus:
            return 0.65
        case .junior:
            return 0.80
        case .intermediateGirls:
            return 0.90
        case .intermediateBoys:
            return 0.95
        case .openGirls:
            return 0.90
        case .openBoys:
            return 1.0
        }
    }

    // MARK: - Form Alerts

    private func checkFormAlerts() {
        guard !isBaselinePhase else { return }

        let now = Date()
        guard now.timeIntervalSince(lastAlertTime) >= alertCooldown else { return }

        // Check impact loading increase - unique metric from phone IMU
        if impactLoadTrend > 25 {
            onFormAlert?(.heavierLandings(trend: impactLoadTrend))
            lastAlertTime = now
            return
        }

        // Check cadence drop
        if !baselineCadences.isEmpty && phoneCadence > 0 {
            let baselineAvg = Double(baselineCadences.reduce(0, +)) / Double(baselineCadences.count)
            if baselineAvg > 0 && Double(phoneCadence) < baselineAvg * 0.9 {
                onFormAlert?(.cadenceDropped(current: phoneCadence, baseline: Int(baselineAvg)))
                lastAlertTime = now
                return
            }
        }
    }

    // MARK: - Session Summary

    /// Get session summary metrics for persistence
    func getSessionSummary() -> RunningMotionSummary {
        // Fix 2: Use tracked average and max cadence instead of instantaneous value
        let avgCadence = cadenceCount > 0 ? Int((cadenceSum / Double(cadenceCount)).rounded()) : phoneCadence
        let maxCadence = maxCadenceObserved > 0 ? maxCadenceObserved : phoneCadence

        return RunningMotionSummary(
            phoneAverageCadence: avgCadence,
            phoneMaxCadence: maxCadence,
            averageImpactLoad: averageImpactLoad,
            // Fix 7: Use session peak impact instead of windowed max
            peakImpactLoad: sessionPeakImpact,
            impactLoadTrend: impactLoadTrend,
            totalStepCount: totalStepCount,
            phaseBreakdown: phaseBreakdown
        )
    }

    // MARK: - Private Helpers

    private func clearBuffers() {
        verticalBuffer.removeAll()
        lateralBuffer.removeAll()
        forwardBuffer.removeAll()
        strideDurations.removeAll()
        firstQuarterImpactLoads.removeAll()
        recentImpactLoads.removeAll()
        baselineCadences.removeAll()
        baselineImpactLoads.removeAll()
        baselinePeaks.removeAll()
        lastFFTTime = .distantPast
        lastAlertTime = .distantPast
        lastStrikeTime = nil
        lastSampleTime = nil
        lastAnnouncedKm = 0
        lastKnownDistance = 0
    }

    private func resetMetrics() {
        phoneCadence = 0
        currentImpactLoad = 0
        averageImpactLoad = 0
        impactLoadTrend = 0
        currentPhase = .walking
        strideFrequency = 0
        smoothedCadence = 0
        smoothedImpactLoad = 0
        isBaselinePhase = true
        lastPhase = .walking
        cadenceSum = 0
        cadenceCount = 0
        maxCadenceObserved = 0
        adaptiveThreshold = nil
        sessionImpactSum = 0
        sessionImpactCount = 0
        sessionPeakImpact = 0
        baselineActiveCadenceCount = 0
    }
}

// MARK: - Running Motion Summary

/// Summary of phone IMU metrics for session persistence
///
/// Phone-unique metrics (not in HealthKit):
/// - Impact load (foot strike g-force)
/// - Phase breakdown
///
/// Phone estimates (HealthKit overrides post-session if Apple Watch used):
/// - Cadence, step count
struct RunningMotionSummary {
    let phoneAverageCadence: Int
    let phoneMaxCadence: Int
    let averageImpactLoad: Double
    let peakImpactLoad: Double
    let impactLoadTrend: Double
    let totalStepCount: Int
    let phaseBreakdown: RunningPhaseBreakdown
}

// MARK: - Running Form Alert

/// Form alerts for real-time coaching feedback
enum RunningFormAlert {
    case heavierLandings(trend: Double)
    case cadenceDropped(current: Int, baseline: Int)
    case phaseTransition(from: RunningPhase, to: RunningPhase)

    var message: String {
        switch self {
        case .heavierLandings(let trend):
            return "Your landings are getting heavier, up \(Int(trend))%. Focus on soft foot strikes."
        case .cadenceDropped(let current, let baseline):
            return "Your cadence has dropped to \(current) from \(baseline). Try to pick up your step rate."
        case .phaseTransition(_, let to):
            return "Now \(to.rawValue.lowercased())."
        }
    }
}
