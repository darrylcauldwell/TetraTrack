//
//  TargetImageSource.swift
//  TrackRide
//
//  Image source abstraction for shooting target analysis.
//  Supports live camera, photo library, and simulator fixtures.
//

import Foundation
import UIKit
import AVFoundation

// MARK: - Image Source Protocol

/// Abstraction for target image input sources
protocol TargetImageSource {
    /// Source type identifier
    var sourceType: TargetImageSourceType { get }

    /// Acquire an image from this source
    func acquireImage() async throws -> AcquiredTargetImage

    /// Whether this source is available on current device/build
    var isAvailable: Bool { get }
}

/// Types of image sources
enum TargetImageSourceType: String, Codable {
    case liveCamera = "camera"
    case photoLibrary = "library"
    case simulatorFixture = "fixture"
    case fileImport = "file"

    var displayName: String {
        switch self {
        case .liveCamera: return "Camera"
        case .photoLibrary: return "Photo Library"
        case .simulatorFixture: return "Test Fixture"
        case .fileImport: return "Import File"
        }
    }

    var icon: String {
        switch self {
        case .liveCamera: return "camera.fill"
        case .photoLibrary: return "photo.on.rectangle"
        case .simulatorFixture: return "testtube.2"
        case .fileImport: return "doc.badge.plus"
        }
    }
}

// MARK: - Acquired Image

/// Image acquired from any source with metadata
struct AcquiredTargetImage {
    /// The image data
    let image: UIImage

    /// CGImage for processing (computed lazily)
    var cgImage: CGImage? { image.cgImage }

    /// Source type
    let sourceType: TargetImageSourceType

    /// Source identifier (fixture name, asset ID, etc.)
    let sourceIdentifier: String?

    /// Acquisition timestamp
    let acquiredAt: Date

    /// Associated fixture metadata (if from fixture)
    let fixtureMetadata: TargetFixtureMetadata?

    /// Image dimensions
    var size: CGSize { image.size }

    /// Hash for caching
    var imageHash: String {
        // Simple hash based on image data
        guard let data = image.jpegData(compressionQuality: 0.5) else {
            return UUID().uuidString
        }
        var hasher = Hasher()
        hasher.combine(data)
        return String(hasher.finalize())
    }

    init(
        image: UIImage,
        sourceType: TargetImageSourceType,
        sourceIdentifier: String? = nil,
        fixtureMetadata: TargetFixtureMetadata? = nil
    ) {
        self.image = image
        self.sourceType = sourceType
        self.sourceIdentifier = sourceIdentifier
        self.acquiredAt = Date()
        self.fixtureMetadata = fixtureMetadata
    }
}

// MARK: - Live Camera Source

/// Image source from device camera
final class LiveCameraImageSource: TargetImageSource {
    let sourceType: TargetImageSourceType = .liveCamera

    var isAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return AVCaptureDevice.default(for: .video) != nil
        #endif
    }

    private var capturedImage: UIImage?

    /// Set the captured image from camera view
    func setCapturedImage(_ image: UIImage) {
        self.capturedImage = image
    }

    func acquireImage() async throws -> AcquiredTargetImage {
        guard let image = capturedImage else {
            throw ImageSourceError.noImageAvailable
        }
        defer { capturedImage = nil }
        return AcquiredTargetImage(
            image: image,
            sourceType: .liveCamera
        )
    }
}

// MARK: - Photo Library Source

/// Image source from photo library selection
final class PhotoLibraryImageSource: TargetImageSource {
    let sourceType: TargetImageSourceType = .photoLibrary

    var isAvailable: Bool { true }

    private var selectedImage: UIImage?
    private var assetIdentifier: String?

    /// Set the selected image from photo picker
    func setSelectedImage(_ image: UIImage, assetIdentifier: String? = nil) {
        self.selectedImage = image
        self.assetIdentifier = assetIdentifier
    }

    func acquireImage() async throws -> AcquiredTargetImage {
        guard let image = selectedImage else {
            throw ImageSourceError.noImageAvailable
        }
        defer {
            selectedImage = nil
            assetIdentifier = nil
        }
        return AcquiredTargetImage(
            image: image,
            sourceType: .photoLibrary,
            sourceIdentifier: assetIdentifier
        )
    }
}

// MARK: - Simulator Fixture Source

/// Image source from bundled test fixtures
final class SimulatorFixtureImageSource: TargetImageSource {
    let sourceType: TargetImageSourceType = .simulatorFixture

    var isAvailable: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    private var selectedFixture: TargetFixture?

    /// All available fixtures
    var availableFixtures: [TargetFixture] {
        TargetFixtureRegistry.shared.allFixtures
    }

    /// Select a fixture for acquisition
    func selectFixture(_ fixture: TargetFixture) {
        self.selectedFixture = fixture
    }

    /// Select fixture by name
    func selectFixture(named name: String) {
        self.selectedFixture = TargetFixtureRegistry.shared.fixture(named: name)
    }

    func acquireImage() async throws -> AcquiredTargetImage {
        guard let fixture = selectedFixture else {
            throw ImageSourceError.noFixtureSelected
        }

        guard let image = fixture.loadImage() else {
            throw ImageSourceError.fixtureImageLoadFailed(fixture.name)
        }

        defer { selectedFixture = nil }
        return AcquiredTargetImage(
            image: image,
            sourceType: .simulatorFixture,
            sourceIdentifier: fixture.name,
            fixtureMetadata: fixture.metadata
        )
    }
}

// MARK: - Image Source Errors

enum ImageSourceError: LocalizedError {
    case noImageAvailable
    case noFixtureSelected
    case fixtureImageLoadFailed(String)
    case cameraNotAvailable
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .noImageAvailable:
            return "No image available from source"
        case .noFixtureSelected:
            return "No test fixture selected"
        case .fixtureImageLoadFailed(let name):
            return "Failed to load fixture image: \(name)"
        case .cameraNotAvailable:
            return "Camera not available"
        case .permissionDenied:
            return "Permission denied for image source"
        }
    }
}

// MARK: - Image Source Factory

/// Factory for creating appropriate image sources
struct TargetImageSourceFactory {

    /// Get all available sources for current environment
    static func availableSources() -> [TargetImageSource] {
        var sources: [TargetImageSource] = []

        let camera = LiveCameraImageSource()
        if camera.isAvailable {
            sources.append(camera)
        }

        sources.append(PhotoLibraryImageSource())

        #if DEBUG
        sources.append(SimulatorFixtureImageSource())
        #endif

        return sources
    }

    /// Get default source for current environment
    static func defaultSource() -> TargetImageSource {
        #if targetEnvironment(simulator)
        return SimulatorFixtureImageSource()
        #else
        return LiveCameraImageSource()
        #endif
    }

    /// Check if running in simulator
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}
