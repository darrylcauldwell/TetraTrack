//
//  TrainingProgram.swift
//  TetraTrack
//
//  Structured multi-week training program (C25K, 10K, etc.)
//

import Foundation
import SwiftData

// MARK: - Training Program

@Model
final class TrainingProgram {
    var id: UUID = UUID()
    var name: String = ""
    var programTypeRaw: String = "c25k"
    var statusRaw: String = "active"

    var startDate: Date = Date()
    var targetEndDate: Date?
    var totalWeeks: Int = 0
    var sessionsPerWeek: Int = 3
    var targetDistanceMeters: Double = 0

    var currentWeek: Int = 1
    var completedSessions: Int = 0
    var totalSessions: Int = 0
    var isCompleted: Bool = false

    // JSON-encoded [ProgramWeek] defining all weeks/sessions/intervals
    var programDefinitionData: Data?

    // Relationship
    @Relationship(deleteRule: .cascade, inverse: \ProgramSession.program)
    var programSessions: [ProgramSession]? = []

    init() {}

    init(
        name: String,
        programType: TrainingProgramType,
        startDate: Date = Date()
    ) {
        self.name = name
        self.programTypeRaw = programType.rawValue
        self.startDate = startDate
    }

    // MARK: - Computed Properties

    var programType: TrainingProgramType {
        get { TrainingProgramType(rawValue: programTypeRaw) ?? .c25k }
        set { programTypeRaw = newValue.rawValue }
    }

    var status: ProgramStatus {
        get { ProgramStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var programDefinition: [ProgramWeek] {
        get {
            guard let data = programDefinitionData else { return [] }
            return (try? JSONDecoder().decode([ProgramWeek].self, from: data)) ?? []
        }
        set {
            programDefinitionData = try? JSONEncoder().encode(newValue)
        }
    }

    var sortedSessions: [ProgramSession] {
        (programSessions ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    var progressFraction: Double {
        guard totalSessions > 0 else { return 0 }
        return Double(completedSessions) / Double(totalSessions)
    }

    var currentWeekSessions: [ProgramSession] {
        sortedSessions.filter { $0.weekNumber == currentWeek }
    }

    var nextSession: ProgramSession? {
        sortedSessions.first { $0.status == .upcoming }
    }

    var weeksRemaining: Int {
        max(0, totalWeeks - currentWeek + 1)
    }

    var formattedProgress: String {
        "\(completedSessions)/\(totalSessions) sessions"
    }
}

// MARK: - Program Session

@Model
final class ProgramSession {
    var id: UUID = UUID()
    var weekNumber: Int = 1
    var sessionNumber: Int = 1
    var orderIndex: Int = 0
    var name: String = ""
    var statusRaw: String = "upcoming"

    var scheduledDate: Date?
    var completedDate: Date?

    // Session definition (JSON-encoded [ProgramInterval])
    var sessionDefinitionData: Data?

    var targetDurationSeconds: Double = 0
    var targetDistanceMeters: Double = 0

    // Actual results
    var actualDurationSeconds: Double = 0
    var actualDistanceMeters: Double = 0
    var averageHeartRate: Int = 0
    var trainingStressScore: Double = 0

    // Link to the actual RunningSession
    var runningSessionId: UUID?

    // Relationship
    var program: TrainingProgram?

    init() {}

    init(
        weekNumber: Int,
        sessionNumber: Int,
        orderIndex: Int,
        name: String,
        targetDurationSeconds: Double = 0
    ) {
        self.weekNumber = weekNumber
        self.sessionNumber = sessionNumber
        self.orderIndex = orderIndex
        self.name = name
        self.targetDurationSeconds = targetDurationSeconds
    }

    // MARK: - Computed Properties

    var status: ProgramSessionStatus {
        get { ProgramSessionStatus(rawValue: statusRaw) ?? .upcoming }
        set { statusRaw = newValue.rawValue }
    }

    var sessionDefinition: [ProgramInterval] {
        get {
            guard let data = sessionDefinitionData else { return [] }
            return (try? JSONDecoder().decode([ProgramInterval].self, from: data)) ?? []
        }
        set {
            sessionDefinitionData = try? JSONEncoder().encode(newValue)
        }
    }

    var isCompleted: Bool {
        status == .completed
    }

    var formattedTargetDuration: String {
        let minutes = Int(targetDurationSeconds) / 60
        return "\(minutes) min"
    }

    /// Total walking time in this session's intervals
    var totalWalkTime: Double {
        sessionDefinition
            .filter { $0.phase == .walk }
            .reduce(0) { $0 + $1.totalDuration }
    }

    /// Total running time in this session's intervals
    var totalRunTime: Double {
        sessionDefinition
            .filter { $0.phase == .run }
            .reduce(0) { $0 + $1.totalDuration }
    }
}

// MARK: - Supporting Codable Types

nonisolated struct ProgramWeek: Codable, Identifiable, Sendable {
    var id: Int { weekNumber }
    let weekNumber: Int
    let theme: String
    let sessions: [ProgramSessionDefinition]
    let weeklyTargetTSS: Double
}

nonisolated struct ProgramSessionDefinition: Codable, Identifiable, Sendable {
    let id: UUID
    let sessionNumber: Int
    let name: String
    let intervals: [ProgramInterval]
    let totalDurationSeconds: Double

    init(sessionNumber: Int, name: String, intervals: [ProgramInterval]) {
        self.id = UUID()
        self.sessionNumber = sessionNumber
        self.name = name
        self.intervals = intervals
        self.totalDurationSeconds = intervals.reduce(0) { $0 + $1.totalDuration }
    }
}

nonisolated struct ProgramInterval: Codable, Identifiable, Sendable {
    let id: UUID
    let phase: IntervalPhase
    let durationSeconds: Double
    let targetPacePerKm: Double?  // optional target pace
    let repeatCount: Int

    init(phase: IntervalPhase, durationSeconds: Double, targetPacePerKm: Double? = nil, repeatCount: Int = 1) {
        self.id = UUID()
        self.phase = phase
        self.durationSeconds = durationSeconds
        self.targetPacePerKm = targetPacePerKm
        self.repeatCount = repeatCount
    }

    var totalDuration: Double {
        durationSeconds * Double(repeatCount)
    }

    var formattedDuration: String {
        let minutes = Int(durationSeconds) / 60
        let seconds = Int(durationSeconds) % 60
        if seconds == 0 {
            return "\(minutes) min"
        }
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

nonisolated enum IntervalPhase: String, Codable, Sendable {
    case warmup = "warmup"
    case walk = "walk"
    case run = "run"
    case cooldown = "cooldown"

    var displayName: String {
        switch self {
        case .warmup: return "Warm Up"
        case .walk: return "Walk"
        case .run: return "Run"
        case .cooldown: return "Cool Down"
        }
    }

    var color: String {
        switch self {
        case .warmup: return "gray"
        case .walk: return "green"
        case .run: return "orange"
        case .cooldown: return "gray"
        }
    }
}

// MARK: - Enums

nonisolated enum TrainingProgramType: String, Codable, CaseIterable, Identifiable {
    case c25k = "c25k"
    case c210k = "c210k"
    case c2half = "c2half"
    case marathon = "marathon"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .c25k: return "Couch to 5K"
        case .c210k: return "Couch to 10K"
        case .c2half: return "Couch to Half Marathon"
        case .marathon: return "Marathon"
        }
    }

    var subtitle: String {
        switch self {
        case .c25k: return "9 weeks - Walk/run intervals to 30 min continuous"
        case .c210k: return "14 weeks - Build from 5K to 10K"
        case .c2half: return "20 weeks - Progressive build to 21.1 km"
        case .marathon: return "20 weeks - Marathon preparation"
        }
    }

    var icon: String {
        switch self {
        case .c25k: return "figure.walk.motion"
        case .c210k: return "figure.run"
        case .c2half: return "figure.run.circle"
        case .marathon: return "flag.checkered"
        }
    }

    var totalWeeks: Int {
        switch self {
        case .c25k: return 9
        case .c210k: return 14
        case .c2half: return 20
        case .marathon: return 20
        }
    }

    var targetDistance: Double {
        switch self {
        case .c25k: return 5000
        case .c210k: return 10000
        case .c2half: return 21097.5
        case .marathon: return 42195
        }
    }
}

nonisolated enum ProgramStatus: String, Codable, CaseIterable {
    case active = "active"
    case paused = "paused"
    case completed = "completed"
    case abandoned = "abandoned"

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .active: return "play.circle.fill"
        case .paused: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .abandoned: return "xmark.circle.fill"
        }
    }
}

nonisolated enum ProgramSessionStatus: String, Codable, CaseIterable {
    case upcoming = "upcoming"
    case completed = "completed"
    case skipped = "skipped"
    case missed = "missed"

    var icon: String {
        switch self {
        case .upcoming: return "circle"
        case .completed: return "checkmark.circle.fill"
        case .skipped: return "arrow.right.circle"
        case .missed: return "xmark.circle"
        }
    }
}
