//
//  MLTrainingModels.swift
//  TrackRide
//
//  Data models for ML training data collection.
//  Captures manual hole markings as ground truth for future model training.
//

import Foundation
import CoreGraphics
import UIKit

// MARK: - Hole Marking Event

/// Records a single user action on a hole marking - comprehensive for future ML
struct HoleMarkingEvent: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let action: MarkingAction
    let holeId: UUID
    let position: CodablePoint          // Normalized coordinates (0-1)
    let pixelPosition: CodablePoint?    // Pixel coordinates in cropped image
    let estimatedDiameter: Double       // Normalized diameter
    let previousPosition: CodablePoint? // For move actions

    // Timing & interaction data - valuable for understanding user behavior
    let timeSinceLastAction: TimeInterval?  // Hesitation/confidence indicator
    let tapCount: Int?                      // Multiple taps might indicate uncertainty
    let dragDistance: Double?               // For move actions - how far was adjustment
    let zoomLevel: Double?                  // Was user zoomed in when marking?

    // Context that might reveal patterns
    let sequenceNumber: Int                 // Order of action in session
    let totalHolesAtTime: Int               // How many holes marked when action taken

    enum MarkingAction: String, Codable {
        case add
        case move
        case delete
        case confirmAutoDetected    // User confirmed an auto-detected hole
        case rejectAutoDetected     // User deleted an auto-detected hole
        case flagAsTorn             // User flagged hole as torn
        case flagAsOverlapping      // User flagged as overlapping
        case unflag                 // User removed a flag
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        action: MarkingAction,
        holeId: UUID,
        position: CodablePoint,
        pixelPosition: CodablePoint? = nil,
        estimatedDiameter: Double = 0.02,
        previousPosition: CodablePoint? = nil,
        timeSinceLastAction: TimeInterval? = nil,
        tapCount: Int? = nil,
        dragDistance: Double? = nil,
        zoomLevel: Double? = nil,
        sequenceNumber: Int = 0,
        totalHolesAtTime: Int = 0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.action = action
        self.holeId = holeId
        self.position = position
        self.pixelPosition = pixelPosition
        self.estimatedDiameter = estimatedDiameter
        self.previousPosition = previousPosition
        self.timeSinceLastAction = timeSinceLastAction
        self.tapCount = tapCount
        self.dragDistance = dragDistance
        self.zoomLevel = zoomLevel
        self.sequenceNumber = sequenceNumber
        self.totalHolesAtTime = totalHolesAtTime
    }
}

/// CGPoint wrapper for Codable support
struct CodablePoint: Codable {
    let x: Double
    let y: Double

    init(_ point: CGPoint) {
        self.x = point.x
        self.y = point.y
    }

    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

// MARK: - Hole Annotation

/// A single hole annotation with comprehensive metadata for ML training
struct HoleAnnotation: Codable, Identifiable {
    let id: UUID
    var position: CodablePoint              // Normalized coordinates (0-1)
    var pixelPosition: CodablePoint?        // Pixel coordinates
    var estimatedDiameter: Double           // Normalized diameter
    var pixelDiameter: Double?              // Actual pixel diameter
    var targetRegion: TargetHalfRegion      // Black or white half
    var holeCharacteristics: HoleCharacteristics
    var score: Int                          // Scoring ring value (0-10)
    var confidence: Double                  // User confidence (1.0 for manual)

    // Source tracking - how was this hole identified?
    var source: HoleSource
    var wasAutoDetected: Bool               // Was initially auto-detected
    var wasUserCorrected: Bool              // User moved/adjusted position
    var autoDetectionConfidence: Double?    // Original auto-detection confidence

    // Local image analysis at hole location (for ML features)
    var localFeatures: LocalImageFeatures?

    init(
        id: UUID = UUID(),
        position: CGPoint,
        pixelPosition: CGPoint? = nil,
        estimatedDiameter: Double = 0.02,
        pixelDiameter: Double? = nil,
        targetRegion: TargetHalfRegion = .unknown,
        holeCharacteristics: HoleCharacteristics = .normal,
        score: Int = 0,
        confidence: Double = 1.0,
        source: HoleSource = .manualAdd,
        wasAutoDetected: Bool = false,
        wasUserCorrected: Bool = false,
        autoDetectionConfidence: Double? = nil,
        localFeatures: LocalImageFeatures? = nil
    ) {
        self.id = id
        self.position = CodablePoint(position)
        self.pixelPosition = pixelPosition.map { CodablePoint($0) }
        self.estimatedDiameter = estimatedDiameter
        self.pixelDiameter = pixelDiameter
        self.targetRegion = targetRegion
        self.holeCharacteristics = holeCharacteristics
        self.score = score
        self.confidence = confidence
        self.source = source
        self.wasAutoDetected = wasAutoDetected
        self.wasUserCorrected = wasUserCorrected
        self.autoDetectionConfidence = autoDetectionConfidence
        self.localFeatures = localFeatures
    }
}

/// How the hole was identified
enum HoleSource: String, Codable {
    case manualAdd              // User tapped to add
    case autoDetectedAccepted   // Auto-detected and user kept it
    case autoDetectedCorrected  // Auto-detected but user moved it
}

/// Local image features extracted at hole location - valuable for ML
struct LocalImageFeatures: Codable {
    // Intensity features
    var centerIntensity: Double             // Grayscale value at center (0-255)
    var backgroundIntensity: Double         // Average background intensity
    var intensityContrast: Double           // Difference between center and background
    var localStandardDeviation: Double      // Texture measure

    // Edge features
    var edgeStrength: Double                // Sobel magnitude at boundary
    var edgeContinuity: Double              // How complete is the edge ring (0-1)

    // Shape features
    var measuredCircularity: Double         // How circular (0-1, 1=perfect circle)
    var aspectRatio: Double                 // Major/minor axis ratio
    var boundingBoxWidth: Double            // Bounding box in pixels
    var boundingBoxHeight: Double

    // Color features (if color image available)
    var redChannel: Double?
    var greenChannel: Double?
    var blueChannel: Double?
    var saturation: Double?

    // Histogram features in local region
    var histogramSkewness: Double?          // Distribution shape
    var histogramKurtosis: Double?

    static var empty: LocalImageFeatures {
        LocalImageFeatures(
            centerIntensity: 0, backgroundIntensity: 0, intensityContrast: 0,
            localStandardDeviation: 0, edgeStrength: 0, edgeContinuity: 0,
            measuredCircularity: 0, aspectRatio: 1, boundingBoxWidth: 0,
            boundingBoxHeight: 0, redChannel: nil, greenChannel: nil,
            blueChannel: nil, saturation: nil, histogramSkewness: nil,
            histogramKurtosis: nil
        )
    }
}

/// Which half of the target the hole is on
enum TargetHalfRegion: String, Codable {
    case black
    case white
    case transition  // Near the boundary
    case unknown
}

/// Special characteristics of a hole
struct HoleCharacteristics: Codable {
    var isTorn: Bool = false            // Torn/irregular edge
    var isOverlapping: Bool = false     // Overlaps with another hole
    var isPartial: Bool = false         // Partially visible (edge of target)
    var isDoubleHole: Bool = false      // Two holes very close together

    nonisolated static let normal = HoleCharacteristics()
}

// MARK: - Image Metadata

/// Comprehensive metadata about the captured image - store everything for future ML
struct CaptureMetadata: Codable {
    // Basic capture info
    let captureTimestamp: Date
    let deviceModel: String
    let deviceOS: String

    // Image dimensions
    let imageWidth: Int
    let imageHeight: Int
    let croppedWidth: Int
    let croppedHeight: Int

    // Camera settings (when available from EXIF)
    let estimatedLighting: LightingCondition
    let hasFlash: Bool
    let focalLength: Double?
    let exposureTime: Double?
    let iso: Int?
    let aperture: Double?
    let whiteBalance: String?

    // Orientation & transform
    let rotationDegrees: Double
    let skewDetected: Bool
    let cropRect: CodableRect?          // Where was crop applied

    // Image quality metrics
    let sharpnessScore: Double?         // Laplacian variance
    let contrastScore: Double?          // Dynamic range
    let noiseLevel: Double?             // Estimated noise
    let brightnessScore: Double?        // Overall brightness

    // Target-specific analysis
    let blackRegionMean: Double?        // Mean intensity of black half
    let whiteRegionMean: Double?        // Mean intensity of white half
    let blackWhiteContrast: Double?     // Contrast between halves
    let transitionLineX: Double?        // Normalized X of black/white boundary
    let isLeftSideBlack: Bool?          // Which side is black

    // Session context
    let sessionDurationSeconds: Double? // How long user spent on this capture
    let retakeCount: Int                // How many times user retook photo

    // App version for tracking algorithm changes
    let appVersion: String
    let algorithmVersion: String

    static func capture(
        originalSize: CGSize,
        croppedSize: CGSize,
        lighting: LightingCondition = .unknown,
        hasFlash: Bool = false,
        rotation: Double = 0,
        cropRect: CGRect? = nil,
        imageAnalysis: ImageAnalysisMetrics? = nil,
        sessionDuration: TimeInterval? = nil,
        retakeCount: Int = 0
    ) -> CaptureMetadata {
        CaptureMetadata(
            captureTimestamp: Date(),
            deviceModel: Self.deviceModel,
            deviceOS: Self.osVersion,
            imageWidth: Int(originalSize.width),
            imageHeight: Int(originalSize.height),
            croppedWidth: Int(croppedSize.width),
            croppedHeight: Int(croppedSize.height),
            estimatedLighting: lighting,
            hasFlash: hasFlash,
            focalLength: nil,
            exposureTime: nil,
            iso: nil,
            aperture: nil,
            whiteBalance: nil,
            rotationDegrees: rotation,
            skewDetected: false,
            cropRect: cropRect.map { CodableRect($0) },
            sharpnessScore: imageAnalysis?.sharpness,
            contrastScore: imageAnalysis?.contrast,
            noiseLevel: imageAnalysis?.noise,
            brightnessScore: imageAnalysis?.brightness,
            blackRegionMean: imageAnalysis?.blackMean,
            whiteRegionMean: imageAnalysis?.whiteMean,
            blackWhiteContrast: imageAnalysis?.blackWhiteContrast,
            transitionLineX: imageAnalysis?.transitionX,
            isLeftSideBlack: imageAnalysis?.isLeftBlack,
            sessionDurationSeconds: sessionDuration,
            retakeCount: retakeCount,
            appVersion: Self.appVersion,
            algorithmVersion: "2.0.0"
        )
    }

    private static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    private static var osVersion: String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
    }

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
}

/// Image analysis metrics computed from the captured image
struct ImageAnalysisMetrics: Codable {
    var sharpness: Double
    var contrast: Double
    var noise: Double
    var brightness: Double
    var blackMean: Double
    var whiteMean: Double
    var blackWhiteContrast: Double
    var transitionX: Double
    var isLeftBlack: Bool
}

/// CGRect wrapper for Codable support
struct CodableRect: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(_ rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.size.width
        self.height = rect.size.height
    }

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

/// Estimated lighting condition
enum LightingCondition: String, Codable {
    case brightOutdoor      // Direct sunlight
    case cloudyOutdoor      // Overcast outdoor
    case brightIndoor       // Well-lit indoor
    case dimIndoor          // Low indoor light
    case flash              // Camera flash used
    case mixed              // Mixed lighting
    case unknown
}

// MARK: - Training Target Capture

/// Complete training sample: image + annotations + metadata
struct TrainingTargetCapture: Codable, Identifiable {
    let id: UUID
    let captureTimestamp: Date
    let imageFilename: String           // Relative path to saved image
    let thumbnailFilename: String?      // Optional thumbnail
    let metadata: CaptureMetadata
    var annotations: [HoleAnnotation]
    var markingEvents: [HoleMarkingEvent]
    let targetType: TargetType
    let sessionContext: SessionContext?

    /// Summary statistics for this capture
    var stats: CaptureStats {
        CaptureStats(
            totalHoles: annotations.count,
            blackRegionHoles: annotations.filter { $0.targetRegion == .black }.count,
            whiteRegionHoles: annotations.filter { $0.targetRegion == .white }.count,
            tornHoles: annotations.filter { $0.holeCharacteristics.isTorn }.count,
            overlappingHoles: annotations.filter { $0.holeCharacteristics.isOverlapping }.count,
            totalCorrections: markingEvents.filter { $0.action == .move || $0.action == .delete }.count
        )
    }
}

/// Type of target being scanned
enum TargetType: String, Codable {
    case tetrathlon          // Standard tetrathlon target (black/white halves)
    case fullCircular        // Full circular target
    case practice            // Practice/free practice target
    case unknown
}

/// Context about the shooting session
struct SessionContext: Codable {
    let sessionId: UUID?
    let competitionId: UUID?
    let shotNumber: Int?        // Which shot in the series
    let totalShots: Int?        // Expected total shots
    let practiceMode: Bool
}

/// Summary statistics for a capture
struct CaptureStats: Codable {
    let totalHoles: Int
    let blackRegionHoles: Int
    let whiteRegionHoles: Int
    let tornHoles: Int
    let overlappingHoles: Int
    let totalCorrections: Int

    var correctionRate: Double {
        totalHoles > 0 ? Double(totalCorrections) / Double(totalHoles) : 0
    }
}

// MARK: - Training Dataset Manifest

/// Manifest file for the entire training dataset
struct TrainingDatasetManifest: Codable {
    var version: String = "1.0"
    var createdAt: Date
    var lastUpdatedAt: Date
    var captures: [TrainingCaptureReference]
    var datasetStats: DatasetStats

    struct TrainingCaptureReference: Codable {
        let captureId: UUID
        let filename: String
        let captureDate: Date
        let holeCount: Int
        let hasBlackRegionHoles: Bool
        let hasOverlappingHoles: Bool
    }

    struct DatasetStats: Codable {
        var totalCaptures: Int
        var totalHoles: Int
        var blackRegionHoles: Int
        var whiteRegionHoles: Int
        var tornHoles: Int
        var overlappingHoles: Int
        var totalCorrections: Int

        static var empty: DatasetStats {
            DatasetStats(
                totalCaptures: 0, totalHoles: 0, blackRegionHoles: 0,
                whiteRegionHoles: 0, tornHoles: 0, overlappingHoles: 0,
                totalCorrections: 0
            )
        }

        mutating func add(_ stats: CaptureStats) {
            totalCaptures += 1
            totalHoles += stats.totalHoles
            blackRegionHoles += stats.blackRegionHoles
            whiteRegionHoles += stats.whiteRegionHoles
            tornHoles += stats.tornHoles
            overlappingHoles += stats.overlappingHoles
            totalCorrections += stats.totalCorrections
        }
    }
}

// MARK: - Simulator Fixture

/// Metadata for simulator test fixtures
struct FixtureMetadataV2: Codable {
    let version: String
    let imageFile: String
    let category: FixtureCategory
    let difficulty: FixtureDifficulty
    let lighting: LightingCondition
    let holes: [FixtureHole]
    let expectedMetrics: ExpectedMetrics

    struct FixtureHole: Codable {
        let id: Int
        let x: Double                   // Normalized X (0-1)
        let y: Double                   // Normalized Y (0-1)
        let region: TargetHalfRegion
        let isTorn: Bool
        let isOverlapping: Bool
        let score: Int
        let matchTolerance: Double      // Tolerance for matching (normalized)
    }

    struct ExpectedMetrics: Codable {
        let minRecall: Double           // Minimum acceptable recall
        let minPrecision: Double        // Minimum acceptable precision
        let maxCorrections: Int         // Maximum expected user corrections
    }

    enum FixtureCategory: String, Codable {
        case clean              // Clean holes, good contrast
        case torn               // Torn/irregular holes
        case overlapping        // Overlapping holes
        case lowContrast        // Poor lighting/contrast
        case blackRegion        // Holes primarily in black region
        case mixed              // Mix of conditions
    }

    enum FixtureDifficulty: String, Codable {
        case easy
        case medium
        case hard
        case extreme
    }
}

// MARK: - Evaluation Results

/// Results from evaluating detection against ground truth
struct DetectionEvaluationResult: Codable {
    let evaluationTimestamp: Date
    let fixtureId: String?
    let captureId: UUID?
    let algorithmVersion: String

    // Core metrics
    let truePositives: Int
    let falsePositives: Int
    let falseNegatives: Int

    // Derived metrics
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

    // Breakdown by region
    var blackRegionMetrics: RegionMetrics?
    var whiteRegionMetrics: RegionMetrics?

    // User correction metrics
    var userCorrections: Int
    var correctionRate: Double {
        let total = truePositives + falseNegatives
        return total > 0 ? Double(userCorrections) / Double(total) : 0
    }

    struct RegionMetrics: Codable {
        let truePositives: Int
        let falsePositives: Int
        let falseNegatives: Int

        var precision: Double {
            let total = truePositives + falsePositives
            return total > 0 ? Double(truePositives) / Double(total) : 0
        }

        var recall: Double {
            let total = truePositives + falseNegatives
            return total > 0 ? Double(truePositives) / Double(total) : 0
        }
    }
}
