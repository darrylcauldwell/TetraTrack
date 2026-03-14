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

// MARK: - Watch Session Discipline

/// Discipline for active Watch connectivity session
enum WatchSessionDiscipline: String, Sendable {
    case riding
    case walking
    case running
    case treadmill
    case swimming
    case shooting
}

// MARK: - Fall Event Type

/// Discriminated fall event from Watch
enum WatchFallEventType: Sendable {
    case detected(confidence: Double, impact: Double, rotation: Double)
    case confirmedOK
    case emergency
}

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

    // MARK: - Session Lifecycle

    private(set) var isSessionActive: Bool = false
    private(set) var activeSessionDiscipline: WatchSessionDiscipline?
    private(set) var sessionStartDate: Date?

    // MARK: - Sequence Counters & Event Properties
    // Observers use .onChange(of: sequence) or withObservationTracking to react.
    // Multiple observers work simultaneously — no overwriting.

    private(set) var commandSequence: Int = 0
    private(set) var lastReceivedCommand: WatchCommand?

    private(set) var heartRateSequence: Int = 0

    private(set) var motionUpdateSequence: Int = 0

    private(set) var voiceNoteSequence: Int = 0
    private(set) var lastVoiceNoteText: String?

    private(set) var strokeDetectedSequence: Int = 0

    private(set) var enhancedSensorSequence: Int = 0

    private(set) var fallEventSequence: Int = 0
    private(set) var lastFallEvent: WatchFallEventType?

    private(set) var shotDetectedSequence: Int = 0
    private(set) var lastDetectedShot: DetectedShotMetrics?

    private(set) var syncedSessionSequence: Int = 0
    private(set) var lastSyncedSession: WatchSyncedSession?

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

    // MARK: - Shot Metrics Buffer

    private(set) var receivedShotMetrics: [DetectedShotMetrics] = []

    // MARK: - Private

    private var session: WCSession?

    // MARK: - Singleton

    static let shared = WatchConnectivityManager()

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Setup

    /// Clear buffered shot metrics (call when a shooting session is saved)
    func clearShotMetrics() {
        receivedShotMetrics = []
    }

    /// Start a connectivity session for a discipline.
    /// Resets accumulators so previous session data doesn't leak.
    func startSession(discipline: WatchSessionDiscipline) {
        resetSessionAccumulators()
        isSessionActive = true
        activeSessionDiscipline = discipline
        sessionStartDate = Date()
        Log.watch.info("Watch session started: \(discipline.rawValue)")
    }

    /// End the active connectivity session.
    func endSession() {
        isSessionActive = false
        let discipline = activeSessionDiscipline?.rawValue ?? "none"
        activeSessionDiscipline = nil
        sessionStartDate = nil
        Log.watch.info("Watch session ended: \(discipline)")
    }

    /// Reset all accumulators for a fresh session.
    private func resetSessionAccumulators() {
        lastReceivedHeartRate = 0
        lastReceivedCommand = nil
        lastVoiceNoteText = nil
        lastFallEvent = nil
        lastDetectedShot = nil
        lastSyncedSession = nil
        receivedShotMetrics = []
    }

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
        currentMotionMode = .idle
        stanceStability = 0.0
        strokeCount = 0
        strokeRate = 0.0
        verticalOscillation = 0.0
        groundContactTime = 0.0
        cadence = 0

        // Reset enhanced sensor data
        relativeAltitude = 0.0
        altitudeChangeRate = 0.0
        barometricPressure = 0.0
        isSubmerged = false
        waterDepth = 0.0
        oxygenSaturation = 0.0
        breathingRate = 0.0
        compassHeading = 0.0
        posturePitch = 0.0
        postureRoll = 0.0
        tremorLevel = 0.0
        movementIntensity = 0.0
    }

    /// Update heart rate from data received via HKWorkoutSession mirrored channel.
    /// Converges with the WCSession `.heartRateUpdate` handler — both increment
    /// `heartRateSequence` so SessionTracker observation handles them identically.
    func updateFromMirroredHeartRate(_ bpm: Int) {
        lastReceivedHeartRate = bpm
        heartRateSequence += 1
        let seq = heartRateSequence
        Log.watch.info("updateFromMirroredHeartRate: \(bpm) bpm, seq=\(seq)")
    }

    /// Update motion metrics from a dictionary received via HKWorkoutSession mirrored channel.
    /// The dictionary is a JSON-decoded `WatchMotionMetrics` from the Watch.
    func updateFromMirroredMotionDict(_ dict: [String: Any]) {
        let previousStrokeCount = strokeCount

        // Map mode string
        if let modeString = dict["mode"] as? String {
            let mode: WatchMotionModeShared = switch modeString {
            case "riding": .riding
            case "running": .running
            case "swimming": .swimming
            case "shooting": .shooting
            default: .idle
            }
            currentMotionMode = mode
        }

        // Core metrics
        if let v = dict["stanceStability"] as? Double { stanceStability = v }
        if let v = dict["strokeCount"] as? Int {
            strokeCount = v
            if v > previousStrokeCount {
                strokeDetectedSequence += 1
            }
        }
        if let v = dict["strokeRate"] as? Double { strokeRate = v }
        if let v = dict["verticalOscillation"] as? Double { verticalOscillation = v }
        if let v = dict["groundContactTime"] as? Double { groundContactTime = v }
        if let v = dict["cadence"] as? Int { cadence = v }

        // Enhanced sensor data
        if let v = dict["relativeAltitude"] as? Double { relativeAltitude = v }
        if let v = dict["altitudeChangeRate"] as? Double { altitudeChangeRate = v }
        if let v = dict["barometricPressure"] as? Double { barometricPressure = v }
        if let v = dict["isSubmerged"] as? Bool { isSubmerged = v }
        if let v = dict["compassHeading"] as? Double { compassHeading = v }
        if let v = dict["breathingRate"] as? Double { breathingRate = v }
        if let v = dict["posturePitch"] as? Double { posturePitch = v }
        if let v = dict["postureRoll"] as? Double { postureRoll = v }
        if let v = dict["tremorLevel"] as? Double { tremorLevel = v }
        if let v = dict["movementIntensity"] as? Double { movementIntensity = v }

        motionUpdateSequence += 1
        enhancedSensorSequence += 1
    }

    // MARK: - Private Methods

    private func sendMessage(_ message: WatchMessage) {
        guard let session = session,
              session.activationState == .activated else {
            Log.watch.debug("Session not activated, skipping message")
            return
        }

        let dict = message.toDictionary()

        // Use exactly ONE transport to avoid duplicate/out-of-order delivery
        if session.isReachable {
            Log.watch.debug("Sending real-time message to Watch (reachable)")
            session.sendMessage(dict, replyHandler: nil) { error in
                Log.watch.error("Send error: \(error)")
            }
        } else {
            Log.watch.debug("Watch not reachable, using application context")
            updateApplicationContext(message)
        }
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

        // Check for shooting shot detection message
        if let type = message["type"] as? String, type == "shootingShotDetected" {
            if let metrics = DetectedShotMetrics.from(dictionary: message) {
                receivedShotMetrics.append(metrics)
                lastDetectedShot = metrics
                shotDetectedSequence += 1
            }
            return
        }

        guard let watchMessage = WatchMessage.from(dictionary: message) else {
            Log.watch.warning("Failed to parse message")
            return
        }

        lastMessageTime = watchMessage.timestamp

        // Handle command
        if let command = watchMessage.command {
            lastReceivedCommand = command
            commandSequence += 1

            // Handle heart rate update
            if command == .heartRateUpdate, let hr = watchMessage.heartRate {
                lastReceivedHeartRate = hr
                heartRateSequence += 1
            }

            // Handle voice note from Watch
            if command == .voiceNote, let noteText = watchMessage.voiceNoteText {
                lastVoiceNoteText = noteText
                voiceNoteSequence += 1
            }

            // Handle motion update from Watch
            if command == .motionUpdate {
                let previousStrokeCount = strokeCount

                if let mode = watchMessage.motionMode {
                    currentMotionMode = mode
                }

                // Update shooting metrics
                if let stability = watchMessage.stanceStability {
                    stanceStability = stability
                }

                // Update swimming metrics
                if let strokes = watchMessage.strokeCount {
                    strokeCount = strokes
                    if strokes > previousStrokeCount {
                        strokeDetectedSequence += 1
                    }
                }
                if let rate = watchMessage.strokeRate {
                    strokeRate = rate
                }

                // Update running metrics
                if let oscillation = watchMessage.verticalOscillation {
                    verticalOscillation = oscillation
                }
                if let gct = watchMessage.groundContactTime {
                    groundContactTime = gct
                }
                if let cad = watchMessage.cadence {
                    cadence = cad
                }

                // Update enhanced sensor data
                if let altitude = watchMessage.relativeAltitude {
                    relativeAltitude = altitude
                }
                if let altRate = watchMessage.altitudeChangeRate {
                    altitudeChangeRate = altRate
                }
                if let pressure = watchMessage.barometricPressure {
                    barometricPressure = pressure
                }
                if let submerged = watchMessage.isSubmerged {
                    isSubmerged = submerged
                }
                if let depth = watchMessage.waterDepth {
                    waterDepth = depth
                }
                if let spo2 = watchMessage.oxygenSaturation {
                    oxygenSaturation = spo2
                }
                if let heading = watchMessage.compassHeading {
                    compassHeading = heading
                }
                if let breathing = watchMessage.breathingRate {
                    breathingRate = breathing
                }
                if let pitch = watchMessage.posturePitch {
                    posturePitch = pitch
                }
                if let roll = watchMessage.postureRoll {
                    postureRoll = roll
                }
                if let tremor = watchMessage.tremorLevel {
                    tremorLevel = tremor
                }
                if let intensity = watchMessage.movementIntensity {
                    movementIntensity = intensity
                }

                motionUpdateSequence += 1
                enhancedSensorSequence += 1
            }

            // Handle fall detection from Watch
            if command == .fallDetected {
                let confidence = watchMessage.fallConfidence ?? 0.5
                let impact = watchMessage.fallImpactMagnitude ?? 0
                let rotation = watchMessage.fallRotationMagnitude ?? 0
                lastFallEvent = .detected(confidence: confidence, impact: impact, rotation: rotation)
                fallEventSequence += 1
            }

            if command == .fallConfirmedOK {
                lastFallEvent = .confirmedOK
                fallEventSequence += 1
            }

            if command == .fallEmergency {
                lastFallEvent = .emergency
                fallEventSequence += 1
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

        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        isReachable = session.isReachable

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
        isReachable = session.isReachable
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

        lastSyncedSession = session
        syncedSessionSequence += 1

        return true
    }

    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        handleReceivedMessage(applicationContext)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        // Handle diagnostic breadcrumbs from Watch (since Console.app can't see Watch logs)
        if let breadcrumb = userInfo["diagnosticBreadcrumb"] as? String {
            Log.watch.info("WATCH DIAGNOSTIC: \(breadcrumb)")
            return
        }

        // Handle Watch session sync via background transfer
        if let type = userInfo["type"] as? String, type == "watchSessionSync" {
            handleWatchSessionSync(userInfo)
            return
        }
        handleReceivedMessage(userInfo)
    }

    #if os(iOS)
    func sessionWatchStateDidChange(_ session: WCSession) {
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        Log.watch.info("Watch state changed - paired: \(session.isPaired)")
    }
    #endif
}
