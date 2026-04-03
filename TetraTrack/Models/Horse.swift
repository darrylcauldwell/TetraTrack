//
//  Horse.swift
//  TetraTrack
//
//  Horse profile model for tracking per-horse statistics and workload

import Foundation
import SwiftData
import TetraTrackShared
import UIKit

// MARK: - Horse Breed Enum

/// Horse breed categories with biomechanical characteristics
enum HorseBreed: String, Codable, CaseIterable, Identifiable {
    // Ponies (under 14.2hh typically)
    case shetland = "Shetland"
    case welshA = "Welsh Section A"
    case welshB = "Welsh Section B"
    case welshC = "Welsh Section C"
    case welshD = "Welsh Section D"
    case connemara = "Connemara"
    case newForest = "New Forest"
    case dartmoor = "Dartmoor"
    case exmoor = "Exmoor"
    case highland = "Highland"
    case fell = "Fell"
    case dales = "Dales"

    // Sport Horses
    case thoroughbred = "Thoroughbred"
    case warmblood = "Warmblood"
    case irishSportHorse = "Irish Sport Horse"
    case hanoverian = "Hanoverian"
    case holsteiner = "Holsteiner"
    case oldenburg = "Oldenburg"
    case trakehner = "Trakehner"
    case dutchWarmblood = "Dutch Warmblood"
    case selleFrancais = "Selle Francais"
    case quarterHorse = "Quarter Horse"

    // Heavy/Draft Types
    case cob = "Cob"
    case irishDraught = "Irish Draught"
    case friesian = "Friesian"

    // Other Breeds
    case arabian = "Arabian"
    case andalusian = "Andalusian"
    case lusitano = "Lusitano"
    case appaloosa = "Appaloosa"
    case morgan = "Morgan"
    case trotter = "Trotter"

    // Generic
    case unknown = "Unknown"
    case mixed = "Mixed/Other"

    var id: String { rawValue }

    /// Biomechanical priors for this breed
    var biomechanicalPriors: BiomechanicalPriors {
        switch self {
        // Small ponies: higher stride frequencies, shorter strides
        case .shetland, .welshA, .dartmoor, .exmoor:
            return BiomechanicalPriors(
                walkFrequencyRange: 1.3...2.5,
                trotFrequencyRange: 2.8...4.5,
                canterFrequencyRange: 2.2...3.5,
                gallopFrequencyRange: 3.5...6.5,
                strideCoefficients: StrideCoefficients(walk: 2.0, trot: 2.4, canter: 2.9, gallop: 3.5),
                typicalWeight: 200,
                typicalHeight: 11.5
            )

        // Medium ponies
        case .welshB, .welshC, .newForest, .connemara:
            return BiomechanicalPriors(
                walkFrequencyRange: 1.2...2.4,
                trotFrequencyRange: 2.4...4.2,
                canterFrequencyRange: 2.0...3.3,
                gallopFrequencyRange: 3.2...6.0,
                strideCoefficients: StrideCoefficients(walk: 2.1, trot: 2.5, canter: 3.0, gallop: 3.6),
                typicalWeight: 350,
                typicalHeight: 13.5
            )

        // Large ponies / small horses
        case .welshD, .highland, .fell, .dales:
            return BiomechanicalPriors(
                walkFrequencyRange: 1.1...2.3,
                trotFrequencyRange: 2.2...4.0,
                canterFrequencyRange: 1.9...3.2,
                gallopFrequencyRange: 3.1...5.8,
                strideCoefficients: StrideCoefficients(walk: 2.15, trot: 2.6, canter: 3.1, gallop: 3.7),
                typicalWeight: 450,
                typicalHeight: 14.2
            )

        // Warmbloods: lower frequencies, longer strides
        case .warmblood, .hanoverian, .holsteiner, .oldenburg, .trakehner, .dutchWarmblood, .selleFrancais:
            return BiomechanicalPriors(
                walkFrequencyRange: 0.9...2.0,
                trotFrequencyRange: 1.8...3.5,
                canterFrequencyRange: 1.6...2.8,
                gallopFrequencyRange: 2.8...5.5,
                strideCoefficients: StrideCoefficients(walk: 2.3, trot: 2.8, canter: 3.4, gallop: 4.1),
                typicalWeight: 550,
                typicalHeight: 16.2
            )

        // Thoroughbreds: intermediate, optimized for speed
        case .thoroughbred:
            return BiomechanicalPriors(
                walkFrequencyRange: 1.0...2.2,
                trotFrequencyRange: 2.0...3.8,
                canterFrequencyRange: 1.8...3.0,
                gallopFrequencyRange: 3.0...6.0,
                strideCoefficients: StrideCoefficients(walk: 2.2, trot: 2.7, canter: 3.3, gallop: 4.0),
                typicalWeight: 500,
                typicalHeight: 16.0
            )

        // Irish Sport Horse
        case .irishSportHorse:
            return BiomechanicalPriors(
                walkFrequencyRange: 0.95...2.1,
                trotFrequencyRange: 1.9...3.6,
                canterFrequencyRange: 1.7...2.9,
                gallopFrequencyRange: 2.9...5.8,
                strideCoefficients: StrideCoefficients(walk: 2.25, trot: 2.75, canter: 3.35, gallop: 4.05),
                typicalWeight: 530,
                typicalHeight: 16.1
            )

        // Quarter Horse: compact, quick
        case .quarterHorse:
            return BiomechanicalPriors(
                walkFrequencyRange: 1.0...2.2,
                trotFrequencyRange: 2.0...3.8,
                canterFrequencyRange: 1.8...3.0,
                gallopFrequencyRange: 3.0...6.2,
                strideCoefficients: StrideCoefficients(walk: 2.1, trot: 2.6, canter: 3.2, gallop: 3.9),
                typicalWeight: 480,
                typicalHeight: 15.0
            )

        // Heavy types: slower, more powerful
        case .cob, .irishDraught, .friesian:
            return BiomechanicalPriors(
                walkFrequencyRange: 0.9...2.0,
                trotFrequencyRange: 1.8...3.2,
                canterFrequencyRange: 1.5...2.7,
                gallopFrequencyRange: 2.6...5.0,
                strideCoefficients: StrideCoefficients(walk: 2.15, trot: 2.6, canter: 3.15, gallop: 3.8),
                typicalWeight: 600,
                typicalHeight: 15.3
            )

        // Arabian: light, animated
        case .arabian:
            return BiomechanicalPriors(
                walkFrequencyRange: 1.1...2.3,
                trotFrequencyRange: 2.2...4.0,
                canterFrequencyRange: 1.9...3.2,
                gallopFrequencyRange: 3.1...6.0,
                strideCoefficients: StrideCoefficients(walk: 2.1, trot: 2.55, canter: 3.1, gallop: 3.8),
                typicalWeight: 450,
                typicalHeight: 15.0
            )

        // Iberian breeds: collected, elevated
        case .andalusian, .lusitano:
            return BiomechanicalPriors(
                walkFrequencyRange: 1.0...2.2,
                trotFrequencyRange: 2.0...3.6,
                canterFrequencyRange: 1.7...2.9,
                gallopFrequencyRange: 2.8...5.5,
                strideCoefficients: StrideCoefficients(walk: 2.15, trot: 2.6, canter: 3.2, gallop: 3.85),
                typicalWeight: 500,
                typicalHeight: 15.2
            )

        // Other breeds / defaults
        case .appaloosa, .morgan, .trotter, .unknown, .mixed:
            return .default
        }
    }

    /// Display name for picker/UI
    var displayName: String { rawValue }

    /// Category for grouping in pickers
    var category: BreedCategory {
        switch self {
        case .shetland, .welshA, .welshB, .welshC, .welshD, .connemara, .newForest, .dartmoor, .exmoor, .highland, .fell, .dales:
            return .pony
        case .thoroughbred, .warmblood, .irishSportHorse, .hanoverian, .holsteiner, .oldenburg, .trakehner, .dutchWarmblood, .selleFrancais, .quarterHorse:
            return .sportHorse
        case .cob, .irishDraught, .friesian:
            return .heavyType
        case .arabian, .andalusian, .lusitano, .appaloosa, .morgan, .trotter:
            return .otherBreed
        case .unknown, .mixed:
            return .other
        }
    }
}

/// Breed category for grouping
enum BreedCategory: String, CaseIterable {
    case pony = "Ponies"
    case sportHorse = "Sport Horses"
    case heavyType = "Heavy Types"
    case otherBreed = "Other Breeds"
    case other = "Other"
}

@Model
final class Horse {
    // All properties have defaults for CloudKit compatibility
    var id: UUID = UUID()
    var name: String = ""
    var breed: String = ""  // Legacy free-form breed string
    var breedType: String = HorseBreed.unknown.rawValue  // Typed breed for biomechanics
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

    // MARK: - Gait Detection Tuning Parameters
    // User-adjustable parameters to fine-tune gait detection for this specific horse

    /// Frequency offset for gait detection (-0.5 to +0.5 Hz)
    /// Positive = horse has higher stride frequency than breed average
    /// Negative = horse has lower stride frequency than breed average
    var gaitFrequencyOffset: Double = 0.0

    /// Speed sensitivity adjustment (-0.5 to +0.5)
    /// Positive = horse transitions to faster gaits at lower speeds
    /// Negative = horse transitions to faster gaits at higher speeds
    var gaitSpeedSensitivity: Double = 0.0

    /// Transition responsiveness (0.5 to 1.5, default 1.0)
    /// Higher = faster gait transitions, Lower = more stable/slower transitions
    var gaitTransitionSpeed: Double = 1.0

    /// Canter detection sensitivity (0.5 to 1.5, default 1.0)
    /// Higher = more likely to detect canter, Lower = requires clearer canter signal
    var canterSensitivity: Double = 1.0

    /// Walk/Trot threshold adjustment (-1.0 to +1.0 m/s)
    /// Positive = higher speed needed to transition from walk to trot
    var walkTrotThreshold: Double = 0.0

    /// Trot/Canter threshold adjustment (-1.0 to +1.0 m/s)
    /// Positive = higher speed needed to transition from trot to canter
    var trotCanterThreshold: Double = 0.0

    /// Whether user has customized gait detection for this horse
    var hasCustomGaitSettings: Bool = false

    /// Encoded learned gait parameters (updated after each ride)
    var learnedGaitParametersData: Data?

    // Cached transient property (not persisted, avoids repeated UIImage creation)
    @Transient private var _cachedPhoto: UIImage??

    // Relationship to rides - optional for CloudKit
    @Relationship
    var rides: [Ride]? = []

    // Relationship to competitions
    @Relationship
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

    /// Horse size category derived from height (for polework calculations)
    /// Returns .average if height is not set
    var horseSize: HorseSize {
        guard let height = heightHands else { return .average }
        return HorseSize.fromHeight(height)
    }

    /// Whether this horse has height set (needed for accurate polework distances)
    var hasHeightSet: Bool {
        heightHands != nil
    }

    // MARK: - Biomechanics

    /// Typed breed for biomechanical analysis
    var typedBreed: HorseBreed {
        get { HorseBreed(rawValue: breedType) ?? .unknown }
        set { breedType = newValue.rawValue }
    }

    // Gait tuning computed properties and methods removed — riding is Watch-primary (#307)
    // Persisted fields (gaitFrequencyOffset etc.) kept for CloudKit backward compat

    // Gait computation methods (ageAdjustmentFactor, computeStrideLength, etc.)
    // removed — riding is Watch-primary (#307)

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
