//
//  DetectionPipelineCache.swift
//  TetraTrack
//
//  Caching infrastructure for detection pipeline stages.
//  Enables fast iterative testing and threshold tuning.
//

import Foundation
import UIKit
import CoreImage

// MARK: - Pipeline Stage Results

/// Result from image preprocessing stage
struct PreprocessingResult {
    let grayscaleData: [UInt8]
    let imageWidth: Int
    let imageHeight: Int
    let edgeMap: [Float]?
    let timestamp: Date

    var pixelCount: Int { imageWidth * imageHeight }
}

/// Result from contour detection stage
struct ContourDetectionResult {
    let contours: [DetectedContour]
    let timestamp: Date
    let processingTime: TimeInterval
}

/// A detected contour with extracted features
struct DetectedContour: Identifiable {
    let id = UUID()
    let boundingBox: CGRect
    let centerPixel: CGPoint
    let area: Double
    let circularity: Double
    let aspectRatio: Double
    let points: [CGPoint]
}

/// Result from candidate filtering stage
struct FilteringResult {
    let acceptedCandidates: [FilteredCandidate]
    let rejectedCandidates: [FilteredCandidate]
    let timestamp: Date
}

struct FilteredCandidate {
    let contour: DetectedContour
    let normalizedPosition: NormalizedTargetPosition
    let filterReason: String?
    let passed: Bool
}

// MARK: - Pipeline Cache

/// Cache for detection pipeline intermediate results
actor DetectionPipelineCache {

    // MARK: - Cache Storage

    private var preprocessingCache: [String: PreprocessingResult] = [:]
    private var contourCache: [String: ContourDetectionResult] = [:]
    private var filteringCache: [String: FilteringResult] = [:]

    /// Maximum cache entries per category
    private let maxCacheSize = 20

    /// Cache hit statistics
    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0

    // MARK: - Preprocessing Cache

    func cachePreprocessing(_ result: PreprocessingResult, for imageHash: String) {
        evictIfNeeded(&preprocessingCache)
        preprocessingCache[imageHash] = result
    }

    func getPreprocessing(for imageHash: String) -> PreprocessingResult? {
        if let result = preprocessingCache[imageHash] {
            cacheHits += 1
            return result
        }
        cacheMisses += 1
        return nil
    }

    // MARK: - Contour Cache

    func cacheContours(_ result: ContourDetectionResult, for imageHash: String) {
        evictIfNeeded(&contourCache)
        contourCache[imageHash] = result
    }

    func getContours(for imageHash: String) -> ContourDetectionResult? {
        if let result = contourCache[imageHash] {
            cacheHits += 1
            return result
        }
        cacheMisses += 1
        return nil
    }

    // MARK: - Filtering Cache

    /// Cache key combines image hash and config hash
    func cacheFiltering(_ result: FilteringResult, for cacheKey: String) {
        evictIfNeeded(&filteringCache)
        filteringCache[cacheKey] = result
    }

    func getFiltering(for cacheKey: String) -> FilteringResult? {
        if let result = filteringCache[cacheKey] {
            cacheHits += 1
            return result
        }
        cacheMisses += 1
        return nil
    }

    // MARK: - Cache Management

    func clearAll() {
        preprocessingCache.removeAll()
        contourCache.removeAll()
        filteringCache.removeAll()
        cacheHits = 0
        cacheMisses = 0
    }

    func clearForImage(_ imageHash: String) {
        preprocessingCache.removeValue(forKey: imageHash)
        contourCache.removeValue(forKey: imageHash)
        // Clear all filtering entries for this image
        filteringCache = filteringCache.filter { !$0.key.hasPrefix(imageHash) }
    }

    var statistics: CacheStatistics {
        CacheStatistics(
            preprocessingCount: preprocessingCache.count,
            contourCount: contourCache.count,
            filteringCount: filteringCache.count,
            hits: cacheHits,
            misses: cacheMisses
        )
    }

    private func evictIfNeeded<T>(_ cache: inout [String: T]) {
        if cache.count >= maxCacheSize {
            // Simple FIFO eviction - remove oldest entries
            let keysToRemove = Array(cache.keys.prefix(cache.count / 2))
            for key in keysToRemove {
                cache.removeValue(forKey: key)
            }
        }
    }

    struct CacheStatistics {
        let preprocessingCount: Int
        let contourCount: Int
        let filteringCount: Int
        let hits: Int
        let misses: Int

        var hitRate: Double {
            let total = hits + misses
            return total > 0 ? Double(hits) / Double(total) : 0
        }
    }
}

// MARK: - Staged Pipeline Executor

/// Executes detection pipeline in distinct cacheable stages
actor StagedPipelineExecutor {

    private let cache = DetectionPipelineCache()
    private let qualityAssessor = ImageQualityAssessor()
    private let holeDetector = AssistedHoleDetector()

    // MARK: - Runtime Configuration

    #if DEBUG
    /// Adjustable thresholds for debug tuning
    nonisolated(unsafe) static var debugConfig = DebugPipelineConfig()
    #endif

    // MARK: - Full Pipeline Execution

    /// Execute full pipeline with caching
    func execute(
        image: AcquiredTargetImage,
        cropGeometry: TargetCropGeometry,
        targetType: ShootingTargetGeometryType,
        config: HoleDetectionConfig
    ) async throws -> PipelineExecutionResult {
        var timing: [String: TimeInterval] = [:]
        var debugState = DebugPipelineState()

        let imageHash = image.imageHash

        // Stage 1: Quality Assessment
        let qualityStart = Date()
        let quality = await qualityAssessor.assess(image: image.image)
        timing["quality"] = Date().timeIntervalSince(qualityStart)

        // Stage 2: Preprocessing
        let preprocessStart = Date()
        let preprocessing: PreprocessingResult
        if let cached = await cache.getPreprocessing(for: imageHash) {
            preprocessing = cached
        } else {
            preprocessing = await preprocess(image.cgImage!)
            await cache.cachePreprocessing(preprocessing, for: imageHash)
        }
        timing["preprocessing"] = Date().timeIntervalSince(preprocessStart)

        // Stage 3: Contour Detection
        let contourStart = Date()
        let contours: ContourDetectionResult
        if let cached = await cache.getContours(for: imageHash) {
            contours = cached
        } else {
            contours = try await detectContours(in: image.cgImage!)
            await cache.cacheContours(contours, for: imageHash)
        }
        timing["contours"] = Date().timeIntervalSince(contourStart)

        #if DEBUG
        debugState.completedStages = [.imageAcquisition, .qualityAssessment, .contourDetection]
        #endif

        // Stage 4: Candidate Filtering (config-dependent)
        let filterStart = Date()
        let configHash = configurationHash(config)
        let filterCacheKey = "\(imageHash)_\(configHash)"

        let filtering: FilteringResult
        if let cached = await cache.getFiltering(for: filterCacheKey) {
            filtering = cached
        } else {
            filtering = await filterCandidates(
                contours: contours.contours,
                preprocessing: preprocessing,
                cropGeometry: cropGeometry,
                targetType: targetType,
                config: config
            )
            await cache.cacheFiltering(filtering, for: filterCacheKey)
        }
        timing["filtering"] = Date().timeIntervalSince(filterStart)

        // Stage 5: Confidence Scoring
        let scoringStart = Date()
        let scoredCandidates = await scoreCandidates(
            filtering.acceptedCandidates,
            preprocessing: preprocessing,
            cropGeometry: cropGeometry,
            targetType: targetType,
            config: config
        )
        timing["scoring"] = Date().timeIntervalSince(scoringStart)

        #if DEBUG
        debugState.completedStages.insert(.candidateFiltering)
        debugState.completedStages.insert(.confidenceScoring)
        debugState.candidateHoles = filtering.acceptedCandidates.map { candidate in
            DebugHoleCandidate(
                pixelPosition: candidate.contour.centerPixel,
                normalizedPosition: candidate.normalizedPosition,
                radiusPixels: sqrt(candidate.contour.area / .pi),
                confidence: 0,
                filterReason: nil,
                features: [
                    "circularity": candidate.contour.circularity,
                    "aspectRatio": candidate.contour.aspectRatio,
                    "area": candidate.contour.area
                ]
            )
        }
        debugState.filteredHoles = filtering.rejectedCandidates.map { candidate in
            DebugHoleCandidate(
                pixelPosition: candidate.contour.centerPixel,
                normalizedPosition: candidate.normalizedPosition,
                radiusPixels: sqrt(candidate.contour.area / .pi),
                confidence: 0,
                filterReason: candidate.filterReason,
                features: [:]
            )
        }
        #endif

        return PipelineExecutionResult(
            candidates: scoredCandidates,
            quality: quality,
            timing: timing,
            debugState: debugState,
            cacheStatistics: await cache.statistics
        )
    }

    // MARK: - Individual Stages

    private func preprocess(_ image: CGImage) async -> PreprocessingResult {
        let width = image.width
        let height = image.height
        var grayscale = [UInt8](repeating: 0, count: width * height)

        // Convert to grayscale
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
            return PreprocessingResult(
                grayscaleData: grayscale,
                imageWidth: width,
                imageHeight: height,
                edgeMap: nil,
                timestamp: Date()
            )
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Optionally compute edge map (Sobel)
        let edgeMap = computeEdgeMap(grayscale, width: width, height: height)

        return PreprocessingResult(
            grayscaleData: grayscale,
            imageWidth: width,
            imageHeight: height,
            edgeMap: edgeMap,
            timestamp: Date()
        )
    }

    private func computeEdgeMap(_ grayscale: [UInt8], width: Int, height: Int) -> [Float] {
        var edges = [Float](repeating: 0, count: width * height)

        // Simple Sobel edge detection
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let idx = y * width + x

                // Sobel X
                let gx = Float(grayscale[(y - 1) * width + (x + 1)]) - Float(grayscale[(y - 1) * width + (x - 1)])
                       + 2 * Float(grayscale[y * width + (x + 1)]) - 2 * Float(grayscale[y * width + (x - 1)])
                       + Float(grayscale[(y + 1) * width + (x + 1)]) - Float(grayscale[(y + 1) * width + (x - 1)])

                // Sobel Y
                let gy = Float(grayscale[(y + 1) * width + (x - 1)]) - Float(grayscale[(y - 1) * width + (x - 1)])
                       + 2 * Float(grayscale[(y + 1) * width + x]) - 2 * Float(grayscale[(y - 1) * width + x])
                       + Float(grayscale[(y + 1) * width + (x + 1)]) - Float(grayscale[(y - 1) * width + (x + 1)])

                edges[idx] = sqrt(gx * gx + gy * gy)
            }
        }

        return edges
    }

    private func detectContours(in image: CGImage) async throws -> ContourDetectionResult {
        let startTime = Date()

        // Use Vision framework for contour detection
        let request = VNDetectContoursRequest()
        request.maximumImageDimension = 1024
        request.contrastAdjustment = 2.0

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first else {
            return ContourDetectionResult(contours: [], timestamp: Date(), processingTime: 0)
        }

        var detectedContours: [DetectedContour] = []
        for i in 0..<observation.contourCount {
            if let contour = try? observation.contour(at: i) {
                let points = contour.normalizedPoints
                guard points.count >= 6 else { continue }

                // Convert to pixel coordinates
                let pixelPoints = points.map { point in
                    CGPoint(
                        x: CGFloat(point.x) * CGFloat(image.width),
                        y: (1 - CGFloat(point.y)) * CGFloat(image.height)
                    )
                }

                // Calculate bounding box
                let xs = pixelPoints.map { $0.x }
                let ys = pixelPoints.map { $0.y }
                guard let minX = xs.min(), let maxX = xs.max(),
                      let minY = ys.min(), let maxY = ys.max() else {
                    continue
                }

                let boundingBox = CGRect(
                    x: minX,
                    y: minY,
                    width: maxX - minX,
                    height: maxY - minY
                )

                // Calculate features
                let area = boundingBox.width * boundingBox.height
                let perimeter = 2 * (boundingBox.width + boundingBox.height)
                let circularity = perimeter > 0 ? (4 * .pi * area) / (perimeter * perimeter) : 0
                let aspectRatio = boundingBox.height > 0 ? boundingBox.width / boundingBox.height : 1

                detectedContours.append(DetectedContour(
                    boundingBox: boundingBox,
                    centerPixel: CGPoint(x: boundingBox.midX, y: boundingBox.midY),
                    area: area,
                    circularity: circularity,
                    aspectRatio: aspectRatio,
                    points: pixelPoints
                ))
            }
        }

        let processingTime = Date().timeIntervalSince(startTime)
        return ContourDetectionResult(
            contours: detectedContours,
            timestamp: Date(),
            processingTime: processingTime
        )
    }

    private func filterCandidates(
        contours: [DetectedContour],
        preprocessing: PreprocessingResult,
        cropGeometry: TargetCropGeometry,
        targetType: ShootingTargetGeometryType,
        config: HoleDetectionConfig
    ) async -> FilteringResult {
        let imageSize = CGSize(
            width: preprocessing.imageWidth,
            height: preprocessing.imageHeight
        )
        let transformer = TargetCoordinateTransformer(
            cropGeometry: cropGeometry,
            imageSize: imageSize
        )

        var accepted: [FilteredCandidate] = []
        var rejected: [FilteredCandidate] = []

        #if DEBUG
        let effectiveConfig = Self.debugConfig.applyTo(config)
        #else
        let effectiveConfig = config
        #endif

        for contour in contours {
            let normalizedPosition = transformer.toTargetCoordinates(
                pixelPosition: contour.centerPixel
            )

            var filterReason: String?

            // Size filter
            let diameter = sqrt(contour.area / .pi) * 2
            if diameter < effectiveConfig.expectedHoleDiameterPixels.lowerBound {
                filterReason = "Too small"
            } else if diameter > effectiveConfig.expectedHoleDiameterPixels.upperBound {
                filterReason = "Too large"
            }

            // Circularity filter
            if filterReason == nil && contour.circularity < effectiveConfig.minCircularity {
                filterReason = "Not circular"
            }

            // Scoring ring filter
            if filterReason == nil && effectiveConfig.filterScoringRingArtifacts {
                if isOnScoringRing(normalizedPosition, targetType: targetType, tolerance: effectiveConfig.scoringRingTolerance) {
                    filterReason = "Scoring ring"
                }
            }

            let candidate = FilteredCandidate(
                contour: contour,
                normalizedPosition: normalizedPosition,
                filterReason: filterReason,
                passed: filterReason == nil
            )

            if filterReason == nil {
                accepted.append(candidate)
            } else {
                rejected.append(candidate)
            }
        }

        return FilteringResult(
            acceptedCandidates: accepted,
            rejectedCandidates: rejected,
            timestamp: Date()
        )
    }

    private func isOnScoringRing(
        _ position: NormalizedTargetPosition,
        targetType: ShootingTargetGeometryType,
        tolerance: Double
    ) -> Bool {
        let distance = position.ellipticalDistance(aspectRatio: targetType.aspectRatio)
        let radii = targetType.normalizedScoringRadii

        for (_, radius) in radii {
            if abs(distance - radius) < tolerance {
                return true
            }
        }
        return false
    }

    private func scoreCandidates(
        _ candidates: [FilteredCandidate],
        preprocessing: PreprocessingResult,
        cropGeometry: TargetCropGeometry,
        targetType: ShootingTargetGeometryType,
        config: HoleDetectionConfig
    ) async -> [DetectedHoleCandidate] {
        var scored: [DetectedHoleCandidate] = []

        for candidate in candidates {
            // Calculate confidence based on multiple factors
            var confidence = 1.0

            // Circularity score (higher is better)
            confidence *= min(1.0, candidate.contour.circularity / 0.8)

            // Size score (penalize extremes)
            let diameter = sqrt(candidate.contour.area / .pi) * 2
            let midpoint = (config.expectedHoleDiameterPixels.lowerBound + config.expectedHoleDiameterPixels.upperBound) / 2
            let sizeDeviation = abs(diameter - midpoint) / midpoint
            confidence *= max(0.5, 1.0 - sizeDeviation)

            // Local background contrast (if enabled)
            if config.useLocalBackground {
                let localBG = LocalBackgroundEstimator.estimate(
                    around: candidate.contour.centerPixel,
                    in: preprocessing.grayscaleData,
                    imageWidth: preprocessing.imageWidth,
                    imageHeight: preprocessing.imageHeight,
                    innerRadius: Int(sqrt(candidate.contour.area / .pi)),
                    outerRadius: Int(sqrt(candidate.contour.area / .pi) * 2)
                )

                // Get mean intensity inside candidate
                let centerIdx = Int(candidate.contour.centerPixel.y) * preprocessing.imageWidth +
                               Int(candidate.contour.centerPixel.x)
                if centerIdx >= 0 && centerIdx < preprocessing.grayscaleData.count {
                    let centerIntensity = Double(preprocessing.grayscaleData[centerIdx])
                    let zScore = localBG.zScore(for: centerIntensity)
                    // Higher z-score = darker than background = more likely a hole
                    confidence *= min(1.0, max(0.3, zScore / 3.0))
                }
            }

            let score = targetType.score(from: candidate.normalizedPosition)

            scored.append(DetectedHoleCandidate(
                pixelPosition: candidate.contour.centerPixel,
                targetPosition: candidate.normalizedPosition,
                radiusPixels: sqrt(candidate.contour.area / .pi),
                confidence: confidence,
                features: HoleFeatures(
                    circularity: candidate.contour.circularity,
                    aspectRatio: candidate.contour.aspectRatio,
                    meanIntensity: 0,  // Could calculate if needed
                    edgeStrength: 0,
                    darknessZScore: 0,
                    area: candidate.contour.area
                ),
                score: score
            ))
        }

        // Sort by confidence descending
        return scored.sorted { $0.confidence > $1.confidence }
    }

    private func configurationHash(_ config: HoleDetectionConfig) -> String {
        var hasher = Hasher()
        hasher.combine(config.expectedHoleDiameterPixels.lowerBound)
        hasher.combine(config.expectedHoleDiameterPixels.upperBound)
        hasher.combine(config.minCircularity)
        hasher.combine(config.filterScoringRingArtifacts)
        hasher.combine(config.scoringRingTolerance)
        return String(hasher.finalize())
    }

    /// Clear all caches
    func clearCache() async {
        await cache.clearAll()
    }

    /// Get cache statistics
    func getCacheStatistics() async -> DetectionPipelineCache.CacheStatistics {
        await cache.statistics
    }
}

// MARK: - Pipeline Execution Result

struct PipelineExecutionResult {
    let candidates: [DetectedHoleCandidate]
    let quality: ImageQualityAssessment
    let timing: [String: TimeInterval]
    let debugState: DebugPipelineState
    let cacheStatistics: DetectionPipelineCache.CacheStatistics

    var totalProcessingTime: TimeInterval {
        timing.values.reduce(0, +)
    }
}

// MARK: - Debug Pipeline Config

#if DEBUG
/// Runtime-adjustable configuration for debug tuning
struct DebugPipelineConfig {
    var minCircularityOverride: Double?
    var holeDiameterMinOverride: CGFloat?
    var holeDiameterMaxOverride: CGFloat?
    var scoringRingToleranceOverride: Double?
    var filterScoringRingsOverride: Bool?

    func applyTo(_ config: HoleDetectionConfig) -> HoleDetectionConfig {
        var modified = config

        if let minCirc = minCircularityOverride {
            modified.minCircularity = minCirc
        }
        if let minDiam = holeDiameterMinOverride,
           let maxDiam = holeDiameterMaxOverride {
            modified.expectedHoleDiameterPixels = minDiam...maxDiam
        }
        if let tolerance = scoringRingToleranceOverride {
            modified.scoringRingTolerance = tolerance
        }
        if let filter = filterScoringRingsOverride {
            modified.filterScoringRingArtifacts = filter
        }

        return modified
    }
}
#endif

// MARK: - Batch Processing

/// Batch processor for multiple fixture images
actor BatchPipelineProcessor {

    private let executor = StagedPipelineExecutor()

    /// Process multiple fixtures and return results
    func processBatch(
        fixtures: [TargetFixture],
        targetType: ShootingTargetGeometryType,
        config: HoleDetectionConfig
    ) async -> [BatchProcessingResult] {
        var results: [BatchProcessingResult] = []

        for fixture in fixtures {
            guard let image = fixture.loadImage(),
                  let cgImage = image.cgImage else {
                results.append(BatchProcessingResult(
                    fixture: fixture,
                    result: nil,
                    error: "Failed to load image"
                ))
                continue
            }

            // Build crop geometry from fixture metadata
            let cropGeometry: TargetCropGeometry
            if let knownBounds = fixture.metadata.knownCropBounds,
               let knownCenter = fixture.metadata.knownTargetCenter,
               let knownAxes = fixture.metadata.knownSemiAxes {
                cropGeometry = TargetCropGeometry(
                    cropRect: knownBounds.cgRect,
                    targetCenterInCrop: knownCenter.cgPoint,
                    targetSemiAxes: knownAxes.cgSize,
                    rotationDegrees: fixture.metadata.rotationDegrees,
                    physicalAspectRatio: targetType.aspectRatio
                )
            } else {
                // Default geometry
                cropGeometry = TargetCropGeometry()
            }

            let acquiredImage = AcquiredTargetImage(
                image: image,
                sourceType: .simulatorFixture,
                sourceIdentifier: fixture.name,
                fixtureMetadata: fixture.metadata
            )

            do {
                let result = try await executor.execute(
                    image: acquiredImage,
                    cropGeometry: cropGeometry,
                    targetType: targetType,
                    config: config
                )

                results.append(BatchProcessingResult(
                    fixture: fixture,
                    result: result,
                    error: nil
                ))
            } catch {
                results.append(BatchProcessingResult(
                    fixture: fixture,
                    result: nil,
                    error: error.localizedDescription
                ))
            }
        }

        return results
    }
}

struct BatchProcessingResult {
    let fixture: TargetFixture
    let result: PipelineExecutionResult?
    let error: String?

    var succeeded: Bool { result != nil }
}

// Import Vision for contour detection
import Vision
