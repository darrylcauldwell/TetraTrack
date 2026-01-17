//
//  MLTrainingDataService.swift
//  TrackRide
//
//  Service for collecting and storing ML training data from manual hole markings.
//  All manual corrections become ground truth for future model training.
//

import Foundation
import UIKit
import os.log

/// Service for collecting ML training data from manual hole markings
@MainActor
final class MLTrainingDataService {

    // MARK: - Singleton

    static let shared = MLTrainingDataService()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.tetratrack", category: "MLTraining")
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Base directory for training data
    private var trainingDataDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("MLTrainingData", isDirectory: true)
    }

    /// Directory for captured images
    private var imagesDirectory: URL {
        trainingDataDirectory.appendingPathComponent("Images", isDirectory: true)
    }

    /// Directory for capture metadata (JSON)
    private var capturesDirectory: URL {
        trainingDataDirectory.appendingPathComponent("Captures", isDirectory: true)
    }

    /// Manifest file path
    private var manifestPath: URL {
        trainingDataDirectory.appendingPathComponent("manifest.json")
    }

    /// Current manifest (cached)
    private var manifest: TrainingDatasetManifest?

    // MARK: - Initialization

    private init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        setupDirectories()
    }

    private func setupDirectories() {
        do {
            try fileManager.createDirectory(at: trainingDataDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: capturesDirectory, withIntermediateDirectories: true)
            logger.info("ML training data directories created at \(self.trainingDataDirectory.path)")
        } catch {
            logger.error("Failed to create training data directories: \(error.localizedDescription)")
        }
    }

    // MARK: - Public Interface

    /// Save a complete training capture (image + annotations + metadata)
    func saveTrainingCapture(
        image: UIImage,
        annotations: [HoleAnnotation],
        markingEvents: [HoleMarkingEvent],
        metadata: CaptureMetadata,
        targetType: TargetType = .tetrathlon,
        sessionContext: SessionContext? = nil
    ) async throws -> TrainingTargetCapture {
        let captureId = UUID()
        let timestamp = Date()

        // Save image
        let imageFilename = "\(captureId.uuidString).jpg"
        let imagePath = imagesDirectory.appendingPathComponent(imageFilename)

        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw MLTrainingError.imageEncodingFailed
        }

        try imageData.write(to: imagePath)
        logger.debug("Saved training image: \(imageFilename)")

        // Create capture record
        let capture = TrainingTargetCapture(
            id: captureId,
            captureTimestamp: timestamp,
            imageFilename: imageFilename,
            thumbnailFilename: nil,
            metadata: metadata,
            annotations: annotations,
            markingEvents: markingEvents,
            targetType: targetType,
            sessionContext: sessionContext
        )

        // Save capture metadata as JSON
        let captureFilename = "\(captureId.uuidString).json"
        let capturePath = capturesDirectory.appendingPathComponent(captureFilename)
        let captureData = try encoder.encode(capture)
        try captureData.write(to: capturePath)
        logger.debug("Saved training capture metadata: \(captureFilename)")

        // Update manifest
        try await updateManifest(with: capture)

        logger.info("Saved ML training capture: \(captureId.uuidString) with \(annotations.count) holes")
        logCaptureStats(capture)

        return capture
    }

    /// Record a hole marking event (for live tracking during editing)
    func recordMarkingEvent(
        action: HoleMarkingEvent.MarkingAction,
        holeId: UUID,
        position: CGPoint,
        pixelPosition: CGPoint? = nil,
        estimatedDiameter: Double = 0.02,
        previousPosition: CGPoint? = nil
    ) -> HoleMarkingEvent {
        HoleMarkingEvent(
            id: UUID(),
            timestamp: Date(),
            action: action,
            holeId: holeId,
            position: CodablePoint(position),
            pixelPosition: pixelPosition.map { CodablePoint($0) },
            estimatedDiameter: estimatedDiameter,
            previousPosition: previousPosition.map { CodablePoint($0) }
        )
    }

    /// Create a hole annotation from detected hole
    func createAnnotation(
        from position: CGPoint,
        pixelPosition: CGPoint? = nil,
        score: Int,
        targetRegion: TargetHalfRegion = .unknown,
        characteristics: HoleCharacteristics = .normal
    ) -> HoleAnnotation {
        HoleAnnotation(
            position: position,
            pixelPosition: pixelPosition,
            estimatedDiameter: 0.02,
            targetRegion: targetRegion,
            holeCharacteristics: characteristics,
            score: score,
            confidence: 1.0
        )
    }

    /// Determine target region for a position (based on normalized X coordinate)
    func determineTargetRegion(position: CGPoint, isLeftBlack: Bool = true) -> TargetHalfRegion {
        let transitionZone = 0.05 // 5% zone around center

        if abs(position.x - 0.5) < transitionZone {
            return .transition
        }

        let isLeftSide = position.x < 0.5

        if isLeftBlack {
            return isLeftSide ? .black : .white
        } else {
            return isLeftSide ? .white : .black
        }
    }

    // MARK: - Dataset Access

    /// Load the current manifest
    func loadManifest() async throws -> TrainingDatasetManifest {
        if let cached = manifest {
            return cached
        }

        guard fileManager.fileExists(atPath: manifestPath.path) else {
            // Create empty manifest
            let newManifest = TrainingDatasetManifest(
                createdAt: Date(),
                lastUpdatedAt: Date(),
                captures: [],
                datasetStats: .empty
            )
            manifest = newManifest
            return newManifest
        }

        let data = try Data(contentsOf: manifestPath)
        let loadedManifest = try decoder.decode(TrainingDatasetManifest.self, from: data)
        manifest = loadedManifest
        return loadedManifest
    }

    /// Load a specific capture
    func loadCapture(id: UUID) async throws -> TrainingTargetCapture {
        let filename = "\(id.uuidString).json"
        let path = capturesDirectory.appendingPathComponent(filename)
        let data = try Data(contentsOf: path)
        return try decoder.decode(TrainingTargetCapture.self, from: data)
    }

    /// Load image for a capture
    func loadImage(for capture: TrainingTargetCapture) async throws -> UIImage {
        let path = imagesDirectory.appendingPathComponent(capture.imageFilename)
        guard let image = UIImage(contentsOfFile: path.path) else {
            throw MLTrainingError.imageLoadFailed
        }
        return image
    }

    /// Get dataset statistics
    func getDatasetStats() async throws -> TrainingDatasetManifest.DatasetStats {
        let manifest = try await loadManifest()
        return manifest.datasetStats
    }

    /// Export dataset for training (returns directory URL)
    func exportDataset() async throws -> URL {
        logger.info("Exporting ML training dataset from \(self.trainingDataDirectory.path)")
        return trainingDataDirectory
    }

    // MARK: - Simulator Fixtures

    /// Load simulator fixtures from bundle
    func loadSimulatorFixtures() async throws -> [FixtureMetadataV2] {
        var fixtures: [FixtureMetadataV2] = []

        // Look in app bundle for fixtures
        guard let fixturesURL = Bundle.main.url(forResource: "SimulatorTargets", withExtension: nil) else {
            logger.warning("No SimulatorTargets folder found in bundle")
            return []
        }

        let categories = try fileManager.contentsOfDirectory(at: fixturesURL, includingPropertiesForKeys: nil)

        for categoryURL in categories where categoryURL.hasDirectoryPath {
            let metadataPath = categoryURL.appendingPathComponent("metadata.json")

            if fileManager.fileExists(atPath: metadataPath.path) {
                do {
                    let data = try Data(contentsOf: metadataPath)
                    let fixture = try decoder.decode(FixtureMetadataV2.self, from: data)
                    fixtures.append(fixture)
                } catch {
                    logger.warning("Failed to load fixture at \(categoryURL.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }

        logger.info("Loaded \(fixtures.count) simulator fixtures")
        return fixtures
    }

    // MARK: - Private Helpers

    private func updateManifest(with capture: TrainingTargetCapture) async throws {
        var currentManifest = try await loadManifest()

        let reference = TrainingDatasetManifest.TrainingCaptureReference(
            captureId: capture.id,
            filename: "\(capture.id.uuidString).json",
            captureDate: capture.captureTimestamp,
            holeCount: capture.annotations.count,
            hasBlackRegionHoles: capture.annotations.contains { $0.targetRegion == .black },
            hasOverlappingHoles: capture.annotations.contains { $0.holeCharacteristics.isOverlapping }
        )

        currentManifest.captures.append(reference)
        currentManifest.datasetStats.add(capture.stats)
        currentManifest.lastUpdatedAt = Date()

        let data = try encoder.encode(currentManifest)
        try data.write(to: manifestPath)

        manifest = currentManifest
    }

    private func logCaptureStats(_ capture: TrainingTargetCapture) {
        let stats = capture.stats
        logger.info("""
        📊 ML Training Capture Stats:
           Total holes: \(stats.totalHoles)
           Black region: \(stats.blackRegionHoles)
           White region: \(stats.whiteRegionHoles)
           Torn: \(stats.tornHoles)
           Overlapping: \(stats.overlappingHoles)
           Corrections: \(stats.totalCorrections)
        """)
    }
}

// MARK: - Errors

enum MLTrainingError: Error, LocalizedError {
    case imageEncodingFailed
    case imageLoadFailed
    case manifestNotFound
    case captureNotFound

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            return "Failed to encode image for training data"
        case .imageLoadFailed:
            return "Failed to load training image"
        case .manifestNotFound:
            return "Training data manifest not found"
        case .captureNotFound:
            return "Training capture not found"
        }
    }
}

// MARK: - Evaluation Service

/// Service for evaluating detection results against ground truth
@MainActor
final class DetectionEvaluator {

    /// Evaluate detection results against ground truth annotations
    static func evaluate(
        predictions: [DetectedHole],
        groundTruth: [HoleAnnotation],
        matchTolerance: Double = 0.03,  // 3% of image dimension
        algorithmVersion: String = "2.0.0"
    ) -> DetectionEvaluationResult {
        var truePositives = 0
        var falsePositives = 0
        var matchedGroundTruth = Set<UUID>()

        // Match predictions to ground truth
        for prediction in predictions {
            var matched = false

            for annotation in groundTruth {
                if matchedGroundTruth.contains(annotation.id) { continue }

                let distance = hypot(
                    prediction.position.x - annotation.position.x,
                    prediction.position.y - annotation.position.y
                )

                if distance <= matchTolerance {
                    truePositives += 1
                    matchedGroundTruth.insert(annotation.id)
                    matched = true
                    break
                }
            }

            if !matched {
                falsePositives += 1
            }
        }

        let falseNegatives = groundTruth.count - matchedGroundTruth.count

        // Calculate region-specific metrics
        let blackAnnotations = groundTruth.filter { $0.targetRegion == .black }
        let whiteAnnotations = groundTruth.filter { $0.targetRegion == .white }

        let blackMetrics = calculateRegionMetrics(
            predictions: predictions,
            groundTruth: blackAnnotations,
            matchTolerance: matchTolerance
        )

        let whiteMetrics = calculateRegionMetrics(
            predictions: predictions,
            groundTruth: whiteAnnotations,
            matchTolerance: matchTolerance
        )

        return DetectionEvaluationResult(
            evaluationTimestamp: Date(),
            fixtureId: nil,
            captureId: nil,
            algorithmVersion: algorithmVersion,
            truePositives: truePositives,
            falsePositives: falsePositives,
            falseNegatives: falseNegatives,
            blackRegionMetrics: blackMetrics,
            whiteRegionMetrics: whiteMetrics,
            userCorrections: falsePositives + falseNegatives
        )
    }

    private static func calculateRegionMetrics(
        predictions: [DetectedHole],
        groundTruth: [HoleAnnotation],
        matchTolerance: Double
    ) -> DetectionEvaluationResult.RegionMetrics? {
        guard !groundTruth.isEmpty else { return nil }

        var tp = 0
        var matched = Set<UUID>()

        for prediction in predictions {
            for annotation in groundTruth {
                if matched.contains(annotation.id) { continue }

                let distance = hypot(
                    prediction.position.x - annotation.position.x,
                    prediction.position.y - annotation.position.y
                )

                if distance <= matchTolerance {
                    tp += 1
                    matched.insert(annotation.id)
                    break
                }
            }
        }

        let fn = groundTruth.count - matched.count
        let fp = predictions.count - tp // Simplified for region

        return DetectionEvaluationResult.RegionMetrics(
            truePositives: tp,
            falsePositives: fp,
            falseNegatives: fn
        )
    }
}
