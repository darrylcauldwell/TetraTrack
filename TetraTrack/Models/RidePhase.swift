//
//  RidePhase.swift
//  TetraTrack
//
//  Represents a phase within a showjumping session (warmup, round, rest, cooldown)
//

import Foundation
import SwiftData

// MARK: - Phase Type

enum RidePhaseType: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }

    case warmup = "Warmup"
    case round = "Round"
    case rest = "Rest"
    case cooldown = "Cooldown"

    var icon: String {
        switch self {
        case .warmup: return "flame"
        case .round: return "flag.fill"
        case .rest: return "pause.circle"
        case .cooldown: return "snowflake"
        }
    }

    var color: String {
        switch self {
        case .warmup: return "gray"
        case .round: return "blue"
        case .rest: return "yellow"
        case .cooldown: return "green"
        }
    }
}

// MARK: - Ride Phase Model

@Model
final class RidePhase {
    var id: UUID = UUID()
    var phaseTypeValue: String = RidePhaseType.warmup.rawValue
    var startDate: Date = Date()
    var endDate: Date?
    var notes: String = ""

    // Per-phase metrics (populated on phase end)
    var distance: Double = 0.0
    var averageHeartRate: Int = 0
    var maxHeartRate: Int = 0
    var averageSpeed: Double = 0.0
    var jumpCount: Int = 0
    var faults: Int = 0

    // Relationship - MUST be optional for CloudKit
    var ride: Ride?

    init() {}

    init(phaseType: RidePhaseType) {
        self.phaseTypeValue = phaseType.rawValue
        self.startDate = Date()
    }

    // MARK: - Computed Properties

    var phaseType: RidePhaseType {
        get { RidePhaseType(rawValue: phaseTypeValue) ?? .warmup }
        set { phaseTypeValue = newValue.rawValue }
    }

    var duration: TimeInterval {
        guard let end = endDate else {
            return Date().timeIntervalSince(startDate)
        }
        return end.timeIntervalSince(startDate)
    }

    var formattedDuration: String {
        duration.formattedDuration
    }

    var isActive: Bool {
        endDate == nil
    }
}
