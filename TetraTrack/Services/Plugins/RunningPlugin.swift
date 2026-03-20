//
//  RunningPlugin.swift
//  TetraTrack
//
//  Running-specific discipline plugin. Manages cadence/form tracking,
//  km split announcements, interval workouts, PB coaching, virtual pacer,
//  track mode lap detection, and running HealthKit metrics.

import CoreLocation
import HealthKit
import SwiftData
import Observation
import UIKit
import os

@Observable
@MainActor
final class RunningPlugin: DisciplinePlugin {
    // MARK: - Identity

    let subscriberId = "running"
    let activityType: GPSActivityType = .running
    let watchDiscipline: WatchSessionDiscipline = .running
    let sharingActivityType = "running"

    // MARK: - Feature Flags

    var usesGPS: Bool {
        session.runMode == .outdoor || session.runMode == .track
    }

    let usesFallDetection = false

    var usesVehicleDetection: Bool {
        session.runMode == .outdoor || session.runMode == .track
    }

    // MARK: - HealthKit

    var workoutConfiguration: HKWorkoutConfiguration {
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = usesGPS ? .outdoor : .indoor
        return config
    }

    // MARK: - Interval Workout Phase

    enum IntervalWorkoutPhase {
        case warmup, work, rest, cooldown, finished
    }

    // MARK: - Observable Properties

    /// Current cadence from Watch (steps per minute)
    var currentCadence: Int = 0

    /// All cadence readings collected during session
    var cadenceReadings: [Int] = []

    /// Vertical oscillation from Watch (cm)
    var verticalOscillation: Double = 0.0

    /// Ground contact time from Watch (ms)
    var groundContactTime: Double = 0.0

    /// Oscillation readings for session averages
    var oscillationReadings: [Double] = []

    /// Ground contact time readings for session averages
    var gctReadings: [Double] = []

    /// Timestamped running form samples
    var formSamples: [RunningFormSample] = []

    /// Interval tracking
    var intervalCount: Int = 1
    var isWorkPhase: Bool = true
    var phaseTime: TimeInterval = 0
    var workoutPhase: IntervalWorkoutPhase = .warmup
    var phaseTransitions: [(phase: IntervalWorkoutPhase, start: Date)] = []

    /// Coaching data collection
    var coachingData = RunningCoachingSummary()

    /// Weather tracking
    var currentWeather: WeatherConditions?

    /// Recovery tracking
    var isRecoveryPhase = false

    // MARK: - Private State

    /// Km split tracking
    private var lastAnnouncedKm: Int = 0
    private var lastKmSplitTime: TimeInterval = 0

    /// PB coaching (time trials)
    private var lastAnnouncedCheckpointIndex: Int = -1
    private var lastPBEncouragementPercent: Int = 0

    /// Virtual pacer audio tracking
    private var lastPacerAnnouncementTime: TimeInterval = 0

    /// Interval countdown tracking
    private var lastAnnouncedCountdown: Int = Int.max

    /// Program interval tracking
    private var programAudioCoach = ProgramAudioCoach()
    private var lastProgramPhaseIndex: Int = -1
    private var lastProgramCountdown: Int = Int.max

    /// Live asymmetry check (every 5 min)
    private var lastSymmetryCheckMark: Int = 0

    /// Form degradation detection
    private var lastDegradationCheckCount: Int = 0
    private var lastDegradationAlertTime: Date = .distantPast

    /// HealthKit fetch task from onSessionStopping (awaited in onSessionCompleted)
    private var healthKitFetchTask: Task<Void, Never>?

    /// Model context reference for persistence
    private var modelContext: ModelContext?

    /// The session model
    private(set) var session: RunningSession

    /// Interval settings (optional)
    let intervalSettings: IntervalSettings?

    /// Program intervals (optional)
    let programIntervals: [ProgramInterval]?

    /// Target distance for time trials / goal runs
    let targetDistance: Double

    /// Target cadence for audio feedback
    let targetCadence: Int

    // MARK: - Services

    private let audioCoach = AudioCoachManager.shared
    private let watchManager = WatchConnectivityManager.shared
    private let sensorAnalyzer = WatchSensorAnalyzer.shared
    private let personalBests = RunningPersonalBests.shared
    private let lapDetector = LapDetector.shared
    private let virtualPacer = VirtualPacer.shared

    // MARK: - Tetrathlon Scoring

    @ObservationIgnored
    private lazy var selectedLevel: CompetitionLevel = {
        let raw = UserDefaults.standard.string(forKey: "selectedCompetitionLevel") ?? "Junior"
        return CompetitionLevel(rawValue: raw) ?? .junior
    }()

    private var standardTime: TimeInterval {
        PonyClubScoringService.getRunStandardTime(
            for: selectedLevel.scoringCategory,
            gender: selectedLevel.scoringGender
        )
    }

    // MARK: - Init

    init(
        session: RunningSession,
        intervalSettings: IntervalSettings? = nil,
        programIntervals: [ProgramInterval]? = nil,
        targetDistance: Double = 0,
        targetCadence: Int = 0
    ) {
        self.session = session
        self.intervalSettings = intervalSettings
        self.programIntervals = programIntervals
        self.targetDistance = targetDistance
        self.targetCadence = targetCadence
    }

    // MARK: - DisciplinePlugin Protocol

    func createSessionModel(in context: ModelContext) -> any SessionWritable {
        modelContext = context
        session.startDate = Date()
        return session
    }

    func createLocationPoint(from location: CLLocation) -> (any PersistentModel)? {
        // Treadmill and indoor modes do not record GPS points
        guard usesGPS else { return nil }
        let point = RunningLocationPoint(from: location)
        point.session = session
        return point
    }

    // MARK: - Voice Notes

    func appendVoiceNote(_ note: String) {
        session.notes = VoiceNotesService.shared.appendNote(note, to: session.notes)
    }

    func onSessionStarted(tracker: SessionTracker) async {
        // Start Watch sensor session
        sensorAnalyzer.startSession(discipline: .running)

        // Reset all state
        currentCadence = 0
        cadenceReadings = []
        verticalOscillation = 0
        groundContactTime = 0
        oscillationReadings = []
        gctReadings = []
        formSamples = []
        lastAnnouncedKm = 0
        lastKmSplitTime = 0
        lastAnnouncedCheckpointIndex = -1
        lastPBEncouragementPercent = 0
        lastPacerAnnouncementTime = 0
        lastAnnouncedCountdown = Int.max
        lastProgramPhaseIndex = -1
        lastProgramCountdown = Int.max
        lastSymmetryCheckMark = 0
        lastDegradationCheckCount = 0
        lastDegradationAlertTime = .distantPast
        intervalCount = 1
        isWorkPhase = true
        phaseTime = 0
        isRecoveryPhase = false
        coachingData = RunningCoachingSummary()
        programAudioCoach = ProgramAudioCoach()

        // Configure LapDetector for track mode
        if session.runMode == .track {
            lapDetector.configure(trackLength: session.trackLength)
            lapDetector.onLapCompleted = { [weak self] lapNumber, lapTime in
                guard let self else { return }
                // Persist lap as RunningSplit
                let split = RunningSplit(orderIndex: lapNumber - 1, distance: session.trackLength)
                split.duration = lapTime
                let hrNow = tracker.currentHeartRate
                if hrNow > 0 { split.heartRate = hrNow }
                if currentCadence > 0 { split.cadence = currentCadence }
                split.session = session
                if session.splits == nil { session.splits = [] }
                session.splits?.append(split)
                if let ctx = modelContext {
                    ctx.insert(split)
                }

                // Haptic feedback
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                watchManager.sendCommand(.hapticMilestone)

                // Audio coaching
                if audioCoach.announceRunningLaps {
                    let previousLapTime: TimeInterval? = lapDetector.lapTimes.count >= 2
                        ? lapDetector.lapTimes[lapDetector.lapTimes.count - 2] : nil
                    let isFastest = lapDetector.lapTimes.count > 1 && lapTime == lapDetector.fastestLap
                    audioCoach.announceLapWithComparison(
                        lapNumber, lapTime: lapTime,
                        previousLapTime: previousLapTime, isFastest: isFastest
                    )
                }
            }
            audioCoach.announceTrackModeStart()
        }

        // Initialize interval phase tracking
        if let settings = intervalSettings {
            let initialPhase: IntervalWorkoutPhase = settings.includeWarmup ? .warmup : .work
            workoutPhase = initialPhase
            phaseTransitions = [(phase: initialPhase, start: Date())]
        }

        // Tetrathlon practice coaching: announce race start for time trials
        if session.sessionType == .timeTrial && targetDistance > 0 && audioCoach.announcePBRaceCoaching {
            let pbTime = personalBests.personalBest(for: targetDistance)
            audioCoach.announceTetrathlonPracticeStart(
                pbTime: pbTime,
                standardTime: standardTime,
                distance: targetDistance,
                category: selectedLevel.displayName
            )
        }

        // Virtual pacer: announce pacer start
        if virtualPacer.isActive && audioCoach.announceVirtualPacer {
            audioCoach.announceVirtualPacerStart(targetPace: virtualPacer.targetPace)
        }

        // Initialize coaching data collection
        coachingData.coachingLevelRaw = audioCoach.runningCoachingLevel.rawValue
        audioCoach.resetSessionAnnouncementCount()

        // Set weather from tracker
        currentWeather = tracker.currentWeather
        tracker.currentWeather.map { session.startWeather = $0 }

        // Start running form reminders
        audioCoach.startRunningFormReminders()

        let mode = session.runMode.rawValue
        Log.tracking.info("Running plugin started (mode: \(mode))")
    }

    func onLocationProcessed(_ location: CLLocation, distanceDelta: Double, tracker: SessionTracker) {
        guard tracker.sessionState == .tracking else { return }

        // Sync elevation to session
        session.totalAscent = tracker.elevationGain
        session.totalDescent = tracker.elevationLoss

        let isTrackMode = session.runMode == .track

        // Outdoor run (non-track): km split detection
        if !isTrackMode {
            let currentKm = Int(tracker.totalDistance / 1000)
            if currentKm > lastAnnouncedKm && currentKm > 0 {
                let splitDuration = tracker.elapsedTime - lastKmSplitTime
                lastAnnouncedKm = currentKm
                lastKmSplitTime = tracker.elapsedTime

                // Create split model
                let split = RunningSplit(orderIndex: currentKm - 1, distance: 1000)
                split.duration = splitDuration
                if tracker.currentHeartRate > 0 { split.heartRate = tracker.currentHeartRate }
                if currentCadence > 0 { split.cadence = currentCadence }
                split.session = session
                if session.splits == nil { session.splits = [] }
                session.splits?.append(split)

                if let ctx = modelContext {
                    ctx.insert(split)
                }

                if audioCoach.announceRunningPace {
                    let remaining = targetDistance > 0
                        ? targetDistance - tracker.totalDistance : nil
                    audioCoach.announceKmSplit(
                        km: currentKm,
                        averagePace: splitDuration,
                        gapMeters: nil,
                        remaining: remaining
                    )
                }

                UIImpactFeedbackGenerator(style: .medium).impactOccurred()

                Log.tracking.info("Running km split \(currentKm): \(Int(splitDuration))s")
            }
        }

        // Update virtual pacer with current distance
        if virtualPacer.isActive {
            virtualPacer.update(distance: tracker.totalDistance, elapsedTime: tracker.elapsedTime)
        }

        // Track mode: auto-detect laps via LapDetector
        if isTrackMode {
            lapDetector.processLocation(location, elapsedTime: tracker.elapsedTime)
        }
    }

    func onTimerTick(elapsedTime: TimeInterval, tracker: SessionTracker) {
        // Read cadence/form data from Watch
        if watchManager.currentMotionMode == .running {
            var sampleCadence: Int = 0
            var sampleOsc: Double = 0
            var sampleGCT: Double = 0

            let osc = watchManager.verticalOscillation
            if osc > 0 {
                verticalOscillation = osc
                oscillationReadings.append(osc)
                sampleOsc = osc
            }
            let gctVal = watchManager.groundContactTime
            if gctVal > 0 {
                groundContactTime = gctVal
                gctReadings.append(gctVal)
                sampleGCT = gctVal
            }
            let watchCadVal = watchManager.cadence
            let phoneCadVal = tracker.pedometerCadence
            let cadVal = watchCadVal > 0 ? watchCadVal : phoneCadVal
            // Filter sub-40 spm readings — CMPedometer reports low values during warmup
            if cadVal >= 40 {
                currentCadence = cadVal
                cadenceReadings.append(cadVal)
                sampleCadence = cadVal
            }

            // Record timestamped form sample
            if sampleCadence > 0 || sampleOsc > 0 || sampleGCT > 0 {
                formSamples.append(RunningFormSample(
                    timestamp: Date(),
                    cadence: sampleCadence,
                    oscillation: sampleOsc,
                    groundContactTime: sampleGCT
                ))
            }

            // Process cadence/biomechanics audio feedback
            if sampleCadence > 0 && audioCoach.announceCadenceFeedback {
                audioCoach.processCadence(sampleCadence, target: targetCadence)
            }
            if sampleGCT > 0 && audioCoach.announceRunningBiomechanics {
                audioCoach.processGroundContactTime(sampleGCT)
            }
            if sampleOsc > 0 && audioCoach.announceRunningBiomechanics {
                audioCoach.processVerticalOscillation(sampleOsc)
            }
            let stability = sensorAnalyzer.postureStability
            if stability > 0 {
                audioCoach.processRunningStability(stability)
            }

            // Form degradation detection
            checkFormDegradation()
        }

        // Handle automatic phase transitions for intervals
        if intervalSettings != nil {
            phaseTime += 1
            checkPhaseTransition()
        }

        // Interval coaching: countdown when <=10 seconds remain in current phase
        if intervalSettings != nil && workoutPhase != .finished {
            let remaining = Int(phaseTimeRemaining)
            if remaining <= 10 && remaining > 0 && remaining < lastAnnouncedCountdown {
                lastAnnouncedCountdown = remaining
                audioCoach.runningCountdown(remaining)
            } else if remaining > 10 {
                lastAnnouncedCountdown = Int.max
            }
        }

        // Program interval coaching: phase transitions and countdowns
        if let intervals = programIntervals, !intervals.isEmpty {
            processProgramIntervalCoaching(intervals: intervals, elapsedTime: elapsedTime)
        }

        // Tetrathlon practice coaching: checkpoint announcements (time trials)
        if session.sessionType == .timeTrial && targetDistance > 0 && audioCoach.announcePBRaceCoaching {
            let pbTime = personalBests.personalBest(for: targetDistance)
            if tracker.totalDistance > 0 {
                let checkpoints = PacerSettings.pbCheckpointFractions
                let percentComplete = tracker.totalDistance / targetDistance

                // Distance-based checkpoint announcements with tetrathlon points
                for (index, fraction) in checkpoints.enumerated() {
                    if percentComplete >= fraction && index > lastAnnouncedCheckpointIndex {
                        lastAnnouncedCheckpointIndex = index
                        let expectedPBTime = pbTime > 0 ? pbTime * fraction : 0
                        audioCoach.announceTetrathlonCheckpoint(
                            distanceCovered: tracker.totalDistance,
                            totalDistance: targetDistance,
                            currentTime: elapsedTime,
                            expectedPBTime: expectedPBTime,
                            standardTime: standardTime
                        )

                        // Capture PB checkpoint for post-session insights
                        coachingData.pbCheckpoints.append(PBCheckpointRecord(
                            distanceFraction: fraction,
                            distanceMeters: tracker.totalDistance,
                            currentTime: elapsedTime,
                            expectedTime: expectedPBTime
                        ))
                    }
                }

                // Encouragement at 25%, 50%, 75%, 90%
                let percentInt = Int(percentComplete * 100)
                let encouragementThresholds = [25, 50, 75, 90]
                for threshold in encouragementThresholds {
                    if percentInt >= threshold && lastPBEncouragementPercent < threshold {
                        lastPBEncouragementPercent = threshold
                        let expectedTime = pbTime > 0 ? pbTime * percentComplete : 0
                        let isAhead = pbTime > 0 ? elapsedTime < expectedTime : true
                        audioCoach.announcePBEncouragement(
                            percentComplete: percentComplete,
                            isAhead: isAhead
                        )
                    }
                }
            }
        }

        // Virtual pacer: periodic gap announcements (~every 60s)
        if virtualPacer.isActive && audioCoach.announceVirtualPacer {
            let timeSinceLastAnnouncement = elapsedTime - lastPacerAnnouncementTime
            if timeSinceLastAnnouncement >= 60 && tracker.totalDistance > 100 {
                lastPacerAnnouncementTime = elapsedTime
                audioCoach.announceGapStatus(
                    gapSeconds: virtualPacer.gapTime,
                    gapMeters: virtualPacer.gapDistance,
                    isAhead: virtualPacer.isAhead
                )

                // Capture pacer gap for post-session insights
                coachingData.pacerGapSnapshots.append(PacerGapSnapshot(
                    elapsedTime: elapsedTime,
                    gapSeconds: virtualPacer.gapTime,
                    gapMeters: virtualPacer.gapDistance,
                    isAhead: virtualPacer.isAhead
                ))

                // Pace alert when significantly off target (>15s/km difference)
                let avgPace = tracker.totalDistance > 0
                    ? (elapsedTime / tracker.totalDistance) * 1000 : 0
                let pacerTarget = virtualPacer.targetPace
                if avgPace > 0 && pacerTarget > 0 && abs(avgPace - pacerTarget) > 15 {
                    audioCoach.announcePaceAlert(
                        currentPace: avgPace,
                        targetPace: pacerTarget
                    )
                }
            }
        }

        // Symmetry check every 5 minutes (same as WalkingPlugin)
        let fiveMinMark = Int(elapsedTime) / 300
        if fiveMinMark > lastSymmetryCheckMark {
            lastSymmetryCheckMark = fiveMinMark
            let startDate = session.startDate
            Task {
                let healthKit = HealthKitManager.shared
                if let asymmetry = await healthKit.fetchRunningAsymmetry(
                    from: startDate, to: Date()
                ), asymmetry > 10 {
                    await MainActor.run {
                        self.audioCoach.processRunningAsymmetry(asymmetry / 100.0)
                    }
                }
            }
        }

        // Process running form reminders
        audioCoach.processRunningFormReminder(elapsedTime: elapsedTime)
    }

    func onSessionStopping(tracker: SessionTracker) -> HealthKitEnrichment {
        // Stop form reminders
        audioCoach.stopRunningFormReminders()

        // Write cadence stats
        if !cadenceReadings.isEmpty {
            session.averageCadence = cadenceReadings.reduce(0, +) / cadenceReadings.count
            session.maxCadence = cadenceReadings.max() ?? 0
        }
        session.targetCadence = targetCadence

        // Write running form averages
        if !oscillationReadings.isEmpty {
            session.averageVerticalOscillation = oscillationReadings.reduce(0, +) / Double(oscillationReadings.count)
        }
        if !gctReadings.isEmpty {
            session.averageGroundContactTime = gctReadings.reduce(0, +) / Double(gctReadings.count)
        }

        // Write timestamped form samples
        if !formSamples.isEmpty {
            session.runningFormSamples = formSamples
        }

        // Write elevation from tracker
        session.totalAscent = tracker.elevationGain
        session.totalDescent = tracker.elevationLoss

        // Write sensor data from WatchSensorAnalyzer
        let runningSummary = sensorAnalyzer.getRunningSummary()
        if runningSummary.averageBreathingRate > 0 {
            session.averageBreathingRate = runningSummary.averageBreathingRate
        }
        if runningSummary.currentSpO2 > 0 {
            session.averageSpO2 = runningSummary.currentSpO2
        }
        if runningSummary.minSpO2 < 100 {
            session.minSpO2 = runningSummary.minSpO2
        }
        session.endFatigueScore = runningSummary.fatigueScore
        session.postureStability = runningSummary.postureStability
        session.trainingLoadScore = runningSummary.trainingLoadScore

        // Training load summary fields
        let trainingLoad = sensorAnalyzer.getTrainingLoadSummary()
        session.recoveryQuality = trainingLoad.recoveryQuality
        session.averageIntensity = trainingLoad.averageIntensity
        session.breathingRateTrend = trainingLoad.breathingRateTrend
        session.spo2Trend = trainingLoad.spo2Trend

        // Posture and active time from WatchSensorAnalyzer
        let totalPostureTime = sensorAnalyzer.goodPostureTime + sensorAnalyzer.poorPostureTime
        if totalPostureTime > 0 {
            session.goodPosturePercent = (sensorAnalyzer.goodPostureTime / totalPostureTime) * 100
        }
        let totalActivePassive = sensorAnalyzer.activeTime + sensorAnalyzer.passiveTime
        if totalActivePassive > 0 {
            session.activeTimePercent = (sensorAnalyzer.activeTime / totalActivePassive) * 100
        }

        // Elevation fallback from sensor analyzer (prefer GPS barometric)
        if session.totalAscent == 0 && runningSummary.totalElevationGain > 0 {
            session.totalAscent = runningSummary.totalElevationGain
        }
        if session.totalDescent == 0 && runningSummary.totalElevationLoss > 0 {
            session.totalDescent = runningSummary.totalElevationLoss
        }

        // Write weather
        if let weather = currentWeather {
            session.startWeather = weather
        }
        tracker.currentWeather.map { session.endWeather = $0 }

        // Stop virtual pacer
        virtualPacer.stop()

        // Stop LapDetector and announce track session complete
        let isTrackMode = session.runMode == .track
        if isTrackMode && lapDetector.lapCount > 0 {
            audioCoach.announceTrackSessionComplete(lapCount: lapDetector.lapCount)
            lapDetector.stop()
        }

        // Tetrathlon race complete coaching for time trials
        if session.sessionType == .timeTrial && targetDistance > 0 && audioCoach.announcePBRaceCoaching {
            let pbTime = personalBests.personalBest(for: targetDistance)
            let isNewPB = pbTime > 0 ? tracker.elapsedTime < pbTime : true
            audioCoach.announceTetrathlonComplete(
                finalTime: tracker.elapsedTime,
                pbTime: pbTime,
                standardTime: standardTime,
                isNewPB: isNewPB
            )
        }

        // Audio coaching: announce run complete summary
        if audioCoach.announceSessionStartEnd && tracker.totalDistance > 100 {
            let avgPace = tracker.totalDistance > 0
                ? (tracker.elapsedTime / tracker.totalDistance) * 1000 : 0
            audioCoach.announceRunComplete(
                distance: tracker.totalDistance,
                duration: tracker.elapsedTime,
                averagePace: avgPace,
                targetPace: nil
            )
        }

        // Auto-update practice PB for time trials
        if session.sessionType == .timeTrial && targetDistance > 0 {
            var pbs = RunningPersonalBests.shared
            pbs.updatePersonalBest(for: targetDistance, time: tracker.elapsedTime)
        }

        // Save coaching insights
        if session.sessionType == .timeTrial && targetDistance > 0 {
            let pbTime = personalBests.personalBest(for: targetDistance)
            if pbTime > 0 {
                coachingData.pbResult = PBResultRecord(
                    finalTime: tracker.elapsedTime, pbTime: pbTime, isNewPB: tracker.elapsedTime < pbTime
                )
            }
        }
        coachingData.announcementCount = audioCoach.sessionAnnouncementCount
        session.coachingSummary = coachingData

        // Stop sensor analyzer
        sensorAnalyzer.stopSession()

        // Fetch post-session HealthKit metrics (running + walking biomechanics)
        let startDate = session.startDate
        let endDate = Date()
        healthKitFetchTask = Task {
            let healthKit = HealthKitManager.shared

            let runningMetrics = await healthKit.fetchRunningMetrics(from: startDate, to: endDate)
            let walkingMetrics = await healthKit.fetchWalkingMetrics(from: startDate, to: endDate)

            await MainActor.run {
                // Running-specific HealthKit metrics
                self.session.healthKitAsymmetry = runningMetrics.asymmetryPercentage
                self.session.healthKitStrideLength = runningMetrics.strideLength
                self.session.healthKitStepCount = runningMetrics.stepCount
                self.session.healthKitPower = runningMetrics.power
                self.session.healthKitSpeed = runningMetrics.speed
                self.session.healthKitHRRecoveryOneMinute = runningMetrics.heartRateRecoveryOneMinute

                // Walking/gait metrics (also useful for running)
                self.session.healthKitDoubleSupportPercentage = walkingMetrics.doubleSupportPercentage
                self.session.healthKitWalkingSpeed = walkingMetrics.walkingSpeed
                self.session.healthKitWalkingStepLength = walkingMetrics.walkingStepLength
                self.session.healthKitWalkingSteadiness = walkingMetrics.walkingSteadiness
                self.session.healthKitWalkingHeartRateAvg = walkingMetrics.walkingHeartRateAverage

                // Compute biomechanics scores (same formulas as WalkingPlugin)
                if let asymmetry = runningMetrics.asymmetryPercentage {
                    self.session.walkingSymmetryScore = max(0, 100 - (asymmetry * 5))
                }

                if !self.cadenceReadings.isEmpty {
                    let mean = Double(self.cadenceReadings.reduce(0, +)) / Double(self.cadenceReadings.count)
                    let variance = self.cadenceReadings.reduce(0.0) { $0 + pow(Double($1) - mean, 2) } / Double(self.cadenceReadings.count)
                    let cv = mean > 0 ? sqrt(variance) / mean : 0
                    self.session.walkingCadenceConsistency = cv
                    self.session.walkingRhythmScore = max(0, min(100, 100 - (cv * 500)))
                }

                if let steadiness = walkingMetrics.walkingSteadiness {
                    self.session.walkingStabilityScore = steadiness
                }

                // save() removed — SessionTracker.stopSession() owns the final save
            }
        }

        // Build HealthKit enrichment
        var enrichment = HealthKitEnrichment()
        enrichment.metadata[HKMetadataKeyIndoorWorkout] = !usesGPS
        enrichment.metadata["SessionType"] = session.sessionType.rawValue
        if let weather = currentWeather {
            enrichment.metadata["Temperature"] = weather.temperature
            enrichment.metadata["Humidity"] = weather.humidity
        }

        // Build interval segment events for HealthKit
        if intervalSettings != nil && phaseTransitions.count > 1 {
            for i in 0..<(phaseTransitions.count - 1) {
                let transition = phaseTransitions[i]
                let nextStart = phaseTransitions[i + 1].start
                let interval = DateInterval(start: transition.start, end: nextStart)
                let event = HKWorkoutEvent(type: .segment, dateInterval: interval, metadata: [
                    "Phase": "\(transition.phase)",
                    "IntervalIndex": i + 1
                ])
                enrichment.workoutEvents.append(event)
            }
            // Last phase segment up to now
            if let last = phaseTransitions.last {
                let interval = DateInterval(start: last.start, end: Date())
                enrichment.workoutEvents.append(HKWorkoutEvent(type: .segment, dateInterval: interval, metadata: [
                    "Phase": "\(last.phase)",
                    "IntervalIndex": phaseTransitions.count
                ]))
            }
        }

        // Track mode: add lap events to HealthKit
        if isTrackMode && !lapDetector.lapTimes.isEmpty {
            var lapStartDate = session.startDate
            for (index, duration) in lapDetector.lapTimes.enumerated() {
                let lapEndDate = lapStartDate.addingTimeInterval(duration)
                let interval = DateInterval(start: lapStartDate, end: lapEndDate)
                enrichment.workoutEvents.append(HKWorkoutEvent(type: .lap, dateInterval: interval, metadata: [
                    "LapIndex": index + 1,
                    "LapDistance": session.trackLength
                ]))
                lapStartDate = lapEndDate
            }
        }

        // Analyze segment PBs for outdoor GPS runs longer than 1200m
        if session.runMode == .outdoor && tracker.totalDistance > 1200 {
            let points = session.sortedLocationPoints
            let pbs = RunningPersonalBests.shared
            let segmentResults = SegmentPBAnalyzer.analyze(
                locationPoints: points,
                totalDistance: tracker.totalDistance,
                personalBests: pbs
            )
            if !segmentResults.isEmpty {
                session.segmentPBResults = segmentResults
            }
        }

        // Compute skill domain scores
        if let ctx = modelContext {
            let skillService = SkillDomainService()
            let scores = skillService.computeScores(from: session, score: nil)
            for score in scores {
                ctx.insert(score)
            }
        }

        // Widget sync
        if let ctx = modelContext {
            WidgetDataSyncService.shared.syncRecentSessions(context: ctx)
        }

        let mode = session.runMode.rawValue
        Log.tracking.info("Running plugin stopped (mode: \(mode))")
        return enrichment
    }

    func onSessionCompleted(tracker: SessionTracker) async {
        // Await HealthKit fetch from onSessionStopping before proceeding
        await healthKitFetchTask?.value
        healthKitFetchTask = nil

        // Retry HR recovery fetch if not captured during onSessionStopping
        if session.healthKitHRRecoveryOneMinute == nil, let endDate = session.endDate {
            try? await Task.sleep(for: .seconds(30))
            let hrRecovery = await HealthKitManager.shared.fetchHeartRateRecoveryOneMinute(
                from: session.startDate, to: endDate
            )
            if let hrRecovery {
                await MainActor.run {
                    session.healthKitHRRecoveryOneMinute = hrRecovery
                    try? modelContext?.save()
                }
            }
        }
        await ArtifactConversionService.shared.convertAndSyncRunningSession(session)
    }

    func onHeartRateUpdate(bpm: Int, tracker: SessionTracker) {
        // Heart rate is tracked by SessionTracker; nothing additional needed here.
    }

    func watchStatusFields(tracker: SessionTracker) -> WatchStatusFields {
        var fields = WatchStatusFields()
        fields.rideType = session.sessionType.rawValue
        fields.elevation = tracker.currentElevation
        return fields
    }

    func handleWatchCommand(_ command: WatchCommand, tracker: SessionTracker) {
        switch command {
        case .startRide:
            Task {
                await tracker.startSession(plugin: self)
            }
        case .stopRide:
            tracker.stopSession()
        case .pauseRide:
            tracker.pauseSession()
        case .resumeRide:
            tracker.resumeSession()
        default:
            break
        }
    }

    func currentGaitType(speed: Double) -> GaitType {
        RunningPhase.fromGPSSpeed(speed).toGaitType
    }

    // MARK: - Interval Phase Management

    private var phaseTimeRemaining: TimeInterval {
        guard let settings = intervalSettings else { return 0 }
        let phaseDuration: TimeInterval
        switch workoutPhase {
        case .warmup: phaseDuration = settings.warmupDuration
        case .work: phaseDuration = settings.workDuration
        case .rest: phaseDuration = settings.restDuration
        case .cooldown: phaseDuration = settings.cooldownDuration
        case .finished: return 0
        }
        return max(0, phaseDuration - phaseTime)
    }

    private func checkPhaseTransition() {
        guard let settings = intervalSettings else { return }

        let phaseDuration: TimeInterval
        switch workoutPhase {
        case .warmup: phaseDuration = settings.warmupDuration
        case .work: phaseDuration = settings.workDuration
        case .rest: phaseDuration = settings.restDuration
        case .cooldown: phaseDuration = settings.cooldownDuration
        case .finished: return
        }

        if phaseTime >= phaseDuration {
            advancePhase()
        }
    }

    private func advancePhase() {
        guard let settings = intervalSettings else { return }

        // Record completed phase performance for coaching insights
        let completedPhase = workoutPhase
        let targetDuration: TimeInterval
        switch completedPhase {
        case .warmup: targetDuration = settings.warmupDuration
        case .work: targetDuration = settings.workDuration
        case .rest: targetDuration = settings.restDuration
        case .cooldown: targetDuration = settings.cooldownDuration
        case .finished: targetDuration = 0
        }
        if completedPhase != .finished {
            let phaseLabel: String
            switch completedPhase {
            case .warmup: phaseLabel = "warmup"
            case .work: phaseLabel = "work"
            case .rest: phaseLabel = "rest"
            case .cooldown: phaseLabel = "cooldown"
            case .finished: phaseLabel = "finished"
            }
            coachingData.intervalPerformance.append(IntervalPerformanceRecord(
                intervalIndex: intervalCount,
                phaseRaw: phaseLabel,
                targetDuration: targetDuration,
                actualDuration: phaseTime
            ))
        }

        phaseTime = 0

        switch workoutPhase {
        case .warmup:
            workoutPhase = .work
        case .work:
            if intervalCount < settings.numberOfIntervals {
                workoutPhase = .rest
            } else if settings.includeCooldown {
                workoutPhase = .cooldown
            } else {
                workoutPhase = .finished
            }
        case .rest:
            intervalCount += 1
            workoutPhase = .work
        case .cooldown:
            workoutPhase = .finished
        case .finished:
            break
        }

        // Record phase transition timestamp for HealthKit segment events
        phaseTransitions.append((phase: workoutPhase, start: Date()))

        // Reset countdown tracker for new phase
        lastAnnouncedCountdown = Int.max

        // Audio coaching: interval phase announcements
        if audioCoach.announceSessionStartEnd {
            switch workoutPhase {
            case .work:
                audioCoach.announceRunningIntervalStart(
                    name: "Interval \(intervalCount)",
                    targetPace: nil
                )
            case .rest:
                audioCoach.announceIntervalRest(duration: settings.restDuration)
            case .finished:
                audioCoach.announce("Interval workout complete. \(settings.numberOfIntervals) intervals finished.")
            default:
                break
            }
        }

        // Haptic feedback on phase change
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(workoutPhase == .work ? .warning : .success)
    }

    // MARK: - Program Interval Coaching

    private func processProgramIntervalCoaching(intervals: [ProgramInterval], elapsedTime: TimeInterval) {
        // Flatten intervals (expanding repeat counts)
        let flat = intervals.flatMap { interval in
            (0..<interval.repeatCount).map { _ in
                (phase: interval.phase, duration: interval.durationSeconds)
            }
        }
        guard !flat.isEmpty else { return }

        // Find current interval index
        var accumulated: Double = 0
        var currentIndex = flat.count - 1
        var timeRemaining: Double = 0
        for (i, interval) in flat.enumerated() {
            if elapsedTime < accumulated + interval.duration {
                currentIndex = i
                timeRemaining = accumulated + interval.duration - elapsedTime
                break
            }
            accumulated += interval.duration
        }

        // Detect phase transition
        if currentIndex != lastProgramPhaseIndex {
            let phase = flat[currentIndex].phase
            let duration = flat[currentIndex].duration

            // Announce phase transition
            programAudioCoach.announcePhaseTransition(
                phase: phase,
                duration: duration,
                intervalIndex: currentIndex,
                totalIntervals: flat.count
            )

            // Announce interval progress when completing an interval
            if lastProgramPhaseIndex >= 0 {
                programAudioCoach.announceIntervalProgress(
                    completedIndex: lastProgramPhaseIndex,
                    totalIntervals: flat.count
                )
            }

            lastProgramPhaseIndex = currentIndex
            lastProgramCountdown = Int.max
        }

        // Countdown announcements (10 seconds and 3 seconds before phase change)
        let secondsRemaining = Int(timeRemaining)
        if secondsRemaining <= 10 && secondsRemaining > 0 && secondsRemaining < lastProgramCountdown {
            let nextPhase: IntervalPhase? = (currentIndex + 1 < flat.count) ? flat[currentIndex + 1].phase : nil
            programAudioCoach.announcePhaseCountdown(
                secondsRemaining: secondsRemaining,
                nextPhase: nextPhase
            )
            lastProgramCountdown = secondsRemaining
        } else if secondsRemaining > 10 {
            lastProgramCountdown = Int.max
        }
    }

    // MARK: - Form Degradation Detection

    private func checkFormDegradation() {
        // Need at least 20 samples and check every 10 new samples (~30s at 3s intervals)
        guard formSamples.count >= 20,
              formSamples.count - lastDegradationCheckCount >= 10 else { return }
        lastDegradationCheckCount = formSamples.count

        // Throttle alerts to at most once per 90 seconds
        guard Date().timeIntervalSince(lastDegradationAlertTime) > 90 else { return }

        let bio = RunnerBiomechanics()
        let analysis = bio.formDegradation(
            oscillationSamples: formSamples.map(\.oscillation),
            gctSamples: formSamples.map(\.groundContactTime),
            cadenceSamples: formSamples.map { Double($0.cadence) }
        )

        guard analysis.hasDegradation else { return }
        lastDegradationAlertTime = Date()

        if analysis.cadenceDegraded {
            audioCoach.announce("Cadence dropping — focus on quick, light steps")
        } else if analysis.gctDegraded {
            audioCoach.announce("Ground contact rising — think hot coals, quick feet")
        } else if analysis.oscillationDegraded {
            audioCoach.announce("Bouncing more — run tall, engage your core")
        }
    }
}
