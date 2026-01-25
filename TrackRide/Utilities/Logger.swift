//
//  Logger.swift
//  TrackRide
//
//  Centralized logging using os.Logger for better performance and filtering
//

import Foundation
import os

/// Centralized logging for TrackRide app
/// Usage: Log.services.debug("Message") or Log.health.error("Error message")
enum Log {
    /// General app logging
    static let app = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrackRide", category: "App")

    /// Services layer logging (RideTracker, etc.)
    static let services = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrackRide", category: "Services")

    /// Ride tracking logging (start, stop, state changes)
    static let tracking = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrackRide", category: "Tracking")

    /// HealthKit related logging
    static let health = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrackRide", category: "Health")

    /// Location and motion logging
    static let location = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrackRide", category: "Location")

    /// Watch connectivity logging
    static let watch = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrackRide", category: "Watch")

    /// Notifications logging
    static let notifications = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrackRide", category: "Notifications")

    /// Family sharing logging
    static let family = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrackRide", category: "Family")

    /// External integrations
    static let integrations = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrackRide", category: "Integrations")

    /// Audio coaching logging
    static let audio = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrackRide", category: "Audio")

    /// Widget data sync logging
    static let widgets = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrackRide", category: "Widgets")

    /// Fall detection logging
    static let safety = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrackRide", category: "Safety")

    /// Data export logging
    static let export = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrackRide", category: "Export")

    /// AI/Intelligence logging
    static let intelligence = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrackRide", category: "Intelligence")

    /// UI/View lifecycle logging
    static let ui = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrackRide", category: "UI")

    /// Gait analysis diagnostic logging (DEBUG only)
    static let gait = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrackRide", category: "GaitDiagnostic")
}
