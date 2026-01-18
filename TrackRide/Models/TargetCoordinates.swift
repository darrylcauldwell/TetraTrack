//
//  TargetCoordinates.swift
//  TrackRide
//
//  Target-centric coordinate system for shooting analysis.
//  All shot positions are normalized relative to target center.
//

import Foundation
import CoreGraphics

// MARK: - Coordinate System Version

/// Version tracking for coordinate system semantics
/// Increment when coordinate interpretation changes
struct CoordinateSystemVersion: Codable, Equatable {
    static let current = CoordinateSystemVersion(major: 1, minor: 0)

    let major: Int
    let minor: Int

    var isCompatible: Bool {
        major == Self.current.major
    }
}

// MARK: - Normalized Target Position

/// Shot position in target-centric normalized coordinates
/// Origin: Target center (0, 0)
/// X-axis: Positive = right, Negative = left
/// Y-axis: Positive = up, Negative = down
/// Units: Normalized target radius (-1 to +1 for shots at target edge)
struct NormalizedTargetPosition: Codable, Equatable, Hashable {
    let x: Double  // -1.0 (left edge) to +1.0 (right edge)
    let y: Double  // -1.0 (bottom) to +1.0 (top)

    /// Coordinate system version for data integrity
    private let coordinateSystemVersion: Int

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
        self.coordinateSystemVersion = CoordinateSystemVersion.current.major
    }

    /// Distance from center (0 to 1+ for shots outside target)
    var radialDistance: Double {
        sqrt(x * x + y * y)
    }

    /// Elliptical distance accounting for oval targets
    /// - Parameter aspectRatio: width/height ratio of target
    func ellipticalDistance(aspectRatio: Double) -> Double {
        let normalizedX = x / aspectRatio
        return sqrt(normalizedX * normalizedX + y * y)
    }

    /// Angle from center in degrees (0 = right, 90 = up, 180 = left, -90 = down)
    var angleDegrees: Double {
        atan2(y, x) * 180 / .pi
    }

    /// Angle from center in radians
    var angleRadians: Double {
        atan2(y, x)
    }

    /// Distance to another position
    func distance(to other: NormalizedTargetPosition) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }

    /// Position in millimeters given target radius
    func toMillimeters(targetRadiusMM: CGSize) -> CGPoint {
        CGPoint(
            x: x * targetRadiusMM.width,
            y: y * targetRadiusMM.height
        )
    }

    static let zero = NormalizedTargetPosition(x: 0, y: 0)
}

// MARK: - Target Crop Geometry

/// Represents how the target was cropped and aligned in the image.
///
/// **Auto-Center Design**: With perspective-corrected crops, the target center is automatically
/// calculated as the geometric center of the crop (0.5, 0.5). This eliminates the need for
/// manual center placement, reducing user steps and potential errors while maintaining
/// scoring accuracy. The crop itself defines the target boundaries, so the center is always
/// at the midpoint.
struct TargetCropGeometry: Codable, Equatable {
    /// Normalized crop rectangle in original image (0-1 coordinates)
    let cropRect: CGRect

    /// Semi-axes of target ellipse within crop (0-1 normalized)
    /// For circular targets, width == height
    var targetSemiAxes: CGSize

    /// Rotation of target within crop (degrees, clockwise from vertical)
    var rotationDegrees: Double = 0

    /// Whether the target axes are swapped (rotated 90°)
    var axesSwapped: Bool = false

    /// Known physical aspect ratio of target type (width/height)
    let physicalAspectRatio: Double

    /// Type of target boundary
    let boundaryType: BoundaryType

    enum BoundaryType: String, Codable {
        case rectangular
        case circular
        case elliptical
    }

    /// Auto-calculated center of target within the cropped image.
    /// With a proper perspective crop, the center is always at (0.5, 0.5) - the geometric
    /// center of the crop. This removes the need for manual center placement.
    var targetCenterInCrop: CGPoint {
        // Auto-calculated: center is always at the midpoint of the perspective-corrected crop.
        // Formula: centreX = cropWidth / 2, centreY = cropHeight / 2
        // In normalized coordinates (0-1), this is simply (0.5, 0.5).
        CGPoint(x: 0.5, y: 0.5)
    }

    init(
        cropRect: CGRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
        targetSemiAxes: CGSize = CGSize(width: 0.4, height: 0.45),
        rotationDegrees: Double = 0,
        physicalAspectRatio: Double = 0.77,  // Tetrathlon default
        boundaryType: BoundaryType = .elliptical
    ) {
        self.cropRect = cropRect
        self.targetSemiAxes = targetSemiAxes
        self.rotationDegrees = rotationDegrees
        self.physicalAspectRatio = physicalAspectRatio
        self.boundaryType = boundaryType
    }

    /// Legacy initializer for backward compatibility.
    /// The targetCenterInCrop parameter is ignored as center is now auto-calculated.
    @available(*, deprecated, message: "Center is now auto-calculated. Use init without targetCenterInCrop.")
    init(
        cropRect: CGRect,
        targetCenterInCrop: CGPoint,  // Ignored - kept for API compatibility
        targetSemiAxes: CGSize,
        rotationDegrees: Double = 0,
        physicalAspectRatio: Double = 0.77,
        boundaryType: BoundaryType = .elliptical
    ) {
        self.cropRect = cropRect
        self.targetSemiAxes = targetSemiAxes
        self.rotationDegrees = rotationDegrees
        self.physicalAspectRatio = physicalAspectRatio
        self.boundaryType = boundaryType
        // Note: targetCenterInCrop is computed as (0.5, 0.5), ignoring the passed value
    }
}

// MARK: - Target Alignment

/// Alignment parameters for target analysis.
///
/// **Auto-Center Design**: With perspective-corrected crops, manual center adjustment
/// is no longer required. The center is automatically calculated as the geometric
/// center of the crop (0.5, 0.5). This struct now primarily tracks semi-axes scaling
/// and any rotation adjustments.
struct TargetAlignment: Codable, Equatable {
    /// Center position - auto-calculated as (0.5, 0.5) for perspective-corrected crops.
    /// This property is kept for backward compatibility but should not be manually set.
    var confirmedCenter: CGPoint

    /// Semi-axes of the target ellipse (can be adjusted for different target sizes)
    var confirmedSemiAxes: CGSize

    /// Offset from auto-detected center (for auditing) - typically zero with auto-center
    var centerOffset: CGPoint = .zero

    /// Rotation adjustment in degrees
    var rotationAdjustment: Double = 0

    /// Confidence in alignment (0-1) - high by default with auto-center
    var alignmentConfidence: Double = 1.0

    /// Whether user manually adjusted the alignment (legacy - always false with auto-center)
    var wasManuallyAdjusted: Bool = false

    /// Timestamp of alignment confirmation
    var confirmedAt: Date = Date()

    /// Creates an auto-calculated alignment with center at (0.5, 0.5).
    /// This is the preferred initializer for the auto-center workflow.
    static func autoCalculated(semiAxes: CGSize = CGSize(width: 0.4, height: 0.45)) -> TargetAlignment {
        TargetAlignment(
            confirmedCenter: CGPoint(x: 0.5, y: 0.5),  // Auto-calculated center
            confirmedSemiAxes: semiAxes,
            centerOffset: .zero,
            rotationAdjustment: 0,
            alignmentConfidence: 1.0,  // High confidence with auto-center
            wasManuallyAdjusted: false,
            confirmedAt: Date()
        )
    }
}

// MARK: - Perspective Assessment

/// Assessment of camera perspective relative to target
struct PerspectiveAssessment: Codable, Equatable {
    /// Ratio of top edge to bottom edge width (1.0 = perpendicular)
    let keystoneRatio: Double

    /// Estimated angle of camera from perpendicular (degrees)
    let estimatedAngle: Double

    var severity: Severity {
        if keystoneRatio > 0.95 && keystoneRatio < 1.05 { return .negligible }
        if keystoneRatio > 0.85 && keystoneRatio < 1.15 { return .minor }
        return .significant
    }

    enum Severity: String, Codable {
        case negligible
        case minor
        case significant
    }

    var warning: String? {
        switch severity {
        case .significant:
            return "Target appears tilted. Hold camera directly above for best accuracy."
        case .minor, .negligible:
            return nil
        }
    }

    static let ideal = PerspectiveAssessment(keystoneRatio: 1.0, estimatedAngle: 0)
}

// MARK: - Acquisition Quality

/// Quality metrics for the target scan acquisition
struct AcquisitionQuality: Codable, Equatable {
    /// Image sharpness score (0-1)
    let imageSharpness: Double

    /// Image contrast score (0-1)
    let imageContrast: Double

    /// Exposure quality
    let exposureLevel: ExposureLevel

    /// Center confirmation confidence (0-1)
    let centerConfidence: Double

    /// Perspective severity (0 = perfect, 1 = severe)
    let perspectiveSeverity: Double

    /// Rate of auto-accepted detections (0-1)
    var detectionAutoAcceptRate: Double = 0

    enum ExposureLevel: String, Codable {
        case underexposed
        case good
        case overexposed
    }

    var overallScore: Double {
        let exposureScore: Double = exposureLevel == .good ? 1.0 : 0.5
        return (imageSharpness * 0.15 +
                imageContrast * 0.15 +
                exposureScore * 0.1 +
                centerConfidence * 0.3 +
                (1 - perspectiveSeverity) * 0.15 +
                detectionAutoAcceptRate * 0.15)
    }

    var isAcceptableForAnalysis: Bool {
        overallScore >= 0.5
    }

    var qualityDescription: String {
        if overallScore >= 0.8 { return "Excellent" }
        if overallScore >= 0.6 { return "Good" }
        if overallScore >= 0.4 { return "Fair" }
        return "Poor"
    }

    static let unknown = AcquisitionQuality(
        imageSharpness: 0.5,
        imageContrast: 0.5,
        exposureLevel: .good,
        centerConfidence: 0.5,
        perspectiveSeverity: 0.5
    )
}

// MARK: - Coordinate Transformer

/// Transforms between pixel coordinates and normalized target coordinates
struct TargetCoordinateTransformer {
    let cropGeometry: TargetCropGeometry
    let imageSize: CGSize  // Cropped image size in pixels

    /// Convert pixel position in cropped image to normalized target coordinates
    func toTargetCoordinates(pixelPosition: CGPoint) -> NormalizedTargetPosition {
        // Step 1: Normalize to 0-1 range within cropped image
        let normalizedX = pixelPosition.x / imageSize.width
        let normalizedY = pixelPosition.y / imageSize.height

        // Step 2: Translate to target center origin
        var centerX = normalizedX - cropGeometry.targetCenterInCrop.x
        var centerY = cropGeometry.targetCenterInCrop.y - normalizedY  // Flip Y (image Y is down)

        // Step 3: Apply rotation correction if target is rotated
        if cropGeometry.rotationDegrees != 0 {
            let radians = -cropGeometry.rotationDegrees * .pi / 180
            let cosR = cos(radians)
            let sinR = sin(radians)
            let rotatedX = centerX * cosR - centerY * sinR
            let rotatedY = centerX * sinR + centerY * cosR
            centerX = rotatedX
            centerY = rotatedY
        }

        // Step 4: Scale by target semi-axes to get -1 to +1 range
        let semiAxes = cropGeometry.axesSwapped
            ? CGSize(width: cropGeometry.targetSemiAxes.height, height: cropGeometry.targetSemiAxes.width)
            : cropGeometry.targetSemiAxes

        let targetX = centerX / semiAxes.width
        let targetY = centerY / semiAxes.height

        return NormalizedTargetPosition(x: targetX, y: targetY)
    }

    /// Convert normalized target coordinates back to pixel position
    func toPixelPosition(targetPosition: NormalizedTargetPosition) -> CGPoint {
        let semiAxes = cropGeometry.axesSwapped
            ? CGSize(width: cropGeometry.targetSemiAxes.height, height: cropGeometry.targetSemiAxes.width)
            : cropGeometry.targetSemiAxes

        // Step 1: Scale from -1 to +1 range to center-relative normalized
        var centerX = targetPosition.x * semiAxes.width
        var centerY = targetPosition.y * semiAxes.height

        // Step 2: Apply inverse rotation
        if cropGeometry.rotationDegrees != 0 {
            let radians = cropGeometry.rotationDegrees * .pi / 180
            let cosR = cos(radians)
            let sinR = sin(radians)
            let rotatedX = centerX * cosR - centerY * sinR
            let rotatedY = centerX * sinR + centerY * cosR
            centerX = rotatedX
            centerY = rotatedY
        }

        // Step 3: Translate from center origin to image coordinates
        let normalizedX = centerX + cropGeometry.targetCenterInCrop.x
        let normalizedY = cropGeometry.targetCenterInCrop.y - centerY  // Flip Y back

        // Step 4: Convert to pixels
        return CGPoint(
            x: normalizedX * imageSize.width,
            y: normalizedY * imageSize.height
        )
    }

    /// Convert a normalized radius to pixels
    func toPixelRadius(_ normalizedRadius: Double) -> CGFloat {
        let avgSemiAxis = (cropGeometry.targetSemiAxes.width + cropGeometry.targetSemiAxes.height) / 2
        let avgImageSize = (imageSize.width + imageSize.height) / 2
        return CGFloat(normalizedRadius * avgSemiAxis) * avgImageSize
    }

    /// Convert pixel radius to normalized radius
    func toNormalizedRadius(_ pixelRadius: CGFloat) -> Double {
        let avgSemiAxis = (cropGeometry.targetSemiAxes.width + cropGeometry.targetSemiAxes.height) / 2
        let avgImageSize = (imageSize.width + imageSize.height) / 2
        return Double(pixelRadius) / (avgSemiAxis * avgImageSize)
    }
}

// MARK: - Target Scaling

/// Converts between pixels and physical measurements
struct TargetScaling {
    let pixelsPerMillimeterX: Double
    let pixelsPerMillimeterY: Double

    init(targetSemiAxesPixels: CGSize, targetSemiAxesMM: CGSize) {
        pixelsPerMillimeterX = Double(targetSemiAxesPixels.width) / targetSemiAxesMM.width
        pixelsPerMillimeterY = Double(targetSemiAxesPixels.height) / targetSemiAxesMM.height
    }

    var averagePixelsPerMM: Double {
        (pixelsPerMillimeterX + pixelsPerMillimeterY) / 2
    }

    func toMillimeters(pixels: CGFloat) -> Double {
        Double(pixels) / averagePixelsPerMM
    }

    func toPixels(millimeters: Double) -> CGFloat {
        CGFloat(millimeters * averagePixelsPerMM)
    }

    func toMillimeters(point pixels: CGPoint) -> CGPoint {
        CGPoint(
            x: Double(pixels.x) / pixelsPerMillimeterX,
            y: Double(pixels.y) / pixelsPerMillimeterY
        )
    }
}

// MARK: - Hole Size Calibration

/// User-calibrated hole size for improved detection
struct HoleSizeCalibration: Codable, Equatable {
    /// Calibrated hole radius in pixels (for current image)
    var calibratedRadiusPixels: CGFloat?

    /// Calibrated hole radius in normalized target units
    var calibratedRadiusNormalized: Double?

    /// Whether this was automatically determined or user-confirmed
    var wasAutomaticallyDetermined: Bool = true

    /// Update calibration from a user-confirmed hole
    mutating func updateFromUserConfirmation(radiusPixels: CGFloat, transformer: TargetCoordinateTransformer) {
        calibratedRadiusPixels = radiusPixels
        calibratedRadiusNormalized = transformer.toNormalizedRadius(radiusPixels)
        wasAutomaticallyDetermined = false
    }

    /// Expected hole diameter range in pixels based on calibration
    func expectedDiameterRange(transformer: TargetCoordinateTransformer, tolerance: Double = 0.5) -> ClosedRange<CGFloat> {
        let baseRadius: CGFloat
        if let calibrated = calibratedRadiusPixels {
            baseRadius = calibrated
        } else if let normalizedRadius = calibratedRadiusNormalized {
            baseRadius = transformer.toPixelRadius(normalizedRadius)
        } else {
            // Default based on standard pellet size
            baseRadius = transformer.toPixelRadius(0.03)  // ~3% of target radius
        }

        let minDiameter = baseRadius * 2 * CGFloat(1 - tolerance)
        let maxDiameter = baseRadius * 2 * CGFloat(1 + tolerance)
        return minDiameter...maxDiameter
    }
}
