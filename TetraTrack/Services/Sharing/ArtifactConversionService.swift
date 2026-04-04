//
//  ArtifactConversionService.swift
//  TetraTrack
//
//  Converts completed discipline sessions into TrainingArtifacts for sharing.
//

import Foundation
import SwiftData
import os

/// Service for converting completed training sessions into shareable artifacts.
@MainActor
@Observable
final class ArtifactConversionService {
    static let shared = ArtifactConversionService()

    private let syncService = ArtifactSyncService.shared
    private let notificationManager = NotificationManager.shared

    private init() {}

    // MARK: - Ride Conversion

    /// Convert a completed Ride into a TrainingArtifact
    func createArtifact(from ride: Ride, athleteName: String = "Athlete") -> TrainingArtifact {
        let artifact = TrainingArtifact(
            discipline: .riding,
            sessionType: ride.rideType.rawValue,
            name: ride.name,
            startTime: ride.startDate
        )

        artifact.endTime = ride.endDate
        artifact.distance = ride.totalDistance
        artifact.averageHeartRate = ride.averageHeartRate > 0 ? ride.averageHeartRate : nil

        // Location
        if let firstPoint = ride.locationPoints?.first {
            artifact.startLatitude = firstPoint.latitude
            artifact.startLongitude = firstPoint.longitude
        }

        // Route data (encode location points for map display)
        if let points = ride.locationPoints, !points.isEmpty {
            let routePoints = points.map { point in
                RoutePoint(
                    latitude: point.latitude,
                    longitude: point.longitude,
                    gait: "unknown",  // Gaits tracked via GaitSegments, not on GPSPoint
                    timestamp: point.timestamp
                )
            }
            artifact.routeData = try? JSONEncoder().encode(routePoints)
        }

        // Riding-specific data
        let ridingData = RidingArtifactData(
            gaitDurations: [
                "walk": ride.gaitDuration(for: .walk),
                "trot": ride.gaitDuration(for: .trot),
                "canter": ride.gaitDuration(for: .canter),
                "gallop": ride.gaitDuration(for: .gallop)
            ],
            leftLeadDuration: ride.leftLeadDuration,
            rightLeadDuration: ride.rightLeadDuration,
            averageSpeed: ride.averageSpeed,
            maxSpeed: ride.maxSpeed,
            elevationGain: ride.elevationGain,
            horseName: ride.horse?.name
        )
        artifact.setRidingData(ridingData)

        Log.family.info("Created artifact from ride: \(ride.name)")

        return artifact
    }

    // MARK: - Running Session Conversion

    /// Convert a completed RunningSession into a TrainingArtifact
    func createArtifact(from session: RunningSession, athleteName: String = "Athlete") -> TrainingArtifact {
        let artifact = TrainingArtifact(
            discipline: .running,
            sessionType: session.runMode.rawValue,
            name: session.name,
            startTime: session.startDate
        )

        artifact.endTime = session.endDate
        artifact.distance = session.totalDistance
        artifact.averageHeartRate = session.averageHeartRate > 0 ? session.averageHeartRate : nil

        // Location (outdoor runs)
        if let firstPoint = session.locationPoints?.first {
            artifact.startLatitude = firstPoint.latitude
            artifact.startLongitude = firstPoint.longitude
        }

        // Running-specific data
        let splits = (session.splits ?? []).map { split in
            SplitSummary(
                distance: split.distance,
                duration: split.duration,
                pace: split.pace
            )
        }

        let runningData = RunningArtifactData(
            averagePace: session.averagePace,
            averageCadence: session.averageCadence,
            elevationGain: session.totalAscent,
            splits: splits,
            runMode: session.runMode.rawValue
        )
        artifact.setRunningData(runningData)

        Log.family.info("Created artifact from running session: \(session.name)")

        return artifact
    }

    // MARK: - Swimming Session Conversion

    /// Convert a completed SwimmingSession into a TrainingArtifact
    func createArtifact(from session: SwimmingSession, athleteName: String = "Athlete") -> TrainingArtifact {
        let artifact = TrainingArtifact(
            discipline: .swimming,
            sessionType: session.poolMode.rawValue,
            name: session.name,
            startTime: session.startDate
        )

        artifact.endTime = session.endDate
        artifact.distance = session.totalDistance
        // SwimmingSession doesn't track heart rate or calories

        // Swimming-specific data
        let swimmingData = SwimmingArtifactData(
            averagePace: session.averagePace,
            averageSwolf: session.averageSwolf,
            totalStrokes: session.totalStrokes,
            lapCount: session.lapCount,
            dominantStroke: session.dominantStroke.rawValue,
            poolLength: session.poolLength > 0 ? session.poolLength : nil
        )
        artifact.setSwimmingData(swimmingData)

        Log.family.info("Created artifact from swimming session: \(session.name)")

        return artifact
    }

    // MARK: - Shooting Session Conversion

    /// Convert a completed ShootingSession into a TrainingArtifact
    func createArtifact(from session: ShootingSession, athleteName: String = "Athlete") -> TrainingArtifact {
        let artifact = TrainingArtifact(
            discipline: .shooting,
            sessionType: session.targetType.rawValue,
            name: session.name,
            startTime: session.startDate
        )

        artifact.endTime = session.endDate
        // Shooting doesn't have distance
        artifact.distance = nil

        // Count total shots from ends
        let totalShots = (session.ends ?? []).flatMap { $0.shots ?? [] }.count

        // Shooting-specific data
        let shootingData = ShootingArtifactData(
            totalScore: session.totalScore,
            maxPossibleScore: session.maxPossibleScore,
            shotCount: totalShots,
            averageScore: session.averageScorePerArrow,
            groupRadius: nil,  // Would come from pattern analysis
            shootingSessionType: session.targetType.rawValue
        )
        artifact.setShootingData(shootingData)

        Log.family.info("Created artifact from shooting session: \(session.name)")

        return artifact
    }

    // MARK: - Unified Artifact Creation

    /// Create and sync a TrainingArtifact from a completed session model.
    /// Routes to the correct discipline-specific createArtifact(from:) based on discipline type.
    /// Deduplicates by sourceSessionID — skips if an artifact already exists for this session.
    func createAndSyncArtifact(session: any PersistentModel, discipline: String, sessionID: String, context: ModelContext) async {
        // Deduplication: check if artifact already exists for this session
        let descriptor = FetchDescriptor<TrainingArtifact>(
            predicate: #Predicate<TrainingArtifact> { $0.sourceSessionID == sessionID }
        )
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            Log.family.info("Artifact already exists for session \(sessionID) — skipping")
            return
        }

        // Create artifact via discipline-specific mapping
        let artifact: TrainingArtifact?
        switch discipline {
        case "riding":
            artifact = (session as? Ride).map { createArtifact(from: $0) }
        case "running", "walking":
            artifact = (session as? RunningSession).map { createArtifact(from: $0) }
        case "swimming":
            artifact = (session as? SwimmingSession).map { createArtifact(from: $0) }
        case "shooting":
            artifact = (session as? ShootingSession).map { createArtifact(from: $0) }
        default:
            Log.family.error("Unknown discipline for artifact: \(discipline)")
            artifact = nil
        }

        guard let artifact else { return }

        artifact.sourceSessionID = sessionID

        // Sync to CloudKit
        await syncService.saveArtifact(artifact)
        Log.family.info("Auto-created and synced artifact for \(discipline) session \(sessionID)")
    }

    // MARK: - Competition Conversion

    /// Create a SharedCompetition from a local Competition model
    func createSharedCompetition(from competition: Competition, ownerID: String) -> SharedCompetition {
        let shared = SharedCompetition(
            name: competition.name,
            date: competition.date,
            location: competition.location,
            venue: competition.venue,
            competitionType: competition.competitionType.rawValue,
            level: competition.level.rawValue,
            ownerID: ownerID
        )

        shared.endDate = competition.endDate
        shared.isEntered = competition.isEntered
        shared.entryDeadline = competition.entryDeadline
        shared.entryFee = competition.entryFee
        shared.isCompleted = competition.isCompleted

        // Venue coordinates
        if let lat = competition.venueLatitude, let lon = competition.venueLongitude {
            shared.venueLatitude = lat
            shared.venueLongitude = lon
        }

        // Discipline start times
        shared.shootingStartTime = competition.shootingStartTime
        shared.runningStartTime = competition.runningStartTime
        shared.swimmingStartTime = competition.swimStartTime
        // No riding start time in Competition model

        // Results (if completed)
        if competition.isCompleted {
            let results = CompetitionResults(
                overallPlacing: competition.overallPlacing,
                shootingScore: competition.shootingScore,
                shootingPoints: competition.shootingPoints.map { Int($0) },
                swimmingTime: competition.swimmingTime,
                swimmingPoints: competition.swimmingPoints.map { Int($0) },
                runningTime: competition.runningTime,
                runningPoints: competition.runningPoints.map { Int($0) },
                ridingScore: competition.ridingScore,
                ridingPoints: competition.ridingPoints.map { Int($0) },
                totalPoints: competition.storedTotalPoints.map { Int($0) }
            )
            shared.results = results
        }

        Log.family.info("Created shared competition from: \(competition.name)")

        return shared
    }

    /// Sync a competition to CloudKit
    func syncCompetition(_ competition: Competition, ownerID: String) async {
        let shared = createSharedCompetition(from: competition, ownerID: ownerID)
        await syncService.saveCompetition(shared, userID: ownerID)

        // Schedule reminders if upcoming
        if shared.isUpcoming {
            notificationManager.scheduleCompetitionReminder(competition: shared)
        }
    }
}

// MARK: - Helper Extensions

extension ArtifactConversionService {
    /// Batch convert all recent sessions for initial sync
    func convertAllRecentSessions(
        rides: [Ride],
        runningSessions: [RunningSession],
        swimmingSessions: [SwimmingSession],
        shootingSessions: [ShootingSession],
        athleteName: String = "Athlete"
    ) -> [TrainingArtifact] {
        var artifacts: [TrainingArtifact] = []

        // Convert rides
        for ride in rides where ride.endDate != nil {
            artifacts.append(createArtifact(from: ride, athleteName: athleteName))
        }

        // Convert running sessions
        for session in runningSessions where session.endDate != nil {
            artifacts.append(createArtifact(from: session, athleteName: athleteName))
        }

        // Convert swimming sessions
        for session in swimmingSessions where session.endDate != nil {
            artifacts.append(createArtifact(from: session, athleteName: athleteName))
        }

        // Convert shooting sessions
        for session in shootingSessions where session.endDate != nil {
            artifacts.append(createArtifact(from: session, athleteName: athleteName))
        }

        Log.family.info("Converted \(artifacts.count) sessions to artifacts")

        return artifacts
    }
}
