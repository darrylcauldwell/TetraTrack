//
//  DataMigrationService.swift
//  TrackRide
//
//  Migrates legacy drill sessions to unified drill sessions
//

import Foundation
import SwiftData

/// Service for migrating legacy drill sessions to the unified model
@Observable
final class DataMigrationService {

    private static let migrationKey = "drillMigrationComplete_v1"

    /// Check if migration has already been completed
    static var isMigrationComplete: Bool {
        UserDefaults.standard.bool(forKey: migrationKey)
    }

    /// Mark migration as complete
    static func markMigrationComplete() {
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    /// Reset migration status (for debugging)
    static func resetMigrationStatus() {
        UserDefaults.standard.removeObject(forKey: migrationKey)
    }

    // MARK: - Migration Methods

    /// Migrate all legacy sessions to unified model
    @MainActor
    func migrateAllSessions(
        ridingSessions: [RidingDrillSession],
        shootingSessions: [ShootingDrillSession],
        context: ModelContext
    ) async throws {
        guard !Self.isMigrationComplete else {
            return
        }

        var migratedCount = 0

        // Migrate riding sessions
        for session in ridingSessions {
            let unified = migrateRidingSession(session)
            context.insert(unified)
            migratedCount += 1
        }

        // Migrate shooting sessions
        for session in shootingSessions {
            let unified = migrateShootingSession(session)
            context.insert(unified)
            migratedCount += 1
        }

        // Save context
        try context.save()

        // Mark as complete
        Self.markMigrationComplete()
    }

    /// Migrate a single riding drill session
    func migrateRidingSession(_ session: RidingDrillSession) -> UnifiedDrillSession {
        let unifiedType = UnifiedDrillType.from(ridingDrillType: session.drillType)

        let unified = UnifiedDrillSession(
            drillType: unifiedType,
            duration: session.duration,
            score: session.score,
            stabilityScore: session.stabilityScore,
            symmetryScore: session.symmetryScore,
            enduranceScore: session.enduranceScore,
            coordinationScore: session.coordinationScore,
            rhythmScore: session.rhythmAccuracy,  // Map rhythm accuracy to rhythm score
            averageRMS: session.averageRMS,
            peakDeviation: session.peakDeviation,
            rhythmAccuracy: session.rhythmAccuracy
        )

        // Preserve original date
        unified.startDate = session.startDate
        unified.notes = session.notes

        return unified
    }

    /// Migrate a single shooting drill session
    func migrateShootingSession(_ session: ShootingDrillSession) -> UnifiedDrillSession {
        let unifiedType = UnifiedDrillType.from(shootingDrillType: session.drillType)

        let unified = UnifiedDrillSession(
            drillType: unifiedType,
            duration: session.duration,
            score: session.score,
            stabilityScore: session.stabilityScore,
            enduranceScore: session.enduranceScore,
            reactionScore: session.transitionScore,  // Map transition to reaction
            averageWobble: session.averageWobble,
            bestReactionTime: session.bestReactionTime,
            averageSplitTime: session.averageSplitTime,
            startHeartRate: session.startHeartRate
        )

        // Preserve original date
        unified.startDate = session.startDate
        unified.notes = session.notes

        return unified
    }

    // MARK: - Validation

    /// Validate that migration was successful by comparing counts
    @MainActor
    func validateMigration(
        originalRidingCount: Int,
        originalShootingCount: Int,
        context: ModelContext
    ) -> MigrationValidationResult {
        let descriptor = FetchDescriptor<UnifiedDrillSession>()

        do {
            let unifiedSessions = try context.fetch(descriptor)

            let ridingMigrated = unifiedSessions.filter {
                $0.primaryDiscipline == .riding
            }.count

            let shootingMigrated = unifiedSessions.filter {
                $0.primaryDiscipline == .shooting
            }.count

            let isValid = ridingMigrated >= originalRidingCount &&
                         shootingMigrated >= originalShootingCount

            return MigrationValidationResult(
                isValid: isValid,
                expectedRiding: originalRidingCount,
                migratedRiding: ridingMigrated,
                expectedShooting: originalShootingCount,
                migratedShooting: shootingMigrated
            )
        } catch {
            return MigrationValidationResult(
                isValid: false,
                expectedRiding: originalRidingCount,
                migratedRiding: 0,
                expectedShooting: originalShootingCount,
                migratedShooting: 0,
                error: error.localizedDescription
            )
        }
    }
}

// MARK: - Migration Validation Result

struct MigrationValidationResult {
    let isValid: Bool
    let expectedRiding: Int
    let migratedRiding: Int
    let expectedShooting: Int
    let migratedShooting: Int
    var error: String?

    var summary: String {
        if isValid {
            return "Migration successful: \(migratedRiding) riding + \(migratedShooting) shooting sessions migrated."
        } else if let error = error {
            return "Migration failed: \(error)"
        } else {
            return "Migration incomplete: Expected \(expectedRiding) riding (got \(migratedRiding)), \(expectedShooting) shooting (got \(migratedShooting))"
        }
    }
}

// MARK: - App Delegate Integration Helper

extension DataMigrationService {

    /// Run migration if needed (call from app launch)
    @MainActor
    static func runMigrationIfNeeded(context: ModelContext) async {
        guard !isMigrationComplete else { return }

        let service = DataMigrationService()

        // Fetch legacy sessions
        let ridingDescriptor = FetchDescriptor<RidingDrillSession>()
        let shootingDescriptor = FetchDescriptor<ShootingDrillSession>()

        do {
            let ridingSessions = try context.fetch(ridingDescriptor)
            let shootingSessions = try context.fetch(shootingDescriptor)

            // Only run migration if there are sessions to migrate
            if ridingSessions.isEmpty && shootingSessions.isEmpty {
                markMigrationComplete()
                return
            }

            try await service.migrateAllSessions(
                ridingSessions: ridingSessions,
                shootingSessions: shootingSessions,
                context: context
            )
        } catch {
            // Migration error - silently fail
        }
    }
}
