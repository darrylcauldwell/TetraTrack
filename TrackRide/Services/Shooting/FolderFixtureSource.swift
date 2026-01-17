//
//  FolderFixtureSource.swift
//  TrackRide
//
//  Folder-based fixture source for loading test target images from directories.
//  Supports both bundled resources and user-provided images in Documents.
//

import Foundation
import UIKit

// MARK: - Folder Fixture Source

/// Image source that loads test fixtures from folder structures
final class FolderFixtureSource: TargetImageSource {
    let sourceType: TargetImageSourceType = .simulatorFixture

    var isAvailable: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    private var selectedImage: FolderFixtureImage?
    private var loadedFolder: FixtureFolder?

    /// Currently loaded folder
    var currentFolder: FixtureFolder? { loadedFolder }

    /// All available fixture folders
    var availableFolders: [FixtureFolder] {
        var folders: [FixtureFolder] = []

        // 1. Bundled simulator targets
        if let bundledFolders = loadBundledFolders() {
            folders.append(contentsOf: bundledFolders)
        }

        // 2. User-provided folders in Documents
        if let userFolders = loadUserFolders() {
            folders.append(contentsOf: userFolders)
        }

        return folders
    }

    /// Load a specific folder
    func loadFolder(_ folder: FixtureFolder) {
        self.loadedFolder = folder
    }

    /// Load folder by path
    func loadFolder(at path: URL) throws {
        let folder = try FixtureFolder(url: path)
        self.loadedFolder = folder
    }

    /// Select an image from the current folder
    func selectImage(_ image: FolderFixtureImage) {
        self.selectedImage = image
    }

    /// Select image by index
    func selectImage(at index: Int) {
        guard let folder = loadedFolder,
              index >= 0 && index < folder.images.count else {
            return
        }
        self.selectedImage = folder.images[index]
    }

    func acquireImage() async throws -> AcquiredTargetImage {
        guard let image = selectedImage else {
            throw ImageSourceError.noFixtureSelected
        }

        guard let uiImage = image.loadImage() else {
            throw ImageSourceError.fixtureImageLoadFailed(image.filename)
        }

        defer { selectedImage = nil }

        // Convert folder metadata to fixture metadata if available
        let fixtureMetadata = image.metadata.map { folderMeta -> TargetFixtureMetadata in
            let lightingCondition = parseLightingCondition(folderMeta.lightingCondition)
            let cropBounds = folderMeta.cropBounds.map {
                TargetFixtureMetadata.CropBounds(x: $0.x, y: $0.y, width: $0.width, height: $0.height)
            }

            return TargetFixtureMetadata(
                targetType: folderMeta.targetType ?? "tetrathlon",
                knownCropBounds: cropBounds,
                knownTargetCenter: nil,
                knownSemiAxes: nil,
                rotationDegrees: folderMeta.rotationDegrees ?? 0,
                perspectiveSkew: folderMeta.perspectiveSkew ?? 0,
                lightingCondition: lightingCondition,
                expectedHoleCount: folderMeta.expectedHoleCount ?? 0,
                goldenMasterShots: folderMeta.goldenMasterShots ?? [],
                expectedAnalysis: folderMeta.expectedAnalysis,
                expectedQuality: nil,
                description: folderMeta.description ?? image.filename,
                difficulty: folderMeta.difficulty ?? 3
            )
        }

        func parseLightingCondition(_ string: String?) -> TargetFixtureMetadata.LightingCondition {
            guard let string = string else { return .ideal }
            return TargetFixtureMetadata.LightingCondition(rawValue: string) ?? .ideal
        }

        return AcquiredTargetImage(
            image: uiImage,
            sourceType: .simulatorFixture,
            sourceIdentifier: image.filename,
            fixtureMetadata: fixtureMetadata
        )
    }

    // MARK: - Folder Discovery

    private func loadBundledFolders() -> [FixtureFolder]? {
        guard let resourceURL = Bundle.main.resourceURL else { return nil }

        let simulatorTargetsURL = resourceURL.appendingPathComponent("SimulatorTargets")

        guard FileManager.default.fileExists(atPath: simulatorTargetsURL.path) else {
            return nil
        }

        return discoverFolders(in: simulatorTargetsURL, source: .bundled)
    }

    private func loadUserFolders() -> [FixtureFolder]? {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let userTargetsURL = documentsURL.appendingPathComponent("SimulatorTargets")

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: userTargetsURL.path) {
            try? FileManager.default.createDirectory(at: userTargetsURL, withIntermediateDirectories: true)
        }

        return discoverFolders(in: userTargetsURL, source: .userProvided)
    }

    private func discoverFolders(in baseURL: URL, source: FixtureFolder.Source) -> [FixtureFolder] {
        var folders: [FixtureFolder] = []

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return folders
        }

        for url in contents {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                if let folder = try? FixtureFolder(url: url, source: source) {
                    folders.append(folder)
                }
            }
        }

        // Also check if base folder itself contains images
        if let baseFolder = try? FixtureFolder(url: baseURL, source: source),
           !baseFolder.images.isEmpty {
            folders.insert(baseFolder, at: 0)
        }

        return folders
    }
}

// MARK: - Fixture Folder

/// Represents a folder containing test fixture images
struct FixtureFolder: Identifiable {
    let id: String
    let name: String
    let url: URL
    let source: Source
    let images: [FolderFixtureImage]
    let metadata: FolderMetadata?

    enum Source: String {
        case bundled
        case userProvided
    }

    init(url: URL, source: Source = .userProvided) throws {
        self.url = url
        self.source = source
        self.name = url.lastPathComponent
        self.id = "\(source.rawValue)_\(name)"

        // Load metadata if exists
        let metadataURL = url.appendingPathComponent("metadata.json")
        if FileManager.default.fileExists(atPath: metadataURL.path),
           let data = try? Data(contentsOf: metadataURL) {
            self.metadata = try? JSONDecoder().decode(FolderMetadata.self, from: data)
        } else {
            self.metadata = nil
        }

        // Discover images
        self.images = Self.discoverImages(in: url, folderMetadata: metadata)
    }

    private static func discoverImages(in url: URL, folderMetadata: FolderMetadata?) -> [FolderFixtureImage] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let imageExtensions = ["jpg", "jpeg", "png", "heic"]

        var images: [FolderFixtureImage] = []

        for fileURL in contents {
            let ext = fileURL.pathExtension.lowercased()
            guard imageExtensions.contains(ext) else { continue }

            let filename = fileURL.lastPathComponent

            // Look up metadata for this image
            let imageMetadata = folderMetadata?.images?[filename]

            images.append(FolderFixtureImage(
                url: fileURL,
                filename: filename,
                metadata: imageMetadata
            ))
        }

        // Sort by filename (which includes date if following convention)
        return images.sorted { $0.filename < $1.filename }
    }

    /// Display name for UI
    var displayName: String {
        metadata?.displayName ?? name.replacingOccurrences(of: "_", with: " ").capitalized
    }

    /// Description from metadata
    var description: String? {
        metadata?.description
    }

    /// Image count
    var imageCount: Int { images.count }
}

// MARK: - Folder Fixture Image

/// Represents a single test fixture image from a folder
struct FolderFixtureImage: Identifiable {
    let id: String
    let url: URL
    let filename: String
    let metadata: ImageMetadata?

    init(url: URL, filename: String, metadata: ImageMetadata? = nil) {
        self.url = url
        self.filename = filename
        self.metadata = metadata
        self.id = filename
    }

    /// Load the image
    func loadImage() -> UIImage? {
        UIImage(contentsOfFile: url.path)
    }

    /// Parse date from filename if following convention: target_YYYYMMDD_##.jpg
    var captureDate: Date? {
        let pattern = #"target_(\d{8})_\d+"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: filename, range: NSRange(filename.startIndex..., in: filename)),
              let dateRange = Range(match.range(at: 1), in: filename) else {
            return nil
        }

        let dateString = String(filename[dateRange])
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.date(from: dateString)
    }

    /// Display name without extension
    var displayName: String {
        metadata?.displayName ?? URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
    }
}

// MARK: - Folder Metadata Schema

/// Metadata for a folder of test fixtures (metadata.json)
struct FolderMetadata: Codable {
    /// Display name for the folder
    let displayName: String?

    /// Description of this test set
    let description: String?

    /// Default target type for images in this folder
    let defaultTargetType: String?

    /// Default lighting condition
    let defaultLighting: String?

    /// Capture conditions
    let captureConditions: CaptureConditions?

    /// Per-image metadata keyed by filename
    let images: [String: ImageMetadata]?

    struct CaptureConditions: Codable {
        let date: String?
        let location: String?
        let camera: String?
        let flash: Bool?
        let notes: String?
    }
}

/// Metadata for a single image within a folder
struct ImageMetadata: Codable {
    /// Display name
    let displayName: String?

    /// Description
    let description: String?

    /// Target type override
    let targetType: String?

    /// Expected number of holes
    let expectedHoleCount: Int?

    /// Crop bounds (normalized 0-1)
    let cropBounds: FolderCropBounds?

    /// Rotation in degrees
    let rotationDegrees: Double?

    /// Perspective skew factor
    let perspectiveSkew: Double?

    /// Lighting condition (string: "ideal", "shadows", "uneven", "overexposed", "underexposed")
    let lightingCondition: String?

    /// Difficulty rating 1-5
    let difficulty: Int?

    /// Golden master hole positions
    let goldenMasterShots: [GoldenMasterShot]?

    /// Expected pattern analysis results
    let expectedAnalysis: ExpectedPatternAnalysis?

    /// Quality assessment results (can be auto-populated)
    var qualityAssessment: StoredQualityAssessment?

    /// Notes about this specific image
    let notes: String?
}

/// Crop bounds for folder metadata (avoids CGRect Codable issues)
struct FolderCropBounds: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

/// Stored quality assessment results
struct StoredQualityAssessment: Codable {
    let sharpness: Double
    let contrast: Double
    let brightness: Double
    let darkAreaVisibility: Double?
    let exposure: String
    let overallScore: Double
    let assessedAt: Date
    let warnings: [String]?
}

// MARK: - CGRect Codable Extension

extension CGRect: @retroactive Codable {
    enum CodingKeys: String, CodingKey {
        case x, y, width, height
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        self.init(x: x, y: y, width: width, height: height)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(origin.x, forKey: .x)
        try container.encode(origin.y, forKey: .y)
        try container.encode(size.width, forKey: .width)
        try container.encode(size.height, forKey: .height)
    }
}

// MARK: - Metadata Writer

/// Utility for writing metadata.json files
struct FolderMetadataWriter {

    /// Write metadata to a folder
    static func write(_ metadata: FolderMetadata, to folderURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(metadata)
        let metadataURL = folderURL.appendingPathComponent("metadata.json")
        try data.write(to: metadataURL)
    }

    /// Create a template metadata file for a folder
    static func createTemplate(for folder: FixtureFolder) throws {
        var images: [String: ImageMetadata] = [:]

        for image in folder.images {
            images[image.filename] = ImageMetadata(
                displayName: image.displayName,
                description: nil,
                targetType: nil,
                expectedHoleCount: nil,
                cropBounds: nil,
                rotationDegrees: nil,
                perspectiveSkew: nil,
                lightingCondition: nil,
                difficulty: nil,
                goldenMasterShots: nil,
                expectedAnalysis: nil,
                qualityAssessment: nil,
                notes: nil
            )
        }

        let metadata = FolderMetadata(
            displayName: folder.name.replacingOccurrences(of: "_", with: " ").capitalized,
            description: "Test fixture images",
            defaultTargetType: "tetrathlon",
            defaultLighting: "normal",
            captureConditions: FolderMetadata.CaptureConditions(
                date: ISO8601DateFormatter().string(from: Date()),
                location: nil,
                camera: nil,
                flash: nil,
                notes: nil
            ),
            images: images
        )

        try write(metadata, to: folder.url)
    }

    /// Update quality assessment for an image in metadata
    static func updateQualityAssessment(
        for imageFilename: String,
        assessment: StoredQualityAssessment,
        in folderURL: URL
    ) throws {
        let metadataURL = folderURL.appendingPathComponent("metadata.json")

        var metadata: FolderMetadata
        if FileManager.default.fileExists(atPath: metadataURL.path),
           let data = try? Data(contentsOf: metadataURL),
           let existing = try? JSONDecoder().decode(FolderMetadata.self, from: data) {
            metadata = existing
        } else {
            metadata = FolderMetadata(
                displayName: nil,
                description: nil,
                defaultTargetType: nil,
                defaultLighting: nil,
                captureConditions: nil,
                images: [:]
            )
        }

        var images = metadata.images ?? [:]
        var imageMetadata = images[imageFilename] ?? ImageMetadata(
            displayName: nil,
            description: nil,
            targetType: nil,
            expectedHoleCount: nil,
            cropBounds: nil,
            rotationDegrees: nil,
            perspectiveSkew: nil,
            lightingCondition: nil,
            difficulty: nil,
            goldenMasterShots: nil,
            expectedAnalysis: nil,
            qualityAssessment: nil,
            notes: nil
        )

        // Create new metadata with updated quality assessment
        imageMetadata = ImageMetadata(
            displayName: imageMetadata.displayName,
            description: imageMetadata.description,
            targetType: imageMetadata.targetType,
            expectedHoleCount: imageMetadata.expectedHoleCount,
            cropBounds: imageMetadata.cropBounds,
            rotationDegrees: imageMetadata.rotationDegrees,
            perspectiveSkew: imageMetadata.perspectiveSkew,
            lightingCondition: imageMetadata.lightingCondition,
            difficulty: imageMetadata.difficulty,
            goldenMasterShots: imageMetadata.goldenMasterShots,
            expectedAnalysis: imageMetadata.expectedAnalysis,
            qualityAssessment: assessment,
            notes: imageMetadata.notes
        )

        images[imageFilename] = imageMetadata

        let updatedMetadata = FolderMetadata(
            displayName: metadata.displayName,
            description: metadata.description,
            defaultTargetType: metadata.defaultTargetType,
            defaultLighting: metadata.defaultLighting,
            captureConditions: metadata.captureConditions,
            images: images
        )

        try write(updatedMetadata, to: folderURL)
    }
}
