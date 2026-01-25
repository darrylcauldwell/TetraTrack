//
//  WorkoutTemplate.swift
//  TrackRide
//
//  Structured workout templates with intervals
//

import Foundation
import SwiftData

// MARK: - Workout Block

/// A single block/interval within a workout
@Model
final class WorkoutBlock {
    var id: UUID = UUID()
    var name: String = ""
    var durationSeconds: Int = 180
    var targetGaitRaw: String?
    var intensityRaw: String = "Moderate"
    var notes: String = ""
    var orderIndex: Int = 0

    // Relationship
    var template: WorkoutTemplate?

    var targetGait: GaitType? {
        get {
            guard let raw = targetGaitRaw else { return nil }
            return GaitType(rawValue: raw)
        }
        set { targetGaitRaw = newValue?.rawValue }
    }

    var intensity: WorkoutIntensity {
        get { WorkoutIntensity(rawValue: intensityRaw) ?? .moderate }
        set { intensityRaw = newValue.rawValue }
    }

    init() {}

    init(
        name: String = "",
        durationSeconds: Int = 180,
        targetGait: GaitType? = nil,
        intensity: WorkoutIntensity = .moderate,
        orderIndex: Int = 0
    ) {
        self.name = name
        self.durationSeconds = durationSeconds
        self.targetGaitRaw = targetGait?.rawValue
        self.intensityRaw = intensity.rawValue
        self.orderIndex = orderIndex
    }

    var formattedDuration: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60

        if minutes > 0 && seconds > 0 {
            return "\(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "\(seconds) sec"
        }
    }
}

// MARK: - Workout Intensity

enum WorkoutIntensity: String, Codable, CaseIterable {
    case recovery = "Recovery"
    case easy = "Easy"
    case moderate = "Moderate"
    case hard = "Hard"
    case maximum = "Maximum"

    var color: String {
        switch self {
        case .recovery: return "green"
        case .easy: return "blue"
        case .moderate: return "yellow"
        case .hard: return "orange"
        case .maximum: return "red"
        }
    }

    var description: String {
        switch self {
        case .recovery: return "Very light effort, focus on relaxation"
        case .easy: return "Comfortable pace, can hold conversation"
        case .moderate: return "Working but sustainable"
        case .hard: return "Challenging, pushing limits"
        case .maximum: return "All-out effort"
        }
    }
}

// MARK: - Workout Template

@Model
final class WorkoutTemplate {
    var id: UUID = UUID()
    var name: String = ""
    var workoutDescription: String = ""
    var disciplineRaw: String = "flatwork"
    var difficultyRaw: String = "Intermediate"
    var estimatedDuration: Int = 0 // Calculated from blocks
    var createdAt: Date = Date()
    var isBuiltIn: Bool = false

    // Relationship
    @Relationship(deleteRule: .cascade, inverse: \WorkoutBlock.template)
    var blocks: [WorkoutBlock]? = []

    var discipline: RideType {
        get { RideType(rawValue: disciplineRaw) ?? .schooling }
        set { disciplineRaw = newValue.rawValue }
    }

    var difficulty: WorkoutDifficulty {
        get { WorkoutDifficulty(rawValue: difficultyRaw) ?? .intermediate }
        set { difficultyRaw = newValue.rawValue }
    }

    init() {}

    init(
        name: String = "",
        description: String = "",
        discipline: RideType = .schooling,
        difficulty: WorkoutDifficulty = .intermediate,
        isBuiltIn: Bool = false
    ) {
        self.name = name
        self.workoutDescription = description
        self.disciplineRaw = discipline.rawValue
        self.difficultyRaw = difficulty.rawValue
        self.isBuiltIn = isBuiltIn
    }

    /// Blocks sorted by order index
    var sortedBlocks: [WorkoutBlock] {
        (blocks ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Total duration in seconds
    var totalDuration: Int {
        (blocks ?? []).reduce(0) { $0 + $1.durationSeconds }
    }

    /// Formatted total duration
    var formattedTotalDuration: String {
        let minutes = totalDuration / 60
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
    }

    /// Add a block to this template
    func addBlock(_ block: WorkoutBlock) {
        block.orderIndex = (blocks ?? []).count
        block.template = self
        if blocks == nil { blocks = [] }
        blocks?.append(block)
        estimatedDuration = totalDuration
    }

    /// Remove a block from this template
    func removeBlock(_ block: WorkoutBlock) {
        blocks?.removeAll { $0.id == block.id }
        // Reorder remaining blocks
        for (index, b) in sortedBlocks.enumerated() {
            b.orderIndex = index
        }
        estimatedDuration = totalDuration
    }
}

// MARK: - Workout Difficulty

enum WorkoutDifficulty: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case expert = "Expert"

    var icon: String {
        switch self {
        case .beginner: return "1.circle.fill"
        case .intermediate: return "2.circle.fill"
        case .advanced: return "3.circle.fill"
        case .expert: return "4.circle.fill"
        }
    }
}

// MARK: - Built-in Workout Templates

extension WorkoutTemplate {
    static func createBuiltInTemplates() -> [WorkoutTemplate] {
        var templates: [WorkoutTemplate] = []

        // Basic Flatwork Warm-up
        let warmup = WorkoutTemplate(
            name: "Basic Warm-up",
            description: "A gentle warm-up routine to prepare horse and rider",
            discipline: .schooling,
            difficulty: .beginner,
            isBuiltIn: true
        )
        warmup.addBlock(WorkoutBlock(name: "Walk on long rein", durationSeconds: 300, targetGait: .walk, intensity: .recovery))
        warmup.addBlock(WorkoutBlock(name: "Working walk", durationSeconds: 180, targetGait: .walk, intensity: .easy))
        warmup.addBlock(WorkoutBlock(name: "Rising trot", durationSeconds: 300, targetGait: .trot, intensity: .easy))
        warmup.addBlock(WorkoutBlock(name: "Walk break", durationSeconds: 120, targetGait: .walk, intensity: .recovery))
        warmup.addBlock(WorkoutBlock(name: "Working trot", durationSeconds: 300, targetGait: .trot, intensity: .moderate))
        templates.append(warmup)

        // Fitness Intervals
        let fitness = WorkoutTemplate(
            name: "Canter Fitness",
            description: "Build cardiovascular fitness with trot-canter intervals",
            discipline: .schooling,
            difficulty: .intermediate,
            isBuiltIn: true
        )
        fitness.addBlock(WorkoutBlock(name: "Warm-up walk", durationSeconds: 300, targetGait: .walk, intensity: .easy))
        fitness.addBlock(WorkoutBlock(name: "Warm-up trot", durationSeconds: 300, targetGait: .trot, intensity: .easy))
        for i in 1...4 {
            fitness.addBlock(WorkoutBlock(name: "Canter \(i)", durationSeconds: 180, targetGait: .canter, intensity: .moderate))
            fitness.addBlock(WorkoutBlock(name: "Trot recovery", durationSeconds: 120, targetGait: .trot, intensity: .easy))
        }
        fitness.addBlock(WorkoutBlock(name: "Cool-down walk", durationSeconds: 300, targetGait: .walk, intensity: .recovery))
        templates.append(fitness)

        // Endurance Builder
        let endurance = WorkoutTemplate(
            name: "Endurance Builder",
            description: "Extended trot work to build stamina",
            discipline: .hack,
            difficulty: .intermediate,
            isBuiltIn: true
        )
        endurance.addBlock(WorkoutBlock(name: "Walk warm-up", durationSeconds: 600, targetGait: .walk, intensity: .easy))
        endurance.addBlock(WorkoutBlock(name: "Extended trot", durationSeconds: 900, targetGait: .trot, intensity: .moderate))
        endurance.addBlock(WorkoutBlock(name: "Walk break", durationSeconds: 300, targetGait: .walk, intensity: .recovery))
        endurance.addBlock(WorkoutBlock(name: "Extended trot", durationSeconds: 900, targetGait: .trot, intensity: .moderate))
        endurance.addBlock(WorkoutBlock(name: "Cool-down", durationSeconds: 600, targetGait: .walk, intensity: .recovery))
        templates.append(endurance)

        // Speed Work
        let speed = WorkoutTemplate(
            name: "Speed Intervals",
            description: "Short bursts to improve acceleration and top speed",
            discipline: .crossCountry,
            difficulty: .advanced,
            isBuiltIn: true
        )
        speed.addBlock(WorkoutBlock(name: "Warm-up", durationSeconds: 600, targetGait: .trot, intensity: .easy))
        for i in 1...5 {
            speed.addBlock(WorkoutBlock(name: "Gallop \(i)", durationSeconds: 30, targetGait: .gallop, intensity: .hard))
            speed.addBlock(WorkoutBlock(name: "Canter recovery", durationSeconds: 120, targetGait: .canter, intensity: .easy))
        }
        speed.addBlock(WorkoutBlock(name: "Cool-down trot", durationSeconds: 300, targetGait: .trot, intensity: .easy))
        speed.addBlock(WorkoutBlock(name: "Cool-down walk", durationSeconds: 600, targetGait: .walk, intensity: .recovery))
        templates.append(speed)

        return templates
    }
}
