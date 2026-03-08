//
//  RidingPlugin.swift
//  TetraTrack
//
//  Riding-specific session logic extracted from RideTracker.
//  All riding analyzers, gait tracking, fall detection, showjumping phases,
//  XC timing, and dressage test state live here.
//

import SwiftData
import CoreLocation
import HealthKit
import Observation
import UIKit
import os

@Observable
@MainActor
final class RidingPlugin: DisciplinePlugin {
    let discipline: Discipline = .riding
    let needsGPS: Bool = true
    let needsMotion: Bool = true

    var workoutConfig: HKWorkoutConfiguration {
        let config = HKWorkoutConfiguration()
        config.activityType = .equestrianSports
        config.locationType = selectedRideType.isIndoor ? .indoor : .outdoor
        return config
    }

    // MARK: - Riding State (observed by views)

    var currentRide: Ride?
    var selectedRideType: RideType = .hack
    var selectedHorse: Horse?
    var phoneMountPosition: PhoneMountPosition = .jodhpurThigh

    // Gait
    var currentGait: GaitType = .stationary
    var walkTime: TimeInterval = 0 { didSet { invalidateGaitCache() } }
    var trotTime: TimeInterval = 0 { didSet { invalidateGaitCache() } }
    var canterTime: TimeInterval = 0 { didSet { invalidateGaitCache() } }
    var gallopTime: TimeInterval = 0 { didSet { invalidateGaitCache() } }
    private var lastGaitUpdateTime: Date?
    private var _cachedGaitPercentages: (walk: Double, trot: Double, canter: Double, gallop: Double)?

    private func invalidateGaitCache() {
        _cachedGaitPercentages = nil
    }

    var totalMovingTime: TimeInterval {
        walkTime + trotTime + canterTime + gallopTime
    }

    var gaitPercentages: (walk: Double, trot: Double, canter: Double, gallop: Double) {
        if let cached = _cachedGaitPercentages { return cached }
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

    // Rein percentages
    var reinPercentages: (left: Double, right: Double) {
        let total = reinAnalyzer.totalLeftReinDuration + reinAnalyzer.totalRightReinDuration
        guard total > 0 else { return (0, 0) }
        return (
            (reinAnalyzer.totalLeftReinDuration / total) * 100,
            (reinAnalyzer.totalRightReinDuration / total) * 100
        )
    }

    var leftReinPercent: Double { reinPercentages.left }
    var rightReinPercent: Double { reinPercentages.right }

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

    // Live metrics
    var currentLead: Lead = .unknown
    var currentRein: ReinDirection = .straight
    var currentSymmetry: Double = 0.0
    var currentRhythm: Double = 0.0
    var strideFrequency: Double = 0.0
    var gaitConfidence: Double = 0.0
    var leadQuality: Double = 0.0

    // Phase tracking (showjumping)
    var currentPhase: RidePhase?
    var currentPhaseType: RidePhaseType = .warmup
    private var phaseStartDistance: Double = 0
    private(set) var phaseStartJumpCount: Int = 0
    private var phaseHeartRates: [Int] = []

    // Dressage test practice
    var selectedDressageTest: DressageTest?
    var currentMovementIndex: Int = 0
    var movementScores: [Int] = []

    // XC
    var xcOptimumTime: TimeInterval = 0
    var xcCourseDistance: Double = 0
    private var lastMinuteMarker: Int = 0

    var xcTimeDifference: TimeInterval {
        guard xcOptimumTime > 0, xcCourseDistance > 0, let tracker else { return 0 }
        guard tracker.totalDistance > 0 else { return 0 }
        let expectedTimeAtDistance = (tracker.totalDistance / xcCourseDistance) * xcOptimumTime
        return tracker.elapsedTime - expectedTimeAtDistance
    }

    var xcIsAheadOfTime: Bool { xcTimeDifference < 0 }

    var currentGradient: Double = 0.0
    private var recentAltitudes: [(altitude: Double, distance: Double)] = []

    // Watch sensor metrics
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

    var rideCalibrationStatus: GaitAnalyzer.CalibrationStatus {
        gaitAnalyzer.calibrationStatus
    }

    // GPS gait fallback
    var isUsingGPSGaitFallback: Bool = false
    private var lastMotionSampleTime: Date?
    private let motionGapThreshold: TimeInterval = 3.0

    // Fall detection
    var fallDetected: Bool = false
    var fallAlertCountdown: Int = 30
    var showingFallAlert: Bool = false

    // Vehicle detection
    var showingVehicleAlert: Bool = false
    private var highSpeedStartTime: Date?
    private let vehicleSpeedThreshold: Double = 17.0
    private let vehicleDetectionDuration: TimeInterval = 10

    // Fall detection callbacks
    var onFallDetected: (() -> Void)?
    var onFallCountdownTick: ((Int) -> Void)?
    var onEmergencyAlert: ((CLLocationCoordinate2D?) -> Void)?

    // MARK: - Analyzers (private)

    private let gaitAnalyzer = GaitAnalyzer()
    private let turnAnalyzer = TurnAnalyzer()
    private let motionManager = MotionManager()
    private let leadAnalyzer = LeadAnalyzer()
    private let transitionAnalyzer = TransitionAnalyzer()
    private let reinAnalyzer = ReinAnalyzer()
    private let symmetryAnalyzer = SymmetryAnalyzer()
    private let rhythmAnalyzer = RhythmAnalyzer()
    private let watchSensorAnalyzer = WatchSensorAnalyzer.shared
    private let healthCoordinator = RideHealthCoordinator()
    private let fallDetectionManager: FallDetectionManager
    private let weatherService: WeatherService
    private let pocketModeManager = PocketModeManager.shared
    private var lastAnnouncedGait: GaitType = .stationary

    private weak var tracker: SessionTracker?
    private var lastLocation: CLLocation?
    private var lastCoordinate: CLLocationCoordinate2D?
    private var startTime: Date?

    // Watch gait enhancement task
    private var watchGaitEnhancementTask: Task<Void, Never>?

    // MARK: - Init

    init(
        rideType: RideType = .hack,
        fallDetection: FallDetectionManager = .shared,
        weatherService: WeatherService = .shared
    ) {
        self.selectedRideType = rideType
        self.fallDetectionManager = fallDetection
        self.weatherService = weatherService
        setupMotionCallback()
        setupGaitCallback()
        setupReinCallback()
        setupFallDetection()
    }

    // MARK: - DisciplinePlugin Lifecycle

    func configure(tracker: SessionTracker) async {
        self.tracker = tracker

        // Create new ride
        let ride = Ride()
        ride.startDate = Date()
        ride.name = Ride.defaultName(for: ride.startDate)
        ride.rideType = selectedRideType
        ride.horse = selectedHorse
        currentRide = ride

        if let ctx = tracker.modelContext {
            ctx.insert(ride)
            gaitAnalyzer.configure(with: ctx)
            fallDetectionManager.configure(modelContext: ctx, heartRateService: HeartRateService())
            do {
                try ctx.save()
            } catch {
                Log.tracking.error("Failed to save initial ride: \(error)")
            }
        }

        // Reset riding state
        currentGait = .stationary
        currentLead = .unknown
        currentRein = .straight
        currentSymmetry = 0.0
        currentRhythm = 0.0
        walkTime = 0
        trotTime = 0
        canterTime = 0
        gallopTime = 0
        lastGaitUpdateTime = nil
        lastLocation = nil
        lastCoordinate = nil
        isUsingGPSGaitFallback = false
        lastMotionSampleTime = nil
        startTime = Date()
        lastAnnouncedGait = .stationary

        // Configure analyzers
        gaitAnalyzer.startAnalyzing(for: ride)
        turnAnalyzer.reset()
        leadAnalyzer.reset()
        transitionAnalyzer.reset()
        reinAnalyzer.reset()
        symmetryAnalyzer.reset()
        rhythmAnalyzer.reset()
        watchSensorAnalyzer.startSession(discipline: .riding)

        if let horse = selectedHorse {
            gaitAnalyzer.configure(for: horse)
        }

        if selectedRideType == .gaitTesting {
            gaitAnalyzer.collectDiagnostics = true
        }

        ride.phoneMountPosition = phoneMountPosition
        gaitAnalyzer.configure(mountPosition: phoneMountPosition)
        motionManager.configureForPlacement(phoneMountPosition)
        leadAnalyzer.configure(phoneMountPosition: phoneMountPosition)

        gaitAnalyzer.onCalibrationComplete = {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }

    func didStart() async {
        // Start motion updates
        motionManager.startUpdates()

        // Start fall detection
        fallDetectionManager.startMonitoring()

        // Start pocket mode
        pocketModeManager.startMonitoring()

        // Watch gait enhancement
        setupWatchGaitEnhancement()

        // Watch discipline session
        WatchConnectivityManager.shared.startSession(discipline: .riding)

        // Fetch weather
        await fetchWeatherForRide()

        // Audio coaching
        tracker?.audioCoach.resetSafetyStatus()

        // Auto-start warmup for showjumping
        if selectedRideType == .showjumping {
            startPhase(.warmup)
        }

        // Disable auto calorie collection — gait-adjusted calories are more accurate
        tracker?.workoutLifecycle.disableAutoCalories()
    }

    func willPause() {
        motionManager.stopUpdates()
    }

    func didResume() {
        motionManager.startUpdates()
    }

    func finalize() async {
        // Stop motion and analyzers
        motionManager.stopUpdates()
        fallDetectionManager.stopMonitoring()
        pocketModeManager.stopMonitoring()
        gaitAnalyzer.stopAnalyzing()
        watchSensorAnalyzer.stopSession()
        watchGaitEnhancementTask?.cancel()
        watchGaitEnhancementTask = nil

        // Finalize symmetry/rhythm
        symmetryAnalyzer.finalizeReinSegment()
        rhythmAnalyzer.finalizeReinSegment()

        // End any active phase
        endCurrentPhase()

        guard let ride = currentRide, let tracker else { return }

        ride.endDate = Date()
        ride.totalDistance = tracker.totalDistance
        ride.totalDuration = tracker.elapsedTime

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

        // Create rein segment records
        if let ctx = tracker.modelContext {
            for segmentData in reinAnalyzer.getSegmentData() {
                let segment = ReinSegment(direction: segmentData.direction, startTime: segmentData.startTime)
                segment.endTime = segmentData.endTime
                segment.distance = segmentData.distance
                segment.ride = ride
                ctx.insert(segment)
            }

            // Create gait transition records
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

        // Heart rate data
        let hrStats = healthCoordinator.getFinalStatistics()
        ride.averageHeartRate = hrStats.averageBPM
        ride.maxHeartRate = hrStats.maxBPM
        ride.minHeartRate = hrStats.minBPM
        ride.heartRateSamples = Array(hrStats.samples)

        // Stride frequency
        ride.averageStrideFrequency = strideFrequency

        // Watch sensor metrics
        let ridingSummary = watchSensorAnalyzer.getRidingSummary()
        ride.detectedJumpCount = ridingSummary.jumpCount
        ride.activeTimePercent = ridingSummary.activePercent

        // Gait diagnostics
        if selectedRideType == .gaitTesting && !gaitAnalyzer.diagnosticEntries.isEmpty {
            ride.gaitDiagnostics = gaitAnalyzer.diagnosticEntries
        }

        // Max speed
        if let gpsTracker = tracker.gpsTracker as GPSSessionTracker? {
            ride.maxSpeed = gpsTracker.maxSpeed
        }
        ride.elevationGain = tracker.elevationGain
        ride.elevationLoss = tracker.elevationLoss

        // Recovery analysis
        if hrStats.maxBPM > 0 {
            await healthCoordinator.startRecoveryAnalysis(peakHeartRate: hrStats.maxBPM)
        }

        // Save
        do {
            try tracker.modelContext?.save()
        } catch {
            Log.tracking.error("Failed to save ride data: \(error)")
        }

        // Skill domain scores
        if let ctx = tracker.modelContext {
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

        // Learn gait characteristics
        if let horse = ride.horse {
            let learningService = GaitLearningService()
            learningService.learnFromRide(ride, horse: horse)
        }

        // Transfer coaching notes
        if tracker.isSharingWithFamily, let session = tracker.sharingCoordinator.mySession {
            let notes = session.coachingNotes
            if !notes.isEmpty {
                ride.coachingNotes = notes
            }
        }

        // Post-session summary
        generatePostSessionSummary(for: ride)

        // Convert to TrainingArtifact
        Task {
            await ArtifactConversionService.shared.convertAndSyncRide(ride)
        }

        // End weather
        if let location = tracker.locationManager.currentLocation {
            Task {
                do {
                    let endWeather = try await self.weatherService.fetchWeather(for: location)
                    await MainActor.run {
                        ride.endWeather = endWeather
                        try? tracker.modelContext?.save()
                    }
                } catch {
                    Log.services.error("Failed to fetch end weather: \(error)")
                }
            }
        }

        // Reset health coordinator
        healthCoordinator.stopMonitoring()
        healthCoordinator.resetState()
    }

    func reset() {
        motionManager.stopUpdates()
        fallDetectionManager.stopMonitoring()
        pocketModeManager.stopMonitoring()
        gaitAnalyzer.stopAnalyzing()
        watchSensorAnalyzer.stopSession()
        watchGaitEnhancementTask?.cancel()
        watchGaitEnhancementTask = nil
        healthCoordinator.stopMonitoring()
        healthCoordinator.resetState()

        // Delete ride if discarding
        if let ride = currentRide, let ctx = tracker?.modelContext {
            ctx.delete(ride)
            try? ctx.save()
        }

        currentRide = nil
        currentGait = .stationary
        currentLead = .unknown
        currentRein = .straight
        currentSymmetry = 0.0
        currentRhythm = 0.0
        strideFrequency = 0
        currentPhase = nil
        currentPhaseType = .warmup
        phaseStartDistance = 0
        phaseStartJumpCount = 0
        phaseHeartRates = []
        selectedDressageTest = nil
        currentMovementIndex = 0
        movementScores = []
    }

    // MARK: - DisciplinePlugin Data Processing

    func processLocation(_ location: CLLocation, distanceDelta: Double) {
        guard let tracker, let ride = currentRide else { return }

        // Track max speed
        if tracker.gpsTracker.maxSpeed > ride.maxSpeed {
            ride.maxSpeed = tracker.gpsTracker.maxSpeed
        }

        // Sync elevation to ride model
        ride.elevationGain = tracker.elevationGain
        ride.elevationLoss = tracker.elevationLoss

        // Gradient calculation
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

        // GPS-only gait fallback
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

        // Track gait time
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

        // Update transition analyzer with speed
        transitionAnalyzer.updateSpeed(tracker.currentSpeed)

        lastLocation = location

        // Fall detection location update
        fallDetectionManager.updateLocation(location.coordinate)

        // Vehicle detection
        checkForVehicleSpeed(tracker.currentSpeed)
    }

    func processMotion(_ sample: MotionSample) {
        guard tracker?.sessionState == .tracking else { return }

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

        fallDetectionManager.processMotionSample(sample)
    }

    func processHeartRate(_ bpm: Int) {
        healthCoordinator.processHeartRate(bpm)
        recordPhaseHeartRate(bpm)
    }

    func timerTick(elapsed: TimeInterval) {
        guard let tracker else { return }

        // Safety status
        tracker.audioCoach.processSafetyStatus(
            elapsedTime: elapsed,
            fallDetectionActive: fallDetectionManager.isMonitoring
        )

        // XC timing alerts
        if selectedRideType == .crossCountry && xcOptimumTime > 0 {
            processXCTimingAlerts(elapsed: elapsed)
        }
    }

    // MARK: - DisciplinePlugin Persistence

    func persistLocationPoint(_ location: CLLocation, in context: ModelContext) {
        guard let ride = currentRide else { return }
        let point = LocationPoint(from: location)
        point.ride = ride
        context.insert(point)
    }

    // MARK: - DisciplinePlugin HealthKit

    func buildHealthKitEnrichment() async -> (events: [HKWorkoutEvent], samples: [HKSample], metadata: [String: Any]) {
        var events: [HKWorkoutEvent] = []
        var samples: [HKSample] = []

        // Gait transition markers
        let transitions = transitionAnalyzer.getTransitionModels()
        for transition in transitions {
            let interval = DateInterval(start: transition.timestamp, duration: 0)
            let event = HKWorkoutEvent(type: .marker, dateInterval: interval, metadata: [
                "GaitFrom": transition.from.rawValue,
                "GaitTo": transition.to.rawValue,
                "TransitionQuality": transition.quality
            ])
            events.append(event)
        }

        // Gait segment events
        if let rideStart = startTime {
            var segmentStart = rideStart
            let gaitDurations: [(GaitType, TimeInterval)] = [
                (.walk, walkTime), (.trot, trotTime), (.canter, canterTime), (.gallop, gallopTime)
            ]
            for (gait, duration) in gaitDurations where duration > 1 {
                let segmentEnd = segmentStart.addingTimeInterval(duration)
                let interval = DateInterval(start: segmentStart, end: segmentEnd)
                let event = HKWorkoutEvent(type: .segment, dateInterval: interval, metadata: [
                    "Gait": gait.rawValue
                ])
                events.append(event)
                segmentStart = segmentEnd
            }
        }

        // Per-gait calorie samples
        let riderWeight = HealthKitManager.shared.healthKitWeight ?? 70.0
        if let rideStart = startTime {
            var sampleStart = rideStart
            let gaitDurations: [(GaitType, TimeInterval)] = [
                (.walk, walkTime), (.trot, trotTime), (.canter, canterTime), (.gallop, gallopTime)
            ]
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
                samples.append(sample)
                sampleStart = sampleEnd
            }
        }

        // Metadata
        var metadata: [String: Any] = [
            HKMetadataKeyIndoorWorkout: false
        ]
        if let horseName = selectedHorse?.name {
            metadata["HorseName"] = horseName
        }
        metadata["RideType"] = selectedRideType.rawValue
        if let tracker, tracker.elevationGain > 0 {
            metadata[HKMetadataKeyElevationAscended] = HKQuantity(unit: .meter(), doubleValue: tracker.elevationGain)
        }

        return (events, samples, metadata)
    }

    // MARK: - DisciplinePlugin Watch

    func watchStatusPayload() -> [String: Any] {
        guard let tracker else { return [:] }

        let gaits = gaitPercentages
        let reins = reinPercentages
        let leads = leadPercentages

        var payload: [String: Any] = [
            "gait": currentGait.rawValue,
            "horseName": selectedHorse?.name as Any,
            "rideType": selectedRideType.rawValue
        ]

        switch selectedRideType {
        case .hack, .showjumping, .gaitTesting:
            payload["walkPercent"] = gaits.walk
            payload["trotPercent"] = gaits.trot
            payload["canterPercent"] = gaits.canter
            payload["gallopPercent"] = gaits.gallop
            payload["elevation"] = tracker.currentElevation

        case .schooling, .dressage:
            payload["walkPercent"] = gaits.walk
            payload["trotPercent"] = gaits.trot
            payload["canterPercent"] = gaits.canter
            payload["leftReinPercent"] = reins.left
            payload["rightReinPercent"] = reins.right
            payload["leftLeadPercent"] = leads.left
            payload["rightLeadPercent"] = leads.right
            payload["symmetryScore"] = currentSymmetry
            payload["rhythmScore"] = currentRhythm

        case .crossCountry:
            payload["trotPercent"] = gaits.trot
            payload["canterPercent"] = gaits.canter
            payload["gallopPercent"] = gaits.gallop
            payload["optimalTime"] = xcOptimumTime
            payload["timeDifference"] = xcTimeDifference
            payload["elevation"] = tracker.currentElevation
        }

        return payload
    }

    // MARK: - Phase Tracking (Showjumping)

    func startPhase(_ type: RidePhaseType) {
        endCurrentPhase()

        let phase = RidePhase(phaseType: type)
        currentPhase = phase
        currentPhaseType = type
        phaseStartDistance = tracker?.totalDistance ?? 0
        phaseStartJumpCount = jumpCount
        phaseHeartRates = []

        if let ride = currentRide {
            if ride.phases == nil { ride.phases = [] }
            ride.phases?.append(phase)
        }
    }

    func endCurrentPhase() {
        guard let phase = currentPhase else { return }
        phase.endDate = Date()
        phase.distance = (tracker?.totalDistance ?? 0) - phaseStartDistance
        phase.jumpCount = jumpCount - phaseStartJumpCount

        if !phaseHeartRates.isEmpty {
            phase.averageHeartRate = phaseHeartRates.reduce(0, +) / phaseHeartRates.count
            phase.maxHeartRate = phaseHeartRates.max() ?? 0
        }

        let duration = phase.duration
        if duration > 0 {
            phase.averageSpeed = phase.distance / duration
        }

        currentPhase = nil
    }

    func recordPhaseHeartRate(_ hr: Int) {
        if currentPhase != nil {
            phaseHeartRates.append(hr)
        }
    }

    // MARK: - Fall Detection

    func confirmFallOK() {
        fallDetectionManager.confirmOK()
    }

    func requestEmergencyHelp() {
        fallDetectionManager.requestEmergency()
    }

    // MARK: - Vehicle Detection

    func dismissVehicleAlert() {
        showingVehicleAlert = false
        highSpeedStartTime = nil
    }

    private func checkForVehicleSpeed(_ speed: Double) {
        if speed > vehicleSpeedThreshold {
            if highSpeedStartTime == nil {
                highSpeedStartTime = Date()
            } else if let start = highSpeedStartTime,
                      Date().timeIntervalSince(start) > vehicleDetectionDuration {
                if !showingVehicleAlert {
                    showingVehicleAlert = true
                    tracker?.audioCoach.announce("It looks like you may be in a vehicle. Would you like to stop tracking?")
                }
            }
        } else {
            highSpeedStartTime = nil
        }
    }

    // MARK: - XC Timing

    private func processXCTimingAlerts(elapsed: TimeInterval) {
        let currentMinute = Int(elapsed) / 60
        let secondsIntoMinute = Int(elapsed) % 60

        if secondsIntoMinute == 50 && currentMinute >= lastMinuteMarker {
            lastMinuteMarker = currentMinute + 1
            tracker?.audioCoach.announceXCMinuteWarning(minute: currentMinute + 1)
        }

        let timeDiff = abs(xcTimeDifference)
        if timeDiff > 20 {
            tracker?.audioCoach.announceXCTimeFault(secondsOff: Int(xcTimeDifference))
        }

        if xcTimeDifference < -15 {
            tracker?.audioCoach.announceXCSpeedingWarning()
        }
    }

    // MARK: - Weather

    private func fetchWeatherForRide() async {
        guard let tracker, let location = tracker.locationManager.currentLocation else {
            tracker?.weatherError = "Location not available"
            return
        }

        do {
            let weather = try await weatherService.fetchWeather(for: location)
            guard weather.temperature != 0 || weather.humidity != 0 else {
                tracker.weatherError = "Invalid weather data received"
                return
            }
            tracker.currentWeather = weather
            currentRide?.startWeather = weather
            tracker.weatherError = nil
        } catch {
            tracker.weatherError = error.localizedDescription
            Log.services.error("Failed to fetch weather: \(error)")
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
                try? tracker?.modelContext?.save()
            }

            await MainActor.run {
                summaryService.readSummaryAloud(summary, brief: false)
            }
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

    // MARK: - Motion Callbacks

    private func setupMotionCallback() {
        motionManager.onMotionUpdate = { [weak self] sample in
            guard let self else { return }
            self.lastMotionSampleTime = Date()
            if self.isUsingGPSGaitFallback {
                self.isUsingGPSGaitFallback = false
                Log.tracking.info("CoreMotion resumed - switching back from GPS gait fallback")
            }
            self.processMotion(sample)
        }

        motionManager.onMotionResumed = {
            Log.tracking.info("CoreMotion delivery resumed after gap")
        }
    }

    private func setupGaitCallback() {
        gaitAnalyzer.onGaitChange = { [weak self] from, to in
            guard let self else { return }
            self.transitionAnalyzer.processGaitChange(from: from, to: to)

            if to != self.lastAnnouncedGait {
                self.tracker?.audioCoach.processGaitChange(from: from, to: to)
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

    private func setupFallDetection() {
        fallDetectionManager.onFallDetected = { [weak self] in
            guard let self else { return }
            self.fallDetected = true
            self.showingFallAlert = true
            self.onFallDetected?()
        }

        fallDetectionManager.onCountdownTick = { [weak self] seconds in
            guard let self else { return }
            self.fallAlertCountdown = seconds
            self.onFallCountdownTick?(seconds)
        }

        fallDetectionManager.onEmergencyAlert = { [weak self] location in
            guard let self else { return }
            self.onEmergencyAlert?(location)
        }

        fallDetectionManager.onFallDismissed = { [weak self] in
            guard let self else { return }
            self.fallDetected = false
            self.showingFallAlert = false
            self.fallAlertCountdown = 30
        }
    }

    // MARK: - Formatters (XC-specific)

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
}
