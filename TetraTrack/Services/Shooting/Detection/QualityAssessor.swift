//
//  QualityAssessor.swift
//  TetraTrack
//
//  Pre-detection image quality assessment for bullet hole detection.
//  Evaluates sharpness, contrast, exposure, and region visibility.
//

import Foundation
import CoreGraphics
import Accelerate

/// Assesses image quality before hole detection
final class QualityAssessor {

    // MARK: - Public Interface

    /// Assess image quality and return metrics
    static func assess(grayscale: [[UInt8]], width: Int, height: Int) -> HoleDetectionQualityAssessment {
        // Find black/white transition
        let transitionX = findTransitionX(grayscale: grayscale, width: width, height: height)
        let normalizedTransition = Double(transitionX) / Double(width)

        // Split into regions
        let whiteRegion = extractRegion(grayscale: grayscale, startX: transitionX, endX: width)
        let blackRegion = extractRegion(grayscale: grayscale, startX: 0, endX: transitionX)

        // Compute metrics
        let sharpness = computeSharpness(grayscale: grayscale, width: width, height: height)
        let contrast = computeContrast(grayscale: grayscale)
        let whiteExposure = computeMean(region: whiteRegion)
        let blackExposure = computeMean(region: blackRegion)
        let blackVisibility = computeVariance(region: blackRegion)
        let noiseLevel = estimateNoise(grayscale: grayscale, width: width, height: height)

        return HoleDetectionQualityAssessment(
            sharpness: sharpness,
            contrast: contrast,
            whiteExposure: whiteExposure,
            blackExposure: blackExposure,
            blackVisibility: blackVisibility,
            noiseLevel: noiseLevel,
            transitionX: normalizedTransition
        )
    }

    // MARK: - Region Detection

    /// Find the X coordinate where black transitions to white (or vice versa)
    static func findTransitionX(grayscale: [[UInt8]], width: Int, height: Int) -> Int {
        // Compute column-wise mean intensity
        var columnMeans = [Double](repeating: 0, count: width)

        for x in 0..<width {
            var sum = 0
            for y in 0..<height {
                sum += Int(grayscale[y][x])
            }
            columnMeans[x] = Double(sum) / Double(height)
        }

        // Find steepest gradient (largest absolute difference)
        var maxGradient = 0.0
        var transitionX = width / 2

        for x in 1..<(width - 1) {
            // Use a wider window for robustness
            let windowSize = min(10, x, width - x - 1)
            let leftMean = columnMeans[(x - windowSize)..<x].reduce(0, +) / Double(windowSize)
            let rightMean = columnMeans[x..<(x + windowSize)].reduce(0, +) / Double(windowSize)
            let gradient = abs(rightMean - leftMean)

            if gradient > maxGradient {
                maxGradient = gradient
                transitionX = x
            }
        }

        // If gradient is small, assume uniform target (use center)
        if maxGradient < 30 {
            transitionX = width / 2
        }

        return transitionX
    }

    /// Determine which side is black based on intensity
    static func isLeftSideBlack(grayscale: [[UInt8]], width: Int, height: Int, transitionX: Int) -> Bool {
        let leftMean = computeMean(region: extractRegion(grayscale: grayscale, startX: 0, endX: transitionX))
        let rightMean = computeMean(region: extractRegion(grayscale: grayscale, startX: transitionX, endX: width))
        return leftMean < rightMean
    }

    // MARK: - Sharpness

    /// Compute sharpness using Laplacian variance
    static func computeSharpness(grayscale: [[UInt8]], width: Int, height: Int) -> Double {
        // Laplacian kernel: [0, 1, 0; 1, -4, 1; 0, 1, 0]
        var laplacianSum: Double = 0
        var laplacianSqSum: Double = 0
        var count = 0

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let center = Int(grayscale[y][x])
                let top = Int(grayscale[y - 1][x])
                let bottom = Int(grayscale[y + 1][x])
                let left = Int(grayscale[y][x - 1])
                let right = Int(grayscale[y][x + 1])

                let laplacian = Double(top + bottom + left + right - 4 * center)
                laplacianSum += laplacian
                laplacianSqSum += laplacian * laplacian
                count += 1
            }
        }

        guard count > 0 else { return 0 }

        let mean = laplacianSum / Double(count)
        let variance = laplacianSqSum / Double(count) - mean * mean

        return variance
    }

    // MARK: - Contrast

    /// Compute contrast as (P95 - P5) / 255
    static func computeContrast(grayscale: [[UInt8]]) -> Double {
        let flat = grayscale.flatMap { $0 }.sorted()
        guard flat.count > 20 else { return 0 }

        let p5Index = flat.count / 20
        let p95Index = flat.count * 19 / 20

        let p5 = flat[p5Index]
        let p95 = flat[p95Index]

        return Double(p95 - p5) / 255.0
    }

    // MARK: - Noise Estimation

    /// Estimate noise level using median absolute deviation of Laplacian
    static func estimateNoise(grayscale: [[UInt8]], width: Int, height: Int) -> Double {
        // Use a robust noise estimator based on Laplacian
        var laplacianValues: [Double] = []

        // Sample every 4th pixel for efficiency
        for y in stride(from: 2, to: height - 2, by: 4) {
            for x in stride(from: 2, to: width - 2, by: 4) {
                let center = Double(grayscale[y][x])
                let neighbors = [
                    Double(grayscale[y - 1][x]),
                    Double(grayscale[y + 1][x]),
                    Double(grayscale[y][x - 1]),
                    Double(grayscale[y][x + 1])
                ]
                let laplacian = abs(neighbors.reduce(0, +) - 4 * center)
                laplacianValues.append(laplacian)
            }
        }

        guard !laplacianValues.isEmpty else { return 0 }

        // Median absolute deviation
        laplacianValues.sort()
        let median = laplacianValues[laplacianValues.count / 2]

        var absoluteDeviations = laplacianValues.map { abs($0 - median) }
        absoluteDeviations.sort()
        let mad = absoluteDeviations[absoluteDeviations.count / 2]

        // Noise estimate (scaled for Laplacian)
        return mad / 1.4826
    }

    // MARK: - Helpers

    /// Extract a vertical strip of the image
    private static func extractRegion(grayscale: [[UInt8]], startX: Int, endX: Int) -> [[UInt8]] {
        guard startX < endX else { return [] }
        return grayscale.map { row in
            Array(row[max(0, startX)..<min(row.count, endX)])
        }
    }

    /// Compute mean intensity of a region
    private static func computeMean(region: [[UInt8]]) -> Double {
        let flat = region.flatMap { $0 }
        guard !flat.isEmpty else { return 0 }
        return Double(flat.reduce(0) { $0 + Int($1) }) / Double(flat.count)
    }

    /// Compute variance of a region
    private static func computeVariance(region: [[UInt8]]) -> Double {
        let flat = region.flatMap { $0 }.map { Double($0) }
        guard flat.count > 1 else { return 0 }

        let mean = flat.reduce(0, +) / Double(flat.count)
        let variance = flat.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(flat.count)

        return variance
    }
}

// MARK: - Image Preprocessing

/// Image preprocessing utilities
final class ImagePreprocessor {

    /// Convert CGImage to grayscale 2D array using CGContext for reliable conversion
    static func toGrayscale(cgImage: CGImage) -> (grayscale: [[UInt8]], width: Int, height: Int)? {
        let width = cgImage.width
        let height = cgImage.height

        // Limit size to prevent excessive processing time
        let maxDimension = 1200
        let scale = min(1.0, Double(maxDimension) / Double(max(width, height)))
        let scaledWidth = Int(Double(width) * scale)
        let scaledHeight = Int(Double(height) * scale)

        // Create grayscale context
        guard let colorSpace = CGColorSpace(name: CGColorSpace.linearGray) else {
            return nil
        }

        var pixelData = [UInt8](repeating: 0, count: scaledWidth * scaledHeight)

        guard let context = CGContext(
            data: &pixelData,
            width: scaledWidth,
            height: scaledHeight,
            bitsPerComponent: 8,
            bytesPerRow: scaledWidth,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        // Draw the image into the grayscale context
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))

        // Convert flat array to 2D array
        var grayscale = [[UInt8]](repeating: [UInt8](repeating: 0, count: scaledWidth), count: scaledHeight)

        for y in 0..<scaledHeight {
            for x in 0..<scaledWidth {
                grayscale[y][x] = pixelData[y * scaledWidth + x]
            }
        }

        return (grayscale, scaledWidth, scaledHeight)
    }

    /// Apply CLAHE (Contrast Limited Adaptive Histogram Equalization)
    static func applyCLAHE(grayscale: inout [[UInt8]], width: Int, height: Int, clipLimit: Double = 2.0, tileSize: Int = 32) {
        let tilesX = max(1, width / tileSize)
        let tilesY = max(1, height / tileSize)

        // Process each tile
        for ty in 0..<tilesY {
            for tx in 0..<tilesX {
                let startX = tx * tileSize
                let startY = ty * tileSize
                let endX = min(startX + tileSize, width)
                let endY = min(startY + tileSize, height)

                // Build histogram for tile
                var histogram = [Int](repeating: 0, count: 256)
                for y in startY..<endY {
                    for x in startX..<endX {
                        histogram[Int(grayscale[y][x])] += 1
                    }
                }

                // Clip histogram
                let tilePixels = (endX - startX) * (endY - startY)
                let clipThreshold = Int(clipLimit * Double(tilePixels) / 256.0)
                var clipped = 0

                for i in 0..<256 {
                    if histogram[i] > clipThreshold {
                        clipped += histogram[i] - clipThreshold
                        histogram[i] = clipThreshold
                    }
                }

                // Redistribute clipped pixels
                let redistribute = clipped / 256
                for i in 0..<256 {
                    histogram[i] += redistribute
                }

                // Build CDF
                var cdf = [Int](repeating: 0, count: 256)
                cdf[0] = histogram[0]
                for i in 1..<256 {
                    cdf[i] = cdf[i - 1] + histogram[i]
                }

                // Normalize CDF to create LUT
                let cdfMin = cdf.first { $0 > 0 } ?? 0
                var lut = [UInt8](repeating: 0, count: 256)
                let denominator = max(1, tilePixels - cdfMin)

                for i in 0..<256 {
                    lut[i] = UInt8(min(255, max(0, (cdf[i] - cdfMin) * 255 / denominator)))
                }

                // Apply LUT to tile
                for y in startY..<endY {
                    for x in startX..<endX {
                        grayscale[y][x] = lut[Int(grayscale[y][x])]
                    }
                }
            }
        }
    }

    /// Compute Sobel edge magnitude
    static func sobelMagnitude(grayscale: [[UInt8]], width: Int, height: Int) -> [[UInt8]] {
        var edges = [[UInt8]](repeating: [UInt8](repeating: 0, count: width), count: height)

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                // Sobel X kernel
                let gx = -Int(grayscale[y - 1][x - 1]) - 2 * Int(grayscale[y][x - 1]) - Int(grayscale[y + 1][x - 1])
                       + Int(grayscale[y - 1][x + 1]) + 2 * Int(grayscale[y][x + 1]) + Int(grayscale[y + 1][x + 1])

                // Sobel Y kernel
                let gy = -Int(grayscale[y - 1][x - 1]) - 2 * Int(grayscale[y - 1][x]) - Int(grayscale[y - 1][x + 1])
                       + Int(grayscale[y + 1][x - 1]) + 2 * Int(grayscale[y + 1][x]) + Int(grayscale[y + 1][x + 1])

                let magnitude = sqrt(Double(gx * gx + gy * gy))
                edges[y][x] = UInt8(min(255, Int(magnitude / 4)))  // Scale down
            }
        }

        return edges
    }

    /// Morphological opening (erosion followed by dilation) for background estimation
    static func morphologicalOpen(grayscale: [[UInt8]], width: Int, height: Int, radius: Int) -> [[UInt8]] {
        // Erosion
        var eroded = [[UInt8]](repeating: [UInt8](repeating: 0, count: width), count: height)

        for y in radius..<(height - radius) {
            for x in radius..<(width - radius) {
                var minVal: UInt8 = 255
                for dy in -radius...radius {
                    for dx in -radius...radius {
                        if dx * dx + dy * dy <= radius * radius {
                            minVal = min(minVal, grayscale[y + dy][x + dx])
                        }
                    }
                }
                eroded[y][x] = minVal
            }
        }

        // Dilation
        var opened = [[UInt8]](repeating: [UInt8](repeating: 0, count: width), count: height)

        for y in radius..<(height - radius) {
            for x in radius..<(width - radius) {
                var maxVal: UInt8 = 0
                for dy in -radius...radius {
                    for dx in -radius...radius {
                        if dx * dx + dy * dy <= radius * radius {
                            maxVal = max(maxVal, eroded[y + dy][x + dx])
                        }
                    }
                }
                opened[y][x] = maxVal
            }
        }

        return opened
    }
}
