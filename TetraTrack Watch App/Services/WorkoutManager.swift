//
//  WorkoutManager.swift
//  TetraTrack Watch App
//
//  Manages autonomous workout sessions on Apple Watch
//  Supports riding, running, and swimming with GPS and heart rate
//

import Foundation
import HealthKit
import Observation
import os

/// Activity type for Watch workouts
enum WatchActivityType: String {
    case riding
    case running
    case swimming

    var healthKitType: HKWorkoutActivityType {
        switch self {
        case .riding: return .equestrianSports
        case .running: return .running
        case .swimming: return .swimming
        }
    }

    var sessionDiscipline: WatchSessionDiscipline {
        switch self {
        case .riding: return .riding
        case .running: return .running
        case .swimming: return .swimming
        }
    }
}

/// Manages autonomous workout sessions on Apple Watch
@Observable
final class WorkoutManager: NSObject {
    static let shared = WorkoutManager()

    // MARK: - State

    private(set) var isWorkoutActive: Bool = false
    private(set) var isPaused: Bool = false
    private(set) var isCompanionMode: Bool = false
    private(set) var activityType: WatchActivityType?

    // MARK: - Metrics

    private(set) var currentHeartRate: Int = 0
    private(set) var averageHeartRate: Int = 0
    private(set) var maxHeartRate: Int = 0
    private(set) var minHeartRate: Int = 0
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var activeCalories: Double = 0

    // MARK: - Swimming Metrics

    private(set) var strokeCount: Int = 0
    private(set) var lapCount: Int = 0
    private(set) var swimmingDistance: Double = 0  // meters
    private(set) var currentStrokeType: HKSwimmingStrokeStyle = .unknown
    private(set) var poolLength: Double = 25.0  // meters (default 25m pool)

    // MARK: - Callbacks

    var onHeartRateUpdate: ((Int) -> Void)?
    var onWorkoutStateChanged: ((Bool) -> Void)?

    // MARK: - Private

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var heartRateSamples: [Int] = []
    private var startTime: Date?
    private var elapsedTimer: Timer?

    // Dependencies
    private let locationManager = WatchLocationManager.shared
    private let sessionStore = WatchSessionStore.shared

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            return false
        }

        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceSwimming)
        ]

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned)
        ]

        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            return true
        } catch {
            Log.health.error("Authorization failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Workout Control

    /// Start an autonomous workout session
    func startWorkout(type: WatchActivityType) async {
        guard !isWorkoutActive else {
            Log.tracking.debug("Workout already active")
            return
        }

        let authorized = await requestAuthorization()
        guard authorized else {
            Log.health.warning("Not authorized for workouts")
            return
        }

        // Create workout configuration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = type.healthKitType
        configuration.locationType = type == .swimming ? .indoor : .outdoor

        // Configure swimming-specific settings
        if type == .swimming {
            configuration.swimmingLocationType = .pool
            configuration.lapLength = HKQuantity(unit: .meter(), doubleValue: poolLength)
        }

        do {
            // Create workout session
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutSession?.delegate = self

            // Create workout builder
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            workoutBuilder?.delegate = self
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            // Start the session
            let startDate = Date()
            workoutSession?.startActivity(with: startDate)
            try await workoutBuilder?.beginCollection(at: startDate)

            // Update state
            activityType = type
            isWorkoutActive = true
            isCompanionMode = false
            isPaused = false
            startTime = startDate

            // Reset metrics
            heartRateSamples = []
            currentHeartRate = 0
            averageHeartRate = 0
            maxHeartRate = 0
            minHeartRate = 0
            elapsedTime = 0
            activeCalories = 0

            // Reset swimming metrics
            strokeCount = 0
            lapCount = 0
            swimmingDistance = 0
            currentStrokeType = .unknown

            // Start location tracking (except swimming)
            if type != .swimming {
                locationManager.startTracking()
            }

            // Start elapsed time timer
            startElapsedTimer()

            // Create session in store
            _ = sessionStore.startSession(discipline: type.sessionDiscipline)

            onWorkoutStateChanged?(true)
            Log.tracking.info("Started \(type.rawValue) workout")

        } catch {
            Log.tracking.error("Failed to start workout: \(error.localizedDescription)")
        }
    }

    /// Pause the current workout
    func pauseWorkout() {
        guard isWorkoutActive, !isPaused else { return }

        workoutSession?.pause()
        isPaused = true
        stopElapsedTimer()
        Log.tracking.info("Paused workout")
    }

    /// Resume a paused workout
    func resumeWorkout() {
        guard isWorkoutActive, isPaused else { return }

        workoutSession?.resume()
        isPaused = false
        startElapsedTimer()
        Log.tracking.info("Resumed workout")
    }

    /// Stop and save the workout
    func stopWorkout() async {
        guard isWorkoutActive else { return }

        // Stop location tracking
        locationManager.stopTracking()
        stopElapsedTimer()

        // End workout session
        workoutSession?.end()

        // End data collection
        let endDate = Date()
        var healthKitSaveSucceeded = false

        do {
            try await workoutBuilder?.endCollection(at: endDate)

            // Save workout to HealthKit
            if let builder = workoutBuilder {
                try await builder.finishWorkout()
                healthKitSaveSucceeded = true
                Log.health.info("Workout saved to HealthKit")
            }
        } catch {
            Log.tracking.error("Failed to end workout: \(error.localizedDescription)")
            // Session data will still be saved locally via sessionStore
            // and can be synced to iPhone for HealthKit save retry
        }

        // Update session store with final metrics
        sessionStore.updateActiveSession(
            duration: elapsedTime,
            distance: locationManager.totalDistance,
            elevationGain: locationManager.elevationGain,
            elevationLoss: locationManager.elevationLoss,
            averageSpeed: locationManager.averageSpeed,
            maxSpeed: locationManager.maxSpeed,
            averageHeartRate: averageHeartRate > 0 ? averageHeartRate : nil,
            maxHeartRate: maxHeartRate > 0 ? maxHeartRate : nil,
            minHeartRate: minHeartRate > 0 ? minHeartRate : nil
        )

        // Complete session with location data
        sessionStore.completeSession(locationPointsData: locationManager.getEncodedPoints())

        // Clean up
        workoutSession = nil
        workoutBuilder = nil
        isWorkoutActive = false
        isCompanionMode = false
        isPaused = false
        activityType = nil

        onWorkoutStateChanged?(false)

        if healthKitSaveSucceeded {
            Log.tracking.info("Workout stopped and saved to HealthKit")
        } else {
            Log.tracking.info("Workout stopped - data saved locally, will sync to iPhone for HealthKit save")
        }
    }

    /// Discard the current workout without saving
    func discardWorkout() {
        guard isWorkoutActive else { return }

        locationManager.stopTracking()
        stopElapsedTimer()

        workoutSession?.end()
        workoutBuilder?.discardWorkout()

        sessionStore.discardSession()

        workoutSession = nil
        workoutBuilder = nil
        isWorkoutActive = false
        isCompanionMode = false
        isPaused = false
        activityType = nil

        onWorkoutStateChanged?(false)
        Log.tracking.info("Workout discarded")
    }

    // MARK: - Heart Rate Monitoring (Companion Mode)

    /// Start heart rate monitoring as a companion to iPhone session.
    /// Creates an HKWorkoutSession for live HR delivery without Watch-side
    /// location tracking, timers, or session store.
    /// The workout is discarded (not saved to HealthKit) when stopped,
    /// since the iPhone handles HealthKit saving.
    func startHeartRateMonitoring(type: WatchActivityType = .riding) async {
        guard !isWorkoutActive else { return }

        let authorized = await requestAuthorization()
        guard authorized else {
            Log.health.warning("Not authorized for companion HR monitoring")
            return
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = type.healthKitType
        configuration.locationType = type == .swimming ? .indoor : .outdoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutSession?.delegate = self

            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            workoutBuilder?.delegate = self
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            let startDate = Date()
            workoutSession?.startActivity(with: startDate)
            try await workoutBuilder?.beginCollection(at: startDate)

            isWorkoutActive = true
            isCompanionMode = true
            heartRateSamples = []
            currentHeartRate = 0
            averageHeartRate = 0
            maxHeartRate = 0
            minHeartRate = 0

            Log.health.info("Heart rate monitoring started (companion mode) - \(type.rawValue)")
        } catch {
            Log.health.error("Failed to start companion HR monitoring: \(error.localizedDescription)")
        }
    }

    /// Stop companion heart rate monitoring and discard the workout
    func stopHeartRateMonitoring() {
        guard isWorkoutActive, isCompanionMode else { return }

        workoutSession?.end()
        workoutBuilder?.discardWorkout()

        workoutSession = nil
        workoutBuilder = nil
        isWorkoutActive = false
        isCompanionMode = false

        Log.health.info("Heart rate monitoring stopped (companion mode)")
    }

    // MARK: - Elapsed Timer

    private func startElapsedTimer() {
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startTime, !self.isPaused else { return }
            self.elapsedTime = Date().timeIntervalSince(start)
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    // MARK: - Computed Properties

    /// Current distance from location manager
    var distance: Double {
        locationManager.totalDistance
    }

    /// Current speed from location manager
    var currentSpeed: Double {
        locationManager.currentSpeed
    }

    /// Current elevation from location manager
    var currentElevation: Double {
        locationManager.currentAltitude
    }

    /// Elevation gain from location manager
    var elevationGain: Double {
        locationManager.elevationGain
    }

    /// Formatted elapsed time string
    var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Formatted distance string
    var formattedDistance: String {
        let km = distance / 1000.0
        if km < 1 {
            return String(format: "%.0f m", distance)
        }
        return String(format: "%.2f km", km)
    }

    /// Formatted pace (for running)
    var formattedPace: String {
        guard currentSpeed > 0 else { return "--:--" }
        let paceSecondsPerKm = 1000.0 / currentSpeed
        let minutes = Int(paceSecondsPerKm) / 60
        let seconds = Int(paceSecondsPerKm) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    // MARK: - Swimming Computed Properties

    /// SWOLF score (strokes + seconds per lap) - lower is better
    var swolfScore: Int {
        guard lapCount > 0 else { return 0 }
        let avgStrokesPerLap = Double(strokeCount) / Double(lapCount)
        let avgSecondsPerLap = elapsedTime / Double(lapCount)
        return Int(avgStrokesPerLap + avgSecondsPerLap)
    }

    /// Average strokes per lap
    var strokesPerLap: Double {
        guard lapCount > 0 else { return 0 }
        return Double(strokeCount) / Double(lapCount)
    }

    /// Formatted swimming distance
    var formattedSwimmingDistance: String {
        if swimmingDistance >= 1000 {
            return String(format: "%.2f km", swimmingDistance / 1000)
        }
        return String(format: "%.0f m", swimmingDistance)
    }

    /// Stroke type display name
    var strokeTypeName: String {
        switch currentStrokeType {
        case .freestyle: return "Freestyle"
        case .backstroke: return "Backstroke"
        case .breaststroke: return "Breaststroke"
        case .butterfly: return "Butterfly"
        case .mixed: return "Mixed"
        case .kickboard: return "Kickboard"
        case .unknown: return "---"
        @unknown default: return "---"
        }
    }

    /// Pace per 100m for swimming
    var swimPacePer100m: String {
        guard swimmingDistance > 0, elapsedTime > 0 else { return "--:--" }
        let secondsPer100m = (elapsedTime / swimmingDistance) * 100
        let minutes = Int(secondsPer100m) / 60
        let seconds = Int(secondsPer100m) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        DispatchQueue.main.async {
            switch toState {
            case .running:
                self.isPaused = false
            case .paused:
                self.isPaused = true
            case .ended:
                self.isWorkoutActive = false
            default:
                break
            }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Log.tracking.error("Workout session failed: \(error.localizedDescription)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }

            if quantityType == HKQuantityType(.heartRate) {
                let statistics = workoutBuilder.statistics(for: quantityType)
                processHeartRateStatistics(statistics)
            }

            if quantityType == HKQuantityType(.activeEnergyBurned) {
                let statistics = workoutBuilder.statistics(for: quantityType)
                if let sum = statistics?.sumQuantity() {
                    DispatchQueue.main.async {
                        self.activeCalories = sum.doubleValue(for: .kilocalorie())
                    }
                }
            }

            // Swimming metrics
            if quantityType == HKQuantityType(.swimmingStrokeCount) {
                let statistics = workoutBuilder.statistics(for: quantityType)
                if let sum = statistics?.sumQuantity() {
                    DispatchQueue.main.async {
                        self.strokeCount = Int(sum.doubleValue(for: .count()))
                    }
                }
            }

            if quantityType == HKQuantityType(.distanceSwimming) {
                let statistics = workoutBuilder.statistics(for: quantityType)
                if let sum = statistics?.sumQuantity() {
                    DispatchQueue.main.async {
                        self.swimmingDistance = sum.doubleValue(for: .meter())
                        // Calculate lap count from distance and pool length
                        self.lapCount = Int(self.swimmingDistance / self.poolLength)
                    }
                }
            }
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events - particularly swimming events
        let events = workoutBuilder.workoutEvents
        guard !events.isEmpty else { return }

        for event in events {
            if event.type == .lap {
                // Lap completed
                DispatchQueue.main.async {
                    // Lap count is calculated from distance, but we can use events as backup
                }
            }

            // Check for swimming stroke style in event metadata
            if let metadata = event.metadata,
               let strokeStyleValue = metadata[HKMetadataKeySwimmingStrokeStyle] as? Int,
               let strokeStyle = HKSwimmingStrokeStyle(rawValue: strokeStyleValue) {
                DispatchQueue.main.async {
                    self.currentStrokeType = strokeStyle
                }
            }
        }
    }

    private func processHeartRateStatistics(_ statistics: HKStatistics?) {
        guard let statistics = statistics else { return }

        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())

        DispatchQueue.main.async {
            if let mostRecent = statistics.mostRecentQuantity() {
                let bpm = Int(mostRecent.doubleValue(for: heartRateUnit))
                self.currentHeartRate = bpm
                self.heartRateSamples.append(bpm)
                self.onHeartRateUpdate?(bpm)
            }

            if let average = statistics.averageQuantity() {
                self.averageHeartRate = Int(average.doubleValue(for: heartRateUnit))
            }

            if let max = statistics.maximumQuantity() {
                self.maxHeartRate = Int(max.doubleValue(for: heartRateUnit))
            }

            if let min = statistics.minimumQuantity() {
                self.minHeartRate = Int(min.doubleValue(for: heartRateUnit))
            }
        }
    }
}
