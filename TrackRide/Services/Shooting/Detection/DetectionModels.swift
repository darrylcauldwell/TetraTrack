//
//  DetectionModels.swift
//  TrackRide
//
//  Data models for multi-signal bullet hole detection pipeline v2.0
//  Supports .22 calibre hole detection on tetrathlon target cards.
//

import Foundation
import CoreGraphics
import UIKit

// MARK: - Detection Signal Types

/// The detection signal that identified a candidate
enum DetectionSignal: String, CaseIterable, Hashable {
    case darkAnomaly        // Signal A: Dark spot on light region
    case lightAnomaly       // Signal B: Light spot on dark region
    case edgeRing           // Signal C: Circular edge pattern
    case textureChange      // Signal D: Texture discontinuity
    case logBlob            // Signal E: Laplacian of Gaussian blob
    case userAdded          // Manually added by user
}

/// Target region classification
enum TargetRegion: Int, Hashable {
    case white = 0
    case black = 1
    case transition = 2
    case unknown = -1
}

// MARK: - Detection Candidate

/// A potential hole candidate before final classification
struct DetectionCandidate: Identifiable {
    let id: UUID
    var center: CGPoint                     // Normalized coordinates (0-1)
    var pixelCenter: CGPoint                // Pixel coordinates
    var estimatedRadius: Double             // Normalized radius
    var pixelRadius: Double                 // Pixel radius
    var signals: Set<DetectionSignal>       // Which signals detected this
    var rawScores: [DetectionSignal: Double] // Raw score per signal
    var region: TargetRegion
    var features: CandidateFeatures?
    var confidence: Double = 0.0
    var needsReview: Bool = false
    var reviewReason: ReviewReason?
    var parentCandidateId: UUID?            // If split from another candidate

    init(
        center: CGPoint,
        pixelCenter: CGPoint,
        estimatedRadius: Double,
        pixelRadius: Double,
        signal: DetectionSignal,
        rawScore: Double,
        region: TargetRegion
    ) {
        self.id = UUID()
        self.center = center
        self.pixelCenter = pixelCenter
        self.estimatedRadius = estimatedRadius
        self.pixelRadius = pixelRadius
        self.signals = [signal]
        self.rawScores = [signal: rawScore]
        self.region = region
    }

    /// Number of independent signals that detected this candidate
    var signalCount: Int { signals.count }

    /// Best raw score across all signals
    var bestRawScore: Double {
        rawScores.values.max() ?? 0.0
    }

    /// Merge another candidate into this one
    mutating func merge(with other: DetectionCandidate) {
        let totalSignals = Double(self.signalCount + other.signalCount)
        let selfWeight = Double(self.signalCount) / totalSignals
        let otherWeight = Double(other.signalCount) / totalSignals

        self.center = CGPoint(
            x: self.center.x * selfWeight + other.center.x * otherWeight,
            y: self.center.y * selfWeight + other.center.y * otherWeight
        )
        self.pixelCenter = CGPoint(
            x: self.pixelCenter.x * selfWeight + other.pixelCenter.x * otherWeight,
            y: self.pixelCenter.y * selfWeight + other.pixelCenter.y * otherWeight
        )
        self.estimatedRadius = (self.estimatedRadius + other.estimatedRadius) / 2
        self.pixelRadius = (self.pixelRadius + other.pixelRadius) / 2
        self.signals.formUnion(other.signals)

        for (signal, score) in other.rawScores {
            if let existing = self.rawScores[signal] {
                self.rawScores[signal] = max(existing, score)
            } else {
                self.rawScores[signal] = score
            }
        }
    }
}

/// Reason a candidate was flagged for review
enum ReviewReason: String {
    case lowConfidence = "Low confidence score"
    case possibleOverlap = "Possible overlapping holes"
    case irregularShape = "Irregular shape detected"
    case ambiguousRegion = "Near black/white boundary"
    case unusualSize = "Unusual hole size"
    case singleSignal = "Single detection signal"
}

// MARK: - Candidate Features (11 features)

/// Feature vector extracted for each candidate
struct CandidateFeatures {
    // Intensity features
    var intensityDelta: Double          // (I_center - I_background) / 255, range [-1, 1]
    var contrastRatio: Double           // |I_center - I_background| / σ_background

    // Edge features
    var edgeClosure: Double             // Fraction of boundary with strong edge [0, 1]
    var edgeStrength: Double            // Mean edge magnitude at boundary [0, 1]

    // Shape features
    var compactness: Double             // 4π·Area / Perimeter² [0, 1]
    var aspectRatio: Double             // Major axis / Minor axis [1, ∞)

    // Size features
    var sizeConformance: Double         // Gaussian fit to expected size [0, 1]

    // Detection features
    var signalCount: Int                // Number of signals [1, 5]

    // Context features
    var regionType: TargetRegion        // White or Black
    var ringProximity: Double           // Distance to target center (normalized)
    var isolation: Double               // Distance to nearest candidate (normalized)

    static var empty: CandidateFeatures {
        CandidateFeatures(
            intensityDelta: 0,
            contrastRatio: 0,
            edgeClosure: 0,
            edgeStrength: 0,
            compactness: 0,
            aspectRatio: 1,
            sizeConformance: 0,
            signalCount: 0,
            regionType: .unknown,
            ringProximity: 0,
            isolation: 1
        )
    }
}

// MARK: - Image Analysis Results

/// Analysis of target image regions
struct TargetRegionAnalysis {
    var blackRegionMean: Double
    var blackRegionStd: Double
    var whiteRegionMean: Double
    var whiteRegionStd: Double
    var transitionX: Int                // Pixel X coordinate of transition
    var transitionXNormalized: Double   // Normalized [0, 1]
    var isLeftBlack: Bool               // True if black region is on left
    var overallContrast: Double         // Global contrast measure
    var sharpness: Double               // Laplacian variance

    var isValid: Bool {
        abs(whiteRegionMean - blackRegionMean) > 50 && overallContrast > 0.3
    }
}

// MARK: - Detection Result

/// Final detection result from the pipeline
struct HoleDetectionResult {
    var acceptedHoles: [DetectedHole]
    var flaggedCandidates: [DetectedHole]
    var rejectedCount: Int
    var qualityWarnings: [String]
    var regionAnalysis: TargetRegionAnalysis
    var processingTimeMs: Int
    var diagnostics: DetectionDiagnostics?

    var allHoles: [DetectedHole] {
        acceptedHoles + flaggedCandidates
    }

    var totalCandidatesProcessed: Int {
        acceptedHoles.count + flaggedCandidates.count + rejectedCount
    }
}

// MARK: - Diagnostics

/// Comprehensive diagnostics for debugging and tuning
struct DetectionDiagnostics {
    var algorithmVersion: String = "2.0.0"
    var imageSize: CGSize
    var expectedRadiusPx: Int
    var minRadiusPx: Int
    var maxRadiusPx: Int

    // Signal generation counts
    var signalACandidates: Int = 0      // Dark anomaly
    var signalBCandidates: Int = 0      // Light anomaly
    var signalCCandidates: Int = 0      // Edge ring
    var signalDCandidates: Int = 0      // Texture
    var signalECandidates: Int = 0      // LoG
    var mergedCandidates: Int = 0

    // Timing
    var regionAnalysisMs: Int = 0
    var signalGenerationMs: Int = 0
    var featureExtractionMs: Int = 0
    var scoringMs: Int = 0
    var totalMs: Int = 0

    // Candidate details (for debugging)
    var allCandidates: [CandidateDiagnostic] = []
}

/// Diagnostic info for a single candidate
struct CandidateDiagnostic {
    var id: UUID
    var position: CGPoint
    var region: TargetRegion
    var signals: Set<DetectionSignal>
    var features: CandidateFeatures?
    var confidence: Double
    var classification: String  // "accept", "flag", "reject"
}

// MARK: - Detection Configuration

/// Configuration for the detection pipeline
struct HoleDetectionConfiguration {
    // Size parameters
    var expectedHoleRadiusPercent: Double = 0.02    // 2% of image dimension
    var sizeToleranceMin: Double = 0.33             // Min = expected × 0.33
    var sizeToleranceMax: Double = 3.0              // Max = expected × 3.0

    // Signal thresholds
    var signalAContrastThreshold: Double = 12       // Dark anomaly contrast
    var signalBContrastThreshold: Double = 10       // Light anomaly contrast
    var signalCEdgeThreshold: Double = 0.15         // Edge ring threshold
    var signalDTextureThreshold: Double = 0.5       // Texture ratio threshold
    var signalELoGThreshold: Double = 0.3           // LoG response threshold

    // Merging
    var mergeRadiusFraction: Double = 0.6           // Merge within 0.6 × expectedRadius

    // Classification thresholds
    var autoAcceptThreshold: Double = 0.85
    var reviewThreshold: Double = 0.50

    // Feature flags
    var enableSignalC: Bool = true
    var enableSignalD: Bool = false  // Expensive, disabled by default
    var enableSignalE: Bool = false  // Expensive, disabled by default
    var enableOverlapDetection: Bool = true
    var enableDiagnostics: Bool = true

    static var `default`: HoleDetectionConfiguration {
        HoleDetectionConfiguration()
    }

    static var highRecall: HoleDetectionConfiguration {
        var config = HoleDetectionConfiguration()
        config.signalAContrastThreshold = 8
        config.signalBContrastThreshold = 6
        config.reviewThreshold = 0.40
        return config
    }

    static var highPrecision: HoleDetectionConfiguration {
        var config = HoleDetectionConfiguration()
        config.signalAContrastThreshold = 15
        config.signalBContrastThreshold = 12
        config.autoAcceptThreshold = 0.90
        return config
    }
}

// MARK: - Blob Structure

/// Connected region for shape analysis
struct Blob {
    var pixels: [(x: Int, y: Int)]
    var boundingBox: CGRect

    var area: Int { pixels.count }

    var centroid: CGPoint {
        guard !pixels.isEmpty else { return .zero }
        let sumX = pixels.reduce(0) { $0 + $1.x }
        let sumY = pixels.reduce(0) { $0 + $1.y }
        return CGPoint(
            x: Double(sumX) / Double(pixels.count),
            y: Double(sumY) / Double(pixels.count)
        )
    }

    var perimeter: Double {
        var boundaryCount = 0
        let pixelSet = Set(pixels.map { "\($0.x),\($0.y)" })
        for pixel in pixels {
            let neighbors = [
                (pixel.x - 1, pixel.y), (pixel.x + 1, pixel.y),
                (pixel.x, pixel.y - 1), (pixel.x, pixel.y + 1)
            ]
            if neighbors.contains(where: { !pixelSet.contains("\($0.0),\($0.1)") }) {
                boundaryCount += 1
            }
        }
        return Double(boundaryCount)
    }

    var compactness: Double {
        let p = perimeter
        guard p > 0 else { return 0 }
        return 4 * .pi * Double(area) / (p * p)
    }

    var aspectRatio: Double {
        guard pixels.count > 2 else { return 1 }
        let center = centroid

        var cxx: Double = 0, cyy: Double = 0, cxy: Double = 0
        for pixel in pixels {
            let dx = Double(pixel.x) - center.x
            let dy = Double(pixel.y) - center.y
            cxx += dx * dx
            cyy += dy * dy
            cxy += dx * dy
        }

        let n = Double(pixels.count)
        cxx /= n; cyy /= n; cxy /= n

        let trace = cxx + cyy
        let det = cxx * cyy - cxy * cxy
        let discriminant = sqrt(max(0, trace * trace / 4 - det))
        let lambda1 = trace / 2 + discriminant
        let lambda2 = max(0.001, trace / 2 - discriminant)

        return sqrt(lambda1 / lambda2)
    }
}

// MARK: - Evaluation Metrics

struct DetectionEvaluationMetrics {
    var truePositives: Int = 0
    var falsePositives: Int = 0
    var falseNegatives: Int = 0
    var totalGroundTruth: Int = 0

    var precision: Double {
        let total = truePositives + falsePositives
        return total > 0 ? Double(truePositives) / Double(total) : 0
    }

    var recall: Double {
        let total = truePositives + falseNegatives
        return total > 0 ? Double(truePositives) / Double(total) : 0
    }

    var f1Score: Double {
        let p = precision, r = recall
        return (p + r) > 0 ? 2 * p * r / (p + r) : 0
    }
}

// MARK: - Quality Assessment

/// Pre-detection image quality metrics
struct HoleDetectionQualityAssessment {
    var sharpness: Double           // Laplacian variance (higher = sharper)
    var contrast: Double            // (P95 - P5) / 255 [0, 1]
    var whiteExposure: Double       // Mean intensity of white region [0, 255]
    var blackExposure: Double       // Mean intensity of black region [0, 255]
    var blackVisibility: Double     // Variance in black region (for hole visibility)
    var noiseLevel: Double          // Estimated noise level
    var transitionX: Double         // Normalized X of black/white transition [0, 1]

    var isAcceptable: Bool {
        sharpness > 50 && contrast > 0.3
    }
}

// MARK: - Ground Truth (for testing)

struct GroundTruthHole: Codable {
    var id: Int
    var x: Double
    var y: Double
    var region: String
    var isOverlapping: Bool
    var matchTolerance: Double

    var normalizedPosition: CGPoint {
        CGPoint(x: x, y: y)
    }
}

struct FixtureMetadata: Codable {
    var imageFile: String
    var category: String
    var difficulty: String
    var holes: [GroundTruthHole]
    var expectedMinRecall: Double
    var expectedMinPrecision: Double
}
