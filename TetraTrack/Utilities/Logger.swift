//
//  Logger.swift
//  TetraTrack
//
//  Centralized logging using os.Logger for better performance and filtering
//

import Foundation
import os

/// Centralized logging for TetraTrack app
/// Usage: Log.services.debug("Message") or Log.health.error("Error message")
enum Log {
    /// General app logging
    static let app = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "App")

    /// Services layer logging (RideTracker, etc.)
    static let services = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Services")

    /// Ride tracking logging (start, stop, state changes)
    static let tracking = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Tracking")

    /// HealthKit related logging
    static let health = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Health")

    /// Location and motion logging
    static let location = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Location")

    /// Watch connectivity logging
    static let watch = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Watch")

    /// Notifications logging
    static let notifications = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Notifications")

    /// Family sharing logging
    static let family = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Family")

    /// External integrations
    static let integrations = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Integrations")

    /// Audio coaching logging
    static let audio = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Audio")

    /// Widget data sync logging
    static let widgets = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Widgets")

    /// Fall detection logging
    static let safety = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Safety")

    /// Data export logging
    static let export = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Export")

    /// AI/Intelligence logging
    static let intelligence = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Intelligence")

    /// UI/View lifecycle logging
    static let ui = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "UI")

    /// Gait analysis diagnostic logging (DEBUG only)
    static let gait = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "GaitDiagnostic")

    /// Shooting discipline logging
    static let shooting = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Shooting")

    /// Storage/persistence logging
    static let storage = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Storage")
}
