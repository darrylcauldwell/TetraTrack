//
//  EnhancedTargetScanner.swift
//  TrackRide
//
//  Enhanced target scanner integration layer.
//  Coordinates all new shooting analysis services.
//

import Foundation
import UIKit
import SwiftUI

// MARK: - Enhanced Scanner Configuration

/// Configuration for the enhanced target scanner
struct EnhancedScannerConfig {
    /// Target geometry type
    var targetType: ShootingTargetGeometryType = .tetrathlon

    /// Whether to run auto-detection
    var enableAutoDetection: Bool = true

    /// Minimum confidence for auto-detected holes
    var minimumConfidence: Double = 0.6

    /// Whether to require center confirmation
    var requireCenterConfirmation: Bool = true

    /// Whether to show quality assessment
    var showQualityAssessment: Bool = true

    /// Detection configuration
    var detectionConfig: HoleDetectionConfig = HoleDetectionConfig()
}

// MARK: - Scanner State

/// Observable state for the enhanced scanner
@Observable
final class EnhancedScannerState {
    // Current phase
    var phase: ScanPhase = .camera

    // Image data
    var rawImage: UIImage?
    var croppedImage: UIImage?

    // Geometry
    var cropGeometry: TargetCropGeometry?
    var targetAlignment: TargetAlignment?

    // Quality assessment
    var imageQuality: ImageQualityAssessment?
    var acquisitionQuality: AcquisitionQuality?

    // Detection results
    var detectedHoles: [DetectedHoleCandidate] = []
    var confirmedShots: [ScanShot] = []

    // Pattern analysis
    var patternAnalysis: PatternAnalysis?

    // Validation
    var validationResult: ValidationResult?

    // UI state
    var isProcessing: Bool = false
    var processingMessage: String = ""
    var error: ScannerError?

    enum ScanPhase {
        case camera
        case crop
        case centerConfirmation
        case holeDetection
        case manualCorrection
        case review
    }

    enum ScannerError: LocalizedError {
        case imageCaptureFailed
        case qualityTooLow(String)
        case detectionFailed(String)
        case validationFailed([ValidationError])

        var errorDescription: String? {
            switch self {
            case .imageCaptureFailed:
                return "Failed to capture image"
            case .qualityTooLow(let reason):
                return "Image quality too low: \(reason)"
            case .detectionFailed(let reason):
                return "Detection failed: \(reason)"
            case .validationFailed(let errors):
                return "Validation failed: \(errors.map { $0.message }.joined(separator: ", "))"
            }
        }
    }

    func reset() {
        phase = .camera
        rawImage = nil
        croppedImage = nil
        cropGeometry = nil
        targetAlignment = nil
        imageQuality = nil
        acquisitionQuality = nil
        detectedHoles = []
        confirmedShots = []
        patternAnalysis = nil
        validationResult = nil
        isProcessing = false
        processingMessage = ""
        error = nil
    }
}

// MARK: - Enhanced Target Scanner

/// Coordinator for the enhanced scanning workflow
actor EnhancedTargetScanner {
    private let config: EnhancedScannerConfig
    private let qualityAssessor = ImageQualityAssessor()
    private let holeDetector = AssistedHoleDetector()

    init(config: EnhancedScannerConfig = EnhancedScannerConfig()) {
        self.config = config
    }

    // MARK: - Image Capture

    /// Process a captured image
    func processCapturedImage(
        _ image: UIImage,
        state: EnhancedScannerState
    ) async {
        await MainActor.run {
            state.rawImage = image
            state.phase = .crop
        }
    }

    // MARK: - Crop Processing

    /// Process the cropped image and estimate geometry
    func processCroppedImage(
        _ croppedImage: UIImage,
        cropRect: CGRect,
        state: EnhancedScannerState
    ) async {
        await MainActor.run {
            state.isProcessing = true
            state.processingMessage = "Assessing image quality..."
        }

        // Assess image quality
        let quality = await qualityAssessor.assess(image: croppedImage)

        await MainActor.run {
            state.imageQuality = quality
        }

        // Check quality gate
        if config.showQualityAssessment && !quality.isAcceptableForDetection {
            await MainActor.run {
                state.error = .qualityTooLow(quality.userGuidance ?? "Image quality insufficient")
                state.isProcessing = false
            }
            return
        }

        // Create initial crop geometry
        let geometry = TargetCropGeometry(
            cropRect: cropRect,
            targetCenterInCrop: CGPoint(x: 0.5, y: 0.5),
            targetSemiAxes: CGSize(width: 0.4, height: 0.45),
            physicalAspectRatio: config.targetType.aspectRatio
        )

        await MainActor.run {
            state.croppedImage = croppedImage
            state.cropGeometry = geometry
            state.processingMessage = ""
            state.isProcessing = false

            if config.requireCenterConfirmation {
                state.phase = .centerConfirmation
            } else {
                state.phase = .holeDetection
            }
        }
    }

    // MARK: - Center Confirmation

    /// Process confirmed target alignment
    func processTargetAlignment(
        _ alignment: TargetAlignment,
        state: EnhancedScannerState
    ) async {
        await MainActor.run {
            state.targetAlignment = alignment

            // Update crop geometry with confirmed values
            if var geometry = state.cropGeometry {
                geometry.targetCenterInCrop = alignment.confirmedCenter
                geometry.targetSemiAxes = alignment.confirmedSemiAxes
                state.cropGeometry = geometry
            }

            state.phase = .holeDetection
        }

        // Run auto-detection if enabled
        if config.enableAutoDetection {
            await runAutoDetection(state: state)
        } else {
            await MainActor.run {
                state.phase = .manualCorrection
            }
        }
    }

    // MARK: - Hole Detection

    /// Run automatic hole detection
    func runAutoDetection(state: EnhancedScannerState) async {
        guard let image = state.croppedImage?.cgImage,
              let geometry = state.cropGeometry else {
            await MainActor.run {
                state.phase = .manualCorrection
            }
            return
        }

        await MainActor.run {
            state.isProcessing = true
            state.processingMessage = "Detecting holes..."
        }

        do {
            let candidates = try await holeDetector.detectHoles(
                in: image,
                cropGeometry: geometry,
                targetType: config.targetType,
                config: config.detectionConfig
            )

            // Filter by confidence
            let filteredCandidates = candidates.filter {
                $0.confidence >= config.minimumConfidence
            }

            await MainActor.run {
                state.detectedHoles = filteredCandidates
                state.processingMessage = ""
                state.isProcessing = false
                state.phase = .manualCorrection
            }
        } catch {
            await MainActor.run {
                state.error = .detectionFailed(error.localizedDescription)
                state.isProcessing = false
                state.phase = .manualCorrection
            }
        }
    }

    // MARK: - Manual Correction

    /// Add a manually placed shot
    func addManualShot(
        at pixelPosition: CGPoint,
        imageSize: CGSize,
        state: EnhancedScannerState
    ) async {
        guard let geometry = state.cropGeometry else { return }

        let transformer = TargetCoordinateTransformer(
            cropGeometry: geometry,
            imageSize: imageSize
        )

        let normalizedPosition = transformer.toTargetCoordinates(pixelPosition: pixelPosition)
        let score = config.targetType.score(from: normalizedPosition)

        let shot = ScanShot(
            normalizedPosition: normalizedPosition,
            score: score,
            confidence: 1.0,
            detectionMethod: .userPlaced
        )

        await MainActor.run {
            state.confirmedShots.append(shot)
        }
    }

    /// Confirm a detected hole candidate
    func confirmDetectedHole(
        _ candidate: DetectedHoleCandidate,
        state: EnhancedScannerState
    ) async {
        guard let geometry = state.cropGeometry,
              let image = state.croppedImage else { return }

        let imageSize = CGSize(width: image.size.width, height: image.size.height)
        let transformer = TargetCoordinateTransformer(cropGeometry: geometry, imageSize: imageSize)

        var shot = ScanShot(
            normalizedPosition: candidate.targetPosition,
            score: candidate.score,
            confidence: candidate.confidence,
            detectionMethod: .autoDetected,
            radiusNormalized: transformer.toNormalizedRadius(candidate.radiusPixels)
        )
        shot.markUserConfirmed()

        await MainActor.run {
            state.confirmedShots.append(shot)
            state.detectedHoles.removeAll { $0.id == candidate.id }
        }
    }

    /// Reject a detected hole candidate
    func rejectDetectedHole(
        _ candidate: DetectedHoleCandidate,
        state: EnhancedScannerState
    ) async {
        await MainActor.run {
            state.detectedHoles.removeAll { $0.id == candidate.id }
        }
    }

    /// Remove a confirmed shot
    func removeShot(
        at index: Int,
        state: EnhancedScannerState
    ) async {
        await MainActor.run {
            guard index < state.confirmedShots.count else { return }
            state.confirmedShots.remove(at: index)
        }
    }

    /// Accept all remaining candidates above threshold
    func acceptAllCandidates(
        minConfidence: Double = 0.7,
        state: EnhancedScannerState
    ) async {
        let toAccept = state.detectedHoles.filter { $0.confidence >= minConfidence }

        for candidate in toAccept {
            await confirmDetectedHole(candidate, state: state)
        }
    }

    // MARK: - Finalization

    /// Finalize the scan and generate analysis
    func finalizeScan(
        state: EnhancedScannerState
    ) async -> TargetScanAnalysis? {
        guard !state.confirmedShots.isEmpty,
              let geometry = state.cropGeometry else {
            return nil
        }

        await MainActor.run {
            state.isProcessing = true
            state.processingMessage = "Analyzing pattern..."
        }

        // Validate shots
        let validationResult = ShotValidator.validateShotCollection(
            shots: state.confirmedShots,
            targetType: config.targetType
        )

        await MainActor.run {
            state.validationResult = validationResult
        }

        if !validationResult.isValid {
            await MainActor.run {
                state.error = .validationFailed(validationResult.errors)
                state.isProcessing = false
            }
            return nil
        }

        // Run pattern analysis
        let patternAnalysis = PatternAnalyzer.analyze(shots: state.confirmedShots)

        await MainActor.run {
            state.patternAnalysis = patternAnalysis
        }

        // Build acquisition quality
        let acquisitionQuality = buildAcquisitionQuality(
            imageQuality: state.imageQuality,
            alignment: state.targetAlignment,
            shots: state.confirmedShots
        )

        // Create analysis record
        let analysis = TargetScanAnalysis()
        analysis.calculateEnhancedMetrics(
            from: state.confirmedShots,
            cropGeometry: geometry,
            targetType: config.targetType
        )
        analysis.targetAlignment = state.targetAlignment
        analysis.acquisitionQuality = acquisitionQuality
        analysis.validationWarnings = validationResult.warnings

        await MainActor.run {
            state.acquisitionQuality = acquisitionQuality
            state.processingMessage = ""
            state.isProcessing = false
            state.phase = .review
        }

        return analysis
    }

    private func buildAcquisitionQuality(
        imageQuality: ImageQualityAssessment?,
        alignment: TargetAlignment?,
        shots: [ScanShot]
    ) -> AcquisitionQuality {
        let autoAcceptRate: Double
        if !shots.isEmpty {
            let autoDetected = shots.filter { $0.detectionMethod == .autoDetected }.count
            autoAcceptRate = Double(autoDetected) / Double(shots.count)
        } else {
            autoAcceptRate = 0
        }

        return AcquisitionQuality(
            imageSharpness: imageQuality?.sharpness ?? 0.5,
            imageContrast: imageQuality?.contrast ?? 0.5,
            exposureLevel: mapExposureLevel(imageQuality?.exposure),
            centerConfidence: alignment?.alignmentConfidence ?? 0.5,
            perspectiveSeverity: 0.2,  // TODO: Calculate from geometry
            detectionAutoAcceptRate: autoAcceptRate
        )
    }

    private func mapExposureLevel(_ level: ImageQualityAssessment.ExposureLevel?) -> AcquisitionQuality.ExposureLevel {
        switch level {
        case .underexposed: return .underexposed
        case .overexposed: return .overexposed
        case .good, .none: return .good
        }
    }
}

// MARK: - Convenience Extensions

extension EnhancedScannerState {
    /// Total score from confirmed shots
    var totalScore: Int {
        confirmedShots.reduce(0) { $0 + $1.score }
    }

    /// Average score from confirmed shots
    var averageScore: Double {
        guard !confirmedShots.isEmpty else { return 0 }
        return Double(totalScore) / Double(confirmedShots.count)
    }

    /// Number of high-confidence candidates not yet confirmed
    var pendingHighConfidenceCandidates: Int {
        detectedHoles.filter { $0.confidence >= 0.7 }.count
    }

    /// Summary text for current state
    var statusSummary: String {
        switch phase {
        case .camera:
            return "Position camera over target"
        case .crop:
            return "Crop to target area"
        case .centerConfirmation:
            return "Confirm target center alignment"
        case .holeDetection:
            return isProcessing ? processingMessage : "Detecting holes..."
        case .manualCorrection:
            let pending = pendingHighConfidenceCandidates
            if pending > 0 {
                return "\(confirmedShots.count) shots confirmed, \(pending) candidates to review"
            }
            return "\(confirmedShots.count) shots marked"
        case .review:
            return "Review and save"
        }
    }
}
