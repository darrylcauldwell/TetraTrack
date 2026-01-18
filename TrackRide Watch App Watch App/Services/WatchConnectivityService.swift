//
//  WatchConnectivityService.swift
//  TrackRide Watch App
//
//  Watch-side WatchConnectivity manager
//

import Foundation
import WatchConnectivity
import Observation

@Observable
final class WatchConnectivityService: NSObject {
    // MARK: - State from iPhone

    private(set) var isReachable: Bool = false
    private(set) var rideState: SharedRideState = .idle
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

    // Discipline-specific ride metrics
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

    // MARK: - Sending Commands

    func sendCommand(_ command: WatchCommand) {
        let message = WatchMessage.command(command)
        sendMessage(message)
    }

    func sendStartRide() {
        sendCommand(.startRide)
    }

    func sendStopRide() {
        sendCommand(.stopRide)
    }

    func sendPauseRide() {
        sendCommand(.pauseRide)
    }

    func sendResumeRide() {
        sendCommand(.resumeRide)
    }

    func sendHeartRateUpdate(_ bpm: Int) {
        let message = WatchMessage.heartRateUpdate(bpm)
        sendMessage(message)
    }

    func sendVoiceNote(_ text: String) {
        let message = WatchMessage.voiceNote(text)
        sendMessage(message)
    }

    func sendMotionUpdate() {
        let motionManager = WatchMotionManager.shared
        let mode: WatchMotionModeShared = switch motionManager.currentMode {
        case .shooting: .shooting
        case .swimming: .swimming
        case .running: .running
        case .idle: .idle
        }

        let message = WatchMessage.motionUpdate(
            mode: mode,
            stanceStability: motionManager.stanceStability,
            strokeCount: motionManager.strokeCount,
            strokeRate: motionManager.strokeRate,
            verticalOscillation: motionManager.verticalOscillation,
            groundContactTime: motionManager.groundContactTime,
            cadence: motionManager.cadence
        )
        sendMessage(message)
    }

    // MARK: - Fall Detection Messages

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
        guard let session = session,
              session.activationState == .activated else {
            print("WatchConnectivityService: Session not active")
            return
        }

        if session.isReachable {
            session.sendMessage(message.toDictionary(), replyHandler: nil) { error in
                print("WatchConnectivityService: Send error - \(error)")
            }
        } else {
            // Use application context for background updates
            do {
                try session.updateApplicationContext(message.toDictionary())
            } catch {
                print("WatchConnectivityService: Context update error - \(error)")
            }
        }
    }

    private func handleReceivedMessage(_ message: [String: Any]) {
        print("WatchConnectivityService: Received message with keys: \(message.keys)")

        guard let watchMessage = WatchMessage.from(dictionary: message) else {
            print("WatchConnectivityService: Failed to parse message")
            return
        }

        print("WatchConnectivityService: Parsed message - rideState: \(String(describing: watchMessage.rideState)), gait: \(String(describing: watchMessage.gait))")

        DispatchQueue.main.async {
            self.lastUpdateTime = watchMessage.timestamp

            // Handle commands from iPhone
            if let command = watchMessage.command {
                switch command {
                case .startRide:
                    // iPhone started a ride - notify observers to start Watch workout
                    NotificationCenter.default.post(name: .iPhoneStartedRide, object: nil)
                case .stopRide:
                    // iPhone stopped a ride
                    NotificationCenter.default.post(name: .iPhoneStoppedRide, object: nil)
                case .pauseRide:
                    NotificationCenter.default.post(name: .iPhonePausedRide, object: nil)
                case .resumeRide:
                    NotificationCenter.default.post(name: .iPhoneResumedRide, object: nil)
                case .startMotionTracking:
                    if let mode = watchMessage.motionMode {
                        let motionMode: WatchMotionMode = switch mode {
                        case .shooting: .shooting
                        case .swimming: .swimming
                        case .running: .running
                        case .idle: .idle
                        }
                        WatchMotionManager.shared.startTracking(mode: motionMode)
                        // Start periodic motion updates
                        self.startMotionUpdateTimer()
                    }
                case .stopMotionTracking:
                    WatchMotionManager.shared.stopTracking()
                    self.stopMotionUpdateTimer()
                case .syncFallState:
                    // Handle fall state sync from iPhone
                    let detected = watchMessage.fallDetected ?? false
                    let countdown = watchMessage.fallCountdown
                    WatchFallDetectionManager.shared.handleSyncedFallState(
                        detected: detected,
                        countdown: countdown
                    )
                default:
                    break
                }
            }

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

    // MARK: - Motion Update Timer

    private var motionUpdateTimer: Timer?

    private func startMotionUpdateTimer() {
        stopMotionUpdateTimer()
        motionUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.sendMotionUpdate()
        }
    }

    private func stopMotionUpdateTimer() {
        motionUpdateTimer?.invalidate()
        motionUpdateTimer = nil
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

    var isRiding: Bool {
        rideState == .tracking
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

// MARK: - Notification Names for iPhone Commands

extension Notification.Name {
    static let iPhoneStartedRide = Notification.Name("iPhoneStartedRide")
    static let iPhoneStoppedRide = Notification.Name("iPhoneStoppedRide")
    static let iPhonePausedRide = Notification.Name("iPhonePausedRide")
    static let iPhoneResumedRide = Notification.Name("iPhoneResumedRide")
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

        print("WatchConnectivityService: Activated - reachable: \(session.isReachable)")
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleReceivedMessage(message)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        handleReceivedMessage(message)
        replyHandler(["status": "received"])
    }

    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        handleReceivedMessage(applicationContext)
    }
}
