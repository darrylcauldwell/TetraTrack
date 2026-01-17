//
//  DebugPipelineTypes.swift
//  TrackRide
//
//  Debug types for the detection pipeline, used by both Services and Views.
//

import Foundation
import SwiftUI

// MARK: - Debug Pipeline State

/// State from detection pipeline for visualization
struct DebugPipelineState {
    /// Crop geometry
    var cropGeometry: TargetCropGeometry?

    /// All candidate holes before filtering
    var candidateHoles: [DebugHoleCandidate] = []

    /// Holes filtered out (scoring ring artifacts, etc.)
    var filteredHoles: [DebugHoleCandidate] = []

    /// Final accepted holes
    var acceptedHoles: [DebugHoleCandidate] = []

    /// Local background sample regions
    var backgroundRegions: [DebugBackgroundRegion] = []

    /// Pattern analysis result
    var patternAnalysis: PatternAnalysis?

    /// Processing stages completed
    var completedStages: Set<PipelineStage> = []

    /// Timing for each stage
    var stageTiming: [PipelineStage: TimeInterval] = [:]

    enum PipelineStage: String, CaseIterable {
        case imageAcquisition = "Acquisition"
        case qualityAssessment = "Quality"
        case contourDetection = "Contours"
        case candidateFiltering = "Filtering"
        case confidenceScoring = "Scoring"
        case patternAnalysis = "Analysis"
    }
}

/// Debug representation of a hole candidate
struct DebugHoleCandidate: Identifiable {
    let id = UUID()
    let pixelPosition: CGPoint
    let normalizedPosition: NormalizedTargetPosition
    let radiusPixels: CGFloat
    let confidence: Double
    let filterReason: String?
    let features: [String: Double]
}

/// Debug representation of a background sample region
struct DebugBackgroundRegion: Identifiable {
    let id = UUID()
    let center: CGPoint
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let meanIntensity: Double
    let stdDev: Double
}
