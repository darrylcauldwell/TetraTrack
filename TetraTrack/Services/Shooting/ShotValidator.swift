//
//  ShotValidator.swift
//  TetraTrack
//
//  Validation and defensive checks for shooting data integrity.
//  Ensures shot data is valid and consistent before storage.
//

import Foundation
import CoreGraphics

// MARK: - Validation Result

/// Result of validating a shot or scan
struct ValidationResult: Equatable {
    let isValid: Bool
    let warnings: [ValidationWarning]
    let errors: [ValidationError]

    var hasWarnings: Bool { !warnings.isEmpty }
    var hasErrors: Bool { !errors.isEmpty }

    /// Pass validation with no issues
    static let valid = ValidationResult(isValid: true, warnings: [], errors: [])

    /// Combine multiple validation results
    static func combine(_ results: [ValidationResult]) -> ValidationResult {
        let allWarnings = results.flatMap { $0.warnings }
        let allErrors = results.flatMap { $0.errors }
        let isValid = results.allSatisfy { $0.isValid }

        return ValidationResult(
            isValid: isValid,
            warnings: allWarnings,
            errors: allErrors
        )
    }
}

/// A non-fatal validation warning
struct ValidationWarning: Equatable, Identifiable {
    let id: UUID
    let code: WarningCode
    let message: String
    let field: String?

    init(code: WarningCode, message: String, field: String? = nil) {
        self.id = UUID()
        self.code = code
        self.message = message
        self.field = field
    }

    enum WarningCode: String, Equatable {
        case shotOutsideTarget = "shot_outside_target"
        case lowConfidenceDetection = "low_confidence"
        case poorImageQuality = "poor_image_quality"
        case perspectiveDistortion = "perspective_distortion"
        case unusualShotSpacing = "unusual_spacing"
        case overlappingShots = "overlapping_shots"
        case possibleMissedHole = "possible_missed"
        case manualOverrideUsed = "manual_override"
        case calibrationUncertain = "calibration_uncertain"
    }
}

/// A fatal validation error
struct ValidationError: Equatable, Identifiable, Error {
    let id: UUID
    let code: ErrorCode
    let message: String
    let field: String?

    init(code: ErrorCode, message: String, field: String? = nil) {
        self.id = UUID()
        self.code = code
        self.message = message
        self.field = field
    }

    enum ErrorCode: String, Equatable {
        case invalidCoordinates = "invalid_coordinates"
        case duplicateShot = "duplicate_shot"
        case invalidScore = "invalid_score"
        case corruptData = "corrupt_data"
        case missingRequiredField = "missing_field"
        case coordinateSystemMismatch = "coord_system_mismatch"
        case imageTooSmall = "image_too_small"
        case noTargetDetected = "no_target_detected"
        case geometryInconsistent = "geometry_inconsistent"
    }
}

// MARK: - Shot Validator

/// Validates individual shots and collections
struct ShotValidator {

    /// Validate a single shot position
    static func validateShot(
        position: NormalizedTargetPosition,
        score: Int,
        targetType: ShootingTargetGeometryType,
        confidence: Double
    ) -> ValidationResult {
        var warnings: [ValidationWarning] = []
        var errors: [ValidationError] = []

        // Validate coordinate bounds
        if !isValidCoordinate(position) {
            errors.append(ValidationError(
                code: .invalidCoordinates,
                message: "Shot position outside valid range (-2 to +2)",
                field: "position"
            ))
        }

        // Check if shot is outside target
        let radialDistance = position.radialDistance
        if radialDistance > 1.0 {
            if radialDistance > 1.5 {
                errors.append(ValidationError(
                    code: .invalidCoordinates,
                    message: "Shot position too far outside target boundary",
                    field: "position"
                ))
            } else {
                warnings.append(ValidationWarning(
                    code: .shotOutsideTarget,
                    message: "Shot recorded outside target boundary",
                    field: "position"
                ))
            }
        }

        // Validate score against position
        let expectedScore = targetType.score(from: position)
        if score != expectedScore && score != 0 {
            // Allow some tolerance for edge cases
            let scoreError = abs(score - expectedScore)
            if scoreError > 2 {
                errors.append(ValidationError(
                    code: .invalidScore,
                    message: "Score \(score) inconsistent with position (expected ~\(expectedScore))",
                    field: "score"
                ))
            } else {
                warnings.append(ValidationWarning(
                    code: .manualOverrideUsed,
                    message: "Score differs from calculated value (edge case or manual override)",
                    field: "score"
                ))
            }
        }

        // Validate score is valid for target type
        if !targetType.validScores.contains(score) {
            errors.append(ValidationError(
                code: .invalidScore,
                message: "Score \(score) is not valid for \(targetType.displayName)",
                field: "score"
            ))
        }

        // Check confidence
        if confidence < 0.5 {
            warnings.append(ValidationWarning(
                code: .lowConfidenceDetection,
                message: String(format: "Detection confidence is low (%.0f%%)", confidence * 100),
                field: "confidence"
            ))
        }

        return ValidationResult(
            isValid: errors.isEmpty,
            warnings: warnings,
            errors: errors
        )
    }

    /// Validate a collection of shots for a scan
    static func validateShotCollection(
        shots: [ValidatableShot],
        targetType: ShootingTargetGeometryType,
        expectedCount: Int? = nil
    ) -> ValidationResult {
        var warnings: [ValidationWarning] = []
        var errors: [ValidationError] = []

        // Check for empty collection
        if shots.isEmpty {
            return ValidationResult.valid  // Empty is valid, just no shots
        }

        // Check expected count if provided
        if let expected = expectedCount, shots.count != expected {
            warnings.append(ValidationWarning(
                code: .possibleMissedHole,
                message: "Expected \(expected) shots but found \(shots.count)",
                field: "shotCount"
            ))
        }

        // Check for duplicates (shots too close together)
        let duplicatePairs = findDuplicates(shots)
        if !duplicatePairs.isEmpty {
            for (i, j) in duplicatePairs {
                warnings.append(ValidationWarning(
                    code: .overlappingShots,
                    message: "Shots \(i + 1) and \(j + 1) may be duplicates (very close positions)",
                    field: "position"
                ))
            }
        }

        // Validate individual shots
        for shot in shots {
            let shotResult = validateShot(
                position: shot.normalizedPosition,
                score: shot.score,
                targetType: targetType,
                confidence: shot.confidence
            )
            warnings.append(contentsOf: shotResult.warnings)
            errors.append(contentsOf: shotResult.errors)
        }

        // Check for unusual spacing (possible detection issues)
        if shots.count >= 2 {
            let spacingAnalysis = analyzeSpacing(shots)
            if spacingAnalysis.hasUnusualSpacing {
                warnings.append(ValidationWarning(
                    code: .unusualShotSpacing,
                    message: spacingAnalysis.message,
                    field: "position"
                ))
            }
        }

        return ValidationResult(
            isValid: errors.isEmpty,
            warnings: warnings,
            errors: errors
        )
    }

    /// Check if coordinate values are within valid range
    private static func isValidCoordinate(_ position: NormalizedTargetPosition) -> Bool {
        // Allow shots slightly outside target (up to 2x radius)
        // but reject obviously invalid data
        let maxRange = 2.0
        return position.x >= -maxRange && position.x <= maxRange &&
               position.y >= -maxRange && position.y <= maxRange &&
               !position.x.isNaN && !position.y.isNaN &&
               position.x.isFinite && position.y.isFinite
    }

    /// Find pairs of shots that might be duplicates
    private static func findDuplicates(_ shots: [ValidatableShot]) -> [(Int, Int)] {
        let minDistance = 0.02  // Minimum distance between distinct shots
        var duplicates: [(Int, Int)] = []

        for i in 0..<shots.count {
            for j in (i + 1)..<shots.count {
                let distance = shots[i].normalizedPosition.distance(to: shots[j].normalizedPosition)
                if distance < minDistance {
                    duplicates.append((i, j))
                }
            }
        }

        return duplicates
    }

    /// Analyze spacing between shots for anomalies
    private static func analyzeSpacing(_ shots: [ValidatableShot]) -> (hasUnusualSpacing: Bool, message: String) {
        guard shots.count >= 3 else {
            return (false, "")
        }

        // Calculate all pairwise distances
        var distances: [Double] = []
        for i in 0..<shots.count {
            for j in (i + 1)..<shots.count {
                distances.append(shots[i].normalizedPosition.distance(to: shots[j].normalizedPosition))
            }
        }

        let avgDistance = distances.reduce(0, +) / Double(distances.count)
        let maxDistance = distances.max() ?? 0
        let minDistance = distances.min() ?? 0

        // Check for very clustered shots (possible grid alignment issue)
        if avgDistance < 0.03 && maxDistance < 0.05 {
            return (true, "Shots are unusually clustered - verify detection accuracy")
        }

        // Check for very spread shots (possible calibration issue)
        if avgDistance > 0.5 {
            return (true, "Shots are widely spread - verify target alignment")
        }

        // Check for one outlier
        if maxDistance > avgDistance * 3 {
            return (true, "One or more shots significantly distant from group")
        }

        return (false, "")
    }
}

// MARK: - Validatable Shot Protocol

/// Protocol for shots that can be validated
protocol ValidatableShot {
    var normalizedPosition: NormalizedTargetPosition { get }
    var score: Int { get }
    var confidence: Double { get }
}

// MARK: - Scan Validator

/// Validates complete target scans
struct ScanValidator {

    /// Minimum image dimension for valid scan
    static let minimumImageDimension: CGFloat = 200

    /// Validate scan image
    static func validateImage(size: CGSize) -> ValidationResult {
        var errors: [ValidationError] = []

        if size.width < minimumImageDimension || size.height < minimumImageDimension {
            errors.append(ValidationError(
                code: .imageTooSmall,
                message: String(format: "Image too small (%.0f x %.0f, minimum %.0f)",
                               size.width, size.height, minimumImageDimension),
                field: "image"
            ))
        }

        return ValidationResult(
            isValid: errors.isEmpty,
            warnings: [],
            errors: errors
        )
    }

    /// Validate crop geometry
    static func validateCropGeometry(_ geometry: TargetCropGeometry) -> ValidationResult {
        var warnings: [ValidationWarning] = []
        var errors: [ValidationError] = []

        // Check crop rect bounds
        let rect = geometry.cropRect
        if rect.width <= 0 || rect.height <= 0 {
            errors.append(ValidationError(
                code: .geometryInconsistent,
                message: "Invalid crop rectangle dimensions",
                field: "cropRect"
            ))
        }

        // Check target center is within crop
        let center = geometry.targetCenterInCrop
        if center.x < 0 || center.x > 1 || center.y < 0 || center.y > 1 {
            errors.append(ValidationError(
                code: .geometryInconsistent,
                message: "Target center outside crop bounds",
                field: "targetCenterInCrop"
            ))
        }

        // Check semi-axes are reasonable
        let semiAxes = geometry.targetSemiAxes
        if semiAxes.width <= 0 || semiAxes.height <= 0 {
            errors.append(ValidationError(
                code: .geometryInconsistent,
                message: "Invalid target semi-axes",
                field: "targetSemiAxes"
            ))
        }

        // Warn if target is very small in frame
        if semiAxes.width < 0.15 || semiAxes.height < 0.15 {
            warnings.append(ValidationWarning(
                code: .calibrationUncertain,
                message: "Target appears small in frame - accuracy may be reduced",
                field: "targetSemiAxes"
            ))
        }

        // Check rotation is within reasonable bounds
        let rotation = geometry.rotationDegrees
        if abs(rotation) > 45 {
            warnings.append(ValidationWarning(
                code: .perspectiveDistortion,
                message: "Target appears significantly rotated",
                field: "rotationDegrees"
            ))
        }

        return ValidationResult(
            isValid: errors.isEmpty,
            warnings: warnings,
            errors: errors
        )
    }

    /// Validate acquisition quality
    static func validateQuality(_ quality: AcquisitionQuality) -> ValidationResult {
        var warnings: [ValidationWarning] = []

        if quality.imageSharpness < 0.3 {
            warnings.append(ValidationWarning(
                code: .poorImageQuality,
                message: "Image appears blurry - hold camera steadier",
                field: "imageSharpness"
            ))
        }

        if quality.imageContrast < 0.2 {
            warnings.append(ValidationWarning(
                code: .poorImageQuality,
                message: "Low contrast - ensure good lighting",
                field: "imageContrast"
            ))
        }

        if quality.exposureLevel != .good {
            warnings.append(ValidationWarning(
                code: .poorImageQuality,
                message: quality.exposureLevel == .underexposed ?
                    "Image too dark" : "Image too bright",
                field: "exposureLevel"
            ))
        }

        if quality.perspectiveSeverity > 0.5 {
            warnings.append(ValidationWarning(
                code: .perspectiveDistortion,
                message: "Camera angle may affect accuracy - position directly above",
                field: "perspectiveSeverity"
            ))
        }

        if quality.centerConfidence < 0.5 {
            warnings.append(ValidationWarning(
                code: .calibrationUncertain,
                message: "Target center detection uncertain - please verify",
                field: "centerConfidence"
            ))
        }

        return ValidationResult(
            isValid: true,  // Quality issues are warnings, not errors
            warnings: warnings,
            errors: []
        )
    }

    /// Full validation of a scan
    static func validateScan(
        imageSize: CGSize,
        cropGeometry: TargetCropGeometry,
        quality: AcquisitionQuality?,
        shots: [ValidatableShot],
        targetType: ShootingTargetGeometryType
    ) -> ValidationResult {
        var results: [ValidationResult] = []

        results.append(validateImage(size: imageSize))
        results.append(validateCropGeometry(cropGeometry))

        if let quality = quality {
            results.append(validateQuality(quality))
        }

        results.append(ShotValidator.validateShotCollection(
            shots: shots,
            targetType: targetType
        ))

        return ValidationResult.combine(results)
    }
}

// MARK: - Data Integrity Checker

/// Checks data integrity for stored shooting data
struct DataIntegrityChecker {

    /// Check if a shot position needs re-analysis due to algorithm changes
    static func needsReanalysis(
        storedVersion: Int,
        currentVersion: Int = PatternAnalysis.currentAlgorithmVersion
    ) -> Bool {
        storedVersion < currentVersion
    }

    /// Validate coordinate system compatibility
    static func validateCoordinateSystemVersion(_ version: Int) -> ValidationResult {
        let current = CoordinateSystemVersion.current.major

        if version != current {
            return ValidationResult(
                isValid: false,
                warnings: [],
                errors: [ValidationError(
                    code: .coordinateSystemMismatch,
                    message: "Data uses coordinate system v\(version), current is v\(current)",
                    field: "coordinateSystemVersion"
                )]
            )
        }

        return ValidationResult.valid
    }

    /// Verify data consistency between related fields
    static func verifyConsistency(
        shotCount: Int,
        totalScore: Int,
        maxScorePerShot: Int
    ) -> ValidationResult {
        var errors: [ValidationError] = []

        // Total score can't exceed max possible
        let maxPossible = shotCount * maxScorePerShot
        if totalScore > maxPossible {
            errors.append(ValidationError(
                code: .corruptData,
                message: "Total score (\(totalScore)) exceeds maximum possible (\(maxPossible))",
                field: "totalScore"
            ))
        }

        // Score can't be negative
        if totalScore < 0 {
            errors.append(ValidationError(
                code: .corruptData,
                message: "Negative total score",
                field: "totalScore"
            ))
        }

        return ValidationResult(
            isValid: errors.isEmpty,
            warnings: [],
            errors: errors
        )
    }
}

// MARK: - Input Sanitizer

/// Sanitizes user input for shooting data
struct InputSanitizer {

    /// Sanitize and clamp a coordinate value
    static func sanitizeCoordinate(_ value: Double) -> Double? {
        guard value.isFinite && !value.isNaN else {
            return nil
        }
        // Clamp to valid range
        return max(-2.0, min(2.0, value))
    }

    /// Sanitize a position
    static func sanitizePosition(_ position: NormalizedTargetPosition) -> NormalizedTargetPosition? {
        guard let x = sanitizeCoordinate(position.x),
              let y = sanitizeCoordinate(position.y) else {
            return nil
        }
        return NormalizedTargetPosition(x: x, y: y)
    }

    /// Sanitize a score value
    static func sanitizeScore(_ score: Int, for targetType: ShootingTargetGeometryType) -> Int {
        // Find closest valid score
        let validScores = targetType.validScores
        guard !validScores.isEmpty else { return 0 }

        // Clamp to range
        let clamped = max(validScores.min()!, min(validScores.max()!, score))

        // Find nearest valid score
        return validScores.min(by: { abs($0 - clamped) < abs($1 - clamped) }) ?? 0
    }

    /// Sanitize confidence value
    static func sanitizeConfidence(_ confidence: Double) -> Double {
        guard confidence.isFinite && !confidence.isNaN else {
            return 0
        }
        return max(0, min(1, confidence))
    }
}
