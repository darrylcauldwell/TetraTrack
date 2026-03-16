//
//  WatchGaitResult.swift
//  TetraTrackShared
//
//  Gait classification result from Watch DSP pipeline, sent to iPhone at 1Hz.
//

import Foundation

/// Gait classification result produced by WatchGaitAnalyzer and consumed by iPhone's RidingPlugin
public struct WatchGaitResult: Codable, Sendable {
    /// Gait state as string ("walk", "trot", "canter", "gallop", "stationary")
    public let gaitState: String

    /// Confidence in classification (0-1)
    public let confidence: Double

    /// Dominant stride frequency (Hz)
    public let strideFrequency: Double

    /// Normalized vertical RMS (bounce amplitude)
    public let bounceAmplitude: Double

    /// XY coherence measuring lateral symmetry (0-1)
    public let lateralSymmetry: Double

    /// Canter lead ("left", "right", or nil if not in canter)
    public let canterLead: String?

    /// Confidence in canter lead detection (0-1)
    public let canterLeadConfidence: Double

    /// Timestamp of this result
    public let timestamp: Date

    public init(
        gaitState: String,
        confidence: Double,
        strideFrequency: Double,
        bounceAmplitude: Double,
        lateralSymmetry: Double,
        canterLead: String?,
        canterLeadConfidence: Double,
        timestamp: Date
    ) {
        self.gaitState = gaitState
        self.confidence = confidence
        self.strideFrequency = strideFrequency
        self.bounceAmplitude = bounceAmplitude
        self.lateralSymmetry = lateralSymmetry
        self.canterLead = canterLead
        self.canterLeadConfidence = canterLeadConfidence
        self.timestamp = timestamp
    }
}
