//
//  HoleDetectionPipeline.swift
//  TrackRide
//
//  Multi-signal bullet hole detection pipeline v2.0
//  Implements 5 detection signals with feature extraction and confidence scoring.
//

import Foundation
import UIKit

/// Main detection pipeline for .22 calibre bullet holes on tetrathlon targets
actor HoleDetectionPipeline {

    // MARK: - Configuration

    private var config: HoleDetectionConfiguration

    // MARK: - Initialization

    init(config: HoleDetectionConfiguration = .default) {
        self.config = config
    }

    // MARK: - Main Detection Entry Point

    func detect(image: UIImage, configuration: HoleDetectionConfiguration? = nil) async throws -> HoleDetectionResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let activeConfig = configuration ?? config

        // Convert to grayscale
        guard let cgImage = image.cgImage,
              let (grayscale, width, height) = ImageProcessor.toGrayscale(cgImage: cgImage) else {
            throw DetectionError.invalidImage
        }

        var diagnostics = DetectionDiagnostics(
            imageSize: CGSize(width: width, height: height),
            expectedRadiusPx: 0, minRadiusPx: 0, maxRadiusPx: 0
        )

        // Calculate hole size parameters
        let imageDim = min(width, height)
        let expectedRadius = max(6, Int(Double(imageDim) * activeConfig.expectedHoleRadiusPercent))
        let minRadius = max(3, Int(Double(expectedRadius) * activeConfig.sizeToleranceMin))
        let maxRadius = Int(Double(expectedRadius) * activeConfig.sizeToleranceMax)

        diagnostics.expectedRadiusPx = expectedRadius
        diagnostics.minRadiusPx = minRadius
        diagnostics.maxRadiusPx = maxRadius

        // Stage 1: Region Analysis
        let regionStart = CFAbsoluteTimeGetCurrent()
        let regionAnalysis = analyzeRegions(grayscale: grayscale, width: width, height: height)
        diagnostics.regionAnalysisMs = Int((CFAbsoluteTimeGetCurrent() - regionStart) * 1000)

        // Compute edge image for Signal C
        let edges = ImageProcessor.sobelMagnitude(grayscale: grayscale, width: width, height: height)

        // Stage 2: Multi-Signal Candidate Generation
        let signalStart = CFAbsoluteTimeGetCurrent()
        var allCandidates: [DetectionCandidate] = []

        // Signal A: Dark anomaly on white region
        let signalA = detectDarkAnomalies(
            grayscale: grayscale,
            regionAnalysis: regionAnalysis,
            expectedRadius: expectedRadius,
            minRadius: minRadius,
            maxRadius: maxRadius,
            width: width,
            height: height,
            config: activeConfig
        )
        allCandidates.append(contentsOf: signalA)
        diagnostics.signalACandidates = signalA.count

        // Signal B: Light anomaly on black region
        let signalB = detectLightAnomalies(
            grayscale: grayscale,
            regionAnalysis: regionAnalysis,
            expectedRadius: expectedRadius,
            minRadius: minRadius,
            maxRadius: maxRadius,
            width: width,
            height: height,
            config: activeConfig
        )
        allCandidates.append(contentsOf: signalB)
        diagnostics.signalBCandidates = signalB.count

        // Signal C: Edge ring detector
        if activeConfig.enableSignalC {
            let signalC = detectEdgeRings(
                edges: edges,
                grayscale: grayscale,
                regionAnalysis: regionAnalysis,
                expectedRadius: expectedRadius,
                width: width,
                height: height,
                config: activeConfig
            )
            allCandidates.append(contentsOf: signalC)
            diagnostics.signalCCandidates = signalC.count
        }

        diagnostics.signalGenerationMs = Int((CFAbsoluteTimeGetCurrent() - signalStart) * 1000)

        // Stage 3: Merge nearby candidates
        let mergedCandidates = mergeCandidates(
            allCandidates,
            mergeRadius: Double(expectedRadius) * activeConfig.mergeRadiusFraction,
            width: width,
            height: height
        )
        diagnostics.mergedCandidates = mergedCandidates.count

        // Stage 4: Feature Extraction
        let featureStart = CFAbsoluteTimeGetCurrent()
        var candidatesWithFeatures = extractFeatures(
            candidates: mergedCandidates,
            grayscale: grayscale,
            edges: edges,
            regionAnalysis: regionAnalysis,
            expectedRadius: expectedRadius,
            width: width,
            height: height
        )
        diagnostics.featureExtractionMs = Int((CFAbsoluteTimeGetCurrent() - featureStart) * 1000)

        // Stage 5: Confidence Scoring
        let scoringStart = CFAbsoluteTimeGetCurrent()
        scoreAndClassify(candidates: &candidatesWithFeatures, config: activeConfig)
        diagnostics.scoringMs = Int((CFAbsoluteTimeGetCurrent() - scoringStart) * 1000)

        // Stage 6: Overlap Detection (optional)
        if activeConfig.enableOverlapDetection {
            candidatesWithFeatures = handleOverlaps(
                candidates: candidatesWithFeatures,
                grayscale: grayscale,
                expectedRadius: expectedRadius,
                width: width,
                height: height
            )
        }

        // Stage 7: Partition into accepted/flagged/rejected
        var accepted: [DetectedHole] = []
        var flagged: [DetectedHole] = []
        var rejectedCount = 0

        for candidate in candidatesWithFeatures {
            let hole = DetectedHole(
                position: candidate.center,
                score: 0,
                confidence: candidate.confidence,
                radius: candidate.estimatedRadius,
                needsReview: candidate.needsReview,
                reviewReason: candidate.reviewReason?.rawValue
            )

            if candidate.confidence >= activeConfig.autoAcceptThreshold && !candidate.needsReview {
                accepted.append(hole)
                diagnostics.allCandidates.append(CandidateDiagnostic(
                    id: candidate.id, position: candidate.center, region: candidate.region,
                    signals: candidate.signals, features: candidate.features,
                    confidence: candidate.confidence, classification: "accept"
                ))
            } else if candidate.confidence >= activeConfig.reviewThreshold {
                flagged.append(hole)
                diagnostics.allCandidates.append(CandidateDiagnostic(
                    id: candidate.id, position: candidate.center, region: candidate.region,
                    signals: candidate.signals, features: candidate.features,
                    confidence: candidate.confidence, classification: "flag"
                ))
            } else {
                rejectedCount += 1
                diagnostics.allCandidates.append(CandidateDiagnostic(
                    id: candidate.id, position: candidate.center, region: candidate.region,
                    signals: candidate.signals, features: candidate.features,
                    confidence: candidate.confidence, classification: "reject"
                ))
            }
        }

        let totalTime = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
        diagnostics.totalMs = totalTime

        // Log diagnostics
        logDiagnostics(diagnostics, regionAnalysis: regionAnalysis)

        return HoleDetectionResult(
            acceptedHoles: accepted,
            flaggedCandidates: flagged,
            rejectedCount: rejectedCount,
            qualityWarnings: generateWarnings(regionAnalysis: regionAnalysis),
            regionAnalysis: regionAnalysis,
            processingTimeMs: totalTime,
            diagnostics: activeConfig.enableDiagnostics ? diagnostics : nil
        )
    }

    // MARK: - Region Analysis

    private func analyzeRegions(grayscale: [[UInt8]], width: Int, height: Int) -> TargetRegionAnalysis {
        // Compute column means
        var columnMeans = [Double](repeating: 0, count: width)
        for x in 0..<width {
            var sum = 0
            for y in stride(from: 0, to: height, by: 4) {
                sum += Int(grayscale[y][x])
            }
            columnMeans[x] = Double(sum) / Double((height + 3) / 4)
        }

        // Find transition (steepest gradient)
        var maxGradient = 0.0
        var transitionX = width / 2
        let windowSize = min(15, width / 20)

        for x in windowSize..<(width - windowSize) {
            let leftMean = columnMeans[(x - windowSize)..<x].reduce(0, +) / Double(windowSize)
            let rightMean = columnMeans[x..<(x + windowSize)].reduce(0, +) / Double(windowSize)
            let gradient = abs(rightMean - leftMean)

            if gradient > maxGradient {
                maxGradient = gradient
                transitionX = x
            }
        }

        // If no clear transition, assume center
        if maxGradient < 30 {
            transitionX = width / 2
        }

        // Compute region statistics
        let (leftMean, leftStd) = computeRegionStats(grayscale: grayscale, startX: 0, endX: transitionX, width: width, height: height)
        let (rightMean, rightStd) = computeRegionStats(grayscale: grayscale, startX: transitionX, endX: width, width: width, height: height)

        let isLeftBlack = leftMean < rightMean

        // Compute overall contrast and sharpness
        let flatPixels = grayscale.flatMap { $0 }
        let sortedPixels = flatPixels.sorted()
        let p5 = sortedPixels[sortedPixels.count / 20]
        let p95 = sortedPixels[sortedPixels.count * 19 / 20]
        let overallContrast = Double(p95 - p5) / 255.0

        let sharpness = computeSharpness(grayscale: grayscale, width: width, height: height)

        return TargetRegionAnalysis(
            blackRegionMean: isLeftBlack ? leftMean : rightMean,
            blackRegionStd: isLeftBlack ? leftStd : rightStd,
            whiteRegionMean: isLeftBlack ? rightMean : leftMean,
            whiteRegionStd: isLeftBlack ? rightStd : leftStd,
            transitionX: transitionX,
            transitionXNormalized: Double(transitionX) / Double(width),
            isLeftBlack: isLeftBlack,
            overallContrast: overallContrast,
            sharpness: sharpness
        )
    }

    private func computeRegionStats(grayscale: [[UInt8]], startX: Int, endX: Int, width: Int, height: Int) -> (mean: Double, std: Double) {
        guard endX > startX else { return (128, 30) }

        var sum: Double = 0
        var count = 0

        for y in stride(from: 0, to: height, by: 4) {
            for x in stride(from: startX, to: endX, by: 4) {
                sum += Double(grayscale[y][x])
                count += 1
            }
        }

        let mean = count > 0 ? sum / Double(count) : 128

        var varianceSum: Double = 0
        for y in stride(from: 0, to: height, by: 4) {
            for x in stride(from: startX, to: endX, by: 4) {
                let diff = Double(grayscale[y][x]) - mean
                varianceSum += diff * diff
            }
        }

        let std = count > 1 ? sqrt(varianceSum / Double(count)) : 30
        return (mean, max(std, 1.0))
    }

    private func computeSharpness(grayscale: [[UInt8]], width: Int, height: Int) -> Double {
        var laplacianSum: Double = 0
        var count = 0

        for y in stride(from: 2, to: height - 2, by: 4) {
            for x in stride(from: 2, to: width - 2, by: 4) {
                let center = Int(grayscale[y][x])
                let lap = Int(grayscale[y-1][x]) + Int(grayscale[y+1][x]) +
                          Int(grayscale[y][x-1]) + Int(grayscale[y][x+1]) - 4 * center
                laplacianSum += Double(lap * lap)
                count += 1
            }
        }

        return count > 0 ? laplacianSum / Double(count) : 0
    }

    // MARK: - Signal A: Dark Anomaly Detection

    private func detectDarkAnomalies(
        grayscale: [[UInt8]],
        regionAnalysis: TargetRegionAnalysis,
        expectedRadius: Int,
        minRadius: Int,
        maxRadius: Int,
        width: Int,
        height: Int,
        config: HoleDetectionConfiguration
    ) -> [DetectionCandidate] {
        var candidates: [DetectionCandidate] = []

        // Determine white region bounds
        let whiteStartX: Int
        let whiteEndX: Int
        if regionAnalysis.isLeftBlack {
            whiteStartX = regionAnalysis.transitionX
            whiteEndX = width
        } else {
            whiteStartX = 0
            whiteEndX = regionAnalysis.transitionX
        }

        guard whiteEndX > whiteStartX + maxRadius * 2 else { return candidates }

        let step = max(3, expectedRadius / 2)
        let innerR = Int(Double(expectedRadius) * 1.2)
        let outerR = Int(Double(expectedRadius) * 2.0)

        for y in stride(from: maxRadius + 5, to: height - maxRadius - 5, by: step) {
            for x in stride(from: max(whiteStartX + maxRadius, maxRadius + 5), to: min(whiteEndX - maxRadius, width - maxRadius - 5), by: step) {
                let centerIntensity = Double(grayscale[y][x])

                // Sample surrounding ring
                let (bgMean, bgStd) = sampleRing(grayscale: grayscale, x: x, y: y, innerR: innerR, outerR: outerR, width: width, height: height)

                // Dark anomaly: center significantly darker than background
                let contrast = bgMean - centerIntensity

                if contrast >= config.signalAContrastThreshold {
                    // Find blob extent
                    let threshold = Int((centerIntensity + bgMean) / 2)
                    let (centerX, centerY, area) = findBlobExtent(
                        grayscale: grayscale, seedX: x, seedY: y,
                        threshold: threshold, maxRadius: maxRadius,
                        width: width, height: height, detectLight: false
                    )

                    let minArea = Int(Double.pi * Double(minRadius * minRadius) * 0.3)
                    let maxArea = Int(Double.pi * Double(maxRadius * maxRadius) * 2.0)

                    if area >= minArea && area <= maxArea {
                        let radius = sqrt(Double(area) / Double.pi)
                        let rawScore = min(1.0, contrast / 50.0)

                        candidates.append(DetectionCandidate(
                            center: CGPoint(x: Double(centerX) / Double(width), y: Double(centerY) / Double(height)),
                            pixelCenter: CGPoint(x: centerX, y: centerY),
                            estimatedRadius: radius / Double(min(width, height)),
                            pixelRadius: radius,
                            signal: .darkAnomaly,
                            rawScore: rawScore,
                            region: .white
                        ))
                    }
                }
            }
        }

        return candidates
    }

    // MARK: - Signal B: Light Anomaly Detection

    private func detectLightAnomalies(
        grayscale: [[UInt8]],
        regionAnalysis: TargetRegionAnalysis,
        expectedRadius: Int,
        minRadius: Int,
        maxRadius: Int,
        width: Int,
        height: Int,
        config: HoleDetectionConfiguration
    ) -> [DetectionCandidate] {
        var candidates: [DetectionCandidate] = []

        // Determine black region bounds
        let blackStartX: Int
        let blackEndX: Int
        if regionAnalysis.isLeftBlack {
            blackStartX = 0
            blackEndX = regionAnalysis.transitionX
        } else {
            blackStartX = regionAnalysis.transitionX
            blackEndX = width
        }

        guard blackEndX > blackStartX + maxRadius * 2 else { return candidates }

        let step = max(3, expectedRadius / 2)
        let innerR = Int(Double(expectedRadius) * 1.2)
        let outerR = Int(Double(expectedRadius) * 2.0)

        for y in stride(from: maxRadius + 5, to: height - maxRadius - 5, by: step) {
            for x in stride(from: max(blackStartX + maxRadius, maxRadius + 5), to: min(blackEndX - maxRadius, width - maxRadius - 5), by: step) {
                let centerIntensity = Double(grayscale[y][x])

                // Sample surrounding ring
                let (bgMean, _) = sampleRing(grayscale: grayscale, x: x, y: y, innerR: innerR, outerR: outerR, width: width, height: height)

                // Light anomaly: center significantly lighter than background
                let contrast = centerIntensity - bgMean

                if contrast >= config.signalBContrastThreshold {
                    // Find blob extent
                    let threshold = Int((centerIntensity + bgMean) / 2)
                    let (centerX, centerY, area) = findBlobExtent(
                        grayscale: grayscale, seedX: x, seedY: y,
                        threshold: threshold, maxRadius: maxRadius,
                        width: width, height: height, detectLight: true
                    )

                    let minArea = Int(Double.pi * Double(minRadius * minRadius) * 0.3)
                    let maxArea = Int(Double.pi * Double(maxRadius * maxRadius) * 2.0)

                    if area >= minArea && area <= maxArea {
                        let radius = sqrt(Double(area) / Double.pi)
                        let rawScore = min(1.0, contrast / 40.0)

                        candidates.append(DetectionCandidate(
                            center: CGPoint(x: Double(centerX) / Double(width), y: Double(centerY) / Double(height)),
                            pixelCenter: CGPoint(x: centerX, y: centerY),
                            estimatedRadius: radius / Double(min(width, height)),
                            pixelRadius: radius,
                            signal: .lightAnomaly,
                            rawScore: rawScore,
                            region: .black
                        ))
                    }
                }
            }
        }

        return candidates
    }

    // MARK: - Signal C: Edge Ring Detection

    private func detectEdgeRings(
        edges: [[UInt8]],
        grayscale: [[UInt8]],
        regionAnalysis: TargetRegionAnalysis,
        expectedRadius: Int,
        width: Int,
        height: Int,
        config: HoleDetectionConfiguration
    ) -> [DetectionCandidate] {
        var candidates: [DetectionCandidate] = []

        let step = max(4, expectedRadius / 2)
        let ringRadius = expectedRadius

        for y in stride(from: expectedRadius + 10, to: height - expectedRadius - 10, by: step) {
            for x in stride(from: expectedRadius + 10, to: width - expectedRadius - 10, by: step) {
                // Sample edge strength in a ring
                let edgeStrength = sampleEdgeRing(edges: edges, x: x, y: y, radius: ringRadius, width: width, height: height)

                if edgeStrength >= config.signalCEdgeThreshold {
                    // Determine region
                    let region: TargetRegion
                    if regionAnalysis.isLeftBlack {
                        region = x < regionAnalysis.transitionX ? .black : .white
                    } else {
                        region = x < regionAnalysis.transitionX ? .white : .black
                    }

                    candidates.append(DetectionCandidate(
                        center: CGPoint(x: Double(x) / Double(width), y: Double(y) / Double(height)),
                        pixelCenter: CGPoint(x: x, y: y),
                        estimatedRadius: Double(expectedRadius) / Double(min(width, height)),
                        pixelRadius: Double(expectedRadius),
                        signal: .edgeRing,
                        rawScore: min(1.0, edgeStrength / 0.3),
                        region: region
                    ))
                }
            }
        }

        return candidates
    }

    // MARK: - Candidate Merging

    private func mergeCandidates(_ candidates: [DetectionCandidate], mergeRadius: Double, width: Int, height: Int) -> [DetectionCandidate] {
        guard !candidates.isEmpty else { return [] }

        var merged: [DetectionCandidate] = []
        var used = Set<UUID>()

        // Sort by raw score descending
        let sorted = candidates.sorted { $0.bestRawScore > $1.bestRawScore }

        for candidate in sorted {
            if used.contains(candidate.id) { continue }
            used.insert(candidate.id)

            var current = candidate

            // Find nearby candidates to merge
            for other in sorted {
                if used.contains(other.id) { continue }

                let distance = hypot(
                    current.pixelCenter.x - other.pixelCenter.x,
                    current.pixelCenter.y - other.pixelCenter.y
                )

                if distance < mergeRadius {
                    current.merge(with: other)
                    used.insert(other.id)
                }
            }

            merged.append(current)
        }

        return merged
    }

    // MARK: - Feature Extraction

    private func extractFeatures(
        candidates: [DetectionCandidate],
        grayscale: [[UInt8]],
        edges: [[UInt8]],
        regionAnalysis: TargetRegionAnalysis,
        expectedRadius: Int,
        width: Int,
        height: Int
    ) -> [DetectionCandidate] {
        return candidates.map { candidate in
            var c = candidate
            let x = Int(c.pixelCenter.x)
            let y = Int(c.pixelCenter.y)
            let radius = Int(c.pixelRadius)

            guard x > radius + 5 && x < width - radius - 5 &&
                  y > radius + 5 && y < height - radius - 5 else {
                c.features = .empty
                return c
            }

            // 1. Intensity features
            let centerMean = sampleDisk(grayscale: grayscale, x: x, y: y, radius: radius, width: width, height: height)
            let (bgMean, bgStd) = sampleRing(grayscale: grayscale, x: x, y: y, innerR: radius + 2, outerR: radius + 10, width: width, height: height)

            let intensityDelta = (centerMean - bgMean) / 255.0
            let contrastRatio = bgStd > 0 ? abs(centerMean - bgMean) / bgStd : 0

            // 2. Edge features
            let (edgeClosure, edgeStrength) = computeEdgeFeatures(edges: edges, x: x, y: y, radius: radius, width: width, height: height)

            // 3. Shape features via blob analysis
            let isLightBlob = candidate.region == .black
            let threshold = Int((centerMean + bgMean) / 2)
            let blob = computeBlob(grayscale: grayscale, x: x, y: y, threshold: threshold, maxRadius: radius * 2, width: width, height: height, detectLight: isLightBlob)

            let compactness = blob.compactness
            let aspectRatio = blob.aspectRatio

            // 4. Size conformance
            let actualRadius = sqrt(Double(blob.area) / .pi)
            let sizeConformance = exp(-pow(actualRadius - Double(expectedRadius), 2) / (2 * pow(Double(expectedRadius) / 3, 2)))

            // 5. Isolation (distance to nearest other candidate)
            var minDistance = Double.infinity
            for other in candidates where other.id != c.id {
                let dist = hypot(c.pixelCenter.x - other.pixelCenter.x, c.pixelCenter.y - other.pixelCenter.y)
                minDistance = min(minDistance, dist)
            }
            let isolation = min(2.0, minDistance / Double(expectedRadius * 2))

            // 6. Ring proximity (distance from center)
            let ringProximity = hypot(c.center.x - 0.5, c.center.y - 0.5) * 2

            c.features = CandidateFeatures(
                intensityDelta: intensityDelta,
                contrastRatio: contrastRatio,
                edgeClosure: edgeClosure,
                edgeStrength: edgeStrength,
                compactness: compactness,
                aspectRatio: max(1.0, aspectRatio),
                sizeConformance: sizeConformance,
                signalCount: c.signalCount,
                regionType: c.region,
                ringProximity: ringProximity,
                isolation: isolation
            )

            return c
        }
    }

    // MARK: - Confidence Scoring

    private func scoreAndClassify(candidates: inout [DetectionCandidate], config: HoleDetectionConfiguration) {
        for i in 0..<candidates.count {
            guard let features = candidates[i].features else {
                candidates[i].confidence = 0
                continue
            }

            // Weights for white region
            var weights: [String: Double] = [
                "intensityDelta": 0.15,
                "contrastRatio": 0.15,
                "edgeClosure": 0.12,
                "edgeStrength": 0.08,
                "compactness": 0.08,
                "sizeConformance": 0.12,
                "signalCount": 0.15,
                "isolation": 0.05,
                "ringProximity": 0.05,
                "regionBonus": 0.05
            ]

            // Adjust for black region
            if features.regionType == .black {
                weights["contrastRatio"] = 0.20
                weights["signalCount"] = 0.20
                weights["compactness"] = 0.05
            }

            var score = 0.0

            // Intensity delta contribution
            let intensityScore: Double
            if features.regionType == .white {
                intensityScore = sigmoid(-features.intensityDelta * 8)  // Dark on white = good
            } else {
                intensityScore = sigmoid(features.intensityDelta * 8)   // Light on black = good
            }
            score += weights["intensityDelta"]! * intensityScore

            // Contrast ratio
            score += weights["contrastRatio"]! * sigmoid(features.contrastRatio - 1.5)

            // Edge features
            score += weights["edgeClosure"]! * features.edgeClosure
            score += weights["edgeStrength"]! * features.edgeStrength

            // Shape features
            score += weights["compactness"]! * features.compactness
            score += weights["sizeConformance"]! * features.sizeConformance

            // Signal count bonus
            let signalScore = min(1.0, Double(features.signalCount) / 3.0)
            score += weights["signalCount"]! * signalScore

            // Isolation
            score += weights["isolation"]! * min(1.0, features.isolation)

            // Ring proximity (slight bonus for being on target)
            let proximityScore = features.ringProximity < 0.8 ? 1.0 : 0.5
            score += weights["ringProximity"]! * proximityScore

            // Region bonus
            score += weights["regionBonus"]!

            // Apply penalties
            if features.aspectRatio > 2.0 {
                score *= 0.75
                candidates[i].needsReview = true
                candidates[i].reviewReason = .possibleOverlap
            } else if features.aspectRatio > 1.5 {
                score *= 0.90
            }

            if features.signalCount == 1 {
                score *= 0.85
                if candidates[i].reviewReason == nil {
                    candidates[i].reviewReason = .singleSignal
                }
            }

            if features.compactness < 0.4 {
                score *= 0.80
                candidates[i].needsReview = true
                if candidates[i].reviewReason == nil {
                    candidates[i].reviewReason = .irregularShape
                }
            }

            if features.isolation < 0.3 {
                score *= 0.85
            }

            candidates[i].confidence = min(1.0, max(0.0, score))

            // Flag low confidence
            if candidates[i].confidence < config.autoAcceptThreshold && candidates[i].confidence >= config.reviewThreshold {
                candidates[i].needsReview = true
                if candidates[i].reviewReason == nil {
                    candidates[i].reviewReason = .lowConfidence
                }
            }
        }
    }

    private func sigmoid(_ x: Double) -> Double {
        return 1.0 / (1.0 + exp(-x))
    }

    // MARK: - Overlap Handling

    private func handleOverlaps(
        candidates: [DetectionCandidate],
        grayscale: [[UInt8]],
        expectedRadius: Int,
        width: Int,
        height: Int
    ) -> [DetectionCandidate] {
        var result: [DetectionCandidate] = []

        for candidate in candidates {
            guard let features = candidate.features else {
                result.append(candidate)
                continue
            }

            // Check for potential overlap
            let isOverlapCandidate = features.aspectRatio > 1.5 ||
                                     features.compactness < 0.6 ||
                                     candidate.pixelRadius > Double(expectedRadius) * 1.5

            if isOverlapCandidate {
                var flagged = candidate
                flagged.needsReview = true
                flagged.reviewReason = .possibleOverlap
                result.append(flagged)
            } else {
                result.append(candidate)
            }
        }

        return result
    }

    // MARK: - Helper Functions

    private func sampleRing(grayscale: [[UInt8]], x: Int, y: Int, innerR: Int, outerR: Int, width: Int, height: Int) -> (mean: Double, std: Double) {
        var values: [Double] = []

        for dy in stride(from: -outerR, through: outerR, by: 2) {
            for dx in stride(from: -outerR, through: outerR, by: 2) {
                let dist = Int(sqrt(Double(dx * dx + dy * dy)))
                if dist >= innerR && dist <= outerR {
                    let px = x + dx, py = y + dy
                    if px >= 0 && px < width && py >= 0 && py < height {
                        values.append(Double(grayscale[py][px]))
                    }
                }
            }
        }

        guard !values.isEmpty else { return (128, 30) }

        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)

        return (mean, max(sqrt(variance), 1.0))
    }

    private func sampleDisk(grayscale: [[UInt8]], x: Int, y: Int, radius: Int, width: Int, height: Int) -> Double {
        var sum = 0, count = 0

        for dy in -radius...radius {
            for dx in -radius...radius {
                if dx * dx + dy * dy <= radius * radius {
                    let px = x + dx, py = y + dy
                    if px >= 0 && px < width && py >= 0 && py < height {
                        sum += Int(grayscale[py][px])
                        count += 1
                    }
                }
            }
        }

        return count > 0 ? Double(sum) / Double(count) : 128
    }

    private func sampleEdgeRing(edges: [[UInt8]], x: Int, y: Int, radius: Int, width: Int, height: Int) -> Double {
        var sum = 0, count = 0
        let numSamples = max(16, radius * 4)

        for i in 0..<numSamples {
            let angle = Double(i) * 2 * .pi / Double(numSamples)
            let px = x + Int(Double(radius) * cos(angle))
            let py = y + Int(Double(radius) * sin(angle))

            if px >= 0 && px < width && py >= 0 && py < height {
                sum += Int(edges[py][px])
                count += 1
            }
        }

        return count > 0 ? Double(sum) / Double(count) / 255.0 : 0
    }

    private func computeEdgeFeatures(edges: [[UInt8]], x: Int, y: Int, radius: Int, width: Int, height: Int) -> (closure: Double, strength: Double) {
        let numSamples = max(16, radius * 4)
        var strongEdgeCount = 0
        var totalStrength = 0

        for i in 0..<numSamples {
            let angle = Double(i) * 2 * .pi / Double(numSamples)
            let px = x + Int(Double(radius) * cos(angle))
            let py = y + Int(Double(radius) * sin(angle))

            if px >= 0 && px < width && py >= 0 && py < height {
                let edgeVal = Int(edges[py][px])
                totalStrength += edgeVal
                if edgeVal > 30 {
                    strongEdgeCount += 1
                }
            }
        }

        let closure = Double(strongEdgeCount) / Double(numSamples)
        let strength = Double(totalStrength) / Double(numSamples) / 255.0

        return (closure, strength)
    }

    private func findBlobExtent(grayscale: [[UInt8]], seedX: Int, seedY: Int, threshold: Int, maxRadius: Int, width: Int, height: Int, detectLight: Bool) -> (x: Int, y: Int, area: Int) {
        var sumX = 0, sumY = 0, count = 0

        let minX = max(0, seedX - maxRadius)
        let maxX = min(width - 1, seedX + maxRadius)
        let minY = max(0, seedY - maxRadius)
        let maxY = min(height - 1, seedY + maxRadius)

        for y in minY...maxY {
            for x in minX...maxX {
                let pixelVal = Int(grayscale[y][x])
                let inBlob = detectLight ? (pixelVal > threshold) : (pixelVal < threshold)

                if inBlob {
                    let dist = (x - seedX) * (x - seedX) + (y - seedY) * (y - seedY)
                    if dist <= maxRadius * maxRadius {
                        sumX += x
                        sumY += y
                        count += 1
                    }
                }
            }
        }

        if count > 0 {
            return (sumX / count, sumY / count, count)
        }
        return (seedX, seedY, 1)
    }

    private func computeBlob(grayscale: [[UInt8]], x: Int, y: Int, threshold: Int, maxRadius: Int, width: Int, height: Int, detectLight: Bool) -> Blob {
        var pixels: [(x: Int, y: Int)] = []

        let minX = max(0, x - maxRadius)
        let maxX = min(width - 1, x + maxRadius)
        let minY = max(0, y - maxRadius)
        let maxY = min(height - 1, y + maxRadius)

        for py in minY...maxY {
            for px in minX...maxX {
                let pixelVal = Int(grayscale[py][px])
                let inBlob = detectLight ? (pixelVal > threshold) : (pixelVal < threshold)

                if inBlob {
                    let dist = (px - x) * (px - x) + (py - y) * (py - y)
                    if dist <= maxRadius * maxRadius {
                        pixels.append((px, py))
                    }
                }
            }
        }

        if pixels.isEmpty {
            pixels = [(x, y)]
        }

        let boundingBox = CGRect(
            x: pixels.map { $0.x }.min() ?? x,
            y: pixels.map { $0.y }.min() ?? y,
            width: (pixels.map { $0.x }.max() ?? x) - (pixels.map { $0.x }.min() ?? x) + 1,
            height: (pixels.map { $0.y }.max() ?? y) - (pixels.map { $0.y }.min() ?? y) + 1
        )

        return Blob(pixels: pixels, boundingBox: boundingBox)
    }

    // MARK: - Warnings

    private func generateWarnings(regionAnalysis: TargetRegionAnalysis) -> [String] {
        var warnings: [String] = []

        if regionAnalysis.sharpness < 100 {
            warnings.append("Image may be blurry - hold camera steady")
        }
        if regionAnalysis.overallContrast < 0.4 {
            warnings.append("Low contrast - improve lighting")
        }
        if !regionAnalysis.isValid {
            warnings.append("Could not detect target regions clearly")
        }

        return warnings
    }

    // MARK: - Diagnostic Logging

    private func logDiagnostics(_ diagnostics: DetectionDiagnostics, regionAnalysis: TargetRegionAnalysis) {
        #if DEBUG
        print("""

        🎯 HOLE DETECTION v\(diagnostics.algorithmVersion)
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        📐 Image: \(Int(diagnostics.imageSize.width))×\(Int(diagnostics.imageSize.height))px
        🎨 Regions: Black μ=\(Int(regionAnalysis.blackRegionMean)), White μ=\(Int(regionAnalysis.whiteRegionMean))
           Transition@\(Int(regionAnalysis.transitionXNormalized * 100))% | Contrast=\(String(format: "%.2f", regionAnalysis.overallContrast)) | Sharp=\(Int(regionAnalysis.sharpness))
        📏 Expected hole: r=\(diagnostics.expectedRadiusPx)px (min=\(diagnostics.minRadiusPx), max=\(diagnostics.maxRadiusPx))

        📡 SIGNAL GENERATION
           A (dark/white):  \(diagnostics.signalACandidates) candidates
           B (light/black): \(diagnostics.signalBCandidates) candidates
           C (edge ring):   \(diagnostics.signalCCandidates) candidates
           ↳ Merged: \(diagnostics.mergedCandidates) candidates

        🔍 CANDIDATE ANALYSIS
        """)

        for cand in diagnostics.allCandidates.prefix(10) {
            let regionStr = cand.region == .white ? "WHITE" : "BLACK"
            let signalStr = cand.signals.map { $0.rawValue.prefix(4) }.joined(separator: ",")
            let featStr: String
            if let f = cand.features {
                featStr = "Δ=\(String(format: "%+.2f", f.intensityDelta)) C=\(String(format: "%.1f", f.contrastRatio)) E=\(String(format: "%.2f", f.edgeClosure)) S=\(f.signalCount)"
            } else {
                featStr = "no features"
            }
            let icon = cand.classification == "accept" ? "✓" : (cand.classification == "flag" ? "⚠" : "✗")
            print("   \(icon) (\(String(format: "%.2f", cand.position.x)),\(String(format: "%.2f", cand.position.y))) \(regionStr) | \(featStr) → \(String(format: "%.2f", cand.confidence)) \(cand.classification.uppercased())")
        }

        if diagnostics.allCandidates.count > 10 {
            print("   ... and \(diagnostics.allCandidates.count - 10) more")
        }

        let accepted = diagnostics.allCandidates.filter { $0.classification == "accept" }.count
        let flagged = diagnostics.allCandidates.filter { $0.classification == "flag" }.count
        let rejected = diagnostics.allCandidates.filter { $0.classification == "reject" }.count

        print("""

        📊 RESULTS
           ✓ Auto-accepted: \(accepted)
           ⚠ Flagged: \(flagged)
           ✗ Rejected: \(rejected)
           ⏱ Time: \(diagnostics.totalMs)ms (region:\(diagnostics.regionAnalysisMs) signal:\(diagnostics.signalGenerationMs) feat:\(diagnostics.featureExtractionMs) score:\(diagnostics.scoringMs))
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        """)
        #endif
    }

    // MARK: - Errors

    enum DetectionError: Error {
        case invalidImage
        case processingFailed
    }
}

// MARK: - Image Processor

enum ImageProcessor {

    static func toGrayscale(cgImage: CGImage) -> (grayscale: [[UInt8]], width: Int, height: Int)? {
        let width = cgImage.width
        let height = cgImage.height

        // Limit size for performance
        let maxDim = 1000
        let scale = min(1.0, Double(maxDim) / Double(max(width, height)))
        let scaledW = max(100, Int(Double(width) * scale))
        let scaledH = max(100, Int(Double(height) * scale))

        guard let colorSpace = CGColorSpace(name: CGColorSpace.linearGray) else { return nil }

        var pixelData = [UInt8](repeating: 0, count: scaledW * scaledH)

        guard let context = CGContext(
            data: &pixelData,
            width: scaledW,
            height: scaledH,
            bitsPerComponent: 8,
            bytesPerRow: scaledW,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: scaledW, height: scaledH))

        var grayscale = [[UInt8]](repeating: [UInt8](repeating: 0, count: scaledW), count: scaledH)
        for y in 0..<scaledH {
            for x in 0..<scaledW {
                grayscale[y][x] = pixelData[y * scaledW + x]
            }
        }

        return (grayscale, scaledW, scaledH)
    }

    static func sobelMagnitude(grayscale: [[UInt8]], width: Int, height: Int) -> [[UInt8]] {
        var edges = [[UInt8]](repeating: [UInt8](repeating: 0, count: width), count: height)

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let gx = -Int(grayscale[y-1][x-1]) - 2*Int(grayscale[y][x-1]) - Int(grayscale[y+1][x-1])
                       + Int(grayscale[y-1][x+1]) + 2*Int(grayscale[y][x+1]) + Int(grayscale[y+1][x+1])

                let gy = -Int(grayscale[y-1][x-1]) - 2*Int(grayscale[y-1][x]) - Int(grayscale[y-1][x+1])
                       + Int(grayscale[y+1][x-1]) + 2*Int(grayscale[y+1][x]) + Int(grayscale[y+1][x+1])

                let mag = sqrt(Double(gx * gx + gy * gy))
                edges[y][x] = UInt8(min(255, Int(mag / 4)))
            }
        }

        return edges
    }
}

// MARK: - DetectedHole Extension

extension DetectedHole {
    init(position: CGPoint, score: Int, confidence: Double, radius: Double, needsReview: Bool = false, reviewReason: String? = nil) {
        self.id = UUID()
        self.position = position
        self.score = score
        self.confidence = confidence
        self.radius = radius
        self.needsReview = needsReview
        self.reviewReason = reviewReason
    }
}
