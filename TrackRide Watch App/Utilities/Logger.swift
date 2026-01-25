//
//  Logger.swift
//  TrackRide Watch App
//
//  Centralized logging for Watch app using os.Logger
//

import Foundation
import os

/// Centralized logging for TrackRide Watch app
/// Usage: Log.watch.debug("Message") or Log.health.error("Error message")
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "TrackRide.Watch"

    /// Watch connectivity logging
    static let watch = Logger(subsystem: subsystem, category: "Watch")

    /// HealthKit related logging
    static let health = Logger(subsystem: subsystem, category: "Health")

    /// Location and motion logging
    static let location = Logger(subsystem: subsystem, category: "Location")

    /// Workout/tracking logging
    static let tracking = Logger(subsystem: subsystem, category: "Tracking")

    /// General app logging
    static let app = Logger(subsystem: subsystem, category: "App")
}
