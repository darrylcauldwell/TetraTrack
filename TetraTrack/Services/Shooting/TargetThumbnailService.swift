//
//  TargetThumbnailService.swift
//  TetraTrack
//
//  Manages persistent storage of target thumbnail images for shooting history.
//

import UIKit

/// Service for managing target thumbnail storage
final class TargetThumbnailService {
    static let shared = TargetThumbnailService()

    private let thumbnailsDirectory: URL
    private let maxDimension: CGFloat = 1024
    private let jpegQuality: CGFloat = 0.7

    private init() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            thumbnailsDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ShootingThumbnails", isDirectory: true)
            ensureDirectoryExists()
            return
        }
        thumbnailsDirectory = documentsDirectory.appendingPathComponent("ShootingThumbnails", isDirectory: true)
        ensureDirectoryExists()
    }

    // MARK: - Public API

    /// Save a thumbnail image for a pattern
    /// - Parameters:
    ///   - image: The target image to save
    ///   - patternId: The UUID of the StoredTargetPattern
    /// - Returns: True if save was successful
    @discardableResult
    func saveThumbnail(_ image: UIImage, forPatternId patternId: UUID) -> Bool {
        // Ensure directory exists before every save
        ensureDirectoryExists()

        let resizedImage = resizeImage(image, maxDimension: maxDimension)
        guard let data = resizedImage.jpegData(compressionQuality: jpegQuality) else {
            print("[TargetThumbnailService] Failed to create JPEG data for pattern \(patternId)")
            return false
        }

        let fileURL = thumbnailURL(for: patternId)
        do {
            try data.write(to: fileURL, options: .atomic)
            // Verify the file was written
            let exists = FileManager.default.fileExists(atPath: fileURL.path)
            print("[TargetThumbnailService] Saved thumbnail for \(patternId): \(exists ? "SUCCESS" : "FAILED") at \(fileURL.path)")
            return exists
        } catch {
            print("[TargetThumbnailService] Failed to save thumbnail for \(patternId): \(error)")
            return false
        }
    }

    /// Load a thumbnail image for a pattern
    /// - Parameter patternId: The UUID of the StoredTargetPattern
    /// - Returns: The thumbnail image, or nil if not found
    func loadThumbnail(forPatternId patternId: UUID) -> UIImage? {
        let fileURL = thumbnailURL(for: patternId)
        let exists = FileManager.default.fileExists(atPath: fileURL.path)
        print("[TargetThumbnailService] Loading thumbnail for \(patternId): exists=\(exists) at \(fileURL.path)")

        guard exists else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let image = UIImage(data: data)
            print("[TargetThumbnailService] Loaded thumbnail for \(patternId): \(image != nil ? "SUCCESS" : "FAILED to decode")")
            return image
        } catch {
            print("[TargetThumbnailService] Failed to load thumbnail data for \(patternId): \(error)")
            return nil
        }
    }

    /// Delete a thumbnail for a pattern
    /// - Parameter patternId: The UUID of the StoredTargetPattern
    func deleteThumbnail(forPatternId patternId: UUID) {
        let fileURL = thumbnailURL(for: patternId)
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Check if a thumbnail exists for a pattern
    /// - Parameter patternId: The UUID of the StoredTargetPattern
    /// - Returns: True if thumbnail exists
    func thumbnailExists(forPatternId patternId: UUID) -> Bool {
        let fileURL = thumbnailURL(for: patternId)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// List all saved thumbnail IDs (for debugging)
    func listAllThumbnails() -> [UUID] {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: thumbnailsDirectory, includingPropertiesForKeys: nil)
            return files.compactMap { url -> UUID? in
                let filename = url.deletingPathExtension().lastPathComponent
                return UUID(uuidString: filename)
            }
        } catch {
            print("[TargetThumbnailService] Failed to list thumbnails: \(error)")
            return []
        }
    }

    // MARK: - Private Helpers

    private func ensureDirectoryExists() {
        if !FileManager.default.fileExists(atPath: thumbnailsDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
                print("[TargetThumbnailService] Created thumbnails directory at \(thumbnailsDirectory.path)")
            } catch {
                print("[TargetThumbnailService] Failed to create thumbnails directory: \(error)")
            }
        }
    }

    private func thumbnailURL(for patternId: UUID) -> URL {
        thumbnailsDirectory.appendingPathComponent("\(patternId.uuidString).jpg")
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size

        // Check if resize is needed
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }

        // Calculate new size maintaining aspect ratio
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        // Render resized image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
