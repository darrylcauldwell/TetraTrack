//
//  Logger.swift
//  TetraTrack Watch App
//
//  Centralized logging for watchOS app using os.Logger
//

import Foundation
import os

/// Centralized logging for TetraTrack watchOS app
/// Usage: Log.watch.debug("Message") or Log.health.error("Error message")
enum Log {
    /// Watch connectivity logging
    nonisolated static let watch = Logger(subsystem: "dev.dreamfold.TetraTrack.watchkitapp", category: "Watch")

    /// HealthKit related logging
    nonisolated static let health = Logger(subsystem: "dev.dreamfold.TetraTrack.watchkitapp", category: "Health")

    /// Location and motion logging
    nonisolated static let location = Logger(subsystem: "dev.dreamfold.TetraTrack.watchkitapp", category: "Location")

    /// Workout/tracking logging
    nonisolated static let tracking = Logger(subsystem: "dev.dreamfold.TetraTrack.watchkitapp", category: "Tracking")

    /// Session sync logging
    nonisolated static let sync = Logger(subsystem: "dev.dreamfold.TetraTrack.watchkitapp", category: "Sync")

    /// Session storage logging
    nonisolated static let storage = Logger(subsystem: "dev.dreamfold.TetraTrack.watchkitapp", category: "Storage")

    /// General app logging
    nonisolated static let app = Logger(subsystem: "dev.dreamfold.TetraTrack.watchkitapp", category: "App")

    /// Safety/fall detection logging
    nonisolated static let safety = Logger(subsystem: "dev.dreamfold.TetraTrack.watchkitapp", category: "Safety")
}
