//
//  PoleStrideCalculator.swift
//  TrackRide
//
//  Calculates pole distances based on horse size, gait, and exercise type
//

import Foundation

// MARK: - Horse Size Categories

enum HorseSize: String, Codable, CaseIterable, Identifiable {
    case small = "small"           // Under 14.2hh (ponies)
    case medium = "medium"         // 14.2-15.2hh
    case average = "average"       // 15.2-16.2hh (most common)
    case large = "large"           // 16.2-17hh
    case extraLarge = "extraLarge" // Over 17hh (warmbloods, drafts)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: return "Small (under 14.2hh)"
        case .medium: return "Medium (14.2-15.2hh)"
        case .average: return "Average (15.2-16.2hh)"
        case .large: return "Large (16.2-17hh)"
        case .extraLarge: return "Extra Large (17hh+)"
        }
    }

    var shortName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .average: return "Average"
        case .large: return "Large"
        case .extraLarge: return "X-Large"
        }
    }

    /// Stride multiplier relative to average horse
    var strideMultiplier: Double {
        switch self {
        case .small: return 0.85
        case .medium: return 0.92
        case .average: return 1.0
        case .large: return 1.08
        case .extraLarge: return 1.15
        }
    }

    /// Initialize from horse height in hands
    static func fromHeight(_ heightHands: Double) -> HorseSize {
        switch heightHands {
        case ..<14.2: return .small
        case 14.2..<15.2: return .medium
        case 15.2..<16.2: return .average
        case 16.2..<17.0: return .large
        default: return .extraLarge
        }
    }
}

// MARK: - Pole Exercise Type

enum PoleExerciseType: String, Codable, CaseIterable, Identifiable {
    case walkPoles = "walkPoles"
    case trotPoles = "trotPoles"
    case canterPoles = "canterPoles"
    case raisedTrotPoles = "raisedTrotPoles"
    case raisedCanterPoles = "raisedCanterPoles"
    case cavaletti = "cavaletti"
    case bounce = "bounce"
    case oneStride = "oneStride"
    case twoStride = "twoStride"
    case grid = "grid"
    case fanPoles = "fanPoles"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .walkPoles: return "Walk Poles"
        case .trotPoles: return "Trot Poles"
        case .canterPoles: return "Canter Poles"
        case .raisedTrotPoles: return "Raised Trot Poles"
        case .raisedCanterPoles: return "Raised Canter Poles"
        case .cavaletti: return "Cavaletti"
        case .bounce: return "Bounce"
        case .oneStride: return "One Stride"
        case .twoStride: return "Two Stride"
        case .grid: return "Gymnastic Grid"
        case .fanPoles: return "Fan Poles"
        }
    }

    var icon: String {
        switch self {
        case .walkPoles: return "figure.walk"
        case .trotPoles, .raisedTrotPoles: return "gauge.with.dots.needle.33percent"
        case .canterPoles, .raisedCanterPoles: return "gauge.with.dots.needle.67percent"
        case .cavaletti: return "square.stack.3d.up"
        case .bounce: return "arrow.up.arrow.down"
        case .oneStride, .twoStride: return "arrow.forward"
        case .grid: return "square.grid.3x3"
        case .fanPoles: return "circle.lefthalf.filled"
        }
    }
}

// MARK: - Pole Stride Calculator

struct PoleStrideCalculator {

    // MARK: - Base Distances (for average 15.2-16.2hh horse) in metres

    /// Base distances for ground poles at different gaits
    private static let baseDistances: [PoleExerciseType: Double] = [
        .walkPoles: 0.90,          // 3 feet
        .trotPoles: 1.35,          // 4.5 feet
        .canterPoles: 3.00,        // 10 feet
        .raisedTrotPoles: 1.40,    // Slightly longer for raised
        .raisedCanterPoles: 3.20,  // Slightly longer for raised
        .cavaletti: 1.35,          // Same as trot poles
        .bounce: 3.35,             // 11 feet (no stride between)
        .oneStride: 7.30,          // 24 feet (one canter stride)
        .twoStride: 10.35,         // 34 feet (two canter strides)
        .grid: 3.35,               // Default grid spacing (bounce)
        .fanPoles: 1.35            // Inner distance for fan
    ]

    // MARK: - Public Methods

    /// Calculate pole distance for a specific horse size and exercise type
    static func distance(
        for exerciseType: PoleExerciseType,
        horseSize: HorseSize,
        adjustmentPercent: Double = 0
    ) -> Double {
        let baseDistance = baseDistances[exerciseType] ?? 1.35
        let sizeAdjusted = baseDistance * horseSize.strideMultiplier
        let finalAdjustment = 1.0 + (adjustmentPercent / 100.0)
        return sizeAdjusted * finalAdjustment
    }

    /// Get distance formatted in both metres and feet
    static func formattedDistance(
        for exerciseType: PoleExerciseType,
        horseSize: HorseSize,
        adjustmentPercent: Double = 0
    ) -> (metres: String, feet: String) {
        let metres = distance(for: exerciseType, horseSize: horseSize, adjustmentPercent: adjustmentPercent)
        let feet = metres * 3.28084

        return (
            metres: String(format: "%.2fm", metres),
            feet: String(format: "%.1fft", feet)
        )
    }

    /// Get a range of acceptable distances (min to max)
    static func distanceRange(
        for exerciseType: PoleExerciseType,
        horseSize: HorseSize
    ) -> (min: Double, max: Double) {
        let base = distance(for: exerciseType, horseSize: horseSize)
        // Generally +/- 10% is acceptable
        return (min: base * 0.9, max: base * 1.1)
    }

    /// Calculate fan pole distances (inner, middle, outer)
    static func fanPoleDistances(
        horseSize: HorseSize,
        gait: FlatworkGait = .trot
    ) -> (inner: Double, middle: Double, outer: Double) {
        let baseGait: PoleExerciseType = gait == .canter ? .canterPoles : .trotPoles
        let middleDistance = distance(for: baseGait, horseSize: horseSize)

        return (
            inner: middleDistance * 0.7,   // 70% at inner edge
            middle: middleDistance,         // 100% at middle
            outer: middleDistance * 1.3    // 130% at outer edge
        )
    }

    /// Calculate grid spacing for gymnastics
    static func gridSpacing(
        elements: [GridElement],
        horseSize: HorseSize
    ) -> [Double] {
        return elements.compactMap { element -> Double? in
            switch element {
            case .bounce:
                return distance(for: .bounce, horseSize: horseSize)
            case .oneStride:
                return distance(for: .oneStride, horseSize: horseSize)
            case .twoStride:
                return distance(for: .twoStride, horseSize: horseSize)
            case .pole:
                return nil // Poles don't have distances to next element by themselves
            case .fence:
                return nil
            }
        }
    }

    /// Get all distances for a horse size (for display)
    static func allDistances(for horseSize: HorseSize) -> [(type: PoleExerciseType, metres: Double, feet: Double)] {
        return PoleExerciseType.allCases.map { type in
            let metres = distance(for: type, horseSize: horseSize)
            let feet = metres * 3.28084
            return (type: type, metres: metres, feet: feet)
        }
    }

    /// Quick reference card data
    static func quickReferenceCard(for horseSize: HorseSize) -> QuickReferenceCard {
        return QuickReferenceCard(
            horseSize: horseSize,
            walkPoles: formattedDistance(for: .walkPoles, horseSize: horseSize),
            trotPoles: formattedDistance(for: .trotPoles, horseSize: horseSize),
            canterPoles: formattedDistance(for: .canterPoles, horseSize: horseSize),
            bounce: formattedDistance(for: .bounce, horseSize: horseSize),
            oneStride: formattedDistance(for: .oneStride, horseSize: horseSize),
            twoStride: formattedDistance(for: .twoStride, horseSize: horseSize)
        )
    }
}

// MARK: - Grid Elements

enum GridElement: String, Codable, CaseIterable {
    case pole = "pole"
    case fence = "fence"
    case bounce = "bounce"
    case oneStride = "oneStride"
    case twoStride = "twoStride"

    var displayName: String {
        switch self {
        case .pole: return "Ground Pole"
        case .fence: return "Fence"
        case .bounce: return "Bounce"
        case .oneStride: return "One Stride"
        case .twoStride: return "Two Stride"
        }
    }
}

// MARK: - Quick Reference Card

struct QuickReferenceCard {
    let horseSize: HorseSize
    let walkPoles: (metres: String, feet: String)
    let trotPoles: (metres: String, feet: String)
    let canterPoles: (metres: String, feet: String)
    let bounce: (metres: String, feet: String)
    let oneStride: (metres: String, feet: String)
    let twoStride: (metres: String, feet: String)
}

// MARK: - Pole Layout Configuration

struct PoleLayoutConfig: Codable {
    let numberOfPoles: Int
    let exerciseType: PoleExerciseType
    let isRaised: Bool
    let raiseHeight: Double? // in cm
    let arrangement: PoleArrangement
    let customSpacings: [Double]? // Override calculated spacings

    enum PoleArrangement: String, Codable {
        case straight = "straight"
        case curved = "curved"
        case fan = "fan"
        case diagonal = "diagonal"
        case circle = "circle"
        case serpentine = "serpentine"
    }

    init(
        numberOfPoles: Int,
        exerciseType: PoleExerciseType,
        isRaised: Bool = false,
        raiseHeight: Double? = nil,
        arrangement: PoleArrangement = .straight,
        customSpacings: [Double]? = nil
    ) {
        self.numberOfPoles = numberOfPoles
        self.exerciseType = exerciseType
        self.isRaised = isRaised
        self.raiseHeight = raiseHeight
        self.arrangement = arrangement
        self.customSpacings = customSpacings
    }

    /// Calculate all spacings for this layout
    func calculateSpacings(for horseSize: HorseSize) -> [Double] {
        if let custom = customSpacings {
            return custom.map { $0 * horseSize.strideMultiplier }
        }

        let baseDistance = PoleStrideCalculator.distance(for: exerciseType, horseSize: horseSize)
        return Array(repeating: baseDistance, count: max(0, numberOfPoles - 1))
    }
}
