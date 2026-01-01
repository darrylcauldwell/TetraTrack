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
    private static let subsystem = Bundle.main.bundleIdentifier ?? "TetraTrack.watchOS"

    /// Watch connectivity logging
    static let watch = Logger(subsystem: subsystem, category: "Watch")

    /// HealthKit related logging
    static let health = Logger(subsystem: subsystem, category: "Health")

    /// Location and motion logging
    static let location = Logger(subsystem: subsystem, category: "Location")

    /// Workout/tracking logging
    static let tracking = Logger(subsystem: subsystem, category: "Tracking")

    /// Session sync logging
    static let sync = Logger(subsystem: subsystem, category: "Sync")

    /// Session storage logging
    static let storage = Logger(subsystem: subsystem, category: "Storage")

    /// General app logging
    static let app = Logger(subsystem: subsystem, category: "App")

    /// Safety/fall detection logging
    static let safety = Logger(subsystem: subsystem, category: "Safety")
}
