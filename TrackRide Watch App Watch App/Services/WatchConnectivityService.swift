//
//  WatchConnectivityService.swift
//  TrackRide Watch App
//
//  Watch-side WatchConnectivity manager
//  Receives session control commands and statistics from iPhone
//

import Foundation
import WatchConnectivity
import HealthKit
import Observation

@Observable
final class WatchConnectivityService: NSObject {
    // MARK: - State from iPhone

    private(set) var isReachable: Bool = false
    private(set) var rideState: SharedRideState = .idle
    private(set) var messageCount: Int = 0  // Debug: count received messages
    private(set) var duration: TimeInterval = 0
    private(set) var distance: Double = 0
    private(set) var speed: Double = 0
    private(set) var gait: String = "Stationary"
    private(set) var heartRate: Int = 0
    private(set) var heartRateZone: Int = 1
    private(set) var averageHeartRate: Int = 0
    private(set) var maxHeartRate: Int = 0
    private(set) var horseName: String?
    private(set) var rideType: String?
    private(set) var lastUpdateTime: Date?

    // Discipline-specific ride metrics (received from iPhone)
    private(set) var walkPercent: Double = 0
    private(set) var trotPercent: Double = 0
    private(set) var canterPercent: Double = 0
    private(set) var gallopPercent: Double = 0
    private(set) var leftTurnCount: Int = 0
    private(set) var rightTurnCount: Int = 0
    private(set) var leftReinPercent: Double = 50
    private(set) var rightReinPercent: Double = 50
    private(set) var leftLeadPercent: Double = 50
    private(set) var rightLeadPercent: Double = 50
    private(set) var symmetryScore: Double = 0
    private(set) var rhythmScore: Double = 0
    private(set) var optimalTime: TimeInterval = 0
    private(set) var timeDifference: TimeInterval = 0
    private(set) var elevation: Double = 0

    // MARK: - Phase 2: Insights Data from iPhone

    /// Recent training sessions (received from iPhone)
    private(set) var recentSessions: [TrainingSessionSummary] = []

    /// Training trends data (received from iPhone)
    private(set) var trends: TrainingTrends = TrainingTrends(
        periodLabel: "This Week",
        sessionCount: 0,
        totalDuration: 0,
        ridingCount: 0,
        runningCount: 0,
        swimmingCount: 0,
        shootingCount: 0,
        comparedToPrevious: 0
    )

    /// Workload data (received from iPhone)
    private(set) var workload: WorkloadData = WorkloadData(
        sessionsThisWeek: 0,
        targetSessionsPerWeek: 4,
        totalDurationThisWeek: 0,
        restDays: 0,
        consecutiveTrainingDays: 0,
        recommendation: .ready
    )

    // MARK: - SpO2 Monitoring

    private(set) var currentOxygenSaturation: Double = 0.0  // 0-100%
    private var healthStore: HKHealthStore?
    private var spo2Query: HKAnchoredObjectQuery?

    // MARK: - Private

    private var session: WCSession?

    // MARK: - Singleton

    static let shared = WatchConnectivityService()

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func activate() {
        guard WCSession.isSupported() else {
            print("WatchConnectivityService: WCSession not supported")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Computed Properties

    /// Whether there is an active session on iPhone
    var hasActiveSession: Bool {
        rideState == .tracking
    }

    /// Convenience for checking if riding discipline is active
    var isRiding: Bool {
        rideState == .tracking && activeDiscipline == .riding
    }

    // MARK: - SpO2 Monitoring

    /// Start monitoring oxygen saturation (requires HealthKit authorization)
    func startSpO2Monitoring() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("WatchConnectivityService: HealthKit not available")
            return
        }

        healthStore = HKHealthStore()

        guard let spo2Type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else {
            print("WatchConnectivityService: SpO2 type not available")
            return
        }

        // Request authorization
        healthStore?.requestAuthorization(toShare: nil, read: [spo2Type]) { [weak self] success, error in
            if success {
                self?.startSpO2Query(spo2Type)
            } else if let error = error {
                print("WatchConnectivityService: SpO2 auth error - \(error)")
            }
        }
    }

    private func startSpO2Query(_ spo2Type: HKQuantityType) {
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-60),  // Last minute
            end: nil,
            options: .strictStartDate
        )

        spo2Query = HKAnchoredObjectQuery(
            type: spo2Type,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, error in
            if let error = error {
                print("WatchConnectivityService: SpO2 query error - \(error)")
                return
            }
            self?.processSpO2Samples(samples)
        }

        spo2Query?.updateHandler = { [weak self] _, samples, _, _, error in
            if let error = error {
                print("WatchConnectivityService: SpO2 update error - \(error)")
                return
            }
            self?.processSpO2Samples(samples)
        }

        if let query = spo2Query {
            healthStore?.execute(query)
            print("WatchConnectivityService: SpO2 monitoring started")
        }
    }

    private func processSpO2Samples(_ samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample],
              let latest = quantitySamples.last else { return }

        let spo2 = latest.quantity.doubleValue(for: HKUnit.percent()) * 100
        DispatchQueue.main.async {
            self.currentOxygenSaturation = spo2
        }
    }

    func stopSpO2Monitoring() {
        if let query = spo2Query {
            healthStore?.stop(query)
            spo2Query = nil
        }
    }

    // MARK: - Sending Messages (Simplified - No Session Control)

    /// Send heart rate update to iPhone (companion feature - no session control)
    func sendHeartRateUpdate(_ bpm: Int) {
        let message = WatchMessage.heartRateUpdate(bpm)
        sendMessage(message)
    }

    /// Send voice note to iPhone (companion feature)
    func sendVoiceNote(_ text: String) {
        let message = WatchMessage.voiceNote(text)
        sendMessage(message)
    }

    /// Request updated statistics from iPhone
    func requestStatisticsUpdate() {
        let message: [String: Any] = [
            "type": "requestStats",
            "timestamp": Date().timeIntervalSince1970
        ]
        sendRawMessage(message)
    }

    // MARK: - Motion Data Sending (Sensor Companion)

    /// Send motion sensor data to iPhone for analysis.
    /// Watch captures IMU data, iPhone processes and stores.
    func sendMotionUpdate() {
        let motionManager = WatchMotionManager.shared
        let mode: WatchMotionModeShared = switch motionManager.currentMode {
        case .shooting: .shooting
        case .swimming: .swimming
        case .running: .running
        case .riding: .riding
        case .idle: .idle
        }

        let message = WatchMessage.motionUpdate(
            mode: mode,
            stanceStability: motionManager.stanceStability,
            strokeCount: motionManager.strokeCount,
            strokeRate: motionManager.strokeRate,
            verticalOscillation: motionManager.verticalOscillation,
            groundContactTime: motionManager.groundContactTime,
            cadence: motionManager.cadence,
            // Enhanced sensor data
            relativeAltitude: motionManager.relativeAltitude,
            altitudeChangeRate: motionManager.altitudeChangeRate,
            barometricPressure: motionManager.barometricPressure,
            isSubmerged: motionManager.isSubmerged,
            waterDepth: motionManager.waterDepth,
            oxygenSaturation: currentOxygenSaturation,
            compassHeading: motionManager.compassHeading,
            breathingRate: motionManager.breathingRate,
            posturePitch: motionManager.posturePitch,
            postureRoll: motionManager.postureRoll,
            tremorLevel: motionManager.tremorLevel,
            movementIntensity: motionManager.movementIntensity
        )
        sendMessage(message)
    }

    /// Send raw motion samples for detailed analysis (bulk transfer)
    func sendMotionSamples(_ samples: [WatchMotionSample]) {
        guard !samples.isEmpty else { return }

        // Encode samples for transfer
        guard let data = try? JSONEncoder().encode(samples),
              let jsonString = String(data: data, encoding: .utf8) else { return }

        let message: [String: Any] = [
            "type": "motionSamples",
            "samples": jsonString,
            "timestamp": Date().timeIntervalSince1970
        ]
        sendRawMessage(message)
    }

    /// Start motion tracking for a specific discipline
    func startMotionTracking(mode: WatchMotionMode) {
        WatchMotionManager.shared.startTracking(mode: mode)
    }

    /// Stop motion tracking
    func stopMotionTracking() {
        WatchMotionManager.shared.stopTracking()
    }

    // MARK: - Fall Detection Messages (Safety Feature - Kept)

    func sendFallDetected(confidence: Double, impactMagnitude: Double, rotationMagnitude: Double) {
        let message = WatchMessage.fallDetectedMessage(
            confidence: confidence,
            impactMagnitude: impactMagnitude,
            rotationMagnitude: rotationMagnitude
        )
        sendMessage(message)
    }

    func sendFallConfirmedOK() {
        let message = WatchMessage.fallResponseMessage(.confirmedOK)
        sendMessage(message)
    }

    func sendFallEmergency() {
        let message = WatchMessage.fallResponseMessage(.emergency)
        sendMessage(message)
    }

    // MARK: - Private Methods

    private func sendMessage(_ message: WatchMessage) {
        sendRawMessage(message.toDictionary())
    }

    private func sendRawMessage(_ message: [String: Any]) {
        guard let session = session,
              session.activationState == .activated else {
            print("WatchConnectivityService: Session not active")
            return
        }

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("WatchConnectivityService: Send error - \(error)")
            }
        } else {
            // Use application context for background updates
            do {
                try session.updateApplicationContext(message)
            } catch {
                print("WatchConnectivityService: Context update error - \(error)")
            }
        }
    }

    private func handleReceivedMessage(_ message: [String: Any]) {
        DispatchQueue.main.async {
            self.messageCount += 1
        }
        print("WatchConnectivityService: Received message #\(messageCount + 1) with keys: \(message.keys)")

        // Handle insights data updates
        if let type = message["type"] as? String {
            switch type {
            case "recentSessions":
                handleRecentSessionsUpdate(message)
            case "trends":
                handleTrendsUpdate(message)
            case "workload":
                handleWorkloadUpdate(message)
            default:
                break
            }
        }

        // Handle standard WatchMessage
        guard let watchMessage = WatchMessage.from(dictionary: message) else {
            print("WatchConnectivityService: Could not parse as WatchMessage")
            return
        }

        print("WatchConnectivityService: Parsed message - rideState: \(String(describing: watchMessage.rideState)), gait: \(String(describing: watchMessage.gait))")

        DispatchQueue.main.async {
            self.lastUpdateTime = watchMessage.timestamp

            // Handle commands from iPhone
            if let command = watchMessage.command {
                switch command {
                // Session control commands - update Watch state to match iPhone
                case .startRide:
                    self.rideState = .tracking
                    // Start heart rate monitoring for the session
                    Task {
                        await WorkoutManager.shared.startHeartRateMonitoring()
                    }
                    print("WatchConnectivityService: Session started from iPhone")

                case .stopRide:
                    self.rideState = .idle
                    // Reset session data
                    self.duration = 0
                    self.distance = 0
                    self.speed = 0
                    self.gait = "Stationary"
                    self.heartRate = 0
                    self.horseName = nil
                    self.rideType = nil
                    print("WatchConnectivityService: Session stopped from iPhone")

                case .pauseRide:
                    self.rideState = .paused
                    print("WatchConnectivityService: Session paused from iPhone")

                case .resumeRide:
                    self.rideState = .tracking
                    print("WatchConnectivityService: Session resumed from iPhone")

                // Motion tracking commands
                case .startMotionTracking:
                    if let sharedMode = watchMessage.motionMode {
                        // Convert from shared enum to Watch-local enum
                        let mode: WatchMotionMode = switch sharedMode {
                        case .shooting: .shooting
                        case .swimming: .swimming
                        case .running: .running
                        case .riding: .riding
                        case .idle: .idle
                        }
                        WatchMotionManager.shared.startTracking(mode: mode)
                        print("WatchConnectivityService: Motion tracking started - \(mode)")
                    }

                case .stopMotionTracking:
                    WatchMotionManager.shared.stopTracking()
                    print("WatchConnectivityService: Motion tracking stopped")

                // Fall detection sync
                case .syncFallState:
                    let detected = watchMessage.fallDetected ?? false
                    let countdown = watchMessage.fallCountdown
                    WatchFallDetectionManager.shared.handleSyncedFallState(
                        detected: detected,
                        countdown: countdown
                    )

                // Commands sent from Watch to iPhone (ignore on Watch side)
                case .requestStatus, .heartRateUpdate, .voiceNote,
                     .motionUpdate, .fallDetected, .fallConfirmedOK, .fallEmergency:
                    break
                }
            }

            // Update session state (read-only display)
            if let state = watchMessage.rideState {
                self.rideState = state
            }
            if let dur = watchMessage.duration {
                self.duration = dur
            }
            if let dist = watchMessage.distance {
                self.distance = dist
            }
            if let spd = watchMessage.speed {
                self.speed = spd
            }
            if let g = watchMessage.gait {
                self.gait = g
            }
            if let hr = watchMessage.heartRate {
                self.heartRate = hr
            }
            if let zone = watchMessage.heartRateZone {
                self.heartRateZone = zone
            }
            if let avg = watchMessage.averageHeartRate {
                self.averageHeartRate = avg
            }
            if let max = watchMessage.maxHeartRate {
                self.maxHeartRate = max
            }
            self.horseName = watchMessage.horseName
            self.rideType = watchMessage.rideType

            // Discipline-specific ride metrics
            if let walk = watchMessage.walkPercent {
                self.walkPercent = walk
            }
            if let trot = watchMessage.trotPercent {
                self.trotPercent = trot
            }
            if let canter = watchMessage.canterPercent {
                self.canterPercent = canter
            }
            if let gallop = watchMessage.gallopPercent {
                self.gallopPercent = gallop
            }
            if let leftTurns = watchMessage.leftTurnCount {
                self.leftTurnCount = leftTurns
            }
            if let rightTurns = watchMessage.rightTurnCount {
                self.rightTurnCount = rightTurns
            }
            if let leftRein = watchMessage.leftReinPercent {
                self.leftReinPercent = leftRein
            }
            if let rightRein = watchMessage.rightReinPercent {
                self.rightReinPercent = rightRein
            }
            if let leftLead = watchMessage.leftLeadPercent {
                self.leftLeadPercent = leftLead
            }
            if let rightLead = watchMessage.rightLeadPercent {
                self.rightLeadPercent = rightLead
            }
            if let symmetry = watchMessage.symmetryScore {
                self.symmetryScore = symmetry
            }
            if let rhythm = watchMessage.rhythmScore {
                self.rhythmScore = rhythm
            }
            if let optimal = watchMessage.optimalTime {
                self.optimalTime = optimal
            }
            if let diff = watchMessage.timeDifference {
                self.timeDifference = diff
            }
            if let elev = watchMessage.elevation {
                self.elevation = elev
            }
        }
    }

    // MARK: - Insights Data Handlers

    private func handleRecentSessionsUpdate(_ message: [String: Any]) {
        guard let sessionsData = message["sessions"] as? [[String: Any]] else { return }

        DispatchQueue.main.async {
            self.recentSessions = sessionsData.compactMap { dict -> TrainingSessionSummary? in
                guard let idString = dict["id"] as? String,
                      let id = UUID(uuidString: idString),
                      let discipline = dict["discipline"] as? String,
                      let timestamp = dict["date"] as? TimeInterval,
                      let duration = dict["duration"] as? TimeInterval,
                      let keyMetric = dict["keyMetric"] as? String,
                      let keyMetricLabel = dict["keyMetricLabel"] as? String else {
                    return nil
                }
                return TrainingSessionSummary(
                    id: id,
                    discipline: discipline,
                    date: Date(timeIntervalSince1970: timestamp),
                    duration: duration,
                    keyMetric: keyMetric,
                    keyMetricLabel: keyMetricLabel
                )
            }
        }
    }

    private func handleTrendsUpdate(_ message: [String: Any]) {
        DispatchQueue.main.async {
            self.trends = TrainingTrends(
                periodLabel: message["periodLabel"] as? String ?? "This Week",
                sessionCount: message["sessionCount"] as? Int ?? 0,
                totalDuration: message["totalDuration"] as? TimeInterval ?? 0,
                ridingCount: message["ridingCount"] as? Int ?? 0,
                runningCount: message["runningCount"] as? Int ?? 0,
                swimmingCount: message["swimmingCount"] as? Int ?? 0,
                shootingCount: message["shootingCount"] as? Int ?? 0,
                comparedToPrevious: message["comparedToPrevious"] as? Double ?? 0
            )
        }
    }

    private func handleWorkloadUpdate(_ message: [String: Any]) {
        DispatchQueue.main.async {
            let recommendationString = message["recommendation"] as? String ?? "ready"
            let recommendation = WorkloadData.WorkloadRecommendation(rawValue: recommendationString) ?? .ready

            self.workload = WorkloadData(
                sessionsThisWeek: message["sessionsThisWeek"] as? Int ?? 0,
                targetSessionsPerWeek: message["targetSessionsPerWeek"] as? Int ?? 4,
                totalDurationThisWeek: message["totalDurationThisWeek"] as? TimeInterval ?? 0,
                restDays: message["restDays"] as? Int ?? 0,
                consecutiveTrainingDays: message["consecutiveTrainingDays"] as? Int ?? 0,
                recommendation: recommendation
            )
        }
    }

    // MARK: - Formatted Values

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedDistance: String {
        let km = distance / 1000.0
        if km < 1 {
            return String(format: "%.0f m", distance)
        }
        return String(format: "%.2f km", km)
    }

    var formattedSpeed: String {
        let kmh = speed * 3.6
        return String(format: "%.1f km/h", kmh)
    }

    // MARK: - Discipline Detection

    enum ActiveDiscipline: Hashable {
        case idle
        case riding
        case swimming
        case running
        case shooting
        case training
    }

    var activeDiscipline: ActiveDiscipline {
        guard rideState == .tracking else { return .idle }

        // Check gait/rideType to determine discipline
        let type = (rideType ?? "").lowercased()
        let gaitLower = gait.lowercased()

        if gaitLower == "swimming" || type.contains("swim") || type.contains("3-min") {
            return .swimming
        }
        if gaitLower == "running" || type.contains("run") || type.contains("interval") || type.contains("tempo") || type.contains("easy") || type.contains("time trial") {
            return .running
        }
        if gaitLower == "shooting" || type.contains("shoot") || type.contains("competition") || type.contains("practice") {
            return .shooting
        }
        if type == "training" || type.contains("drill") {
            return .training
        }

        // Default to riding for hacking, flatwork, cross-country, etc.
        return .riding
    }

    var isSwimming: Bool {
        activeDiscipline == .swimming
    }

    var isRunning: Bool {
        activeDiscipline == .running
    }

    var isShooting: Bool {
        activeDiscipline == .shooting
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error = error {
            print("WatchConnectivityService: Activation error - \(error)")
            return
        }

        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }

        // Request initial statistics on activation
        if session.isReachable {
            requestStatisticsUpdate()
        }

        print("WatchConnectivityService: Activated - reachable: \(session.isReachable)")
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }

        // Request statistics when connection is restored
        if session.isReachable {
            requestStatisticsUpdate()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("WatchConnectivityService: didReceiveMessage called")
        handleReceivedMessage(message)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        print("WatchConnectivityService: didReceiveMessage (with reply) called")
        handleReceivedMessage(message)
        replyHandler(["status": "received"])
    }

    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        print("WatchConnectivityService: didReceiveApplicationContext called with keys: \(applicationContext.keys)")
        handleReceivedMessage(applicationContext)
    }
}
