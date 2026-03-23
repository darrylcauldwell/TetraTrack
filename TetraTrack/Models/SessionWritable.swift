//
//  SessionWritable.swift
//  TetraTrack
//
//  Protocol for session models that receive common field writes from SessionTracker.

import Foundation
import SwiftData

@MainActor
protocol SessionWritable: PersistentModel {
    var startDate: Date { get set }
    var endDate: Date? { get set }
    var totalDistance: Double { get set }
    var totalDuration: TimeInterval { get set }
    var averageHeartRate: Int { get set }
    var maxHeartRate: Int { get set }
    var minHeartRate: Int { get set }
    var heartRateSamplesData: Data? { get set }
    var healthKitWorkoutUUID: String { get set }
    var competitionID: String { get set }
}
