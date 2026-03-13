//
//  RidingPlugin.swift
//  TetraTrack
//
//  Riding-specific discipline plugin. Contains all equestrian logic
//  extracted from RideTracker: gait detection, lead/rein analysis,
//  CoreMotion, turn analysis, phase tracking, dressage, XC timing.

import CoreLocation
import HealthKit
import SwiftData
import Observation
import UIKit
import os

@Observable
@MainActor
final class RidingPlugin: DisciplinePlugin {
    // MARK: - Identity

    let subscriberId = "ride"
    let activityType: GPSActivityType = .riding
    let watchDiscipline: WatchSessionDiscipline = .riding
    let sharingActivityType = "riding"

    // MARK: - Feature Flags

    let usesGPS = true
    let usesFallDetection = true
    let usesVehicleDetection = true
    let supportsFamilySharing = true
    let disableAutoCalories = true  // Gait-adjusted calories are more accurate for riding

    // MARK: - HealthKit

    var workoutConfiguration: HKWorkoutConfiguration {
        let config = HKWorkoutConfiguration()
        config.activityType = .equestrianSports
        config.locationType = selectedRideType.isIndoor ? .indoor : .outdoor
        return config
    }

    // MARK: - Observable Properties (Riding-Specific)

    // Gait
    var currentGait: GaitType = .stationary
    var walkTime: TimeInterval = 0 { didSet { invalidateGaitCache() } }
    var trotTime: TimeInterval = 0 { didSet { invalidateGaitCache() } }
    var canterTime: TimeInterval = 0 { didSet { invalidateGaitCache() } }
    var gallopTime: TimeInterval = 0 { didSet { invalidateGaitCache() } }
    var gaitConfidence: Double = 0.0

    // Cached gait percentages
    private var _cachedGaitPercentages: (walk: Double, trot: Double, canter: Double, gallop: Double)?

    private func invalidateGaitCache() {
        _cachedGaitPercentages = nil
    }

    var totalMovingTime: TimeInterval {
        walkTime + trotTime + canterTime + gallopTime
    }

    var gaitPercentages: (walk: Double, trot: Double, canter: Double, gallop: Double) {
        if let cached = _cachedGaitPercentages {
            return cached
        }
        let total = walkTime + trotTime + canterTime + gallopTime
        guard total > 0 else { return (0, 0, 0, 0) }
        let computed = (
            (walkTime / total) * 100,
            (trotTime / total) * 100,
            (canterTime / total) * 100,
            (gallopTime / total) * 100
        )
        _cachedGaitPercentages = computed
        return computed
    }

    var walkPercent: Double { gaitPercentages.walk }
    var trotPercent: Double { gaitPercentages.trot }
    var canterPercent: Double { gaitPercentages.canter }
    var gallopPercent: Double { gaitPercentages.gallop }

    // Lead/Rein
    var currentLead: Lead = .unknown
    var leadQuality: Double = 0.0
    var currentRein: ReinDirection = .straight
    var leftReinPercent: Double { reinPercentages.left }
    var rightReinPercent: Double { reinPercentages.right }

    var reinPercentages: (left: Double, right: Double) {
        let total = reinAnalyzer.totalLeftReinDuration + reinAnalyzer.totalRightReinDuration
        guard total > 0 else { return (0, 0) }
        return (
            (reinAnalyzer.totalLeftReinDuration / total) * 100,
            (reinAnalyzer.totalRightReinDuration / total) * 100
        )
    }

    // Turn percentages
    var turnPercentages: (left: Double, right: Double) {
        let stats = turnAnalyzer.turnStats
        let totalAngle = stats.totalLeftAngle + stats.totalRightAngle
        guard totalAngle > 0 else { return (0, 0) }
        return (
            (stats.totalLeftAngle / totalAngle) * 100,
            (stats.totalRightAngle / totalAngle) * 100
        )
    }

    var leftTurnPercent: Double { turnPercentages.left }
    var rightTurnPercent: Double { turnPercentages.right }

    // Lead percentages
    var leadPercentages: (left: Double, right: Double) {
        let total = leadAnalyzer.totalLeftLeadDuration + leadAnalyzer.totalRightLeadDuration
        guard total > 0 else { return (0, 0) }
        return (
            (leadAnalyzer.totalLeftLeadDuration / total) * 100,
            (leadAnalyzer.totalRightLeadDuration / total) * 100
        )
    }

    var leftLeadPercent: Double { leadPercentages.left }
    var rightLeadPercent: Double { leadPercentages.right }

    // Analysis
    var currentSymmetry: Double = 0.0
    var currentRhythm: Double = 0.0
    var strideFrequency: Double = 0.0

    // Gradient
    var currentGradient: Double = 0.0
    private var recentAltitudes: [(altitude: Double, distance: Double)] = []

    // Phase tracking (showjumping)
    var currentPhase: RidePhase?
    var currentPhaseType: RidePhaseType = .warmup
    private var phaseStartDistance: Double = 0
    private(set) var phaseStartJumpCount: Int = 0
    private var phaseHeartRates: [Int] = []

    // Dressage
    var selectedDressageTest: DressageTest?
    var currentMovementIndex: Int = 0
    var movementScores: [Int] = []

    // Cross Country
    var xcOptimumTime: TimeInterval = 0
    var xcCourseDistance: Double = 0
    private var lastMinuteMarker: Int = 0

    var xcTimeDifference: TimeInterval {
        guard xcOptimumTime > 0, xcCourseDistance > 0,
              let tracker = _weakTracker, tracker.totalDistance > 0 else { return 0 }
        let expectedTimeAtDistance = (tracker.totalDistance / xcCourseDistance) * xcOptimumTime
        return tracker.elapsedTime - expectedTimeAtDistance
    }

    var xcIsAheadOfTime: Bool {
        xcTimeDifference < 0
    }

    // Config
    var selectedRideType: RideType = .hack
    var selectedHorse: Horse?
    var phoneMountPosition: PhoneMountPosition = .jodhpurThigh

    // Reference to current ride model
    var currentRide: Ride?

    // MARK: - Watch Sensor Metrics

    var jumpCount: Int { watchSensorAnalyzer.jumpCount }
    var movementIntensity: Double { watchSensorAnalyzer.movementIntensity }
    var activeRidingTime: TimeInterval { watchSensorAnalyzer.activeTime }
    var passiveRidingTime: TimeInterval { watchSensorAnalyzer.passiveTime }
    var activeRidingPercent: Double {
        let total = activeRidingTime + passiveRidingTime
        guard total > 0 else { return 50 }
        return (activeRidingTime / total) * 100
    }
    var compassTurnCount: Int { watchSensorAnalyzer.compassTurns.count }
    var sensorRelativeAltitude: Double { watchSensorAnalyzer.relativeAltitude }
    var sensorElevationGain: Double { watchSensorAnalyzer.totalElevationGain }
    var sensorElevationLoss: Double { watchSensorAnalyzer.totalElevationLoss }

    // Calibration status
    var rideCalibrationStatus: GaitAnalyzer.CalibrationStatus {
        gaitAnalyzer.calibrationStatus
    }

    // GPS gait fallback
    var isUsingGPSGaitFallback: Bool = false
    private var lastMotionSampleTime: Date?
    private let motionGapThreshold: TimeInterval = 3.0

    // MARK: - Private Services

    private let gaitAnalyzer = GaitAnalyzer()
    private let turnAnalyzer = TurnAnalyzer()
    private let motionManager = MotionManager()
    private let leadAnalyzer = LeadAnalyzer()
    private let transitionAnalyzer = TransitionAnalyzer()
    private let reinAnalyzer = ReinAnalyzer()
    private let symmetryAnalyzer = SymmetryAnalyzer()
    private let rhythmAnalyzer = RhythmAnalyzer()
    private let watchSensorAnalyzer = WatchSensorAnalyzer.shared
    private let pocketModeManager = PocketModeManager.shared
    private let audioCoach = AudioCoachManager.shared
    private var lastAnnouncedGait: GaitType = .stationary

    private var lastGaitUpdateTime: Date?
    private var lastCoordinate: CLLocationCoordinate2D?
    private var lastLocation: CLLocation?

    // Watch gait enhancement task
    private var watchGaitEnhancementTask: Task<Void, Never>?

    // Weak reference to tracker for computed properties (XC timing)
    private weak var _weakTracker: SessionTracker?

    private var modelContext: ModelContext?

    // MARK: - DisciplinePlugin Protocol

    func createSessionModel(in context: ModelContext) -> any SessionWritable {
        modelContext = context
        let ride = Ride()
        ride.startDate = Date()
        ride.name = Ride.defaultName(for: ride.startDate)
        ride.rideType = selectedRideType
        ride.horse = selectedHorse
        ride.phoneMountPosition = phoneMountPosition
        currentRide = ride
        return ride
    }

    func createLocationPoint(from location: CLLocation) -> (any PersistentModel)? {
        guard let ride = currentRide else { return nil }
        let point = LocationPoint(from: location)
        point.ride = ride
        return point
    }

    func onSessionStarted(tracker: SessionTracker) async {
        _weakTracker = tracker

        // Configure gait analyzer
        gaitAnalyzer.configure(with: modelContext!)
        if let ride = currentRide {
            gaitAnalyzer.startAnalyzing(for: ride)
        }

        // Configure horse-specific priors
        if let horse = selectedHorse {
            gaitAnalyzer.configure(for: horse)
        }

        // Configure mount position
        gaitAnalyzer.configure(mountPosition: phoneMountPosition)
        motionManager.configureForPlacement(phoneMountPosition)
        leadAnalyzer.configure(phoneMountPosition: phoneMountPosition)

        // Enable diagnostics for gait testing rides
        if selectedRideType == .gaitTesting {
            gaitAnalyzer.collectDiagnostics = true
        }

        // Wire calibration haptic
        gaitAnalyzer.onCalibrationComplete = {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }

        // Reset analyzers
        turnAnalyzer.reset()
        leadAnalyzer.reset()
        transitionAnalyzer.reset()
        reinAnalyzer.reset()
        symmetryAnalyzer.reset()
        rhythmAnalyzer.reset()
        watchSensorAnalyzer.startSession(discipline: .riding)

        // Reset riding state
        currentGait = .stationary
        walkTime = 0
        trotTime = 0
        canterTime = 0
        gallopTime = 0
        lastGaitUpdateTime = nil
        lastCoordinate = nil
        lastLocation = nil
        isUsingGPSGaitFallback = false
        lastMotionSampleTime = nil
        currentLead = .unknown
        currentRein = .straight
        currentSymmetry = 0.0
        currentRhythm = 0.0
        currentGradient = 0.0
        recentAltitudes = []
        lastAnnouncedGait = .stationary

        // Start motion updates
        setupMotionCallback()
        setupGaitCallback()
        setupReinCallback()
        motionManager.startUpdates()

        // Start pocket mode
        pocketModeManager.startMonitoring()

        // Watch gait enhancement
        setupWatchGaitEnhancement()

        // Setup voice note handling
        setupVoiceNoteObservation()

        // Set weather on ride model
        tracker.currentWeather.map { currentRide?.startWeather = $0 }

        // Auto-start warmup phase for showjumping
        if selectedRideType == .showjumping {
            startPhase(.warmup)
        }

        // Audio announcement
        audioCoach.announce("Ride started. Have a great ride!")
    }

    func onSessionPaused(tracker: SessionTracker) {
        motionManager.stopUpdates()
    }

    func onSessionResumed(tracker: SessionTracker) {
        motionManager.startUpdates()
    }

    func onSessionStopping(tracker: SessionTracker) -> HealthKitEnrichment {
        // Audio announcement
        let distanceKm = tracker.totalDistance / 1000.0
        let minutes = Int(tracker.elapsedTime) / 60
        if distanceKm >= 1.0 {
            audioCoach.announce("Ride complete. You covered \(String(format: "%.1f", distanceKm)) kilometres in \(minutes) minutes.")
        } else {
            let meters = Int(tracker.totalDistance)
            audioCoach.announce("Ride complete. You covered \(meters) metres in \(minutes) minutes.")
        }

        // End any active phase
        endCurrentPhase()

        // Stop motion
        motionManager.stopUpdates()
        pocketModeManager.stopMonitoring()

        // Stop analyzers
        gaitAnalyzer.stopAnalyzing()
        watchSensorAnalyzer.stopSession()
        watchGaitEnhancementTask?.cancel()
        watchGaitEnhancementTask = nil

        // Finalize symmetry/rhythm
        symmetryAnalyzer.finalizeReinSegment()
        rhythmAnalyzer.finalizeReinSegment()

        // Build HealthKit enrichment
        var enrichment = HealthKitEnrichment()

        // Gait transition marker events
        let transitions = transitionAnalyzer.getTransitionModels()
        for transition in transitions {
            let interval = DateInterval(start: transition.timestamp, duration: 0)
            let event = HKWorkoutEvent(type: .marker, dateInterval: interval, metadata: [
                "GaitFrom": transition.from.rawValue,
                "GaitTo": transition.to.rawValue,
                "TransitionQuality": transition.quality
            ])
            enrichment.workoutEvents.append(event)
        }

        // Gait segment events
        if let ride = currentRide {
            var segmentStart = ride.startDate
            let gaitDurations: [(GaitType, TimeInterval)] = [
                (.walk, walkTime), (.trot, trotTime), (.canter, canterTime), (.gallop, gallopTime)
            ]
            for (gait, duration) in gaitDurations where duration > 1 {
                let segmentEnd = segmentStart.addingTimeInterval(duration)
                let interval = DateInterval(start: segmentStart, end: segmentEnd)
                let event = HKWorkoutEvent(type: .segment, dateInterval: interval, metadata: [
                    "Gait": gait.rawValue
                ])
                enrichment.workoutEvents.append(event)
                segmentStart = segmentEnd
            }

            // Per-gait calorie samples
            let riderWeight = HealthKitManager.shared.healthKitWeight ?? 70.0
            var sampleStart = ride.startDate
            for (gait, duration) in gaitDurations where duration > 1 {
                let met = RidingMETValues.met(for: gait)
                let calories = RidingMETValues.calories(met: met, weightKg: riderWeight, durationSeconds: duration)
                let sampleEnd = sampleStart.addingTimeInterval(duration)
                let sample = HKQuantitySample(
                    type: HKQuantityType(.activeEnergyBurned),
                    quantity: HKQuantity(unit: .kilocalorie(), doubleValue: calories),
                    start: sampleStart,
                    end: sampleEnd,
                    metadata: ["Gait": gait.rawValue]
                )
                enrichment.calorieSamples.append(sample)
                sampleStart = sampleEnd
            }
        }

        // Build metadata
        enrichment.metadata[HKMetadataKeyIndoorWorkout] = false
        if let horseName = selectedHorse?.name {
            enrichment.metadata["HorseName"] = horseName
        }
        enrichment.metadata["RideType"] = selectedRideType.rawValue
        if tracker.elevationGain > 0 {
            enrichment.metadata[HKMetadataKeyElevationAscended] = HKQuantity(unit: .meter(), doubleValue: tracker.elevationGain)
        }

        // Finalize ride model (discipline-specific fields only — common fields
        // like endDate, totalDistance, totalDuration, HR stats are written by SessionTracker)
        if let ride = currentRide {
            ride.maxSpeed = tracker.gpsTracker.maxSpeed

            // Elevation (property names differ from RunningSession, so plugin writes these)
            ride.elevationGain = tracker.elevationGain
            ride.elevationLoss = tracker.elevationLoss

            // Turn stats
            let turnStats = turnAnalyzer.turnStats
            ride.totalLeftAngle = turnStats.totalLeftAngle
            ride.totalRightAngle = turnStats.totalRightAngle

            // Lead stats
            ride.leftLeadDuration = leadAnalyzer.totalLeftLeadDuration
            ride.rightLeadDuration = leadAnalyzer.totalRightLeadDuration

            // Rein stats
            ride.leftReinDuration = reinAnalyzer.totalLeftReinDuration
            ride.rightReinDuration = reinAnalyzer.totalRightReinDuration
            ride.leftReinSymmetry = symmetryAnalyzer.leftReinSymmetry
            ride.rightReinSymmetry = symmetryAnalyzer.rightReinSymmetry
            ride.leftReinRhythm = rhythmAnalyzer.leftReinRhythm
            ride.rightReinRhythm = rhythmAnalyzer.rightReinRhythm

            // Rein segments
            if let ctx = modelContext {
                for segmentData in reinAnalyzer.getSegmentData() {
                    let segment = ReinSegment(direction: segmentData.direction, startTime: segmentData.startTime)
                    segment.endTime = segmentData.endTime
                    segment.distance = segmentData.distance
                    segment.ride = ride
                    ctx.insert(segment)
                }

                // Gait transitions
                for transition in transitionAnalyzer.getTransitionModels() {
                    let record = GaitTransition(
                        from: transition.from,
                        to: transition.to,
                        timestamp: transition.timestamp,
                        quality: transition.quality
                    )
                    record.ride = ride
                    ctx.insert(record)
                }
            }

            // Stride frequency
            ride.averageStrideFrequency = strideFrequency

            // Watch sensor metrics
            let ridingSummary = watchSensorAnalyzer.getRidingSummary()
            ride.detectedJumpCount = ridingSummary.jumpCount
            ride.activeTimePercent = ridingSummary.activePercent
            ride.sessionPostureStability = ridingSummary.postureStability
            ride.goodPosturePercent = ridingSummary.goodPosturePercent
            ride.endFatigueScore = ridingSummary.fatigueScore

            // Training load and fatigue metrics
            let trainingLoad = watchSensorAnalyzer.getTrainingLoadSummary()
            ride.trainingLoadScore = trainingLoad.totalLoad
            ride.recoveryQuality = trainingLoad.recoveryQuality
            ride.averageIntensity = trainingLoad.averageIntensity
            ride.breathingRateTrend = trainingLoad.breathingRateTrend
            ride.spo2Trend = trainingLoad.spo2Trend

            // Breathing and SpO2
            ride.averageBreathingRate = watchSensorAnalyzer.breathingRate
            if watchSensorAnalyzer.oxygenSaturation > 0 {
                ride.averageSpO2 = watchSensorAnalyzer.oxygenSaturation
            }
            if watchSensorAnalyzer.minSpO2 < 100 {
                ride.minSpO2 = watchSensorAnalyzer.minSpO2
            }

            // Gait diagnostics for testing rides
            if selectedRideType == .gaitTesting && !gaitAnalyzer.diagnosticEntries.isEmpty {
                ride.gaitDiagnostics = gaitAnalyzer.diagnosticEntries
            }

            // Coaching notes from family sharing
            if tracker.isSharingWithFamily {
                let sharingCoordinator = UnifiedSharingCoordinator.shared
                if let session = sharingCoordinator.mySession {
                    let notes = session.coachingNotes
                    if !notes.isEmpty {
                        ride.coachingNotes = notes
                        Log.tracking.info("Transferred \(notes.count) coaching notes to ride")
                    }
                }
            }

            // HealthKit workout UUID will be set by SessionTracker's endWorkoutTask

            do {
                try modelContext?.save()
            } catch {
                Log.tracking.error("Failed to save ride data: \(error)")
            }

            // Compute skill domain scores
            if let ctx = modelContext {
                let skillService = SkillDomainService()
                let scores = skillService.computeScores(from: ride)
                for score in scores {
                    ctx.insert(score)
                }
                do {
                    try ctx.save()
                } catch {
                    Log.tracking.error("Failed to save skill domain scores: \(error)")
                }
            }

            // Learn gait characteristics for this horse
            if let horse = ride.horse {
                let learningService = GaitLearningService()
                learningService.learnFromRide(ride, horse: horse)
            }
        }

        return enrichment
    }

    func onSessionCompleted(tracker: SessionTracker) async {
        guard let ride = currentRide else { return }

        // Generate post-session AI summary
        generatePostSessionSummary(for: ride)

        // Convert to TrainingArtifact and sync for family sharing
        await ArtifactConversionService.shared.convertAndSyncRide(ride)
    }

    func onSessionDiscarded(tracker: SessionTracker) {
        // Stop all riding-specific services
        motionManager.stopUpdates()
        pocketModeManager.stopMonitoring()
        gaitAnalyzer.stopAnalyzing()
        watchSensorAnalyzer.stopSession()
        watchGaitEnhancementTask?.cancel()
        watchGaitEnhancementTask = nil

        // Model deletion is handled by SessionTracker.discardSession()

        // Reset riding state
        currentRide = nil
        currentPhase = nil
        currentPhaseType = .warmup
        phaseStartDistance = 0
        phaseStartJumpCount = 0
        phaseHeartRates = []
        selectedDressageTest = nil
        currentMovementIndex = 0
        movementScores = []
        currentGait = .stationary
        currentLead = .unknown
        currentRein = .straight
        currentSymmetry = 0.0
        currentRhythm = 0.0
    }

    // MARK: - Location Processing

    func onLocationProcessed(_ location: CLLocation, distanceDelta: Double, tracker: SessionTracker) {
        guard tracker.sessionState == .tracking, let ride = currentRide else { return }

        // Track max speed on the ride model
        if tracker.gpsTracker.maxSpeed > ride.maxSpeed {
            ride.maxSpeed = tracker.gpsTracker.maxSpeed
        }

        // Sync elevation to ride model
        ride.elevationGain = tracker.elevationGain
        ride.elevationLoss = tracker.elevationLoss

        // Calculate gradient for XC
        if distanceDelta > 0 {
            recentAltitudes.append((altitude: location.altitude, distance: tracker.totalDistance))
            let minDistance = tracker.totalDistance - 50
            recentAltitudes.removeAll { $0.distance < minDistance }

            if recentAltitudes.count >= 2,
               let first = recentAltitudes.first,
               let last = recentAltitudes.last {
                let distDiff = last.distance - first.distance
                if distDiff > 10 {
                    let altDiff = last.altitude - first.altitude
                    currentGradient = (altDiff / distDiff) * 100
                }
            }
        }

        // Turn analysis
        if let lastCoord = lastCoordinate {
            turnAnalyzer.processLocations(from: lastCoord, to: location.coordinate)
            reinAnalyzer.processLocation(from: lastCoord, to: location.coordinate)
            currentRein = reinAnalyzer.currentRein
        }
        lastCoordinate = location.coordinate

        // Gait analysis
        gaitAnalyzer.processLocation(speed: tracker.currentSpeed, distance: distanceDelta, horizontalAccuracy: location.horizontalAccuracy)
        var newGait = gaitAnalyzer.currentGait

        // GPS-only gait fallback when CoreMotion pauses
        if let lastMotion = lastMotionSampleTime,
           Date().timeIntervalSince(lastMotion) > motionGapThreshold {
            let gpsFallbackGait = GaitType.fromSpeed(tracker.currentSpeed)
            if gpsFallbackGait != newGait {
                newGait = gpsFallbackGait
            }
            if !isUsingGPSGaitFallback {
                isUsingGPSGaitFallback = true
                Log.tracking.warning("CoreMotion delivery gap - falling back to GPS gait detection")
            }
        }

        // Track time in each gait
        if let lastUpdate = lastGaitUpdateTime {
            let timeDelta = Date().timeIntervalSince(lastUpdate)
            switch currentGait {
            case .walk: walkTime += timeDelta
            case .trot: trotTime += timeDelta
            case .canter: canterTime += timeDelta
            case .gallop: gallopTime += timeDelta
            case .stationary: break
            }
        }
        lastGaitUpdateTime = Date()
        currentGait = newGait

        // Update location manager for map display
        tracker.locationManager.updateGait(newGait)
        tracker.locationManager.addTrackedPoint(location)

        // Update transition analyzer
        transitionAnalyzer.updateSpeed(tracker.currentSpeed)

        lastLocation = location

        // Fall detection with current location
        tracker.fallDetectionManager.updateLocation(location.coordinate)
    }

    // MARK: - Timer Tick

    func onTimerTick(elapsedTime: TimeInterval, tracker: SessionTracker) {
        // XC-specific timing alerts
        if selectedRideType == .crossCountry && xcOptimumTime > 0 {
            processXCTimingAlerts(elapsedTime: elapsedTime)
        }
    }

    // MARK: - Heart Rate

    func onHeartRateUpdate(bpm: Int, tracker: SessionTracker) {
        recordPhaseHeartRate(bpm)
    }

    // MARK: - Watch

    func watchStatusFields(tracker: SessionTracker) -> WatchStatusFields {
        let gaits = gaitPercentages
        let reins = reinPercentages
        let leads = leadPercentages

        var fields = WatchStatusFields()
        fields.horseName = selectedHorse?.name
        fields.rideType = selectedRideType.rawValue

        switch selectedRideType {
        case .hack, .showjumping, .gaitTesting:
            fields.walkPercent = gaits.walk
            fields.trotPercent = gaits.trot
            fields.canterPercent = gaits.canter
            fields.gallopPercent = gaits.gallop
            fields.elevation = tracker.currentElevation

        case .schooling, .dressage:
            fields.walkPercent = gaits.walk
            fields.trotPercent = gaits.trot
            fields.canterPercent = gaits.canter
            fields.leftReinPercent = reins.left
            fields.rightReinPercent = reins.right
            fields.leftLeadPercent = leads.left
            fields.rightLeadPercent = leads.right
            fields.symmetryScore = currentSymmetry
            fields.rhythmScore = currentRhythm

        case .crossCountry:
            fields.trotPercent = gaits.trot
            fields.canterPercent = gaits.canter
            fields.gallopPercent = gaits.gallop
            fields.optimalTime = xcOptimumTime
            fields.timeDifference = xcTimeDifference
            fields.elevation = tracker.currentElevation
        }

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
        currentGait
    }

    // MARK: - Phase Tracking (Showjumping)

    func startPhase(_ type: RidePhaseType) {
        endCurrentPhase()

        let phase = RidePhase(phaseType: type)
        currentPhase = phase
        currentPhaseType = type
        phaseStartDistance = _weakTracker?.totalDistance ?? 0
        phaseStartJumpCount = jumpCount
        phaseHeartRates = []

        if let ride = currentRide {
            if ride.phases == nil { ride.phases = [] }
            ride.phases?.append(phase)
        }

        Log.tracking.info("Started phase: \(type.rawValue)")
    }

    func endCurrentPhase() {
        guard let phase = currentPhase else { return }
        phase.endDate = Date()
        phase.distance = (_weakTracker?.totalDistance ?? 0) - phaseStartDistance
        phase.jumpCount = jumpCount - phaseStartJumpCount

        if !phaseHeartRates.isEmpty {
            phase.averageHeartRate = phaseHeartRates.reduce(0, +) / phaseHeartRates.count
            phase.maxHeartRate = phaseHeartRates.max() ?? 0
        }

        let duration = phase.duration
        if duration > 0 {
            phase.averageSpeed = phase.distance / duration
        }

        Log.tracking.info("Ended phase: \(phase.phaseType.rawValue), duration: \(Int(duration))s")
        currentPhase = nil
    }

    func recordPhaseHeartRate(_ hr: Int) {
        if currentPhase != nil {
            phaseHeartRates.append(hr)
        }
    }

    // MARK: - XC Timing

    private func processXCTimingAlerts(elapsedTime: TimeInterval) {
        let currentMinute = Int(elapsedTime) / 60
        let secondsIntoMinute = Int(elapsedTime) % 60

        // Triple haptic + beep 10 seconds before each minute marker
        if secondsIntoMinute == 50 && currentMinute >= lastMinuteMarker {
            lastMinuteMarker = currentMinute + 1
            audioCoach.announceXCMinuteWarning(minute: currentMinute + 1)
        }

        // Time fault warning
        let timeDiff = abs(xcTimeDifference)
        if timeDiff > 20 {
            audioCoach.announceXCTimeFault(secondsOff: Int(xcTimeDifference))
        }

        // Speeding penalty warning
        if xcTimeDifference < -15 {
            audioCoach.announceXCSpeedingWarning()
        }
    }

    // MARK: - XC/Gradient Formatters

    var xcTimeDifferenceFormatted: String {
        let diff = xcTimeDifference
        let absDiff = abs(Int(diff))
        if diff > 0 {
            return "+\(absDiff)s"
        } else if diff < 0 {
            return "-\(absDiff)s"
        }
        return "0s"
    }

    var currentGradientFormatted: String {
        if currentGradient > 0 {
            return String(format: "+%.0f%%", currentGradient)
        } else if currentGradient < 0 {
            return String(format: "%.0f%%", currentGradient)
        }
        return "0%"
    }

    // MARK: - Motion Callbacks

    private func setupMotionCallback() {
        motionManager.onMotionUpdate = { [weak self] sample in
            guard let self else { return }
            self.lastMotionSampleTime = Date()
            if self.isUsingGPSGaitFallback {
                self.isUsingGPSGaitFallback = false
                Log.tracking.info("CoreMotion resumed - switching back from GPS gait fallback")
            }
            self.handleMotion(sample)
        }

        motionManager.onMotionResumed = { [weak self] in
            guard self != nil else { return }
            Log.tracking.info("CoreMotion delivery resumed after gap")
        }
    }

    private func setupGaitCallback() {
        gaitAnalyzer.onGaitChange = { [weak self] from, to in
            guard let self else { return }
            self.transitionAnalyzer.processGaitChange(from: from, to: to)

            if to != self.lastAnnouncedGait {
                self.audioCoach.processGaitChange(from: from, to: to)
                self.lastAnnouncedGait = to
            }
        }
    }

    private func setupReinCallback() {
        reinAnalyzer.onReinChange = { [weak self] _, newRein in
            guard let self else { return }
            self.symmetryAnalyzer.finalizeReinSegment()
            self.rhythmAnalyzer.updateRein(newRein)
        }
    }

    private func handleMotion(_ sample: MotionSample) {
        guard _weakTracker?.sessionState == .tracking else { return }

        gaitAnalyzer.processMotion(sample)

        leadAnalyzer.processMotionSample(sample, currentGait: currentGait)
        currentLead = leadAnalyzer.currentLead
        gaitAnalyzer.updateLead(leadAnalyzer.currentLead, confidence: leadAnalyzer.currentConfidence)

        reinAnalyzer.processMotion(sample)
        currentRein = reinAnalyzer.currentRein

        symmetryAnalyzer.processMotionSample(sample, currentRein: currentRein)
        currentSymmetry = symmetryAnalyzer.currentSymmetryScore

        rhythmAnalyzer.processMotionSample(sample, currentGait: currentGait)
        currentRhythm = rhythmAnalyzer.currentRhythmScore

        gaitAnalyzer.updateRhythm(currentRhythm)

        leadAnalyzer.configure(strideFrequency: gaitAnalyzer.strideFrequency)
        leadQuality = leadAnalyzer.leadQuality
        gaitConfidence = gaitAnalyzer.gaitConfidence
        strideFrequency = gaitAnalyzer.strideFrequency

        // Fall detection processing
        if let tracker = _weakTracker {
            tracker.fallDetectionManager.processMotionSample(sample)
        }
    }

    // MARK: - Watch Gait Enhancement

    private func setupWatchGaitEnhancement() {
        watchGaitEnhancementTask?.cancel()
        watchGaitEnhancementTask = Task { @MainActor [weak self] in
            let wm = WatchConnectivityManager.shared
            var lastSeq = wm.enhancedSensorSequence
            while !Task.isCancelled {
                await withCheckedContinuation { cont in
                    withObservationTracking { _ = wm.enhancedSensorSequence }
                        onChange: { cont.resume() }
                }
                guard let self, !Task.isCancelled else { break }
                guard wm.enhancedSensorSequence != lastSeq else { continue }
                lastSeq = wm.enhancedSensorSequence

                let rollVariance = self.watchSensorAnalyzer.postureStability / 100.0
                let armSymmetry = 1.0 - min(1.0, abs(wm.postureRoll) / 30.0)
                let yawEnergy = self.watchSensorAnalyzer.movementIntensity / 100.0

                self.gaitAnalyzer.updateWatchData(
                    armSymmetry: max(0, min(1, armSymmetry * rollVariance)),
                    yawEnergy: max(0, min(1, yawEnergy))
                )
            }
        }
    }

    // MARK: - Voice Note Observation

    private func setupVoiceNoteObservation() {
        // Voice notes are observed by SessionTracker's watchVoiceNoteTask.
        // Here we set up the handler for when notes arrive.
        // The RidingPlugin handles voice notes directly when the watch note arrives.
        Task { @MainActor [weak self] in
            let wm = WatchConnectivityManager.shared
            var lastSeq = wm.voiceNoteSequence
            while !Task.isCancelled {
                await withCheckedContinuation { cont in
                    withObservationTracking { _ = wm.voiceNoteSequence }
                        onChange: { cont.resume() }
                }
                guard let self, !Task.isCancelled else { break }
                guard wm.voiceNoteSequence != lastSeq else { continue }
                lastSeq = wm.voiceNoteSequence
                guard let noteText = wm.lastVoiceNoteText,
                      let ride = self.currentRide else { continue }
                let service = VoiceNotesService.shared
                ride.notes = service.appendNote(noteText, to: ride.notes)
                var currentNotes = ride.voiceNotes
                currentNotes.append(noteText)
                ride.voiceNotes = currentNotes
            }
        }
    }

    // MARK: - Post-Session Summary

    private func generatePostSessionSummary(for ride: Ride) {
        let summaryService = PostSessionSummaryService.shared
        let voiceNotes = ride.voiceNotes

        Task {
            let summary: SessionSummary
            if #available(iOS 26.0, *) {
                do {
                    summary = try await summaryService.generateRideSummary(
                        ride: ride,
                        voiceNotes: voiceNotes
                    )
                } catch {
                    summary = summaryService.generateFallbackRideSummary(
                        ride: ride,
                        voiceNotes: voiceNotes
                    )
                }
            } else {
                summary = summaryService.generateFallbackRideSummary(
                    ride: ride,
                    voiceNotes: voiceNotes
                )
            }

            await MainActor.run {
                ride.aiSummary = summary
                do {
                    try modelContext?.save()
                } catch {
                    Log.services.error("Failed to save AI summary: \(error)")
                }
            }

            await MainActor.run {
                summaryService.readSummaryAloud(summary, brief: false)
            }

            Log.services.info("Post-session summary generated and announced")
        }
    }
}
