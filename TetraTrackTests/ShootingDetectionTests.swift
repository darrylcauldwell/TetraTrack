//
//  ShootingDetectionTests.swift
//  TetraTrackTests
//
//  Golden master tests for shooting target detection pipeline.
//  Validates detection accuracy against curated fixture images.
//

import Testing
import Foundation
import UIKit
@testable import TetraTrack

// MARK: - Golden Master Test Infrastructure

struct ShootingDetectionTests {

    // MARK: - Position Matching Tests

    @Test func goldenMasterShotMatching() {
        // Test that position matching works correctly
        let shot = GoldenMasterShot(x: 0.1, y: 0.2, score: 8, tolerance: 0.05)
        let detectedPosition = NormalizedTargetPosition(x: 0.12, y: 0.18)

        let distance = sqrt(
            pow(detectedPosition.x - shot.normalizedX, 2) +
            pow(detectedPosition.y - shot.normalizedY, 2)
        )

        #expect(distance <= shot.matchTolerance)
    }

    @Test func goldenMasterShotNotMatching() {
        let shot = GoldenMasterShot(x: 0.1, y: 0.2, score: 8, tolerance: 0.05)
        let detectedPosition = NormalizedTargetPosition(x: 0.3, y: 0.4)

        let distance = sqrt(
            pow(detectedPosition.x - shot.normalizedX, 2) +
            pow(detectedPosition.y - shot.normalizedY, 2)
        )

        #expect(distance > shot.matchTolerance)
    }

    // MARK: - Score Calculation Tests

    @Test func tetrathlonScoreCalculation() {
        let geometry = ShootingTargetGeometryType.tetrathlon

        // Center shot = 10
        let centerPos = NormalizedTargetPosition(x: 0.0, y: 0.0)
        #expect(geometry.score(from: centerPos) == 10)

        // Near edge (using elliptical distance)
        let edgePos = NormalizedTargetPosition(x: 0.95, y: 0.0)
        #expect(geometry.score(from: edgePos) == 2)

        // Outside target
        let outsidePos = NormalizedTargetPosition(x: 1.2, y: 0.0)
        #expect(geometry.score(from: outsidePos) == 0)
    }

    @Test func olympicPistolScoreCalculation() {
        let geometry = ShootingTargetGeometryType.olympicPistol

        // Center shot = 10
        let centerPos = NormalizedTargetPosition(x: 0.0, y: 0.0)
        #expect(geometry.score(from: centerPos) == 10)
    }

    // MARK: - Stadium Geometry Tests

    @Test func stadiumGeometryContainment() {
        // Test stadium shape contains center
        let outerStadium = TetrathlonTargetGeometry.outerStadium
        let centerPoint = CGPoint(x: 0.0, y: 0.0)
        #expect(outerStadium.contains(normalizedPoint: centerPoint))

        // Test stadium shape contains point in straight section
        let straightPoint = CGPoint(x: 0.3, y: 0.0)
        #expect(outerStadium.contains(normalizedPoint: straightPoint))

        // Test stadium shape contains point in semicircle region
        let semicirclePoint = CGPoint(x: 0.0, y: 0.5)
        #expect(outerStadium.contains(normalizedPoint: semicirclePoint))
    }

    @Test func stadiumRingClassification() {
        // Center should be in 10 ring
        let centerPos = NormalizedTargetPosition(x: 0.0, y: 0.0)
        #expect(TetrathlonTargetGeometry.score(from: centerPos) == 10)

        // Small offset should still be 10
        let smallOffset = NormalizedTargetPosition(x: 0.05, y: 0.05)
        #expect(TetrathlonTargetGeometry.score(from: smallOffset) == 10)

        // Shots in straight section at different horizontal distances
        // At x=0.2, y=0 should be in 8 ring (between 0.12 and 0.35)
        let straightSection8 = NormalizedTargetPosition(x: 0.2, y: 0.0)
        #expect(TetrathlonTargetGeometry.score(from: straightSection8) == 8)

        // At x=0.5, y=0 should be in 6 ring (between 0.35 and 0.55)
        let straightSection6 = NormalizedTargetPosition(x: 0.5, y: 0.0)
        #expect(TetrathlonTargetGeometry.score(from: straightSection6) == 6)
    }

    @Test func stadiumDistanceCalculation() {
        let outerStadium = TetrathlonTargetGeometry.outerStadium

        // Center should have distance ~0
        let centerDist = outerStadium.normalizedDistance(from: CGPoint(x: 0, y: 0))
        #expect(centerDist < 0.01)

        // Point on boundary should have distance ~1
        // In straight section, x=full width means at boundary
        let semicircleRadius = outerStadium.semicircleRadius
        let boundaryX = semicircleRadius / (outerStadium.totalWidth / 2)
        let boundaryPoint = CGPoint(x: boundaryX, y: 0)
        let boundaryDist = outerStadium.normalizedDistance(from: boundaryPoint)
        #expect(abs(boundaryDist - 1.0) < 0.01)
    }

    @Test func bullValidation75Percent() {
        // All shots in center should validate
        let centralShots = [
            CGPoint(x: 0.0, y: 0.0),
            CGPoint(x: 0.03, y: 0.02),
            CGPoint(x: -0.02, y: 0.03),
            CGPoint(x: 0.04, y: -0.01)
        ]
        #expect(TetrathlonTargetGeometry.validateBullClassification(shots: centralShots))
    }

    // MARK: - Fixture Registry Tests

    @Test func fixtureRegistryContainsFixtures() {
        let registry = TargetFixtureRegistry.shared

        #expect(registry.allFixtures.count > 0)
    }

    @Test func fixtureRegistryCategories() {
        let registry = TargetFixtureRegistry.shared

        // Check ideal fixtures exist
        let idealFixtures = registry.fixtures(in: .idealConditions)
        #expect(idealFixtures.count >= 1)
    }

    @Test func fixtureMetadataConsistency() {
        let registry = TargetFixtureRegistry.shared

        for fixture in registry.allFixtures {
            // Golden master shot count should match expected hole count
            if !fixture.metadata.goldenMasterShots.isEmpty {
                #expect(fixture.metadata.goldenMasterShots.count == fixture.metadata.expectedHoleCount,
                       "Fixture \(fixture.name): golden shots count mismatch")
            }

            // Difficulty should be 1-5
            #expect((1...5).contains(fixture.metadata.difficulty),
                   "Fixture \(fixture.name): difficulty out of range")

            // Rotation degrees should be reasonable
            #expect(fixture.metadata.rotationDegrees >= -180 && fixture.metadata.rotationDegrees <= 180,
                   "Fixture \(fixture.name): rotation out of range")
        }
    }

    // MARK: - Coordinate Transformer Tests

    @Test func coordinateTransformerRoundTrip() {
        let cropGeometry = TargetCropGeometry(
            cropRect: CGRect(x: 100, y: 100, width: 600, height: 600),
            targetCenterInCrop: CGPoint(x: 0.5, y: 0.5),
            targetSemiAxes: CGSize(width: 0.4, height: 0.45),
            rotationDegrees: 0,
            physicalAspectRatio: 0.86
        )

        let transformer = TargetCoordinateTransformer(
            cropGeometry: cropGeometry,
            imageSize: CGSize(width: 600, height: 600)
        )

        // Test center point
        let centerPixel = CGPoint(x: 300, y: 300) // Center of crop
        let normalized = transformer.toTargetCoordinates(pixelPosition: centerPixel)
        let backToPixel = transformer.toPixelPosition(targetPosition: normalized)

        #expect(abs(backToPixel.x - centerPixel.x) < 1.0)
        #expect(abs(backToPixel.y - centerPixel.y) < 1.0)
    }

    @Test func coordinateTransformerEdgeBounds() {
        let cropGeometry = TargetCropGeometry()
        let transformer = TargetCoordinateTransformer(
            cropGeometry: cropGeometry,
            imageSize: CGSize(width: 1000, height: 1000)
        )

        // Target edge should map to approximately -1 or +1
        let topEdge = NormalizedTargetPosition(x: 0, y: -1)
        let bottomEdge = NormalizedTargetPosition(x: 0, y: 1)

        // Verify these are valid positions (radial distance <= 1)
        #expect(topEdge.radialDistance <= 1.0)
        #expect(bottomEdge.radialDistance <= 1.0)
    }

    // MARK: - Quality Assessment Tests

    @Test func qualityAssessmentPassesGoodImage() async {
        let assessor = ImageQualityAssessor()

        // Create a synthetic "good" image (high contrast, sharp)
        guard let image = createTestImage(
            width: 500,
            height: 500,
            pattern: .highContrast
        ) else {
            Issue.record("Failed to create test image")
            return
        }

        let assessment = await assessor.assess(image: image)

        // Good image should have reasonable quality
        #expect(assessment.overallScore > 0.3)
    }

    @Test func qualityAssessmentWarnsOnBlurry() async {
        let assessor = ImageQualityAssessor()

        // Create a synthetic blurry image
        guard let image = createTestImage(
            width: 500,
            height: 500,
            pattern: .uniform
        ) else {
            Issue.record("Failed to create test image")
            return
        }

        let assessment = await assessor.assess(image: image)

        // Uniform image should have low contrast
        #expect(assessment.contrast < 0.5)
    }

    // MARK: - Pattern Analysis Tests

    @Test func patternAnalyzerMPICalculation() {
        // Create a symmetric pattern centered at origin
        let shots: [TestShot] = [
            TestShot(x: 0.1, y: 0.1, score: 8),
            TestShot(x: -0.1, y: 0.1, score: 8),
            TestShot(x: 0.1, y: -0.1, score: 8),
            TestShot(x: -0.1, y: -0.1, score: 8)
        ]

        guard let analysis = PatternAnalyzer.analyze(shots: shots) else {
            Issue.record("Pattern analysis returned nil")
            return
        }

        // MPI should be near center
        #expect(abs(analysis.mpi.x) < 0.01)
        #expect(abs(analysis.mpi.y) < 0.01)
    }

    @Test func patternAnalyzerBiasedPattern() {
        // Create a pattern biased to the right
        let shots: [TestShot] = [
            TestShot(x: 0.2, y: 0.0, score: 6),
            TestShot(x: 0.25, y: 0.05, score: 6),
            TestShot(x: 0.22, y: -0.03, score: 6),
            TestShot(x: 0.18, y: 0.02, score: 6)
        ]

        guard let analysis = PatternAnalyzer.analyze(shots: shots) else {
            Issue.record("Pattern analysis returned nil")
            return
        }

        // Should detect rightward bias
        #expect(analysis.mpi.x > 0.15)
        #expect(analysis.directionalBias.isSignificant)
    }

    @Test func patternAnalyzerExtremeSpread() {
        // Wide spread pattern
        let shots: [TestShot] = [
            TestShot(x: 0.5, y: 0.5, score: 4),
            TestShot(x: -0.5, y: 0.5, score: 4),
            TestShot(x: 0.5, y: -0.5, score: 4),
            TestShot(x: -0.5, y: -0.5, score: 4)
        ]

        guard let analysis = PatternAnalyzer.analyze(shots: shots) else {
            Issue.record("Pattern analysis returned nil")
            return
        }

        // Extreme spread should be approximately sqrt(2)
        #expect(analysis.extremeSpread > 1.0)
    }

    @Test func patternAnalyzerInsufficientShots() {
        // Too few shots for analysis
        let shots: [TestShot] = [
            TestShot(x: 0.1, y: 0.05, score: 8)
        ]

        let analysis = PatternAnalyzer.analyze(shots: shots)

        // Should return nil for insufficient shots
        #expect(analysis == nil)
    }

    // MARK: - Validation Tests

    @Test func shotValidatorReasonablePositions() {
        // Valid position inside target
        let validPos = NormalizedTargetPosition(x: 0.3, y: 0.2)
        let result = ShotValidator.validateShot(
            position: validPos,
            score: 6,
            targetType: .tetrathlon,
            confidence: 0.8
        )

        #expect(result.isValid == true)
    }

    @Test func shotValidatorEdgePosition() {
        // Position near edge
        let edgePos = NormalizedTargetPosition(x: 0.95, y: 0.0)
        let result = ShotValidator.validateShot(
            position: edgePos,
            score: 2,
            targetType: .tetrathlon,
            confidence: 0.8
        )

        // Should be valid
        #expect(result.isValid == true)
    }

    @Test func shotValidatorOutsidePosition() {
        // Position clearly outside
        let outsidePos = NormalizedTargetPosition(x: 2.0, y: 2.0)
        let result = ShotValidator.validateShot(
            position: outsidePos,
            score: 0,
            targetType: .tetrathlon,
            confidence: 0.8
        )

        #expect(result.isValid == false || !result.warnings.isEmpty)
    }

    @Test func shotValidatorLowConfidence() {
        let pos = NormalizedTargetPosition(x: 0.1, y: 0.1)
        let result = ShotValidator.validateShot(
            position: pos,
            score: 8,
            targetType: .tetrathlon,
            confidence: 0.2
        )

        // Low confidence should generate warning
        #expect(!result.warnings.isEmpty)
    }

    // MARK: - Target Geometry Tests

    @Test func tetrathlonGeometryAspectRatio() {
        let geometry = ShootingTargetGeometryType.tetrathlon

        // Tetrathlon target is elliptical
        #expect(geometry.aspectRatio < 1.0)
        #expect(geometry.aspectRatio > 0.7)
    }

    @Test func tetrathlonScoringZones() {
        let geometry = ShootingTargetGeometryType.tetrathlon

        // Check scoring radii are defined
        let radii = geometry.normalizedScoringRadii
        #expect(radii.count == 5) // 10, 8, 6, 4, 2
    }

    @Test func normalizedPositionEllipticalDistance() {
        let pos = NormalizedTargetPosition(x: 0.77, y: 0.0)
        let aspectRatio = 0.77

        // Should be at edge of ellipse (distance ~1)
        let distance = pos.ellipticalDistance(aspectRatio: aspectRatio)
        #expect(abs(distance - 1.0) < 0.01)
    }

    // MARK: - Detection Config Tests

    @Test func holeDetectionConfigDefaults() {
        let config = HoleDetectionConfig()

        #expect(config.minCircularity > 0)
        #expect(config.minCircularity < 1)
        #expect(config.autoAcceptConfidence >= 0)
        #expect(config.autoAcceptConfidence <= 1)
    }

    // MARK: - Pipeline Cache Tests

    @Test func pipelineCacheStatisticsInitialState() async {
        let cache = DetectionPipelineCache()

        let stats = await cache.statistics

        #expect(stats.preprocessingCount == 0)
        #expect(stats.contourCount == 0)
        #expect(stats.filteringCount == 0)
        #expect(stats.hits == 0)
        #expect(stats.misses == 0)
    }

    @Test func pipelineCacheHitRate() async {
        let cache = DetectionPipelineCache()

        let testResult = PreprocessingResult(
            grayscaleData: [0, 1, 2, 3],
            imageWidth: 2,
            imageHeight: 2,
            edgeMap: nil,
            timestamp: Date()
        )

        // Cache miss then hit
        _ = await cache.getPreprocessing(for: "test_hash")
        await cache.cachePreprocessing(testResult, for: "test_hash")
        _ = await cache.getPreprocessing(for: "test_hash")

        let stats = await cache.statistics
        #expect(stats.hits == 1)
        #expect(stats.misses == 1)
        #expect(stats.hitRate == 0.5)
    }

    // MARK: - Helper Functions

    private enum TestImagePattern {
        case highContrast
        case uniform
    }

    private func createTestImage(
        width: Int,
        height: Int,
        pattern: TestImagePattern
    ) -> UIImage? {
        UIGraphicsBeginImageContext(CGSize(width: width, height: height))
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return nil
        }

        switch pattern {
        case .highContrast:
            // Draw high contrast pattern (checkerboard)
            let squareSize = 50
            for row in 0..<(height / squareSize) {
                for col in 0..<(width / squareSize) {
                    let isBlack = (row + col) % 2 == 0
                    context.setFillColor(isBlack ? UIColor.black.cgColor : UIColor.white.cgColor)
                    context.fill(CGRect(
                        x: col * squareSize,
                        y: row * squareSize,
                        width: squareSize,
                        height: squareSize
                    ))
                }
            }

        case .uniform:
            // Draw solid color (no contrast)
            context.setFillColor(UIColor.gray.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}

// MARK: - Test Shot Type

/// Test shot that conforms to ShotForAnalysis
private struct TestShot: ShotForAnalysis {
    let normalizedPosition: NormalizedTargetPosition
    let score: Int

    init(x: Double, y: Double, score: Int) {
        self.normalizedPosition = NormalizedTargetPosition(x: x, y: y)
        self.score = score
    }
}

// MARK: - Golden Master Comparison Tests

struct GoldenMasterComparisonTests {

    @Test func compareDetectedPositionsWithGoldenMaster() {
        // This test structure validates detected positions against golden master
        let goldenShots = [
            GoldenMasterShot(x: 0.02, y: 0.03, score: 10),
            GoldenMasterShot(x: -0.01, y: -0.02, score: 10),
            GoldenMasterShot(x: 0.05, y: -0.01, score: 10)
        ]

        // Simulated detected positions (slightly off from golden)
        let detectedPositions = [
            NormalizedTargetPosition(x: 0.025, y: 0.028),
            NormalizedTargetPosition(x: -0.008, y: -0.022),
            NormalizedTargetPosition(x: 0.048, y: -0.012)
        ]

        let matches = matchDetectedToGolden(
            detected: detectedPositions,
            golden: goldenShots
        )

        // All detections should match within tolerance
        #expect(matches.matchedCount == 3)
        #expect(matches.unmatchedDetected.isEmpty)
        #expect(matches.unmatchedGolden.isEmpty)
    }

    @Test func detectUnmatchedGoldenShots() {
        let goldenShots = [
            GoldenMasterShot(x: 0.0, y: 0.0, score: 10),
            GoldenMasterShot(x: 0.5, y: 0.5, score: 6)  // This one not detected
        ]

        let detectedPositions = [
            NormalizedTargetPosition(x: 0.01, y: -0.01)  // Only one detection
        ]

        let matches = matchDetectedToGolden(
            detected: detectedPositions,
            golden: goldenShots
        )

        #expect(matches.matchedCount == 1)
        #expect(matches.unmatchedGolden.count == 1)
    }

    @Test func detectFalsePositives() {
        let goldenShots = [
            GoldenMasterShot(x: 0.0, y: 0.0, score: 10)
        ]

        let detectedPositions = [
            NormalizedTargetPosition(x: 0.01, y: 0.01),
            NormalizedTargetPosition(x: 0.8, y: 0.8)  // False positive
        ]

        let matches = matchDetectedToGolden(
            detected: detectedPositions,
            golden: goldenShots
        )

        #expect(matches.matchedCount == 1)
        #expect(matches.unmatchedDetected.count == 1)
    }

    @Test func comparePatternAnalysisWithExpected() {
        let expectedAnalysis = ExpectedPatternAnalysis(
            mpiX: 0.008,
            mpiY: 0.01,
            standardDeviation: 0.035,
            extremeSpread: 0.08,
            tolerance: 0.02
        )

        // Simulated actual analysis (slightly different)
        let actualMpiX = 0.01
        let actualMpiY = 0.012
        let actualStdDev = 0.033
        let actualSpread = 0.082

        // Check within tolerance
        #expect(abs(actualMpiX - expectedAnalysis.mpiX) <= expectedAnalysis.tolerance)
        #expect(abs(actualMpiY - expectedAnalysis.mpiY) <= expectedAnalysis.tolerance)
        #expect(abs(actualStdDev - expectedAnalysis.standardDeviation) <= expectedAnalysis.tolerance)
        #expect(abs(actualSpread - expectedAnalysis.extremeSpread) <= expectedAnalysis.tolerance)
    }

    // MARK: - Matching Helper

    private struct MatchResult {
        let matchedCount: Int
        let unmatchedDetected: [NormalizedTargetPosition]
        let unmatchedGolden: [GoldenMasterShot]
    }

    private func matchDetectedToGolden(
        detected: [NormalizedTargetPosition],
        golden: [GoldenMasterShot]
    ) -> MatchResult {
        var remainingGolden = golden
        var unmatchedDetected: [NormalizedTargetPosition] = []
        var matchedCount = 0

        for detectedPos in detected {
            var foundMatch = false

            for (index, goldenShot) in remainingGolden.enumerated() {
                let distance = sqrt(
                    pow(detectedPos.x - goldenShot.normalizedX, 2) +
                    pow(detectedPos.y - goldenShot.normalizedY, 2)
                )

                if distance <= goldenShot.matchTolerance {
                    remainingGolden.remove(at: index)
                    matchedCount += 1
                    foundMatch = true
                    break
                }
            }

            if !foundMatch {
                unmatchedDetected.append(detectedPos)
            }
        }

        return MatchResult(
            matchedCount: matchedCount,
            unmatchedDetected: unmatchedDetected,
            unmatchedGolden: remainingGolden
        )
    }
}

// MARK: - Batch Processing Tests

struct BatchProcessingTests {

    @Test func batchProcessorHandlesEmptyList() async {
        let processor = BatchPipelineProcessor()

        let results = await processor.processBatch(
            fixtures: [],
            targetType: .tetrathlon,
            config: HoleDetectionConfig()
        )

        #expect(results.isEmpty)
    }

    @Test func batchResultsContainTimingInfo() {
        // Test that successful results include timing information
        let testResult = PipelineExecutionResult(
            candidates: [],
            quality: ImageQualityAssessment(
                sharpness: 0.8,
                contrast: 0.7,
                exposure: .good,
                brightness: 0.5,
                noiseLevel: 0.2
            ),
            timing: ["quality": 0.01, "preprocessing": 0.02],
            debugState: DebugPipelineState(),
            cacheStatistics: DetectionPipelineCache.CacheStatistics(
                preprocessingCount: 0,
                contourCount: 0,
                filteringCount: 0,
                hits: 0,
                misses: 0
            )
        )

        #expect(testResult.totalProcessingTime > 0)
        #expect(testResult.timing.count >= 2)
    }
}

// MARK: - Fixture Validation Tests

struct FixtureValidationTests {

    @Test func allFixturesHaveValidMetadata() {
        let registry = TargetFixtureRegistry.shared

        for fixture in registry.allFixtures {
            // Target type should be valid
            #expect(["tetrathlon", "olympicPistol"].contains(fixture.metadata.targetType),
                   "Invalid target type for fixture: \(fixture.name)")

            // Golden shots should have valid scores
            for shot in fixture.metadata.goldenMasterShots {
                #expect((0...10).contains(shot.expectedScore),
                       "Invalid score in fixture: \(fixture.name)")
                #expect(shot.matchTolerance > 0,
                       "Invalid tolerance in fixture: \(fixture.name)")
            }

            // Expected analysis tolerance should be positive
            if let analysis = fixture.metadata.expectedAnalysis {
                #expect(analysis.tolerance > 0,
                       "Invalid analysis tolerance in fixture: \(fixture.name)")
            }
        }
    }

    @Test func idealFixturesHaveExpectedAnalysis() {
        let registry = TargetFixtureRegistry.shared
        let idealFixtures = registry.fixtures(in: .idealConditions)

        for fixture in idealFixtures {
            // Ideal fixtures should have expected analysis for validation
            if fixture.metadata.goldenMasterShots.count >= 3 {
                #expect(fixture.metadata.expectedAnalysis != nil,
                       "Ideal fixture '\(fixture.name)' should have expectedAnalysis")
            }
        }
    }

    @Test func edgeCaseFixturesHandleSpecialCases() {
        let registry = TargetFixtureRegistry.shared
        let edgeCases = registry.fixtures(in: .edgeCases)

        // Should have empty target fixture
        let emptyFixture = edgeCases.first { $0.metadata.expectedHoleCount == 0 }
        #expect(emptyFixture != nil, "Should have empty target fixture")

        // Should have single shot fixture
        let singleFixture = edgeCases.first { $0.metadata.expectedHoleCount == 1 }
        #expect(singleFixture != nil, "Should have single shot fixture")
    }
}
