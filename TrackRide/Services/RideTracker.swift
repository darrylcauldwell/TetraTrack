//
//  RideTracker.swift
//  TrackRide
//

import SwiftData
import CoreLocation
import HealthKit
import Observation
import os

@Observable
final class RideTracker {
    // Current state
    var rideState: RideState = .idle
    var currentRide: Ride?
    var elapsedTime: TimeInterval = 0
    var totalDistance: Double = 0
    var currentSpeed: Double = 0  // m/s
    var currentGait: GaitType = .stationary
    var currentElevation: Double = 0  // meters
    var elevationGain: Double = 0
    var elevationLoss: Double = 0

    // Live gait time tracking
    var walkTime: TimeInterval = 0 { didSet { invalidateGaitCache() } }
    var trotTime: TimeInterval = 0 { didSet { invalidateGaitCache() } }
    var canterTime: TimeInterval = 0 { didSet { invalidateGaitCache() } }
    var gallopTime: TimeInterval = 0 { didSet { invalidateGaitCache() } }
    private var lastGaitUpdateTime: Date?

    // Cached gait percentages - invalidated when gait times change
    private var _cachedGaitPercentages: (walk: Double, trot: Double, canter: Double, gallop: Double)?

    private func invalidateGaitCache() {
        _cachedGaitPercentages = nil
    }

    // Computed gait percentages - batch computed to avoid redundant totalMovingTime calculations
    var totalMovingTime: TimeInterval {
        walkTime + trotTime + canterTime + gallopTime
    }

    /// Batch computation of all gait percentages (cached for efficiency)
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

    // Live rein percentages - batch computed
    /// Batch computation of rein percentages
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

    // Live turn percentages - batch computed with cached turnStats access
    /// Batch computation of turn percentages and total
    var turnPercentages: (left: Double, right: Double, total: Int) {
        let stats = turnAnalyzer.turnStats
        let total = stats.leftTurns + stats.rightTurns
        guard total > 0 else { return (0, 0, 0) }
        let totalDouble = Double(total)
        return (
            (Double(stats.leftTurns) / totalDouble) * 100,
            (Double(stats.rightTurns) / totalDouble) * 100,
            total
        )
    }

    var leftTurnPercent: Double { turnPercentages.left }
    var rightTurnPercent: Double { turnPercentages.right }
    var totalTurns: Int { turnPercentages.total }

    // Live lead percentages - batch computed
    /// Batch computation of lead percentages
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

    // Ride type selection
    var selectedRideType: RideType = .hack

    // Horse selection
    var selectedHorse: Horse?

    // Live metrics
    var currentLead: Lead = .unknown
    var currentRein: ReinDirection = .straight
    var currentSymmetry: Double = 0.0
    var currentRhythm: Double = 0.0

    // MARK: - Biomechanics Metrics (Physics-Based)

    /// Current stride length in meters
    var strideLength: Double = 0.0

    /// Current stride frequency in Hz
    var strideFrequency: Double = 0.0

    /// Current stride speed in m/s (stride × frequency)
    var strideSpeed: Double = 0.0

    /// Current impulsion (0-100)
    var impulsion: Double = 0.0

    /// Current engagement (0-100)
    var engagement: Double = 0.0

    /// Current straightness (0-100)
    var straightness: Double = 0.0

    /// Current rider stability (0-100)
    var riderStability: Double = 0.0

    /// Cumulative training load
    var trainingLoad: Double = 0.0

    /// Gait confidence from HMM (0-1)
    var gaitConfidence: Double = 0.0

    /// Lead quality from phase analysis
    var leadQuality: Double = 0.0

    // Heart rate metrics
    var currentHeartRate: Int = 0
    var averageHeartRate: Int = 0
    var maxHeartRate: Int = 0
    var currentHeartRateZone: HeartRateZone = .zone1

    // Cross Country specific - Optimum Time
    var xcOptimumTime: TimeInterval = 0  // Target time in seconds (set before ride)
    var xcCourseDistance: Double = 0  // Course distance in meters (set before ride)
    private var lastMinuteMarker: Int = 0  // Track last announced minute

    // Weather state
    var currentWeather: WeatherConditions?
    var weatherError: String?

    // Computed XC metrics
    var xcTimeDifference: TimeInterval {
        guard xcOptimumTime > 0, xcCourseDistance > 0, totalDistance > 0 else { return 0 }
        // Calculate expected time at current distance
        let expectedTimeAtDistance = (totalDistance / xcCourseDistance) * xcOptimumTime
        return elapsedTime - expectedTimeAtDistance
    }

    var xcIsAheadOfTime: Bool {
        xcTimeDifference < 0
    }

    // Current gradient (percentage)
    var currentGradient: Double = 0.0
    private var recentAltitudes: [(altitude: Double, distance: Double)] = []

    // MARK: - Watch Sensor Metrics (from WatchSensorAnalyzer)

    /// Jump count from altitude detection
    var jumpCount: Int { watchSensorAnalyzer.jumpCount }

    /// Rider posture stability (0-100)
    var postureStability: Double { watchSensorAnalyzer.postureStability }

    /// Current fatigue score (0-100)
    var fatigueScore: Double { watchSensorAnalyzer.fatigueScore }

    /// Current breathing rate (breaths per minute)
    var breathingRate: Double { watchSensorAnalyzer.breathingRate }

    /// Tremor level (0-100)
    var tremorLevel: Double { watchSensorAnalyzer.tremorLevel }

    /// Movement intensity (0-100)
    var movementIntensity: Double { watchSensorAnalyzer.movementIntensity }

    /// Active riding time (high intensity)
    var activeRidingTime: TimeInterval { watchSensorAnalyzer.activeTime }

    /// Passive riding time (low intensity)
    var passiveRidingTime: TimeInterval { watchSensorAnalyzer.passiveTime }

    /// Active riding percentage
    var activeRidingPercent: Double {
        let total = activeRidingTime + passiveRidingTime
        guard total > 0 else { return 50 }
        return (activeRidingTime / total) * 100
    }

    /// Compass-detected turns
    var compassTurnCount: Int { watchSensorAnalyzer.compassTurns.count }

    /// Relative altitude from session start
    var sensorRelativeAltitude: Double { watchSensorAnalyzer.relativeAltitude }

    /// Sensor-based elevation gain
    var sensorElevationGain: Double { watchSensorAnalyzer.totalElevationGain }

    /// Sensor-based elevation loss
    var sensorElevationLoss: Double { watchSensorAnalyzer.totalElevationLoss }

    // Family sharing
    var isSharingWithFamily: Bool = false

    // Fall detection
    var fallDetected: Bool = false
    var fallAlertCountdown: Int = 30
    var showingFallAlert: Bool = false

    // Vehicle detection
    var showingVehicleAlert: Bool = false
    private var highSpeedStartTime: Date?
    private let vehicleSpeedThreshold: Double = 17.0  // ~60 km/h for riding
    private let vehicleDetectionDuration: TimeInterval = 10  // 10 seconds sustained

    // Fall detection callbacks
    var onFallDetected: (() -> Void)?
    var onFallCountdownTick: ((Int) -> Void)?
    var onEmergencyAlert: ((CLLocationCoordinate2D?) -> Void)?

    private let locationManager: LocationManager
    private let gaitAnalyzer = GaitAnalyzer()
    private let turnAnalyzer = TurnAnalyzer()

    // New analyzers
    private let motionManager = MotionManager()
    private let leadAnalyzer = LeadAnalyzer()
    private let transitionAnalyzer = TransitionAnalyzer()
    private let reinAnalyzer = ReinAnalyzer()
    private let symmetryAnalyzer = SymmetryAnalyzer()
    private let rhythmAnalyzer = RhythmAnalyzer()
    private let biomechanicsAnalyzer = BiomechanicsAnalyzer()
    private let watchSensorAnalyzer = WatchSensorAnalyzer.shared

    // Extracted coordinators
    private let healthCoordinator = RideHealthCoordinator()
    private let watchBridge = RideWatchBridge()
    private let liveWorkoutManager = LiveWorkoutManager.shared

    // Injected services (concrete types for full API access, injectable for testing)
    private let sharingCoordinator: UnifiedSharingCoordinator
    private let fallDetectionManager: FallDetectionManager
    private let audioCoach: AudioCoachManager
    private let weatherService: WeatherService
    private var lastAnnouncedGait: GaitType = .stationary

    private var modelContext: ModelContext?
    private var lastLocation: CLLocation?
    private var lastCoordinate: CLLocationCoordinate2D?
    private var startTime: Date?
    private var timer: Timer?
    private var lastAltitude: Double?

    /// Initialize with default production services
    convenience init(locationManager: LocationManager) {
        self.init(
            locationManager: locationManager,
            sharingCoordinator: .shared,
            fallDetection: .shared,
            audioCoach: .shared,
            weatherService: .shared
        )
    }

    /// Initialize with dependency injection (for testing)
    init(
        locationManager: LocationManager,
        sharingCoordinator: UnifiedSharingCoordinator,
        fallDetection: FallDetectionManager,
        audioCoach: AudioCoachManager,
        weatherService: WeatherService
    ) {
        self.locationManager = locationManager
        self.sharingCoordinator = sharingCoordinator
        self.fallDetectionManager = fallDetection
        self.audioCoach = audioCoach
        self.weatherService = weatherService
        setupLocationCallback()
        setupMotionCallback()
        setupGaitCallback()
        setupReinCallback()
        setupWatchBridge()
        setupHealthCoordinator()
        setupFallDetection()
    }

    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        gaitAnalyzer.configure(with: modelContext)
        fallDetectionManager.configure(modelContext: modelContext, heartRateService: HeartRateService())
    }

    func configure(riderProfile: RiderProfile?) {
        healthCoordinator.configure(riderProfile: riderProfile)
    }

    private func setupLocationCallback() {
        locationManager.onLocationUpdate = { [weak self] location in
            self?.handleNewLocation(location)
        }
    }

    private func setupMotionCallback() {
        motionManager.onMotionUpdate = { [weak self] sample in
            self?.handleMotion(sample)
        }
    }

    private func setupGaitCallback() {
        gaitAnalyzer.onGaitChange = { [weak self] from, to in
            guard let self else { return }
            self.transitionAnalyzer.processGaitChange(from: from, to: to)

            // Audio coaching for gait changes
            if to != self.lastAnnouncedGait {
                self.audioCoach.processGaitChange(from: from, to: to)
                self.lastAnnouncedGait = to
            }
        }
    }

    private func setupReinCallback() {
        reinAnalyzer.onReinChange = { [weak self] _, newRein in
            guard let self else { return }
            // Finalize symmetry for previous rein
            self.symmetryAnalyzer.finalizeReinSegment()
            self.rhythmAnalyzer.updateRein(newRein)
        }
    }

    private func setupWatchBridge() {
        watchBridge.onStartRide = { [weak self] in
            await self?.startRide()
        }

        watchBridge.onStopRide = { [weak self] in
            self?.stopRide()
        }

        watchBridge.onRequestStatus = { [weak self] in
            self?.sendStatusToWatch()
        }

        watchBridge.onHeartRateReceived = { [weak self] bpm in
            self?.handleHeartRateUpdate(bpm)
        }

        watchBridge.onVoiceNoteReceived = { [weak self] noteText in
            guard let self, let ride = self.currentRide else { return }
            let service = VoiceNotesService.shared
            ride.notes = service.appendNote(noteText, to: ride.notes)
            var currentNotes = ride.voiceNotes
            currentNotes.append(noteText)
            ride.voiceNotes = currentNotes
        }
    }

    private func setupHealthCoordinator() {
        healthCoordinator.onHeartRateZoneChanged = { [weak self] newZone in
            guard let self else { return }
            self.audioCoach.processHeartRateZone(newZone)
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

    /// User confirms they are OK after fall detection
    func confirmFallOK() {
        fallDetectionManager.confirmOK()
    }

    /// User requests emergency help
    func requestEmergencyHelp() {
        fallDetectionManager.requestEmergency()
    }

    /// Dismiss vehicle alert without stopping
    func dismissVehicleAlert() {
        showingVehicleAlert = false
        highSpeedStartTime = nil  // Reset so it doesn't immediately trigger again
    }

    // MARK: - Ride Control

    func startRide() async {
        Log.tracking.debug("startRide() called, current state: \(String(describing: self.rideState))")
        guard rideState == .idle else {
            Log.tracking.warning("startRide() aborted - not in idle state")
            return
        }

        // Request permission if needed
        if locationManager.needsPermission {
            Log.tracking.debug("Requesting location permission...")
            locationManager.requestPermission()
            // Wait a moment for authorization
            try? await Task.sleep(nanoseconds: 500_000_000)
        }

        Log.tracking.debug("Location permission status: hasPermission=\(self.locationManager.hasPermission), status=\(String(describing: self.locationManager.authorizationStatus))")
        guard locationManager.hasPermission else {
            Log.tracking.warning("startRide() aborted - no location permission")
            return
        }

        // Create new ride
        Log.tracking.debug("Creating new ride...")
        let ride = Ride()
        ride.startDate = Date()
        ride.name = Ride.defaultName(for: ride.startDate)
        ride.rideType = selectedRideType
        ride.horse = selectedHorse

        currentRide = ride
        modelContext?.insert(ride)
        Log.tracking.debug("Ride created and inserted into context")

        // Reset tracking state
        totalDistance = 0
        elapsedTime = 0
        currentSpeed = 0
        currentGait = .stationary
        currentElevation = 0
        elevationGain = 0
        elevationLoss = 0
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
        lastAltitude = nil
        startTime = Date()
        rideState = .tracking

        // Start analyzers
        gaitAnalyzer.startAnalyzing(for: ride)
        turnAnalyzer.reset()

        // Reset new analyzers
        leadAnalyzer.reset()
        transitionAnalyzer.reset()
        reinAnalyzer.reset()
        symmetryAnalyzer.reset()
        rhythmAnalyzer.reset()
        biomechanicsAnalyzer.reset()
        watchSensorAnalyzer.startSession()

        // Configure analyzers with horse profile for breed-specific priors
        if let horse = selectedHorse {
            gaitAnalyzer.configure(for: horse)
            biomechanicsAnalyzer.configure(for: horse)
        }

        // Start motion updates
        motionManager.startUpdates()

        // Clear tracked points for fresh route display
        locationManager.clearTrackedPoints()

        // Re-establish location callback (in case it was overwritten by another view)
        setupLocationCallback()

        // Start location updates
        Log.tracking.debug("Starting location tracking...")
        await locationManager.startTracking()
        Log.tracking.debug("Location tracking started")

        // Start family sharing if enabled
        if isSharingWithFamily {
            Log.tracking.debug("Starting family sharing...")
            await sharingCoordinator.startSharingLocation()
        }

        // Start elapsed time timer
        Log.tracking.debug("Starting timer...")
        startTimer()

        // Start heart rate monitoring
        Log.tracking.debug("Starting health coordinator...")
        await healthCoordinator.startMonitoring()

        // Start live workout session with Watch mirroring (auto-launches Watch app)
        Log.tracking.debug("Starting live workout with Watch mirroring...")
        do {
            try await liveWorkoutManager.startWorkout(activityType: .equestrianSports)
        } catch {
            Log.tracking.error("Failed to start live workout: \(error)")
        }

        // Start Watch updates
        Log.tracking.debug("Starting watch bridge...")
        watchBridge.startUpdates { [weak self] in
            self?.sendStatusToWatch()
        }

        // Start fall detection monitoring
        Log.tracking.debug("Starting fall detection...")
        fallDetectionManager.startMonitoring()

        // Subscribe to Watch sensor updates for gait detection enhancement
        setupWatchGaitEnhancement()

        // Fetch weather for outdoor ride
        Log.tracking.debug("Fetching weather...")
        await fetchWeatherForRide()

        // Start audio coaching session
        Log.tracking.debug("Starting audio coach...")
        audioCoach.startSession()
        audioCoach.resetSafetyStatus()
        lastAnnouncedGait = .stationary
        Log.tracking.info("Ride started successfully")
    }

    private func fetchWeatherForRide() async {
        guard let location = locationManager.currentLocation else {
            weatherError = "Location not available"
            Log.services.warning("Weather fetch skipped: no location available")
            return
        }

        do {
            let weather = try await weatherService.fetchWeather(for: location)

            // Validate weather data before assignment
            guard weather.temperature != 0 || weather.humidity != 0 else {
                weatherError = "Invalid weather data received"
                Log.services.warning("Weather fetch returned invalid/empty data")
                return
            }

            currentWeather = weather
            currentRide?.startWeather = weather
            weatherError = nil
            Log.services.info("Weather fetched: \(weather.temperature)°C, \(weather.condition)")
        } catch {
            weatherError = error.localizedDescription
            Log.services.error("Failed to fetch weather: \(error)")
        }
    }

    func pauseRide() {
        guard rideState == .tracking else { return }

        // Pause location updates
        locationManager.stopTracking()
        stopTimer()

        // Pause motion updates
        motionManager.stopUpdates()

        // Pause live workout session
        liveWorkoutManager.pauseWorkout()

        // Update state
        rideState = .paused
    }

    func resumeRide() {
        guard rideState == .paused else { return }

        // Resume location updates
        Task {
            await locationManager.startTracking()
        }
        startTimer()

        // Resume motion updates
        motionManager.startUpdates()

        // Resume live workout session
        liveWorkoutManager.resumeWorkout()

        // Update state
        rideState = .tracking
    }

    func stopRide() {
        guard rideState == .tracking || rideState == .paused else { return }

        // Stop location updates
        locationManager.stopTracking()
        stopTimer()

        // Stop motion updates
        motionManager.stopUpdates()

        // Stop fall detection
        fallDetectionManager.stopMonitoring()

        // End audio coaching session
        audioCoach.endSession(distance: totalDistance, duration: elapsedTime)

        // Stop analyzers
        gaitAnalyzer.stopAnalyzing()
        watchSensorAnalyzer.stopSession()

        // Finalize symmetry/rhythm for last rein segment
        symmetryAnalyzer.finalizeReinSegment()
        rhythmAnalyzer.finalizeReinSegment()

        // Stop heart rate monitoring and get final stats
        healthCoordinator.stopMonitoring()
        watchBridge.stopUpdates()

        // End live workout session (stops Watch mirroring)
        Task {
            await liveWorkoutManager.endWorkout()
        }

        // Finalize ride - capture reference BEFORE any async tasks
        let completedRide = currentRide

        // Capture end weather (use captured ride reference to avoid race)
        if let location = locationManager.currentLocation, let ride = completedRide {
            Task { [modelContext] in
                do {
                    let endWeather = try await self.weatherService.fetchWeather(for: location)
                    await MainActor.run {
                        ride.endWeather = endWeather
                        do {
                            try modelContext?.save()
                        } catch {
                            Log.services.error("Failed to save end weather: \(error)")
                        }
                    }
                } catch {
                    Log.services.error("Failed to fetch end weather: \(error)")
                }
            }
        }
        if let ride = completedRide {
            ride.endDate = Date()
            ride.totalDistance = totalDistance
            ride.totalDuration = elapsedTime

            // Save turn stats
            let turnStats = turnAnalyzer.turnStats
            ride.leftTurns = turnStats.leftTurns
            ride.rightTurns = turnStats.rightTurns
            ride.totalLeftAngle = turnStats.totalLeftAngle
            ride.totalRightAngle = turnStats.totalRightAngle

            // Save lead stats
            ride.leftLeadDuration = leadAnalyzer.totalLeftLeadDuration
            ride.rightLeadDuration = leadAnalyzer.totalRightLeadDuration

            // Save rein stats
            ride.leftReinDuration = reinAnalyzer.totalLeftReinDuration
            ride.rightReinDuration = reinAnalyzer.totalRightReinDuration
            ride.leftReinSymmetry = symmetryAnalyzer.leftReinSymmetry
            ride.rightReinSymmetry = symmetryAnalyzer.rightReinSymmetry
            ride.leftReinRhythm = rhythmAnalyzer.leftReinRhythm
            ride.rightReinRhythm = rhythmAnalyzer.rightReinRhythm

            // Create rein segment records
            for segmentData in reinAnalyzer.getSegmentData() {
                let segment = ReinSegment(direction: segmentData.direction, startTime: segmentData.startTime)
                segment.endTime = segmentData.endTime
                segment.distance = segmentData.distance
                segment.ride = ride
                modelContext?.insert(segment)
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
                modelContext?.insert(record)
            }

            // Save heart rate data
            let hrStats = healthCoordinator.getFinalStatistics()
            ride.averageHeartRate = hrStats.averageBPM
            ride.maxHeartRate = hrStats.maxBPM
            ride.minHeartRate = hrStats.minBPM
            ride.heartRateSamples = Array(hrStats.samples)

            // Save biomechanical metrics
            ride.averageStrideLength = strideLength
            ride.averageStrideFrequency = strideFrequency
            ride.averageImpulsion = impulsion
            ride.averageEngagement = engagement
            ride.averageStraightness = straightness
            ride.averageRiderStability = riderStability
            ride.totalTrainingLoad = trainingLoad

            // Start recovery analysis if we have HR data
            if hrStats.maxBPM > 0 {
                Task {
                    await healthCoordinator.startRecoveryAnalysis(peakHeartRate: hrStats.maxBPM)
                }
            }

            do {
                try modelContext?.save()
            } catch {
                Log.tracking.error("Failed to save ride data: \(error)")
            }

            // Compute and save skill domain scores
            if let context = modelContext {
                let skillService = SkillDomainService()
                let scores = skillService.computeScores(from: ride)
                for score in scores {
                    context.insert(score)
                }
                do {
                    try context.save()
                } catch {
                    Log.tracking.error("Failed to save skill domain scores: \(error)")
                }
            }

            // Save to HealthKit
            Task {
                await saveToHealthKit(ride)
            }

            // Stop family sharing
            if isSharingWithFamily {
                Task {
                    await sharingCoordinator.stopSharingLocation()
                }
            }

            // Generate and announce post-session AI summary
            generatePostSessionSummary(for: ride)

            // Convert to TrainingArtifact and sync to CloudKit for family sharing
            Task {
                await ArtifactConversionService.shared.convertAndSyncRide(ride)
            }
        }

        // Reset state
        rideState = .idle
        currentRide = nil
        lastLocation = nil
        lastCoordinate = nil
        lastAltitude = nil
        currentSpeed = 0
        currentGait = .stationary
        currentElevation = 0
        elevationGain = 0
        elevationLoss = 0
        currentLead = .unknown
        currentRein = .straight
        currentSymmetry = 0.0
        currentRhythm = 0.0
        currentHeartRate = 0
        averageHeartRate = 0
        maxHeartRate = 0
        currentHeartRateZone = .zone1

        // Reset biomechanical metrics
        strideLength = 0
        strideSpeed = 0
        strideFrequency = 0
        impulsion = 0
        engagement = 0
        straightness = 0
        riderStability = 0
        trainingLoad = 0

        // Reset health coordinator
        healthCoordinator.resetState()

        // Reset weather state
        currentWeather = nil
        weatherError = nil
    }

    func discardRide() {
        guard rideState == .tracking || rideState == .paused else { return }

        // Stop all tracking services
        locationManager.stopTracking()
        stopTimer()
        motionManager.stopUpdates()
        fallDetectionManager.stopMonitoring()
        audioCoach.endSession(distance: 0, duration: 0)
        gaitAnalyzer.stopAnalyzing()
        healthCoordinator.stopMonitoring()
        watchBridge.stopUpdates()

        // Discard live workout session (stops Watch mirroring)
        Task {
            await liveWorkoutManager.discardWorkout()
        }

        // Delete the current ride without saving
        if let ride = currentRide {
            modelContext?.delete(ride)
            do {
                try modelContext?.save()
            } catch {
                Log.tracking.error("Failed to save after discarding ride: \(error)")
            }
        }

        // Stop family sharing
        if isSharingWithFamily {
            Task {
                await sharingCoordinator.stopSharingLocation()
            }
        }

        // Reset state
        rideState = .idle
        currentRide = nil
        lastLocation = nil
        lastCoordinate = nil
        lastAltitude = nil
        currentSpeed = 0
        currentGait = .stationary
        currentElevation = 0
        elevationGain = 0
        elevationLoss = 0
        currentLead = .unknown
        currentRein = .straight
        currentSymmetry = 0.0
        currentRhythm = 0.0
        currentHeartRate = 0
        averageHeartRate = 0
        maxHeartRate = 0
        currentHeartRateZone = .zone1
        healthCoordinator.resetState()
        currentWeather = nil
        weatherError = nil
    }

    // MARK: - Post-Session Summary

    private func generatePostSessionSummary(for ride: Ride) {
        let summaryService = PostSessionSummaryService.shared
        let voiceNotes = ride.voiceNotes

        Task {
            // Generate AI summary (will use fallback if AI not available)
            let summary: SessionSummary
            if #available(iOS 26.0, *) {
                do {
                    summary = try await summaryService.generateRideSummary(
                        ride: ride,
                        voiceNotes: voiceNotes
                    )
                } catch {
                    // Fall back to rule-based summary
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

            // Store summary in ride
            await MainActor.run {
                ride.aiSummary = summary
                do {
                    try modelContext?.save()
                } catch {
                    Log.services.error("Failed to save AI summary: \(error)")
                }
            }

            // Read summary aloud via AirPods
            await MainActor.run {
                summaryService.readSummaryAloud(summary, brief: false)
            }

            Log.services.info("Post-session summary generated and announced")
        }
    }

    // MARK: - HealthKit

    private func saveToHealthKit(_ ride: Ride) async {
        let healthKit = HealthKitManager.shared

        // Request authorization if needed
        if !healthKit.isAuthorized {
            _ = await healthKit.requestAuthorization()
        }

        // Save workout
        let success = await healthKit.saveRideAsWorkout(ride)
        if success {
            Log.health.info("Ride saved to Apple Health")
        }
    }

    // MARK: - Location Handling

    private func handleNewLocation(_ location: CLLocation) {
        guard rideState == .tracking,
              let ride = currentRide else { return }

        // Filter poor accuracy (> 20 meters)
        guard location.horizontalAccuracy <= 20 else { return }

        var distanceDelta: Double = 0

        // Update current speed
        if location.speed >= 0 {
            currentSpeed = location.speed
            // Track max speed
            if location.speed > ride.maxSpeed {
                ride.maxSpeed = location.speed
            }
        }

        // Calculate distance from last point
        if let last = lastLocation {
            let timeDelta = location.timestamp.timeIntervalSince(last.timestamp)
            guard timeDelta > 0 else { return }

            let delta = location.distance(from: last)
            let speed = delta / timeDelta

            // Filter GPS jumps (max 50 m/s ~ 180 km/h - reasonable for horse riding)
            if speed < 50 {
                totalDistance += delta
                distanceDelta = delta
            }
        }

        // Track elevation
        currentElevation = location.altitude
        if let lastAlt = lastAltitude {
            let altDelta = location.altitude - lastAlt
            if altDelta > 0 {
                ride.elevationGain += altDelta
                elevationGain += altDelta
            } else {
                ride.elevationLoss += abs(altDelta)
                elevationLoss += abs(altDelta)
            }

            // Calculate gradient for XC
            if distanceDelta > 0 {
                recentAltitudes.append((altitude: location.altitude, distance: totalDistance))
                // Keep last 50m of samples for gradient calculation
                let minDistance = totalDistance - 50
                recentAltitudes.removeAll { $0.distance < minDistance }

                if recentAltitudes.count >= 2,
                   let first = recentAltitudes.first,
                   let last = recentAltitudes.last {
                    let distDiff = last.distance - first.distance
                    if distDiff > 10 {  // Need at least 10m for reliable gradient
                        let altDiff = last.altitude - first.altitude
                        currentGradient = (altDiff / distDiff) * 100
                    }
                }
            }
        }
        lastAltitude = location.altitude

        // Turn analysis
        if let lastCoord = lastCoordinate {
            turnAnalyzer.processLocations(from: lastCoord, to: location.coordinate)

            // Rein analysis (GPS component)
            reinAnalyzer.processLocation(from: lastCoord, to: location.coordinate)
            currentRein = reinAnalyzer.currentRein
        }
        lastCoordinate = location.coordinate

        // Gait analysis (pass GPS accuracy for weighted speed constraints)
        gaitAnalyzer.processLocation(speed: currentSpeed, distance: distanceDelta, horizontalAccuracy: location.horizontalAccuracy)
        let newGait = gaitAnalyzer.currentGait

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
        locationManager.updateGait(newGait)
        locationManager.addTrackedPoint(location)

        // Update transition analyzer with speed
        transitionAnalyzer.updateSpeed(currentSpeed)

        // Store location point
        let point = LocationPoint(from: location)
        point.ride = ride
        modelContext?.insert(point)

        lastLocation = location

        // Update fall detection with current location
        fallDetectionManager.updateLocation(location.coordinate)

        // Vehicle detection
        checkForVehicleSpeed(currentSpeed)

        // Update family sharing (throttled to every 10 seconds)
        if isSharingWithFamily {
            Task {
                await updateFamilySharing(location: location)
            }
        }
    }

    // MARK: - Vehicle Detection

    private func checkForVehicleSpeed(_ speed: Double) {
        if speed > vehicleSpeedThreshold {
            if highSpeedStartTime == nil {
                highSpeedStartTime = Date()
            } else if let start = highSpeedStartTime,
                      Date().timeIntervalSince(start) > vehicleDetectionDuration {
                // Sustained high speed detected - show alert
                if !showingVehicleAlert {
                    showingVehicleAlert = true
                    audioCoach.announce("It looks like you may be in a vehicle. Would you like to stop tracking?")
                }
            }
        } else {
            // Speed dropped below threshold - reset detection
            highSpeedStartTime = nil
        }
    }

    // MARK: - Motion Handling

    private func handleMotion(_ sample: MotionSample) {
        guard rideState == .tracking else { return }

        // Feed motion data to gait analyzer for improved detection
        gaitAnalyzer.processMotion(sample)

        // Lead analysis (during canter/gallop)
        leadAnalyzer.processMotionSample(sample, currentGait: currentGait)
        currentLead = leadAnalyzer.currentLead

        // Update gait analyzer with lead info
        gaitAnalyzer.updateLead(leadAnalyzer.currentLead, confidence: leadAnalyzer.currentConfidence)

        // Rein analysis (accelerometer + gyroscope components)
        reinAnalyzer.processMotion(sample)
        currentRein = reinAnalyzer.currentRein

        // Symmetry analysis
        symmetryAnalyzer.processMotionSample(sample, currentRein: currentRein)
        currentSymmetry = symmetryAnalyzer.currentSymmetryScore

        // Rhythm analysis
        rhythmAnalyzer.processMotionSample(sample, currentGait: currentGait)
        currentRhythm = rhythmAnalyzer.currentRhythmScore

        // Update gait analyzer with rhythm
        gaitAnalyzer.updateRhythm(currentRhythm)

        // Update stride frequency for lead analyzer
        leadAnalyzer.configure(strideFrequency: gaitAnalyzer.strideFrequency)
        leadQuality = leadAnalyzer.leadQuality

        // Update gait confidence from HMM
        gaitConfidence = gaitAnalyzer.gaitConfidence

        // Biomechanics analysis - compute stride, impulsion, engagement, etc.
        let yawRateMean = sample.yawRate
        let yawRateStdDev = 0.1  // Simplified - would need rolling stats
        biomechanicsAnalyzer.update(
            strideFrequency: gaitAnalyzer.strideFrequency,
            gait: currentGait,
            verticalRMS: gaitAnalyzer.bounceAmplitude,
            forwardRMS: abs(sample.forwardAcceleration),
            lateralRMS: abs(sample.lateralAcceleration),
            yawRateMean: yawRateMean,
            yawRateStdDev: yawRateStdDev,
            pitchRMS: abs(sample.pitch),
            spectralEntropy: gaitAnalyzer.spectralEntropy,
            xyCoherence: gaitAnalyzer.leftRightSymmetry,
            zYawCoherence: gaitAnalyzer.verticalYawCoherence,
            gpsSpeed: currentSpeed,
            elapsedTime: elapsedTime
        )

        // Feed lateral sample for proper rein balance calculation (RMS+/RMS- method)
        biomechanicsAnalyzer.addLateralSample(sample.lateralAcceleration)

        // Feed forward acceleration for IMU displacement integration (stride refinement)
        biomechanicsAnalyzer.addForwardAccelSample(sample.forwardAcceleration)

        // Update public biomechanics metrics
        strideLength = biomechanicsAnalyzer.strideLength
        strideFrequency = gaitAnalyzer.strideFrequency
        strideSpeed = biomechanicsAnalyzer.strideSpeed
        impulsion = biomechanicsAnalyzer.impulsion
        engagement = biomechanicsAnalyzer.engagement
        straightness = biomechanicsAnalyzer.straightness
        riderStability = biomechanicsAnalyzer.riderStability
        trainingLoad = biomechanicsAnalyzer.trainingLoad

        // Fall detection processing
        fallDetectionManager.processMotionSample(sample)
    }

    private var lastFamilyUpdateTime: Date?

    private func updateFamilySharing(location: CLLocation) async {
        // Throttle updates to every 10 seconds
        if let lastUpdate = lastFamilyUpdateTime,
           Date().timeIntervalSince(lastUpdate) < 10 {
            return
        }
        lastFamilyUpdateTime = Date()

        await sharingCoordinator.updateSharedLocation(
            location: location,
            gait: currentGait,
            distance: totalDistance,
            duration: elapsedTime
        )
    }

    // MARK: - Timer

    private func startTimer() {
        // Ensure any existing timer is invalidated first to prevent leaks
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let start = self.startTime else { return }
            self.elapsedTime = Date().timeIntervalSince(start)

            // Audio coaching for milestones
            self.audioCoach.processTime(self.elapsedTime)
            self.audioCoach.processDistance(self.totalDistance)

            // Periodic safety status announcement
            self.audioCoach.processSafetyStatus(
                elapsedTime: self.elapsedTime,
                fallDetectionActive: self.fallDetectionManager.isMonitoring
            )

            // XC-specific timing alerts
            if self.selectedRideType == .crossCountry && self.xcOptimumTime > 0 {
                self.processXCTimingAlerts()
            }
        }
    }

    private func processXCTimingAlerts() {
        let currentMinute = Int(elapsedTime) / 60
        let secondsIntoMinute = Int(elapsedTime) % 60

        // Triple haptic + beep 10 seconds before each minute marker
        if secondsIntoMinute == 50 && currentMinute >= lastMinuteMarker {
            lastMinuteMarker = currentMinute + 1
            audioCoach.announceXCMinuteWarning(minute: currentMinute + 1)
        }

        // Time fault warning: Urgent double haptic if >20s off pace
        let timeDiff = abs(xcTimeDifference)
        if timeDiff > 20 {
            audioCoach.announceXCTimeFault(secondsOff: Int(xcTimeDifference))
        }

        // Speeding penalty warning: If >15s early (ahead of pace)
        if xcTimeDifference < -15 {
            audioCoach.announceXCSpeedingWarning()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Heart Rate Handling

    private func handleHeartRateUpdate(_ bpm: Int) {
        guard rideState == .tracking else { return }

        healthCoordinator.processHeartRate(bpm)

        // Sync state from coordinator
        currentHeartRate = healthCoordinator.currentHeartRate
        currentHeartRateZone = healthCoordinator.currentZone
        averageHeartRate = healthCoordinator.averageHeartRate
        maxHeartRate = healthCoordinator.maxHeartRate
    }

    // MARK: - Watch Gait Enhancement

    /// Subscribe to Watch sensor updates to enhance gait detection
    /// Watch provides posture and movement data that improves gait classification accuracy
    private func setupWatchGaitEnhancement() {
        let watchManager = WatchConnectivityManager.shared

        // Store existing callback (if any) to chain with our enhancement
        let existingCallback = watchManager.onEnhancedSensorUpdate

        watchManager.onEnhancedSensorUpdate = { [weak self] in
            // Call existing callback first
            existingCallback?()

            // Compute arm symmetry and yaw energy from Watch sensor data
            guard let self = self else { return }

            // Arm symmetry: computed from posture roll consistency
            // Low roll variance = good arm symmetry (arms moving evenly)
            // Roll is in degrees from WatchConnectivityManager
            let rollVariance = self.watchSensorAnalyzer.postureStability / 100.0
            let armSymmetry = 1.0 - min(1.0, abs(watchManager.postureRoll) / 30.0)

            // Yaw energy: computed from movement intensity and tremor
            // Higher intensity with low tremor indicates purposeful rotation
            let yawEnergy = (self.watchSensorAnalyzer.movementIntensity / 100.0) *
                            (1.0 - self.watchSensorAnalyzer.tremorLevel / 100.0)

            // Feed Watch data to gait analyzer for enhanced classification
            self.gaitAnalyzer.updateWatchData(
                armSymmetry: max(0, min(1, armSymmetry * rollVariance)),
                yawEnergy: max(0, min(1, yawEnergy))
            )
        }
    }

    // MARK: - Watch Communication

    private func sendStatusToWatch() {
        let state: SharedRideState = rideState == .tracking ? .tracking : .idle

        // Pre-compute batch percentages once for efficiency
        let gaits = gaitPercentages
        let reins = reinPercentages
        let leads = leadPercentages
        let turns = turnPercentages

        // Build discipline-specific metrics based on ride type
        var walkPct: Double?
        var trotPct: Double?
        var canterPct: Double?
        var gallopPct: Double?
        var leftTurns: Int?
        var rightTurns: Int?
        var leftRein: Double?
        var rightRein: Double?
        var leftLead: Double?
        var rightLead: Double?
        var symmetry: Double?
        var rhythm: Double?
        var optTime: TimeInterval?
        var timeDiff: TimeInterval?
        var elev: Double?

        switch selectedRideType {
        case .hack:
            walkPct = gaits.walk
            trotPct = gaits.trot
            canterPct = gaits.canter
            gallopPct = gaits.gallop
            elev = currentElevation

        case .schooling:
            walkPct = gaits.walk
            trotPct = gaits.trot
            canterPct = gaits.canter
            leftTurns = turns.total > 0 ? turnAnalyzer.turnStats.leftTurns : nil
            rightTurns = turns.total > 0 ? turnAnalyzer.turnStats.rightTurns : nil
            leftRein = reins.left
            rightRein = reins.right
            leftLead = leads.left
            rightLead = leads.right
            symmetry = currentSymmetry
            rhythm = currentRhythm

        case .crossCountry:
            trotPct = gaits.trot
            canterPct = gaits.canter
            gallopPct = gaits.gallop
            optTime = xcOptimumTime
            timeDiff = xcTimeDifference
            elev = currentElevation
        }

        watchBridge.sendStatus(
            rideState: state,
            duration: elapsedTime,
            distance: totalDistance,
            speed: currentSpeed,
            gait: currentGait.rawValue,
            heartRate: currentHeartRate > 0 ? currentHeartRate : nil,
            heartRateZone: currentHeartRateZone.rawValue,
            averageHeartRate: averageHeartRate > 0 ? averageHeartRate : nil,
            maxHeartRate: maxHeartRate > 0 ? maxHeartRate : nil,
            horseName: selectedHorse?.name,
            rideType: selectedRideType.rawValue,
            walkPercent: walkPct,
            trotPercent: trotPct,
            canterPercent: canterPct,
            gallopPercent: gallopPct,
            leftTurnCount: leftTurns,
            rightTurnCount: rightTurns,
            leftReinPercent: leftRein,
            rightReinPercent: rightRein,
            leftLeadPercent: leftLead,
            rightLeadPercent: rightLead,
            symmetryScore: symmetry,
            rhythmScore: rhythm,
            optimalTime: optTime,
            timeDifference: timeDiff,
            elevation: elev
        )
    }
}
