//
//  SessionHistoryItem.swift
//  TetraTrack
//
//  Unified session history item for cross-discipline display
//

import Foundation
import HealthKit

struct SessionHistoryItem: Identifiable, Hashable {
    static func == (lhs: SessionHistoryItem, rhs: SessionHistoryItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let id: UUID
    let discipline: TrainingDiscipline
    let date: Date
    let name: String
    let duration: TimeInterval
    let primaryMetric: String
    let secondaryMetric: String?
    let isExternal: Bool
    let externalSourceName: String?

    var ride: Ride?
    var runningSession: RunningSession?
    var swimmingSession: SwimmingSession?
    var shootingSession: ShootingSession?
    var externalWorkout: ExternalWorkout?

    init(ride: Ride) {
        self.id = ride.id
        self.discipline = .riding
        self.date = ride.startDate
        self.name = ride.name.isEmpty ? "Ride" : ride.name
        self.duration = ride.totalDuration
        self.primaryMetric = ride.formattedDistance
        self.secondaryMetric = ride.horse?.name
        self.isExternal = false
        self.externalSourceName = nil
        self.ride = ride
    }

    init(runningSession: RunningSession) {
        self.id = runningSession.id
        self.discipline = .running
        self.date = runningSession.startDate
        self.name = runningSession.name.isEmpty ? "Run" : runningSession.name
        self.duration = runningSession.totalDuration
        self.primaryMetric = runningSession.formattedDistance
        self.secondaryMetric = runningSession.formattedPace
        self.isExternal = false
        self.externalSourceName = nil
        self.runningSession = runningSession
    }

    init(swimmingSession: SwimmingSession) {
        self.id = swimmingSession.id
        self.discipline = .swimming
        self.date = swimmingSession.startDate
        self.name = swimmingSession.name.isEmpty ? "Swim" : swimmingSession.name
        self.duration = swimmingSession.totalDuration
        self.primaryMetric = swimmingSession.formattedDistance
        self.secondaryMetric = "\(swimmingSession.lapCount) laps"
        self.isExternal = false
        self.externalSourceName = nil
        self.swimmingSession = swimmingSession
    }

    init(shootingSession: ShootingSession) {
        self.id = shootingSession.id
        self.discipline = .shooting
        self.date = shootingSession.startDate
        self.name = shootingSession.name.isEmpty ? "Shooting" : shootingSession.name
        self.duration = shootingSession.totalDuration
        self.primaryMetric = "\(shootingSession.totalScore) pts"
        self.secondaryMetric = "\((shootingSession.ends ?? []).count) ends"
        self.isExternal = false
        self.externalSourceName = nil
        self.shootingSession = shootingSession
    }

    init(externalWorkout: ExternalWorkout) {
        self.id = externalWorkout.id
        // Map external activity type to closest discipline
        self.discipline = Self.mapDiscipline(from: externalWorkout)
        self.date = externalWorkout.startDate
        self.name = externalWorkout.activityName
        self.duration = externalWorkout.duration
        self.primaryMetric = externalWorkout.formattedDistance ?? externalWorkout.formattedCalories ?? ""
        self.secondaryMetric = externalWorkout.sourceName
        self.isExternal = true
        self.externalSourceName = externalWorkout.sourceName
        self.externalWorkout = externalWorkout
    }

    private static func mapDiscipline(from workout: ExternalWorkout) -> TrainingDiscipline {
        switch workout.activityType {
        case .equestrianSports: return .riding
        case .running, .walking, .hiking: return .running
        case .swimming: return .swimming
        default: return .running // Default to running for other cardio
        }
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var formattedDuration: String {
        duration.formattedDuration
    }
}

// MARK: - Combined Helper

extension SessionHistoryItem {
    static func combined(
        rides: [Ride] = [],
        runs: [RunningSession] = [],
        swims: [SwimmingSession] = [],
        shoots: [ShootingSession] = [],
        externals: [ExternalWorkout] = [],
        discipline: TrainingDiscipline? = nil,
        includeExternal: Bool = false
    ) -> [SessionHistoryItem] {
        var items: [SessionHistoryItem] = []
        if discipline == nil || discipline == .riding {
            items += rides.map { SessionHistoryItem(ride: $0) }
        }
        if discipline == nil || discipline == .running {
            items += runs.map { SessionHistoryItem(runningSession: $0) }
        }
        if discipline == nil || discipline == .swimming {
            items += swims.map { SessionHistoryItem(swimmingSession: $0) }
        }
        if discipline == nil || discipline == .shooting {
            items += shoots.map { SessionHistoryItem(shootingSession: $0) }
        }
        if includeExternal {
            let externalItems = externals.map { SessionHistoryItem(externalWorkout: $0) }
            if let discipline {
                items += externalItems.filter { $0.discipline == discipline }
            } else {
                items += externalItems
            }
        }
        return items.sorted { $0.date > $1.date }
    }
}
