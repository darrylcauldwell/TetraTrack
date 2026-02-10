//
//  ImageQualityAssessor.swift
//  TetraTrack
//
//  Pre-detection image quality assessment for shooting target analysis.
//  Provides quality gate before attempting hole detection.
//

import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Accelerate

// MARK: - Image Quality Assessment Result

struct ImageQualityAssessment {
    /// Sharpness score (0-1, higher is sharper)
    let sharpness: Double

    /// Contrast score (0-1, higher is more contrast)
    let contrast: Double

    /// Exposure assessment
    let exposure: ExposureLevel

    /// Overall brightness (0-1)
    let brightness: Double

    /// Noise level estimate (0-1, lower is less noise)
    let noiseLevel: Double

    enum ExposureLevel: String {
        case underexposed
        case good
        case overexposed

        var description: String {
            switch self {
            case .underexposed: return "Too dark"
            case .good: return "Good"
            case .overexposed: return "Too bright"
            }
        }
    }

    /// Whether the image quality is acceptable for hole detection
    var isAcceptableForDetection: Bool {
        sharpness > 0.3 && contrast > 0.2 && exposure == .good
    }

    /// Overall quality score (0-1)
    var overallScore: Double {
        let exposureScore: Double = exposure == .good ? 1.0 : 0.3
        let noiseScore = 1.0 - noiseLevel

        return (sharpness * 0.35 +
                contrast * 0.25 +
                exposureScore * 0.25 +
                noiseScore * 0.15)
    }

    /// User guidance message if quality is poor
    var userGuidance: String? {
        var issues: [String] = []

        if sharpness < 0.3 {
            issues.append("Image is blurry - hold camera steadier or move closer")
        }
        if contrast < 0.2 {
            issues.append("Low contrast - ensure good lighting on target")
        }
        if exposure == .underexposed {
            issues.append("Image is too dark - add more light")
        }
        if exposure == .overexposed {
            issues.append("Image is too bright - reduce direct light or shadows")
        }
        if noiseLevel > 0.5 {
            issues.append("High noise - try better lighting conditions")
        }

        return issues.isEmpty ? nil : issues.joined(separator: "\n")
    }

    /// Quality level for display
    var qualityLevel: QualityLevel {
        let score = overallScore
        if score >= 0.7 { return .good }
        if score >= 0.5 { return .acceptable }
        return .poor
    }

    enum QualityLevel {
        case good
        case acceptable
        case poor

        var description: String {
            switch self {
            case .good: return "Good quality"
            case .acceptable: return "Acceptable"
            case .poor: return "Poor quality"
            }
        }

        var color: String {
            switch self {
            case .good: return "green"
            case .acceptable: return "yellow"
            case .poor: return "red"
            }
        }
    }
}

// MARK: - Image Quality Assessor

actor ImageQualityAssessor {

    private let context = CIContext()

    /// Assess image quality for target detection
    func assess(image: UIImage) async -> ImageQualityAssessment {
        guard let cgImage = image.cgImage else {
            return defaultAssessment()
        }

        // Run assessments in parallel where possible
        async let sharpnessResult = calculateSharpness(cgImage)
        async let contrastResult = calculateContrast(cgImage)
        async let brightnessResult = calculateBrightness(cgImage)
        async let noiseResult = estimateNoise(cgImage)

        let sharpness = await sharpnessResult
        let contrast = await contrastResult
        let brightness = await brightnessResult
        let noiseLevel = await noiseResult

        let exposure = classifyExposure(brightness: brightness)

        return ImageQualityAssessment(
            sharpness: sharpness,
            contrast: contrast,
            exposure: exposure,
            brightness: brightness,
            noiseLevel: noiseLevel
        )
    }

    /// Calculate image sharpness using Laplacian variance
    private func calculateSharpness(_ image: CGImage) -> Double {
        let width = image.width
        let height = image.height

        guard width > 0 && height > 0 else { return 0.5 }

        // Convert to grayscale
        guard let grayscale = convertToGrayscale(image) else { return 0.5 }

        // Apply Laplacian kernel for edge detection
        let laplacianVariance = calculateLaplacianVariance(grayscale, width: width, height: height)

        // Normalize to 0-1 range (empirically determined thresholds)
        let normalized = min(1.0, laplacianVariance / 500.0)
        return normalized
    }

    /// Calculate image contrast using standard deviation of luminance
    private func calculateContrast(_ image: CGImage) -> Double {
        guard let grayscale = convertToGrayscale(image) else { return 0.5 }

        let width = image.width
        let height = image.height
        let pixelCount = width * height

        guard pixelCount > 0 else { return 0.5 }

        // Calculate mean
        var sum: Double = 0
        for i in 0..<pixelCount {
            sum += Double(grayscale[i])
        }
        let mean = sum / Double(pixelCount)

        // Calculate variance
        var varianceSum: Double = 0
        for i in 0..<pixelCount {
            let diff = Double(grayscale[i]) - mean
            varianceSum += diff * diff
        }
        let variance = varianceSum / Double(pixelCount)
        let stdDev = sqrt(variance)

        // Normalize to 0-1 (max std dev for 8-bit is ~128)
        return min(1.0, stdDev / 64.0)
    }

    /// Calculate average brightness
    private func calculateBrightness(_ image: CGImage) -> Double {
        guard let grayscale = convertToGrayscale(image) else { return 0.5 }

        let pixelCount = image.width * image.height
        guard pixelCount > 0 else { return 0.5 }

        var sum: Double = 0
        for i in 0..<pixelCount {
            sum += Double(grayscale[i])
        }

        return sum / Double(pixelCount) / 255.0
    }

    /// Estimate noise level using local variance method
    private func estimateNoise(_ image: CGImage) -> Double {
        guard let grayscale = convertToGrayscale(image) else { return 0.3 }

        let width = image.width
        let height = image.height

        guard width > 10 && height > 10 else { return 0.3 }

        // Sample local variances in flat regions
        var localVariances: [Double] = []
        let sampleSize = 5
        let step = max(1, min(width, height) / 20)

        for y in stride(from: sampleSize, to: height - sampleSize, by: step) {
            for x in stride(from: sampleSize, to: width - sampleSize, by: step) {
                var localSum: Double = 0
                var localSumSq: Double = 0
                var count = 0

                for dy in -sampleSize/2...sampleSize/2 {
                    for dx in -sampleSize/2...sampleSize/2 {
                        let idx = (y + dy) * width + (x + dx)
                        let value = Double(grayscale[idx])
                        localSum += value
                        localSumSq += value * value
                        count += 1
                    }
                }

                let mean = localSum / Double(count)
                let variance = localSumSq / Double(count) - mean * mean
                localVariances.append(variance)
            }
        }

        // Use median of local variances as noise estimate
        guard !localVariances.isEmpty else { return 0.3 }

        localVariances.sort()
        let medianVariance = localVariances[localVariances.count / 2]

        // Normalize (empirically determined)
        return min(1.0, sqrt(medianVariance) / 20.0)
    }

    /// Classify exposure level based on brightness
    private func classifyExposure(brightness: Double) -> ImageQualityAssessment.ExposureLevel {
        if brightness < 0.25 { return .underexposed }
        if brightness > 0.75 { return .overexposed }
        return .good
    }

    /// Convert CGImage to grayscale pixel array
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

    /// Calculate Laplacian variance for sharpness estimation
    private func calculateLaplacianVariance(_ grayscale: [UInt8], width: Int, height: Int) -> Double {
        guard width > 2 && height > 2 else { return 0 }

        // Laplacian kernel: [0, 1, 0; 1, -4, 1; 0, 1, 0]
        var laplacianValues: [Double] = []

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let idx = y * width + x
                let center = Double(grayscale[idx])
                let top = Double(grayscale[(y - 1) * width + x])
                let bottom = Double(grayscale[(y + 1) * width + x])
                let left = Double(grayscale[y * width + (x - 1)])
                let right = Double(grayscale[y * width + (x + 1)])

                let laplacian = top + bottom + left + right - 4 * center
                laplacianValues.append(laplacian)
            }
        }

        guard !laplacianValues.isEmpty else { return 0 }

        // Calculate variance of Laplacian
        let mean = laplacianValues.reduce(0, +) / Double(laplacianValues.count)
        let variance = laplacianValues.map { pow($0 - mean, 2) }.reduce(0, +) / Double(laplacianValues.count)

        return variance
    }

    private func defaultAssessment() -> ImageQualityAssessment {
        ImageQualityAssessment(
            sharpness: 0.5,
            contrast: 0.5,
            exposure: .good,
            brightness: 0.5,
            noiseLevel: 0.3
        )
    }
}

// MARK: - Local Background Estimation

/// Estimates local background around a point for hole detection
struct LocalBackgroundEstimator {

    /// Estimate local background intensity around a candidate hole position
    static func estimate(
        around position: CGPoint,
        in grayscale: [UInt8],
        imageWidth: Int,
        imageHeight: Int,
        innerRadius: Int,
        outerRadius: Int
    ) -> LocalBackground {
        var samples: [UInt8] = []

        let centerX = Int(position.x)
        let centerY = Int(position.y)

        // Sample pixels in annulus around position
        for dy in -outerRadius...outerRadius {
            for dx in -outerRadius...outerRadius {
                let distance = sqrt(Double(dx * dx + dy * dy))

                // Only sample in annulus (outside hole, inside window)
                guard distance >= Double(innerRadius) && distance <= Double(outerRadius) else {
                    continue
                }

                let x = centerX + dx
                let y = centerY + dy

                // Bounds check
                guard x >= 0 && x < imageWidth && y >= 0 && y < imageHeight else {
                    continue
                }

                let idx = y * imageWidth + x
                samples.append(grayscale[idx])
            }
        }

        guard !samples.isEmpty else {
            return LocalBackground(meanIntensity: 128, stdDev: 30)
        }

        // Calculate statistics
        let sum = samples.reduce(0) { $0 + Int($1) }
        let mean = Double(sum) / Double(samples.count)

        let varianceSum = samples.reduce(0.0) { $0 + pow(Double($1) - mean, 2) }
        let variance = varianceSum / Double(samples.count)
        let stdDev = sqrt(variance)

        return LocalBackground(meanIntensity: mean, stdDev: stdDev)
    }
}

/// Local background statistics for hole detection
struct LocalBackground {
    let meanIntensity: Double
    let stdDev: Double

    /// Check if a candidate intensity is significantly darker than background
    func isDarkEnough(_ candidateIntensity: Double, sigmaThreshold: Double = 2.0) -> Bool {
        let threshold = meanIntensity - stdDev * sigmaThreshold
        return candidateIntensity < threshold
    }

    /// Calculate z-score for a candidate intensity
    func zScore(for intensity: Double) -> Double {
        guard stdDev > 0 else { return 0 }
        return (meanIntensity - intensity) / stdDev
    }
}
