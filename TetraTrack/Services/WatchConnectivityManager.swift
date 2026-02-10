//
//  WatchConnectivityManager.swift
//  TetraTrack
//
//  iPhone-side WatchConnectivity manager
//

import Foundation
import WatchConnectivity
import Observation
import os

// MARK: - Watch Synced Session

/// Represents a session recorded on Apple Watch and synced to iPhone
struct WatchSyncedSession {
    let id: UUID
    let discipline: String  // "riding", "running", "swimming"
    let startDate: Date
    let endDate: Date?
    let duration: TimeInterval
    let distance: Double
    let elevationGain: Double
    let elevationLoss: Double
    let averageSpeed: Double
    let maxSpeed: Double
    let averageHeartRate: Int?
    let maxHeartRate: Int?
    let minHeartRate: Int?
    let locationPointsData: Data?

    /// Decode from JSON string received from Watch
    static func from(jsonString: String) -> WatchSyncedSession? {
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let discipline = dict["discipline"] as? String,
              let startTimestamp = dict["startDate"] as? TimeInterval,
              let duration = dict["duration"] as? Double,
              let distance = dict["distance"] as? Double else {
            return nil
        }

        let endDate: Date? = (dict["endDate"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }

        // Decode location points from base64
        var locationData: Data?
        if let base64String = dict["locationPoints"] as? String {
            locationData = Data(base64Encoded: base64String)
        }

        return WatchSyncedSession(
            id: id,
            discipline: discipline,
            startDate: Date(timeIntervalSince1970: startTimestamp),
            endDate: endDate,
            duration: duration,
            distance: distance,
            elevationGain: dict["elevationGain"] as? Double ?? 0,
            elevationLoss: dict["elevationLoss"] as? Double ?? 0,
            averageSpeed: dict["averageSpeed"] as? Double ?? 0,
            maxSpeed: dict["maxSpeed"] as? Double ?? 0,
            averageHeartRate: dict["averageHeartRate"] as? Int,
            maxHeartRate: dict["maxHeartRate"] as? Int,
            minHeartRate: dict["minHeartRate"] as? Int,
            locationPointsData: locationData
        )
    }
}

@Observable
@MainActor
final class WatchConnectivityManager: NSObject, WatchConnecting {
    // MARK: - State

    private(set) var isReachable: Bool = false
    private(set) var isPaired: Bool = false
    private(set) var isWatchAppInstalled: Bool = false
    private(set) var lastReceivedHeartRate: Int = 0
    private(set) var lastMessageTime: Date?

    // MARK: - Motion Tracking State (received from Watch)

    private(set) var currentMotionMode: WatchMotionModeShared = .idle

    // Shooting metrics
    private(set) var stanceStability: Double = 0.0  // 0-100%

    // Swimming metrics
    private(set) var strokeCount: Int = 0
    private(set) var strokeRate: Double = 0.0  // strokes per minute

    // Running metrics
    private(set) var verticalOscillation: Double = 0.0  // cm
    private(set) var groundContactTime: Double = 0.0  // ms
    private(set) var cadence: Int = 0  // steps per minute

    // MARK: - Enhanced Sensor Data (Phase 3)

    // Altimeter metrics
    private(set) var relativeAltitude: Double = 0.0  // meters from start
    private(set) var altitudeChangeRate: Double = 0.0  // m/s (positive = ascending)
    private(set) var barometricPressure: Double = 0.0  // kPa

    // Water detection
    private(set) var isSubmerged: Bool = false
    private(set) var waterDepth: Double = 0.0  // meters

    // Health metrics
    private(set) var oxygenSaturation: Double = 0.0  // 0-100%
    private(set) var breathingRate: Double = 0.0  // breaths per minute

    // Orientation & navigation
    private(set) var compassHeading: Double = 0.0  // degrees (0-360)
    private(set) var posturePitch: Double = 0.0  // degrees (-90 to 90)
    private(set) var postureRoll: Double = 0.0  // degrees (-180 to 180)

    // Motion analysis
    private(set) var tremorLevel: Double = 0.0  // 0-100 (higher = more tremor)
    private(set) var movementIntensity: Double = 0.0  // 0-100 (overall activity level)

    // MARK: - Callbacks

    var onCommandReceived: ((WatchCommand) -> Void)?
    var onHeartRateReceived: ((Int) -> Void)?
    var onVoiceNoteReceived: ((String) -> Void)?
    var onMotionUpdate: ((WatchMotionModeShared, Double?, Int?, Double?, Double?, Double?, Int?) -> Void)?
    var onStrokeDetected: (() -> Void)?

    // Enhanced sensor callback (fired when new sensor data received)
    var onEnhancedSensorUpdate: (() -> Void)?

    // Fall detection callbacks
    var onWatchFallDetected: ((Double, Double, Double) -> Void)?  // confidence, impact, rotation
    var onWatchFallConfirmedOK: (() -> Void)?
    var onWatchFallEmergency: (() -> Void)?

    // Watch autonomous session sync callback
    var onWatchSessionReceived: ((WatchSyncedSession) -> Void)?

    // MARK: - Private

    private var session: WCSession?

    // MARK: - Singleton

    static let shared = WatchConnectivityManager()

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func activate() {
        guard WCSession.isSupported() else {
            Log.watch.debug("WCSession not supported")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Sending Messages

    /// Send ride status update to Watch
    func sendStatusUpdate(
        rideState: SharedRideState,
        duration: TimeInterval,
        distance: Double,
        speed: Double,
        gait: String,
        heartRate: Int?,
        heartRateZone: Int?,
        averageHeartRate: Int?,
        maxHeartRate: Int?,
        horseName: String?,
        rideType: String?,
        // Discipline-specific metrics
        walkPercent: Double? = nil,
        trotPercent: Double? = nil,
        canterPercent: Double? = nil,
        gallopPercent: Double? = nil,
        leftTurnCount: Int? = nil,
        rightTurnCount: Int? = nil,
        leftReinPercent: Double? = nil,
        rightReinPercent: Double? = nil,
        leftLeadPercent: Double? = nil,
        rightLeadPercent: Double? = nil,
        symmetryScore: Double? = nil,
        rhythmScore: Double? = nil,
        optimalTime: TimeInterval? = nil,
        timeDifference: TimeInterval? = nil,
        elevation: Double? = nil,
        // Phone running form data
        runningPhase: String? = nil,
        asymmetryIndex: Double? = nil
    ) {
        let message = WatchMessage.statusUpdate(
            rideState: rideState,
            duration: duration,
            distance: distance,
            speed: speed,
            gait: gait,
            heartRate: heartRate,
            heartRateZone: heartRateZone,
            averageHeartRate: averageHeartRate,
            maxHeartRate: maxHeartRate,
            horseName: horseName,
            rideType: rideType,
            walkPercent: walkPercent,
            trotPercent: trotPercent,
            canterPercent: canterPercent,
            gallopPercent: gallopPercent,
            leftTurnCount: leftTurnCount,
            rightTurnCount: rightTurnCount,
            leftReinPercent: leftReinPercent,
            rightReinPercent: rightReinPercent,
            leftLeadPercent: leftLeadPercent,
            rightLeadPercent: rightLeadPercent,
            symmetryScore: symmetryScore,
            rhythmScore: rhythmScore,
            optimalTime: optimalTime,
            timeDifference: timeDifference,
            elevation: elevation,
            runningPhase: runningPhase,
            asymmetryIndex: asymmetryIndex
        )

        sendMessage(message)
    }

    /// Send a command to Watch (e.g., ride started confirmation)
    func sendCommand(_ command: WatchCommand) {
        let message = WatchMessage.command(command)
        sendMessage(message)
    }

    /// Start motion tracking on Watch for a specific discipline
    func startMotionTracking(mode: WatchMotionModeShared) {
        let message = WatchMessage.startMotionTracking(mode: mode)
        sendMessage(message)
    }

    /// Stop motion tracking on Watch
    func stopMotionTracking() {
        sendCommand(.stopMotionTracking)
    }

    /// Sync fall detection state to Watch
    func syncFallStateToWatch(fallDetected: Bool, countdown: Int?) {
        let message = WatchMessage.syncFallState(detected: fallDetected, countdown: countdown)
        sendMessage(message)
    }

    /// Reset motion metrics (for new session)
    func resetMotionMetrics() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.currentMotionMode = .idle
            self.stanceStability = 0.0
            self.strokeCount = 0
            self.strokeRate = 0.0
            self.verticalOscillation = 0.0
            self.groundContactTime = 0.0
            self.cadence = 0

            // Reset enhanced sensor data
            self.relativeAltitude = 0.0
            self.altitudeChangeRate = 0.0
            self.barometricPressure = 0.0
            self.isSubmerged = false
            self.waterDepth = 0.0
            self.oxygenSaturation = 0.0
            self.breathingRate = 0.0
            self.compassHeading = 0.0
            self.posturePitch = 0.0
            self.postureRoll = 0.0
            self.tremorLevel = 0.0
            self.movementIntensity = 0.0
        }
    }

    // MARK: - Private Methods

    private func sendMessage(_ message: WatchMessage) {
        guard let session = session,
              session.activationState == .activated else {
            Log.watch.debug("Session not activated, skipping message")
            return
        }

        let dict = message.toDictionary()

        // Always try sendMessage first for real-time updates
        // It will fail gracefully if not reachable
        if session.isReachable {
            Log.watch.debug("Sending real-time message to Watch (reachable)")
            session.sendMessage(dict, replyHandler: nil) { error in
                Log.watch.error("Send error: \(error)")
            }
        } else {
            // Try sendMessage anyway - sometimes isReachable is stale
            Log.watch.debug("Watch not reachable, trying sendMessage then context")
            session.sendMessage(dict, replyHandler: nil) { [weak self] _ in
                // If sendMessage fails, fall back to application context
                self?.updateApplicationContext(message)
            }
        }

        // Always update application context as backup for when Watch wakes
        updateApplicationContext(message)
    }

    private func updateApplicationContext(_ message: WatchMessage) {
        guard let session = session,
              session.activationState == .activated else {
            return
        }

        do {
            try session.updateApplicationContext(message.toDictionary())
        } catch {
            Log.watch.error("Context update error: \(error)")
        }
    }

    private func handleReceivedMessage(_ message: [String: Any]) {
        // Check for Watch session sync message (autonomous session from Watch)
        if let type = message["type"] as? String, type == "watchSessionSync" {
            handleWatchSessionSync(message)
            return
        }

        guard let watchMessage = WatchMessage.from(dictionary: message) else {
            Log.watch.warning("Failed to parse message")
            return
        }

        lastMessageTime = watchMessage.timestamp

        // Handle command
        if let command = watchMessage.command {
            DispatchQueue.main.async {
                self.onCommandReceived?(command)
            }

            // Handle heart rate update
            if command == .heartRateUpdate, let hr = watchMessage.heartRate {
                DispatchQueue.main.async {
                    self.lastReceivedHeartRate = hr
                    self.onHeartRateReceived?(hr)
                }
            }

            // Handle voice note from Watch
            if command == .voiceNote, let noteText = watchMessage.voiceNoteText {
                DispatchQueue.main.async {
                    self.onVoiceNoteReceived?(noteText)
                }
            }

            // Handle motion update from Watch
            if command == .motionUpdate {
                let previousStrokeCount = self.strokeCount

                DispatchQueue.main.async {
                    if let mode = watchMessage.motionMode {
                        self.currentMotionMode = mode
                    }

                    // Update shooting metrics
                    if let stability = watchMessage.stanceStability {
                        self.stanceStability = stability
                    }

                    // Update swimming metrics
                    if let strokes = watchMessage.strokeCount {
                        self.strokeCount = strokes
                        // Detect new stroke
                        if strokes > previousStrokeCount {
                            self.onStrokeDetected?()
                        }
                    }
                    if let rate = watchMessage.strokeRate {
                        self.strokeRate = rate
                    }

                    // Update running metrics
                    if let oscillation = watchMessage.verticalOscillation {
                        self.verticalOscillation = oscillation
                    }
                    if let gct = watchMessage.groundContactTime {
                        self.groundContactTime = gct
                    }
                    if let cad = watchMessage.cadence {
                        self.cadence = cad
                    }

                    // Update enhanced sensor data
                    if let altitude = watchMessage.relativeAltitude {
                        self.relativeAltitude = altitude
                    }
                    if let altRate = watchMessage.altitudeChangeRate {
                        self.altitudeChangeRate = altRate
                    }
                    if let pressure = watchMessage.barometricPressure {
                        self.barometricPressure = pressure
                    }
                    if let submerged = watchMessage.isSubmerged {
                        self.isSubmerged = submerged
                    }
                    if let depth = watchMessage.waterDepth {
                        self.waterDepth = depth
                    }
                    if let spo2 = watchMessage.oxygenSaturation {
                        self.oxygenSaturation = spo2
                    }
                    if let heading = watchMessage.compassHeading {
                        self.compassHeading = heading
                    }
                    if let breathing = watchMessage.breathingRate {
                        self.breathingRate = breathing
                    }
                    if let pitch = watchMessage.posturePitch {
                        self.posturePitch = pitch
                    }
                    if let roll = watchMessage.postureRoll {
                        self.postureRoll = roll
                    }
                    if let tremor = watchMessage.tremorLevel {
                        self.tremorLevel = tremor
                    }
                    if let intensity = watchMessage.movementIntensity {
                        self.movementIntensity = intensity
                    }

                    // Fire motion update callback
                    self.onMotionUpdate?(
                        self.currentMotionMode,
                        watchMessage.stanceStability,
                        watchMessage.strokeCount,
                        watchMessage.strokeRate,
                        watchMessage.verticalOscillation,
                        watchMessage.groundContactTime,
                        watchMessage.cadence
                    )

                    // Fire enhanced sensor callback if set
                    self.onEnhancedSensorUpdate?()
                }
            }

            // Handle fall detection from Watch
            if command == .fallDetected {
                let confidence = watchMessage.fallConfidence ?? 0.5
                let impact = watchMessage.fallImpactMagnitude ?? 0
                let rotation = watchMessage.fallRotationMagnitude ?? 0
                DispatchQueue.main.async {
                    self.onWatchFallDetected?(confidence, impact, rotation)
                }
            }

            // Handle fall confirmed OK from Watch
            if command == .fallConfirmedOK {
                DispatchQueue.main.async {
                    self.onWatchFallConfirmedOK?()
                }
            }

            // Handle fall emergency from Watch
            if command == .fallEmergency {
                DispatchQueue.main.async {
                    self.onWatchFallEmergency?()
                }
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error = error {
            Log.watch.error("Activation error: \(error)")
            return
        }

        DispatchQueue.main.async {
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isReachable = session.isReachable
        }

        Log.watch.info("Activated - paired: \(session.isPaired), installed: \(session.isWatchAppInstalled)")
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        Log.watch.debug("Session became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        Log.watch.debug("Session deactivated")
        // Reactivate for switching watches
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
        Log.watch.info("Reachability changed: \(session.isReachable)")
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleReceivedMessage(message)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        // Check for Watch session sync message
        if let type = message["type"] as? String, type == "watchSessionSync" {
            let success = handleWatchSessionSync(message)
            replyHandler(["success": success])
            return
        }

        handleReceivedMessage(message)
        replyHandler(["status": "received"])
    }

    // MARK: - Watch Session Sync Handling

    /// Handle session data synced from Watch autonomous mode
    @discardableResult
    private func handleWatchSessionSync(_ message: [String: Any]) -> Bool {
        guard let sessionData = message["sessionData"] as? String,
              let session = WatchSyncedSession.from(jsonString: sessionData) else {
            Log.watch.error("Failed to parse Watch session sync message")
            return false
        }

        Log.watch.info("Received Watch session: \(session.discipline) - \(session.duration)s")

        // Notify callback to handle the synced session
        DispatchQueue.main.async {
            self.onWatchSessionReceived?(session)
        }

        return true
    }

    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        handleReceivedMessage(applicationContext)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        // Handle Watch session sync via background transfer
        if let type = userInfo["type"] as? String, type == "watchSessionSync" {
            handleWatchSessionSync(userInfo)
            return
        }
        handleReceivedMessage(userInfo)
    }

    #if os(iOS)
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
        Log.watch.info("Watch state changed - paired: \(session.isPaired)")
    }
    #endif
}
