//
//  Horse.swift
//  TrackRide
//
//  Horse profile model for tracking per-horse statistics and workload

import Foundation
import SwiftData
import UIKit

@Model
final class Horse {
    // All properties have defaults for CloudKit compatibility
    var id: UUID = UUID()
    var name: String = ""
    var breed: String = ""
    var color: String = ""
    var dateOfBirth: Date?
    var weight: Double?  // kg
    var heightHands: Double?  // Height in hands (e.g., 15.2 for 15.2hh)
    var notes: String = ""

    // Legacy photo storage (for backwards compatibility)
    var photoData: Data?  // JPEG compressed for CloudKit

    // Photo reference - stored as PHAsset local identifier (photo stays in Apple Photos)
    var photoAssetIdentifier: String?
    @Attribute(.externalStorage) var photoThumbnail: Data?

    // Video references - stored as PHAsset local identifiers (videos stay in Apple Photos)
    var videoAssetIdentifiers: [String] = []
    @Attribute(.externalStorage) var videoThumbnails: [Data] = []

    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    @Attribute(.spotlight)
    var isArchived: Bool = false  // Soft delete to preserve history

    // Cached transient property (not persisted, avoids repeated UIImage creation)
    @Transient private var _cachedPhoto: UIImage??

    // Relationship to rides - optional for CloudKit
    @Relationship(inverse: \Ride.horse)
    var rides: [Ride]? = []

    // Relationship to competitions
    @Relationship(inverse: \Competition.horse)
    var competitions: [Competition]? = []

    init() {}

    // MARK: - Computed Properties

    /// Calculate age from date of birth
    var age: Int? {
        guard let dob = dateOfBirth else { return nil }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dob, to: Date())
        return ageComponents.year
    }

    /// Formatted age string
    var formattedAge: String {
        guard let age = age else { return "Unknown" }
        return "\(age) \(age == 1 ? "year" : "years")"
    }

    /// Formatted weight string
    var formattedWeight: String {
        guard let weight = weight else { return "Not set" }
        return String(format: "%.0f kg", weight)
    }

    /// Formatted height string
    var formattedHeight: String {
        guard let height = heightHands else { return "Not set" }
        let hands = Int(height)
        // Use round() to avoid floating-point precision issues (e.g., 14.2 displaying as 14.1)
        let inches = Int(round((height - Double(hands)) * 10))
        return "\(hands).\(inches)hh"
    }

    /// Get recommended pole spacings for this horse
    var poleSpacings: PoleSpacings? {
        guard let height = heightHands else { return nil }
        return PoleSpacingCalculator.recommendedSpacings(forHeightHands: height)
    }

    /// Get all active (non-archived) rides
    var activeRides: [Ride] {
        rides ?? []
    }

    /// Total number of rides
    var rideCount: Int {
        activeRides.count
    }

    /// Total distance across all rides (meters)
    var totalDistance: Double {
        activeRides.reduce(0) { $0 + $1.totalDistance }
    }

    /// Total duration across all rides (seconds)
    var totalDuration: TimeInterval {
        activeRides.reduce(0) { $0 + $1.totalDuration }
    }

    /// Formatted total distance
    var formattedTotalDistance: String {
        let km = totalDistance / 1000.0
        if km < 1 {
            return String(format: "%.0f m", totalDistance)
        }
        return String(format: "%.1f km", km)
    }

    /// Formatted total duration
    var formattedTotalDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        }
        return String(format: "%d min", minutes)
    }

    /// Most recent ride
    var lastRide: Ride? {
        activeRides.max { $0.startDate < $1.startDate }
    }

    /// Days since last ride
    var daysSinceLastRide: Int? {
        guard let lastRide = lastRide else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: lastRide.startDate, to: Date())
        return components.day
    }

    /// Formatted days since last ride
    var formattedLastRide: String {
        guard let days = daysSinceLastRide else { return "No rides yet" }
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        return "\(days) days ago"
    }

    // MARK: - Photo Helpers

    /// Set photo from UIImage (compresses to JPEG) - Legacy method
    func setPhoto(_ image: UIImage?) {
        // Invalidate cache
        _cachedPhoto = nil

        guard let image = image else {
            photoData = nil
            return
        }
        // Compress to reasonable size for CloudKit
        photoData = image.jpegData(compressionQuality: 0.7)
        // Cache the new image
        _cachedPhoto = .some(image)
        updatedAt = Date()
    }

    /// Get photo as UIImage (cached to avoid repeated UIImage creation)
    /// Checks thumbnail first (from Apple Photos), then falls back to legacy photoData
    var photo: UIImage? {
        // Return cached value if available
        if let cached = _cachedPhoto {
            return cached
        }
        // First try thumbnail from Apple Photos link
        if let thumbnailData = photoThumbnail, let image = UIImage(data: thumbnailData) {
            _cachedPhoto = .some(image)
            return image
        }
        // Fall back to legacy embedded photo data
        guard let data = photoData else {
            _cachedPhoto = .some(nil)
            return nil
        }
        let image = UIImage(data: data)
        _cachedPhoto = .some(image)
        return image
    }

    /// Check if horse has any photo (either Apple Photos link or legacy data)
    var hasPhoto: Bool {
        photoAssetIdentifier != nil || photoData != nil || photoThumbnail != nil
    }

    /// Check if horse has any videos
    var hasVideos: Bool {
        !videoAssetIdentifiers.isEmpty
    }

    /// Check if horse has any media (photo or videos)
    var hasMedia: Bool {
        hasPhoto || hasVideos
    }
}
