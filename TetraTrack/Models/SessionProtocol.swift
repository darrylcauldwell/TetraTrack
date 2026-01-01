//
//  SessionProtocol.swift
//  TetraTrack
//
//  Unified protocol for all training session types (Running, Swimming, Shooting, Riding)
//

import Foundation
import SwiftUI

// MARK: - Base Session Protocol

/// Protocol defining common properties and methods for all training sessions
/// Note: @Model classes already conform to Identifiable via the macro
protocol TrainingSessionProtocol {
    var id: UUID { get }
    var startDate: Date { get set }
    var endDate: Date? { get set }
    var name: String { get set }
    var notes: String { get set }

    // Core metrics
    var totalDistance: Double { get }
    var totalDuration: TimeInterval { get }

    // Formatted outputs
    var formattedDistance: String { get }
    var formattedDuration: String { get }
}

// MARK: - Default Implementations

extension TrainingSessionProtocol {
    var formattedDistance: String {
        totalDistance.formattedDistance
    }

    var formattedDuration: String {
        totalDuration.formattedDuration
    }

    var isCompleted: Bool {
        endDate != nil
    }

    var duration: TimeInterval {
        guard let end = endDate else {
            return Date().timeIntervalSince(startDate)
        }
        return end.timeIntervalSince(startDate)
    }
}

// MARK: - Pace-Based Session Protocol

/// Protocol for sessions that track pace (Running, Swimming)
protocol PaceBasedSessionProtocol: TrainingSessionProtocol {
    var averagePace: TimeInterval { get }
    var formattedPace: String { get }
}

extension PaceBasedSessionProtocol {
    var formattedPace: String {
        averagePace.formattedPace
    }
}

// MARK: - Speed-Based Session Protocol

/// Protocol for sessions that track speed
protocol SpeedBasedSessionProtocol: TrainingSessionProtocol {
    var averageSpeed: Double { get }
    var formattedSpeed: String { get }
}

extension SpeedBasedSessionProtocol {
    var formattedSpeed: String {
        averageSpeed.formattedSpeed
    }
}

// MARK: - Elevation Session Protocol

/// Protocol for sessions that track elevation
protocol ElevationSessionProtocol: TrainingSessionProtocol {
    var totalAscent: Double { get }
    var totalDescent: Double { get }
}

extension ElevationSessionProtocol {
    var formattedAscent: String {
        totalAscent.formattedElevation
    }

    var formattedDescent: String {
        totalDescent.formattedElevation
    }

    var netElevation: Double {
        totalAscent - totalDescent
    }
}

// MARK: - Heart Rate Session Protocol

/// Protocol for sessions that track heart rate
protocol HeartRateSessionProtocol: TrainingSessionProtocol {
    var averageHeartRate: Int { get }
    var maxHeartRate: Int { get }
}

extension HeartRateSessionProtocol {
    var formattedAverageHeartRate: String {
        "\(averageHeartRate) bpm"
    }

    var formattedMaxHeartRate: String {
        "\(maxHeartRate) bpm"
    }
}

// MARK: - Cadence Session Protocol

/// Protocol for sessions that track cadence/steps
protocol CadenceSessionProtocol: TrainingSessionProtocol {
    var averageCadence: Int { get }
    var maxCadence: Int { get }
}

extension CadenceSessionProtocol {
    var formattedAverageCadence: String {
        "\(averageCadence) spm"
    }
}

// MARK: - Split-Based Session Protocol

/// Protocol for sessions with splits/laps
protocol SplitBasedSessionProtocol: TrainingSessionProtocol {
    associatedtype SplitType
    var splits: [SplitType] { get }
}

// MARK: - Interval Session Protocol

/// Protocol for sessions with intervals
protocol IntervalSessionProtocol: TrainingSessionProtocol {
    associatedtype IntervalType
    var intervals: [IntervalType] { get }
}

// MARK: - Session Statistics

/// Common statistics structure for any session type
struct SessionStatistics {
    let totalSessions: Int
    let totalDistance: Double
    let totalDuration: TimeInterval
    let averageDistance: Double
    let averageDuration: TimeInterval

    var formattedTotalDistance: String { totalDistance.formattedDistance }
    var formattedTotalDuration: String { totalDuration.formattedDuration }
    var formattedAverageDistance: String { averageDistance.formattedDistance }
    var formattedAverageDuration: String { averageDuration.formattedDuration }

    init(sessions: [any TrainingSessionProtocol]) {
        self.totalSessions = sessions.count
        self.totalDistance = sessions.reduce(0) { $0 + $1.totalDistance }
        self.totalDuration = sessions.reduce(0) { $0 + $1.totalDuration }
        self.averageDistance = totalSessions > 0 ? totalDistance / Double(totalSessions) : 0
        self.averageDuration = totalSessions > 0 ? totalDuration / Double(totalSessions) : 0
    }
}

// MARK: - Discipline Type

/// Enum representing different training disciplines
enum TrainingDiscipline: String, CaseIterable, Codable {
    case riding = "Riding"
    case running = "Running"
    case swimming = "Swimming"
    case shooting = "Shooting"

    var icon: String {
        switch self {
        case .riding: return "figure.equestrian.sports"
        case .running: return "figure.run"
        case .swimming: return "figure.pool.swim"
        case .shooting: return "target"
        }
    }

    var color: String {
        switch self {
        case .riding: return "brown"
        case .running: return "green"
        case .swimming: return "blue"
        case .shooting: return "orange"
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .riding: return .brown
        case .running: return .green
        case .swimming: return .blue
        case .shooting: return .orange
        }
    }

    var unitOfMeasure: String {
        switch self {
        case .riding, .running: return "km"
        case .swimming: return "m"
        case .shooting: return "points"
        }
    }

    var paceUnit: String {
        switch self {
        case .riding, .running: return "/km"
        case .swimming: return "/100m"
        case .shooting: return ""
        }
    }
}
