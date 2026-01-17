//
//  AssistedHoleDetector.swift
//  TrackRide
//
//  Robust pellet hole detection with confidence scoring for assisted annotation.
//  Handles varying lighting, background noise, and target artifacts.
//

import Foundation
import CoreGraphics
import CoreImage
import Vision
import UIKit

// MARK: - Detection Configuration

struct HoleDetectionConfig {
    /// Expected pellet hole diameter range in pixels
    var expectedHoleDiameterPixels: ClosedRange<CGFloat> = 10...40

    /// Minimum circularity (0-1) to accept as potential hole
    var minCircularity: Double = 0.5

    /// Confidence threshold for auto-accept
    var autoAcceptConfidence: Double = 0.85

    /// Confidence threshold for suggestions
    var suggestionConfidence: Double = 0.5

    /// Minimum confidence to even consider
    var minimumConfidence: Double = 0.3

    /// Whether to filter out candidates on scoring ring lines
    var filterScoringRingArtifacts: Bool = true

    /// Tolerance for scoring ring filtering (fraction of target radius)
    var scoringRingTolerance: Double = 0.025

    /// Maximum number of candidates to return
    var maxCandidates: Int = 30

    /// Enable local background estimation
    var useLocalBackground: Bool = true

    static let `default` = HoleDetectionConfig()

    /// Calibrate configuration based on image and target
    static func calibrated(
        for imageSize: CGSize,
        transformer: TargetCoordinateTransformer,
        holeSizeCalibration: HoleSizeCalibration?
    ) -> HoleDetectionConfig {
        var config = HoleDetectionConfig.default

        // Calculate expected hole size in pixels
        let expectedRange = holeSizeCalibration?.expectedDiameterRange(transformer: transformer, tolerance: 0.5)
            ?? (transformer.toPixelRadius(0.02) * 2)...(transformer.toPixelRadius(0.06) * 2)

        config.expectedHoleDiameterPixels = expectedRange

        return config
    }
}

// MARK: - Detected Hole Candidate

struct DetectedHoleCandidate: Identifiable {
    let id = UUID()

    /// Position in pixels within cropped image
    let pixelPosition: CGPoint

    /// Position in normalized target coordinates
    let targetPosition: NormalizedTargetPosition

    /// Detected radius in pixels
    let radiusPixels: CGFloat

    /// Confidence score (0-1)
    let confidence: Double

    /// Detection features for debugging/analysis
    let features: HoleFeatures

    /// Calculated score based on position
    let score: Int

    /// Acceptance level based on confidence
    var acceptanceLevel: AcceptanceLevel {
        if confidence >= 0.85 { return .autoAccept }
        if confidence >= 0.5 { return .suggestion }
        return .rejected
    }

    enum AcceptanceLevel {
        case autoAccept    // High confidence, auto-add
        case suggestion    // Medium confidence, show as suggestion
        case rejected      // Low confidence, don't show
    }
}

/// Features extracted from a hole candidate
struct HoleFeatures: Codable {
    /// Circularity (0-1, 1 = perfect circle)
    let circularity: Double

    /// Aspect ratio (width/height)
    let aspectRatio: Double

    /// Mean intensity inside candidate
    let meanIntensity: Double

    /// Edge strength (gradient magnitude)
    let edgeStrength: Double

    /// Z-score relative to local background (positive = darker)
    let darknessZScore: Double

    /// Area in pixels
    let area: Double
}

// MARK: - Assisted Hole Detector

actor AssistedHoleDetector {

    private let context = CIContext()

    /// Detect pellet holes in a cropped target image
    func detectHoles(
        in image: CGImage,
        cropGeometry: TargetCropGeometry,
        targetType: ShootingTargetGeometryType = .tetrathlon,
        config: HoleDetectionConfig = .default
    ) async throws -> [DetectedHoleCandidate] {
        let imageSize = CGSize(width: image.width, height: image.height)
        let transformer = TargetCoordinateTransformer(cropGeometry: cropGeometry, imageSize: imageSize)

        // Step 1: Convert to grayscale for processing
        guard let grayscale = convertToGrayscale(image) else {
            throw DetectionError.imageProcessingFailed
        }

        // Step 2: Detect contours
        let contours = try await detectContours(in: image)

        // Step 3: Filter and score candidates
        var candidates: [DetectedHoleCandidate] = []

        for contour in contours {
            guard let candidate = evaluateContour(
                contour,
                grayscale: grayscale,
                imageWidth: image.width,
                imageHeight: image.height,
                transformer: transformer,
                targetType: targetType,
                config: config
            ) else {
                continue
            }

            // Filter by confidence
            guard candidate.confidence >= config.minimumConfidence else {
                continue
            }

            // Filter scoring ring artifacts
            if config.filterScoringRingArtifacts {
                if isOnScoringRing(candidate.targetPosition, targetType: targetType, tolerance: config.scoringRingTolerance) {
                    // Only reject if confidence is not very high
                    if candidate.confidence < 0.9 {
                        continue
                    }
                }
            }

            candidates.append(candidate)
        }

        // Step 4: Non-maximum suppression for overlapping detections
        let filtered = nonMaximumSuppression(candidates, overlapThreshold: 0.3)

        // Step 5: Sort by confidence and limit
        let sorted = filtered
            .sorted { $0.confidence > $1.confidence }
            .prefix(config.maxCandidates)

        return Array(sorted)
    }

    /// Detect possible overlapping holes (figure-8 shapes)
    func detectOverlappingHoles(
        in image: CGImage,
        cropGeometry: TargetCropGeometry,
        config: HoleDetectionConfig = .default
    ) async throws -> [(CGPoint, CGPoint)] {
        // This is an advanced feature - detect elongated shapes that might be two holes
        guard let grayscale = convertToGrayscale(image) else {
            return []
        }

        let contours = try await detectContours(in: image)
        var overlappingPairs: [(CGPoint, CGPoint)] = []

        for contour in contours {
            // Calculate bounding box from normalized points
            let points = contour.normalizedPoints
            guard points.count >= 6 else { continue }

            let xs = points.map { CGFloat($0.x) * CGFloat(image.width) }
            let ys = points.map { (1 - CGFloat($0.y)) * CGFloat(image.height) }

            guard let minX = xs.min(), let maxX = xs.max(),
                  let minY = ys.min(), let maxY = ys.max() else {
                continue
            }

            let boundsWidth = maxX - minX
            let boundsHeight = maxY - minY
            guard boundsHeight > 0 else { continue }

            let aspectRatio = boundsWidth / boundsHeight

            // Two overlapping holes create elongated shapes
            if aspectRatio > 1.5 || aspectRatio < 0.67 {
                // Try to find two intensity minima
                if let pair = findIntensityMinimaPair(
                    contour: contour,
                    grayscale: grayscale,
                    imageWidth: image.width,
                    imageHeight: image.height
                ) {
                    overlappingPairs.append(pair)
                }
            }
        }

        return overlappingPairs
    }

    // MARK: - Private Methods

    private func detectContours(in image: CGImage) async throws -> [VNContour] {
        let request = VNDetectContoursRequest()
        request.maximumImageDimension = 1024
        request.contrastAdjustment = 2.0

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first else {
            return []
        }

        var allContours: [VNContour] = []
        for i in 0..<observation.contourCount {
            if let contour = try? observation.contour(at: i) {
                allContours.append(contour)
            }
        }

        return allContours
    }

    private func evaluateContour(
        _ contour: VNContour,
        grayscale: [UInt8],
        imageWidth: Int,
        imageHeight: Int,
        transformer: TargetCoordinateTransformer,
        targetType: ShootingTargetGeometryType,
        config: HoleDetectionConfig
    ) -> DetectedHoleCandidate? {
        let points = contour.normalizedPoints
        guard points.count >= 6 else { return nil }

        // Calculate bounding box in pixel coordinates
        let xs = points.map { CGFloat($0.x) * CGFloat(imageWidth) }
        let ys = points.map { (1 - CGFloat($0.y)) * CGFloat(imageHeight) }  // Flip Y

        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else {
            return nil
        }

        let width = maxX - minX
        let height = maxY - minY
        let diameter = (width + height) / 2

        // Size filter
        guard config.expectedHoleDiameterPixels.contains(diameter) else {
            return nil
        }

        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        let pixelPosition = CGPoint(x: centerX, y: centerY)

        // Calculate features
        let circularity = calculateCircularity(points: points)
        let aspectRatio = width / height
        let area = Double(width * height)

        // Shape filter
        guard circularity >= config.minCircularity else { return nil }
        guard aspectRatio > 0.5 && aspectRatio < 2.0 else { return nil }

        // Calculate intensity features
        let meanIntensity = sampleMeanIntensity(
            center: pixelPosition,
            radius: diameter / 2,
            grayscale: grayscale,
            imageWidth: imageWidth,
            imageHeight: imageHeight
        )

        // Local background estimation
        var darknessZScore: Double = 0
        if config.useLocalBackground {
            let localBG = LocalBackgroundEstimator.estimate(
                around: pixelPosition,
                in: grayscale,
                imageWidth: imageWidth,
                imageHeight: imageHeight,
                innerRadius: Int(diameter / 2 * 1.5),
                outerRadius: Int(diameter / 2 * 3)
            )
            darknessZScore = localBG.zScore(for: meanIntensity)
        }

        // Edge strength
        let edgeStrength = calculateEdgeStrength(
            center: pixelPosition,
            radius: diameter / 2,
            grayscale: grayscale,
            imageWidth: imageWidth,
            imageHeight: imageHeight
        )

        let features = HoleFeatures(
            circularity: circularity,
            aspectRatio: Double(aspectRatio),
            meanIntensity: meanIntensity,
            edgeStrength: edgeStrength,
            darknessZScore: darknessZScore,
            area: area
        )

        // Calculate confidence
        let confidence = calculateConfidence(features: features, config: config)

        // Convert to target coordinates
        let targetPosition = transformer.toTargetCoordinates(pixelPosition: pixelPosition)

        // Calculate score
        let score = targetType.score(from: targetPosition)

        return DetectedHoleCandidate(
            pixelPosition: pixelPosition,
            targetPosition: targetPosition,
            radiusPixels: diameter / 2,
            confidence: confidence,
            features: features,
            score: score
        )
    }

    private func calculateCircularity(points: [SIMD2<Float>]) -> Double {
        guard points.count >= 6 else { return 0 }

        // Calculate perimeter
        var perimeter: Float = 0
        for i in 0..<points.count {
            let p1 = points[i]
            let p2 = points[(i + 1) % points.count]
            let dx = p2.x - p1.x
            let dy = p2.y - p1.y
            perimeter += sqrt(dx * dx + dy * dy)
        }

        // Calculate area using shoelace formula
        var area: Float = 0
        for i in 0..<points.count {
            let p1 = points[i]
            let p2 = points[(i + 1) % points.count]
            area += p1.x * p2.y - p2.x * p1.y
        }
        area = abs(area) / 2

        // Circularity = 4 * pi * area / perimeter^2
        guard perimeter > 0 else { return 0 }
        let circularity = 4 * Float.pi * area / (perimeter * perimeter)

        return Double(min(1.0, circularity))
    }

    private func sampleMeanIntensity(
        center: CGPoint,
        radius: CGFloat,
        grayscale: [UInt8],
        imageWidth: Int,
        imageHeight: Int
    ) -> Double {
        let cx = Int(center.x)
        let cy = Int(center.y)
        let r = Int(radius)

        var sum: Int = 0
        var count: Int = 0

        for dy in -r...r {
            for dx in -r...r {
                let dist = sqrt(Double(dx * dx + dy * dy))
                guard dist <= Double(r) else { continue }

                let x = cx + dx
                let y = cy + dy

                guard x >= 0 && x < imageWidth && y >= 0 && y < imageHeight else {
                    continue
                }

                let idx = y * imageWidth + x
                sum += Int(grayscale[idx])
                count += 1
            }
        }

        return count > 0 ? Double(sum) / Double(count) : 128
    }

    private func calculateEdgeStrength(
        center: CGPoint,
        radius: CGFloat,
        grayscale: [UInt8],
        imageWidth: Int,
        imageHeight: Int
    ) -> Double {
        let cx = Int(center.x)
        let cy = Int(center.y)
        let r = Int(radius)

        var gradientSum: Double = 0
        var count = 0

        // Sample gradient magnitude around the edge
        for angle in stride(from: 0.0, to: 2 * Double.pi, by: Double.pi / 8) {
            let x = cx + Int(Double(r) * cos(angle))
            let y = cy + Int(Double(r) * sin(angle))

            guard x > 0 && x < imageWidth - 1 && y > 0 && y < imageHeight - 1 else {
                continue
            }

            // Sobel gradient
            let idx = y * imageWidth + x
            let left = Int(grayscale[idx - 1])
            let right = Int(grayscale[idx + 1])
            let top = Int(grayscale[idx - imageWidth])
            let bottom = Int(grayscale[idx + imageWidth])

            let gx = Double(right - left)
            let gy = Double(bottom - top)
            let magnitude = sqrt(gx * gx + gy * gy)

            gradientSum += magnitude
            count += 1
        }

        // Normalize to 0-1
        return count > 0 ? min(1.0, gradientSum / Double(count) / 100.0) : 0
    }

    private func calculateConfidence(features: HoleFeatures, config: HoleDetectionConfig) -> Double {
        var score: Double = 0

        // Circularity (most important)
        if features.circularity > 0.7 {
            score += 0.35
        } else if features.circularity > config.minCircularity {
            score += 0.2
        }

        // Darkness relative to background
        if features.darknessZScore > 3.0 {
            score += 0.3
        } else if features.darknessZScore > 2.0 {
            score += 0.2
        } else if features.darknessZScore > 1.0 {
            score += 0.1
        }

        // Edge definition
        if features.edgeStrength > 0.6 {
            score += 0.2
        } else if features.edgeStrength > 0.4 {
            score += 0.1
        }

        // Aspect ratio (closer to 1.0 is better)
        let aspectDeviation = abs(features.aspectRatio - 1.0)
        if aspectDeviation < 0.2 {
            score += 0.15
        } else if aspectDeviation < 0.4 {
            score += 0.1
        }

        return min(1.0, score)
    }

    private func isOnScoringRing(
        _ position: NormalizedTargetPosition,
        targetType: ShootingTargetGeometryType,
        tolerance: Double
    ) -> Bool {
        let radii = targetType.normalizedScoringRadii
        let distance = position.ellipticalDistance(aspectRatio: targetType.aspectRatio)

        return radii.contains { _, ringRadius in
            abs(distance - ringRadius) < tolerance
        }
    }

    private func nonMaximumSuppression(
        _ candidates: [DetectedHoleCandidate],
        overlapThreshold: Double
    ) -> [DetectedHoleCandidate] {
        guard !candidates.isEmpty else { return [] }

        var sorted = candidates.sorted { $0.confidence > $1.confidence }
        var kept: [DetectedHoleCandidate] = []

        while !sorted.isEmpty {
            let best = sorted.removeFirst()
            kept.append(best)

            // Remove overlapping candidates
            sorted.removeAll { candidate in
                let dist = best.targetPosition.distance(to: candidate.targetPosition)
                return dist < overlapThreshold
            }
        }

        return kept
    }

    private func findIntensityMinimaPair(
        contour: VNContour,
        grayscale: [UInt8],
        imageWidth: Int,
        imageHeight: Int
    ) -> (CGPoint, CGPoint)? {
        let points = contour.normalizedPoints
        guard points.count >= 10 else { return nil }

        // Get bounding box
        let xs = points.map { CGFloat($0.x) * CGFloat(imageWidth) }
        let ys = points.map { (1 - CGFloat($0.y)) * CGFloat(imageHeight) }

        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else {
            return nil
        }

        // Determine major axis
        let width = maxX - minX
        let height = maxY - minY
        let isHorizontal = width > height

        // Sample intensity along major axis
        var intensityProfile: [(position: CGPoint, intensity: Double)] = []
        let steps = 10
        let centerY = (minY + maxY) / 2
        let centerX = (minX + maxX) / 2

        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let position: CGPoint
            if isHorizontal {
                position = CGPoint(x: minX + t * width, y: centerY)
            } else {
                position = CGPoint(x: centerX, y: minY + t * height)
            }

            let intensity = sampleMeanIntensity(
                center: position,
                radius: 3,
                grayscale: grayscale,
                imageWidth: imageWidth,
                imageHeight: imageHeight
            )

            intensityProfile.append((position, intensity))
        }

        // Find two local minima
        var minima: [(position: CGPoint, intensity: Double)] = []
        for i in 1..<(intensityProfile.count - 1) {
            if intensityProfile[i].intensity < intensityProfile[i-1].intensity &&
               intensityProfile[i].intensity < intensityProfile[i+1].intensity {
                minima.append(intensityProfile[i])
            }
        }

        // Need exactly 2 minima for overlapping holes
        guard minima.count == 2 else { return nil }

        return (minima[0].position, minima[1].position)
    }

    private func convertToGrayscale(_ image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        let pixelCount = width * height

        var grayscale = [UInt8](repeating: 0, count: pixelCount)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.linearGray),
              let context = CGContext(
                data: &grayscale,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
              ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return grayscale
    }

    // MARK: - Errors

    enum DetectionError: Error {
        case imageProcessingFailed
        case contourDetectionFailed
    }
}

// MARK: - Hole Classifier

/// Classifies detected holes with learned thresholds
struct HoleClassifier {
    // Thresholds (could be learned from labeled data in future)
    static let circularityThreshold: Double = 0.55
    static let darknessZScoreThreshold: Double = 1.5
    static let edgeStrengthThreshold: Double = 0.35
    static let aspectRatioTolerance: Double = 0.5

    static func classify(features: HoleFeatures) -> HoleClassification {
        var passingCriteria = 0
        var totalCriteria = 4

        if features.circularity >= circularityThreshold { passingCriteria += 1 }
        if features.darknessZScore >= darknessZScoreThreshold { passingCriteria += 1 }
        if features.edgeStrength >= edgeStrengthThreshold { passingCriteria += 1 }
        if abs(features.aspectRatio - 1.0) <= aspectRatioTolerance { passingCriteria += 1 }

        switch passingCriteria {
        case 4:
            return .definitelyHole
        case 3:
            return .likelyHole
        case 2:
            return .possibleHole
        default:
            return .unlikelyHole
        }
    }

    enum HoleClassification {
        case definitelyHole
        case likelyHole
        case possibleHole
        case unlikelyHole
    }
}
