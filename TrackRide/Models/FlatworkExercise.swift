//
//  FlatworkExercise.swift
//  TrackRide
//
//  Flatwork/Dressage exercise model for the exercise library
//

import Foundation
import SwiftData

// MARK: - Flatwork Exercise Model

@Model
final class FlatworkExercise {
    var id: UUID = UUID()
    var name: String = ""
    var exerciseDescription: String = ""
    var difficultyRaw: String = "beginner"
    var categoryRaw: String = "figures"
    var instructions: [String] = []
    var benefits: [String] = []
    var tips: [String] = []
    var requiredGaitsRaw: [String] = []
    var isBuiltIn: Bool = true
    var isFavorite: Bool = false
    var createdDate: Date = Date()

    // Photos stored as compressed JPEG data (max 5 photos)
    @Attribute(.externalStorage) var photos: [Data] = []

    // Video references - stored as PHAsset local identifiers (videos stay in Apple Photos)
    var videoAssetIdentifiers: [String] = []
    @Attribute(.externalStorage) var videoThumbnails: [Data] = []

    var difficulty: FlatworkDifficulty {
        get { FlatworkDifficulty(rawValue: difficultyRaw) ?? .beginner }
        set { difficultyRaw = newValue.rawValue }
    }

    var category: FlatworkCategory {
        get { FlatworkCategory(rawValue: categoryRaw) ?? .figures }
        set { categoryRaw = newValue.rawValue }
    }

    var requiredGaits: [FlatworkGait] {
        get { requiredGaitsRaw.compactMap { FlatworkGait(rawValue: $0) } }
        set { requiredGaitsRaw = newValue.map { $0.rawValue } }
    }

    init() {}

    init(
        name: String,
        description: String,
        difficulty: FlatworkDifficulty = .beginner,
        category: FlatworkCategory = .figures,
        instructions: [String] = [],
        benefits: [String] = [],
        tips: [String] = [],
        requiredGaits: [FlatworkGait] = []
    ) {
        self.name = name
        self.exerciseDescription = description
        self.difficultyRaw = difficulty.rawValue
        self.categoryRaw = category.rawValue
        self.instructions = instructions
        self.benefits = benefits
        self.tips = tips
        self.requiredGaitsRaw = requiredGaits.map { $0.rawValue }
        self.isBuiltIn = true
    }
}

// MARK: - Flatwork Difficulty

enum FlatworkDifficulty: String, Codable, CaseIterable, Identifiable {
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

// MARK: - Flatwork Category

enum FlatworkCategory: String, Codable, CaseIterable, Identifiable {
    case figures = "figures"
    case transitions = "transitions"
    case circles = "circles"
    case lateral = "lateral"
    case collection = "collection"
    case suppleness = "suppleness"
    case straightness = "straightness"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .figures: return "School Figures"
        case .transitions: return "Transitions"
        case .circles: return "Circles & Curves"
        case .lateral: return "Lateral Work"
        case .collection: return "Collection"
        case .suppleness: return "Suppleness"
        case .straightness: return "Straightness"
        }
    }

    var icon: String {
        switch self {
        case .figures: return "square.on.circle"
        case .transitions: return "arrow.up.arrow.down"
        case .circles: return "circle"
        case .lateral: return "arrow.left.arrow.right"
        case .collection: return "arrow.down.to.line"
        case .suppleness: return "waveform.path"
        case .straightness: return "arrow.up"
        }
    }

    var sortOrder: Int {
        switch self {
        case .figures: return 0
        case .circles: return 1
        case .transitions: return 2
        case .lateral: return 3
        case .collection: return 4
        case .suppleness: return 5
        case .straightness: return 6
        }
    }
}

// MARK: - Flatwork Gait

enum FlatworkGait: String, Codable, CaseIterable, Identifiable {
    case walk = "walk"
    case trot = "trot"
    case canter = "canter"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .walk: return "Walk"
        case .trot: return "Trot"
        case .canter: return "Canter"
        }
    }

    var icon: String {
        switch self {
        case .walk: return "figure.walk"
        case .trot: return "gauge.with.dots.needle.33percent"
        case .canter: return "gauge.with.dots.needle.67percent"
        }
    }
}
