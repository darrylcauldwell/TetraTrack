//
//  DarkAreaQualityAssessor.swift
//  TrackRide
//
//  Enhanced quality assessment for targets with dark areas.
//  Analyzes both light and dark regions for hole visibility.
//

import Foundation
import CoreGraphics
import UIKit

// MARK: - Enhanced Quality Assessment

/// Extended quality assessment including dark area visibility
struct EnhancedQualityAssessment {
    /// Base quality metrics
    let base: ImageQualityAssessment

    /// Dark area specific metrics
    let darkAreaMetrics: DarkAreaMetrics?

    /// Flash detection result
    let flashDetected: Bool

    /// Regional analysis
    let regionalAnalysis: RegionalAnalysis

    /// Overall suitability for detection
    var suitabilityScore: Double {
        var score = base.overallScore

        // Boost score if flash is used
        if flashDetected {
            score = min(1.0, score * 1.1)
        }

        // Adjust based on dark area visibility
        if let dark = darkAreaMetrics {
            if dark.holeVisibilityScore < 0.3 {
                score *= 0.7  // Significantly reduce if holes not visible in dark areas
            } else if dark.holeVisibilityScore > 0.6 {
                score *= 1.1  // Boost if dark areas are well lit
            }
        }

        return min(1.0, score)
    }

    /// Detailed user guidance
    var detailedGuidance: [GuidanceItem] {
        var items: [GuidanceItem] = []

        // Base quality issues
        if base.sharpness < 0.3 {
            items.append(GuidanceItem(
                severity: .high,
                message: "Image is blurry",
                suggestion: "Hold camera steadier or use a tripod"
            ))
        }

        if base.contrast < 0.2 {
            items.append(GuidanceItem(
                severity: .medium,
                message: "Low overall contrast",
                suggestion: "Improve lighting conditions"
            ))
        }

        if base.exposure == .underexposed {
            items.append(GuidanceItem(
                severity: .high,
                message: "Image is underexposed",
                suggestion: "Add more light or use flash"
            ))
        }

        // Dark area specific issues
        if let dark = darkAreaMetrics {
            if !flashDetected && dark.holeVisibilityScore < 0.5 {
                items.append(GuidanceItem(
                    severity: .high,
                    message: "Holes may not be visible on dark target areas",
                    suggestion: "Enable flash for better visibility on dark surfaces"
                ))
            }

            if dark.contrastWithHoles < 0.3 {
                items.append(GuidanceItem(
                    severity: .medium,
                    message: "Low contrast between holes and dark background",
                    suggestion: "Try angling a light to illuminate inside the holes"
                ))
            }
        }

        // Regional imbalance
        if regionalAnalysis.brightnessVariance > 0.3 {
            items.append(GuidanceItem(
                severity: .low,
                message: "Uneven lighting across the target",
                suggestion: "Position light source more centrally"
            ))
        }

        return items
    }

    struct GuidanceItem {
        let severity: Severity
        let message: String
        let suggestion: String

        enum Severity {
            case high, medium, low
        }
    }
}

// MARK: - Dark Area Metrics

/// Quality metrics specific to dark target regions
struct DarkAreaMetrics {
    /// Average brightness of dark regions (0-1)
    let darkRegionBrightness: Double

    /// Contrast within dark regions (0-1)
    let darkRegionContrast: Double

    /// Estimated visibility of holes in dark areas (0-1)
    let holeVisibilityScore: Double

    /// Contrast between expected hole appearance and background
    let contrastWithHoles: Double

    /// Percentage of image that is dark (0-1)
    let darkAreaPercentage: Double

    /// Whether dark areas appear to have sufficient detail
    var hasSufficientDetail: Bool {
        darkRegionContrast > 0.15 && holeVisibilityScore > 0.4
    }
}

// MARK: - Regional Analysis

/// Analysis of different image regions
struct RegionalAnalysis {
    /// Brightness values for quadrants [topLeft, topRight, bottomLeft, bottomRight]
    let quadrantBrightness: [Double]

    /// Variance in brightness across regions
    let brightnessVariance: Double

    /// Estimated light and dark halves
    let lightHalfBrightness: Double
    let darkHalfBrightness: Double

    /// Ratio of light to dark brightness
    var lightDarkRatio: Double {
        guard darkHalfBrightness > 0 else { return 1.0 }
        return lightHalfBrightness / darkHalfBrightness
    }
}

// MARK: - Dark Area Quality Assessor

/// Assesses image quality with special attention to dark target areas
actor DarkAreaQualityAssessor {

    private let baseAssessor = ImageQualityAssessor()

    /// Perform enhanced quality assessment
    func assess(image: UIImage, targetType: ShootingTargetGeometryType = .tetrathlon) async -> EnhancedQualityAssessment {
        guard let cgImage = image.cgImage else {
            return defaultAssessment()
        }

        // Get base assessment
        let base = await baseAssessor.assess(image: image)

        // Convert to grayscale for regional analysis
        guard let grayscale = convertToGrayscale(cgImage) else {
            return EnhancedQualityAssessment(
                base: base,
                darkAreaMetrics: nil,
                flashDetected: false,
                regionalAnalysis: defaultRegionalAnalysis()
            )
        }

        let width = cgImage.width
        let height = cgImage.height

        // Analyze regions
        let regional = analyzeRegions(grayscale: grayscale, width: width, height: height)

        // Detect dark areas and assess
        let darkMetrics = analyzeDarkAreas(
            grayscale: grayscale,
            width: width,
            height: height,
            regional: regional
        )

        // Detect flash usage
        let flashDetected = detectFlash(grayscale: grayscale, width: width, height: height)

        return EnhancedQualityAssessment(
            base: base,
            darkAreaMetrics: darkMetrics,
            flashDetected: flashDetected,
            regionalAnalysis: regional
        )
    }

    /// Assess suitability for a specific target type (tetrathlon has half-black)
    func assessForTetrathlonTarget(image: UIImage) async -> EnhancedQualityAssessment {
        await assess(image: image, targetType: .tetrathlon)
    }

    // MARK: - Regional Analysis

    private func analyzeRegions(grayscale: [UInt8], width: Int, height: Int) -> RegionalAnalysis {
        let midX = width / 2
        let midY = height / 2

        // Calculate quadrant averages
        let topLeft = averageBrightness(grayscale, width: width, x: 0..<midX, y: 0..<midY)
        let topRight = averageBrightness(grayscale, width: width, x: midX..<width, y: 0..<midY)
        let bottomLeft = averageBrightness(grayscale, width: width, x: 0..<midX, y: midY..<height)
        let bottomRight = averageBrightness(grayscale, width: width, x: midX..<width, y: midY..<height)

        let quadrants = [topLeft, topRight, bottomLeft, bottomRight]
        let mean = quadrants.reduce(0, +) / 4.0
        let variance = quadrants.map { pow($0 - mean, 2) }.reduce(0, +) / 4.0

        // For tetrathlon, assume left half might be lighter
        let leftAvg = (topLeft + bottomLeft) / 2.0
        let rightAvg = (topRight + bottomRight) / 2.0

        let lightHalf = max(leftAvg, rightAvg)
        let darkHalf = min(leftAvg, rightAvg)

        return RegionalAnalysis(
            quadrantBrightness: quadrants,
            brightnessVariance: sqrt(variance) / 255.0,
            lightHalfBrightness: lightHalf / 255.0,
            darkHalfBrightness: darkHalf / 255.0
        )
    }

    private func averageBrightness(_ grayscale: [UInt8], width: Int, x: Range<Int>, y: Range<Int>) -> Double {
        var sum: Double = 0
        var count = 0

        for row in y {
            for col in x {
                let idx = row * width + col
                sum += Double(grayscale[idx])
                count += 1
            }
        }

        return count > 0 ? sum / Double(count) : 128
    }

    // MARK: - Dark Area Analysis

    private func analyzeDarkAreas(
        grayscale: [UInt8],
        width: Int,
        height: Int,
        regional: RegionalAnalysis
    ) -> DarkAreaMetrics? {
        // Define dark threshold (pixels darker than this are considered "dark area")
        let darkThreshold: UInt8 = 100

        var darkPixels: [UInt8] = []
        var totalPixels = 0

        for pixel in grayscale {
            totalPixels += 1
            if pixel < darkThreshold {
                darkPixels.append(pixel)
            }
        }

        // If less than 10% is dark, this probably isn't a half-black target
        let darkPercentage = Double(darkPixels.count) / Double(totalPixels)
        guard darkPercentage > 0.1 else {
            return nil
        }

        // Analyze dark region statistics
        let darkMean = darkPixels.isEmpty ? 0.0 : Double(darkPixels.reduce(0, { $0 + Int($1) })) / Double(darkPixels.count)
        let darkVariance = darkPixels.isEmpty ? 0.0 : darkPixels.reduce(0.0) { $0 + pow(Double($1) - darkMean, 2) } / Double(darkPixels.count)
        let darkStdDev = sqrt(darkVariance)

        // Contrast within dark region
        let darkContrast = min(1.0, darkStdDev / 30.0)  // Normalize

        // Estimate hole visibility: holes should create local brightness spikes
        // Higher variance in dark areas suggests visible features (holes)
        let holeVisibility = min(1.0, darkContrast * 2.0)

        // Contrast with expected holes (holes should appear lighter due to paper behind)
        // Estimate based on difference between dark area and what we'd expect a hole to look like
        let expectedHoleBrightness = (darkMean + 50)  // Holes let light through
        let contrastWithHoles = min(1.0, (expectedHoleBrightness - darkMean) / 100.0)

        return DarkAreaMetrics(
            darkRegionBrightness: darkMean / 255.0,
            darkRegionContrast: darkContrast,
            holeVisibilityScore: holeVisibility,
            contrastWithHoles: contrastWithHoles,
            darkAreaPercentage: darkPercentage
        )
    }

    // MARK: - Flash Detection

    private func detectFlash(grayscale: [UInt8], width: Int, height: Int) -> Bool {
        // Flash typically creates a bright specular highlight
        // Look for very bright pixels concentrated in a region

        var veryBrightCount = 0
        let brightThreshold: UInt8 = 250

        // Sample center region (flash reflection usually near center)
        let centerX = width / 2
        let centerY = height / 2
        let sampleRadius = min(width, height) / 4

        for dy in -sampleRadius..<sampleRadius {
            for dx in -sampleRadius..<sampleRadius {
                let x = centerX + dx
                let y = centerY + dy
                guard x >= 0 && x < width && y >= 0 && y < height else { continue }

                let idx = y * width + x
                if grayscale[idx] > brightThreshold {
                    veryBrightCount += 1
                }
            }
        }

        let sampleArea = (2 * sampleRadius) * (2 * sampleRadius)
        let brightRatio = Double(veryBrightCount) / Double(sampleArea)

        // If more than 0.5% of center is very bright, likely flash was used
        return brightRatio > 0.005
    }

    // MARK: - Helpers

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

    private func defaultAssessment() -> EnhancedQualityAssessment {
        EnhancedQualityAssessment(
            base: ImageQualityAssessment(
                sharpness: 0.5,
                contrast: 0.5,
                exposure: .good,
                brightness: 0.5,
                noiseLevel: 0.3
            ),
            darkAreaMetrics: nil,
            flashDetected: false,
            regionalAnalysis: defaultRegionalAnalysis()
        )
    }

    private func defaultRegionalAnalysis() -> RegionalAnalysis {
        RegionalAnalysis(
            quadrantBrightness: [0.5, 0.5, 0.5, 0.5],
            brightnessVariance: 0.0,
            lightHalfBrightness: 0.5,
            darkHalfBrightness: 0.5
        )
    }
}

// MARK: - Image Suitability Checker

/// Quick check for image suitability before full detection
struct ImageSuitabilityChecker {

    /// Minimum requirements for detection
    struct Requirements {
        let minSharpness: Double
        let minContrast: Double
        let minDarkAreaVisibility: Double

        static let standard = Requirements(
            minSharpness: 0.25,
            minContrast: 0.15,
            minDarkAreaVisibility: 0.3
        )

        static let relaxed = Requirements(
            minSharpness: 0.15,
            minContrast: 0.1,
            minDarkAreaVisibility: 0.2
        )
    }

    /// Check if image meets minimum requirements
    static func check(
        assessment: EnhancedQualityAssessment,
        requirements: Requirements = .standard
    ) -> SuitabilityResult {
        var issues: [String] = []
        var canProceed = true

        if assessment.base.sharpness < requirements.minSharpness {
            issues.append("Image too blurry")
            canProceed = false
        }

        if assessment.base.contrast < requirements.minContrast {
            issues.append("Contrast too low")
            // Can still proceed with low contrast
        }

        if let dark = assessment.darkAreaMetrics,
           dark.holeVisibilityScore < requirements.minDarkAreaVisibility {
            issues.append("Holes may not be visible on dark areas")
            // Warning only, don't block
        }

        if assessment.base.exposure == .underexposed {
            issues.append("Image underexposed")
            canProceed = false
        }

        return SuitabilityResult(
            isSuitable: canProceed,
            issues: issues,
            suggestions: generateSuggestions(for: issues, assessment: assessment)
        )
    }

    private static func generateSuggestions(
        for issues: [String],
        assessment: EnhancedQualityAssessment
    ) -> [String] {
        var suggestions: [String] = []

        if issues.contains(where: { $0.contains("blurry") }) {
            suggestions.append("Use a tripod or steady rest")
        }

        if issues.contains(where: { $0.contains("dark areas") }) && !assessment.flashDetected {
            suggestions.append("Enable flash for better visibility")
        }

        if issues.contains(where: { $0.contains("underexposed") }) {
            suggestions.append("Add more lighting or use flash")
        }

        return suggestions
    }

    struct SuitabilityResult {
        let isSuitable: Bool
        let issues: [String]
        let suggestions: [String]
    }
}
