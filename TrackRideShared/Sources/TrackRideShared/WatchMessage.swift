//
//  WatchMessage.swift
//  TrackRideShared
//
//  Shared message types for Watch <-> iPhone communication
//

import Foundation

// MARK: - Message Keys

public enum WatchMessageKey: String {
    case command = "command"
    case rideState = "rideState"
    case duration = "duration"
    case distance = "distance"
    case speed = "speed"
    case gait = "gait"
    case heartRate = "heartRate"
    case heartRateZone = "heartRateZone"
    case averageHeartRate = "averageHeartRate"
    case maxHeartRate = "maxHeartRate"
    case horseName = "horseName"
    case rideType = "rideType"
    case timestamp = "timestamp"
    case voiceNoteText = "voiceNoteText"
    // Motion metrics
    case motionMode = "motionMode"
    case stanceStability = "stanceStability"
    case strokeCount = "strokeCount"
    case strokeRate = "strokeRate"
    case verticalOscillation = "verticalOscillation"
    case groundContactTime = "groundContactTime"
    case cadence = "cadence"
    // Ride discipline metrics
    case walkPercent = "walkPercent"
    case trotPercent = "trotPercent"
    case canterPercent = "canterPercent"
    case gallopPercent = "gallopPercent"
    case leftTurnCount = "leftTurnCount"
    case rightTurnCount = "rightTurnCount"
    case leftReinPercent = "leftReinPercent"
    case rightReinPercent = "rightReinPercent"
    case leftLeadPercent = "leftLeadPercent"
    case rightLeadPercent = "rightLeadPercent"
    case symmetryScore = "symmetryScore"
    case rhythmScore = "rhythmScore"
    case optimalTime = "optimalTime"
    case actualTime = "actualTime"
    case timeDifference = "timeDifference"
    case elevation = "elevation"
    // Fall detection
    case fallDetected = "fallDetected"
    case fallConfidence = "fallConfidence"
    case fallImpactMagnitude = "fallImpactMagnitude"
    case fallRotationMagnitude = "fallRotationMagnitude"
    case fallCountdown = "fallCountdown"
    case fallResponse = "fallResponse"
    // Enhanced sensor data (Watch -> iPhone)
    case relativeAltitude = "relativeAltitude"
    case altitudeChangeRate = "altitudeChangeRate"
    case barometricPressure = "barometricPressure"
    case isSubmerged = "isSubmerged"
    case waterDepth = "waterDepth"
    case oxygenSaturation = "oxygenSaturation"
    case compassHeading = "compassHeading"
    case breathingRate = "breathingRate"
    case bodyTemperature = "bodyTemperature"
    case posturePitch = "posturePitch"
    case postureRoll = "postureRoll"
    case tremorLevel = "tremorLevel"
    case movementIntensity = "movementIntensity"
}

// MARK: - Commands

public enum WatchCommand: String, Codable, Sendable {
    case startRide = "startRide"
    case stopRide = "stopRide"
    case pauseRide = "pauseRide"
    case resumeRide = "resumeRide"
    case requestStatus = "requestStatus"
    case heartRateUpdate = "heartRateUpdate"
    case voiceNote = "voiceNote"
    // Motion commands
    case startMotionTracking = "startMotionTracking"
    case stopMotionTracking = "stopMotionTracking"
    case motionUpdate = "motionUpdate"
    // Fall detection commands
    case fallDetected = "fallDetected"        // Watch -> iPhone: fall detected
    case fallConfirmedOK = "fallConfirmedOK"  // Watch -> iPhone: user confirmed OK
    case fallEmergency = "fallEmergency"      // Watch -> iPhone: emergency requested
    case syncFallState = "syncFallState"      // iPhone -> Watch: sync fall state
}

// MARK: - Fall Response

public enum FallResponse: String, Codable, Sendable {
    case confirmedOK = "confirmedOK"
    case emergency = "emergency"
}

// MARK: - Motion Mode

public enum WatchMotionModeShared: String, Codable, Sendable {
    case shooting
    case swimming
    case running
    case riding
    case idle
}

// MARK: - Ride State (Shared)

public enum SharedRideState: String, Codable, Sendable {
    case idle
    case tracking
    case paused
}

// MARK: - Watch Message

public struct WatchMessage: Codable, Sendable {
    public let command: WatchCommand?
    public let rideState: SharedRideState?
    public let duration: TimeInterval?
    public let distance: Double?
    public let speed: Double?
    public let gait: String?
    public let heartRate: Int?
    public let heartRateZone: Int?
    public let averageHeartRate: Int?
    public let maxHeartRate: Int?
    public let horseName: String?
    public let rideType: String?
    public let timestamp: Date
    public let voiceNoteText: String?
    // Motion metrics
    public let motionMode: WatchMotionModeShared?
    public let stanceStability: Double?
    public let strokeCount: Int?
    public let strokeRate: Double?
    public let verticalOscillation: Double?
    public let groundContactTime: Double?
    public let cadence: Int?
    // Ride discipline metrics
    public let walkPercent: Double?
    public let trotPercent: Double?
    public let canterPercent: Double?
    public let gallopPercent: Double?
    public let leftTurnCount: Int?
    public let rightTurnCount: Int?
    public let leftReinPercent: Double?
    public let rightReinPercent: Double?
    public let leftLeadPercent: Double?
    public let rightLeadPercent: Double?
    public let symmetryScore: Double?
    public let rhythmScore: Double?
    public let optimalTime: TimeInterval?
    public let actualTime: TimeInterval?
    public let timeDifference: TimeInterval?
    public let elevation: Double?
    // Fall detection
    public let fallDetected: Bool?
    public let fallConfidence: Double?
    public let fallImpactMagnitude: Double?
    public let fallRotationMagnitude: Double?
    public let fallCountdown: Int?
    public let fallResponse: FallResponse?
    // Enhanced sensor data
    public let relativeAltitude: Double?        // Meters relative to session start
    public let altitudeChangeRate: Double?      // Meters per second (climb rate)
    public let barometricPressure: Double?      // kPa
    public let isSubmerged: Bool?               // Water detection
    public let waterDepth: Double?              // Meters (if available)
    public let oxygenSaturation: Double?        // SpO2 percentage (0-100)
    public let compassHeading: Double?          // Degrees (0-360)
    public let breathingRate: Double?           // Breaths per minute
    public let bodyTemperature: Double?         // Celsius
    public let posturePitch: Double?            // Forward/back lean in degrees
    public let postureRoll: Double?             // Left/right lean in degrees
    public let tremorLevel: Double?             // Tremor intensity (0-100)
    public let movementIntensity: Double?       // Overall movement (0-100)

    public init(
        command: WatchCommand? = nil,
        rideState: SharedRideState? = nil,
        duration: TimeInterval? = nil,
        distance: Double? = nil,
        speed: Double? = nil,
        gait: String? = nil,
        heartRate: Int? = nil,
        heartRateZone: Int? = nil,
        averageHeartRate: Int? = nil,
        maxHeartRate: Int? = nil,
        horseName: String? = nil,
        rideType: String? = nil,
        voiceNoteText: String? = nil,
        motionMode: WatchMotionModeShared? = nil,
        stanceStability: Double? = nil,
        strokeCount: Int? = nil,
        strokeRate: Double? = nil,
        verticalOscillation: Double? = nil,
        groundContactTime: Double? = nil,
        cadence: Int? = nil,
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
        actualTime: TimeInterval? = nil,
        timeDifference: TimeInterval? = nil,
        elevation: Double? = nil,
        fallDetected: Bool? = nil,
        fallConfidence: Double? = nil,
        fallImpactMagnitude: Double? = nil,
        fallRotationMagnitude: Double? = nil,
        fallCountdown: Int? = nil,
        fallResponse: FallResponse? = nil,
        // Enhanced sensor data
        relativeAltitude: Double? = nil,
        altitudeChangeRate: Double? = nil,
        barometricPressure: Double? = nil,
        isSubmerged: Bool? = nil,
        waterDepth: Double? = nil,
        oxygenSaturation: Double? = nil,
        compassHeading: Double? = nil,
        breathingRate: Double? = nil,
        bodyTemperature: Double? = nil,
        posturePitch: Double? = nil,
        postureRoll: Double? = nil,
        tremorLevel: Double? = nil,
        movementIntensity: Double? = nil
    ) {
        self.command = command
        self.rideState = rideState
        self.duration = duration
        self.distance = distance
        self.speed = speed
        self.gait = gait
        self.heartRate = heartRate
        self.heartRateZone = heartRateZone
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.horseName = horseName
        self.rideType = rideType
        self.timestamp = Date()
        self.voiceNoteText = voiceNoteText
        self.motionMode = motionMode
        self.stanceStability = stanceStability
        self.strokeCount = strokeCount
        self.strokeRate = strokeRate
        self.verticalOscillation = verticalOscillation
        self.groundContactTime = groundContactTime
        self.walkPercent = walkPercent
        self.trotPercent = trotPercent
        self.canterPercent = canterPercent
        self.gallopPercent = gallopPercent
        self.leftTurnCount = leftTurnCount
        self.rightTurnCount = rightTurnCount
        self.leftReinPercent = leftReinPercent
        self.rightReinPercent = rightReinPercent
        self.leftLeadPercent = leftLeadPercent
        self.rightLeadPercent = rightLeadPercent
        self.symmetryScore = symmetryScore
        self.rhythmScore = rhythmScore
        self.optimalTime = optimalTime
        self.actualTime = actualTime
        self.timeDifference = timeDifference
        self.elevation = elevation
        self.cadence = cadence
        self.fallDetected = fallDetected
        self.fallConfidence = fallConfidence
        self.fallImpactMagnitude = fallImpactMagnitude
        self.fallRotationMagnitude = fallRotationMagnitude
        self.fallCountdown = fallCountdown
        self.fallResponse = fallResponse
        // Enhanced sensor data
        self.relativeAltitude = relativeAltitude
        self.altitudeChangeRate = altitudeChangeRate
        self.barometricPressure = barometricPressure
        self.isSubmerged = isSubmerged
        self.waterDepth = waterDepth
        self.oxygenSaturation = oxygenSaturation
        self.compassHeading = compassHeading
        self.breathingRate = breathingRate
        self.bodyTemperature = bodyTemperature
        self.posturePitch = posturePitch
        self.postureRoll = postureRoll
        self.tremorLevel = tremorLevel
        self.movementIntensity = movementIntensity
    }

    // MARK: - Convenience Initializers

    /// Create a command message from Watch to iPhone
    public static func command(_ cmd: WatchCommand) -> WatchMessage {
        WatchMessage(command: cmd)
    }

    /// Create a heart rate update from Watch to iPhone
    public static func heartRateUpdate(_ hr: Int) -> WatchMessage {
        WatchMessage(command: .heartRateUpdate, heartRate: hr)
    }

    /// Create a voice note message from Watch to iPhone
    public static func voiceNote(_ text: String) -> WatchMessage {
        WatchMessage(command: .voiceNote, voiceNoteText: text)
    }

    /// Create a status update from iPhone to Watch
    public static func statusUpdate(
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
        elevation: Double? = nil
    ) -> WatchMessage {
        WatchMessage(
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
            elevation: elevation
        )
    }

    /// Create a motion tracking start command from iPhone to Watch
    public static func startMotionTracking(mode: WatchMotionModeShared) -> WatchMessage {
        WatchMessage(command: .startMotionTracking, motionMode: mode)
    }

    /// Create a motion update from Watch to iPhone
    public static func motionUpdate(
        mode: WatchMotionModeShared,
        stanceStability: Double? = nil,
        strokeCount: Int? = nil,
        strokeRate: Double? = nil,
        verticalOscillation: Double? = nil,
        groundContactTime: Double? = nil,
        cadence: Int? = nil,
        // Enhanced sensor data
        relativeAltitude: Double? = nil,
        altitudeChangeRate: Double? = nil,
        barometricPressure: Double? = nil,
        isSubmerged: Bool? = nil,
        waterDepth: Double? = nil,
        oxygenSaturation: Double? = nil,
        compassHeading: Double? = nil,
        breathingRate: Double? = nil,
        posturePitch: Double? = nil,
        postureRoll: Double? = nil,
        tremorLevel: Double? = nil,
        movementIntensity: Double? = nil
    ) -> WatchMessage {
        WatchMessage(
            command: .motionUpdate,
            motionMode: mode,
            stanceStability: stanceStability,
            strokeCount: strokeCount,
            strokeRate: strokeRate,
            verticalOscillation: verticalOscillation,
            groundContactTime: groundContactTime,
            cadence: cadence,
            relativeAltitude: relativeAltitude,
            altitudeChangeRate: altitudeChangeRate,
            barometricPressure: barometricPressure,
            isSubmerged: isSubmerged,
            waterDepth: waterDepth,
            oxygenSaturation: oxygenSaturation,
            compassHeading: compassHeading,
            breathingRate: breathingRate,
            posturePitch: posturePitch,
            postureRoll: postureRoll,
            tremorLevel: tremorLevel,
            movementIntensity: movementIntensity
        )
    }

    /// Create a fall detected message from Watch to iPhone
    public static func fallDetectedMessage(
        confidence: Double,
        impactMagnitude: Double,
        rotationMagnitude: Double
    ) -> WatchMessage {
        WatchMessage(
            command: .fallDetected,
            fallDetected: true,
            fallConfidence: confidence,
            fallImpactMagnitude: impactMagnitude,
            fallRotationMagnitude: rotationMagnitude
        )
    }

    /// Create a fall response message from Watch to iPhone
    public static func fallResponseMessage(_ response: FallResponse) -> WatchMessage {
        WatchMessage(
            command: response == .confirmedOK ? .fallConfirmedOK : .fallEmergency,
            fallResponse: response
        )
    }

    /// Create a sync fall state message from iPhone to Watch
    public static func syncFallState(
        detected: Bool,
        countdown: Int?
    ) -> WatchMessage {
        WatchMessage(
            command: .syncFallState,
            fallDetected: detected,
            fallCountdown: countdown
        )
    }

    // MARK: - Dictionary Conversion

    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            WatchMessageKey.timestamp.rawValue: timestamp.timeIntervalSince1970
        ]

        if let command = command {
            dict[WatchMessageKey.command.rawValue] = command.rawValue
        }
        if let rideState = rideState {
            dict[WatchMessageKey.rideState.rawValue] = rideState.rawValue
        }
        if let duration = duration {
            dict[WatchMessageKey.duration.rawValue] = duration
        }
        if let distance = distance {
            dict[WatchMessageKey.distance.rawValue] = distance
        }
        if let speed = speed {
            dict[WatchMessageKey.speed.rawValue] = speed
        }
        if let gait = gait {
            dict[WatchMessageKey.gait.rawValue] = gait
        }
        if let heartRate = heartRate {
            dict[WatchMessageKey.heartRate.rawValue] = heartRate
        }
        if let heartRateZone = heartRateZone {
            dict[WatchMessageKey.heartRateZone.rawValue] = heartRateZone
        }
        if let averageHeartRate = averageHeartRate {
            dict[WatchMessageKey.averageHeartRate.rawValue] = averageHeartRate
        }
        if let maxHeartRate = maxHeartRate {
            dict[WatchMessageKey.maxHeartRate.rawValue] = maxHeartRate
        }
        if let horseName = horseName {
            dict[WatchMessageKey.horseName.rawValue] = horseName
        }
        if let rideType = rideType {
            dict[WatchMessageKey.rideType.rawValue] = rideType
        }
        if let voiceNoteText = voiceNoteText {
            dict[WatchMessageKey.voiceNoteText.rawValue] = voiceNoteText
        }
        // Motion metrics
        if let motionMode = motionMode {
            dict[WatchMessageKey.motionMode.rawValue] = motionMode.rawValue
        }
        if let stanceStability = stanceStability {
            dict[WatchMessageKey.stanceStability.rawValue] = stanceStability
        }
        if let strokeCount = strokeCount {
            dict[WatchMessageKey.strokeCount.rawValue] = strokeCount
        }
        if let strokeRate = strokeRate {
            dict[WatchMessageKey.strokeRate.rawValue] = strokeRate
        }
        if let verticalOscillation = verticalOscillation {
            dict[WatchMessageKey.verticalOscillation.rawValue] = verticalOscillation
        }
        if let groundContactTime = groundContactTime {
            dict[WatchMessageKey.groundContactTime.rawValue] = groundContactTime
        }
        if let cadence = cadence {
            dict[WatchMessageKey.cadence.rawValue] = cadence
        }
        // Ride discipline metrics
        if let walkPercent = walkPercent {
            dict[WatchMessageKey.walkPercent.rawValue] = walkPercent
        }
        if let trotPercent = trotPercent {
            dict[WatchMessageKey.trotPercent.rawValue] = trotPercent
        }
        if let canterPercent = canterPercent {
            dict[WatchMessageKey.canterPercent.rawValue] = canterPercent
        }
        if let gallopPercent = gallopPercent {
            dict[WatchMessageKey.gallopPercent.rawValue] = gallopPercent
        }
        if let leftTurnCount = leftTurnCount {
            dict[WatchMessageKey.leftTurnCount.rawValue] = leftTurnCount
        }
        if let rightTurnCount = rightTurnCount {
            dict[WatchMessageKey.rightTurnCount.rawValue] = rightTurnCount
        }
        if let leftReinPercent = leftReinPercent {
            dict[WatchMessageKey.leftReinPercent.rawValue] = leftReinPercent
        }
        if let rightReinPercent = rightReinPercent {
            dict[WatchMessageKey.rightReinPercent.rawValue] = rightReinPercent
        }
        if let leftLeadPercent = leftLeadPercent {
            dict[WatchMessageKey.leftLeadPercent.rawValue] = leftLeadPercent
        }
        if let rightLeadPercent = rightLeadPercent {
            dict[WatchMessageKey.rightLeadPercent.rawValue] = rightLeadPercent
        }
        if let symmetryScore = symmetryScore {
            dict[WatchMessageKey.symmetryScore.rawValue] = symmetryScore
        }
        if let rhythmScore = rhythmScore {
            dict[WatchMessageKey.rhythmScore.rawValue] = rhythmScore
        }
        if let optimalTime = optimalTime {
            dict[WatchMessageKey.optimalTime.rawValue] = optimalTime
        }
        if let actualTime = actualTime {
            dict[WatchMessageKey.actualTime.rawValue] = actualTime
        }
        if let timeDifference = timeDifference {
            dict[WatchMessageKey.timeDifference.rawValue] = timeDifference
        }
        if let elevation = elevation {
            dict[WatchMessageKey.elevation.rawValue] = elevation
        }
        // Fall detection
        if let fallDetected = fallDetected {
            dict[WatchMessageKey.fallDetected.rawValue] = fallDetected
        }
        if let fallConfidence = fallConfidence {
            dict[WatchMessageKey.fallConfidence.rawValue] = fallConfidence
        }
        if let fallImpactMagnitude = fallImpactMagnitude {
            dict[WatchMessageKey.fallImpactMagnitude.rawValue] = fallImpactMagnitude
        }
        if let fallRotationMagnitude = fallRotationMagnitude {
            dict[WatchMessageKey.fallRotationMagnitude.rawValue] = fallRotationMagnitude
        }
        if let fallCountdown = fallCountdown {
            dict[WatchMessageKey.fallCountdown.rawValue] = fallCountdown
        }
        if let fallResponse = fallResponse {
            dict[WatchMessageKey.fallResponse.rawValue] = fallResponse.rawValue
        }
        // Enhanced sensor data
        if let relativeAltitude = relativeAltitude {
            dict[WatchMessageKey.relativeAltitude.rawValue] = relativeAltitude
        }
        if let altitudeChangeRate = altitudeChangeRate {
            dict[WatchMessageKey.altitudeChangeRate.rawValue] = altitudeChangeRate
        }
        if let barometricPressure = barometricPressure {
            dict[WatchMessageKey.barometricPressure.rawValue] = barometricPressure
        }
        if let isSubmerged = isSubmerged {
            dict[WatchMessageKey.isSubmerged.rawValue] = isSubmerged
        }
        if let waterDepth = waterDepth {
            dict[WatchMessageKey.waterDepth.rawValue] = waterDepth
        }
        if let oxygenSaturation = oxygenSaturation {
            dict[WatchMessageKey.oxygenSaturation.rawValue] = oxygenSaturation
        }
        if let compassHeading = compassHeading {
            dict[WatchMessageKey.compassHeading.rawValue] = compassHeading
        }
        if let breathingRate = breathingRate {
            dict[WatchMessageKey.breathingRate.rawValue] = breathingRate
        }
        if let bodyTemperature = bodyTemperature {
            dict[WatchMessageKey.bodyTemperature.rawValue] = bodyTemperature
        }
        if let posturePitch = posturePitch {
            dict[WatchMessageKey.posturePitch.rawValue] = posturePitch
        }
        if let postureRoll = postureRoll {
            dict[WatchMessageKey.postureRoll.rawValue] = postureRoll
        }
        if let tremorLevel = tremorLevel {
            dict[WatchMessageKey.tremorLevel.rawValue] = tremorLevel
        }
        if let movementIntensity = movementIntensity {
            dict[WatchMessageKey.movementIntensity.rawValue] = movementIntensity
        }

        return dict
    }

    public static func from(dictionary dict: [String: Any]) -> WatchMessage? {
        guard let timestampInterval = dict[WatchMessageKey.timestamp.rawValue] as? TimeInterval else {
            return nil
        }

        let command: WatchCommand? = (dict[WatchMessageKey.command.rawValue] as? String)
            .flatMap { WatchCommand(rawValue: $0) }

        let rideState: SharedRideState? = (dict[WatchMessageKey.rideState.rawValue] as? String)
            .flatMap { SharedRideState(rawValue: $0) }

        let motionMode: WatchMotionModeShared? = (dict[WatchMessageKey.motionMode.rawValue] as? String)
            .flatMap { WatchMotionModeShared(rawValue: $0) }

        let fallResponse: FallResponse? = (dict[WatchMessageKey.fallResponse.rawValue] as? String)
            .flatMap { FallResponse(rawValue: $0) }

        let message = WatchMessage(
            command: command,
            rideState: rideState,
            duration: dict[WatchMessageKey.duration.rawValue] as? TimeInterval,
            distance: dict[WatchMessageKey.distance.rawValue] as? Double,
            speed: dict[WatchMessageKey.speed.rawValue] as? Double,
            gait: dict[WatchMessageKey.gait.rawValue] as? String,
            heartRate: dict[WatchMessageKey.heartRate.rawValue] as? Int,
            heartRateZone: dict[WatchMessageKey.heartRateZone.rawValue] as? Int,
            averageHeartRate: dict[WatchMessageKey.averageHeartRate.rawValue] as? Int,
            maxHeartRate: dict[WatchMessageKey.maxHeartRate.rawValue] as? Int,
            horseName: dict[WatchMessageKey.horseName.rawValue] as? String,
            rideType: dict[WatchMessageKey.rideType.rawValue] as? String,
            voiceNoteText: dict[WatchMessageKey.voiceNoteText.rawValue] as? String,
            motionMode: motionMode,
            stanceStability: dict[WatchMessageKey.stanceStability.rawValue] as? Double,
            strokeCount: dict[WatchMessageKey.strokeCount.rawValue] as? Int,
            strokeRate: dict[WatchMessageKey.strokeRate.rawValue] as? Double,
            verticalOscillation: dict[WatchMessageKey.verticalOscillation.rawValue] as? Double,
            groundContactTime: dict[WatchMessageKey.groundContactTime.rawValue] as? Double,
            cadence: dict[WatchMessageKey.cadence.rawValue] as? Int,
            walkPercent: dict[WatchMessageKey.walkPercent.rawValue] as? Double,
            trotPercent: dict[WatchMessageKey.trotPercent.rawValue] as? Double,
            canterPercent: dict[WatchMessageKey.canterPercent.rawValue] as? Double,
            gallopPercent: dict[WatchMessageKey.gallopPercent.rawValue] as? Double,
            leftTurnCount: dict[WatchMessageKey.leftTurnCount.rawValue] as? Int,
            rightTurnCount: dict[WatchMessageKey.rightTurnCount.rawValue] as? Int,
            leftReinPercent: dict[WatchMessageKey.leftReinPercent.rawValue] as? Double,
            rightReinPercent: dict[WatchMessageKey.rightReinPercent.rawValue] as? Double,
            leftLeadPercent: dict[WatchMessageKey.leftLeadPercent.rawValue] as? Double,
            rightLeadPercent: dict[WatchMessageKey.rightLeadPercent.rawValue] as? Double,
            symmetryScore: dict[WatchMessageKey.symmetryScore.rawValue] as? Double,
            rhythmScore: dict[WatchMessageKey.rhythmScore.rawValue] as? Double,
            optimalTime: dict[WatchMessageKey.optimalTime.rawValue] as? TimeInterval,
            actualTime: dict[WatchMessageKey.actualTime.rawValue] as? TimeInterval,
            timeDifference: dict[WatchMessageKey.timeDifference.rawValue] as? TimeInterval,
            elevation: dict[WatchMessageKey.elevation.rawValue] as? Double,
            fallDetected: dict[WatchMessageKey.fallDetected.rawValue] as? Bool,
            fallConfidence: dict[WatchMessageKey.fallConfidence.rawValue] as? Double,
            fallImpactMagnitude: dict[WatchMessageKey.fallImpactMagnitude.rawValue] as? Double,
            fallRotationMagnitude: dict[WatchMessageKey.fallRotationMagnitude.rawValue] as? Double,
            fallCountdown: dict[WatchMessageKey.fallCountdown.rawValue] as? Int,
            fallResponse: fallResponse,
            // Enhanced sensor data
            relativeAltitude: dict[WatchMessageKey.relativeAltitude.rawValue] as? Double,
            altitudeChangeRate: dict[WatchMessageKey.altitudeChangeRate.rawValue] as? Double,
            barometricPressure: dict[WatchMessageKey.barometricPressure.rawValue] as? Double,
            isSubmerged: dict[WatchMessageKey.isSubmerged.rawValue] as? Bool,
            waterDepth: dict[WatchMessageKey.waterDepth.rawValue] as? Double,
            oxygenSaturation: dict[WatchMessageKey.oxygenSaturation.rawValue] as? Double,
            compassHeading: dict[WatchMessageKey.compassHeading.rawValue] as? Double,
            breathingRate: dict[WatchMessageKey.breathingRate.rawValue] as? Double,
            bodyTemperature: dict[WatchMessageKey.bodyTemperature.rawValue] as? Double,
            posturePitch: dict[WatchMessageKey.posturePitch.rawValue] as? Double,
            postureRoll: dict[WatchMessageKey.postureRoll.rawValue] as? Double,
            tremorLevel: dict[WatchMessageKey.tremorLevel.rawValue] as? Double,
            movementIntensity: dict[WatchMessageKey.movementIntensity.rawValue] as? Double
        )

        return message
    }
}
