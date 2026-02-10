//
//  FixtureTestRunner.swift
//  TetraTrack
//
//  Runs detection algorithm against ground truth fixtures and reports metrics.
//  Used for validating detection improvements in Simulator.
//

import Foundation
import UIKit
import os.log

/// Runs detection tests against ground truth fixtures
@MainActor
final class FixtureTestRunner {

    // MARK: - Properties

    private let logger = Logger(subsystem: "dev.dreamfold.tetratrack", category: "FixtureTest")
    private let pipeline = HoleDetectionPipeline()

    // MARK: - Public Interface

    /// Run all fixture tests and return aggregate results
    func runAllTests() async -> FixtureTestSummary {
        logger.info("Starting fixture test run...")

        var results: [FixtureTestResult] = []
        let fixtures = loadAllFixtures()

        for fixture in fixtures {
            if let result = await runTest(fixture: fixture) {
                results.append(result)
            }
        }

        let summary = FixtureTestSummary(results: results)
        logSummary(summary)

        return summary
    }

    /// Run test for a specific fixture
    func runTest(fixture: FixtureMetadataV2) async -> FixtureTestResult? {
        logger.info("Testing fixture: \(fixture.imageFile)")

        // Load image
        guard let image = loadFixtureImage(fixture: fixture) else {
            logger.error("Failed to load image for fixture: \(fixture.imageFile)")
            return nil
        }

        do {
            // Run detection
            let detectionResult = try await pipeline.detect(image: image)

            // Compare to ground truth
            let evaluation = evaluate(
                predictions: detectionResult.acceptedHoles + detectionResult.flaggedCandidates,
                groundTruth: fixture.holes,
                fixture: fixture
            )

            // Check against expected metrics
            let meetsRecall = evaluation.recall >= fixture.expectedMetrics.minRecall
            let meetsPrecision = evaluation.precision >= fixture.expectedMetrics.minPrecision
            let meetsCorrections = evaluation.userCorrections <= fixture.expectedMetrics.maxCorrections

            let result = FixtureTestResult(
                fixtureId: fixture.imageFile,
                category: fixture.category,
                difficulty: fixture.difficulty,
                evaluation: evaluation,
                meetsRecallTarget: meetsRecall,
                meetsPrecisionTarget: meetsPrecision,
                meetsCorrectionsTarget: meetsCorrections,
                passed: meetsRecall && meetsPrecision && meetsCorrections
            )

            logResult(result)
            return result

        } catch {
            logger.error("Detection failed for \(fixture.imageFile): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Private Helpers

    private func loadAllFixtures() -> [FixtureMetadataV2] {
        var fixtures: [FixtureMetadataV2] = []
        let decoder = JSONDecoder()

        guard let fixturesURL = Bundle.main.url(forResource: "SimulatorTargets", withExtension: nil) else {
            logger.warning("No SimulatorTargets folder found")
            return []
        }

        let categories = ["clean", "torn", "overlapping", "low_contrast", "black_region"]

        for category in categories {
            let categoryURL = fixturesURL.appendingPathComponent(category)
            let metadataURL = categoryURL.appendingPathComponent("metadata.json")

            if FileManager.default.fileExists(atPath: metadataURL.path) {
                do {
                    let data = try Data(contentsOf: metadataURL)
                    let fixture = try decoder.decode(FixtureMetadataV2.self, from: data)
                    fixtures.append(fixture)
                } catch {
                    logger.warning("Failed to load fixture from \(category): \(error.localizedDescription)")
                }
            }
        }

        return fixtures
    }

    private func loadFixtureImage(fixture: FixtureMetadataV2) -> UIImage? {
        // Try to find the image in the bundle
        let categoryDir = fixture.category.rawValue.lowercased()
        guard let fixturesURL = Bundle.main.url(forResource: "SimulatorTargets", withExtension: nil) else {
            return nil
        }

        let imageURL = fixturesURL
            .appendingPathComponent(categoryDir)
            .appendingPathComponent(fixture.imageFile)

        return UIImage(contentsOfFile: imageURL.path)
    }

    private func evaluate(
        predictions: [DetectedHole],
        groundTruth: [FixtureMetadataV2.FixtureHole],
        fixture: FixtureMetadataV2
    ) -> FixtureEvaluation {
        var truePositives = 0
        var matchedGroundTruth = Set<Int>()

        // Match predictions to ground truth
        for prediction in predictions {
            for hole in groundTruth {
                if matchedGroundTruth.contains(hole.id) { continue }

                let distance = hypot(
                    prediction.position.x - hole.x,
                    prediction.position.y - hole.y
                )

                if distance <= hole.matchTolerance {
                    truePositives += 1
                    matchedGroundTruth.insert(hole.id)
                    break
                }
            }
        }

        let falsePositives = predictions.count - truePositives
        let falseNegatives = groundTruth.count - matchedGroundTruth.count

        let precision = (truePositives + falsePositives) > 0
            ? Double(truePositives) / Double(truePositives + falsePositives)
            : 0

        let recall = (truePositives + falseNegatives) > 0
            ? Double(truePositives) / Double(truePositives + falseNegatives)
            : 0

        let f1 = (precision + recall) > 0
            ? 2 * precision * recall / (precision + recall)
            : 0

        // Calculate per-region metrics
        let blackHoles = groundTruth.filter { $0.region == .black }
        let whiteHoles = groundTruth.filter { $0.region == .white }

        let blackRecall = calculateRegionRecall(predictions: predictions, groundTruth: blackHoles)
        let whiteRecall = calculateRegionRecall(predictions: predictions, groundTruth: whiteHoles)

        return FixtureEvaluation(
            truePositives: truePositives,
            falsePositives: falsePositives,
            falseNegatives: falseNegatives,
            precision: precision,
            recall: recall,
            f1Score: f1,
            blackRegionRecall: blackRecall,
            whiteRegionRecall: whiteRecall,
            userCorrections: falsePositives + falseNegatives
        )
    }

    private func calculateRegionRecall(
        predictions: [DetectedHole],
        groundTruth: [FixtureMetadataV2.FixtureHole]
    ) -> Double? {
        guard !groundTruth.isEmpty else { return nil }

        var matched = 0
        for hole in groundTruth {
            for prediction in predictions {
                let distance = hypot(
                    prediction.position.x - hole.x,
                    prediction.position.y - hole.y
                )
                if distance <= hole.matchTolerance {
                    matched += 1
                    break
                }
            }
        }

        return Double(matched) / Double(groundTruth.count)
    }

    private func logResult(_ result: FixtureTestResult) {
        let status = result.passed ? "PASS" : "FAIL"
        let icon = result.passed ? "✓" : "✗"

        logger.info("""
        \(icon) [\(status)] \(result.fixtureId)
           Category: \(result.category.rawValue) | Difficulty: \(result.difficulty.rawValue)
           Precision: \(String(format: "%.1f%%", result.evaluation.precision * 100)) (target: \(String(format: "%.0f%%", result.evaluation.precision >= 0.9 ? 90 : 0)))
           Recall: \(String(format: "%.1f%%", result.evaluation.recall * 100))
           F1: \(String(format: "%.3f", result.evaluation.f1Score))
           Corrections: \(result.evaluation.userCorrections)
        """)
    }

    private func logSummary(_ summary: FixtureTestSummary) {
        logger.info("""

        ══════════════════════════════════════════
        FIXTURE TEST SUMMARY
        ══════════════════════════════════════════
        Total: \(summary.totalTests) | Passed: \(summary.passedTests) | Failed: \(summary.failedTests)
        Pass Rate: \(String(format: "%.1f%%", summary.passRate * 100))

        Aggregate Metrics:
          Precision: \(String(format: "%.1f%%", summary.aggregatePrecision * 100))
          Recall: \(String(format: "%.1f%%", summary.aggregateRecall * 100))
          F1 Score: \(String(format: "%.3f", summary.aggregateF1))

        By Category:
          Clean: \(summary.resultsByCategory[.clean]?.passRate ?? 0)
          Black Region: \(summary.resultsByCategory[.blackRegion]?.passRate ?? 0)
          Overlapping: \(summary.resultsByCategory[.overlapping]?.passRate ?? 0)
          Torn: \(summary.resultsByCategory[.torn]?.passRate ?? 0)
          Low Contrast: \(summary.resultsByCategory[.lowContrast]?.passRate ?? 0)
        ══════════════════════════════════════════

        """)
    }
}

// MARK: - Result Types

struct FixtureTestResult {
    let fixtureId: String
    let category: FixtureMetadataV2.FixtureCategory
    let difficulty: FixtureMetadataV2.FixtureDifficulty
    let evaluation: FixtureEvaluation
    let meetsRecallTarget: Bool
    let meetsPrecisionTarget: Bool
    let meetsCorrectionsTarget: Bool
    let passed: Bool
}

struct FixtureEvaluation {
    let truePositives: Int
    let falsePositives: Int
    let falseNegatives: Int
    let precision: Double
    let recall: Double
    let f1Score: Double
    let blackRegionRecall: Double?
    let whiteRegionRecall: Double?
    let userCorrections: Int
}

struct FixtureTestSummary {
    let results: [FixtureTestResult]

    var totalTests: Int { results.count }
    var passedTests: Int { results.filter { $0.passed }.count }
    var failedTests: Int { results.filter { !$0.passed }.count }
    var passRate: Double { totalTests > 0 ? Double(passedTests) / Double(totalTests) : 0 }

    var aggregatePrecision: Double {
        guard !results.isEmpty else { return 0 }
        return results.map { $0.evaluation.precision }.reduce(0, +) / Double(results.count)
    }

    var aggregateRecall: Double {
        guard !results.isEmpty else { return 0 }
        return results.map { $0.evaluation.recall }.reduce(0, +) / Double(results.count)
    }

    var aggregateF1: Double {
        guard !results.isEmpty else { return 0 }
        return results.map { $0.evaluation.f1Score }.reduce(0, +) / Double(results.count)
    }

    var resultsByCategory: [FixtureMetadataV2.FixtureCategory: CategorySummary] {
        var summaries: [FixtureMetadataV2.FixtureCategory: CategorySummary] = [:]

        for category in FixtureMetadataV2.FixtureCategory.allCases {
            let categoryResults = results.filter { $0.category == category }
            if !categoryResults.isEmpty {
                summaries[category] = CategorySummary(
                    total: categoryResults.count,
                    passed: categoryResults.filter { $0.passed }.count
                )
            }
        }

        return summaries
    }

    struct CategorySummary {
        let total: Int
        let passed: Int
        var passRate: Double { total > 0 ? Double(passed) / Double(total) : 0 }
    }
}

// MARK: - CaseIterable conformance

extension FixtureMetadataV2.FixtureCategory: CaseIterable {
    static var allCases: [FixtureMetadataV2.FixtureCategory] = [
        .clean, .torn, .overlapping, .lowContrast, .blackRegion, .mixed
    ]
}
