//
//  DetectedShotMetrics.swift
//  TetraTrackShared
//
//  Per-shot metrics computed by Watch-side ShootingShotDetector
//  Shared between Watch (producer) and iPhone (consumer)
//

import Foundation

/// Phase of the shot cycle detected by the state machine
public enum ShotPhase: String, Codable, Sendable {
    case idle
    case raise
    case settle
    case hold
    case shot
    case recovery
}

/// Per-shot metrics computed on Watch from 50Hz IMU data
public struct DetectedShotMetrics: Codable, Sendable, Identifiable {
    public let id: UUID
    public let shotIndex: Int
    public let timestamp: Date

    // Phase timings (seconds)
    public let raiseDuration: Double
    public let settleDuration: Double
    public let holdDuration: Double
    public let totalCycleTime: Double

    // Quality metrics (0-100)
    public let raiseSmoothness: Double
    public let holdSteadiness: Double
    public let tremorIntensity: Double
    public let driftMagnitude: Double

    // Raw variance values for iPhone analysis
    public let holdPitchVariance: Double
    public let holdYawVariance: Double

    // Heart rate at shot moment
    public let heartRateAtShot: Int?

    public init(
        shotIndex: Int,
        timestamp: Date = Date(),
        raiseDuration: Double,
        settleDuration: Double,
        holdDuration: Double,
        totalCycleTime: Double,
        raiseSmoothness: Double,
        holdSteadiness: Double,
        tremorIntensity: Double,
        driftMagnitude: Double,
        holdPitchVariance: Double,
        holdYawVariance: Double,
        heartRateAtShot: Int? = nil
    ) {
        self.id = UUID()
        self.shotIndex = shotIndex
        self.timestamp = timestamp
        self.raiseDuration = raiseDuration
        self.settleDuration = settleDuration
        self.holdDuration = holdDuration
        self.totalCycleTime = totalCycleTime
        self.raiseSmoothness = raiseSmoothness
        self.holdSteadiness = holdSteadiness
        self.tremorIntensity = tremorIntensity
        self.driftMagnitude = driftMagnitude
        self.holdPitchVariance = holdPitchVariance
        self.holdYawVariance = holdYawVariance
        self.heartRateAtShot = heartRateAtShot
    }

    // MARK: - JSON Conversion

    public func toJSON() -> Data? {
        try? JSONEncoder().encode(self)
    }

    public static func from(json data: Data) -> DetectedShotMetrics? {
        try? JSONDecoder().decode(DetectedShotMetrics.self, from: data)
    }

    public static func arrayFrom(json data: Data) -> [DetectedShotMetrics] {
        (try? JSONDecoder().decode([DetectedShotMetrics].self, from: data)) ?? []
    }

    // MARK: - Dictionary Conversion (for WCSession.sendMessage)

    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "type": "shootingShotDetected",
            "shotIndex": shotIndex,
            "timestamp": timestamp.timeIntervalSince1970,
            "raiseDuration": raiseDuration,
            "settleDuration": settleDuration,
            "holdDuration": holdDuration,
            "totalCycleTime": totalCycleTime,
            "raiseSmoothness": raiseSmoothness,
            "holdSteadiness": holdSteadiness,
            "tremorIntensity": tremorIntensity,
            "driftMagnitude": driftMagnitude,
            "holdPitchVariance": holdPitchVariance,
            "holdYawVariance": holdYawVariance
        ]
        if let hr = heartRateAtShot {
            dict["heartRateAtShot"] = hr
        }
        return dict
    }

    public static func from(dictionary dict: [String: Any]) -> DetectedShotMetrics? {
        guard let shotIndex = dict["shotIndex"] as? Int,
              let timestampInterval = dict["timestamp"] as? TimeInterval,
              let raiseDuration = dict["raiseDuration"] as? Double,
              let settleDuration = dict["settleDuration"] as? Double,
              let holdDuration = dict["holdDuration"] as? Double,
              let totalCycleTime = dict["totalCycleTime"] as? Double,
              let raiseSmoothness = dict["raiseSmoothness"] as? Double,
              let holdSteadiness = dict["holdSteadiness"] as? Double,
              let tremorIntensity = dict["tremorIntensity"] as? Double,
              let driftMagnitude = dict["driftMagnitude"] as? Double,
              let holdPitchVariance = dict["holdPitchVariance"] as? Double,
              let holdYawVariance = dict["holdYawVariance"] as? Double
        else { return nil }

        return DetectedShotMetrics(
            shotIndex: shotIndex,
            timestamp: Date(timeIntervalSince1970: timestampInterval),
            raiseDuration: raiseDuration,
            settleDuration: settleDuration,
            holdDuration: holdDuration,
            totalCycleTime: totalCycleTime,
            raiseSmoothness: raiseSmoothness,
            holdSteadiness: holdSteadiness,
            tremorIntensity: tremorIntensity,
            driftMagnitude: driftMagnitude,
            holdPitchVariance: holdPitchVariance,
            holdYawVariance: holdYawVariance,
            heartRateAtShot: dict["heartRateAtShot"] as? Int
        )
    }
}
