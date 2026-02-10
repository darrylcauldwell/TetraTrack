//
//  PoleworkExercise.swift
//  TetraTrack
//
//  Polework and grid exercise model with dynamic stride calculations
//

import Foundation
import SwiftData

// MARK: - Polework Exercise Model

@Model
final class PoleworkExercise {
    var id: UUID = UUID()
    var name: String = ""
    var exerciseDescription: String = ""
    var difficultyRaw: String = "beginner"
    var categoryRaw: String = "groundPoles"
    var exerciseTypeRaw: String = "trotPoles"
    var instructions: [String] = []
    var benefits: [String] = []
    var tips: [String] = []
    var safetyNotes: [String] = []
    var numberOfPoles: Int = 4
    var isRaised: Bool = false
    var raiseHeightCm: Double = 0
    var arrangementRaw: String = "straight"
    var requiredGaitsRaw: [String] = []
    var isBuiltIn: Bool = true
    var isFavorite: Bool = false
    var createdDate: Date = Date()

    // Photos stored as compressed JPEG data (max 5 photos)
    @Attribute(.externalStorage) var photos: [Data] = []

    // Video references - stored as PHAsset local identifiers (videos stay in Apple Photos)
    var videoAssetIdentifiers: [String] = []
    @Attribute(.externalStorage) var videoThumbnails: [Data] = []

    // Grid-specific properties
    var gridElementsRaw: [String] = []
    var isGrid: Bool = false

    // MARK: - Computed Properties

    var difficulty: PoleworkDifficulty {
        get { PoleworkDifficulty(rawValue: difficultyRaw) ?? .beginner }
        set { difficultyRaw = newValue.rawValue }
    }

    var category: PoleworkCategory {
        get { PoleworkCategory(rawValue: categoryRaw) ?? .groundPoles }
        set { categoryRaw = newValue.rawValue }
    }

    var exerciseType: PoleExerciseType {
        get { PoleExerciseType(rawValue: exerciseTypeRaw) ?? .trotPoles }
        set { exerciseTypeRaw = newValue.rawValue }
    }

    var arrangement: PoleLayoutConfig.PoleArrangement {
        get { PoleLayoutConfig.PoleArrangement(rawValue: arrangementRaw) ?? .straight }
        set { arrangementRaw = newValue.rawValue }
    }

    var requiredGaits: [FlatworkGait] {
        get { requiredGaitsRaw.compactMap { FlatworkGait(rawValue: $0) } }
        set { requiredGaitsRaw = newValue.map { $0.rawValue } }
    }

    var gridElements: [GridElement] {
        get { gridElementsRaw.compactMap { GridElement(rawValue: $0) } }
        set { gridElementsRaw = newValue.map { $0.rawValue } }
    }

    // MARK: - Pole Layout

    var poleLayout: PoleLayoutConfig {
        PoleLayoutConfig(
            numberOfPoles: numberOfPoles,
            exerciseType: exerciseType,
            isRaised: isRaised,
            raiseHeight: isRaised ? raiseHeightCm : nil,
            arrangement: arrangement
        )
    }

    // MARK: - Distance Calculations

    /// Get spacing for this exercise based on horse size
    func spacing(for horseSize: HorseSize) -> Double {
        PoleStrideCalculator.distance(for: exerciseType, horseSize: horseSize)
    }

    /// Get formatted spacing for display
    func formattedSpacing(for horseSize: HorseSize) -> (metres: String, feet: String) {
        PoleStrideCalculator.formattedDistance(for: exerciseType, horseSize: horseSize)
    }

    /// Get all spacings for a multi-pole layout
    func allSpacings(for horseSize: HorseSize) -> [Double] {
        poleLayout.calculateSpacings(for: horseSize)
    }

    /// Get fan pole distances if applicable
    func fanDistances(for horseSize: HorseSize) -> (inner: Double, middle: Double, outer: Double)? {
        guard arrangement == .fan else { return nil }
        let gait: FlatworkGait = exerciseType == .canterPoles ? .canter : .trot
        return PoleStrideCalculator.fanPoleDistances(horseSize: horseSize, gait: gait)
    }

    /// Total length of the exercise setup
    func totalLength(for horseSize: HorseSize) -> Double {
        let spacings = allSpacings(for: horseSize)
        return spacings.reduce(0, +)
    }

    // MARK: - Initializer

    init() {}

    init(
        name: String,
        description: String,
        difficulty: PoleworkDifficulty = .beginner,
        category: PoleworkCategory = .groundPoles,
        exerciseType: PoleExerciseType = .trotPoles,
        numberOfPoles: Int = 4,
        isRaised: Bool = false,
        raiseHeightCm: Double = 0,
        arrangement: PoleLayoutConfig.PoleArrangement = .straight,
        instructions: [String] = [],
        benefits: [String] = [],
        tips: [String] = [],
        safetyNotes: [String] = [],
        requiredGaits: [FlatworkGait] = [],
        isGrid: Bool = false,
        gridElements: [GridElement] = []
    ) {
        self.name = name
        self.exerciseDescription = description
        self.difficultyRaw = difficulty.rawValue
        self.categoryRaw = category.rawValue
        self.exerciseTypeRaw = exerciseType.rawValue
        self.numberOfPoles = numberOfPoles
        self.isRaised = isRaised
        self.raiseHeightCm = raiseHeightCm
        self.arrangementRaw = arrangement.rawValue
        self.instructions = instructions
        self.benefits = benefits
        self.tips = tips
        self.safetyNotes = safetyNotes
        self.requiredGaitsRaw = requiredGaits.map { $0.rawValue }
        self.isBuiltIn = true
        self.isGrid = isGrid
        self.gridElementsRaw = gridElements.map { $0.rawValue }
    }
}

// MARK: - Polework Difficulty

enum PoleworkDifficulty: String, Codable, CaseIterable, Identifiable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }

    var sortOrder: Int {
        switch self {
        case .beginner: return 0
        case .intermediate: return 1
        case .advanced: return 2
        }
    }

    var color: String {
        switch self {
        case .beginner: return "green"
        case .intermediate: return "orange"
        case .advanced: return "red"
        }
    }
}

// MARK: - Polework Category

enum PoleworkCategory: String, Codable, CaseIterable, Identifiable {
    case groundPoles = "groundPoles"
    case raisedPoles = "raisedPoles"
    case cavaletti = "cavaletti"
    case grids = "grids"
    case circles = "circles"
    case conditioning = "conditioning"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .groundPoles: return "Ground Poles"
        case .raisedPoles: return "Raised Poles"
        case .cavaletti: return "Cavaletti"
        case .grids: return "Gymnastic Grids"
        case .circles: return "Circle Work"
        case .conditioning: return "Conditioning"
        }
    }

    var icon: String {
        switch self {
        case .groundPoles: return "minus"
        case .raisedPoles: return "arrow.up.to.line"
        case .cavaletti: return "square.stack.3d.up"
        case .grids: return "square.grid.3x3"
        case .circles: return "circle"
        case .conditioning: return "figure.strengthtraining.traditional"
        }
    }

    var sortOrder: Int {
        switch self {
        case .groundPoles: return 0
        case .raisedPoles: return 1
        case .cavaletti: return 2
        case .circles: return 3
        case .grids: return 4
        case .conditioning: return 5
        }
    }
}
